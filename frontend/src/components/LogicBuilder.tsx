import { useEffect, useState } from "react";
import { api } from "../api/client";
import type { Constraint, LogicRule } from "../types";

interface Props {
  projectId: number | null;
}

export default function LogicBuilder({ projectId }: Props) {
  const [rules, setRules] = useState<LogicRule[]>([]);
  const [constraints, setConstraints] = useState<Constraint[]>([]);
  const [condition, setCondition] = useState("");
  const [action, setAction] = useState("");
  const [cName, setCName] = useState("");
  const [cType, setCType] = useState("Resource");
  const [cCap, setCCap] = useState(1);

  const reload = () => {
    if (projectId == null) return;
    api.listLogicRules(projectId).then(setRules);
    api.listConstraints(projectId).then(setConstraints);
  };
  useEffect(reload, [projectId]);

  if (projectId == null) return <div className="p-8 text-slate-500">No project selected.</div>;

  return (
    <div className="p-6 grid grid-cols-2 gap-6">
      {/* Logic rules */}
      <div>
        <h1 className="text-xl font-semibold text-slate-800 mb-1">No-Code Logic Engine</h1>
        <p className="text-sm text-slate-500 mb-4">
          Author rules in plain language. Supports AND / OR / NOT and parentheses.
        </p>

        <div className="bg-white rounded-xl border border-slate-100 shadow-sm p-4 space-y-3 mb-4">
          <label className="block">
            <span className="text-xs uppercase tracking-wide text-slate-500">IF (Condition)</span>
            <input
              className="linp"
              placeholder="Hydrotest Complete AND Nitrogen Available"
              value={condition}
              onChange={(e) => setCondition(e.target.value)}
            />
          </label>
          <label className="block">
            <span className="text-xs uppercase tracking-wide text-slate-500">THEN (Action)</span>
            <input
              className="linp"
              placeholder="Enable Leak Test"
              value={action}
              onChange={(e) => setAction(e.target.value)}
            />
          </label>
          <button
            className="bg-epc-700 hover:bg-epc-800 text-white rounded px-4 py-2 text-sm"
            onClick={async () => {
              if (!condition.trim() || !action.trim()) return;
              await api.createLogicRule(projectId, { condition, action, enabled: true });
              setCondition("");
              setAction("");
              reload();
            }}
          >
            Add Rule
          </button>
        </div>

        <div className="space-y-2">
          {rules.map((r) => (
            <div
              key={r.id}
              className="bg-white border border-slate-100 rounded-lg shadow-sm p-3 text-sm flex items-start justify-between"
            >
              <div>
                <span className="text-epc-700 font-semibold">IF</span> {r.condition}{" "}
                <span className="text-epc-700 font-semibold">THEN</span> {r.action}
              </div>
              <button
                className="text-slate-300 hover:text-red-500"
                onClick={async () => {
                  await api.deleteLogicRule(r.id);
                  reload();
                }}
              >
                ✕
              </button>
            </div>
          ))}
          {rules.length === 0 && <div className="text-sm text-slate-400">No rules yet.</div>}
        </div>
      </div>

      {/* Constraints */}
      <div>
        <h1 className="text-xl font-semibold text-slate-800 mb-1">Constraints</h1>
        <p className="text-sm text-slate-500 mb-4">
          Resource / utility / area / vendor / permit constraints. Leveling is applied in a later
          phase; constraints are captured and reported now.
        </p>

        <div className="bg-white rounded-xl border border-slate-100 shadow-sm p-4 space-y-3 mb-4">
          <div className="grid grid-cols-3 gap-2">
            <select className="linp" value={cType} onChange={(e) => setCType(e.target.value)}>
              {["Resource", "Utility", "Area", "Vendor", "Permit"].map((t) => (
                <option key={t}>{t}</option>
              ))}
            </select>
            <input
              className="linp col-span-2"
              placeholder="Name (e.g. Hydrotest Pump)"
              value={cName}
              onChange={(e) => setCName(e.target.value)}
            />
          </div>
          <label className="block">
            <span className="text-xs uppercase tracking-wide text-slate-500">Capacity</span>
            <input
              type="number"
              className="linp"
              value={cCap}
              onChange={(e) => setCCap(Number(e.target.value))}
            />
          </label>
          <button
            className="bg-epc-700 hover:bg-epc-800 text-white rounded px-4 py-2 text-sm"
            onClick={async () => {
              if (!cName.trim()) return;
              await api.createConstraint(projectId, {
                constraint_type: cType,
                name: cName,
                capacity: cCap,
                available: true,
              });
              setCName("");
              reload();
            }}
          >
            Add Constraint
          </button>
        </div>

        <div className="space-y-2">
          {constraints.map((c) => (
            <div
              key={c.id}
              className="bg-white border border-slate-100 rounded-lg shadow-sm p-3 text-sm flex items-center justify-between"
            >
              <div>
                <span className="text-[10px] uppercase tracking-wide text-white bg-epc-700/80 rounded px-1.5 py-0.5 mr-2">
                  {c.constraint_type}
                </span>
                {c.name} <span className="text-slate-400">· cap {c.capacity}</span>
              </div>
              <button
                className="text-slate-300 hover:text-red-500"
                onClick={async () => {
                  await api.deleteConstraint(c.id);
                  reload();
                }}
              >
                ✕
              </button>
            </div>
          ))}
          {constraints.length === 0 && (
            <div className="text-sm text-slate-400">No constraints yet.</div>
          )}
        </div>
      </div>

      <style>{`.linp{width:100%;border:1px solid #cbd5e1;border-radius:6px;padding:7px 10px;font-size:14px;margin-top:4px}`}</style>
    </div>
  );
}
