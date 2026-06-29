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

echo Starting Commissioning Scheduler Pro (standalone) ...
echo The app will open in your browser automatically once it is ready.
echo (Keep this window open while using the app; close it to stop.)
echo.
python "%~dp0backend\run_standalone.py"
echo.
echo The app has stopped. Press any key to close this window.
pause >nul

endlocal
