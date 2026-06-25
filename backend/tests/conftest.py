"""Pytest configuration: make the ``app`` package importable from the backend root."""

import sys
from pathlib import Path

# backend/ (parent of tests/) on sys.path so `import app...` works without install
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
