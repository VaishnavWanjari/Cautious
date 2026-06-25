"""PDF schedule report via ReportLab."""

from __future__ import annotations

import io

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.platypus import (
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

_HEADERS = ["ID", "Activity", "Dur", "Start", "Finish", "Float", "Critical"]


def export_schedule_pdf(project_name: str, schedule: dict) -> bytes:
    buf = io.BytesIO()
    doc = SimpleDocTemplate(buf, pagesize=landscape(A4), title="Commissioning Schedule")
    styles = getSampleStyleSheet()
    flow = [
        Paragraph(f"Commissioning Schedule — {project_name}", styles["Title"]),
        Spacer(1, 12),
    ]

    rows = [_HEADERS]
    crit_rows: list[int] = []
    for i, a in enumerate(schedule.get("activities", []), start=1):
        rows.append(
            [
                a.get("activity_id", ""),
                a.get("name", ""),
                str(a.get("duration", "")),
                str(a.get("start_date") or ""),
                str(a.get("finish_date") or ""),
                str(a.get("total_float") if a.get("total_float") is not None else ""),
                "Yes" if a.get("is_critical") else "No",
            ]
        )
        if a.get("is_critical"):
            crit_rows.append(i)

    table = Table(rows, repeatRows=1)
    style = TableStyle(
        [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1F4E78")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 8),
            ("GRID", (0, 0), (-1, -1), 0.4, colors.grey),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F2F2F2")]),
        ]
    )
    for r in crit_rows:
        style.add("BACKGROUND", (0, r), (-1, r), colors.HexColor("#F8CBAD"))
    table.setStyle(style)

    flow.append(table)
    doc.build(flow)
    return buf.getvalue()
