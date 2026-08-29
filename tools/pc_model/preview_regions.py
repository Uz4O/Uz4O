"""Render spatial component candidates without modifying the high-fidelity source."""

from __future__ import annotations

import argparse
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


def flat_material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    output = nodes.new("ShaderNodeOutputMaterial")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = 0.7
    material.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    return material


def in_box(point: Vector, minimum: tuple[float, float, float], maximum: tuple[float, float, float]) -> bool:
    return all(minimum[index] <= point[index] <= maximum[index] for index in range(3))


def main() -> None:
    args = parse_args()
    bpy.ops.wm.open_mainfile(filepath=str(args.master.resolve()))
    source = bpy.data.objects["PC_HighFidelity_Source"]
    source.hide_render = True

    overlay = source.copy()
    overlay.data = source.data.copy()
    overlay.name = "Review_RegionOverlay"
    bpy.context.scene.collection.objects.link(overlay)
    overlay.hide_select = False
    overlay.hide_render = False

    base = flat_material("Review_Base", (0.08, 0.08, 0.08, 1))
    fan = flat_material("Review_Fans", (0.0, 0.65, 1.0, 1))
    cooler = flat_material("Review_WaterCooling", (0.85, 0.05, 0.65, 1))
    gpu = flat_material("Review_GPU", (1.0, 0.28, 0.02, 1))
    overlay.data.materials.clear()
    for material in (base, fan, cooler, gpu):
        overlay.data.materials.append(material)

    fan_boxes = (
        ((0.22, -0.24, 0.12), (0.47, 0.18, 0.72)),
        ((-0.30, -0.24, 0.05), (0.40, 0.16, 0.20)),
        ((-0.34, -0.24, 0.32), (-0.17, 0.12, 0.66)),
    )
    cooler_boxes = (
        ((-0.17, -0.24, 0.33), (0.14, 0.10, 0.59)),
        ((-0.22, -0.08, 0.50), (0.24, 0.16, 0.74)),
    )
    gpu_box = ((-0.25, -0.24, 0.16), (0.30, 0.10, 0.35))

    counts = [0, 0, 0, 0]
    for polygon in overlay.data.polygons:
        point = overlay.matrix_world @ polygon.center
        index = 0
        if any(in_box(point, *box) for box in fan_boxes):
            index = 1
        if any(in_box(point, *box) for box in cooler_boxes):
            index = 2
        if in_box(point, *gpu_box):
            index = 3
        polygon.material_index = index
        counts[index] += 1

    minimum = Vector((-0.3362700045, -0.2148141414, 0))
    maximum = Vector((0.4644590020, 0.2697770298, 0.7808191776))
    center = (minimum + maximum) / 2
    max_dimension = max(maximum - minimum)
    camera = bpy.data.objects["ReviewCamera"]
    camera.location = center + Vector((0, -1, 0.12)).normalized() * max_dimension * 3
    look_at(camera, center)

    scene = bpy.context.scene
    scene.render.filepath = str(args.output.resolve())
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    print({"base": counts[0], "fans": counts[1], "water_cooling": counts[2], "gpu": counts[3]})


if __name__ == "__main__":
    main()
