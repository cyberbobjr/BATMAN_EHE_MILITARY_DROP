"""Atlas original de l'épave (Pillow), masque noir et icônes de récupération.

    python source/heli_wreck/make_texture.py
"""
import json
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
MEDIA = HERE.parents[1] / 'Contents/mods/batman_MilitaryDrop/common/media'
OUT = MEDIA / 'textures/Vehicles/MilitaryDrop'
REGIONS = ['olive', 'army', 'soot', 'metal', 'glass', 'interior', 'rotor', 'orange']


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rng = random.Random(84221)
    atlas = Image.new('RGB', (2048, 2048))
    draw = ImageDraw.Draw(atlas)
    colors = [(76, 81, 49), (78, 84, 51), (35, 34, 30), (108, 105, 91),
              (20, 35, 37), (32, 34, 29), (55, 56, 49), (199, 102, 27)]
    uv = {}
    for i, (name, color) in enumerate(zip(REGIONS, colors)):
        x, y = i % 4 * 512, i // 4 * 1024
        draw.rectangle((x, y, x + 511, y + 1023), fill=color)
        for _ in range(30000):
            px, py = x + rng.randrange(512), y + rng.randrange(1024)
            delta = rng.randrange(-12, 13)
            draw.point((px, py), fill=tuple(max(0, min(255, c + delta)) for c in color))
        if name in ('olive', 'army', 'metal'):
            for off in range(16, 1024, 128):
                draw.line((x + 8, y + off, x + 502, y + off), fill=(42, 44, 34), width=3)
                for rx in range(20, 512, 64):
                    draw.ellipse((x + rx, y + off - 5, x + rx + 4, y + off - 1), fill=(133, 136, 108))
        if name == 'army':
            font = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 74)
            small = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 30)
            draw.text((x + 128, y + 380), 'ARMY', font=font, fill=(211, 210, 162))
            draw.text((x + 128, y + 470), 'MD-08 / 214', font=small, fill=(191, 191, 147))
        uv[name] = [(x + 4) / 2048, 1 - (y + 1020) / 2048, (x + 508) / 2048, 1 - (y + 4) / 2048]
    for name in ('Vehicle_MilitaryDrop_HeliWreck', 'Vehicle_MilitaryDrop_HeliTail'):
        atlas.save(OUT / f'{name}.png')
        Image.new('RGB', (2048, 2048)).save(OUT / f'{name}_mask.png')
    (HERE / 'atlas.json').write_text(json.dumps(uv, indent=2) + '\n', encoding='utf-8')
    icons = MEDIA / 'textures'
    for name, color in [('AvionicsSalvage', '#52635a'), ('MechanicalSalvage', '#777969'),
                        ('MetalSalvage', '#94988e'), ('FlightRecorder', '#d87023')]:
        image = Image.new('RGBA', (64, 64))
        d = ImageDraw.Draw(image)
        d.polygon([(8, 21), (42, 12), (57, 23), (24, 33)], fill=color, outline='#20251f')
        d.polygon([(8, 21), (24, 33), (24, 54), (8, 40)], fill='#3c443c', outline='#20251f')
        d.polygon([(24, 33), (57, 23), (57, 44), (24, 54)], fill=color, outline='#20251f')
        d.line((17, 18, 33, 29, 33, 51), fill='#242923', width=4)
        d.rectangle((36, 35, 49, 41), fill='#d1c9a0', outline='#29312b')
        image.save(icons / f'Item_MilitaryDrop_{name}.png')
    print('Atlas 2048, masks, four transparent icons generated')


if __name__ == '__main__':
    main()
