"""Aperçu hors jeu des documents du mod (rendu printMedia simulé).

    python source/print_media/preview.py [EN|FR] [dossier_de_sortie]

Fabrique la note (mode chiffré) et le carnet de codes avec le vrai Lua du mod (lupa) et les vraies traductions, puis les dessine
comme la fenêtre des journaux du jeu : textures du mod, polices SDF du jeu
(fichiers AngelCode .fnt et atlas de champ de distance, métriques exactes).

Approximations : pas de justification des lignes coupées par autoWidth, pas de
crénage, rotation autour du coin haut gauche comme dans le jeu. Les couleurs
de texture multiplient l'image, comme dans le jeu. À confirmer en jeu.
"""

import json
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(REPO / "tests"))
import lua_harness  # noqa: E402

MOD = REPO / "Contents" / "mods" / "batman_MilitaryDrop"
TRANSLATE = MOD / "42.21" / "media" / "lua" / "shared" / "Translate"
PZ_FONTS = lua_harness.PZ_MEDIA / "fonts"
FONT_FILES = {
    "SdfOldRegular": "SdfOldRegular.fnt", "SdfOldBold": "SdfOldBold.fnt", "SdfOldItalic": "SdfOldItalic.fnt",
    "SdfOldBoldItalic": "SdfOldBoldItalic.fnt", "SdfCaveat": "sdfCaveat.fnt", "SdfRegular": "sdfRegular.fnt",
    "SdfBold": "sdfBold.fnt", "SdfRobertoSans": "sdfRobertoSans.fnt",
}


# ----------------------------------------------------------------------------
# Documents produits par le Lua du mod
# ----------------------------------------------------------------------------

SETUP = r"""
SandboxVars = { MilitaryDrop = { AuthCode = 4 } }
isClient = function() return false end
isServer = function() return false end
ModData = { getOrCreate = function() return {} end }
FILES = { ["MilitaryDrop/Sandbox_Preview_seed.txt"] = "1650289923" }
getWorld = function()
    return { getGameMode = function() return "Sandbox" end, getWorld = function() return "Preview" end }
end
getFileReader = function(name)
    local value = FILES[name]
    if not value then return nil end
    return { readLine = function() return value end, close = function() end }
end
getFileWriter = function() return { write = function() end, close = function() end } end
local n = 0
ZombRand = function(a, b) n = n + 1 if b then return a + 417 end return n % a end
getGameTime = function()
    return {
        getYear = function() return 1993 end, getMonth = function() return 6 end,
        getDay = function() return 13 end, getTimeOfDay = function() return 12.5 end,
    }
end
instanceItem = function(fullType)
    local item = { fullType = fullType, modData = {} }
    function item.getModData(self) return self.modData end
    return item
end
loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
loadMod("shared/MilitaryDrop/MilitaryDrop_Loot.lua")
VehicleDistributions = { {} }
loadMod("server/MilitaryDrop/MilitaryDrop_Crate.lua")
loadMod("server/MilitaryDrop/MilitaryDrop_Secrets.lua")
loadMod("server/MilitaryDrop/MilitaryDrop_Server.lua")
loadMod("server/MilitaryDrop/MilitaryDrop_NumbersStation.lua")
loadMod("shared/MilitaryDrop/MilitaryDrop_PrintMedia.lua")
loadMod("server/MilitaryDrop/MilitaryDrop_Documents.lua")
loadMod("server/MilitaryDrop/MilitaryDrop_Notes.lua")
MilitaryDrop.NumbersStation.frequency = 20000
"""


def documents(language):
    table = {}
    for path in (TRANSLATE / language).glob("*.json"):
        table.update(json.loads(path.read_text(encoding="utf-8")))

    def get_text(key, *args):
        text = table.get(key, key)
        for i, arg in enumerate(args, 1):
            text = text.replace(f"%{i}", str(arg))
        return text

    lua = lua_harness.new_runtime()
    lua.globals().getText = get_text
    lua.execute(SETUP)
    docs = lua.execute(r"""
        local memo = instanceItem("MilitaryDrop.MilitaryMemo")
        MilitaryDrop.Notes.fillMemo(memo, 3)
        local book = instanceItem("MilitaryDrop.Codebook")
        MilitaryDrop.Notes.fillCodebook(book)
        return memo.modData.printMedia, book.modData.printMedia
    """)
    return {name: dict(doc) for name, doc in zip(("memo", "codebook"), docs)}


# ----------------------------------------------------------------------------
# Rendu
# ----------------------------------------------------------------------------

class Font:
    def __init__(self, fnt):
        self.chars = {}
        self.pages = {}
        for line in (PZ_FONTS / fnt).read_text(encoding="utf-8").splitlines():
            kind, _, rest = line.partition(" ")
            values = dict(re.findall(r'(\w+)=("[^"]*"|\S+)', rest))
            if kind == "common":
                self.line_height = int(values["lineHeight"])
            elif kind == "page":
                # Atlas en palette : la distance est dans la transparence.
                sdf = Image.open(PZ_FONTS / values["file"].strip('"')).convert("RGBA")
                self.pages[int(values["id"])] = np.array(sdf.getchannel("A"), dtype=np.float32) / 255
            elif kind == "char":
                self.chars[int(values["id"])] = {k: int(v) for k, v in values.items()}

    def width(self, text):
        return sum(self.chars.get(ord(c), self.chars.get(32))["xadvance"] for c in text)

    def lines(self, text, auto_width):
        lines = []
        for paragraph in text.split("\n"):
            if auto_width is None:
                lines.append(paragraph)
                continue
            current = ""
            for word in paragraph.split(" "):
                candidate = (current + " " + word).strip()
                if current and self.width(candidate) > auto_width:
                    lines.append(current)
                    current = word
                else:
                    current = candidate
            lines.append(current)
        return lines

    def render(self, text, color, auto_width=None, leading=0):
        lines = self.lines(text, auto_width)
        width = max([self.width(line) for line in lines] + [1]) + 16
        height = len(lines) * (self.line_height + leading) + 32
        alpha = np.zeros((height, width), dtype=np.float32)
        for row, line in enumerate(lines):
            # Marge de 4 px : les glyphes ont des décalages négatifs.
            x, y0 = 4, 14 + row * (self.line_height + leading)
            for ch in line:
                c = self.chars.get(ord(ch)) or self.chars.get(32)
                page = self.pages[c["page"]]
                glyph = page[c["y"]:c["y"] + c["height"], c["x"]:c["x"] + c["width"]]
                gx, gy = x + c["xoffset"], y0 + c["yoffset"]
                h = min(glyph.shape[0], height - gy)
                w = min(glyph.shape[1], width - gx)
                if h > 0 and w > 0 and gx >= 0 and gy >= 0:
                    edge = np.clip((glyph[:h, :w] - 0.38) / 0.08, 0, 1)
                    alpha[gy:gy + h, gx:gx + w] = np.maximum(alpha[gy:gy + h, gx:gx + w], edge)
                x += c["xadvance"]
        rgba = np.zeros((height, width, 4), dtype=np.uint8)
        rgba[..., :3] = [int(v * 255) for v in color[:3]]
        rgba[..., 3] = (alpha * color[3] * 255).astype(np.uint8)
        return Image.fromarray(rgba, "RGBA")


FONTS = {}


def font(name):
    if name not in FONTS:
        FONTS[name] = Font(FONT_FILES[name])
    return FONTS[name]


def parse(info):
    for chunk in info.split("<"):
        if not chunk:
            continue
        head, _, content = chunk.partition(">")
        params = {}
        for pair in head.split(","):
            key, _, value = pair.partition(":")
            params[key.strip()] = value.strip()
        yield params, content.replace("^", "\n")


def num(params, key, default=0.0):
    return float(params.get(key, default))


def place(canvas, layer, x, y, angle):
    """Colle layer en (x, y), tourné de angle degrés (sens horaire) autour de ce point."""
    full = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    full.alpha_composite(layer, (int(round(x)), int(round(y))))
    if angle:
        full = full.rotate(-angle, resample=Image.BICUBIC, center=(x, y))
    canvas.alpha_composite(full)


def render(doc):
    elements = list(parse(doc["info"]))
    parent = elements[0][0]
    canvas = Image.new("RGBA", (int(num(parent, "width")), int(num(parent, "height"))), (46, 46, 46, 255))
    for params, content in elements[1:]:
        color = (num(params, "r", 1), num(params, "g", 1), num(params, "b", 1), num(params, "a", 1))
        x, y, angle = num(params, "x"), num(params, "y"), num(params, "angle")
        if params["type"] == "texture":
            w, h = int(num(params, "width")), int(num(params, "height"))
            if "texture" in params:
                layer = Image.open(MOD / "common" / params["texture"]).convert("RGBA").resize((w, h), Image.LANCZOS)
                arr = np.array(layer, dtype=np.float32)
                arr[..., :3] *= color[:3]
                arr[..., 3] *= color[3]
                layer = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")
            else:
                layer = Image.new("RGBA", (max(w, 1), max(h, 1)), tuple(int(c * 255) for c in color))
            place(canvas, layer, x, y, angle)
        elif params["type"] == "text":
            f = font(params.get("font", "SdfRegular"))
            auto = num(params, "autoWidth", -1)
            layer = f.render(content, color, auto if auto > 0 else None, int(num(params, "textLeading")))
            sx, sy = num(params, "scaleX", 1), num(params, "scaleY", 1)
            layer = layer.resize((max(1, int(layer.width * sx)), max(1, int(layer.height * sy))), Image.LANCZOS)
            # Marge haute de 14 px ajoutée au rendu (accents des majuscules), et
            # calage sur une capture en jeu (2026-09-30) : le jeu dessine le texte
            # environ 12 unités (avant échelle) plus haut que le haut de ligne AngelCode.
            place(canvas, layer, x - num(params, "pivotX") * layer.width, y - 26 * sy, angle)
    return canvas


def main():
    language = sys.argv[1] if len(sys.argv) > 1 else "FR"
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else HERE / "preview"
    out.mkdir(parents=True, exist_ok=True)
    for name, doc in documents(language).items():
        path = out / f"{name}_{language}.png"
        render(doc).convert("RGB").save(path)
        print(path)


if __name__ == "__main__":
    main()
