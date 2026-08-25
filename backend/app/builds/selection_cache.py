import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, Tuple

from pydantic import ValidationError
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.builds import customization
from app.builds.customization import customized_budget_floor, customized_budget_limit
from app.builds.models import BuildSelectionCache, BuildTemplate
from app.builds.service import BuildOptionResponse, BuildRequest
from app.catalog.models import ComponentPrice, HardwareComponent


CACHE_SCHEMA_VERSION = "build-selection-v2"


def request_identity(request: BuildRequest) -> Tuple[str, dict]:
    payload = {
        "budget": request.budget,
        "use_case": request.use_case,
        "game_categories": sorted(request.game_categories),
        "direction": request.direction,
        "ray_tracing": request.ray_tracing,
        "office_apps": sorted(request.office_apps),
        "needs_wireless_network": request.needs_wireless_network,
        "memory_size": request.memory_size,
        "storage_size": request.storage_size,
        "allows_flexible_budget": request.allows_flexible_budget,
        "no_gpu_build": request.no_gpu_build,
        "owned_gpu_model": (request.owned_gpu_model or "").lower() or None,
        "chassis_color": request.chassis_color,
        "cpu_preference": request.cpu_preference,
        "specified_cpu": request.specified_cpu,
        "specified_gpu": request.specified_gpu,
        "aesthetic_style": (
            request.aesthetic_style.model_dump(mode="json")
            if request.aesthetic_style is not None
            else None
        ),
        "notes": request.notes,
    }
    encoded = json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest(), payload


def option_cache_key(purchase_mode: str, gpu_vendor: Optional[str]) -> str:
    return f"{purchase_mode}:{gpu_vendor or 'any'}"


def current_cache_version(session: Session) -> str:
    parts = [CACHE_SCHEMA_VERSION, _build_rule_code_hash()]
    for model in (BuildTemplate, HardwareComponent, ComponentPrice):
        count, latest = session.execute(
            select(func.count(), func.max(model.updated_at))
        ).one()
        parts.append(f"{model.__tablename__}:{count}:{latest or ''}")
    return hashlib.sha256("|".join(parts).encode("utf-8")).hexdigest()


def selected_option(
    session: Session,
    request: BuildRequest,
    request_hash: str,
    option_key: str,
    cache_version: str,
    *,
    purchase_mode: str,
    gpu_vendor: Optional[str],
) -> Optional[BuildOptionResponse]:
    row = session.scalar(
        select(BuildSelectionCache).where(
            BuildSelectionCache.request_hash == request_hash,
            BuildSelectionCache.option_key == option_key,
            BuildSelectionCache.cache_version == cache_version,
            BuildSelectionCache.selected_count > 0,
        )
    )
    if row is None:
        return None
    try:
        option = BuildOptionResponse.model_validate(row.response_payload)
    except ValidationError:
        return None
    if option.details.direction != request.direction:
        return None
    if option.details.purchase_mode != purchase_mode:
        return None
    if gpu_vendor and option.details.gpu_vendor != gpu_vendor:
        return None
    parts = {part.role: part for part in option.details.parts}
    if not customization.budget_cpu_policy_allows(request, parts["cpu"]):
        return None
    if not customization.ddr4_memory_policy_allows(parts["ram"]):
        return None
    if (
        option.estimated_total is None
        or option.estimated_total < customized_budget_floor(request)
        or option.estimated_total > customized_budget_limit(request)
    ):
        return None
    return option.model_copy(
        update={
            "source": "selection_cache",
            "selection_id": row.id,
        }
    )


def store_pending_option(
    session: Session,
    request_hash: str,
    option_key: str,
    request_payload: dict,
    cache_version: str,
    option: BuildOptionResponse,
) -> BuildOptionResponse:
    response_payload = option.model_dump(
        mode="json",
        exclude={"selection_id"},
    )
    row = session.scalar(
        select(BuildSelectionCache).where(
            BuildSelectionCache.request_hash == request_hash,
            BuildSelectionCache.option_key == option_key,
        )
    )
    if row is None:
        row = BuildSelectionCache(
            request_hash=request_hash,
            option_key=option_key,
            request_payload=request_payload,
            response_payload=response_payload,
            cache_version=cache_version,
        )
        session.add(row)
        try:
            session.flush()
        except IntegrityError:
            session.rollback()
            row = session.scalar(
                select(BuildSelectionCache).where(
                    BuildSelectionCache.request_hash == request_hash,
                    BuildSelectionCache.option_key == option_key,
                )
            )
            if row is None:
                raise
            if row.cache_version != cache_version or row.response_payload != response_payload:
                row.selected_count = 0
                row.last_selected_at = None
            row.request_payload = request_payload
            row.response_payload = response_payload
            row.cache_version = cache_version
            row.updated_at = datetime.now(timezone.utc)
    else:
        if row.cache_version != cache_version or row.response_payload != response_payload:
            row.selected_count = 0
            row.last_selected_at = None
        row.request_payload = request_payload
        row.response_payload = response_payload
        row.cache_version = cache_version
        row.updated_at = datetime.now(timezone.utc)
    session.commit()
    return option.model_copy(update={"selection_id": row.id})


def mark_option_selected(
    session: Session,
    selection_id: str,
    cache_version: str,
) -> Optional[BuildSelectionCache]:
    row = session.get(BuildSelectionCache, selection_id)
    if row is None or row.cache_version != cache_version:
        return None
    row.selected_count += 1
    row.last_selected_at = datetime.now(timezone.utc)
    session.commit()
    session.refresh(row)
    return row


def _build_rule_code_hash() -> str:
    app_root = Path(customization.__file__).resolve().parents[1]
    digest = hashlib.sha256()
    for path in (
        Path(customization.__file__),
        app_root / "builds" / "service.py",
        app_root / "api" / "builds.py",
        Path(__file__),
    ):
        digest.update(path.read_bytes())
    return digest.hexdigest()
