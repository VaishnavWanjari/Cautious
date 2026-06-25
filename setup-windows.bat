@echo off
REM ==================================================================
REM  Commissioning Scheduler Pro - one-time setup (no admin required)
REM  Installs the Python backend venv and the frontend node modules.
REM ==================================================================
setlocal

echo.
echo === Commissioning Scheduler Pro - setup ===
echo.

where python >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Python 3.11+ not found on PATH. Install from https://python.org
  echo         and tick "Add Python to PATH", then re-run this script.
  pause
  exit /b 1
)

where node >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Node.js 18+ not found on PATH. Install from https://nodejs.org
  pause
  exit /b 1
)

echo [1/3] Creating Python virtual environment...
cd backend
python -m venv .venv
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip
echo [2/3] Installing backend dependencies...
pip install -r requirements.txt
deactivate
cd ..

echo [3/3] Installing frontend dependencies...
cd frontend
call npm install
cd ..

echo.
echo === Setup complete. Run run-windows.bat to start the app. ===
pause
