"""Startup dialog — Create New Project, Open Existing, or pick a Recent one.

Returns the chosen project database path (and whether to seed sample data).
Portable: new projects are created under ``data/database`` next to the app.
"""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QDialog, QFileDialog, QFrame, QHBoxLayout, QInputDialog, QLabel,
    QListWidget, QListWidgetItem, QMessageBox, QPushButton, QVBoxLayout, QWidget,
)

from ... import __app_name__, __version__, config
from ...core import settings


class StartupDialog(QDialog):
    def __init__(self, parent: QWidget | None = None):
        super().__init__(parent)
        self.setWindowTitle(__app_name__)
        self.setMinimumSize(560, 460)
        self.selected_path: str | None = None
        self.seed_sample = False

        root = QVBoxLayout(self)
        root.setContentsMargins(28, 26, 28, 26)
        root.setSpacing(14)

        title = QLabel(__app_name__)
        title.setStyleSheet("font-size:22px; font-weight:800;")
        sub = QLabel(f"Offline commissioning management · v{__version__}")
        sub.setStyleSheet("color:#8A97AB;")
        root.addWidget(title)
        root.addWidget(sub)

        btn_row = QHBoxLayout()
        btn_row.setSpacing(10)
        new_btn = QPushButton("＋ Create New Project")
        new_btn.setMinimumHeight(46)
        new_btn.clicked.connect(self._create_new)
        open_btn = QPushButton("📂 Open Existing")
        open_btn.setObjectName("Ghost")
        open_btn.setMinimumHeight(46)
        open_btn.clicked.connect(self._open_existing)
        sample_btn = QPushButton("✨ New with Sample Data")
        sample_btn.setObjectName("Ghost")
        sample_btn.setMinimumHeight(46)
        sample_btn.clicked.connect(self._create_sample)
        btn_row.addWidget(new_btn)
        btn_row.addWidget(open_btn)
        btn_row.addWidget(sample_btn)
        root.addLayout(btn_row)

        root.addWidget(QLabel("Recent projects"))
        self.recent_list = QListWidget()
        self.recent_list.itemDoubleClicked.connect(self._open_recent)
        for p in settings.recent_projects():
            item = QListWidgetItem(f"{Path(p).stem}\n{p}")
            item.setData(Qt.UserRole, p)
            self.recent_list.addItem(item)
        if self.recent_list.count() == 0:
            self.recent_list.addItem("No recent projects yet.")
            self.recent_list.setEnabled(False)
        root.addWidget(self.recent_list, 1)

        bottom = QHBoxLayout()
        bottom.addStretch(1)
        open_sel = QPushButton("Open Selected")
        open_sel.clicked.connect(self._open_selected)
        bottom.addWidget(open_sel)
        root.addLayout(bottom)

    # --- actions ------------------------------------------------------------
    def _new_path(self) -> str | None:
        name, ok = QInputDialog.getText(self, "New Project", "Project name:")
        if not ok or not name.strip():
            return None
        config.ensure_dirs()
        safe = "".join(c for c in name if c.isalnum() or c in " -_").strip() or "Project"
        return str(config.DATABASE_DIR / f"{safe}{config.DB_SUFFIX}")

    def _create_new(self) -> None:
        path = self._new_path()
        if path:
            self.selected_path = path
            self.seed_sample = False
            self.accept()

    def _create_sample(self) -> None:
        path = self._new_path()
        if path:
            self.selected_path = path
            self.seed_sample = True
            self.accept()

    def _open_existing(self) -> None:
        path, _ = QFileDialog.getOpenFileName(
            self, "Open Project", str(config.DATABASE_DIR),
            f"Project database (*{config.DB_SUFFIX} *.db *.sqlite);;All files (*.*)")
        if path:
            self.selected_path = path
            self.accept()

    def _open_recent(self, item: QListWidgetItem) -> None:
        path = item.data(Qt.UserRole)
        if path:
            self.selected_path = path
            self.accept()

    def _open_selected(self) -> None:
        item = self.recent_list.currentItem()
        if item and item.data(Qt.UserRole):
            self.selected_path = item.data(Qt.UserRole)
            self.accept()
        else:
            QMessageBox.information(self, "Open", "Select a recent project, or create/open one above.")
