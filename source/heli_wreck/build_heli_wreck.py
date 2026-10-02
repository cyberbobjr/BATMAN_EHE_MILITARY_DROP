"""Épave originale : fuselage ouvert et queue séparée, sans ressources tierces.

    blender -b --factory-startup -P source/heli_wreck/build_heli_wreck.py

Produit les FBX (centimètres/Y haut), une scène .blend éditable et 3 aperçus.
Le script ne travaille que dans une scène dédiée, même lancé dans une interface.
"""
import json
import math
from pathlib import Path
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
MEDIA = HERE.parents[1] / 'Contents/mods/batman_MilitaryDrop/common/media'
UV = json.loads((HERE / 'atlas.json').read_text(encoding='utf-8'))
OBJECTS = []


def material(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(str(MEDIA / f'textures/Vehicles/MilitaryDrop/{name}.png'))
    mat.node_tree.links.new(tex.outputs['Color'], mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .92
    return mat


def mesh(name, verts, faces, region='olive'):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    layer = data.uv_layers.new(name='UVMap')
    for poly in data.polygons:
        u0, v0, u1, v1 = UV[region]
        for k, index in enumerate(poly.loop_indices):
            # Une cellule d'atlas entière par panneau : rivets lisibles aux petites tailles.
            layer.data[index].uv = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)][k % 4]
    OBJECTS.append(obj)
    return obj


def box(name, center, size, region='olive', rot=(0, 0, 0)):
    x, y, z = center
    sx, sy, sz = (s / 2 for s in size)
    verts = [(a * sx, b * sy, c * sz) for a in (-1, 1) for b in (-1, 1) for c in (-1, 1)]
    obj = mesh(name, verts, [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4),
                            (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)], region)
    obj.location = (x, y, z)
    obj.rotation_euler = rot
    return obj


def bar(name, a, b, radius=.06, region='metal'):
    a, b = Vector(a), Vector(b)
    obj = box(name, (a + b) / 2, (radius * 2, radius * 2, (b - a).length), region)
    obj.rotation_euler = (b - a).to_track_quat('Z', 'Y').to_euler()
    return obj


def hull():
    # Section ovale longitudinale, porte arrachée, nez aplati, raccord de queue déchiré.
    rings = [(-2.9, .30, .40, .70), (-2.1, .92, .83, 1.05), (-1.0, 1.08, .91, 1.13),
             (1.0, 1.02, .85, 1.13), (2.3, .72, .67, 1.02), (2.8, .45, .45, .85)]
    # Interpolation Catmull-Rom : la coque est courbe aussi dans la longueur.
    sections = []
    for i in range(len(rings) - 1):
        p0, p1 = rings[max(0, i - 1)], rings[i]
        p2, p3 = rings[i + 1], rings[min(len(rings) - 1, i + 2)]
        for step in range(6):
            t = step / 6
            sections.append(tuple(.5 * ((2 * b) + (-a + c) * t
                                        + (2*a - 5*b + 4*c - d) * t*t
                                        + (-a + 3*b - 3*c + d) * t*t*t)
                                  for a, b, c, d in zip(p0, p1, p2, p3)))
    sections.append(rings[-1])
    segments = 40
    verts = []
    for y, w, h, z in sections:
        for j in range(segments):
            angle = j * math.tau / segments
            shred = .10 * math.sin(j * 9) if y == 2.8 else 0
            verts.append((w * math.cos(angle), y + shred, z + h * math.sin(angle)))
    faces = []
    for i in range(len(sections) - 1):
        y = (sections[i][0] + sections[i + 1][0]) / 2
        for j in range(segments):
            angle = (j + .5) * math.tau / segments
            if -1.65 < y < .95 and (angle < .75 or angle > 5.6):
                continue  # Porte du côté droit ouverte ; intérieur visible.
            if y < -2.1 and .4 < angle < 2.6:
                continue  # Verrière cassée.
            faces.append((i * segments + j, i * segments + (j + 1) % segments,
                          (i + 1) * segments + (j + 1) % segments, (i + 1) * segments + j))
    obj = mesh('TornFuselage', verts, faces, 'olive')
    # Une texture continue sur la coque, pas une inscription répétée sur chaque face.
    u0, v0, u1, v1 = UV['olive']
    for poly in obj.data.polygons:
        poly.use_smooth = True
        for li in poly.loop_indices:
            vi = obj.data.loops[li].vertex_index
            ring, section = divmod(vi, segments)
            u = (sections[ring][0] + 2.9) / 5.7
            v = section / segments
            obj.data.uv_layers.active.data[li].uv = (u0 + (u1-u0)*u, v0 + (v1-v0)*v)
    solid = obj.modifiers.new('PanelThickness', 'SOLIDIFY')
    solid.thickness = .035
    # Plaque de marquage unique sur le flanc intact.
    plaque = mesh('ArmyStencil', [(-1.04, -.05, 1.3), (-1.04, .9, 1.3),
                                  (-.99, .9, 1.61), (-1.0, -.05, 1.61)], [(0, 1, 2, 3)], 'army')
    au0, av0, au1, av1 = UV['army']
    for li, (u, v) in zip(plaque.data.polygons[0].loop_indices, [(0,0),(1,0),(1,1),(0,1)]):
        plaque.data.uv_layers.active.data[li].uv = (au0+(au1-au0)*(.2+.65*u), av0+(av1-av0)*(.45+.22*v))
    box('CabinFloor', (0, -.2, .45), (1.5, 3.7, .08), 'interior')
    for x in (-.45, .45):
        box('PilotSeat', (x, -1.25, .63), (.45, .52, .16), 'interior')
        box('PilotSeatBack', (x, -.99, .97), (.46, .14, .67), 'interior', (.12, 0, 0))
        bar('WindscreenFrame', (x * 1.8, -2.05, .95), (x * 1.7, -1.82, 1.86), .025)
    box('InstrumentPanel', (0, -1.75, 1.13), (1.38, .18, .33), 'soot', (.2, 0, 0))
    mesh('BrokenGlass', [(-.82, -2.05, 1.0), (-.78, -1.8, 1.82), (-.23, -1.8, 1.8),
                         (-.37, -1.95, 1.3), (-.67, -2.06, 1.25)], [(0, 1, 2, 3), (0, 3, 4)], 'glass')
    box('BurnedEngineHousing', (0, 1.15, 1.95), (1.14, 1.5, .38), 'soot', (0, .12, 0))
    for x in (-.32, .32):
        bar('EngineExhaust', (x, 1.65, 2.0), (x, 2.2, 1.9), .13, 'soot')
    # Skids bent at the front, mount on one side collapsed.
    for s in (-1, 1):
        points = [(s * 1.2, -2.1, .33), (s * 1.35, -1.4, .10), (s * 1.32, 1.5, .10),
                  (s * 1.22, 2.1, .24)]
        for i in range(3):
            bar('BentSkid', points[i], points[i + 1], .055)
        for y in (-.9, 1.15):
            bar('SkidBrace', (s * .65, y, .58), (s * 1.32, y, .12), .045)
    bar('BentMast', (0, .15, 1.9), (.32, .05, 2.52), .085)
    box('RotorHub', (.32, .05, 2.51), (.38, .4, .18), 'metal')
    for i, length in enumerate((3.7, 2.8, 3.25, 1.8)):
        angle = .18 + i * math.pi / 2
        dx, dy = math.cos(angle), math.sin(angle)
        bar('RotorRoot', (.32, .05, 2.5), (.32 + dx * .6, .05 + dy * .6, 2.48), .07)
        box('CollapsedBlade', (.32 + dx * (length / 2 + .5), .05 + dy * (length / 2 + .5),
                              2.33 - i * .14), (length, .30, .05), 'rotor', (0, .07 + i * .05, angle))
    # Detached door and torn panels remain part of the fuselage asset.
    box('LooseDoor', (1.5, .2, .12), (.95, 1.3, .05), 'olive', (0, .07, -.2))
    return OBJECTS[:]


def tail():
    base = len(OBJECTS)
    # Poutre ovale, conique et légèrement fléchie ; raccord arraché laissé ouvert.
    segments, rings = 32, 24
    verts = []
    for i in range(rings + 1):
        t = i / rings
        width = .43 * (1 - t) ** 1.2 + .12 * t
        height = .37 * (1 - t) ** 1.1 + .15 * t
        cx = .08 * math.sin(math.pi * t)
        cz = .72 + .16 * t - .10 * math.sin(math.pi * t)
        for j in range(segments):
            angle = j * math.tau / segments
            tear = .08 * math.sin(j * 7) if i == 0 else 0
            verts.append((cx + width * math.cos(angle), -2.05 + 3.9 * t + tear,
                          cz + height * math.sin(angle)))
    faces = [(i * segments + j, i * segments + (j+1) % segments,
              (i+1) * segments + (j+1) % segments, (i+1) * segments + j)
             for i in range(rings) for j in range(segments)]
    boom = mesh('SnappedTailBoom', verts, faces, 'olive')
    u0, v0, u1, v1 = UV['olive']
    for poly in boom.data.polygons:
        poly.use_smooth = True
        for li in poly.loop_indices:
            i, j = divmod(boom.data.loops[li].vertex_index, segments)
            boom.data.uv_layers.active.data[li].uv = (u0+(u1-u0)*i/rings, v0+(v1-v0)*j/segments)
    thickness = boom.modifiers.new('TornTailSkin', 'SOLIDIFY')
    thickness.thickness = .025
    # Empennage avec profils affinés et arêtes arrondies, sans gros pavé rectangulaire.
    fin = mesh('BentFin', [(-.10,.65,.86),(.02,1.8,.87),(.08,1.53,1.87),
                           (.01,1.33,2.03),(-.07,1.13,1.97),(-.13,.93,1.12)],
               [(0,1,2,3,4,5)], 'olive')
    skin = fin.modifiers.new('FinThickness', 'SOLIDIFY')
    skin.thickness = .065
    edge = fin.modifiers.new('RoundedFinEdges', 'BEVEL')
    edge.width, edge.segments = .025, 4
    for side in (-1, 1):
        wing = mesh('TailStabilizer', [(0,.13,.89),(side*1.08,.35,.91),
                                      (side*1.01,.56,.86),(0,.62,.87)], [(0,1,2,3)], 'olive')
        solid = wing.modifiers.new('AirfoilThickness', 'SOLIDIFY')
        solid.thickness = .045
        bevel = wing.modifiers.new('RoundedStabilizer', 'BEVEL')
        bevel.width, bevel.segments = .015, 3
    bar('TailRotorAxle', (-.12, 1.6, 1.02), (.42, 1.6, 1.02), .06)
    for angle in (.4, .4 + math.pi / 2):
        box('BrokenTailRotor', (.42, 1.6, 1.02), (.05, .18, 1.6), 'rotor', (angle, 0, 0))
    return OBJECTS[base:]


def join(objects, name):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    for obj in objects:
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.convert(target='MESH')
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.clear()
    obj.data.materials.append(material(name))
    bpy.ops.export_scene.fbx(filepath=str(MEDIA / f'models_X/vehicles/{name}.fbx'), use_selection=True,
                             object_types={'MESH'}, global_scale=1, apply_unit_scale=True,
                             bake_space_transform=True, mesh_smooth_type='FACE', path_mode='STRIP')
    return obj


def main():
    scene = bpy.data.scenes.new('MilitaryDrop_Mayday')
    bpy.context.window.scene = scene
    (MEDIA / 'models_X/vehicles').mkdir(parents=True, exist_ok=True)
    main_obj = join(hull(), 'Vehicle_MilitaryDrop_HeliWreck')
    tail_obj = join(tail(), 'Vehicle_MilitaryDrop_HeliTail')
    # Export local de la queue avant de la déplacer dans la vitrine.
    tail_obj.location = (3.8, 6, 0)
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.background_type = 'WORLD'
    scene.world = bpy.data.worlds.new('MaydayPreviewWorld')
    scene.world.color = (.17, .19, .16)
    scene.render.resolution_x, scene.render.resolution_y = 1200, 900
    scene.render.resolution_percentage = 100
    camera_data = bpy.data.cameras.new('MaydayPreview')
    camera_data.type = 'ORTHO'
    camera_data.ortho_scale = 16
    camera = bpy.data.objects.new('MaydayPreview', camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    for name, azimuth, elevation in [('se', 45, 30), ('nw', 225, 30), ('top', 45, 80)]:
        az, el = math.radians(azimuth), math.radians(elevation)
        target = Vector((1, 2, .8))
        camera.location = target + Vector((math.cos(el) * math.sin(az), -math.cos(el) * math.cos(az),
                                           math.sin(el))) * 24
        camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
        scene.render.filepath = str(HERE / f'preview_{name}.png')
        bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / 'heli_wreck.blend'))
    metrics = {}
    for obj in (main_obj, tail_obj):
        metrics[obj.name] = {'dimensions_m': list(obj.dimensions), 'vertices': len(obj.data.vertices),
                             'polygons': len(obj.data.polygons), 'uv_layers': len(obj.data.uv_layers)}
    (HERE / 'metrics.json').write_text(json.dumps(metrics, indent=2) + '\n', encoding='utf-8')
    print('ASSET METRICS', metrics)


if __name__ == '__main__':
    main()
