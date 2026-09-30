"""Caisse de largage de Military Drop : modèle, export FBX et aperçus.

    blender -b --factory-startup -P source/supply_crate/build_supply_crate.py -- [dossier_aperçus]

Prérequis : python source/supply_crate/make_texture.py (texture et atlas.json).

Unités : 1 unité Blender = 1 m en jeu, avec le script de modèle `scale = 0.01`
et le véhicule `scale = 1.0` (le jeu lit un FBX de Blender en centimètres).
Origine au centre du dessous de la palette, Z vers le haut dans Blender. Le
fichier FBX reçoit des sommets en Y vers le haut et en centimètres, sans
transformation de nœud (bake_space_transform).

Écrit :
  common/media/models_X/vehicles/Vehicle_MilitaryDrop_SupplyCrate.fbx
  source/supply_crate/supply_crate.blend (copie modifiable)
  <dossier_aperçus>/preview_*.png si un dossier est donné.
"""

import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
MOD_MEDIA = REPO / "Contents" / "mods" / "batman_MilitaryDrop" / "common" / "media"
NAME = "Vehicle_MilitaryDrop_SupplyCrate"
TEXTURE = MOD_MEDIA / "textures" / "Vehicles" / "MilitaryDrop" / f"{NAME}.png"
FBX = MOD_MEDIA / "models_X" / "vehicles" / f"{NAME}.fbx"
BLEND = HERE / "supply_crate.blend"

ATLAS = json.loads((HERE / "atlas.json").read_text(encoding="utf-8"))

# Dimensions (m).
PALLET = 1.10
STRINGER_H = 0.10
STRINGER_W = 0.10
PLANK_T = 0.03
PLANK_W = 0.18
PLANK_COUNT = 5
DECK_TOP = STRINGER_H + PLANK_T
CRATE = 1.00
CRATE_TOP = DECK_TOP + 0.68
LID = 1.04
LID_T = 0.05
STRAP_W = 0.07
STRAP_T = 0.008
BUCKLE = 0.06
STRAP_OFFSET = 0.40

# Pour chaque normale, axe horizontal « vers la droite » vu de l'extérieur.
RIGHT = {
    (0, -1, 0): Vector((1, 0, 0)),
    (0, 1, 0): Vector((-1, 0, 0)),
    (1, 0, 0): Vector((0, 1, 0)),
    (-1, 0, 0): Vector((0, -1, 0)),
}


def face_axes(normal):
    key = tuple(int(round(c)) for c in normal)
    if key in RIGHT:
        return RIGHT[key], Vector((0, 0, 1))
    if key == (0, 0, 1):
        return Vector((1, 0, 0)), Vector((0, 1, 0))
    return Vector((1, 0, 0)), Vector((0, -1, 0))


def add_box(bm, uv_layer, center, size, regions, long_u=False):
    """Pavé ; regions(normal) donne la région d'atlas de chaque face."""
    cx, cy, cz = center
    sx, sy, sz = (s / 2 for s in size)
    verts = [bm.verts.new((cx + dx * sx, cy + dy * sy, cz + dz * sz))
             for dx in (-1, 1) for dy in (-1, 1) for dz in (-1, 1)]
    quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    for quad in quads:
        face = bm.faces.new([verts[i] for i in quad])
        face.normal_update()
        center_f = face.calc_center_median()
        if (center_f - Vector(center)).dot(face.normal) < 0:
            face.normal_flip()
        a, b = face_axes(face.normal)
        pa = [v.co.dot(a) for v in face.verts]
        pb = [v.co.dot(b) for v in face.verts]
        span_a, span_b = max(pa) - min(pa), max(pb) - min(pb)
        swap = long_u and span_b > span_a
        u0, v0, u1, v1 = ATLAS[regions(face.normal)]
        for loop in face.loops:
            ta = (loop.vert.co.dot(a) - min(pa)) / (span_a or 1)
            tb = (loop.vert.co.dot(b) - min(pb)) / (span_b or 1)
            if swap:
                ta, tb = tb, ta
            loop[uv_layer].uv = (u0 + (u1 - u0) * ta, v0 + (v1 - v0) * tb)


def crate_regions(normal):
    # Le dessus de la caisse est caché par le couvercle.
    if abs(normal.z) > 0.5:
        return "olive"
    return "side_marked" if abs(normal.y) > 0.5 else "side_arrows"


def lid_regions(normal):
    return "top" if normal.z > 0.5 else "olive"


def build_mesh():
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    # Palette : trois traverses, cinq planches.
    for x in (-(PALLET - STRINGER_W) / 2, 0, (PALLET - STRINGER_W) / 2):
        add_box(bm, uv, (x, 0, STRINGER_H / 2), (STRINGER_W, PALLET, STRINGER_H), lambda n: "stringer")
    gap = (PALLET - PLANK_COUNT * PLANK_W) / (PLANK_COUNT - 1)
    for i in range(PLANK_COUNT):
        y = -PALLET / 2 + PLANK_W / 2 + i * (PLANK_W + gap)
        add_box(bm, uv, (0, y, STRINGER_H + PLANK_T / 2), (PALLET, PLANK_W, PLANK_T), lambda n: "plank", long_u=True)

    # Caisse et couvercle.
    add_box(bm, uv, (0, 0, (DECK_TOP + CRATE_TOP) / 2), (CRATE, CRATE, CRATE_TOP - DECK_TOP), crate_regions)
    add_box(bm, uv, (0, 0, CRATE_TOP + LID_T / 2), (LID, LID, LID_T), lid_regions)

    # Quatre sangles au bord des faces (le marquage reste lisible) : dessus du
    # couvercle et deux côtés jusqu'à la palette, avec une boucle par sangle.
    top = CRATE_TOP + LID_T
    height = top - DECK_TOP
    for offset in (-STRAP_OFFSET, STRAP_OFFSET):
        # Sangle dans l'axe X (passe sur les faces ±X).
        add_box(bm, uv, (0, offset, top + STRAP_T / 2), (LID + 2 * STRAP_T, STRAP_W, STRAP_T), lambda n: "strap", True)
        for s in (-1, 1):
            add_box(bm, uv, (s * (LID / 2 + STRAP_T / 2), offset, DECK_TOP + height / 2),
                    (STRAP_T, STRAP_W, height), lambda n: "strap", True)
        add_box(bm, uv, (LID / 2 + STRAP_T + 0.01, offset, DECK_TOP + height * 0.45),
                (0.02, BUCKLE, BUCKLE), lambda n: "metal")
        # Sangle dans l'axe Y (passe sur les faces ±Y), un peu plus haut au croisement.
        add_box(bm, uv, (offset, 0, top + STRAP_T * 1.5), (STRAP_W, LID + 2 * STRAP_T, STRAP_T), lambda n: "strap", True)
        for s in (-1, 1):
            add_box(bm, uv, (offset, s * (LID / 2 + STRAP_T / 2), DECK_TOP + height / 2),
                    (STRAP_W, STRAP_T, height), lambda n: "strap", True)
        add_box(bm, uv, (offset, -(LID / 2 + STRAP_T + 0.01), DECK_TOP + height * 0.45),
                (BUCKLE, 0.02, BUCKLE), lambda n: "metal")

    mesh = bpy.data.meshes.new("MilitaryDrop_SupplyCrate")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def material():
    mat = bpy.data.materials.new("MilitaryDrop_SupplyCrate")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(TEXTURE))
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    return mat


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    mesh = build_mesh()
    obj = bpy.data.objects.new("MilitaryDrop_SupplyCrate", mesh)
    scene.collection.objects.link(obj)
    mesh.materials.append(material())
    return scene, obj


def export_fbx(obj):
    FBX.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    # bake_space_transform : sommets écrits directement en Y vers le haut et en
    # centimètres, sans rotation ni échelle de nœud (forme la plus sûre : le jeu
    # applique les transformations de nœud, mais on n'en dépend plus).
    bpy.ops.export_scene.fbx(filepath=str(FBX), use_selection=True, object_types={"MESH"},
                             global_scale=1.0, apply_unit_scale=True, bake_space_transform=True,
                             mesh_smooth_type="FACE", path_mode="STRIP", embed_textures=False)
    print("FBX:", FBX)


def render_previews(scene, out_dir):
    out_dir.mkdir(parents=True, exist_ok=True)
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x, scene.render.resolution_y = 640, 480
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("preview")
    scene.world = world
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.2
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    # Vue du jeu (30° d'élévation) depuis le sud-est et le nord-ouest, puis de dessus.
    views = {"se": (45, 30), "nw": (225, 30), "top": (45, 80)}
    for name, (azimuth, elevation) in views.items():
        az, el = math.radians(azimuth), math.radians(elevation)
        target = Vector((0, 0, 0.45))
        direction = Vector((math.cos(el) * math.sin(az), -math.cos(el) * math.cos(az), math.sin(el)))
        cam.location = target + direction * 6
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(out_dir / f"preview_{name}.png")
        bpy.ops.render.render(write_still=True)
        print("preview:", scene.render.filepath)
    bpy.data.objects.remove(cam)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    scene, obj = build()
    export_fbx(obj)
    if argv:
        render_previews(scene, Path(argv[0]))
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    dims = obj.dimensions
    print(f"DIMENSIONS {dims.x:.3f} x {dims.y:.3f} x {dims.z:.3f} m, {len(obj.data.vertices)} verts")


if __name__ == "__main__":
    main()
