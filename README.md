# GPT-3/4 Gas Processing Train — Pre-Commissioning Tracker & Visualizer

A professional **offline desktop application** for EPC Pre-Commissioning &
Commissioning planning on **Oil & Gas, LNG, Refinery, Petrochemical and Gas
Processing** projects. It works like a focused, Primavera-style planning tool:
build the commissioning hierarchy, draw the logic network visually, and let the
engine **back-calculate the schedule from the Mechanical Completion date** with
full critical-path analysis.

It ships preloaded with the **GPT-3/4 Gas Processing Train** dataset: the
21-PMCC handover sequence (Non-Process / Utility / Process) and ~155 commissioning
circuits, each with its priority and special pre-commissioning activity (chemical
cleaning, steam blowing, adsorbent loading, amine degreasing, internals box-up,
…) plus the standard activity set applied to every circuit — Reinstatement,
Vessel Inspection (if any), Leak Test with Dry Air, Inertization, No-Load Test
(if motors), Loop Check, Punch Point Liquidation and Layup Witness. Browse and
filter everything by PMCC.

> Built for commissioning, startup, planning and project-controls engineers.

---

## What it does (Phase 1 — current)

- **Project setup** — client, location, Mechanical Completion & startup dates,
  working-day calendar (incl. 6-day weeks) and holidays.
- **Commissioning hierarchy** — `PMCC → System → Subsystem → SNR/Circuit → Activity`
  with full CRUD.
- **Activity template library** — 17 preloaded pre-commissioning/commissioning
  activities (Hydrotest, Dewatering, Drying, Flushing, Leak Test, Loop Check,
  Energization, Startup, …) plus custom templates.
- **Backward scheduling + Critical Path Method** — computes ES/EF/LS/LF, total
  float and the critical path, anchored so the network finishes on the
  Mechanical Completion date. Date math honours working days and holidays.
- **Editable visual logic network** (React Flow) — drag activities, draw arrows
  to auto-create Finish-to-Start links, with critical activities highlighted and
  auto-layout. Supports FS/SS/FF/SF relationships with lead/lag.
- **Interactive Gantt** with critical-path highlight and a critical-only filter.
- **Agile SIMOPS Timeline** (standalone build) — every PMCC on one calendar axis,
  each PMCC its own independent Mechanical Completion date (default 26-Apr-2027,
  editable). **Drag a whole PMCC bar** to shift every one of its activities
  together; **click a PMCC** to expand its circuits/activities inline, each
  individually **draggable** — dependent activities cascade forward automatically,
  and every change is reflected immediately in the same sheet. "Reset drags"
  clears manual adjustments back to the pure backward-CPM schedule.
- **No-code logic engine** — author rules in plain language
  (`IF Hydrotest Complete AND Nitrogen Available THEN Enable Leak Test`) with
  AND/OR/NOT and nesting.
- **Constraint capture** — resource / utility / area / vendor / permit.
- **Dashboard** — totals, completion, critical count, readiness and validation
  warnings (circular logic, orphans, missing predecessors/successors).
- **Exports** — Excel (.xlsx), PDF report, and a self-contained HTML dashboard.
- **AI assistant** — Anthropic Claude, grounded in the current schedule; fully
  offline-graceful when no API key is set.

### Roadmap (Phase 2)

Resource-leveling algorithm, utility/area/vendor/permit constraint *solving*,
Primavera **XML/XER** export, PNG/SVG network snapshots, baseline & progress
tracking, and the **Saudi Aramco** turnover module (MCC/RFPC/RFC/RFSU, Punch
A/B/C, preservation & systemization tracking). The database already models the
constraint tables so these are additive.

---

## Architecture

```
Electron + React (TypeScript + Tailwind)  ──HTTP──▶  Python FastAPI backend
        frontend/                                        backend/
  project setup · hierarchy tree ·                 domain (calendar, entities) →
  React Flow network · Gantt ·                      application (CPM scheduler,
  logic builder · dashboard ·                       validation, logic engine,
  AI chat · exports                                 network layout) →
                                                    infrastructure (SQLite ORM,
                                                    repositories, exporters, AI) →
                                                    api (FastAPI routers)
```

Clean architecture: the scheduling engine in `backend/app/application` and the
domain in `backend/app/domain` are **framework-free and dependency-free** (the
CPM graph algorithms are a small pure-Python module, `application/graph.py`), so
they install instantly, run fully offline and are unit-tested in isolation.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for how the code maps to the
specification modules.

---

## Fastest start — zero-dependency standalone mode (no pip, no npm)

If you only have Python 3.11+ and no way to install packages, run the
**standalone** server. It uses the Python standard library only and serves a
self-contained web UI that reuses the exact same scheduling engine:

```bash
cd backend
python -m app.standalone        # then open http://127.0.0.1:8000
```

On Windows, just double-click **`run-standalone.bat`**. This needs no
`pip install`, no `npm install`, and no internet — ideal for locked-down site
laptops. (The full FastAPI + Electron build below adds Excel/PDF export, the
React desktop shell and SQLite persistence.)

### Windows with **no administrator rights**

Locked-down site laptop? Use **`run-portable-windows.bat`** — it runs with no
admin, no installer, no pip/npm and no internet, against either an existing
Python (`py` launcher) or a bundled portable Python you simply unzip. Full
step-by-step in **[docs/WINDOWS-NO-ADMIN.md](docs/WINDOWS-NO-ADMIN.md)**.

## Desktop app (Electron window, not just a browser tab)

The Electron shell spawns the same zero-dependency standalone server described
above and loads it directly in a native window — **no `pip install` needed**,
just Node.js to run/build the Electron shell and a system Python for the
backend it wraps.

1. Install [Python 3.11+](https://python.org) (tick *Add Python to PATH*) and
   [Node.js 18+](https://nodejs.org). No admin rights required for either.
2. `cd frontend && npm install` (one-time).
3. `npm run dev:electron` — opens the real desktop window immediately, with
   the full GPT-3/4 tracker including the draggable SIMOPS timeline.
4. To build a standalone installer/portable `.exe` you can hand to someone
   else: `npm run build` (output under `frontend/release/`) — see
   [Build a Windows installer](#build-a-windows-installer) below.

On a locked-down machine with no admin and no internet, use
`run-portable-windows.bat` instead (browser tab rather than a native window,
but otherwise identical) — see
[docs/WINDOWS-NO-ADMIN.md](docs/WINDOWS-NO-ADMIN.md).

## Run from source (any OS)

```bash
# Standalone backend the Electron shell wraps (stdlib only, no pip install)
cd backend
python run_standalone.py                          # http://127.0.0.1:8000

# Frontend / Electron shell (separate terminal)
cd frontend
npm install
npm run dev:electron   # desktop window, loads the backend above directly
```

The full FastAPI + SQLAlchemy backend (`uvicorn app.main:app --reload`, after
`pip install -r requirements.txt`) remains available for the richer Excel/PDF
export and persistent-database path; it is not what the packaged desktop app
loads by default today.

A **GPT-3/4 Gas Processing Train** project is seeded on first launch — the
21-PMCC handover sequence and ~155 commissioning circuits with their
precedence networks — so every screen is populated immediately.

## Enable the AI assistant (optional)

```bash
cp backend/.env.example backend/.env
# set ANTHROPIC_API_KEY=...   (model defaults to claude-opus-4-8)
```

## Tests

```bash
cd backend && pytest        # CPM, calendar, logic, validation, exporters
```

## Build a Windows installer

```bash
cd frontend && npm run build   # produces NSIS installer + portable build under release/
```

---

## Tech stack

React · TypeScript · Tailwind CSS · Electron · Python · FastAPI · SQLite
(SQLAlchemy) · React Flow · OpenPyXL · ReportLab · Anthropic Claude.

MIT licensed.
