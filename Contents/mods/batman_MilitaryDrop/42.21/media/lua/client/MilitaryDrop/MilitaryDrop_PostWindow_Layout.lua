-- Military Drop — console du poste de liaison (client) : mise en forme et disposition
-- Partie de MilitaryDrop_PostWindow.lua (voir son en-tête).

require "MilitaryDrop/MilitaryDrop_PostWindow"

local PostWindow = MilitaryDrop.PostWindow
local Config = MilitaryDrop.Config
local Codes = MilitaryDrop.Codes
local U = PostWindow.util
local escape, measure, fontHeight, rect = U.escape, U.measure, U.fontHeight, U.rect
local LAMP_KEYS = U.LAMP_KEYS

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
            text = rgb("sys") .. escape(getText("IGUI_MilitaryDrop_PostSys_" .. tostring(entry.sys),
                tostring(entry.site or "")))
        else
            text = rgb("line") .. escape(MilitaryDrop.Exchange.lineText(entry.t))
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
    local titleKey = PostWindow.MISSION_TITLES[mission.kind]
    local view = { title = titleKey and getText(titleKey) or tostring(mission.title or mission.kind or ""),
        due = "", sub = "" }
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
    local left, target = tonumber(mission.left), tonumber(mission.target)
    if mission.kind == "cleanup" and mission.spotted == true and left and target and target > 0 then
        -- Horde apparue : barre des morts de la horde vers l'objectif ;
        -- étiquette « abattus par la station, reste à abattre ».
        local down = tonumber(mission.down) or math.max(0, target - left)
        view.bar = { kind = "progress", fraction = math.max(0, math.min(1, down / target)),
            label = getText("IGUI_MilitaryDrop_PostCleanupProgress", tostring(math.floor(progress or 0)),
                tostring(math.floor(left))) }
    elseif mission.kind == "cleanup" and mission.spotted == false then
        -- Horde pas encore repérée : barre de temps, avec la mention.
        view.sub = view.sub ~= "" and (view.sub .. " - " .. getText("IGUI_MilitaryDrop_PostCleanupPending"))
            or getText("IGUI_MilitaryDrop_PostCleanupPending")
        if remaining and hours then
            view.bar = { kind = "time", fraction = math.max(0, math.min(1, remaining / hours)), label = "" }
        end
    elseif progress and quota and quota > 1 then
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

--- Retire le dernier caractère, toujours au moins une unité (Kahlua : chaîne
--- Java en UTF-16, pas en octets UTF-8 ; voir MilitaryDrop.dropLastChar).
local function dropLastChar(text)
    return MilitaryDrop.dropLastChar(text)
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

local POWER_KINDS = { "grid", "generator", "battery", "none" }

--- Disposition complète (maquette C, POSTE-08) pour data (nil : avant les
--- données) dans un écran de maxWidth × maxHeight (nil : sans limite) :
--- en-tête, voyants, journal ; liste des affaires à gauche, volet de
--- l'affaire choisie à droite ; bande de la confiance, du code et de l'appel.
--- Toutes les largeurs sont mesurées.
function PostWindow.computeLayout(data, maxWidth, maxHeight)
    local fh, fm = fontHeight(UIFont.Small), fontHeight(UIFont.Medium)
    local mono = PostWindow.monoFont()
    local lh = fontHeight(mono)
    local u = math.max(6, math.floor(fh * 0.4))
    local L = { fh = fh, fm = fm, u = u, mono = mono, lh = lh }
    local frame = 2 * u + 2
    L.frame = frame
    local half = math.floor(u / 2)

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

    L.gap = 2 * u
    L.btnH = fh + 12
    L.labelH = fh + half
    L.barH = math.max(6, math.floor(fh * 0.45))
    L.cardH = 2 * fh + L.barH + 2 * u

    -- Liste des affaires : en-têtes peints, lignes à icône (titre, état).
    L.headH = fh + half
    L.rowH = 2 * fh + u
    L.rowGap = 2
    L.iconSize = L.rowH - u
    local listW = math.max(fh * 15, measure(getText("IGUI_MilitaryDrop_PostAffairs")) + 2 * u,
        measure(getText("IGUI_MilitaryDrop_PostTodo")) + 3 * u, measure(getText("IGUI_MilitaryDrop_PostOrders")) + 3 * u)

    -- Volet : ruban du titre, fiche, baie de lecture, consigne, deux boutons.
    L.tapeH = fh + 6
    local btnW = measure(getText("IGUI_MilitaryDrop_PostDeposit", "99")) + 3 * u + fh
    for _, key in ipairs({ "IGUI_MilitaryDrop_PostRecorderEject", "IGUI_MilitaryDrop_PostRecorderSend",
        "IGUI_MilitaryDrop_PostRecorderInsert", "IGUI_MilitaryDrop_PostTransmit" }) do
        btnW = math.max(btnW, measure(getText(key)) + 3 * u + fh)
    end
    L.tagW = math.floor(math.max(fh * 5, measure("Xxxxxxx Xxxxxxx", mono) * 0.8 + 2 * u))
    L.tagH = fh + 10
    L.boxSize = math.max(48, 3 * fh)
    L.wellH = L.boxSize + 2 * u
    L.infoH = 3 * fh + u
    local detailW = math.max(fh * 22, 2 * btnW + 3 * u, 2 * L.tagW + 3 * u,
        measure(getText("IGUI_MilitaryDrop_PostRecorderTitle", "W999")) + 4 * u)
    local detailH = half + L.tapeH + u + L.infoH + u + L.wellH + u + 2 * fh + u + L.btnH + u
    local listH = L.labelH + 2 * L.headH + 4 * (L.rowH + L.rowGap) + u
    L.contentH = math.max(detailH, listH)

    -- Bande du bas : confiance, champ du code (option AuthCode), appel.
    L.codeShown = PostWindow.codeRequired()
    L.entryH = fh + 6
    L.codeLabel = getText("IGUI_MilitaryDrop_RadioModule_Code")
    L.stripH = math.max(L.btnH, L.entryH) + u
    local requestW = measure(getText("IGUI_MilitaryDrop_RequestDrop")) + 3 * u + fh
    local standLabelW = measure(getText("IGUI_MilitaryDrop_PostStanding"))
    local codeEntryW = measure("888888888888") + 2 * u
    local codeW = L.codeShown and (measure(L.codeLabel) + u + codeEntryW + u) or 0
    local stripW = u + standLabelW + u + fh * 10 + u + codeW + requestW + u

    local W = 2 * frame + math.max(listW + L.gap + detailW, statusW, titleW, stripW)
    if maxWidth and W > maxWidth then
        W = math.max(2 * frame + fh * 12 + L.gap + detailW, maxWidth)
    end
    W = math.floor(W)

    -- Hauteurs : le journal s'adapte à l'écran.
    L.bezel = u
    local fixed = frame + L.headerH + L.statusH + u + L.labelH + 2 * L.bezel + 2 * u + u + L.contentH + u
        + L.stripH + frame
    local lines = PostWindow.JOURNAL_LINES
    if maxHeight then
        lines = math.max(PostWindow.JOURNAL_MIN_LINES, math.min(lines, math.floor((maxHeight - fixed) / lh)))
    end
    L.journalLines = lines
    local H = fixed + lines * lh
    L.W, L.H = W, H

    -- Rectangles : en-tête, voyants, journal.
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
    L.journal = rect(L.screen.x + u, L.screen.y + u, L.screen.w - 3 * u, lines * lh)
    L.scrollTrack = rect(L.screen.x + L.screen.w - u - 3, L.screen.y + u, 3, lines * lh)
    y = L.bezelRect.y + L.bezelRect.h + u

    -- Liste des affaires.
    listW = math.min(listW, inner - L.gap - fh * 18)
    L.list = rect(x0, y, listW, L.contentH)
    L.listArea = rect(x0 + half, y + L.labelH, listW - 2 * half, L.contentH - L.labelH - half)

    -- Volet de l'affaire choisie.
    L.detail = rect(x0 + listW + L.gap, y, inner - listW - L.gap, L.contentH)
    local d = L.detail
    local dx, dw = d.x + u, d.w - 2 * u
    L.detailTape = rect(dx, d.y + half, dw, L.tapeH)
    L.detailTop = L.detailTape.y + L.tapeH + u
    L.btnB = rect(dx, d.y + d.h - u - L.btnH, math.floor((dw - u) / 2), L.btnH)
    L.btnA = rect(L.btnB.x + L.btnB.w + u, L.btnB.y, dw - L.btnB.w - u, L.btnH)
    -- Enregistreur : fiche du crash, baie (logement, barre, état), consigne.
    L.info = rect(dx, L.detailTop, dw, L.infoH)
    L.well = rect(dx, L.info.y + L.info.h + u, dw, L.wellH)
    L.box = rect(L.well.x + u, L.well.y + u, L.boxSize, L.boxSize)
    local barX = L.box.x + L.box.w + 2 * u
    L.bayLabel = { x = barX, y = L.well.y + u }
    L.progress = rect(barX, L.well.y + u + fh + half, L.well.x + L.well.w - u - barX, L.barH * 2)
    L.bayState = { x = barX, y = L.progress.y + L.progress.h + half }
    L.hint = rect(dx, L.well.y + L.well.h + half, dw, L.btnB.y - u - (L.well.y + L.well.h + half))
    -- Plaques : alvéoles sur deux colonnes, consigne au-dessus des boutons.
    L.slots = {}
    local slotW = math.floor((dw - u) / 2)
    local slotY = L.detailTop
    while slotY + L.tagH <= L.btnB.y - u - fh do
        for column = 0, 1 do
            L.slots[#L.slots + 1] = rect(dx + column * (slotW + u), slotY, slotW, L.tagH)
        end
        slotY = slotY + L.tagH + half
    end
    L.tagsHint = rect(dx, L.btnB.y - u - fh, dw, fh)
    -- Mission : fiche de l'ordre, puis texte complet de la base.
    L.missionCard = rect(dx, L.detailTop, dw, L.cardH)
    L.missionText = rect(dx, L.missionCard.y + L.cardH + u, dw, d.y + d.h - u - (L.missionCard.y + L.cardH + u))

    -- Bande du bas.
    y = d.y + d.h + u
    L.strip = rect(x0, y, inner, L.stripH)
    L.standing = L.strip
    L.request = rect(x0 + inner - u - requestW, y + (L.stripH - L.btnH) / 2, requestW, L.btnH)
    local textRight = L.request.x - u
    if L.codeShown then
        L.code = rect(L.request.x - u - codeEntryW, y + (L.stripH - L.entryH) / 2, codeEntryW, L.entryH)
        L.codeLabelW = measure(L.codeLabel)
        L.codeLabelPos = { x = L.code.x - u - L.codeLabelW, y = y + math.floor((L.stripH - fh) / 2) }
        textRight = L.codeLabelPos.x - u
    end
    L.standLabelPos = { x = x0 + u, y = y + math.floor((L.stripH - fh) / 2) }
    local textX = L.standLabelPos.x + standLabelW + u
    L.standText = rect(textX, y, math.max(0, textRight - textX), L.stripH)
    return L
end

--- Taille de la console : largeur, hauteur.
function PostWindow.measureSize(data, maxWidth, maxHeight)
    local L = PostWindow.computeLayout(data, maxWidth, maxHeight)
    return L.W, L.H
end

return PostWindow
