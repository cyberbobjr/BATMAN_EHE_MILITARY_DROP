-- ============================================================================
-- Military Drop — sources de confiance et missions (serveur MP ou solo)
--
-- Échanges radio sans code (AUTH-01 sans objet), sur la fréquence militaire,
-- par une radio militaire allumée en main, posée à 2 cases ou le poste de
-- liaison (MilitaryDrop_Exchange.lua). Le serveur revérifie tout : radio,
-- équipe (MilitaryDrop.Teams, au moment de l'échange), ligne coupée,
-- échéance, objets possédés, cadence. Chaque gain passe par
-- MilitaryDrop.Trust.add (plafond quotidien commun, bonus du poste).
--
--   * SRC-01 rapport de situation : +ReportGain, une fois par jour calendaire
--     et par équipe ;
--   * SRC-02 plaques d'identité vanilla (tag base:dogtag) renommées d'après
--     leur porteur par le jeu (MilitaryDrop.Exchange.isDogTag : pas la plaque
--     du joueur, pas une plaque vierge du butin). « Transmettre les
--     matricules » : plaques de l'inventaire du joueur, identifiant d'objet
--     (getID) jamais transmis → +DogTagGain chacune, plaque consommée, la
--     base cite les noms. Plafond du jour atteint : plaques gardées ;
--   * SRC-03 reconnaissance (publique) : grille tirée comme un point de
--     largage autour d'un joueur connecté ; première équipe qui confirme à
--     RECON_RADIUS cases au plus avant ReconHours → +ReconGain ;
--   * SRC-04 nettoyage (publique) : zone de rayon CLEANUP_RADIUS, quota
--     CleanupQuota ; zombies tués dans la zone (OnZombieDead serveur, tueur
--     zombie:getAttackedBy() s'il est un IsoPlayer : feu et pièges non
--     attribués), équipe du tueur figée à la mort, un zombie compté une fois ;
--     première équipe au quota avant CleanupHours → +CleanupGain ;
--   * SRC-05 appel de contrôle : chaque équipe qui confirme la réception avant
--     ControlHours gagne +ControlGain, une fois.
-- Planification : une mission de chaque type au plus ; la suivante est tirée
-- <type>IntervalHours (±25 %) après la clôture de la précédente, si la chaîne
-- militaire existe et qu'un joueur est connecté. Lancements et clôtures sont
-- annoncés sur la chaîne militaire (textes du serveur). Gain 0 : source
-- désactivée.
--
-- État privé (MilitaryDrop.Secrets.privateState, jamais transmis aux clients) :
--   missions = { reports = { teamId = jour }, open = { recon|cleanup|control
--     = mission }, nextHours = { type = heures }, last = { type = { id,
--     outcome, team, hours } }, nextId, dogtags = { ids = { identifiant
--     d'objet (chaîne) = teamId } } }
--     (v1.3 en essai : les anciens champs a, b, issued, used des plaques
--     numérotées du mod sont effacés au chargement.)
--   mission = { id, kind, openedHours, deadline, text, x, y, radius, quota,
--     counts = { teamId = morts }, responded = { teamId = true } }
-- ModData de zombie : mission de nettoyage déjà comptée.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Server"
require "MilitaryDrop/MilitaryDrop_Secrets"
require "MilitaryDrop/MilitaryDrop_Guard"
require "MilitaryDrop/MilitaryDrop_Broadcast"
require "MilitaryDrop/MilitaryDrop_Teams"
require "MilitaryDrop/MilitaryDrop_Trust"
require "MilitaryDrop/MilitaryDrop_Exchange"

local Config = MilitaryDrop.Config
local Exchange = MilitaryDrop.Exchange

local Missions = {}
MilitaryDrop.Missions = Missions

Missions.KINDS = { "recon", "cleanup", "control" }
Missions.RECON_RADIUS = 25
Missions.CLEANUP_RADIUS = 40
-- Un échange par joueur toutes les 3 s réelles au plus (anti-rafale, commun aux
-- quatre échanges) ; un échange refusé reçoit le statut « busy ».
Missions.EXCHANGE_INTERVAL_MS = 3000
-- Plaques traitées par transmission.
Missions.DOGTAGS_PER_CALL = Exchange.DOGTAGS_PER_CALL
Missions.INTERVAL_JITTER = 0.25
Missions.ANNOUNCE_REPEATS = 2
Missions.REPORT_REPLIES = 3

local KILL_KEY = "MilitaryDrop_cleanup"
local HOURS_OPTIONS = { recon = "ReconHours", cleanup = "CleanupHours", control = "ControlHours" }
local INTERVAL_OPTIONS = { recon = "ReconIntervalHours", cleanup = "CleanupIntervalHours",
    control = "ControlIntervalHours" }
local TITLES = { recon = "IGUI_MilitaryDrop_Mission_Recon", cleanup = "IGUI_MilitaryDrop_Mission_Cleanup",
    control = "IGUI_MilitaryDrop_Mission_Control" }

local function hoursNow()
    return getGameTime():getWorldAgeHours()
end

--- Jour calendaire du jeu (une fois par jour).
local function currentDay()
    return math.floor(MilitaryDrop.Server.clock() / 24)
end

local function state()
    local s = MilitaryDrop.Secrets.privateState()
    if type(s.missions) ~= "table" then
        s.missions = {}
    end
    local m = s.missions
    m.reports = m.reports or {}
    m.open = m.open or {}
    m.nextHours = m.nextHours or {}
    m.last = m.last or {}
    if type(m.dogtags) ~= "table" then
        m.dogtags = {}
    end
    local tags = m.dogtags
    if type(tags.ids) ~= "table" then
        tags.ids = {}
    end
    -- Plaques numérotées du mod (essais v1.3) : registre sans objet.
    tags.a, tags.b, tags.issued, tags.used = nil, nil, nil, nil
    return m
end

local function optionNumber(name, minimum)
    return math.max(minimum or 0, tonumber(Config.get(name)) or 0)
end

local function whole(value)
    return string.format("%d", math.floor(value + 0.5))
end

-- ----------------------------------------------------------------------------
-- Poste de liaison (module facultatif : MilitaryDrop_Post.lua)
-- ----------------------------------------------------------------------------

--- Ligne de la base adressée à une équipe (teamId) ou à toutes les stations (nil).
local function postRecord(teamId, text)
    local Post = MilitaryDrop.Post
    if Post and Post.record then
        Post.record(teamId, text)
    end
end

local function isTeamPost(teamId, object)
    local Post = MilitaryDrop.Post
    return Post ~= nil and Post.isTeamPost ~= nil and Post.isTeamPost(teamId, object) == true
end

-- ----------------------------------------------------------------------------
-- Annonces et réponses
-- ----------------------------------------------------------------------------

--- Annonce à toutes les stations sur la chaîne militaire (repeats fois), notée
--- au journal des postes. code : code des lignes répétées (repère de carte de
--- la reconnaissance, MilitaryDrop.Broadcast.reconAnnounced), pas de la fin.
function Missions.announce(text, repeats, code)
    postRecord(nil, text)
    local lines = {}
    for i = 1, repeats or 1 do
        lines[i] = { text, code }
    end
    lines[#lines + 1] = { getText("IGUI_MilitaryDrop_BroadcastOut") }
    return MilitaryDrop.Broadcast.air(lines)
end

--- Réponse privée au joueur : statut et lignes de la base (notées au journal
--- du poste de son équipe).
local function reply(ctx, status, lines)
    lines = lines or {}
    for _, text in ipairs(lines) do
        postRecord(ctx.teamId, text)
    end
    Exchange.toPlayer(ctx.player, Exchange.REPLY, { exchangeId = ctx.exchangeId, status = status, lines = lines })
end

--- Début commun d'un échange : cadence, radio, équipe, ligne coupée, source
--- active. Renvoie le contexte, ou nil si l'échange s'arrête là.
local function begin(player, args, source)
    local ctx = { player = player, exchangeId = tonumber(args.exchangeId) }
    if MilitaryDrop.Guard.throttled(player, "exchange", Missions.EXCHANGE_INTERVAL_MS) then
        -- Réponse sans ligne de la base (rien sur le canal) : le client libère l'échange.
        reply(ctx, "busy")
        return nil
    end
    local radio, status = Exchange.checkRadio(player, args.radio)
    if not radio then
        reply(ctx, status)
        return nil
    end
    ctx.radio = radio
    ctx.teamId = MilitaryDrop.Teams.idFor(player)
    ctx.callsign = MilitaryDrop.Teams.callsign(ctx.teamId) or ""
    if MilitaryDrop.Trust.isLineCut(ctx.teamId) then
        reply(ctx, "lineCut", { getText("IGUI_MilitaryDrop_LineCut", ctx.callsign) })
        return nil
    end
    MilitaryDrop.Trust.touch(ctx.teamId)
    if not Exchange.isEnabled(source) then
        reply(ctx, "disabled", { getText("IGUI_MilitaryDrop_Reply_Disabled", ctx.callsign) })
        return nil
    end
    ctx.opts = { fromPost = isTeamPost(ctx.teamId, radio) }
    return ctx
end

-- ----------------------------------------------------------------------------
-- SRC-01 : rapport de situation
-- ----------------------------------------------------------------------------

function Missions.report(player, args)
    local ctx = begin(player, args, "report")
    if not ctx then
        return
    end
    local reports = state().reports
    local day = currentDay()
    if reports[ctx.teamId] == day then
        reply(ctx, "already", { getText("IGUI_MilitaryDrop_Reply_ReportAlready", ctx.callsign) })
        return
    end
    reports[ctx.teamId] = day
    MilitaryDrop.Trust.add(ctx.teamId, Exchange.gain("report"), "report", ctx.opts)
    reply(ctx, "ok", { getText("IGUI_MilitaryDrop_Reply_Report_" .. (ZombRand(Missions.REPORT_REPLIES) + 1),
        ctx.callsign) })
end

-- ----------------------------------------------------------------------------
-- SRC-02 : plaques d'identité vanilla (MilitaryDrop.Exchange.isDogTag)
-- ----------------------------------------------------------------------------

--- Plafond quotidien de l'équipe atteint (état privé trust, MilitaryDrop_Trust.lua) :
--- une plaque transmise ne rapporterait rien, elle reste au joueur.
local function capReached(teamId)
    local trust = MilitaryDrop.Secrets.privateState().trust
    local entry = type(trust) == "table" and trust[teamId]
    if not entry or entry.day ~= currentDay() then
        return false
    end
    local cap = math.max(0, math.floor(tonumber(Config.get("TrustDailyCap")) or 0))
    return (tonumber(entry.dayGain) or 0) >= cap
end

--- Identifiant normalisé (chaîne d'un entier), ou nil.
local function normalizeId(id)
    local value = tonumber(id)
    if not value or value ~= math.floor(value) then
        return nil
    end
    return string.format("%d", value)
end

--- Vrai si la plaque d'identifiant id a déjà été transmise.
function Missions.isDogTagUsed(id)
    local key = normalizeId(id)
    return key ~= nil and state().dogtags.ids[key] ~= nil
end

--- Crédite une plaque à l'équipe (transmission radio ou boîte à courrier du
--- poste, opts.fromPost) ; tag = { id = identifiant de l'objet, name = nom du
--- soldat }. Renvoie le gain appliqué, ou nil et le motif : "disabled",
--- "lineCut", "unknown" (identifiant mal formé), "used" (déjà transmise),
--- "dailyCap" (non enregistrée : la plaque peut attendre demain).
function Missions.creditDogTag(player, teamId, tag, opts)
    if not teamId or not Exchange.isEnabled("dogtag") then
        return nil, "disabled"
    end
    if MilitaryDrop.Trust.isLineCut(teamId) then
        return nil, "lineCut"
    end
    local key = normalizeId(type(tag) == "table" and tag.id)
    if not key then
        return nil, "unknown"
    end
    local ids = state().dogtags.ids
    if ids[key] then
        return nil, "used"
    end
    if capReached(teamId) then
        return nil, "dailyCap"
    end
    -- Confiance déjà au maximum : la plaque ne rapporterait rien, elle est
    -- gardée pour plus tard (la note peut redescendre).
    if MilitaryDrop.Trust.get(teamId) >= MilitaryDrop.Trust.MAX then
        return nil, "full"
    end
    ids[key] = teamId
    MilitaryDrop.log("dog tag " .. key .. " (" .. tostring(tag.name) .. ") credited to " .. tostring(teamId)
        .. " by " .. tostring(player and player:getUsername()))
    return MilitaryDrop.Trust.add(teamId, Exchange.gain("dogtag"), "dogtag", opts)
end

--- Lignes de la base après une transmission : noms crédités, noms déjà
--- transmis, plaques gardées (kept : true ou "dailyCap", plafond du jour ;
--- "full", confiance au maximum).
function Missions.dogTagReplyLines(callsign, credited, known, kept)
    local lines = {}
    if #credited > 0 then
        lines[#lines + 1] = getText("IGUI_MilitaryDrop_Reply_DogTags", callsign, Exchange.namesText(credited))
    end
    if #known > 0 then
        lines[#lines + 1] = getText("IGUI_MilitaryDrop_Reply_DogTagsKnown", callsign, Exchange.namesText(known))
    end
    if kept == "full" then
        lines[#lines + 1] = getText("IGUI_MilitaryDrop_Reply_DogTagsFull", callsign)
    elseif kept then
        lines[#lines + 1] = getText("IGUI_MilitaryDrop_Reply_DogTagsCap", callsign)
    end
    return lines
end

--- Retire une plaque de son conteneur (serveur : retrait transmis aux clients).
local function consume(item)
    local container = item:getContainer()
    if container then
        container:Remove(item)
        if isServer() then
            sendRemoveItemFromContainer(container, item)
        end
    end
end

--- « Transmettre les matricules » : plaques vanilla renommées de l'inventaire
--- du joueur (pas la sienne), DOGTAGS_PER_CALL au plus.
function Missions.transmitDogTags(player, args)
    local ctx = begin(player, args, "dogtag")
    if not ctx then
        return
    end
    local items = Exchange.findDogTags(player, Missions.DOGTAGS_PER_CALL)
    if #items == 0 then
        reply(ctx, "noTags")
        return
    end
    local credited, known, kept = {}, {}, false
    for _, item in ipairs(items) do
        local name = Exchange.dogTagLabel(item)
        local gain, reason = Missions.creditDogTag(player, ctx.teamId, { id = Exchange.dogTagId(item), name = name },
            ctx.opts)
        if gain then
            consume(item)
            credited[#credited + 1] = name
        elseif reason == "used" then
            -- Doublon (objet dupliqué) : sans valeur pour la base, la plaque est remise.
            consume(item)
            known[#known + 1] = name
        elseif reason == "dailyCap" or reason == "full" then
            kept = reason
            break
        end
    end
    reply(ctx, #credited > 0 and "ok" or "refused", Missions.dogTagReplyLines(ctx.callsign, credited, known, kept))
end

-- ----------------------------------------------------------------------------
-- Missions publiques (SRC-03, SRC-04, SRC-05)
-- ----------------------------------------------------------------------------

--- Mission ouverte d'un type, encore dans les temps, ou nil.
function Missions.openMission(kind, now)
    local mission = state().open[kind]
    if mission and (now or hoursNow()) < mission.deadline then
        return mission
    end
    return nil
end

local function interval(kind)
    local hours = optionNumber(INTERVAL_OPTIONS[kind], 1)
    return hours * ZombRandFloat(1 - Missions.INTERVAL_JITTER, 1 + Missions.INTERVAL_JITTER)
end

--- Clôt la mission ouverte d'un type ; la suivante est tirée après l'intervalle.
local function close(kind, now, outcome, teamId, text)
    local s = state()
    local mission = s.open[kind]
    if not mission then
        return
    end
    s.open[kind] = nil
    s.last[kind] = { id = mission.id, outcome = outcome, team = teamId, hours = now }
    s.nextHours[kind] = now + interval(kind)
    MilitaryDrop.log("mission " .. mission.id .. " (" .. kind .. ") " .. outcome .. " " .. tostring(teamId))
    if text then
        Missions.announce(text, 1)
    end
end

--- Joueurs vivants connectés (serveur MP) ou locaux (solo).
local function livePlayers()
    local list = {}
    if isServer() then
        local players = getOnlinePlayers()
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            if player and not player:isDead() then
                list[#list + 1] = player
            end
        end
        return list
    end
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and not player:isDead() then
            list[#list + 1] = player
        end
    end
    return list
end

local function launchText(mission)
    local hours = whole(mission.deadline - mission.openedHours)
    if mission.kind == "recon" then
        return getText("IGUI_MilitaryDrop_Broadcast_Recon", tostring(mission.x), tostring(mission.y), hours)
    elseif mission.kind == "cleanup" then
        return getText("IGUI_MilitaryDrop_Broadcast_Cleanup", tostring(mission.x), tostring(mission.y),
            tostring(mission.radius), tostring(mission.quota), hours)
    end
    return getText("IGUI_MilitaryDrop_Broadcast_Control", hours)
end

--- Lance une mission du type (aucune si déjà ouverte, source désactivée,
--- chaîne militaire absente ou aucun joueur connecté). Aussi appelable depuis
--- la console du serveur pour un essai. Renvoie la mission, ou nil.
function Missions.launch(kind, now)
    now = now or hoursNow()
    local s = state()
    if not HOURS_OPTIONS[kind] or s.open[kind] or not Exchange.isEnabled(kind)
        or not MilitaryDrop.Broadcast.channel then
        return nil
    end
    local players = livePlayers()
    if #players == 0 then
        return nil
    end
    s.nextId = (tonumber(s.nextId) or 0) + 1
    local mission = { id = "M" .. s.nextId, kind = kind, openedHours = now,
        deadline = now + optionNumber(HOURS_OPTIONS[kind], 1) }
    if kind == "control" then
        mission.responded = {}
    else
        local around = players[ZombRand(#players) + 1]
        local x, y = MilitaryDrop.Server.pickDropPoint(math.floor(around:getX()), math.floor(around:getY()))
        if not x then
            return nil
        end
        mission.x, mission.y = x, y
        if kind == "recon" then
            mission.radius = Missions.RECON_RADIUS
        else
            mission.radius = Missions.CLEANUP_RADIUS
            mission.quota = math.floor(optionNumber("CleanupQuota", 1))
            mission.counts = {}
        end
    end
    mission.text = launchText(mission)
    s.open[kind] = mission
    s.nextHours[kind] = nil
    -- Reconnaissance : coordonnées envoyées avant l'annonce ; seuls les
    -- clients dont une radio reçoit une ligne codée marquent leur carte.
    local code = nil
    if kind == "recon" and MilitaryDrop.Broadcast and MilitaryDrop.Broadcast.reconAnnounced then
        code = MilitaryDrop.Broadcast.reconAnnounced(mission.id, mission.x, mission.y)
    end
    Missions.announce(mission.text, Missions.ANNOUNCE_REPEATS, code)
    MilitaryDrop.log("mission " .. mission.id .. " (" .. kind .. ") until " .. mission.deadline)
    return mission
end

--- Échéances et lancements (toutes les 10 minutes de jeu).
function Missions.update(now)
    now = now or hoursNow()
    local s = state()
    for _, kind in ipairs(Missions.KINDS) do
        local mission = s.open[kind]
        if mission and now >= mission.deadline then
            if kind == "control" then
                local answered = 0
                for _ in pairs(mission.responded or {}) do
                    answered = answered + 1
                end
                close(kind, now, "closed", nil, getText("IGUI_MilitaryDrop_Broadcast_ControlClosed", tostring(answered)))
            else
                local key = kind == "recon" and "IGUI_MilitaryDrop_Broadcast_ReconExpired"
                    or "IGUI_MilitaryDrop_Broadcast_CleanupExpired"
                close(kind, now, "expired", nil, getText(key, tostring(mission.x), tostring(mission.y)))
            end
        elseif not mission then
            if not Exchange.isEnabled(kind) then
                s.nextHours[kind] = nil
            elseif not s.nextHours[kind] then
                s.nextHours[kind] = now + interval(kind)
            elseif now >= s.nextHours[kind] then
                Missions.launch(kind, now)
            end
        end
    end
end

-- SRC-03 : reconnaissance
function Missions.confirmRecon(player, args)
    local ctx = begin(player, args, "recon")
    if not ctx then
        return
    end
    local now = hoursNow()
    local mission = Missions.openMission("recon", now)
    if not mission then
        reply(ctx, "noMission", { getText("IGUI_MilitaryDrop_Reply_NoRecon", ctx.callsign) })
        return
    end
    local dx = player:getX() - (mission.x + 0.5)
    local dy = player:getY() - (mission.y + 0.5)
    if dx * dx + dy * dy > mission.radius * mission.radius then
        reply(ctx, "tooFar", { getText("IGUI_MilitaryDrop_Reply_ReconFar", ctx.callsign, tostring(mission.x),
            tostring(mission.y)) })
        return
    end
    MilitaryDrop.Trust.add(ctx.teamId, Exchange.gain("recon"), "recon", ctx.opts)
    reply(ctx, "ok", { getText("IGUI_MilitaryDrop_Reply_ReconDone", ctx.callsign) })
    close("recon", now, "done", ctx.teamId, getText("IGUI_MilitaryDrop_Broadcast_ReconDone", tostring(mission.x),
        tostring(mission.y), ctx.callsign))
end

-- SRC-04 : nettoyage
--- Zombie tué : compté pour l'équipe du tueur s'il est dans la zone.
function Missions.countKill(zombie)
    local now = hoursNow()
    local mission = Missions.openMission("cleanup", now)
    if not mission then
        return
    end
    local modData = zombie:getModData()
    if modData[KILL_KEY] == mission.id then
        return
    end
    local dx = zombie:getX() - (mission.x + 0.5)
    local dy = zombie:getY() - (mission.y + 0.5)
    if dx * dx + dy * dy > mission.radius * mission.radius then
        return
    end
    local killer = zombie:getAttackedBy()
    if not killer or not instanceof(killer, "IsoPlayer") then
        return
    end
    local teamId = MilitaryDrop.Teams.idFor(killer)
    if not teamId or MilitaryDrop.Trust.isLineCut(teamId) then
        return
    end
    modData[KILL_KEY] = mission.id
    local count = (tonumber(mission.counts[teamId]) or 0) + 1
    mission.counts[teamId] = count
    if count >= mission.quota then
        MilitaryDrop.Trust.add(teamId, Exchange.gain("cleanup"), "cleanup")
        close("cleanup", now, "done", teamId, getText("IGUI_MilitaryDrop_Broadcast_CleanupDone", tostring(mission.x),
            tostring(mission.y), MilitaryDrop.Teams.callsign(teamId) or ""))
    end
end

-- SRC-05 : appel de contrôle
function Missions.confirmControl(player, args)
    local ctx = begin(player, args, "control")
    if not ctx then
        return
    end
    local mission = Missions.openMission("control")
    if not mission then
        reply(ctx, "noMission", { getText("IGUI_MilitaryDrop_Reply_NoControl", ctx.callsign) })
        return
    end
    if mission.responded[ctx.teamId] then
        reply(ctx, "already", { getText("IGUI_MilitaryDrop_Reply_ControlAlready", ctx.callsign) })
        return
    end
    mission.responded[ctx.teamId] = true
    MilitaryDrop.Trust.add(ctx.teamId, Exchange.gain("control"), "control", ctx.opts)
    reply(ctx, "ok", { getText("IGUI_MilitaryDrop_Reply_ControlDone", ctx.callsign) })
end

--- Missions ouvertes et progression de l'équipe (console du poste de liaison) :
--- liste de { kind, title, text, deadlineHours (heures restantes), deadline
--- (heure absolue), x, y, radius, progress, quota }.
function Missions.listForTeam(teamId)
    local now = hoursNow()
    local list = {}
    for _, kind in ipairs(Missions.KINDS) do
        local mission = Missions.openMission(kind, now)
        if mission then
            local entry = { kind = kind, title = getText(TITLES[kind]), text = mission.text,
                deadlineHours = math.max(0, mission.deadline - now), deadline = mission.deadline,
                hours = mission.deadline - mission.openedHours,
                x = mission.x, y = mission.y, radius = mission.radius }
            if kind == "cleanup" then
                entry.progress = tonumber(mission.counts[teamId]) or 0
                entry.quota = mission.quota
            elseif kind == "control" then
                entry.progress = mission.responded[teamId] and 1 or 0
                entry.quota = 1
            end
            list[#list + 1] = entry
        end
    end
    return list
end

function Missions.onZombieDead(zombie)
    Missions.countKill(zombie)
end

local COMMANDS = MilitaryDrop.Server.COMMANDS
COMMANDS[Exchange.COMMANDS.report] = function(player, args) Missions.report(player, args) end
COMMANDS[Exchange.COMMANDS.dogtag] = function(player, args) Missions.transmitDogTags(player, args) end
COMMANDS[Exchange.COMMANDS.recon] = function(player, args) Missions.confirmRecon(player, args) end
COMMANDS[Exchange.COMMANDS.control] = function(player, args) Missions.confirmControl(player, args) end

Events.EveryTenMinutes.Add(function() Missions.update() end)
Events.OnZombieDead.Add(Missions.onZombieDead)

return Missions
