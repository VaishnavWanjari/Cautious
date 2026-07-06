"""Executive Dashboard — the landing screen.

A scrollable board of animated KPI cards and native Qt charts, all computed
live from the open project. Refreshes whenever any module changes.
"""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QFrame, QGridLayout, QHBoxLayout, QLabel, QScrollArea, QVBoxLayout, QWidget,
)

from ...core import metrics
from ..theme import Palette
from ..widgets import charts
from ..widgets.kpi_card import KpiCard


def _panel(title: str, inner: QWidget, min_h: int = 260) -> QFrame:
    frame = QFrame()
    frame.setObjectName("Panel")
    frame.setMinimumHeight(min_h)
    lay = QVBoxLayout(frame)
    lay.setContentsMargins(14, 12, 14, 12)
    lay.setSpacing(8)
    head = QLabel(title)
    head.setStyleSheet("font-weight:700; font-size:13px;")
    lay.addWidget(head)
    lay.addWidget(inner, 1)
    return frame


def _list_panel(title: str, items: list[str], empty: str) -> QFrame:
    inner = QWidget()
    lay = QVBoxLayout(inner)
    lay.setContentsMargins(0, 0, 0, 0)
    lay.setSpacing(6)
    if not items:
        lbl = QLabel(empty)
        lbl.setStyleSheet(f"color:{Palette.status_color('')};")
        lay.addWidget(lbl)
    for text in items:
        row = QLabel("•  " + text)
        row.setWordWrap(True)
        lay.addWidget(row)
    lay.addStretch(1)
    return _panel(title, inner, min_h=170)


class Dashboard(QWidget):
    def __init__(self, parent: QWidget | None = None):
        super().__init__(parent)
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QFrame.NoShape)
        outer.addWidget(self.scroll)
        self.refresh()

    def refresh(self) -> None:
        m = metrics.compute_dashboard()
        content = QWidget()
        content.setObjectName("RootBg")
        v = QVBoxLayout(content)
        v.setContentsMargins(18, 16, 18, 20)
        v.setSpacing(14)

        # --- KPI cards -------------------------------------------------------
        trend = "Ahead of schedule" if m.schedule_variance >= 0 else "Behind schedule"
        cards = [
            KpiCard("Overall Progress", m.overall_progress, "%", Palette.PRIMARY,
                    sub=f"Target {m.target_progress:.1f}%", is_float=True),
            KpiCard("Schedule Variance", m.schedule_variance, "%",
                    Palette.OK if m.schedule_variance >= 0 else Palette.DANGER,
                    sub=trend, is_float=True),
            KpiCard("Daily / Weekly / Monthly", f"{m.daily_progress:+.1f}%",
                    accent=Palette.TEAL, sub=f"W {m.weekly_progress:+.1f}%  ·  M {m.monthly_progress:+.1f}%"),
            KpiCard("PMCCs", m.pmcc_total, accent=Palette.PRIMARY,
                    sub=f"{m.pmcc_completed} completed · {m.pmcc_pending} pending"),
            KpiCard("Critical PMCCs", m.pmcc_critical, accent=Palette.CRITICAL,
                    sub=f"{m.pmcc_blocked} blocked"),
            KpiCard("Open Punches", m.punch_open, accent=Palette.DANGER,
                    sub=f"{m.punch_closed} closed · {m.punch_critical} critical"),
            KpiCard("Equipment Commissioned", m.equipment_commissioned, accent=Palette.OK,
                    sub=f"of {m.equipment_total}"),
            KpiCard("Procedures Closed", m.procedures_closed, accent=Palette.INFO,
                    sub=f"of {m.procedures_total}"),
            KpiCard("Special Activities", m.special_completed, accent=Palette.ACCENT,
                    sub=f"of {m.special_total} completed"),
            KpiCard("Manpower Today", m.manpower_today, accent=Palette.TEAL,
                    sub=f"{m.manpower_total} logged"),
            KpiCard("Consumables Low-Stock", m.consumables_low, accent=Palette.WARN,
                    sub="items at/below reorder"),
        ]
        grid = QGridLayout()
        grid.setSpacing(12)
        per_row = 4
        for i, card in enumerate(cards):
            grid.addWidget(card, i // per_row, i % per_row)
        v.addLayout(grid)

        # --- charts row 1 ----------------------------------------------------
        row1 = QHBoxLayout()
        row1.setSpacing(12)
        row1.addWidget(_panel("PMCC Status", charts.donut(
            "", m.pmcc_status_counts or {"No data": 1}, color_by_status=True)), 1)
        row1.addWidget(_panel("Equipment by Type", charts.pie(
            "", m.equipment_by_type or {"No data": 1})), 1)
        row1.addWidget(_panel("Overall vs Target", charts.gauge(
            "", m.overall_progress, Palette.PRIMARY)), 1)
        v.addLayout(row1)

        # --- charts row 2 ----------------------------------------------------
        row2 = QHBoxLayout()
        row2.setSpacing(12)
        row2.addWidget(_panel("Progress S-Curve (Actual vs Target)", charts.scurve(
            "", m.scurve or [("", 0, 0)])), 2)
        row2.addWidget(_panel("Discipline-wise % Complete", charts.hbar(
            "", m.by_discipline or {"No data": 0})), 1)
        v.addLayout(row2)

        # --- charts row 3 ----------------------------------------------------
        row3 = QHBoxLayout()
        row3.setSpacing(12)
        row3.addWidget(_panel("Area-wise % Complete", charts.hbar(
            "", m.by_area or {"No data": 0}, accent=Palette.TEAL)), 1)
        row3.addWidget(_panel("System-wise % Complete", charts.hbar(
            "", m.by_system or {"No data": 0}, accent=Palette.ACCENT)), 1)
        v.addLayout(row3)

        # --- narrative panels ------------------------------------------------
        row4 = QHBoxLayout()
        row4.setSpacing(12)
        row4.addWidget(_list_panel("Client Remarks", m.client_remarks, "No open client remarks."), 1)
        row4.addWidget(_list_panel(
            "Major Risks", [f"[{sev}] {t}" for t, sev in m.risks], "No open risks."), 1)
        row4.addWidget(_list_panel(
            "Upcoming Activities", [f"{a} — target {b}" for a, b in m.upcoming], "Nothing upcoming."), 1)
        v.addLayout(row4)

        v.addStretch(1)
        self.scroll.setWidget(content)
