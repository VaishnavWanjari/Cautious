# Running on Windows without administrator rights

Commissioning Scheduler Pro runs on locked-down Windows laptops with **no admin
rights, no installer, no pip, no npm and no internet** at run time. It uses the
**standalone** mode — a server built on the Python standard library only — and
opens in your normal browser.

You only need a Python 3.11+ runtime present *somewhere*. Pick whichever of the
two options matches your machine.

---

## Option A — you already have Python (nothing to download)

Many corporate images already ship Python (the `py` launcher). To check, open
**Command Prompt** and run:

```bat
py -3 --version
```

If that prints `Python 3.11` (or newer), you're done:

1. Copy the project folder anywhere you can write (e.g. your Desktop or a USB stick).
2. Double-click **`run-portable-windows.bat`**.
3. Your browser opens at <http://127.0.0.1:8000>. Close the console window to stop.

No admin, no install — the launcher just uses the Python you already have.

---

## Option B — portable "embeddable" Python (no admin, no installer)

If no Python is available, use Python's **embeddable package**. It is a plain
ZIP you *unzip* — there is no installer and it never touches the registry or
`Program Files`, so it needs no administrator rights.

1. On any machine with internet, download
   **`python-3.11.x-embed-amd64.zip`** from
   <https://www.python.org/downloads/windows/> (under *"Windows embeddable
   package (64-bit)"*). Any 3.11/3.12/3.13 embed build works.
2. Unzip it into a folder named **`python`** placed **next to**
   `run-portable-windows.bat`, so you end up with:

   ```
   Commissioning-Scheduler-Pro\
     run-portable-windows.bat
     backend\
     python\
       python.exe      <-- from the embeddable zip
       python311.zip
       ...
   ```
3. Double-click **`run-portable-windows.bat`**. It detects `python\python.exe`
   automatically and starts the app at <http://127.0.0.1:8000>.

The whole folder is now fully self-contained and portable — copy it to a USB
stick and run it on any Windows PC, online or offline, without admin.

> The embeddable build includes the complete Python standard library, which is
> all this app's standalone mode needs. The `run_standalone.py` bootstrap forces
> the correct import path, so the embeddable `._pth` restriction is handled for
> you — no editing required.

---

## What you get

The browser app provides the full Phase-1 experience: project dashboard,
commissioning hierarchy, backward CPM schedule with critical path, the visual
logic network, an interactive Gantt, the no-code logic builder, and HTML/CSV
exports — all computed locally and offline.

### Optional: the AI assistant

The assistant is offline by default. To enable Claude-powered answers, set an
environment variable for your user (no admin needed) before launching:

```bat
set ANTHROPIC_API_KEY=sk-ant-...
run-portable-windows.bat
```

### Want the full desktop app instead?

The richer Electron desktop build (Excel/PDF export, SQLite persistence,
packaged window) is described in the main [README](../README.md). It also
installs per-user without admin, but requires a one-time `pip install` and
`npm install`, so it needs internet during setup. For a locked-down machine,
the standalone mode above is the recommended path.
