"""Atlas original de l'épave (Pillow), masque noir et icônes de récupération.

    python source/heli_wreck/make_texture.py
"""
import json
import random
from pathlib import Path
import math
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
    colors = [(104, 112, 78), (104, 112, 78), (44, 43, 39), (125, 126, 117),
              (54, 81, 83), (53, 56, 49), (73, 77, 65), (199, 102, 27)]
    uv = {}
    for i, (name, color) in enumerate(zip(REGIONS, colors)):
        x, y = i % 4 * 512, i // 4 * 1024
        draw.rectangle((x, y, x + 511, y + 1023), fill=color)
        # Usure à plusieurs échelles : les grandes traces survivent à la vue isométrique.
        patch = Image.new('RGB', (512, 1024), color)
        pixels = patch.load()
        for py in range(1024):
            for px in range(512):
                wave = 4*math.sin(px/57 + py/139) + 3*math.sin(py/43)
                delta = wave + rng.randrange(-4, 5)
                if name == 'olive':
                    # Incendie près du moteur, asymétrique, et non vert uniforme.
                    burn = math.exp(-((px-383)/92)**2 - ((py-710)/205)**2)
                    delta -= 58*burn
                pixels[px, py] = tuple(max(0, min(255, int(c+delta))) for c in color)
        atlas.paste(patch, (x, y))
        if name in ('olive', 'army', 'metal'):
            for off in (112, 296, 512, 748, 910):
                draw.line((x+8, y+off, x+502, y+off), fill=(68, 74, 53), width=2)
                draw.line((x+8, y+off+2, x+502, y+off+2), fill=(121, 129, 91), width=1)
                for rx in range(20, 512, 48):
                    draw.ellipse((x+rx, y+off-3, x+rx+2, y+off-1), fill=(145, 148, 119))
            for off in (96, 252, 408):
                draw.line((x+off, y+8, x+off, y+1015), fill=(68, 74, 53), width=2)
            # Éclats de peinture et rayures irrégulières, sans motif noir répété.
            for _ in range(150):
                px, py = x+rng.randrange(12, 495), y+rng.randrange(12, 1004)
                length = rng.randrange(3, 25)
                draw.line((px, py, px+length, py+rng.randrange(-6, 7)), fill=(151, 150, 127), width=1)
            for _ in range(28):
                px, py = x+rng.randrange(24, 465), y+rng.randrange(24, 980)
                draw.polygon([(px,py),(px+12,py-4),(px+23,py+3),(px+7,py+7)], fill=(72, 67, 51))
                draw.line((px,py+1,px+12,py-3,px+23,py+4), fill=(151, 148, 123), width=1)
        if name == 'soot':
            for off in range(60, 1024, 82):
                draw.line((x+30,y+off,x+480,y+off-13), fill=(63,61,54), width=7)
        if name == 'glass':
            draw.line((x+130,y+780,x+270,y+560,x+310,y+110), fill=(143,161,153), width=4)
            draw.line((x+270,y+560,x+450,y+650), fill=(143,161,153), width=3)
        if name == 'rotor':
            draw.rectangle((x+458,y+6,x+502,y+1017), fill=(142,132,75))
            draw.line((x+20,y+60,x+440,y+80), fill=(143,145,130), width=3)
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
