@echo off
REM ==================================================================
REM  Commissioning Scheduler Pro - launch backend + Electron desktop
REM ==================================================================
setlocal

echo Starting backend (FastAPI on http://127.0.0.1:8000) ...
cd backend
start "Scheduler Backend" cmd /c ".venv\Scripts\python.exe -m uvicorn app.main:app --port 8000"
cd ..

echo Waiting for backend to come up...
timeout /t 4 /nobreak >nul

echo Starting desktop app...
cd frontend
call npm run dev:electron
cd ..

endlocal
