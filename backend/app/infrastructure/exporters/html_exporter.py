"""Self-contained HTML dashboard/report export."""

from __future__ import annotations

import html


def export_dashboard_html(summary: dict, schedule: dict) -> str:
    p = summary.get("project", {})
    name = html.escape(str(p.get("name", "Project")))
    client = html.escape(str(p.get("client", "")))
    mc = html.escape(str(p.get("mechanical_completion_date") or ""))

    cards = [
        ("Total Activities", summary.get("total_activities", 0)),
        ("Completed", summary.get("completed", 0)),
        ("In Progress", summary.get("in_progress", 0)),
        ("Pending", summary.get("pending", 0)),
        ("Critical", summary.get("critical", 0)),
    ]
    card_html = "".join(
        f'<div class="card"><div class="num">{v}</div><div class="lbl">{html.escape(k)}</div></div>'
        for k, v in cards
    )

    rows = []
    for a in schedule.get("activities", []):
        cls = "crit" if a.get("is_critical") else ""
        rows.append(
            f'<tr class="{cls}">'
            f"<td>{html.escape(str(a.get('activity_id','')))}</td>"
            f"<td>{html.escape(str(a.get('name','')))}</td>"
            f"<td>{a.get('duration','')}</td>"
            f"<td>{html.escape(str(a.get('start_date') or ''))}</td>"
            f"<td>{html.escape(str(a.get('finish_date') or ''))}</td>"
            f"<td>{a.get('total_float') if a.get('total_float') is not None else ''}</td>"
            f"<td>{'Yes' if a.get('is_critical') else 'No'}</td>"
            "</tr>"
        )
    table_rows = "".join(rows)

    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<title>Commissioning Readiness — {name}</title>
<style>
  body {{ font-family: 'Segoe UI', Arial, sans-serif; margin: 0; background:#f5f7fa; color:#1f2933; }}
  header {{ background:#1F4E78; color:#fff; padding:20px 28px; }}
  header h1 {{ margin:0; font-size:20px; }}
  header p {{ margin:4px 0 0; opacity:.85; font-size:13px; }}
  .cards {{ display:flex; gap:14px; flex-wrap:wrap; padding:24px 28px; }}
  .card {{ background:#fff; border-radius:10px; padding:18px 22px; box-shadow:0 1px 4px rgba(0,0,0,.08); min-width:130px; }}
  .card .num {{ font-size:30px; font-weight:700; color:#1F4E78; }}
  .card .lbl {{ font-size:12px; text-transform:uppercase; letter-spacing:.5px; color:#6b7280; }}
  table {{ width: calc(100% - 56px); margin:0 28px 28px; border-collapse:collapse; background:#fff; border-radius:10px; overflow:hidden; box-shadow:0 1px 4px rgba(0,0,0,.08); }}
  th {{ background:#1F4E78; color:#fff; text-align:left; padding:10px; font-size:12px; }}
  td {{ padding:9px 10px; border-top:1px solid #eef0f3; font-size:13px; }}
  tr.crit td {{ background:#FDEBE0; font-weight:600; }}
</style></head>
<body>
  <header><h1>Commissioning Readiness — {name}</h1>
  <p>Client: {client} &nbsp;·&nbsp; Mechanical Completion: {mc}</p></header>
  <div class="cards">{card_html}</div>
  <table>
    <thead><tr><th>ID</th><th>Activity</th><th>Duration</th><th>Start</th><th>Finish</th><th>Float</th><th>Critical</th></tr></thead>
    <tbody>{table_rows}</tbody>
  </table>
</body></html>"""
