import { useEffect, useState } from "react";
import { api } from "../api/client";
import type { Template } from "../types";

const empty = { name: "", category: "", default_duration: 1, discipline: "", resources: "", utilities: "" };

export default function TemplateLibrary() {
  const [templates, setTemplates] = useState<Template[]>([]);
  const [form, setForm] = useState({ ...empty });

  const reload = () => api.listTemplates().then(setTemplates);
  useEffect(() => {
    reload();
  }, []);

  const grouped = templates.reduce<Record<string, Template[]>>((acc, t) => {
    const k = t.category || "Other";
    (acc[k] ??= []).push(t);
    return acc;
  }, {});

  return (
    <div className="p-6">
      <h1 className="text-xl font-semibold text-slate-800 mb-1">Activity Template Library</h1>
      <p className="text-sm text-slate-500 mb-4">
        Reusable pre-commissioning & commissioning activities. Built-in templates are read-only;
        add your own below.
      </p>

      <div className="grid grid-cols-3 gap-6">
        <div className="col-span-2 space-y-5">
          {Object.entries(grouped).map(([cat, items]) => (
            <div key={cat}>
              <h2 className="text-xs uppercase tracking-wide text-slate-400 mb-2">{cat}</h2>
              <div className="grid grid-cols-2 gap-3">
                {items.map((t) => (
                  <div
                    key={t.id}
                    className="bg-white border border-slate-100 rounded-lg shadow-sm p-3 text-sm"
                  >
                    <div className="flex items-center justify-between">
                      <span className="font-semibold text-slate-700">{t.name}</span>
                      <span className="text-xs text-epc-700 bg-epc-100 rounded px-2 py-0.5">
                        {t.default_duration}d
                      </span>
                    </div>
                    <div className="text-xs text-slate-500 mt-1">{t.discipline}</div>
                    {t.utilities && (
                      <div className="text-xs text-slate-400 mt-1">Utilities: {t.utilities}</div>
                    )}
                    {!t.is_builtin && (
                      <button
                        className="text-xs text-red-500 mt-2"
                        onClick={async () => {
                          await api.deleteTemplate(t.id);
                          reload();
                        }}
                      >
                        Delete
                      </button>
                    )}
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>

        <div className="bg-white border border-slate-100 rounded-lg shadow-sm p-4 h-fit">
          <h2 className="text-sm font-semibold text-slate-700 mb-3">New Template</h2>
          <div className="space-y-2 text-sm">
            <input
              className="tinp"
              placeholder="Name"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
            />
            <input
              className="tinp"
              placeholder="Category"
              value={form.category}
              onChange={(e) => setForm({ ...form, category: e.target.value })}
            />
            <input
              className="tinp"
              type="number"
              min={1}
              placeholder="Duration (days)"
              value={form.default_duration}
              onChange={(e) => setForm({ ...form, default_duration: Number(e.target.value) })}
            />
            <input
              className="tinp"
              placeholder="Discipline"
              value={form.discipline}
              onChange={(e) => setForm({ ...form, discipline: e.target.value })}
            />
            <input
              className="tinp"
              placeholder="Utilities"
              value={form.utilities}
              onChange={(e) => setForm({ ...form, utilities: e.target.value })}
            />
            <button
              className="w-full bg-epc-700 hover:bg-epc-800 text-white rounded py-2"
              onClick={async () => {
                if (!form.name.trim()) return;
                await api.createTemplate(form);
                setForm({ ...empty });
                reload();
              }}
            >
              Add Template
            </button>
          </div>
        </div>
      </div>
      <style>{`.tinp{width:100%;border:1px solid #cbd5e1;border-radius:6px;padding:6px 9px;font-size:13px}`}</style>
    </div>
  );
}
