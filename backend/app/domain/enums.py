"""Domain enumerations shared across the scheduling engine and API."""

from __future__ import annotations

from enum import Enum


class RelationType(str, Enum):
    """Precedence relationship types (Primavera-compatible)."""

    FS = "FS"  # Finish-to-Start
    SS = "SS"  # Start-to-Start
    FF = "FF"  # Finish-to-Finish
    SF = "SF"  # Start-to-Finish


class Discipline(str, Enum):
    MECHANICAL = "Mechanical"
    PIPING = "Piping"
    ELECTRICAL = "Electrical"
    INSTRUMENTATION = "Instrumentation"
    PROCESS = "Process"
    TELECOM = "Telecom"
    CIVIL = "Civil"
    UTILITIES = "Utilities"
    MULTI = "Multi-discipline"


class ActivityStatus(str, Enum):
    NOT_STARTED = "Not Started"
    IN_PROGRESS = "In Progress"
    COMPLETED = "Completed"
    ON_HOLD = "On Hold"


class SnrType(str, Enum):
    SNR = "SNR"
    CIRCUIT = "Commissioning Circuit"
    TEST_PACKAGE = "Test Package"


class ConstraintType(str, Enum):
    RESOURCE = "Resource"
    UTILITY = "Utility"
    AREA = "Area"
    VENDOR = "Vendor"
    PERMIT = "Permit"


class LogicOperator(str, Enum):
    AND = "AND"
    OR = "OR"
    NOT = "NOT"
