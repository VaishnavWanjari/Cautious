"""Import module data from Excel / CSV / JSON.

Header matching is tolerant: a column is matched to a field if it equals the
field's ``name`` or its ``label`` (case/space/underscore-insensitive), so the
same spreadsheets the site already uses import cleanly. Values are coerced to
the field's type before insertion.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from . import repository
from .columns import spec_for


def _norm(s: str) -> str:
    return "".join(ch for ch in str(s).lower() if ch.isalnum())


def _header_map(entity_key: str, headers: list[str]) -> dict[str, str]:
    """Map incoming header -> ORM field name using name/label aliases."""
    specs = [s for s in spec_for(entity_key) if not s.read_only]
    alias: dict[str, str] = {}
    for sp in specs:
        alias[_norm(sp.name)] = sp.name
        alias[_norm(sp.label)] = sp.name
    return {h: alias[_norm(h)] for h in headers if _norm(h) in alias}


def _rows_from_file(path: Path) -> tuple[list[str], list[dict[str, Any]]]:
    suffix = path.suffix.lower()
    if suffix == ".json":
        data = json.loads(path.read_text("utf-8"))
        rows = data if isinstance(data, list) else data.get("rows", [])
        headers = list(rows[0].keys()) if rows else []
        return headers, rows
    # Excel / CSV via pandas (bundled in the exe).
    import pandas as pd

    if suffix in (".xlsx", ".xls"):
        df = pd.read_excel(path)
    else:
        df = pd.read_csv(path)
    df = df.where(df.notna(), None)
    headers = [str(c) for c in df.columns]
    rows = df.to_dict(orient="records")
    return headers, rows


def import_file(entity_key: str, path: str | Path) -> dict[str, Any]:
    """Import a file into ``entity_key``. Returns a small result summary."""
    path = Path(path)
    if not path.exists():
        return {"ok": False, "added": 0, "errors": [f"File not found: {path}"]}
    try:
        headers, raw_rows = _rows_from_file(path)
    except Exception as exc:  # bad/locked file — never crash the UI
        return {"ok": False, "added": 0, "errors": [f"Could not read file: {exc}"]}

    hmap = _header_map(entity_key, headers)
    if not hmap:
        return {"ok": False, "added": 0,
                "errors": ["No recognizable columns. Expected headers like: "
                           + ", ".join(s.label for s in spec_for(entity_key)[:6])]}

    kind_by_field = {s.name: s.kind for s in spec_for(entity_key)}
    clean_rows: list[dict[str, Any]] = []
    for r in raw_rows:
        row: dict[str, Any] = {}
        for header, field_name in hmap.items():
            row[field_name] = repository.coerce(kind_by_field.get(field_name, "text"), r.get(header))
        if any(v not in (None, "", 0) for v in row.values()):
            clean_rows.append(row)

    if not clean_rows:
        return {"ok": False, "added": 0, "errors": ["No usable rows found."]}
    added = repository.bulk_create(entity_key, clean_rows)
    return {"ok": True, "added": added, "errors": [],
            "matched_columns": list(hmap.values())}
