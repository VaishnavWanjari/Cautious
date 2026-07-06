"""Application configuration and portable path resolution.

Everything the app writes (database, backups, exports, reports, logs, config)
lives in a ``data`` folder next to the executable, so the whole thing is
portable: copy the folder (or the single .exe) to a USB stick and it carries
its data with it. No registry keys, no AppData, no admin rights.
"""

from __future__ import annotations

import sys
from pathlib import Path


def app_base_dir() -> Path:
    """Directory the app treats as its home.

    When frozen by PyInstaller (``--onefile``) ``sys.executable`` is the path
    to the running .exe, so data sits beside it. In development it is the
    ``desktop`` project folder.
    """
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent.parent


BASE_DIR = app_base_dir()

# Portable data tree (created on first run).
DATA_DIR = BASE_DIR / "data"
DATABASE_DIR = DATA_DIR / "database"
BACKUP_DIR = DATA_DIR / "backup"
EXPORT_DIR = DATA_DIR / "exports"
IMPORT_DIR = DATA_DIR / "imports"
REPORT_DIR = DATA_DIR / "reports"
LOG_DIR = DATA_DIR / "logs"
CONFIG_DIR = DATA_DIR / "config"

# Read-only assets bundled with the app (icons, templates, sample files).
ASSETS_DIR = Path(__file__).resolve().parent / "resources"

RECENT_PROJECTS_FILE = CONFIG_DIR / "recent_projects.json"
SETTINGS_FILE = CONFIG_DIR / "settings.json"

DEFAULT_PROJECT_NAME = "Commissioning Project"
DB_SUFFIX = ".cmsdb"  # SQLite file extension for a project database

# How many recent projects to remember on the startup screen.
MAX_RECENT_PROJECTS = 8

# Consumable low-stock alert fires when balance falls to/below this fraction of
# the required quantity.
LOW_STOCK_FRACTION = 0.15


def ensure_dirs() -> None:
    """Create the portable data tree if it does not exist yet."""
    for d in (
        DATA_DIR, DATABASE_DIR, BACKUP_DIR, EXPORT_DIR, IMPORT_DIR,
        REPORT_DIR, LOG_DIR, CONFIG_DIR,
    ):
        d.mkdir(parents=True, exist_ok=True)
