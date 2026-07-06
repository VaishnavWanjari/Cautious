"""Reports page — one-click PDF / Excel / Word / PowerPoint generation.

Every report is built live from the database with today's date auto-inserted,
saved into the portable ``data/reports`` folder.
"""

from __future__ import annotations

import os
import subprocess
import sys

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QComboBox, QFrame, QGridLayout, QHBoxLayout, QLabel, QMessageBox,
    QPushButton, QVBoxLayout, QWidget,
)

from ... import config
from ...core import reporting

REPORT_TYPES = ["Daily", "Weekly", "Monthly", "Management", "Client",
                "Commissioning", "Progress"]
FORMATS = ["PDF", "Excel", "Word", "PowerPoint"]


class ReportsPage(QWidget):
    def __init__(self, parent: QWidget | None = None):
        super().__init__(parent)
        root = QVBoxLayout(self)
        root.setContentsMargins(18, 14, 18, 16)
        root.setSpacing(14)

        title = QLabel("Reports")
        title.setObjectName("PageTitle")
        root.addWidget(title)
        root.addWidget(QLabel(
            "Generate an audit-ready report — executive summary, KPIs, module "
            "tables, risks and upcoming activities. Today's date is inserted "
            "automatically."))

        # report type selector
        sel = QFrame()
        sel.setObjectName("Panel")
        sl = QHBoxLayout(sel)
        sl.setContentsMargins(14, 12, 14, 12)
        sl.addWidget(QLabel("Report type:"))
        self.type_combo = QComboBox()
        self.type_combo.addItems(REPORT_TYPES)
        self.type_combo.setFixedWidth(200)
        sl.addWidget(self.type_combo)
        sl.addStretch(1)
        open_btn = QPushButton("Open reports folder")
        open_btn.setObjectName("Ghost")
        open_btn.clicked.connect(self._open_folder)
        sl.addWidget(open_btn)
        root.addWidget(sel)

        # format buttons
        grid_frame = QFrame()
        grid_frame.setObjectName("Panel")
        grid = QGridLayout(grid_frame)
        grid.setContentsMargins(16, 16, 16, 16)
        grid.setSpacing(12)
        for i, fmt in enumerate(FORMATS):
            btn = QPushButton(f"Generate {fmt}")
            btn.setMinimumHeight(52)
            btn.clicked.connect(lambda _=False, f=fmt: self._generate(f))
            grid.addWidget(btn, i // 2, i % 2)
        root.addWidget(grid_frame)

        self.status = QLabel("")
        self.status.setWordWrap(True)
        root.addWidget(self.status)
        root.addStretch(1)

    def _generate(self, fmt: str) -> None:
        kind = self.type_combo.currentText()
        try:
            path = reporting.GENERATORS[fmt](kind)
        except ImportError as exc:
            QMessageBox.warning(
                self, "Missing component",
                f"The {fmt} generator needs an extra library that isn't "
                f"installed in this build:\n{exc}")
            return
        except Exception as exc:
            QMessageBox.warning(self, "Report failed", str(exc))
            return
        self.status.setText(f"✔ {kind} {fmt} report saved:\n{path}")
        self._reveal(path)

    def _open_folder(self) -> None:
        config.ensure_dirs()
        self._reveal(config.REPORT_DIR)

    @staticmethod
    def _reveal(path) -> None:
        try:
            if sys.platform.startswith("win"):
                os.startfile(str(path))  # noqa: S606 - opening a local file
            elif sys.platform == "darwin":
                subprocess.Popen(["open", str(path)])
            else:
                subprocess.Popen(["xdg-open", str(path)])
        except Exception:
            pass
