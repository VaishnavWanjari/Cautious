"""Headless smoke test — the real end-to-end validation for CI.

Runs under ``QT_QPA_PLATFORM=offscreen`` (no display needed). It:
  1. creates a temp project DB and seeds sample data,
  2. exercises repository CRUD, import and export round-trips,
  3. computes the dashboard metrics,
  4. builds the MainWindow and visits every navigation page,
  5. generates a report in each format (PDF/Excel/Word/PowerPoint).

Exits non-zero on any failure so the build stops before packaging.
"""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

# Make the app importable when run as a plain script from desktop/.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))


def main() -> int:
    from PySide6.QtWidgets import QApplication

    from app.core import exporter, importer, metrics, repository, reporting
    from app.database.db import db
    from app.database.seed import seed_sample_project
    from app.ui.main_window import NAV, MainWindow

    tmp = Path(tempfile.mkdtemp())
    db.open(tmp / "smoke.cmsdb")
    seed_sample_project()

    # --- data layer ---------------------------------------------------------
    pmccs = repository.list_all("pmcc")
    assert len(pmccs) == 40, f"expected 40 PMCCs, got {len(pmccs)}"
    obj = repository.create("pmcc", {"number": "PMCC-TEST", "completion": 50,
                                     "status": "In Progress"})
    repository.update("pmcc", obj.id, {"completion": 75})
    assert repository.get("pmcc", obj.id).completion == 75
    assert repository.delete("pmcc", obj.id)

    # --- import / export round-trip ----------------------------------------
    xlsx = tmp / "equipment.xlsx"
    exporter.export_excel("equipment", xlsx, "Equipment")
    result = importer.import_file("equipment", xlsx)
    assert result["ok"], result["errors"]
    exporter.export_csv("punch", tmp / "punch.csv")
    exporter.export_json("consumable", tmp / "cons.json")

    # --- metrics ------------------------------------------------------------
    m = metrics.compute_dashboard()
    assert m.pmcc_total >= 40
    assert 0 <= m.overall_progress <= 100
    assert m.punch_total > 0
    assert m.scurve, "s-curve should have data"

    # --- UI: build window and visit every page ------------------------------
    app = QApplication.instance() or QApplication(sys.argv)
    win = MainWindow()
    win.show()
    for nav_id, *_ in NAV:
        win.navigate(nav_id)
        app.processEvents()
    # exercise kanban reload + dashboard refresh
    win._on_data_changed()
    app.processEvents()

    # --- reports (every format) --------------------------------------------
    for fmt in ("PDF", "Excel", "Word", "PowerPoint"):
        path = reporting.GENERATORS[fmt]("Management")
        assert Path(path).exists(), f"{fmt} report not written"

    print("SMOKE TEST PASSED — modules, UI, import/export and all report formats OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
