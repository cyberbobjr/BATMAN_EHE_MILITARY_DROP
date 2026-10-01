-- ============================================================================
-- Military Drop — console du poste de liaison (client)
--
-- Menu contextuel d'une radio posée pouvant servir de poste (non portable,
-- haut de gamme, émettrice : propriétés DeviceData, aucun nom d'objet) :
--   * « Installer le poste de liaison » : le serveur l'enregistre pour
--     l'équipe du joueur (un poste par équipe ; installer ailleurs déplace) ;
--   * « Poste de liaison » sur le poste de l'équipe : console « poste radio
--     militaire » : façade de tôle olive vissée, voyants (marche, réception,
--     alimentation), indicatif sur ruban, fréquence sur afficheur, journal sur
--     écran à phosphore vert façon téléimprimeur, ordres de mission (échéance,
--     barre de progression), casier des plaques d'identité (bouton
--     « Transmettre »), confiance en galons (paliers en mots, jamais de chiffre).
-- Tout est dessiné par la fenêtre (textures du mod, polices du jeu) ; les
-- largeurs sont mesurées selon la langue et la taille de police.
--
-- Le client ne décide rien : il connaît seulement la position du poste de son
-- équipe (PostInfo) pour choisir l'entrée du menu, et affiche ce que le serveur
-- envoie (PostData), qui revérifie équipe, poste, distance et objets.
--
-- La console ne dit jamais si la radio est sur la fréquence militaire (elle
-- servirait à la trouver en balayant les canaux) : le voyant de réception ne
-- reflète que la dernière entrée du journal (reçue ou « aucune réception »).
--
-- Solo : MilitaryDrop.Net appelle directement MilitaryDrop.Client.onServerCommand,
-- dont les gestionnaires HANDLERS reçoivent les commandes du poste. MP :
-- événement OnServerCommand.
-- ============================================================================

require "ISUI/ISPanelJoypad"
require "ISUI/ISRichTextPanel"
require "ISUI/ISToolTip"
require "MilitaryDrop/MilitaryDrop_Net"
require "MilitaryDrop/MilitaryDrop_Radio"
require "MilitaryDrop/MilitaryDrop_Codes"
require "MilitaryDrop/MilitaryDrop_Exchange"
require "MilitaryDrop/MilitaryDrop_Client"

local Config = MilitaryDrop.Config
local Net = MilitaryDrop.Net
local Radio = MilitaryDrop.Radio
local Codes = MilitaryDrop.Codes

local PostWindow = ISPanelJoypad:derive("MilitaryDropPostWindow")
MilitaryDrop.PostWindow = PostWindow

PostWindow.DEPOSIT_MAX = 50
-- Rafraîchissement de la console ouverte (ms réelles).
PostWindow.REFRESH_MS = 10000
-- Fermeture quand le joueur s'éloigne : même portée que le serveur
-- (Radio.isNear), sinon la console resterait ouverte sans pouvoir agir.
PostWindow.CLOSE_DISTANCE = Radio.MAX_WORLD_DISTANCE + 0.5
PostWindow.TIER_COUNT = 4
-- Hauteur de la colonne « Confiance », en lignes : phrase, demi-ligne, effet.
PostWindow.STANDING_LINES = 7
-- Lignes visibles du journal (moins si l'écran du joueur est petit).
PostWindow.JOURNAL_LINES = 9
PostWindow.JOURNAL_MIN_LINES = 4
-- Durée du clignotement du voyant de réception après une nouvelle ligne (ms).
PostWindow.RX_FLASH_MS = 2500
-- Textures du mod (common/media/textures/MilitaryDrop/PostConsole) ; préfixe
-- distinctif : le jeu cherche d'abord le nom de base dans ses packs.
PostWindow.TEXTURE_PATH = "media/textures/MilitaryDrop/PostConsole/MDPost_"
-- Durée totale d'une mission par type, si le serveur ne l'envoie pas (heures).
PostWindow.HOURS_OPTIONS = { recon = "ReconHours", cleanup = "CleanupHours", control = "ControlHours" }
-- Langues dont l'alphabet tient dans la police à chasse fixe du jeu (Latin-1) :
-- journal et plaques en caractères de téléimprimeur ; sinon police normale.
PostWindow.MONO_LANGUAGES = {
    EN = true, FR = true, DE = true, ES = true, IT = true, PT = true, PTBR = true, NL = true, DA = true,
    NO = true, FI = true, ID = true,
}

-- Couleurs du texte riche du journal (phosphore vert).
PostWindow.COLORS = {
    stamp = "0.32,0.66,0.38",
    line = "0.62,1,0.62",
    gap = "0.42,0.62,0.42",
    sys = "0.86,1,0.62",
    text = "0.5,0.82,0.54",
}
-- Couleurs de la façade (r, g, b).
local PAINT = { 0.92, 0.9, 0.78 }
local INK = { 0.16, 0.15, 0.13 }
local INK_RED = { 0.62, 0.12, 0.1 }
local AMBER = { 1, 0.7, 0.22 }
local GREEN = { 0.4, 1, 0.42 }
local RED = { 1, 0.28, 0.2 }
local METAL = { 0.34, 0.35, 0.24 }

-- Statuts de PostResult affichés (IGUI_MilitaryDrop_PostResult_<statut>) ;
-- « busy » (cadence du serveur) n'affiche rien.
PostWindow.RESULTS = {
    installed = true, moved = true, already = true, otherTeam = true, notEligible = true, notPost = true,
    tooFar = true, deposited = true, noTags = true, emptyMail = true, radioOff = true, noAnswer = true,
    unavailable = true, transmitted = true, held = true, lineCut = true,
}

-- Statuts qui ferment la console du joueur : poste qui n'est plus le sien
-- (sorti de la faction, poste déplacé) ou hors de portée.
PostWindow.CLOSING = { notPost = true, otherTeam = true, tooFar = true }

-- Position du poste de l'équipe ({ x, y, z }), envoyée par le serveur.
PostWindow.myPost = nil
PostWindow.instances = {}
local pendingOpen = nil

-- ----------------------------------------------------------------------------
-- Radio et poste
-- ----------------------------------------------------------------------------

--- Radio posée pouvant servir de poste (même règle que MilitaryDrop.Post.isEligible).
function PostWindow.isEligible(object)
    if not Radio.isWorldRadio(object) then
        return false
    end
    local data = object:getDeviceData()
    return data ~= nil and not data:getIsPortable() and data:getIsHighTier() == true and data:getIsTwoWay() == true
end

--- La radio est à l'emplacement du poste de l'équipe (le serveur revérifie).
function PostWindow.isOwnPost(object)
    local post = PostWindow.myPost
    local square = object and object:getSquare()
    return post ~= nil and square ~= nil and square:getX() == post.x and square:getY() == post.y
        and square:getZ() == post.z
end

local function sendToServer(player, command, object, extra)
    local args = extra or {}
    args.radio = Radio.makeRef(object)
    Net.toServer(player, command, args)
end

function PostWindow.requestInstall(player, object)
    sendToServer(player, "PostInstall", object)
end

function PostWindow.requestOpen(player, object)
    pendingOpen = { playerNum = player:getPlayerNum(), object = object }
    sendToServer(player, "PostOpen", object)
end

--- Plaque d'identité transmissible (MilitaryDrop.Exchange.isDogTag : plaque
--- vanilla gravée, pas celle du joueur) ; repli : étiquette du jeu seule.
function PostWindow.isDogTag(item, player)
    local Exchange = MilitaryDrop.Exchange
    if type(Exchange) == "table" and type(Exchange.isDogTag) == "function" then
        return Exchange.isDogTag(item, player) == true
    end
    return ItemTag ~= nil and ItemTag.DOG_TAG ~= nil and item:hasTag(ItemTag.DOG_TAG)
end

--- Nom gravé sur une plaque de l'inventaire.
function PostWindow.dogTagLabel(item)
    local Exchange = MilitaryDrop.Exchange
    if type(Exchange) == "table" and type(Exchange.dogTagLabel) == "function" then
        local label = Exchange.dogTagLabel(item)
        if label ~= nil and label ~= "" then
            return tostring(label)
        end
    end
    return tostring(item:getDisplayName())
end

--- Plaques d'identité de l'inventaire (sacs compris), ni portées ni accrochées
--- (MilitaryDrop.Exchange.findDogTags s'il existe).
function PostWindow.dogTags(player)
    local Exchange = MilitaryDrop.Exchange
    if type(Exchange) == "table" and type(Exchange.findDogTags) == "function" then
        return Exchange.findDogTags(player, PostWindow.DEPOSIT_MAX)
    end
    local found = {}
    local items = player:getInventory():getAllEvalRecurse(function(item)
        return PostWindow.isDogTag(item, player)
    end)
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if #found < PostWindow.DEPOSIT_MAX and not player:isEquipped(item) and not player:isAttachedItem(item) then
            found[#found + 1] = item
        end
    end
    return found
end

-- ----------------------------------------------------------------------------
-- Menu contextuel
-- ----------------------------------------------------------------------------

local function addTooltip(option, text)
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip:setVisible(false)
    tooltip.description = text
    option.toolTip = tooltip
end

function PostWindow.addOptions(player, context, object)
    local option
    if PostWindow.isOwnPost(object) then
        option = context:addOption(getText("IGUI_MilitaryDrop_PostOpen"), player, PostWindow.requestOpen, object)
    else
        option = context:addOption(getText("IGUI_MilitaryDrop_PostInstall"), player, PostWindow.requestInstall, object)
        addTooltip(option, getText("IGUI_MilitaryDrop_PostInstallTooltip"))
    end
    if not Radio.isNear(player, object) then
        option.notAvailable = true
        addTooltip(option, getText("IGUI_MilitaryDrop_PostResult_tooFar"))
    end
end

function PostWindow.onFillWorldContextMenu(playerNum, context, worldObjects, test)
    if test then
        return
    end
    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end
    local seen = {}
    for _, object in ipairs(worldObjects) do
        local square = object and object:getSquare()
        if square and not seen[square] then
            seen[square] = true
            local objects = square:getObjects()
            for i = 0, objects:size() - 1 do
                local candidate = objects:get(i)
                if PostWindow.isEligible(candidate) then
                    PostWindow.addOptions(player, context, candidate)
                    return
                end
            end
        end
    end
end

-- ----------------------------------------------------------------------------
-- Mise en forme (fonctions pures, testées hors jeu)
-- ----------------------------------------------------------------------------

--- Date et heure d'une entrée (horloge du calendrier, Codes.clockHours).
function PostWindow.stamp(clock)
    clock = tonumber(clock) or 0
    local dayIndex = math.floor(clock / 24)
    local _, month, day = Codes.civilFromDays(dayIndex - 3)
    local hours = clock - dayIndex * 24
    local hh = math.floor(hours)
    local mm = math.min(59, math.floor((hours - hh) * 60))
    return getText("IGUI_MilitaryDrop_PostTime", string.format("%02d", day), string.format("%02d", month),
        string.format("%02d:%02d", hh, mm))
end

--- Texte de la base inséré dans un texte riche (« < » et « > » échappés).
local function escape(text)
    return (tostring(text or ""):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
PostWindow.escape = escape

local function rgb(name)
    return " <RGB:" .. PostWindow.COLORS[name] .. "> "
end

--- Texte riche du journal (entrées les plus anciennes en haut).
function PostWindow.journalText(lines)
    local parts = {}
    for _, entry in ipairs(lines or {}) do
        local text
        if entry.gap then
            text = rgb("gap") .. escape(getText("IGUI_MilitaryDrop_PostGap", tostring(entry.gap)))
        elseif entry.sys then
            text = rgb("sys") .. escape(getText("IGUI_MilitaryDrop_PostSys_" .. tostring(entry.sys)))
        else
            text = rgb("line") .. escape(entry.t)
        end
        -- ISRichTextPanel avale les espaces autour des balises : <SPACE> sépare
        -- l'heure du texte.
        parts[#parts + 1] = rgb("stamp") .. PostWindow.stamp(entry.c) .. " <SPACE> <SPACE> " .. text .. " <LINE> "
    end
    if #parts == 0 then
        return rgb("text") .. escape(getText("IGUI_MilitaryDrop_PostLogEmpty"))
    end
    return table.concat(parts)
end

--- État en toutes lettres (infobulle des voyants) : indicatif, fréquence, alimentation, marche.
function PostWindow.statusText(data)
    local power = getText("IGUI_MilitaryDrop_PostPower_" .. tostring(data.power or "none"))
    local parts = {
        tostring(data.callsign or ""),
        getText("IGUI_MilitaryDrop_PostFrequency", Config.formatChannel(tonumber(data.channel) or 0)),
        getText("IGUI_MilitaryDrop_PostPower", power),
        getText(data.on and "IGUI_MilitaryDrop_PostOn" or "IGUI_MilitaryDrop_PostOff"),
    }
    return table.concat(parts, "  |  ")
end

--- Palier de confiance valide (1 à TIER_COUNT), sinon nil.
local function tierOf(data)
    local tier = math.floor(tonumber(data.tier) or 0)
    if tier < 1 or tier > PostWindow.TIER_COUNT then
        return nil
    end
    return tier
end

--- Phrase de confiance par palier, sans chiffre (ligne coupée d'abord) : infobulle de l'écusson.
function PostWindow.trustText(data)
    if data.lineCut then
        return getText("IGUI_MilitaryDrop_PostLineCut")
    end
    local tier = tierOf(data)
    if not tier then
        return ""
    end
    return getText("IGUI_MilitaryDrop_PostTrust" .. tier)
end

--- Effet concret de la confiance sur les largages, sans chiffre (ligne
--- coupée d'abord).
function PostWindow.effectText(data)
    if data.lineCut then
        return getText("IGUI_MilitaryDrop_PostEffectLineCut")
    end
    local tier = tierOf(data)
    if not tier then
        return ""
    end
    return getText("IGUI_MilitaryDrop_PostEffect" .. tier)
end

--- Voyants : marche (allumé et alimenté), réception (dernière entrée du journal
--- reçue, poste allumé et alimenté), alimentation (source, charge si connue).
function PostWindow.lamps(data)
    local powered = data.power ~= nil and data.power ~= "none"
    local on = data.on == true and powered
    local rx = false
    if on then
        local lines = data.lines or {}
        for i = #lines, 1, -1 do
            local entry = lines[i]
            if not entry.sys then
                rx = not entry.gap
                break
            end
        end
    end
    local battery = tonumber(data.battery)
    if battery then
        battery = math.max(0, math.min(1, battery))
    end
    local level = "ok"
    if not powered then
        level = "none"
    elseif data.power == "battery" then
        level = (battery and battery < 0.15) and "low" or "battery"
    end
    return { on = on, rx = rx, power = powered, level = level, battery = battery }
end

--- Durée totale d'une mission (heures) : envoyée par le serveur, sinon option du type.
local function missionHours(mission)
    local hours = tonumber(mission.hours)
    if not hours then
        local option = PostWindow.HOURS_OPTIONS[tostring(mission.kind)]
        hours = option and tonumber(Config.get(option))
    end
    if hours and hours > 0 then
        return hours
    end
    return nil
end

--- Ordre de mission affiché : titre, échéance, ligne secondaire, barre.
--- bar = { fraction 0..1, label, kind = "progress" | "time", urgent }.
function PostWindow.missionView(mission)
    local view = { title = tostring(mission.title or mission.kind or ""), due = "", sub = "" }
    local remaining = tonumber(mission.remaining)
    if remaining then
        if remaining >= 1 then
            view.due = getText("IGUI_MilitaryDrop_PostDue", tostring(math.ceil(remaining)))
        else
            view.due = getText("IGUI_MilitaryDrop_PostDueSoon")
        end
    end
    local progress, quota = tonumber(mission.progress), tonumber(mission.quota)
    local x, y = tonumber(mission.x), tonumber(mission.y)
    if x and y then
        view.sub = getText("IGUI_MilitaryDrop_PostGrid", tostring(math.floor(x)), tostring(math.floor(y)))
    elseif progress and quota == 1 then
        view.sub = getText(progress >= 1 and "IGUI_MilitaryDrop_PostControlDone" or "IGUI_MilitaryDrop_PostControlWait")
    end
    view.done = progress ~= nil and quota ~= nil and quota > 0 and progress >= quota
    local hours = missionHours(mission)
    if progress and quota and quota > 1 then
        view.bar = { kind = "progress", fraction = math.max(0, math.min(1, progress / quota)),
            label = string.format("%d / %d", math.floor(progress), math.floor(quota)) }
    elseif remaining and hours then
        view.bar = { kind = "time", fraction = math.max(0, math.min(1, remaining / hours)), label = "" }
    end
    if view.bar and remaining and hours then
        view.bar.urgent = remaining < math.max(1, hours * 0.2)
    end
    return view
end

--- Infobulle d'un ordre : texte complet de la base.
function PostWindow.missionTooltip(mission)
    local view = PostWindow.missionView(mission)
    local parts = { " <RGB:1,1,1> " .. escape(view.title) .. " <LINE> " }
    if mission.text and mission.text ~= "" then
        parts[#parts + 1] = " <RGB:0.85,0.85,0.85> " .. escape(mission.text) .. " <LINE> "
    end
    if view.due ~= "" then
        parts[#parts + 1] = " <RGB:0.7,0.7,0.7> " .. escape(view.due)
    end
    return table.concat(parts)
end

--- Nom gravé sur une plaque du casier ({ id, name, by } ; ancien format : serial).
function PostWindow.mailName(entry)
    local name = entry.name or entry.serial
    if name == nil or name == "" then
        return "?"
    end
    return tostring(name)
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

--- Police à chasse fixe si la langue tient en Latin-1, sinon UIFont.Small.
function PostWindow.monoFont()
    -- Translator.getLanguage():name() : même lecture que le vanilla (ISLcdBar.lua:14).
    local language = Translator and Translator.getLanguage()
    local name = language and language:name()
    if name and PostWindow.MONO_LANGUAGES[tostring(name)] and UIFont.CodeSmall then
        return UIFont.CodeSmall
    end
    return UIFont.Small
end

--- Retire le dernier caractère. Kahlua : un caractère Java ; Lua 5.1 (tests) :
--- un octet de tête UTF-8 et ses octets de suite, jamais un caractère coupé.
local function dropLastChar(text)
    return (text:gsub("[^\128-\191][\128-\191]*$", ""))
end

--- Texte raccourci (« … » en trois points) pour tenir dans maxWidth.
function PostWindow.fit(text, font, maxWidth)
    text = tostring(text or "")
    if measure(text, font) <= maxWidth then
        return text
    end
    while #text > 0 and measure(text .. "...", font) > maxWidth do
        text = dropLastChar(text)
    end
    return text .. "..."
end

--- Coupe un texte en lignes de maxWidth au plus (mots entiers).
function PostWindow.wrap(text, font, maxWidth)
    local lines, current = {}, ""
    for word in tostring(text or ""):gmatch("[^ ]+") do
        local candidate = current == "" and word or (current .. " " .. word)
        if current ~= "" and measure(candidate, font) > maxWidth then
            lines[#lines + 1] = current
            current = word
        else
            current = candidate
        end
    end
    if current ~= "" then
        lines[#lines + 1] = current
    end
    return lines
end

local function rect(x, y, w, h)
    return { x = math.floor(x), y = math.floor(y), w = math.floor(w), h = math.floor(h) }
end

local LAMP_KEYS = { "IGUI_MilitaryDrop_PostLampOn", "IGUI_MilitaryDrop_PostLampRx", "IGUI_MilitaryDrop_PostLampPower" }
local POWER_KINDS = { "grid", "generator", "battery", "none" }

--- Disposition complète pour data (nil : avant les données) dans un écran de
--- maxWidth × maxHeight (nil : sans limite). Toutes les largeurs sont mesurées.
function PostWindow.computeLayout(data, maxWidth, maxHeight)
    local fh, fm = fontHeight(UIFont.Small), fontHeight(UIFont.Medium)
    local mono = PostWindow.monoFont()
    local lh = fontHeight(mono)
    local u = math.max(6, math.floor(fh * 0.4))
    local L = { fh = fh, fm = fm, u = u, mono = mono, lh = lh }
    local frame = 2 * u + 2
    L.frame = frame

    -- En-tête : titre peint et bouton de fermeture.
    L.closeSize = fm + 6
    L.headerH = math.max(fm, L.closeSize) + u
    local titleW = measure(getText("IGUI_MilitaryDrop_PostConsoleTitle"), UIFont.Medium) + L.closeSize + 3 * u

    -- Rangée d'état : voyants, ruban de l'indicatif, afficheur de fréquence.
    L.lampD = fh + 4
    L.statusH = L.lampD + u
    L.gaugeW = 4 * math.max(4, math.floor(fh / 3)) + 3
    local powerW = 0
    for _, kind in ipairs(POWER_KINDS) do
        powerW = math.max(powerW, measure(getText("IGUI_MilitaryDrop_PostPower_" .. kind)))
    end
    L.lampLabelW = {}
    local lampsW = 0
    for i, key in ipairs(LAMP_KEYS) do
        L.lampLabelW[i] = measure(getText(key))
        lampsW = lampsW + L.lampD + u + L.lampLabelW[i] + 2 * u
    end
    L.powerWordW = powerW + u + L.gaugeW
    lampsW = lampsW + L.powerWordW
    L.freqW = measure(getText("IGUI_MilitaryDrop_PostFrequency", "888.8"), mono) + 2 * u
    local callsign = data and data.callsign and tostring(data.callsign) or ""
    L.tapeW = math.max(measure(callsign), measure("Station Foxtrot-88")) + 3 * u
    local statusW = lampsW + 2 * u + L.tapeW + u + L.freqW

    -- Colonnes du bas : ordres, casier, confiance.
    L.gap = 2 * u
    L.btnH = fh + 12
    local btnW = 0
    for _, text in ipairs({ getText("IGUI_MilitaryDrop_PostDeposit", "99"), getText("IGUI_MilitaryDrop_PostTransmit") }) do
        btnW = math.max(btnW, measure(text) + 3 * u + fh)
    end
    L.tagW = math.max(fh * 5, measure("Xxxxxxx Xxxxxxx", mono) * 0.8 + 2 * u)
    L.tagW = math.floor(L.tagW)
    L.tagH = fh + 10
    local rackHeader = measure(getText("IGUI_MilitaryDrop_PostRack")) + measure(getText("IGUI_MilitaryDrop_PostRackCount", "99"))
        + 3 * u
    local rackW = math.max(2 * L.tagW + 3 * u, btnW + 2 * u, rackHeader)
    -- Confiance en toutes lettres : phrase du commandement, puis effet sur
    -- les largages, renvoyés à la ligne dans une colonne de largeur bornée.
    local standW = math.max(fh * 9, measure(getText("IGUI_MilitaryDrop_PostStanding")) + 2 * u)
    local ordersMin = math.max(fh * 14, measure(getText("IGUI_MilitaryDrop_PostOrders")) + 2 * u)
    local columnsW = ordersMin + rackW + standW + 2 * L.gap

    local W = 2 * frame + math.max(columnsW, statusW, titleW)
    if maxWidth and W > maxWidth then
        W = math.max(2 * frame + rackW + standW + 2 * L.gap + fh * 8, maxWidth)
    end
    W = math.floor(W)

    -- Hauteurs.
    L.barH = math.max(6, math.floor(fh * 0.45))
    L.cardH = 2 * fh + L.barH + 2 * u
    L.cardGap = math.floor(u / 2) + 1
    local ordersH = 3 * L.cardH + 2 * L.cardGap
    local rackH = 3 * (L.tagH + math.floor(u / 2)) + 2 * L.btnH + 2 * u
    local standH = PostWindow.STANDING_LINES * fh + u
    L.contentH = math.max(ordersH, rackH, standH)
    L.labelH = fh + math.floor(u / 2)
    L.bezel = u
    local fixed = frame + L.headerH + L.statusH + u + L.labelH + 2 * L.bezel + 2 * u + u + L.labelH + L.contentH + u
        + frame
    local lines = PostWindow.JOURNAL_LINES
    if maxHeight then
        lines = math.max(PostWindow.JOURNAL_MIN_LINES, math.min(lines, math.floor((maxHeight - fixed) / lh)))
    end
    L.journalLines = lines
    local H = fixed + lines * lh
    L.W, L.H = W, H

    -- Rectangles.
    local x0, inner = frame, W - 2 * frame
    local y = frame
    L.header = rect(x0, y, inner, L.headerH)
    L.close = rect(W - frame - L.closeSize, y + (L.headerH - L.closeSize) / 2, L.closeSize, L.closeSize)
    y = y + L.headerH
    L.status = rect(x0, y, inner, L.statusH)
    local rightEdge = W - frame
    L.freq = rect(rightEdge - L.freqW, y + (L.statusH - L.lampD) / 2, L.freqW, L.lampD)
    L.tape = rect(L.freq.x - u - L.tapeW, L.freq.y, L.tapeW, L.lampD)
    L.lampsArea = rect(x0, y, L.tape.x - x0 - u, L.statusH)
    y = y + L.statusH + u
    L.screenLabelY = y
    y = y + L.labelH
    L.bezelRect = rect(x0, y, inner, lines * lh + 2 * L.bezel + 2 * u)
    L.screen = rect(x0 + L.bezel, y + L.bezel, inner - 2 * L.bezel, lines * lh + 2 * u)
    -- Journal : marge du verre à gauche, témoin de défilement à droite.
    L.journal = rect(L.screen.x + u, L.screen.y + u, L.screen.w - 3 * u, lines * lh)
    L.scrollTrack = rect(L.screen.x + L.screen.w - u - 3, L.screen.y + u, 3, lines * lh)
    y = L.bezelRect.y + L.bezelRect.h + u
    L.columnsY = y
    local standX = W - frame - standW
    local rackX = standX - L.gap - rackW
    local ordersW = rackX - L.gap - x0
    L.orders = rect(x0, y, ordersW, L.labelH + L.contentH + u)
    L.rack = rect(rackX, y, rackW, L.labelH + L.contentH + u)
    L.standing = rect(standX, y, standW, L.labelH + L.contentH + u)
    local contentY = y + L.labelH + math.floor(u / 2)
    L.contentY = contentY
    -- Ordres : cartes empilées.
    L.cards = {}
    local cardY = contentY
    while cardY + L.cardH <= L.orders.y + L.orders.h - math.floor(u / 2) do
        L.cards[#L.cards + 1] = rect(x0 + u, cardY, ordersW - 2 * u, L.cardH)
        cardY = cardY + L.cardH + L.cardGap
    end
    -- Casier : boutons en bas, plaques sur deux colonnes au-dessus.
    local bottom = L.rack.y + L.rack.h - u
    L.transmit = rect(rackX + u, bottom - L.btnH, rackW - 2 * u, L.btnH)
    L.deposit = rect(rackX + u, L.transmit.y - math.floor(u / 2) - L.btnH, rackW - 2 * u, L.btnH)
    L.slots = {}
    local slotW = math.floor((rackW - 3 * u) / 2)
    local slotY = contentY
    while slotY + L.tagH <= L.deposit.y - u do
        for column = 0, 1 do
            L.slots[#L.slots + 1] = rect(rackX + u + column * (slotW + u), slotY, slotW, L.tagH)
        end
        slotY = slotY + L.tagH + math.floor(u / 2)
    end
    -- Confiance : texte sur toute la colonne.
    L.standText = rect(standX + u, contentY + math.floor(u / 2), standW - 2 * u,
        L.standing.y + L.standing.h - u - contentY)
    return L
end

--- Taille de la console : largeur, hauteur.
function PostWindow.measureSize(data, maxWidth, maxHeight)
    local L = PostWindow.computeLayout(data, maxWidth, maxHeight)
    return L.W, L.H
end

-- ----------------------------------------------------------------------------
-- Fenêtre
-- ----------------------------------------------------------------------------

function PostWindow:new(x, y, width, height, player, object)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.object = object
    o.data = nil
    o.background = false
    o.moveWithMouse = true
    o.lastRefreshMs = getTimestampMs()
    o.rxFlashUntil = 0
    o.rackScroll = 0
    o.ordersScroll = 0
    o.tagCount = 0
    o.tagLabels = {}
    o.maxWidth = width
    o.maxHeight = height
    o:setWantKeyEvents(true)
    return o
end

function PostWindow:createChildren()
    ISPanelJoypad.createChildren(self)
    local journal = ISRichTextPanel:new(0, 0, 100, 100)
    journal:initialise()
    journal.background = false
    journal.clip = true
    journal.autosetheight = false
    journal.defaultFont = PostWindow.monoFont()
    journal:setMargins(0, 0, 0, 0)
    -- Molette bornée (pas de barre de défilement : témoin dessiné sur le verre).
    journal.onMouseWheel = function(panel, del)
        PostWindow.scrollJournal(panel, -del * panel.lineStep)
        return true
    end
    self:addChild(journal)
    self.journal = journal
    self:layout()
end

--- Défile le journal de dy pixels (positif : vers le haut), borné au texte.
function PostWindow.scrollJournal(journal, dy)
    local lowest = -math.max(0, journal:getScrollHeight() - journal:getHeight())
    journal:setYScroll(math.max(lowest, math.min(0, journal:getYScroll() + dy)))
end

local function journalAtBottom(journal)
    local lowest = -math.max(0, journal:getScrollHeight() - journal:getHeight())
    return journal:getYScroll() <= lowest + 2
end

--- Recalcule la disposition (taille selon les données) et place le journal.
function PostWindow:layout()
    local L = PostWindow.computeLayout(self.data, self.maxWidth, self.maxHeight)
    self.L = L
    if self.width ~= L.W or self.height ~= L.H then
        self:setWidth(L.W)
        self:setHeight(L.H)
    end
    local journal = self.journal
    journal.defaultFont = L.mono
    journal.lineStep = L.lh * 2
    journal:setX(L.journal.x)
    journal:setY(L.journal.y)
    journal:setWidth(L.journal.w)
    journal:setHeight(L.journal.h)
    journal.textDirty = true
end

--- Données reçues du serveur (PostData) : tout est remplacé.
function PostWindow:setData(data)
    local first = self.data == nil
    local previous = self.data
    self.data = data
    self:layout()
    local journal = self.journal
    local stick = first or journalAtBottom(journal)
    journal.text = PostWindow.journalText(data.lines)
    journal:paginate()
    if stick then
        PostWindow.scrollJournal(journal, -journal:getScrollHeight())
    else
        PostWindow.scrollJournal(journal, 0)
    end
    -- Nouvelle ligne reçue : le voyant de réception clignote.
    if not first and PostWindow.lastReceivedKey(data) ~= PostWindow.lastReceivedKey(previous) then
        self.rxFlashUntil = getTimestampMs() + PostWindow.RX_FLASH_MS
    end
    self:updateButtons()
end

--- Clé de la dernière ligne reçue (horloge et texte), pour le clignotement.
function PostWindow.lastReceivedKey(data)
    local lines = data and data.lines or {}
    for i = #lines, 1, -1 do
        local entry = lines[i]
        if entry.t and not entry.gap then
            return tostring(entry.c) .. "|" .. tostring(entry.t)
        end
    end
    return ""
end

function PostWindow:updateButtons()
    local tags = PostWindow.dogTags(self.player)
    self.tagCount = #tags
    self.tagLabels = {}
    for i, item in ipairs(tags) do
        self.tagLabels[i] = PostWindow.dogTagLabel(item)
    end
end

function PostWindow:canDeposit()
    return self.tagCount > 0
end

function PostWindow:canTransmit()
    return self.data ~= nil and #(self.data.mail or {}) > 0
end

function PostWindow:onDeposit()
    local ids = {}
    for i, item in ipairs(PostWindow.dogTags(self.player)) do
        ids[i] = item:getID()
    end
    if #ids > 0 and self:objectValid() then
        sendToServer(self.player, "PostDeposit", self.object, { items = ids })
    end
end

function PostWindow:onTransmit()
    if not self:objectValid() then
        return
    end
    local callsign = self.data and self.data.callsign
    if callsign then
        self.player:Say(getText("IGUI_MilitaryDrop_PostTransmitSay", tostring(callsign)))
    end
    sendToServer(self.player, "PostTransmit", self.object)
end

--- La radio est toujours là et le joueur à côté (même étage).
function PostWindow:objectValid()
    local object, player = self.object, self.player
    if not object or not player or player:isDead() or object:getObjectIndex() == -1 then
        return false
    end
    local square = object:getSquare()
    if not square or math.floor(player:getZ()) ~= square:getZ() then
        return false
    end
    local limit = PostWindow.CLOSE_DISTANCE
    return math.abs(player:getX() - (square:getX() + 0.5)) <= limit
        and math.abs(player:getY() - (square:getY() + 0.5)) <= limit
end

-- ----------------------------------------------------------------------------
-- Souris : zones actives dessinées par la fenêtre
-- ----------------------------------------------------------------------------

local function inside(r, x, y)
    return r ~= nil and x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h
end

--- Élément sous le point (x, y) de la fenêtre : nom, donnée.
function PostWindow:hitTest(x, y)
    local L = self.L
    if not L then
        return nil
    end
    if inside(L.close, x, y) then
        return "close"
    elseif inside(L.deposit, x, y) then
        return "deposit"
    elseif inside(L.transmit, x, y) then
        return "transmit"
    elseif inside(L.standText, x, y) then
        return "standing"
    elseif inside(L.lampsArea, x, y) or inside(L.tape, x, y) or inside(L.freq, x, y) then
        return "status"
    end
    local missions = self.data and self.data.missions or {}
    for i, card in ipairs(L.cards) do
        local mission = missions[i + self.ordersScroll]
        if mission and inside(card, x, y) then
            return "mission", mission
        end
    end
    local mail = self.data and self.data.mail or {}
    for i, slot in ipairs(L.slots) do
        local entry = mail[i + self.rackScroll * 2]
        if entry and inside(slot, x, y) then
            return "tag", entry
        end
    end
    return nil
end

function PostWindow:mouseTarget()
    if not self:isReallyVisible() then
        return nil
    end
    local x, y = self:getMouseX(), self:getMouseY()
    if x < 0 or y < 0 or x >= self.width or y >= self.height then
        return nil
    end
    return self:hitTest(x, y)
end

function PostWindow:isEnabled(target)
    if target == "deposit" then
        return self:canDeposit()
    elseif target == "transmit" then
        return self:canTransmit()
    end
    return target == "close"
end

function PostWindow:activate(target)
    getSoundManager():playUISound("UIActivateButton")
    if target == "close" then
        self:close()
    elseif target == "deposit" then
        self:onDeposit()
    elseif target == "transmit" then
        self:onTransmit()
    end
end

function PostWindow:onMouseDown(x, y)
    local target = self:hitTest(x, y)
    if target == "close" or target == "deposit" or target == "transmit" then
        self.pressed = self:isEnabled(target) and target or nil
        return true
    end
    return ISPanelJoypad.onMouseDown(self, x, y)
end

function PostWindow:onMouseUp(x, y)
    local pressed = self.pressed
    self.pressed = nil
    if pressed then
        if self:hitTest(x, y) == pressed and self:isEnabled(pressed) then
            self:activate(pressed)
        end
        return true
    end
    return ISPanelJoypad.onMouseUp(self, x, y)
end

function PostWindow:onMouseUpOutside(x, y)
    self.pressed = nil
    return ISPanelJoypad.onMouseUpOutside(self, x, y)
end

function PostWindow:onMouseWheel(del)
    local L = self.L
    local x, y = self:getMouseX(), self:getMouseY()
    if L and inside(L.rack, x, y) then
        local rows = math.ceil(#(self.data and self.data.mail or {}) / 2) - math.floor(#L.slots / 2)
        self.rackScroll = math.max(0, math.min(math.max(0, rows), self.rackScroll + (del > 0 and 1 or -1)))
        return true
    elseif L and inside(L.orders, x, y) then
        local extra = #(self.data and self.data.missions or {}) - #L.cards
        self.ordersScroll = math.max(0, math.min(math.max(0, extra), self.ordersScroll + (del > 0 and 1 or -1)))
        return true
    end
    return false
end

--- Texte de l'infobulle de la cible survolée (texte riche), ou nil.
function PostWindow:tooltipFor(target, payload)
    local data = self.data
    if not data then
        return nil
    end
    if target == "mission" then
        return PostWindow.missionTooltip(payload)
    elseif target == "tag" then
        return escape(getText("IGUI_MilitaryDrop_PostTagTooltip", PostWindow.mailName(payload), tostring(payload.by or "?")))
    elseif target == "standing" then
        return escape(getText("IGUI_MilitaryDrop_PostStandingTooltip"))
    elseif target == "status" then
        return escape(PostWindow.statusText(data))
    elseif target == "deposit" and #self.tagLabels > 0 then
        local names = {}
        for i, label in ipairs(self.tagLabels) do
            names[i] = escape(label)
        end
        return table.concat(names, " <LINE> ")
    elseif target == "close" then
        return escape(getText("IGUI_MilitaryDrop_PostClose"))
    end
    return nil
end

function PostWindow:showTooltip(text)
    if text and text ~= "" then
        if not self.tooltipUI then
            self.tooltipUI = ISToolTip:new()
            self.tooltipUI:setOwner(self)
            self.tooltipUI:setVisible(false)
            self.tooltipUI:setAlwaysOnTop(true)
            self.tooltipUI.maxLineWidth = 360
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

function PostWindow:update()
    ISPanelJoypad.update(self)
    if not self:getIsVisible() then
        return
    end
    if not self:objectValid() then
        self:close()
        return
    end
    local now = getTimestampMs()
    if now - self.lastRefreshMs >= PostWindow.REFRESH_MS or now < self.lastRefreshMs then
        self.lastRefreshMs = now
        sendToServer(self.player, "PostOpen", self.object)
        self:updateButtons()
    end
    self:showTooltip(self:tooltipFor(self:mouseTarget()))
end

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

function PostWindow:drawOrders(hover, payload)
    local L, data = self.L, self.data
    local missions = data.missions or {}
    self:drawCompartment(L.orders, getText("IGUI_MilitaryDrop_PostOrders"))
    if #missions == 0 then
        self:drawText(PostWindow.fit(getText("IGUI_MilitaryDrop_PostNoMission"), UIFont.Small, L.orders.w - 2 * L.u),
            L.orders.x + L.u, L.contentY + L.u, PAINT[1], PAINT[2], PAINT[3], 0.55, UIFont.Small)
        return
    end
    for i, card in ipairs(L.cards) do
        local mission = missions[i + self.ordersScroll]
        if mission then
            self:drawOrder(card, mission, hover == "mission" and payload == mission)
        end
    end
    local hidden = #missions - #L.cards - self.ordersScroll
    if hidden > 0 then
        self:drawPaint("+" .. hidden, L.orders.x + L.orders.w - L.u, L.orders.y + L.orders.h - L.fh - 2, nil, 0.8,
            "right")
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

function PostWindow:drawRack(hover, payload)
    local L, data = self.L, self.data
    local mail = data.mail or {}
    local count = #mail > 0 and getText("IGUI_MilitaryDrop_PostRackCount", tostring(#mail)) or nil
    self:drawCompartment(L.rack, getText("IGUI_MilitaryDrop_PostRack"), count)
    for i, slot in ipairs(L.slots) do
        -- Alvéole du casier.
        self:drawRect(slot.x, slot.y, slot.w, slot.h, 0.45, 0.02, 0.03, 0.01)
        self:drawBevel(slot.x, slot.y, slot.w, slot.h, false, 0.7, 1)
        local entry = mail[i + self.rackScroll * 2]
        if entry then
            self:drawTag(rect(slot.x + 2, slot.y + 1, slot.w - 4, slot.h - 2), entry, hover == "tag" and payload == entry)
        end
    end
    if #mail == 0 and L.slots[1] then
        local s = L.slots[1]
        self:drawText(PostWindow.fit(getText("IGUI_MilitaryDrop_PostMailEmpty"), UIFont.Small, L.rack.w - 4 * L.u),
            s.x + L.u, s.y + (s.h - L.fh) / 2, PAINT[1], PAINT[2], PAINT[3], 0.55, UIFont.Small)
    end
    local hidden = #mail - #L.slots - self.rackScroll * 2
    if hidden > 0 then
        local last = L.slots[#L.slots]
        self:drawPaint("+" .. hidden, last.x + last.w, last.y + last.h + 1, nil, 0.8, "right")
    end
    local joypad = self.drawJoypadFocus and Joypad and Joypad.Texture
    self:drawButton(L.deposit, getText("IGUI_MilitaryDrop_PostDeposit", tostring(self.tagCount)), self:canDeposit(),
        hover == "deposit", self.pressed == "deposit", false, joypad and Joypad.Texture.XButton or nil)
    self:drawButton(L.transmit, getText("IGUI_MilitaryDrop_PostTransmit"), self:canTransmit(),
        hover == "transmit", self.pressed == "transmit", true, joypad and Joypad.Texture.AButton or nil)
end

--- Confiance en toutes lettres : phrase du commandement (rouge si ligne
--- coupée), puis effet sur les largages, plus discret.
function PostWindow:drawStanding(hover)
    local L, data = self.L, self.data
    self:drawCompartment(L.standing, getText("IGUI_MilitaryDrop_PostStanding"))
    local box = L.standText
    local alpha = hover == "standing" and 1 or 0.92
    local y = box.y
    local bottom = box.y + box.h - L.fh
    local color = data.lineCut and { 1, 0.45, 0.35 } or PAINT
    for _, line in ipairs(PostWindow.wrap(PostWindow.trustText(data), UIFont.Small, box.w)) do
        if y > bottom then
            return
        end
        self:drawText(line, box.x, y, color[1], color[2], color[3], alpha, UIFont.Small)
        y = y + L.fh
    end
    y = y + math.floor(L.fh / 2)
    for _, line in ipairs(PostWindow.wrap(PostWindow.effectText(data), UIFont.Small, box.w)) do
        if y > bottom then
            return
        end
        self:drawText(line, box.x, y, AMBER[1], AMBER[2], AMBER[3], alpha * 0.9, UIFont.Small)
        y = y + L.fh
    end
end

function PostWindow:prerender()
    if not self.L or not self.data then
        return
    end
    self:drawFace()
    self:drawScreen()
end

function PostWindow:render()
    if not self.L or not self.data then
        return
    end
    local hover, payload = self:mouseTarget()
    self:drawScreenOverlay()
    self:drawHeader(hover)
    self:drawStatus()
    self:drawOrders(hover, payload)
    self:drawRack(hover, payload)
    self:drawStanding(hover)
    if self.drawJoypadFocus then
        self:drawRectBorder(0, 0, self.width, self.height, 0.9, AMBER[1], AMBER[2], AMBER[3])
    end
end

function PostWindow:close()
    self:showTooltip(nil)
    self:setVisible(false)
    if JoypadState.players[self.playerNum + 1] and getFocusForPlayer(self.playerNum) == self then
        setJoypadFocus(self.playerNum, nil)
    end
    self:removeFromUIManager()
    if PostWindow.instances[self.playerNum] == self then
        PostWindow.instances[self.playerNum] = nil
    end
end

-- Clavier : Échap ferme la console (sans ouvrir le menu de pause).
function PostWindow:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
end

function PostWindow:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE and self:isReallyVisible() then
        self:close()
    end
end

-- Manette : A transmet, X dépose, B ferme ; haut et bas font défiler le journal.
function PostWindow:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self.drawJoypadFocus = true
end

function PostWindow:onLoseJoypadFocus(joypadData)
    ISPanelJoypad.onLoseJoypadFocus(self, joypadData)
    self.drawJoypadFocus = false
end

function PostWindow:onJoypadDown(button)
    if button == Joypad.AButton then
        if self:canTransmit() then
            self:onTransmit()
        end
    elseif button == Joypad.XButton then
        if self:canDeposit() then
            self:onDeposit()
        end
    elseif button == Joypad.BButton then
        self:close()
    end
end

function PostWindow:onJoypadDirUp()
    PostWindow.scrollJournal(self.journal, self.L.lh * 3)
end

function PostWindow:onJoypadDirDown()
    PostWindow.scrollJournal(self.journal, -self.L.lh * 3)
end

function PostWindow:getAPrompt()
    return getText("IGUI_MilitaryDrop_PostTransmit")
end

function PostWindow:getXPrompt()
    return getText("IGUI_MilitaryDrop_PostDeposit", tostring(#PostWindow.dogTags(self.player)))
end

function PostWindow:getBPrompt()
    return getText("IGUI_MilitaryDrop_PostClose")
end

--- Ouvre (ou met à jour) la console du joueur.
function PostWindow.show(player, object, data)
    local playerNum = player:getPlayerNum()
    local window = PostWindow.instances[playerNum]
    if not window then
        local screenW, screenH = getPlayerScreenWidth(playerNum), getPlayerScreenHeight(playerNum)
        local width, height = PostWindow.measureSize(data, screenW, screenH)
        width, height = math.min(width, screenW), math.min(height, screenH)
        local x = getPlayerScreenLeft(playerNum) + math.floor((screenW - width) / 2)
        local y = getPlayerScreenTop(playerNum) + math.floor((screenH - height) / 2)
        window = PostWindow:new(x, y, width, height, player, object)
        window.maxWidth, window.maxHeight = screenW, screenH
        window:initialise()
        window:instantiate()
        window:addToUIManager()
        PostWindow.instances[playerNum] = window
        if JoypadState.players[playerNum + 1] then
            if getPlayerInventory(playerNum) then
                getPlayerInventory(playerNum):close()
            end
            if getPlayerLoot(playerNum) then
                getPlayerLoot(playerNum):close()
            end
            setJoypadFocus(playerNum, window)
        end
    end
    window.object = object
    window:setVisible(true)
    window:setData(data)
    return window
end

-- ----------------------------------------------------------------------------
-- Réponses du serveur
-- ----------------------------------------------------------------------------

local function localPlayer(playerNum)
    return getSpecificPlayer(playerNum or 0)
end

local function onPostData(args)
    if type(args.x) == "number" then
        PostWindow.myPost = { x = args.x, y = args.y, z = args.z }
    end
    local request = pendingOpen
    pendingOpen = nil
    if request then
        local player = localPlayer(request.playerNum)
        if player and request.object then
            PostWindow.show(player, request.object, args)
        end
        return
    end
    -- Rafraîchissement, dépôt, transmission : console du joueur concerné
    -- (toutes si le nom manque).
    for _, window in pairs(PostWindow.instances) do
        if type(args.username) ~= "string" or (window.player and window.player:getUsername() == args.username) then
            window:setData(args)
        end
    end
end

--- Joueur local concerné par une réponse (écran partagé : nom envoyé par le
--- serveur), sinon le joueur 0.
function PostWindow.playerFor(username)
    if type(username) == "string" then
        for i = 0, getNumActivePlayers() - 1 do
            local player = getSpecificPlayer(i)
            if player and player:getUsername() == username then
                return player
            end
        end
    end
    return localPlayer(0)
end

local function onPostResult(args)
    local status = tostring(args.status)
    if status ~= "installed" and status ~= "moved" then
        pendingOpen = nil
    end
    local player = PostWindow.playerFor(args.username)
    if PostWindow.RESULTS[status] and player then
        player:Say(getText("IGUI_MilitaryDrop_PostResult_" .. status, tostring(args.count or 0)))
    end
    -- Poste de l'équipe inconnu ou périmé (nouveau membre d'une faction, poste
    -- déplacé par un coéquipier) : redemander sa position.
    if (status == "already" or status == "notPost" or status == "otherTeam") and player then
        Net.toServer(player, "PostSync", {})
    end
    if PostWindow.CLOSING[status] and player then
        -- Fermées après le parcours (close retire l'instance de la table).
        local closing = {}
        for _, window in pairs(PostWindow.instances) do
            if window.player == player then
                closing[#closing + 1] = window
            end
        end
        for _, window in ipairs(closing) do
            window:close()
        end
    end
end

--- Commandes du poste ; renvoie vrai si la commande a été traitée.
function PostWindow.handleCommand(module, command, args)
    if module ~= Net.MODULE or type(args) ~= "table" then
        return false
    end
    if command == "PostInfo" then
        if type(args.x) == "number" then
            PostWindow.myPost = { x = args.x, y = args.y, z = args.z }
        else
            PostWindow.myPost = nil
        end
        return true
    elseif command == "PostData" then
        onPostData(args)
        return true
    elseif command == "PostResult" then
        onPostResult(args)
        return true
    end
    return false
end

-- Commandes du poste, reçues par MilitaryDrop.Client (solo et MP).
for _, command in ipairs({ "PostInfo", "PostData", "PostResult" }) do
    MilitaryDrop.Client.HANDLERS[command] = function(args)
        PostWindow.handleCommand(Net.MODULE, command, args)
    end
end

--- Arrivée en jeu : position du poste de l'équipe.
function PostWindow.onGameStart()
    local player = getSpecificPlayer(0)
    if player then
        Net.toServer(player, "PostSync", {})
    end
end

Events.OnGameStart.Add(PostWindow.onGameStart)
Events.OnFillWorldObjectContextMenu.Add(PostWindow.onFillWorldContextMenu)

return PostWindow
