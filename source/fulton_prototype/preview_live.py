"""Append the prototype into a dedicated scene and play its ascent in Blender.

Run from the interactive Blender MCP. Preserves all pre-existing scenes.
Writes only the new scene to fulton_ascent_preview.blend, not the open file.
"""
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent


def animate(scene):
    """Match the Lua prototype: 3 s rise, immediate 1.5 s pickup."""
    balloon = next(o for o in scene.objects if o.name.startswith("md_fulton_balloon"))
    bag = next(o for o in scene.objects if o.name.startswith("md_fulton_bag"))
    for obj in (balloon, bag):
        obj.animation_data_clear()
    scene.frame_start, scene.frame_end = 1, 109
    scene.render.fps = 24
    # A world Z level is sqrt(6) metres; origin offset is .2 level in Lua.
    unit = 2.44949
    for frame in range(1, scene.frame_end + 1):
        elapsed = (frame - 1) / 24
        t = max(0, min(1, (elapsed - 3) / 1.5))
        lift = t * t * (3 - 2 * t)
        bag.location = (4 * lift, 4 * lift, 2.5 * unit * lift)
        balloon.location = (4 * lift, 4 * lift,
                            .2 * unit + 2.5 * unit * min(1, elapsed / 3) + 2.5 * unit * lift)
        for obj in (balloon, bag):
            obj.keyframe_insert(data_path="location", frame=frame)
    scene.frame_set(1)


def main():
    with bpy.data.libraries.load(str(HERE / "fulton_prototype.blend"), link=False) as (src, dst):
        dst.scenes = [name for name in src.scenes if name == "MilitaryDrop Fulton prototype"]
    scene = dst.scenes[0]
    scene.name = "MilitaryDrop - Fulton ascent preview"
    bpy.context.window.scene = scene
    balloon = next(o for o in scene.objects if o.name.startswith("md_fulton_balloon"))
    bag = next(o for o in scene.objects if o.name.startswith("md_fulton_bag"))
    animate(scene)
    curve = bpy.data.curves.new("Fulton preview tether", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = .009
    curve.bevel_resolution = 1
    spline = curve.splines.new("POLY")
    spline.points.add(1)
    for index, target, zoffset in [(0, bag, .45), (1, balloon, .03)]:
        point = spline.points[index]
        point.co = (0, 0, zoffset, 1)
        for axis in range(3):
            driver = point.driver_add("co", axis).driver
            variable = driver.variables.new()
            variable.name = "coord"
            variable.type = "TRANSFORMS"
            variable.targets[0].id = target
            variable.targets[0].transform_type = ("LOC_X", "LOC_Y", "LOC_Z")[axis]
            variable.targets[0].transform_space = "WORLD_SPACE"
            driver.expression = f"coord + {zoffset if axis == 2 else 0}"
    tether = bpy.data.objects.new("Fulton preview tether", curve)
    scene.collection.objects.link(tether)
    mat = bpy.data.materials.new("Fulton preview cable")
    mat.diffuse_color = (.18, .20, .18, 1)
    curve.materials.append(mat)
    # Inspection ground, preview only (never exported to the game).
    ground_mesh = bpy.data.meshes.new("Fulton preview ground")
    ground_mesh.from_pydata([(-4, -4, -.01), (4, -4, -.01), (4, 4, -.01), (-4, 4, -.01)], [], [(0, 1, 2, 3)])
    ground = bpy.data.objects.new("Fulton preview ground", ground_mesh)
    scene.collection.objects.link(ground)
    ground_mat = bpy.data.materials.new("Fulton preview ground")
    ground_mat.diffuse_color = (.24, .26, .22, 1)
    ground_mesh.materials.append(ground_mat)
    scene.frame_set(1)
    for obj in scene.objects:
        obj.select_set(False)
        if obj.type in {"LIGHT", "CAMERA"}:
            obj.hide_set(True)
    balloon.select_set(True)
    bpy.context.view_layer.objects.active = balloon
    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            space = area.spaces.active
            space.shading.type = "MATERIAL"
            space.region_3d.view_perspective = "ORTHO"
            space.region_3d.view_location = (0, 0, 4)
            space.region_3d.view_distance = 14
            space.region_3d.view_rotation = Vector((3, -4, 2)).to_track_quat("Z", "Y")
    bpy.data.libraries.write(str(HERE / "fulton_ascent_preview.blend"), {scene},
                             path_remap="RELATIVE_ALL", fake_user=True, compress=True)
    if not bpy.context.screen.is_animation_playing:
        bpy.ops.screen.animation_play()
    return {"scene": scene.name, "frames": [1, 109], "rise_seconds": 3, "pickup_seconds": 1.5}


if __name__ == "__main__":
    result = main()
