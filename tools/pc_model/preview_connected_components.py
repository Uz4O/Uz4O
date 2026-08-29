"""Preview whole loose mesh components selected from the three editable PC part regions."""

from __future__ import annotations

import argparse
import json
from array import array
from collections import Counter
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--master", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    argv = __import__("sys").argv
    return parser.parse_args(argv[argv.index("--") + 1 :])


def look_at(camera: bpy.types.Object, target: Vector) -> None:
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()


def material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    result = bpy.data.materials.new(name)
    result.diffuse_color = color
    result.use_nodes = True
    nodes = result.node_tree.nodes
    nodes.clear()
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    output = nodes.new("ShaderNodeOutputMaterial")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = 0.7
    result.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    return result


def point_in_polygon(x: float, z: float, polygon: tuple[tuple[float, float], ...]) -> bool:
    inside = False
    previous = polygon[-1]
    for current in polygon:
        x1, z1 = previous
        x2, z2 = current
        if (z1 > z) != (z2 > z):
            crossing = (x2 - x1) * (z - z1) / (z2 - z1) + x1
            if x < crossing:
                inside = not inside
        previous = current
    return inside


def roots_for_regions(
    obj: bpy.types.Object,
    regions: tuple[tuple[tuple[float, float], ...], ...],
    step: float = 0.003,
) -> Counter[int]:
    inverse = obj.matrix_world.inverted()
    direction = (inverse.to_3x3() @ Vector((0, 1, 0))).normalized()
    loops = obj.data.loops
    loop_vertices = array("i", [0]) * len(loops)
    loops.foreach_get("vertex_index", loop_vertices)
    hits: Counter[int] = Counter()

    for region in regions:
        min_x = min(point[0] for point in region)
        max_x = max(point[0] for point in region)
        min_z = min(point[1] for point in region)
        max_z = max(point[1] for point in region)
        x = min_x + step / 2
        while x < max_x:
            z = min_z + step / 2
            while z < max_z:
                if point_in_polygon(x, z, region):
                    origin = inverse @ Vector((x, -0.35, z))
                    hit, _, _, face_index = obj.ray_cast(origin, direction, distance=0.8)
                    if hit:
                        hits[loop_vertices[face_index * 3]] += 1
                z += step
            x += step
    return hits


def main() -> None:
    args = parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(args.master.resolve()))
    source = bpy.data.objects["PC_HighFidelity_Source"]
    mesh = source.data

    loops = array("i", [0]) * len(mesh.loops)
    mesh.loops.foreach_get("vertex_index", loops)
    parent = array("i", range(len(mesh.vertices)))
    size = array("i", [1]) * len(mesh.vertices)

    def find(vertex: int) -> int:
        while parent[vertex] != vertex:
            parent[vertex] = parent[parent[vertex]]
            vertex = parent[vertex]
        return vertex

    def union(left: int, right: int) -> None:
        left = find(left)
        right = find(right)
        if left == right:
            return
        if size[left] < size[right]:
            left, right = right, left
        parent[right] = left
        size[left] += size[right]

    for index in range(0, len(loops), 3):
        union(loops[index], loops[index + 1])
        union(loops[index], loops[index + 2])
    for vertex in range(len(parent)):
        parent[vertex] = find(vertex)

    case_fan_regions = (
        ((0.245, 0.535), (0.425, 0.535), (0.425, 0.695), (0.245, 0.695)),
        ((0.245, 0.370), (0.425, 0.370), (0.425, 0.530), (0.245, 0.530)),
        ((0.245, 0.205), (0.425, 0.205), (0.425, 0.365), (0.245, 0.365)),
        ((-0.255, 0.075), (0.385, 0.075), (0.385, 0.185), (-0.255, 0.185)),
    )
    water_cooling_regions = (
        ((-0.235, 0.625), (0.155, 0.625), (0.155, 0.725), (-0.235, 0.725)),
        ((-0.155, 0.345), (0.105, 0.345), (0.105, 0.555), (-0.155, 0.555)),
        ((-0.185, 0.525), (-0.115, 0.525), (-0.105, 0.650), (-0.220, 0.650)),
        ((-0.090, 0.515), (0.090, 0.515), (0.155, 0.650), (-0.035, 0.650)),
        ((0.055, 0.425), (0.215, 0.425), (0.215, 0.590), (0.055, 0.590)),
    )
    gpu_regions = (
        ((-0.235, 0.185), (0.300, 0.185), (0.300, 0.325), (-0.235, 0.325)),
        ((0.090, 0.305), (0.285, 0.305), (0.285, 0.400), (0.090, 0.400)),
    )

    hit_counts = {
        "fans": roots_for_regions(source, case_fan_regions),
        "water_cooling": roots_for_regions(source, water_cooling_regions),
        "gpu": roots_for_regions(source, gpu_regions),
    }
    root_hits: dict[str, Counter[int]] = {}
    for name, hits in hit_counts.items():
        counts: Counter[int] = Counter()
        for vertex, count in hits.items():
            counts[parent[vertex]] += count
        root_hits[name] = counts

    candidates = {
        root for counts in root_hits.values() for root, count in counts.items() if count >= 2
    }
    bounds: dict[int, list[float]] = {}
    for vertex in mesh.vertices:
        root = parent[vertex.index]
        if root not in candidates:
            continue
        point = source.matrix_world @ vertex.co
        if root not in bounds:
            bounds[root] = [point.x, point.y, point.z, point.x, point.y, point.z]
        else:
            value = bounds[root]
            value[0] = min(value[0], point.x)
            value[1] = min(value[1], point.y)
            value[2] = min(value[2], point.z)
            value[3] = max(value[3], point.x)
            value[4] = max(value[4], point.y)
            value[5] = max(value[5], point.z)

    def dimensions(root: int) -> tuple[float, float, float]:
        value = bounds[root]
        return value[3] - value[0], value[4] - value[1], value[5] - value[2]

    def keep_fan(root: int) -> bool:
        x, y, z = dimensions(root)
        return y < 0.32 and ((x < 0.24 and z < 0.58) or (x < 0.70 and z < 0.20))

    def keep_water_cooling(root: int) -> bool:
        x, y, z = dimensions(root)
        return x < 0.46 and y < 0.34 and z < 0.42 and bounds[root][1] < 0

    def keep_gpu(root: int) -> bool:
        x, y, z = dimensions(root)
        return x < 0.62 and y < 0.30 and z < 0.24 and bounds[root][1] < -0.04

    filters = {"fans": keep_fan, "water_cooling": keep_water_cooling, "gpu": keep_gpu}
    selected_roots = {
        name: {root for root, count in counts.items() if count >= 2 and filters[name](root)}
        for name, counts in root_hits.items()
    }
    selected_roots["water_cooling"] -= selected_roots["gpu"]
    selected_roots["fans"] -= selected_roots["water_cooling"] | selected_roots["gpu"]

    source.hide_render = True
    overlay = source.copy()
    overlay.data = source.data.copy()
    overlay.name = "Review_ConnectedComponents"
    bpy.context.scene.collection.objects.link(overlay)
    overlay.hide_select = False
    overlay.hide_render = False
    overlay.data.materials.clear()
    for value in (
        material("Review_Base", (0.055, 0.055, 0.055, 1)),
        material("Review_CaseFans", (0.0, 0.65, 1.0, 1)),
        material("Review_WaterCooling", (0.85, 0.05, 0.65, 1)),
        material("Review_GPU", (1.0, 0.28, 0.02, 1)),
    ):
        overlay.data.materials.append(value)

    face_counts = [0, 0, 0, 0]
    fan_roots = selected_roots["fans"]
    cooler_roots = selected_roots["water_cooling"]
    gpu_roots = selected_roots["gpu"]
    for face_index, polygon in enumerate(overlay.data.polygons):
        root = parent[loops[face_index * 3]]
        material_index = 0
        if root in fan_roots:
            material_index = 1
        elif root in cooler_roots:
            material_index = 2
        elif root in gpu_roots:
            material_index = 3
        polygon.material_index = material_index
        face_counts[material_index] += 1

    minimum = Vector((-0.3362700045, -0.2148141414, 0))
    maximum = Vector((0.4644590020, 0.2697770298, 0.7808191776))
    center = (minimum + maximum) / 2
    max_dimension = max(maximum - minimum)
    camera = bpy.data.objects["ReviewCamera"]
    views = {
        "08_connected_front.png": Vector((0, -1, 0.12)),
        "09_connected_front_left.png": Vector((-1, -1, 0.45)),
    }
    for filename, direction in views.items():
        camera.location = center + direction.normalized() * max_dimension * 3
        look_at(camera, center)
        bpy.context.scene.render.filepath = str(output / filename)
        bpy.ops.render.render(write_still=True)

    report = {
        "roots": {name: len(roots) for name, roots in selected_roots.items()},
        "faces": {
            "base": face_counts[0],
            "fans": face_counts[1],
            "water_cooling": face_counts[2],
            "gpu": face_counts[3],
        },
        "largest_selected_bounds": {
            name: [
                {
                    "root": root,
                    "hits": root_hits[name][root],
                    "dimensions": dimensions(root),
                    "bounds": bounds[root],
                }
                for root in sorted(roots, key=lambda value: size[value], reverse=True)[:20]
            ]
            for name, roots in selected_roots.items()
        },
    }
    (output / "connected_component_report.json").write_text(
        json.dumps(report, indent=2), encoding="utf-8"
    )
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
