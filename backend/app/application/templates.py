"""Built-in commissioning activity template library.

These mirror the standard pre-commissioning / commissioning activity set used on
Oil & Gas / LNG / Refinery projects. They are seeded into the database as
read-only "builtin" templates that users can copy and customise.
"""

from __future__ import annotations

# (name, category, default_duration_days, discipline, resources, utilities)
BUILTIN_TEMPLATES: list[tuple[str, str, int, str, str, str]] = [
    ("Hydrotest", "Piping", 7, "Piping", "Test Pump x2, Crew x3", "Water"),
    ("Dewatering", "Piping", 2, "Piping", "Crew x2", "Air"),
    ("Drying", "Piping", 5, "Piping", "Dryer x1", "Air, Nitrogen"),
    ("Air Blowing", "Piping", 2, "Piping", "Compressor x1", "Air"),
    ("Water Flushing", "Piping", 3, "Piping", "Flushing Crew x3", "Water"),
    ("Oil Flushing", "Mechanical", 4, "Mechanical", "Flushing Skid x1", "Power"),
    ("Chemical Cleaning", "Piping", 4, "Piping", "Chem Crew x2", "Chemical Supply, Water"),
    ("Nitrogen Purging", "Process", 2, "Process", "N2 Compressor x1", "Nitrogen"),
    ("Reinstatement", "Piping", 3, "Piping", "Crew x2", ""),
    ("Leak Test", "Process", 2, "Process", "Crew x2", "Nitrogen"),
    ("Loop Check", "Instrumentation", 3, "Instrumentation", "Instrument Team x5", "Power"),
    ("Motor Solo Run", "Electrical", 1, "Electrical", "Elec Crew x2", "Power"),
    ("Functional Test", "Instrumentation", 3, "Instrumentation", "Instrument Team x3", "Power"),
    ("Dynamic Commissioning", "Process", 5, "Process", "Commissioning Team x4", "Power, Utilities"),
    ("Preservation", "Mechanical", 1, "Mechanical", "Crew x1", ""),
    ("Energization", "Electrical", 2, "Electrical", "Elec Crew x3", "Power"),
    ("Startup", "Process", 3, "Process", "Startup Team x5", "All Utilities"),
]
