import pytest

from app.perf.estimator import LimitPoint, predict_average_fps


CPU_POINTS = [LimitPoint(50, 120), LimitPoint(100, 220)]
GPU_POINTS = [LimitPoint(40, 90), LimitPoint(80, 180)]


def test_prediction_uses_the_lower_hardware_limit() -> None:
    prediction = predict_average_fps(
        cpu_score=75,
        gpu_score=60,
        cpu_points=CPU_POINTS,
        gpu_points=GPU_POINTS,
        correction_factor=0.95,
        fps_cap=None,
    )

    assert prediction.cpu_limit == 170
    assert prediction.gpu_limit == 135
    assert prediction.average_fps == 128
    assert prediction.limiting_component == "gpu"


def test_prediction_extrapolates_monotonically_and_applies_cap() -> None:
    slow = predict_average_fps(40, 35, CPU_POINTS, GPU_POINTS, 1.0, 60)
    fast = predict_average_fps(120, 100, CPU_POINTS, GPU_POINTS, 1.0, 60)

    assert 1 <= slow.average_fps <= fast.average_fps
    assert fast.average_fps == 60


def test_prediction_requires_two_distinct_points_per_axis() -> None:
    with pytest.raises(ValueError, match="two distinct"):
        predict_average_fps(
            50,
            50,
            [LimitPoint(50, 100)],
            GPU_POINTS,
            1.0,
            None,
        )


def test_interpolation_handles_boundaries_and_unordered_points() -> None:
    unordered = [LimitPoint(100, 200), LimitPoint(50, 100)]

    at_point = predict_average_fps(50, 50, unordered, unordered, 1.0, None)
    below = predict_average_fps(25, 25, unordered, unordered, 1.0, None)
    above = predict_average_fps(125, 125, unordered, unordered, 1.0, None)

    assert at_point.average_fps == 100
    assert below.average_fps == 50
    assert above.average_fps == 250


def test_interpolation_rejects_duplicate_scores() -> None:
    duplicates = [LimitPoint(50, 100), LimitPoint(50, 110)]

    with pytest.raises(ValueError, match="distinct"):
        predict_average_fps(50, 50, duplicates, GPU_POINTS, 1.0, None)


def test_interpolation_rejects_non_monotonic_fit_points() -> None:
    decreasing = [LimitPoint(50, 110), LimitPoint(100, 100)]

    with pytest.raises(ValueError, match="monotonic"):
        predict_average_fps(75, 75, decreasing, GPU_POINTS, 1.0, None)
