import { useEffect, useMemo, useState } from "react";
import { api } from "../api/client";
import type { ScheduleResult } from "../types";

interface Props {
  projectId: number | null;
  version: number;
}

const DAY_MS = 86400000;

/** Lightweight dependency-free Gantt rendered with CSS grid + absolute bars. */
export default function GanttChart({ projectId, version }: Props) {
  const [schedule, setSchedule] = useState<ScheduleResult | null>(null);
  const [onlyCritical, setOnlyCritical] = useState(false);

  useEffect(() => {
    if (projectId == null) return;
    api.computeSchedule(projectId).then(setSchedule).catch(() => setSchedule(null));
  }, [projectId, version]);

  const model = useMemo(() => {
    if (!schedule) return null;
    const acts = schedule.activities.filter(
      (a) => a.start_date && a.finish_date && (!onlyCritical || a.is_critical)
    );
    if (acts.length === 0) return null;
    const starts = acts.map((a) => new Date(a.start_date!).getTime());
    const finishes = acts.map((a) => new Date(a.finish_date!).getTime());
    const min = Math.min(...starts);
    const max = Math.max(...finishes);
    const totalDays = Math.max(1, Math.round((max - min) / DAY_MS) + 1);
    return { acts, min, totalDays };
  }, [schedule, onlyCritical]);

  if (projectId == null) return <div className="p-8 text-slate-500">No project selected.</div>;
  if (!model) return <div className="p-8 text-slate-500">No scheduled activities to chart.</div>;

  const { acts, min, totalDays } = model;
  const colWidth = 26; // px per day
  const chartWidth = totalDays * colWidth;

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-3">
        <h1 className="text-xl font-semibold text-slate-800">Gantt Chart</h1>
        <label className="text-sm text-slate-600 flex items-center gap-2">
          <input
            type="checkbox"
            checked={onlyCritical}
            onChange={(e) => setOnlyCritical(e.target.checked)}
          />
          Critical path only
        </label>
      </div>

      <div className="bg-white rounded-xl border border-slate-100 shadow-sm overflow-auto">
        <div className="flex min-w-fit">
          {/* labels column */}
          <div className="sticky left-0 bg-white z-10 border-r border-slate-100">
            <div className="h-8 border-b border-slate-100" />
            {acts.map((a) => (
              <div
                key={a.id}
                className="h-8 px-3 flex items-center text-xs whitespace-nowrap border-b border-slate-50"
                style={{ width: 220 }}
              >
                {a.is_critical && <span className="text-critical mr-1">●</span>}
                <span className="font-medium text-slate-700">{a.activity_id}</span>
                <span className="text-slate-500 ml-2 truncate">{a.name}</span>
              </div>
            ))}
          </div>

          {/* bars area */}
          <div style={{ width: chartWidth }} className="relative">
            {/* week gridlines header */}
            <div className="h-8 border-b border-slate-100 relative">
              {Array.from({ length: Math.ceil(totalDays / 7) }).map((_, w) => (
                <div
                  key={w}
                  className="absolute top-0 h-full border-l border-slate-100 text-[10px] text-slate-400 pl-1"
                  style={{ left: w * 7 * colWidth }}
                >
                  W{w + 1}
                </div>
              ))}
            </div>
            {acts.map((a) => {
              const s = new Date(a.start_date!).getTime();
              const f = new Date(a.finish_date!).getTime();
              const offsetDays = Math.round((s - min) / DAY_MS);
              const spanDays = Math.max(1, Math.round((f - s) / DAY_MS) + 1);
              return (
                <div key={a.id} className="h-8 border-b border-slate-50 relative">
                  {Array.from({ length: Math.ceil(totalDays / 7) }).map((_, w) => (
                    <div
                      key={w}
                      className="absolute top-0 h-full border-l border-slate-50"
                      style={{ left: w * 7 * colWidth }}
                    />
                  ))}
                  <div
                    className={`absolute top-1.5 h-5 rounded text-[10px] text-white flex items-center px-2 overflow-hidden ${
                      a.is_critical ? "bg-critical" : "bg-epc-700"
                    }`}
                    style={{ left: offsetDays * colWidth, width: spanDays * colWidth - 2 }}
                    title={`${a.name}: ${a.start_date} → ${a.finish_date} (${a.duration}d)`}
                  >
                    {a.duration}d
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
      <p className="text-xs text-slate-400 mt-2">
        Project: {schedule?.project_start} → {schedule?.project_finish} · Critical activities in
        orange.
      </p>
    </div>
  );
}
