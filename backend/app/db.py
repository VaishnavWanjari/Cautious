"""SQLAlchemy engine/session wiring for the SQLite database."""

from __future__ import annotations

from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from .config import get_settings

_settings = get_settings()
_settings.ensure_dirs()

# check_same_thread=False lets the dev server share the connection across
# FastAPI's threadpool; SQLite file access is still serialized by SQLAlchemy.
engine = create_engine(
    _settings.db_url,
    connect_args={"check_same_thread": False},
    future=True,
)

SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False, future=True)


def init_db() -> None:
    """Create tables (and optionally seed) on startup."""
    from .infrastructure import models  # noqa: F401  (register mappers)

    models.Base.metadata.create_all(engine)

    if _settings.seed_on_start:
        from .infrastructure.seed import seed_if_empty

        with SessionLocal() as session:
            seed_if_empty(session)


def get_db() -> Iterator[Session]:
    """FastAPI dependency yielding a scoped session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
