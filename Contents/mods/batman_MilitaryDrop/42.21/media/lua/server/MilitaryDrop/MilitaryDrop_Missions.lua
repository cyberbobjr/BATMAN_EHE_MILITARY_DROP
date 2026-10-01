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
--   * SRC-03 reconnaissance (publique) : grille dans l'anneau des largages
--     autour d'un joueur connecté, sur la terre ferme (Missions.pickSite :
--     centre d'un bâtiment, sinon route, la métagrille ne connaissant pas
--     l'eau) ; première équipe qui confirme à RECON_RADIUS cases au plus avant
--     ReconHours → +ReconGain ;
--   * SRC-04 nettoyage (publique) : horde signalée dans un rayon de
--     CLEANUP_RADIUS cases autour d'un bâtiment entouré d'autres
--     (Missions.pickSite). Quand la case du centre est chargée (premier joueur
--     qui approche : LoadChunk, lancement, toutes les 10 minutes), le serveur
--     fait apparaître UNE fois CleanupQuota zombies répartis dans la zone, sur
--     des cases extérieures libres, loin des joueurs (Missions.spawnHorde).
--     Chaque zombie est suivi par sa tenue persistante (voir plus bas) : seuls
--     ceux-là comptent, où qu'ils meurent. Mort d'un zombie de la horde
--     (OnZombieDead serveur), toute cause : compté pour le « reste » ; tueur
--     zombie:getAttackedBy() IsoPlayer dont la ligne n'est pas coupée : compté
--     aussi pour son équipe (figée à la mort). À HORDE_SHARE (90 %) de la
--     horde morte, arrondi au supérieur, l'ordre se clôt : l'équipe qui en a
--     abattu le plus gagne +CleanupGain (égalité : la première à ce compte) ;
--     aucune : clôture sans récompense. Sinon, échéance CleanupHours.
--     « Faire le point » (Missions.cleanupStatus) : réponse privée, sans gain ;
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
--     counts = { teamId = zombies de la horde abattus }, reached = { teamId =
--     rang du dernier abattu (égalités) }, seq, horde = { ids = { clé de
--     tenue = zombies vivants }, size, dead, hours } (nettoyage, horde
--     apparue), responded = { teamId = true } (appel de contrôle) }
--     Ancien format (nettoyage v1.3 sans horde) : la horde apparaît à la
--     prochaine arrivée, les anciens comptes sont remis à zéro.
-- ModData de zombie : mission de nettoyage déjà comptée (double OnZombieDead
-- d'un zombie brûlé).
--
-- Suivi d'un zombie de la horde : ses ModData sont vidées quand il devient
-- virtuel puis réel à nouveau (IsoZombie.resetForReuse) et persistentId n'a
-- pas de getter. Seule getPersistentOutfitID() est conservée à la
-- virtualisation et au rechargement (ZombiePopulationManager.java:395-427,
-- relue par createRealZombieAlways, :611, VirtualZombieManager.java:189-191) :
-- bit femme (signe) + tenue × 65 536 + bit « chapeau tombé » (0x8000, posé
-- en jeu par setFallenHat, donc retiré de la clé) + variante 1-500
-- (PersistentOutfits.java:142-186, 293-300). Clé non unique : registre par
-- clé avec un nombre de zombies vivants ; un autre zombie de même tenue et
-- même variante tué ailleurs peut prendre une place (rare, accepté).
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
-- Part de la horde à abattre pour clore le nettoyage (en dixièmes : arrondi
-- au supérieur sans erreur de flottant).
Missions.HORDE_SHARE_TENTHS = 9
-- Cases d'apparition : tirées dans le disque de la zone, extérieures et
-- libres ; d'abord à HORDE_FAR cases au moins de tout joueur (hors de vue en
-- pratique), sinon à HORDE_NEAR ; aucune plus près.
Missions.HORDE_FAR = 30
Missions.HORDE_NEAR = 15
Missions.HORDE_ATTEMPTS = 400
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
--- la reconnaissance ou du nettoyage, MilitaryDrop.Broadcast.reconAnnounced
--- et cleanupAnnounced), pas de la fin.
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
    if kind == "cleanup" then
        Missions.sendCleanupState()
    end
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

-- ----------------------------------------------------------------------------
-- Point d'une mission : sur la terre ferme, d'après la métagrille
-- ----------------------------------------------------------------------------
-- La métagrille ne connaît pas l'eau : aucune zone de type eau n'y est
-- enregistrée (WaterFlow et WaterZone vont à registerWaterFlow et
-- registerWaterZone, metazoneHandler.lua:34-65, 99-102). Elle connaît en
-- revanche, sans rien charger, les bâtiments (IsoMetaCell :
-- getBuildingsIntersecting, IsoMetaCell.java:255-273) et les routes (zones
-- « Nav » des rues de streets.xml, WorldMapStreet.java:973-1025, lues par
-- getZonesIntersecting, IsoMetaGrid.java:222-235), toujours sur la terre
-- ferme. Le point vise donc le centre d'un bâtiment, sinon une route, et
-- seulement en dernier recours un point tiré comme un largage.
-- IsoMetaGrid.getBuildingsIntersecting n'est pas utilisé : il parcourt les
-- cellules jusqu'à (x + nombre de cellules de la carte) / 256 au lieu de
-- (x + w) / 256 (IsoMetaGrid.java:408-416), donc une ou deux cellules
-- seulement ; on interroge chaque cellule touchée.

-- Points tirés dans l'anneau de distance, par méthode.
Missions.SITE_ATTEMPTS = 20
-- Demi-côté de la fenêtre examinée autour de chaque point tiré.
Missions.SITE_WINDOW = 48
-- Plus grand côté d'un bâtiment visé : son centre reste à 20 cases au plus de
-- son bord, la confirmation (RECON_RADIUS = 25) se fait de l'extérieur.
Missions.SITE_MAX_BUILDING = 40
-- Nettoyage : au moins ce nombre de bâtiments (le visé compris) à
-- CLEANUP_RADIUS cases de son centre, pour une zone habitée plutôt qu'une
-- cabane au bord d'un lac.
Missions.CLEANUP_MIN_BUILDINGS = 3
Missions.ROAD_ZONE = "Nav"
Missions.CELL_SIZE = 256

--- Anneau de distance des largages (options DropMinDistance, DropMaxDistance).
local function ring()
    local low = math.max(0, tonumber(Config.get("DropMinDistance")) or 0)
    local high = math.max(0, tonumber(Config.get("DropMaxDistance")) or 0)
    if high < low then
        low, high = high, low
    end
    return low, high
end

local function ringPoint(cx, cy, low, high)
    local angle = ZombRandFloat(0, 2 * math.pi)
    local distance = ZombRandFloat(low, high)
    return math.floor(cx + math.cos(angle) * distance), math.floor(cy + math.sin(angle) * distance)
end

--- Bâtiments (BuildingDef) qui touchent le carré de demi-côté w autour de
--- (px, py) : liste Java (la métagrille ne met pas deux fois le même).
local function buildingsNear(grid, px, py, w)
    local list = ArrayList.new()
    local size = Missions.CELL_SIZE
    local x0, y0 = math.max(0, px - w), math.max(0, py - w)
    for cy = math.floor(y0 / size), math.floor((py + w) / size) do
        for cx = math.floor(x0 / size), math.floor((px + w) / size) do
            local cell = grid:getCellData(cx, cy)
            if cell then
                cell:getBuildingsIntersecting(x0, y0, px + w - x0, py + w - y0, list)
            end
        end
    end
    return list
end

--- Centre d'un bâtiment visable (ni construit par un joueur, ni seulement
--- souterrain, assez petit), ou nil.
local function buildingCenter(building)
    if building:isUserDefined() or building:isBasement() then
        return nil
    end
    local w, h = building:getW(), building:getH()
    if w < 1 or h < 1 or w > Missions.SITE_MAX_BUILDING or h > Missions.SITE_MAX_BUILDING then
        return nil
    end
    return building:getX() + math.floor(w / 2), building:getY() + math.floor(h / 2)
end

local function inRing(x, y, cx, cy, low, high)
    local d2 = (x - cx) * (x - cx) + (y - cy) * (y - cy)
    return d2 >= low * low and d2 <= high * high
end

--- Centre d'un bâtiment dans l'anneau (nettoyage : au milieu d'autres), ou nil.
local function buildingSite(grid, kind, cx, cy, low, high)
    local w = Missions.SITE_WINDOW
    for _ = 1, Missions.SITE_ATTEMPTS do
        local px, py = ringPoint(cx, cy, low, high)
        if grid:isValidSquare(px, py) then
            local list = buildingsNear(grid, px, py, kind == "cleanup" and (w + Missions.CLEANUP_RADIUS) or w)
            local centers, candidates = {}, {}
            for i = 0, list:size() - 1 do
                local x, y = buildingCenter(list:get(i))
                if x then
                    centers[#centers + 1] = { x = x, y = y }
                end
            end
            local r2 = Missions.CLEANUP_RADIUS * Missions.CLEANUP_RADIUS
            for _, c in ipairs(centers) do
                local ok = math.abs(c.x - px) <= w and math.abs(c.y - py) <= w and inRing(c.x, c.y, cx, cy, low, high)
                if ok and kind == "cleanup" then
                    local around = 0
                    for _, other in ipairs(centers) do
                        if (other.x - c.x) * (other.x - c.x) + (other.y - c.y) * (other.y - c.y) <= r2 then
                            around = around + 1
                        end
                    end
                    ok = around >= Missions.CLEANUP_MIN_BUILDINGS
                end
                if ok then
                    candidates[#candidates + 1] = c
                end
            end
            if #candidates > 0 then
                local c = candidates[ZombRand(#candidates) + 1]
                return c.x, c.y
            end
        end
    end
    return nil
end

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

--- Point d'une route (zone « Nav » rectangulaire) près d'un point de l'anneau, ou nil.
local function roadSite(grid, cx, cy, low, high)
    local w = Missions.SITE_WINDOW
    for _ = 1, Missions.SITE_ATTEMPTS do
        local px, py = ringPoint(cx, cy, low, high)
        if grid:isValidSquare(px, py) then
            local zones = grid:getZonesIntersecting(math.max(0, px - w), math.max(0, py - w), 0, 2 * w, 2 * w)
            local candidates = {}
            for i = 0, zones:size() - 1 do
                local zone = zones:get(i)
                if zone:getType() == Missions.ROAD_ZONE and zone:isRectangle() and zone:getWidth() > 0
                    and zone:getHeight() > 0 then
                    -- Case de la route la plus proche du point tiré.
                    local x = clamp(px, zone:getX(), zone:getX() + zone:getWidth() - 1)
                    local y = clamp(py, zone:getY(), zone:getY() + zone:getHeight() - 1)
                    if grid:isValidSquare(x, y) then
                        candidates[#candidates + 1] = { x = x, y = y }
                    end
                end
            end
            if #candidates > 0 then
                local c = candidates[ZombRand(#candidates) + 1]
                return c.x, c.y
            end
        end
    end
    return nil
end

--- Point d'une reconnaissance ou d'un nettoyage autour de (cx, cy), dans
--- l'anneau des largages : centre d'un bâtiment, sinon route, sinon point
--- tiré comme un largage (Server.pickDropPoint, eau possible). Renvoie x, y
--- et la méthode (« building », « road », « fallback »), ou nil.
function Missions.pickSite(kind, cx, cy)
    local grid = getWorld():getMetaGrid()
    local low, high = ring()
    local x, y = buildingSite(grid, kind, cx, cy, low, high)
    if x then
        return x, y, "building"
    end
    x, y = roadSite(grid, cx, cy, low, high)
    if x then
        return x, y, "road"
    end
    x, y = MilitaryDrop.Server.pickDropPoint(cx, cy)
    if x then
        return x, y, "fallback"
    end
    return nil
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
        local x, y, how = Missions.pickSite(kind, math.floor(around:getX()), math.floor(around:getY()))
        if not x then
            return nil
        end
        mission.x, mission.y = x, y
        MilitaryDrop.log("mission site " .. x .. "," .. y .. " (" .. tostring(how) .. ")")
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
    -- Reconnaissance et nettoyage : coordonnées envoyées avant l'annonce ;
    -- seuls les clients dont une radio reçoit une ligne codée marquent leur carte.
    local code = nil
    local Broadcast = MilitaryDrop.Broadcast
    if kind == "recon" and Broadcast.reconAnnounced then
        code = Broadcast.reconAnnounced(mission.id, mission.x, mission.y)
    elseif kind == "cleanup" and Broadcast.cleanupAnnounced then
        code = Broadcast.cleanupAnnounced(mission.id, mission.x, mission.y, mission.radius)
    end
    Missions.announce(mission.text, Missions.ANNOUNCE_REPEATS, code)
    MilitaryDrop.log("mission " .. mission.id .. " (" .. kind .. ") until " .. mission.deadline)
    if kind == "cleanup" then
        mission.reached, mission.seq = {}, 0
        Missions.sendCleanupState()
        -- Centre déjà chargé (lancement près d'un joueur) : LoadChunk ne
        -- reviendra pas pour ses chunks.
        Missions.trySpawnHorde(now)
    end
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
    -- Horde pas encore apparue alors que le centre est chargé (chunk chargé
    -- avant l'ouverture, ou aucune case libre au premier essai).
    Missions.trySpawnHorde(now)
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

--- Clé de suivi d'un zombie : sexe (bit de signe : « F », sinon « M ») et 31
--- bits bas de la tenue persistante, sans le bit « chapeau tombé » (0x8000,
--- posé en jeu). Chaîne courte, entiers sous 2^31 (string.format %d sûr).
--- nil : aucune tenue persistante.
function Missions.hordeKey(outfitId)
    local value = tonumber(outfitId)
    if not value or value == 0 or value ~= math.floor(value) then
        return nil
    end
    local sex = "M"
    if value < 0 then
        sex = "F"
        value = value + 2147483648
    end
    value = value - (math.floor(value / 32768) % 2) * 32768
    return sex .. string.format("%d", value)
end

--- Zombies de la horde à abattre pour clore l'ordre : HORDE_SHARE_TENTHS
--- dixièmes de la horde, arrondi au supérieur (au moins 1).
function Missions.hordeTarget(horde)
    local size = math.max(0, math.floor(tonumber(horde and horde.size) or 0))
    return math.max(1, math.floor((size * Missions.HORDE_SHARE_TENTHS + 9) / 10))
end

--- Zombies de la horde encore à abattre avant la clôture (jamais négatif).
function Missions.hordeLeft(horde)
    return math.max(0, Missions.hordeTarget(horde) - (tonumber(horde and horde.dead) or 0))
end

--- Clients : un nettoyage est-il en cours (grisé de « Faire le point ») ? À
--- un joueur (arrivée en jeu, Sync) ou à tous (ouverture, clôture). Rien de
--- la horde : l'annonce publique dit déjà qu'un ordre est ouvert.
function Missions.sendCleanupState(player)
    local args = { open = Missions.openMission("cleanup") ~= nil }
    if player then
        MilitaryDrop.Net.toPlayer(player, "CleanupState", args)
    else
        MilitaryDrop.Net.toAll("CleanupState", args)
    end
end

--- Arrivée d'un joueur (commande Sync du client).
function Missions.sync(player)
    Missions.sendCleanupState(player)
end

--- Cases d'apparition de la horde : tirées dans le disque de la zone, chargées,
--- extérieures et libres (Server.isFreeSquare), distinctes ; celles à
--- HORDE_FAR cases au moins de tout joueur d'abord, puis celles à HORDE_NEAR.
--- Au plus count cases de chaque sorte.
function Missions.hordeSquares(mission, count)
    local cell = getCell()
    local players = livePlayers()
    local far2, near2 = Missions.HORDE_FAR * Missions.HORDE_FAR, Missions.HORDE_NEAR * Missions.HORDE_NEAR
    local far, near, seen = {}, {}, {}
    local radius = tonumber(mission.radius) or Missions.CLEANUP_RADIUS
    for _ = 1, Missions.HORDE_ATTEMPTS do
        if #far >= count then
            break
        end
        -- Tirage uniforme dans le disque (racine du rayon).
        local angle = ZombRandFloat(0, 2 * math.pi)
        local distance = radius * math.sqrt(ZombRandFloat(0, 1))
        local x = math.floor(mission.x + 0.5 + math.cos(angle) * distance)
        local y = math.floor(mission.y + 0.5 + math.sin(angle) * distance)
        local key = x .. "," .. y
        if not seen[key] then
            seen[key] = true
            local square = cell:getGridSquare(x, y, 0)
            if square and MilitaryDrop.Server.isFreeSquare(square) then
                local closest = nil
                for _, player in ipairs(players) do
                    local dx, dy = player:getX() - (x + 0.5), player:getY() - (y + 0.5)
                    local d2 = dx * dx + dy * dy
                    if not closest or d2 < closest then
                        closest = d2
                    end
                end
                if not closest or closest >= far2 then
                    far[#far + 1] = square
                elseif closest >= near2 and #near < count then
                    near[#near + 1] = square
                end
            end
        end
    end
    for _, square in ipairs(near) do
        far[#far + 1] = square
    end
    return far
end

--- Un zombie sur la case : apparition vanilla (spawnHorde sur une seule case :
--- Rand.Next(min, min) rend min, RandAbstract.java:69-72 ; tenue tirée de la
--- zone, santé selon les options, comme la horde d'un largage), puis le
--- zombie créé, dernier ajouté à la liste des zombies de la cellule
--- (VirtualZombieManager.createRealZombieAlways, VirtualZombieManager.java:
--- 208-211, après OnZombieCreate). spawnHorde ne rend rien ; protégé par
--- pcall : création de zombies désactivée → zombie nul → erreur Java.
local function spawnOne(cell, square)
    local x, y = square:getX(), square:getY()
    local list = cell:getZombieList()
    local before = list:size()
    if not pcall(spawnHorde, x + 0.5, y + 0.5, x + 0.5, y + 0.5, 0, 1) then
        return nil
    end
    local after = list:size()
    if after <= before then
        return nil
    end
    local zombie = list:get(after - 1)
    if zombie and instanceof(zombie, "IsoZombie") and math.floor(zombie:getX()) == x
        and math.floor(zombie:getY()) == y then
        return zombie
    end
    return nil
end

--- Fait apparaître la horde du nettoyage ouvert, une seule fois, si la case de
--- son centre est chargée (serveur MP : cellule de 64 × 64 cases déjà lisible
--- dans LoadChunk ; solo : zone du joueur). Renvoie le nombre de zombies
--- suivis, ou nil (rien à faire, ou à retenter : aucune case libre, aucun
--- zombie créé).
function Missions.trySpawnHorde(now)
    local mission = Missions.openMission("cleanup", now)
    if not mission or type(mission.horde) == "table" or not mission.x then
        return nil
    end
    local cell = getCell()
    if not cell or not cell:getGridSquare(mission.x, mission.y, 0) then
        return nil
    end
    local count = math.max(1, math.floor(tonumber(mission.quota) or optionNumber("CleanupQuota", 1)))
    local squares = Missions.hordeSquares(mission, count)
    if #squares == 0 then
        return nil
    end
    -- Registre écrit avant les apparitions (un LoadChunk pendant l'une d'elles
    -- ne relance rien) ; comptes remis à zéro (ancien format : morts de
    -- n'importe quel zombie).
    local horde = { ids = {}, size = 0, dead = 0, hours = now or hoursNow() }
    mission.horde = horde
    mission.counts, mission.reached, mission.seq = {}, {}, 0
    for i = 1, count do
        local zombie = spawnOne(cell, squares[(i - 1) % #squares + 1])
        local key = zombie and Missions.hordeKey(zombie:getPersistentOutfitID())
        if key then
            horde.ids[key] = (tonumber(horde.ids[key]) or 0) + 1
            horde.size = horde.size + 1
        end
    end
    if horde.size == 0 then
        -- Aucun zombie suivi : pas d'apparition, nouvel essai plus tard.
        mission.horde = nil
        MilitaryDrop.log("cleanup " .. mission.id .. ": no horde zombie could spawn", true)
        return nil
    end
    MilitaryDrop.log(string.format("cleanup %s: horde of %d (%d tracked) around %d,%d on %d squares",
        mission.id, count, horde.size, mission.x, mission.y, #squares))
    return horde.size
end

--- Fin du chargement d'un chunk : la horde attend que le centre soit chargé
--- (la case visée, pas un chunk voisin).
function Missions.onLoadChunk()
    local mission = state().open.cleanup
    if mission and type(mission.horde) ~= "table" then
        Missions.trySpawnHorde()
    end
end

--- Équipe qui a abattu le plus de zombies de la horde (égalité : la première
--- à ce compte), ou nil.
function Missions.cleanupWinner(mission)
    local best, bestCount, bestRank = nil, 0, nil
    for teamId, value in pairs(mission.counts or {}) do
        local count = tonumber(value) or 0
        local rank = tonumber(mission.reached and mission.reached[teamId]) or math.huge
        if count > bestCount or (count == bestCount and count > 0 and rank < bestRank) then
            best, bestCount, bestRank = teamId, count, rank
        end
    end
    return best
end

--- HORDE_SHARE atteinte : récompense de la meilleure équipe, clôture annoncée.
local function finishCleanup(mission, now)
    local winner = Missions.cleanupWinner(mission)
    local x, y = tostring(mission.x), tostring(mission.y)
    if winner then
        MilitaryDrop.Trust.add(winner, Exchange.gain("cleanup"), "cleanup")
        close("cleanup", now, "done", winner, getText("IGUI_MilitaryDrop_Broadcast_CleanupDone", x, y,
            MilitaryDrop.Teams.callsign(winner) or ""))
    else
        close("cleanup", now, "destroyed", nil, getText("IGUI_MilitaryDrop_Broadcast_CleanupNoWinner", x, y))
    end
end

--- Zombie mort (OnZombieDead, serveur) : seul un zombie de la horde compte,
--- où qu'il meure et quelle que soit la cause ; pour l'équipe de son tueur
--- joueur si sa ligne n'est pas coupée.
function Missions.countKill(zombie)
    local now = hoursNow()
    local mission = Missions.openMission("cleanup", now)
    if not mission or type(mission.horde) ~= "table" then
        return
    end
    local horde = mission.horde
    local modData = zombie:getModData()
    if modData[KILL_KEY] == mission.id then
        return
    end
    local key = Missions.hordeKey(zombie:getPersistentOutfitID())
    local alive = key and tonumber(horde.ids[key]) or 0
    if alive <= 0 then
        return
    end
    modData[KILL_KEY] = mission.id
    horde.ids[key] = alive > 1 and alive - 1 or nil
    horde.dead = (tonumber(horde.dead) or 0) + 1
    local killer = zombie:getAttackedBy()
    if killer and instanceof(killer, "IsoPlayer") then
        local teamId = MilitaryDrop.Teams.idFor(killer)
        if teamId and not MilitaryDrop.Trust.isLineCut(teamId) then
            mission.counts = mission.counts or {}
            mission.reached = mission.reached or {}
            mission.seq = (tonumber(mission.seq) or 0) + 1
            mission.counts[teamId] = (tonumber(mission.counts[teamId]) or 0) + 1
            mission.reached[teamId] = mission.seq
        end
    end
    if horde.dead >= Missions.hordeTarget(horde) then
        finishCleanup(mission, now)
    end
end

--- « Faire le point » : avant l'apparition, la grille à rejoindre ; après, les
--- zombies de la horde abattus par l'équipe et ceux qui restent à abattre
--- avant la clôture (pas les survivants : l'ordre se clôt avant le dernier).
--- Aucun gain.
function Missions.cleanupStatus(player, args)
    local ctx = begin(player, args, "cleanup")
    if not ctx then
        return
    end
    local mission = Missions.openMission("cleanup")
    if not mission then
        reply(ctx, "noMission", { getText("IGUI_MilitaryDrop_Reply_NoCleanup", ctx.callsign) })
        return
    end
    if type(mission.horde) ~= "table" then
        reply(ctx, "ok", { getText("IGUI_MilitaryDrop_Reply_CleanupPending", ctx.callsign, tostring(mission.x),
            tostring(mission.y), tostring(mission.radius)) })
        return
    end
    local mine = tonumber(mission.counts and mission.counts[ctx.teamId]) or 0
    reply(ctx, "ok", { getText("IGUI_MilitaryDrop_Reply_CleanupStatus", ctx.callsign, tostring(mine),
        tostring(Missions.hordeLeft(mission.horde))) })
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
--- (heure absolue), x, y, radius, progress, quota } ; nettoyage : progress
--- (zombies de la horde abattus par l'équipe), spotted (horde apparue), left
--- (reste à abattre avant la clôture), down (morts), target (objectif).
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
                -- Horde apparue : abattus par l'équipe, reste à abattre avant
                -- la clôture, morts et objectif (barre) ; sinon pas encore repérée.
                local horde = type(mission.horde) == "table" and mission.horde or nil
                entry.spotted = horde ~= nil
                entry.progress = horde and (tonumber(mission.counts and mission.counts[teamId]) or 0) or 0
                if horde then
                    entry.left = Missions.hordeLeft(horde)
                    entry.down = tonumber(horde.dead) or 0
                    entry.target = Missions.hordeTarget(horde)
                end
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

-- ----------------------------------------------------------------------------
-- Mission lancée par un admin (menu contextuel d'une radio militaire)
-- ----------------------------------------------------------------------------

-- Une commande d'admin par seconde réelle au plus ; réponse privée (Notice).
Missions.ADMIN_INTERVAL_MS = 1000
Missions.ADMIN_RESULTS = {
    launched = "IGUI_MilitaryDrop_AdminMission_Launched",
    open = "IGUI_MilitaryDrop_AdminMission_Open",
    failed = "IGUI_MilitaryDrop_AdminMission_Failed",
    closed = "IGUI_MilitaryDrop_AdminMission_Closed",
    none = "IGUI_MilitaryDrop_AdminMission_None",
}

--- Même mission que la planification (Missions.launch : annonce à toutes les
--- stations, repère, quota, échéance) ; seul le moment change. Avec
--- args.action == "close" : clôt la mission de ce type en cours, sans
--- récompense, avec l'annonce d'annulation (la suivante est planifiée comme
--- après une échéance). Droit revérifié ici (Server.canForce, comme le
--- largage forcé). Renvoie le statut.
function Missions.adminLaunch(player, args)
    if not MilitaryDrop.Server.canForce(player) then
        return "denied"
    end
    local kind = type(args) == "table" and args.kind
    if type(kind) ~= "string" or not HOURS_OPTIONS[kind] then
        return "invalid"
    end
    if MilitaryDrop.Guard.throttled(player, "AdminMission", Missions.ADMIN_INTERVAL_MS) then
        return "busy"
    end
    local status
    local mission = Missions.openMission(kind)
    if args.action == "close" then
        if mission then
            local text
            if kind == "control" then
                text = getText("IGUI_MilitaryDrop_Broadcast_ControlCancelled")
            else
                local key = kind == "recon" and "IGUI_MilitaryDrop_Broadcast_ReconExpired"
                    or "IGUI_MilitaryDrop_Broadcast_CleanupExpired"
                text = getText(key, tostring(mission.x), tostring(mission.y))
            end
            close(kind, hoursNow(), "cancelled", nil, text)
            status = "closed"
        else
            status = "none"
        end
    elseif mission then
        status = "open"
    else
        status = Missions.launch(kind) and "launched" or "failed"
    end
    MilitaryDrop.log("admin " .. tostring(player:getUsername()) .. " mission " .. kind .. ": " .. status, true)
    MilitaryDrop.Net.toPlayer(player, "Notice", { key = Missions.ADMIN_RESULTS[status],
        username = tostring(player:getUsername()) })
    return status
end

local COMMANDS = MilitaryDrop.Server.COMMANDS
COMMANDS.AdminMission = function(player, args) Missions.adminLaunch(player, args) end
COMMANDS[Exchange.COMMANDS.report] = function(player, args) Missions.report(player, args) end
COMMANDS[Exchange.COMMANDS.dogtag] = function(player, args) Missions.transmitDogTags(player, args) end
COMMANDS[Exchange.COMMANDS.recon] = function(player, args) Missions.confirmRecon(player, args) end
COMMANDS[Exchange.COMMANDS.control] = function(player, args) Missions.confirmControl(player, args) end
COMMANDS[Exchange.COMMANDS.cleanupStatus] = function(player, args) Missions.cleanupStatus(player, args) end

Events.EveryTenMinutes.Add(function() Missions.update() end)
Events.OnZombieDead.Add(Missions.onZombieDead)
Events.LoadChunk.Add(Missions.onLoadChunk)

return Missions
