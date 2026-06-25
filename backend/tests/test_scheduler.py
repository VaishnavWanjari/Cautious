"""Tests for the CPM backward-scheduling engine (pure stdlib)."""

from datetime import date

from app.domain.calendar import WorkCalendar
from app.domain.entities import ActivityNode, Edge
from app.domain.enums import RelationType
from app.application.scheduler import compute_schedule, detect_cycle


def _chain():
    """Documented sample chain: Hydrotest 7 -> Dewatering 2 -> Drying 5 ->
    Reinstatement 3 -> Leak Test 2 (all Finish-to-Start)."""
    acts = [
        ActivityNode(id="H", name="Hydrotest", duration=7),
        ActivityNode(id="DW", name="Dewatering", duration=2),
        ActivityNode(id="DR", name="Drying", duration=5),
        ActivityNode(id="R", name="Reinstatement", duration=3),
        ActivityNode(id="L", name="Leak Test", duration=2),
    ]
    edges = [
        Edge("H", "DW", RelationType.FS),
        Edge("DW", "DR", RelationType.FS),
        Edge("DR", "R", RelationType.FS),
        Edge("R", "L", RelationType.FS),
    ]
    return acts, edges


def test_single_chain_is_fully_critical_and_anchored():
    acts, edges = _chain()
    cal = WorkCalendar()  # Mon-Fri
    mc = date(2027, 1, 15)  # Friday
    res = compute_schedule(acts, edges, cal, mc)

    by = {a.id: a for a in res.activities}
    # offsets
    assert (by["H"].es, by["H"].ef) == (0, 6)
    assert (by["DW"].es, by["DW"].ef) == (7, 8)
    assert (by["L"].es, by["L"].ef) == (17, 18)

    # every activity on a single chain is critical with zero float
    assert all(a.is_critical for a in res.activities)
    assert all(a.total_float == 0 for a in res.activities)

    # backward anchor: the network finishes exactly on the MC date
    assert res.project_finish == mc
    assert by["L"].finish_date == mc
    assert by["L"].start_date == date(2027, 1, 14)  # Thursday


def test_chain_is_contiguous_across_weekends():
    acts, edges = _chain()
    cal = WorkCalendar()
    res = compute_schedule(acts, edges, cal, date(2027, 1, 15))
    by = {a.id: a for a in res.activities}
    # each FS successor starts the next working day after its predecessor finishes
    for pred, succ in [("H", "DW"), ("DW", "DR"), ("DR", "R"), ("R", "L")]:
        assert by[succ].start_date == cal.add_working_days(by[pred].finish_date, 1)


def test_parallel_branch_has_float():
    # A -> C and A -> B -> C; the short branch (A->C) gains float.
    acts = [
        ActivityNode(id="A", name="A", duration=2),
        ActivityNode(id="B", name="B", duration=5),
        ActivityNode(id="C", name="C", duration=2),
    ]
    edges = [
        Edge("A", "B", RelationType.FS),
        Edge("B", "C", RelationType.FS),
        Edge("A", "C", RelationType.FS),  # direct shortcut
    ]
    res = compute_schedule(acts, edges, WorkCalendar(), date(2027, 6, 30))
    by = {a.id: a for a in res.activities}
    # critical path runs A -> B -> C
    assert by["A"].is_critical and by["B"].is_critical and by["C"].is_critical
    # the direct A->C edge does not change criticality of B; B is on the long path
    assert by["B"].total_float == 0


def test_lag_pushes_successor():
    acts = [
        ActivityNode(id="X", name="X", duration=3),
        ActivityNode(id="Y", name="Y", duration=2),
    ]
    no_lag = compute_schedule(acts[:], [Edge("X", "Y", RelationType.FS, 0)], WorkCalendar(), None)
    with_lag = compute_schedule(
        [ActivityNode(id="X", name="X", duration=3), ActivityNode(id="Y", name="Y", duration=2)],
        [Edge("X", "Y", RelationType.FS, 2)],
        WorkCalendar(),
        None,
    )
    y0 = next(a for a in no_lag.activities if a.id == "Y")
    y2 = next(a for a in with_lag.activities if a.id == "Y")
    assert y2.es == y0.es + 2


def test_start_to_start_relationship():
    acts = [
        ActivityNode(id="M", name="Motor Solo Run", duration=4),
        ActivityNode(id="F", name="Functional Test", duration=3),
    ]
    res = compute_schedule(acts, [Edge("M", "F", RelationType.SS, 3)], WorkCalendar(), None)
    by = {a.id: a for a in res.activities}
    assert by["F"].es == by["M"].es + 3  # SS+3


def test_cycle_detection_blocks_schedule():
    acts = [
        ActivityNode(id="A", name="A", duration=1),
        ActivityNode(id="B", name="B", duration=1),
    ]
    edges = [Edge("A", "B", RelationType.FS), Edge("B", "A", RelationType.FS)]
    assert detect_cycle(acts, edges) is not None

    res = compute_schedule(acts, edges, WorkCalendar(), date(2027, 1, 15))
    assert res.warnings  # refuses to schedule and reports the cycle
    assert res.project_finish is None


def test_empty_network():
    res = compute_schedule([], [], WorkCalendar(), date(2027, 1, 15))
    assert res.activities == []
    assert res.critical_path == []
