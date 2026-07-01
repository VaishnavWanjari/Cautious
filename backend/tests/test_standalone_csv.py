"""Tests for the blank-by-default Store and CSV template import/export/priority
staggering/cross-PMCC scheduling constraints in app.standalone."""

import json

import pytest

from app import standalone as sa


@pytest.fixture
def store(tmp_path, monkeypatch):
    """A Store instance backed by a throwaway data file, never the real one."""
    monkeypatch.setattr(sa, "DATA_FILE", tmp_path / "standalone.json")
    return sa.Store()


def test_blank_by_default(store):
    assert store.pmccs == []
    assert store.activities == []
    assert store.relationships == []
    assert store.project["name"] == "New Commissioning Project"


def test_renaming_project_does_not_wipe_saved_data(tmp_path, monkeypatch):
    data_file = tmp_path / "standalone.json"
    monkeypatch.setattr(sa, "DATA_FILE", data_file)

    s1 = sa.Store()
    s1.import_from_csv(
        "pmcc_no,circuit_code,circuit_description,priority\n"
        "PMCC-01,866-A-001,Test line,A\n"
    )
    s1.project["name"] = "My Real Plant"
    s1.save()

    s2 = sa.Store()  # simulates an app restart
    assert s2.project["name"] == "My Real Plant"
    assert len(s2.activities) > 0


def test_import_basic_circuit_and_building(store):
    csv_text = (
        "pmcc_no,pmcc_category,pmcc_description,circuit_code,circuit_description,"
        "priority,special_activity,building_duration_days,depends_on\n"
        "PMCC-01,Non-Process,Substation,,,,,,45\n"
        "PMCC-02,Process,Feed train,866-A-001,Feed line,A,Chemical Cleaning,,\n"
    )
    result = store.import_from_csv(csv_text)
    assert result["ok"] is True
    assert result["pmccs"] == 2
    assert result["buildings"] == 1
    assert result["circuits"] == 1
    assert not result["errors"]
    assert len(store.pmccs) == 2
    assert len(store.activities) > 1


def test_duplicate_circuit_code_is_skipped_with_warning(store):
    csv_text = (
        "pmcc_no,circuit_code,circuit_description,priority\n"
        "PMCC-01,866-A-001,First,A\n"
        "PMCC-01,866-A-001,Duplicate,A\n"
    )
    result = store.import_from_csv(csv_text)
    assert result["ok"] is True
    assert result["circuits"] == 1
    assert any("duplicate circuit_code" in w for w in result["warnings"])


def test_bad_upload_never_touches_existing_data(store):
    store.import_from_csv("pmcc_no,circuit_code,circuit_description,priority\nPMCC-01,866-A-001,Feed,A\n")
    assert len(store.pmccs) == 1

    result = store.import_from_csv("not,a,valid,header\n1,2,3,4\n")
    assert result["ok"] is False
    assert len(store.pmccs) == 1  # untouched


def test_priority_staggering_10_working_days_apart(store):
    csv_text = (
        "pmcc_no,pmcc_priority,circuit_code,circuit_description,priority\n"
        "PMCC-01,1,866-A-001,Line A,A\n"
        "PMCC-02,2,866-A-002,Line B,A\n"
        "PMCC-03,3,866-A-003,Line C,A\n"
    )
    store.import_from_csv(csv_text)
    store.project["working_weekdays"] = [1, 2, 3, 4, 5, 6, 7]  # 7-day week for exact day math
    store.save()

    anchors = {p["no"]: store._pmcc_anchor(p["no"]) for p in store.pmccs}
    # priority 3 (== N) lands exactly on the project MC date
    mc = sa.date.fromisoformat(store.project["mechanical_completion_date"])
    assert anchors["PMCC-03"] == mc
    assert (anchors["PMCC-03"] - anchors["PMCC-02"]).days == 10
    assert (anchors["PMCC-02"] - anchors["PMCC-01"]).days == 10


def test_explicit_pmcc_finish_override_beats_priority_default(store):
    store.import_from_csv(
        "pmcc_no,pmcc_priority,circuit_code,circuit_description,priority\n"
        "PMCC-01,1,866-A-001,Line A,A\n"
        "PMCC-02,2,866-A-002,Line B,A\n"
    )
    store.pmcc_finish["PMCC-01"] = "2030-01-01"
    assert store._pmcc_anchor("PMCC-01") == sa.date(2030, 1, 1)


def test_intra_pmcc_circuit_dependency_becomes_real_precedence_edge(store):
    store.import_from_csv(
        "pmcc_no,circuit_code,circuit_description,priority,depends_on\n"
        "PMCC-01,866-A-001,Upstream,A,\n"
        "PMCC-01,866-A-002,Downstream,A,866-A-001\n"
    )
    upstream_ids = {a["id"] for a in store.activities if a["circuit"] == "866-A-001"}
    downstream_first = min(a["id"] for a in store.activities if a["circuit"] == "866-A-002")
    # the downstream circuit's first activity has an incoming edge from the
    # upstream circuit's last activity (real CPM constraint, not just a label)
    incoming = [r for r in store.relationships if r["successor_id"] == downstream_first]
    assert any(r["predecessor_id"] in upstream_ids for r in incoming)


def test_cross_pmcc_dependency_delays_downstream(store):
    store.import_from_csv(
        "pmcc_no,pmcc_priority,circuit_code,circuit_description,priority,depends_on\n"
        "PMCC-01,1,866-A-001,Utility line,A,\n"
        "PMCC-02,2,866-B-001,Process line,A,PMCC-01\n"
    )
    sched = store.compute()
    by_id = {a["id"]: a for a in sched["activities"]}
    upstream_finish = max(
        sa.date.fromisoformat(by_id[a["id"]]["finish_date"])
        for a in store.activities if a["pmcc_no"] == "PMCC-01"
    )
    downstream_start = min(
        sa.date.fromisoformat(by_id[a["id"]]["start_date"])
        for a in store.activities if a["pmcc_no"] == "PMCC-02"
    )
    assert downstream_start > upstream_finish


def test_cross_pmcc_dependency_warns_when_it_overruns_the_target(store):
    store.import_from_csv(
        "pmcc_no,pmcc_priority,circuit_code,circuit_description,priority,depends_on\n"
        "PMCC-01,1,866-A-001,Utility line,A,\n"
        "PMCC-02,2,866-B-001,Process line,A,PMCC-01\n"
    )
    # force PMCC-02's own target finish earlier than PMCC-01 can possibly
    # finish, so the dependency floor is guaranteed to blow past it
    store.pmcc_finish["PMCC-02"] = store.project["mechanical_completion_date"]
    store.pmcc_finish["PMCC-01"] = store.project["mechanical_completion_date"]
    sched = store.compute()
    assert any("cross-PMCC dependency" in w for w in sched["warnings"])


def test_priority_vs_depends_on_conflict_is_a_warning_not_a_block(store):
    # PMCC-01 (priority 1 = finishes earliest) depends on PMCC-02 (priority 2
    # = finishes later) -- contradictory inputs that must coexist, not error.
    result = store.import_from_csv(
        "pmcc_no,pmcc_priority,circuit_code,circuit_description,priority,depends_on\n"
        "PMCC-01,1,866-A-001,Line A,A,PMCC-02\n"
        "PMCC-02,2,866-B-001,Line B,A,\n"
    )
    assert result["ok"] is True
    assert not result["errors"]
    assert any("priority and dependency targets conflict" in w for w in result["warnings"])


def test_duplicate_priority_is_a_tie_warning_not_blocked(store):
    result = store.import_from_csv(
        "pmcc_no,pmcc_priority,circuit_code,circuit_description,priority\n"
        "PMCC-01,1,866-A-001,Line A,A\n"
        "PMCC-02,1,866-B-001,Line B,A\n"
    )
    assert result["ok"] is True
    assert any("treated as a tie" in w for w in result["warnings"])


def test_export_round_trips_cleanly(store):
    original_csv = (
        "pmcc_no,pmcc_category,pmcc_description,pmcc_priority,circuit_code,"
        "circuit_description,priority,special_activity,depends_on\n"
        "PMCC-01,Utility,Utility train,1,866-A-001,Feed line,A,Chemical Cleaning,\n"
        "PMCC-02,Process,Process train,2,866-B-001,Sep line,A,,PMCC-01\n"
    )
    r1 = store.import_from_csv(original_csv)
    assert r1["ok"]
    exported = store.export_to_csv()

    store.reset_to_blank()
    r2 = store.import_from_csv(exported)
    assert r2["ok"] is True
    assert not r2["errors"]
    assert not r2["warnings"]
    assert r2["pmccs"] == r1["pmccs"]
    assert r2["activities"] == r1["activities"]


def test_template_csv_has_required_header(store):
    text = store.template_csv()
    header = text.splitlines()[0]
    assert "pmcc_no" in header
    assert "depends_on" in header
