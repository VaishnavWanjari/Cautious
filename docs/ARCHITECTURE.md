# Architecture

Commissioning Scheduler Pro follows a clean, layered architecture so the
scheduling engine can evolve independently of the database and the UI.

## Layers (backend)

```
backend/app/
  domain/            framework-free, no I/O
    calendar.py        WorkCalendar — working-day/holiday date arithmetic
    entities.py        ActivityNode, Edge, ScheduleResult (engine dataclasses)
    enums.py           RelationType (FS/SS/FF/SF), Discipline, Status, ...
  application/       use cases, framework-free
    graph.py           tiny pure-Python DiGraph (topo sort, cycle detection)
    scheduler.py       CPM forward/backward passes, float, critical path,
                       backward anchoring to the Mechanical Completion date
    validation.py      circular/broken logic, orphans, missing pred/succ
    logic_engine.py    plain-language rule parser (AND/OR/NOT, nesting)
    network.py         schedule -> React Flow nodes/edges + auto-layout ranks
    templates.py       built-in activity template library
  infrastructure/    adapters / I/O
    models.py          SQLAlchemy ORM (the SQLite schema)
    repositories.py    ORM <-> domain entity mapping; result persistence
    seed.py            sample LNG Train 1 project + templates
    exporters/         xlsx (OpenPyXL), pdf (ReportLab), html dashboard
    ai/claude_client.py Anthropic Claude wrapper (offline-graceful)
  api/               FastAPI routers (thin: validate -> service -> repo)
  services.py        orchestration used by routers
  config.py db.py main.py
```

The **domain** and **application** layers have zero third-party dependencies —
the CPM graph algorithms live in `application/graph.py` rather than pulling in a
graph library — so the engine is portable, instant to install and trivially
unit-tested (`backend/tests`).

## Scheduling model

Durations are **working days**; offsets are 0-based inclusive working-day indices
(`EF = ES + duration − 1`). The forward pass yields ES/EF, the backward pass
LS/LF, and total float = LS − ES (critical when ≤ 0). The network is then
*anchored*: its latest finish is pinned to the project's Mechanical Completion
date and the required project start is derived, so every predecessor start date
is back-calculated. Offsets map to real dates through `WorkCalendar`, which skips
non-working weekdays and holidays.

Relationship semantics (with lead/lag in working days):

| Type | Constraint on the successor |
|------|------------------------------|
| FS   | starts after predecessor finishes (+lag) |
| SS   | starts relative to predecessor start (+lag) |
| FF   | finishes relative to predecessor finish (+lag) |
| SF   | finishes relative to predecessor start (+lag) |

## Specification → code map

| Spec module | Where |
|-------------|-------|
| Create Project / calendar / holidays | `domain/calendar.py`, `api/projects.py`, `components/ProjectSetup.tsx` |
| PMCC / System / Subsystem / SNR hierarchy | `infrastructure/models.py`, `api/projects.py`, `components/HierarchyTree.tsx` |
| Activity template library | `application/templates.py`, `api/activities.py`, `components/TemplateLibrary.tsx` |
| No-code logic engine (AND/OR/NOT) | `application/logic_engine.py`, `api/logic.py`, `components/LogicBuilder.tsx` |
| Constraint engine (capture) | `infrastructure/models.py` (Constraint), `components/LogicBuilder.tsx` |
| Backward scheduling + CPM | `application/scheduler.py`, `services.py`, `api/schedule.py` |
| Critical path analysis | `application/scheduler.py` (`_critical_path`) |
| Visual network builder + auto-logic | `application/network.py`, `components/NetworkEditor.tsx` |
| Real-time recalculation | `App.tsx` (`recompute`) → `POST /schedule/compute` |
| Bidirectional network ↔ schedule | shared activity rows; `getNetwork` + `computeSchedule` |
| Network validation | `application/validation.py`, `components/Dashboard.tsx` |
| Gantt chart | `components/GanttChart.tsx` |
| Dashboard | `api/schedule.py` (`summary`), `components/Dashboard.tsx` |
| Exports (xlsx/pdf/html) | `infrastructure/exporters/`, `api/exports.py`, `components/ExportPanel.tsx` |
| AI assistant | `infrastructure/ai/claude_client.py`, `api/ai.py`, `components/AiAssistant.tsx` |
| Offline desktop packaging | `frontend/electron/`, `package.json` (electron-builder) |

## Phase 2 (planned, additive)

Resource leveling and constraint *solving* (tables already modeled), Primavera
XML/XER export, PNG/SVG snapshots, baseline/progress tracking, and the Saudi
Aramco turnover workflow (MCC/RFPC/RFC/RFSU, Punch A/B/C, preservation,
systemization).
