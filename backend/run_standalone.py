"""Bootstrap entry point for the zero-dependency standalone server.

Running this script (rather than ``python -m app.standalone``) makes the app
work on **every** Python distribution, including Python's *embeddable* build
used for no-admin Windows deployments — where a ``._pth`` file otherwise keeps
the ``app`` package off ``sys.path``. We force this file's directory (the
``backend`` folder) onto ``sys.path`` so ``import app`` always resolves.

    python run_standalone.py        # then open http://127.0.0.1:8000
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.standalone import main  # noqa: E402  (after sys.path fix)

if __name__ == "__main__":
    main()
