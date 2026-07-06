"""Automatic report generation: PDF, Excel, Word and PowerPoint.

Every report opens with an executive summary (today's date auto-inserted),
KPI tables, per-module tables, open risks and upcoming activities — drawn live
from the database so a report is always current.
"""

from __future__ import annotations

from datetime import date
from pathlib import Path
from typing import Any

from .. import config
from ..database.db import db
from . import exporter, metrics
from .columns import spec_for

# Which modules appear (as tables) in a full report.
REPORT_MODULES = [
    ("PMCC Status", "pmcc"),
    ("Equipment", "equipment"),
    ("Punch List", "punch"),
    ("Special Recommissioning Activities", "special_activity"),
    ("Procedures", "procedure"),
    ("Preservation", "preservation"),
    ("Consumables", "consumable"),
]


def _project_name() -> str:
    proj = db.project()
    return proj.name if proj else config.DEFAULT_PROJECT_NAME


def _summary_rows(m: metrics.DashboardMetrics) -> list[tuple[str, str]]:
    trend = "AHEAD" if m.schedule_variance >= 0 else "BEHIND"
    return [
        ("Overall Progress", f"{m.overall_progress:.1f}%"),
        ("Target Progress", f"{m.target_progress:.1f}%"),
        ("Schedule Variance", f"{m.schedule_variance:+.1f}%  ({trend})"),
        ("PMCCs (Total / Completed / Pending)", f"{m.pmcc_total} / {m.pmcc_completed} / {m.pmcc_pending}"),
        ("PMCCs Critical / Blocked", f"{m.pmcc_critical} / {m.pmcc_blocked}"),
        ("Punch (Open / Closed / Critical)", f"{m.punch_open} / {m.punch_closed} / {m.punch_critical}"),
        ("Equipment Commissioned", f"{m.equipment_commissioned} / {m.equipment_total}"),
        ("Procedures Closed", f"{m.procedures_closed} / {m.procedures_total}"),
        ("Special Activities Completed", f"{m.special_completed} / {m.special_total}"),
        ("Manpower Today / Total logged", f"{m.manpower_today} / {m.manpower_total}"),
        ("Consumables Low-Stock", f"{m.consumables_low}"),
    ]


def _out_path(kind: str, ext: str) -> Path:
    config.ensure_dirs()
    stamp = date.today().isoformat()
    safe = "".join(c for c in _project_name() if c.isalnum() or c in " -_").strip() or "Project"
    return config.REPORT_DIR / f"{safe}_{kind}_{stamp}.{ext}"


# --- PDF (ReportLab) --------------------------------------------------------
def generate_pdf_report(kind: str = "Management") -> Path:
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import A4, landscape
    from reportlab.lib.styles import getSampleStyleSheet
    from reportlab.lib.units import mm
    from reportlab.platypus import (
        Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle,
    )

    m = metrics.compute_dashboard()
    styles = getSampleStyleSheet()
    path = _out_path(kind.replace(" ", "_"), "pdf")
    doc = SimpleDocTemplate(str(path), pagesize=landscape(A4),
                            leftMargin=14 * mm, rightMargin=14 * mm,
                            topMargin=14 * mm, bottomMargin=14 * mm)
    elems: list[Any] = []
    elems.append(Paragraph(f"<b>{_project_name()}</b>", styles["Title"]))
    elems.append(Paragraph(f"{kind} Report &nbsp;·&nbsp; {date.today():%d %b %Y}", styles["Heading2"]))
    elems.append(Spacer(1, 6 * mm))

    elems.append(Paragraph("Executive Summary", styles["Heading2"]))
    summ = Table([["Metric", "Value"]] + [list(r) for r in _summary_rows(m)], colWidths=[110 * mm, 60 * mm])
    summ.setStyle(_table_style())
    elems.append(summ)
    elems.append(Spacer(1, 6 * mm))

    if m.risks:
        elems.append(Paragraph("Major Risks", styles["Heading2"]))
        rt = Table([["Risk", "Severity"]] + [[t, sev] for t, sev in m.risks], colWidths=[140 * mm, 30 * mm])
        rt.setStyle(_table_style())
        elems.append(rt)
        elems.append(Spacer(1, 5 * mm))

    if m.upcoming:
        elems.append(Paragraph("Upcoming Activities", styles["Heading2"]))
        ut = Table([["PMCC", "Target Date"]] + [[a, b] for a, b in m.upcoming], colWidths=[100 * mm, 40 * mm])
        ut.setStyle(_table_style())
        elems.append(ut)

    doc.build(elems)
    return path


def _table_style():
    from reportlab.lib import colors
    from reportlab.platypus import TableStyle

    return TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1F4E78")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 8),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#eef2f7")]),
        ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#cbd5e1")),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
    ])


# --- Excel workbook report (multi-sheet) ------------------------------------
def generate_excel_report(kind: str = "Management") -> Path:
    from openpyxl import Workbook
    from openpyxl.styles import Font, PatternFill

    m = metrics.compute_dashboard()
    path = _out_path(kind.replace(" ", "_"), "xlsx")
    wb = Workbook()
    ws = wb.active
    ws.title = "Summary"
    ws.append([f"{_project_name()} — {kind} Report"])
    ws.append([f"Generated: {date.today():%d %b %Y}"])
    ws.append([])
    ws.append(["Metric", "Value"])
    for r in _summary_rows(m):
        ws.append(list(r))
    for cell in ws[4]:
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = PatternFill("solid", fgColor="1F4E78")
    ws.column_dimensions["A"].width = 42
    ws.column_dimensions["B"].width = 30

    for title, key in REPORT_MODULES:
        sheet = wb.create_sheet(title[:31])
        specs = spec_for(key)
        sheet.append([s.label for s in specs])
        for cell in sheet[1]:
            cell.font = Font(bold=True, color="FFFFFF")
            cell.fill = PatternFill("solid", fgColor="1F4E78")
        from . import repository
        for obj in repository.list_all(key):
            sheet.append([exporter._cell(getattr(obj, s.name, "")) for s in specs])
    wb.save(path)
    return path


# --- Word (python-docx) -----------------------------------------------------
def generate_word_report(kind: str = "Management") -> Path:
    from docx import Document
    from docx.shared import Pt, RGBColor

    m = metrics.compute_dashboard()
    path = _out_path(kind.replace(" ", "_"), "docx")
    doc = Document()
    doc.add_heading(_project_name(), 0)
    doc.add_heading(f"{kind} Report — {date.today():%d %b %Y}", level=1)

    doc.add_heading("Executive Summary", level=2)
    t = doc.add_table(rows=1, cols=2)
    t.style = "Light Grid Accent 1"
    t.rows[0].cells[0].text, t.rows[0].cells[1].text = "Metric", "Value"
    for name, val in _summary_rows(m):
        row = t.add_row().cells
        row[0].text, row[1].text = name, str(val)

    if m.risks:
        doc.add_heading("Major Risks", level=2)
        for title, sev in m.risks:
            doc.add_paragraph(f"[{sev}] {title}", style="List Bullet")
    if m.upcoming:
        doc.add_heading("Upcoming Activities", level=2)
        for a, b in m.upcoming:
            doc.add_paragraph(f"{a} — target {b}", style="List Bullet")
    doc.save(path)
    return path


# --- PowerPoint (python-pptx) -----------------------------------------------
def generate_pptx_report(kind: str = "Management") -> Path:
    from pptx import Presentation
    from pptx.util import Inches, Pt

    m = metrics.compute_dashboard()
    path = _out_path(kind.replace(" ", "_"), "pptx")
    prs = Presentation()
    title_slide = prs.slides.add_slide(prs.slide_layouts[0])
    title_slide.shapes.title.text = _project_name()
    title_slide.placeholders[1].text = f"{kind} Report — {date.today():%d %b %Y}"

    body = prs.slides.add_slide(prs.slide_layouts[1])
    body.shapes.title.text = "Executive Summary"
    tf = body.placeholders[1].text_frame
    tf.clear()
    for name, val in _summary_rows(m):
        p = tf.add_paragraph()
        p.text = f"{name}: {val}"
        p.font.size = Pt(14)
    prs.save(path)
    return path


GENERATORS = {
    "PDF": generate_pdf_report,
    "Excel": generate_excel_report,
    "Word": generate_word_report,
    "PowerPoint": generate_pptx_report,
}
