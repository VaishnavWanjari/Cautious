"""Scheduling, network and validation endpoints."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import schemas, services
from ..db import get_db

router = APIRouter(prefix="/api", tags=["schedule"])


@router.post("/projects/{project_id}/schedule/compute", response_model=schemas.ScheduleResultOut)
def compute(project_id: int, db: Session = Depends(get_db)):
    try:
        return services.run_schedule(db, project_id)
    except ValueError as exc:
        raise HTTPException(404, str(exc))


@router.get("/projects/{project_id}/network", response_model=schemas.NetworkOut)
def network(project_id: int, db: Session = Depends(get_db)):
    try:
        return services.build_network(db, project_id)
    except ValueError as exc:
        raise HTTPException(404, str(exc))


@router.get("/projects/{project_id}/validate", response_model=schemas.ValidationOut)
def validate(project_id: int, db: Session = Depends(get_db)):
    try:
        return services.validate(db, project_id)
    except ValueError as exc:
        raise HTTPException(404, str(exc))


@router.get("/projects/{project_id}/summary")
def summary(project_id: int, db: Session = Depends(get_db)):
    try:
        return services.project_summary(db, project_id)
    except ValueError as exc:
        raise HTTPException(404, str(exc))
