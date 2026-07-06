"""A complete, reusable CRUD page for any registered module.

Renders a searchable/sortable table plus a toolbar (Add / Edit / Delete /
Import / Export). Because it is metadata-driven (it reads the field spec), the
same class powers PMCC, Equipment, Procedures, Punch, Manpower, Consumables,
Preservation, Special Activities, Proposal, Risks and Client Remarks.
"""

from __future__ import annotations

from datetime import date, datetime
from typing import Any

from PySide6.QtCore import (
    QAbstractTableModel, QModelIndex, QSortFilterProxyModel, Qt, Signal,
)
from PySide6.QtGui import QColor
from PySide6.QtWidgets import (
    QAbstractItemView, QFileDialog, QHBoxLayout, QHeaderView, QLabel, QLineEdit,
    QMenu, QMessageBox, QPushButton, QTableView, QVBoxLayout, QWidget,
)

from ...core import exporter, importer, repository
from ...core.columns import spec_for
from ..dialogs.record_dialog import RecordDialog
from ..theme import Palette

COLOR_FIELDS = {"status", "priority", "severity", "category"}


class EntityTableModel(QAbstractTableModel):
    def __init__(self, entity_key: str):
        super().__init__()
        self.entity_key = entity_key
        self.specs = spec_for(entity_key)
        self.rows: list[Any] = []

    def reload(self) -> None:
        self.beginResetModel()
        self.rows = repository.list_all(self.entity_key)
        self.endResetModel()

    def rowCount(self, parent=QModelIndex()) -> int:
        return 0 if parent.isValid() else len(self.rows)

    def columnCount(self, parent=QModelIndex()) -> int:
        return len(self.specs)

    def record_at(self, row: int) -> Any:
        return self.rows[row]

    def headerData(self, section, orientation, role=Qt.DisplayRole):
        if role != Qt.DisplayRole:
            return None
        if orientation == Qt.Horizontal:
            return self.specs[section].label
        return section + 1

    def data(self, index: QModelIndex, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        sp = self.specs[index.column()]
        obj = self.rows[index.row()]
        val = getattr(obj, sp.name, "")
        if role in (Qt.DisplayRole, Qt.EditRole):
            if isinstance(val, (date, datetime)):
                return val.isoformat()
            if sp.kind == "percent" and isinstance(val, (int, float)):
                return f"{val:.0f}%"
            if sp.kind == "float" and isinstance(val, (int, float)):
                return f"{val:,.2f}".rstrip("0").rstrip(".")
            return "" if val is None else str(val)
        if role == Qt.ForegroundRole and sp.name in COLOR_FIELDS:
            return QColor(Palette.status_color(str(val)))
        if role == Qt.TextAlignmentRole and sp.kind in ("int", "float", "percent"):
            return int(Qt.AlignRight | Qt.AlignVCenter)
        return None


class TablePage(QWidget):
    """A module page: title, toolbar and table with full CRUD + import/export."""

    changed = Signal()  # emitted after any data mutation so the shell can refresh

    def __init__(self, entity_key: str, title: str, parent: QWidget | None = None):
        super().__init__(parent)
        self.entity_key = entity_key
        self.title = title

        self.model = EntityTableModel(entity_key)
        self.proxy = QSortFilterProxyModel(self)
        self.proxy.setSourceModel(self.model)
        self.proxy.setFilterKeyColumn(-1)  # search all columns
        self.proxy.setFilterCaseSensitivity(Qt.CaseInsensitive)

        root = QVBoxLayout(self)
        root.setContentsMargins(18, 14, 18, 16)
        root.setSpacing(10)

        # toolbar
        bar = QHBoxLayout()
        self.count_lbl = QLabel("")
        self.count_lbl.setObjectName("Chip")
        self.search = QLineEdit()
        self.search.setPlaceholderText("Search…")
        self.search.setClearButtonEnabled(True)
        self.search.setFixedWidth(240)
        self.search.textChanged.connect(self.proxy.setFilterFixedString)
        add_btn = QPushButton("+ Add")
        edit_btn = QPushButton("Edit")
        edit_btn.setObjectName("Ghost")
        del_btn = QPushButton("Delete")
        del_btn.setObjectName("Danger")
        imp_btn = QPushButton("Import ▾")
        imp_btn.setObjectName("Ghost")
        exp_btn = QPushButton("Export ▾")
        exp_btn.setObjectName("Ghost")
        add_btn.clicked.connect(self.add_record)
        edit_btn.clicked.connect(self.edit_record)
        del_btn.clicked.connect(self.delete_records)
        imp_btn.clicked.connect(lambda: self._import_menu(imp_btn))
        exp_btn.clicked.connect(lambda: self._export_menu(exp_btn))

        bar.addWidget(self.count_lbl)
        bar.addStretch(1)
        bar.addWidget(self.search)
        bar.addWidget(add_btn)
        bar.addWidget(edit_btn)
        bar.addWidget(del_btn)
        bar.addWidget(imp_btn)
        bar.addWidget(exp_btn)
        root.addLayout(bar)

        # table
        self.table = QTableView()
        self.table.setModel(self.proxy)
        self.table.setSortingEnabled(True)
        self.table.setAlternatingRowColors(True)
        self.table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.ExtendedSelection)
        self.table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.table.verticalHeader().setVisible(False)
        self.table.doubleClicked.connect(lambda _i: self.edit_record())
        root.addWidget(self.table)

        self.reload()
        self._size_columns()

    # --- data ---------------------------------------------------------------
    def reload(self) -> None:
        self.model.reload()
        self.count_lbl.setText(f"{self.model.rowCount()} records")

    def _size_columns(self) -> None:
        header = self.table.horizontalHeader()
        for i, sp in enumerate(self.model.specs):
            self.table.setColumnWidth(i, sp.width)
        header.setStretchLastSection(True)

    def _current_record(self) -> Any | None:
        idx = self.table.currentIndex()
        if not idx.isValid():
            return None
        return self.model.record_at(self.proxy.mapToSource(idx).row())

    # --- CRUD ---------------------------------------------------------------
    def add_record(self) -> None:
        dlg = RecordDialog(self.entity_key, f"Add — {self.title}", None, self)
        if dlg.exec():
            repository.create(self.entity_key, dlg.values())
            self.reload()
            self.changed.emit()

    def edit_record(self) -> None:
        rec = self._current_record()
        if rec is None:
            QMessageBox.information(self, "Edit", "Select a row to edit.")
            return
        dlg = RecordDialog(self.entity_key, f"Edit — {self.title}", rec, self)
        if dlg.exec():
            repository.update(self.entity_key, rec.id, dlg.values())
            self.reload()
            self.changed.emit()

    def delete_records(self) -> None:
        sel = {self.proxy.mapToSource(idx).row() for idx in self.table.selectionModel().selectedRows()}
        ids = [self.model.record_at(r).id for r in sel]
        if not ids:
            QMessageBox.information(self, "Delete", "Select one or more rows to delete.")
            return
        if QMessageBox.question(self, "Delete",
                                f"Delete {len(ids)} record(s)? This cannot be undone.") != QMessageBox.Yes:
            return
        repository.delete_many(self.entity_key, ids)
        self.reload()
        self.changed.emit()

    # --- import / export ----------------------------------------------------
    def _import_menu(self, anchor: QWidget) -> None:
        menu = QMenu(self)
        menu.addAction("From Excel (.xlsx)", lambda: self._do_import("Excel (*.xlsx *.xls)"))
        menu.addAction("From CSV (.csv)", lambda: self._do_import("CSV (*.csv)"))
        menu.addAction("From JSON (.json)", lambda: self._do_import("JSON (*.json)"))
        menu.exec(anchor.mapToGlobal(anchor.rect().bottomLeft()))

    def _do_import(self, filt: str) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Import file", "", filt)
        if not path:
            return
        result = importer.import_file(self.entity_key, path)
        if result["ok"]:
            self.reload()
            self.changed.emit()
            QMessageBox.information(self, "Import", f"Imported {result['added']} record(s).")
        else:
            QMessageBox.warning(self, "Import failed", "\n".join(result["errors"]))

    def _export_menu(self, anchor: QWidget) -> None:
        menu = QMenu(self)
        menu.addAction("To Excel (.xlsx)", lambda: self._do_export("xlsx"))
        menu.addAction("To CSV (.csv)", lambda: self._do_export("csv"))
        menu.addAction("To JSON (.json)", lambda: self._do_export("json"))
        menu.exec(anchor.mapToGlobal(anchor.rect().bottomLeft()))

    def _do_export(self, ext: str) -> None:
        path, _ = QFileDialog.getSaveFileName(
            self, "Export", f"{self.entity_key}.{ext}", f"{ext.upper()} (*.{ext})")
        if not path:
            return
        try:
            if ext == "xlsx":
                exporter.export_excel(self.entity_key, path, self.title)
            elif ext == "csv":
                exporter.export_csv(self.entity_key, path)
            else:
                exporter.export_json(self.entity_key, path)
            QMessageBox.information(self, "Export", f"Saved:\n{path}")
        except Exception as exc:
            QMessageBox.warning(self, "Export failed", str(exc))
