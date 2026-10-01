"""Aperçu hors jeu de la console du poste de liaison.

    python source/post_console/preview.py [--extra traductions.json] [--out dossier]

Exécute le vrai Lua de la fenêtre (client/MilitaryDrop/MilitaryDrop_PostWindow.lua,
avec lupa) dans des éléments d'interface simulés qui enregistrent les ordres de
dessin (drawRect, drawTextureScaled, drawTextureTiled, drawText…, pochoir du
journal), puis les rastérise avec les textures du mod et les polices bitmap du
jeu (fichiers AngelCode .fnt de media/fonts/EN/<1x|2x>, largeurs comme
AngelCodeFont.getWidth). Les traductions viennent du mod ; --extra ajoute un
fichier au format des rapports de sous-agents ({"EN": {"IG_UI": {...}}, ...}).

Sortie (dossier ignoré par git) : source/post_console/preview/console_<cas>.png.
Approximations : texte riche simplifié (couleurs et retours à la ligne), pas
de filtrage bilinéaire identique au jeu. À confirmer en jeu.
"""

import argparse
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
COMMON_MEDIA = MOD / "common"
PZ_FONTS = lua_harness.PZ_MEDIA / "fonts"
FONT_FILES = {
    "Small": "zomboidSmall.fnt", "NewSmall": "zomboidSmall.fnt", "Medium": "zomboidMedium.fnt",
    "Large": "zomboidLarge.fnt", "CodeSmall": "codeSmall.fnt",
}
OUT_DIR = HERE / "preview"


# ----------------------------------------------------------------------------
# Polices bitmap du jeu
# ----------------------------------------------------------------------------

class Font:
    def __init__(self, path):
        self.chars, self.kerning, pages = {}, {}, {}
        for line in path.read_text(encoding="utf-8").splitlines():
            fields = dict(re.findall(r"(\w+)=(\"[^\"]*\"|\S+)", line))
            if line.startswith("common "):
                self.line_height = int(fields["lineHeight"])
            elif line.startswith("page "):
                pages[int(fields["id"])] = fields["file"].strip('"')
            elif line.startswith("char "):
                self.chars[int(fields["id"])] = {k: int(v) for k, v in fields.items() if k != "letter"}
            elif line.startswith("kerning "):
                self.kerning[(int(fields["first"]), int(fields["second"]))] = int(fields["amount"])
        self.pages = {}
        for pid, name in pages.items():
            img = Image.open(path.parent / name).convert("RGBA")
            arr = np.array(img, dtype=np.float32) / 255
            alpha = arr[..., 3]
            if alpha.min() > 0.99:  # glyphes dans la luminance
                alpha = arr[..., :3].max(-1)
            self.pages[pid] = alpha

    def width(self, text):
        width = best = 0
        last = None
        codes = [ord(c) for c in text]
        for i, code in enumerate(codes):
            ch = self.chars.get(code)
            if not ch:
                continue
            if last is not None:
                width += self.kerning.get((last, code), 0)
            last = code
            width += ch["xadvance"] if i < len(codes) - 1 else ch["width"]
            best = max(best, width)
        return best

    def draw(self, canvas, text, x, y, color, alpha):
        last = None
        for c in text:
            code = ord(c)
            ch = self.chars.get(code)
            if not ch:
                continue
            if last is not None:
                x += self.kerning.get((last, code), 0)
            last = code
            if ch["width"] > 0 and ch["height"] > 0:
                glyph = self.pages[ch["page"]][ch["y"]:ch["y"] + ch["height"], ch["x"]:ch["x"] + ch["width"]]
                canvas.blend(round(x + ch["xoffset"]), round(y + ch["yoffset"]), glyph * alpha, color)
            x += ch["xadvance"]


# ----------------------------------------------------------------------------
# Toile
# ----------------------------------------------------------------------------

class Canvas:
    def __init__(self, w, h, background):
        self.rgb = np.ones((h, w, 3), dtype=np.float32) * np.array(background, dtype=np.float32) / 255
        self.clip = None

    def blend(self, x, y, alpha, color):
        """alpha : tableau h×w (0..1) ; color : (r, g, b) ou tableau h×w×3."""
        h, w = alpha.shape
        x0, y0, x1, y1 = x, y, x + w, y + h
        cx0, cy0, cx1, cy1 = 0, 0, self.rgb.shape[1], self.rgb.shape[0]
        if self.clip:
            cx0, cy0 = max(cx0, self.clip[0]), max(cy0, self.clip[1])
            cx1, cy1 = min(cx1, self.clip[2]), min(cy1, self.clip[3])
        sx0, sy0, sx1, sy1 = max(x0, cx0), max(y0, cy0), min(x1, cx1), min(y1, cy1)
        if sx0 >= sx1 or sy0 >= sy1:
            return
        a = alpha[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0, None]
        col = np.asarray(color, dtype=np.float32)
        if col.ndim == 3:
            col = col[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0]
        region = self.rgb[sy0:sy1, sx0:sx1]
        region[:] = region * (1 - a) + np.clip(col, 0, 1) * a

    def image(self):
        return Image.fromarray((np.clip(self.rgb, 0, 1) * 255).astype(np.uint8), "RGB")


TEXTURE_CACHE = {}


def texture(path):
    if path not in TEXTURE_CACHE:
        file = COMMON_MEDIA / path
        TEXTURE_CACHE[path] = Image.open(file).convert("RGBA") if file.is_file() else None
    return TEXTURE_CACHE[path]


def draw_texture(canvas, img, x, y, w, h, color, alpha):
    w, h = round(w), round(h)
    if w <= 0 or h <= 0:
        return
    arr = np.array(img.resize((w, h), Image.BILINEAR), dtype=np.float32) / 255
    canvas.blend(round(x), round(y), arr[..., 3] * alpha, arr[..., :3] * np.array(color, dtype=np.float32))


def draw_tiled(canvas, img, x, y, w, h, color, alpha):
    arr = np.array(img, dtype=np.float32) / 255
    th, tw = arr.shape[:2]
    reps = (int(h // th) + 2, int(w // tw) + 2, 1)
    tiled = np.tile(arr, reps)[:round(h), :round(w)]
    canvas.blend(round(x), round(y), tiled[..., 3] * alpha, tiled[..., :3] * np.array(color, dtype=np.float32))


# ----------------------------------------------------------------------------
# Interface simulée (Lua)
# ----------------------------------------------------------------------------

SETUP = r"""
OPS = {}
local function op(...) OPS[#OPS + 1] = { ... } end

isClient = function() return true end
isServer = function() return false end
SandboxVars = { MilitaryDrop = { Frequency = 151.4 } }
NOW_MS = 1000
getTimestampMs = function() return NOW_MS end
MOUSE_X, MOUSE_Y = -100, -100
getMouseX = function() return MOUSE_X end
getMouseY = function() return MOUSE_Y end
getSoundManager = function() return { playUISound = function() end } end
JoypadState = { players = {} }
Joypad = { AButton = 0, BButton = 1, XButton = 2, Texture = { AButton = "A", XButton = "X" } }
Keyboard = { KEY_ESCAPE = 1 }
Translator = { getLanguage = function() return { name = function() return LANGUAGE end } end }
getTexture = function(path) if textureExists(path) then return { path = path } end return nil end
ItemTag = { DOG_TAG = "base:dogtag" }

UIFont = { Small = "Small", NewSmall = "NewSmall", Medium = "Medium", Large = "Large", CodeSmall = "CodeSmall" }
getTextManager = function()
    return {
        getFontHeight = function(_, font) return fontHeight(font) end,
        MeasureStringX = function(_, font, text) return measureText(font, text) end,
    }
end

-- Élément d'interface : position relative au parent, défilement vertical.
ISUIElement = {}
ISUIElement.__index = ISUIElement
function ISUIElement:derive(name)
    local cls = setmetatable({}, { __index = self })
    cls.__index = cls
    cls.Type = name
    return cls
end
function ISUIElement.new(cls, x, y, w, h)
    local o = setmetatable({}, cls)
    o.x, o.y, o.width, o.height = x, y, w, h
    o.children, o.yscroll, o.scrollHeight, o.visible = {}, 0, 0, true
    return o
end
function ISUIElement:initialise() end
function ISUIElement:instantiate()
    if not self.instantiated then
        self.instantiated = true
        self:createChildren()
    end
end
function ISUIElement:createChildren() end
function ISUIElement:addChild(child)
    child.parent = self
    self.children[#self.children + 1] = child
    child:instantiate()
end
function ISUIElement:addToUIManager() end
function ISUIElement:removeFromUIManager() end
function ISUIElement:setWantKeyEvents() end
function ISUIElement:setVisible(v) self.visible = v end
function ISUIElement:getIsVisible() return self.visible end
function ISUIElement:isReallyVisible() return self.visible end
function ISUIElement:update() end
function ISUIElement:getX() return self.x end
function ISUIElement:getY() return self.y end
function ISUIElement:getWidth() return self.width end
function ISUIElement:getHeight() return self.height end
function ISUIElement:setX(v) self.x = v end
function ISUIElement:setY(v) self.y = v end
function ISUIElement:setWidth(v) self.width = v end
function ISUIElement:setHeight(v) self.height = v end
function ISUIElement:getAbsoluteX() return self.x + (self.parent and self.parent:getAbsoluteX() or 0) end
function ISUIElement:getAbsoluteY() return self.y + (self.parent and self.parent:getAbsoluteY() or 0) end
function ISUIElement:getMouseX() return MOUSE_X - self:getAbsoluteX() end
function ISUIElement:getMouseY() return MOUSE_Y - self:getAbsoluteY() end
function ISUIElement:getYScroll() return self.yscroll end
function ISUIElement:setYScroll(v) self.yscroll = v end
function ISUIElement:getScrollHeight() return self.scrollHeight end
function ISUIElement:setScrollHeight(v) self.scrollHeight = v end
function ISUIElement:onGainJoypadFocus() end
function ISUIElement:onLoseJoypadFocus() end
local function ax(self, x) return self:getAbsoluteX() + x end
local function ay(self, y) return self:getAbsoluteY() + y + self.yscroll end
function ISUIElement:drawRect(x, y, w, h, a, r, g, b) op("rect", ax(self, x), ay(self, y), w, h, r, g, b, a) end
function ISUIElement:drawRectBorder(x, y, w, h, a, r, g, b)
    self:drawRect(x, y, 1, h, a, r, g, b)
    self:drawRect(x + 1, y, w - 2, 1, a, r, g, b)
    self:drawRect(x + w - 1, y, 1, h, a, r, g, b)
    self:drawRect(x + 1, y + h - 1, w - 2, 1, a, r, g, b)
end
function ISUIElement:drawTextureScaled(t, x, y, w, h, a, r, g, b)
    if t and t.path then op("tex", t.path, ax(self, x), ay(self, y), w, h, r or 1, g or 1, b or 1, a) end
end
function ISUIElement:drawTextureTiled(t, x, y, w, h, r, g, b, a)
    if t and t.path then op("tiled", t.path, ax(self, x), ay(self, y), w, h, r or 1, g or 1, b or 1, a or 1) end
end
function ISUIElement:drawText(s, x, y, r, g, b, a, font)
    op("text", tostring(s), ax(self, x), ay(self, y), r, g, b, a, font or UIFont.Small)
end
function ISUIElement:drawTextCentre(s, x, y, r, g, b, a, font)
    font = font or UIFont.Small
    self:drawText(s, x - measureText(font, tostring(s)) / 2, y, r, g, b, a, font)
end
function ISUIElement:drawTextRight(s, x, y, r, g, b, a, font)
    font = font or UIFont.Small
    self:drawText(s, x - measureText(font, tostring(s)), y, r, g, b, a, font)
end
function ISUIElement:setStencilRect(x, y, w, h) op("clip", ax(self, x), self:getAbsoluteY() + y, w, h) end
function ISUIElement:clearStencilRect() op("unclip") end
function ISUIElement:renderTree()
    if self.prerender then self:prerender() end
    for _, child in ipairs(self.children) do if child.visible then child:renderTree() end end
    if self.render then self:render() end
end

ISPanelJoypad = ISUIElement:derive("ISPanelJoypad")
function ISPanelJoypad:onMouseDown() end
function ISPanelJoypad:onMouseUp() end
function ISPanelJoypad:onMouseUpOutside() end

-- Texte riche simplifié : <RGB:r,g,b>, <LINE>, <SPACE>, mots coupés à la
-- largeur. Comme le vanilla, un espace voisin d'une balise ne compte pas :
-- seul <SPACE> écarte deux fragments séparés par une balise.
ISRichTextPanel = ISUIElement:derive("ISRichTextPanel")
function ISRichTextPanel:new(x, y, w, h)
    local o = ISUIElement.new(self, x, y, w, h)
    o.marginLeft, o.marginTop, o.marginRight, o.marginBottom = 20, 10, 10, 10
    o.text, o.defaultFont = "", UIFont.NewSmall
    return o
end
function ISRichTextPanel:setMargins(l, t, r, b)
    self.marginLeft, self.marginTop, self.marginRight, self.marginBottom = l, t, r, b
end
function ISRichTextPanel:paginate()
    local font = self.defaultFont
    local lh = fontHeight(font)
    local maxW = self.width - self.marginLeft - self.marginRight
    local spaceW = measureText(font, "a a") - measureText(font, "aa")
    self.frags, self.lineY = {}, {}
    local color = { 1, 1, 1 }
    local x, y = 0, 0
    local afterWord = false
    for token in self.text:gmatch("[^ ]+") do
        local rgb = token:match("^<RGB:([%d%.,]+)>$")
        if rgb then
            local r, g, b = rgb:match("([%d%.]+),([%d%.]+),([%d%.]+)")
            color = { tonumber(r), tonumber(g), tonumber(b) }
            afterWord = false
        elseif token == "<LINE>" then
            x, y = 0, y + lh
            afterWord = false
        elseif token == "<SPACE>" then
            if x > 0 then
                x = x + measureText(font, " ") + 2
            end
            afterWord = false
        else
            local word = token:gsub("&lt;", "<"):gsub("&gt;", ">")
            local w = measureText(font, word)
            if afterWord then
                x = x + spaceW
            end
            if x > 0 and x + w > maxW then
                x, y = 0, y + lh
            end
            self.frags[#self.frags + 1] = { word, x, y, color }
            self.lineY[#self.lineY + 1] = y
            x = x + w
            afterWord = true
        end
    end
    self:setScrollHeight(y + (x > 0 and lh or 0) + self.marginTop + self.marginBottom)
end
function ISRichTextPanel:render()
    self:setStencilRect(0, 0, self.width, self.height)
    for _, f in ipairs(self.frags or {}) do
        self:drawText(f[1], self.marginLeft + f[2], self.marginTop + f[3], f[4][1], f[4][2], f[4][3], 1,
            self.defaultFont)
    end
    self:clearStencilRect()
end

-- Champ de saisie (code) : fond et cadre de ses couleurs, texte ou texte
-- indicatif grisé, comme UITextBox2.
ISTextEntryBox = ISUIElement:derive("ISTextEntryBox")
function ISTextEntryBox:new(text, x, y, w, h)
    local o = ISUIElement.new(self, x, y, w, h)
    o.text = text or ""
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    return o
end
function ISTextEntryBox:setMaxTextLength() end
function ISTextEntryBox:setPlaceholderText(t) self.placeholder = t end
function ISTextEntryBox:setTooltip() end
function ISTextEntryBox:getText() return self.text end
function ISTextEntryBox:setText(t) self.text = t end
function ISTextEntryBox:render()
    if not self.visible then return end
    local bg, bd = self.backgroundColor, self.borderColor
    self:drawRect(0, 0, self.width, self.height, bg.a, bg.r, bg.g, bg.b)
    self:drawRectBorder(0, 0, self.width, self.height, bd.a, bd.r, bd.g, bd.b)
    local font = self.font or UIFont.Small
    local y = (self.height - fontHeight(font)) / 2
    if self.text ~= "" then
        self:drawText(self.text, 3, y, 1, 1, 1, 1, font)
    elseif self.placeholder then
        self:drawText(self.placeholder, 3, y, 0.5, 0.5, 0.5, 1, font)
    end
end

ISToolTip = ISUIElement:derive("ISToolTip")
function ISToolTip:new() return ISUIElement.new(self, 0, 0, 10, 10) end
function ISToolTip:setOwner() end
function ISToolTip:setAlwaysOnTop() end
function ISToolTip:setDesiredPosition() end

loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
pcall(loadMod, "shared/MilitaryDrop/MilitaryDrop_Exchange.lua")
MilitaryDrop.Client = { HANDLERS = {}, rememberedCode = function() return CODE or "" end,
    rememberCode = function() end }
loadMod("client/MilitaryDrop/MilitaryDrop_PostWindow.lua")

ArrayList = { new = function() return {} end }
local function arrayList(values)
    return { size = function() return #values end, get = function(_, i) return values[i + 1] end }
end
local function dogTag(name, id)
    return {
        hasTag = function() return true end,
        getDisplayName = function() return "Dog Tag: " .. name end,
        getScriptItem = function() return { getDisplayName = function() return "Dog Tag" end } end,
        getID = function() return id end,
    }
end
TAG_ITEMS = { dogTag("A. Brooks", 11), dogTag("T. Nguyen", 12) }
PLAYER = {
    getPlayerNum = function() return 0 end,
    getInventory = function()
        return {
            getAllTagRecurse = function() return arrayList(TAG_ITEMS) end,
            getAllEvalRecurse = function() return arrayList(TAG_ITEMS) end,
        }
    end,
    getDescriptor = function()
        return { getForename = function() return "Bob" end, getSurname = function() return "Smith" end }
    end,
    isEquipped = function() return false end,
    isAttachedItem = function() return false end,
}
"""

RENDER = r"""
local data, screenW, screenH = ...
local W = MilitaryDrop.PostWindow
local width, height = W.measureSize(data, screenW, screenH)
local window = W:new(0, 0, width, height, PLAYER, {})
window.maxWidth, window.maxHeight = screenW, screenH
window:initialise()
window:instantiate()
window:setData(data)
OPS = {}
window:renderTree()
return window.width, window.height
"""


SAMPLE_LINES = {
    "FR": [
        ("Logistique : rapport de situation reçu, Station Kilo-7. Merci.", 14, 30),
        (None, 15, 0),
        ("À toutes les stations, ici Logistique. Reconnaissance demandée en grille 10874 / 9512. "
         "Première station à confirmer sur place dans les 48 heures.", 16, 10),
        ("Station Kilo-7, ici Logistique. Matricules reçus : J. Miller, R. Ortega. Merci.", 17, 45),
        ("SYS", 18, 2),
        ("À toutes les stations, ici Logistique. Appel de contrôle. Confirmez la réception sur cette fréquence "
         "dans les 4 heures.", 19, 20),
    ],
    "EN": [
        ("Logistics: situation report received, Station Kilo-7. Thank you.", 14, 30),
        (None, 15, 0),
        ("All stations, this is Logistics. Reconnaissance requested at grid 10874 / 9512. First station to "
         "confirm on site within 48 hours.", 16, 10),
        ("Station Kilo-7, this is Logistics. Tags received: J. Miller, R. Ortega. Thank you.", 17, 45),
        ("SYS", 18, 2),
        ("All stations, this is Logistics. Radio check. Confirm receipt on this frequency within 4 hours.", 19, 20),
    ],
}


def sample_data(lua, language, variant):
    clock_hours = lua.eval("MilitaryDrop.Codes.clockHours")
    lines = []
    for text, hh, mm in SAMPLE_LINES[language]:
        c = clock_hours(1993, 6, 7, hh + mm / 60)
        if text is None:
            lines.append({"c": c, "gap": 2})
        elif text == "SYS":
            lines.append({"c": c, "sys": "moved"})
        else:
            lines.append({"c": c, "t": text})
    titles = {"FR": ("Reconnaissance", "Nettoyage", "Appel de contrôle"),
              "EN": ("Reconnaissance", "Cleanup", "Radio check")}[language]
    missions = [
        {"kind": "recon", "title": titles[0], "text": lines[2]["t"], "remaining": 31.2, "x": 10874, "y": 9512},
        {"kind": "cleanup", "title": titles[1], "text": "...", "remaining": 52, "hours": 72, "progress": 12,
         "spotted": True, "left": 9, "down": 18, "target": 27, "x": 11210, "y": 6930},
        {"kind": "control", "title": titles[2], "text": lines[-1]["t"], "remaining": 2.4, "progress": 0, "quota": 1},
    ]
    mail = [{"id": 1, "name": "J. Miller", "by": "alice"}, {"id": 2, "name": "R. Ortega", "by": "bob"},
            {"id": 3, "name": "Kowalczyk-Brandt", "by": "alice"}]
    data = {"x": 100, "y": 100, "z": 0, "callsign": "Station Kilo-7", "channel": 151400, "on": True,
            "power": "battery", "battery": 0.62, "tier": 3, "lineCut": False, "lines": lines, "missions": missions,
            "mail": mail}
    if variant == "off":
        data.update(on=False, power="none", battery=None, tier=1, lineCut=True, missions=[], mail=[], lines=[])
    if variant == "grid":
        data.update(power="grid", battery=None, tier=4, mail=mail * 4)
    if variant == "first":
        # Poste tout juste installé : secteur, confiance de départ, rien reçu.
        data.update(power="grid", battery=None, tier=3, missions=[], mail=[],
                    lines=[{"c": clock_hours(1993, 6, 7, 9.5), "sys": "installed"}])
    if variant == "generator":
        # Groupe électrogène, dossier mitigé, reconnaissance presque échue,
        # nettoyage presque au quota.
        data.update(power="generator", battery=None, tier=2, mail=mail[:1])
        data["missions"] = [dict(missions[0], remaining=0.6),
                            dict(missions[1], remaining=20, progress=0, spotted=False, left=None, down=None,
                                 target=None)]
    if variant == "lowbat":
        # Pile presque vide, méfiance, dernière annonce manquée (voyant RX éteint).
        data.update(battery=0.08, tier=1, mail=[], missions=missions[2:])
        data["lines"] = lines[:4] + [{"c": clock_hours(1993, 6, 7, 20.5), "gap": 3}]
    return to_lua(lua, data)


def to_lua(lua, value):
    if isinstance(value, dict):
        return lua.table_from({k: to_lua(lua, v) for k, v in value.items() if v is not None})
    if isinstance(value, list):
        return lua.table_from([to_lua(lua, v) for v in value])
    return value


def render(language, size_dir, variant, extra, screen=(1920, 1080), mouse=None):
    table = {}
    for path in (TRANSLATE / language).glob("*.json"):
        table.update(json.loads(path.read_text(encoding="utf-8")))
    for path in extra:
        report = json.loads(Path(path).read_text(encoding="utf-8"))
        for content in (report.get(language) or {}).values():
            table.update(content)

    def get_text(key, *args):
        text = table.get(key, key)
        for i, arg in enumerate(args, 1):
            text = text.replace(f"%{i}", str(arg))
        return text

    fonts = {}

    def font(name):
        name = str(name)
        if name not in fonts:
            fonts[name] = Font(PZ_FONTS / "EN" / size_dir / FONT_FILES[name])
        return fonts[name]

    def text_of(value):
        return value.decode("utf-8", "ignore") if isinstance(value, bytes) else str(value)

    lua = lua_harness.new_runtime()
    g = lua.globals()
    g.getText = get_text
    g.LANGUAGE = language
    g.fontHeight = lambda f: font(f).line_height
    g.measureText = lambda f, s: font(f).width(text_of(s))
    g.textureExists = lambda p: (COMMON_MEDIA / text_of(p)).is_file()
    lua.execute(SETUP)
    data = sample_data(lua, language, variant)
    g.CODE = "" if variant == "first" else "BRAVO-KILO-42"
    if mouse:
        g.MOUSE_X, g.MOUSE_Y = mouse
    width, height = lua.execute(RENDER, data, screen[0], screen[1])
    pad = 24
    canvas = Canvas(int(width) + 2 * pad, int(height) + 2 * pad, (38, 42, 36))
    for entry in lua.eval("OPS").values():
        args = list(entry.values())
        kind = args[0]
        if kind == "rect":
            _, x, y, w, h, r, gg, b, a = args
            canvas.blend(round(x) + pad, round(y) + pad, np.ones((max(0, round(h)), max(0, round(w))),
                                                                 dtype=np.float32) * a, (r, gg, b))
        elif kind in ("tex", "tiled"):
            _, path, x, y, w, h, r, gg, b, a = args
            img = texture(text_of(path))
            if img is not None:
                fn = draw_texture if kind == "tex" else draw_tiled
                fn(canvas, img, x + pad, y + pad, w, h, (r, gg, b), a)
        elif kind == "text":
            _, s, x, y, r, gg, b, a, f = args
            font(f).draw(canvas, text_of(s), x + pad, y + pad, (r, gg, b), a)
        elif kind == "clip":
            _, x, y, w, h = args
            canvas.clip = (round(x) + pad, round(y) + pad, round(x + w) + pad, round(y + h) + pad)
        elif kind == "unclip":
            canvas.clip = None
    return canvas.image()


CASES = [
    ("FR", "1x", "normal", None, None),
    ("EN", "1x", "normal", None, None),
    ("FR", "2x", "normal", None, None),
    ("FR", "1x", "off", None, None),
    ("FR", "1x", "grid", None, None),
    ("FR", "1x", "normal", (960, 540), None),
    ("FR", "1x", "first", None, None),
    ("FR", "1x", "generator", None, None),
    ("FR", "1x", "lowbat", None, None),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--extra", action="append", default=[])
    parser.add_argument("--out", default=str(OUT_DIR))
    args = parser.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for language, size_dir, variant, screen, mouse in CASES:
        img = render(language, size_dir, variant, args.extra, screen or (1920, 1080), mouse)
        name = f"console_{language}_{size_dir}_{variant}" + (f"_{screen[0]}x{screen[1]}" if screen else "") + ".png"
        img.save(out / name)
        print(out / name, img.size)


if __name__ == "__main__":
    main()
