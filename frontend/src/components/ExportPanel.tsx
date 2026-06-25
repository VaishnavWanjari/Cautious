import { useEffect, useState } from "react";
import { api } from "../api/client";

interface Props {
  projectId: number | null;
}

const EXPORTS: { kind: "xlsx" | "pdf" | "html"; title: string; desc: string; icon: string }[] = [
  { kind: "xlsx", title: "Excel (.xlsx)", desc: "Full schedule with ES/EF/LS/LF, float and critical flags.", icon: "▤" },
  { kind: "pdf", title: "PDF Report", desc: "Print-ready landscape schedule report.", icon: "▣" },
  { kind: "html", title: "HTML Dashboard", desc: "Self-contained commissioning readiness report.", icon: "◫" },
];

export default function ExportPanel({ projectId }: Props) {
  const [urls, setUrls] = useState<Record<string, string>>({});

  useEffect(() => {
    if (projectId == null) return;
    Promise.all(
      EXPORTS.map(async (e) => [e.kind, await api.exportUrl(projectId, e.kind)] as const)
    ).then((pairs) => setUrls(Object.fromEntries(pairs)));
  }, [projectId]);

  if (projectId == null) return <div className="p-8 text-slate-500">No project selected.</div>;

  return (
    <div className="p-6">
      <h1 className="text-xl font-semibold text-slate-800 mb-1">Exports & Reports</h1>
      <p className="text-sm text-slate-500 mb-5">
        Generate professional deliverables from the current schedule. Files are produced offline by
        the local backend.
      </p>

      <div className="grid grid-cols-3 gap-4 max-w-3xl">
        {EXPORTS.map((e) => (
          <a
            key={e.kind}
            href={urls[e.kind]}
            target="_blank"
            rel="noreferrer"
            className="bg-white border border-slate-100 rounded-xl shadow-sm p-5 hover:shadow-md transition block"
          >
            <div className="text-3xl text-epc-700">{e.icon}</div>
            <div className="font-semibold text-slate-700 mt-2">{e.title}</div>
            <div className="text-xs text-slate-500 mt-1">{e.desc}</div>
            <div className="text-xs text-epc-700 mt-3 underline">Download →</div>
          </a>
        ))}
      </div>

      <div className="mt-6 text-xs text-slate-400 max-w-3xl">
        Roadmap (Phase 2): Primavera XML / XER export, PNG/SVG network snapshots, and the Saudi
        Aramco turnover (RFC/RFSU/punch) report pack.
      </div>
    </div>
  );
}
