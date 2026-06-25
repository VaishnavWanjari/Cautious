import { contextBridge, ipcRenderer } from "electron";

// Safe bridge: expose only the backend base URL lookup to the renderer.
contextBridge.exposeInMainWorld("scheduler", {
  backendBaseUrl: (): Promise<string> => ipcRenderer.invoke("backend-base-url"),
});
