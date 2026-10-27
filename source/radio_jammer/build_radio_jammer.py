"""RJ-93 visual proposal. Builds in its own scene; never clears a user scene.

Blender --background --factory-startup --python build_radio_jammer.py -- OUTPUT
Recipe entry points build(subject, mats) and materials() work with forge tools.
Builds geometry and proposal renders; export_game.py packages the dedicated world item.
"""
from pathlib import Path
import math
import os
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from sanitize_asset_paths import sanitize_asset_paths

import bpy
from mathutils import Vector

FORGE = Path(os.environ.get("PZ_FORGE", r"E:\pz-tools\pz-sprite-forge"))
sys.path.insert(0, str(FORGE / "blender"))
import pz_sprite_forge as F

PREFIX = "MD_RJ93"


def materials():
    colors = {
        "olive": (0.32, 0.36, 0.23),
        "edge": (0.47, 0.48, 0.33),
        "dark": (0.10, 0.12, 0.11),
        "rubber": (0.055, 0.065, 0.06),
        "steel": (0.52, 0.54, 0.48),
        "cream": (0.82, 0.80, 0.64),
        "amber": (0.91, 0.47, 0.12),
        "red": (0.63, 0.12, 0.07),
        "glass": (0.19, 0.25, 0.20),
    }
    return {key: F.forge_material(f"{PREFIX}_{key}", "metal", value)
            for key, value in colors.items()}


def build(subject, mats):
    """Portable 42 x 28 cm case, front -Y, world origin at feet."""
    def finish(obj, name, mat):
        obj.name = f"{PREFIX}_{name}"
        obj.parent = subject
        obj.data.materials.append(mats[mat])
        return obj

    def box(name, pos, size, mat, bevel=0.003):
        bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
        obj = bpy.context.object
        obj.scale = size
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        if bevel:
            mod = obj.modifiers.new("Machined edges", "BEVEL")
            mod.width = min(bevel, min(size) * 0.25)
            mod.segments = 2
        return finish(obj, name, mat)

    def cylinder(name, pos, radius, depth, mat, axis="z", vertices=16):
        rotation = {"z": (0, 0, 0), "y": (math.pi / 2, 0, 0),
                    "x": (0, math.pi / 2, 0)}[axis]
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
            depth=depth, location=pos, rotation=rotation)
        return finish(bpy.context.object, name, mat)

    def rod(name, a, b, radius, mat):
        a, b = Vector(a), Vector(b)
        obj = cylinder(name, (a + b) / 2, radius, (b - a).length, mat)
        obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
        return obj

    def label(name, text, pos, size, mat="cream", front=True):
        data = bpy.data.curves.new(f"{PREFIX}_{name}", "FONT")
        data.body = text
        data.size = size
        data.align_x = "CENTER"
        data.extrude = 0
        obj = bpy.data.objects.new(f"{PREFIX}_{name}", data)
        bpy.context.scene.collection.objects.link(obj)
        obj.location = pos
        obj.rotation_euler = (math.pi / 2 if front else math.pi / 2, 0,
                              0 if front else math.pi)
        obj.parent = subject
        data.materials.append(mats[mat])

    box("case", (0, 0, 0.168), (0.42, 0.28, 0.29), "olive", 0.014)
    box("bottom_bumper", (0, 0, 0.038), (0.435, 0.295, 0.032), "dark", 0.008)
    box("lid_gasket", (0, 0, 0.283), (0.429, 0.287, 0.008), "rubber")
    box("lid", (0, 0, 0.305), (0.43, 0.29, 0.035), "edge", 0.009)
    for x in (-0.17, 0.17):
        for y in (-0.105, 0.105):
            box("rubber_foot", (x, y, 0.012), (0.05, 0.045, 0.024), "rubber")
        box("front_protector", (x * 1.15, -0.143, 0.166),
            (0.026, 0.015, 0.215), "dark")
    # Front is readable as radio equipment, not a crate or an explosive.
    box("control_recess", (0, -0.143, 0.177), (0.335, 0.012, 0.192), "dark")
    box("control_plate", (0, -0.151, 0.177), (0.318, 0.008, 0.177), "olive")
    for x in (-0.145, 0.145):
        for z in (0.104, 0.248):
            cylinder("panel_screw", (x, -0.158, z), 0.004, 0.004, "steel", "y", 8)
    box("meter_frame", (-0.072, -0.16, 0.207), (0.126, 0.016, 0.068), "rubber")
    box("meter_face", (-0.072, -0.169, 0.207), (0.111, 0.003, 0.052), "cream", 0.001)
    for i in range(5):
        box("meter_tick", (-0.113 + i * 0.02, -0.172, 0.216),
            (0.002, 0.002, 0.012 if i % 2 == 0 else 0.007), "dark", 0)
    needle = box("meter_needle", (-0.075, -0.174, 0.201),
                 (0.0025, 0.002, 0.029), "red", 0)
    needle.rotation_euler.y = -0.42
    cylinder("frequency_knob", (0.069, -0.168, 0.204), 0.031, 0.027, "rubber", "y", 20)
    box("knob_index", (0.069, -0.184, 0.225), (0.004, 0.003, 0.013), "cream", 0)
    cylinder("status_bezel", (0.122, -0.16, 0.229), 0.008, 0.008, "dark", "y")
    cylinder("status_lens", (0.122, -0.166, 0.229), 0.005, 0.006, "amber", "y")
    box("switch_guard", (0.122, -0.164, 0.178), (0.029, 0.021, 0.033), "steel")
    rod("power_toggle", (0.122, -0.177, 0.175), (0.122, -0.196, 0.188), 0.0035, "dark")
    box("nameplate", (-0.039, -0.16, 0.12), (0.226, 0.004, 0.038), "dark")
    label("designation", "RJ-93", (-0.039, -0.164, 0.112), 0.025)
    label("signal", "SIGNAL", (-0.072, -0.164, 0.153), 0.012)
    label("power", "PWR", (0.12, -0.164, 0.148), 0.009)
    # Latches, carry handle, two unequal antennas for a clear silhouette.
    for x in (-0.146, 0.146):
        box("lid_latch", (x, -0.15, 0.288), (0.028, 0.015, 0.043), "steel")
    for x in (-0.064, 0.064):
        box("handle_mount", (x, -0.018, 0.331), (0.023, 0.032, 0.016), "dark")
        rod("handle_upright", (x, -0.018, 0.332), (x, -0.018, 0.397), 0.009, "dark")
    rod("carry_grip", (-0.064, -0.018, 0.397), (0.064, -0.018, 0.397), 0.013, "rubber")
    for x, height in ((-0.155, 0.77), (0.155, 0.59)):
        cylinder("antenna_socket", (x, 0.075, 0.337), 0.019, 0.031, "dark")
        cylinder("antenna_collar", (x, 0.075, 0.357), 0.012, 0.014, "steel")
        rod("antenna", (x, 0.075, 0.36), (x + 0.023, 0.095, height), 0.009, "dark")
        cylinder("antenna_tip", (x + 0.023, 0.095, height), 0.011, 0.025, "amber")
    # Side vents and the battery hatch remain legible at game scale.
    for x in (-0.214, 0.214):
        for z in (0.12, 0.145, 0.17, 0.195):
            box("vent", (x, -0.008, z), (0.004, 0.132, 0.008), "dark", 0)
    box("battery_gasket", (0, 0.143, 0.159), (0.264, 0.008, 0.172), "rubber")
    box("battery_hatch", (0, 0.15, 0.159), (0.248, 0.009, 0.155), "edge")
    box("battery_pull", (0.081, 0.16, 0.163), (0.034, 0.012, 0.037), "amber")
    label("battery_mark", "BATTERY", (-0.02, 0.156, 0.166), 0.022, front=False)
    label("battery_warning", "REMOVE BEFORE SERVICE", (-0.02, 0.156, 0.13), 0.009, front=False)
    for x in (-0.095, 0.095):
        for z in (0.103, 0.214):
            cylinder("hatch_screw", (x, 0.157, z), 0.004, 0.004, "steel", "y", 8)
    # Small restrained chips, deterministic and part of the recipe.
    for x, z, width in ((-0.19, 0.27, 0.014), (0.178, 0.079, 0.019),
                        (-0.184, 0.07, 0.009)):
        box("paint_chip", (x, -0.151, z), (width, 0.001, 0.002), "steel", 0)


def render_hero(scene, subject, out, rear=False):
    camera = bpy.data.objects.new(f"{PREFIX}_PresentationCamera", bpy.data.cameras.new("RJ93Camera"))
    scene.collection.objects.link(camera)
    target = Vector((0, 0, 0.36))
    camera.location = (1.12, 1.65 if rear else -1.65, 1.03)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.10
    subject.rotation_euler = (0, 0, 0)
    scene.camera = camera
    scene.render.resolution_x, scene.render.resolution_y = 1000, 1000
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.filepath = str(out)
    for obj in scene.objects:
        if obj.name in (F.GROUND_NAME, F.GUIDE_NAME):
            obj.hide_render = True
    bpy.ops.render.render(write_still=True)


def _build_scene(out, scene):
    out = Path(out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    # Register once; other scenes and their objects remain untouched.
    if not hasattr(bpy.types.Scene, "pz_forge"):
        F.register()
    props = scene.pz_forge
    props.sheet_name = "md_rj93_draft"
    props.output_dir = str(out / "cells")
    props.footprint_x = props.footprint_y = 1
    props.facings = "4"
    props.show_guide = False
    props.contrast_boost = 1.0
    F.build_rig(bpy.context)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 64
    scene.cycles.seed = 93
    scene.cycles.use_denoising = True
    subject = bpy.data.objects[F.SUBJECT_NAME]
    build(subject, materials())
    F.render_cells(bpy.context)
    render_hero(scene, subject, out / "preview-front.png")
    front_camera = scene.camera
    render_hero(scene, subject, out / "preview-rear.png", rear=True)
    scene.camera = front_camera
    # Save only this scene and its dependencies, not the user's other scenes.
    props.output_dir = "//cells"
    scene.render.filepath = "//preview-front.png"
    bpy.data.libraries.write(str(out / "radio_jammer.blend"), {scene},
                             path_remap="RELATIVE", fake_user=True, compress=False)
    sanitize_asset_paths(out / "radio_jammer.blend")
    return {"scene": scene.name, "objects": len(scene.objects), "output": str(out)}


def main(out):
    scene = bpy.data.scenes.new("MilitaryDrop_RJ93_Proposal")
    if not bpy.context.window:
        raise RuntimeError("No active Blender window context")
    bpy.context.window.scene = scene
    # Forge uses global rig names. Namespace every one before calling it so
    # an existing forge scene is never relinked or modified, even on a rerun.
    keys = ("RIG_COLLECTION", "SUBJECT_NAME", "CAMERA_NAME", "SUN_NAME",
            "GUIDE_NAME", "GROUND_NAME")
    previous = {key: getattr(F, key) for key in keys}
    try:
        for key, value in previous.items():
            setattr(F, key, f"{scene.name}_{value}")
        return _build_scene(out, scene)
    finally:
        for key, value in previous.items():
            setattr(F, key, value)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    print(main(args[0] if args else str(Path(__file__).parent)))
