"""AI assistant endpoint (Anthropic Claude, offline-graceful)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import schemas, services
from ..db import get_db
from ..infrastructure.ai import claude_client

router = APIRouter(prefix="/api", tags=["ai"])


@router.get("/ai/status")
def ai_status():
    return {"available": claude_client.is_available()}


@router.post("/ai/chat", response_model=schemas.AiReply)
def chat(body: schemas.AiQuery, db: Session = Depends(get_db)):
    try:
        context = services.project_summary(db, body.project_id)
    except ValueError as exc:
        raise HTTPException(404, str(exc))
    reply, available = claude_client.ask(body.message, context)
    return {"reply": reply, "ai_available": available}
