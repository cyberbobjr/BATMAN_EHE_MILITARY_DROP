"""Export the dedicated RJ-93 item: single atlas/material, applied geometry, FBX and icon.
Run with Blender --background --factory-startup --python source/radio_jammer/export_game.py.
"""
from pathlib import Path
import importlib.util
import tempfile
import math
import sys
import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "tools"))
from sanitize_asset_paths import sanitize_asset_paths
MEDIA = HERE.parents[1] / "Contents/mods/batman_MilitaryDropJammer/common/media"
spec = importlib.util.spec_from_file_location("rj93_recipe", HERE / "build_radio_jammer.py")
recipe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recipe)
recipe.main(Path(tempfile.gettempdir()) / "rj93-export-preview")
scene = bpy.context.scene
subject = next(o for o in scene.objects if o.type == "EMPTY" and o.name.endswith("PZ_Subject"))
parts = []
for obj in list(subject.children):
    if obj.type not in ("MESH", "FONT"):
        continue
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    parts.append(bpy.context.object)
bpy.ops.object.select_all(action="DESELECT")
for obj in parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
obj = bpy.context.object
obj.name = "MDJ_RJ93"
obj.parent = None
scene.cursor.location = (0, 0, 0)
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
colors = {
    "olive": (0.32, 0.36, 0.23), "edge": (0.47, 0.48, 0.33),
    "dark": (0.10, 0.12, 0.11), "rubber": (0.055, 0.065, 0.06),
    "steel": (0.52, 0.54, 0.48), "cream": (0.82, 0.80, 0.64),
    "amber": (0.91, 0.47, 0.12), "red": (0.63, 0.12, 0.07), "glass": (0.19, 0.25, 0.20),
}
keys = list(colors)
image = bpy.data.images.new("MDJ_RJ93", width=288, height=32, alpha=True)
image.pixels = [v for _y in range(32) for x in range(288) for v in (*colors[keys[x // 32]], 1)]
for folder in ("models_X/WorldItems", "textures/WorldItems", "textures"):
    (MEDIA / folder).mkdir(parents=True, exist_ok=True)
image.filepath_raw = str(MEDIA / "textures/WorldItems/MDJ_RJ93.png")
image.file_format = "PNG"
image.save()
for layer in list(obj.data.uv_layers):
    obj.data.uv_layers.remove(layer)
uv = obj.data.uv_layers.new(name="UVMap")
for face in obj.data.polygons:
    material = obj.data.materials[face.material_index]
    name = material.name.split(".")[0].removeprefix("MD_RJ93_")
    idx = keys.index(name)
    for loop in face.loop_indices:
        uv.data[loop].uv = ((idx + 0.5) / len(keys), 0.5)
    face.material_index = 0
obj.data.materials.clear()
atlas = bpy.data.materials.new("MDJ_RJ93_Atlas")
atlas.use_nodes = True
tex = atlas.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = bpy.data.images.load(image.filepath_raw, check_existing=False)
atlas.node_tree.links.new(tex.outputs["Color"], atlas.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
atlas.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.85
obj.data.materials.append(atlas)
tri = obj.modifiers.new("Export triangles", "TRIANGULATE")
bpy.ops.object.modifier_apply(modifier=tri.name)
bpy.ops.export_scene.fbx(filepath=str(MEDIA / "models_X/WorldItems/MDJ_RJ93.fbx"),
    use_selection=True, object_types={"MESH"}, apply_unit_scale=True,
    bake_space_transform=False, axis_forward="-Z", axis_up="Y", add_leaf_bones=False, path_mode="STRIP")
sanitize_asset_paths(MEDIA / "models_X/WorldItems/MDJ_RJ93.fbx")
scene.render.resolution_x = scene.render.resolution_y = 64
scene.render.filepath = str(MEDIA / "textures/Item_MDJ_RJ93.png")
bpy.ops.render.render(write_still=True)
print({"vertices": len(obj.data.vertices), "triangles": len(obj.data.polygons), "materials": len(obj.data.materials)})
