import json
from pathlib import Path
from typing import List

from app.builds.service import BuildTemplateInput


def read_build_template_inputs(path: Path) -> List[BuildTemplateInput]:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError("Build template file must contain a JSON array")
    return [BuildTemplateInput.model_validate(item) for item in data]
