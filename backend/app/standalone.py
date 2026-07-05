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
import sys
import threading
from datetime import date, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from .application.graph import DiGraph
from .application.logic_engine import compile_rule
from .application.network import build_network
from .application.scheduler import compute_schedule
from .application.templates import BUILTIN_TEMPLATES
from .application.validation import validate_network
from .domain.calendar import WorkCalendar
from .domain.entities import ActivityNode, Edge
from .domain.enums import RelationType
from .infrastructure.exporters.html_exporter import export_dashboard_html

# When frozen into a single-file executable (PyInstaller), data files are
# extracted to a temporary read-only directory (``sys._MEIPASS``) rather than
# living next to this source file, and that directory disappears when the exe
# exits — so persistence must live next to the exe itself instead.
if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
    WEB_DIR = Path(sys._MEIPASS) / "app" / "web"  # type: ignore[attr-defined]
    DATA_FILE = Path(sys.executable).resolve().parent / "data" / "standalone.json"
else:
    WEB_DIR = Path(__file__).resolve().parent / "web"
    DATA_FILE = Path(__file__).resolve().parent.parent / "data" / "standalone.json"


# --------------------------------------------------------------------------
# In-memory store with JSON persistence
# --------------------------------------------------------------------------
class Store:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.reset_to_blank()
        self.load()

    # --- blank ----------------------------------------------------------------
    def reset_to_blank(self) -> None:
        """The true default: no PMCCs, no circuits, no activities.

        Data only ever enters the app via CSV import (or, optionally, the
        "Load Sample Data" action which calls ``reset_to_seed`` below). This
        exists because auto-loading a hardcoded dataset on every fresh start
        was the actual bug behind "my data keeps getting wiped" — see the
        fixed ``load()`` below for the other half of that fix.
        """
        self.project = {
            "name": "New Commissioning Project",
            "subtitle": "Pre-Commissioning Tracker & Visualizer",
            "client": "",
            "location": "",
            # Placeholder so the engine has something to compute against before
            # you set your own in Project Setup (Data tab) or via the CSV.
            "mechanical_completion_date": (date.today() + timedelta(days=180)).isoformat(),
            "planned_startup_date": "",
            "working_weekdays": [1, 2, 3, 4, 5, 6, 7],  # 7-day week default
            "holidays": [],
        }
        self.pmcc_finish: dict[str, str] = {}
        self.manual_start: dict[int, str] = {}
        if not hasattr(self, "settings"):
            self.settings: dict[str, str] = {"anthropic_api_key": ""}
        self.pmccs: list[dict] = []
        self.subsystems: list[dict] = []
        self.activities: list[dict] = []
        self.relationships: list[dict] = []
        self.logic_rules: list[dict] = []
        # Resource & rental planning (consumables, tools & tackles, equipment).
        self.resources: list[dict] = []  # master catalogue
        self.resource_assignments: list[dict] = []  # catalogue item -> PMCC/activity
        self._next = {
            "activity": 1, "rel": 1, "rule": 1, "resource": 1, "assignment": 1,
        }

    # --- seed (optional "Load Sample Data" action, never automatic) ----------
    def reset_to_seed(self) -> None:
        from . import seed_data as sd

        self.project = {
            "name": "GPT-3/4 Gas Processing Train",
            "subtitle": "Pre-Commissioning Tracker & Visualizer",
            "client": "Gas Processing Plant",
            "location": "GPT-3/4",
            # Default Mechanical Completion date — this is each PMCC's own last
            # date unless the user drags that PMCC's bar to its own target.
            "mechanical_completion_date": "2027-04-26",
            "planned_startup_date": "2027-05-26",
            "working_weekdays": [1, 2, 3, 4, 5, 6],
            "holidays": [],
        }
        # Per-PMCC finish-date override (drag the whole PMCC bar) — keyed by PMCC no.
        # Absent = use the project's mechanical_completion_date as that PMCC's anchor.
        self.pmcc_finish: dict[str, str] = {}
        # Per-activity manual start override (drag a single activity) — keyed by id.
        self.manual_start: dict[int, str] = {}
        # User-entered settings (e.g. the Claude API key, set from the AI tab
        # rather than an environment variable so the desktop app is self-serve).
        self.settings: dict[str, str] = {"anthropic_api_key": ""}
        self.pmccs = [
            {
                "seq": seq,
                "category": cat,
                "no": no,
                "description": desc,
                "system_count": sysn,
                "subsystem_count": subn,
                "priority": seq,  # sample data has no explicit ranking; use handover seq
                "depends_on": [],
            }
            for (seq, cat, no, desc, sysn, subn) in sd.PMCCS
        ]
        self.subsystems = []
        self.activities = []
        self.relationships = []
        aid = 1
        rid = 1
        sub_index = 0
        for (code, desc, prio, special, pmcc_no) in sd.CIRCUITS:
            sub_index += 1
            self.subsystems.append(
                {
                    "id": sub_index,
                    "code": code,
                    "description": desc,
                    "priority": prio,
                    "special": special,
                    "pmcc_no": pmcc_no,
                    "depends_on": [],
                }
            )
            activities, edges = sd.build_circuit(code, desc, special)
            local_ids: list[int] = []
            for seq, (name, dur, disc) in enumerate(activities):
                self.activities.append(
                    {
                        "id": aid,
                        "activity_id": f"{code}/{seq + 1:02d}",
                        "name": name,
                        "duration": dur,
                        "discipline": disc,
                        "circuit": code,
                        "circuit_desc": desc,
                        "pmcc_no": pmcc_no,
                        "priority": prio,
                        "status": "Not Started",
                        "pos_x": None,
                        "pos_y": None,
                    }
                )
                local_ids.append(aid)
                aid += 1
            for pi, si, lag in edges:
                self.relationships.append(
                    {
                        "id": rid,
                        "predecessor_id": local_ids[pi],
                        "successor_id": local_ids[si],
                        "rel_type": "FS",
                        "lag": lag,
                    }
                )
                rid += 1

        # Building PMCCs (01-05): a single handover block each, no precom circuits.
        for pmcc_no, dur in sd.BUILDING_DURATIONS.items():
            sub_index += 1
            self.subsystems.append(
                {
                    "id": sub_index,
                    "code": pmcc_no,
                    "description": "Building Pre-Commissioning & Handover",
                    "priority": "A-1",
                    "special": "",
                    "pmcc_no": pmcc_no,
                    "depends_on": [],
                }
            )
            self.activities.append(
                {
                    "id": aid,
                    "activity_id": f"{pmcc_no}/HANDOVER",
                    "name": "Building Pre-Commissioning & Handover",
                    "duration": dur,
                    "discipline": "Building",
                    "circuit": pmcc_no,
                    "circuit_desc": "Building Pre-Commissioning & Handover",
                    "pmcc_no": pmcc_no,
                    "priority": "A-1",
                    "status": "Not Started",
                    "pos_x": None,
                    "pos_y": None,
                }
            )
            aid += 1
        self.logic_rules = [
            {"id": 1, "condition": "Hydrotest Complete", "action": "Enable Reinstatement"},
            {"id": 2, "condition": "Leak Test Complete AND Nitrogen Available", "action": "Enable Inertization"},
            {"id": 3, "condition": "Loop Check Complete", "action": "Enable Punch Point Liquidation"},
        ]
        # Resource & rental catalogue + PMCC-scoped assignments.
        self.resources = []
        self.resource_assignments = []
        code_to_id: dict[str, int] = {}
        for i, (cat, name, code, unit, own, rate, cur, sup, notes) in enumerate(
            sd.RESOURCES, start=1
        ):
            code_to_id[code] = i
            self.resources.append(
                {
                    "id": i, "category": cat, "name": name, "code": code,
                    "unit": unit, "ownership": own, "rate": rate,
                    "currency": cur, "supplier": sup, "notes": notes,
                }
            )
        for j, (rcode, pmcc_no, qty) in enumerate(sd.RESOURCE_ASSIGNMENTS, start=1):
            self.resource_assignments.append(
                {
                    "id": j, "resource_id": code_to_id[rcode], "scope": "PMCC",
                    "pmcc_no": pmcc_no, "activity_id": None, "quantity": qty,
                    "start_date": "", "finish_date": "",
                }
            )
        self._next = {
            "activity": aid, "rel": rid, "rule": 4,
            "resource": len(self.resources) + 1,
            "assignment": len(self.resource_assignments) + 1,
        }

    # --- persistence --------------------------------------------------------
    def load(self) -> None:
        """Restore the saved project, if any.

        This used to bail out (keeping the hardcoded seed) whenever the saved
        project's *name* no longer matched the seed's name exactly — which
        meant simply renaming your project to your own plant's name, then
        restarting the app, silently discarded your data. There is no reason
        to gate loading on the project name at all: the file is either valid
        project data or it isn't, and that's judged by its shape, not its
        title.
        """
        if not DATA_FILE.exists():
            return
        try:
            data = json.loads(DATA_FILE.read_text("utf-8"))
        except Exception:
            return  # corrupt file — keep the blank in-memory state, don't crash
        if "activities" not in data or "relationships" not in data:
            return  # not a recognizable project file — leave the blank state alone
        self.project = data.get("project", self.project)
        self.pmccs = data.get("pmccs", self.pmccs)
        self.subsystems = data.get("subsystems", self.subsystems)
        self.activities = data["activities"]
        self.relationships = data["relationships"]
        self.logic_rules = data.get("logic_rules", [])
        self.resources = data.get("resources", [])
        self.resource_assignments = data.get("resource_assignments", [])
        self.pmcc_finish = data.get("pmcc_finish", {})
        self.manual_start = {int(k): v for k, v in data.get("manual_start", {}).items()}
        self.settings = data.get("settings", self.settings)
        # Merge saved id counters over the defaults so a file written before the
        # resource module existed still gets the new counters.
        self._next = {**self._next, **data.get("_next", {})}

    def save(self) -> None:
        DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
        DATA_FILE.write_text(
            json.dumps(
                {
                    "project": self.project,
                    "pmccs": self.pmccs,
                    "subsystems": self.subsystems,
                    "activities": self.activities,
                    "relationships": self.relationships,
                    "logic_rules": self.logic_rules,
                    "resources": self.resources,
                    "resource_assignments": self.resource_assignments,
                    "pmcc_finish": self.pmcc_finish,
                    "manual_start": self.manual_start,
                    "settings": self.settings,
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

    # --- CSV template import / export ----------------------------------------
    CSV_COLUMNS = [
        "pmcc_no", "pmcc_category", "pmcc_description", "pmcc_priority",
        "mechanical_completion_date", "circuit_code", "circuit_description",
        "priority", "special_activity", "building_duration_days", "depends_on",
    ]

    def template_csv(self) -> str:
        """A blank CSV with headers + a few clearly-marked example rows."""
        buf = io.StringIO()
        w = csv.DictWriter(buf, fieldnames=self.CSV_COLUMNS)
        w.writeheader()
        w.writerows(
            [
                {
                    "pmcc_no": "PMCC-01", "pmcc_category": "Non-Process",
                    "pmcc_description": "EXAMPLE - delete this row (building block, no circuit_code)",
                    "pmcc_priority": "1", "mechanical_completion_date": "",
                    "circuit_code": "", "circuit_description": "", "priority": "",
                    "special_activity": "", "building_duration_days": "45", "depends_on": "",
                },
                {
                    "pmcc_no": "PMCC-07", "pmcc_category": "Utility",
                    "pmcc_description": "EXAMPLE - delete this row (a utility feeding other PMCCs)",
                    "pmcc_priority": "2", "mechanical_completion_date": "",
                    "circuit_code": "866-XXX-001", "circuit_description": "Suction line to compressor inlet",
                    "priority": "A", "special_activity": "Chemical Cleaning",
                    "building_duration_days": "", "depends_on": "",
                },
                {
                    "pmcc_no": "PMCC-13", "pmcc_category": "Process",
                    "pmcc_description": "EXAMPLE - delete this row (depends on PMCC-07; use ; for more than one)",
                    "pmcc_priority": "3", "mechanical_completion_date": "",
                    "circuit_code": "866-XXX-002", "circuit_description": "Feed line to separator",
                    "priority": "A", "special_activity": "",
                    "building_duration_days": "", "depends_on": "PMCC-07",
                },
            ]
        )
        return buf.getvalue()

    def export_to_csv(self) -> str:
        """Round-trip export of the current project in the same template shape.

        Re-importing this rebuilds each circuit's activities fresh from
        ``seed_data.build_circuit()`` — it preserves your PMCCs, circuits,
        priorities and dependencies exactly, but not one-off per-activity
        duration tweaks made by dragging in the Timeline (those live at the
        activity level, below what this template describes).
        """
        buf = io.StringIO()
        w = csv.DictWriter(buf, fieldnames=self.CSV_COLUMNS)
        w.writeheader()
        pmcc_by_no = {p["no"]: p for p in self.pmccs}
        acts_by_circuit: dict[str, list[dict]] = {}
        for a in self.activities:
            acts_by_circuit.setdefault(a["circuit"], []).append(a)
        for s in self.subsystems:
            p = pmcc_by_no.get(s["pmcc_no"], {})
            acts = acts_by_circuit.get(s["code"], [])
            is_building = len(acts) == 1 and acts[0]["name"] == "Building Pre-Commissioning & Handover"
            w.writerow(
                {
                    "pmcc_no": s["pmcc_no"],
                    "pmcc_category": p.get("category", ""),
                    "pmcc_description": p.get("description", ""),
                    "pmcc_priority": p.get("priority", ""),
                    "mechanical_completion_date": self.pmcc_finish.get(s["pmcc_no"], ""),
                    "circuit_code": "" if is_building else s["code"],
                    "circuit_description": "" if is_building else s["description"],
                    "priority": s.get("priority", ""),
                    "special_activity": s.get("special", ""),
                    "building_duration_days": acts[0]["duration"] if is_building and acts else "",
                    "depends_on": ";".join(s.get("depends_on") or []),
                }
            )
        return buf.getvalue()

    def import_from_csv(self, text: str) -> dict:
        """Parse an uploaded CSV and, if it has at least one usable row,
        replace the current project with what it describes. Never touches
        existing data if the file is empty/unusable. Returns a summary with
        row-level errors/warnings so bad rows are visible, not silent.
        """
        from . import seed_data as sd

        reader = csv.DictReader(io.StringIO(text))
        if not reader.fieldnames or "pmcc_no" not in reader.fieldnames:
            return {
                "ok": False,
                "errors": ["CSV is missing the required 'pmcc_no' column (or the file is empty)."],
                "warnings": [], "pmccs": 0, "circuits": 0, "buildings": 0, "activities": 0,
            }

        errors: list[str] = []
        warnings: list[str] = []
        pmcc_order: list[str] = []
        pmcc_meta: dict[str, dict] = {}
        circuit_rows: list[dict] = []
        seen_codes: set[str] = set()

        for i, row in enumerate(reader, start=2):  # row 1 is the header
            pmcc_no = (row.get("pmcc_no") or "").strip()
            if not pmcc_no:
                errors.append(f"Row {i}: missing pmcc_no — row skipped.")
                continue
            if pmcc_no not in pmcc_meta:
                pmcc_order.append(pmcc_no)
                pmcc_meta[pmcc_no] = {
                    "category": (row.get("pmcc_category") or "").strip() or "General",
                    "description": (row.get("pmcc_description") or "").strip() or pmcc_no,
                    "priority": None,
                    "mc_date": None,
                }
            meta = pmcc_meta[pmcc_no]

            pr = (row.get("pmcc_priority") or "").strip()
            if pr and meta["priority"] is None:
                try:
                    meta["priority"] = int(pr)
                except ValueError:
                    warnings.append(f"Row {i}: pmcc_priority '{pr}' is not a whole number — ignored.")

            mc = (row.get("mechanical_completion_date") or "").strip()
            if mc and meta["mc_date"] is None:
                try:
                    date.fromisoformat(mc)
                    meta["mc_date"] = mc
                except ValueError:
                    warnings.append(f"Row {i}: mechanical_completion_date '{mc}' is not YYYY-MM-DD — ignored.")

            depends_raw = (row.get("depends_on") or "").strip()
            row_depends = [d.strip() for d in depends_raw.split(";") if d.strip()]

            circuit_code = (row.get("circuit_code") or "").strip()
            circuit_desc = (row.get("circuit_description") or "").strip()
            priority = (row.get("priority") or "").strip() or "B"
            special = (row.get("special_activity") or "").strip()

            if circuit_code:
                if not circuit_desc:
                    errors.append(
                        f"Row {i}: circuit_code '{circuit_code}' given without a circuit_description — row skipped."
                    )
                    continue
                if circuit_code in seen_codes:
                    warnings.append(f"Row {i}: duplicate circuit_code '{circuit_code}' — row skipped.")
                    continue
                seen_codes.add(circuit_code)
                circuit_rows.append(
                    {
                        "kind": "circuit", "row": i, "pmcc_no": pmcc_no, "code": circuit_code,
                        "desc": circuit_desc, "priority": priority, "special": special,
                        "depends_on": row_depends,
                    }
                )
            else:
                dur_raw = (row.get("building_duration_days") or "").strip()
                try:
                    dur = int(dur_raw) if dur_raw else 30
                except ValueError:
                    warnings.append(f"Row {i}: building_duration_days '{dur_raw}' invalid — defaulted to 30.")
                    dur = 30
                code = pmcc_no
                if code in seen_codes:
                    warnings.append(f"Row {i}: duplicate building block for '{pmcc_no}' — row skipped.")
                    continue
                seen_codes.add(code)
                circuit_rows.append(
                    {
                        "kind": "building", "row": i, "pmcc_no": pmcc_no, "code": code,
                        "desc": "Building Pre-Commissioning & Handover", "priority": priority,
                        "duration": dur, "depends_on": row_depends,
                    }
                )

        if not pmcc_meta:
            return {
                "ok": False,
                "errors": errors or ["No usable rows found in the uploaded file."],
                "warnings": warnings, "pmccs": 0, "circuits": 0, "buildings": 0, "activities": 0,
            }

        # fill in any missing priorities sequentially, in first-seen order,
        # continuing after the highest explicit rank given (ties are allowed)
        used_ranks = [m["priority"] for m in pmcc_meta.values() if m["priority"] is not None]
        next_rank = (max(used_ranks) + 1) if used_ranks else 1
        for no in pmcc_order:
            if pmcc_meta[no]["priority"] is None:
                pmcc_meta[no]["priority"] = next_rank
                next_rank += 1

        # duplicate priority ranks are allowed — just flagged as a tie, not blocked
        rank_holders: dict[int, list[str]] = {}
        for no in pmcc_order:
            rank_holders.setdefault(pmcc_meta[no]["priority"], []).append(no)
        for rank, holders in rank_holders.items():
            if len(holders) > 1:
                warnings.append(
                    f"Priority {rank} is shared by {', '.join(holders)} — treated as a tie, not blocked."
                )

        # validate depends_on tokens refer to something real (a known pmcc_no or circuit_code)
        known_codes = seen_codes
        known_pmccs = set(pmcc_order)
        for r in circuit_rows:
            valid = []
            for token in r["depends_on"]:
                if token in known_pmccs or token in known_codes:
                    valid.append(token)
                else:
                    warnings.append(
                        f"Row {r['row']}: depends_on '{token}' doesn't match any pmcc_no or circuit_code "
                        "in this file — dependency dropped."
                    )
            r["depends_on"] = valid

        # --- commit: replace current project -------------------------------
        self.pmccs = []
        self.subsystems = []
        self.activities = []
        self.relationships = []
        self.logic_rules = []
        self.pmcc_finish = {}
        self.manual_start = {}
        aid, rid, sub_index = 1, 1, 0
        circuit_owner: dict[str, str] = {r["code"]: r["pmcc_no"] for r in circuit_rows}
        circuit_first_id: dict[str, int] = {}
        circuit_last_id: dict[str, int] = {}

        for seq, no in enumerate(pmcc_order, start=1):
            meta = pmcc_meta[no]
            self.pmccs.append(
                {
                    "seq": seq, "category": meta["category"], "no": no, "description": meta["description"],
                    "system_count": 1,
                    "subsystem_count": sum(1 for r in circuit_rows if r["pmcc_no"] == no),
                    "priority": meta["priority"], "depends_on": [],
                }
            )
            if meta["mc_date"]:
                self.pmcc_finish[no] = meta["mc_date"]

        for r in circuit_rows:
            sub_index += 1
            self.subsystems.append(
                {
                    "id": sub_index, "code": r["code"], "description": r["desc"],
                    "priority": r["priority"], "special": r.get("special", ""),
                    "pmcc_no": r["pmcc_no"], "depends_on": r["depends_on"],
                }
            )
            if r["kind"] == "circuit":
                activities, edges = sd.build_circuit(r["code"], r["desc"], r["special"])
            else:
                activities, edges = [("Building Pre-Commissioning & Handover", r["duration"], "Building")], []
            local_ids: list[int] = []
            for seqn, (name, dur, disc) in enumerate(activities):
                self.activities.append(
                    {
                        "id": aid, "activity_id": f"{r['code']}/{seqn + 1:02d}", "name": name,
                        "duration": dur, "discipline": disc, "circuit": r["code"], "circuit_desc": r["desc"],
                        "pmcc_no": r["pmcc_no"], "priority": r["priority"], "status": "Not Started",
                        "pos_x": None, "pos_y": None,
                    }
                )
                local_ids.append(aid)
                aid += 1
            for pi, si, lag in edges:
                self.relationships.append(
                    {"id": rid, "predecessor_id": local_ids[pi], "successor_id": local_ids[si], "rel_type": "FS", "lag": lag}
                )
                rid += 1
            if local_ids:
                circuit_first_id[r["code"]] = local_ids[0]
                circuit_last_id[r["code"]] = local_ids[-1]

        # Same-PMCC circuit-to-circuit dependencies become real precedence
        # edges (last activity of upstream circuit -> first activity of
        # downstream circuit), so the CPM run already respects them exactly.
        # Cross-PMCC dependencies (a different pmcc_no, or a circuit owned by
        # a different pmcc_no) can't be folded into one CPM run since each
        # PMCC keeps its own independent anchor date — those are enforced as
        # a real floor constraint across PMCCs in ``compute()`` instead.
        pmcc_depends: dict[str, set[str]] = {no: set() for no in pmcc_order}
        for r in circuit_rows:
            for tok in r["depends_on"]:
                owner = circuit_owner.get(tok) if tok in circuit_owner else (tok if tok in pmcc_meta else None)
                if owner is None or owner == r["pmcc_no"]:
                    if tok in circuit_first_id and circuit_owner.get(tok) == r["pmcc_no"] and r["code"] in circuit_first_id:
                        self.relationships.append(
                            {
                                "id": rid, "predecessor_id": circuit_last_id[tok],
                                "successor_id": circuit_first_id[r["code"]], "rel_type": "FS", "lag": 0,
                            }
                        )
                        rid += 1
                    continue
                pmcc_depends[r["pmcc_no"]].add(owner)

        for p in self.pmccs:
            p["depends_on"] = sorted(pmcc_depends.get(p["no"], set()))

        # Priority and depends_on are independent inputs and are allowed to
        # coexist even when they conflict (e.g. a PMCC ranked to finish early
        # depends on a PMCC ranked to finish later) — surfaced as a warning,
        # never blocked or auto-corrected.
        priority_of = {p["no"]: p["priority"] for p in self.pmccs}
        for p in self.pmccs:
            for dep in p["depends_on"]:
                if priority_of.get(dep, 0) > priority_of[p["no"]]:
                    warnings.append(
                        f"{p['no']} (priority {priority_of[p['no']]}) depends on {dep} "
                        f"(priority {priority_of[dep]}), which is scheduled to finish later — "
                        "priority and dependency targets conflict."
                    )

        self._next = {"activity": aid, "rel": rid, "rule": 1}
        self.save()

        return {
            "ok": True,
            "pmccs": len(self.pmccs),
            "circuits": sum(1 for r in circuit_rows if r["kind"] == "circuit"),
            "buildings": sum(1 for r in circuit_rows if r["kind"] == "building"),
            "activities": len(self.activities),
            "errors": errors,
            "warnings": warnings,
        }

    # --- engine glue --------------------------------------------------------
    def _calendar(self) -> WorkCalendar:
        return WorkCalendar(
            working_weekdays=set(self.project["working_weekdays"]),
            holidays={date.fromisoformat(h) for h in self.project["holidays"]},
        )

    def _domain(self, pmcc: str | None = None) -> tuple[list[ActivityNode], list[Edge]]:
        acts = self.activities
        if pmcc:
            acts = [a for a in acts if a.get("pmcc_no") == pmcc]
        ids = {a["id"] for a in acts}
        nodes = [
            ActivityNode(
                id=str(a["id"]),
                name=a["name"],
                duration=a["duration"],
                code=a["activity_id"],
                discipline=a["discipline"],
                status=a["status"],
            )
            for a in acts
        ]
        edges = [
            Edge(str(r["predecessor_id"]), str(r["successor_id"]), RelationType(r["rel_type"]), r["lag"])
            for r in self.relationships
            if r["predecessor_id"] in ids and r["successor_id"] in ids
        ]
        return nodes, edges

    def _pmcc_anchor(self, pmcc_no: str) -> date:
        """Each PMCC's own last date: its drag override, else a priority-
        staggered default counting back from the project MC date — rank 1
        (highest priority) finishes earliest, 10 working days apart per rank,
        with the lowest-priority (highest-numbered) PMCC landing exactly on
        the project MC date.
        """
        override = self.pmcc_finish.get(pmcc_no)
        mc = date.fromisoformat(self.project["mechanical_completion_date"])
        if override:
            return date.fromisoformat(override)
        p = next((p for p in self.pmccs if p["no"] == pmcc_no), None)
        if not p or not self.pmccs:
            return mc
        n = len(self.pmccs)
        priority = p.get("priority") or n
        offset_days = (n - priority) * 10
        if offset_days <= 0:
            return mc
        return self._calendar().add_working_days(mc, -offset_days)

    def _apply_manual_overrides(
        self,
        acts: list[dict],
        rels: list[dict],
        calendar: WorkCalendar,
        extra_floor: dict[int, date] | None = None,
    ) -> bool:
        """Overlay per-activity drag pins on top of the natural CPM dates.

        Walks the circuit's activities in topological order; a pinned activity's
        start is forced to its manual date, and every activity's start is then
        floored at whatever its predecessors' (already-resolved) finish + lag
        requires — so dragging one activity later pushes its dependents with it,
        while dragging earlier is only honoured as far as the logic network
        allows. Un-pinned activities with no manual override keep their natural
        CPM date unless a pinned ancestor pushes them out.

        ``extra_floor`` additionally seeds a hard earliest-start floor per
        activity id (used for cross-PMCC dependency constraints) that is
        merged in the same way as a predecessor's floor. Returns True if any
        activity's start date was pushed later than its natural CPM date by
        one of these floors.
        """
        shifted = False
        g = DiGraph()
        by_id = {a["id"]: a for a in acts}
        for a in acts:
            g.add_node(a["id"])
        for r in rels:
            if r["predecessor_id"] in by_id and r["successor_id"] in by_id:
                g.add_edge(r["predecessor_id"], r["successor_id"], rel=r)
        try:
            order = g.topological_sort()
        except ValueError:
            return False  # cyclic — leave the natural CPM dates in place

        for nid in order:
            a = by_id[nid]
            if not a.get("start_date"):
                continue
            pin = self.manual_start.get(nid)
            candidate = date.fromisoformat(pin) if pin else date.fromisoformat(a["start_date"])

            floor: date | None = None
            for pred_id in g.predecessors(nid):
                pred = by_id.get(pred_id)
                if not pred or not pred.get("start_date"):
                    continue
                rel = g.edge_attr(pred_id, nid)["rel"]
                lag = rel.get("lag", 0)
                rtype = rel.get("rel_type", "FS")
                p_start = date.fromisoformat(pred["start_date"])
                p_finish = date.fromisoformat(pred["finish_date"])
                if rtype == "SS":
                    req = calendar.add_working_days(p_start, lag)
                elif rtype == "FF":
                    req = calendar.start_of(calendar.add_working_days(p_finish, lag), a["duration"])
                elif rtype == "SF":
                    req = calendar.start_of(calendar.add_working_days(p_start, lag), a["duration"])
                else:  # FS
                    req = calendar.add_working_days(p_finish, 1 + lag)
                floor = req if floor is None else max(floor, req)

            if extra_floor and nid in extra_floor:
                floor = extra_floor[nid] if floor is None else max(floor, extra_floor[nid])

            effective = candidate if floor is None else max(candidate, floor)
            effective = calendar.next_working_day(effective)
            if effective > date.fromisoformat(a["start_date"]):
                shifted = True
            a["start_date"] = effective.isoformat()
            a["finish_date"] = calendar.finish_of(effective, a["duration"]).isoformat()
            a["is_manual"] = nid in self.manual_start
        return shifted

    def compute(self) -> dict:
        """Run backward CPM **per PMCC**, each anchored at its own last date.

        PMCCs are independent handover packages (circuits never cross a PMCC
        boundary), so grouping the CPM run this way lets every PMCC carry its
        own Mechanical Completion date — dragging one PMCC's bar only moves
        that PMCC. Manual per-activity drags are then layered on top.

        Cross-PMCC ``depends_on`` links (e.g. a utility PMCC feeding several
        process PMCCs) are real scheduling constraints, not just visual: PMCCs
        are processed in dependency order, and a downstream circuit's entry
        activity is floored at its upstream dependency's actual finish date +
        1 working day. If that floor pushes a PMCC's finish past its own
        priority-staggered/target date, a warning is raised (the shift is
        still applied — never silently blocked or clamped).
        """
        calendar = self._calendar()
        by_pmcc: dict[str, list[dict]] = {}
        for a in self.activities:
            by_pmcc.setdefault(a["pmcc_no"], []).append(a)

        circuit_pmcc = {s["code"]: s["pmcc_no"] for s in self.subsystems}
        circuit_depends = {s["code"]: (s.get("depends_on") or []) for s in self.subsystems}

        pmcc_deps: dict[str, set[str]] = {no: set() for no in by_pmcc}
        for s in self.subsystems:
            for tok in (s.get("depends_on") or []):
                dep_pmcc = tok if tok in pmcc_deps else circuit_pmcc.get(tok)
                if dep_pmcc and dep_pmcc != s["pmcc_no"] and dep_pmcc in pmcc_deps:
                    pmcc_deps.setdefault(s["pmcc_no"], set()).add(dep_pmcc)

        g_pmcc = DiGraph()
        for no in by_pmcc:
            g_pmcc.add_node(no)
        for no, deps in pmcc_deps.items():
            for d in deps:
                g_pmcc.add_edge(d, no)
        try:
            order = [no for no in g_pmcc.topological_sort() if no in by_pmcc]
        except ValueError:
            order = list(by_pmcc.keys())

        out: list[dict] = []
        critical_path: list[int] = []
        proj_start: date | None = None
        proj_finish: date | None = None
        warnings: list[str] = []
        finish_by_circuit: dict[str, date] = {}
        finish_by_pmcc: dict[str, date] = {}

        for pmcc_no in order:
            acts = by_pmcc[pmcc_no]
            ids = {a["id"] for a in acts}
            rels = [
                r for r in self.relationships
                if r["predecessor_id"] in ids and r["successor_id"] in ids
            ]
            nodes = [
                ActivityNode(
                    id=str(a["id"]), name=a["name"], duration=a["duration"],
                    code=a["activity_id"], discipline=a["discipline"], status=a["status"],
                )
                for a in acts
            ]
            edges = [
                Edge(str(r["predecessor_id"]), str(r["successor_id"]), RelationType(r["rel_type"]), r["lag"])
                for r in rels
            ]
            anchor = self._pmcc_anchor(pmcc_no)
            res = compute_schedule(nodes, edges, calendar, anchor)
            warnings.extend(f"[{pmcc_no}] {w}" for w in res.warnings)

            by_id = {a["id"]: a for a in acts}
            for n in res.activities:
                a = by_id[int(n.id)]
                a["es"], a["ef"], a["ls"], a["lf"] = n.es, n.ef, n.ls, n.lf
                a["total_float"], a["is_critical"] = n.total_float, n.is_critical
                a["start_date"] = n.start_date.isoformat() if n.start_date else None
                a["finish_date"] = n.finish_date.isoformat() if n.finish_date else None

            # cross-PMCC dependency floor: only entry activities (no in-PMCC
            # predecessor) of a circuit that has an *unresolved-here* upstream
            # dependency (a different pmcc, already processed above) get one.
            has_local_pred = {r["successor_id"] for r in rels}
            external_floor: dict[int, date] = {}
            for a in acts:
                if a["id"] in has_local_pred:
                    continue
                deps = circuit_depends.get(a["circuit"], [])
                floor_date: date | None = None
                for tok in deps:
                    fd = finish_by_circuit.get(tok) or finish_by_pmcc.get(tok)
                    if fd is None:
                        continue
                    cand = calendar.add_working_days(fd, 1)
                    floor_date = cand if floor_date is None else max(floor_date, cand)
                if floor_date is not None:
                    external_floor[a["id"]] = floor_date

            shifted = self._apply_manual_overrides(acts, rels, calendar, extra_floor=external_floor)

            if shifted and external_floor:
                natural_finish = max(
                    (date.fromisoformat(a["finish_date"]) for a in acts if a.get("finish_date")),
                    default=None,
                )
                if natural_finish and natural_finish > anchor:
                    warnings.append(
                        f"[{pmcc_no}] cross-PMCC dependency pushed the finish to "
                        f"{natural_finish.isoformat()}, later than its target "
                        f"{anchor.isoformat()}."
                    )

            acts_by_circuit: dict[str, list[dict]] = {}
            for a in acts:
                acts_by_circuit.setdefault(a["circuit"], []).append(a)
            for code, cacts in acts_by_circuit.items():
                finishes = [date.fromisoformat(a["finish_date"]) for a in cacts if a.get("finish_date")]
                if finishes:
                    finish_by_circuit[code] = max(finishes)
            all_finishes = [date.fromisoformat(a["finish_date"]) for a in acts if a.get("finish_date")]
            if all_finishes:
                finish_by_pmcc[pmcc_no] = max(all_finishes)

            if res.project_start and (proj_start is None or res.project_start < proj_start):
                proj_start = res.project_start
            proj_finish_candidate = max(
                (date.fromisoformat(a["finish_date"]) for a in acts if a.get("finish_date")),
                default=res.project_finish,
            )
            if proj_finish_candidate and (proj_finish is None or proj_finish_candidate > proj_finish):
                proj_finish = proj_finish_candidate
            critical_path.extend(int(x) for x in res.critical_path)

        for a in self.activities:
            out.append(
                {
                    "id": a["id"],
                    "activity_id": a["activity_id"],
                    "name": a["name"],
                    "duration": a["duration"],
                    "es": a.get("es"),
                    "ef": a.get("ef"),
                    "ls": a.get("ls"),
                    "lf": a.get("lf"),
                    "total_float": a.get("total_float"),
                    "is_critical": a.get("is_critical", False),
                    "start_date": a.get("start_date"),
                    "finish_date": a.get("finish_date"),
                    "is_manual": a.get("is_manual", False),
                    "status": a["status"],
                }
            )
        return {
            "activities": out,
            "critical_path": critical_path,
            "project_start": proj_start.isoformat() if proj_start else None,
            "project_finish": proj_finish.isoformat() if proj_finish else None,
            "warnings": warnings,
        }

    def scale_pmcc_duration(self, pmcc_no: str, factor: float) -> int:
        """Compress/stretch a whole PMCC's schedule by scaling every one of its
        activity durations by ``factor`` (e.g. 0.8 = 20% shorter), rounding to
        whole days with a 1-day floor. This is what "shrinking the PMCC bar"
        in the timeline does — the bar's length is the span of its longest
        circuit, so shortening every activity shortens that span too.
        Returns the number of activities scaled.
        """
        factor = max(0.1, min(5.0, factor))
        count = 0
        for a in self.activities:
            if a["pmcc_no"] == pmcc_no:
                a["duration"] = max(1, round(a["duration"] * factor))
                count += 1
        return count

    def network(self, pmcc: str | None = None) -> dict:
        self.compute()  # ensure dates fresh (global schedule)
        nodes, edges = self._domain(pmcc)
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
        net = build_network(nodes, edges, positions)
        # enrich each node with circuit / priority for grouped display
        for node in net["nodes"]:
            a = by.get(int(node["id"]))
            if a:
                node["data"]["circuit"] = a.get("circuit", "")
                node["data"]["priority"] = a.get("priority", "")
        return net

    def validate(self, pmcc: str | None = None) -> dict:
        nodes, edges = self._domain(pmcc)
        w, e = validate_network(nodes, edges)
        return {"warnings": w, "errors": e}

    def summary(self, pmcc: str | None = None) -> dict:
        sched = self.compute()
        sched_by = {a["id"]: a for a in sched["activities"]}
        acts = self.activities if not pmcc else [a for a in self.activities if a.get("pmcc_no") == pmcc]
        total = len(acts)
        completed = sum(1 for a in acts if a["status"] == "Completed")
        in_prog = sum(1 for a in acts if a["status"] == "In Progress")
        rows = [sched_by[a["id"]] for a in acts if a["id"] in sched_by]
        # per-PMCC roll-up for the overview
        pmcc_rollup = []
        for p in self.pmccs:
            pa = [a for a in self.activities if a.get("pmcc_no") == p["no"]]
            if not pa:
                continue
            done = sum(1 for a in pa if a["status"] == "Completed")
            pmcc_rollup.append(
                {
                    "no": p["no"],
                    "category": p["category"],
                    "description": p["description"],
                    "seq": p["seq"],
                    "activities": len(pa),
                    "completed": done,
                    "critical": sum(1 for a in pa if a.get("is_critical")),
                }
            )
        return {
            "project": {
                "name": self.project["name"],
                "subtitle": self.project.get("subtitle", ""),
                "client": self.project["client"],
                "mechanical_completion_date": self.project["mechanical_completion_date"],
                "planned_startup_date": self.project["planned_startup_date"],
            },
            "filter_pmcc": pmcc,
            "total_activities": total,
            "completed": completed,
            "in_progress": in_prog,
            "pending": total - completed - in_prog,
            "critical": sum(1 for a in rows if a["is_critical"]),
            "circuits": len({a["circuit"] for a in acts}),
            "activities": rows,
            "pmcc_rollup": pmcc_rollup,
        }

    def timeline(self, pmcc: str | None = None) -> dict:
        """Time-phased data: PMCC blocks + (optionally) their circuits/activities.

        Drives the SIMOPS timeline. ``pmcc_rows`` is always computed across the
        *whole* train (one aggregate bar per PMCC, its own start/finish span) so
        the top-level view is always "all PMCCs clubbed" regardless of the page
        filter; ``circuits`` drills into one PMCC's circuits + activities when
        expanded.
        """
        sched = self.compute()
        sched_by = {a["id"]: a for a in sched["activities"]}

        def merged(a: dict) -> dict:
            s = sched_by.get(a["id"], {})
            m = dict(a)
            m.update(
                {
                    k: s.get(k)
                    for k in ("start_date", "finish_date", "is_critical", "total_float", "is_manual")
                }
            )
            return m

        all_acts = [merged(a) for a in self.activities]

        preds: dict[int, list[int]] = {}
        for r in self.relationships:
            preds.setdefault(r["successor_id"], []).append(r["predecessor_id"])

        # PMCC-level aggregate rows — always all PMCCs (the "clubbed" overview).
        pmcc_rows = []
        for p in self.pmccs:
            pa = [a for a in all_acts if a["pmcc_no"] == p["no"]]
            starts = [a["start_date"] for a in pa if a.get("start_date")]
            finishes = [a["finish_date"] for a in pa if a.get("finish_date")]
            if not starts:
                continue
            pmcc_rows.append(
                {
                    "no": p["no"],
                    "seq": p["seq"],
                    "category": p["category"],
                    "description": p["description"],
                    "start": min(starts),
                    "finish": max(finishes),
                    "critical": any(a.get("is_critical") for a in pa),
                    "manual": any(a.get("is_manual") for a in pa),
                    "activities": len(pa),
                    "finish_override": self.pmcc_finish.get(p["no"]),
                    "priority": p.get("priority"),
                    "depends_on": p.get("depends_on") or [],
                }
            )
        pmcc_rows.sort(key=lambda r: r["start"])

        # Circuit/activity drill-down, respecting the requested PMCC filter.
        acts = all_acts if not pmcc else [a for a in all_acts if a["pmcc_no"] == pmcc]
        by_code: dict[str, list[dict]] = {}
        for a in acts:
            by_code.setdefault(a["circuit"], []).append(a)
        circuits = []
        for code, items in by_code.items():
            starts = [a["start_date"] for a in items if a.get("start_date")]
            finishes = [a["finish_date"] for a in items if a.get("finish_date")]
            circuits.append(
                {
                    "code": code,
                    "pmcc_no": items[0]["pmcc_no"],
                    "priority": items[0]["priority"],
                    "description": items[0].get("circuit_desc", ""),
                    "start": min(starts) if starts else None,
                    "finish": max(finishes) if finishes else None,
                    "critical": any(a.get("is_critical") for a in items),
                    "activities": [
                        {
                            "id": a["id"],
                            "name": a["name"],
                            "discipline": a["discipline"],
                            "duration": a["duration"],
                            "start": a.get("start_date"),
                            "finish": a.get("finish_date"),
                            "critical": a.get("is_critical", False),
                            "float": a.get("total_float"),
                            "is_manual": a.get("is_manual", False),
                            "preds": preds.get(a["id"], []),
                        }
                        for a in items
                    ],
                }
            )
        circuits.sort(key=lambda c: (c["start"] or "9999", c["pmcc_no"], c["code"]))
        return {
            "project_start": sched["project_start"],
            "project_finish": sched["project_finish"],
            "mechanical_completion_date": self.project["mechanical_completion_date"],
            "filter_pmcc": pmcc,
            "pmcc_rows": pmcc_rows,
            "circuits": circuits,
        }

    # --- resource & rental planning -----------------------------------------
    RESOURCE_CSV_COLUMNS = [
        "record_type", "category", "name", "code", "unit", "ownership",
        "rate", "currency", "supplier", "notes",
        "assign_scope", "assign_pmcc", "assign_activity_id", "assign_quantity",
        "assign_start", "assign_finish",
    ]

    def _pmcc_spans(self) -> dict[str, tuple[str, str]]:
        """min start / max finish (ISO strings) for every PMCC, from the last
        computed schedule already written onto ``self.activities``."""
        spans: dict[str, tuple[str, str]] = {}
        for a in self.activities:
            s, f = a.get("start_date"), a.get("finish_date")
            no = a.get("pmcc_no")
            if not no or not s or not f:
                continue
            if no not in spans:
                spans[no] = (s, f)
            else:
                cs, cf = spans[no]
                spans[no] = (min(cs, s), max(cf, f))
        return spans

    def _assignment_window(
        self, asg: dict, act_by_id: dict, pmcc_spans: dict
    ) -> tuple[str | None, str | None, str | None]:
        """Resolve (start, finish, pmcc_no) for an assignment.

        An explicit start/finish on the assignment always wins; otherwise the
        window is inferred from the linked activity (Activity scope) or the
        PMCC's schedule span (PMCC scope)."""
        start = asg.get("start_date") or None
        finish = asg.get("finish_date") or None
        pmcc_no = asg.get("pmcc_no") or None
        if asg.get("scope") == "Activity" and asg.get("activity_id") is not None:
            act = act_by_id.get(asg["activity_id"])
            if act:
                pmcc_no = act.get("pmcc_no") or pmcc_no
                start = start or act.get("start_date")
                finish = finish or act.get("finish_date")
        elif pmcc_no and pmcc_no in pmcc_spans:
            s, f = pmcc_spans[pmcc_no]
            start = start or s
            finish = finish or f
        return start, finish, pmcc_no

    def resource_plan(self) -> dict:
        """Time-phased resource demand and rental-cost rollup.

        Cost model: a *Rental* line costs ``rate x quantity x working-days`` over
        its scheduled window; anything else (owned gear / consumables) costs
        ``rate x quantity`` as a one-off. Working days honour the project
        calendar (weekends + holidays)."""
        self.compute()  # refresh activity start/finish dates
        calendar = self._calendar()
        act_by_id = {a["id"]: a for a in self.activities}
        res_by_id = {r["id"]: r for r in self.resources}
        pmcc_spans = self._pmcc_spans()

        lines: list[dict] = []
        for asg in self.resource_assignments:
            res = res_by_id.get(asg.get("resource_id"))
            if not res:
                continue
            start, finish, pmcc_no = self._assignment_window(asg, act_by_id, pmcc_spans)
            days = 0
            if start and finish:
                days = calendar.working_days_between(
                    date.fromisoformat(start), date.fromisoformat(finish)
                )
            qty = float(asg.get("quantity") or 0)
            rate = float(res.get("rate") or 0)
            is_rental = (res.get("ownership") == "Rental")
            cost = rate * qty * days if is_rental else rate * qty
            act = act_by_id.get(asg.get("activity_id")) if asg.get("activity_id") is not None else None
            lines.append(
                {
                    "assignment_id": asg["id"],
                    "resource_id": res["id"],
                    "category": res.get("category", ""),
                    "name": res.get("name", ""),
                    "code": res.get("code", ""),
                    "unit": res.get("unit", ""),
                    "ownership": res.get("ownership", ""),
                    "rate": rate,
                    "currency": res.get("currency", ""),
                    "supplier": res.get("supplier", ""),
                    "scope": asg.get("scope", "PMCC"),
                    "pmcc_no": pmcc_no or "",
                    "activity_label": (act.get("name") if act else ""),
                    "quantity": qty,
                    "start_date": start or "",
                    "finish_date": finish or "",
                    "working_days": days,
                    "is_rental": is_rental,
                    "cost": round(cost, 2),
                }
            )

        # per-resource aggregation (+ peak concurrent demand across the timeline)
        by_resource: dict[int, dict] = {}
        for ln in lines:
            agg = by_resource.setdefault(
                ln["resource_id"],
                {
                    "resource_id": ln["resource_id"], "name": ln["name"],
                    "code": ln["code"], "category": ln["category"],
                    "unit": ln["unit"], "ownership": ln["ownership"],
                    "currency": ln["currency"], "total_quantity": 0.0,
                    "total_cost": 0.0, "peak_demand": 0.0, "_spans": [],
                },
            )
            agg["total_quantity"] += ln["quantity"]
            agg["total_cost"] = round(agg["total_cost"] + ln["cost"], 2)
            agg["_spans"].append((ln["start_date"], ln["finish_date"], ln["quantity"]))
        for agg in by_resource.values():
            agg["peak_demand"] = _peak_concurrent(agg.pop("_spans"))

        # per-category subtotals
        by_category: dict[str, dict] = {}
        for agg in by_resource.values():
            cat = by_category.setdefault(
                agg["category"] or "Uncategorised",
                {"category": agg["category"] or "Uncategorised", "items": 0, "cost": 0.0},
            )
            cat["items"] += 1
            cat["cost"] = round(cat["cost"] + agg["total_cost"], 2)

        currencies = {r.get("currency") for r in self.resources if r.get("currency")}
        currency = currencies.pop() if len(currencies) == 1 else ""
        total_cost = round(sum(a["total_cost"] for a in by_resource.values()), 2)
        rental_cost = round(
            sum(ln["cost"] for ln in lines if ln["is_rental"]), 2
        )
        return {
            "lines": sorted(lines, key=lambda x: (x["category"], x["name"], x["pmcc_no"])),
            "by_resource": sorted(by_resource.values(), key=lambda x: (x["category"], x["name"])),
            "by_category": sorted(by_category.values(), key=lambda x: x["category"]),
            "total_cost": total_cost,
            "rental_cost": rental_cost,
            "currency": currency,
            "catalogue_size": len(self.resources),
            "assignment_count": len(self.resource_assignments),
        }

    def export_resources_csv(self) -> str:
        """Round-trippable CSV of the whole catalogue + its assignments."""
        buf = io.StringIO()
        w = csv.DictWriter(buf, fieldnames=self.RESOURCE_CSV_COLUMNS)
        w.writeheader()
        for r in self.resources:
            w.writerow(
                {
                    "record_type": "RESOURCE", "category": r.get("category", ""),
                    "name": r.get("name", ""), "code": r.get("code", ""),
                    "unit": r.get("unit", ""), "ownership": r.get("ownership", ""),
                    "rate": r.get("rate", ""), "currency": r.get("currency", ""),
                    "supplier": r.get("supplier", ""), "notes": r.get("notes", ""),
                }
            )
        res_by_id = {r["id"]: r for r in self.resources}
        for a in self.resource_assignments:
            res = res_by_id.get(a.get("resource_id"))
            w.writerow(
                {
                    "record_type": "ASSIGNMENT",
                    "code": res.get("code", "") if res else "",
                    "assign_scope": a.get("scope", "PMCC"),
                    "assign_pmcc": a.get("pmcc_no", "") or "",
                    "assign_activity_id": a.get("activity_id") or "",
                    "assign_quantity": a.get("quantity", ""),
                    "assign_start": a.get("start_date", "") or "",
                    "assign_finish": a.get("finish_date", "") or "",
                }
            )
        return buf.getvalue()

    def import_resources_csv(self, text: str) -> dict:
        """Load a catalogue/assignment CSV. RESOURCE rows are upserted by code;
        ASSIGNMENT rows link to a catalogue item by code. Tolerant of blanks."""
        reader = csv.DictReader(io.StringIO(text))
        by_code: dict[str, dict] = {r["code"]: r for r in self.resources if r.get("code")}
        errors: list[str] = []
        added_res = added_asg = 0
        assignment_rows: list[dict] = []
        for i, row in enumerate(reader, start=2):
            row = {(k or "").strip(): (v or "").strip() for k, v in row.items()}
            kind = (row.get("record_type") or "").upper()
            # infer: a row with catalogue fields but no record_type is a RESOURCE
            if not kind:
                kind = "ASSIGNMENT" if row.get("assign_quantity") or row.get("assign_pmcc") else "RESOURCE"
            if kind == "RESOURCE":
                code = row.get("code") or row.get("name")
                if not row.get("name"):
                    continue
                try:
                    rate = float(row.get("rate") or 0)
                except ValueError:
                    rate = 0.0
                    errors.append(f"Row {i}: bad rate '{row.get('rate')}' — used 0.")
                existing = by_code.get(code)
                payload = {
                    "category": row.get("category") or "Consumable",
                    "name": row.get("name"), "code": code,
                    "unit": row.get("unit", ""),
                    "ownership": row.get("ownership") or "Owned",
                    "rate": rate, "currency": row.get("currency") or "USD",
                    "supplier": row.get("supplier", ""), "notes": row.get("notes", ""),
                }
                if existing:
                    existing.update(payload)
                else:
                    rid = self.next_id("resource")
                    rec = {"id": rid, **payload}
                    self.resources.append(rec)
                    by_code[code] = rec
                    added_res += 1
            elif kind == "ASSIGNMENT":
                assignment_rows.append((i, row))
        # second pass so assignments can reference resources added above
        for i, row in assignment_rows:
            res = by_code.get(row.get("code"))
            if not res:
                errors.append(f"Row {i}: assignment references unknown resource code '{row.get('code')}'.")
                continue
            try:
                qty = float(row.get("assign_quantity") or 0)
            except ValueError:
                qty = 0.0
            act_id = row.get("assign_activity_id")
            self.resource_assignments.append(
                {
                    "id": self.next_id("assignment"),
                    "resource_id": res["id"],
                    "scope": row.get("assign_scope") or ("Activity" if act_id else "PMCC"),
                    "pmcc_no": row.get("assign_pmcc") or None,
                    "activity_id": int(act_id) if act_id and act_id.isdigit() else None,
                    "quantity": qty,
                    "start_date": row.get("assign_start", ""),
                    "finish_date": row.get("assign_finish", ""),
                }
            )
            added_asg += 1
        self.save()
        return {"ok": added_res + added_asg > 0, "resources_added": added_res,
                "assignments_added": added_asg, "errors": errors}


def _peak_concurrent(spans: list[tuple[str, str, float]]) -> float:
    """Maximum simultaneous quantity across dated spans (inclusive). Undated
    spans are treated as always-on and added to the baseline."""
    baseline = sum(q for s, f, q in spans if not (s and f))
    events: list[tuple[str, float]] = []
    for s, f, q in spans:
        if s and f:
            events.append((s, q))
            events.append((f + "~", -q))  # '~' sorts after any ISO date on same day → inclusive
    if not events:
        return round(baseline, 2)
    events.sort()
    cur = baseline
    peak = baseline
    for _, delta in events:
        cur += delta
        peak = max(peak, cur)
    return round(peak, 2)


STORE = Store()


def effective_api_key() -> str:
    """The Claude API key to use: the one entered in the AI tab, else the
    ANTHROPIC_API_KEY environment variable (either is optional)."""
    return STORE.settings.get("anthropic_api_key") or os.environ.get("ANTHROPIC_API_KEY", "")


def ai_reply(message: str) -> dict:
    """Offline-graceful AI: uses Claude if key + SDK present, else a clear note."""
    key = effective_api_key()
    if not key:
        return {
            "reply": "AI assistant is offline. Enter a Claude API key on this AI tab "
            "(or set ANTHROPIC_API_KEY) to enable it. All scheduling, network, "
            "Gantt and export features work without it.",
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
        parsed = urlparse(self.path)
        path = parsed.path
        qs = parse_qs(parsed.query)
        pmcc = (qs.get("pmcc") or [None])[0] or None
        if path in ("/", "/index.html"):
            html = (WEB_DIR / "index.html").read_bytes()
            return self._bytes(html, "text/html; charset=utf-8")
        with STORE.lock:
            if path == "/api/health":
                return self._json({"status": "ok", "mode": "standalone", "ai_available": bool(effective_api_key())})
            if path == "/api/settings":
                return self._json({"anthropic_configured": bool(STORE.settings.get("anthropic_api_key"))})
            if path == "/api/project":
                return self._json(STORE.project)
            if path == "/api/pmccs":
                return self._json(STORE.pmccs)
            if path == "/api/subsystems":
                subs = STORE.subsystems if not pmcc else [s for s in STORE.subsystems if s["pmcc_no"] == pmcc]
                return self._json(subs)
            if path == "/api/activities":
                acts = STORE.activities if not pmcc else [a for a in STORE.activities if a.get("pmcc_no") == pmcc]
                return self._json(acts)
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
            if path == "/api/resources":
                return self._json(STORE.resources)
            if path == "/api/resource-assignments":
                asgs = STORE.resource_assignments
                if pmcc:
                    asgs = [a for a in asgs if a.get("pmcc_no") == pmcc]
                return self._json(asgs)
            if path == "/api/resource-plan":
                return self._json(STORE.resource_plan())
            if path == "/api/export/resources-csv":
                return self._bytes(STORE.export_resources_csv().encode(), "text/csv", filename="resource_plan.csv")
            if path == "/api/schedule/compute":
                return self._json(STORE.compute())
            if path == "/api/network":
                return self._json(STORE.network(pmcc))
            if path == "/api/validate":
                return self._json(STORE.validate(pmcc))
            if path == "/api/summary":
                return self._json(STORE.summary(pmcc))
            if path == "/api/timeline":
                return self._json(STORE.timeline(pmcc))
            if path == "/api/export/html":
                return self._bytes(export_dashboard_html(STORE.summary(pmcc), STORE.compute()).encode(), "text/html; charset=utf-8")
            if path == "/api/export/csv":
                return self._bytes(export_csv(), "text/csv", filename="schedule.csv")
            if path == "/api/template/csv":
                return self._bytes(STORE.template_csv().encode(), "text/csv", filename="commissioning_template.csv")
            if path == "/api/export/template-csv":
                return self._bytes(STORE.export_to_csv().encode(), "text/csv", filename="commissioning_data_export.csv")
        return self._json({"error": "not found"}, 404)

    def do_POST(self):
        path = urlparse(self.path).path
        body = self._read_json()
        with STORE.lock:
            # --- drag the whole PMCC bar: shift its target finish date, carrying
            # every activity (including already-pinned ones) by the same delta ---
            m = re.match(r"/api/pmcc/([\w-]+)/finish$", path)
            if m:
                pmcc_no = m.group(1)
                finish = body.get("finish")
                if not finish:
                    return self._json({"error": "finish required"}, 400)
                sched = STORE.compute()
                sched_by = {a["id"]: a for a in sched["activities"]}
                pmcc_ids = [a["id"] for a in STORE.activities if a["pmcc_no"] == pmcc_no]
                finishes = [
                    sched_by[i]["finish_date"] for i in pmcc_ids
                    if sched_by.get(i) and sched_by[i].get("finish_date")
                ]
                old_finish = max(finishes) if finishes else None
                STORE.pmcc_finish[pmcc_no] = finish
                if old_finish:
                    delta = (date.fromisoformat(finish) - date.fromisoformat(old_finish)).days
                    if delta:
                        for aid in pmcc_ids:
                            if aid in STORE.manual_start:
                                shifted = date.fromisoformat(STORE.manual_start[aid]) + timedelta(days=delta)
                                STORE.manual_start[aid] = shifted.isoformat()
                STORE.save()
                return self._json({"ok": True, "pmcc_no": pmcc_no, "finish": finish})
            m = re.match(r"/api/pmcc/([\w-]+)/clear-finish$", path)
            if m:
                STORE.pmcc_finish.pop(m.group(1), None)
                STORE.save()
                return self._json({"ok": True})
            # --- resize the whole PMCC bar: scale every activity's duration ---
            m = re.match(r"/api/pmcc/([\w-]+)/scale-duration$", path)
            if m:
                pmcc_no = m.group(1)
                try:
                    factor = float(body.get("factor", 1.0))
                except (TypeError, ValueError):
                    return self._json({"error": "factor must be a number"}, 400)
                if factor <= 0:
                    return self._json({"error": "factor must be positive"}, 400)
                count = STORE.scale_pmcc_duration(pmcc_no, factor)
                STORE.save()
                return self._json({"ok": True, "pmcc_no": pmcc_no, "factor": factor, "activities_scaled": count})
            # --- drag a single activity: manual start-date pin ---
            m = re.match(r"/api/activities/(\d+)/reschedule$", path)
            if m:
                aid = int(m.group(1))
                start = body.get("start")
                if start:
                    STORE.manual_start[aid] = start
                else:
                    STORE.manual_start.pop(aid, None)
                STORE.save()
                return self._json({"ok": True, "id": aid, "start": start})
            if path == "/api/reset-adjustments":
                STORE.pmcc_finish.clear()
                STORE.manual_start.clear()
                STORE.save()
                return self._json({"ok": True})
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
            if path == "/api/resources":
                if not body.get("name"):
                    return self._json({"error": "name required"}, 400)
                rid = STORE.next_id("resource")
                try:
                    rate = float(body.get("rate") or 0)
                except (TypeError, ValueError):
                    rate = 0.0
                rec = {
                    "id": rid,
                    "category": body.get("category") or "Consumable",
                    "name": body.get("name"),
                    "code": body.get("code", ""),
                    "unit": body.get("unit", ""),
                    "ownership": body.get("ownership") or "Owned",
                    "rate": rate,
                    "currency": body.get("currency") or "USD",
                    "supplier": body.get("supplier", ""),
                    "notes": body.get("notes", ""),
                }
                STORE.resources.append(rec)
                STORE.save()
                return self._json(rec)
            if path == "/api/resource-assignments":
                if not body.get("resource_id"):
                    return self._json({"error": "resource_id required"}, 400)
                aid = STORE.next_id("assignment")
                act_id = body.get("activity_id")
                try:
                    qty = float(body.get("quantity") or 1)
                except (TypeError, ValueError):
                    qty = 1.0
                rec = {
                    "id": aid,
                    "resource_id": int(body["resource_id"]),
                    "scope": body.get("scope") or ("Activity" if act_id else "PMCC"),
                    "pmcc_no": body.get("pmcc_no") or None,
                    "activity_id": int(act_id) if act_id else None,
                    "quantity": qty,
                    "start_date": body.get("start_date", ""),
                    "finish_date": body.get("finish_date", ""),
                }
                STORE.resource_assignments.append(rec)
                STORE.save()
                return self._json(rec)
            if path == "/api/import/resources-csv":
                text = body.get("csv", "")
                if not text:
                    return self._json({"ok": False, "errors": ["No CSV content received."],
                                        "resources_added": 0, "assignments_added": 0})
                return self._json(STORE.import_resources_csv(text))
            if path == "/api/ai/chat":
                return self._json(ai_reply(body.get("message", "")))
            if path == "/api/reset":
                STORE.reset_to_seed()
                STORE.save()
                return self._json({"ok": True})
            if path == "/api/reset-blank":
                STORE.reset_to_blank()
                STORE.save()
                return self._json({"ok": True})
            if path == "/api/import/csv":
                text = body.get("csv", "")
                if not text:
                    return self._json({"ok": False, "errors": ["No CSV content received."], "warnings": [],
                                        "pmccs": 0, "circuits": 0, "buildings": 0, "activities": 0})
                result = STORE.import_from_csv(text)
                return self._json(result)
        return self._json({"error": "not found"}, 404)

    def do_PUT(self):
        path = urlparse(self.path).path
        body = self._read_json()
        if path == "/api/project":
            with STORE.lock:
                for k in ("mechanical_completion_date", "planned_startup_date", "name", "client", "location"):
                    if body.get(k):
                        STORE.project[k] = body[k]
                if isinstance(body.get("working_weekdays"), list):
                    try:
                        STORE.project["working_weekdays"] = [int(d) for d in body["working_weekdays"]]
                    except (TypeError, ValueError):
                        pass
                if isinstance(body.get("holidays"), list):
                    STORE.project["holidays"] = [str(h) for h in body["holidays"]]
                STORE.save()
                return self._json(STORE.project)
        if path == "/api/settings":
            with STORE.lock:
                if "anthropic_api_key" in body:
                    STORE.settings["anthropic_api_key"] = (body.get("anthropic_api_key") or "").strip()
                STORE.save()
                return self._json({"anthropic_configured": bool(STORE.settings.get("anthropic_api_key"))})
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
        m = re.match(r"/api/resources/(\d+)$", path)
        if m:
            with STORE.lock:
                r = next((x for x in STORE.resources if x["id"] == int(m.group(1))), None)
                if not r:
                    return self._json({"error": "not found"}, 404)
                for k in ("category", "name", "code", "unit", "ownership", "currency", "supplier", "notes"):
                    if k in body:
                        r[k] = body[k]
                if "rate" in body:
                    try:
                        r["rate"] = float(body["rate"])
                    except (TypeError, ValueError):
                        pass
                STORE.save()
                return self._json(r)
        m = re.match(r"/api/resource-assignments/(\d+)$", path)
        if m:
            with STORE.lock:
                a = next((x for x in STORE.resource_assignments if x["id"] == int(m.group(1))), None)
                if not a:
                    return self._json({"error": "not found"}, 404)
                for k in ("scope", "pmcc_no", "start_date", "finish_date"):
                    if k in body:
                        a[k] = body[k]
                if "activity_id" in body:
                    a["activity_id"] = int(body["activity_id"]) if body["activity_id"] else None
                if "quantity" in body:
                    try:
                        a["quantity"] = float(body["quantity"])
                    except (TypeError, ValueError):
                        pass
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
            m = re.match(r"/api/resources/(\d+)$", path)
            if m:
                rid = int(m.group(1))
                STORE.resources = [r for r in STORE.resources if r["id"] != rid]
                # cascade: drop assignments that referenced the deleted resource
                STORE.resource_assignments = [
                    a for a in STORE.resource_assignments if a.get("resource_id") != rid
                ]
                STORE.save()
                return self._json({"ok": True})
            m = re.match(r"/api/resource-assignments/(\d+)$", path)
            if m:
                aid = int(m.group(1))
                STORE.resource_assignments = [
                    a for a in STORE.resource_assignments if a["id"] != aid
                ]
                STORE.save()
                return self._json({"ok": True})
        return self._json({"error": "not found"}, 404)


def _bind(preferred: int) -> ThreadingHTTPServer:
    """Bind 127.0.0.1 on the preferred port, falling back if it's in use."""
    last_err: OSError | None = None
    for port in [preferred, *range(8001, 8011), 0]:
        try:
            return ThreadingHTTPServer(("127.0.0.1", port), Handler)
        except OSError as exc:  # port already in use, etc.
            last_err = exc
            continue
    raise last_err or OSError("Could not bind a local port")


def _open_browser(url: str) -> None:
    """Open the default browser once the server is actually listening."""
    import time
    import webbrowser

    def worker() -> None:
        time.sleep(1.0)  # give serve_forever a moment to start accepting
        try:
            webbrowser.open(url)
        except Exception:
            pass  # headless / no browser — the URL is printed anyway

    threading.Thread(target=worker, daemon=True).start()


def main() -> None:
    if not (WEB_DIR / "index.html").exists():
        print("ERROR: web UI not found at", WEB_DIR / "index.html")
        print("Run this from the project's `backend` folder (or via run-portable-windows.bat).")
        raise SystemExit(1)

    preferred = int(os.environ.get("PORT", "8000"))
    httpd = _bind(preferred)
    actual_port = httpd.server_address[1]
    url = f"http://127.0.0.1:{actual_port}"

    print("=" * 60)
    print("  Commissioning Scheduler Pro — standalone (offline) mode")
    print("=" * 60)
    print(f"  Open this in your browser:  {url}")
    if actual_port != preferred:
        print(f"  (port {preferred} was busy, using {actual_port})")
    print("  Zero-dependency mode: Python standard library only.")
    print("  Keep this window open while using the app. Ctrl+C to stop.")
    print("=" * 60)

    if os.environ.get("NO_BROWSER") != "1":
        _open_browser(url)

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
