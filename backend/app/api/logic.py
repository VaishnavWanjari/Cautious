"""Plain-language logic rules and constraint endpoints."""

from __future__ import annotations

import json

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import schemas
from ..application.logic_engine import compile_rule
from ..db import get_db
from ..infrastructure import models

router = APIRouter(prefix="/api", tags=["logic"])


# --- Logic rules --------------------------------------------------------
@router.get("/projects/{project_id}/logic-rules", response_model=list[schemas.LogicRuleOut])
def list_rules(project_id: int, db: Session = Depends(get_db)):
    return list(
        db.scalars(select(models.LogicRule).where(models.LogicRule.project_id == project_id))
    )


@router.post("/projects/{project_id}/logic-rules", response_model=schemas.LogicRuleOut)
def create_rule(project_id: int, body: schemas.LogicRuleIn, db: Session = Depends(get_db)):
    if not db.get(models.Project, project_id):
        raise HTTPException(404, "Project not found")
    structured = json.dumps(compile_rule(body.condition, body.action))
    obj = models.LogicRule(
        project_id=project_id,
        condition=body.condition,
        action=body.action,
        structured=structured,
        enabled=body.enabled,
    )
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


@router.put("/logic-rules/{rule_id}", response_model=schemas.LogicRuleOut)
def update_rule(rule_id: int, body: schemas.LogicRuleIn, db: Session = Depends(get_db)):
    obj = db.get(models.LogicRule, rule_id)
    if not obj:
        raise HTTPException(404, "Logic rule not found")
    obj.condition = body.condition
    obj.action = body.action
    obj.enabled = body.enabled
    obj.structured = json.dumps(compile_rule(body.condition, body.action))
    db.commit()
    db.refresh(obj)
    return obj


@router.delete("/logic-rules/{rule_id}")
def delete_rule(rule_id: int, db: Session = Depends(get_db)):
    obj = db.get(models.LogicRule, rule_id)
    if not obj:
        raise HTTPException(404, "Logic rule not found")
    db.delete(obj)
    db.commit()
    return {"ok": True}


# --- Constraints --------------------------------------------------------
@router.get("/projects/{project_id}/constraints", response_model=list[schemas.ConstraintOut])
def list_constraints(project_id: int, db: Session = Depends(get_db)):
    return list(
        db.scalars(select(models.Constraint).where(models.Constraint.project_id == project_id))
    )


@router.post("/projects/{project_id}/constraints", response_model=schemas.ConstraintOut)
def create_constraint(project_id: int, body: schemas.ConstraintIn, db: Session = Depends(get_db)):
    if not db.get(models.Project, project_id):
        raise HTTPException(404, "Project not found")
    obj = models.Constraint(project_id=project_id, **body.model_dump())
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


@router.delete("/constraints/{constraint_id}")
def delete_constraint(constraint_id: int, db: Session = Depends(get_db)):
    obj = db.get(models.Constraint, constraint_id)
    if not obj:
        raise HTTPException(404, "Constraint not found")
    db.delete(obj)
    db.commit()
    return {"ok": True}
