"""Seed a realistic sample project so the app is populated on first launch.

Creates PMCC-01 with three systems (Condensate Stabilizer / Slug Catcher /
Fuel Gas) and the documented pre-commissioning activity chain on the Condensate
Stabilizer subsystem, anchored to a Mechanical Completion date of 15-Jan-2027.
Also seeds the built-in activity template library.
"""

from __future__ import annotations

from datetime import date

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..application.templates import BUILTIN_TEMPLATES
from . import models


def _seed_templates(session: Session) -> None:
    existing = session.scalar(select(func.count()).select_from(models.ActivityTemplate))
    if existing:
        return
    for name, category, dur, disc, res, util in BUILTIN_TEMPLATES:
        session.add(
            models.ActivityTemplate(
                name=name,
                category=category,
                default_duration=dur,
                discipline=disc,
                resources=res,
                utilities=util,
                is_builtin=True,
            )
        )
    session.commit()


def _seed_sample_project(session: Session) -> None:
    if session.scalar(select(func.count()).select_from(models.Project)):
        return

    project = models.Project(
        name="LNG Train 1 — Pre-Commissioning",
        client="ACME Energy",
        location="Ras Laffan",
        mechanical_completion_date=date(2027, 1, 15),
        planned_startup_date=date(2027, 2, 1),
        working_weekdays="1,2,3,4,5,6",  # 6-day week common on EPC sites
        holidays="2027-01-01",
    )
    session.add(project)
    session.flush()

    pmcc = models.PMCC(project_id=project.id, code="PMCC-01", name="Process Area", area="Area-100")
    session.add(pmcc)
    session.flush()

    systems = [
        ("SYS-CS", "Condensate Stabilizer", 1, "Process", "Area-100"),
        ("SYS-SC", "Slug Catcher", 2, "Process", "Area-100"),
        ("SYS-FG", "Fuel Gas", 3, "Process", "Area-110"),
    ]
    system_rows = []
    for sid, desc, prio, disc, area in systems:
        s = models.System(
            pmcc_id=pmcc.id,
            system_id=sid,
            description=desc,
            priority=prio,
            discipline=disc,
            area=area,
        )
        session.add(s)
        system_rows.append(s)
    session.flush()

    # Subsystem + SNR on the Condensate Stabilizer
    subsystem = models.Subsystem(
        system_id=system_rows[0].id,
        number="SS001",
        description="Stabilizer Feed Line",
        priority=1,
        discipline="Piping",
        area="Area-100",
    )
    session.add(subsystem)
    session.flush()

    snr = models.SNR(
        subsystem_id=subsystem.id,
        code="SNR-001",
        description="Feed line pre-commissioning circuit",
        snr_type="SNR",
    )
    session.add(snr)
    session.flush()

    # Documented activity chain: Hydrotest 7 -> Dewatering 2 -> Drying 5 ->
    # Reinstatement 3 -> Leak Test 2 (all Finish-to-Start).
    chain = [
        ("A-010", "Hydrotest", 7, "Piping"),
        ("A-020", "Dewatering", 2, "Piping"),
        ("A-030", "Drying", 5, "Piping"),
        ("A-040", "Reinstatement", 3, "Piping"),
        ("A-050", "Leak Test", 2, "Process"),
    ]
    act_rows = []
    for i, (aid, name, dur, disc) in enumerate(chain):
        a = models.Activity(
            snr_id=snr.id,
            activity_id=aid,
            name=name,
            duration=dur,
            discipline=disc,
            area="Area-100",
            priority=1,
            pos_x=float(i * 260),
            pos_y=0.0,
        )
        session.add(a)
        act_rows.append(a)
    session.flush()

    for pred, succ in zip(act_rows, act_rows[1:]):
        session.add(
            models.Relationship(
                project_id=project.id,
                predecessor_id=pred.id,
                successor_id=succ.id,
                rel_type="FS",
                lag=0,
            )
        )

    # A couple of starter logic rules (plain language)
    session.add_all(
        [
            models.LogicRule(
                project_id=project.id,
                condition="Hydrotest Complete",
                action="Enable Dewatering",
                enabled=True,
            ),
            models.LogicRule(
                project_id=project.id,
                condition="Drying Complete AND Nitrogen Available",
                action="Enable Leak Test",
                enabled=True,
            ),
        ]
    )

    # Example constraints (Phase-2 solving)
    session.add_all(
        [
            models.Constraint(
                project_id=project.id,
                constraint_type="Resource",
                name="Hydrotest Pump",
                capacity=2,
            ),
            models.Constraint(
                project_id=project.id,
                constraint_type="Utility",
                name="Nitrogen",
                available=True,
            ),
        ]
    )
    session.commit()


def seed_if_empty(session: Session) -> None:
    _seed_templates(session)
    _seed_sample_project(session)
