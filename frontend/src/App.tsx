import { useCallback, useEffect, useState } from "react";
import { api } from "./api/client";
import type { Project } from "./types";
import ProjectSetup from "./components/ProjectSetup";
import HierarchyTree from "./components/HierarchyTree";
import TemplateLibrary from "./components/TemplateLibrary";
import NetworkEditor from "./components/NetworkEditor";
import GanttChart from "./components/GanttChart";
import LogicBuilder from "./components/LogicBuilder";
import Dashboard from "./components/Dashboard";
import AiAssistant from "./components/AiAssistant";
import ExportPanel from "./components/ExportPanel";

type View =
  | "dashboard"
  | "project"
  | "hierarchy"
  | "templates"
  | "network"
  | "gantt"
  | "logic"
  | "ai"
  | "exports";

const NAV: { key: View; label: string; icon: string }[] = [
  { key: "dashboard", label: "Dashboard", icon: "▣" },
  { key: "project", label: "Project Setup", icon: "⚙" },
  { key: "hierarchy", label: "Hierarchy", icon: "❖" },
  { key: "templates", label: "Templates", icon: "▤" },
  { key: "network", label: "Network", icon: "⤳" },
  { key: "gantt", label: "Gantt", icon: "▬" },
  { key: "logic", label: "Logic Engine", icon: "⎇" },
  { key: "ai", label: "AI Assistant", icon: "✦" },
  { key: "exports", label: "Exports", icon: "⇩" },
];

export default function App() {
  const [projects, setProjects] = useState<Project[]>([]);
  const [projectId, setProjectId] = useState<number | null>(null);
  const [view, setView] = useState<View>("dashboard");
  const [scheduleVersion, setScheduleVersion] = useState(0);
  const [aiAvailable, setAiAvailable] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadProjects = useCallback(async () => {
    try {
      const list = await api.listProjects();
      setProjects(list);
      setProjectId((cur) => cur ?? (list[0]?.id ?? null));
    } catch (e) {
      setError(`Cannot reach backend: ${(e as Error).message}`);
    }
  }, []);

  useEffect(() => {
    loadProjects();
    api.health().then((h) => setAiAvailable(h.ai_available)).catch(() => {});
  }, [loadProjects]);

  // Recompute the schedule whenever the network/activities change.
  const recompute = useCallback(async () => {
    if (projectId == null) return;
    try {
      await api.computeSchedule(projectId);
      setScheduleVersion((v) => v + 1);
    } catch (e) {
      setError((e as Error).message);
    }
  }, [projectId]);

  useEffect(() => {
    if (projectId != null) recompute();
  }, [projectId, recompute]);

  return (
    <div className="flex h-full">
      {/* Sidebar */}
      <aside className="w-56 bg-epc-900 text-white flex flex-col">
        <div className="px-4 py-4 border-b border-white/10">
          <div className="text-sm font-bold leading-tight">Commissioning</div>
          <div className="text-sm font-bold leading-tight">Scheduler Pro</div>
          <div className="text-[10px] uppercase tracking-wider text-white/50 mt-1">
            EPC Pre-Commissioning
          </div>
        </div>
        <nav className="flex-1 py-2">
          {NAV.map((n) => (
            <button
              key={n.key}
              onClick={() => setView(n.key)}
              className={`w-full text-left px-4 py-2 text-sm flex items-center gap-3 transition ${
                view === n.key ? "bg-epc-700 text-white" : "text-white/70 hover:bg-white/5"
              }`}
            >
              <span className="w-4 text-center opacity-80">{n.icon}</span>
              {n.label}
            </button>
          ))}
        </nav>
        <div className="px-4 py-3 border-t border-white/10 text-[11px] text-white/50">
          AI: {aiAvailable ? "Online" : "Offline"}
        </div>
      </aside>

      {/* Main */}
      <main className="flex-1 flex flex-col min-w-0">
        <header className="h-14 bg-white border-b border-slate-200 flex items-center px-5 gap-4">
          <span className="text-sm text-slate-500">Project</span>
          <select
            className="border border-slate-300 rounded px-2 py-1 text-sm"
            value={projectId ?? ""}
            onChange={(e) => setProjectId(Number(e.target.value))}
          >
            {projects.length === 0 && <option value="">No projects</option>}
            {projects.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
          <div className="flex-1" />
          <button
            onClick={recompute}
            className="text-sm bg-epc-700 hover:bg-epc-800 text-white px-3 py-1.5 rounded"
          >
            ↻ Recalculate Schedule
          </button>
        </header>

        {error && (
          <div className="bg-red-50 text-red-700 text-sm px-5 py-2 border-b border-red-200">
            {error}
            <button className="ml-3 underline" onClick={() => setError(null)}>
              dismiss
            </button>
          </div>
        )}

        <section className="flex-1 overflow-auto">
          {view === "dashboard" && (
            <Dashboard projectId={projectId} version={scheduleVersion} />
          )}
          {view === "project" && (
            <ProjectSetup
              projectId={projectId}
              onSaved={async () => {
                await loadProjects();
                recompute();
              }}
              onCreated={(id) => setProjectId(id)}
            />
          )}
          {view === "hierarchy" && (
            <HierarchyTree projectId={projectId} onChanged={recompute} />
          )}
          {view === "templates" && <TemplateLibrary />}
          {view === "network" && (
            <NetworkEditor
              projectId={projectId}
              version={scheduleVersion}
              onChanged={recompute}
            />
          )}
          {view === "gantt" && <GanttChart projectId={projectId} version={scheduleVersion} />}
          {view === "logic" && <LogicBuilder projectId={projectId} />}
          {view === "ai" && <AiAssistant projectId={projectId} aiAvailable={aiAvailable} />}
          {view === "exports" && <ExportPanel projectId={projectId} />}
        </section>
      </main>
    </div>
  );
}
