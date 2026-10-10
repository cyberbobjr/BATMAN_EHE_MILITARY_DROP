"""Relit les FBX binaires exportés, leurs unités, UV et références sensibles à la casse.

    python tests/check_mayday_assets.py

Ne constitue pas un test du chargement par le moteur du jeu.
"""
import io
import json
import os
import re
import struct
import xml.etree.ElementTree as ET
import zlib
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
COMMON = ROOT / 'Contents/mods/batman_MilitaryDrop/common/media'
SCRIPTS = ROOT / 'Contents/mods/batman_MilitaryDrop/42.21/media/scripts'


def exact(path):
    assert path.is_file(), f'Missing: {path}'
    node = path
    while node != ROOT:
        assert node.name in [p.name for p in node.parent.iterdir()], f'Case mismatch: {node}'
        node = node.parent
    return path


def read_fbx(path):
    stream = io.BytesIO(path.read_bytes())
    assert stream.read(23) == b'Kaydara FBX Binary  \x00\x1a\x00'
    version = struct.unpack('<I', stream.read(4))[0]
    header = '<QQQB' if version >= 7500 else '<IIIB'
    header_size = struct.calcsize(header)

    def prop():
        tag = stream.read(1).decode('ascii')
        scalar = {'Y': 'h', 'C': '?', 'I': 'i', 'F': 'f', 'D': 'd', 'L': 'q'}
        if tag in scalar:
            fmt = '<' + scalar[tag]
            return struct.unpack(fmt, stream.read(struct.calcsize(fmt)))[0]
        if tag in 'SR':
            length = struct.unpack('<I', stream.read(4))[0]
            value = stream.read(length)
            return value.decode('utf-8', errors='replace') if tag == 'S' else value
        count, encoding, length = struct.unpack('<III', stream.read(12))
        raw = stream.read(length)
        if encoding == 1:
            raw = zlib.decompress(raw)
        fmt = {'f':'f','d':'d','l':'q','i':'i','b':'?','c':'B'}[tag]
        return struct.unpack('<' + str(count) + fmt, raw)

    def node():
        end, count, _, length = struct.unpack(header, stream.read(header_size))
        if end == 0:
            return None
        name = stream.read(length).decode('ascii')
        values = [prop() for _ in range(count)]
        children = []
        while stream.tell() < end:
            child = node()
            if child:
                children.append(child)
        assert stream.tell() == end
        return name, values, children

    nodes = []
    while True:
        root = node()
        if root is None:
            return nodes
        nodes.append(root)


def walk(nodes):
    for node in nodes:
        yield node
        yield from walk(node[2])


def main():
    metrics = json.loads((ROOT / 'source/heli_wreck/metrics.json').read_text())
    for name, details in metrics.items():
        path = exact(COMMON / f'models_X/vehicles/{name}.fbx')
        nodes = list(walk(read_fbx(path)))
        vertices = [v[0] for n, v, _ in nodes if n == 'Vertices']
        assert len(vertices) == 1, 'One exported mesh per vehicle'
        data = vertices[0]
        dimensions = [max(data[axis::3]) - min(data[axis::3]) for axis in range(3)]
        expected = details['dimensions_m']
        # Blender XYZ -> FBX XZY, sommets en centimètres.
        for actual, meters in zip(dimensions, (expected[0], expected[2], expected[1])):
            assert abs(actual / 100 - meters) < .002, (name, dimensions, expected)
        for n, values, _ in nodes:
            if n == 'P' and values[0] in ('Lcl Scaling','Lcl Rotation','PreRotation'):
                expected_transform = (1,1,1) if values[0] == 'Lcl Scaling' else (0,0,0)
                assert all(abs(a-b) < .0001 for a,b in zip(values[-3:],expected_transform)), values
        assert sum(1 for n, _, _ in nodes if n == 'LayerElementUV') == 1
        for n, v, _ in nodes:
            if n == 'UV':
                assert all(0 <= value <= 1 for value in v[0]), 'UV inside the atlas'
        texture = exact(COMMON / f'textures/Vehicles/MilitaryDrop/{name}.png')
        mask = exact(COMMON / f'textures/Vehicles/MilitaryDrop/{name}_mask.png')
        assert Image.open(texture).size == (2048,2048)
        assert Image.open(mask).convert('RGB').getextrema() == ((0,0),(0,0),(0,0))
        print(f'{name}: {len(data)//3} exported vertices, cm/Y up, identity nodes, one UV layer')
    vehicle = (SCRIPTS / 'vehicles/MilitaryDrop_HeliWreck.txt').read_text(encoding='utf-8')
    for kind, ref in re.findall(r'\b(mesh|texture|textureMask|textureShadow)\s*=\s*([\w/]+)',vehicle):
        exact(COMMON / (f'models_X/{ref}.fbx' if kind == 'mesh' else f'textures/{ref}.png'))
    shadows = json.loads((ROOT/'source/heli_wreck/shadows.json').read_text())
    for name, details in shadows.items():
        image = Image.open(COMMON/f'textures/Vehicles/MilitaryDrop/{name}_shadow.png')
        assert image.mode == 'RGBA' and image.size == (1024,1024)
        alpha = image.getchannel('A')
        assert alpha.getbbox() == tuple(details['alpha_bbox'])
        assert alpha.getextrema() == (0,210)
        assert 0.08 < sum(alpha.histogram()[64:])/1024**2 < .65, 'Silhouette, not a rectangle'
        ext = ' '.join(f'{v:.5f}' for v in details['extents_m'])
        off = ' '.join(f'{v:.5f}' for v in details['offset_m'])
        assert re.search(rf'textureShadow = Vehicles/MilitaryDrop/{name}_shadow,\s*'
                         rf'shadowExtents = {re.escape(ext)},\s*shadowOffset = {re.escape(off)},', vehicle)
        nodes = list(walk(read_fbx(COMMON/f'models_X/vehicles/{name}.fbx')))
        raw = next(v[0] for n,v,_ in nodes if n == 'Vertices')
        width,length = details['extents_m']
        ox,oz = details['offset_m']
        # Contrôle de l'orientation (+X,+Z au coin haut-gauche), sur les FBX livrés.
        polygon_indices = next(v[0] for n,v,_ in nodes if n == 'PolygonVertexIndex')
        used_vertices = {-v-1 if v < 0 else v for v in polygon_indices}
        for index in used_vertices:
            i = index*3
            px = round((ox+width/2-raw[i]/100)/width*1024)
            py = round((oz+length/2-raw[i+2]/100)/length*1024)
            assert alpha.getpixel((px,py)) > 10, 'Projected vertex outside the shadow'
        print(f'{name}: fitted shadow silhouette, bounds, offset and UV orientation verified')
    vanilla = Path(os.environ.get('PZ_MEDIA', r'D:\SteamLibrary\steamapps\common\ProjectZomboid\media'))
    if vanilla.is_dir():
        outfit_xml = ET.parse(vanilla/'clothing/clothing.xml').getroot()
        for gender in ('m_MaleOutfits','m_FemaleOutfits'):
            assert any(entry.findtext('m_Name') == 'ArmyCamoGreen' for entry in outfit_xml.findall(gender))
        script = (SCRIPTS/'vehicles/MilitaryDrop_HeliWreck.txt').read_text(encoding='utf-8')
        assert re.search(r'extents\s*=\s*2\.8\s+2\.56\s+5\.8\s*,',script)
        print('Pilot outfit exists in both vanilla clothing registries; vehicle obstruction bounds follow the fuselage')
    for icon in re.findall(r'Icon\s*=\s*(\w+)',(SCRIPTS/'MilitaryDrop_salvage.txt').read_text()):
        p = exact(COMMON/f'textures/Item_{icon}.png')
        im = Image.open(p)
        assert im.size == (64,64) and im.mode == 'RGBA'
    print('Model, texture, mask and icon paths match exact filesystem case.')


if __name__ == '__main__':
    main()
