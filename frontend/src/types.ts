// Shared types mirroring the backend pydantic schemas.

export interface Project {
  id: number;
  name: string;
  client: string;
  location: string;
  mechanical_completion_date: string | null;
  planned_startup_date: string | null;
  working_weekdays: number[];
  holidays: string[];
}

export interface PMCC {
  id: number;
  project_id: number;
  code: string;
  name: string;
  area: string;
}

export interface System {
  id: number;
  pmcc_id: number;
  system_id: string;
  description: string;
  priority: number;
  discipline: string;
  area: string;
}

export interface Subsystem {
  id: number;
  system_id: number;
  number: string;
  description: string;
  priority: number;
  discipline: string;
  area: string;
}

export interface SNR {
  id: number;
  subsystem_id: number;
  code: string;
  description: string;
  snr_type: string;
}

export interface Activity {
  id: number;
  snr_id: number;
  activity_id: string;
  name: string;
  duration: number;
  discipline: string;
  area: string;
  priority: number;
  status: string;
  progress: number;
  es: number | null;
  ef: number | null;
  ls: number | null;
  lf: number | null;
  total_float: number | null;
  is_critical: boolean;
  start_date: string | null;
  finish_date: string | null;
  pos_x: number | null;
  pos_y: number | null;
}

export interface Relationship {
  id: number;
  project_id: number;
  predecessor_id: number;
  successor_id: number;
  rel_type: string;
  lag: number;
}

export interface Template {
  id: number;
  name: string;
  category: string;
  default_duration: number;
  discipline: string;
  resources: string;
  utilities: string;
  description: string;
  is_builtin: boolean;
}

export interface LogicRule {
  id: number;
  project_id: number;
  condition: string;
  action: string;
  structured: string;
  enabled: boolean;
}

export interface Constraint {
  id: number;
  project_id: number;
  constraint_type: string;
  name: string;
  capacity: number;
  available: boolean;
  notes: string;
}

export interface ScheduleActivity {
  id: number;
  activity_id: string;
  name: string;
  duration: number;
  es: number | null;
  ef: number | null;
  ls: number | null;
  lf: number | null;
  total_float: number | null;
  is_critical: boolean;
  start_date: string | null;
  finish_date: string | null;
}

export interface ScheduleResult {
  activities: ScheduleActivity[];
  critical_path: number[];
  project_start: string | null;
  project_finish: string | null;
  warnings: string[];
}

export interface NetworkNode {
  id: string;
  data: {
    activityId: string;
    name: string;
    duration: number;
    discipline: string;
    status: string;
    priority: number;
    startDate: string | null;
    finishDate: string | null;
    totalFloat: number | null;
    isCritical: boolean;
  };
  position: { x: number; y: number };
}

export interface NetworkEdge {
  id: string;
  source: string;
  target: string;
  label: string;
  animated: boolean;
}

export interface NetworkData {
  nodes: NetworkNode[];
  edges: NetworkEdge[];
}

export interface ValidationResult {
  warnings: string[];
  errors: string[];
}

export interface ProjectSummary {
  project: {
    id: number;
    name: string;
    client: string;
    mechanical_completion_date: string | null;
    planned_startup_date: string | null;
  };
  total_activities: number;
  completed: number;
  in_progress: number;
  pending: number;
  critical: number;
  activities: Array<{
    name: string;
    duration: number;
    status: string;
    is_critical: boolean;
    start_date: string | null;
    finish_date: string | null;
    total_float: number | null;
  }>;
}
