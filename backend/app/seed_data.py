"""Real project dataset: GPT-3/4 Gas Processing Train.

Defines the PMCC handover sequence (21 PMCCs) and the commissioning circuits
(test packages) with their priority and *special* pre-commissioning activity.
Every circuit additionally gets the standard activity set that applies to all
systems, with vessel/motor-conditional activities included by keyword heuristics.

This module is pure data + helpers (no I/O) so both the standalone server and
the FastAPI seed can build the hierarchy from a single source of truth.
"""

from __future__ import annotations

import re

# --- PMCC handover sequence --------------------------------------------------
# (sequence, category, no, description, systems, subsystems)
PMCCS: list[tuple[int, str, str, str, int, int]] = [
    (1, "Non Process", "PMCC-01", "Substation (SS-03) & EDG building (EDG-03)", 2, 38),
    (2, "Non Process", "PMCC-02", "Process Interface Building (PIB-14) & PCS", 1, 18),
    (3, "Non Process", "PMCC-03", "Operator Maintenance OME Building (OME-06)", 1, 7),
    (4, "Non Process", "PMCC-04", "Operator Shelter (OS) Building (OS-03)", 1, 7),
    (5, "Non Process", "PMCC-05", "Shelters & Sunshades", 1, 7),
    (6, "P&ID-Utility", "PMCC-06", "Sanitary Water Waste (SWS)", 1, 4),
    (7, "P&ID-Utility", "PMCC-07", "Inst Air, Plant Air & Nitrogen", 3, 5),
    (8, "P&ID-Utility", "PMCC-08", "Potable Water & Utility Water", 2, 13),
    (9, "P&ID-Utility", "PMCC-09", "Oily Water Sewer (OWS) & Firewater", 2, 5),
    (10, "P&ID-Utility", "PMCC-10", "Steam, Condensate, BFW and DM Water", 6, 11),
    (11, "P&ID-Utility", "PMCC-11", "Fuel Gas, Flare Header and Closed Drain", 5, 11),
    (12, "P&ID-Utility", "PMCC-12", "Chilled Water, Chemical Injection & Makeup Oil Unit", 2, 4),
    (13, "P&ID-Process", "PMCC-13", "Condensate Separator, WOSEP & Condensate Stabilizer Unit", 8, 17),
    (14, "P&ID-Process", "PMCC-14", "Inlet Slug Catcher & Condensate Stabilizer OH Compressor K-3104 A/B", 3, 9),
    (15, "P&ID-Process", "PMCC-15", "Booster Compressor K-3001 A/B/C/D/E & Air fin Coolers E-3001", 9, 24),
    (16, "P&ID-Process", "PMCC-16", "Vessel Loadings — Gas/Liquid Dehydrators, Mercury & Activated Carbon beds", 1, 4),
    (17, "P&ID-Process", "PMCC-17", "Gas & Liquid Dehydration, Mercury Removal & Regen Gas Compressor", 14, 22),
    (18, "P&ID-Process", "PMCC-18", "Sales Gas Compressor & Export", 8, 18),
    (19, "P&ID-Process", "PMCC-19", "NGLRU", 12, 22),
    (20, "P&ID-Process", "PMCC-20", "Propane Refrigeration Unit", 7, 20),
    (21, "P&ID-Process", "PMCC-21", "Acid Gas Removal Unit (AGRU)", 16, 31),
]

# --- Commissioning circuits --------------------------------------------------
# (code, description, priority, special_precom_activity, pmcc_no)
_CC = "Chemical Cleaning"
_SG = "Seal Gas Piping Chemical Cleaning"
_SU = "Suction Piping Chemical Cleaning"
_LO = "Lube Oil Chemical Cleaning and Flushing"
_ADL = "Adsorbent Loading"
_AML = "Amine Degreasing Loop"
_AMLI = "Amine Degreasing Loop & Internal Installation"
_INT = "Internals Installation and Box-up"
_STB = "Steam Blowing"
_PROP = "Hydromilling / Chemical Cleaning of Propane loop"

CIRCUITS: list[tuple[str, str, str, str, str]] = [
    # --- 300: Slug catcher (PMCC-14) + Booster Compressor K-3001 (PMCC-15) ---
    ("866-300-101-P-P-01", "Inlet Gas Manifold to D-3001 Slug Gas Catcher Outlet", "B", "", "PMCC-14"),
    ("866-300-102-P-P-01", "Suction KOD D-3003A to Discharge Cooler E-3001A", "A", _SU, "PMCC-15"),
    ("866-300-102-P-P-02", "Booster Compressor K-3001 A & Seal Gas Skid Package", "A", _SG, "PMCC-15"),
    ("866-300-102-P-P-03", "Lube Oil Skid A Package (K-3001A)", "A", _LO, "PMCC-15"),
    ("866-300-103-P-P-01", "Suction KOD D-3003B to Discharge Cooler E-3001B", "A", _SU, "PMCC-15"),
    ("866-300-103-P-P-02", "Booster Compressor K-3001 B & Seal Gas Skid Package", "A", _SG, "PMCC-15"),
    ("866-300-103-P-P-03", "Lube Oil Skid B Package (K-3001B)", "A", _LO, "PMCC-15"),
    ("866-300-104-P-P-01", "Suction KOD D-3003C to Discharge Cooler E-3001C", "A", _SU, "PMCC-15"),
    ("866-300-104-P-P-02", "Booster Compressor K-3001 C & Seal Gas Skid Package", "A", _SG, "PMCC-15"),
    ("866-300-104-P-P-03", "Lube Oil Skid C Package (K-3001C)", "A", _LO, "PMCC-15"),
    ("866-300-105-P-P-01", "Suction KOD D-3003D to Discharge Cooler E-3001D", "A", _SU, "PMCC-15"),
    ("866-300-105-P-P-02", "Booster Compressor K-3001 D & Seal Gas Skid Package", "A", _SG, "PMCC-15"),
    ("866-300-105-P-P-03", "Lube Oil Skid D Package (K-3001D)", "A", _LO, "PMCC-15"),
    ("866-300-106-P-P-01", "Suction KOD D-3003E to Discharge Cooler E-3001E", "A", _SU, "PMCC-15"),
    ("866-300-106-P-P-02", "Booster Compressor K-3001 E & Seal Gas Skid Package", "A", _SG, "PMCC-15"),
    ("866-300-106-P-P-03", "Lube Oil Skid E Package (K-3001E)", "A", _LO, "PMCC-15"),
    # --- 310: Condensate Separator/WOSEP/Stabilizer (PMCC-13) + OH comp (PMCC-14) ---
    ("866-310-107-P-P-01", "Condensate Inlet Manifold & Inlet Condensate Separator Outlet", "B", "", "PMCC-13"),
    ("866-310-108-P-P-01", "Inlet Condensate Separator D-3002 to Stabilizer Coalescer U-3101 A/B Outlet", "B", "", "PMCC-13"),
    ("866-310-109-P-P-01", "Condensate Stabilizer Column C-3101 & Overhead Vapor to KOD Inlet", "A", _INT, "PMCC-13"),
    ("866-310-109-P-P-02", "Condensate Stabilizer Side Reboilers (Shell Side) E-3101A/B/C/D", "B", "", "PMCC-13"),
    ("866-310-109-P-P-03", "Condensate Stabilizer Side Reboilers (Tube Side) E-3101A/B/C/D", "B", "", "PMCC-13"),
    ("866-310-109-P-P-04", "Condensate Stabilizer Reboiler E-3102 A/B", "B", "", "PMCC-13"),
    ("866-310-109-P-P-05", "Condensate to Export line", "C", "", "PMCC-13"),
    ("866-310-110-P-P-01", "Stabilizer OH Compressor Suction KOD-3104A to D-3105A Discharge KOD outlet", "A", _SU, "PMCC-14"),
    ("866-310-110-P-P-02", "Condensate Stabilizer OH Compressor K-3104A Skid package", "A", _SG, "PMCC-14"),
    ("866-310-110-P-P-03", "Stabilizer OH Compressor Lube oil skid A Package (K-3104A)", "A", _LO, "PMCC-14"),
    ("866-310-110-P-P-04", "Stabilizer OH Compressor Vorecon System A (K-3104A)", "A", _LO, "PMCC-14"),
    ("866-310-111-P-P-01", "Stabilizer OH Compressor Suction KOD-3104B to D-3105B Discharge KOD outlet", "A", _SU, "PMCC-14"),
    ("866-310-111-P-P-02", "Condensate Stabilizer OH Compressor K-3104B Skid package", "A", _SG, "PMCC-14"),
    ("866-310-111-P-P-03", "Stabilizer OH Compressor Lube oil skid B Package (K-3104B)", "A", _LO, "PMCC-14"),
    ("866-310-111-P-P-04", "Stabilizer OH Compressor Vorecon System B (K-3104B)", "A", _LO, "PMCC-14"),
    ("866-310-112-P-PW-01", "Incoming Streams to WOSEP D-3006 and Produced water export", "B", "", "PMCC-13"),
    # --- 320: AGRU (PMCC-21), beds to PMCC-16 ---
    ("866-320-113-P-P-01", "Wet Sour Gas from K-3001 A/B/C/D/E to D-3201 Feed Gas KOD Inlet", "B", "", "PMCC-21"),
    ("866-320-114-P-P-01", "Feed Gas from D-3201 to Amine Absorber C-3201", "B", "", "PMCC-21"),
    ("866-320-115-P-AG-01", "Amine Absorber C-3201 & Outlet to Treated Gas KOD D-3203", "A", _AMLI, "PMCC-21"),
    ("866-320-116-P-PW-01", "Wash Water Pumps G-3205 and Water Makeup Pumps G-3206 A/B", "A", _AML, "PMCC-21"),
    ("866-320-117-P-MDEA-01", "Amine Booster Pump G-3201 A/B/C & Lean Amine Air cooler E-3205/E-3201 A-E", "A", _AML, "PMCC-21"),
    ("866-320-117-P-MDEA-02", "Lean Amine Circulation Circuit (Lean Amine Cooler to C-3201 via G-3203 A/B/C)", "A", _AML, "PMCC-21"),
    ("866-320-117-P-MDEA-03", "Lean Amine Filtration Circuit (G-3212, Activated Carbon & Polishing filters)", "A", _AML, "PMCC-21"),
    ("866-320-118-P-MDEA-01", "Amine Absorber C-3201 Bottom to Amine Flash Drum D-3202 via GT-3201 Turbine", "A", _AML, "PMCC-21"),
    ("866-320-118-P-MDEA-02", "Amine Flash Drum D-3202 and Flash Gas Absorber C-3203", "A", _AMLI, "PMCC-21"),
    ("866-320-118-P-MDEA-03", "Amine Flash Drum D-3202 Rich Amine to C-3202 via Lean/Rich Exchanger E-3201 A-E", "A", _AML, "PMCC-21"),
    ("866-320-118-P-MDEA-04", "Lube Oil Skid G-3203C and GT-3201 (Hydraulic Turbine)", "A", _LO, "PMCC-21"),
    ("866-320-118-P-MDEA-05", "Lube Oil Skid G-3203A/B (Amine Circulation Pumps)", "A", _LO, "PMCC-21"),
    ("866-320-119-P-AG-02", "Amine Regenerator Top & Amine Regenerator Reflux drum D-3204", "A", _AML, "PMCC-21"),
    ("866-320-119-P-MDEA-01", "Amine Regenerator C-3202", "A", _AMLI, "PMCC-21"),
    ("866-320-119-P-MDEA-03", "Amine Regenerator Reboilers E-3202 A/B/C/D", "A", _AML, "PMCC-21"),
    ("866-320-120-P-P-01", "Hydrocarbon Condensate Skim Drum & Transfer Pump G-3208 A/B", "C", "", "PMCC-21"),
    ("866-320-121-P-AD-01", "Amine Sump Drum D-3205 & Amine Sump Pump G-3207 A/B", "A", _AML, "PMCC-21"),
    ("866-320-121-P-AD-02", "Amine Drain System (UG- Underground Lines)", "A", _AML, "PMCC-21"),
    ("866-320-122-P-C-01", "U-3202 HEP Injection System & Piping", "C", "", "PMCC-21"),
    ("866-320-123-P-C-01", "U-3201 Antifoam Injection system & Piping", "C", "", "PMCC-21"),
    ("866-320-124-P-P-01", "Treated Gas KOD D-3203 to Condensate Heater E-3307", "B", "", "PMCC-21"),
    ("866-320-150-P-P-04", "Activated Carbon Filter Bed (D-3214)", "B", _ADL, "PMCC-16"),
    # --- 330: Dehydration / Mercury / Regen (PMCC-17), beds to PMCC-16 ---
    ("866-330-125-P-P-01", "Condensate Heater E-3307 to Dehydration Beds Inlet via Gas Dehy KOD D-3303", "B", "", "PMCC-17"),
    ("866-330-126-P-P-01", "Wet Sweet Gas from Gas Dehydration Beds D-3304 A-E to Dry Gas Filter D-3305 Inlet", "A", _ADL, "PMCC-17"),
    ("866-330-127-P-P-01", "Dry Gas Filter D-3305 A/B to Mercury Removal guard Bed D-3307 A/B/C/D Outlet", "B", "", "PMCC-17"),
    ("866-330-128-P-P-01", "Mercury Removal guard Bed D-3307 A/B/C/D Outlet to NGLRU unit", "A", _ADL, "PMCC-17"),
    ("866-330-129-P-P-01", "Condensate from D-3303 Dehy inlet KOD to Liq-Liq Coalescer D-3313 A/B outlet", "B", "", "PMCC-17"),
    ("866-330-130-P-P-01", "Hot Regen Gas from Preheater E-3305 to Dehydration Beds via E-3304 A/B/C/D", "B", "", "PMCC-17"),
    ("866-330-130-P-P-02", "Wet Regen Gas from Dehy Beds to Regen Gas Air Cooler E-3306 via E-3305 (tube)", "B", "", "PMCC-17"),
    ("866-330-131-P-P-01", "Regen Gas Cooler Outlet to Dehy Propane Cooler E-3303 via Suction KOD D-3306", "A", _SU, "PMCC-17"),
    ("866-330-131-P-P-02", "Regeneration Gas Compressor K-3306 & Seal gas Skid Package", "A", _SG, "PMCC-17"),
    ("866-330-131-P-P-03", "Regeneration Gas Compressor Lube Oil Skid Package", "A", _LO, "PMCC-17"),
    ("866-330-132-P-P-01", "Liquid Dehy feed from D-3303 to Liquid Feed Coalescer Separator U-3312 A/B outlet", "B", "", "PMCC-17"),
    ("866-330-133-P-P-01", "Liquid Feed Coalescer U-3312 A/B to D-3310 Flash drum via Liquid Dehydrators D-3314 A/B", "A", _ADL, "PMCC-17"),
    ("866-330-134-P-P-01", "D-3310 Liquid Dehydrator Flash drum & Product Pump G-3303 to Demethanizer Pump G-3501", "A", "Hydromilling / Chemical Cleaning of C2+NGL Line", "PMCC-17"),
    ("866-330-150-P-P-01", "Gas Dehydration Beds (D-3304 A/B/C/D/E)", "A", _ADL, "PMCC-16"),
    ("866-330-150-P-P-02", "Liquid Dehydration Beds (D-3314 A/B)", "A", _ADL, "PMCC-16"),
    ("866-330-150-P-P-03", "Mercury Removal Beds (D-3307 A/B/C/D)", "A", _ADL, "PMCC-16"),
    # --- 340: Propane Refrigeration (PMCC-20) ---
    ("866-340-135-P-RP-01", "Inlet to Propane Condenser E-3403 & Propane Accumulator D-3403 Outlet", "A", _PROP, "PMCC-20"),
    ("866-340-135-P-RP-02", "Propane Liquid Circuit (Accumulator to Demethanizer Reboiler & sub-cooled users)", "A", _PROP, "PMCC-20"),
    ("866-340-135-P-RP-03", "Propane Vapour Circuit (Dehy Inlet & Chilled Water Cooler to 2nd Stage KOD)", "A", _PROP, "PMCC-20"),
    ("866-340-135-P-RP-04", "Propane to Refrigerant Head Drum D-3502 & Outlet to 1st Stage Compressor KOD", "A", _PROP, "PMCC-20"),
    ("866-340-135-P-RP-05", "Propane Drain System (Drain Drum D-3404 & Drain Pump G-3404)", "A", _PROP, "PMCC-20"),
    ("866-340-136-P-RP-01", "Propane Compressor A Suction KOD D-3401A to Condenser E-3403 via D-3402A 2nd Stage KOD", "A", _SU, "PMCC-20"),
    ("866-340-136-P-RP-02", "Propane Compressor A K-3401 A & Seal Gas Skid Package", "A", _SG, "PMCC-20"),
    ("866-340-136-P-RP-03", "Propane Compressor A Lube Oil Skid A Package (K-3401A)", "A", _LO, "PMCC-20"),
    ("866-340-137-P-RP-01", "Propane Compressor B Suction KOD D-3401B to Condenser E-3403 via D-3402A 2nd Stage KOD", "A", _SU, "PMCC-20"),
    ("866-340-137-P-RP-02", "Propane Compressor B K-3401 B & Seal Gas Skid Package", "A", _SG, "PMCC-20"),
    ("866-340-137-P-RP-03", "Propane Compressor B Lube Oil Skid B Package (K-3401B)", "A", _LO, "PMCC-20"),
    # --- 350: NGLRU (PMCC-19) ---
    ("866-350-138-P-P-01", "Dry Gas from D-3308 A/B Mercury Guard bed filters to D-3501 Warm Separator Inlet", "B", "", "PMCC-19"),
    ("866-350-138-P-P-02", "Dry-out Gas Lines", "B", "", "PMCC-19"),
    ("866-350-139-P-P-01", "Warm Separator D-3501 & Outlet to Cold Separator D-3503 Inlet", "B", "", "PMCC-19"),
    ("866-350-140-P-P-01", "Cold Separator & Top to Demethanizer C-3501 (Tray 37, Tray 21)", "B", "", "PMCC-19"),
    ("866-350-141-P-P-01", "Expander Compressor K-3501A - E-3501/3504 to Sales gas Compressor suction KOD", "A", _SU, "PMCC-19"),
    ("866-350-141-P-P-02", "Expander K-3501A - Cold sep to Demethanizer (Tray 27)", "A", _SU, "PMCC-19"),
    ("866-350-142-P-P-01", "Expander Compressor K-3501B - E-3501/3504 to Sales gas Compressor suction KOD", "A", _SU, "PMCC-19"),
    ("866-350-142-P-P-02", "Expander K-3501B - Cold sep to Demethanizer (Tray 27)", "A", _SU, "PMCC-19"),
    ("866-350-143-P-P-01", "Demethanizer Column C-3501 & Bottom Product Pump G-3501 A/B/C", "A", _INT, "PMCC-19"),
    ("866-350-143-P-P-02", "Bottom Reboiler E-3508 A/B (Shell Side)", "B", "", "PMCC-19"),
    ("866-350-143-P-P-03", "Upper side Reboiler E-3506", "B", "", "PMCC-19"),
    ("866-350-143-P-P-04", "Lower side Reboiler E-3502", "B", "", "PMCC-19"),
    ("866-350-144-P-P-01", "Demethanizer top to Expander Compressor Suction K-3501 A/B (Sales Gas Reflux excl.)", "A", _SU, "PMCC-19"),
    ("866-350-145-P-C-01", "Methanol Dosing in NGLRU", "C", "", "PMCC-19"),
    # --- 360: Sales Gas Compressor & Export (PMCC-18) ---
    ("866-360-146-P-P-01", "Sales Gas Compressor Suction KOD D-3601A Inlet to Discharge Cooler E-3601A Outlet", "A", _SU, "PMCC-18"),
    ("866-360-146-P-P-02", "Sales Gas Compressor K-3601 A Skid & Seal Gas Package", "A", _SG, "PMCC-18"),
    ("866-360-146-P-P-03", "Sales Gas Compressor Lube Oil Skid A Package (K-3601A)", "A", _LO, "PMCC-18"),
    ("866-360-147-P-P-01", "Sales Gas Compressor Suction KOD D-3601B Inlet to Discharge Cooler E-3601B Outlet", "A", _SU, "PMCC-18"),
    ("866-360-147-P-P-02", "Sales Gas Compressor K-3601 B Skid & Seal Gas Package", "A", _SG, "PMCC-18"),
    ("866-360-147-P-P-03", "Sales Gas Compressor Lube Oil Skid B Package (K-3601B)", "A", _LO, "PMCC-18"),
    ("866-360-148-P-P-01", "Sales Gas Compressor Suction KOD D-3601C Inlet to Discharge Cooler E-3601C Outlet", "A", _SU, "PMCC-18"),
    ("866-360-148-P-P-02", "Sales Gas Compressor K-3601 C Skid & Seal Gas Package", "A", _SG, "PMCC-18"),
    ("866-360-148-P-P-03", "Sales Gas Compressor Lube Oil Skid C Package (K-3601C)", "A", _LO, "PMCC-18"),
    ("866-360-149-P-P-01", "Sales Gas Export to Master Gas Line (Sales gas Reflux to Demethanizer C-3501)", "A", "Hydromilling / Chemical Cleaning of Sales Gas Export Line", "PMCC-18"),
    # --- 370: Steam / Condensate / BFW / DM (PMCC-10) ---
    ("866-370-101-U-LPS-01", "LP Steam to Distribution Header", "A-1", _STB, "PMCC-10"),
    ("866-370-101-U-LPS-02", "LP Steam to AGRU Distribution Header", "A-1", _STB, "PMCC-10"),
    ("866-370-101-U-LPS-03", "LP steam to Amine Regenerator Reboiler", "A-1", _STB, "PMCC-10"),
    ("866-370-102-U-LPC-01", "Condensate Collection Header", "A-1", _CC, "PMCC-10"),
    ("866-370-102-U-LPC-02", "Atmospheric Condensate Flash Drum & Transfer pump", "A-1", _CC, "PMCC-10"),
    ("866-370-103-U-HPS-01", "HP steam to Regen Gas Heater E-3304 ABCD & Main Header", "A-1", _STB, "PMCC-10"),
    ("866-370-103-U-HPS-02", "HP/MP steam to Condensate Stabilizer Reboiler", "A-1", _STB, "PMCC-10"),
    ("866-370-104-U-MPS-01", "HP/MP condensate to HP Condensate Flash Drum", "A-1", _CC, "PMCC-10"),
    ("866-370-108-U-BFW-01", "HP BFW to Condensate Stabilizer Reboiler Desuperheater", "A-1", _CC, "PMCC-10"),
    ("866-370-108-U-BFW-02", "HP BFW to AGRU (Amine Regenerator Reboiler Desuperheater)", "A-1", _CC, "PMCC-10"),
    ("866-370-109-U-DMW-01", "DM Demin Water Distribution Header", "B-1", "", "PMCC-10"),
    # --- 380: IA/PA/N2 (PMCC-07), FG/Flare (PMCC-11), CW/Chem/MakeupOil (PMCC-12), Water (PMCC-08/09) ---
    ("866-380-110-U-IA-01", "Instrument Air to Inlet & Condensate, NGLRU & DMRU Facility", "A-1", "", "PMCC-07"),
    ("866-380-110-U-IA-02", "Instrument Air to AGRU", "A-1", "", "PMCC-07"),
    ("866-380-111-U-PA-01", "Plant Air to Utility Distribution Header", "A-1", "", "PMCC-07"),
    ("866-380-112-U-N-01", "Nitrogen N2 to Distribution", "B-1", "", "PMCC-07"),
    ("866-380-112-U-N-02", "Nitrogen N2 to AGRU Unit", "B-1", "", "PMCC-07"),
    ("866-380-113-U-FGH-01", "FGH High Pressure Fuel Gas", "C-1", "", "PMCC-11"),
    ("866-380-113-U-FGL-02", "FGL Low Pressure Fuel Gas", "C-1", "", "PMCC-11"),
    ("866-380-114-U-HPF-01", "HP Flare Collection Header", "C-1", "", "PMCC-11"),
    ("866-380-114-U-HPF-02", "HP Flare AGRU Collection Header", "C-1", "", "PMCC-11"),
    ("866-380-115-U-LPF-01", "LP Flare from Collection Header", "C-1", "", "PMCC-11"),
    ("866-380-115-U-LPF-02", "LP Flare from AGRU Collection Header", "C-1", "", "PMCC-11"),
    ("866-380-116-U-LTF-01", "LTF Flare Header", "C-1", "", "PMCC-11"),
    ("866-380-117-U-C-02", "Oxygen Scavenger / Corrosion inhibitor", "C-1", "", "PMCC-12"),
    ("866-380-117-U-CW-01", "Chilled Water", "C-1", "", "PMCC-12"),
    ("866-380-118-U-DW-01", "Potable Water Distribution Network (AG) & SSEW", "A-1", "Chlorine Disinfection", "PMCC-08"),
    ("866-380-118-U-DW-02", "Potable Water Distribution Network (UG)", "A-1", "Chlorine Disinfection", "PMCC-08"),
    ("866-380-118-U-DW-03", "Potable Water to Operator Shelter (OS)", "A-1", "Chlorine Disinfection", "PMCC-08"),
    ("866-380-118-U-DW-04", "Potable Water to Substation-03 (SS03)", "A-1", "Chlorine Disinfection", "PMCC-08"),
    ("866-380-118-U-DW-05", "Potable Water to PIB-14", "A-1", "Chlorine Disinfection", "PMCC-08"),
    ("866-380-118-U-DW-06", "Potable water to OME-06", "A-1", "Chlorine Disinfection", "PMCC-08"),
    ("866-380-119-U-UW-01", "Utility Water to Distribution (AG)", "A-1", "", "PMCC-08"),
    ("866-380-119-U-UW-02", "Utility Water to Distribution (UG)", "A-1", "", "PMCC-08"),
    ("866-380-119-U-UW-03", "Utility Water to EDG-03", "A-1", "", "PMCC-08"),
    ("866-380-119-U-UW-04", "Utility Water to Operator Shelter (OS)", "A-1", "", "PMCC-08"),
    ("866-380-119-U-UW-05", "Utility Water to Substation-03 (SS03)", "A-1", "", "PMCC-08"),
    ("866-380-119-U-UW-06", "Utility Water to PIB-14", "A-1", "", "PMCC-08"),
    ("866-380-119-U-UW-07", "Utility Water to OME-06", "A-1", "", "PMCC-08"),
    ("866-380-120-U-FW-01", "Fire Water AG", "A-1", "", "PMCC-09"),
    ("866-380-120-U-FW-02", "Fire Water UG", "A-1", "", "PMCC-09"),
    ("866-380-121-U-SO-01", "Makeup Oil Unit (MUU-1, MUU-2)", "A-1", "Chemical Cleaning & Lube Oil flushing", "PMCC-12"),
    ("866-380-121-U-SO-02", "Makeup DM water Unit (MUU-3)", "A-1", "Chemical Cleaning & Lube Oil flushing", "PMCC-12"),
    # --- 390: OWS (PMCC-09), SWS (PMCC-06), Closed Drain (PMCC-11) ---
    ("866-390-105-U-OWS-01", "OWS Oily water Sewer - AG", "A-1", "", "PMCC-09"),
    ("866-390-105-U-OWS-02", "OWS Oily water Sewer - UG", "A-1", "", "PMCC-09"),
    ("866-390-106-U-SWS-01", "SWS Sanitary Waste water - AG", "A-1", "", "PMCC-06"),
    ("866-390-106-U-SWS-02", "SWS Sanitary Waste water - UG", "A-1", "", "PMCC-06"),
    ("866-390-107-U-CD-01", "Closed Drain from Inlet & Condensate", "C-1", "", "PMCC-11"),
    ("866-390-107-U-CD-02", "Closed Drain from AGRU", "C-1", "", "PMCC-11"),
    ("866-390-107-U-CD-03", "Closed Drain from Dehydration", "C-1", "", "PMCC-11"),
    ("866-390-107-U-CD-04", "Closed Drain from Sales Gas / NGLRU", "C-1", "", "PMCC-11"),
]

# --- standard activity set (applies to every circuit) ------------------------
# Conditional ones (Vessel Inspection / No Load Test) are included by heuristic.
_VESSEL_RE = re.compile(
    r"\b[DCU]-\d|Drum|Separator|Column|Absorber|Regenerator|KOD|Catcher|"
    r"Coalescer|Accumulator|\bBed\b|Vessel|Reboiler|Condenser|Reflux",
    re.IGNORECASE,
)
_MOTOR_RE = re.compile(
    r"\b[KG]-\d|Compressor|\bPump\b|Skid|Turbine|Blower|\bFan\b|Air cooler|Air fin",
    re.IGNORECASE,
)


def _special_duration(special: str) -> int:
    s = special.lower()
    if "internals" in s:
        return 4
    if "hydromilling" in s:
        return 4
    if "degreasing" in s:
        return 3
    if "adsorbent" in s:
        return 3
    if "lube oil" in s:
        return 3
    if "chemical cleaning" in s:
        return 3
    if "steam blowing" in s:
        return 2
    if "chlorine" in s:
        return 2
    if special:
        return 3
    return 0


def has_vessel(description: str) -> bool:
    return bool(_VESSEL_RE.search(description))


def has_motor(description: str) -> bool:
    return bool(_MOTOR_RE.search(description))


def build_activities(code: str, description: str, special: str) -> list[tuple[str, int, str]]:
    """Return the ordered activity list (name, duration_days, discipline) for a circuit."""
    acts: list[tuple[str, int, str]] = []
    if special:
        acts.append((special, _special_duration(special), "Pre-Commissioning"))
    acts.append(("Reinstatement", 2, "Piping"))
    if has_vessel(description):
        acts.append(("Vessel Inspection", 1, "Mechanical"))
    acts.append(("Leak Test (Dry Air)", 1, "Process"))
    acts.append(("Inertization", 1, "Process"))
    if has_motor(description):
        acts.append(("No Load Test (Motor Solo Run)", 1, "Electrical"))
    acts.append(("Loop Check", 3, "Instrumentation"))
    acts.append(("Punch Point Liquidation", 2, "Multi-discipline"))
    acts.append(("Layup Witness", 1, "QA / Preservation"))
    return acts


# numeric rank for priority letters (A highest); used by the priority engine
def priority_rank(priority: str) -> int:
    base = {"A": 1, "B": 2, "C": 3}.get(priority[:1].upper(), 3)
    return base
