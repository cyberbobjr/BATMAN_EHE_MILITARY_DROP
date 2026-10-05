"""Ombres au sol projetées depuis les FBX livrés, avec bounds dans le script.

python source/heli_wreck/make_shadows.py
Le coin UV (0,0) de BaseVehicle correspond à (+X,+Z) du maillage FBX.
"""
import json
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'tests'))
from check_mayday_assets import read_fbx, walk

MEDIA = ROOT / 'Contents/mods/batman_MilitaryDrop/common/media'
SCRIPT = ROOT / 'Contents/mods/batman_MilitaryDrop/42.21/media/scripts/vehicles/MilitaryDrop_HeliWreck.txt'


def main():
    text = SCRIPT.read_text(encoding='utf-8')
    report = {}
    for suffix in ('HeliWreck', 'HeliTail'):
        name = 'Vehicle_MilitaryDrop_' + suffix
        nodes = list(walk(read_fbx(MEDIA / f'models_X/vehicles/{name}.fbx')))
        raw = next(v[0] for n, v, _ in nodes if n == 'Vertices')
        indices = next(v[0] for n, v, _ in nodes if n == 'PolygonVertexIndex')
        vertices = [(raw[i]/100, raw[i+2]/100) for i in range(0, len(raw), 3)]
        lo_x, hi_x = min(v[0] for v in vertices)-.18, max(v[0] for v in vertices)+.18
        lo_z, hi_z = min(v[1] for v in vertices)-.18, max(v[1] for v in vertices)+.18
        width, length = hi_x-lo_x, hi_z-lo_z
        size, scale = 1024, 4
        alpha = Image.new('L', (size*scale, size*scale))
        draw = ImageDraw.Draw(alpha)
        polygon = []
        for index in indices:
            x, z = vertices[-index-1 if index < 0 else index]
            polygon.append(((hi_x-x)/width*size*scale, (hi_z-z)/length*size*scale))
            if index < 0:
                draw.polygon(polygon, fill=210)
                polygon = []
        alpha = alpha.resize((size,size), Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(3))
        shadow = Image.new('RGBA', (size,size), (0,0,0,0))
        shadow.putalpha(alpha)
        shadow.save(MEDIA / f'textures/Vehicles/MilitaryDrop/{name}_shadow.png')
        pattern = rf'(textureMask = Vehicles/MilitaryDrop/{name}_mask,)(?:\s*textureShadow[^,]+,\s*shadowExtents[^,]+,\s*shadowOffset[^,]+,)?'
        replacement = (rf'\1\n        textureShadow = Vehicles/MilitaryDrop/{name}_shadow,\n'
                       f'        shadowExtents = {width:.5f} {length:.5f},\n'
                       f'        shadowOffset = {(hi_x+lo_x)/2:.5f} {(hi_z+lo_z)/2:.5f},')
        text, count = re.subn(pattern, replacement, text)
        assert count == 1
        report[name] = {'extents_m': [width,length], 'offset_m': [(hi_x+lo_x)/2,(hi_z+lo_z)/2],
                        'uv_origin': '+X,+Z', 'size': size, 'alpha_bbox': alpha.getbbox()}
    SCRIPT.write_text(text, encoding='utf-8')
    (HERE / 'shadows.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
