"""Texture de la caisse de largage (atlas 1024 × 1024), entièrement générée.

    python source/supply_crate/make_texture.py

Écrit dans le mod :
  common/media/textures/Vehicles/MilitaryDrop/Vehicle_MilitaryDrop_SupplyCrate.png
  common/media/textures/Vehicles/MilitaryDrop/Vehicle_MilitaryDrop_SupplyCrate_mask.png
et, à côté de ce script, atlas.json : les régions (UV 0-1, origine en bas à
gauche comme Blender) lues par build_supply_crate.py.

Contenu original : contreplaqué vert olive, palette en bois, sangles, boucles,
marquages au pochoir (police Stencil de Windows, rendue en image seulement).
Le masque est noir : le shader « vehicle » n'applique aucune peinture de
carrosserie aléatoire.
"""

import json
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
OUT_DIR = REPO / "Contents" / "mods" / "batman_MilitaryDrop" / "common" / "media" / "textures" / "Vehicles" / "MilitaryDrop"
NAME = "Vehicle_MilitaryDrop_SupplyCrate"
SIZE = 1024
SEED = 42

FONT_STENCIL = r"C:\Windows\Fonts\STENCIL.TTF"
OLIVE = (82, 90, 56)
PAINT = (226, 219, 184)

# Régions en pixels (x0, y0, x1, y1), origine en haut à gauche de l'image.
REGIONS = {
    "side_marked": (0, 0, 512, 384),
    "side_arrows": (512, 0, 1024, 384),
    "top": (0, 384, 512, 896),
    "olive": (512, 384, 768, 640),
    "stringer": (768, 384, 1024, 640),
    "plank": (512, 640, 1024, 768),
    "strap": (512, 768, 1024, 832),
    "metal": (512, 832, 640, 960),
}


def noise(w, h, amount, rng):
    return rng.normal(0.0, amount, (h, w, 1))


def fill(img, box, color, grain, rng, vertical=False):
    """Aplat bruité avec un léger veinage (bois, contreplaqué)."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    base = np.ones((h, w, 3)) * np.array(color, dtype=float)
    base += noise(w, h, 4.0, rng)
    if grain:
        axis = np.arange(w if vertical else h, dtype=float)
        phase = rng.uniform(0, 6.28)
        waves = np.sin(axis / rng.uniform(3.0, 5.0) + phase) * grain
        waves += np.sin(axis / rng.uniform(11.0, 17.0)) * grain * 0.6
        waves = waves[np.newaxis, :, np.newaxis] if vertical else waves[:, np.newaxis, np.newaxis]
        base += waves
    img.paste(Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB"), (x0, y0))


def frame(draw, box, width, color):
    x0, y0, x1, y1 = box
    for i in range(width):
        draw.rectangle((x0 + i, y0 + i, x1 - 1 - i, y1 - 1 - i), outline=color)


def stencil(img, box, text, size, center, rng, color=PAINT):
    """Texte au pochoir, un peu usé (pixels retirés au hasard)."""
    layer = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(layer)
    font = ImageFont.truetype(FONT_STENCIL, size)
    tw = d.textlength(text, font=font)
    x = box[0] + center[0] - tw / 2
    y = box[1] + center[1] - size / 2
    d.text((x, y), text, font=font, fill=235)
    arr = np.array(layer, dtype=float)
    arr *= rng.uniform(0.55, 1.0, arr.shape)
    mask = Image.fromarray(arr.astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(0.6))
    img.paste(Image.new("RGB", img.size, color), (0, 0), mask)


def star(img, box, center, radius, rng):
    cx, cy = box[0] + center[0], box[1] + center[1]
    layer = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(layer)
    d.ellipse((cx - radius * 1.25, cy - radius * 1.25, cx + radius * 1.25, cy + radius * 1.25), outline=235, width=10)
    import math
    points = []
    for i in range(10):
        r = radius if i % 2 == 0 else radius * 0.4
        a = -math.pi / 2 + i * math.pi / 5
        points.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d.polygon(points, fill=235)
    arr = np.array(layer, dtype=float) * rng.uniform(0.6, 1.0, (img.size[1], img.size[0]))
    img.paste(Image.new("RGB", img.size, PAINT), (0, 0),
              Image.fromarray(arr.astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(0.6)))


def arrows(img, box, rng):
    layer = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(layer)
    for cx in (box[0] + 170, box[0] + 342):
        top = box[1] + 70
        d.polygon([(cx, top), (cx - 55, top + 70), (cx + 55, top + 70)], fill=235)
        d.rectangle((cx - 20, top + 70, cx + 20, top + 170), fill=235)
    arr = np.array(layer, dtype=float) * rng.uniform(0.6, 1.0, (img.size[1], img.size[0]))
    img.paste(Image.new("RGB", img.size, PAINT), (0, 0),
              Image.fromarray(arr.astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(0.6)))


def dirt(img, rng, amount=18):
    arr = np.array(img, dtype=float)
    blotches = Image.fromarray((rng.random((64, 64)) * 255).astype(np.uint8), "L").resize(img.size, Image.BICUBIC)
    arr -= (np.array(blotches, dtype=float)[:, :, np.newaxis] / 255.0) * amount
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def main():
    rng = np.random.default_rng(SEED)
    random.seed(SEED)
    img = Image.new("RGB", (SIZE, SIZE), (40, 40, 40))
    draw = ImageDraw.Draw(img)

    # Panneaux de contreplaqué vert olive, cadre plus sombre.
    for key in ("side_marked", "side_arrows", "top", "olive"):
        fill(img, REGIONS[key], OLIVE, 3.0, rng, vertical=True)
        frame(draw, REGIONS[key], 14 if key != "olive" else 6, (58, 64, 40))

    box = REGIONS["side_marked"]
    stencil(img, box, "U.S. ARMY", 70, (256, 130), rng)
    stencil(img, box, "SUPPLY - AIRDROP", 32, (256, 215), rng)
    stencil(img, box, "NSN 8140-01-MD-0042", 24, (256, 280), rng)
    stencil(img, box, "GROSS WT 440 LBS", 24, (256, 318), rng)

    box = REGIONS["side_arrows"]
    arrows(img, box, rng)
    stencil(img, box, "THIS SIDE UP", 36, (256, 300), rng)

    star(img, REGIONS["top"], (256, 230), 120, rng)
    stencil(img, REGIONS["top"], "DROP ZONE", 48, (256, 430), rng)

    # Bois de la palette : planches claires, traverses plus sombres.
    fill(img, REGIONS["plank"], (150, 112, 72), 9.0, rng)
    for y in range(REGIONS["plank"][1], REGIONS["plank"][3], 32):
        draw.line((REGIONS["plank"][0], y, REGIONS["plank"][2], y), fill=(92, 66, 40), width=2)
    fill(img, REGIONS["stringer"], (120, 88, 56), 8.0, rng)
    frame(draw, REGIONS["stringer"], 4, (80, 58, 36))

    # Sangle kaki avec coutures, boucle métallique.
    fill(img, REGIONS["strap"], (120, 110, 78), 0, rng)
    x0, y0, x1, y1 = REGIONS["strap"]
    for y in range(y0 + 6, y1, 13):
        draw.line((x0, y, x1, y), fill=(98, 90, 62), width=1)
    for x in range(x0, x1, 18):
        draw.line((x, y0 + 4, x + 8, y0 + 4), fill=(170, 160, 120), width=2)
        draw.line((x, y1 - 5, x + 8, y1 - 5), fill=(170, 160, 120), width=2)
    fill(img, REGIONS["metal"], (128, 130, 132), 0, rng)
    frame(draw, REGIONS["metal"], 10, (86, 88, 90))

    img = dirt(img, rng)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    img.convert("RGBA").save(OUT_DIR / f"{NAME}.png")
    Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255)).save(OUT_DIR / f"{NAME}_mask.png")

    atlas = {}
    for key, (x0, y0, x1, y1) in REGIONS.items():
        # UV Blender : v = 0 en bas de l'image.
        atlas[key] = [x0 / SIZE, 1 - y1 / SIZE, x1 / SIZE, 1 - y0 / SIZE]
    (HERE / "atlas.json").write_text(json.dumps(atlas, indent=2), encoding="utf-8")
    print("texture:", OUT_DIR / f"{NAME}.png")


if __name__ == "__main__":
    main()
