# Commissioning Management Suite — Offline Windows Desktop App

A **portable, offline** desktop application (PySide6 / Qt) for monitoring the
complete commissioning status of an Oil & Gas project — built for daily
management meetings, client reviews and commissioning planning.

- **No installation, no administrator rights.** Ships as a single `.exe` you
  run from any folder or USB drive.
- **Fully offline.** All data lives in a local SQLite file; no internet, no
  cloud during execution.
- **Premium UI.** Power-BI-style dark/light dashboard with animated KPI cards
  and native Qt charts (donut, pie, gauge, bar, S-curve).

> Portable design: everything the app writes (database, backups, reports,
> exports, logs, config) goes into a `data/` folder **next to the executable**,
> so the whole thing travels on a USB stick.

---

## Tech stack

Python 3.11+ · PySide6 (Qt Widgets + **Qt Charts**) · SQLAlchemy 2 · SQLite ·
pandas + openpyxl (import/export) · ReportLab (PDF) · python-docx (Word) ·
python-pptx (PowerPoint) · PyInstaller (portable exe).

> Qt Charts is used instead of Plotly/Matplotlib: it renders natively inside
> Qt with **zero web/browser dependency**, which is the right choice for a
> locked-down offline desktop app.

---

## Run from source (development)

```bash
cd desktop
python -m pip install -r requirements.txt
python run.py
```

On first launch you get the **startup screen**: *Create New Project*,
*New with Sample Data*, *Open Existing*, or a **Recent Projects** list. If a
previous project exists the app first asks whether to reload it.

## Build the portable Windows .exe

```bash
cd desktop
pip install -r requirements.txt
pyinstaller build/app.spec
# -> dist/CommissioningManagementSuite.exe   (double-click to run, no install)
```

This is also done automatically in CI
(`.github/workflows/build-desktop-exe.yml`): a Linux **headless smoke test**
validates the whole app end-to-end, then a Windows job builds the exe and
uploads it as a downloadable artifact.

---

## Modules

| Module | Status |
|---|---|
| Executive Dashboard (KPIs + charts, live roll-up) | ✅ |
| Kanban board (drag-and-drop across status columns) | ✅ |
| PMCC management (CRUD, import/export) | ✅ |
| Equipment | ✅ |
| Procedures | ✅ |
| Special Recommissioning Activities | ✅ |
| Preservation tracker (overdue highlight) | ✅ |
| Manpower | ✅ |
| Consumables (low-stock flag) | ✅ |
| Punch list (A/B/C, open/closed/critical) | ✅ |
| Proposal comparison (proposed/current/completed/variance) | ✅ |
| Risks & Client Remarks | ✅ |
| Reports — PDF / Excel / Word / PowerPoint (auto-dated) | ✅ |
| Auto-save (every edit committed) · backup on close | ✅ |
| Import Excel / CSV / JSON · Export Excel / CSV / JSON | ✅ |
| Dark / Light theme · global per-module search | ✅ |

Every module is metadata-driven (see `app/core/columns.py`) — the table,
add/edit form, importer and exporter all read one field spec, so extending a
module is a one-line change.

---

## Folder structure

```
desktop/
  run.py                     # launcher / PyInstaller entry
  requirements.txt
  build/app.spec             # PyInstaller (onefile, windowed, portable)
  tools/make_samples.py      # generate sample Excel import templates
  tests/smoke_test.py        # headless end-to-end validation (CI)
  app/
    main.py                  # boot: theme, startup flow, open project
    config.py                # portable path resolution (data next to exe)
    database/
      models.py              # SQLAlchemy schema (all modules)
      db.py                  # engine/session, auto-save, backup
      seed.py                # sample project dataset
    core/
      columns.py             # field specs (single source of truth)
      metrics.py             # dashboard analytics
      repository.py          # generic CRUD
      importer.py exporter.py reporting.py
      settings.py            # recent projects + theme preference
    ui/
      main_window.py         # sidebar + header + stacked pages
      theme.py               # dark/light QSS + palette
      widgets/               # kpi_card, charts, table_page
      pages/                 # dashboard, kanban, reports
      dialogs/               # startup, record editor
    resources/logo.svg
  data/                      # created at runtime (db, backups, reports, …)
```

---

## Sample data

- **In-app:** Startup → *New with Sample Data* seeds a realistic project
  (40 PMCCs, 120 equipment tags, punch list, manpower, preservation, etc.).
- **Excel templates:** `python tools/make_samples.py` writes import templates
  into `sample/` showing the expected column layout for each module.

---

*Designed by Vaishnao Wanjari.*
