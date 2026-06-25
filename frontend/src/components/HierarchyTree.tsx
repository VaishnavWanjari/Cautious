import { useCallback, useEffect, useState, type ReactNode } from "react";
import { api } from "../api/client";
import type { Activity, PMCC, SNR, Subsystem, System, Template } from "../types";

interface Props {
  projectId: number | null;
  onChanged: () => void;
}

/** A small inline "add" form shared by every level. */
function AddRow({ placeholder, onAdd }: { placeholder: string; onAdd: (v: string) => void }) {
  const [v, setV] = useState("");
  return (
    <div className="flex gap-2 mt-1">
      <input
        className="border border-slate-300 rounded px-2 py-1 text-xs flex-1"
        placeholder={placeholder}
        value={v}
        onChange={(e) => setV(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter" && v.trim()) {
            onAdd(v.trim());
            setV("");
          }
        }}
      />
      <button
        className="text-xs bg-slate-100 hover:bg-slate-200 rounded px-2"
        onClick={() => {
          if (v.trim()) {
            onAdd(v.trim());
            setV("");
          }
        }}
      >
        + Add
      </button>
    </div>
  );
}

export default function HierarchyTree({ projectId, onChanged }: Props) {
  const [pmccs, setPmccs] = useState<PMCC[]>([]);
  const [templates, setTemplates] = useState<Template[]>([]);
  const [open, setOpen] = useState<Set<string>>(new Set());

  const reload = useCallback(() => {
    if (projectId == null) return;
    api.listPmccs(projectId).then(setPmccs);
  }, [projectId]);

  useEffect(() => {
    reload();
    api.listTemplates().then(setTemplates);
  }, [reload]);

  const toggle = (key: string) =>
    setOpen((s) => {
      const n = new Set(s);
      n.has(key) ? n.delete(key) : n.add(key);
      return n;
    });

  if (projectId == null) return <div className="p-8 text-slate-500">No project selected.</div>;

  return (
    <div className="p-6">
      <h1 className="text-xl font-semibold text-slate-800 mb-4">
        Commissioning Hierarchy
        <span className="text-sm font-normal text-slate-400 ml-2">
          PMCC → System → Subsystem → SNR → Activity
        </span>
      </h1>

      <div className="bg-white rounded-xl border border-slate-100 shadow-sm p-4 space-y-2">
        {pmccs.map((p) => (
          <PMCCNode
            key={p.id}
            pmcc={p}
            open={open}
            toggle={toggle}
            templates={templates}
            onChanged={onChanged}
            onDelete={async () => {
              await api.deletePmcc(p.id);
              reload();
              onChanged();
            }}
          />
        ))}
        <AddRow
          placeholder="New PMCC code (e.g. PMCC-04)"
          onAdd={async (code) => {
            await api.createPmcc(projectId, { code, name: code });
            reload();
          }}
        />
      </div>
    </div>
  );
}

function Caret({ on }: { on: boolean }) {
  return <span className="inline-block w-3 text-slate-400">{on ? "▾" : "▸"}</span>;
}

function PMCCNode({
  pmcc,
  open,
  toggle,
  templates,
  onChanged,
  onDelete,
}: {
  pmcc: PMCC;
  open: Set<string>;
  toggle: (k: string) => void;
  templates: Template[];
  onChanged: () => void;
  onDelete: () => void;
}) {
  const key = `p${pmcc.id}`;
  const [systems, setSystems] = useState<System[]>([]);
  const isOpen = open.has(key);

  const reload = useCallback(() => api.listSystems(pmcc.id).then(setSystems), [pmcc.id]);
  useEffect(() => {
    if (isOpen) reload();
  }, [isOpen, reload]);

  return (
    <div>
      <Row
        onClick={() => toggle(key)}
        caret={<Caret on={isOpen} />}
        title={pmcc.code}
        subtitle={pmcc.name}
        badge="PMCC"
        onDelete={onDelete}
      />
      {isOpen && (
        <div className="ml-5 mt-1 space-y-1 border-l border-slate-100 pl-3">
          {systems.map((s) => (
            <SystemNode
              key={s.id}
              system={s}
              open={open}
              toggle={toggle}
              templates={templates}
              onChanged={onChanged}
              onDelete={async () => {
                await api.deleteSystem(s.id);
                reload();
                onChanged();
              }}
            />
          ))}
          <AddRow
            placeholder="New System ID"
            onAdd={async (id) => {
              await api.createSystem(pmcc.id, { system_id: id, description: id });
              reload();
            }}
          />
        </div>
      )}
    </div>
  );
}

function SystemNode({
  system,
  open,
  toggle,
  templates,
  onChanged,
  onDelete,
}: {
  system: System;
  open: Set<string>;
  toggle: (k: string) => void;
  templates: Template[];
  onChanged: () => void;
  onDelete: () => void;
}) {
  const key = `s${system.id}`;
  const [subs, setSubs] = useState<Subsystem[]>([]);
  const isOpen = open.has(key);
  const reload = useCallback(() => api.listSubsystems(system.id).then(setSubs), [system.id]);
  useEffect(() => {
    if (isOpen) reload();
  }, [isOpen, reload]);

  return (
    <div>
      <Row
        onClick={() => toggle(key)}
        caret={<Caret on={isOpen} />}
        title={system.system_id}
        subtitle={system.description}
        badge="System"
        onDelete={onDelete}
      />
      {isOpen && (
        <div className="ml-5 mt-1 space-y-1 border-l border-slate-100 pl-3">
          {subs.map((ss) => (
            <SubsystemNode
              key={ss.id}
              subsystem={ss}
              open={open}
              toggle={toggle}
              templates={templates}
              onChanged={onChanged}
              onDelete={async () => {
                await api.deleteSubsystem(ss.id);
                reload();
                onChanged();
              }}
            />
          ))}
          <AddRow
            placeholder="New Subsystem number (e.g. SS004)"
            onAdd={async (number) => {
              await api.createSubsystem(system.id, { number, description: number });
              reload();
            }}
          />
        </div>
      )}
    </div>
  );
}

function SubsystemNode({
  subsystem,
  open,
  toggle,
  templates,
  onChanged,
  onDelete,
}: {
  subsystem: Subsystem;
  open: Set<string>;
  toggle: (k: string) => void;
  templates: Template[];
  onChanged: () => void;
  onDelete: () => void;
}) {
  const key = `ss${subsystem.id}`;
  const [snrs, setSnrs] = useState<SNR[]>([]);
  const isOpen = open.has(key);
  const reload = useCallback(() => api.listSnrs(subsystem.id).then(setSnrs), [subsystem.id]);
  useEffect(() => {
    if (isOpen) reload();
  }, [isOpen, reload]);

  return (
    <div>
      <Row
        onClick={() => toggle(key)}
        caret={<Caret on={isOpen} />}
        title={subsystem.number}
        subtitle={subsystem.description}
        badge="Subsystem"
        onDelete={onDelete}
      />
      {isOpen && (
        <div className="ml-5 mt-1 space-y-1 border-l border-slate-100 pl-3">
          {snrs.map((snr) => (
            <SNRNode
              key={snr.id}
              snr={snr}
              open={open}
              toggle={toggle}
              templates={templates}
              onChanged={onChanged}
              onDelete={async () => {
                await api.deleteSnr(snr.id);
                reload();
                onChanged();
              }}
            />
          ))}
          <AddRow
            placeholder="New SNR / Circuit code"
            onAdd={async (code) => {
              await api.createSnr(subsystem.id, { code, description: code });
              reload();
            }}
          />
        </div>
      )}
    </div>
  );
}

function SNRNode({
  snr,
  open,
  toggle,
  templates,
  onChanged,
  onDelete,
}: {
  snr: SNR;
  open: Set<string>;
  toggle: (k: string) => void;
  templates: Template[];
  onChanged: () => void;
  onDelete: () => void;
}) {
  const key = `snr${snr.id}`;
  const [acts, setActs] = useState<Activity[]>([]);
  const [tplId, setTplId] = useState<string>("");
  const isOpen = open.has(key);
  const reload = useCallback(() => api.listSnrActivities(snr.id).then(setActs), [snr.id]);
  useEffect(() => {
    if (isOpen) reload();
  }, [isOpen, reload]);

  async function addFromTemplate() {
    const tpl = templates.find((t) => t.id === Number(tplId));
    if (!tpl) return;
    const seq = (acts.length + 1) * 10;
    await api.createActivity(snr.id, {
      activity_id: `A-${String(seq).padStart(3, "0")}`,
      name: tpl.name,
      duration: tpl.default_duration,
      discipline: tpl.discipline,
      template_id: tpl.id,
    });
    reload();
    onChanged();
  }

  return (
    <div>
      <Row
        onClick={() => toggle(key)}
        caret={<Caret on={isOpen} />}
        title={snr.code}
        subtitle={`${snr.snr_type} · ${snr.description}`}
        badge="SNR"
        onDelete={onDelete}
      />
      {isOpen && (
        <div className="ml-5 mt-1 space-y-1 border-l border-slate-100 pl-3">
          {acts.map((a) => (
            <div
              key={a.id}
              className="flex items-center justify-between text-xs py-1 px-2 rounded hover:bg-slate-50"
            >
              <span>
                {a.is_critical && <span className="text-critical mr-1">●</span>}
                <span className="font-medium">{a.activity_id}</span> {a.name}
                <span className="text-slate-400 ml-2">{a.duration}d</span>
                {a.start_date && (
                  <span className="text-slate-400 ml-2">
                    {a.start_date} → {a.finish_date}
                  </span>
                )}
              </span>
              <button
                className="text-slate-300 hover:text-red-500"
                onClick={async () => {
                  await api.deleteActivity(a.id);
                  reload();
                  onChanged();
                }}
              >
                ✕
              </button>
            </div>
          ))}
          <div className="flex gap-2 mt-1">
            <select
              className="border border-slate-300 rounded px-2 py-1 text-xs flex-1"
              value={tplId}
              onChange={(e) => setTplId(e.target.value)}
            >
              <option value="">Add activity from template…</option>
              {templates.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name} ({t.default_duration}d)
                </option>
              ))}
            </select>
            <button
              className="text-xs bg-slate-100 hover:bg-slate-200 rounded px-2"
              onClick={addFromTemplate}
            >
              + Add
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function Row({
  onClick,
  caret,
  title,
  subtitle,
  badge,
  onDelete,
}: {
  onClick: () => void;
  caret: ReactNode;
  title: string;
  subtitle?: string;
  badge: string;
  onDelete: () => void;
}) {
  return (
    <div className="group flex items-center gap-2 py-1 px-2 rounded hover:bg-slate-50">
      <button onClick={onClick} className="flex items-center gap-2 flex-1 text-left">
        {caret}
        <span className="text-[10px] uppercase tracking-wide text-white bg-epc-700/80 rounded px-1.5 py-0.5">
          {badge}
        </span>
        <span className="text-sm font-medium text-slate-700">{title}</span>
        {subtitle && <span className="text-xs text-slate-400">{subtitle}</span>}
      </button>
      <button
        className="text-slate-300 hover:text-red-500 opacity-0 group-hover:opacity-100"
        onClick={onDelete}
      >
        ✕
      </button>
    </div>
  );
}
