"""Native offline charts built on Qt Charts (no web engine, no internet).

Factory functions return themed ``QChartView`` widgets for the dashboard:
donut, pie, horizontal/vertical bar, gauge and an S-curve line chart.
"""

from __future__ import annotations

from PySide6.QtCharts import (
    QBarCategoryAxis, QBarSet, QChart, QChartView, QHorizontalBarSeries,
    QLineSeries, QPieSeries, QValueAxis,
)
from PySide6.QtCore import QMargins, Qt
from PySide6.QtGui import QColor, QPainter

from ..theme import Palette


def _new_chart(title: str) -> QChart:
    chart = QChart()
    chart.setTitle(title)
    chart.setBackgroundVisible(False)
    chart.setMargins(QMargins(0, 0, 0, 0))
    chart.setAnimationOptions(QChart.SeriesAnimations)
    chart.legend().setVisible(True)
    chart.legend().setAlignment(Qt.AlignBottom)
    chart.legend().setLabelColor(QColor("#8A97AB"))
    chart.setTitleBrush(QColor("#8A97AB"))
    return chart


def _view(chart: QChart) -> QChartView:
    view = QChartView(chart)
    view.setRenderHint(QPainter.Antialiasing)
    view.setStyleSheet("background: transparent; border: none;")
    view.setMinimumHeight(220)
    return view


def donut(title: str, data: dict[str, float], hole: float = 0.55,
          color_by_status: bool = False) -> QChartView:
    chart = _new_chart(title)
    series = QPieSeries()
    series.setHoleSize(hole)
    for i, (k, v) in enumerate(data.items()):
        if not v:
            continue
        sl = series.append(f"{k} ({int(v) if float(v).is_integer() else v})", float(v))
        color = Palette.status_color(k) if color_by_status else Palette.SERIES[i % len(Palette.SERIES)]
        sl.setColor(QColor(color))
        sl.setLabelVisible(False)
        sl.setBorderWidth(0)
    chart.addSeries(series)
    return _view(chart)


def pie(title: str, data: dict[str, float], color_by_status: bool = False) -> QChartView:
    return donut(title, data, hole=0.0, color_by_status=color_by_status)


def hbar(title: str, data: dict[str, float], accent: str = Palette.PRIMARY,
         max_value: float = 100.0) -> QChartView:
    """Horizontal progress-style bars (e.g. discipline/area % complete)."""
    chart = _new_chart(title)
    chart.legend().setVisible(False)
    series = QHorizontalBarSeries()
    bar_set = QBarSet("")
    cats: list[str] = []
    for k, v in data.items():
        cats.append(str(k))
        bar_set.append(float(v))
    bar_set.setColor(QColor(accent))
    series.append(bar_set)
    chart.addSeries(series)

    axis_y = QBarCategoryAxis()
    axis_y.append(cats)
    axis_y.setLabelsColor(QColor("#8A97AB"))
    chart.addAxis(axis_y, Qt.AlignLeft)
    series.attachAxis(axis_y)

    axis_x = QValueAxis()
    axis_x.setRange(0, max(max_value, (max(data.values()) if data else 0) * 1.1 or 1))
    axis_x.setLabelsColor(QColor("#8A97AB"))
    axis_x.setGridLineColor(QColor("#26324A"))
    chart.addAxis(axis_x, Qt.AlignBottom)
    series.attachAxis(axis_x)
    return _view(chart)


def scurve(title: str, series_data: list[tuple[str, float, float]]) -> QChartView:
    """Actual-vs-target S-curve from (date, actual, target) tuples."""
    chart = _new_chart(title)
    actual = QLineSeries()
    actual.setName("Actual")
    target = QLineSeries()
    target.setName("Target")
    for i, (_d, a, t) in enumerate(series_data):
        actual.append(i, a)
        target.append(i, t)
    actual.setColor(QColor(Palette.PRIMARY))
    target.setColor(QColor(Palette.ACCENT))
    chart.addSeries(actual)
    chart.addSeries(target)

    axis_x = QValueAxis()
    axis_x.setRange(0, max(1, len(series_data) - 1))
    axis_x.setLabelFormat("%d")
    axis_x.setTitleText("Days")
    axis_x.setLabelsColor(QColor("#8A97AB"))
    axis_x.setGridLineColor(QColor("#26324A"))
    axis_y = QValueAxis()
    axis_y.setRange(0, 100)
    axis_y.setLabelsColor(QColor("#8A97AB"))
    axis_y.setGridLineColor(QColor("#26324A"))
    chart.addAxis(axis_x, Qt.AlignBottom)
    chart.addAxis(axis_y, Qt.AlignLeft)
    for s in (actual, target):
        s.attachAxis(axis_x)
        s.attachAxis(axis_y)
    return _view(chart)


def gauge(title: str, value: float, accent: str = Palette.PRIMARY) -> QChartView:
    """A simple donut 'gauge' showing value vs remaining."""
    value = max(0.0, min(100.0, float(value)))
    chart = _new_chart(title)
    chart.legend().setVisible(False)
    series = QPieSeries()
    series.setHoleSize(0.68)
    done = series.append("done", value)
    done.setColor(QColor(accent))
    done.setBorderWidth(0)
    rem = series.append("rem", max(0.0001, 100 - value))
    rem.setColor(QColor("#26324A"))
    rem.setBorderWidth(0)
    chart.addSeries(series)
    return _view(chart)
