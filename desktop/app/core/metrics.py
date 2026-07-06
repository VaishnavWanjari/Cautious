"""Dashboard analytics — all computed live from the open database.

Pure query logic (no Qt), so it is unit-testable in isolation and reused by
both the Executive Dashboard and the report generator.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, timedelta

from sqlalchemy import func

from ..config import LOW_STOCK_FRACTION
from ..database.db import db
from ..database.models import (
    PMCC, ClientRemark, Consumable, Equipment, Manpower, Preservation,
    Procedure, ProgressSnapshot, Punch, Risk, SpecialActivity, Task,
)


@dataclass
class DashboardMetrics:
    overall_progress: float = 0.0
    target_progress: float = 0.0
    schedule_variance: float = 0.0          # actual - target (+ ahead, - behind)
    daily_progress: float = 0.0
    weekly_progress: float = 0.0
    monthly_progress: float = 0.0

    pmcc_total: int = 0
    pmcc_completed: int = 0
    pmcc_pending: int = 0
    pmcc_critical: int = 0
    pmcc_blocked: int = 0

    punch_total: int = 0
    punch_open: int = 0
    punch_closed: int = 0
    punch_critical: int = 0

    equipment_total: int = 0
    equipment_commissioned: int = 0
    procedures_total: int = 0
    procedures_closed: int = 0
    special_total: int = 0
    special_completed: int = 0

    manpower_total: int = 0
    manpower_today: int = 0

    consumables_low: int = 0

    by_discipline: dict[str, float] = field(default_factory=dict)
    by_area: dict[str, float] = field(default_factory=dict)
    by_system: dict[str, float] = field(default_factory=dict)
    equipment_by_type: dict[str, int] = field(default_factory=dict)
    pmcc_status_counts: dict[str, int] = field(default_factory=dict)
    scurve: list[tuple[str, float, float]] = field(default_factory=list)

    client_remarks: list[str] = field(default_factory=list)
    risks: list[tuple[str, str]] = field(default_factory=list)
    upcoming: list[tuple[str, str]] = field(default_factory=list)


def _avg_completion(session, model, group_col) -> dict[str, float]:
    rows = (
        session.query(group_col, func.avg(model.completion))
        .group_by(group_col)
        .all()
    )
    return {(k or "Unassigned"): round(v or 0.0, 1) for k, v in rows}


def compute_dashboard() -> DashboardMetrics:
    """Roll every module up into a single dashboard snapshot."""
    m = DashboardMetrics()
    if not db.is_open:
        return m
    today = date.today()
    with db.session() as s:
        # --- overall progress: weighted average of PMCC completion -----------
        m.pmcc_total = s.query(func.count(PMCC.id)).scalar() or 0
        avg = s.query(func.avg(PMCC.completion)).scalar()
        m.overall_progress = round(avg or 0.0, 1)

        proj = s.query(func.avg(ProgressSnapshot.target)).scalar()
        # target = latest snapshot target if available, else project target
        latest = (
            s.query(ProgressSnapshot)
            .order_by(ProgressSnapshot.snap_date.desc())
            .first()
        )
        m.target_progress = round(latest.target, 1) if latest else round(proj or 0.0, 1)
        m.schedule_variance = round(m.overall_progress - m.target_progress, 1)

        # daily / weekly / monthly deltas from snapshots
        m.daily_progress = _delta(s, today, 1)
        m.weekly_progress = _delta(s, today, 7)
        m.monthly_progress = _delta(s, today, 30)

        # --- PMCC counters ---------------------------------------------------
        m.pmcc_completed = s.query(func.count(PMCC.id)).filter(PMCC.status == "Completed").scalar() or 0
        m.pmcc_critical = s.query(func.count(PMCC.id)).filter(PMCC.status == "Critical").scalar() or 0
        m.pmcc_blocked = s.query(func.count(PMCC.id)).filter(PMCC.status == "Blocked").scalar() or 0
        m.pmcc_pending = m.pmcc_total - m.pmcc_completed
        m.pmcc_status_counts = {
            k: v for k, v in s.query(PMCC.status, func.count(PMCC.id)).group_by(PMCC.status).all()
        }

        # --- punch -----------------------------------------------------------
        m.punch_total = s.query(func.count(Punch.id)).scalar() or 0
        m.punch_open = s.query(func.count(Punch.id)).filter(Punch.status == "Open").scalar() or 0
        m.punch_closed = m.punch_total - m.punch_open
        m.punch_critical = s.query(func.count(Punch.id)).filter(
            Punch.status == "Open", Punch.priority == "Critical"
        ).scalar() or 0

        # --- equipment / procedures / special --------------------------------
        m.equipment_total = s.query(func.count(Equipment.id)).scalar() or 0
        m.equipment_commissioned = s.query(func.count(Equipment.id)).filter(
            Equipment.status == "Commissioned"
        ).scalar() or 0
        m.equipment_by_type = {
            k: v for k, v in s.query(Equipment.equipment_type, func.count(Equipment.id))
            .group_by(Equipment.equipment_type).all()
        }
        m.procedures_total = s.query(func.count(Procedure.id)).scalar() or 0
        m.procedures_closed = s.query(func.count(Procedure.id)).filter(
            Procedure.status.in_(["Closed", "Implemented"])
        ).scalar() or 0
        m.special_total = s.query(func.count(SpecialActivity.id)).scalar() or 0
        m.special_completed = s.query(func.count(SpecialActivity.id)).filter(
            SpecialActivity.status == "Completed"
        ).scalar() or 0

        # --- manpower --------------------------------------------------------
        m.manpower_total = s.query(func.coalesce(func.sum(Manpower.count), 0)).scalar() or 0
        m.manpower_today = s.query(func.coalesce(func.sum(Manpower.count), 0)).filter(
            Manpower.log_date == today
        ).scalar() or 0

        # --- consumables low stock ------------------------------------------
        for c in s.query(Consumable).all():
            if c.required and (c.available - c.consumed) <= c.required * LOW_STOCK_FRACTION:
                m.consumables_low += 1

        # --- breakdowns ------------------------------------------------------
        m.by_discipline = _avg_completion(s, PMCC, PMCC.discipline)
        m.by_area = _avg_completion(s, PMCC, PMCC.area)
        m.by_system = _avg_completion(s, PMCC, PMCC.system)

        # --- s-curve ---------------------------------------------------------
        snaps = s.query(ProgressSnapshot).order_by(ProgressSnapshot.snap_date).all()
        m.scurve = [(sn.snap_date.isoformat(), round(sn.actual, 1), round(sn.target, 1)) for sn in snaps]

        # --- narrative widgets ----------------------------------------------
        m.client_remarks = [r.remark for r in s.query(ClientRemark).filter(
            ClientRemark.status == "Open").limit(6).all()]
        m.risks = [(r.title, r.severity) for r in s.query(Risk).filter(
            Risk.status == "Open").limit(6).all()]
        # upcoming: PMCCs with the nearest target dates that are not complete
        up = (
            s.query(PMCC)
            .filter(PMCC.status != "Completed", PMCC.target_date.isnot(None))
            .order_by(PMCC.target_date)
            .limit(6)
            .all()
        )
        m.upcoming = [(p.number, p.target_date.isoformat() if p.target_date else "") for p in up]
    return m


def _delta(session, today: date, days: int) -> float:
    """Actual-progress gain over the last ``days`` from the snapshot series."""
    cur = (
        session.query(ProgressSnapshot)
        .order_by(ProgressSnapshot.snap_date.desc())
        .first()
    )
    if not cur:
        return 0.0
    past = (
        session.query(ProgressSnapshot)
        .filter(ProgressSnapshot.snap_date <= today - timedelta(days=days))
        .order_by(ProgressSnapshot.snap_date.desc())
        .first()
    )
    if not past:
        return round(cur.actual, 1)
    return round(cur.actual - past.actual, 1)
