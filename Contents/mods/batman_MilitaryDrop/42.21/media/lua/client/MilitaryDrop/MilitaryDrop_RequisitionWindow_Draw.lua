-- Military Drop — formulaire de réquisition (client) : dessin
-- Partie de MilitaryDrop_RequisitionWindow.lua (voir son en-tête).

require "MilitaryDrop/MilitaryDrop_RequisitionWindow"

local RW = MilitaryDrop.RequisitionWindow
local U = RW.util
local measure, fontHeight, BUDGET_KEYS = U.measure, U.fontHeight, U.BUDGET_KEYS

-- Encres (r, g, b).
local INK = { 0.13, 0.12, 0.11 }
local RED = { 0.66, 0.1, 0.08 }
local BLUE = { 0.1, 0.2, 0.52 }
local MARKER = { 1, 0.9, 0.3 }
local PAINT = { 0.92, 0.9, 0.78 }

-- ----------------------------------------------------------------------------
-- Dessin
-- ----------------------------------------------------------------------------

local textures = {}

--- Texture du mod (nil si absente : repli sur des aplats).
local function tex(path)
    local texture = textures[path]
    if texture == nil then
        texture = getTexture(path) or false
        textures[path] = texture
    end
    return texture or nil
end

local function formTex(name)
    return tex(RW.TEXTURE_PATH .. name .. ".png")
end

local function postTex(name)
    return tex(RW.POST_TEXTURE_PATH .. name .. ".png")
end

--- Texte dactylographié : encre, léger empâtement du ruban.
function RW:type(text, x, y, color, alpha, font)
    color = color or INK
    alpha = alpha or 1
    font = font or self.L.font
    self:drawText(text, x + 1, y, color[1], color[2], color[3], 0.12 * alpha, font)
    self:drawText(text, x, y, color[1], color[2], color[3], 0.92 * alpha, font)
end

function RW:typeRight(text, right, y, color, alpha, font)
    self:type(text, right - measure(text, font or self.L.font), y, color, alpha, font)
end

function RW:typeCentre(text, cx, y, color, alpha, font)
    self:type(text, cx - measure(text, font or self.L.font) / 2, y, color, alpha, font)
end

--- Filet imprimé du formulaire.
function RW:rule(x, y, w, alpha)
    self:drawRect(x, y, w, 1, alpha or 0.55, INK[1], INK[2], INK[3])
end

--- Case imprimée (cadre d'encre) ; fill : fond plus clair ou survol.
function RW:printedBox(r, alpha, fill)
    if fill then
        self:drawRect(r.x, r.y, r.w, r.h, fill[4], fill[1], fill[2], fill[3])
    end
    self:drawRectBorder(r.x, r.y, r.w, r.h, alpha or 0.7, INK[1], INK[2], INK[3])
end

--- Bouton − ou + imprimé dans une case.
function RW:stepButton(r, sign, enabled, hover, pressed)
    local fill = nil
    if enabled and pressed then
        fill = { INK[1], INK[2], INK[3], 0.22 }
    elseif enabled and hover then
        fill = { INK[1], INK[2], INK[3], 0.1 }
    end
    self:printedBox(r, enabled and 0.75 or 0.22, fill)
    local L = self.L
    local alpha = enabled and 1 or 0.25
    local cx, cy = r.x + r.w / 2, r.y + r.h / 2
    local arm = math.max(2, math.floor(r.w * 0.28))
    local stroke = math.max(1, math.floor(L.fh / 12))
    self:drawRect(cx - arm, cy - stroke / 2, 2 * arm, stroke, 0.9 * alpha, INK[1], INK[2], INK[3])
    if sign == "+" then
        self:drawRect(cx - stroke / 2, cy - arm, stroke, 2 * arm, 0.9 * alpha, INK[1], INK[2], INK[3])
    end
end

--- Bouton de page (< ou >) imprimé dans une case.
function RW:pageButton(r, sign, enabled, hover, pressed)
    local fill = nil
    if enabled and (hover or pressed) then
        fill = { INK[1], INK[2], INK[3], pressed and 0.22 or 0.1 }
    end
    self:printedBox(r, enabled and 0.75 or 0.22, fill)
    local L = self.L
    self:typeCentre(sign, r.x + r.w / 2, r.y + math.floor((r.h - L.fh) / 2), INK, enabled and 1 or 0.25)
end

--- Chiffres ou croix écrits à la main, centrés sur (cx, cy), à l'encre bleue.
--- La police manuscrite a une taille fixe (40 px, chiffres d'environ 20 px) :
--- agrandie avec les cases quand la police de l'interface grandit.
function RW:handwrite(text, cx, cy, alpha)
    local L = self.L
    local font = L.hand
    if font ~= UIFont.Handwritten then
        self:drawText(text, cx - measure(text, font) / 2, cy - L.hh / 2, BLUE[1], BLUE[2], BLUE[3], alpha or 0.92, font)
        return
    end
    local zoom = math.max(0.8, math.min(2, L.box / 22))
    local y = cy - L.hh * 0.55 * zoom
    self:drawTextZoomed(text, cx - measure(text, font) * zoom / 2, y, zoom, BLUE[1], BLUE[2], BLUE[3], alpha or 0.92,
        font)
end

--- Coche manuscrite dans une case.
function RW:tick(r)
    local check = formTex("Check")
    local s = math.floor(r.h * 1.5)
    if check then
        self:drawTextureScaled(check, r.x + r.w / 2 - s / 2 + 2, r.y + r.h / 2 - s / 2 - 2, s, s, 0.95,
            BLUE[1], BLUE[2], BLUE[3])
    else
        self:handwrite("X", r.x + r.w / 2, r.y + r.h / 2)
    end
end

--- Planchette de tôle olive, feuille, ombre.
function RW:drawBoard()
    local L, w, h = self.L, self.width, self.height
    self:drawRect(0, 0, w, h, 1, 0.06, 0.07, 0.04)
    local metal = postTex("Metal")
    if metal then
        self:drawTextureTiled(metal, 1, 1, w - 2, h - 2, 1, 1, 1, 1)
    else
        self:drawRect(1, 1, w - 2, h - 2, 1, 0.34, 0.35, 0.24)
    end
    -- Relief de la planchette : arête claire en haut, sombre en bas.
    self:drawRect(1, 1, w - 2, 2, 0.22, 1, 1, 0.9)
    self:drawRect(1, 3, 2, h - 4, 0.18, 1, 1, 0.9)
    self:drawRect(1, h - 3, w - 2, 2, 0.5, 0, 0, 0)
    self:drawRect(w - 3, 1, 2, h - 2, 0.45, 0, 0, 0)
    local p = L.paper
    -- Ombre portée de la feuille, puis papier.
    self:drawRect(p.x + 2, p.y + 3, p.w, p.h, 0.35, 0, 0, 0)
    self:drawRect(p.x + 1, p.y + 1, p.w, p.h, 0.25, 0, 0, 0)
    local paper = postTex("Paper")
    if paper then
        self:drawTextureTiled(paper, p.x, p.y, p.w, p.h, 1, 1, 1, 1)
    else
        self:drawRect(p.x, p.y, p.w, p.h, 1, 0.91, 0.88, 0.79)
    end
    -- Bord jauni de la feuille.
    self:drawRectBorder(p.x, p.y, p.w, p.h, 0.18, 0.45, 0.36, 0.2)
end

--- En-tête : titre, service, demandeur, référence ; double filet.
function RW:drawHeader()
    local L, form = self.L, self.form
    local x = L.textX
    self:type(RW.fit(getText("IGUI_MilitaryDrop_ReqTitle"), L.title, L.infoW), x, L.titleY, INK, 1, L.title)
    self:type(RW.fit(getText("IGUI_MilitaryDrop_ReqService"), L.font, L.infoW), x, L.serviceY, INK, 0.8)
    local ref = getText("IGUI_MilitaryDrop_ReqRef", string.format("MD-%04d", (tonumber(form.requestId) or 0) % 10000))
    local refW = measure(ref, L.font)
    self:type(RW.fit(getText("IGUI_MilitaryDrop_ReqFrom", form.callsign), L.font, L.infoW - refW - 2 * L.u), x,
        L.infoY, INK, 1)
    self:type(ref, x + L.infoW - refW, L.infoY, INK, 0.75)
    self:rule(x, L.ruleY, L.contentW, 0.8)
    self:rule(x, L.ruleY + 2, L.contentW, 0.8)
end

--- Tampon rouge « Autorisé », délai de validité ; « Expiré » à l'échéance.
function RW:drawStamp(now)
    local L, form = self.L, self.form
    local s = L.stamp
    local expired = RW.expired(form, now)
    local alpha = 0.82
    self:drawRectBorder(s.x, s.y, s.w, s.h, alpha, RED[1], RED[2], RED[3])
    self:drawRectBorder(s.x + 1, s.y + 1, s.w - 2, s.h - 2, alpha, RED[1], RED[2], RED[3])
    self:drawRectBorder(s.x + 3, s.y + 3, s.w - 6, s.h - 6, alpha * 0.8, RED[1], RED[2], RED[3])
    local cx = s.x + s.w / 2
    local ty = s.y + math.floor(L.u / 2) + 1
    local word = getText(expired and "IGUI_MilitaryDrop_ReqStampExpired" or RW.stampKey(form))
    local wordY = expired and (s.y + (s.h - L.ft) / 2) or ty
    self:drawText(word, cx - measure(word, L.title) / 2, wordY, RED[1], RED[2], RED[3], alpha, L.title)
    -- Encre usée du tampon : grain du papier par-dessus le cadre et le mot.
    local grunge = formTex("Grunge")
    if grunge then
        self:drawTextureTiled(grunge, s.x, s.y, s.w, s.h, 1, 1, 1, 1)
    end
    if not expired then
        -- Délai inscrit au composteur sous le mot : net, il clignote la dernière minute.
        local left = form.deadline - now
        local valid = getText("IGUI_MilitaryDrop_ReqValid", RW.clockText(left))
        local a = 0.95
        if left < 60000 and math.floor(now / 500) % 2 == 0 then
            a = 0.4
        end
        local vy = ty + L.ft - 2
        self:drawRect(s.x + 4, vy - 1, s.w - 8, 1, 0.5, RED[1], RED[2], RED[3])
        self:drawText(valid, cx - measure(valid, L.font) / 2, vy, RED[1], RED[2], RED[3], a, L.font)
    end
end

--- Titres de colonnes, sections, lignes de lots.
function RW:drawTable(hover, payload, now)
    local L, form = self.L, self.form
    local expired = RW.expired(form, now)
    for _, column in ipairs(L.columns) do
        self:type(getText("IGUI_MilitaryDrop_ReqColLot"), column.x, L.colHeadY, INK, 0.7)
        local costRight = column.x + L.labelW + 2 * L.u + L.costW
        self:typeRight(getText("IGUI_MilitaryDrop_ReqColCost"), costRight, L.colHeadY, INK, 0.7)
        local qtyX = column.x + column.w - L.box - L.gapS - L.numW / 2
        self:typeCentre(getText("IGUI_MilitaryDrop_ReqColQty"), qtyX, L.colHeadY, INK, 0.7)
        self:rule(column.x, L.colRuleY, column.w, 0.7)
    end
    for _, section in ipairs(L.sectionsAt) do
        local ty = section.y + math.floor((L.sectionH - L.fh) / 2)
        self:type(section.label, section.x, ty, INK, 1)
        local lw = measure(section.label, L.font) + L.u
        self:drawRect(section.x + lw, ty + math.floor(L.fh / 2), section.w - lw, 1, 0.35, INK[1], INK[2], INK[3])
    end
    local cursor = self.drawJoypadFocus and self:navigation()[self.cursor] or nil
    for _, lot in ipairs(form.lots) do
        local row = L.rows[lot.id]
        if row then
            local focused = cursor and cursor.kind == "lot" and cursor.id == lot.id
            self:drawLotRow(lot, row, hover, payload, expired, focused)
        end
    end
end

function RW:drawLotRow(lot, row, hover, payload, expired, focused)
    local L, form = self.L, self.form
    local ty = row.row.y + math.floor((L.rowH - L.fh) / 2)
    local hovered = payload == lot.id and (hover == "lot" or hover == "minus" or hover == "plus")
    if (hovered or focused) and lot.allowed then
        -- Surligneur sous la ligne survolée.
        self:drawRect(row.row.x - 2, row.row.y + 1, row.row.w + 4, row.row.h - 2, 0.22, MARKER[1], MARKER[2], MARKER[3])
    end
    if focused then
        self:drawRectBorder(row.row.x - 3, row.row.y, row.row.w + 6, row.row.h, 0.85, BLUE[1], BLUE[2], BLUE[3])
    end
    local alpha = lot.allowed and 1 or 0.38
    local label = RW.fit(RW.lotLabel(lot), L.font, L.labelW)
    self:type(label, row.label.x, ty, INK, alpha)
    -- Pointillés de conduite jusqu'au coût.
    local dotsX = row.label.x + measure(label, L.font) + L.gapS
    local costText = RW.costText(lot.cost)
    local dotsEnd = row.costRight - measure(costText, L.font) - L.gapS
    local dotY = ty + L.fh - math.floor(L.fh / 4)
    local x = dotsX
    while x + 1 < dotsEnd do
        self:drawRect(x, dotY, 1, 1, 0.45 * alpha, INK[1], INK[2], INK[3])
        x = x + 4
    end
    if not lot.allowed then
        -- Raison à la place du coût et des boutons, lot rayé.
        local lineY = ty + math.floor(L.fh / 2)
        self:drawRect(row.label.x, lineY, measure(label, L.font), 1, 0.45, INK[1], INK[2], INK[3])
        local reason = RW.fit(RW.reasonText(lot), L.font, row.span.w)
        self:typeRight(reason, row.span.x + row.span.w, ty, RED, 0.7)
        return
    end
    self:typeRight(costText, row.costRight, ty, INK, 1)
    local qty = form.qty[lot.id] or 0
    local canMinus = not expired and RW.canRemove(form, lot.id)
    local canPlus = not expired and RW.canAdd(form, lot.id)
    self:stepButton(row.minus, "-", canMinus, hover == "minus" and payload == lot.id,
        self.pressed == "minus" and self.pressedPayload == lot.id)
    self:stepButton(row.plus, "+", canPlus, hover == "plus" and payload == lot.id,
        self.pressed == "plus" and self.pressedPayload == lot.id)
    -- Case de quantité : vide à zéro, chiffre manuscrit sinon.
    self:printedBox(row.qty, 0.6, { 1, 1, 1, 0.22 })
    if qty > 0 then
        self:handwrite(tostring(qty), row.qty.x + row.qty.w / 2, row.qty.y + row.qty.h / 2)
    end
end

--- Commande spéciale : case du leurre, coût, secteurs en rose des vents.
function RW:drawDecoy(hover, payload, now)
    local L, form = self.L, self.form
    local decoy, row = form.decoy, L.decoyRow
    if not decoy or not row then
        return
    end
    local expired = RW.expired(form, now)
    local nav = self.drawJoypadFocus and self:navigation()[self.cursor] or nil
    local focusedRow = nav and nav.kind == "decoy"
    local focusedSectors = nav and nav.kind == "sectors"
    local canToggle = not expired and RW.canToggleDecoy(form)
    local ty = row.row.y + math.floor((L.rowH - L.fh) / 2)
    if (hover == "decoy" or focusedRow) and decoy.allowed then
        self:drawRect(row.row.x - 2, row.row.y + 1, row.row.w + 4, row.row.h - 2, 0.22, MARKER[1], MARKER[2], MARKER[3])
    end
    if focusedRow then
        self:drawRectBorder(row.row.x - 3, row.row.y, row.row.w + 6, row.row.h, 0.85, BLUE[1], BLUE[2], BLUE[3])
    end
    local alpha = (decoy.allowed and (canToggle or form.decoyOn)) and 1 or 0.38
    local fill = (hover == "decoy" and canToggle) and { INK[1], INK[2], INK[3], 0.1 } or { 1, 1, 1, 0.22 }
    self:printedBox(row.check, 0.75 * alpha, fill)
    if form.decoyOn then
        self:tick(row.check)
    end
    local labelX = row.check.x + row.check.w + L.u
    local label = RW.fit(getText("IGUI_MilitaryDrop_ReqDecoy"), L.font, L.labelW - (labelX - row.label.x))
    self:type(label, labelX, ty, INK, alpha)
    if not decoy.allowed then
        self:typeRight(RW.fit(RW.reasonText(decoy), L.font, row.span.w), row.span.x + row.span.w, ty, RED, 0.7)
        return
    end
    local costText = RW.costText(decoy.cost)
    local dotsEnd = row.costRight - measure(costText, L.font) - L.gapS
    local x = labelX + measure(label, L.font) + L.gapS
    while x + 1 < dotsEnd do
        self:drawRect(x, ty + L.fh - math.floor(L.fh / 4), 1, 1, 0.45 * alpha, INK[1], INK[2], INK[3])
        x = x + 4
    end
    self:typeRight(costText, row.costRight, ty, INK, alpha)
    if L.dropField then
        -- Secteur du leurre : le champ du pied (drawFooter).
        return
    end
    if L.zones then
        self:drawZoneSectors(hover, expired, focusedSectors)
        return
    end
    -- Secteurs : libellé, mention d'exclusivité, rose des vents.
    local area = L.sectorsArea
    local sy = area.y + math.floor(L.u / 2)
    if focusedSectors then
        self:drawRectBorder(area.x - 3, area.y, area.w + 6, area.h, 0.85, BLUE[1], BLUE[2], BLUE[3])
    end
    local textW = L.sectorBoxes.W.x - L.sectorLabelX - L.u
    self:type(RW.fit(getText("IGUI_MilitaryDrop_ReqSectorLabel"), L.font, textW), L.sectorLabelX, sy, INK,
        form.decoyOn and 1 or 0.6)
    local note = getText(form.decoyOn and not form.sector and "IGUI_MilitaryDrop_ReqBlock_sector"
        or "IGUI_MilitaryDrop_ReqExclusive")
    local noteColor = (form.decoyOn and not form.sector) and RED or INK
    self:type(RW.fit(note, L.font, textW), L.sectorLabelX, sy + L.fh, noteColor, 0.6)
    local c = L.compassCenter
    self:drawRect(c.x - 1, c.y - 1, 3, 3, 0.6, INK[1], INK[2], INK[3])
    for _, sector in ipairs(decoy.sectors) do
        local r = L.sectorBoxes[sector]
        local enabled = not expired and RW.canPickSector(form, sector)
        local hovered = hover == "sector" and payload == sector and enabled
        self:printedBox(r, enabled and 0.7 or 0.3, hovered and { INK[1], INK[2], INK[3], 0.1 } or nil)
        local letter = getText("IGUI_MilitaryDrop_ReqSector_" .. sector)
        self:typeCentre(letter, r.x + r.w / 2, r.y + (r.h - L.fh) / 2, INK, enabled and 1 or 0.4)
        if form.sector == sector then
            -- Lettre entourée au stylo.
            local circle = formTex("Circle")
            local s = r.w * 1.9
            if circle then
                self:drawTextureScaled(circle, r.x + r.w / 2 - s / 2, r.y + r.h / 2 - s / 2, s, s, 0.95,
                    BLUE[1], BLUE[2], BLUE[3])
            else
                self:drawRectBorder(r.x - 2, r.y - 2, r.w + 4, r.h + 4, 0.9, BLUE[1], BLUE[2], BLUE[3])
            end
        end
    end
end

--- Secteurs nommés (mode zones) : libellé, sélecteur « < nom > » (nom choisi
--- écrit à l'encre bleue et souligné, champ en pointillés tant qu'aucun
--- secteur n'est choisi), ou nom imposé imprimé ; puis la note. Noms dessinés
--- par drawText (aucune balise interprétée), raccourcis à la largeur du champ.
--- Champ du largage (ZONE-09) : toujours à l'encre pleine, note « point
--- exact choisi par la Logistique » (ou « choisir un secteur » en rouge).
function RW:drawZoneSectors(hover, expired, focused)
    local L, form = self.L, self.form
    local area = L.sectorsArea
    if focused then
        self:drawRectBorder(area.x - 3, area.y, area.w + 6, area.h, 0.85, BLUE[1], BLUE[2], BLUE[3])
    end
    local active = form.drop ~= nil or form.decoyOn
    local textW = area.x + area.w - L.sectorLabelX
    self:type(RW.fit(getText("IGUI_MilitaryDrop_ReqSectorLabel"), L.font, textW), L.sectorLabelX, L.sectorLabelY,
        INK, active and 1 or 0.6)
    local r = L.sectorName
    local ty = r.y + math.floor((r.h - L.fh) / 2)
    local fixed = RW.fixedSector(form)
    if fixed then
        -- Secteur imposé : simple information, imprimée.
        self:type(RW.fit(fixed, L.font, r.w), r.x, ty, INK, active and 1 or 0.6)
    else
        local enabled = not expired and RW.canStepSector(form)
        local nameHover = hover == "sectorName" and enabled
        self:pageButton(L.sectorPrev, "<", enabled, hover == "sectorPrev", self.pressed == "sectorPrev")
        self:pageButton(L.sectorNext, ">", enabled, hover == "sectorNext", self.pressed == "sectorNext")
        local fill = nameHover and { INK[1], INK[2], INK[3], self.pressed == "sectorName" and 0.22 or 0.1 } or nil
        self:printedBox(r, enabled and 0.5 or 0.22, fill)
        if form.sector then
            local name = RW.fit(form.sector, L.font, r.w - 2 * L.u)
            local nameW = measure(name, L.font)
            local cx = r.x + r.w / 2
            self:type(name, cx - nameW / 2, ty, BLUE, 1)
            self:drawRect(cx - nameW / 2, ty + L.fh - 1, nameW, 1, 0.7, BLUE[1], BLUE[2], BLUE[3])
        else
            -- Champ à remplir : pointillés.
            local x = r.x + L.u
            while x + 1 < r.x + r.w - L.u do
                self:drawRect(x, ty + L.fh - math.floor(L.fh / 4), 1, 1, 0.45, INK[1], INK[2], INK[3])
                x = x + 4
            end
        end
    end
    local missing = active and not form.sector
    local note = getText(missing and "IGUI_MilitaryDrop_ReqBlock_sector"
        or (form.drop and "IGUI_MilitaryDrop_ReqSectorNote" or "IGUI_MilitaryDrop_ReqExclusive"))
    self:type(RW.fit(note, L.font, textW), L.sectorLabelX, L.sectorNoteY, missing and RED or INK, 0.6)
end

--- Pied : champ du largage (ZONE-09), budget, engagé, restant (points de
--- conduite), note, boutons.
function RW:drawFooter(hover, now)
    local L, form = self.L, self.form
    if L.dropField then
        local nav = self.drawJoypadFocus and self:navigation()[self.cursor] or nil
        self:drawZoneSectors(hover, RW.expired(form, now), nav ~= nil and nav.kind == "sectors")
    end
    local b = L.budget
    self:rule(b.x, b.y - math.floor(L.u / 2), b.w, 0.6)
    local values = { form.budget, RW.spent(form), RW.remaining(form) }
    for i, key in ipairs(BUDGET_KEYS) do
        local y = b.y + (i - 1) * L.fh
        local label = getText(key)
        self:type(label, b.x, y, INK, i == 3 and 1 or 0.85)
        local value = RW.costText(values[i])
        local right = b.x + b.w
        local valueX = right - measure(value, L.font)
        local x = b.x + measure(label, L.font) + L.gapS
        while x + 1 < valueX - L.gapS do
            self:drawRect(x, y + L.fh - math.floor(L.fh / 4), 1, 1, 0.45, INK[1], INK[2], INK[3])
            x = x + 4
        end
        self:typeRight(value, right, y, INK, i == 3 and 1 or 0.85)
        if i == 3 then
            -- Restant : double soulignement.
            local vw = measure(value, L.font)
            self:drawRect(right - vw, y + L.fh - 2, vw, 1, 0.7, INK[1], INK[2], INK[3])
            self:drawRect(right - vw, y + L.fh, vw, 1, 0.7, INK[1], INK[2], INK[3])
        end
    end
    self:type(RW.fit(getText("IGUI_MilitaryDrop_ReqLost"), L.font, b.w), b.x, L.lostY, INK, 0.5)
    if L.paging then
        -- Pages : < Page 1/2 > (clic, molette, ou la ligne de la manette).
        self:pageButton(L.pagePrev, "<", self:isEnabled("pagePrev"), hover == "pagePrev", self.pressed == "pagePrev")
        self:pageButton(L.pageNext, ">", self:isEnabled("pageNext"), hover == "pageNext", self.pressed == "pageNext")
        self:typeCentre(getText("IGUI_MilitaryDrop_ReqPage", L.page, L.pages), L.pageTextX, L.pageTextY, INK, 0.85)
    end
    local joypad = self.drawJoypadFocus and Joypad and Joypad.Texture
    self:drawFormButton(L.cancel, getText("IGUI_MilitaryDrop_ReqCancel"), true, hover == "cancel",
        self.pressed == "cancel", false, joypad and Joypad.Texture.BButton or nil)
    self:drawFormButton(L.transmit, getText("IGUI_MilitaryDrop_ReqTransmit"), RW.canTransmit(form, now),
        hover == "transmit", self.pressed == "transmit", true, joypad and Joypad.Texture.AButton or nil)
end

--- Bouton imprimé sur la feuille : cadre d'encre (rouge pour transmettre).
function RW:drawFormButton(r, label, enabled, hover, pressed, primary, joypadTexture)
    local L = self.L
    local color = primary and RED or INK
    local dy = pressed and 1 or 0
    local alpha = enabled and 1 or 0.3
    if enabled and (hover or pressed) then
        self:drawRect(r.x, r.y, r.w, r.h, pressed and 0.2 or 0.1, color[1], color[2], color[3])
    elseif primary and enabled then
        self:drawRect(r.x, r.y, r.w, r.h, 0.05, color[1], color[2], color[3])
    end
    self:drawRectBorder(r.x, r.y, r.w, r.h, 0.85 * alpha, color[1], color[2], color[3])
    if primary then
        self:drawRectBorder(r.x + 2, r.y + 2, r.w - 4, r.h - 4, 0.55 * alpha, color[1], color[2], color[3])
    end
    local textX = r.x + r.w / 2
    local iconW = 0
    if joypadTexture then
        iconW = L.fh
        self:drawTextureScaled(joypadTexture, r.x + L.u, r.y + (r.h - L.fh) / 2 + dy, L.fh, L.fh, enabled and 1 or 0.4)
        textX = textX + iconW / 2
    end
    local text = RW.fit(label, L.font, r.w - 2 * L.u - iconW)
    self:typeCentre(text, textX, r.y + (r.h - L.fh) / 2 + dy, color, alpha)
    if primary and enabled then
        self:drawText(text, textX - measure(text, L.font) / 2 + 1, r.y + (r.h - L.fh) / 2 + dy, color[1], color[2],
            color[3], 0.35, L.font)
    end
end

--- Pince de la planchette (par-dessus la feuille) et croix de fermeture.
function RW:drawClipAndClose(hover)
    local L = self.L
    local clip = formTex("Clip")
    local c = L.clip
    if clip then
        self:drawTextureScaled(clip, c.x, c.y, c.w, c.h, 1)
    else
        self:drawRect(c.x, c.y + c.h / 4, c.w, c.h / 2, 1, 0.6, 0.6, 0.58)
    end
    local r = L.close
    local plate = postTex("Button")
    local shade = hover == "close" and 1.12 or 1
    if self.pressed == "close" then
        shade = 0.85
    end
    self:drawRect(r.x - 1, r.y - 1, r.w + 2, r.h + 2, 0.8, 0.05, 0.05, 0.03)
    if plate then
        self:drawTextureScaled(plate, r.x, r.y, r.w, r.h, 1, shade, shade, shade)
    else
        self:drawRect(r.x, r.y, r.w, r.h, 1, 0.58 * shade, 0.58 * shade, 0.56 * shade)
    end
    self:drawRect(r.x, r.y, r.w, 1, 0.22, 1, 1, 1)
    self:drawRect(r.x, r.y + r.h - 1, r.w, 1, 0.5, 0, 0, 0)
    self:drawText("X", r.x + (r.w - measure("X", UIFont.Small)) / 2, r.y + (r.h - fontHeight(UIFont.Small)) / 2,
        INK[1], INK[2], INK[3], 1, UIFont.Small)
end

function RW:prerender()
    if not self.L then
        return
    end
    self:drawBoard()
end

function RW:render()
    if not self.L then
        return
    end
    local now = getTimestampMs()
    local hover, payload = self:mouseTarget()
    self:drawHeader()
    self:drawStamp(now)
    self:drawTable(hover, payload, now)
    self:drawDecoy(hover, payload, now)
    self:drawFooter(hover, now)
    self:drawClipAndClose(hover)
    if self.drawJoypadFocus then
        self:drawRectBorder(0, 0, self.width, self.height, 0.9, PAINT[1], PAINT[2], PAINT[3])
    end
end

return RW
