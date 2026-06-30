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

## Full desktop app on Windows — no administrator needed

1. Install [Python 3.11+](https://python.org) (tick *Add Python to PATH*) and
   [Node.js 18+](https://nodejs.org).
2. Double-click **`setup-windows.bat`** (one-time: creates the backend venv and
   installs dependencies).
3. Double-click **`run-windows.bat`** to launch the backend and the desktop app.

## Run from source (any OS)

```bash
# Backend
cd backend
python -m venv .venv && . .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload                     # http://127.0.0.1:8000

# Frontend (separate terminal)
cd frontend
npm install
npm run dev            # browser dev server at http://localhost:5173
# or
npm run dev:electron   # full Electron desktop shell
```

A sample **LNG Train 1** project (PMCC-01 → Condensate Stabilizer / Slug Catcher
/ Fuel Gas with the Hydrotest → Dewatering → Drying → Reinstatement → Leak Test
chain) is seeded on first launch so every screen is populated immediately.

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
