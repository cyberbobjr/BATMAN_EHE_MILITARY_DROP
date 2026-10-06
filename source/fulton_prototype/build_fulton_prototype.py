"""Build the visual-only Fulton prototype with Blender (headless).

blender -b --factory-startup -P source/fulton_prototype/build_fulton_prototype.py
One metre per Blender unit; FBX node scale 100, model-script scale 0.01.
Produces two meshes, a shared palette, icons, preview and editable .blend.
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
MEDIA = HERE.parents[1] / "Contents/mods/batman_MilitaryDrop/common/media"
PALETTE = [(0.72, 0.67, 0.46), (0.85, 0.79, 0.58), (0.24, 0.29, 0.18),
           (0.12, 0.15, 0.12), (0.85, 0.28, 0.09), (0.52, 0.54, 0.50)]


def linear(value):
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def materials():
    result = []
    for i, color in enumerate(PALETTE):
        mat = bpy.data.materials.new(f"FultonPalette_{i}")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (*[linear(v) for v in color], 1)
        bsdf.inputs["Roughness"].default_value = 0.85
        result.append(mat)
    return result


def mesh(name, kind, location, scale, material, parts):
    if kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, location=location)
    elif kind == "cylinder":
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=1, depth=2, location=location)
    else:
        bpy.ops.mesh.primitive_cube_add(size=2, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    parts.append(obj)
    return obj


def build(subject, mats):
    """Reusable recipe entry point (subject collection, palette materials)."""
    parts = []
    body = mesh("Gasbag", "sphere", (0, 0, 1.05), (0.55, 0.55, 0.90), mats[0], parts)
    body.data.materials.append(mats[1])
    for face in body.data.polygons:
        angle = math.atan2(face.center.y, face.center.x)
        face.material_index = int((angle + math.pi) / (math.pi / 4)) % 2
        face.use_smooth = True
    mesh("Neck", "cylinder", (0, 0, 0.14), (0.065, 0.065, 0.12), mats[2], parts)
    mesh("Valve", "cylinder", (0, 0, 0.03), (0.08, 0.08, 0.03), mats[5], parts)
    # Four visible fabric tapes follow the gasbag profile.
    for side in range(4):
        curve = bpy.data.curves.new("Harness", "CURVE")
        curve.dimensions = "3D"
        curve.bevel_depth = 0.012
        curve.bevel_resolution = 1
        spline = curve.splines.new("POLY")
        spline.points.add(15)
        angle = side * math.pi / 2
        for i, point in enumerate(spline.points):
            theta = 0.12 + i * (math.pi - 0.24) / 15
            radius = 0.558 * math.sin(theta)
            point.co = (radius * math.cos(angle), radius * math.sin(angle),
                        1.05 + 0.906 * math.cos(theta), 1)
        obj = bpy.data.objects.new("Harness", curve)
        subject.objects.link(obj)
        obj.data.materials.append(mats[2])
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.convert(target="MESH")
        obj.select_set(False)
        parts.append(obj)
    # Bright identification panel on both sides.
    mesh("SignalBand", "cube", (0, -0.552, 1.08), (0.11, 0.012, 0.16), mats[4], parts)
    mesh("SignalBandBack", "cube", (0, 0.552, 1.08), (0.11, 0.012, 0.16), mats[4], parts)
    return parts


def build_bag(mats):
    parts = []
    obj = mesh("CargoBag", "cube", (0, 0, 0.22), (0.30, 0.22, 0.22), mats[2], parts)
    bevel = obj.modifiers.new("Soft corners", "BEVEL")
    bevel.width = 0.07
    bevel.segments = 3
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for x in (-0.18, 0.18):
        mesh("CargoStrap", "cube", (x, 0, 0.45), (0.025, 0.22, 0.012), mats[3], parts)
        for y in (-0.223, 0.223):
            mesh("CargoStrapSide", "cube", (x, y, 0.22), (0.025, 0.009, 0.20), mats[3], parts)
    mesh("CargoLabel", "cube", (0, -0.23, 0.25), (0.09, 0.007, 0.065), mats[1], parts)
    return parts


def join(name, parts, image):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for layer in list(obj.data.uv_layers):
        obj.data.uv_layers.remove(layer)
    uv = obj.data.uv_layers.new(name="UVMap")
    # Each material becomes a solid swatch in one shared texture.
    for face in obj.data.polygons:
        slot = obj.data.materials[face.material_index]
        index = int(slot.name.split("_")[-1].split(".")[0])
        for loop in face.loop_indices:
            uv.data[loop].uv = ((index + 0.5) / len(PALETTE), 0.5)
        face.material_index = 0
    obj.data.materials.clear()
    mat = bpy.data.materials.get("FultonAtlas")
    if mat is None:
        mat = bpy.data.materials.new("FultonAtlas")
        mat.use_nodes = True
        tree = mat.node_tree
        tex = tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        bsdf = tree.nodes.get("Principled BSDF")
        bsdf.inputs["Roughness"].default_value = 0.85
        tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    obj.data.materials.append(mat)
    return obj


def render(scene, obj, path, size):
    for other in scene.objects:
        if other.type == "MESH":
            other.hide_render = other != obj
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector([min(c[i] for c in corners) for i in range(3)])
    hi = Vector([max(c[i] for c in corners) for i in range(3)])
    center = (lo + hi) / 2
    camera = scene.camera
    camera.location = center + Vector((3, -4, 2.6))
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.ortho_scale = max(hi - lo) * 1.25
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main():
    # Dedicated headless scene; never clears a user's interactive scene.
    scene = bpy.data.scenes.new("MilitaryDrop Fulton prototype")
    bpy.context.window.scene = scene
    scene.unit_settings.system = "METRIC"
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = True
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("FultonWorld")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.7
    for name, kind in [("FultonCamera", "CAMERA"), ("FultonSun", "SUN")]:
        data = bpy.data.cameras.new(name) if kind == "CAMERA" else bpy.data.lights.new(name, kind)
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        if kind == "CAMERA":
            scene.camera = obj
            data.type = "ORTHO"
        else:
            data.energy = 2.5
            obj.rotation_euler = (0.55, -0.40, -0.50)
    for folder in (MEDIA / "models_X/WorldItems/MilitaryDrop", MEDIA / "textures/WorldItems/MilitaryDrop"):
        folder.mkdir(parents=True, exist_ok=True)
    image = bpy.data.images.new("md_fulton_palette", width=192, height=32, alpha=True)
    pixels = []
    for _y in range(32):
        for x in range(192):
            # Non-float generated PNG stores these channel values verbatim.
            pixels.extend([*PALETTE[x // 32], 1])
    image.pixels = pixels
    image.filepath_raw = str(MEDIA / "textures/WorldItems/MilitaryDrop/md_fulton_palette.png")
    image.file_format = "PNG"
    image.save()
    # Reload the saved sRGB PNG so render and FBX use the same interpretation.
    image = bpy.data.images.load(image.filepath_raw, check_existing=False)
    mats = materials()
    balloon = join("md_fulton_balloon", build(scene.collection, mats), image)
    bag = join("md_fulton_bag", build_bag(mats), image)
    for obj, icon in [(balloon, "MilitaryDrop_FultonPrototypeBalloon"), (bag, "MilitaryDrop_FultonPrototypeBag")]:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.fbx(
            filepath=str(MEDIA / f"models_X/WorldItems/MilitaryDrop/{obj.name}.fbx"),
            use_selection=True, object_types={"MESH"}, global_scale=1.0,
            apply_unit_scale=True, bake_space_transform=False, mesh_smooth_type="FACE",
            add_leaf_bones=False, path_mode="STRIP")
        render(scene, obj, MEDIA / f"textures/Item_{icon}.png", 64)
    render(scene, balloon, HERE / "preview_balloon.png", 512)
    for obj in (balloon, bag):
        obj.hide_render = False
    image.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "fulton_prototype.blend"), compress=True)
    print("Fulton prototype assets built")


if __name__ == "__main__":
    main()
