"""Seed the GPT-3/4 Gas Processing Train project on first launch.

Builds the full hierarchy from the shared dataset in ``app.seed_data``:
Project -> PMCC (21) -> System (one per PMCC) -> Subsystem (commissioning
circuit) -> SNR -> Activities (special pre-commissioning activity + the standard
set), anchored to a Mechanical Completion date, plus the built-in template
library. The standalone server uses the same dataset, so both builds match.
"""

from __future__ import annotations

from datetime import date

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .. import seed_data as sd
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


def _seed_project(session: Session) -> None:
    if session.scalar(select(func.count()).select_from(models.Project)):
        return

    project = models.Project(
        name="GPT-3/4 Gas Processing Train",
        client="Gas Processing Plant",
        location="GPT-3/4",
        mechanical_completion_date=date(2027, 12, 31),
        planned_startup_date=date(2028, 1, 31),
        working_weekdays="1,2,3,4,5,6",
        holidays="",
    )
    session.add(project)
    session.flush()

    # One PMCC + one umbrella System per PMCC (detailed systems not enumerated).
    system_by_pmcc: dict[str, int] = {}
    for seq, category, no, desc, sysn, subn in sd.PMCCS:
        pmcc = models.PMCC(project_id=project.id, code=no, name=desc, area=category)
        session.add(pmcc)
        session.flush()
        system = models.System(
            pmcc_id=pmcc.id, system_id=f"{no}-SYS", description=desc, discipline="Multi-discipline"
        )
        session.add(system)
        session.flush()
        system_by_pmcc[no] = system.id

    # Each circuit -> Subsystem + SNR + its activity chain.
    for code, cdesc, prio, special, pmcc_no in sd.CIRCUITS:
        system_id = system_by_pmcc.get(pmcc_no)
        if system_id is None:
            continue
        subsystem = models.Subsystem(
            system_id=system_id,
            number=code,
            description=cdesc,
            priority=sd.priority_rank(prio),
        )
        session.add(subsystem)
        session.flush()
        snr = models.SNR(subsystem_id=subsystem.id, code=code, description=cdesc, snr_type="Commissioning Circuit")
        session.add(snr)
        session.flush()

        activities, edges = sd.build_circuit(code, cdesc, special)
        local: list[int] = []
        for seq, (name, dur, disc) in enumerate(activities):
            act = models.Activity(
                snr_id=snr.id,
                activity_id=f"{code}/{seq + 1:02d}",
                name=name,
                duration=dur,
                discipline=disc,
                priority=sd.priority_rank(prio),
            )
            session.add(act)
            session.flush()
            local.append(act.id)
        for pi, si, lag in edges:
            session.add(
                models.Relationship(
                    project_id=project.id,
                    predecessor_id=local[pi],
                    successor_id=local[si],
                    rel_type="FS",
                    lag=lag,
                )
            )

    # Building PMCCs (01-05): one handover block each (no precom circuits).
    for pmcc_no, dur in sd.BUILDING_DURATIONS.items():
        system_id = system_by_pmcc.get(pmcc_no)
        if system_id is None:
            continue
        subsystem = models.Subsystem(
            system_id=system_id, number=pmcc_no, description="Building Pre-Commissioning & Handover", priority=1
        )
        session.add(subsystem)
        session.flush()
        snr = models.SNR(subsystem_id=subsystem.id, code=pmcc_no, description="Building handover", snr_type="Building")
        session.add(snr)
        session.flush()
        session.add(
            models.Activity(
                snr_id=snr.id,
                activity_id=f"{pmcc_no}/HANDOVER",
                name="Building Pre-Commissioning & Handover",
                duration=dur,
                discipline="Building",
                priority=1,
            )
        )

    session.add_all(
        [
            models.LogicRule(
                project_id=project.id,
                condition="Leak Test Complete AND Nitrogen Available",
                action="Enable Inertization",
                enabled=True,
            ),
            models.LogicRule(
                project_id=project.id,
                condition="Loop Check Complete",
                action="Enable Punch Point Liquidation",
                enabled=True,
            ),
        ]
    )
    session.commit()


def seed_if_empty(session: Session) -> None:
    _seed_templates(session)
    _seed_project(session)
