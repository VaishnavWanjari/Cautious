"""Small JSON-backed app settings: recent projects and theme preference.

Stored in the portable ``data/config`` folder so preferences travel with the
app on a USB drive.
"""

from __future__ import annotations

import json
from pathlib import Path

from .. import config


def _read(path: Path, default):
    try:
        return json.loads(path.read_text("utf-8"))
    except Exception:
        return default


def _write(path: Path, data) -> None:
    config.ensure_dirs()
    path.write_text(json.dumps(data, indent=2), "utf-8")


def recent_projects() -> list[str]:
    items = _read(config.RECENT_PROJECTS_FILE, [])
    # keep only paths that still exist
    return [p for p in items if Path(p).exists()]


def add_recent_project(path: str | Path) -> None:
    path = str(Path(path).resolve())
    items = [p for p in _read(config.RECENT_PROJECTS_FILE, []) if p != path]
    items.insert(0, path)
    _write(config.RECENT_PROJECTS_FILE, items[: config.MAX_RECENT_PROJECTS])


def last_project() -> str | None:
    items = recent_projects()
    return items[0] if items else None


def get_setting(key: str, default=None):
    return _read(config.SETTINGS_FILE, {}).get(key, default)


def set_setting(key: str, value) -> None:
    data = _read(config.SETTINGS_FILE, {})
    data[key] = value
    _write(config.SETTINGS_FILE, data)
