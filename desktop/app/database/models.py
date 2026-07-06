"""SQLAlchemy ORM models — the full commissioning-management schema.

One SQLite file == one project. The schema covers every module in the app:
project meta, PMCCs, equipment, procedures, preservation, manpower,
consumables, special (re)commissioning activities, punch list, Kanban tasks,
proposal comparison line items, client remarks and risks.

The models are intentionally flat and denormalised (area/system/subsystem are
plain strings) — commissioning source data arrives that way in Excel, and it
keeps import/export and free-text filtering simple and fast.
"""

from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import Date, DateTime, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


# --- controlled vocabularies (kept as plain strings in the DB) --------------
class Status:
    """Status value sets used across modules and for dashboard roll-ups."""

    PMCC = ["Not Started", "In Progress", "Completed", "Critical", "Blocked", "On Hold"]
    KANBAN = ["Not Started", "Ready", "In Progress", "Waiting", "Blocked", "Completed"]
    EQUIPMENT = [
        "Installed", "Aligned", "Preserved", "Flushed", "Hydrotested",
        "Ready", "Commissioned", "Hold", "Blocked",
    ]
    PROCEDURE = ["Draft", "Review", "Approved", "Issued", "Implemented", "Closed"]
    PRESERVATION = ["OK", "Due", "Overdue", "Completed"]
    SPECIAL = ["Not Started", "In Progress", "Completed", "Blocked", "On Hold"]
    PUNCH = ["Open", "Closed"]
    GENERIC = ["Open", "In Progress", "Completed"]


PRIORITIES = ["Critical", "High", "Medium", "Low"]
DISCIPLINES = [
    "Piping", "Mechanical", "Static Equipment", "Rotary Equipment", "Electrical",
    "Instrumentation", "Process", "Civil", "Telecom", "Multi-discipline",
]
EQUIPMENT_TYPES = ["Static", "Rotary", "Electrical", "Instrument"]
MANPOWER_AGENCIES = ["L&T", "Subcontractor", "External Agency"]


class TimestampMixin:
    """Created/updated audit columns; ``updated_at`` drives auto-save feedback."""

    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), onupdate=func.now()
    )


class Project(Base, TimestampMixin):
    __tablename__ = "project"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(200), default="Commissioning Project")
    client: Mapped[str] = mapped_column(String(200), default="")
    location: Mapped[str] = mapped_column(String(200), default="")
    contractor: Mapped[str] = mapped_column(String(200), default="")
    start_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    target_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    # Planned (target) overall % for "ahead/behind schedule" on the dashboard.
    target_progress: Mapped[float] = mapped_column(Float, default=0.0)
    notes: Mapped[str] = mapped_column(Text, default="")


class PMCC(Base, TimestampMixin):
    __tablename__ = "pmcc"

    id: Mapped[int] = mapped_column(primary_key=True)
    number: Mapped[str] = mapped_column(String(60), default="")
    description: Mapped[str] = mapped_column(String(400), default="")
    subsystem: Mapped[str] = mapped_column(String(120), default="")
    system: Mapped[str] = mapped_column(String(120), default="")
    area: Mapped[str] = mapped_column(String(120), default="")
    discipline: Mapped[str] = mapped_column(String(80), default="")
    contractor: Mapped[str] = mapped_column(String(120), default="")
    status: Mapped[str] = mapped_column(String(40), default="Not Started")
    priority: Mapped[str] = mapped_column(String(20), default="Medium")
    completion: Mapped[float] = mapped_column(Float, default=0.0)  # 0..100
    target_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    actual_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    remarks: Mapped[str] = mapped_column(Text, default="")


class Equipment(Base, TimestampMixin):
    __tablename__ = "equipment"

    id: Mapped[int] = mapped_column(primary_key=True)
    tag_number: Mapped[str] = mapped_column(String(80), default="")
    description: Mapped[str] = mapped_column(String(400), default="")
    area: Mapped[str] = mapped_column(String(120), default="")
    subsystem: Mapped[str] = mapped_column(String(120), default="")
    system: Mapped[str] = mapped_column(String(120), default="")
    discipline: Mapped[str] = mapped_column(String(80), default="")
    equipment_type: Mapped[str] = mapped_column(String(40), default="Static")
    status: Mapped[str] = mapped_column(String(40), default="Installed")
    completion: Mapped[float] = mapped_column(Float, default=0.0)
    remarks: Mapped[str] = mapped_column(Text, default="")


class Procedure(Base, TimestampMixin):
    __tablename__ = "procedure"

    id: Mapped[int] = mapped_column(primary_key=True)
    number: Mapped[str] = mapped_column(String(80), default="")
    title: Mapped[str] = mapped_column(String(400), default="")
    revision: Mapped[str] = mapped_column(String(20), default="0")
    responsible: Mapped[str] = mapped_column(String(120), default="")
    status: Mapped[str] = mapped_column(String(40), default="Draft")
    remarks: Mapped[str] = mapped_column(Text, default="")


class Preservation(Base, TimestampMixin):
    __tablename__ = "preservation"

    id: Mapped[int] = mapped_column(primary_key=True)
    tag_number: Mapped[str] = mapped_column(String(80), default="")
    description: Mapped[str] = mapped_column(String(400), default="")
    area: Mapped[str] = mapped_column(String(120), default="")
    preservation_type: Mapped[str] = mapped_column(String(120), default="")
    frequency_days: Mapped[int] = mapped_column(Integer, default=30)
    last_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    next_due: Mapped[date | None] = mapped_column(Date, nullable=True)
    status: Mapped[str] = mapped_column(String(40), default="OK")
    remarks: Mapped[str] = mapped_column(Text, default="")


class Manpower(Base, TimestampMixin):
    __tablename__ = "manpower"

    id: Mapped[int] = mapped_column(primary_key=True)
    log_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    agency: Mapped[str] = mapped_column(String(80), default="L&T")
    department: Mapped[str] = mapped_column(String(120), default="")
    discipline: Mapped[str] = mapped_column(String(80), default="")
    area: Mapped[str] = mapped_column(String(120), default="")
    count: Mapped[int] = mapped_column(Integer, default=0)
    remarks: Mapped[str] = mapped_column(Text, default="")


class Consumable(Base, TimestampMixin):
    __tablename__ = "consumable"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(200), default="")
    unit: Mapped[str] = mapped_column(String(40), default="")
    required: Mapped[float] = mapped_column(Float, default=0.0)
    available: Mapped[float] = mapped_column(Float, default=0.0)
    consumed: Mapped[float] = mapped_column(Float, default=0.0)
    remarks: Mapped[str] = mapped_column(Text, default="")

    @property
    def balance(self) -> float:
        return round(self.available - self.consumed, 2)


class SpecialActivity(Base, TimestampMixin):
    __tablename__ = "special_activity"

    id: Mapped[int] = mapped_column(primary_key=True)
    activity: Mapped[str] = mapped_column(String(400), default="")
    area: Mapped[str] = mapped_column(String(120), default="")
    subsystem: Mapped[str] = mapped_column(String(120), default="")
    priority: Mapped[str] = mapped_column(String(20), default="Medium")
    responsible: Mapped[str] = mapped_column(String(120), default="")
    status: Mapped[str] = mapped_column(String(40), default="Not Started")
    dependencies: Mapped[str] = mapped_column(String(400), default="")
    completion: Mapped[float] = mapped_column(Float, default=0.0)
    remarks: Mapped[str] = mapped_column(Text, default="")


class Punch(Base, TimestampMixin):
    __tablename__ = "punch"

    id: Mapped[int] = mapped_column(primary_key=True)
    number: Mapped[str] = mapped_column(String(80), default="")
    description: Mapped[str] = mapped_column(String(400), default="")
    category: Mapped[str] = mapped_column(String(10), default="B")  # A / B / C
    area: Mapped[str] = mapped_column(String(120), default="")
    subsystem: Mapped[str] = mapped_column(String(120), default="")
    system: Mapped[str] = mapped_column(String(120), default="")
    discipline: Mapped[str] = mapped_column(String(80), default="")
    priority: Mapped[str] = mapped_column(String(20), default="Medium")
    status: Mapped[str] = mapped_column(String(20), default="Open")
    raised_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    closed_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    remarks: Mapped[str] = mapped_column(Text, default="")


class Task(Base, TimestampMixin):
    """A Kanban card."""

    __tablename__ = "task"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(300), default="")
    status: Mapped[str] = mapped_column(String(40), default="Not Started")
    priority: Mapped[str] = mapped_column(String(20), default="Medium")
    owner: Mapped[str] = mapped_column(String(120), default="")
    area: Mapped[str] = mapped_column(String(120), default="")
    subsystem: Mapped[str] = mapped_column(String(120), default="")
    system: Mapped[str] = mapped_column(String(120), default="")
    start_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    finish_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    progress: Mapped[float] = mapped_column(Float, default=0.0)
    order_index: Mapped[int] = mapped_column(Integer, default=0)  # position in column
    remarks: Mapped[str] = mapped_column(Text, default="")


class ProposalItem(Base, TimestampMixin):
    """A line item for the proposal-vs-actual comparison module."""

    __tablename__ = "proposal_item"

    id: Mapped[int] = mapped_column(primary_key=True)
    item: Mapped[str] = mapped_column(String(300), default="")
    category: Mapped[str] = mapped_column(String(120), default="")
    proposed: Mapped[float] = mapped_column(Float, default=0.0)
    current: Mapped[float] = mapped_column(Float, default=0.0)
    completed: Mapped[float] = mapped_column(Float, default=0.0)
    cost: Mapped[float] = mapped_column(Float, default=0.0)
    resources: Mapped[float] = mapped_column(Float, default=0.0)
    duration: Mapped[float] = mapped_column(Float, default=0.0)
    remarks: Mapped[str] = mapped_column(Text, default="")

    @property
    def pending(self) -> float:
        return round(self.proposed - self.completed, 2)

    @property
    def difference(self) -> float:
        return round(self.current - self.proposed, 2)


class ClientRemark(Base, TimestampMixin):
    __tablename__ = "client_remark"

    id: Mapped[int] = mapped_column(primary_key=True)
    log_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    remark: Mapped[str] = mapped_column(Text, default="")
    raised_by: Mapped[str] = mapped_column(String(120), default="")
    status: Mapped[str] = mapped_column(String(40), default="Open")


class Risk(Base, TimestampMixin):
    __tablename__ = "risk"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(300), default="")
    severity: Mapped[str] = mapped_column(String(20), default="Medium")
    mitigation: Mapped[str] = mapped_column(Text, default="")
    owner: Mapped[str] = mapped_column(String(120), default="")
    status: Mapped[str] = mapped_column(String(40), default="Open")


class ProgressSnapshot(Base):
    """A daily snapshot of overall % — powers the S-curve / trend charts."""

    __tablename__ = "progress_snapshot"

    id: Mapped[int] = mapped_column(primary_key=True)
    snap_date: Mapped[date] = mapped_column(Date)
    actual: Mapped[float] = mapped_column(Float, default=0.0)
    target: Mapped[float] = mapped_column(Float, default=0.0)


# Registry used by the generic table pages, importer and exporter so a single
# component can serve every module. Order controls sidebar/report order.
ENTITY_REGISTRY: dict[str, type] = {
    "pmcc": PMCC,
    "equipment": Equipment,
    "procedure": Procedure,
    "preservation": Preservation,
    "manpower": Manpower,
    "consumable": Consumable,
    "special_activity": SpecialActivity,
    "punch": Punch,
    "task": Task,
    "proposal_item": ProposalItem,
    "client_remark": ClientRemark,
    "risk": Risk,
}
