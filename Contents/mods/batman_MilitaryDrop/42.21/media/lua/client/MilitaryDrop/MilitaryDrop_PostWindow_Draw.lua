-- Military Drop — console du poste de liaison (client) : dessin
-- Partie de MilitaryDrop_PostWindow.lua (voir son en-tête).

require "MilitaryDrop/MilitaryDrop_PostWindow"

local PostWindow = MilitaryDrop.PostWindow
local Config = MilitaryDrop.Config
local U = PostWindow.util
local measure, rect = U.measure, U.rect
local LAMP_KEYS = U.LAMP_KEYS

-- Couleurs de la façade (r, g, b).
local PAINT = { 0.92, 0.9, 0.78 }
local INK = { 0.16, 0.15, 0.13 }
local INK_RED = { 0.62, 0.12, 0.1 }
local AMBER = { 1, 0.7, 0.22 }
local GREEN = { 0.4, 1, 0.42 }
local RED = { 1, 0.28, 0.2 }
local METAL = { 0.34, 0.35, 0.24 }

-- ----------------------------------------------------------------------------
-- Dessin
-- ----------------------------------------------------------------------------

local textures = {}

--- Texture du mod (nil si absente : repli sur des aplats).
local function tex(name)
    local texture = textures[name]
    if texture == nil then
        texture = getTexture(PostWindow.TEXTURE_PATH .. name .. ".png") or false
        textures[name] = texture
    end
    return texture or nil
end

--- Tôle (pavée à sa taille réelle), assombrie par shade.
function PostWindow:drawMetal(x, y, w, h, shade)
    local metal = tex("Metal")
    if metal then
        self:drawTextureTiled(metal, x, y, w, h, shade, shade, shade, 1)
    else
        self:drawRect(x, y, w, h, 1, METAL[1] * shade, METAL[2] * shade, METAL[3] * shade)
    end
end

--- Relief : arête claire en haut à gauche et sombre en bas à droite (raised),
--- ou l'inverse pour un creux.
function PostWindow:drawBevel(x, y, w, h, raised, strength, size)
    size = size or 2
    local light, dark = 0.22 * strength, 0.5 * strength
    local la, da = light, dark
    if not raised then
        la, da = dark, light
    end
    local lr, dr = raised and 1 or 0, raised and 0 or 1
    self:drawRect(x, y, w, size, la, lr, lr, lr * 0.9)
    self:drawRect(x, y + size, size, h - size, la, lr, lr, lr * 0.9)
    self:drawRect(x, y + h - size, w, size, da, dr, dr, dr * 0.9)
    self:drawRect(x + w - size, y, size, h - size, da, dr, dr, dr * 0.9)
end

--- Libellé peint au pochoir (blanc cassé, ombre légère).
function PostWindow:drawPaint(text, x, y, font, alpha, align)
    font = font or UIFont.Small
    alpha = alpha or 1
    if align == "right" then
        x = x - measure(text, font)
    elseif align == "center" then
        x = x - measure(text, font) / 2
    end
    self:drawText(text, x + 1, y + 1, 0.05, 0.06, 0.02, 0.55 * alpha, font)
    self:drawText(text, x, y, PAINT[1], PAINT[2], PAINT[3], 0.92 * alpha, font)
end

function PostWindow:drawScrew(cx, cy, size)
    local screw = tex("Screw")
    if screw then
        self:drawTextureScaled(screw, cx - size / 2, cy - size / 2, size, size, 1)
    else
        self:drawRect(cx - size / 4, cy - size / 4, size / 2, size / 2, 1, 0.6, 0.6, 0.55)
    end
end

--- Voyant rond : verre teinté (allumé ou éteint), halo, sertissage.
function PostWindow:drawLamp(cx, cy, d, lit, color, intensity)
    intensity = intensity or 1
    local glow, glass, bezel = tex("LampGlow"), tex("LampGlass"), tex("LampBezel")
    local r, g, b = color[1], color[2], color[3]
    if lit and glow then
        local s = d * 2.6
        self:drawTextureScaled(glow, cx - s / 2, cy - s / 2, s, s, 0.75 * intensity, r, g, b)
    end
    local k = lit and (0.6 + 0.4 * intensity) or 0.22
    if glass then
        self:drawTextureScaled(glass, cx - d / 2, cy - d / 2, d, d, 1, r * k, g * k, b * k)
    else
        self:drawRect(cx - d / 3, cy - d / 3, d * 2 / 3, d * 2 / 3, 1, r * k, g * k, b * k)
    end
    if lit and glow then
        -- Cœur chauffé à blanc du voyant allumé.
        local s = d * 0.7
        self:drawTextureScaled(glow, cx - s / 2, cy - s / 2, s, s, 0.8 * intensity, 1, 1, 0.92)
    end
    if bezel then
        self:drawTextureScaled(bezel, cx - d / 2, cy - d / 2, d, d, 1)
    end
end

--- Bouton dessiné : plaque d'aluminium ou caoutchouc, relief, libellé.
function PostWindow:drawButton(r, label, enabled, hover, pressed, rubber, joypadTexture)
    local plate = tex(rubber and "ButtonRubber" or "Button")
    local dy = pressed and 1 or 0
    self:drawRect(r.x - 1, r.y - 1, r.w + 2, r.h + 2, 0.8, 0.05, 0.05, 0.03)
    local shade = enabled and (hover and 1.12 or 1) or 0.6
    if pressed then
        shade = 0.85
    end
    if plate then
        self:drawTextureScaled(plate, r.x, r.y + dy, r.w, r.h - dy, 1, shade, shade, shade)
    else
        local base = rubber and 0.2 or 0.58
        self:drawRect(r.x, r.y + dy, r.w, r.h - dy, 1, base * shade, base * shade, base * shade)
    end
    if not pressed then
        self:drawBevel(r.x, r.y, r.w, r.h, true, rubber and 0.6 or 1, 1)
    end
    local fh = self.L.fh
    local textX = r.x + r.w / 2
    if joypadTexture then
        local size = fh
        self:drawTextureScaled(joypadTexture, r.x + self.L.u, r.y + (r.h - size) / 2 + dy, size, size, enabled and 1 or 0.4)
        textX = textX + size / 2
    end
    local text = PostWindow.fit(label, UIFont.Small, r.w - 2 * self.L.u - (joypadTexture and fh or 0))
    local ty = r.y + (r.h - fh) / 2 + dy
    if rubber then
        local c = enabled and AMBER or { 0.45, 0.42, 0.36 }
        self:drawTextCentre(text, textX, ty, c[1], c[2], c[3], 1, UIFont.Small)
    else
        local a = enabled and 1 or 0.45
        self:drawTextCentre(text, textX + 1, ty + 1, 1, 1, 1, 0.35 * a, UIFont.Small)
        self:drawTextCentre(text, textX, ty, INK[1], INK[2], INK[3], a, UIFont.Small)
    end
end

--- Façade : tôle, relief, rainure intérieure, vis aux coins.
function PostWindow:drawFace()
    local L, w, h = self.L, self.width, self.height
    self:drawRect(0, 0, w, h, 1, 0.06, 0.07, 0.04)
    self:drawMetal(1, 1, w - 2, h - 2, 1)
    self:drawBevel(1, 1, w - 2, h - 2, true, 1, 2)
    local g = L.frame - 4
    self:drawBevel(g, g, w - 2 * g, h - 2 * g, false, 0.8, 1)
    local s = math.max(12, math.floor(L.fh * 0.8))
    local c = math.floor(L.frame / 2) + 1
    self:drawScrew(c, c, s)
    self:drawScrew(w - c, c, s)
    self:drawScrew(c, h - c, s)
    self:drawScrew(w - c, h - c, s)
end

--- Compartiment en creux (ordres, casier, confiance) avec son libellé peint.
function PostWindow:drawCompartment(r, label, extra)
    local u = self.L.u
    self:drawMetal(r.x, r.y, r.w, r.h, 0.78)
    self:drawBevel(r.x, r.y, r.w, r.h, false, 1, 2)
    self:drawPaint(label, r.x + u, r.y + math.floor(u / 2))
    if extra then
        self:drawText(extra, r.x + r.w - u - measure(extra), r.y + math.floor(u / 2), PAINT[1], PAINT[2], PAINT[3], 0.6,
            UIFont.Small)
    end
end

function PostWindow:drawHeader(hover)
    local L = self.L
    local r = L.header
    self:drawPaint(getText("IGUI_MilitaryDrop_PostConsoleTitle"), r.x + L.u, r.y + (r.h - L.fm) / 2, UIFont.Medium)
    -- Filet peint sous le titre.
    self:drawRect(r.x + L.u, r.y + r.h - 3, L.close.x - r.x - 3 * L.u, 1, 0.35, PAINT[1], PAINT[2], PAINT[3])
    local c = L.close
    self:drawButton(c, "X", true, hover == "close", self.pressed == "close", false, nil)
end

function PostWindow:drawStatus()
    local L, data = self.L, self.data
    local lamps = PostWindow.lamps(data)
    local now = getTimestampMs()
    local cy = L.status.y + L.statusH / 2
    local x = L.status.x + L.u
    local labelY = cy - L.fh / 2
    local states = {
        { lit = lamps.on, color = GREEN, intensity = 1 },
        { lit = lamps.rx, color = AMBER, intensity = 1 },
        { lit = lamps.power, color = lamps.level == "battery" and AMBER or (lamps.level == "low" and RED or GREEN),
            intensity = 1 },
    }
    if lamps.rx and now < self.rxFlashUntil then
        states[2].intensity = 0.5 + 0.5 * math.abs(math.sin(now / 120))
    end
    for i, key in ipairs(LAMP_KEYS) do
        local state = states[i]
        self:drawLamp(x + L.lampD / 2, cy, L.lampD, state.lit, state.color, state.intensity)
        x = x + L.lampD + L.u
        self:drawPaint(getText(key), x, labelY)
        x = x + L.lampLabelW[i] + 2 * L.u
    end
    -- Source d'alimentation et jauge de la pile si le serveur l'envoie.
    x = x - L.u
    local word = getText("IGUI_MilitaryDrop_PostPower_" .. tostring(data.power or "none"))
    self:drawText(word, x, labelY, PAINT[1], PAINT[2], PAINT[3], 0.7, UIFont.Small)
    if lamps.battery then
        local gx = x + measure(word) + L.u
        local segW = math.max(4, math.floor(L.fh / 3))
        local filled = math.ceil(lamps.battery * 4 - 0.01)
        local color = lamps.level == "low" and RED or GREEN
        for i = 1, 4 do
            local sx = gx + (i - 1) * (segW + 1)
            self:drawRect(sx, cy - L.fh / 3, segW, L.fh * 2 / 3, 0.9, 0.05, 0.06, 0.03)
            if i <= filled then
                self:drawRect(sx + 1, cy - L.fh / 3 + 1, segW - 2, L.fh * 2 / 3 - 2, 0.95, color[1], color[2], color[3])
            end
        end
    end
    -- Ruban de l'étiqueteuse : indicatif en lettres blanches en relief.
    local t = L.tape
    local tape = tex("Tape")
    if tape then
        self:drawTextureScaled(tape, t.x, t.y, t.w, t.h, 1)
    else
        self:drawRect(t.x, t.y, t.w, t.h, 1, 0.08, 0.08, 0.09)
    end
    local callsign = PostWindow.fit(tostring(data.callsign or ""), UIFont.Small, t.w - 2 * L.u)
    local ty = t.y + (t.h - L.fh) / 2
    self:drawTextCentre(callsign, t.x + t.w / 2, ty + 1, 0, 0, 0, 0.8, UIFont.Small)
    self:drawTextCentre(callsign, t.x + t.w / 2, ty, 0.93, 0.93, 0.9, 1, UIFont.Small)
    -- Afficheur de fréquence : ambre allumé, éteint sans courant.
    local f = L.freq
    self:drawRect(f.x - 1, f.y - 1, f.w + 2, f.h + 2, 1, 0.03, 0.03, 0.02)
    self:drawRect(f.x, f.y, f.w, f.h, 1, 0.1, 0.07, 0.02)
    local fy = f.y + (f.h - L.lh) / 2
    if lamps.on then
        local text = getText("IGUI_MilitaryDrop_PostFrequency", Config.formatChannel(tonumber(data.channel) or 0))
        self:drawTextRight(text, f.x + f.w - L.u, fy, AMBER[1], AMBER[2], AMBER[3], 1, L.mono)
    else
        self:drawTextRight(getText("IGUI_MilitaryDrop_PostFrequency", "---.-"), f.x + f.w - L.u, fy, 0.3, 0.2, 0.06, 1,
            L.mono)
    end
    self:drawRect(f.x, f.y, f.w, math.floor(f.h / 2), 0.06, 1, 1, 1)
end

--- Écran : cadre de caoutchouc, verre à phosphore (sous le texte du journal).
function PostWindow:drawScreen()
    local L = self.L
    self:drawPaint(getText("IGUI_MilitaryDrop_PostLogHeader"), L.bezelRect.x + L.u, L.screenLabelY)
    local b = L.bezelRect
    self:drawRect(b.x, b.y, b.w, b.h, 1, 0.07, 0.075, 0.06)
    self:drawBevel(b.x, b.y, b.w, b.h, false, 1, 2)
    local s = L.screen
    local glass = tex("Screen")
    if glass then
        self:drawTextureScaled(glass, s.x, s.y, s.w, s.h, 1)
    else
        self:drawRect(s.x, s.y, s.w, s.h, 1, 0.03, 0.09, 0.05)
    end
end

--- Par-dessus le texte : lignes de balayage, curseur, témoin de défilement.
function PostWindow:drawScreenOverlay()
    local L, journal = self.L, self.journal
    local s = L.screen
    local scan = tex("Scanlines")
    if scan then
        self:drawTextureTiled(scan, s.x, s.y, s.w, s.h, 1, 1, 1, 1)
    end
    local total = journal:getScrollHeight()
    local view = journal:getHeight()
    local track = L.scrollTrack
    if total > view + 1 then
        local thumb = math.max(L.lh, math.floor(track.h * view / total))
        local offset = math.floor((track.h - thumb) * (-journal:getYScroll()) / (total - view))
        self:drawRect(track.x, track.y, track.w, track.h, 0.25, 0.3, 0.8, 0.35)
        self:drawRect(track.x, track.y + offset, track.w, thumb, 0.8, 0.5, 1, 0.55)
    end
    -- Curseur de téléimprimeur qui clignote sous la dernière ligne.
    local lineY = journal.lineY
    if lineY and #lineY > 0 and math.floor(getTimestampMs() / 530) % 2 == 0 then
        local y = journal:getY() + lineY[#lineY] + L.lh + journal:getYScroll()
        if y >= journal:getY() and y + L.lh <= journal:getY() + journal:getHeight() then
            self:drawRect(journal:getX(), y + 2, math.floor(L.lh * 0.5), L.lh - 4, 0.85, 0.55, 1, 0.6)
        end
    end
end

--- Ordre de mission : fiche de papier tapée, échéance, barre.
function PostWindow:drawOrder(r, mission, hover)
    local L = self.L
    local u = L.u
    local view = PostWindow.missionView(mission)
    local paper = tex("Paper")
    self:drawRect(r.x + 2, r.y + 3, r.w, r.h, 0.45, 0, 0, 0)
    if paper then
        self:drawTextureTiled(paper, r.x, r.y, r.w, r.h, 1, 1, 1, 1)
    else
        self:drawRect(r.x, r.y, r.w, r.h, 1, 0.9, 0.87, 0.78)
    end
    if hover then
        self:drawRect(r.x, r.y, r.w, r.h, 0.12, 1, 1, 0.8)
    end
    -- Marge rouge du formulaire.
    self:drawRect(r.x + u, r.y, 1, r.h, 0.55, INK_RED[1], INK_RED[2], INK_RED[3])
    local tx = r.x + 2 * u
    local inner = r.w - 3 * u
    local dueW = measure(view.due)
    local title = PostWindow.fit(view.title, UIFont.Small, inner - dueW - u)
    self:drawText(title, tx, r.y + u / 2, INK[1], INK[2], INK[3], 1, UIFont.Small)
    if view.due ~= "" then
        local c = (view.bar and view.bar.urgent) and INK_RED or INK
        self:drawTextRight(view.due, r.x + r.w - u, r.y + u / 2, c[1], c[2], c[3], 1, UIFont.Small)
    end
    if view.sub ~= "" then
        self:drawText(PostWindow.fit(view.sub, UIFont.Small, inner), tx, r.y + u / 2 + L.fh, 0.3, 0.28, 0.24, 1,
            UIFont.Small)
    end
    local bar = view.bar
    if bar then
        local labelW = bar.label ~= "" and (measure(bar.label) + u) or 0
        local bx, by = tx, r.y + r.h - u - L.barH
        local segW = math.max(4, math.floor(L.barH * 1.2))
        local count = math.max(1, math.floor((r.x + r.w - u - labelW - bx - 2) / (segW + 1)))
        local bw = count * (segW + 1) + 1
        self:drawRect(bx, by, bw, L.barH, 1, 0.22, 0.2, 0.16)
        local filled = math.floor(bar.fraction * count + 0.5)
        local color = bar.urgent and { 0.75, 0.18, 0.12 } or (bar.kind == "progress" and { 0.36, 0.42, 0.2 } or
            { 0.25, 0.3, 0.18 })
        for i = 1, count do
            local sx = bx + 1 + (i - 1) * (segW + 1)
            if i <= filled then
                self:drawRect(sx, by + 1, segW, L.barH - 2, 1, color[1], color[2], color[3])
            else
                self:drawRect(sx, by + 1, segW, L.barH - 2, 1, 0.78, 0.74, 0.62)
            end
        end
        if labelW > 0 then
            self:drawTextRight(bar.label, r.x + r.w - u, by + (L.barH - L.fh) / 2, INK[1], INK[2], INK[3], 1, UIFont.Small)
        end
    end
    if view.done then
        local stamp = getText("IGUI_MilitaryDrop_PostControlDone")
        self:drawTextRight(PostWindow.fit(stamp, UIFont.Small, inner / 2), r.x + r.w - u, r.y + u / 2 + L.fh,
            INK_RED[1], INK_RED[2], INK_RED[3], 0.9, UIFont.Small)
    end
end

--- Plaque d'identité gravée au nom du soldat.
function PostWindow:drawTag(r, entry, hover)
    local L = self.L
    local tag = tex("DogTag")
    local h = r.h
    local w = math.min(r.w, h * 4)
    if tag then
        self:drawTextureScaled(tag, r.x, r.y, w, h, 1, hover and 1.1 or 1, hover and 1.1 or 1, hover and 1.05 or 1)
    else
        self:drawRect(r.x, r.y + 2, w, h - 4, 1, 0.7, 0.7, 0.72)
    end
    local textX = r.x + h * 0.5
    local name = PostWindow.fit(PostWindow.mailName(entry), L.mono, w - h * 0.5 - h * 0.35)
    local ty = r.y + (h - L.lh) / 2
    self:drawText(name, textX + 1, ty + 1, 1, 1, 1, 0.45, L.mono)
    self:drawText(name, textX, ty, 0.18, 0.19, 0.2, 1, L.mono)
end

local LAMP_COLORS = { green = GREEN, amber = AMBER, red = RED }

--- Liste des affaires : en-têtes peints, lignes de papier avec l'icône de
--- l'objet du jeu, titre, état et voyant ; la ligne choisie est cerclée d'ambre.
function PostWindow:drawAffairs(hover, payload)
    local L = self.L
    local u = L.u
    self:drawCompartment(L.list, getText("IGUI_MilitaryDrop_PostAffairs"))
    local paper = tex("Paper")
    local rows, hidden = self:affairRows()
    for _, row in ipairs(rows) do
        local entry, r = row.entry, row.r
        if entry.kind == "header" then
            self:drawText(PostWindow.fit(entry.text, UIFont.Small, r.w), r.x + 2, r.y + 1, AMBER[1], AMBER[2], AMBER[3], 0.9,
                UIFont.Small)
        elseif entry.kind == "empty" then
            self:drawText(PostWindow.fit(entry.text, UIFont.Small, r.w), r.x + 2, r.y + 1, PAINT[1], PAINT[2], PAINT[3], 0.55,
                UIFont.Small)
        else
            local selected = entry.key == self.selectedKey
            self:drawRect(r.x + 2, r.y + 2, r.w, r.h, 0.4, 0, 0, 0)
            if paper then
                self:drawTextureTiled(paper, r.x, r.y, r.w, r.h, 1, 1, 1, 1)
            else
                self:drawRect(r.x, r.y, r.w, r.h, 1, 0.9, 0.87, 0.78)
            end
            if hover == "affair" and payload == entry then
                self:drawRect(r.x, r.y, r.w, r.h, 0.12, 1, 1, 0.8)
            end
            if selected then
                self:drawRectBorder(r.x - 1, r.y - 1, r.w + 2, r.h + 2, 1, AMBER[1], AMBER[2], AMBER[3])
                self:drawRectBorder(r.x, r.y, r.w, r.h, 1, AMBER[1], AMBER[2], AMBER[3])
            end
            local tx = r.x + u
            local icon = entry.icon and PostWindow.itemIcon(entry.icon)
            if icon then
                local s = L.iconSize
                self:drawTextureScaled(icon, r.x + math.floor(u / 2), r.y + math.floor((r.h - s) / 2), s, s, 1)
                tx = r.x + math.floor(u / 2) + s + math.floor(u / 2)
            end
            local lampD = math.floor(L.fh * 0.7)
            local right = r.x + r.w - u
            if entry.lamp then
                self:drawLamp(right - lampD / 2, r.y + r.h / 2, lampD, true, LAMP_COLORS[entry.lamp] or AMBER, 0.8)
                right = right - lampD - math.floor(u / 2)
            end
            local w = right - tx
            if entry.kind == "mission" and entry.due ~= "" then
                local dueW = measure(entry.due)
                self:drawTextRight(entry.due, right, r.y + math.floor(u / 2), INK[1], INK[2], INK[3], 1, UIFont.Small)
                self:drawText(PostWindow.fit(entry.title, UIFont.Small, w - dueW - u), tx, r.y + math.floor(u / 2),
                    INK[1], INK[2], INK[3], 1, UIFont.Small)
            else
                self:drawText(PostWindow.fit(entry.title, UIFont.Small, w), tx, r.y + math.floor(u / 2), INK[1], INK[2],
                    INK[3], 1, UIFont.Small)
            end
            local sub = entry.sub or ""
            if entry.kind == "bay" and type(self.data.bay) == "table" then
                -- Même valeur que la barre du volet, pas l'instantané de la liste.
                sub = PostWindow.bayStatus(self.data.bay, self:bayProgress())
            end
            self:drawText(PostWindow.fit(sub, UIFont.Small, w), tx, r.y + math.floor(u / 2) + L.fh, 0.3, 0.28,
                0.24, 1, UIFont.Small)
        end
    end
    if hidden > 0 then
        self:drawPaint("+" .. hidden, L.list.x + L.list.w - u, L.list.y + L.list.h - L.fh - 2, nil, 0.8, "right")
    end
end

--- Ruban de l'étiqueteuse en tête du volet (titre de l'affaire).
function PostWindow:drawDetailTape(text)
    local L = self.L
    local t = L.detailTape
    local w = math.min(t.w, measure(text) + 3 * L.u)
    local tape = tex("Tape")
    if tape then
        self:drawTextureScaled(tape, t.x, t.y, w, t.h, 1)
    else
        self:drawRect(t.x, t.y, w, t.h, 1, 0.08, 0.08, 0.09)
    end
    local label = PostWindow.fit(text, UIFont.Small, w - 2 * L.u)
    local ty = t.y + (t.h - L.fh) / 2
    self:drawText(label, t.x + L.u + 1, ty + 1, 0, 0, 0, 0.8, UIFont.Small)
    self:drawText(label, t.x + L.u, ty, 0.93, 0.93, 0.9, 1, UIFont.Small)
end

--- Feuille de papier avec des lignes tapées (fiche du crash).
function PostWindow:drawSheet(r, lines)
    local L = self.L
    local paper = tex("Paper")
    self:drawRect(r.x + 2, r.y + 3, r.w, r.h, 0.45, 0, 0, 0)
    if paper then
        self:drawTextureTiled(paper, r.x, r.y, r.w, r.h, 1, 1, 1, 1)
    else
        self:drawRect(r.x, r.y, r.w, r.h, 1, 0.9, 0.87, 0.78)
    end
    self:drawRect(r.x + L.u, r.y, 1, r.h, 0.55, INK_RED[1], INK_RED[2], INK_RED[3])
    local y = r.y + math.floor(L.u / 2)
    for _, line in ipairs(lines) do
        self:drawText(PostWindow.fit(line, UIFont.Small, r.w - 3 * L.u), r.x + 2 * L.u, y, INK[1], INK[2], INK[3], 1,
            UIFont.Small)
        y = y + L.fh
    end
end

--- Volet d'un enregistreur : fiche du crash, baie de lecture, consigne.
function PostWindow:drawRecorderDetail(entry)
    local L, data = self.L, self.data
    local u = L.u
    local bay = data.bay
    local inBay = entry.kind == "bay"
    local source = inBay and bay or entry
    self:drawDetailTape(getText("IGUI_MilitaryDrop_PostRecorderTitle", tostring(entry.site)))
    local lines = {}
    if tonumber(source.cc) then
        lines[#lines + 1] = getText("IGUI_MilitaryDrop_PostRecorderCrash", PostWindow.stamp(source.cc))
    end
    if tonumber(source.cx) and tonumber(source.cy) then
        lines[#lines + 1] = getText("IGUI_MilitaryDrop_PostGrid", tostring(math.floor(source.cx)),
            tostring(math.floor(source.cy)))
    end
    lines[#lines + 1] = getText("IGUI_MilitaryDrop_PostRecorderOrigin")
    self:drawSheet(L.info, lines)

    -- Baie : creux de tôle, logement noir, enregistreur, barre segmentée.
    local w = L.well
    self:drawMetal(w.x, w.y, w.w, w.h, 0.62)
    self:drawBevel(w.x, w.y, w.w, w.h, false, 1, 2)
    local b = L.box
    self:drawRect(b.x - 1, b.y - 1, b.w + 2, b.h + 2, 1, 0.02, 0.02, 0.015)
    self:drawRect(b.x, b.y, b.w, b.h, 1, 0.07, 0.075, 0.05)
    self:drawBevel(b.x, b.y, b.w, b.h, false, 1, 2)
    local fraction, label, color = 0, getText("IGUI_MilitaryDrop_PostBayEmpty"), GREEN
    local stateText
    if bay then
        local icon = PostWindow.itemIcon(PostWindow.RECORDER_TYPE)
        if icon and inBay then
            local s = math.floor(b.w * 0.8)
            self:drawTextureScaled(icon, b.x + (b.w - s) / 2, b.y + (b.h - s) / 2, s, s, 1)
        end
        fraction = inBay and self:bayProgress() or 0
        label = inBay and getText("IGUI_MilitaryDrop_PostBay")
            or getText("IGUI_MilitaryDrop_PostBayBusy", tostring(bay.site))
        if inBay then
            stateText = PostWindow.bayStatus(bay, fraction)
            if bay.paused then
                color = RED
            elseif not bay.done then
                color = AMBER
            end
        end
    end
    self:drawPaint(PostWindow.fit(label, UIFont.Small, w.x + w.w - u - L.bayLabel.x), L.bayLabel.x, L.bayLabel.y)
    local p = L.progress
    local count = PostWindow.BAY_SEGMENTS
    local percent = string.format("%d%%", math.floor(fraction * 100))
    local percentW = measure("100%", L.mono) + u
    local segW = math.max(3, math.floor((p.w - percentW - (count - 1)) / count))
    local filled = math.floor(fraction * count + 0.0001)
    for i = 1, count do
        local sx = p.x + (i - 1) * (segW + 1)
        self:drawRect(sx, p.y, segW, p.h, 1, 0.05, 0.07, 0.04)
        if i <= filled then
            self:drawRect(sx + 1, p.y + 1, segW - 2, p.h - 2, 0.95, color[1], color[2], color[3])
        end
    end
    if inBay then
        self:drawTextRight(percent, p.x + p.w, p.y + (p.h - L.lh) / 2, color[1], color[2], color[3], 1, L.mono)
        self:drawText(PostWindow.fit(stateText, UIFont.Small, w.x + w.w - u - L.bayState.x), L.bayState.x, L.bayState.y,
            PAINT[1], PAINT[2], PAINT[3], 0.85, UIFont.Small)
    end

    -- Consigne sous la baie.
    local hint
    if inBay and bay.done then
        hint = getText("IGUI_MilitaryDrop_PostRecorderDoneHint")
    elseif inBay and bay.paused then
        hint = getText("IGUI_MilitaryDrop_PostRecorderPausedHint")
    elseif inBay then
        local left = tonumber(bay.minutesLeft) or 0
        local total = tonumber(bay.total)
        if total and total > 0 then
            left = math.max(1, math.ceil((1 - self:bayProgress()) * total * 60))
        end
        hint = getText("IGUI_MilitaryDrop_PostRecorderLeft", tostring(left))
    else
        hint = getText("IGUI_MilitaryDrop_PostRecorderInsertHint")
    end
    local y = L.hint.y
    for _, line in ipairs(PostWindow.wrap(hint, UIFont.Small, L.hint.w)) do
        if y + L.fh > L.hint.y + L.hint.h then
            break
        end
        self:drawText(line, L.hint.x, y, AMBER[1], AMBER[2], AMBER[3], 0.9, UIFont.Small)
        y = y + L.fh
    end
end

--- Volet des plaques : casier en alvéoles, consigne.
function PostWindow:drawTagsDetail(hover, payload)
    local L, data = self.L, self.data
    local mail = data.mail or {}
    self:drawDetailTape(getText("IGUI_MilitaryDrop_PostRack"))
    for i, slot in ipairs(L.slots) do
        self:drawRect(slot.x, slot.y, slot.w, slot.h, 0.45, 0.02, 0.03, 0.01)
        self:drawBevel(slot.x, slot.y, slot.w, slot.h, false, 0.7, 1)
        local entry = mail[i + self.rackScroll * 2]
        if entry then
            self:drawTag(rect(slot.x + 2, slot.y + 1, slot.w - 4, slot.h - 2), entry, hover == "tag" and payload == entry)
        end
    end
    local hidden = #mail - #L.slots - self.rackScroll * 2
    if hidden > 0 then
        local last = L.slots[#L.slots]
        self:drawPaint("+" .. hidden, last.x + last.w, last.y + last.h + 1, nil, 0.8, "right")
    end
    local hint = #mail == 0 and getText("IGUI_MilitaryDrop_PostMailEmpty") or getText("IGUI_MilitaryDrop_PostTagsHint")
    self:drawText(PostWindow.fit(hint, UIFont.Small, L.tagsHint.w), L.tagsHint.x, L.tagsHint.y, PAINT[1], PAINT[2],
        PAINT[3], 0.7, UIFont.Small)
end

--- Volet d'une mission : fiche de l'ordre, puis texte complet de la base.
function PostWindow:drawMissionDetail(entry, hover)
    local L = self.L
    self:drawDetailTape(string.upper(tostring(entry.title or "")))
    self:drawOrder(L.missionCard, entry.mission, hover == "mission")
    local box = L.missionText
    local y = box.y
    local body = PostWindow.missionText(entry.mission)
    for _, line in ipairs(PostWindow.wrap(body, UIFont.Small, box.w)) do
        if y + L.fh > box.y + box.h then
            break
        end
        self:drawText(line, box.x, y, PAINT[1], PAINT[2], PAINT[3], 0.9, UIFont.Small)
        y = y + L.fh
    end
end

--- Volet de l'affaire choisie et ses boutons (A à droite, X à gauche).
function PostWindow:drawDetail(hover, payload)
    local L = self.L
    self:drawMetal(L.detail.x, L.detail.y, L.detail.w, L.detail.h, 0.78)
    self:drawBevel(L.detail.x, L.detail.y, L.detail.w, L.detail.h, false, 1, 2)
    local entry = self:selectedAffair()
    if not entry then
        return
    end
    if entry.kind == "bay" or entry.kind == "recorder" then
        self:drawRecorderDetail(entry)
    elseif entry.kind == "tags" then
        self:drawTagsDetail(hover, payload)
    elseif entry.kind == "mission" then
        self:drawMissionDetail(entry, hover)
    elseif entry.kind == "exchange" then
        self:drawDetailTape(entry.title)
        local option = MilitaryDrop.ExchangeMenu.optionFor(entry.source)
        local box = L.missionText
        local y = L.detailTop
        local text = getText(option.tooltip)
        if entry.sub ~= text then
            text = text .. " " .. entry.sub
        end
        for _, line in ipairs(PostWindow.wrap(text, UIFont.Small, box.w)) do
            if y + L.fh > L.btnA.y - L.u then
                break
            end
            self:drawText(line, box.x, y, PAINT[1], PAINT[2], PAINT[3], 0.9, UIFont.Small)
            y = y + L.fh
        end
    end
    local primary, secondary = self:actions()
    local joypad = self.drawJoypadFocus and Joypad and Joypad.Texture
    if secondary then
        self:drawButton(L.btnB, secondary.text, secondary.enabled, hover == "secondary", self.pressed == "secondary",
            false, joypad and Joypad.Texture.XButton or nil)
    end
    if primary then
        self:drawButton(L.btnA, primary.text, primary.enabled, hover == "primary", self.pressed == "primary", true,
            joypad and Joypad.Texture.AButton or nil)
    end
end

--- Bande du bas : confiance en toutes lettres (sur une ligne, entière dans
--- l'infobulle), libellé du code, bouton d'appel.
function PostWindow:drawStrip(hover)
    local L, data = self.L, self.data
    -- Creux dessiné dans prerender : le champ du code (enfant) passe entre les deux.
    self:drawPaint(getText("IGUI_MilitaryDrop_PostStanding"), L.standLabelPos.x, L.standLabelPos.y)
    local box = L.standText
    local alpha = hover == "standing" and 1 or 0.92
    local trust = PostWindow.trustText(data)
    local effect = PostWindow.effectText(data)
    local trustColor = data.lineCut and { 1, 0.45, 0.35 } or PAINT
    local trustText = PostWindow.fit(trust, UIFont.Small, box.w)
    self:drawText(trustText, box.x, L.standLabelPos.y, trustColor[1], trustColor[2], trustColor[3], alpha, UIFont.Small)
    local used = measure(trustText) + L.u
    if effect ~= "" and box.w - used > L.fh * 3 then
        self:drawText(PostWindow.fit("- " .. effect, UIFont.Small, box.w - used), box.x + used, L.standLabelPos.y,
            AMBER[1], AMBER[2], AMBER[3], alpha * 0.9, UIFont.Small)
    end
    if L.codeShown then
        self:drawPaint(L.codeLabel, L.codeLabelPos.x, L.codeLabelPos.y)
    end
    local joypad = self.drawJoypadFocus and Joypad and Joypad.Texture
    self:drawButton(L.request, getText("IGUI_MilitaryDrop_RequestDrop"), self:canRequest(), hover == "request",
        self.pressed == "request", false, joypad and Joypad.Texture.YButton or nil)
end

function PostWindow:prerender()
    if not self.L or not self.data then
        return
    end
    self:drawFace()
    self:drawScreen()
    -- Sous le champ du code (enfant dessiné après prerender, avant render).
    local s = self.L.strip
    self:drawMetal(s.x, s.y, s.w, s.h, 0.78)
    self:drawBevel(s.x, s.y, s.w, s.h, false, 1, 2)
end

function PostWindow:render()
    if not self.L or not self.data then
        return
    end
    local hover, payload = self:mouseTarget()
    self:drawScreenOverlay()
    self:drawHeader(hover)
    self:drawStatus()
    self:drawAffairs(hover, payload)
    self:drawDetail(hover, payload)
    self:drawStrip(hover)
    if self.drawJoypadFocus then
        self:drawRectBorder(0, 0, self.width, self.height, 0.9, AMBER[1], AMBER[2], AMBER[3])
    end
end

return PostWindow
