"""Network validation: surface logic problems before/after scheduling."""

from __future__ import annotations

from ..domain.entities import ActivityNode, Edge
from .scheduler import detect_cycle


def validate_network(
    activities: list[ActivityNode], edges: list[Edge]
) -> tuple[list[str], list[str]]:
    """Return ``(warnings, errors)`` describing problems in the network."""
    warnings: list[str] = []
    errors: list[str] = []

    ids = {a.id for a in activities}
    name_of = {a.id: a.name for a in activities}

    # broken relationship references
    for e in edges:
        if e.predecessor_id not in ids:
            errors.append(
                f"Relationship references missing predecessor '{e.predecessor_id}'."
            )
        if e.successor_id not in ids:
            errors.append(
                f"Relationship references missing successor '{e.successor_id}'."
            )

    # circular logic
    cyc = detect_cycle(activities, edges)
    if cyc is not None:
        errors.append("Circular logic: " + " -> ".join(name_of.get(n, n) for n in cyc))

    # Orphan detection only. This network is intentionally many independent
    # precedence chains (one per commissioning circuit), each with its own
    # legitimate start node(s) (no predecessor) and end node (no successor) —
    # that is expected, correct structure, not a defect, so it is not flagged.
    # An activity with *no* relationships at all (neither predecessor nor
    # successor) is the only genuinely suspicious case: it suggests the
    # activity was never wired into its circuit's logic.
    has_pred = {e.successor_id for e in edges if e.successor_id in ids}
    has_succ = {e.predecessor_id for e in edges if e.predecessor_id in ids}

    if len(activities) > 1:
        for a in activities:
            if a.id not in has_pred and a.id not in has_succ:
                warnings.append(f"Orphan activity (no logic links): {a.name}")

    return warnings, errors
