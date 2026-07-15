import pytest

from app.perf.calibration import ValidationSample, calibrate_game_model
from app.perf.estimator import LimitPoint


CPU_POINTS = [LimitPoint(50, 100), LimitPoint(100, 200)]
GPU_POINTS = [LimitPoint(50, 90), LimitPoint(100, 180)]


def test_calibration_scores_only_independent_validation_samples() -> None:
    result = calibrate_game_model(
        cpu_points=CPU_POINTS,
        gpu_points=GPU_POINTS,
        validation_samples=[
            ValidationSample(75, 75, 135, True),
            ValidationSample(100, 100, 171, False),
        ],
        fps_cap=None,
    )

    assert result.correction_factor == pytest.approx(0.975, abs=0.001)
    assert result.validation_count == 2
    assert result.common_validation_count == 1
    assert result.common_validation_mape <= 8.0


@pytest.mark.parametrize(
    ("cpu_points", "gpu_points", "samples", "message"),
    [
        ([LimitPoint(50, 100)], GPU_POINTS, [ValidationSample(75, 75, 135, True)], "CPU axis"),
        (CPU_POINTS, [LimitPoint(50, 90)], [ValidationSample(75, 75, 135, True)], "GPU axis"),
        (CPU_POINTS, GPU_POINTS, [], "validation samples"),
        (CPU_POINTS, GPU_POINTS, [ValidationSample(75, 75, 0, True)], "positive"),
        (CPU_POINTS, GPU_POINTS, [ValidationSample(75, 75, 135, False)], "common-hardware"),
    ],
)
def test_calibration_rejects_unpublishable_inputs(
    cpu_points,
    gpu_points,
    samples,
    message,
) -> None:
    with pytest.raises(ValueError, match=message):
        calibrate_game_model(
            cpu_points,
            gpu_points,
            samples,
            fps_cap=None,
        )


def test_calibration_applies_game_cap_when_scoring_validation() -> None:
    result = calibrate_game_model(
        cpu_points=[LimitPoint(50, 60), LimitPoint(100, 120)],
        gpu_points=[LimitPoint(50, 60), LimitPoint(100, 120)],
        validation_samples=[ValidationSample(100, 100, 60, True)],
        fps_cap=60,
    )

    assert result.correction_factor == 1.0
    assert result.validation_mape == 0.0
