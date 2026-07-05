"""Tests for the resource & rental planning module in app.standalone:
catalogue/assignment CRUD state, the rental-cost rollup and CSV round-trip.
Pure standard-library, fully offline — mirrors the shipping standalone build.
"""

import pytest

from app import standalone as sa


@pytest.fixture
def store(tmp_path, monkeypatch):
    """A Store instance backed by a throwaway data file, never the real one."""
    monkeypatch.setattr(sa, "DATA_FILE", tmp_path / "standalone.json")
    return sa.Store()


@pytest.fixture
def seeded(store):
    """Store loaded with the GPT-3/4 sample (incl. the resource catalogue)."""
    store.reset_to_seed()
    return store


def test_blank_store_has_empty_resources(store):
    assert store.resources == []
    assert store.resource_assignments == []
    assert store._next["resource"] == 1
    assert store._next["assignment"] == 1


def test_seed_loads_catalogue_and_assignments(seeded):
    assert len(seeded.resources) == 10
    assert len(seeded.resource_assignments) == 9
    # every assignment references a real catalogue item
    ids = {r["id"] for r in seeded.resources}
    assert all(a["resource_id"] in ids for a in seeded.resource_assignments)


def test_resource_plan_totals_and_categories(seeded):
    plan = seeded.resource_plan()
    assert plan["catalogue_size"] == 10
    assert plan["assignment_count"] == 9
    assert plan["currency"] == "USD"
    # the grand total equals the sum of per-category subtotals...
    cat_total = round(sum(c["cost"] for c in plan["by_category"]), 2)
    assert cat_total == plan["total_cost"]
    # ...and the sum of every line's cost
    line_total = round(sum(l["cost"] for l in plan["lines"]), 2)
    assert line_total == plan["total_cost"]
    # rental cost is a strict subset of the total and non-zero for this sample
    assert 0 < plan["rental_cost"] <= plan["total_cost"]


def test_rental_cost_is_rate_times_qty_times_working_days(store):
    """A single rental line over a known window costs rate x qty x working-days."""
    store.reset_to_blank()
    store.project["working_weekdays"] = [1, 2, 3, 4, 5, 6, 7]  # 7-day week
    store.resources = [
        {"id": 1, "category": "Equipment", "name": "Genset", "code": "EQ-DG",
         "unit": "unit", "ownership": "Rental", "rate": 100.0, "currency": "USD",
         "supplier": "", "notes": ""}
    ]
    # explicit 5-day inclusive window (Mon..Fri span on a 7-day calendar = 5 days)
    store.resource_assignments = [
        {"id": 1, "resource_id": 1, "scope": "PMCC", "pmcc_no": None,
         "activity_id": None, "quantity": 2, "start_date": "2027-01-01",
         "finish_date": "2027-01-05"}
    ]
    store._next = {"activity": 1, "rel": 1, "rule": 1, "resource": 2, "assignment": 2}
    plan = store.resource_plan()
    line = plan["lines"][0]
    assert line["working_days"] == 5
    assert line["cost"] == 100.0 * 2 * 5  # rate x qty x days = 1000
    assert plan["rental_cost"] == 1000.0


def test_owned_consumable_cost_ignores_duration(store):
    """Owned / consumable items cost rate x qty regardless of any window."""
    store.reset_to_blank()
    store.resources = [
        {"id": 1, "category": "Consumable", "name": "Chemical", "code": "C1",
         "unit": "drum", "ownership": "Owned", "rate": 200.0, "currency": "USD",
         "supplier": "", "notes": ""}
    ]
    store.resource_assignments = [
        {"id": 1, "resource_id": 1, "scope": "PMCC", "pmcc_no": None,
         "activity_id": None, "quantity": 3, "start_date": "2027-01-01",
         "finish_date": "2027-03-01"}
    ]
    store._next = {"activity": 1, "rel": 1, "rule": 1, "resource": 2, "assignment": 2}
    plan = store.resource_plan()
    assert plan["lines"][0]["cost"] == 200.0 * 3  # 600, no day multiplier
    assert plan["rental_cost"] == 0.0


def test_peak_concurrent_demand_across_overlapping_spans(store):
    store.reset_to_blank()
    store.resources = [
        {"id": 1, "category": "Tool & Tackle", "name": "Pump", "code": "P1",
         "unit": "unit", "ownership": "Owned", "rate": 0.0, "currency": "USD",
         "supplier": "", "notes": ""}
    ]
    # two spans overlap in the middle -> peak = 2, one span before -> baseline 1
    store.resource_assignments = [
        {"id": 1, "resource_id": 1, "scope": "PMCC", "pmcc_no": None, "activity_id": None,
         "quantity": 1, "start_date": "2027-01-01", "finish_date": "2027-01-10"},
        {"id": 2, "resource_id": 1, "scope": "PMCC", "pmcc_no": None, "activity_id": None,
         "quantity": 1, "start_date": "2027-01-05", "finish_date": "2027-01-15"},
    ]
    store._next = {"activity": 1, "rel": 1, "rule": 1, "resource": 2, "assignment": 3}
    plan = store.resource_plan()
    agg = next(r for r in plan["by_resource"] if r["resource_id"] == 1)
    assert agg["total_quantity"] == 2
    assert agg["peak_demand"] == 2  # both pumps needed 05..10 Jan


def test_pmcc_scope_window_comes_from_the_schedule(store):
    """A PMCC-scoped assignment inherits the PMCC's scheduled start/finish span."""
    store.import_from_csv(
        "pmcc_no,circuit_code,circuit_description,priority\n"
        "PMCC-01,866-A-001,Feed line,A\n"
    )
    store.resources = [
        {"id": 1, "category": "Equipment", "name": "Genset", "code": "EQ-DG",
         "unit": "unit", "ownership": "Rental", "rate": 10.0, "currency": "USD",
         "supplier": "", "notes": ""}
    ]
    store.resource_assignments = [
        {"id": 1, "resource_id": 1, "scope": "PMCC", "pmcc_no": "PMCC-01",
         "activity_id": None, "quantity": 1, "start_date": "", "finish_date": ""}
    ]
    store._next["resource"] = 2
    store._next["assignment"] = 2
    plan = store.resource_plan()
    line = plan["lines"][0]
    assert line["start_date"] and line["finish_date"]  # inferred, not blank
    assert line["working_days"] >= 1
    assert line["cost"] > 0


def test_resources_csv_round_trip(seeded):
    exported = seeded.export_resources_csv()
    header = exported.splitlines()[0]
    assert "record_type" in header and "assign_pmcc" in header

    n_res = len(seeded.resources)
    n_asg = len(seeded.resource_assignments)

    seeded.reset_to_blank()
    result = seeded.import_resources_csv(exported)
    assert result["ok"] is True
    assert not result["errors"]
    assert result["resources_added"] == n_res
    assert result["assignments_added"] == n_asg
    # assignments still resolve to catalogue items after the round-trip
    ids = {r["id"] for r in seeded.resources}
    assert all(a["resource_id"] in ids for a in seeded.resource_assignments)


def test_import_reports_unknown_resource_code(store):
    csv_text = (
        "record_type,code,assign_scope,assign_pmcc,assign_quantity\n"
        "ASSIGNMENT,NOPE,PMCC,PMCC-01,2\n"
    )
    result = store.import_resources_csv(csv_text)
    assert result["assignments_added"] == 0
    assert any("unknown resource code" in e for e in result["errors"])


def test_resources_persist_across_restart(tmp_path, monkeypatch):
    data_file = tmp_path / "standalone.json"
    monkeypatch.setattr(sa, "DATA_FILE", data_file)
    s1 = sa.Store()
    s1.reset_to_seed()
    s1.save()

    s2 = sa.Store()  # simulates an app restart
    assert len(s2.resources) == len(s1.resources)
    assert len(s2.resource_assignments) == len(s1.resource_assignments)
