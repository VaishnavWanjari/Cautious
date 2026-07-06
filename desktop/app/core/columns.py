"""Field specifications that drive the generic table pages, editors,
importers and exporters from a single source of truth.

Adding a column to a module is a one-line change here — the table view, the
add/edit dialog, Excel import and Excel export all read the same spec.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from ..database.models import DISCIPLINES, EQUIPMENT_TYPES, MANPOWER_AGENCIES, PRIORITIES, Status


@dataclass
class FieldSpec:
    name: str                       # ORM attribute
    label: str                      # column header / form label
    kind: str = "text"              # text | int | float | date | choice | percent | longtext
    choices: list[str] = field(default_factory=list)
    width: int = 120
    read_only: bool = False         # computed columns (e.g. balance)


# Per-entity column layout. Order = display order.
COLUMNS: dict[str, list[FieldSpec]] = {
    "pmcc": [
        FieldSpec("number", "PMCC No.", width=110),
        FieldSpec("description", "Description", width=280),
        FieldSpec("subsystem", "Subsystem", width=110),
        FieldSpec("system", "System", width=120),
        FieldSpec("area", "Area", width=130),
        FieldSpec("discipline", "Discipline", "choice", DISCIPLINES, 130),
        FieldSpec("contractor", "Contractor", width=140),
        FieldSpec("status", "Status", "choice", Status.PMCC, 110),
        FieldSpec("priority", "Priority", "choice", PRIORITIES, 90),
        FieldSpec("completion", "% Complete", "percent", width=95),
        FieldSpec("target_date", "Target", "date", width=105),
        FieldSpec("actual_date", "Actual", "date", width=105),
        FieldSpec("remarks", "Remarks", "longtext", width=200),
    ],
    "equipment": [
        FieldSpec("tag_number", "Tag No.", width=110),
        FieldSpec("description", "Description", width=260),
        FieldSpec("area", "Area", width=130),
        FieldSpec("subsystem", "Subsystem", width=110),
        FieldSpec("system", "System", width=120),
        FieldSpec("discipline", "Discipline", "choice", DISCIPLINES, 130),
        FieldSpec("equipment_type", "Type", "choice", EQUIPMENT_TYPES, 100),
        FieldSpec("status", "Status", "choice", Status.EQUIPMENT, 120),
        FieldSpec("completion", "% Complete", "percent", width=95),
        FieldSpec("remarks", "Remarks", "longtext", width=200),
    ],
    "procedure": [
        FieldSpec("number", "Proc. No.", width=110),
        FieldSpec("title", "Title", width=320),
        FieldSpec("revision", "Rev", width=60),
        FieldSpec("responsible", "Responsible", width=140),
        FieldSpec("status", "Status", "choice", Status.PROCEDURE, 120),
        FieldSpec("remarks", "Remarks", "longtext", width=220),
    ],
    "preservation": [
        FieldSpec("tag_number", "Tag No.", width=110),
        FieldSpec("description", "Description", width=250),
        FieldSpec("area", "Area", width=130),
        FieldSpec("preservation_type", "Type", width=160),
        FieldSpec("frequency_days", "Freq (d)", "int", width=80),
        FieldSpec("last_date", "Last", "date", width=105),
        FieldSpec("next_due", "Next Due", "date", width=105),
        FieldSpec("status", "Status", "choice", Status.PRESERVATION, 100),
        FieldSpec("remarks", "Remarks", "longtext", width=180),
    ],
    "manpower": [
        FieldSpec("log_date", "Date", "date", width=105),
        FieldSpec("agency", "Agency", "choice", MANPOWER_AGENCIES, 130),
        FieldSpec("department", "Department", width=130),
        FieldSpec("discipline", "Discipline", "choice", DISCIPLINES, 130),
        FieldSpec("area", "Area", width=130),
        FieldSpec("count", "Count", "int", width=80),
        FieldSpec("remarks", "Remarks", "longtext", width=180),
    ],
    "consumable": [
        FieldSpec("name", "Consumable", width=200),
        FieldSpec("unit", "Unit", width=70),
        FieldSpec("required", "Required", "float", width=90),
        FieldSpec("available", "Available", "float", width=90),
        FieldSpec("consumed", "Consumed", "float", width=90),
        FieldSpec("balance", "Balance", "float", width=90, read_only=True),
        FieldSpec("remarks", "Remarks", "longtext", width=200),
    ],
    "special_activity": [
        FieldSpec("activity", "Activity", width=240),
        FieldSpec("area", "Area", width=130),
        FieldSpec("subsystem", "Subsystem", width=110),
        FieldSpec("priority", "Priority", "choice", PRIORITIES, 90),
        FieldSpec("responsible", "Responsible", width=130),
        FieldSpec("status", "Status", "choice", Status.SPECIAL, 120),
        FieldSpec("dependencies", "Dependencies", width=180),
        FieldSpec("completion", "% Complete", "percent", width=95),
        FieldSpec("remarks", "Remarks", "longtext", width=180),
    ],
    "punch": [
        FieldSpec("number", "Punch No.", width=100),
        FieldSpec("description", "Description", width=280),
        FieldSpec("category", "Cat", "choice", ["A", "B", "C"], 60),
        FieldSpec("area", "Area", width=130),
        FieldSpec("system", "System", width=120),
        FieldSpec("discipline", "Discipline", "choice", DISCIPLINES, 130),
        FieldSpec("priority", "Priority", "choice", PRIORITIES, 90),
        FieldSpec("status", "Status", "choice", Status.PUNCH, 90),
        FieldSpec("raised_date", "Raised", "date", width=105),
        FieldSpec("closed_date", "Closed", "date", width=105),
        FieldSpec("remarks", "Remarks", "longtext", width=180),
    ],
    "task": [
        FieldSpec("title", "Task", width=280),
        FieldSpec("status", "Status", "choice", Status.KANBAN, 120),
        FieldSpec("priority", "Priority", "choice", PRIORITIES, 90),
        FieldSpec("owner", "Owner", width=130),
        FieldSpec("area", "Area", width=130),
        FieldSpec("subsystem", "Subsystem", width=110),
        FieldSpec("system", "System", width=120),
        FieldSpec("start_date", "Start", "date", width=105),
        FieldSpec("finish_date", "Finish", "date", width=105),
        FieldSpec("progress", "% Progress", "percent", width=95),
        FieldSpec("remarks", "Remarks", "longtext", width=180),
    ],
    "proposal_item": [
        FieldSpec("item", "Item", width=220),
        FieldSpec("category", "Category", width=140),
        FieldSpec("proposed", "Proposed", "float", width=90),
        FieldSpec("current", "Current", "float", width=90),
        FieldSpec("completed", "Completed", "float", width=90),
        FieldSpec("pending", "Pending", "float", width=90, read_only=True),
        FieldSpec("difference", "Variance", "float", width=90, read_only=True),
        FieldSpec("cost", "Cost", "float", width=100),
        FieldSpec("resources", "Resources", "float", width=90),
        FieldSpec("duration", "Duration", "float", width=90),
    ],
    "client_remark": [
        FieldSpec("log_date", "Date", "date", width=105),
        FieldSpec("remark", "Remark", "longtext", width=360),
        FieldSpec("raised_by", "Raised By", width=140),
        FieldSpec("status", "Status", "choice", Status.GENERIC, 110),
    ],
    "risk": [
        FieldSpec("title", "Risk", width=300),
        FieldSpec("severity", "Severity", "choice", PRIORITIES, 100),
        FieldSpec("mitigation", "Mitigation", "longtext", width=300),
        FieldSpec("owner", "Owner", width=130),
        FieldSpec("status", "Status", "choice", Status.GENERIC, 110),
    ],
}


def spec_for(entity_key: str) -> list[FieldSpec]:
    return COLUMNS.get(entity_key, [])
