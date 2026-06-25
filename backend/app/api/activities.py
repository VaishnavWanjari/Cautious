"""Activity, relationship and template endpoints."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import schemas
from ..db import get_db
from ..infrastructure import models, repositories

router = APIRouter(prefix="/api", tags=["activities"])


# --- Activities ---------------------------------------------------------
@router.get("/snrs/{snr_id}/activities", response_model=list[schemas.ActivityOut])
def list_activities(snr_id: int, db: Session = Depends(get_db)):
    return list(db.scalars(select(models.Activity).where(models.Activity.snr_id == snr_id)))


@router.get("/projects/{project_id}/activities", response_model=list[schemas.ActivityOut])
def list_project_activities(project_id: int, db: Session = Depends(get_db)):
    return repositories.project_activities(db, project_id)


@router.post("/snrs/{snr_id}/activities", response_model=schemas.ActivityOut)
def create_activity(snr_id: int, body: schemas.ActivityIn, db: Session = Depends(get_db)):
    if not db.get(models.SNR, snr_id):
        raise HTTPException(404, "SNR not found")
    obj = models.Activity(snr_id=snr_id, **body.model_dump())
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


@router.put("/activities/{activity_id}", response_model=schemas.ActivityOut)
def update_activity(activity_id: int, body: schemas.ActivityIn, db: Session = Depends(get_db)):
    obj = db.get(models.Activity, activity_id)
    if not obj:
        raise HTTPException(404, "Activity not found")
    for k, v in body.model_dump().items():
        setattr(obj, k, v)
    db.commit()
    db.refresh(obj)
    return obj


@router.patch("/activities/{activity_id}/position", response_model=schemas.ActivityOut)
def update_position(activity_id: int, x: float, y: float, db: Session = Depends(get_db)):
    obj = db.get(models.Activity, activity_id)
    if not obj:
        raise HTTPException(404, "Activity not found")
    obj.pos_x, obj.pos_y = x, y
    db.commit()
    db.refresh(obj)
    return obj


@router.delete("/activities/{activity_id}")
def delete_activity(activity_id: int, db: Session = Depends(get_db)):
    obj = db.get(models.Activity, activity_id)
    if not obj:
        raise HTTPException(404, "Activity not found")
    db.delete(obj)
    db.commit()
    return {"ok": True}


# --- Relationships ------------------------------------------------------
@router.get("/projects/{project_id}/relationships", response_model=list[schemas.RelationshipOut])
def list_relationships(project_id: int, db: Session = Depends(get_db)):
    return repositories.project_relationships(db, project_id)


@router.post("/projects/{project_id}/relationships", response_model=schemas.RelationshipOut)
def create_relationship(
    project_id: int, body: schemas.RelationshipIn, db: Session = Depends(get_db)
):
    if not db.get(models.Project, project_id):
        raise HTTPException(404, "Project not found")
    if body.predecessor_id == body.successor_id:
        raise HTTPException(400, "An activity cannot precede itself")
    obj = models.Relationship(project_id=project_id, **body.model_dump())
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


@router.put("/relationships/{rel_id}", response_model=schemas.RelationshipOut)
def update_relationship(rel_id: int, body: schemas.RelationshipIn, db: Session = Depends(get_db)):
    obj = db.get(models.Relationship, rel_id)
    if not obj:
        raise HTTPException(404, "Relationship not found")
    obj.predecessor_id = body.predecessor_id
    obj.successor_id = body.successor_id
    obj.rel_type = body.rel_type
    obj.lag = body.lag
    db.commit()
    db.refresh(obj)
    return obj


@router.delete("/relationships/{rel_id}")
def delete_relationship(rel_id: int, db: Session = Depends(get_db)):
    obj = db.get(models.Relationship, rel_id)
    if not obj:
        raise HTTPException(404, "Relationship not found")
    db.delete(obj)
    db.commit()
    return {"ok": True}


# --- Templates ----------------------------------------------------------
@router.get("/templates", response_model=list[schemas.TemplateOut])
def list_templates(db: Session = Depends(get_db)):
    return list(db.scalars(select(models.ActivityTemplate)))


@router.post("/templates", response_model=schemas.TemplateOut)
def create_template(body: schemas.TemplateIn, db: Session = Depends(get_db)):
    obj = models.ActivityTemplate(is_builtin=False, **body.model_dump())
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


@router.delete("/templates/{template_id}")
def delete_template(template_id: int, db: Session = Depends(get_db)):
    obj = db.get(models.ActivityTemplate, template_id)
    if not obj:
        raise HTTPException(404, "Template not found")
    if obj.is_builtin:
        raise HTTPException(400, "Built-in templates cannot be deleted")
    db.delete(obj)
    db.commit()
    return {"ok": True}
