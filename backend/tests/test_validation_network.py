"""Tests for network validation and React Flow layout (pure stdlib)."""

from app.domain.entities import ActivityNode, Edge
from app.domain.enums import RelationType
from app.application.network import build_network
from app.application.validation import validate_network


def test_detects_orphan_and_endpoints():
    acts = [
        ActivityNode(id="A", name="A", duration=1),
        ActivityNode(id="B", name="B", duration=1),
        ActivityNode(id="ORPH", name="Orphan", duration=1),
    ]
    edges = [Edge("A", "B", RelationType.FS)]
    warnings, errors = validate_network(acts, edges)
    assert any("Orphan" in w for w in warnings)
    assert any("predecessor" in w.lower() for w in warnings)  # A is a start node
    assert any("successor" in w.lower() for w in warnings)  # B is an end node
    assert errors == []


def test_detects_cycle_as_error():
    acts = [ActivityNode(id="A", name="A", duration=1), ActivityNode(id="B", name="B", duration=1)]
    edges = [Edge("A", "B", RelationType.FS), Edge("B", "A", RelationType.FS)]
    _warnings, errors = validate_network(acts, edges)
    assert any("Circular" in e for e in errors)


def test_broken_reference_is_error():
    acts = [ActivityNode(id="A", name="A", duration=1)]
    edges = [Edge("A", "GHOST", RelationType.FS)]
    _warnings, errors = validate_network(acts, edges)
    assert any("missing successor" in e.lower() for e in errors)


def test_build_network_ranks_and_edges():
    acts = [
        ActivityNode(id="A", name="A", duration=1, is_critical=True),
        ActivityNode(id="B", name="B", duration=1),
        ActivityNode(id="C", name="C", duration=1),
    ]
    edges = [Edge("A", "B", RelationType.FS), Edge("B", "C", RelationType.FS, 2)]
    net = build_network(acts, edges)
    assert len(net["nodes"]) == 3
    assert len(net["edges"]) == 2
    pos = {n["id"]: n["position"]["x"] for n in net["nodes"]}
    # ranks increase along the chain
    assert pos["A"] < pos["B"] < pos["C"]
    # lag is rendered in the edge label
    bc = next(e for e in net["edges"] if e["id"] == "B-C")
    assert bc["label"] == "FS+2"
    # critical flag flows into node data
    a_node = next(n for n in net["nodes"] if n["id"] == "A")
    assert a_node["data"]["isCritical"] is True


def test_persisted_positions_take_precedence():
    acts = [ActivityNode(id="A", name="A", duration=1)]
    net = build_network(acts, [], positions={"A": (123.0, 45.0)})
    assert net["nodes"][0]["position"] == {"x": 123.0, "y": 45.0}
