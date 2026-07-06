"""Application entry point.

Boots Qt, restores the theme, runs the startup / reload-previous flow, opens
(or creates) the chosen SQLite project and shows the main window.
"""

from __future__ import annotations

import sys

from PySide6.QtGui import QIcon
from PySide6.QtWidgets import QApplication, QMessageBox

from . import __app_name__, config
from .core import settings
from .database.db import db
from .database.seed import seed_sample_project
from .ui.main_window import MainWindow
from .ui.dialogs.startup import StartupDialog
from .ui.theme import build_qss


def _app_icon() -> QIcon:
    svg = config.ASSETS_DIR / "logo.svg"
    return QIcon(str(svg)) if svg.exists() else QIcon()


def run() -> int:
    config.ensure_dirs()
    app = QApplication(sys.argv)
    app.setApplicationName(__app_name__)
    app.setWindowIcon(_app_icon())
    app.setStyleSheet(build_qss(settings.get_setting("dark_theme", True)))

    project_path: str | None = None
    seed = False

    # Offer to reload the previous session directly.
    last = settings.last_project()
    if last:
        ask = QMessageBox()
        ask.setWindowTitle(__app_name__)
        ask.setText(f"Reload previous project?\n\n{last}")
        ask.setStandardButtons(QMessageBox.Yes | QMessageBox.No)
        ask.setDefaultButton(QMessageBox.Yes)
        if ask.exec() == QMessageBox.Yes:
            project_path = last

    if project_path is None:
        dlg = StartupDialog()
        if not dlg.exec():
            return 0  # user cancelled startup
        project_path = dlg.selected_path
        seed = dlg.seed_sample

    if not project_path:
        return 0

    db.open(project_path)
    if seed:
        seed_sample_project()
    settings.add_recent_project(project_path)

    win = MainWindow()
    win.show()
    return app.exec()


def main() -> None:
    sys.exit(run())


if __name__ == "__main__":
    main()
