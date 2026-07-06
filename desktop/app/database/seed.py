"""Sample project data so the app looks alive on first run / for demos.

``seed_sample_project`` fills an open database with a realistic Oil & Gas
commissioning dataset (PMCCs, equipment, punches, manpower, etc.). It is only
ever called explicitly ("Load Sample Data" / when creating the bundled sample
database) — never automatically on top of real data.
"""

from __future__ import annotations

import random
from datetime import date, timedelta

from .db import db
from .models import (
    PMCC, ClientRemark, Consumable, Equipment, Manpower, Preservation,
    Procedure, ProgressSnapshot, ProposalItem, Punch, Risk, SpecialActivity,
    Task,
)

AREAS = ["Inlet Facility", "AGRU", "Gas Train-3", "Gas Train-4", "Utilities", "Flare & Relief"]
SYSTEMS = ["Feed Gas", "Amine", "Dehydration", "Compression", "Instrument Air", "Nitrogen"]
DISCIPLINES = ["Piping", "Static Equipment", "Rotary Equipment", "Electrical", "Instrumentation", "Mechanical"]
CONTRACTORS = ["L&T Hydrocarbon", "Subcontractor-A", "Subcontractor-B"]


def _d(offset: int) -> date:
    return date.today() + timedelta(days=offset)


def seed_sample_project() -> None:
    """Populate the currently-open database with demo data."""
    rnd = random.Random(42)  # deterministic so demos are repeatable
    with db.session() as s:
        # PMCCs
        for i in range(1, 41):
            comp = rnd.choice([0, 10, 25, 45, 60, 75, 90, 100])
            status = (
                "Completed" if comp == 100 else
                "Blocked" if rnd.random() < 0.08 else
                "Critical" if rnd.random() < 0.1 else
                "In Progress" if comp > 0 else "Not Started"
            )
            s.add(PMCC(
                number=f"PMCC-{i:02d}",
                description=f"{rnd.choice(SYSTEMS)} subsystem handover package {i}",
                subsystem=f"SS-{100 + i}",
                system=rnd.choice(SYSTEMS),
                area=rnd.choice(AREAS),
                discipline=rnd.choice(DISCIPLINES),
                contractor=rnd.choice(CONTRACTORS),
                status=status,
                priority=rnd.choice(["Critical", "High", "Medium", "Low"]),
                completion=comp,
                target_date=_d(rnd.randint(10, 200)),
                remarks="",
            ))

        # Equipment
        eq_status = ["Installed", "Aligned", "Preserved", "Flushed", "Hydrotested", "Ready", "Commissioned"]
        eq_types = ["Static", "Rotary", "Electrical", "Instrument"]
        for i in range(1, 121):
            s.add(Equipment(
                tag_number=f"{rnd.choice(['P','V','E','K','T','LT','PT','FT'])}-{3000 + i}",
                description=f"Equipment item {i}",
                area=rnd.choice(AREAS),
                subsystem=f"SS-{100 + rnd.randint(1, 40)}",
                system=rnd.choice(SYSTEMS),
                discipline=rnd.choice(DISCIPLINES),
                equipment_type=rnd.choice(eq_types),
                status=rnd.choice(eq_status),
                completion=rnd.choice([0, 20, 40, 60, 80, 100]),
            ))

        # Procedures
        proc_status = ["Draft", "Review", "Approved", "Issued", "Implemented", "Closed"]
        for i in range(1, 21):
            s.add(Procedure(
                number=f"CP-{200 + i}",
                title=f"Commissioning Procedure — {rnd.choice(SYSTEMS)} {i}",
                revision=str(rnd.randint(0, 3)),
                responsible=rnd.choice(["A. Rao", "B. Khan", "C. Patel", "D. Mehta"]),
                status=rnd.choice(proc_status),
            ))

        # Preservation (some overdue)
        for i in range(1, 31):
            last = _d(-rnd.randint(1, 60))
            freq = rnd.choice([15, 30, 45])
            nxt = last + timedelta(days=freq)
            s.add(Preservation(
                tag_number=f"K-{3000 + rnd.randint(1, 40)}",
                description=f"Rotary preservation item {i}",
                area=rnd.choice(AREAS),
                preservation_type=rnd.choice(["Nitrogen Blanketing", "Oil Circulation", "Shaft Rotation", "VCI"]),
                frequency_days=freq,
                last_date=last,
                next_due=nxt,
                status="Overdue" if nxt < date.today() else "OK",
            ))

        # Manpower (last 14 days)
        for offset in range(-14, 1):
            for agency in ["L&T", "Subcontractor", "External Agency"]:
                for disc in DISCIPLINES:
                    s.add(Manpower(
                        log_date=_d(offset), agency=agency, discipline=disc,
                        department=disc, area=rnd.choice(AREAS),
                        count=rnd.randint(2, 18),
                    ))

        # Consumables (some low stock)
        for name, unit, req in [
            ("Nitrogen", "Nm3", 5000), ("Argon", "cyl", 40), ("Welding Rod E7018", "kg", 800),
            ("Hydro Test Water", "m3", 300), ("Lube Oil ISO VG 32", "L", 1200),
            ("Chemical Cleaning Solvent", "drum", 30), ("Blind Flanges", "set", 120),
            ("Gaskets", "set", 500), ("Calibration Gas", "cyl", 25),
        ]:
            avail = req * rnd.uniform(0.1, 1.0)
            consumed = avail * rnd.uniform(0.2, 0.9)
            s.add(Consumable(name=name, unit=unit, required=round(req, 1),
                             available=round(avail, 1), consumed=round(consumed, 1)))

        # Special recommissioning activities
        for act in ["Chemical Cleaning", "Steam Blowing", "Adsorbent Loading", "Amine Degreasing",
                    "Catalyst Loading", "Oil Flushing", "Air Blowing", "Drying / Dew Point"]:
            s.add(SpecialActivity(
                activity=act, area=rnd.choice(AREAS), subsystem=f"SS-{100 + rnd.randint(1, 40)}",
                priority=rnd.choice(["Critical", "High", "Medium"]),
                responsible=rnd.choice(["A. Rao", "B. Khan", "C. Patel"]),
                status=rnd.choice(["Not Started", "In Progress", "Completed"]),
                completion=rnd.choice([0, 30, 60, 100]),
            ))

        # Punch list (A/B/C, open & closed)
        for i in range(1, 81):
            closed = rnd.random() < 0.45
            s.add(Punch(
                number=f"PL-{1000 + i}",
                description=f"Punch item {i}",
                category=rnd.choice(["A", "A", "B", "B", "B", "C"]),
                area=rnd.choice(AREAS), system=rnd.choice(SYSTEMS),
                discipline=rnd.choice(DISCIPLINES),
                priority=rnd.choice(["Critical", "High", "Medium", "Low"]),
                status="Closed" if closed else "Open",
                raised_date=_d(-rnd.randint(5, 90)),
                closed_date=_d(-rnd.randint(0, 4)) if closed else None,
            ))

        # Kanban tasks
        kb_status = ["Not Started", "Ready", "In Progress", "Waiting", "Blocked", "Completed"]
        for i in range(1, 25):
            st = rnd.choice(kb_status)
            s.add(Task(
                title=f"{rnd.choice(['Loop check', 'Leak test', 'Energize', 'Flush', 'Align', 'Punch closeout'])} — item {i}",
                status=st, priority=rnd.choice(["Critical", "High", "Medium", "Low"]),
                owner=rnd.choice(["A. Rao", "B. Khan", "C. Patel", "D. Mehta"]),
                area=rnd.choice(AREAS), system=rnd.choice(SYSTEMS),
                subsystem=f"SS-{100 + rnd.randint(1, 40)}",
                progress=100 if st == "Completed" else rnd.choice([0, 25, 50, 75]),
                order_index=i,
            ))

        # Proposal comparison
        for cat in ["Piping Tests", "Loop Checks", "Motor Solo Runs", "Vessel Box-up", "Instrument Calibration"]:
            proposed = rnd.randint(100, 500)
            completed = int(proposed * rnd.uniform(0.3, 0.9))
            s.add(ProposalItem(
                item=cat, category="Commissioning", proposed=proposed,
                current=proposed + rnd.randint(-20, 40), completed=completed,
                cost=round(proposed * rnd.uniform(80, 150), 0),
                resources=rnd.randint(4, 20), duration=rnd.randint(10, 60),
            ))

        # Client remarks & risks
        for r in ["Expedite AGRU punch closure", "Provide updated 90-day look-ahead",
                  "Preservation records to be witnessed"]:
            s.add(ClientRemark(log_date=_d(-rnd.randint(1, 10)), remark=r,
                               raised_by="Client Rep", status="Open"))
        for t, sev in [("N2 supply shortfall for inertization", "High"),
                       ("Late vendor for compressor commissioning", "Critical"),
                       ("Monsoon impact on outdoor testing", "Medium")]:
            s.add(Risk(title=t, severity=sev, owner="Commissioning Mgr", status="Open"))

        # Progress snapshots for the S-curve (60 days back)
        for offset in range(-60, 1):
            frac = (offset + 60) / 60.0
            s.add(ProgressSnapshot(
                snap_date=_d(offset),
                actual=round(72 * frac + rnd.uniform(-2, 2), 1),
                target=round(78 * frac, 1),
            ))

        s.commit()
