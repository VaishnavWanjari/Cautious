"""SQLAlchemy ORM models — the SQLite schema.

Hierarchy: Project -> PMCC -> System -> Subsystem -> SNR -> Activity, with
Relationships between activities, reusable ActivityTemplates, plain-language
LogicRules, and Phase-2 constraint tables (Resource/Utility/Area/Vendor/Permit)
included now so later phases are additive rather than a migration.
"""

from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class Project(Base):
    __tablename__ = "projects"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(200))
    client: Mapped[str] = mapped_column(String(200), default="")
    location: Mapped[str] = mapped_column(String(200), default="")
    mechanical_completion_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    planned_startup_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    # working weekdays as comma-separated ISO numbers, e.g. "1,2,3,4,5"
    working_weekdays: Mapped[str] = mapped_column(String(20), default="1,2,3,4,5")
    holidays: Mapped[str] = mapped_column(Text, default="")  # comma-separated ISO dates
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    pmccs: Mapped[list["PMCC"]] = relationship(
        back_populates="project", cascade="all, delete-orphan"
    )
    logic_rules: Mapped[list["LogicRule"]] = relationship(
        back_populates="project", cascade="all, delete-orphan"
    )
    constraints: Mapped[list["Constraint"]] = relationship(
        back_populates="project", cascade="all, delete-orphan"
    )


class PMCC(Base):
    __tablename__ = "pmccs"

    id: Mapped[int] = mapped_column(primary_key=True)
    project_id: Mapped[int] = mapped_column(ForeignKey("projects.id", ondelete="CASCADE"))
    code: Mapped[str] = mapped_column(String(50))
    name: Mapped[str] = mapped_column(String(200), default="")
    area: Mapped[str] = mapped_column(String(100), default="")

    project: Mapped[Project] = relationship(back_populates="pmccs")
    systems: Mapped[list["System"]] = relationship(
        back_populates="pmcc", cascade="all, delete-orphan"
    )


class System(Base):
    __tablename__ = "systems"

    id: Mapped[int] = mapped_column(primary_key=True)
    pmcc_id: Mapped[int] = mapped_column(ForeignKey("pmccs.id", ondelete="CASCADE"))
    system_id: Mapped[str] = mapped_column(String(50))
    description: Mapped[str] = mapped_column(String(300), default="")
    priority: Mapped[int] = mapped_column(Integer, default=3)
    discipline: Mapped[str] = mapped_column(String(50), default="")
    area: Mapped[str] = mapped_column(String(100), default="")

    pmcc: Mapped[PMCC] = relationship(back_populates="systems")
    subsystems: Mapped[list["Subsystem"]] = relationship(
        back_populates="system", cascade="all, delete-orphan"
    )


class Subsystem(Base):
    __tablename__ = "subsystems"

    id: Mapped[int] = mapped_column(primary_key=True)
    system_id: Mapped[int] = mapped_column(ForeignKey("systems.id", ondelete="CASCADE"))
    number: Mapped[str] = mapped_column(String(50))
    description: Mapped[str] = mapped_column(String(300), default="")
    priority: Mapped[int] = mapped_column(Integer, default=3)
    discipline: Mapped[str] = mapped_column(String(50), default="")
    area: Mapped[str] = mapped_column(String(100), default="")

    system: Mapped[System] = relationship(back_populates="subsystems")
    snrs: Mapped[list["SNR"]] = relationship(
        back_populates="subsystem", cascade="all, delete-orphan"
    )


class SNR(Base):
    __tablename__ = "snrs"

    id: Mapped[int] = mapped_column(primary_key=True)
    subsystem_id: Mapped[int] = mapped_column(ForeignKey("subsystems.id", ondelete="CASCADE"))
    code: Mapped[str] = mapped_column(String(50))
    description: Mapped[str] = mapped_column(String(300), default="")
    snr_type: Mapped[str] = mapped_column(String(50), default="SNR")

    subsystem: Mapped[Subsystem] = relationship(back_populates="snrs")
    activities: Mapped[list["Activity"]] = relationship(
        back_populates="snr", cascade="all, delete-orphan"
    )


class Activity(Base):
    __tablename__ = "activities"

    id: Mapped[int] = mapped_column(primary_key=True)
    snr_id: Mapped[int] = mapped_column(ForeignKey("snrs.id", ondelete="CASCADE"))
    template_id: Mapped[int | None] = mapped_column(
        ForeignKey("activity_templates.id", ondelete="SET NULL"), nullable=True
    )
    activity_id: Mapped[str] = mapped_column(String(50))
    name: Mapped[str] = mapped_column(String(200))
    duration: Mapped[int] = mapped_column(Integer, default=1)  # working days
    discipline: Mapped[str] = mapped_column(String(50), default="")
    area: Mapped[str] = mapped_column(String(100), default="")
    priority: Mapped[int] = mapped_column(Integer, default=3)
    status: Mapped[str] = mapped_column(String(30), default="Not Started")
    progress: Mapped[float] = mapped_column(Float, default=0.0)

    # cached schedule results (recomputed by the engine)
    es: Mapped[int | None] = mapped_column(Integer, nullable=True)
    ef: Mapped[int | None] = mapped_column(Integer, nullable=True)
    ls: Mapped[int | None] = mapped_column(Integer, nullable=True)
    lf: Mapped[int | None] = mapped_column(Integer, nullable=True)
    total_float: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_critical: Mapped[bool] = mapped_column(Boolean, default=False)
    start_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    finish_date: Mapped[date | None] = mapped_column(Date, nullable=True)

    # optional persisted canvas position for the network editor
    pos_x: Mapped[float | None] = mapped_column(Float, nullable=True)
    pos_y: Mapped[float | None] = mapped_column(Float, nullable=True)

    snr: Mapped[SNR] = relationship(back_populates="activities")


class Relationship(Base):
    __tablename__ = "relationships"

    id: Mapped[int] = mapped_column(primary_key=True)
    project_id: Mapped[int] = mapped_column(ForeignKey("projects.id", ondelete="CASCADE"))
    predecessor_id: Mapped[int] = mapped_column(
        ForeignKey("activities.id", ondelete="CASCADE")
    )
    successor_id: Mapped[int] = mapped_column(
        ForeignKey("activities.id", ondelete="CASCADE")
    )
    rel_type: Mapped[str] = mapped_column(String(2), default="FS")
    lag: Mapped[int] = mapped_column(Integer, default=0)


class ActivityTemplate(Base):
    __tablename__ = "activity_templates"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(200))
    category: Mapped[str] = mapped_column(String(100), default="")
    default_duration: Mapped[int] = mapped_column(Integer, default=1)
    discipline: Mapped[str] = mapped_column(String(50), default="")
    resources: Mapped[str] = mapped_column(Text, default="")
    utilities: Mapped[str] = mapped_column(Text, default="")
    description: Mapped[str] = mapped_column(Text, default="")
    is_builtin: Mapped[bool] = mapped_column(Boolean, default=False)


class LogicRule(Base):
    __tablename__ = "logic_rules"

    id: Mapped[int] = mapped_column(primary_key=True)
    project_id: Mapped[int] = mapped_column(ForeignKey("projects.id", ondelete="CASCADE"))
    condition: Mapped[str] = mapped_column(Text)  # plain language
    action: Mapped[str] = mapped_column(Text)  # plain language
    structured: Mapped[str] = mapped_column(Text, default="")  # JSON boolean tree
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)

    project: Mapped[Project] = relationship(back_populates="logic_rules")


class Constraint(Base):
    """Resource / utility / area / vendor / permit constraint (Phase-2 solving)."""

    __tablename__ = "constraints"

    id: Mapped[int] = mapped_column(primary_key=True)
    project_id: Mapped[int] = mapped_column(ForeignKey("projects.id", ondelete="CASCADE"))
    constraint_type: Mapped[str] = mapped_column(String(30))
    name: Mapped[str] = mapped_column(String(200))
    capacity: Mapped[float] = mapped_column(Float, default=1.0)
    available: Mapped[bool] = mapped_column(Boolean, default=True)
    notes: Mapped[str] = mapped_column(Text, default="")

    project: Mapped[Project] = relationship(back_populates="constraints")
