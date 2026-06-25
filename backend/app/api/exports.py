"""Export endpoints: Excel, PDF, HTML dashboard."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import HTMLResponse, Response
from sqlalchemy.orm import Session

from .. import services
from ..db import get_db
from ..infrastructure import models
from ..infrastructure.exporters.html_exporter import export_dashboard_html
from ..infrastructure.exporters.pdf_exporter import export_schedule_pdf
from ..infrastructure.exporters.xlsx_exporter import export_schedule_xlsx

router = APIRouter(prefix="/api", tags=["exports"])

_XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"


def _name(db: Session, project_id: int) -> str:
    p = db.get(models.Project, project_id)
    if not p:
        raise HTTPException(404, "Project not found")
    return p.name


@router.get("/projects/{project_id}/export/xlsx")
def export_xlsx(project_id: int, db: Session = Depends(get_db)):
    name = _name(db, project_id)
    schedule = services.run_schedule(db, project_id)
    data = export_schedule_xlsx(name, schedule)
    return Response(
        content=data,
        media_type=_XLSX,
        headers={"Content-Disposition": f'attachment; filename="schedule-{project_id}.xlsx"'},
    )


@router.get("/projects/{project_id}/export/pdf")
def export_pdf(project_id: int, db: Session = Depends(get_db)):
    name = _name(db, project_id)
    schedule = services.run_schedule(db, project_id)
    data = export_schedule_pdf(name, schedule)
    return Response(
        content=data,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="schedule-{project_id}.pdf"'},
    )


@router.get("/projects/{project_id}/export/html")
def export_html(project_id: int, db: Session = Depends(get_db)):
    _name(db, project_id)
    summary = services.project_summary(db, project_id)
    schedule = services.run_schedule(db, project_id)
    return HTMLResponse(content=export_dashboard_html(summary, schedule))
