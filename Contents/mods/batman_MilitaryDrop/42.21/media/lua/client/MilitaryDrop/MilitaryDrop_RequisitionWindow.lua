-- ============================================================================
-- Military Drop — formulaire de réquisition (client, v1.4)
--
-- Ouvert quand le serveur accepte un appel et répond « form » (contrat de
-- docs/PLAN-V14.md) : feuille dactylographiée pincée sur une planchette de
-- tôle olive. Lots groupés par palier (I, II, III) puis « Commande spéciale »
-- (le leurre, v1.5) ; chaque ligne : libellé, coût, boutons − et +, quantité
-- écrite à la main. Lots non permis grisés avec leur raison. Budget, points
-- engagés et restants en bas (les points non dépensés sont perdus), tampon
-- « Autorisé » avec le délai de validité.
--
-- Le leurre est exclusif : le cocher bloque les autres lots, et un lot choisi
-- bloque le leurre ; il exige un secteur (N, E, S, O).
--
-- Le client ne décide rien : il compose la commande (budget, paliers) pour
-- l'affichage, puis MilitaryDrop.Client l'envoie (RequisitionOrder) ou
-- l'annule (RequisitionCancel) ; le serveur revalide tout. Fermer la feuille
-- (Échap, B, croix, joueur éloigné de la radio) annule la réquisition.
--
-- Tout est dessiné par la fenêtre (textures du mod, polices du jeu) ; les
-- largeurs sont mesurées selon la langue et la taille de police, et la mise
-- en page passe de deux colonnes à une, puis en version serrée, pour tenir
-- dans l'écran du joueur (écran partagé compris).
-- ============================================================================

require "ISUI/ISPanelJoypad"
require "ISUI/ISToolTip"
require "MilitaryDrop/MilitaryDrop_Radio"
require "MilitaryDrop/MilitaryDrop_Client"

local Config = MilitaryDrop.Config
local Radio = MilitaryDrop.Radio

local RW = ISPanelJoypad:derive("MilitaryDropRequisitionWindow")
MilitaryDrop.RequisitionWindow = RW

-- Secteurs du leurre, dans l'ordre du contrat (W s'affiche « O » en français).
RW.SECTORS = { "N", "E", "S", "W" }
-- Validité par défaut si le serveur ne l'envoie pas (ms réelles), et marge
-- retranchée côté client : le délai part de la réception, après celui du serveur.
RW.DEFAULT_EXPIRES_MS = 300000
RW.SAFETY_MS = 2000
RW.MAX_QTY = 99
-- Seuils de confiance affichés pour un lot réservé à un palier (options
-- sandbox, lues par nom composé ; valeurs par défaut du PLAN-V14).
RW.TIER_OPTIONS = { [2] = { "RequisitionTier2", 50 }, [3] = { "RequisitionTier3", 75 } }
RW.GROUP_COUNT = 3
-- Fermeture quand le joueur s'éloigne de la radio posée (même portée que le serveur).
RW.CLOSE_DISTANCE = Radio.MAX_WORLD_DISTANCE + 0.5
-- Textures du mod (common/media/textures/MilitaryDrop/…) ; préfixes
-- distinctifs : le jeu cherche d'abord le nom de base dans ses packs.
RW.TEXTURE_PATH = "media/textures/MilitaryDrop/RequisitionForm/MDReq_"
RW.POST_TEXTURE_PATH = "media/textures/MilitaryDrop/PostConsole/MDPost_"
-- Langues dont l'alphabet tient dans la police à chasse fixe du jeu (Latin-1) :
-- texte dactylographié ; sinon police normale.
RW.MONO_LANGUAGES = {
    EN = true, FR = true, DE = true, ES = true, IT = true, PT = true, PTBR = true, NL = true, DA = true,
    NO = true, FI = true, ID = true,
}
-- Mises en page essayées dans l'ordre : la première qui tient dans l'écran.
RW.MODES = {
    { cols = 2, compact = false },
    { cols = 1, compact = false },
    { cols = 2, compact = true },
    { cols = 1, compact = true },
}

-- Encres (r, g, b).
local INK = { 0.13, 0.12, 0.11 }
local RED = { 0.66, 0.1, 0.08 }
local BLUE = { 0.1, 0.2, 0.52 }
local MARKER = { 1, 0.9, 0.3 }
local PAINT = { 0.92, 0.9, 0.78 }

RW.instances = {}

-- ----------------------------------------------------------------------------
-- Formulaire (fonctions pures, testées hors jeu)
-- ----------------------------------------------------------------------------

local function toInt(value, default)
    local n = tonumber(value)
    if not n then
        return default
    end
    return math.floor(n)
end

--- Formulaire à partir du Result « form » reçu à nowMs (données du serveur
--- nettoyées : lots sans identifiant ignorés, coûts entiers ≥ 1).
function RW.newForm(args, nowMs)
    local form = {
        requestId = args.requestId,
        callsign = tostring(args.callsign or ""),
        tier = toInt(args.tier, 0),
        budget = math.max(0, toInt(args.budget, 0)),
        lots = {}, byId = {}, qty = {},
        decoy = nil, decoyOn = false, sector = nil,
    }
    local expires = tonumber(args.expiresMs) or RW.DEFAULT_EXPIRES_MS
    form.deadline = (nowMs or 0) + math.max(0, expires - RW.SAFETY_MS)
    for _, lot in ipairs(type(args.lots) == "table" and args.lots or {}) do
        if type(lot) == "table" and type(lot.id) == "string" and not form.byId[lot.id] then
            local entry = {
                id = lot.id,
                group = math.max(1, toInt(lot.group, 1)),
                cost = math.max(1, toInt(lot.cost, 1)),
                allowed = lot.allowed == true,
                label = type(lot.label) == "string" and lot.label or nil,
                desc = type(lot.desc) == "string" and lot.desc or nil,
            }
            if not entry.allowed then
                entry.reason = type(lot.reason) == "string" and lot.reason or "empty"
            end
            form.lots[#form.lots + 1] = entry
            form.byId[entry.id] = entry
            form.qty[entry.id] = 0
        end
    end
    local decoy = args.decoy
    if type(decoy) == "table" then
        local sectors, known = {}, {}
        for _, sector in ipairs(RW.SECTORS) do
            known[sector] = true
        end
        for _, sector in ipairs(type(decoy.sectors) == "table" and decoy.sectors or RW.SECTORS) do
            if known[sector] then
                sectors[#sectors + 1] = sector
                known[sector] = false
            end
        end
        form.decoy = {
            cost = math.max(1, toInt(decoy.cost, 1)),
            allowed = decoy.allowed == true and #sectors > 0,
            reason = decoy.allowed ~= true and (type(decoy.reason) == "string" and decoy.reason or "empty") or nil,
            sectors = sectors,
        }
        if decoy.allowed == true and #sectors == 0 then
            form.decoy.reason = "empty"
        end
    end
    return form
end

--- Points engagés (lots, ou leurre coché).
function RW.spent(form)
    local total = 0
    for _, lot in ipairs(form.lots) do
        total = total + (form.qty[lot.id] or 0) * lot.cost
    end
    if form.decoyOn and form.decoy then
        total = total + form.decoy.cost
    end
    return total
end

function RW.remaining(form)
    return form.budget - RW.spent(form)
end

--- Au moins un lot commandé.
function RW.anyLot(form)
    for _, lot in ipairs(form.lots) do
        if (form.qty[lot.id] or 0) > 0 then
            return true
        end
    end
    return false
end

function RW.canAdd(form, id)
    local lot = form.byId[id]
    return lot ~= nil and lot.allowed and not form.decoyOn and (form.qty[id] or 0) < RW.MAX_QTY
        and RW.remaining(form) >= lot.cost
end

function RW.canRemove(form, id)
    return form.byId[id] ~= nil and (form.qty[id] or 0) > 0
end

function RW.add(form, id)
    if not RW.canAdd(form, id) then
        return false
    end
    form.qty[id] = form.qty[id] + 1
    return true
end

function RW.remove(form, id)
    if not RW.canRemove(form, id) then
        return false
    end
    form.qty[id] = form.qty[id] - 1
    return true
end

--- Le leurre peut être coché (aucun lot choisi, budget suffisant) ou décoché.
function RW.canToggleDecoy(form)
    local decoy = form.decoy
    if not decoy or not decoy.allowed then
        return false
    end
    return form.decoyOn or (not RW.anyLot(form) and form.budget >= decoy.cost)
end

function RW.toggleDecoy(form)
    if not RW.canToggleDecoy(form) then
        return false
    end
    form.decoyOn = not form.decoyOn
    if not form.decoyOn then
        form.sector = nil
    end
    return true
end

local function hasSector(form, sector)
    for _, s in ipairs(form.decoy and form.decoy.sectors or {}) do
        if s == sector then
            return true
        end
    end
    return false
end

--- Un secteur peut être choisi (il coche le leurre au besoin).
function RW.canPickSector(form, sector)
    return hasSector(form, sector) and (form.decoyOn or RW.canToggleDecoy(form))
end

function RW.pickSector(form, sector)
    if not RW.canPickSector(form, sector) then
        return false
    end
    if not form.decoyOn then
        RW.toggleDecoy(form)
    end
    form.sector = sector
    return true
end

function RW.expired(form, nowMs)
    return nowMs >= form.deadline
end

--- Motif qui empêche de transmettre (« expired », « sector », « nothing »,
--- « budget »), ou nil.
function RW.blocker(form, nowMs)
    if RW.expired(form, nowMs) then
        return "expired"
    end
    if form.decoyOn then
        if not form.sector then
            return "sector"
        end
    elseif not RW.anyLot(form) then
        return "nothing"
    end
    if RW.remaining(form) < 0 then
        return "budget"
    end
    return nil
end

function RW.canTransmit(form, nowMs)
    return RW.blocker(form, nowMs) == nil
end

--- Arguments de RequisitionOrder : { requestId, radio, order = { [lot] = n },
--- decoy = secteur ou nil }. Le leurre part seul (order vide).
function RW.buildOrder(form, radioRef)
    local order = {}
    if not form.decoyOn then
        for _, lot in ipairs(form.lots) do
            local n = form.qty[lot.id] or 0
            if n > 0 then
                order[lot.id] = n
            end
        end
    end
    return { requestId = form.requestId, radio = radioRef, order = order,
        decoy = form.decoyOn and form.sector or nil }
end

--- Temps restant « m:ss » (jamais négatif).
function RW.clockText(ms)
    local seconds = math.max(0, math.ceil((tonumber(ms) or 0) / 1000))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

--- Seuil de confiance d'un palier (option sandbox, sinon valeur par défaut).
function RW.threshold(group)
    local option = RW.TIER_OPTIONS[group]
    if not option then
        return nil
    end
    return toInt(Config.get(option[1]), option[2])
end

--- Raison affichée à la place des boutons d'un lot non permis.
function RW.reasonText(entry)
    if entry.reason == "tier" then
        local threshold = RW.threshold(entry.group)
        if threshold then
            return getText("IGUI_MilitaryDrop_ReqReasonTier", tostring(threshold))
        end
    elseif entry.reason == "disabled" then
        return getText("IGUI_MilitaryDrop_ReqReasonDisabled")
    end
    return getText("IGUI_MilitaryDrop_ReqReasonEmpty")
end

function RW.costText(cost)
    return getText(cost == 1 and "IGUI_MilitaryDrop_ReqPoint" or "IGUI_MilitaryDrop_ReqPoints", tostring(cost))
end

function RW.lotLabel(lot)
    return lot.label and getText(lot.label) or lot.id
end

function RW.sectionLabel(group)
    if group == "special" then
        return getText("IGUI_MilitaryDrop_ReqGroupSpecial")
    end
    return getText("IGUI_MilitaryDrop_ReqGroup" .. math.min(group, RW.GROUP_COUNT))
end

--- Sections dans l'ordre d'affichage : paliers croissants (ordre du serveur
--- dans chaque palier), puis la commande spéciale.
function RW.sections(form)
    local byGroup, groups = {}, {}
    for _, lot in ipairs(form.lots) do
        if not byGroup[lot.group] then
            byGroup[lot.group] = {}
            groups[#groups + 1] = lot.group
        end
        local list = byGroup[lot.group]
        list[#list + 1] = lot
    end
    table.sort(groups)
    local sections = {}
    for _, group in ipairs(groups) do
        sections[#sections + 1] = { group = group, lots = byGroup[group] }
    end
    if form.decoy then
        sections[#sections + 1] = { group = "special", lots = {}, decoy = true }
    end
    return sections
end

-- ----------------------------------------------------------------------------
-- Mesures et disposition
-- ----------------------------------------------------------------------------

local function measure(text, font)
    return getTextManager():MeasureStringX(font or UIFont.Small, tostring(text or ""))
end

local function fontHeight(font)
    return getTextManager():getFontHeight(font)
end

local function rect(x, y, w, h)
    return { x = math.floor(x), y = math.floor(y), w = math.floor(w), h = math.floor(h) }
end

local function monoLanguage()
    -- Translator.getLanguage():name() : même lecture que le vanilla (ISLcdBar.lua:14).
    local language = Translator and Translator.getLanguage()
    local name = language and language:name()
    return name ~= nil and RW.MONO_LANGUAGES[tostring(name)] == true
end

--- Police « machine à écrire » si la langue tient en Latin-1, sinon UIFont.Small.
function RW.typedFont()
    if monoLanguage() and UIFont.CodeSmall then
        return UIFont.CodeSmall
    end
    return UIFont.Small
end

function RW.titleFont()
    if monoLanguage() and UIFont.CodeMedium then
        return UIFont.CodeMedium
    end
    return UIFont.Medium
end

--- Chiffres écrits à la main (police manuscrite du jeu, chiffres universels).
function RW.handFont()
    return UIFont.Handwritten or RW.typedFont()
end

--- Retire le dernier caractère (Lua 5.1 : octet de tête UTF-8 et suites).
local function dropLastChar(text)
    return (text:gsub("[^\128-\191][\128-\191]*$", ""))
end

--- Texte raccourci (« ... ») pour tenir dans maxWidth.
function RW.fit(text, font, maxWidth)
    text = tostring(text or "")
    if measure(text, font) <= maxWidth then
        return text
    end
    while #text > 0 and measure(text .. "...", font) > maxWidth do
        text = dropLastChar(text)
    end
    return text .. "..."
end

local BUDGET_KEYS = { "IGUI_MilitaryDrop_ReqBudget", "IGUI_MilitaryDrop_ReqSpent", "IGUI_MilitaryDrop_ReqLeft" }

--- Hauteur d'une section (titre, lignes, bloc des secteurs pour le leurre).
local function sectionHeight(L, section)
    local h = L.sectionH + #section.lots * L.rowH
    if section.decoy then
        h = h + L.rowH + L.sectorsH
    end
    return h
end

--- Disposition pour un mode (colonnes, serré) ; voir computeLayout.
local function place(form, mode)
    local font, title, hand = RW.typedFont(), RW.titleFont(), RW.handFont()
    local fh, ft = fontHeight(font), fontHeight(title)
    local u = math.max(4, math.floor(fh * 0.35))
    local compact = mode.compact
    local L = { mode = mode, cols = mode.cols, compact = compact, font = font, title = title, hand = hand,
        fh = fh, ft = ft, hh = fontHeight(hand), u = u }
    L.box = compact and (fh - 1) or (fh + 2)
    L.rowH = compact and (fh + 2) or (L.box + u)
    L.sectionH = compact and (fh + 2) or (fh + u)
    L.sectorBox = L.box - 2
    L.sectorsH = 3 * L.sectorBox + 4 + (compact and 2 or u)
    L.btnH = fh + (compact and 6 or 2 * u)
    L.gapS = math.max(2, math.floor(u / 2))
    L.colGap = 3 * u
    L.frame = 2 * u + 2
    L.closeSize = fh + 6
    L.pad = compact and 2 * u or 3 * u

    -- Largeurs mesurées : libellés, coûts, contrôles, raisons.
    local labelW = measure(getText("IGUI_MilitaryDrop_ReqColLot"), font)
    local costW = measure(getText("IGUI_MilitaryDrop_ReqColCost"), font)
    local reasonW = 0
    for _, lot in ipairs(form.lots) do
        labelW = math.max(labelW, measure(RW.lotLabel(lot), font))
        costW = math.max(costW, measure(RW.costText(lot.cost), font))
        if not lot.allowed then
            reasonW = math.max(reasonW, measure(RW.reasonText(lot), font))
        end
    end
    if form.decoy then
        labelW = math.max(labelW, L.box + u + measure(getText("IGUI_MilitaryDrop_ReqDecoy"), font))
        costW = math.max(costW, measure(RW.costText(form.decoy.cost), font))
        if not form.decoy.allowed then
            reasonW = math.max(reasonW, measure(RW.reasonText(form.decoy), font))
        end
    end
    -- Libellé trop long (traduction) : raccourci, complet dans l'infobulle.
    L.labelW = math.min(labelW, fh * 15)
    L.costW = costW
    L.numW = math.max(L.box + 4, measure("88", hand) + 4, measure(getText("IGUI_MilitaryDrop_ReqColQty"), font))
    local ctrlW = 2 * L.box + 2 * L.gapS + L.numW
    ctrlW = math.max(ctrlW, 3 * L.sectorBox + 4)
    local spanW = costW + 2 * u + ctrlW
    if reasonW > spanW then
        ctrlW = ctrlW + reasonW - spanW
    end
    L.ctrlW = ctrlW
    local colW = L.labelW + 2 * u + costW + 2 * u + ctrlW
    -- Pied : budget (libellé, points de suite, valeur), note, boutons.
    L.budgetLabelW = 0
    for _, key in ipairs(BUDGET_KEYS) do
        L.budgetLabelW = math.max(L.budgetLabelW, measure(getText(key), font))
    end
    L.budgetValueW = measure(RW.costText(888), font)
    colW = math.max(colW, L.budgetLabelW + 3 * u + L.budgetValueW, measure(getText("IGUI_MilitaryDrop_ReqLost"), font))
    local transmitW = measure(getText("IGUI_MilitaryDrop_ReqTransmit"), font) + 4 * u
    local cancelW = measure(getText("IGUI_MilitaryDrop_ReqCancel"), font) + 4 * u
    L.stacked = transmitW + cancelW + u > colW
    if L.stacked then
        colW = math.max(colW, transmitW, cancelW)
    end
    L.footerH = u + 3 * fh + fh + u + L.btnH + (L.stacked and (L.btnH + L.gapS) or 0)

    -- En-tête : titre, service, demandeur et référence ; tampon à droite.
    local stampTitleW = math.max(measure(getText("IGUI_MilitaryDrop_ReqStamp"), title),
        measure(getText("IGUI_MilitaryDrop_ReqStampExpired"), title))
    L.stampW = math.max(stampTitleW, measure(getText("IGUI_MilitaryDrop_ReqValid", "88:88"), font)) + 3 * u
    L.stampH = ft + fh + u
    local infoW = math.max(measure(getText("IGUI_MilitaryDrop_ReqTitle"), title),
        measure(getText("IGUI_MilitaryDrop_ReqService"), font),
        measure(getText("IGUI_MilitaryDrop_ReqFrom", form.callsign), font) + 2 * u
        + measure(getText("IGUI_MilitaryDrop_ReqRef", "MD-8888"), font))
    local headerNeed = infoW + 3 * u + L.stampW

    -- Colonnes : sections réparties pour la hauteur la plus faible, pied dans
    -- la dernière colonne.
    local sections = RW.sections(form)
    local heights = {}
    for i, section in ipairs(sections) do
        heights[i] = sectionHeight(L, section)
    end
    local cols = math.min(mode.cols, math.max(1, #sections))
    local split = #sections
    if cols == 2 then
        local best
        for k = 1, #sections - 1 do
            local left, right = 0, L.footerH
            for i, h in ipairs(heights) do
                if i <= k then
                    left = left + h
                else
                    right = right + h
                end
            end
            local tallest = math.max(left, right)
            if not best or tallest < best then
                best, split = tallest, k
            end
        end
    end
    L.cols = cols
    local contentW = cols * colW + (cols - 1) * L.colGap
    if headerNeed > contentW then
        colW = colW + math.ceil((headerNeed - contentW) / cols)
        contentW = cols * colW + (cols - 1) * L.colGap
    end
    L.colW = colW
    L.contentW = contentW

    -- Planchette et pince.
    L.clipW = math.max(96, math.floor(fh * 5.5))
    L.clipH = math.floor(L.clipW / 2)
    local paperY = math.max(math.floor(L.clipH / 2) + 2, L.closeSize + 6)
    local W = 2 * L.frame + 2 * L.pad + contentW
    L.paper = rect(L.frame, paperY, W - 2 * L.frame, 0)
    L.clip = rect((W - L.clipW) / 2, paperY - math.floor(L.clipH / 2), L.clipW, L.clipH)
    L.close = rect(W - L.frame - L.closeSize, math.max(2, (paperY - L.closeSize) / 2), L.closeSize, L.closeSize)
    local x0 = L.paper.x + L.pad
    local y = paperY + math.max(L.pad, math.ceil(L.clipH / 2) + u)
    L.titleY = y
    L.serviceY = y + ft
    L.infoY = L.serviceY + fh
    L.textX = x0
    L.infoW = contentW - L.stampW - 3 * u
    L.stamp = rect(x0 + contentW - L.stampW, y + math.floor((ft + 2 * fh - L.stampH) / 2), L.stampW, L.stampH)
    y = L.infoY + fh + u
    L.ruleY = y
    y = y + 3 + u
    L.colHeadY = y
    y = y + fh
    L.colRuleY = y
    y = y + (compact and 2 or math.floor(u / 2) + 1)
    L.columnsY = y

    -- Lignes de chaque colonne.
    L.columns, L.sectionsAt, L.rows, L.sectorBoxes = {}, {}, {}, {}
    local bottom = y
    for c = 1, cols do
        local cx = x0 + (c - 1) * (colW + L.colGap)
        L.columns[c] = rect(cx, L.colHeadY, colW, 0)
        local cy = y
        local first, last = 1, split
        if c == 2 then
            first, last = split + 1, #sections
        elseif cols == 1 then
            last = #sections
        end
        for i = first, last do
            local section = sections[i]
            L.sectionsAt[#L.sectionsAt + 1] = { label = RW.sectionLabel(section.group), x = cx, y = cy, w = colW }
            cy = cy + L.sectionH
            for _, lot in ipairs(section.lots) do
                L.rows[lot.id] = RW.rowRects(L, cx, cy, colW)
                cy = cy + L.rowH
            end
            if section.decoy then
                local row = RW.rowRects(L, cx, cy, colW)
                row.check = rect(cx, cy + (L.rowH - L.box) / 2, L.box, L.box)
                L.decoyRow = row
                cy = cy + L.rowH
                local sb = L.sectorBox
                local mid = cx + colW - math.floor((3 * sb + 4) / 2)
                local top = cy + (compact and 1 or math.floor(u / 2))
                L.sectorsArea = rect(cx, cy, colW, L.sectorsH)
                L.sectorLabelX = cx + L.box + u
                L.sectorBoxes.N = rect(mid - sb / 2, top, sb, sb)
                L.sectorBoxes.W = rect(mid - sb / 2 - sb - 2, top + sb + 2, sb, sb)
                L.sectorBoxes.E = rect(mid + sb / 2 + 2, top + sb + 2, sb, sb)
                L.sectorBoxes.S = rect(mid - sb / 2, top + 2 * (sb + 2), sb, sb)
                L.compassCenter = { x = mid, y = top + sb + 2 + sb / 2 }
                cy = cy + L.sectorsH
            end
        end
        if c == cols then
            -- Pied : budget, note, boutons.
            cy = cy + u
            L.budgetY = cy
            L.budget = rect(cx, cy, colW, 3 * fh)
            cy = cy + 3 * fh
            L.lostY = cy
            cy = cy + fh + u
            if L.stacked then
                L.transmit = rect(cx, cy, colW, L.btnH)
                L.cancel = rect(cx, cy + L.btnH + L.gapS, colW, L.btnH)
                cy = cy + 2 * L.btnH + L.gapS
            else
                local cancelSize = cancelW
                L.cancel = rect(cx, cy, cancelSize, L.btnH)
                L.transmit = rect(cx + cancelSize + u, cy, colW - cancelSize - u, L.btnH)
                cy = cy + L.btnH
            end
        end
        bottom = math.max(bottom, cy)
    end
    for c = 1, cols do
        L.columns[c].h = bottom - L.colHeadY
    end
    L.paper.h = bottom + L.pad - paperY
    L.W = math.floor(W)
    L.H = math.floor(L.paper.y + L.paper.h + L.frame)
    return L
end

--- Rectangles d'une ligne de lot : ligne, libellé, coût (bord droit), zone des
--- contrôles (raison), boutons − et +, case de quantité.
function RW.rowRects(L, x, y, colW)
    local row = { row = rect(x, y, colW, L.rowH) }
    local midY = y + (L.rowH - L.box) / 2
    row.label = rect(x, y, L.labelW, L.rowH)
    row.costRight = x + L.labelW + 2 * L.u + L.costW
    row.span = rect(x + L.labelW + 2 * L.u, y, colW - L.labelW - 2 * L.u, L.rowH)
    row.plus = rect(x + colW - L.box, midY, L.box, L.box)
    row.qty = rect(row.plus.x - L.gapS - L.numW, midY, L.numW, L.box)
    row.minus = rect(row.qty.x - L.gapS - L.box, midY, L.box, L.box)
    return row
end

--- Disposition complète du formulaire dans un écran de maxWidth × maxHeight
--- (nil : sans limite) : le premier mode de RW.MODES qui tient, sinon le
--- moins débordant.
function RW.computeLayout(form, maxWidth, maxHeight)
    local best, bestOverflow
    for _, mode in ipairs(RW.MODES) do
        local L = place(form, mode)
        local overflow = math.max(0, L.W - (maxWidth or L.W)) + math.max(0, L.H - (maxHeight or L.H))
        if overflow == 0 then
            return L
        end
        if not best or overflow < bestOverflow then
            best, bestOverflow = L, overflow
        end
    end
    return best
end

function RW.measureSize(form, maxWidth, maxHeight)
    local L = RW.computeLayout(form, maxWidth, maxHeight)
    return L.W, L.H
end

-- ----------------------------------------------------------------------------
-- Fenêtre
-- ----------------------------------------------------------------------------

function RW:new(x, y, width, height, player, device, form)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.device = device
    o.form = form
    o.background = false
    o.moveWithMouse = true
    o.maxWidth = width
    o.maxHeight = height
    o.cursor = 1
    o.done = false
    o:setWantKeyEvents(true)
    return o
end

function RW:createChildren()
    ISPanelJoypad.createChildren(self)
    self:layout()
end

function RW:layout()
    local L = RW.computeLayout(self.form, self.maxWidth, self.maxHeight)
    self.L = L
    if self.width ~= L.W or self.height ~= L.H then
        self:setWidth(L.W)
        self:setHeight(L.H)
    end
end

--- La radio est toujours utilisable par le joueur : talkie en main (ou sur le
--- dos en solo), ou appareil posé à portée, au même étage.
function RW:deviceValid()
    local device, player = self.device, self.player
    if not device or not player or player:isDead() then
        return false
    end
    if Radio.isInventoryRadio(device) then
        return Radio.isCarried(player, device)
    end
    if device:getObjectIndex() == -1 then
        return false
    end
    local square = device:getSquare()
    if not square or math.floor(player:getZ()) ~= square:getZ() then
        return false
    end
    local limit = RW.CLOSE_DISTANCE
    return math.abs(player:getX() - (square:getX() + 0.5)) <= limit
        and math.abs(player:getY() - (square:getY() + 0.5)) <= limit
end

--- Lignes accessibles à la manette : lots permis, leurre, secteurs.
function RW:navigation()
    local items = {}
    for _, section in ipairs(RW.sections(self.form)) do
        for _, lot in ipairs(section.lots) do
            if lot.allowed then
                items[#items + 1] = { kind = "lot", id = lot.id }
            end
        end
        if section.decoy and self.form.decoy.allowed then
            items[#items + 1] = { kind = "decoy" }
            items[#items + 1] = { kind = "sectors" }
        end
    end
    return items
end

function RW:transmit()
    local now = getTimestampMs()
    if self.done or not RW.canTransmit(self.form, now) then
        return false
    end
    self.done = true
    local Client = MilitaryDrop.Client
    if Client and Client.sendRequisition then
        local order = RW.buildOrder(self.form, nil)
        Client.sendRequisition(self.form.requestId, order.order, order.decoy, self.form)
    end
    self:close()
    return true
end

--- Annulation : bouton « Annuler » (le personnage le dit à la radio), ou
--- fermeture de la feuille (croix, Échap, B, radio hors de portée).
function RW:cancel(spoken)
    if not self.done then
        self.done = true
        local Client = MilitaryDrop.Client
        if Client and Client.cancelRequisition then
            Client.cancelRequisition(self.form.requestId, spoken == true)
        end
    end
    self:close()
end

function RW:close()
    self:showTooltip(nil)
    if not self.done then
        -- Fermée sans transmettre : la réquisition est annulée.
        self:cancel(false)
        return
    end
    self:setVisible(false)
    if JoypadState and JoypadState.players[self.playerNum + 1] and getFocusForPlayer(self.playerNum) == self then
        setJoypadFocus(self.playerNum, nil)
    end
    self:removeFromUIManager()
    if RW.instances[self.playerNum] == self then
        RW.instances[self.playerNum] = nil
    end
end

-- ----------------------------------------------------------------------------
-- Souris
-- ----------------------------------------------------------------------------

local function inside(r, x, y)
    return r ~= nil and x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h
end

--- Élément sous (x, y) : nom, donnée (lot ou secteur).
function RW:hitTest(x, y)
    local L = self.L
    if not L then
        return nil
    end
    if inside(L.close, x, y) then
        return "close"
    elseif inside(L.transmit, x, y) then
        return "transmit"
    elseif inside(L.cancel, x, y) then
        return "cancel"
    end
    for _, lot in ipairs(self.form.lots) do
        local row = L.rows[lot.id]
        if row then
            if lot.allowed and inside(row.minus, x, y) then
                return "minus", lot.id
            elseif lot.allowed and inside(row.plus, x, y) then
                return "plus", lot.id
            elseif inside(row.row, x, y) then
                return "lot", lot.id
            end
        end
    end
    for _, sector in ipairs(self.form.decoy and self.form.decoy.sectors or {}) do
        if inside(L.sectorBoxes[sector], x, y) then
            return "sector", sector
        end
    end
    if L.decoyRow and inside(L.decoyRow.row, x, y) then
        return "decoy"
    end
    return nil
end

function RW:mouseTarget()
    if not self:isReallyVisible() then
        return nil
    end
    local x, y = self:getMouseX(), self:getMouseY()
    if x < 0 or y < 0 or x >= self.width or y >= self.height then
        return nil
    end
    return self:hitTest(x, y)
end

function RW:isEnabled(target, payload)
    local form, now = self.form, getTimestampMs()
    if target == "close" or target == "cancel" then
        return true
    elseif target == "transmit" then
        return RW.canTransmit(form, now)
    elseif RW.expired(form, now) then
        return false
    elseif target == "minus" then
        return RW.canRemove(form, payload)
    elseif target == "plus" then
        return RW.canAdd(form, payload)
    elseif target == "decoy" then
        return RW.canToggleDecoy(form)
    elseif target == "sector" then
        return RW.canPickSector(form, payload)
    end
    return false
end

function RW:activate(target, payload)
    local form = self.form
    getSoundManager():playUISound("UIActivateButton")
    if target == "close" then
        self:close()
    elseif target == "cancel" then
        self:cancel(true)
    elseif target == "transmit" then
        self:transmit()
    elseif target == "minus" then
        RW.remove(form, payload)
    elseif target == "plus" then
        RW.add(form, payload)
    elseif target == "decoy" then
        RW.toggleDecoy(form)
    elseif target == "sector" then
        RW.pickSector(form, payload)
    end
end

local CLICKABLE = { close = true, transmit = true, cancel = true, minus = true, plus = true, decoy = true, sector = true }

function RW:onMouseDown(x, y)
    local target, payload = self:hitTest(x, y)
    if CLICKABLE[target] then
        if self:isEnabled(target, payload) then
            self.pressed, self.pressedPayload = target, payload
        end
        return true
    end
    return ISPanelJoypad.onMouseDown(self, x, y)
end

function RW:onMouseUp(x, y)
    local pressed, payload = self.pressed, self.pressedPayload
    self.pressed, self.pressedPayload = nil, nil
    if pressed then
        local target, again = self:hitTest(x, y)
        if target == pressed and again == payload and self:isEnabled(pressed, payload) then
            self:activate(pressed, payload)
        end
        return true
    end
    return ISPanelJoypad.onMouseUp(self, x, y)
end

function RW:onMouseUpOutside(x, y)
    self.pressed, self.pressedPayload = nil, nil
    return ISPanelJoypad.onMouseUpOutside(self, x, y)
end

-- ----------------------------------------------------------------------------
-- Infobulles
-- ----------------------------------------------------------------------------

local function escape(text)
    return (tostring(text or ""):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

--- Texte riche de l'infobulle de la cible, ou nil.
function RW:tooltipFor(target, payload)
    local form = self.form
    if target == "lot" or target == "minus" or target == "plus" then
        local lot = form.byId[payload]
        if not lot then
            return nil
        end
        local parts = { " <RGB:1,1,1> " .. escape(RW.lotLabel(lot)) .. " <LINE> " }
        if lot.desc then
            parts[#parts + 1] = " <RGB:0.85,0.85,0.85> " .. escape(getText(lot.desc)) .. " <LINE> "
        end
        if not lot.allowed then
            parts[#parts + 1] = " <RGB:1,0.55,0.45> " .. escape(RW.reasonText(lot))
        end
        return table.concat(parts)
    elseif target == "decoy" or target == "sector" then
        local parts = { " <RGB:1,1,1> " .. escape(getText("IGUI_MilitaryDrop_ReqDecoy")) .. " <LINE> ",
            " <RGB:0.85,0.85,0.85> " .. escape(getText("IGUI_MilitaryDrop_ReqDecoyDesc")) }
        if target == "sector" then
            parts[#parts + 1] = " <LINE> <RGB:1,1,1> " .. escape(getText("IGUI_MilitaryDrop_ReqSectorName_" .. payload))
        elseif form.decoy and not form.decoy.allowed then
            parts[#parts + 1] = " <LINE> <RGB:1,0.55,0.45> " .. escape(RW.reasonText(form.decoy))
        end
        return table.concat(parts)
    elseif target == "transmit" then
        local blocker = RW.blocker(form, getTimestampMs())
        return blocker and escape(getText("IGUI_MilitaryDrop_ReqBlock_" .. blocker)) or nil
    elseif target == "close" then
        return escape(getText("IGUI_MilitaryDrop_ReqCancel"))
    end
    return nil
end

function RW:showTooltip(text)
    if text and text ~= "" then
        if not self.tooltipUI then
            self.tooltipUI = ISToolTip:new()
            self.tooltipUI:setOwner(self)
            self.tooltipUI:setVisible(false)
            self.tooltipUI:setAlwaysOnTop(true)
            self.tooltipUI.maxLineWidth = 340
        end
        if not self.tooltipUI:getIsVisible() then
            self.tooltipUI:addToUIManager()
            self.tooltipUI:setVisible(true)
        end
        self.tooltipUI.description = text
        self.tooltipUI:setDesiredPosition(getMouseX(), getMouseY() + self.L.fh + 8)
    elseif self.tooltipUI and self.tooltipUI:getIsVisible() then
        self.tooltipUI:setVisible(false)
        self.tooltipUI:removeFromUIManager()
    end
end

function RW:update()
    ISPanelJoypad.update(self)
    if not self:getIsVisible() then
        return
    end
    if not self:deviceValid() then
        self:close()
        return
    end
    self:showTooltip(self:tooltipFor(self:mouseTarget()))
end

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
    local word = getText(expired and "IGUI_MilitaryDrop_ReqStampExpired" or "IGUI_MilitaryDrop_ReqStamp")
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

--- Pied : budget, engagé, restant (points de conduite), note, boutons.
function RW:drawFooter(hover, now)
    local L, form = self.L, self.form
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

-- ----------------------------------------------------------------------------
-- Clavier et manette
-- ----------------------------------------------------------------------------

-- Échap ferme la feuille (annulation) sans ouvrir le menu de pause.
function RW:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
end

function RW:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE and self:isReallyVisible() then
        self:close()
    end
end

-- Manette : haut et bas choisissent la ligne, gauche et droite retirent ou
-- ajoutent (leurre : décoche ou coche ; secteurs : tour de la rose), A
-- transmet, B annule.
function RW:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self.drawJoypadFocus = true
end

function RW:onLoseJoypadFocus(joypadData)
    ISPanelJoypad.onLoseJoypadFocus(self, joypadData)
    self.drawJoypadFocus = false
end

function RW:moveCursor(delta)
    local count = #self:navigation()
    if count > 0 then
        self.cursor = math.max(1, math.min(count, self.cursor + delta))
    end
end

--- Gauche (-1) ou droite (+1) sur la ligne de la manette.
function RW:stepCursor(delta)
    local form = self.form
    if RW.expired(form, getTimestampMs()) then
        return
    end
    local item = self:navigation()[self.cursor]
    if not item then
        return
    end
    if item.kind == "lot" then
        if delta > 0 then
            RW.add(form, item.id)
        else
            RW.remove(form, item.id)
        end
    elseif item.kind == "decoy" then
        if (delta > 0) ~= form.decoyOn then
            RW.toggleDecoy(form)
        end
    elseif item.kind == "sectors" then
        local sectors = form.decoy.sectors
        local index = 0
        for i, sector in ipairs(sectors) do
            if sector == form.sector then
                index = i
            end
        end
        index = index + delta
        if index < 1 then
            index = #sectors
        elseif index > #sectors then
            index = 1
        end
        RW.pickSector(form, sectors[index])
    end
end

function RW:onJoypadDown(button)
    if button == Joypad.AButton then
        self:transmit()
    elseif button == Joypad.BButton then
        self:cancel(true)
    end
end

function RW:onJoypadDirUp()
    self:moveCursor(-1)
end

function RW:onJoypadDirDown()
    self:moveCursor(1)
end

function RW:onJoypadDirLeft()
    self:stepCursor(-1)
end

function RW:onJoypadDirRight()
    self:stepCursor(1)
end

function RW:getAPrompt()
    return getText("IGUI_MilitaryDrop_ReqTransmit")
end

function RW:getBPrompt()
    return getText("IGUI_MilitaryDrop_ReqCancel")
end

-- ----------------------------------------------------------------------------
-- Ouverture
-- ----------------------------------------------------------------------------

--- Ouvre la feuille du joueur pour le Result « form » args (reçu à
--- receivedMs). Une feuille déjà ouverte pour ce joueur est annulée.
function RW.open(player, device, args, receivedMs)
    return RW.show(player, device, RW.newForm(args, receivedMs or getTimestampMs()))
end

--- Affiche la feuille d'un formulaire (nouveau, ou rouvert après un refus
--- qui garde l'autorisation : radio éteinte, cadence).
function RW.show(player, device, form)
    local playerNum = player:getPlayerNum()
    local previous = RW.instances[playerNum]
    if previous then
        previous:close()
    end
    local screenW, screenH = getPlayerScreenWidth(playerNum), getPlayerScreenHeight(playerNum)
    local width, height = RW.measureSize(form, screenW, screenH)
    width, height = math.min(width, screenW), math.min(height, screenH)
    local x = getPlayerScreenLeft(playerNum) + math.floor((screenW - width) / 2)
    local y = getPlayerScreenTop(playerNum) + math.floor((screenH - height) / 2)
    local window = RW:new(x, y, width, height, player, device, form)
    window.maxWidth, window.maxHeight = screenW, screenH
    window:initialise()
    window:instantiate()
    window:addToUIManager()
    RW.instances[playerNum] = window
    if JoypadState and JoypadState.players[playerNum + 1] then
        if getPlayerInventory(playerNum) then
            getPlayerInventory(playerNum):close()
        end
        if getPlayerLoot(playerNum) then
            getPlayerLoot(playerNum):close()
        end
        setJoypadFocus(playerNum, window)
    end
    return window
end

--- Ferme sans rien envoyer la feuille d'une demande que le serveur a déjà
--- tranchée (réponse reçue pendant que la feuille est ouverte).
function RW.dismiss(requestId)
    local closing = {}
    for _, window in pairs(RW.instances) do
        if window.form.requestId == requestId then
            closing[#closing + 1] = window
        end
    end
    for _, window in ipairs(closing) do
        window.done = true
        window:close()
    end
end

return RW
