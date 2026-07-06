"""Generic CRUD over any registered entity, plus value coercion helpers.

A single repository serves every module (the UI is metadata-driven), so there
is no per-entity boilerplate. Sessions are opened per operation and committed
immediately — that is the app's auto-save.
"""

from __future__ import annotations

from datetime import date, datetime
from typing import Any

from ..database.db import db
from ..database.models import ENTITY_REGISTRY


def model_for(entity_key: str) -> type:
    return ENTITY_REGISTRY[entity_key]


def list_all(entity_key: str, order_by: str = "id") -> list[Any]:
    model = model_for(entity_key)
    with db.session() as s:
        col = getattr(model, order_by, model.id)
        return s.query(model).order_by(col).all()


def get(entity_key: str, obj_id: int) -> Any | None:
    model = model_for(entity_key)
    with db.session() as s:
        return s.get(model, obj_id)


def create(entity_key: str, values: dict[str, Any]) -> Any:
    model = model_for(entity_key)
    with db.session() as s:
        obj = model(**_clean(model, values))
        s.add(obj)
        s.commit()          # auto-save
        s.refresh(obj)
        return obj


def update(entity_key: str, obj_id: int, values: dict[str, Any]) -> Any | None:
    model = model_for(entity_key)
    with db.session() as s:
        obj = s.get(model, obj_id)
        if obj is None:
            return None
        for k, v in _clean(model, values).items():
            setattr(obj, k, v)
        s.commit()          # auto-save
        s.refresh(obj)
        return obj


def delete(entity_key: str, obj_id: int) -> bool:
    model = model_for(entity_key)
    with db.session() as s:
        obj = s.get(model, obj_id)
        if obj is None:
            return False
        s.delete(obj)
        s.commit()
        return True


def delete_many(entity_key: str, ids: list[int]) -> int:
    model = model_for(entity_key)
    with db.session() as s:
        n = s.query(model).filter(model.id.in_(ids)).delete(synchronize_session=False)
        s.commit()
        return n


def bulk_create(entity_key: str, rows: list[dict[str, Any]]) -> int:
    model = model_for(entity_key)
    with db.session() as s:
        objs = [model(**_clean(model, r)) for r in rows]
        s.add_all(objs)
        s.commit()
        return len(objs)


# --- value handling ---------------------------------------------------------
def _clean(model: type, values: dict[str, Any]) -> dict[str, Any]:
    """Keep only real, writable columns and coerce empty strings to sensible
    defaults so a half-filled form never crashes the DB layer."""
    cols = {c.name for c in model.__table__.columns}
    out: dict[str, Any] = {}
    for k, v in values.items():
        if k not in cols or k in ("id", "created_at", "updated_at"):
            continue
        out[k] = v
    return out


def coerce(kind: str, raw: Any) -> Any:
    """Convert a UI/string value into the right Python type for the ORM."""
    if raw is None:
        return None
    if isinstance(raw, str) and raw.strip() == "":
        return None if kind == "date" else ("" if kind in ("text", "longtext", "choice") else 0)
    try:
        if kind in ("int",):
            return int(float(raw))
        if kind in ("float", "percent"):
            return float(raw)
        if kind == "date":
            if isinstance(raw, date):
                return raw
            return datetime.fromisoformat(str(raw)[:10]).date()
    except (ValueError, TypeError):
        return None if kind == "date" else 0
    return str(raw)


def display_value(obj: Any, spec_name: str) -> Any:
    """Read a field for display, supporting computed @property columns."""
    val = getattr(obj, spec_name, "")
    if isinstance(val, date):
        return val.isoformat()
    return val
