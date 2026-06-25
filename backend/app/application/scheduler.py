"""Critical Path Method (CPM) engine with backward anchoring.

The engine works in two layers:

1. **Working-day offsets** — a forward pass computes early start/finish (ES/EF)
   and a backward pass computes late start/finish (LS/LF) as 0-based inclusive
   working-day indices. Total float = LS - ES; an activity is critical when its
   float is <= 0.
2. **Calendar dates** — the network is *anchored* so its latest finish lands on
   the project's Mechanical Completion date. The required project start date is
   derived from that anchor, then every activity's offsets are mapped onto real
   calendar dates via :class:`WorkCalendar` (skipping weekends/holidays).

This is the standard CPM presentation: forward pass for early dates, backward
pass for late dates, project finish pinned to the Mechanical Completion date so
predecessor start dates are *back-calculated* from it.

Inclusive-span convention (see ``domain/calendar``): EF = ES + duration - 1,
so a 1-day activity has EF == ES.
"""

from __future__ import annotations

from datetime import date

from ..domain.calendar import WorkCalendar
from ..domain.entities import ActivityNode, Edge, ScheduleResult
from ..domain.enums import RelationType
from .graph import DiGraph


def _build_graph(activities: list[ActivityNode], edges: list[Edge]) -> DiGraph:
    g = DiGraph()
    for a in activities:
        g.add_node(a.id, activity=a)
    for e in edges:
        if e.predecessor_id in g and e.successor_id in g:
            g.add_edge(e.predecessor_id, e.successor_id, edge=e)
    return g


def detect_cycle(activities: list[ActivityNode], edges: list[Edge]) -> list[str] | None:
    """Return the node ids forming a cycle, or ``None`` if the network is acyclic."""
    g = _build_graph(activities, edges)
    return g.find_cycle()


def compute_schedule(
    activities: list[ActivityNode],
    edges: list[Edge],
    calendar: WorkCalendar,
    mechanical_completion: date | None,
) -> ScheduleResult:
    """Run the CPM forward/backward passes and map offsets to calendar dates."""
    result = ScheduleResult(activities=activities)
    if not activities:
        return result

    g = _build_graph(activities, edges)

    # --- guard: cyclic networks cannot be scheduled ----------------------
    cyc = detect_cycle(activities, edges)
    if cyc is not None:
        result.warnings.append(
            "Circular logic detected (" + " -> ".join(cyc) + "); cannot schedule."
        )
        return result

    order = g.topological_sort()
    by_id = {a.id: a for a in activities}
    dur = {a.id: max(1, int(a.duration)) for a in activities}

    # --- forward pass: ES / EF ------------------------------------------
    es: dict[str, int] = {}
    for node in order:
        earliest = 0
        for pred in g.predecessors(node):
            edge: Edge = g.edge_attr(pred, node)["edge"]
            lag = edge.lag
            pe_s, pe_f = es[pred], es[pred] + dur[pred] - 1
            if edge.rel_type == RelationType.FS:
                earliest = max(earliest, pe_f + 1 + lag)
            elif edge.rel_type == RelationType.SS:
                earliest = max(earliest, pe_s + lag)
            elif edge.rel_type == RelationType.FF:
                earliest = max(earliest, pe_f + lag - (dur[node] - 1))
            elif edge.rel_type == RelationType.SF:
                earliest = max(earliest, pe_s + lag - (dur[node] - 1))
        es[node] = max(0, earliest)

    ef = {n: es[n] + dur[n] - 1 for n in order}
    project_finish_idx = max(ef.values())

    # --- backward pass: LS / LF -----------------------------------------
    lf: dict[str, int] = {}
    for node in reversed(order):
        latest = project_finish_idx
        for succ in g.successors(node):
            edge: Edge = g.edge_attr(node, succ)["edge"]
            lag = edge.lag
            ss_s, ss_f = lf[succ] - dur[succ] + 1, lf[succ]
            if edge.rel_type == RelationType.FS:
                latest = min(latest, ss_s - 1 - lag)
            elif edge.rel_type == RelationType.SS:
                latest = min(latest, ss_s - lag + (dur[node] - 1))
            elif edge.rel_type == RelationType.FF:
                latest = min(latest, ss_f - lag)
            elif edge.rel_type == RelationType.SF:
                latest = min(latest, ss_f - lag + (dur[node] - 1))
        lf[node] = latest

    ls = {n: lf[n] - dur[n] + 1 for n in order}

    # --- write offsets + float + criticality ----------------------------
    for n in order:
        a = by_id[n]
        a.es, a.ef, a.ls, a.lf = es[n], ef[n], ls[n], lf[n]
        a.total_float = ls[n] - es[n]
        a.is_critical = a.total_float <= 0

    # --- map offsets onto calendar dates (backward anchor) --------------
    if mechanical_completion is not None:
        mc = calendar.next_working_day(mechanical_completion)
        # project finish offset maps to the Mechanical Completion date
        project_start_date = calendar.add_working_days(mc, -project_finish_idx)
        result.project_start = project_start_date
        result.project_finish = mc
        for n in order:
            a = by_id[n]
            a.start_date = calendar.add_working_days(project_start_date, a.es or 0)
            a.finish_date = calendar.add_working_days(project_start_date, a.ef or 0)

    # --- critical path (longest chain of critical activities) -----------
    result.critical_path = _critical_path(g, by_id)
    return result


def _critical_path(g: DiGraph, by_id: dict[str, ActivityNode]) -> list[str]:
    """Critical activities ordered into a readable chain by early start/finish."""
    crit_nodes = [n for n in g.nodes if by_id[n].is_critical]
    if not crit_nodes:
        return []
    # order critical nodes by early start to present a readable chain
    return sorted(crit_nodes, key=lambda n: (by_id[n].es or 0, by_id[n].ef or 0))
