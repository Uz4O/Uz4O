"""Import the source GLB unchanged, save a packed Blender master, and render review views."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    argv = __import__("sys").argv
    return parser.parse_args(argv[argv.index("--") + 1 :])


def look_at(camera: bpy.types.Object, target: Vector) -> None:
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()


def world_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    corners = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    return (
        Vector(tuple(min(point[axis] for point in corners) for axis in range(3))),
        Vector(tuple(max(point[axis] for point in corners) for axis in range(3))),
    )


def add_area_light(name: str, location: tuple[float, float, float], energy: float, size: float) -> None:
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    obj.location = location
    bpy.context.scene.collection.objects.link(obj)
    look_at(obj, Vector((0, 0, 0)))


def main() -> None:
    args = parse_args()
    source = args.source.resolve()
    output = args.output.resolve()
    preview_dir = output / "previews"
    output.mkdir(parents=True, exist_ok=True)
    preview_dir.mkdir(parents=True, exist_ok=True)

    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(meshes) != 1:
        raise RuntimeError(f"Expected one source mesh, found {len(meshes)}")

    source_object = meshes[0]
    source_object.name = "PC_HighFidelity_Source"
    source_object.data.name = "PC_HighFidelity_Source_Mesh"
    source_object["source_file"] = source.name
    source_object["source_sha256"] = source_hash
    source_object["editing_policy"] = "Do not decimate or edit this object; duplicate into editable collections."

    source_collection = bpy.data.collections.new("00_SOURCE_LOCKED")
    bpy.context.scene.collection.children.link(source_collection)
    for collection in list(source_object.users_collection):
        collection.objects.unlink(source_object)
    source_collection.objects.link(source_object)
    source_object.hide_select = True

    for name in ("10_EDITABLE_COMPONENTS", "20_REPLACEMENT_SLOTS"):
        bpy.context.scene.collection.children.link(bpy.data.collections.new(name))

    minimum, maximum = world_bounds(meshes)
    center = (minimum + maximum) / 2
    dimensions = maximum - minimum
    max_dimension = max(dimensions)

    camera_data = bpy.data.cameras.new("ReviewCamera")
    camera = bpy.data.objects.new("ReviewCamera", camera_data)
    bpy.context.scene.collection.objects.link(camera)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = max_dimension * 1.45
    bpy.context.scene.camera = camera

    light_distance = max_dimension * 2.5
    add_area_light("Key", tuple(center + Vector((-1.2, -1.6, 1.8)) * light_distance), 1100, max_dimension)
    add_area_light("Fill", tuple(center + Vector((1.8, -0.5, 0.6)) * light_distance), 850, max_dimension)
    add_area_light("Rim", tuple(center + Vector((0.5, 1.8, 1.5)) * light_distance), 1000, max_dimension)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 1200
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("ReviewWorld")
    scene.world.color = (0.025, 0.025, 0.025)
    scene.view_settings.look = "AgX - Medium High Contrast"

    directions = {
        "01_front": Vector((0, -1, 0.12)),
        "02_front_left": Vector((-1, -1, 0.45)),
        "03_left": Vector((-1, 0, 0.12)),
        "04_back": Vector((0, 1, 0.12)),
        "05_right": Vector((1, 0, 0.12)),
        "06_top_front": Vector((0, -1, 1.25)),
    }
    camera_distance = max_dimension * 3
    for name, direction in directions.items():
        camera.location = center + direction.normalized() * camera_distance
        look_at(camera, center)
        scene.render.filepath = str(preview_dir / f"{name}.png")
        bpy.ops.render.render(write_still=True)

    source_object.hide_select = False
    bpy.ops.file.pack_all()
    blend_path = output / "pc_high_fidelity_master.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))

    mesh = source_object.data
    report = {
        "source": str(source),
        "source_sha256": source_hash,
        "blend": str(blend_path),
        "object_count": len(meshes),
        "vertices": len(mesh.vertices),
        "edges": len(mesh.edges),
        "polygons": len(mesh.polygons),
        "materials": [material.name for material in mesh.materials],
        "bounds_min": list(minimum),
        "bounds_max": list(maximum),
        "dimensions": list(dimensions),
        "geometry_changed": False,
    }
    (output / "master_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
