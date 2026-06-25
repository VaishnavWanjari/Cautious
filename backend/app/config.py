"""Application settings and runtime paths.

Settings are read from environment variables (and an optional ``.env`` file)
and cached so the rest of the app can call :func:`get_settings` cheaply.
The app runs fully offline; the only optional secret is ``ANTHROPIC_API_KEY``
for the AI assistant, which degrades gracefully when unset.
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration for the backend."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # --- storage ---------------------------------------------------------
    data_dir: Path = Path(__file__).resolve().parent.parent / "data"
    db_filename: str = "scheduler.db"

    # --- web -------------------------------------------------------------
    cors_origins: str = "http://localhost:5173,http://127.0.0.1:5173,app://."

    # --- AI assistant (optional) ----------------------------------------
    anthropic_api_key: str = ""
    anthropic_model: str = "claude-opus-4-8"

    # --- seeding ---------------------------------------------------------
    seed_on_start: bool = True

    @property
    def db_path(self) -> Path:
        return self.data_dir / self.db_filename

    @property
    def db_url(self) -> str:
        return f"sqlite:///{self.db_path}"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def has_ai(self) -> bool:
        return bool(self.anthropic_api_key)

    def ensure_dirs(self) -> None:
        self.data_dir.mkdir(parents=True, exist_ok=True)
        (self.data_dir / "exports").mkdir(parents=True, exist_ok=True)


@lru_cache
def get_settings() -> Settings:
    return Settings()
