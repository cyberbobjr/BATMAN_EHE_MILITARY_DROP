-- Réputation personnelle persistante, indépendante du compte et de la faction.
-- L'identifiant est sauvegardé sur IsoPlayer ; la note reste dans l'état privé.
-- Ancienne table trust : conservée, sans transfert des notes collectives.
if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Core"
require "MilitaryDrop/MilitaryDrop_Secrets"
require "MilitaryDrop/MilitaryDrop_Net"
require "MilitaryDrop/MilitaryDrop_Teams"

local Config = MilitaryDrop.Config

local Trust = {}
MilitaryDrop.Trust = Trust

Trust.START = 25
-- Note « neutre » du délai entre largages (×1) : le départ, plus bas, l'allonge.
Trust.NEUTRAL = 50
Trust.MIN = 0
Trust.MAX = 100
Trust.LINE_CUT_BELOW = 15
Trust.DROP_RECOVERED = 10
Trust.DROP_RECOVERED_BY_FACTION = 5
Trust.DROP_TAKEN = -5
Trust.DROP_LOST = -10
-- Enregistreur de vol lu et transmis depuis le poste (SRC-08), hors plafond quotidien.
Trust.RECORDER = 10
Trust.FAILED_CODE_PENALTY = -2
Trust.FAILED_CODE_LIMIT = 3
Trust.FAILED_CODE_WINDOW_HOURS = 1
-- Paliers des réponses : <25, <50, <75, ≥75.
Trust.TIER_BOUNDS = { 25, 50, 75 }
Trust.FACTOR_AT_MIN = 1.5
Trust.FACTOR_AT_NEUTRAL = 1
Trust.FACTOR_AT_MAX = 0.6
Trust.EROSION_IDLE_HOURS = 24
-- Largages clos gardés pour la console, puis oubliés.
Trust.CLOSED_DROP_KEEP_HOURS = 168
Trust.ITEM_KEY = "MilitaryDrop_dropId"

Config.addDefaults({
    TrustDailyCap = 8,
    TrustPostBonus = 50,
    TrustLineCutDays = 3,
    TrustDropLostHours = 48,
    TrustErosion = false,
})

-- characterId → heures des codes faux récents ; pertes en attente du changement d'heure.
local failedCodes = {}
local lastCodePenalty = {}
local pendingPenalties = {}

local function state()
    local s = MilitaryDrop.Secrets.privateState()
    s.characterTrust = s.characterTrust or {}
    s.drops = s.drops or {}
    return s
end

local function hoursNow()
    return getGameTime():getWorldAgeHours()
end

--- Jour calendaire du jeu (une fois par jour).
local function currentDay()
    return math.floor(MilitaryDrop.Server.clock() / 24)
end

local function round(value)
    return math.floor(value + 0.5)
end

local function clamp(value)
    return math.max(Trust.MIN, math.min(Trust.MAX, value))
end

local function entry(characterId)
    local trust = state().characterTrust
    local e = trust[characterId]
    if not e then
        e = { value = Trust.START }
        trust[characterId] = e
    end
    return e
end

-- Only an opaque identity is stored on IsoPlayer. Scores remain server-private.
-- IsoPlayer.save/load persists ModData (SP and ServerPlayerDB in MP, B42.21).
Trust.CHARACTER_KEY = "MilitaryDrop_characterId"
local characterIds = setmetatable({}, { __mode = "k" })

function Trust.idFor(player)
    if not player or type(player) == "string" then
        return nil
    end
    local cached = characterIds[player]
    if cached then
        player:getModData()[Trust.CHARACTER_KEY] = cached
        return cached
    end
    local data = player:getModData()
    local id = data[Trust.CHARACTER_KEY]
    local username = tostring(player:getUsername())
    if type(id) ~= "string" or not id:match("^C:") then
        id = "C:" .. getRandomUUID()
        data[Trust.CHARACTER_KEY] = id
    end
    characterIds[player] = id
    local e = entry(id)
    e.username = username
    local desc = player:getDescriptor()
    e.name = desc and (tostring(desc:getForename()) .. " " .. tostring(desc:getSurname())) or username
    return id
end

-- The client keeps this identity in its copy of the character ModData too:
-- a vanilla transmitModData (e.g. favourites) must not erase it on the server.
function Trust.sync(player)
    local id = Trust.idFor(player)
    MilitaryDrop.Net.toPlayer(player, "CharacterIdentity", {
        id = id, username = tostring(player:getUsername()), index = player:getPlayerNum(),
    })
end

function Trust.name(characterId)
    local e = characterId and state().characterTrust[characterId]
    return e and e.name or ""
end

--- Ligne coupée encore active : heure de fin, ou nil.
local function activeLock(characterId)
    local e = characterId and state().characterTrust[characterId]
    local lockedUntil = e and tonumber(e.lockedUntil)
    if lockedUntil and hoursNow() < lockedUntil then
        return lockedUntil
    end
    return nil
end

-- ----------------------------------------------------------------------------
-- Lecture
-- ----------------------------------------------------------------------------

--- Note du personnage, 0 à 100 (Trust.START pour un personnage inconnu).
function Trust.get(characterId)
    local e = characterId and state().characterTrust[characterId]
    return e and tonumber(e.value) or Trust.START
end

function Trust.isLineCut(characterId)
    return activeLock(characterId) ~= nil
end

--- Palier de 1 (<25) à 4 (≥75) : choix des répliques, jamais de chiffre.
function Trust.tier(characterId)
    local value = Trust.get(characterId)
    for index, bound in ipairs(Trust.TIER_BOUNDS) do
        if value < bound then
            return index
        end
    end
    return #Trust.TIER_BOUNDS + 1
end

--- Facteur du délai global entre deux largages pour le personnage qui appelle.
function Trust.factor(characterId)
    local value = Trust.get(characterId)
    local span = Trust.NEUTRAL - Trust.MIN
    if value <= Trust.NEUTRAL then
        return Trust.FACTOR_AT_MIN + (Trust.FACTOR_AT_NEUTRAL - Trust.FACTOR_AT_MIN) * (value - Trust.MIN) / span
    end
    span = Trust.MAX - Trust.NEUTRAL
    return Trust.FACTOR_AT_NEUTRAL + (Trust.FACTOR_AT_MAX - Trust.FACTOR_AT_NEUTRAL) * (value - Trust.NEUTRAL) / span
end

-- ----------------------------------------------------------------------------
-- Gains et pertes
-- ----------------------------------------------------------------------------

--- Échange avec la base (érosion : dernier contact).
function Trust.touch(characterId)
    if characterId then
        entry(characterId).lastCallHours = hoursNow()
    end
end

local function cutLine(characterId, e)
    local days = math.max(0, tonumber(Config.get("TrustLineCutDays")) or 0)
    if days <= 0 then
        return
    end
    e.lockedUntil = hoursNow() + days * 24
    MilitaryDrop.log("character " .. tostring(characterId) .. ": trust " .. e.value .. ", line cut for " .. days .. " days", true)
end

--- Ajoute amount à la note (négatif : perte). source "drop" ou "recorder" : hors plafond ;
--- "code" : perte ; autres sources : gains plafonnés par jour, opts.fromPost
--- applique le bonus du poste. Renvoie la variation réellement appliquée.
function Trust.add(characterId, amount, source, opts)
    amount = tonumber(amount)
    if not characterId or not amount then
        return 0
    end
    amount = amount >= 0 and round(amount) or -round(-amount)
    if amount == 0 then
        return 0
    end
    local e = entry(characterId)
    local capped = amount > 0 and source ~= "drop" and source ~= "recorder"
    if capped then
        if type(opts) == "table" and opts.fromPost then
            local bonus = math.max(0, tonumber(Config.get("TrustPostBonus")) or 0)
            amount = amount + round(amount * bonus / 100)
        end
        local day = currentDay()
        if e.day ~= day then
            e.day = day
            e.dayGain = 0
        end
        local cap = math.max(0, math.floor(tonumber(Config.get("TrustDailyCap")) or 0))
        amount = math.min(amount, math.max(0, cap - (tonumber(e.dayGain) or 0)))
    end
    if source ~= "drop" and source ~= "code" then
        e.lastCallHours = hoursNow()
    end
    local old = tonumber(e.value) or Trust.START
    e.value = clamp(old + amount)
    local applied = e.value - old
    if capped then
        e.dayGain = (tonumber(e.dayGain) or 0) + applied
    end
    if applied < 0 and e.value < Trust.LINE_CUT_BELOW and not Trust.isLineCut(characterId) then
        cutLine(characterId, e)
    end
    if applied ~= 0 then
        MilitaryDrop.log(string.format("character %s: trust %d -> %d (%s)",
            tostring(characterId), old, e.value, tostring(source)))
    end
    return applied
end

-- ----------------------------------------------------------------------------
-- Largages
-- ----------------------------------------------------------------------------

--- Nouveau largage : identifiant, personnage du demandeur au moment de l'appel.
--- Un largage admin (forced) n'a pas d'effet sur la confiance, ni un largage
--- hors suivi (opts.untracked : leurre, LEURRE-04). opts.order et opts.decoy :
--- commande du formulaire de réquisition (MilitaryDrop_Requisition.lua).
function Trust.registerDrop(characterId, requester, forced, opts)
    opts = type(opts) == "table" and opts or {}
    local s = state()
    s.nextDropId = (tonumber(s.nextDropId) or 0) + 1
    local dropId = "D" .. s.nextDropId
    s.drops[dropId] = {
        character = not forced and not opts.untracked and characterId or nil,
        recoveryFaction = opts.recoveryFaction,
        requester = requester,
        forced = forced == true,
        requestedHours = hoursNow(),
        order = opts.order,
        decoy = opts.decoy,
    }
    return dropId
end

--- Dossier privé d'un largage (lecture : Crate.contentsFor, Server), ou nil.
function Trust.drop(dropId)
    return dropId and state().drops[dropId] or nil
end

--- Caisse posée : l'échéance du largage court. placed (facultatif) : { x, y,
--- cases } — case de la caisse (ou du repli au sol) et nombre d'objets
--- marqués du dropId posés (Server.deliver), suivis par Server.pollCollected.
--- Fournitures d'une épave (crash) : le dossier peut de nouveau être oublié.
function Trust.onDropDelivered(dropId, placed)
    local drop = dropId and state().drops[dropId]
    if not drop then
        return
    end
    drop.suppliesPending = nil
    if drop.deliveredHours then
        return
    end
    local hours = hoursNow()
    drop.deliveredHours = hours
    drop.deadline = hours + math.max(1, tonumber(Config.get("TrustDropLostHours")) or 48)
    if type(placed) == "table" and (tonumber(placed.cases) or 0) > 0 then
        drop.placed = { x = placed.x, y = placed.y, cases = placed.cases }
    end
end

--- Contenu de la caisse pris (au moins un objet marqué retiré du coffre ou
--- du sol, ou caisse disparue : Server.pollCollected) : la base cesse de
--- rappeler la grille. Sans effet sur la confiance ni sur l'issue du largage
--- (CONF-04 : seule l'ouverture d'une caisse de ravitaillement compte).
function Trust.markCollected(dropId)
    local drop = dropId and state().drops[dropId]
    if not drop or drop.collectedHours then
        return false
    end
    drop.collectedHours = hoursNow()
    MilitaryDrop.log("drop " .. tostring(dropId) .. ": crate emptied, grid reminders stop")
    return true
end

--- Grille annoncée au passage de l'hélicoptère (MilitaryDrop_Flights.lua) :
--- point de départ des rappels de la base (Server.repeatGrids).
function Trust.onDropAnnounced(dropId, x, y)
    local drop = dropId and state().drops[dropId]
    if not drop or type(x) ~= "number" or type(y) ~= "number" then
        return
    end
    drop.x, drop.y = x, y
    drop.announcedHours = hoursNow()
    drop.repeats = 0
end

--- Largages annoncés dont aucune caisse n'a été ouverte (ni échus, ni
--- trouvés, ni vidés : Trust.markCollected) : { { id, drop } }, du plus
--- ancien au plus récent.
function Trust.announcedDrops()
    local list = {}
    for dropId, drop in pairs(state().drops) do
        if drop.announcedHours and not drop.outcome and not drop.collectedHours then
            list[#list + 1] = { id = dropId, drop = drop }
        end
    end
    table.sort(list, function(a, b)
        if a.drop.announcedHours ~= b.drop.announcedHours then
            return a.drop.announcedHours < b.drop.announcedHours
        end
        return a.id < b.id
    end)
    return list
end

--- Caisse trouvée sans caisse de ravitaillement ouverte : sirène d'un leurre
--- coupée, caisse démontée ou disparue (MilitaryDrop_Decoy.lua). Le largage est
--- clos comme une caisse ouverte (plus de rappel), sans effet sur la confiance :
--- seuls les leurres, hors suivi, passent par ici.
function Trust.markFound(dropId)
    local drop = dropId and state().drops[dropId]
    if not drop or drop.outcome or drop.character then
        return false
    end
    drop.outcome = "opened"
    drop.closedHours = hoursNow()
    return true
end

--- Panne de l'appareil : clôt le suivi, sans perte de confiance ni rappels de ravitaillement.
--- supplies : fournitures de l'épave à livrer (option CrashCrates) ; le
--- dossier (commande comprise, Requisition.orderOf) est gardé jusqu'à leur
--- livraison (Trust.onDropDelivered), même au-delà de CLOSED_DROP_KEEP_HOURS.
function Trust.onCrash(dropId, supplies)
    local drop = dropId and state().drops[dropId]
    if not drop or drop.outcome then return end
    drop.outcome = "crashed"
    drop.closedHours = hoursNow()
    drop.suppliesPending = supplies == true or nil
end

--- Marque une caisse de ravitaillement du largage dropId.
function Trust.tagItem(item, dropId)
    if item and dropId then
        item:getModData()[Trust.ITEM_KEY] = dropId
    end
end

--- Ouverture d'une caisse de ravitaillement (Recipe.openSupplyCase, serveur ou
--- solo). Seule la première caisse ouverte d'un largage compte.
function Trust.onCaseOpened(item, character)
    if not item or not character then
        return
    end
    local dropId = item:getModData()[Trust.ITEM_KEY]
    local drop = type(dropId) == "string" and state().drops[dropId]
    if not drop or drop.outcome then
        return
    end
    local username = tostring(character:getUsername())
    drop.openedBy = username
    drop.closedHours = hoursNow()
    if not drop.character then
        drop.outcome = "opened"
        return
    end
    -- Un membre de la faction de l'appel peut récupérer pour le demandeur.
    -- La note modifiée reste celle du personnage demandeur, jamais de la faction.
    if Trust.idFor(character) == drop.character then
        drop.outcome = "recovered"
        Trust.add(drop.character, Trust.DROP_RECOVERED, "drop")
    elseif drop.recoveryFaction and MilitaryDrop.Teams.isMember(drop.recoveryFaction, username) then
        drop.outcome = "recovered"
        Trust.add(drop.character, Trust.DROP_RECOVERED_BY_FACTION, "drop")
    else
        drop.outcome = "taken"
        Trust.add(drop.character, Trust.DROP_TAKEN, "drop")
    end
    MilitaryDrop.log("drop " .. dropId .. " " .. drop.outcome .. " by " .. username)
end

--- Largages échus (rien d'ouvert) et oubli des largages clos anciens.
function Trust.checkDrops(hours)
    hours = hours or hoursNow()
    local drops = state().drops
    local expired, forgotten = {}, {}
    for dropId, drop in pairs(drops) do
        if not drop.outcome and drop.deadline and hours >= drop.deadline then
            expired[#expired + 1] = dropId
        elseif drop.outcome and drop.closedHours and not drop.suppliesPending
            and hours - drop.closedHours > Trust.CLOSED_DROP_KEEP_HOURS then
            forgotten[#forgotten + 1] = dropId
        end
    end
    table.sort(expired)
    for _, dropId in ipairs(expired) do
        local drop = drops[dropId]
        drop.outcome = drop.character and "lost" or "expired"
        drop.closedHours = hours
        if drop.character then
            Trust.add(drop.character, Trust.DROP_LOST, "drop")
        end
        MilitaryDrop.log("drop " .. dropId .. " " .. drop.outcome)
    end
    for _, dropId in ipairs(forgotten) do
        drops[dropId] = nil
    end
end

-- ----------------------------------------------------------------------------
-- Codes faux répétés
-- ----------------------------------------------------------------------------

--- Code faux d'un joueur (Server.recordFailedCode) : compté pour son personnage.
function Trust.onFailedCode(player)
    local characterId = Trust.idFor(player)
    if not characterId then
        return
    end
    local hours = hoursNow()
    local recent = {}
    for _, at in ipairs(failedCodes[characterId] or {}) do
        if hours - at < Trust.FAILED_CODE_WINDOW_HOURS then
            recent[#recent + 1] = at
        end
    end
    recent[#recent + 1] = hours
    failedCodes[characterId] = recent
    local last = lastCodePenalty[characterId]
    if #recent >= Trust.FAILED_CODE_LIMIT and (not last or hours - last >= Trust.FAILED_CODE_WINDOW_HOURS) then
        lastCodePenalty[characterId] = hours
        failedCodes[characterId] = {}
        pendingPenalties[#pendingPenalties + 1] = characterId
    end
end

--- Applique les pertes des codes faux en attente (changement d'heure).
function Trust.flushPenalties()
    local teams = pendingPenalties
    pendingPenalties = {}
    for _, characterId in ipairs(teams) do
        Trust.add(characterId, Trust.FAILED_CODE_PENALTY, "code")
    end
end

-- ----------------------------------------------------------------------------
-- Érosion et tâche horaire
-- ----------------------------------------------------------------------------

--- Un point par jour vers la note de départ pour les personnages sans échange depuis 24 h.
function Trust.erode(hours)
    if not Config.get("TrustErosion") then
        return
    end
    hours = hours or hoursNow()
    local day = currentDay()
    local trust = state().characterTrust
    local idle = {}
    for characterId, e in pairs(trust) do
        if e.erodedDay ~= day and hours - (tonumber(e.lastCallHours) or 0) >= Trust.EROSION_IDLE_HOURS then
            idle[#idle + 1] = characterId
        end
    end
    for _, characterId in ipairs(idle) do
        local e = trust[characterId]
        e.erodedDay = day
        if e.value > Trust.START then
            e.value = e.value - 1
        elseif e.value < Trust.START then
            e.value = e.value + 1
        end
    end
end

function Trust.onEveryHour()
    local hours = hoursNow()
    Trust.flushPenalties()
    Trust.checkDrops(hours)
    Trust.erode(hours)
end

-- ----------------------------------------------------------------------------
-- Console (admin)
-- ----------------------------------------------------------------------------

--- Notes, personnages et largages ouverts dans la console du serveur.
function Trust.debugPrint()
    local s = state()
    local ids = {}
    for id in pairs(s.characterTrust) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    MilitaryDrop.log("---- character trust (" .. #ids .. ") ----", true)
    for _, id in ipairs(ids) do
        local e = s.characterTrust[id]
        local lock = activeLock(id)
        MilitaryDrop.log(string.format("%s %s [%s]: %d, tier %d, x%.2f, today +%d%s", id,
            tostring(e.name), tostring(e.username), Trust.get(id), Trust.tier(id), Trust.factor(id),
            tonumber(e.dayGain) or 0, lock and string.format(", line cut until %.1f h", lock) or ""), true)
    end
    for dropId, drop in pairs(s.drops) do
        if not drop.outcome then
            MilitaryDrop.log("drop " .. dropId .. ": character " .. tostring(drop.character)
                .. ", requester " .. tostring(drop.requester) .. ", deadline " .. tostring(drop.deadline), true)
        end
    end
end

Events.EveryHours.Add(Trust.onEveryHour)

return Trust
