"""Project + hierarchy (PMCC/System/Subsystem/SNR) CRUD endpoints."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import schemas
from ..db import get_db
from ..infrastructure import models
from ..infrastructure.repositories import parse_holidays, parse_weekdays

router = APIRouter(prefix="/api", tags=["projects"])


def _project_out(p: models.Project) -> schemas.ProjectOut:
    return schemas.ProjectOut(
        id=p.id,
        name=p.name,
        client=p.client,
        location=p.location,
        mechanical_completion_date=p.mechanical_completion_date,
        planned_startup_date=p.planned_startup_date,
        working_weekdays=sorted(parse_weekdays(p.working_weekdays)),
        holidays=sorted(parse_holidays(p.holidays)),
    )


# --- Projects -----------------------------------------------------------
@router.get("/projects", response_model=list[schemas.ProjectOut])
def list_projects(db: Session = Depends(get_db)):
    return [_project_out(p) for p in db.scalars(select(models.Project))]


@router.post("/projects", response_model=schemas.ProjectOut)
def create_project(body: schemas.ProjectIn, db: Session = Depends(get_db)):
    p = models.Project(
        name=body.name,
        client=body.client,
        location=body.location,
        mechanical_completion_date=body.mechanical_completion_date,
        planned_startup_date=body.planned_startup_date,
        working_weekdays=",".join(str(d) for d in body.working_weekdays),
        holidays=",".join(d.isoformat() for d in body.holidays),
    )
    db.add(p)
    db.commit()
    db.refresh(p)
    return _project_out(p)


@router.get("/projects/{project_id}", response_model=schemas.ProjectOut)
def get_project(project_id: int, db: Session = Depends(get_db)):
    p = db.get(models.Project, project_id)
    if not p:
        raise HTTPException(404, "Project not found")
    return _project_out(p)


@router.put("/projects/{project_id}", response_model=schemas.ProjectOut)
def update_project(project_id: int, body: schemas.ProjectIn, db: Session = Depends(get_db)):
    p = db.get(models.Project, project_id)
    if not p:
        raise HTTPException(404, "Project not found")
    p.name = body.name
    p.client = body.client
    p.location = body.location
    p.mechanical_completion_date = body.mechanical_completion_date
    p.planned_startup_date = body.planned_startup_date
    p.working_weekdays = ",".join(str(d) for d in body.working_weekdays)
    p.holidays = ",".join(d.isoformat() for d in body.holidays)
    db.commit()
    db.refresh(p)
    return _project_out(p)


@router.delete("/projects/{project_id}")
def delete_project(project_id: int, db: Session = Depends(get_db)):
    p = db.get(models.Project, project_id)
    if not p:
        raise HTTPException(404, "Project not found")
    db.delete(p)
    db.commit()
    return {"ok": True}


# --- PMCC ---------------------------------------------------------------
@router.get("/projects/{project_id}/pmccs", response_model=list[schemas.PMCCOut])
def list_pmccs(project_id: int, db: Session = Depends(get_db)):
    return list(
        db.scalars(select(models.PMCC).where(models.PMCC.project_id == project_id))
    )


@router.post("/projects/{project_id}/pmccs", response_model=schemas.PMCCOut)
def create_pmcc(project_id: int, body: schemas.PMCCIn, db: Session = Depends(get_db)):
    if not db.get(models.Project, project_id):
        raise HTTPException(404, "Project not found")
    pmcc = models.PMCC(project_id=project_id, **body.model_dump())
    db.add(pmcc)
    db.commit()
    db.refresh(pmcc)
    return pmcc


@router.delete("/pmccs/{pmcc_id}")
def delete_pmcc(pmcc_id: int, db: Session = Depends(get_db)):
    obj = db.get(models.PMCC, pmcc_id)
    if not obj:
        raise HTTPException(404, "PMCC not found")
    db.delete(obj)
    db.commit()
    return {"ok": True}


# --- Systems ------------------------------------------------------------
@router.get("/pmccs/{pmcc_id}/systems", response_model=list[schemas.SystemOut])
def list_systems(pmcc_id: int, db: Session = Depends(get_db)):
    return list(db.scalars(select(models.System).where(models.System.pmcc_id == pmcc_id)))


@router.post("/pmccs/{pmcc_id}/systems", response_model=schemas.SystemOut)
def create_system(pmcc_id: int, body: schemas.SystemIn, db: Session = Depends(get_db)):
    if not db.get(models.PMCC, pmcc_id):
        raise HTTPException(404, "PMCC not found")
    s = models.System(pmcc_id=pmcc_id, **body.model_dump())
    db.add(s)
    db.commit()
    db.refresh(s)
    return s


@router.delete("/systems/{system_id}")
def delete_system(system_id: int, db: Session = Depends(get_db)):
    obj = db.get(models.System, system_id)
    if not obj:
        raise HTTPException(404, "System not found")
    db.delete(obj)
    db.commit()
    return {"ok": True}


# --- Subsystems ---------------------------------------------------------
@router.get("/systems/{system_id}/subsystems", response_model=list[schemas.SubsystemOut])
def list_subsystems(system_id: int, db: Session = Depends(get_db)):
    return list(
        db.scalars(select(models.Subsystem).where(models.Subsystem.system_id == system_id))
    )


@router.post("/systems/{system_id}/subsystems", response_model=schemas.SubsystemOut)
def create_subsystem(system_id: int, body: schemas.SubsystemIn, db: Session = Depends(get_db)):
    if not db.get(models.System, system_id):
        raise HTTPException(404, "System not found")
    obj = models.Subsystem(system_id=system_id, **body.model_dump())
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


@router.delete("/subsystems/{subsystem_id}")
def delete_subsystem(subsystem_id: int, db: Session = Depends(get_db)):
    obj = db.get(models.Subsystem, subsystem_id)
    if not obj:
        raise HTTPException(404, "Subsystem not found")
    db.delete(obj)
    db.commit()
    return {"ok": True}


# --- SNR ----------------------------------------------------------------
@router.get("/subsystems/{subsystem_id}/snrs", response_model=list[schemas.SNROut])
def list_snrs(subsystem_id: int, db: Session = Depends(get_db)):
    return list(db.scalars(select(models.SNR).where(models.SNR.subsystem_id == subsystem_id)))


@router.post("/subsystems/{subsystem_id}/snrs", response_model=schemas.SNROut)
def create_snr(subsystem_id: int, body: schemas.SNRIn, db: Session = Depends(get_db)):
    if not db.get(models.Subsystem, subsystem_id):
        raise HTTPException(404, "Subsystem not found")
    obj = models.SNR(subsystem_id=subsystem_id, **body.model_dump())
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


@router.delete("/snrs/{snr_id}")
def delete_snr(snr_id: int, db: Session = Depends(get_db)):
    obj = db.get(models.SNR, snr_id)
    if not obj:
        raise HTTPException(404, "SNR not found")
    db.delete(obj)
    db.commit()
    return {"ok": True}
