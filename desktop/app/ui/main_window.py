"""Application shell: sidebar navigation, header, stacked module pages,
theme toggle, global search and the close-with-report workflow.
"""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QApplication, QButtonGroup, QFrame, QHBoxLayout, QLabel, QLineEdit,
    QMessageBox, QPushButton, QStackedWidget, QVBoxLayout, QWidget,
)

from .. import __app_name__, __version__
from ..core import reporting, settings
from ..database.db import db
from .pages.dashboard import Dashboard
from .pages.kanban import KanbanBoard
from .pages.reports import ReportsPage
from .theme import build_qss
from .widgets.table_page import TablePage

# (nav id, label, kind, entity_key)
NAV = [
    ("dashboard", "📊  Executive Dashboard", "dashboard", None),
    ("kanban", "🗂  Kanban Board", "kanban", None),
    ("pmcc", "🧩  PMCC", "table", "pmcc"),
    ("equipment", "⚙  Equipment", "table", "equipment"),
    ("special", "🧪  Special Activities", "table", "special_activity"),
    ("preservation", "🛡  Preservation", "table", "preservation"),
    ("procedure", "📄  Procedures", "table", "procedure"),
    ("punch", "📌  Punch List", "table", "punch"),
    ("manpower", "👷  Manpower", "table", "manpower"),
    ("consumable", "🧴  Consumables", "table", "consumable"),
    ("proposal", "📈  Proposal Comparison", "table", "proposal_item"),
    ("risk", "⚠  Risks", "table", "risk"),
    ("client", "💬  Client Remarks", "table", "client_remark"),
    ("reports", "🖨  Reports", "reports", None),
]


class MainWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setObjectName("RootBg")
        self.dark = settings.get_setting("dark_theme", True)
        self._pages: dict[str, QWidget] = {}
        self._search_pages: dict[str, TablePage] = {}
        self.dashboard: Dashboard | None = None

        self.setWindowTitle(__app_name__)
        self.resize(1360, 860)
        self._build()
        self._apply_theme()

    # --- construction -------------------------------------------------------
    def _build(self) -> None:
        root = QHBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)
        root.addWidget(self._build_sidebar())

        right = QVBoxLayout()
        right.setContentsMargins(0, 0, 0, 0)
        right.setSpacing(0)
        right.addWidget(self._build_header())
        self.stack = QStackedWidget()
        right.addWidget(self.stack, 1)
        container = QWidget()
        container.setLayout(right)
        root.addWidget(container, 1)

        self._build_pages()
        self.navigate("dashboard")

    def _build_sidebar(self) -> QWidget:
        side = QFrame()
        side.setObjectName("Sidebar")
        side.setFixedWidth(240)
        lay = QVBoxLayout(side)
        lay.setContentsMargins(0, 16, 0, 12)
        lay.setSpacing(2)

        brand = QVBoxLayout()
        brand.setContentsMargins(18, 0, 18, 10)
        t = QLabel(__app_name__)
        t.setObjectName("BrandTitle")
        t.setWordWrap(True)
        s = QLabel("OIL & GAS COMMISSIONING")
        s.setObjectName("BrandSub")
        brand.addWidget(t)
        brand.addWidget(s)
        lay.addLayout(brand)

        self.nav_group = QButtonGroup(self)
        self.nav_group.setExclusive(True)
        for nav_id, label, _kind, _ek in NAV:
            btn = QPushButton(label)
            btn.setCheckable(True)
            btn.clicked.connect(lambda _=False, nid=nav_id: self.navigate(nid))
            self.nav_group.addButton(btn)
            btn._nav_id = nav_id  # type: ignore[attr-defined]
            lay.addWidget(btn)

        lay.addStretch(1)
        self.theme_btn = QPushButton("🌗  Toggle Light / Dark")
        self.theme_btn.setObjectName("Ghost")
        self.theme_btn.clicked.connect(self.toggle_theme)
        theme_wrap = QVBoxLayout()
        theme_wrap.setContentsMargins(10, 0, 10, 4)
        theme_wrap.addWidget(self.theme_btn)
        lay.addLayout(theme_wrap)
        credit = QLabel("Designed by Vaishnao Wanjari")
        credit.setObjectName("Credit")
        credit.setContentsMargins(18, 4, 18, 0)
        lay.addWidget(credit)
        return side

    def _build_header(self) -> QWidget:
        header = QFrame()
        header.setObjectName("Header")
        header.setFixedHeight(60)
        lay = QHBoxLayout(header)
        lay.setContentsMargins(18, 8, 18, 8)
        self.page_title = QLabel("Executive Dashboard")
        self.page_title.setObjectName("PageTitle")
        self.project_chip = QLabel("")
        self.project_chip.setObjectName("Chip")
        self.search = QLineEdit()
        self.search.setPlaceholderText("Global search in this module…")
        self.search.setFixedWidth(280)
        self.search.textChanged.connect(self._on_search)
        lay.addWidget(self.page_title)
        lay.addStretch(1)
        lay.addWidget(self.project_chip)
        lay.addWidget(self.search)
        return header

    def _build_pages(self) -> None:
        for nav_id, label, kind, entity_key in NAV:
            if kind == "dashboard":
                page = Dashboard()
                self.dashboard = page
            elif kind == "kanban":
                page = KanbanBoard()
                page.changed.connect(self._on_data_changed)
            elif kind == "reports":
                page = ReportsPage()
            else:
                title = label.split("  ", 1)[-1]
                page = TablePage(entity_key, title)
                page.changed.connect(self._on_data_changed)
                self._search_pages[nav_id] = page
            self._pages[nav_id] = page
            self.stack.addWidget(page)

    # --- navigation / state -------------------------------------------------
    def navigate(self, nav_id: str) -> None:
        page = self._pages.get(nav_id)
        if page is None:
            return
        self.stack.setCurrentWidget(page)
        for btn in self.nav_group.buttons():
            if getattr(btn, "_nav_id", None) == nav_id:
                btn.setChecked(True)
        label = next((l for i, l, *_ in NAV if i == nav_id), nav_id)
        self.page_title.setText(label.split("  ", 1)[-1])
        self.search.clear()
        self.search.setVisible(nav_id in self._search_pages)
        if nav_id == "dashboard" and self.dashboard is not None:
            self.dashboard.refresh()
        self._refresh_chip()

    def _on_search(self, text: str) -> None:
        cur = self.stack.currentWidget()
        if isinstance(cur, TablePage):
            cur.search.setText(text)

    def _on_data_changed(self) -> None:
        if self.dashboard is not None:
            self.dashboard.refresh()
        self._refresh_chip()

    def _refresh_chip(self) -> None:
        proj = db.project()
        name = proj.name if proj else "Project"
        self.project_chip.setText(f"📁 {name}")

    # --- theme --------------------------------------------------------------
    def _apply_theme(self) -> None:
        app = QApplication.instance()
        if app is not None:
            app.setStyleSheet(build_qss(self.dark))

    def toggle_theme(self) -> None:
        self.dark = not self.dark
        settings.set_setting("dark_theme", self.dark)
        self._apply_theme()

    # --- close workflow -----------------------------------------------------
    def closeEvent(self, event) -> None:
        box = QMessageBox(self)
        box.setWindowTitle("Close Application")
        box.setText("Generate today's report before closing?")
        box.setStandardButtons(QMessageBox.Yes | QMessageBox.No | QMessageBox.Cancel)
        box.setDefaultButton(QMessageBox.No)
        choice = box.exec()
        if choice == QMessageBox.Cancel:
            event.ignore()
            return
        if choice == QMessageBox.Yes:
            try:
                reporting.generate_pdf_report("Daily")
            except Exception:
                pass  # never block shutdown on a report error
        try:
            db.backup()   # automatic backup on every close
        except Exception:
            pass
        event.accept()
