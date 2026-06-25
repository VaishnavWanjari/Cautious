// Typed fetch wrapper around the FastAPI backend.
import type {
  Activity,
  Constraint,
  LogicRule,
  NetworkData,
  PMCC,
  Project,
  ProjectSummary,
  Relationship,
  SNR,
  ScheduleResult,
  Subsystem,
  System,
  Template,
  ValidationResult,
} from "../types";

let cachedBase: string | null = null;

async function baseUrl(): Promise<string> {
  if (cachedBase) return cachedBase;
  if (window.scheduler?.backendBaseUrl) {
    cachedBase = await window.scheduler.backendBaseUrl();
  } else {
    cachedBase = "http://127.0.0.1:8000";
  }
  return cachedBase;
}

async function req<T>(method: string, path: string, body?: unknown): Promise<T> {
  const base = await baseUrl();
  const res = await fetch(`${base}${path}`, {
    method,
    headers: body ? { "Content-Type": "application/json" } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) {
    let detail = res.statusText;
    try {
      detail = (await res.json()).detail ?? detail;
    } catch {
      /* ignore */
    }
    throw new Error(`${res.status}: ${detail}`);
  }
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

export const api = {
  baseUrl,
  health: () => req<{ status: string; ai_available: boolean }>("GET", "/api/health"),

  // projects + hierarchy
  listProjects: () => req<Project[]>("GET", "/api/projects"),
  getProject: (id: number) => req<Project>("GET", `/api/projects/${id}`),
  createProject: (b: Partial<Project>) => req<Project>("POST", "/api/projects", b),
  updateProject: (id: number, b: Partial<Project>) =>
    req<Project>("PUT", `/api/projects/${id}`, b),

  listPmccs: (pid: number) => req<PMCC[]>("GET", `/api/projects/${pid}/pmccs`),
  createPmcc: (pid: number, b: Partial<PMCC>) =>
    req<PMCC>("POST", `/api/projects/${pid}/pmccs`, b),
  deletePmcc: (id: number) => req<void>("DELETE", `/api/pmccs/${id}`),

  listSystems: (pmccId: number) => req<System[]>("GET", `/api/pmccs/${pmccId}/systems`),
  createSystem: (pmccId: number, b: Partial<System>) =>
    req<System>("POST", `/api/pmccs/${pmccId}/systems`, b),
  deleteSystem: (id: number) => req<void>("DELETE", `/api/systems/${id}`),

  listSubsystems: (sysId: number) =>
    req<Subsystem[]>("GET", `/api/systems/${sysId}/subsystems`),
  createSubsystem: (sysId: number, b: Partial<Subsystem>) =>
    req<Subsystem>("POST", `/api/systems/${sysId}/subsystems`, b),
  deleteSubsystem: (id: number) => req<void>("DELETE", `/api/subsystems/${id}`),

  listSnrs: (subId: number) => req<SNR[]>("GET", `/api/subsystems/${subId}/snrs`),
  createSnr: (subId: number, b: Partial<SNR>) =>
    req<SNR>("POST", `/api/subsystems/${subId}/snrs`, b),
  deleteSnr: (id: number) => req<void>("DELETE", `/api/snrs/${id}`),

  // activities + relationships
  listSnrActivities: (snrId: number) =>
    req<Activity[]>("GET", `/api/snrs/${snrId}/activities`),
  listProjectActivities: (pid: number) =>
    req<Activity[]>("GET", `/api/projects/${pid}/activities`),
  createActivity: (snrId: number, b: Partial<Activity>) =>
    req<Activity>("POST", `/api/snrs/${snrId}/activities`, b),
  updateActivity: (id: number, b: Partial<Activity>) =>
    req<Activity>("PUT", `/api/activities/${id}`, b),
  updatePosition: (id: number, x: number, y: number) =>
    req<Activity>("PATCH", `/api/activities/${id}/position?x=${x}&y=${y}`),
  deleteActivity: (id: number) => req<void>("DELETE", `/api/activities/${id}`),

  listRelationships: (pid: number) =>
    req<Relationship[]>("GET", `/api/projects/${pid}/relationships`),
  createRelationship: (pid: number, b: Partial<Relationship>) =>
    req<Relationship>("POST", `/api/projects/${pid}/relationships`, b),
  updateRelationship: (id: number, b: Partial<Relationship>) =>
    req<Relationship>("PUT", `/api/relationships/${id}`, b),
  deleteRelationship: (id: number) => req<void>("DELETE", `/api/relationships/${id}`),

  // templates
  listTemplates: () => req<Template[]>("GET", "/api/templates"),
  createTemplate: (b: Partial<Template>) => req<Template>("POST", "/api/templates", b),
  deleteTemplate: (id: number) => req<void>("DELETE", `/api/templates/${id}`),

  // logic + constraints
  listLogicRules: (pid: number) => req<LogicRule[]>("GET", `/api/projects/${pid}/logic-rules`),
  createLogicRule: (pid: number, b: Partial<LogicRule>) =>
    req<LogicRule>("POST", `/api/projects/${pid}/logic-rules`, b),
  deleteLogicRule: (id: number) => req<void>("DELETE", `/api/logic-rules/${id}`),
  listConstraints: (pid: number) =>
    req<Constraint[]>("GET", `/api/projects/${pid}/constraints`),
  createConstraint: (pid: number, b: Partial<Constraint>) =>
    req<Constraint>("POST", `/api/projects/${pid}/constraints`, b),
  deleteConstraint: (id: number) => req<void>("DELETE", `/api/constraints/${id}`),

  // scheduling + network
  computeSchedule: (pid: number) =>
    req<ScheduleResult>("POST", `/api/projects/${pid}/schedule/compute`),
  getNetwork: (pid: number) => req<NetworkData>("GET", `/api/projects/${pid}/network`),
  validate: (pid: number) => req<ValidationResult>("GET", `/api/projects/${pid}/validate`),
  summary: (pid: number) => req<ProjectSummary>("GET", `/api/projects/${pid}/summary`),

  // exports (return absolute URLs the browser can open)
  exportUrl: async (pid: number, kind: "xlsx" | "pdf" | "html") =>
    `${await baseUrl()}/api/projects/${pid}/export/${kind}`,

  // AI
  aiStatus: () => req<{ available: boolean }>("GET", "/api/ai/status"),
  aiChat: (pid: number, message: string) =>
    req<{ reply: string; ai_available: boolean }>("POST", "/api/ai/chat", {
      project_id: pid,
      message,
    }),
};
