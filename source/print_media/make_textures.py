"""Textures des documents militaires (rendu printMedia du jeu), entièrement générées.

    python source/print_media/make_textures.py

Écrit dans le mod : common/media/textures/printMedia/MilitaryDrop/*.png.
Contenu original : papier, chemise kraft, étiquette,
trombone, tampon SECRET, insigne fictif, trait de stylo et tache de café. Les
polices de Windows (Stencil, Arial Bold) ne servent qu'à rendre des images ;
aucun fichier de police n'est distribué. Le mot « SECRET » est le même en
anglais et en français : c'est le seul texte figé dans une image.

Les textures sont produites au double de leur taille d'affichage, pour rester
nettes quand le joueur zoome dans la fenêtre du document.
"""

import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
OUT_DIR = REPO / "Contents" / "mods" / "batman_MilitaryDrop" / "common" / "media" / "textures" / "printMedia" / "MilitaryDrop"
SEED = 1993

FONT_STENCIL = r"C:\Windows\Fonts\STENCIL.TTF"
FONT_BOLD = r"C:\Windows\Fonts\arialbd.ttf"

INK_RED = (168, 30, 36)
INK_NAVY = (34, 40, 62)
INK_BLUE = (28, 52, 140)


def rng(offset=0):
    return random.Random(SEED + offset), np.random.default_rng(SEED + offset)


def grain(size, strength, offset=0):
    """Bruit de fibres : valeurs centrées sur 0, amplitude strength."""
    _, nrng = rng(offset)
    w, h = size
    fine = nrng.normal(0, 1, (h, w))
    coarse = np.array(Image.fromarray(nrng.normal(128, 40, (h // 8 + 1, w // 8 + 1)).clip(0, 255).astype(np.uint8))
                      .resize((w, h), Image.BICUBIC), dtype=np.float32) - 128
    return (fine * 0.6 + coarse / 40 * 0.4) * strength


def tint(size, color, strength, offset=0, vignette=0.0):
    """Surface unie + grain + assombrissement des bords."""
    w, h = size
    base = np.ones((h, w, 3), dtype=np.float32) * np.array(color, dtype=np.float32)
    base += grain(size, strength, offset)[..., None]
    if vignette:
        yy, xx = np.mgrid[0:h, 0:w]
        dx = np.abs(xx - w / 2) / (w / 2)
        dy = np.abs(yy - h / 2) / (h / 2)
        edge = np.clip(np.maximum(dx, dy) - 0.75, 0, 1) / 0.25
        base *= (1 - vignette * edge ** 2)[..., None]
    return base


def to_image(arr, alpha=None):
    rgb = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGB")
    if alpha is None:
        return rgb.convert("RGBA")
    rgb.putalpha(alpha)
    return rgb


def rounded_alpha(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def fibers(img, count, color, offset, length=(4, 12), width=1, alpha=(8, 22)):
    """Fibres discrètes, fondues sur l'image (calque composé, pas remplacé)."""
    prng, _ = rng(offset)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    w, h = img.size
    for _ in range(count):
        x, y = prng.uniform(0, w), prng.uniform(0, h)
        a = prng.uniform(0, math.pi)
        n = prng.uniform(*length)
        draw.line((x, y, x + math.cos(a) * n, y + math.sin(a) * n), fill=color + (prng.randint(*alpha),), width=width)
    mask = img.getchannel("A")
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.5)))
    img.putalpha(mask)


def distress(img, keep, offset, blur=0.6):
    """Encre usée : retire des points au hasard dans l'alpha."""
    _, nrng = rng(offset)
    a = np.array(img.getchannel("A"), dtype=np.float32)
    noise = np.array(Image.fromarray(nrng.normal(128, 60, (a.shape[0] // 3 + 1, a.shape[1] // 3 + 1))
                                     .clip(0, 255).astype(np.uint8)).resize((a.shape[1], a.shape[0]), Image.BICUBIC),
                     dtype=np.float32)
    speck = nrng.random(a.shape)
    a *= (noise > (255 * (1 - keep))) * 1.0
    a *= (speck > 0.06)
    a *= 0.88
    out = img.copy()
    out.putalpha(Image.fromarray(a.clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur)))
    return out


# ----------------------------------------------------------------------------
# Supports
# ----------------------------------------------------------------------------

def paper(size=(920, 1296)):
    """Feuille dactylographiée : crème, grain, deux plis, bords un peu jaunis."""
    w, h = size
    arr = tint(size, (240, 234, 218), 5, 1, vignette=0.10)
    yy = np.mgrid[0:h, 0:w][0]
    for fold in (h / 3, 2 * h / 3):
        d = (yy - fold) / 3.0
        arr += (-7 * np.exp(-d ** 2) + 4 * np.exp(-((yy - fold - 5) / 4.0) ** 2))[..., None]
    img = to_image(arr, rounded_alpha(size, 6))
    fibers(img, 260, (150, 128, 96), 2)
    return img


def kraft(size=(1560, 1080)):
    """Chemise cartonnée ouverte : kraft, fibres, pli central, coins arrondis."""
    w, h = size
    arr = tint(size, (182, 142, 96), 9, 3, vignette=0.22)
    xx = np.mgrid[0:h, 0:w][1]
    d = (xx - w / 2) / 8.0
    arr += (-24 * np.exp(-d ** 2) + 9 * np.exp(-((xx - w / 2 - 12) / 8.0) ** 2))[..., None]
    img = to_image(arr, rounded_alpha(size, 28))
    fibers(img, 1600, (110, 76, 42), 4, length=(5, 16), alpha=(10, 26))
    # Rabat du bas du volet gauche : bande un peu plus claire, bord marqué.
    flap = Image.new("RGBA", size, (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(flap)
    fdraw.rectangle((30, h - 230, w / 2 - 30, h - 30), fill=(255, 238, 205, 26))
    fdraw.line((30, h - 230, w / 2 - 30, h - 230), fill=(90, 60, 30, 110), width=3)
    mask = img.getchannel("A")
    img.alpha_composite(flap)
    img.putalpha(mask)
    return img


def label(size=(720, 400)):
    """Étiquette collée sur la chemise : blanc cassé, double filet."""
    w, h = size
    img = to_image(tint(size, (244, 240, 228), 4, 8), rounded_alpha(size, 14))
    draw = ImageDraw.Draw(img, "RGBA")
    draw.rounded_rectangle((18, 18, w - 19, h - 19), radius=8, outline=INK_NAVY + (230,), width=5)
    draw.rounded_rectangle((32, 32, w - 33, h - 33), radius=6, outline=INK_NAVY + (200,), width=2)
    draw.rectangle((32, 32, w - 33, 108), fill=INK_RED + (225,))
    return img


# ----------------------------------------------------------------------------
# Accessoires
# ----------------------------------------------------------------------------

def paperclip(size=(120, 300)):
    w, h = size
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))

    def wire(draw, color, width, dx=0, dy=0):
        # Trois boucles imbriquées d'un trombone, ouvertes.
        draw.rounded_rectangle((18 + dx, 14 + dy, w - 18 + dx, h - 22 + dy), radius=42, outline=color, width=width)
        draw.rounded_rectangle((34 + dx, 56 + dy, w - 34 + dx, h - 48 + dy), radius=28, outline=color, width=width)
        draw.rectangle((w - 40 + dx, 56 + dy, w - 20 + dx, 120 + dy), fill=(0, 0, 0, 0))

    wire(ImageDraw.Draw(shadow), (0, 0, 0, 90), 9, 5, 6)
    shadow = shadow.filter(ImageFilter.GaussianBlur(3))
    img.alpha_composite(shadow)
    wire(ImageDraw.Draw(img), (138, 144, 152, 255), 9)
    wire(ImageDraw.Draw(img), (226, 230, 236, 200), 3, -2, -2)
    return img


def stamp(text="SECRET", size=(960, 320)):
    """Tampon encreur rouge : double cadre, lettres au pochoir, encre usée."""
    w, h = size
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((10, 10, w - 11, h - 11), radius=18, outline=INK_RED + (255,), width=16)
    draw.rounded_rectangle((38, 38, w - 39, h - 39), radius=10, outline=INK_RED + (255,), width=6)
    font = ImageFont.truetype(FONT_STENCIL, 190)
    box = draw.textbbox((0, 0), text, font=font)
    tw, th = box[2] - box[0], box[3] - box[1]
    draw.text(((w - tw) / 2 - box[0], (h - th) / 2 - box[1]), text, font=font, fill=INK_RED + (255,))
    return distress(img, 0.82, 9)


def seal(size=(440, 440)):
    """Insigne fictif « Military Logistics — Knox Zone » à l'encre bleu nuit."""
    w, h = size
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    c = w / 2
    ink = INK_NAVY + (255,)
    draw.ellipse((6, 6, w - 7, h - 7), outline=ink, width=12)
    draw.ellipse((78, 78, w - 79, h - 79), outline=ink, width=5)
    # Étoile à cinq branches.
    r1, r2 = 100, 40
    pts = []
    for i in range(10):
        r = r1 if i % 2 == 0 else r2
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((c + math.cos(a) * r, c + 8 + math.sin(a) * r))
    draw.polygon(pts, fill=ink)
    font = ImageFont.truetype(FONT_BOLD, 34)

    def arc_text(text, radius, start_deg, step_deg, flip):
        angle = start_deg
        for ch in text:
            glyph = Image.new("RGBA", (60, 60), (0, 0, 0, 0))
            ImageDraw.Draw(glyph).text((30, 30), ch, font=font, fill=ink, anchor="mm")
            rot = -(angle + 90) if not flip else -(angle - 90)
            glyph = glyph.rotate(rot, resample=Image.BICUBIC)
            x = c + math.cos(math.radians(angle)) * radius
            y = c + math.sin(math.radians(angle)) * radius
            img.alpha_composite(glyph, (int(x - 30), int(y - 30)))
            angle += step_deg

    top = "MILITARY LOGISTICS"
    arc_text(top, 172, -90 - (len(top) - 1) * 8.6 / 2, 8.6, False)
    bottom = "KNOX ZONE"
    arc_text(bottom, 172, 90 + (len(bottom) - 1) * 10 / 2, -10, True)
    for a in (0, 180):
        x = c + math.cos(math.radians(a)) * 172
        y = c + math.sin(math.radians(a)) * 172
        draw.ellipse((x - 8, y - 8, x + 8, y + 8), fill=ink)
    return distress(img, 0.93, 10, blur=0.4)


def pen_circle(size=(560, 240)):
    """Ellipse tracée au stylo bleu, un peu plus d'un tour, trait irrégulier."""
    w, h = size
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    prng, _ = rng(11)
    cx, cy, rx, ry = w / 2, h / 2, w / 2 - 20, h / 2 - 18
    steps = 260
    prev = None
    for i in range(steps + 1):
        t = i / steps * 2.15 * math.pi + 0.3
        wobble = 1 + 0.035 * math.sin(t * 3.1) + 0.02 * math.sin(t * 7.3)
        drift = i / steps * 10
        x = cx + math.cos(t) * rx * wobble
        y = cy + math.sin(t) * (ry - drift) * wobble
        if prev:
            width = int(5 + 2 * math.sin(t * 1.7) + prng.uniform(0, 1))
            draw.line((prev[0], prev[1], x, y), fill=INK_BLUE + (230,), width=width)
        prev = (x, y)
    return img.filter(ImageFilter.GaussianBlur(0.6))


def coffee_ring(size=(600, 600)):
    """Tache de café : anneau irrégulier, fond à peine teinté."""
    w, h = size
    _, nrng = rng(12)
    yy, xx = np.mgrid[0:h, 0:w]
    ang = np.arctan2(yy - h / 2, xx - w / 2)
    radius = 230 + 10 * np.sin(ang * 3 + 0.5) + 6 * np.sin(ang * 7)
    dist = np.hypot(xx - w / 2, yy - h / 2)
    ring = np.exp(-((dist - radius) / 9.0) ** 2) * (0.55 + 0.35 * np.sin(ang * 2 + 1) ** 2)
    fill = (dist < radius) * 0.10
    alpha = (ring + fill) * 255 * (0.85 + 0.15 * nrng.random((h, w)))
    rgb = np.zeros((h, w, 3), dtype=np.float32) + np.array((120, 78, 40), dtype=np.float32)
    img = to_image(rgb, Image.fromarray(alpha.clip(0, 200).astype(np.uint8)))
    return img.filter(ImageFilter.GaussianBlur(1.2))


TEXTURES = {
    "paper": paper,
    "kraft": kraft,
    "label": label,
    "paperclip": paperclip,
    "stamp_secret": stamp,
    "seal": seal,
    "pen_circle": pen_circle,
    "coffee": coffee_ring,
}


PALETTE = {"paper", "kraft", "label"}


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, make in TEXTURES.items():
        img = make()
        path = OUT_DIR / f"{name}.png"
        if name in PALETTE:
            # 256 couleurs suffisent au grain et divisent le poids par 3 ou 4.
            img = img.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.FLOYDSTEINBERG)
        img.save(path, optimize=True)
        print(f"{path.relative_to(REPO)} {img.size[0]}x{img.size[1]} {path.stat().st_size // 1024} Kio")


if __name__ == "__main__":
    main()
