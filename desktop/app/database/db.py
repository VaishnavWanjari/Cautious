"""Engine / session lifecycle for the currently-open project.

A desktop app has exactly one project open at a time, so a small singleton
``DatabaseManager`` owns the SQLAlchemy engine and hands out sessions. Every
write is committed immediately (auto-save), and a timestamped copy of the
SQLite file is dropped into ``data/backup`` whenever the project closes.
"""

from __future__ import annotations

import shutil
from datetime import datetime
from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from .. import config
from .models import Base, Project


class DatabaseManager:
    """Owns the engine/session for the open project database file."""

    def __init__(self) -> None:
        self._engine = None
        self._Session: sessionmaker | None = None
        self.path: Path | None = None

    # --- lifecycle ----------------------------------------------------------
    def open(self, path: str | Path) -> None:
        """Open (creating if needed) a project database at ``path``."""
        self.close()
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        # future=True + SQLite; check_same_thread off is safe here because the
        # Qt UI is single-threaded and background jobs use their own sessions.
        self._engine = create_engine(
            f"sqlite:///{self.path}",
            future=True,
            connect_args={"check_same_thread": False},
        )
        Base.metadata.create_all(self._engine)
        self._Session = sessionmaker(bind=self._engine, expire_on_commit=False, future=True)
        self._ensure_project_row()

    def close(self) -> None:
        if self._engine is not None:
            self._engine.dispose()
        self._engine = None
        self._Session = None
        self.path = None

    @property
    def is_open(self) -> bool:
        return self._Session is not None

    def session(self) -> Session:
        if self._Session is None:
            raise RuntimeError("No project database is open.")
        return self._Session()

    # --- helpers ------------------------------------------------------------
    def _ensure_project_row(self) -> None:
        """Guarantee a single Project meta row exists."""
        with self.session() as s:
            if s.query(Project).first() is None:
                s.add(Project(name=config.DEFAULT_PROJECT_NAME))
                s.commit()

    def project(self) -> Project | None:
        with self.session() as s:
            return s.query(Project).first()

    def backup(self) -> Path | None:
        """Copy the live SQLite file into the backup folder with a timestamp."""
        if self.path is None or not self.path.exists():
            return None
        config.ensure_dirs()
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        dest = config.BACKUP_DIR / f"{self.path.stem}_{stamp}{self.path.suffix}.bak"
        shutil.copy2(self.path, dest)
        return dest


# Process-wide singleton the whole UI shares.
db = DatabaseManager()
