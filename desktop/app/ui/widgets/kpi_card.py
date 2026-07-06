"""Animated KPI card used across the Executive Dashboard.

A rounded surface with a big value, an uppercase label, an optional sub-line
and a coloured accent bar. The value animates up on show for a premium feel.
"""

from __future__ import annotations

from PySide6.QtCore import Property, QEasingCurve, QPropertyAnimation, Qt
from PySide6.QtGui import QColor, QPainter
from PySide6.QtWidgets import (
    QFrame, QGraphicsDropShadowEffect, QHBoxLayout, QLabel, QVBoxLayout, QWidget,
)

from ..theme import Palette


class KpiCard(QFrame):
    def __init__(self, label: str, value: float | int | str = 0,
                 suffix: str = "", accent: str = Palette.PRIMARY,
                 sub: str = "", is_float: bool = False, parent: QWidget | None = None):
        super().__init__(parent)
        self.setObjectName("Card")
        self.setMinimumWidth(180)
        self.setMinimumHeight(96)
        self._suffix = suffix
        self._is_float = is_float
        self._display = 0.0
        self._target = float(value) if _is_number(value) else 0.0
        self._static_text = None if _is_number(value) else str(value)

        # soft shadow for depth
        shadow = QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(24)
        shadow.setOffset(0, 6)
        shadow.setColor(QColor(0, 0, 0, 55))
        self.setGraphicsEffect(shadow)

        root = QHBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        bar = QFrame()
        bar.setFixedWidth(6)
        bar.setStyleSheet(f"background:{accent}; border-top-left-radius:14px; border-bottom-left-radius:14px;")
        root.addWidget(bar)

        body = QVBoxLayout()
        body.setContentsMargins(16, 12, 16, 12)
        body.setSpacing(3)
        self._value_lbl = QLabel(self._static_text or "0")
        self._value_lbl.setObjectName("CardValue")
        self._value_lbl.setStyleSheet(f"color:{accent};")
        self._label_lbl = QLabel(label.upper())
        self._label_lbl.setObjectName("CardLabel")
        self._sub_lbl = QLabel(sub)
        self._sub_lbl.setObjectName("CardSub")
        self._sub_lbl.setVisible(bool(sub))
        body.addWidget(self._value_lbl)
        body.addWidget(self._label_lbl)
        body.addWidget(self._sub_lbl)
        body.addStretch(1)
        root.addLayout(body, 1)

        if self._static_text is None:
            self._anim = QPropertyAnimation(self, b"display", self)
            self._anim.setDuration(650)
            self._anim.setStartValue(0.0)
            self._anim.setEndValue(self._target)
            self._anim.setEasingCurve(QEasingCurve.OutCubic)
            self._anim.start()

    def set_sub(self, text: str) -> None:
        self._sub_lbl.setText(text)
        self._sub_lbl.setVisible(bool(text))

    def get_display(self) -> float:
        return self._display

    def set_display(self, v: float) -> None:
        self._display = v
        if self._is_float:
            self._value_lbl.setText(f"{v:.1f}{self._suffix}")
        else:
            self._value_lbl.setText(f"{int(round(v))}{self._suffix}")

    display = Property(float, get_display, set_display)


def _is_number(v) -> bool:
    return isinstance(v, (int, float))
