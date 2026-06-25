import { useState } from "react";
import { api } from "../api/client";

interface Props {
  projectId: number | null;
  aiAvailable: boolean;
}

interface Msg {
  role: "user" | "assistant";
  text: string;
}

const SUGGESTIONS = [
  "Show the critical path.",
  "Which systems delay startup?",
  "Optimize the schedule to finish 5 days earlier.",
  "Generate commissioning logic for the condensate system.",
];

export default function AiAssistant({ projectId, aiAvailable }: Props) {
  const [messages, setMessages] = useState<Msg[]>([]);
  const [input, setInput] = useState("");
  const [busy, setBusy] = useState(false);

  async function send(text: string) {
    if (!text.trim() || projectId == null) return;
    setMessages((m) => [...m, { role: "user", text }]);
    setInput("");
    setBusy(true);
    try {
      const res = await api.aiChat(projectId, text);
      setMessages((m) => [...m, { role: "assistant", text: res.reply }]);
    } catch (e) {
      setMessages((m) => [...m, { role: "assistant", text: (e as Error).message }]);
    } finally {
      setBusy(false);
    }
  }

  if (projectId == null) return <div className="p-8 text-slate-500">No project selected.</div>;

  return (
    <div className="p-6 max-w-3xl flex flex-col h-full">
      <h1 className="text-xl font-semibold text-slate-800 mb-1">AI Assistant</h1>
      <p className="text-sm text-slate-500 mb-4">
        {aiAvailable
          ? "Ask about the critical path, bottlenecks and schedule optimisation."
          : "Offline — set ANTHROPIC_API_KEY to enable Claude-powered answers. The rest of the app works without it."}
      </p>

      <div className="flex-1 bg-white rounded-xl border border-slate-100 shadow-sm p-4 overflow-auto space-y-3 mb-3">
        {messages.length === 0 && (
          <div className="text-sm text-slate-400">
            <div className="mb-2">Try:</div>
            <div className="flex flex-wrap gap-2">
              {SUGGESTIONS.map((s) => (
                <button
                  key={s}
                  className="text-xs border border-slate-200 rounded-full px-3 py-1 hover:bg-slate-50"
                  onClick={() => send(s)}
                >
                  {s}
                </button>
              ))}
            </div>
          </div>
        )}
        {messages.map((m, i) => (
          <div key={i} className={`flex ${m.role === "user" ? "justify-end" : "justify-start"}`}>
            <div
              className={`max-w-[80%] rounded-lg px-3 py-2 text-sm whitespace-pre-wrap ${
                m.role === "user" ? "bg-epc-700 text-white" : "bg-slate-100 text-slate-800"
              }`}
            >
              {m.text}
            </div>
          </div>
        ))}
        {busy && <div className="text-sm text-slate-400">Thinking…</div>}
      </div>

      <div className="flex gap-2">
        <input
          className="flex-1 border border-slate-300 rounded px-3 py-2 text-sm"
          placeholder="Ask the scheduling assistant…"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && send(input)}
        />
        <button
          className="bg-epc-700 hover:bg-epc-800 text-white rounded px-4 text-sm disabled:opacity-50"
          disabled={busy}
          onClick={() => send(input)}
        >
          Send
        </button>
      </div>
    </div>
  );
}
