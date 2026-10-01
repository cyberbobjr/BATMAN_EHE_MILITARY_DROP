"""Aperçu hors jeu du module « Logistique » de la fenêtre radio.

    python source/radio_module/preview.py [--extra traductions.json] [--out dossier]

Exécute le vrai Lua du module (client/MilitaryDrop/MilitaryDrop_RadioModule.lua,
avec MilitaryDrop_Client.lua, MilitaryDrop_ExchangeMenu.lua et les fichiers
partagés, sous lupa) dans une maquette de la fenêtre radio vanilla
(ISRadioWindow, RWMElement, ISButton, ISTextEntryBox simulés d'après leur
rendu 42.21), enregistre les ordres de dessin et les rastérise avec les polices
bitmap du jeu (réutilise source/post_console/preview.py). --extra ajoute un
fichier de traductions au format des rapports de sous-agents.

Sortie (dossier ignoré par git) : source/radio_module/preview/radio_<cas>.png.
Approximations : en-têtes des modules vanilla sans leur texture, pas de
filtrage identique au jeu. À confirmer en jeu.
"""

import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
_spec = importlib.util.spec_from_file_location("post_console_preview", REPO / "source" / "post_console" / "preview.py")
base = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(base)
lua_harness = base.lua_harness

OUT_DIR = HERE / "preview"

SETUP = r"""
OPS = {}
local function op(...) OPS[#OPS + 1] = { ... } end

isClient = function() return false end
isServer = function() return false end
isDebugEnabled = function() return false end
NOW_MS = 1000
getTimestampMs = function() return NOW_MS end
ZombRand = function() return 0 end
getSoundManager = function() return { playUISound = function() end } end
JoypadState = { players = {} }
Joypad = { AButton = 0, BButton = 1, LBumper = 4, RBumper = 5 }
UIFont = { Small = "Small", Medium = "Medium" }
getTextManager = function()
    return {
        getFontHeight = function(_, font) return fontHeight(font) end,
        MeasureStringX = function(_, font, text) return measureText(font, text) end,
    }
end
instanceof = function(object, class) return type(object) == "table" and object.kind == class end

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
    o.x, o.y, o.width, o.height, o.visible, o.children = x, y, w, h, true, {}
    return o
end
function ISUIElement:initialise() end
function ISUIElement:instantiate()
    if not self.instantiated then
        self.instantiated = true
        if self.createChildren then self:createChildren() end
    end
end
function ISUIElement:addChild(child)
    child:instantiate()
    child.parent = self
    self.children[#self.children + 1] = child
end
function ISUIElement:setVisible(v) self.visible = v end
function ISUIElement:getIsVisible() return self.visible end
function ISUIElement:getX() return self.x end
function ISUIElement:getY() return self.y end
function ISUIElement:setX(v) self.x = v end
function ISUIElement:setY(v) self.y = v end
function ISUIElement:getWidth() return self.width end
function ISUIElement:getHeight() return self.height end
function ISUIElement:setWidth(v) self.width = v end
function ISUIElement:setHeight(v) self.height = v end
function ISUIElement:update() end
function ISUIElement:getAbsoluteX() return self.x + (self.parent and self.parent:getAbsoluteX() or 0) end
function ISUIElement:getAbsoluteY() return self.y + (self.parent and self.parent:getAbsoluteY() or 0) end
local function ax(self, x) return self:getAbsoluteX() + x end
local function ay(self, y) return self:getAbsoluteY() + y end
function ISUIElement:drawRect(x, y, w, h, a, r, g, b) op("rect", ax(self, x), ay(self, y), w, h, r, g, b, a) end
function ISUIElement:drawRectBorder(x, y, w, h, a, r, g, b)
    self:drawRect(x, y, 1, h, a, r, g, b)
    self:drawRect(x + 1, y, w - 2, 1, a, r, g, b)
    self:drawRect(x + w - 1, y, 1, h, a, r, g, b)
    self:drawRect(x + 1, y + h - 1, w - 2, 1, a, r, g, b)
end
function ISUIElement:drawText(s, x, y, r, g, b, a, font)
    op("text", tostring(s), ax(self, x), ay(self, y), r, g, b, a, font or UIFont.Small)
end
function ISUIElement:drawTextCentre(s, x, y, r, g, b, a, font)
    font = font or UIFont.Small
    self:drawText(s, x - measureText(font, tostring(s)) / 2, y, r, g, b, a, font)
end
function ISUIElement:renderTree()
    if not self.visible then return end
    if self.prerender then self:prerender() end
    for _, child in ipairs(self.children) do child:renderTree() end
    if self.render then self:render() end
end

ISPanel = ISUIElement:derive("ISPanel")
RWMPanel = ISUIElement:derive("RWMPanel")
function RWMPanel:new(x, y, w, h) return ISUIElement.new(self, x, y, w, h) end
function RWMPanel:readFromObject(player, device, data, kind)
    self.player, self.device, self.deviceData, self.deviceType = player, device, data, kind
    return true
end
function RWMPanel:clear() self.player, self.device, self.focusElement = nil, nil, nil end
function RWMPanel:render() end

-- ISButton 42.21 (rendu : cadre, titre centré, gris 0,3 si inactif).
ISButton = ISUIElement:derive("ISButton")
function ISButton:new(x, y, w, h, title, target, onclick)
    local o = ISUIElement.new(self, x, y, w, h)
    o.title, o.target, o.onclick, o.enable, o.font = title, target, onclick, true, UIFont.Small
    o.borderColor = { r = 0.7, g = 0.7, b = 0.7, a = 1 }
    return o
end
function ISButton:setTitle(t) self.title = t end
function ISButton:setEnable(v) self.enable = v end
function ISButton:setTooltip(t) self.tooltip = t end
function ISButton:setJoypadFocused(v) self.joypadFocused = v end
function ISButton:forceClick() if self.enable then self.onclick(self.target, self) end end
function ISButton:prerender()
    local c = self.borderColor
    self:drawRectBorder(0, 0, self.width, self.height, c.a, c.r, c.g, c.b)
end
function ISButton:render()
    local h = fontHeight(self.font)
    local x = (self.width - measureText(self.font, self.title)) / 2
    if self.enable then
        self:drawText(self.title, x, (self.height - h) / 2, 1, 1, 1, 1, self.font)
    else
        self:drawText(self.title, x, (self.height - h) / 2, 0.3, 0.3, 0.3, 1, self.font)
    end
end

ISTextEntryBox = ISUIElement:derive("ISTextEntryBox")
function ISTextEntryBox:new(text, x, y, w, h)
    local o = ISUIElement.new(self, x, y, w, h)
    o.text = text
    return o
end
function ISTextEntryBox:getText() return self.text end
function ISTextEntryBox:setText(t) self.text = t end
function ISTextEntryBox:setMaxTextLength() end
function ISTextEntryBox:setPlaceholderText(t) self.placeholder = t end
function ISTextEntryBox:setTooltip() end
function ISTextEntryBox:setJoypadFocused(v) self.joypadFocused = v end
function ISTextEntryBox:prerender()
    self:drawRect(0, 0, self.width, self.height, 0.5, 0, 0, 0)
    self:drawRectBorder(0, 0, self.width, self.height, 1, 0.4, 0.4, 0.4)
    local h = fontHeight(UIFont.Small)
    if self.text ~= "" then
        self:drawText(self.text, 4, (self.height - h) / 2, 1, 1, 1, 1, UIFont.Small)
    elseif self.placeholder then
        self:drawText(self.placeholder, 4, (self.height - h) / 2, 0.5, 0.5, 0.5, 1, UIFont.Small)
    end
end

-- En-tête de module (RWMElement) : barre de titre, puis le panneau.
RWMElement = ISUIElement:derive("RWMElement")
function RWMElement:new(x, y, w, h, subpanel, title, radioParent)
    local o = ISUIElement.new(self, x, y, w, h)
    o.subpanel, o.titleText, o.radioParent = subpanel, title, radioParent
    o.headerH = fontHeight(UIFont.Small) + 2
    return o
end
function RWMElement:createChildren()
    if self.subpanel then
        self.subpanel:setY(self.headerH)
        self.subpanel:setWidth(self.width)
        self:addChild(self.subpanel)
    end
    self:calculateHeights()
end
function RWMElement:calculateHeights()
    self.height = self.headerH + ((self.subpanel and self.expanded) and self.subpanel.height or 0)
    if self.subpanel then self.subpanel.visible = self.expanded end
end
function RWMElement:prerender()
    self:drawRect(0, 0, self.width, self.headerH, 1, 0.16, 0.16, 0.16)
    self:drawRectBorder(0, 0, self.width, self.headerH, 0.3, 1, 1, 1)
    self:drawTextCentre(self.titleText, self.width / 2, 1, 1, 1, 1, 1, UIFont.Small)
end
function RWMElement:onJoypadDirUp() end
function RWMElement:onJoypadDirDown() end

-- Fenêtre radio : titre, modules vanilla repliés, puis « Logistique ».
ISRadioWindow = ISUIElement:derive("ISRadioWindow")
function ISRadioWindow:addModule(panel, name, enable)
    local module = { enabled = enable, element = RWMElement:new(0, 0, self.width, 0, panel, name, self) }
    module.element.expanded = panel ~= nil
    table.insert(self.modules, module)
    self:addChild(module.element)
end
function ISRadioWindow:createChildren()
    for _, name in ipairs(VANILLA_MODULES) do
        self:addModule(nil, name, true)
    end
end
function ISRadioWindow:readFromObject(player, device)
    for _, module in ipairs(self.modules) do
        local panel = module.element.subpanel
        if panel then
            module.enabled = panel:readFromObject(player, device, device:getDeviceData(), "InventoryItem")
            module.element:calculateHeights()
        end
    end
end
function ISRadioWindow:layoutModules()
    local y = self.titleH + 1
    for _, module in ipairs(self.modules) do
        module.element.visible = module.enabled
        if module.enabled then
            module.element:setY(y)
            y = y + module.element.height + 1
        end
    end
    self.height = y
end
function ISRadioWindow:prerender()
    self:drawRect(0, 0, self.width, self.height, 0.8, 0, 0, 0)
    self:drawRect(0, 0, self.width, self.titleH, 1, 0.12, 0.12, 0.12)
    self:drawTextCentre(self.title, self.width / 2, 1, 1, 1, 1, 1, UIFont.Small)
end
function ISRadioWindow:render()
    self:drawRectBorder(0, 0, self.width, self.height, 1, 0.4, 0.4, 0.4)
end

loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
loadMod("shared/MilitaryDrop/MilitaryDrop_Exchange.lua")
loadMod("client/MilitaryDrop/MilitaryDrop_Client.lua")
loadMod("client/MilitaryDrop/MilitaryDrop_ExchangeMenu.lua")
loadMod("client/MilitaryDrop/MilitaryDrop_RadioModule.lua")
"""

RENDER = r"""
local width, case = ...
SandboxVars = { MilitaryDrop = { AuthCode = case.codeMode or 3 } }
local data = {
    getIsHighTier = function() return true end,
    getIsPortable = function() return true end,
    getIsTurnedOn = function() return case.on ~= false end,
    getDeviceVolume = function() return 0.5 end,
}
RADIO = { kind = "Radio", getDeviceData = function() return data end, getID = function() return 42 end,
    AddDeviceText = function() end }
local tags = {}
for i = 1, case.tags or 0 do
    tags[i] = { getDisplayName = function() return "Tag " .. i end }
end
MilitaryDrop.ExchangeMenu.dogTags = function() return tags end
PLAYER = {
    getPlayerNum = function() return 0 end,
    Say = function() end,
    getPrimaryHandItem = function() return RADIO end,
    getSecondaryHandItem = function() return nil end,
    getClothingItem_Back = function() return nil end,
}
getSpecificPlayer = function() return PLAYER end
if case.code then
    MilitaryDrop.Client.rememberCode(0, case.code)
end
if case.reply then
    MilitaryDrop.Client.radioSay({ playerNum = 0, device = { getDeviceData = function()
        return { getIsTurnedOn = function() return false end, getDeviceVolume = function() return 0 end } end } },
        case.reply)
end
local window = ISUIElement.new(ISRadioWindow, 0, 0, width, 100)
window.modules, window.title = {}, case.title
window.titleH = fontHeight(UIFont.Small) + 2
window:instantiate()
window:readFromObject(PLAYER, RADIO)
local panel = window.militaryDropModule.element.subpanel
if case.focus then
    panel:setFocusIndex(case.focus)
end
window:layoutModules()
OPS = {}
window:renderTree()
return window.width, window.height
"""

TEXTS = {
    "FR": {"reply": "Station Kilo-7, ici Logistique. Rapport de situation reçu. Restez à l'écoute sur cette "
                    "fréquence, terminé.", "title": "Talkie-walkie militaire",
           "vanilla": ["Général", "Alimentation", "Signal", "Volume", "Microphone", "Canal"]},
    "EN": {"reply": "Station Kilo-7, this is Logistics. Situation report received. Stay tuned on this "
                    "frequency, out.", "title": "Military Walkie Talkie",
           "vanilla": ["General", "Power", "Signal", "Volume", "Microphone", "Channel"]},
}

# (langue, police, largeur de fenêtre, cas)
CASES = [
    ("FR", "1x", 350, "normal", {"code": "BRAVO-KILO-42", "tags": 3, "reply": True}),
    ("EN", "1x", 350, "normal", {"code": "BRAVO-KILO-42", "tags": 3, "reply": True}),
    ("FR", "2x", 400, "normal", {"code": "BRAVO-KILO-42", "tags": 3, "reply": True}),
    ("FR", "1x", 300, "narrow", {"tags": 0, "reply": True}),
    ("FR", "1x", 350, "off", {"on": False, "tags": 1}),
    ("FR", "1x", 350, "nocode", {"codeMode": 1, "tags": 0}),
    ("FR", "1x", 350, "joypad", {"code": "BRAVO-KILO-42", "tags": 0, "focus": 4, "reply": True}),
]


def render(language, size_dir, width, case, extra):
    table = {}
    for path in (base.TRANSLATE / language).glob("*.json"):
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
            fonts[name] = base.Font(base.PZ_FONTS / "EN" / size_dir / base.FONT_FILES[name])
        return fonts[name]

    def text_of(value):
        return value.decode("utf-8", "ignore") if isinstance(value, bytes) else str(value)

    lua = lua_harness.new_runtime()
    g = lua.globals()
    g.getText = get_text
    g.fontHeight = lambda f: font(f).line_height
    g.measureText = lambda f, s: font(f).width(text_of(s))
    g.VANILLA_MODULES = lua.table_from(TEXTS[language]["vanilla"])
    lua.execute(SETUP)
    data = dict(case)
    data["title"] = TEXTS[language]["title"]
    data["reply"] = TEXTS[language]["reply"] if case.get("reply") else None
    w, h = lua.execute(RENDER, width, base.to_lua(lua, data))
    pad = 16
    canvas = base.Canvas(int(w) + 2 * pad, int(h) + 2 * pad, (70, 78, 62))
    for entry in lua.eval("OPS").values():
        args = list(entry.values())
        kind = args[0]
        if kind == "rect":
            _, x, y, rw, rh, r, gg, b, a = args
            canvas.blend(round(x) + pad, round(y) + pad,
                         np.ones((max(0, round(rh)), max(0, round(rw))), dtype=np.float32) * a, (r, gg, b))
        elif kind == "text":
            _, s, x, y, r, gg, b, a, f = args
            font(f).draw(canvas, text_of(s), x + pad, y + pad, (r, gg, b), a)
    return canvas.image()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--extra", action="append", default=[])
    parser.add_argument("--out", default=str(OUT_DIR))
    args = parser.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for language, size_dir, width, name, case in CASES:
        img = render(language, size_dir, width, case, args.extra)
        path = out / f"radio_{language}_{size_dir}_{width}_{name}.png"
        img.save(path)
        print(path, img.size)


if __name__ == "__main__":
    main()
