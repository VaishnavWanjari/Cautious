"""Kanban board with drag-and-drop between status columns.

Each column is a QListWidget; dragging a card to another column updates its
status in the database (auto-saved). Cards are colour-coded by priority.
"""

from __future__ import annotations

from PySide6.QtCore import QSize, Qt, Signal
from PySide6.QtGui import QColor
from PySide6.QtWidgets import (
    QAbstractItemView, QFrame, QHBoxLayout, QLabel, QListWidget, QListWidgetItem,
    QMessageBox, QPushButton, QVBoxLayout, QWidget,
)

from ...core import repository
from ...database.models import Status
from ..dialogs.record_dialog import RecordDialog
from ..theme import Palette

PRIORITY_COLOR = {
    "Critical": Palette.CRITICAL, "High": Palette.DANGER,
    "Medium": Palette.WARN, "Low": Palette.TEAL,
}
TASK_ROLE = Qt.UserRole + 1
STATUS_ROLE = Qt.UserRole + 2


class KanbanList(QListWidget):
    """A single status column that reports when a card is dropped into it."""

    dropped = Signal()

    def __init__(self, status: str, parent=None):
        super().__init__(parent)
        self.status = status
        self.setDragDropMode(QAbstractItemView.DragDrop)
        self.setDefaultDropAction(Qt.MoveAction)
        self.setSelectionMode(QAbstractItemView.SingleSelection)
        self.setSpacing(6)
        self.setUniformItemSizes(False)
        self.setResizeMode(QListWidget.Adjust)
        self.setStyleSheet("QListWidget{background:transparent;border:none;}")

    def dropEvent(self, event):
        super().dropEvent(event)
        self.dropped.emit()


class KanbanBoard(QWidget):
    changed = Signal()

    COLUMNS = Status.KANBAN

    def __init__(self, parent: QWidget | None = None):
        super().__init__(parent)
        self.lists: dict[str, KanbanList] = {}

        root = QVBoxLayout(self)
        root.setContentsMargins(18, 14, 18, 16)
        root.setSpacing(10)

        top = QHBoxLayout()
        title = QLabel("Kanban Board")
        title.setObjectName("PageTitle")
        add = QPushButton("+ Add Task")
        add.clicked.connect(self.add_task)
        top.addWidget(title)
        top.addStretch(1)
        top.addWidget(add)
        root.addLayout(top)

        cols = QHBoxLayout()
        cols.setSpacing(12)
        for status in self.COLUMNS:
            col = QFrame()
            col.setObjectName("KanbanColumn")
            cl = QVBoxLayout(col)
            cl.setContentsMargins(10, 10, 10, 10)
            cl.setSpacing(8)
            header = QLabel(status)
            header.setObjectName("KanbanColHeader")
            header.setStyleSheet(f"color:{Palette.status_color(status)};")
            lw = KanbanList(status)
            lw.dropped.connect(self._on_drop)
            lw.itemDoubleClicked.connect(self._edit_item)
            self.lists[status] = lw
            cl.addWidget(header)
            cl.addWidget(lw, 1)
            cols.addWidget(col, 1)
        root.addLayout(cols, 1)
        self.reload()

    # --- data ---------------------------------------------------------------
    def reload(self) -> None:
        for lw in self.lists.values():
            lw.clear()
        for task in repository.list_all("task", order_by="order_index"):
            self._add_card(task)

    def _add_card(self, task) -> None:
        status = task.status if task.status in self.lists else "Not Started"
        item = QListWidgetItem()
        item.setSizeHint(QSize(0, 74))
        item.setData(TASK_ROLE, task.id)
        item.setData(STATUS_ROLE, status)
        item.setText(self._card_text(task))
        color = PRIORITY_COLOR.get(task.priority, Palette.TEAL)
        item.setForeground(QColor("#E6EDF6"))
        # a subtle priority-tinted background
        bg = QColor(color)
        bg.setAlpha(38)
        item.setBackground(bg)
        item.setToolTip(f"{task.title}\nOwner: {task.owner}  ·  {task.priority}\n"
                        f"{task.area}  ·  {task.system}\nProgress: {task.progress:.0f}%")
        self.lists[status].addItem(item)

    @staticmethod
    def _card_text(task) -> str:
        bits = [f"● {task.title}"]
        meta = "   ".join(x for x in [task.priority, task.owner, task.area] if x)
        bits.append(meta)
        bits.append(f"{task.progress:.0f}%  ·  {task.system}")
        return "\n".join(bits)

    # --- interaction --------------------------------------------------------
    def _on_drop(self) -> None:
        """After any drop, reconcile every card's stored status with the column
        it now sits in, and persist the changes."""
        for status, lw in self.lists.items():
            for i in range(lw.count()):
                item = lw.item(i)
                if item.data(STATUS_ROLE) != status:
                    task_id = item.data(TASK_ROLE)
                    values = {"status": status}
                    if status == "Completed":
                        values["progress"] = 100.0
                    repository.update("task", task_id, values)
                    item.setData(STATUS_ROLE, status)
        self.changed.emit()

    def add_task(self) -> None:
        dlg = RecordDialog("task", "Add Task", None, self)
        if dlg.exec():
            repository.create("task", dlg.values())
            self.reload()
            self.changed.emit()

    def _edit_item(self, item: QListWidgetItem) -> None:
        task = repository.get("task", item.data(TASK_ROLE))
        if task is None:
            return
        dlg = RecordDialog("task", "Edit Task", task, self)
        if dlg.exec():
            repository.update("task", task.id, dlg.values())
            self.reload()
            self.changed.emit()
