import { useEffect, useState, type ReactNode } from "react";
import { api } from "../api/client";
import type { Project } from "../types";

interface Props {
  projectId: number | null;
  onSaved: () => void;
  onCreated: (id: number) => void;
}

const WEEKDAYS = [
  { n: 1, l: "Mon" },
  { n: 2, l: "Tue" },
  { n: 3, l: "Wed" },
  { n: 4, l: "Thu" },
  { n: 5, l: "Fri" },
  { n: 6, l: "Sat" },
  { n: 7, l: "Sun" },
];

const blank: Partial<Project> = {
  name: "",
  client: "",
  location: "",
  mechanical_completion_date: "",
  planned_startup_date: "",
  working_weekdays: [1, 2, 3, 4, 5],
  holidays: [],
};

export default function ProjectSetup({ projectId, onSaved, onCreated }: Props) {
  const [form, setForm] = useState<Partial<Project>>(blank);
  const [creating, setCreating] = useState(false);
  const [holidayText, setHolidayText] = useState("");
  const [msg, setMsg] = useState<string | null>(null);

  useEffect(() => {
    if (projectId == null || creating) return;
    api.getProject(projectId).then((p) => {
      setForm(p);
      setHolidayText(p.holidays.join(", "));
    });
  }, [projectId, creating]);

  const set = (k: keyof Project, v: unknown) => setForm((f) => ({ ...f, [k]: v }));

  const toggleDay = (n: number) => {
    const days = new Set(form.working_weekdays ?? []);
    days.has(n) ? days.delete(n) : days.add(n);
    set("working_weekdays", [...days].sort());
  };

  async function save() {
    const payload = {
      ...form,
      mechanical_completion_date: form.mechanical_completion_date || null,
      planned_startup_date: form.planned_startup_date || null,
      holidays: holidayText
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean),
    };
    try {
      if (creating || projectId == null) {
        const p = await api.createProject(payload);
        setCreating(false);
        onCreated(p.id);
        setMsg("Project created.");
      } else {
        await api.updateProject(projectId, payload);
        setMsg("Project saved.");
      }
      onSaved();
    } catch (e) {
      setMsg((e as Error).message);
    }
  }

  return (
    <div className="p-6 max-w-2xl">
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-xl font-semibold text-slate-800">
          {creating ? "New Project" : "Project Setup"}
        </h1>
        <button
          className="text-sm text-epc-700 underline"
          onClick={() => {
            setCreating(true);
            setForm(blank);
            setHolidayText("");
          }}
        >
          + New Project
        </button>
      </div>

      <div className="bg-white rounded-xl border border-slate-100 shadow-sm p-5 space-y-4">
        <Field label="Project Name">
          <input className="inp" value={form.name ?? ""} onChange={(e) => set("name", e.target.value)} />
        </Field>
        <div className="grid grid-cols-2 gap-4">
          <Field label="Client Name">
            <input className="inp" value={form.client ?? ""} onChange={(e) => set("client", e.target.value)} />
          </Field>
          <Field label="Project Location">
            <input
              className="inp"
              value={form.location ?? ""}
              onChange={(e) => set("location", e.target.value)}
            />
          </Field>
        </div>
        <div className="grid grid-cols-2 gap-4">
          <Field label="Mechanical Completion Date">
            <input
              type="date"
              className="inp"
              value={form.mechanical_completion_date ?? ""}
              onChange={(e) => set("mechanical_completion_date", e.target.value)}
            />
          </Field>
          <Field label="Planned Startup Date">
            <input
              type="date"
              className="inp"
              value={form.planned_startup_date ?? ""}
              onChange={(e) => set("planned_startup_date", e.target.value)}
            />
          </Field>
        </div>

        <Field label="Working Days">
          <div className="flex gap-2">
            {WEEKDAYS.map((d) => {
              const on = (form.working_weekdays ?? []).includes(d.n);
              return (
                <button
                  key={d.n}
                  onClick={() => toggleDay(d.n)}
                  className={`px-3 py-1.5 rounded text-sm border ${
                    on ? "bg-epc-700 text-white border-epc-700" : "bg-white text-slate-600 border-slate-300"
                  }`}
                >
                  {d.l}
                </button>
              );
            })}
          </div>
        </Field>

        <Field label="Holidays (comma-separated, YYYY-MM-DD)">
          <input
            className="inp"
            placeholder="2027-01-01, 2027-02-22"
            value={holidayText}
            onChange={(e) => setHolidayText(e.target.value)}
          />
        </Field>

        <div className="flex items-center gap-3 pt-2">
          <button onClick={save} className="bg-epc-700 hover:bg-epc-800 text-white px-4 py-2 rounded text-sm">
            {creating ? "Create Project" : "Save Changes"}
          </button>
          {msg && <span className="text-sm text-slate-500">{msg}</span>}
        </div>
      </div>

      <style>{`.inp{width:100%;border:1px solid #cbd5e1;border-radius:6px;padding:7px 10px;font-size:14px}`}</style>
    </div>
  );
}

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="block">
      <span className="text-xs uppercase tracking-wide text-slate-500">{label}</span>
      <div className="mt-1">{children}</div>
    </label>
  );
}
