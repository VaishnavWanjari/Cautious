/**
 * Electron main process.
 *
 * Spawns the zero-dependency Python "standalone" backend (stdlib only — no
 * pip install needed) as a child process, discovers the URL it actually bound
 * (it self-selects a free port and prints a banner line), waits for it to
 * come up, then loads that URL directly in the window. The backend serves its
 * own complete HTML/CSS/JS UI, so the desktop window is a thin native shell
 * around it — this is the same UI already verified in the browser, including
 * the draggable SIMOPS timeline.
 */
import { app, BrowserWindow, ipcMain } from "electron";
import { spawn, ChildProcess } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";

const isDev = !app.isPackaged;
const URL_RE = /Open this in your browser:\s*(http:\/\/127\.0\.0\.1:\d+)/;
const CANDIDATE_PORTS = [8000, 8001, 8002, 8003, 8004, 8005, 8006, 8007, 8008, 8009, 8010];

let backend: ChildProcess | null = null;
let mainWindow: BrowserWindow | null = null;
let backendUrl = "http://127.0.0.1:8000";

function backendDir(): string {
  return isDev
    ? path.join(__dirname, "..", "..", "backend")
    : path.join(process.resourcesPath, "backend");
}

/** Resolve a Python invocation as {command, args}, preferring a bundled venv. */
function resolvePython(dir: string): { command: string; args: string[] } {
  const venvCandidates = [
    path.join(dir, ".venv", "bin", "python"),
    path.join(dir, ".venv", "Scripts", "python.exe"),
  ];
  for (const c of venvCandidates) {
    if (existsSync(c)) return { command: c, args: [] };
  }
  if (process.platform === "win32") {
    // The `py` launcher is present on most Windows Python installs (including
    // the official installer's default) even when `python.exe` isn't on PATH.
    return { command: "py", args: ["-3"] };
  }
  return { command: "python3", args: [] };
}

/** Wait for the backend's stdout banner announcing the URL it actually bound. */
function waitForUrlFromStdout(child: ChildProcess, timeoutMs = 8000): Promise<string | null> {
  return new Promise((resolve) => {
    let done = false;
    const finish = (url: string | null) => {
      if (done) return;
      done = true;
      resolve(url);
    };
    const timer = setTimeout(() => finish(null), timeoutMs);
    child.stdout?.on("data", (chunk: Buffer) => {
      const m = URL_RE.exec(chunk.toString());
      if (m) {
        clearTimeout(timer);
        finish(m[1]);
      }
    });
  });
}

async function pingHealth(url: string): Promise<boolean> {
  try {
    const res = await fetch(`${url}/api/health`);
    return res.ok;
  } catch {
    return false;
  }
}

/** Fallback: probe the same port range the backend itself falls back through. */
async function discoverByProbing(timeoutMs = 15000): Promise<string | null> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    for (const port of CANDIDATE_PORTS) {
      const url = `http://127.0.0.1:${port}`;
      if (await pingHealth(url)) return url;
    }
    await new Promise((r) => setTimeout(r, 400));
  }
  return null;
}

async function startBackend(): Promise<void> {
  const dir = backendDir();
  const entry = path.join(dir, "run_standalone.py");
  if (!existsSync(entry)) {
    console.error("Standalone backend entry not found at", entry);
    return;
  }
  const { command, args } = resolvePython(dir);
  backend = spawn(command, [...args, entry], {
    cwd: dir,
    env: { ...process.env, NO_BROWSER: "1" },
  });
  backend.on("error", (err) => console.error("Backend failed to start:", err));
  backend.stdout?.on("data", (d) => process.stdout.write(`[backend] ${d}`));
  backend.stderr?.on("data", (d) => process.stderr.write(`[backend] ${d}`));

  const urlFromBanner = await waitForUrlFromStdout(backend);
  if (urlFromBanner) {
    backendUrl = urlFromBanner;
    return;
  }
  // Banner missed (buffering, timing) — fall back to probing /api/health.
  const probed = await discoverByProbing();
  if (probed) backendUrl = probed;
}

async function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1480,
    height: 920,
    backgroundColor: "#0f2a43",
    title: "GPT-3/4 Gas Processing Train — Pre-Commissioning Tracker & Visualizer",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  await mainWindow.loadURL(backendUrl);
  if (isDev) mainWindow.webContents.openDevTools({ mode: "detach" });
}

ipcMain.handle("backend-base-url", () => backendUrl);

app.whenReady().then(async () => {
  await startBackend();
  await createWindow();
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
