"""Commissioning Scheduler Pro — FastAPI application entrypoint.

Run in development with:

    cd backend
    uvicorn app.main:app --reload
"""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import __version__
from .api import activities, ai, exports, logic, projects, schedule
from .config import get_settings
from .db import init_db
from .infrastructure.ai import claude_client

settings = get_settings()
settings.ensure_dirs()

app = FastAPI(
    title="Commissioning Scheduler Pro API",
    description="EPC pre-commissioning & commissioning planning: backward "
    "scheduling, critical path, visual logic networks and reporting.",
    version=__version__,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(projects.router)
app.include_router(activities.router)
app.include_router(schedule.router)
app.include_router(logic.router)
app.include_router(exports.router)
app.include_router(ai.router)


@app.on_event("startup")
def _startup() -> None:
    init_db()


@app.get("/api/health", tags=["meta"])
def health() -> dict:
    """Liveness probe + capability flags for the UI."""
    return {
        "status": "ok",
        "version": __version__,
        "ai_available": claude_client.is_available(),
        "model": settings.anthropic_model,
    }
