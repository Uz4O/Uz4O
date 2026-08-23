from typing import Dict, Optional


# User-provided Delta Force benchmark charts dated 2026-05-02. Values are
# average FPS under the chart's high-preset, quality-upscaling, frame-generation
# disabled test condition. The source images are reference-only and are not
# distributed with the application.
CPU_AVERAGE_FPS: Dict[str, Dict[str, float]] = {
    "1080p": {
        "r7-9850x3d": 391.5,
        "r9-9950x3d": 383.1,
        "r7-9800x3d": 363.2,
        "r7-7800x3d": 314.2,
        "r7-9700x": 286.3,
        "r5-9600x": 260.3,
        "u7-270-plus": 253.8,
        "r5-9500f": 251.6,
        "u5-250-plus": 246.5,
        "i5-13600kf": 234.1,
        "u7-265k": 231.4,
        "i5-14600kf": 227.2,
        "i5-14400f": 190.3,
        "r5-7500f": 187.4,
        "i5-12400f": 178.6,
        "r7-5700x": 174.2,
        "i3-14100f": 162.8,
        "r5-5600": 160.0,
        "r5-5500": 141.3,
    },
    "2k": {
        "r7-9850x3d": 379.9,
        "r9-9950x3d": 379.3,
        "r7-9800x3d": 372.6,
        "r7-7800x3d": 310.0,
        "r7-9700x": 282.3,
        "r5-9600x": 267.2,
        "u7-270-plus": 265.6,
        "u5-250-plus": 244.8,
        "r5-9500f": 242.6,
        "u7-265k": 239.7,
        "i5-13600kf": 229.3,
        "i5-14600kf": 225.4,
        "r5-7500f": 200.0,
        "i5-14400f": 184.1,
        "r7-5700x": 181.1,
        "i5-12400f": 177.2,
        "i3-14100f": 166.4,
        "r5-5600": 162.7,
        "r5-5500": 135.4,
    },
}

GPU_AVERAGE_FPS: Dict[str, Dict[str, float]] = {
    "1080p": {
        "rtx-5090-d": 391.5,
        "rtx-5090-d-v2": 387.0,
        "arc-a580-8gb": 128.2,
        "rx-6500-xt": 100.6,
    },
    "2k": {
        "rtx-5090-d": 373.3,
        "rtx-5090-d-v2": 370.5,
        "rtx-5080": 350.8,
        "rtx-5070-ti": 331.5,
        "rx-9070-xt": 301.5,
        "rtx-5070": 264.7,
        "rx-9070-gre": 236.6,
        "rtx-5060-ti": 201.2,
        "rx-9060-xt-16gb": 197.4,
        "rtx-5060": 180.9,
        "arc-b580-12gb": 152.1,
        "rtx-5050": 134.9,
        "rx-7650-gre": 133.6,
        "arc-a580-8gb": 94.7,
        "rx-6500-xt": 58.0,
    },
    "4k": {
        "rtx-5090-d": 322.4,
        "rtx-5090-d-v2": 317.4,
        "rtx-5080": 219.5,
        "rtx-5070-ti": 194.7,
        "rx-9070-xt": 176.5,
        "rtx-5070": 153.8,
        "rx-9070-gre": 132.4,
        "rtx-5060-ti": 109.8,
    },
}


def delta_force_average_fps(
    cpu_id: str,
    gpu_id: str,
    resolution: str,
) -> Optional[int]:
    gpu_limit = GPU_AVERAGE_FPS.get(resolution, {}).get(gpu_id)
    if gpu_limit is None:
        return None
    if resolution == "4k":
        return round(gpu_limit)

    cpu_limit = CPU_AVERAGE_FPS.get(resolution, {}).get(cpu_id)
    if cpu_limit is None:
        return round(gpu_limit)
    return round(min(cpu_limit, gpu_limit))
