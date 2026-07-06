# -*- mode: python ; coding: utf-8 -*-
"""PyInstaller spec — single-file, windowed, portable Windows executable.

Run from the ``desktop`` folder:  pyinstaller build/app.spec
Produces  dist/CommissioningManagementSuite.exe  (no install, no admin).
"""

import os

from PyInstaller.utils.hooks import collect_submodules

# Paths in a .spec resolve relative to the spec file's own folder (build/),
# not the invocation cwd — so anchor everything to the project root (desktop/).
ROOT = os.path.abspath(os.path.join(SPECPATH, os.pardir))
ENTRY = os.path.join(ROOT, "run.py")

# Bundle the app's read-only assets (logo, etc.).
datas = [(os.path.join(ROOT, "app", "resources"), "app/resources")]

# Libraries PyInstaller can miss when they are imported lazily.
hiddenimports = (
    collect_submodules("reportlab")
    + ["openpyxl", "pandas", "docx", "pptx", "PySide6.QtCharts"]
)

# Trim heavy/unused Qt + science stacks to keep the exe smaller.
excludes = [
    "matplotlib", "plotly", "tkinter", "PyQt5", "PyQt6",
    "PySide6.QtWebEngineCore", "PySide6.QtWebEngineWidgets", "PySide6.Qt3D",
]

a = Analysis(
    [ENTRY],
    pathex=[ROOT],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=excludes,
    noarchive=False,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="CommissioningManagementSuite",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    runtime_tmpdir=None,
    console=False,          # windowed GUI app — no console window
    disable_windowed_traceback=False,
    argv_emulation=False,
)
