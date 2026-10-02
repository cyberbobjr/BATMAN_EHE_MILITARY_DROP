-- ============================================================================
-- Military Drop — poste de commandement (« poste de liaison »), serveur MP ou solo
--
-- Poste = radio posée (IsoWaveSignal) non portable, haut de gamme et capable
-- d'émettre (propriétés DeviceData, aucun nom d'objet). Un seul poste actif
-- par équipe (MilitaryDrop_Teams.lua) : l'installer ailleurs le déplace. Un
-- objet du monde n'a pas d'identifiant persistant : le poste est une position
-- (x, y, z) et un uid écrit dans la ModData de l'objet, retrouvé en balayant
-- la case. Le ramassage vanilla perd cette ModData : une radio ramassée ou
-- détruite n'est plus le poste, ce qui est constaté au chargement de sa case
-- (LoadChunk), chaque minute de jeu tant qu'elle est chargée, ou à l'usage.
--
-- Journal (POSTE-05) : toute ligne que la base adresse à l'équipe ou à toutes
-- les stations (Post.record) est ajoutée au journal de l'équipe si le poste la
-- reçoit :
--   * case chargée : état réel (allumé, canal militaire, canBePoweredHere,
--     pile > 0) ;
--   * case déchargée : l'IsoWaveSignal est retiré du monde et de ZomboidRadio
--     (IsoWaveSignal.java:322-338), son état n'est plus lisible. On lit alors
--     l'instantané pris pendant qu'il était chargé (allumé, canal) et sa
--     source : secteur → réseau global actuel (la coupure est globale) ;
--     générateur → carburant projeté > 0 (il rattrape sa consommation au
--     rechargement, IsoGenerator.java:182-236) ; pile → charge figée (la pile
--     d'un appareil déchargé ne se vide pas : DeviceData.lastMinuteStamp n'est
--     pas sauvegardé).
-- Sinon, une entrée « aucune réception » (regroupée) marque le trou. 200
-- entrées au plus par équipe, dont les 60 dernières sont envoyées à la console
-- (LOG_SEND_MAX). Le journal, la boîte à courrier et les missions
-- sont à l'équipe, pas à l'objet : perdre la radio ne fait rien perdre.
--
-- Boîte à courrier : plaques d'identité vanilla renommées d'après leur
-- porteur (MilitaryDrop.Exchange.isDogTag : pas celle du déposant) déposées
-- par les membres, retirées de leur inventaire par le serveur ; « Transmettre
-- le courrier » les crédite par MilitaryDrop.Missions.creditDogTag (fromPost :
-- bonus du poste, POSTE-06) et la base cite les noms au journal.
--
-- La fréquence militaire ne se trahit pas : la console n'indique jamais si le
-- poste est « sur la bonne fréquence », et une transmission sur un autre canal
-- reçoit la même réponse qu'un appel sans réponse.
--
-- Cadence par commande et par joueur (MilitaryDrop_Guard.lua) : 0,3 s pour
-- l'installation, la console, le dépôt et l'état d'une radio (PostQuery :
-- bouton « Poste de liaison » de la fenêtre radio), 3 s pour la
-- transmission ; une commande refusée reçoit PostResult « busy ».
--
-- État privé (MilitaryDrop.Secrets.privateState, jamais transmis ; la console
-- n'en reçoit que ce qui concerne l'équipe du joueur) :
--   posts[teamId] = { x, y, z, uid, snapshot = { h, on, channel, source,
--                     power, grid, gen = { x, y, z, fuel, rate }, scanH } }
--   postLogs[teamId] = { { c, t } | { c, c2, gap, lt } | { c, sys } … }
--                      (c : horloge du calendrier, Server.clock)
--   postMail[teamId] = { { id, name, by, c } … } (id : identifiant d'objet de
--                      la plaque, chaîne ; name : nom du soldat ; by : déposant)
--   nextPostUid = compteur des uid
-- ModData d'objet : Post.UID_KEY sur la radio du poste.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Server"
require "MilitaryDrop/MilitaryDrop_Secrets"
require "MilitaryDrop/MilitaryDrop_Guard"
require "MilitaryDrop/MilitaryDrop_Teams"
require "MilitaryDrop/MilitaryDrop_Trust"
require "MilitaryDrop/MilitaryDrop_Exchange"

local Config = MilitaryDrop.Config
local Net = MilitaryDrop.Net
local Radio = MilitaryDrop.Radio
local Teams = MilitaryDrop.Teams
local Exchange = MilitaryDrop.Exchange

local Post = {}
MilitaryDrop.Post = Post

Post.UID_KEY = "MilitaryDrop_postUid"
Post.LOG_MAX = 200
-- Lignes du journal envoyées à la console (les plus récentes).
Post.LOG_SEND_MAX = 60
Post.MAIL_MAX = 100
Post.DEPOSIT_MAX = 50
Post.MISSION_MAX = 10
Post.TEXT_MAX = 400
-- Une commande de console par joueur toutes les 0,3 s réelles au plus, par
-- commande ; une transmission toutes les 3 s (échange radio avec la base).
Post.COMMAND_INTERVAL_MS = 300
Post.TRANSMIT_INTERVAL_MS = 3000
-- Même ligne enregistrée deux fois (annonce relayée par deux modules) : ignorée.
Post.DEDUP_HOURS = 0.1
-- Recherche complète d'un générateur : au plus toutes les 10 minutes de jeu.
Post.GENERATOR_SCAN_HOURS = 1 / 6
-- Portée vanilla par défaut (SandboxOptions GeneratorTileRange, GeneratorVerticalPowerRange).
Post.GENERATOR_RANGE = 20
Post.GENERATOR_LEVELS = 3

-- Motifs de refus de Missions.creditDogTag pour lesquels la plaque reste dans
-- la boîte (plafond du jour, ligne coupée, source désactivée) ; les autres
-- (identifiant mal formé ou plaque déjà transmise) la consomment.
Post.KEEP_MAIL = { dailyCap = true, full = true, lineCut = true, disabled = true }

local function state()
    local s = MilitaryDrop.Secrets.privateState()
    s.posts = s.posts or {}
    s.postLogs = s.postLogs or {}
    s.postMail = s.postMail or {}
    return s
end

local function hoursNow()
    return getGameTime():getWorldAgeHours()
end

local function clockNow()
    return MilitaryDrop.Server.clock()
end

local function isInteger(value)
    return type(value) == "number" and value == math.floor(value)
end

local function sortedKeys(t)
    local keys = {}
    for key in pairs(t) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function sandboxNumber(name, default)
    local value = SandboxVars and tonumber(SandboxVars[name])
    return value or default
end

local function shortText(value)
    if type(value) ~= "string" and type(value) ~= "number" then
        return nil
    end
    value = tostring(value)
    if #value > Post.TEXT_MAX then
        value = string.sub(value, 1, Post.TEXT_MAX)
    end
    return value
end

-- ----------------------------------------------------------------------------
-- Radio du poste
-- ----------------------------------------------------------------------------

--- Radio posée pouvant servir de poste : non portable, haut de gamme, émettrice.
function Post.isEligible(object)
    if not Radio.isWorldRadio(object) then
        return false
    end
    local data = object:getDeviceData()
    return data ~= nil and not data:getIsPortable() and data:getIsHighTier() == true and data:getIsTwoWay() == true
end

local function transmitModData(object)
    if isServer() then
        object:transmitModData()
    end
end

--- Objet du poste sur sa case : objet (ou nil), et vrai si la case est chargée.
local function findPostObject(post)
    local square = getCell():getGridSquare(post.x, post.y, post.z)
    if not square then
        return nil, false
    end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if Radio.isWorldRadio(object) and object:getModData()[Post.UID_KEY] == post.uid then
            return object, true
        end
    end
    return nil, true
end

local function matchesPost(post, object)
    if not post or not Radio.isWorldRadio(object) or object:getObjectIndex() == -1 then
        return false
    end
    local square = object:getSquare()
    return square ~= nil and square:getX() == post.x and square:getY() == post.y and square:getZ() == post.z
        and object:getModData()[Post.UID_KEY] == post.uid
end

--- Vrai si object (IsoWaveSignal) est le poste installé de l'équipe teamId.
function Post.isTeamPost(teamId, object)
    return teamId ~= nil and matchesPost(state().posts[teamId], object)
end

--- Équipe dont object est le poste, ou nil.
function Post.ownerOf(object)
    local uid = Radio.isWorldRadio(object) and object:getModData()[Post.UID_KEY]
    if not uid then
        return nil
    end
    local posts = state().posts
    for _, teamId in ipairs(sortedKeys(posts)) do
        if matchesPost(posts[teamId], object) then
            return teamId
        end
    end
    return nil
end

-- ----------------------------------------------------------------------------
-- Alimentation et réception
-- ----------------------------------------------------------------------------

--- Réseau électrique public encore en service (global : SandboxOptions.doesPowerGridExist).
function Post.gridExists()
    return getSandboxOptions():doesPowerGridExist() == true
end

local function activeGeneratorAt(cell, x, y, z)
    local square = cell:getGridSquare(x, y, z)
    if not square then
        return nil
    end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if instanceof(object, "IsoGenerator") and object:isActivated() then
            return object
        end
    end
    return nil
end

--- Générateur allumé qui alimente la case (même règle qu'IsoGenerator.isPoweringSquare),
--- le plus chargé en carburant ; hint (position connue) est essayé d'abord.
--- La recherche complète ne lit que les cases chargées.
function Post.findGenerator(square, hint, full)
    local cell = getCell()
    local range = math.floor(sandboxNumber("GeneratorTileRange", Post.GENERATOR_RANGE))
    local levels = math.floor(sandboxNumber("GeneratorVerticalPowerRange", Post.GENERATOR_LEVELS))
    local sx, sy, sz = square:getX(), square:getY(), square:getZ()
    local function powers(x, y, z)
        local dx, dy = x - sx, y - sy
        return math.abs(z - sz) <= levels and dx * dx + dy * dy <= range * range
    end
    if type(hint) == "table" and isInteger(hint.x) and isInteger(hint.y) and isInteger(hint.z)
        and powers(hint.x, hint.y, hint.z) then
        local generator = activeGeneratorAt(cell, hint.x, hint.y, hint.z)
        if generator or not full then
            return generator
        end
    end
    if not full then
        return nil
    end
    local best = nil
    for z = sz - levels, sz + levels do
        for x = sx - range, sx + range do
            for y = sy - range, sy + range do
                if powers(x, y, z) then
                    local generator = activeGeneratorAt(cell, x, y, z)
                    if generator and (not best or generator:getFuel() > best:getFuel()) then
                        best = generator
                    end
                end
            end
        end
    end
    return best
end

--- Instantané de l'état du poste (case chargée), lu quand elle ne l'est plus.
--- previous : instantané précédent (générateur connu, date de la dernière recherche).
function Post.snapshot(object, previous)
    local data = object:getDeviceData()
    local square = object:getSquare()
    local now = hoursNow()
    local snap = { h = now, on = data:getIsTurnedOn() == true, channel = data:getChannel() }
    if data:getIsBatteryPowered() then
        snap.source = "battery"
        snap.power = data:getPower()
        return snap
    end
    -- Secteur : DeviceData.canBePoweredHere exige une pièce (DeviceData.java:506-530).
    snap.grid = square:hasGridPower() == true and square:getRoom() ~= nil
    snap.scanH = previous and previous.scanH
    if square:haveElectricity() then
        local lastScan = tonumber(snap.scanH)
        local full = not lastScan or now - lastScan >= Post.GENERATOR_SCAN_HOURS or now < lastScan
        local generator = Post.findGenerator(square, previous and previous.gen, false)
        if not generator and full then
            generator = Post.findGenerator(square, nil, true)
            snap.scanH = now
        end
        if generator then
            local gs = generator:getSquare()
            snap.gen = { x = gs:getX(), y = gs:getY(), z = gs:getZ(), fuel = generator:getFuel(),
                rate = generator:getTotalPowerUsing() }
        end
    end
    snap.source = (snap.grid and "grid") or (snap.gen and "generator") or "none"
    return snap
end

--- Radio en état de recevoir la chaîne militaire (case chargée, état réel).
function Post.deviceReceives(object)
    local data = object:getDeviceData()
    if not data or not data:getIsTurnedOn() or data:getChannel() ~= Config.getChannel() then
        return false
    end
    if not data:canBePoweredHere() then
        return false
    end
    -- canBePoweredHere est toujours vrai sur pile (DeviceData.java:506-509).
    return not data:getIsBatteryPowered() or data:getPower() > 0
end

--- Réception d'après l'instantané (case déchargée) à l'heure now.
function Post.snapshotReceives(snap, now)
    if type(snap) ~= "table" or not snap.on or snap.channel ~= Config.getChannel() then
        return false
    end
    if snap.source == "battery" then
        return (tonumber(snap.power) or 0) > 0
    end
    if snap.grid and Post.gridExists() then
        return true
    end
    local gen = snap.gen
    if type(gen) == "table" then
        local elapsed = math.max(0, now - (tonumber(snap.h) or now))
        return (tonumber(gen.fuel) or 0) - (tonumber(gen.rate) or 0) * elapsed > 0
    end
    return false
end

-- ----------------------------------------------------------------------------
-- Journal
-- ----------------------------------------------------------------------------

local function logOf(teamId)
    local logs = state().postLogs
    local lines = logs[teamId]
    if not lines then
        lines = {}
        logs[teamId] = lines
    end
    return lines
end

local function push(lines, entry)
    lines[#lines + 1] = entry
    while #lines > Post.LOG_MAX do
        table.remove(lines, 1)
    end
end

--- Entrée système du journal (installed, moved, lost), traduite par le client.
local function addSystem(teamId, kind)
    push(logOf(teamId), { c = clockNow(), sys = kind })
end

local function addLine(teamId, text, clock)
    local lines = logOf(teamId)
    local last = lines[#lines]
    if last and last.t == text and math.abs(clock - (tonumber(last.c) or 0)) < Post.DEDUP_HOURS then
        return
    end
    push(lines, { c = clock, t = text })
end

local function addGap(teamId, text, clock)
    local lines = logOf(teamId)
    local last = lines[#lines]
    if last and last.gap then
        if last.lt == text and math.abs(clock - (tonumber(last.c2) or 0)) < Post.DEDUP_HOURS then
            return
        end
        last.gap = last.gap + 1
        last.c2 = clock
        last.lt = text
        return
    end
    push(lines, { c = clock, c2 = clock, gap = 1, lt = text })
end

-- ----------------------------------------------------------------------------
-- Installation et état du poste
-- ----------------------------------------------------------------------------

--- Données du poste envoyées aux membres (position seulement).
function Post.infoFor(teamId)
    local post = teamId and state().posts[teamId]
    if not post then
        return { none = true }
    end
    return { x = post.x, y = post.y, z = post.z }
end

--- Position du poste à tous les membres connectés de l'équipe.
function Post.notifyTeam(teamId)
    local info = Post.infoFor(teamId)
    for _, name in ipairs(Teams.members(teamId)) do
        local player = MilitaryDrop.Server.findPlayer(name)
        if player then
            Net.toPlayer(player, "PostInfo", info)
        end
    end
end

--- Le poste n'existe plus (radio ramassée, détruite, remplacée).
function Post.uninstall(teamId)
    local s = state()
    if not s.posts[teamId] then
        return
    end
    s.posts[teamId] = nil
    addSystem(teamId, "lost")
    MilitaryDrop.log("team " .. tostring(teamId) .. ": liaison post lost")
    Post.notifyTeam(teamId)
end

--- Poste de l'équipe : objet (case chargée) et "loaded", ou nil et "none",
--- "unloaded", "lost" (radio disparue : poste désinstallé).
function Post.locate(teamId)
    local post = teamId and state().posts[teamId]
    if not post then
        return nil, "none"
    end
    local object, loaded = findPostObject(post)
    if object then
        return object, "loaded"
    end
    if not loaded then
        return nil, "unloaded"
    end
    Post.uninstall(teamId)
    return nil, "lost"
end

--- Revérifie le poste de l'équipe et rafraîchit son instantané s'il est chargé.
function Post.refresh(teamId)
    local object, where = Post.locate(teamId)
    if object then
        local post = state().posts[teamId]
        post.snapshot = Post.snapshot(object, post.snapshot)
    end
    return object, where
end

--- Le poste de l'équipe reçoit la chaîne militaire en ce moment.
function Post.receives(teamId)
    local object, where = Post.refresh(teamId)
    if object then
        return Post.deviceReceives(object)
    end
    if where == "unloaded" then
        return Post.snapshotReceives(state().posts[teamId].snapshot, hoursNow())
    end
    return false
end

--- Ligne de la base pour l'équipe teamId, ou pour toutes les stations (nil) :
--- au journal de chaque équipe dont le poste la reçoit, sinon « aucune réception ».
function Post.record(teamId, text)
    text = shortText(text)
    if not text or text == "" then
        return
    end
    local s = state()
    local teams = {}
    if teamId == nil then
        -- Équipes qui ont un poste, et celles qui en ont eu un (le trou est marqué).
        for _, id in ipairs(sortedKeys(s.posts)) do
            teams[#teams + 1] = id
        end
        for _, id in ipairs(sortedKeys(s.postLogs)) do
            if not s.posts[id] then
                teams[#teams + 1] = id
            end
        end
    elseif s.posts[teamId] or s.postLogs[teamId] then
        teams[1] = teamId
    end
    local clock = clockNow()
    for _, id in ipairs(teams) do
        if Post.receives(id) then
            addLine(id, text, clock)
        else
            addGap(id, text, clock)
        end
    end
end

--- Revérifie tous les postes chargés (chaque minute de jeu).
function Post.refreshAll()
    for _, teamId in ipairs(sortedKeys(state().posts)) do
        Post.refresh(teamId)
    end
end

--- Fin du chargement d'un chunk : revérifie les postes qui s'y trouvent.
function Post.onLoadChunk(chunk)
    local s = state()
    local cell = getCell()
    local found = {}
    for teamId, post in pairs(s.posts) do
        local square = cell:getGridSquare(post.x, post.y, post.z)
        if square and square:getChunk() == chunk then
            found[#found + 1] = teamId
        end
    end
    table.sort(found)
    for _, teamId in ipairs(found) do
        Post.refresh(teamId)
    end
end

-- ----------------------------------------------------------------------------
-- Console : données envoyées aux seuls membres
-- ----------------------------------------------------------------------------

--- Missions en cours et progression du personnage (module des missions).
function Post.missions(characterId)
    local Missions = MilitaryDrop.Missions
    if type(Missions) ~= "table" or type(Missions.listForCharacter) ~= "function" then
        return {}
    end
    local list = Missions.listForCharacter(characterId)
    local out = {}
    if type(list) ~= "table" then
        return out
    end
    local now = hoursNow()
    for _, mission in ipairs(list) do
        if type(mission) == "table" and #out < Post.MISSION_MAX then
            -- deadline : échéance absolue (getWorldAgeHours), recalculée à l'envoi ;
            -- à défaut deadlineHours, heures restantes au moment de la liste.
            local deadline = tonumber(mission.deadline)
            local remaining = deadline and deadline - now or tonumber(mission.deadlineHours)
            out[#out + 1] = {
                kind = shortText(mission.kind),
                title = shortText(mission.title),
                text = shortText(mission.text),
                remaining = remaining and math.max(0, remaining) or nil,
                progress = tonumber(mission.progress),
                quota = tonumber(mission.quota),
                -- Nettoyage : horde apparue, reste à abattre avant la
                -- clôture, morts de la horde et objectif (barre).
                spotted = type(mission.spotted) == "boolean" and mission.spotted or nil,
                left = tonumber(mission.left),
                down = tonumber(mission.down),
                target = tonumber(mission.target),
                -- Durée totale (barre de temps) et grille annoncée à toutes les
                -- stations (déjà publique) : seulement pour la console.
                hours = tonumber(mission.hours),
                x = tonumber(mission.x) and math.floor(mission.x) or nil,
                y = tonumber(mission.y) and math.floor(mission.y) or nil,
            }
        end
    end
    return out
end

--- Boîte à courrier de l'équipe. Les entrées sans identifiant (plaques
--- numérotées du mod, essais v1.3) sont retirées.
local function mailOf(teamId)
    local mail = state().postMail
    local list = mail[teamId]
    if type(list) ~= "table" then
        list = {}
        mail[teamId] = list
    end
    local valid = true
    for _, entry in ipairs(list) do
        if type(entry) ~= "table" or type(entry.id) ~= "string" then
            valid = false
            break
        end
    end
    if not valid then
        local kept = {}
        for _, entry in ipairs(list) do
            if type(entry) == "table" and type(entry.id) == "string" then
                kept[#kept + 1] = entry
            end
        end
        list = kept
        mail[teamId] = list
    end
    return list
end

--- Tout ce qu'affiche la console du poste de l'équipe (object : radio chargée).
function Post.consoleData(teamId, object, player)
    local characterId = MilitaryDrop.Trust.idFor(player)
    local post = state().posts[teamId]
    post.snapshot = Post.snapshot(object, post.snapshot)
    local data = object:getDeviceData()
    local lines = {}
    local log = logOf(teamId)
    for i = math.max(1, #log - Post.LOG_SEND_MAX + 1), #log do
        local entry = log[i]
        lines[#lines + 1] = { c = entry.c, c2 = entry.c2, t = entry.t, gap = entry.gap, sys = entry.sys }
    end
    local mail = {}
    for i, entry in ipairs(mailOf(teamId)) do
        mail[i] = { id = entry.id, name = entry.name, by = entry.by }
    end
    local Trust = MilitaryDrop.Trust
    return {
        x = post.x, y = post.y, z = post.z,
        callsign = Teams.callsign(teamId),
        channel = data:getChannel(),
        on = data:getIsTurnedOn() == true,
        power = post.snapshot.source,
        -- Charge de la pile (0 à 1), poste sur pile seulement.
        battery = post.snapshot.source == "battery" and tonumber(post.snapshot.power) or nil,
        -- Confiance du personnage qui consulte ce poste partagé.
        tier = Trust.tier(characterId),
        lineCut = Trust.isLineCut(characterId),
        lines = lines,
        missions = Post.missions(characterId),
        mail = mail,
    }
end

--- Données de la console envoyées au joueur, avec son nom : en écran
--- partagé, seule sa console les applique.
function Post.sendConsole(player, teamId, object)
    local data = Post.consoleData(teamId, object, player)
    data.username = tostring(player:getUsername())
    Net.toPlayer(player, "PostData", data)
end

-- ----------------------------------------------------------------------------
-- Commandes des clients
-- ----------------------------------------------------------------------------

--- Réponse à une commande ; username : le client fait parler ce joueur local
--- (écran partagé).
local function reply(player, status, extra)
    local args = extra or {}
    args.status = status
    args.username = tostring(player:getUsername())
    Net.toPlayer(player, "PostResult", args)
end

--- Radio désignée par le client, à portée, et poste de l'équipe du joueur :
--- teamId, objet ; sinon nil, nil, motif.
local function resolvePost(player, args)
    local object = Radio.resolve(player, args.radio)
    if not object then
        return nil, nil, "tooFar"
    end
    local teamId = Teams.idFor(player)
    if Post.isTeamPost(teamId, object) then
        return teamId, object
    end
    if Post.ownerOf(object) then
        return nil, nil, "otherTeam"
    end
    return nil, nil, "notPost"
end

--- « Installer le poste de liaison ».
function Post.install(player, args)
    local object = Radio.resolve(player, args.radio)
    if not object then
        return reply(player, "tooFar")
    end
    if not Post.isEligible(object) then
        return reply(player, "notEligible")
    end
    local teamId = Teams.idFor(player)
    local owner = Post.ownerOf(object)
    if owner == teamId then
        return reply(player, "already")
    end
    if owner then
        return reply(player, "otherTeam")
    end
    local s = state()
    local old = s.posts[teamId]
    if old then
        -- Déplacement : l'ancienne radio (si sa case est chargée) n'est plus le poste.
        local oldObject = findPostObject(old)
        if oldObject then
            oldObject:getModData()[Post.UID_KEY] = nil
            transmitModData(oldObject)
        end
    end
    s.nextPostUid = (tonumber(s.nextPostUid) or 0) + 1
    local uid = "L" .. s.nextPostUid
    object:getModData()[Post.UID_KEY] = uid
    transmitModData(object)
    local square = object:getSquare()
    local post = { x = square:getX(), y = square:getY(), z = square:getZ(), uid = uid }
    post.snapshot = Post.snapshot(object, nil)
    s.posts[teamId] = post
    local status = old and "moved" or "installed"
    addSystem(teamId, status)
    MilitaryDrop.log(string.format("team %s: liaison post %s at %d,%d,%d by %s", tostring(teamId), status,
        post.x, post.y, post.z, tostring(player:getUsername())))
    reply(player, status)
    Post.notifyTeam(teamId)
end

--- « Poste de liaison » : ouverture ou rafraîchissement de la console.
function Post.open(player, args)
    local teamId, object, reason = resolvePost(player, args)
    if not teamId then
        return reply(player, reason)
    end
    Post.sendConsole(player, teamId, object)
end

--- Dépôt de plaques dans la boîte à courrier : chaque plaque est retirée de
--- l'inventaire du joueur par le serveur (args.items : identifiants d'objets).
function Post.deposit(player, args)
    local teamId, object, reason = resolvePost(player, args)
    if not teamId then
        return reply(player, reason)
    end
    -- Plaques désactivées ou ligne coupée : rien n'entre dans la boîte (une
    -- plaque déposée n'en ressort pas).
    if not Exchange.isEnabled("dogtag") then
        return reply(player, "unavailable")
    end
    if MilitaryDrop.Trust.isLineCut(MilitaryDrop.Trust.idFor(player)) then
        return reply(player, "lineCut")
    end
    local ids = type(args.items) == "table" and args.items or {}
    local inventory = player:getInventory()
    local mail = mailOf(teamId)
    local name = tostring(player:getUsername())
    local clock = clockNow()
    local seen, count = {}, 0
    for i = 1, Post.DEPOSIT_MAX do
        local id = ids[i]
        if id == nil or #mail >= Post.MAIL_MAX then
            break
        end
        if isInteger(id) and not seen[id] then
            seen[id] = true
            local item = inventory:getItemWithIDRecursiv(id)
            local key = item and Exchange.isDogTag(item, player) and Exchange.dogTagId(item)
            -- Plaque portée ou accrochée : à retirer d'abord (sinon objet fantôme).
            if key and not player:isEquipped(item) and not player:isAttachedItem(item) then
                local container = item:getContainer()
                container:Remove(item)
                if isServer() then
                    sendRemoveItemFromContainer(container, item)
                end
                mail[#mail + 1] = { id = key, name = shortText(Exchange.dogTagLabel(item)), by = name, c = clock }
                count = count + 1
            end
        end
    end
    reply(player, count > 0 and "deposited" or "noTags", { count = count })
    Post.sendConsole(player, teamId, object)
end

--- « Transmettre le courrier » : toutes les plaques de la boîte, depuis le poste.
function Post.transmit(player, args)
    local teamId, object, reason = resolvePost(player, args)
    if not teamId then
        return reply(player, reason)
    end
    local s = state()
    local mail = mailOf(teamId)
    if #mail == 0 then
        return reply(player, "emptyMail")
    end
    local data = object:getDeviceData()
    if not data:getIsTurnedOn() or not data:canBePoweredHere()
        or (data:getIsBatteryPowered() and data:getPower() <= 0) then
        return reply(player, "radioOff")
    end
    -- Autre canal : pas de réponse, comme un appel de largage (fréquence non trahie).
    if data:getChannel() ~= Config.getChannel() then
        return reply(player, "noAnswer")
    end
    local Missions = MilitaryDrop.Missions
    if type(Missions) ~= "table" or type(Missions.creditDogTag) ~= "function" then
        return reply(player, "unavailable")
    end
    -- La boîte est remplacée avant les crédits (un crédit peut écrire au
    -- journal) ; une plaque refusée pour un motif passager y reste.
    local kept = {}
    s.postMail[teamId] = kept
    local accepted = 0
    local credited, known, held = {}, {}, false
    for _, entry in ipairs(mail) do
        local gain, why = Missions.creditDogTag(player, teamId, { id = entry.id, name = entry.name }, { fromPost = true })
        if gain ~= nil then
            accepted = accepted + 1
            credited[#credited + 1] = tostring(entry.name)
        elseif Post.KEEP_MAIL[why] then
            kept[#kept + 1] = entry
            if why == "dailyCap" or why == "full" then
                held = held or why
            end
        elseif why == "used" then
            known[#known + 1] = tostring(entry.name)
        end
    end
    -- Réponse de la base au journal du poste (noms cités).
    if type(Missions.dogTagReplyLines) == "function" then
        for _, line in ipairs(Missions.dogTagReplyLines(Teams.callsign(teamId) or "", credited, known, held)) do
            Post.record(teamId, line)
        end
    end
    MilitaryDrop.log(string.format("team %s: %d dog tag(s) transmitted from the post, %d credited, %d kept",
        tostring(teamId), #mail - #kept, accepted, #kept))
    if #kept == #mail then
        reply(player, "held", { count = #kept })
    else
        reply(player, "transmitted", { count = #mail - #kept, accepted = accepted })
    end
    Post.sendConsole(player, teamId, object)
end

--- État d'une radio pour le bouton « Poste de liaison » de la fenêtre radio
--- (client) : "own" (poste de l'équipe), "otherTeam" (poste d'une autre
--- équipe), "elsewhere" (l'équipe a son poste sur une autre radio), "none"
--- (pas de poste), "notEligible", "tooFar". Rien d'autre n'est révélé :
--- l'installation répondrait de même (PostInstall).
function Post.radioStatus(player, object)
    if not object then
        return "tooFar"
    end
    if not Post.isEligible(object) then
        return "notEligible"
    end
    local teamId = Teams.idFor(player)
    local owner = Post.ownerOf(object)
    if owner ~= nil and owner == teamId then
        return "own"
    elseif owner then
        return "otherTeam"
    elseif teamId and state().posts[teamId] then
        return "elsewhere"
    end
    return "none"
end

--- « PostQuery » : état de la radio désignée, renvoyé au joueur (PostStatus,
--- avec la référence reçue pour que le client le range).
function Post.query(player, args)
    local status = Post.radioStatus(player, Radio.resolve(player, args.radio))
    local radio = type(args.radio) == "table" and args.radio or nil
    Net.toPlayer(player, "PostStatus", { status = status, username = tostring(player:getUsername()),
        x = radio and tonumber(radio.x), y = radio and tonumber(radio.y), z = radio and tonumber(radio.z) })
end

--- Position du poste de l'équipe du joueur (arrivée en jeu).
function Post.sync(player)
    Net.toPlayer(player, "PostInfo", Post.infoFor(Teams.idFor(player)))
end

--- Commande soumise à sa propre cadence (clé : son nom) ; refusée : « busy ».
local function guarded(name, handler, intervalMs)
    return function(player, args)
        if MilitaryDrop.Guard.throttled(player, name, intervalMs) then
            return reply(player, "busy")
        end
        handler(player, args)
    end
end

local COMMANDS = MilitaryDrop.Server.COMMANDS
COMMANDS.PostInstall = guarded("PostInstall", Post.install, Post.COMMAND_INTERVAL_MS)
COMMANDS.PostOpen = guarded("PostOpen", Post.open, Post.COMMAND_INTERVAL_MS)
COMMANDS.PostDeposit = guarded("PostDeposit", Post.deposit, Post.COMMAND_INTERVAL_MS)
COMMANDS.PostTransmit = guarded("PostTransmit", Post.transmit, Post.TRANSMIT_INTERVAL_MS)
COMMANDS.PostSync = Post.sync
COMMANDS.PostQuery = guarded("PostQuery", Post.query, Post.COMMAND_INTERVAL_MS)

Events.EveryOneMinute.Add(Post.refreshAll)
Events.LoadChunk.Add(Post.onLoadChunk)

return Post
