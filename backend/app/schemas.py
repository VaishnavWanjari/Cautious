"""Pydantic request/response schemas for the API layer."""

from __future__ import annotations

from datetime import date

from pydantic import BaseModel, ConfigDict, Field


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# --- Project ------------------------------------------------------------
class ProjectIn(BaseModel):
    name: str
    client: str = ""
    location: str = ""
    mechanical_completion_date: date | None = None
    planned_startup_date: date | None = None
    working_weekdays: list[int] = Field(default_factory=lambda: [1, 2, 3, 4, 5])
    holidays: list[date] = Field(default_factory=list)


class ProjectOut(ORMModel):
    id: int
    name: str
    client: str
    location: str
    mechanical_completion_date: date | None
    planned_startup_date: date | None
    working_weekdays: list[int]
    holidays: list[date]


# --- Hierarchy nodes ----------------------------------------------------
class PMCCIn(BaseModel):
    code: str
    name: str = ""
    area: str = ""


class PMCCOut(ORMModel):
    id: int
    project_id: int
    code: str
    name: str
    area: str


class SystemIn(BaseModel):
    system_id: str
    description: str = ""
    priority: int = 3
    discipline: str = ""
    area: str = ""


class SystemOut(ORMModel):
    id: int
    pmcc_id: int
    system_id: str
    description: str
    priority: int
    discipline: str
    area: str


class SubsystemIn(BaseModel):
    number: str
    description: str = ""
    priority: int = 3
    discipline: str = ""
    area: str = ""


class SubsystemOut(ORMModel):
    id: int
    system_id: int
    number: str
    description: str
    priority: int
    discipline: str
    area: str


class SNRIn(BaseModel):
    code: str
    description: str = ""
    snr_type: str = "SNR"


class SNROut(ORMModel):
    id: int
    subsystem_id: int
    code: str
    description: str
    snr_type: str


# --- Activities & relationships ----------------------------------------
class ActivityIn(BaseModel):
    activity_id: str
    name: str
    duration: int = 1
    discipline: str = ""
    area: str = ""
    priority: int = 3
    status: str = "Not Started"
    progress: float = 0.0
    template_id: int | None = None
    pos_x: float | None = None
    pos_y: float | None = None


class ActivityOut(ORMModel):
    id: int
    snr_id: int
    activity_id: str
    name: str
    duration: int
    discipline: str
    area: str
    priority: int
    status: str
    progress: float
    es: int | None
    ef: int | None
    ls: int | None
    lf: int | None
    total_float: int | None
    is_critical: bool
    start_date: date | None
    finish_date: date | None
    pos_x: float | None
    pos_y: float | None


class RelationshipIn(BaseModel):
    predecessor_id: int
    successor_id: int
    rel_type: str = "FS"
    lag: int = 0


class RelationshipOut(ORMModel):
    id: int
    project_id: int
    predecessor_id: int
    successor_id: int
    rel_type: str
    lag: int


# --- Templates ----------------------------------------------------------
class TemplateIn(BaseModel):
    name: str
    category: str = ""
    default_duration: int = 1
    discipline: str = ""
    resources: str = ""
    utilities: str = ""
    description: str = ""


class TemplateOut(ORMModel):
    id: int
    name: str
    category: str
    default_duration: int
    discipline: str
    resources: str
    utilities: str
    description: str
    is_builtin: bool


# --- Logic rules --------------------------------------------------------
class LogicRuleIn(BaseModel):
    condition: str
    action: str
    enabled: bool = True


class LogicRuleOut(ORMModel):
    id: int
    project_id: int
    condition: str
    action: str
    structured: str
    enabled: bool


# --- Constraints --------------------------------------------------------
class ConstraintIn(BaseModel):
    constraint_type: str
    name: str
    capacity: float = 1.0
    available: bool = True
    notes: str = ""


class ConstraintOut(ORMModel):
    id: int
    project_id: int
    constraint_type: str
    name: str
    capacity: float
    available: bool
    notes: str


# --- Scheduling / network outputs --------------------------------------
class ScheduleActivity(BaseModel):
    id: int
    activity_id: str
    name: str
    duration: int
    es: int | None
    ef: int | None
    ls: int | None
    lf: int | None
    total_float: int | None
    is_critical: bool
    start_date: date | None
    finish_date: date | None


class ScheduleResultOut(BaseModel):
    activities: list[ScheduleActivity]
    critical_path: list[int]
    project_start: date | None
    project_finish: date | None
    warnings: list[str]


class NetworkNode(BaseModel):
    id: str
    data: dict
    position: dict


class NetworkEdge(BaseModel):
    id: str
    source: str
    target: str
    label: str
    animated: bool = False


class NetworkOut(BaseModel):
    nodes: list[NetworkNode]
    edges: list[NetworkEdge]


class ValidationOut(BaseModel):
    warnings: list[str]
    errors: list[str]


class AiQuery(BaseModel):
    project_id: int
    message: str


class AiReply(BaseModel):
    reply: str
    ai_available: bool
