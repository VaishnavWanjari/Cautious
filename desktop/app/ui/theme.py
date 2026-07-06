"""Premium Oil & Gas visual theme — dark & light QSS with a shared palette.

The look targets a Power-BI-grade dashboard: deep navy/teal base, amber accent,
rounded cards, soft borders and subtle hover states. Colours live in one place
so widgets (KPI cards, charts) can pick brand colours programmatically too.
"""

from __future__ import annotations


class Palette:
    # brand
    PRIMARY = "#1F6FEB"
    PRIMARY_DEEP = "#0E4FB0"
    ACCENT = "#F2A93B"
    TEAL = "#17A2A2"
    # semantic
    OK = "#2FB380"
    WARN = "#E0A422"
    DANGER = "#E4572E"
    CRITICAL = "#D22B2B"
    INFO = "#3B82F6"
    # categorical series (charts)
    SERIES = ["#1F6FEB", "#17A2A2", "#F2A93B", "#8B5CF6", "#2FB380",
              "#E4572E", "#0EA5E9", "#EC4899", "#84CC16", "#F59E0B"]

    @staticmethod
    def status_color(status: str) -> str:
        s = (status or "").lower()
        if s in ("completed", "closed", "commissioned", "implemented", "ok", "approved"):
            return Palette.OK
        if s in ("critical",):
            return Palette.CRITICAL
        if s in ("blocked", "overdue", "hold", "on hold", "waiting"):
            return Palette.DANGER
        if s in ("in progress", "ready", "issued", "review", "due"):
            return Palette.INFO
        return "#7C8798"


DARK = {
    "bg": "#0E1420", "surface": "#161E2E", "surface2": "#1E2940",
    "text": "#E6EDF6", "muted": "#8A97AB", "border": "#26324A",
    "sidebar": "#0B111C", "sidebar_active": "#1F6FEB", "hover": "#22304C",
}
LIGHT = {
    "bg": "#F3F5F9", "surface": "#FFFFFF", "surface2": "#F7F9FC",
    "text": "#1F2A3A", "muted": "#64748B", "border": "#E2E8F0",
    "sidebar": "#0F2A43", "sidebar_active": "#1F6FEB", "hover": "#EAF1FB",
}


def build_qss(dark: bool) -> str:
    c = DARK if dark else LIGHT
    return f"""
    QWidget {{ color: {c['text']}; font-family: 'Segoe UI','Inter',sans-serif; font-size: 13px; }}
    QMainWindow, #RootBg {{ background: {c['bg']}; }}

    /* Sidebar */
    #Sidebar {{ background: {c['sidebar']}; border: none; }}
    #Sidebar QPushButton {{
        text-align: left; padding: 11px 16px; border: none; border-radius: 9px;
        color: rgba(255,255,255,0.75); font-size: 13px; margin: 2px 10px;
    }}
    #Sidebar QPushButton:hover {{ background: rgba(255,255,255,0.08); color: #fff; }}
    #Sidebar QPushButton:checked {{ background: {c['sidebar_active']}; color: #fff; font-weight: 600; }}
    #BrandTitle {{ color: #fff; font-size: 14px; font-weight: 700; }}
    #BrandSub {{ color: rgba(255,255,255,0.5); font-size: 10px; letter-spacing: 1px; }}
    #Credit {{ color: rgba(255,255,255,0.4); font-size: 10px; }}

    /* Header */
    #Header {{ background: {c['surface']}; border-bottom: 1px solid {c['border']}; }}
    #PageTitle {{ font-size: 18px; font-weight: 700; }}
    #Chip {{ background: {c['surface2']}; border: 1px solid {c['border']}; border-radius: 12px; padding: 3px 10px; color: {c['muted']}; }}

    /* Cards / panels */
    #Card, #Panel {{ background: {c['surface']}; border: 1px solid {c['border']}; border-radius: 14px; }}
    #CardValue {{ font-size: 26px; font-weight: 800; }}
    #CardLabel {{ color: {c['muted']}; font-size: 11px; text-transform: uppercase; letter-spacing: .6px; }}
    #CardSub {{ color: {c['muted']}; font-size: 11px; }}

    /* Inputs & buttons */
    QLineEdit, QComboBox, QDateEdit, QSpinBox, QDoubleSpinBox, QPlainTextEdit, QTextEdit {{
        background: {c['surface2']}; border: 1px solid {c['border']}; border-radius: 8px;
        padding: 6px 9px; selection-background-color: {Palette.PRIMARY};
    }}
    QComboBox::drop-down {{ border: none; width: 20px; }}
    QComboBox QAbstractItemView {{ background: {c['surface']}; border: 1px solid {c['border']}; selection-background-color: {Palette.PRIMARY}; }}
    QPushButton {{ background: {Palette.PRIMARY}; color: #fff; border: none; border-radius: 8px; padding: 8px 14px; font-weight: 600; }}
    QPushButton:hover {{ background: {Palette.PRIMARY_DEEP}; }}
    QPushButton:disabled {{ background: {c['border']}; color: {c['muted']}; }}
    QPushButton#Ghost {{ background: transparent; color: {c['text']}; border: 1px solid {c['border']}; }}
    QPushButton#Ghost:hover {{ background: {c['hover']}; }}
    QPushButton#Danger {{ background: {Palette.DANGER}; }}

    /* Tables */
    QTableView {{ background: {c['surface']}; alternate-background-color: {c['surface2']};
        gridline-color: {c['border']}; border: 1px solid {c['border']}; border-radius: 12px;
        selection-background-color: {Palette.PRIMARY}; selection-color: #fff; }}
    QHeaderView::section {{ background: {c['surface2']}; color: {c['muted']}; padding: 7px 8px;
        border: none; border-bottom: 1px solid {c['border']}; font-weight: 600; }}
    QTableView::item {{ padding: 4px 6px; }}

    /* Kanban */
    #KanbanColumn {{ background: {c['surface']}; border: 1px solid {c['border']}; border-radius: 14px; }}
    #KanbanColHeader {{ font-weight: 700; font-size: 13px; }}
    QListWidget {{ background: transparent; border: none; }}
    QListWidget::item {{ margin: 0; padding: 0; }}

    /* Scrollbars */
    QScrollBar:vertical {{ background: transparent; width: 10px; margin: 2px; }}
    QScrollBar::handle:vertical {{ background: {c['border']}; border-radius: 5px; min-height: 30px; }}
    QScrollBar::handle:vertical:hover {{ background: {Palette.PRIMARY}; }}
    QScrollBar:horizontal {{ background: transparent; height: 10px; margin: 2px; }}
    QScrollBar::handle:horizontal {{ background: {c['border']}; border-radius: 5px; min-width: 30px; }}
    QScrollBar::add-line, QScrollBar::sub-line {{ height: 0; width: 0; }}

    QTabBar::tab {{ background: transparent; padding: 8px 14px; color: {c['muted']}; border-bottom: 2px solid transparent; }}
    QTabBar::tab:selected {{ color: {Palette.PRIMARY}; border-bottom: 2px solid {Palette.PRIMARY}; font-weight: 600; }}
    """


THEME_COLORS = {"dark": DARK, "light": LIGHT}
