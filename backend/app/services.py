"""Application service layer used by the API routers.

Orchestrates: load domain entities from SQLite -> run the engine -> persist
results -> shape responses. Keeps routers thin and the engine pure.
"""

from __future__ import annotations

from sqlalchemy.orm import Session

from .application import network as network_app
from .application import validation as validation_app
from .application.scheduler import compute_schedule
from .domain.entities import ActivityNode, Edge
from .infrastructure import models, repositories


def _project(session: Session, project_id: int) -> models.Project:
    project = session.get(models.Project, project_id)
    if project is None:
        raise ValueError(f"Project {project_id} not found")
    return project


def run_schedule(session: Session, project_id: int) -> dict:
    """Compute the schedule, persist results, and return a response dict."""
    project = _project(session, project_id)
    nodes, edges, orm_by_id = repositories.load_domain(session, project_id)
    calendar = repositories.calendar_for(project)

    result = compute_schedule(
        nodes, edges, calendar, project.mechanical_completion_date
    )
    repositories.write_results(session, result.activities, orm_by_id)

    return {
        "activities": [
            {
                "id": int(a.id),
                "activity_id": orm_by_id[a.id].activity_id,
                "name": a.name,
                "duration": a.duration,
                "es": a.es,
                "ef": a.ef,
                "ls": a.ls,
                "lf": a.lf,
                "total_float": a.total_float,
                "is_critical": a.is_critical,
                "start_date": a.start_date,
                "finish_date": a.finish_date,
            }
            for a in result.activities
        ],
        "critical_path": [int(n) for n in result.critical_path],
        "project_start": result.project_start,
        "project_finish": result.project_finish,
        "warnings": result.warnings,
    }


def build_network(session: Session, project_id: int) -> dict:
    """Return React Flow nodes/edges, honouring persisted canvas positions."""
    _project(session, project_id)
    nodes, edges, orm_by_id = repositories.load_domain(session, project_id)

    positions: dict[str, tuple[float, float]] = {}
    for aid, orm in orm_by_id.items():
        if orm.pos_x is not None and orm.pos_y is not None:
            positions[aid] = (orm.pos_x, orm.pos_y)

    # ensure node data reflects the latest persisted schedule fields
    for n in nodes:
        orm = orm_by_id[n.id]
        n.start_date = orm.start_date
        n.finish_date = orm.finish_date
        n.total_float = orm.total_float
        n.is_critical = orm.is_critical

    return network_app.build_network(nodes, edges, positions)


def validate(session: Session, project_id: int) -> dict:
    _project(session, project_id)
    nodes, edges, _ = repositories.load_domain(session, project_id)
    warnings, errors = validation_app.validate_network(nodes, edges)
    return {"warnings": warnings, "errors": errors}


def project_summary(session: Session, project_id: int) -> dict:
    """Compact dashboard/AI summary of a project's schedule state."""
    project = _project(session, project_id)
    acts = repositories.project_activities(session, project_id)
    total = len(acts)
    completed = sum(1 for a in acts if a.status == "Completed")
    in_progress = sum(1 for a in acts if a.status == "In Progress")
    critical = sum(1 for a in acts if a.is_critical)
    return {
        "project": {
            "id": project.id,
            "name": project.name,
            "client": project.client,
            "mechanical_completion_date": project.mechanical_completion_date,
            "planned_startup_date": project.planned_startup_date,
        },
        "total_activities": total,
        "completed": completed,
        "in_progress": in_progress,
        "pending": total - completed - in_progress,
        "critical": critical,
        "activities": [
            {
                "name": a.name,
                "duration": a.duration,
                "status": a.status,
                "is_critical": a.is_critical,
                "start_date": a.start_date.isoformat() if a.start_date else None,
                "finish_date": a.finish_date.isoformat() if a.finish_date else None,
                "total_float": a.total_float,
            }
            for a in acts
        ],
    }


# expose for type hints / reuse
__all__ = ["run_schedule", "build_network", "validate", "project_summary", "ActivityNode", "Edge"]
