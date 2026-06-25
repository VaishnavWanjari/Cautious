"""Map a scheduled network into React Flow nodes/edges with auto-layout.

Layout ranks each activity by its longest-path depth from a start node (a
"dagre-style" layered layout). The frontend can override positions by dragging;
persisted ``pos_x/pos_y`` take precedence when present.
"""

from __future__ import annotations

from ..domain.entities import ActivityNode, Edge
from .graph import DiGraph

_RANK_GAP_X = 260
_NODE_GAP_Y = 130


def _ranks(activities: list[ActivityNode], edges: list[Edge]) -> dict[str, int]:
    g = DiGraph()
    for a in activities:
        g.add_node(a.id)
    for e in edges:
        if e.predecessor_id in g and e.successor_id in g:
            g.add_edge(e.predecessor_id, e.successor_id)
    rank: dict[str, int] = {}
    try:
        order = g.topological_sort()
    except ValueError:
        # cyclic: fall back to insertion order, single rank
        return {a.id: 0 for a in activities}
    for n in order:
        preds = list(g.predecessors(n))
        rank[n] = 0 if not preds else max(rank[p] for p in preds) + 1
    return rank


def build_network(
    activities: list[ActivityNode],
    edges: list[Edge],
    positions: dict[str, tuple[float, float]] | None = None,
) -> dict:
    """Return ``{"nodes": [...], "edges": [...]}`` for React Flow."""
    positions = positions or {}
    rank = _ranks(activities, edges)

    # vertical slot per rank for auto-placed nodes
    slot: dict[int, int] = {}
    nodes = []
    for a in activities:
        if a.id in positions:
            x, y = positions[a.id]
        else:
            r = rank.get(a.id, 0)
            s = slot.get(r, 0)
            slot[r] = s + 1
            x, y = r * _RANK_GAP_X, s * _NODE_GAP_Y
        nodes.append(
            {
                "id": a.id,
                "position": {"x": float(x), "y": float(y)},
                "data": {
                    "activityId": a.id,
                    "name": a.name,
                    "duration": a.duration,
                    "discipline": a.discipline,
                    "status": a.status,
                    "priority": a.priority,
                    "startDate": a.start_date.isoformat() if a.start_date else None,
                    "finishDate": a.finish_date.isoformat() if a.finish_date else None,
                    "totalFloat": a.total_float,
                    "isCritical": a.is_critical,
                },
            }
        )

    edge_out = []
    for e in edges:
        label = e.rel_type.value if hasattr(e.rel_type, "value") else str(e.rel_type)
        if e.lag:
            label += f"{'+' if e.lag > 0 else ''}{e.lag}"
        edge_out.append(
            {
                "id": f"{e.predecessor_id}-{e.successor_id}",
                "source": e.predecessor_id,
                "target": e.successor_id,
                "label": label,
                "animated": False,
            }
        )

    return {"nodes": nodes, "edges": edge_out}
