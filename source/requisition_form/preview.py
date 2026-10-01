"""Aperçu hors jeu du formulaire de réquisition.

    python source/requisition_form/preview.py [--extra traductions.json] [--out dossier]

Exécute le vrai Lua de la fenêtre (client/MilitaryDrop/MilitaryDrop_RequisitionWindow.lua,
avec lupa) dans les éléments d'interface simulés de l'aperçu de la console du
poste (source/post_console/preview.py : ordres de dessin enregistrés puis
rastérisés avec les textures du mod et les polices bitmap du jeu, .fnt de
media/fonts/EN/<1x|2x> et la police manuscrite media/fonts/handwritten.fnt).
Les traductions viennent du mod ; --extra ajoute un fichier au format des
rapports de sous-agents ({"EN": {"IG_UI": {...}}, ...}).

Sortie (dossier ignoré par git) : source/requisition_form/preview/form_<cas>.png.
Approximations : pas de filtrage bilinéaire identique au jeu. À confirmer en jeu.
"""

import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
OUT_DIR = HERE / "preview"

# Aperçu de la console : polices, toile, textures, interface simulée.
_spec = importlib.util.spec_from_file_location("post_console_preview", HERE.parent / "post_console" / "preview.py")
post = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(post)
lua_harness = post.lua_harness

FONT_FILES = dict(post.FONT_FILES, CodeMedium="codeMedium.fnt")
HANDWRITTEN = post.PZ_FONTS / "handwritten.fnt"
SCRATCH = Path(r"C:\Users\cyber\AppData\Local\Temp\claude\C--Users-cyber-Zomboid-Workshop"
               r"\587b50a0-acfe-4863-a0ac-513996e4045c\scratchpad\v14")

# Interface simulée de la console, sans le chargement de ses modules.
UI = post.SETUP.split('loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")')[0]

SETUP = r"""
UIFont.CodeMedium = "CodeMedium"
UIFont.Handwritten = "Handwritten"
Joypad.Texture.BButton = "B"
function ISUIElement:drawTextZoomed(s, x, y, zoom, r, g, b, a, font)
    OPS[#OPS + 1] = { "textz", tostring(s), self:getAbsoluteX() + x, self:getAbsoluteY() + y + self.yscroll,
        r, g, b, a, font or UIFont.Small, zoom }
end
loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
MilitaryDrop.Client = { HANDLERS = {} }
loadMod("client/MilitaryDrop/MilitaryDrop_RequisitionWindow.lua")
PLAYER = { getPlayerNum = function() return 0 end }
"""

RENDER = r"""
local args, actions, screenW, screenH, receivedMs = ...
local RW = MilitaryDrop.RequisitionWindow
local form = RW.newForm(args, receivedMs)
for _, action in ipairs(actions) do
    local kind, value = action[1], action[2]
    if kind == "add" then RW.add(form, value)
    elseif kind == "decoy" then RW.toggleDecoy(form)
    elseif kind == "sector" then RW.pickSector(form, value)
    elseif kind == "fill" then
        while RW.add(form, value) do end
    end
end
local width, height = RW.measureSize(form, screenW, screenH)
local window = RW:new(0, 0, width, height, PLAYER, {}, form)
window.maxWidth, window.maxHeight = screenW, screenH
window:initialise()
window:instantiate()
OPS = {}
window:renderTree()
return window.width, window.height, window.L.cols, tostring(window.L.compact)
"""

LOTS = [
    ("rations", 1, 1), ("water", 1, 1), ("medical", 1, 2), ("tools", 1, 2), ("materials", 1, 1), ("camping", 1, 2),
    ("ammo", 2, 2), ("melee", 2, 3), ("protection", 2, 3), ("mechanics", 2, 2), ("comms", 2, 2), ("seeds", 2, 1),
    ("books", 2, 2), ("packs", 2, 2),
    ("firearms", 3, 5), ("attachments", 3, 3), ("explosives", 3, 5), ("fuel", 3, 3),
]
BUDGETS = {25: 8, 50: 12, 75: 16, 100: 20}


def form_args(trust, decoy=True, empty=(), disabled=()):
    group = 3 if trust >= 75 else (2 if trust >= 50 else 1)
    lots = []
    for lot_id, lot_group, cost in LOTS:
        reason = None
        if lot_id in disabled:
            reason = "disabled"
        elif lot_group > group:
            reason = "tier"
        elif lot_id in empty:
            reason = "empty"
        lots.append({"id": lot_id, "group": lot_group, "cost": cost, "allowed": reason is None, "reason": reason,
                     "label": f"IGUI_MilitaryDrop_Lot_{lot_id}", "desc": f"IGUI_MilitaryDrop_LotDesc_{lot_id}"})
    args = {"requestId": 7, "status": "form", "callsign": "Station Kilo-7", "tier": 1 + trust // 26,
            "budget": BUDGETS[trust], "expiresMs": 300000, "lots": lots}
    if decoy:
        args["decoy"] = {"cost": 3, "allowed": True, "sectors": ["N", "E", "S", "W"]}
    return args


def render(language, size_dir, args, actions, extra, screen=(1920, 1080), elapsed_ms=28000, mouse=None):
    table = {}
    for path in (post.TRANSLATE / language).glob("*.json"):
        table.update(json.loads(path.read_text(encoding="utf-8")))
    for path in extra:
        report = json.loads(Path(path).read_text(encoding="utf-8"))
        for content in (report.get(language) or {}).values():
            table.update(content)

    def get_text(key, *a):
        text = table.get(key, key)
        for i, arg in enumerate(a, 1):
            text = text.replace(f"%{i}", str(arg))
        return text

    fonts = {}

    def font(name):
        name = str(name)
        if name not in fonts:
            path = HANDWRITTEN if name == "Handwritten" else post.PZ_FONTS / "EN" / size_dir / FONT_FILES[name]
            fonts[name] = post.Font(path)
        return fonts[name]

    def text_of(value):
        return value.decode("utf-8", "ignore") if isinstance(value, bytes) else str(value)

    lua = lua_harness.new_runtime()
    g = lua.globals()
    g.getText = get_text
    g.LANGUAGE = language
    g.fontHeight = lambda f: font(f).line_height
    g.measureText = lambda f, s: font(f).width(text_of(s))
    g.textureExists = lambda p: (post.COMMON_MEDIA / text_of(p)).is_file()
    lua.execute(UI)
    lua.execute(SETUP)
    now = 1_000_000
    g.NOW_MS = now
    if mouse:
        g.MOUSE_X, g.MOUSE_Y = mouse
    lua_actions = post.to_lua(lua, [list(a) for a in actions])
    width, height, cols, compact = lua.execute(RENDER, post.to_lua(lua, args), lua_actions, screen[0], screen[1],
                                               now - elapsed_ms)
    pad = 24
    canvas = post.Canvas(int(width) + 2 * pad, int(height) + 2 * pad, (38, 42, 36))
    for entry in lua.eval("OPS").values():
        values = list(entry.values())
        kind = values[0]
        if kind == "rect":
            _, x, y, w, h, r, gg, b, a = values
            canvas.blend(round(x) + pad, round(y) + pad,
                         np.ones((max(0, round(h)), max(0, round(w))), dtype=np.float32) * a, (r, gg, b))
        elif kind in ("tex", "tiled"):
            _, path, x, y, w, h, r, gg, b, a = values
            img = post.texture(text_of(path))
            if img is not None:
                fn = post.draw_texture if kind == "tex" else post.draw_tiled
                fn(canvas, img, x + pad, y + pad, w, h, (r, gg, b), a)
        elif kind == "text":
            _, s, x, y, r, gg, b, a, f = values
            font(f).draw(canvas, text_of(s), x + pad, y + pad, (r, gg, b), a)
        elif kind == "textz":
            _, s, x, y, r, gg, b, a, f, zoom = values
            draw_zoomed(canvas, font(f), text_of(s), x + pad, y + pad, (r, gg, b), a, zoom)
    return canvas.image(), (int(cols), compact)


def draw_zoomed(canvas, fnt, text, x, y, color, alpha, zoom):
    """Texte agrandi (TextManager.DrawString avec zoom) : rendu à 1, puis mis à l'échelle."""
    w, h = fnt.width(text) + 8, fnt.line_height + 8
    layer = post.Canvas(w, h, (0, 0, 0))
    fnt.draw(layer, text, 0, 0, (1, 1, 1), 1)
    mask = layer.image().convert("L")
    size = (max(1, round(w * zoom)), max(1, round(h * zoom)))
    scaled = np.array(mask.resize(size, Image.BILINEAR), dtype=np.float32) / 255
    canvas.blend(round(x), round(y), scaled * alpha, color)


CASES = [
    # nom, langue, taille, arguments, actions, écran, temps écoulé, souris
    ("trust25", "FR", "1x", form_args(25), [("add", "rations"), ("add", "rations"), ("add", "medical")], None, 28000,
     None),
    ("trust50", "FR", "1x", form_args(50, empty=("seeds",)), [("add", "ammo"), ("add", "melee"), ("add", "water")],
     None, 95000, None),
    ("trust100", "FR", "1x", form_args(100, disabled=("explosives",)),
     [("add", "firearms"), ("add", "ammo"), ("add", "ammo"), ("add", "medical"), ("add", "rations")], None, 250000,
     None),
    ("decoy", "FR", "1x", form_args(75), [("decoy", None), ("sector", "W")], None, 40000, None),
    ("decoy_nosector", "FR", "1x", form_args(75), [("decoy", None)], None, 40000, None),
    ("budget_spent", "FR", "1x", form_args(50), [("fill", "melee"), ("add", "rations"), ("add", "water")], None,
     60000, None),
    ("english", "EN", "1x", form_args(75), [("add", "firearms"), ("add", "attachments"), ("add", "rations")], None,
     30000, None),
    ("expired", "FR", "1x", form_args(50), [("add", "tools")], None, 310000, None),
    ("small_960x540", "FR", "1x", form_args(100), [("add", "fuel"), ("add", "tools")], (960, 540), 30000, None),
    ("fonts2x", "FR", "2x", form_args(100), [("add", "fuel"), ("add", "tools")], None, 30000, None),
    ("nodecoy", "EN", "1x", form_args(25, decoy=False), [("add", "camping")], None, 30000, None),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--extra", action="append", default=[])
    parser.add_argument("--out", default=str(OUT_DIR))
    parser.add_argument("--only", default=None)
    args = parser.parse_args()
    extra = list(args.extra)
    if not extra:
        # Traductions des sous-agents encore hors du mod (développement).
        for name in ("requisition_translations.json", "formulaire_translations.json"):
            if (SCRATCH / name).is_file():
                extra.append(str(SCRATCH / name))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for name, language, size_dir, form, actions, screen, elapsed, mouse in CASES:
        if args.only and args.only not in name:
            continue
        img, (cols, compact) = render(language, size_dir, form, actions, extra, screen or (1920, 1080), elapsed,
                                      mouse)
        path = out / f"form_{name}.png"
        img.save(path)
        print(path.name, img.size, f"{cols} colonne(s), serré={compact}")


if __name__ == "__main__":
    main()
