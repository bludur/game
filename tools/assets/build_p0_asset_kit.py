from __future__ import annotations

from pathlib import Path
from typing import Iterable

import bpy


ROOT_DIR = Path(__file__).resolve().parents[2]
MODEL_DIR = ROOT_DIR / "assets" / "models"
SOURCE_DIR = ROOT_DIR / "assets" / "source"


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)
    for material in list(bpy.data.materials):
        bpy.data.materials.remove(material)


def create_collection(name: str) -> bpy.types.Collection:
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def move_to_collection(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for current_collection in list(obj.users_collection):
        current_collection.objects.unlink(obj)
    collection.objects.link(obj)


def make_material(
    name: str,
    color: tuple[float, float, float, float],
    roughness: float = 0.75,
    metallic: float = 0.0,
    emission: tuple[float, float, float, float] | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    emission_input = shader.inputs.get("Emission Color") or shader.inputs.get("Emission")
    if emission is not None and emission_input is not None:
        emission_input.default_value = emission
        strength_input = shader.inputs.get("Emission Strength")
        if strength_input is not None:
            strength_input.default_value = emission_strength
    return material


def finish_object(
    obj: bpy.types.Object,
    collection: bpy.types.Collection,
    material: bpy.types.Material,
    name: str,
) -> bpy.types.Object:
    obj.name = name
    if obj.data is not None and hasattr(obj.data, "materials"):
        obj.data.materials.append(material)
    if obj.type == "MESH":
        for polygon in obj.data.polygons:
            polygon.use_smooth = False
    move_to_collection(obj, collection)
    return obj


def add_cone(
    collection: bpy.types.Collection,
    name: str,
    radius_bottom: float,
    radius_top: float,
    depth: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    vertices: int = 10,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    scale: tuple[float, float, float] = (1.0, 1.0, 1.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius_bottom,
        radius2=radius_top,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    obj = finish_object(bpy.context.object, collection, material, name)
    obj.scale = scale
    return obj


def add_ico(
    collection: bpy.types.Collection,
    name: str,
    radius: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    scale: tuple[float, float, float] = (1.0, 1.0, 1.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=location)
    obj = finish_object(bpy.context.object, collection, material, name)
    obj.scale = scale
    return obj


def add_cube(
    collection: bpy.types.Collection,
    name: str,
    size: tuple[float, float, float],
    location: tuple[float, float, float],
    material: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = finish_object(bpy.context.object, collection, material, name)
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def add_torus(
    collection: bpy.types.Collection,
    name: str,
    major_radius: float,
    minor_radius: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=16,
        minor_segments=6,
        location=location,
        rotation=rotation,
    )
    return finish_object(bpy.context.object, collection, material, name)


def build_player(materials: dict[str, bpy.types.Material]) -> bpy.types.Collection:
    collection = create_collection("MagePlayer")
    add_cone(collection, "Mage_Robe", 0.55, 0.34, 1.25, (0.0, 0.0, 0.65), materials["robe"], 12)
    add_ico(collection, "Mage_Shoulders", 0.52, (0.0, 0.0, 1.18), materials["robe_light"], (1.0, 0.62, 0.48))
    add_ico(collection, "Mage_Face", 0.31, (0.0, -0.04, 1.52), materials["skin"], (0.9, 0.82, 1.0))
    add_cone(collection, "Mage_HatBrim", 0.58, 0.58, 0.09, (0.0, 0.0, 1.82), materials["hat"], 14)
    add_cone(collection, "Mage_HatCrown", 0.43, 0.035, 0.82, (0.0, 0.0, 2.22), materials["hat"], 10, (0.0, 0.12, -0.08))
    add_cone(collection, "Mage_LeftSleeve", 0.22, 0.12, 0.72, (-0.42, 0.0, 1.12), materials["robe_light"], 8, (0.0, 0.45, -0.38))
    add_cone(collection, "Mage_RightSleeve", 0.22, 0.12, 0.72, (0.42, 0.0, 1.12), materials["robe_light"], 8, (0.0, -0.45, 0.38))
    add_cone(collection, "Mage_Staff", 0.045, 0.045, 1.72, (0.68, 0.02, 0.88), materials["wood"], 8, (0.0, 0.15, 0.04))
    add_ico(collection, "Mage_Focus", 0.18, (0.68, 0.0, 1.78), materials["arcane"])
    add_torus(collection, "Mage_FocusRing", 0.26, 0.035, (0.68, 0.0, 1.78), materials["gold"], (1.57, 0.0, 0.0))
    return collection


def build_chaser(materials: dict[str, bpy.types.Material]) -> bpy.types.Collection:
    collection = create_collection("ShadowChaser")
    add_ico(collection, "Chaser_Body", 0.62, (0.0, 0.0, 0.78), materials["shadow"], (0.82, 0.7, 1.2))
    add_cone(collection, "Chaser_LeftHorn", 0.15, 0.015, 0.66, (-0.28, 0.0, 1.55), materials["horn"], 7, (0.0, -0.3, -0.34))
    add_cone(collection, "Chaser_RightHorn", 0.15, 0.015, 0.66, (0.28, 0.0, 1.55), materials["horn"], 7, (0.0, 0.3, 0.34))
    add_cone(collection, "Chaser_LeftClaw", 0.18, 0.03, 0.7, (-0.55, -0.08, 0.72), materials["shadow_light"], 7, (0.45, 0.0, -0.52))
    add_cone(collection, "Chaser_RightClaw", 0.18, 0.03, 0.7, (0.55, -0.08, 0.72), materials["shadow_light"], 7, (-0.45, 0.0, 0.52))
    add_ico(collection, "Chaser_Core", 0.2, (0.0, -0.5, 0.94), materials["hostile"])
    add_torus(collection, "Chaser_Ring", 0.58, 0.045, (0.0, 0.0, 0.36), materials["hostile"], (0.0, 0.0, 0.0))
    return collection


def build_cultist(materials: dict[str, bpy.types.Material]) -> bpy.types.Collection:
    collection = create_collection("EmberCultist")
    add_cone(collection, "Cultist_Robe", 0.58, 0.3, 1.38, (0.0, 0.0, 0.7), materials["cultist"], 12)
    add_cone(collection, "Cultist_Hood", 0.43, 0.28, 0.62, (0.0, 0.0, 1.48), materials["cultist_dark"], 10)
    add_ico(collection, "Cultist_Mask", 0.28, (0.0, -0.28, 1.5), materials["mask"], (0.75, 0.45, 1.0))
    add_cone(collection, "Cultist_Staff", 0.045, 0.045, 1.72, (-0.6, 0.0, 0.86), materials["wood"], 8, (0.0, -0.12, -0.05))
    add_ico(collection, "Cultist_Orb", 0.17, (-0.6, 0.0, 1.76), materials["ember"])
    add_cone(collection, "Cultist_LeftSleeve", 0.2, 0.1, 0.64, (-0.4, -0.02, 1.05), materials["cultist_dark"], 8, (0.0, 0.4, -0.42))
    add_cone(collection, "Cultist_RightSleeve", 0.2, 0.1, 0.64, (0.4, -0.02, 1.05), materials["cultist_dark"], 8, (0.0, -0.4, 0.42))
    add_torus(collection, "Cultist_RitualRing", 0.62, 0.035, (0.0, 0.0, 0.08), materials["ember"])
    return collection


def build_arena_floor(materials: dict[str, bpy.types.Material]) -> bpy.types.Collection:
    collection = create_collection("ArenaFloor")
    add_cube(collection, "Arena_Floor", (24.0, 24.0, 0.4), (0.0, 0.0, -0.2), materials["stone"])
    add_torus(collection, "Arena_RuneOuter", 8.5, 0.075, (0.0, 0.0, 0.015), materials["rune"])
    add_torus(collection, "Arena_RuneInner", 4.3, 0.045, (0.0, 0.0, 0.02), materials["rune_dim"])
    for index in range(12):
        angle = index * 0.5235987756
        x = 6.4 * __import__("math").cos(angle)
        y = 6.4 * __import__("math").sin(angle)
        add_cube(collection, f"Arena_Rune_{index:02d}", (0.18, 1.0, 0.035), (x, y, 0.025), materials["rune_dim"], (0.0, 0.0, angle))
    return collection


def build_obelisk(materials: dict[str, bpy.types.Material]) -> bpy.types.Collection:
    collection = create_collection("ArenaObelisk")
    add_cube(collection, "Obelisk_Base", (2.4, 2.4, 0.28), (0.0, 0.0, 0.14), materials["stone_light"], (0.0, 0.0, 0.1))
    add_cone(collection, "Obelisk_Body", 0.78, 0.42, 1.5, (0.0, 0.0, 0.95), materials["stone"], 6, (0.0, 0.0, 0.08))
    add_cone(collection, "Obelisk_Tip", 0.43, 0.03, 0.82, (0.0, 0.0, 2.08), materials["stone_light"], 6)
    add_ico(collection, "Obelisk_Core", 0.17, (0.0, -0.48, 1.18), materials["rune"])
    return collection


def build_altar(materials: dict[str, bpy.types.Material]) -> bpy.types.Collection:
    collection = create_collection("ArenaAltar")
    add_cone(collection, "Altar_Base", 1.0, 0.82, 0.35, (0.0, 0.0, 0.18), materials["stone_light"], 8)
    add_cone(collection, "Altar_Plinth", 0.62, 0.48, 0.82, (0.0, 0.0, 0.72), materials["stone"], 8)
    add_ico(collection, "Altar_Crystal", 0.34, (0.0, 0.0, 1.38), materials["arcane"], (0.68, 0.68, 1.45))
    add_torus(collection, "Altar_Ring", 0.72, 0.055, (0.0, 0.0, 1.18), materials["gold"])
    return collection


def export_collection(collection: bpy.types.Collection, filename: str) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.all_objects:
        obj.hide_set(False)
        obj.select_set(True)
    if collection.all_objects:
        bpy.context.view_layer.objects.active = collection.all_objects[0]
    bpy.ops.export_scene.gltf(
        filepath=str(MODEL_DIR / filename),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=False,
    )


def hide_all_except(collections: Iterable[bpy.types.Collection], visible: bpy.types.Collection) -> None:
    for collection in collections:
        collection.hide_viewport = collection != visible
        collection.hide_render = collection != visible


def main() -> None:
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    reset_scene()

    materials = {
        "robe": make_material("Mage Robe", (0.16, 0.055, 0.38, 1.0), 0.78),
        "robe_light": make_material("Mage Robe Trim", (0.34, 0.12, 0.68, 1.0), 0.65),
        "skin": make_material("Mage Skin", (0.78, 0.5, 0.34, 1.0), 0.9),
        "hat": make_material("Mage Hat", (0.24, 0.07, 0.54, 1.0), 0.72),
        "wood": make_material("Dark Wood", (0.17, 0.07, 0.035, 1.0), 0.88),
        "gold": make_material("Runic Gold", (0.82, 0.52, 0.12, 1.0), 0.32, 0.65, (0.7, 0.28, 0.03, 1.0), 1.8),
        "arcane": make_material("Arcane Focus", (0.45, 0.12, 1.0, 1.0), 0.24, 0.2, (0.38, 0.06, 1.0, 1.0), 5.0),
        "shadow": make_material("Shadow Body", (0.075, 0.008, 0.085, 1.0), 0.46, 0.15),
        "shadow_light": make_material("Shadow Claws", (0.2, 0.018, 0.18, 1.0), 0.38, 0.2),
        "horn": make_material("Void Horn", (0.025, 0.008, 0.035, 1.0), 0.25, 0.55),
        "hostile": make_material("Hostile Core", (0.95, 0.015, 0.18, 1.0), 0.18, 0.15, (1.0, 0.005, 0.12, 1.0), 6.0),
        "cultist": make_material("Cultist Robe", (0.25, 0.025, 0.015, 1.0), 0.74),
        "cultist_dark": make_material("Cultist Hood", (0.1, 0.012, 0.008, 1.0), 0.82),
        "mask": make_material("Bone Mask", (0.72, 0.56, 0.35, 1.0), 0.62),
        "ember": make_material("Ember", (1.0, 0.08, 0.005, 1.0), 0.2, 0.1, (1.0, 0.025, 0.002, 1.0), 6.0),
        "stone": make_material("Witchroot Stone", (0.105, 0.13, 0.18, 1.0), 0.92),
        "stone_light": make_material("Witchroot Stone Edge", (0.2, 0.16, 0.28, 1.0), 0.86),
        "rune": make_material("Arena Rune", (0.52, 0.18, 1.0, 1.0), 0.3, 0.1, (0.4, 0.05, 1.0, 1.0), 4.0),
        "rune_dim": make_material("Arena Rune Dim", (0.22, 0.07, 0.42, 1.0), 0.45, 0.05, (0.16, 0.02, 0.36, 1.0), 2.0),
    }

    collections = [
        build_player(materials),
        build_chaser(materials),
        build_cultist(materials),
        build_arena_floor(materials),
        build_obelisk(materials),
        build_altar(materials),
    ]
    exports = [
        "mage_player.glb",
        "shadow_chaser.glb",
        "ember_cultist.glb",
        "arena_floor.glb",
        "arena_obelisk.glb",
        "arena_altar.glb",
    ]
    for collection, filename in zip(collections, exports, strict=True):
        export_collection(collection, filename)

    hide_all_except(collections, collections[0])
    bpy.context.scene.render.engine = "BLENDER_EEVEE"
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_DIR / "mage_prototype_p0.blend"))
    print(f"Built {len(exports)} GLB assets and mage_prototype_p0.blend")


if __name__ == "__main__":
    main()
