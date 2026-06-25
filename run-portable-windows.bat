@echo off
REM ==================================================================
REM  Commissioning Scheduler Pro - PORTABLE, NO-ADMIN Windows launcher
REM
REM  Needs NO administrator rights, NO installer, NO pip, NO npm and
REM  NO internet. Runs the zero-dependency standalone server using
REM  whichever Python it can find:
REM    1) a bundled embeddable Python in .\python\python.exe   (fully self-contained)
REM    2) the "py" launcher (any per-user Python install)
REM    3) "python" on PATH
REM  See docs\WINDOWS-NO-ADMIN.md to set up option 1 without admin.
REM ==================================================================
setlocal
set "ROOT=%~dp0"
set "ENTRY=%ROOT%backend\run_standalone.py"

set "PY="
if exist "%ROOT%python\python.exe" set "PY=%ROOT%python\python.exe"
if not defined PY ( where py >nul 2>nul && set "PY=py -3" )
if not defined PY ( where python >nul 2>nul && set "PY=python" )

if not defined PY (
  echo.
  echo [No Python found]
  echo This app needs Python 3.11+ but does NOT need admin rights.
  echo Open docs\WINDOWS-NO-ADMIN.md for a 2-minute, no-admin setup
  echo using Python's portable "embeddable" zip ^(just unzip a folder^).
  echo.
  pause
  exit /b 1
)

echo Starting Commissioning Scheduler Pro at http://127.0.0.1:8000 ...
echo (Close this window to stop the app.)
start "" http://127.0.0.1:8000
%PY% "%ENTRY%"
endlocal
