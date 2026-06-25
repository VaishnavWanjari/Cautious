"""Tests for the no-code logic engine parser (pure stdlib)."""

from app.application.logic_engine import (
    atoms_of,
    compile_rule,
    parse_action,
    parse_condition,
)


def test_single_atom():
    tree = parse_condition("Hydrotest Complete")
    assert tree == {"atom": "Hydrotest Complete"}


def test_and_condition():
    tree = parse_condition("Hydrotest Complete AND Nitrogen Available")
    assert tree["op"] == "AND"
    assert atoms_of(tree) == ["Hydrotest Complete", "Nitrogen Available"]


def test_or_condition():
    tree = parse_condition("Temporary Power Available OR Permanent Power Available")
    assert tree["op"] == "OR"
    assert len(tree["children"]) == 2


def test_not_condition():
    tree = parse_condition("NOT Area Released")
    assert tree["op"] == "NOT"
    assert tree["children"][0] == {"atom": "Area Released"}


def test_precedence_and_binds_tighter_than_or():
    # A OR B AND C  ==  A OR (B AND C)
    tree = parse_condition("A OR B AND C")
    assert tree["op"] == "OR"
    second = tree["children"][1]
    assert second["op"] == "AND"


def test_nested_parentheses():
    tree = parse_condition("(Loop Check Complete OR Bypassed) AND Power Available")
    assert tree["op"] == "AND"
    assert tree["children"][0]["op"] == "OR"


def test_parse_action_enable():
    assert parse_action("Enable Dewatering") == {"verb": "enable", "target": "Dewatering"}
    assert parse_action("Leak Test Can Start")["verb"] == "enable"


def test_parse_action_block():
    parsed = parse_action("Block Commissioning")
    assert parsed == {"verb": "block", "target": "Commissioning"}


def test_compile_rule_roundtrip():
    compiled = compile_rule("Hydrotest Complete", "Enable Dewatering")
    assert compiled["condition"] == {"atom": "Hydrotest Complete"}
    assert compiled["action"]["target"] == "Dewatering"
