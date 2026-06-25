"""Data-access helpers that bridge the ORM and the scheduling engine.

These functions load a project's activities/relationships out of SQLite into the
framework-free domain entities the engine consumes, and write computed results
back. Keeping the mapping here keeps the engine pure and the API routers thin.
"""

from __future__ import annotations

from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..domain.calendar import WorkCalendar
from ..domain.entities import ActivityNode, Edge
from ..domain.enums import RelationType
from . import models


def parse_weekdays(raw: str) -> set[int]:
    return {int(x) for x in raw.split(",") if x.strip().isdigit()}


def parse_holidays(raw: str) -> set[date]:
    out: set[date] = set()
    for token in raw.split(","):
        token = token.strip()
        if token:
            try:
                out.add(date.fromisoformat(token))
            except ValueError:
                continue
    return out


def calendar_for(project: models.Project) -> WorkCalendar:
    weekdays = parse_weekdays(project.working_weekdays) or {1, 2, 3, 4, 5}
    return WorkCalendar(working_weekdays=weekdays, holidays=parse_holidays(project.holidays))


def project_activities(session: Session, project_id: int) -> list[models.Activity]:
    """All activities belonging to a project (joined through the hierarchy)."""
    stmt = (
        select(models.Activity)
        .join(models.SNR, models.Activity.snr_id == models.SNR.id)
        .join(models.Subsystem, models.SNR.subsystem_id == models.Subsystem.id)
        .join(models.System, models.Subsystem.system_id == models.System.id)
        .join(models.PMCC, models.System.pmcc_id == models.PMCC.id)
        .where(models.PMCC.project_id == project_id)
    )
    return list(session.scalars(stmt))


def project_relationships(session: Session, project_id: int) -> list[models.Relationship]:
    stmt = select(models.Relationship).where(models.Relationship.project_id == project_id)
    return list(session.scalars(stmt))


def load_domain(
    session: Session, project_id: int
) -> tuple[list[ActivityNode], list[Edge], dict[str, models.Activity]]:
    """Load engine-ready ActivityNode/Edge lists keyed by activity primary id."""
    acts = project_activities(session, project_id)
    rels = project_relationships(session, project_id)

    nodes = [
        ActivityNode(
            id=str(a.id),
            name=a.name,
            duration=a.duration,
            code=a.activity_id,
            discipline=a.discipline,
            status=a.status,
            priority=a.priority,
            area=a.area,
        )
        for a in acts
    ]
    edges = [
        Edge(
            predecessor_id=str(r.predecessor_id),
            successor_id=str(r.successor_id),
            rel_type=RelationType(r.rel_type),
            lag=r.lag,
        )
        for r in rels
    ]
    orm_by_id = {str(a.id): a for a in acts}
    return nodes, edges, orm_by_id


def write_results(
    session: Session, nodes: list[ActivityNode], orm_by_id: dict[str, models.Activity]
) -> None:
    """Persist computed ES/EF/LS/LF/float/dates back onto the ORM rows."""
    for n in nodes:
        a = orm_by_id.get(n.id)
        if a is None:
            continue
        a.es, a.ef, a.ls, a.lf = n.es, n.ef, n.ls, n.lf
        a.total_float = n.total_float
        a.is_critical = n.is_critical
        a.start_date = n.start_date
        a.finish_date = n.finish_date
    session.commit()
