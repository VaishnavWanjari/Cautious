"""A generic Add/Edit dialog built automatically from a module's field spec.

One dialog serves every module: it reads ``spec_for(entity_key)`` and renders
the right editor per field kind (text, choice, date, number, %). It returns a
coerced values dict ready for the repository.
"""

from __future__ import annotations

from datetime import date
from typing import Any

from PySide6.QtCore import QDate, Qt
from PySide6.QtWidgets import (
    QComboBox, QDateEdit, QDialog, QDialogButtonBox, QDoubleSpinBox, QFormLayout,
    QLineEdit, QPlainTextEdit, QSpinBox, QVBoxLayout, QWidget,
)

from ...core import repository
from ...core.columns import FieldSpec, spec_for


class RecordDialog(QDialog):
    def __init__(self, entity_key: str, title: str,
                 record: Any | None = None, parent: QWidget | None = None):
        super().__init__(parent)
        self.entity_key = entity_key
        self.setWindowTitle(title)
        self.setMinimumWidth(460)
        self._editors: dict[str, QWidget] = {}

        root = QVBoxLayout(self)
        form = QFormLayout()
        form.setLabelAlignment(Qt.AlignRight)
        form.setSpacing(9)

        for sp in spec_for(entity_key):
            if sp.read_only:
                continue
            editor = self._make_editor(sp, record)
            self._editors[sp.name] = editor
            form.addRow(sp.label, editor)
        root.addLayout(form)

        buttons = QDialogButtonBox(QDialogButtonBox.Save | QDialogButtonBox.Cancel)
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        root.addWidget(buttons)

    # --- editor construction ------------------------------------------------
    def _make_editor(self, sp: FieldSpec, record: Any | None) -> QWidget:
        cur = getattr(record, sp.name, None) if record is not None else None
        if sp.kind == "choice":
            w = QComboBox()
            w.addItems(sp.choices)
            if cur:
                idx = w.findText(str(cur))
                if idx >= 0:
                    w.setCurrentIndex(idx)
            return w
        if sp.kind == "date":
            w = QDateEdit()
            w.setCalendarPopup(True)
            w.setDisplayFormat("yyyy-MM-dd")
            w.setSpecialValueText(" ")
            w.setDate(QDate(cur.year, cur.month, cur.day) if isinstance(cur, date) else QDate.currentDate())
            return w
        if sp.kind == "int":
            w = QSpinBox()
            w.setRange(0, 1_000_000)
            w.setValue(int(cur) if cur is not None else 0)
            return w
        if sp.kind in ("float", "percent"):
            w = QDoubleSpinBox()
            w.setRange(0, 1_000_000_000)
            w.setDecimals(1 if sp.kind == "percent" else 2)
            if sp.kind == "percent":
                w.setRange(0, 100)
                w.setSuffix(" %")
            w.setValue(float(cur) if cur is not None else 0.0)
            return w
        if sp.kind == "longtext":
            w = QPlainTextEdit()
            w.setFixedHeight(64)
            w.setPlainText(str(cur) if cur else "")
            return w
        w = QLineEdit()
        w.setText(str(cur) if cur else "")
        return w

    # --- result -------------------------------------------------------------
    def values(self) -> dict[str, Any]:
        out: dict[str, Any] = {}
        kinds = {s.name: s.kind for s in spec_for(self.entity_key)}
        for name, w in self._editors.items():
            kind = kinds.get(name, "text")
            if isinstance(w, QComboBox):
                raw = w.currentText()
            elif isinstance(w, QDateEdit):
                d = w.date()
                raw = f"{d.year():04d}-{d.month():02d}-{d.day():02d}"
            elif isinstance(w, QSpinBox):
                raw = w.value()
            elif isinstance(w, QDoubleSpinBox):
                raw = w.value()
            elif isinstance(w, QPlainTextEdit):
                raw = w.toPlainText()
            else:
                raw = w.text()
            out[name] = repository.coerce(kind, raw)
        return out
