@echo off
REM ==================================================================
REM  Commissioning Scheduler Pro - ZERO-DEPENDENCY standalone mode
REM  Runs on the Python standard library only: no pip, no npm needed.
REM  Open http://127.0.0.1:8000 in your browser once it starts.
REM ==================================================================
setlocal

where python >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Python 3.11+ not found on PATH. Install from https://python.org
  pause
  exit /b 1
)

cd backend
echo Starting Commissioning Scheduler Pro (standalone) on http://127.0.0.1:8000 ...
start "" http://127.0.0.1:8000
python -m app.standalone
cd ..

endlocal
