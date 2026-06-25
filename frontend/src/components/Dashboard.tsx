import { useEffect, useState } from "react";
import { api } from "../api/client";
import type { ProjectSummary, ValidationResult } from "../types";

interface Props {
  projectId: number | null;
  version: number;
}

function Card({ label, value, accent }: { label: string; value: number; accent?: string }) {
  return (
    <div className="bg-white rounded-xl shadow-sm border border-slate-100 px-5 py-4 min-w-[140px]">
      <div className={`text-3xl font-bold ${accent ?? "text-epc-700"}`}>{value}</div>
      <div className="text-[11px] uppercase tracking-wide text-slate-500 mt-1">{label}</div>
    </div>
  );
}

export default function Dashboard({ projectId, version }: Props) {
  const [summary, setSummary] = useState<ProjectSummary | null>(null);
  const [validation, setValidation] = useState<ValidationResult | null>(null);

  useEffect(() => {
    if (projectId == null) return;
    api.summary(projectId).then(setSummary).catch(() => setSummary(null));
    api.validate(projectId).then(setValidation).catch(() => setValidation(null));
  }, [projectId, version]);

  if (projectId == null) return <Empty />;
  if (!summary) return <div className="p-8 text-slate-500">Loading dashboard…</div>;

  const readiness =
    summary.total_activities > 0
      ? Math.round((summary.completed / summary.total_activities) * 100)
      : 0;

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-xl font-semibold text-slate-800">{summary.project.name}</h1>
        <p className="text-sm text-slate-500">
          {summary.project.client} · Mechanical Completion:{" "}
          {summary.project.mechanical_completion_date ?? "—"} · Planned Startup:{" "}
          {summary.project.planned_startup_date ?? "—"}
        </p>
      </div>

      <div className="flex gap-4 flex-wrap">
        <Card label="Total Activities" value={summary.total_activities} />
        <Card label="Completed" value={summary.completed} accent="text-green-600" />
        <Card label="In Progress" value={summary.in_progress} accent="text-amber-600" />
        <Card label="Pending" value={summary.pending} accent="text-slate-500" />
        <Card label="Critical" value={summary.critical} accent="text-critical" />
        <Card label="Readiness %" value={readiness} accent="text-epc-700" />
      </div>

      {validation && (validation.warnings.length > 0 || validation.errors.length > 0) && (
        <div className="bg-white rounded-xl border border-slate-100 shadow-sm p-4">
          <h2 className="text-sm font-semibold text-slate-700 mb-2">Network Validation</h2>
          {validation.errors.map((e, i) => (
            <div key={`e${i}`} className="text-sm text-red-600">
              ✕ {e}
            </div>
          ))}
          {validation.warnings.map((w, i) => (
            <div key={`w${i}`} className="text-sm text-amber-600">
              ⚠ {w}
            </div>
          ))}
        </div>
      )}

      <div className="bg-white rounded-xl border border-slate-100 shadow-sm overflow-hidden">
        <h2 className="text-sm font-semibold text-slate-700 px-4 py-3 border-b border-slate-100">
          Activity Schedule
        </h2>
        <table className="w-full text-sm">
          <thead className="bg-slate-50 text-slate-500 text-left">
            <tr>
              <th className="px-4 py-2">Activity</th>
              <th className="px-4 py-2">Duration</th>
              <th className="px-4 py-2">Start</th>
              <th className="px-4 py-2">Finish</th>
              <th className="px-4 py-2">Float</th>
              <th className="px-4 py-2">Status</th>
            </tr>
          </thead>
          <tbody>
            {summary.activities.map((a, i) => (
              <tr
                key={i}
                className={`border-t border-slate-100 ${a.is_critical ? "bg-orange-50" : ""}`}
              >
                <td className="px-4 py-2 font-medium">
                  {a.is_critical && <span className="text-critical mr-1">●</span>}
                  {a.name}
                </td>
                <td className="px-4 py-2">{a.duration}d</td>
                <td className="px-4 py-2">{a.start_date ?? "—"}</td>
                <td className="px-4 py-2">{a.finish_date ?? "—"}</td>
                <td className="px-4 py-2">{a.total_float ?? "—"}</td>
                <td className="px-4 py-2">{a.status}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function Empty() {
  return (
    <div className="p-10 text-center text-slate-500">
      No project selected. Create one under <strong>Project Setup</strong>.
    </div>
  );
}
