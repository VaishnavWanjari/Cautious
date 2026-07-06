"""Dev/portable launcher: ``python run.py``.

This is also the PyInstaller entry script (see build/app.spec).
"""

from app.main import main

if __name__ == "__main__":
    main()
