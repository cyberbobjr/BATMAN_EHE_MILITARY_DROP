-- Military Drop — formulaire de réquisition (client) : formulaire, budget, secteurs et lots (fonctions pures)
-- Partie de MilitaryDrop_RequisitionWindow.lua (voir son en-tête).

require "MilitaryDrop/MilitaryDrop_RequisitionWindow"

local RW = MilitaryDrop.RequisitionWindow
local Config = MilitaryDrop.Config

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

-- Textes d'un lot ajouté par l'admin (contrat « form » : lot.texts =
-- { EN = { label = "...", desc = "..." }, FR = { ... } }) : longueur bornée.
RW.TEXT_LIMITS = { label = 80, desc = 600 }

--- Textes libres d'un lot nettoyés (langue → { label, desc } de chaînes non
--- vides, tronquées), ou nil s'il n'y en a aucun.
function RW.cleanTexts(texts)
    if type(texts) ~= "table" then
        return nil
    end
    local clean, any = {}, false
    for language, entry in pairs(texts) do
        if type(language) == "string" and type(entry) == "table" then
            local kept = {}
            for field, limit in pairs(RW.TEXT_LIMITS) do
                local value = entry[field]
                if type(value) == "string" and value ~= "" then
                    -- Sans couper un caractère (chaîne Java sous Kahlua).
                    kept[field] = MilitaryDrop.cutText(value, limit)
                    any = true
                end
            end
            clean[string.upper(language)] = kept
        end
    end
    return any and clean or nil
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
        forced = args.forced == true,
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
                texts = RW.cleanTexts(lot.texts),
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
        local zones = decoy.zones == true
        local sectors
        if zones then
            sectors = RW.zoneSectors(decoy.sectors)
        else
            -- Proximité : seulement N, E, S, W (secteurs inconnus écartés).
            local known = {}
            sectors = {}
            for _, sector in ipairs(RW.SECTORS) do
                known[sector] = true
            end
            for _, sector in ipairs(type(decoy.sectors) == "table" and decoy.sectors or RW.SECTORS) do
                if known[sector] then
                    sectors[#sectors + 1] = sector
                    known[sector] = false
                end
            end
        end
        form.decoy = {
            cost = math.max(1, toInt(decoy.cost, 1)),
            allowed = decoy.allowed == true and #sectors > 0,
            reason = decoy.allowed ~= true and (type(decoy.reason) == "string" and decoy.reason or "empty") or nil,
            sectors = sectors,
            zones = zones or nil,
        }
        if decoy.allowed == true and #sectors == 0 then
            form.decoy.reason = "empty"
        end
    end
    -- Secteur de largage choisi par le joueur (ZONE-09), feuille admin
    -- comprise. Le leurre partage la liste et le sélecteur du champ.
    local drop = args.drop
    if type(drop) == "table" and drop.zones == true then
        form.drop = { sectors = RW.zoneSectors(drop.sectors) }
        if form.decoy then
            form.decoy.sectors = form.drop.sectors
            form.decoy.zones = true
            if form.decoy.allowed and #form.drop.sectors == 0 then
                form.decoy.allowed, form.decoy.reason = false, "empty"
            end
        end
    end
    -- Un seul secteur nommé : sélectionné d'office.
    form.sector = RW.fixedSector(form)
    return form
end

--- Secteurs nommés du mode zones nettoyés : textes non vides, sans caractère
--- de contrôle ni espaces de bord, bornés (sans couper un caractère), sans
--- doublon, dans l'ordre du serveur (alphabétique). Aucun nom de zone.
function RW.zoneSectors(list)
    local sectors, seen = {}, {}
    for _, name in ipairs(type(list) == "table" and list or {}) do
        if type(name) == "string" and #sectors < RW.MAX_ZONE_SECTORS then
            name = name:gsub("%c", " "):gsub("^%s+", ""):gsub("%s+$", "")
            name = MilitaryDrop.cutText(name, RW.SECTOR_NAME_LIMIT)
            if name ~= "" and not seen[name] then
                seen[name] = true
                sectors[#sectors + 1] = name
            end
        end
    end
    return sectors
end

--- Leurre en mode zones (secteurs nommés).
function RW.zoneDecoy(form)
    return form.decoy ~= nil and form.decoy.zones == true
end

--- Secteurs nommés à choisir : champ du largage (ZONE-09) ou leurre en mode
--- zones.
function RW.namedSectors(form)
    return form.drop ~= nil or RW.zoneDecoy(form)
end

--- Secteurs du sélecteur : ceux du champ du largage s'il existe (le leurre
--- les partage), sinon ceux du leurre, sinon nil.
function RW.sectorList(form)
    if form.drop then
        return form.drop.sectors
    end
    return form.decoy and form.decoy.sectors or nil
end

--- Secteur imposé : secteurs nommés, un seul, sinon nil.
function RW.fixedSector(form)
    local sectors = RW.namedSectors(form) and RW.sectorList(form)
    if sectors and #sectors == 1 then
        return sectors[1]
    end
    return nil
end

--- Nom complet d'un secteur pour l'infobulle : le nom libre (mode zones),
--- sinon le point cardinal traduit.
function RW.sectorName(form, sector)
    if RW.namedSectors(form) then
        return sector
    end
    return getText("IGUI_MilitaryDrop_ReqSectorName_" .. tostring(sector))
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
    if not form.decoyOn and not form.drop then
        -- Secteur oublié, sauf le secteur imposé (un seul secteur nommé).
        -- Champ du largage (ZONE-09) : le secteur reste, il sert au largage.
        form.sector = RW.fixedSector(form)
    end
    return true
end

local function hasSector(form, sector)
    for _, s in ipairs(RW.sectorList(form) or {}) do
        if s == sector then
            return true
        end
    end
    return false
end

--- Un secteur peut être choisi (il coche le leurre au besoin, sauf avec le
--- champ du largage : le secteur sert alors aux lots comme au leurre).
function RW.canPickSector(form, sector)
    if form.drop then
        return hasSector(form, sector)
    end
    return hasSector(form, sector) and (form.decoyOn or RW.canToggleDecoy(form))
end

function RW.pickSector(form, sector)
    if not RW.canPickSector(form, sector) then
        return false
    end
    if not form.decoyOn and not form.drop then
        RW.toggleDecoy(form)
    end
    form.sector = sector
    return true
end

--- Le secteur peut changer par les flèches (au moins un secteur, pas de
--- secteur imposé ; leurre coché ou cochable, sauf champ du largage).
function RW.canStepSector(form)
    local sectors = RW.sectorList(form)
    return sectors ~= nil and sectors[1] ~= nil and not RW.fixedSector(form)
        and RW.canPickSector(form, sectors[1])
end

--- Secteur précédent (-1) ou suivant (+1), en boucle ; sans secteur choisi,
--- le premier (+1) ou le dernier (-1). Coche le leurre au besoin (sans champ
--- du largage).
function RW.stepSector(form, delta)
    if not RW.canStepSector(form) then
        return false
    end
    local sectors = RW.sectorList(form)
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
    return RW.pickSector(form, sectors[index])
end

function RW.expired(form, nowMs)
    return nowMs >= form.deadline
end

--- Motif qui empêche de transmettre (« expired », « sector », « nothing »,
--- « budget »), ou nil. Champ du largage (ZONE-09) : les lots aussi
--- attendent un secteur.
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
    elseif form.drop and not form.sector then
        return "sector"
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
--- decoy = secteur ou nil, sector = secteur du largage (ZONE-09) ou nil }.
--- Le leurre part seul (order vide, sans sector).
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
        decoy = form.decoyOn and form.sector or nil,
        sector = (form.drop and not form.decoyOn) and form.sector or nil }
end

--- Clé du mot du tampon tant que la feuille est valide : « ADMIN » pour un
--- largage forcé, sinon « Autorisé ».
function RW.stampKey(form)
    return form.forced and "IGUI_MilitaryDrop_ReqStampAdmin" or "IGUI_MilitaryDrop_ReqStamp"
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

--- Langues du client pour les textes libres : la sienne, puis sa langue de
--- base (Language.name et Language.base, zombie/core/Language.java), puis EN.
function RW.languages()
    local list = {}
    local language = Translator and Translator.getLanguage and Translator.getLanguage()
    if language then
        list[#list + 1] = tostring(language:name())
        if language.base then
            local base = language:base()
            if base ~= nil then
                list[#list + 1] = tostring(base)
            end
        end
    end
    list[#list + 1] = "EN"
    return list
end

--- Texte libre d'un lot (field : "label" ou "desc") dans la langue du
--- client, sinon sa langue de base, sinon en anglais, sinon dans la première
--- langue qui le fournit (ordre alphabétique, comme Lots.text sur le
--- serveur), sinon nil.
function RW.lotText(lot, field)
    local texts = lot.texts
    if not texts then
        return nil
    end
    for _, language in ipairs(RW.languages()) do
        local entry = texts[string.upper(language)]
        if entry and entry[field] then
            return entry[field]
        end
    end
    local languages = {}
    for language, entry in pairs(texts) do
        if entry[field] then
            languages[#languages + 1] = language
        end
    end
    table.sort(languages)
    return languages[1] and texts[languages[1]][field] or nil
end

--- Libellé d'un lot : texte libre de l'admin, sinon clé de traduction, sinon id.
function RW.lotLabel(lot)
    return RW.lotText(lot, "label") or (lot.label and getText(lot.label)) or lot.id
end

--- Description d'un lot (même ordre que le libellé), ou nil.
function RW.lotDesc(lot)
    return RW.lotText(lot, "desc") or (lot.desc and getText(lot.desc)) or nil
end

function RW.sectionLabel(group)
    if group == "special" then
        return getText("IGUI_MilitaryDrop_ReqGroupSpecial")
    end
    return getText("IGUI_MilitaryDrop_ReqGroup" .. math.min(group, RW.GROUP_COUNT))
end

--- Sections dans l'ordre d'affichage : paliers croissants (ordre du serveur
--- dans chaque palier), puis la commande spéciale. view (facultatif, feuille
--- paginée) : { ids = { [id] = true }, decoy = bool } garde les lots de la page.
function RW.sections(form, view)
    local byGroup, groups = {}, {}
    for _, lot in ipairs(form.lots) do
        if not view or view.ids[lot.id] then
            if not byGroup[lot.group] then
                byGroup[lot.group] = {}
                groups[#groups + 1] = lot.group
            end
            local list = byGroup[lot.group]
            list[#list + 1] = lot
        end
    end
    table.sort(groups)
    local sections = {}
    for _, group in ipairs(groups) do
        sections[#sections + 1] = { group = group, lots = byGroup[group] }
    end
    if form.decoy and (not view or view.decoy) then
        sections[#sections + 1] = { group = "special", lots = {}, decoy = true }
    end
    return sections
end

return RW
