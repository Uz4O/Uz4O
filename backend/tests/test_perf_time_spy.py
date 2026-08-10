from datetime import datetime, timezone

from app.perf.models import HardwarePerformanceProfile
from app.perf.time_spy import (
    effective_performance_score,
    generated_gpu_performance_score,
    gpu_time_spy_score,
    has_time_spy_scores,
)


NOW = datetime(2026, 8, 9, tzinfo=timezone.utc)


def profile(component_id: str, score: int = 100) -> HardwarePerformanceProfile:
    return HardwarePerformanceProfile(
        component_id=component_id,
        category="gpu",
        performance_score=score,
        is_common=True,
        supports_dlss=True,
        supports_fsr=True,
        supports_standard_frame_generation=True,
        source_kind="self_measured",
        source_reference="test-fixture",
        reviewed_at=NOW,
        import_batch="test",
    )


def test_chart_scores_cover_exact_nvidia_amd_and_intel_catalog_ids() -> None:
    assert gpu_time_spy_score("rtx-5080") == 33018
    assert gpu_time_spy_score("rx-7900-xtx") == 30633
    assert gpu_time_spy_score("arc-b580-12gb") == 14688


def test_5090_d_v2_uses_the_delta_force_ratio_estimate() -> None:
    assert gpu_time_spy_score("rtx-5090-d-v2") == 47000


def test_other_ambiguous_or_missing_chart_variants_are_not_guessed() -> None:
    assert gpu_time_spy_score("rx-9060-xt-12gb") is None
    assert gpu_time_spy_score("rx-6750-gre") is None


def test_effective_score_switches_only_when_the_entire_gpu_axis_is_mapped() -> None:
    mapped = profile("rtx-4070", 100)
    assert has_time_spy_scores(["rtx-4060", "rtx-4070", "rtx-5080"])
    assert not has_time_spy_scores(["rtx-4070", "unknown-gpu"])
    assert effective_performance_score(mapped, use_time_spy=True) == 17867
    assert effective_performance_score(mapped, use_time_spy=False) == 100


def test_time_spy_normalizes_generated_scores_against_rtx_4060() -> None:
    assert generated_gpu_performance_score("rtx-4060", 999) == 40
    assert generated_gpu_performance_score("rtx-4080", 85) == 106
    assert generated_gpu_performance_score("unknown-gpu", 55) == 55
