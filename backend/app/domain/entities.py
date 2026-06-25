"""Framework-free domain entities used by the scheduling engine.

These are plain dataclasses decoupled from the ORM and the web layer so the
scheduler can be unit-tested in isolation. The infrastructure layer maps ORM
rows into these, runs the engine, and writes results back.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date

from .enums import RelationType


@dataclass
class ActivityNode:
    """A schedulable activity within the network."""

    id: str
    name: str
    duration: int  # working days, >= 1
    discipline: str = ""
    status: str = "Not Started"
    priority: int = 3
    area: str = ""

    # computed by the scheduler (working-day offsets + dates)
    es: int | None = None  # early start (working-day index, 0-based)
    ef: int | None = None  # early finish
    ls: int | None = None  # late start
    lf: int | None = None  # late finish
    total_float: int | None = None
    is_critical: bool = False
    start_date: date | None = None
    finish_date: date | None = None


@dataclass
class Edge:
    """A precedence relationship between two activities."""

    predecessor_id: str
    successor_id: str
    rel_type: RelationType = RelationType.FS
    lag: int = 0  # working days; negative = lead


@dataclass
class ScheduleResult:
    """Output of a scheduling run."""

    activities: list[ActivityNode] = field(default_factory=list)
    critical_path: list[str] = field(default_factory=list)
    project_start: date | None = None
    project_finish: date | None = None
    warnings: list[str] = field(default_factory=list)
