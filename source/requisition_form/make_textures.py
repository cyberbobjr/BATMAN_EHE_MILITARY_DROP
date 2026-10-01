"""Textures du formulaire de réquisition (fenêtre client), entièrement générées.

    python source/requisition_form/make_textures.py

Écrit dans le mod : common/media/textures/MilitaryDrop/RequisitionForm/MDReq_*.png,
lues en jeu par getTexture("media/textures/MilitaryDrop/RequisitionForm/MDReq_x.png").

Le préfixe MDReq_ est obligatoire : Texture.getSharedTextureInternal cherche
d'abord le NOM DE BASE du fichier (sans dossier ni extension) dans les packs de
textures du jeu ; un nom commun (« clip », « check »…) afficherait une image
vanilla à la place de la nôtre.

Le formulaire réutilise la tôle olive (planchette), le papier et la plaque de
bouton de la console du poste (PostConsole/MDPost_Metal, _Paper, _Button) ;
seuls s'ajoutent ici : la pince de la planchette, le grain qui use l'encre du
tampon, la boucle et la coche tracées au stylo. Contenu original, sans texte
ni marque. Tailles en puissances de deux ; boucle et coche en blanc (teintées
à l'encre bleue en jeu).
"""

import importlib.util
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent

# Outils de la console du poste (même nom de fichier : chargés par leur chemin).
_spec = importlib.util.spec_from_file_location("post_console_textures",
                                               HERE.parent / "post_console" / "make_textures.py")
_post = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_post)
radial, seamless_noise, shape, to_rgba = _post.radial, _post.seamless_noise, _post.shape, _post.to_rgba

OUT_DIR = (REPO / "Contents" / "mods" / "batman_MilitaryDrop" / "common" / "media" / "textures" / "MilitaryDrop"
           / "RequisitionForm")
PREFIX = "MDReq_"
SEED = 1404
SS = 4  # suréchantillonnage des traits
PAPER = (232, 224, 200)


def rng(offset=0):
    return random.Random(SEED + offset), np.random.default_rng(SEED + offset)


# ----------------------------------------------------------------------------
# Pince de planchette
# ----------------------------------------------------------------------------

def steel(size, top, bottom, offset):
    """Acier brossé horizontalement, dégradé vertical de top à bottom."""
    w, h = size
    yy = np.mgrid[0:h, 0:w][0].astype(np.float32) / max(1, h - 1)
    tone = top + (bottom - top) * yy
    _, nrng = rng(offset)
    streaks = np.repeat(nrng.normal(0, 1, (h, 1)).astype(np.float32), w, axis=1)
    streaks = np.array(Image.fromarray(((streaks - streaks.min()) / (np.ptp(streaks) or 1) * 255).astype(np.uint8))
                       .filter(ImageFilter.GaussianBlur((6, 0.4))), dtype=np.float32) / 255 - 0.5
    tone = tone + streaks * 14 + seamless_noise(size, 0.5, offset + 1) * 2
    return np.stack([tone * 0.98, tone, tone * 1.02], -1)


def clip(size=(256, 128)):
    """Pince chromée : semelle rivetée, capot bombé à lumière oblongue, ombre."""
    w, h = size
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    # Ombre portée sur la feuille.
    shadow = Image.new("L", size, 0)
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((14, 64, w - 10, h - 6), radius=12, fill=150)
    sd.rounded_rectangle((70, 20, w - 64, 82), radius=26, fill=120)
    shadow = shadow.filter(ImageFilter.GaussianBlur(4))
    shade = Image.new("RGBA", size, (6, 8, 4, 0))
    shade.putalpha(shadow)
    img.alpha_composite(shade, (3, 4))
    # Semelle : plaque large, arrondie, qui pince le papier.
    base_mask = shape(size, lambda d, s: d.rounded_rectangle((8 * s, 54 * s, (w - 8) * s, (h - 14) * s),
                                                              radius=12 * s, fill=255))
    base = to_rgba(steel(size, 214, 132, 10), base_mask)
    img.alpha_composite(base)
    rim = Image.new("RGBA", size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(rim)
    rd.rounded_rectangle((9, 55, w - 9, h - 15), radius=11, outline=(255, 255, 250, 120), width=1)
    rd.line((20, h - 15, w - 20, h - 15), fill=(30, 30, 30, 170), width=2)
    img.alpha_composite(rim.filter(ImageFilter.GaussianBlur(0.4)))
    # Rivets aux deux bouts.
    for cx in (28, w - 28):
        cy = 86
        d = radial(size, cx, cy, 7)
        body = np.clip(1 - d, 0, 1)
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        light = np.clip(((cx - xx) + (cy - yy)) / 10, -1, 1)
        tone = 150 + 80 * light
        rivet = to_rgba(np.stack([tone] * 3, -1), Image.fromarray((np.clip(body * 4, 0, 1) * 255).astype(np.uint8)))
        img.alpha_composite(rivet)
    # Capot bombé (le levier à ressort) au centre.
    hood_box = (72 * SS, 14 * SS, (w - 72) * SS, 78 * SS)
    hood_mask = shape(size, lambda d, s: d.rounded_rectangle(tuple(v * s // SS for v in hood_box),
                                                              radius=26 * s, fill=255))
    hood = steel(size, 238, 120, 20)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    bulge = np.clip(1 - ((xx - w / 2) / (w / 2 - 72)) ** 2, 0, 1)
    hood += (bulge * 18)[..., None]
    img.alpha_composite(to_rgba(hood, hood_mask))
    detail = Image.new("RGBA", size, (0, 0, 0, 0))
    dd = ImageDraw.Draw(detail)
    dd.rounded_rectangle((73, 15, w - 73, 77), radius=25, outline=(255, 255, 255, 140), width=2)
    dd.arc((73, 15, w - 73, 77), 20, 160, fill=(20, 20, 20, 120), width=3)
    # Lumière oblongue pour l'accrocher au mur.
    dd.rounded_rectangle((w / 2 - 22, 28, w / 2 + 22, 42), radius=7, fill=(28, 30, 26, 255))
    dd.rounded_rectangle((w / 2 - 22, 28, w / 2 + 22, 42), radius=7, outline=(250, 250, 245, 90), width=1)
    img.alpha_composite(detail.filter(ImageFilter.GaussianBlur(0.5)))
    return img


# ----------------------------------------------------------------------------
# Encre
# ----------------------------------------------------------------------------

def grunge(size=(128, 128)):
    """Grain du papier qui ronge l'encre du tampon (pavé raccordable, couleur papier)."""
    w, h = size
    fine = seamless_noise(size, 0.7, 40)
    blot = seamless_noise(size, 3.0, 41)
    alpha = np.clip((fine * 0.8 + blot * 0.9 - 1.1) * 260, 0, 235)
    # Rayures fines du caoutchouc usé, recopiées aux bords.
    prng, _ = rng(42)
    layer = Image.new("L", (w * 3, h * 3), 0)
    draw = ImageDraw.Draw(layer)
    for _ in range(18):
        x, y = prng.uniform(w, 2 * w), prng.uniform(h, 2 * h)
        a = prng.uniform(-0.3, 0.3)
        n = prng.uniform(6, 22)
        for dx in (-w, 0, w):
            for dy in (-h, 0, h):
                draw.line((x + dx, y + dy, x + dx + math.cos(a) * n, y + dy + math.sin(a) * n),
                          fill=prng.randint(120, 220), width=1)
    scratches = np.array(layer.crop((w, h, 2 * w, 2 * h)), dtype=np.float32)
    alpha = np.maximum(alpha, scratches)
    img = Image.new("RGBA", size, PAPER + (0,))
    img.putalpha(Image.fromarray(alpha.astype(np.uint8)))
    return img


def pen_stroke(size, points, width, offset):
    """Trait de stylo (blanc) le long de points, épaisseur variable, bords lissés."""
    w, h = size
    prng, _ = rng(offset)
    big = Image.new("L", (w * SS, h * SS), 0)
    draw = ImageDraw.Draw(big)
    for i in range(len(points) - 1):
        t = i / max(1, len(points) - 2)
        # Plus appuyé au milieu, léger aux extrémités.
        pressure = 0.55 + 0.45 * math.sin(math.pi * min(1, t * 1.15))
        r = width * pressure * (0.92 + 0.16 * prng.random()) * SS / 2
        (x0, y0), (x1, y1) = points[i], points[i + 1]
        steps = max(1, int(math.hypot(x1 - x0, y1 - y0) * SS / 2))
        for k in range(steps + 1):
            x = (x0 + (x1 - x0) * k / steps) * SS
            y = (y0 + (y1 - y0) * k / steps) * SS
            draw.ellipse((x - r, y - r, x + r, y + r), fill=235)
    mask = big.resize(size, Image.LANCZOS)
    img = Image.new("RGBA", size, (255, 255, 255, 0))
    img.putalpha(mask)
    return img


def circle(size=(128, 128)):
    """Boucle tracée au stylo autour d'une lettre : ovale irrégulier qui se chevauche."""
    w, h = size
    prng, _ = rng(50)
    cx, cy = w / 2, h / 2
    points = []
    turns = 1.12
    for i in range(160):
        t = i / 159
        a = -2.3 + t * turns * 2 * math.pi
        wobble = 1 + 0.05 * math.sin(a * 3 + 0.7) + 0.02 * prng.uniform(-1, 1)
        rx, ry = w * 0.4 * wobble, h * 0.34 * wobble * (1 + 0.06 * t)
        points.append((cx + math.cos(a) * rx, cy + math.sin(a) * ry - 2 * t))
    return pen_stroke(size, points, 7, 51)


def check(size=(64, 64)):
    """Coche au stylo : court trait descendant, long trait remontant."""
    w, h = size
    points = []
    for i in range(12):
        t = i / 11
        points.append((12 + t * 12, 32 + t * 14 + math.sin(t * math.pi) * 1.5))
    for i in range(1, 26):
        t = i / 25
        points.append((24 + t * 30, 46 - t * 36 - math.sin(t * math.pi) * 3))
    return pen_stroke(size, points, 6, 60)


TEXTURES = {
    "Clip": clip,
    "Grunge": grunge,
    "Circle": circle,
    "Check": check,
}


def is_pow2(n):
    return n > 0 and (n & (n - 1)) == 0


def build():
    """Toutes les textures : { nom de fichier : image }."""
    out = {}
    for name, make in TEXTURES.items():
        img = make()
        assert is_pow2(img.size[0]) and is_pow2(img.size[1]), f"{name} : taille non puissance de deux"
        out[f"{PREFIX}{name}.png"] = img
    return out


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for filename, img in build().items():
        path = OUT_DIR / filename
        img.save(path, optimize=True)
        print(f"{path.relative_to(REPO)} {img.size[0]}x{img.size[1]} {path.stat().st_size // 1024} Kio")


if __name__ == "__main__":
    main()
