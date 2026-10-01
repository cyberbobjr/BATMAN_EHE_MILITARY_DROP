"""Textures de la console du poste de liaison (fenêtre client), entièrement générées.

    python source/post_console/make_textures.py

Écrit dans le mod : common/media/textures/MilitaryDrop/PostConsole/MDPost_*.png,
lues en jeu par getTexture("media/textures/MilitaryDrop/PostConsole/MDPost_x.png").

Le préfixe MDPost_ est obligatoire : Texture.getSharedTextureInternal cherche
d'abord le NOM DE BASE du fichier (sans dossier ni extension) dans les packs de
textures du jeu ; un nom commun (« screen », « button »…) afficherait une
image vanilla à la place de la nôtre.

Contenu original, sans texte ni marque : tôle peinte olive, vis, verre d'écran
à phosphore, lignes de balayage, voyants (sertissage, verre, halo), galon,
écusson de tissu, plaque d'identité, papier d'ordre, ruban d'étiqueteuse,
plaques de boutons. Toutes les tailles sont des puissances de deux (le jeu
agrandit sinon l'image en mémoire et l'échantillonnage en pavage se décale).
Les éléments teintés en jeu (verre et halo des voyants, galon) sont en gris :
la couleur de dessin les multiplie.
"""

import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
OUT_DIR = (REPO / "Contents" / "mods" / "batman_MilitaryDrop" / "common" / "media" / "textures" / "MilitaryDrop"
           / "PostConsole")
PREFIX = "MDPost_"
SEED = 1993
SS = 4  # suréchantillonnage des formes (dessin à 4x puis réduction)


def rng(offset=0):
    return random.Random(SEED + offset), np.random.default_rng(SEED + offset)


def seamless_noise(size, sigma, offset):
    """Bruit flou raccordable : pavé 3x3, flou, puis découpe du centre."""
    w, h = size
    _, nrng = rng(offset)
    base = nrng.normal(0, 1, (h, w)).astype(np.float32)
    tiled = np.tile(base, (3, 3))
    lo, hi = tiled.min(), tiled.max()
    img = Image.fromarray(((tiled - lo) / (hi - lo) * 255).astype(np.uint8))
    img = img.filter(ImageFilter.GaussianBlur(sigma))
    arr = np.array(img, dtype=np.float32)[h:2 * h, w:2 * w]
    arr -= arr.mean()
    std = arr.std() or 1
    return arr / std


def to_rgba(arr, alpha=None):
    rgb = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    if alpha is not None:
        rgb.putalpha(alpha)
    return rgb


def shape(size, draw_fn):
    """Masque L dessiné à SS fois la taille puis réduit (bords lissés)."""
    w, h = size
    big = Image.new("L", (w * SS, h * SS), 0)
    draw_fn(ImageDraw.Draw(big), SS)
    return big.resize(size, Image.LANCZOS)


def radial(size, cx, cy, r):
    h, w = size[1], size[0]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    return np.hypot(xx + 0.5 - cx, yy + 0.5 - cy) / r


# ----------------------------------------------------------------------------
# Façade et écran
# ----------------------------------------------------------------------------

def metal_olive(size=(256, 256)):
    """Tôle peinte vert olive mat, raccordable : peau d'orange, grain, éraflures."""
    w, h = size
    base = np.ones((h, w, 3), dtype=np.float32) * np.array((86, 90, 60), dtype=np.float32)
    orange = seamless_noise(size, 2.2, 1)
    fine = seamless_noise(size, 0.6, 2)
    blotch = seamless_noise(size, 18, 3)
    base += (orange * 3.0 + fine * 2.2 + blotch * 4.0)[..., None]
    img = to_rgba(base)
    # Éraflures claires et petites piqûres, recopiées aux bords pour raccorder.
    prng, _ = rng(4)
    layer = Image.new("RGBA", (w * 3, h * 3), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for _ in range(26):
        x, y = prng.uniform(w, 2 * w), prng.uniform(h, 2 * h)
        a = prng.uniform(-0.5, 0.5) + (math.pi / 2 if prng.random() < 0.3 else 0)
        n = prng.uniform(6, 26)
        color = (200, 196, 160, prng.randint(14, 34))
        for dx in (-w, 0, w):
            for dy in (-h, 0, h):
                draw.line((x + dx, y + dy, x + dx + math.cos(a) * n, y + dy + math.sin(a) * n), fill=color, width=1)
    for _ in range(40):
        x, y = prng.uniform(w, 2 * w), prng.uniform(h, 2 * h)
        r = prng.uniform(0.6, 1.4)
        for dx in (-w, 0, w):
            for dy in (-h, 0, h):
                draw.ellipse((x + dx - r, y + dy - r, x + dx + r, y + dy + r), fill=(40, 42, 26, 60))
    layer = layer.crop((w, h, 2 * w, 2 * h)).filter(ImageFilter.GaussianBlur(0.35))
    img.alpha_composite(layer)
    return img


def screw(size=(64, 64)):
    """Vis à tête bombée fendue, acier un peu terni, ombre portée."""
    w, h = size
    c = w / 2
    d = radial(size, c, c - 1, w * 0.36)
    body = np.clip(1 - d, 0, 1)
    # Éclairage venant du haut à gauche.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    light = 0.55 + 0.45 * np.clip(((c - xx) + (c - yy)) / (w * 0.5), -1, 1)
    tone = 110 + 95 * light * (0.6 + 0.4 * body)
    rgb = np.stack([tone * 0.97, tone * 0.98, tone * 0.92], -1)
    head = shape(size, lambda dr, s: dr.ellipse((c * s - w * 0.36 * s, (c - 1) * s - w * 0.36 * s,
                                                  c * s + w * 0.36 * s, (c - 1) * s + w * 0.36 * s), fill=255))
    img = to_rgba(rgb, head)
    # Fente en diagonale, sombre avec un liseré clair.
    slot = Image.new("RGBA", size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(slot)
    a = math.radians(-35)
    dx, dy = math.cos(a) * w * 0.27, math.sin(a) * w * 0.27
    sd.line((c - dx + 1, c - 1 - dy + 1, c + dx + 1, c - 1 + dy + 1), fill=(235, 235, 220, 120), width=4)
    sd.line((c - dx, c - 1 - dy, c + dx, c - 1 + dy), fill=(30, 30, 26, 235), width=5)
    slot = slot.filter(ImageFilter.GaussianBlur(0.5))
    img.alpha_composite(slot)
    img.putalpha(head)
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((c - w * 0.37 + 2, c - w * 0.37 + 3, c + w * 0.37 + 2, c + w * 0.37 + 3),
                                   fill=(10, 12, 6, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(2.5))
    shadow.alpha_composite(img)
    return shadow


def screen(size=(512, 256)):
    """Verre d'écran à phosphore vert, éteint : lueur centrale, coins sombres, reflet."""
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    nx, ny = (xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2)
    d = np.sqrt(nx ** 2 * 0.85 + ny ** 2)
    glow = np.clip(1 - d * 0.75, 0, 1) ** 1.6
    corner = np.clip(np.maximum(np.abs(nx), np.abs(ny)) - 0.82, 0, 1) / 0.18
    base = np.stack([6 + 12 * glow, 18 + 34 * glow, 10 + 18 * glow], -1)
    base *= (1 - 0.55 * corner ** 2)[..., None]
    base += (seamless_noise(size, 0.7, 20) * 1.2)[..., None]
    img = to_rgba(base)
    # Reflet du verre bombé : bande douce en haut à gauche.
    refl = Image.new("L", size, 0)
    ImageDraw.Draw(refl).ellipse((-w * 0.25, -h * 0.9, w * 0.75, h * 0.42), fill=255)
    refl = refl.filter(ImageFilter.GaussianBlur(h * 0.12))
    sheen = Image.new("RGBA", size, (210, 255, 220, 0))
    sheen.putalpha(refl.point(lambda v: int(v * 0.07)))
    img.alpha_composite(sheen)
    return img


def scanlines(size=(256, 32)):
    """Lignes de balayage (pavé natif, une ligne sombre sur trois)."""
    w, h = size
    alpha = np.zeros((h, w), dtype=np.uint8)
    for y in range(h):
        if y % 3 == 2:
            alpha[y, :] = 70
        elif y % 3 == 0:
            alpha[y, :] = 18
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    img.putalpha(Image.fromarray(alpha))
    return img


# ----------------------------------------------------------------------------
# Voyants
# ----------------------------------------------------------------------------

def lamp_bezel(size=(64, 64)):
    """Sertissage chromé d'un voyant (anneau), centre vide."""
    w, h = size
    c = w / 2
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ang = np.arctan2(yy - c, xx - c)
    tone = 150 + 80 * np.cos(ang + math.radians(135))
    rgb = np.stack([tone, tone, tone * 0.96], -1)
    ring = shape(size, lambda dr, s: (dr.ellipse((2 * s, 2 * s, (w - 2) * s, (h - 2) * s), fill=255),
                                      dr.ellipse((11 * s, 11 * s, (w - 11) * s, (h - 11) * s), fill=0)))
    img = to_rgba(rgb, ring)
    # Arête sombre intérieure.
    edge = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(edge).ellipse((10, 10, w - 10, h - 10), outline=(20, 20, 18, 200), width=2)
    img.alpha_composite(edge)
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((3, 5, w - 1, h - 1), fill=(8, 10, 4, 140))
    shadow = shadow.filter(ImageFilter.GaussianBlur(2))
    shadow.alpha_composite(img)
    # Centre transparent : le verre du voyant, dessiné dessous, reste visible.
    hole = np.array(shape(size, lambda dr, s: dr.ellipse((11 * s, 11 * s, (w - 11) * s, (h - 11) * s), fill=255)),
                    dtype=np.float32) / 255
    alpha = np.array(shadow.getchannel("A"), dtype=np.float32) * (1 - hole)
    shadow.putalpha(Image.fromarray(alpha.astype(np.uint8)))
    return shadow


def lamp_glass(size=(64, 64)):
    """Verre bombé d'un voyant, en gris (teinté en jeu), reflet blanc."""
    w, h = size
    c = w / 2
    d = radial(size, c, c, w / 2 - 10)
    tone = np.clip(1 - d * 0.55, 0, 1) * 200 + 40
    facets = seamless_noise(size, 1.2, 30) * 6
    rgb = np.stack([tone + facets] * 3, -1)
    mask = shape(size, lambda dr, s: dr.ellipse((10 * s, 10 * s, (w - 10) * s, (h - 10) * s), fill=255))
    img = to_rgba(rgb, mask)
    spec = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(spec).ellipse((c - 13, c - 14, c - 3, c - 6), fill=(255, 255, 255, 210))
    spec = spec.filter(ImageFilter.GaussianBlur(1.6))
    img.alpha_composite(spec)
    img.putalpha(mask)
    return img


def lamp_glow(size=(128, 128)):
    """Halo d'un voyant allumé (blanc, teinté et dosé en jeu)."""
    d = radial(size, size[0] / 2, size[1] / 2, size[0] / 2)
    alpha = (np.clip(1 - d, 0, 1) ** 2.4 * 255).astype(np.uint8)
    img = Image.new("RGBA", size, (255, 255, 255, 0))
    img.putalpha(Image.fromarray(alpha))
    return img


# ----------------------------------------------------------------------------
# Confiance : écusson et galon
# ----------------------------------------------------------------------------

def brushed(size, color, strength, offset):
    """Métal brossé raccordable : stries horizontales fines sur un grain léger.

    Reconstruite le 2026-10-01 (la version d'origine a été perdue) : les PNG
    MDPost_Button et MDPost_DogTag livrés viennent de l'originale ; les
    régénérer change légèrement leur grain."""
    w, h = size
    _, nrng = rng(offset)
    rows = nrng.normal(0, 1, (h, 1)).astype(np.float32)
    streaks = np.tile(rows, (1, w)) + nrng.normal(0, 0.35, (h, w)).astype(np.float32)
    # Stries étirées dans le sens du brossage (flou horizontal raccordable).
    tiled = np.tile(streaks, (1, 3))
    kernel = np.ones(15, dtype=np.float32) / 15
    blurred = np.apply_along_axis(lambda r: np.convolve(r, kernel, mode="same"), 1, tiled)[:, w:2 * w]
    blurred /= blurred.std() or 1
    base = np.ones((h, w, 3), dtype=np.float32) * np.array(color, dtype=np.float32)
    base += (blurred * strength + seamless_noise(size, 2.0, offset + 1) * strength * 0.3)[..., None]
    return base


def weave(size, color, strength, offset):
    """Toile tissée : trame et chaîne, raccordable."""
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    pattern = (np.sin(xx * math.pi / 2) * np.sin(yy * math.pi / 2)) * strength
    base = np.ones((h, w, 3), dtype=np.float32) * np.array(color, dtype=np.float32)
    base += (pattern + seamless_noise(size, 1.0, offset) * strength * 0.6)[..., None]
    return base






def dogtag(size=(256, 64)):
    """Plaque d'identité en acier : bords roulés, trou, encoche, rebord embouti."""
    w, h = size

    def outline(dr, s, inset=0):
        dr.rounded_rectangle(((2 + inset) * s, (4 + inset) * s, (w - 2 - inset) * s, (h - 4 - inset) * s),
                             radius=(h / 2 - 4 - inset) * s, fill=255)

    mask = np.array(shape(size, outline), dtype=np.float32)
    hole = np.array(shape(size, lambda dr, s: dr.ellipse((14 * s, (h / 2 - 6) * s, 26 * s, (h / 2 + 6) * s),
                                                          fill=255)), dtype=np.float32)
    notch = np.array(shape(size, lambda dr, s: dr.ellipse(((w - 12) * s, (h / 2 - 7) * s, (w + 2) * s,
                                                           (h / 2 + 7) * s), fill=255)), dtype=np.float32)
    alpha = np.clip(mask - hole - notch, 0, 255)
    yy = np.mgrid[0:h, 0:w][0].astype(np.float32)
    rgb = brushed(size, (176, 180, 182), 7, 60)
    rgb += ((h / 2 - yy) / (h / 2) * 22)[..., None]
    img = to_rgba(rgb, Image.fromarray(alpha.astype(np.uint8)))
    # Rebord embouti : liseré clair en haut, sombre en bas.
    rim = Image.new("RGBA", size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(rim)
    rd.rounded_rectangle((9, 10, w - 9, h - 10), radius=h / 2 - 10, outline=(90, 94, 96, 170), width=2)
    rd.rounded_rectangle((10, 12, w - 8, h - 8), radius=h / 2 - 10, outline=(240, 244, 246, 110), width=1)
    img.alpha_composite(rim.filter(ImageFilter.GaussianBlur(0.5)))
    img.putalpha(Image.fromarray(alpha.astype(np.uint8)))
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    sh = Image.new("RGBA", size, (4, 6, 2, 0))
    sh.putalpha(Image.fromarray((alpha * 0.55).astype(np.uint8)))
    shadow.alpha_composite(sh, (2, 3))
    shadow = shadow.filter(ImageFilter.GaussianBlur(1.5))
    shadow.alpha_composite(img)
    return shadow


def paper(size=(256, 256)):
    """Papier d'ordre de mission, raccordable : crème, grain, fibres."""
    w, h = size
    base = np.ones((h, w, 3), dtype=np.float32) * np.array((232, 224, 200), dtype=np.float32)
    base += (seamless_noise(size, 0.6, 70) * 3 + seamless_noise(size, 10, 71) * 5)[..., None]
    img = to_rgba(base)
    prng, _ = rng(72)
    layer = Image.new("RGBA", (w * 3, h * 3), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for _ in range(140):
        x, y = prng.uniform(w, 2 * w), prng.uniform(h, 2 * h)
        a = prng.uniform(0, math.pi)
        n = prng.uniform(3, 9)
        color = (140, 120, 88, prng.randint(10, 26))
        for dx in (-w, 0, w):
            for dy in (-h, 0, h):
                draw.line((x + dx, y + dy, x + dx + math.cos(a) * n, y + dy + math.sin(a) * n), fill=color)
    img.alpha_composite(layer.crop((w, h, 2 * w, 2 * h)).filter(ImageFilter.GaussianBlur(0.4)))
    return img


def tape(size=(256, 64)):
    """Ruban d'étiqueteuse en relief, noir brillant (le texte est dessiné en jeu)."""
    w, h = size
    yy = np.mgrid[0:h, 0:w][0].astype(np.float32)
    t = yy / h
    tone = 22 + 26 * np.exp(-((t - 0.22) / 0.12) ** 2) - 10 * t
    rgb = np.stack([tone, tone, tone * 1.05], -1) + (seamless_noise(size, 0.8, 80) * 2)[..., None]
    img = to_rgba(rgb)
    edge = Image.new("RGBA", size, (0, 0, 0, 0))
    ed = ImageDraw.Draw(edge)
    ed.line((0, 1, w, 1), fill=(120, 120, 124, 120))
    ed.line((0, h - 2, w, h - 2), fill=(0, 0, 0, 180), width=2)
    img.alpha_composite(edge)
    return img


def button_plate(size=(256, 64)):
    """Plaque de bouton en aluminium brossé, légèrement bombée."""
    w, h = size
    yy = np.mgrid[0:h, 0:w][0].astype(np.float32)
    rgb = brushed(size, (150, 152, 146), 8, 90)
    rgb += ((0.5 - yy / h) * 40)[..., None]
    return to_rgba(rgb)


def button_rubber(size=(256, 64)):
    """Bouton d'émission en caoutchouc sombre, mat, bombé."""
    w, h = size
    yy = np.mgrid[0:h, 0:w][0].astype(np.float32)
    tone = 46 + (0.5 - yy / h) * 22
    rgb = np.stack([tone, tone * 0.98, tone * 0.92], -1) + (seamless_noise(size, 0.6, 95) * 3)[..., None]
    return to_rgba(rgb)


TEXTURES = {
    "Metal": metal_olive,
    "Screw": screw,
    "Screen": screen,
    "Scanlines": scanlines,
    "LampBezel": lamp_bezel,
    "LampGlass": lamp_glass,
    "LampGlow": lamp_glow,
    "DogTag": dogtag,
    "Paper": paper,
    "Tape": tape,
    "Button": button_plate,
    "ButtonRubber": button_rubber,
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
