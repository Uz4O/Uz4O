import json
from pathlib import Path
from typing import List, Literal, Optional

from pydantic import BaseModel


Status = Literal["completed", "in_progress", "not_started"]
DEFAULT_PROGRESS_PATH = Path(__file__).resolve().parents[1] / "progress.json"


class ProgressItem(BaseModel):
    title: str
    description: str
    status: Status
    completed_at: Optional[str] = None


class ProgressPhase(BaseModel):
    name: str
    description: str
    items: List[ProgressItem]


class ProgressDashboard(BaseModel):
    project: str
    updated_at: str
    current_phase: str
    phases: List[ProgressPhase]

    @property
    def total_items(self) -> int:
        return sum(len(phase.items) for phase in self.phases)

    @property
    def completed_items(self) -> int:
        return sum(
            item.status == "completed"
            for phase in self.phases
            for item in phase.items
        )

    @property
    def completion_percentage(self) -> int:
        if self.total_items == 0:
            return 0
        return round(self.completed_items / self.total_items * 100)


def load_progress(path: Path = DEFAULT_PROGRESS_PATH) -> ProgressDashboard:
    with path.open(encoding="utf-8") as progress_file:
        return ProgressDashboard.model_validate(json.load(progress_file))
