/**
 * Electron main process.
 *
 * In production it spawns the bundled Python FastAPI backend as a child process
 * (looking for a system Python), waits for it to come up, then loads the React
 * UI. In development (`vite` serving on :5173) it just loads the dev server and
 * assumes the backend is started separately via `uvicorn`.
 */
import { app, BrowserWindow, ipcMain } from "electron";
import { spawn, ChildProcess } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";

const BACKEND_PORT = 8000;
const BACKEND_URL = `http://127.0.0.1:${BACKEND_PORT}`;
const isDev = !app.isPackaged;

let backend: ChildProcess | null = null;
let mainWindow: BrowserWindow | null = null;

function resolvePython(): string {
  // Prefer a bundled venv, fall back to a system interpreter.
  const candidates = [
    path.join(process.resourcesPath, "backend", ".venv", "bin", "python"),
    path.join(process.resourcesPath, "backend", ".venv", "Scripts", "python.exe"),
    process.platform === "win32" ? "python.exe" : "python3",
  ];
  for (const c of candidates) {
    if (c.includes(path.sep) ? existsSync(c) : true) return c;
  }
  return process.platform === "win32" ? "python.exe" : "python3";
}

function startBackend() {
  if (isDev) return; // backend run manually in dev
  const backendDir = path.join(process.resourcesPath, "backend");
  if (!existsSync(backendDir)) {
    console.error("Bundled backend not found at", backendDir);
    return;
  }
  backend = spawn(
    resolvePython(),
    ["-m", "uvicorn", "app.main:app", "--port", String(BACKEND_PORT)],
    { cwd: backendDir, env: { ...process.env }, stdio: "inherit" }
  );
  backend.on("error", (err) => console.error("Backend failed to start:", err));
}

async function waitForBackend(timeoutMs = 20000): Promise<boolean> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(`${BACKEND_URL}/api/health`);
      if (res.ok) return true;
    } catch {
      /* not up yet */
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  return false;
}

async function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1480,
    height: 920,
    backgroundColor: "#0f2a43",
    title: "Commissioning Scheduler Pro",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  if (isDev) {
    await mainWindow.loadURL("http://localhost:5173");
    mainWindow.webContents.openDevTools({ mode: "detach" });
  } else {
    await waitForBackend();
    await mainWindow.loadFile(path.join(__dirname, "..", "dist", "index.html"));
  }
}

ipcMain.handle("backend-base-url", () => BACKEND_URL);

app.whenReady().then(() => {
  startBackend();
  createWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (backend) backend.kill();
  if (process.platform !== "darwin") app.quit();
});

app.on("before-quit", () => {
  if (backend) backend.kill();
});
