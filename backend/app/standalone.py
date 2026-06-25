"""Zero-dependency standalone server.

Runs the full Commissioning Scheduler Pro core using **only the Python standard
library** (``http.server`` + ``json``) — no FastAPI, SQLAlchemy, pip or npm
required. It reuses the exact engine modules used by the FastAPI app
(``application.scheduler``/``network``/``validation``/``logic_engine``) and
serves a self-contained web UI from ``app/web/index.html``.

This is the offline fallback that works on any machine with Python 3.11+:

    cd backend
    python -m app.standalone           # then open http://127.0.0.1:8000

The FastAPI app (``app.main``) remains the primary path for CI and packaging.
"""

from __future__ import annotations

import csv
import io
import json
import os
import re
import threading
from datetime import date
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

from .application.logic_engine import compile_rule
from .application.network import build_network
from .application.scheduler import compute_schedule
from .application.templates import BUILTIN_TEMPLATES
from .application.validation import validate_network
from .domain.calendar import WorkCalendar
from .domain.entities import ActivityNode, Edge
from .domain.enums import RelationType
from .infrastructure.exporters.html_exporter import export_dashboard_html

WEB_DIR = Path(__file__).resolve().parent / "web"
DATA_FILE = Path(__file__).resolve().parent.parent / "data" / "standalone.json"


# --------------------------------------------------------------------------
# In-memory store with JSON persistence
# --------------------------------------------------------------------------
class Store:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.reset_to_seed()
        self.load()

    # --- seed ---------------------------------------------------------------
    def reset_to_seed(self) -> None:
        self.project = {
            "name": "LNG Train 1 — Pre-Commissioning",
            "client": "ACME Energy",
            "location": "Ras Laffan",
            "mechanical_completion_date": "2027-01-15",
            "planned_startup_date": "2027-02-01",
            "working_weekdays": [1, 2, 3, 4, 5, 6],
            "holidays": ["2027-01-01"],
        }
        chain = [
            ("A-010", "Hydrotest", 7, "Piping"),
            ("A-020", "Dewatering", 2, "Piping"),
            ("A-030", "Drying", 5, "Piping"),
            ("A-040", "Reinstatement", 3, "Piping"),
            ("A-050", "Leak Test", 2, "Process"),
        ]
        self.activities = []
        for i, (aid, name, dur, disc) in enumerate(chain):
            self.activities.append(
                {
                    "id": i + 1,
                    "activity_id": aid,
                    "name": name,
                    "duration": dur,
                    "discipline": disc,
                    "system": "Condensate Stabilizer",
                    "status": "Not Started",
                    "pos_x": i * 260.0,
                    "pos_y": 0.0,
                }
            )
        self.relationships = [
            {"id": i + 1, "predecessor_id": i + 1, "successor_id": i + 2, "rel_type": "FS", "lag": 0}
            for i in range(len(chain) - 1)
        ]
        self.logic_rules = [
            {"id": 1, "condition": "Hydrotest Complete", "action": "Enable Dewatering"},
            {
                "id": 2,
                "condition": "Drying Complete AND Nitrogen Available",
                "action": "Enable Leak Test",
            },
        ]
        self._next = {"activity": 6, "rel": 5, "rule": 3}

    # --- persistence --------------------------------------------------------
    def load(self) -> None:
        if DATA_FILE.exists():
            try:
                data = json.loads(DATA_FILE.read_text("utf-8"))
                self.project = data["project"]
                self.activities = data["activities"]
                self.relationships = data["relationships"]
                self.logic_rules = data.get("logic_rules", [])
                self._next = data.get("_next", self._next)
            except Exception:
                pass

    def save(self) -> None:
        DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
        DATA_FILE.write_text(
            json.dumps(
                {
                    "project": self.project,
                    "activities": self.activities,
                    "relationships": self.relationships,
                    "logic_rules": self.logic_rules,
                    "_next": self._next,
                },
                indent=2,
            ),
            "utf-8",
        )

    def next_id(self, kind: str) -> int:
        v = self._next[kind]
        self._next[kind] += 1
        return v

    # --- engine glue --------------------------------------------------------
    def _calendar(self) -> WorkCalendar:
        return WorkCalendar(
            working_weekdays=set(self.project["working_weekdays"]),
            holidays={date.fromisoformat(h) for h in self.project["holidays"]},
        )

    def _domain(self) -> tuple[list[ActivityNode], list[Edge]]:
        nodes = [
            ActivityNode(
                id=str(a["id"]),
                name=a["name"],
                duration=a["duration"],
                code=a["activity_id"],
                discipline=a["discipline"],
                status=a["status"],
            )
            for a in self.activities
        ]
        edges = [
            Edge(str(r["predecessor_id"]), str(r["successor_id"]), RelationType(r["rel_type"]), r["lag"])
            for r in self.relationships
        ]
        return nodes, edges

    def compute(self) -> dict:
        nodes, edges = self._domain()
        mc = date.fromisoformat(self.project["mechanical_completion_date"])
        res = compute_schedule(nodes, edges, self._calendar(), mc)
        by = {a["id"]: a for a in self.activities}
        out = []
        for n in res.activities:
            a = by[int(n.id)]
            a["es"], a["ef"], a["ls"], a["lf"] = n.es, n.ef, n.ls, n.lf
            a["total_float"], a["is_critical"] = n.total_float, n.is_critical
            a["start_date"] = n.start_date.isoformat() if n.start_date else None
            a["finish_date"] = n.finish_date.isoformat() if n.finish_date else None
            out.append(
                {
                    "id": int(n.id),
                    "activity_id": a["activity_id"],
                    "name": n.name,
                    "duration": n.duration,
                    "es": n.es,
                    "ef": n.ef,
                    "ls": n.ls,
                    "lf": n.lf,
                    "total_float": n.total_float,
                    "is_critical": n.is_critical,
                    "start_date": a["start_date"],
                    "finish_date": a["finish_date"],
                    "status": a["status"],
                }
            )
        return {
            "activities": out,
            "critical_path": [int(x) for x in res.critical_path],
            "project_start": res.project_start.isoformat() if res.project_start else None,
            "project_finish": res.project_finish.isoformat() if res.project_finish else None,
            "warnings": res.warnings,
        }

    def network(self) -> dict:
        self.compute()  # ensure dates fresh
        nodes, edges = self._domain()
        by = {a["id"]: a for a in self.activities}
        positions = {}
        for n in nodes:
            a = by[int(n.id)]
            n.start_date = date.fromisoformat(a["start_date"]) if a.get("start_date") else None
            n.finish_date = date.fromisoformat(a["finish_date"]) if a.get("finish_date") else None
            n.total_float = a.get("total_float")
            n.is_critical = a.get("is_critical", False)
            if a.get("pos_x") is not None:
                positions[n.id] = (a["pos_x"], a["pos_y"])
        return build_network(nodes, edges, positions)

    def validate(self) -> dict:
        nodes, edges = self._domain()
        w, e = validate_network(nodes, edges)
        return {"warnings": w, "errors": e}

    def summary(self) -> dict:
        sched = self.compute()
        acts = self.activities
        total = len(acts)
        completed = sum(1 for a in acts if a["status"] == "Completed")
        in_prog = sum(1 for a in acts if a["status"] == "In Progress")
        return {
            "project": {
                "name": self.project["name"],
                "client": self.project["client"],
                "mechanical_completion_date": self.project["mechanical_completion_date"],
                "planned_startup_date": self.project["planned_startup_date"],
            },
            "total_activities": total,
            "completed": completed,
            "in_progress": in_prog,
            "pending": total - completed - in_prog,
            "critical": sum(1 for a in sched["activities"] if a["is_critical"]),
            "activities": sched["activities"],
        }


STORE = Store()


def ai_reply(message: str) -> dict:
    """Offline-graceful AI: uses Claude if key + SDK present, else a clear note."""
    key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not key:
        return {
            "reply": "AI assistant is offline. Set ANTHROPIC_API_KEY to enable Claude. "
            "All scheduling, network, Gantt and export features work without it.",
            "ai_available": False,
        }
    try:
        import anthropic
    except ImportError:
        return {"reply": "Install the `anthropic` package to enable the AI assistant.", "ai_available": False}
    try:
        client = anthropic.Anthropic(api_key=key)
        ctx = json.dumps(STORE.summary(), default=str)[:12000]
        resp = client.messages.create(
            model=os.environ.get("ANTHROPIC_MODEL", "claude-opus-4-8"),
            max_tokens=1024,
            system="You are the scheduling assistant in Commissioning Scheduler Pro. "
            "Answer concisely using the project schedule JSON.",
            messages=[{"role": "user", "content": f"{ctx}\n\nQuestion: {message}"}],
        )
        text = "".join(b.text for b in resp.content if getattr(b, "type", "") == "text")
        return {"reply": text or "(no response)", "ai_available": True}
    except Exception as exc:
        return {"reply": f"AI request failed: {exc}", "ai_available": True}


def export_csv() -> bytes:
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(["Activity ID", "Name", "Duration", "Start", "Finish", "ES", "EF", "LS", "LF", "Float", "Critical"])
    for a in STORE.compute()["activities"]:
        w.writerow(
            [a["activity_id"], a["name"], a["duration"], a["start_date"], a["finish_date"],
             a["es"], a["ef"], a["ls"], a["lf"], a["total_float"], "Yes" if a["is_critical"] else "No"]
        )
    return buf.getvalue().encode("utf-8")


# --------------------------------------------------------------------------
# HTTP handler
# --------------------------------------------------------------------------
class Handler(BaseHTTPRequestHandler):
    server_version = "CommissioningScheduler/0.1"

    def log_message(self, *args):  # quieter logs
        pass

    # --- helpers ---
    def _json(self, obj, status=200):
        body = json.dumps(obj, default=str).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _bytes(self, body: bytes, ctype: str, status=200, filename: str | None = None):
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        if filename:
            self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self) -> dict:
        n = int(self.headers.get("Content-Length", 0) or 0)
        if not n:
            return {}
        try:
            return json.loads(self.rfile.read(n).decode("utf-8"))
        except Exception:
            return {}

    # --- routing ---
    def do_GET(self):
        path = urlparse(self.path).path
        if path in ("/", "/index.html"):
            html = (WEB_DIR / "index.html").read_bytes()
            return self._bytes(html, "text/html; charset=utf-8")
        with STORE.lock:
            if path == "/api/health":
                return self._json({"status": "ok", "mode": "standalone", "ai_available": bool(os.environ.get("ANTHROPIC_API_KEY"))})
            if path == "/api/project":
                return self._json(STORE.project)
            if path == "/api/activities":
                return self._json(STORE.activities)
            if path == "/api/relationships":
                return self._json(STORE.relationships)
            if path == "/api/templates":
                return self._json(
                    [
                        {"id": i + 1, "name": t[0], "category": t[1], "default_duration": t[2],
                         "discipline": t[3], "resources": t[4], "utilities": t[5]}
                        for i, t in enumerate(BUILTIN_TEMPLATES)
                    ]
                )
            if path == "/api/logic-rules":
                return self._json(STORE.logic_rules)
            if path == "/api/schedule/compute":
                return self._json(STORE.compute())
            if path == "/api/network":
                return self._json(STORE.network())
            if path == "/api/validate":
                return self._json(STORE.validate())
            if path == "/api/summary":
                return self._json(STORE.summary())
            if path == "/api/export/html":
                return self._bytes(export_dashboard_html(STORE.summary(), STORE.compute()).encode(), "text/html; charset=utf-8")
            if path == "/api/export/csv":
                return self._bytes(export_csv(), "text/csv", filename="schedule.csv")
        return self._json({"error": "not found"}, 404)

    def do_POST(self):
        path = urlparse(self.path).path
        body = self._read_json()
        with STORE.lock:
            if path == "/api/activities":
                aid = STORE.next_id("activity")
                seq = (len(STORE.activities) + 1) * 10
                STORE.activities.append(
                    {
                        "id": aid,
                        "activity_id": body.get("activity_id") or f"A-{seq:03d}",
                        "name": body.get("name", "New Activity"),
                        "duration": int(body.get("duration", 1)),
                        "discipline": body.get("discipline", ""),
                        "system": body.get("system", ""),
                        "status": "Not Started",
                        "pos_x": float(len(STORE.activities) % 5 * 260),
                        "pos_y": float(len(STORE.activities) // 5 * 130),
                    }
                )
                STORE.save()
                return self._json({"id": aid})
            if path == "/api/relationships":
                if body.get("predecessor_id") == body.get("successor_id"):
                    return self._json({"error": "self-link"}, 400)
                rid = STORE.next_id("rel")
                STORE.relationships.append(
                    {
                        "id": rid,
                        "predecessor_id": int(body["predecessor_id"]),
                        "successor_id": int(body["successor_id"]),
                        "rel_type": body.get("rel_type", "FS"),
                        "lag": int(body.get("lag", 0)),
                    }
                )
                STORE.save()
                return self._json({"id": rid})
            if path == "/api/logic-rules":
                rid = STORE.next_id("rule")
                STORE.logic_rules.append(
                    {"id": rid, "condition": body.get("condition", ""), "action": body.get("action", ""),
                     "structured": compile_rule(body.get("condition", ""), body.get("action", ""))}
                )
                STORE.save()
                return self._json({"id": rid})
            if path == "/api/ai/chat":
                return self._json(ai_reply(body.get("message", "")))
            if path == "/api/reset":
                STORE.reset_to_seed()
                STORE.save()
                return self._json({"ok": True})
        return self._json({"error": "not found"}, 404)

    def do_PUT(self):
        path = urlparse(self.path).path
        body = self._read_json()
        m = re.match(r"/api/activities/(\d+)$", path)
        if m:
            with STORE.lock:
                a = next((x for x in STORE.activities if x["id"] == int(m.group(1))), None)
                if not a:
                    return self._json({"error": "not found"}, 404)
                for k in ("name", "duration", "discipline", "status"):
                    if k in body:
                        a[k] = int(body[k]) if k == "duration" else body[k]
                STORE.save()
                return self._json(a)
        return self._json({"error": "not found"}, 404)

    def do_PATCH(self):
        path = urlparse(self.path).path
        body = self._read_json()
        m = re.match(r"/api/activities/(\d+)/position$", path)
        if m:
            with STORE.lock:
                a = next((x for x in STORE.activities if x["id"] == int(m.group(1))), None)
                if a:
                    a["pos_x"], a["pos_y"] = float(body.get("x", 0)), float(body.get("y", 0))
                    STORE.save()
                    return self._json(a)
        return self._json({"error": "not found"}, 404)

    def do_DELETE(self):
        path = urlparse(self.path).path
        with STORE.lock:
            m = re.match(r"/api/activities/(\d+)$", path)
            if m:
                aid = int(m.group(1))
                STORE.activities = [a for a in STORE.activities if a["id"] != aid]
                STORE.relationships = [
                    r for r in STORE.relationships if aid not in (r["predecessor_id"], r["successor_id"])
                ]
                STORE.save()
                return self._json({"ok": True})
            m = re.match(r"/api/relationships/(\d+)$", path)
            if m:
                rid = int(m.group(1))
                STORE.relationships = [r for r in STORE.relationships if r["id"] != rid]
                STORE.save()
                return self._json({"ok": True})
            m = re.match(r"/api/logic-rules/(\d+)$", path)
            if m:
                rid = int(m.group(1))
                STORE.logic_rules = [r for r in STORE.logic_rules if r["id"] != rid]
                STORE.save()
                return self._json({"ok": True})
        return self._json({"error": "not found"}, 404)


def main() -> None:
    port = int(os.environ.get("PORT", "8000"))
    httpd = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"Commissioning Scheduler Pro (standalone) → http://127.0.0.1:{port}")
    print("Zero-dependency mode: Python standard library only. Ctrl+C to stop.")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
