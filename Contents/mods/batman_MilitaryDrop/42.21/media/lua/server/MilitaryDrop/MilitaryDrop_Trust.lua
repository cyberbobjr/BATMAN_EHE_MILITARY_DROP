-- ============================================================================
-- Military Drop — confiance de la base, par équipe (serveur MP ou solo)
--
-- Note de 0 à 100 (départ 50) par équipe (MilitaryDrop_Teams.lua). Rien n'est
-- affiché en chiffres au joueur : la base répond par palier (Trust.tier), un
-- admin lit les notes par MilitaryDrop.Trust.debugPrint() en console.
--
-- Gains et pertes :
--   * largages (source "drop", hors plafond) : première caisse ouverte par
--     l'équipe du demandeur +10 ; par une autre équipe d'abord −5 au
--     demandeur ; rien d'ouvert TrustDropLostHours après la pose −10 ;
--   * autres sources (rapports, plaques, missions…) : plafond quotidien commun
--     (TrustDailyCap), bonus du poste de liaison (opts.fromPost, TrustPostBonus
--     en %, arrondi, dans le plafond) ;
--   * code faux répété : 3 codes faux de l'équipe dans l'heure de jeu → −2, une
--     fois par heure. La perte est appliquée au changement d'heure suivant, pas
--     sur-le-champ : même privée, la note ne doit pas permettre de dater un
--     appel compté (principe, comme le silence des codes faux).
--   * érosion (TrustErosion, désactivée par défaut) : un point par jour vers 50
--     sans échange depuis 24 h.
-- Une perte qui laisse la note sous 15 coupe la ligne TrustLineCutDays jours de
-- jeu (Server.evaluate répond « lineCut » après un canal et un code justes).
-- Effet sur le délai global entre deux largages : Trust.factor (×1,5 à 0,
-- ×1 à 50, ×0,6 à 100, linéaire par morceaux).
--
-- État privé (MilitaryDrop.Secrets.privateState, jamais transmis aux clients) :
--   trust[teamId] = { value, lockedUntil (heures de jeu), day, dayGain,
--                     lastCallHours, erodedDay }
--   drops[dropId] = { team, requester, forced, requestedHours, deliveredHours,
--                     deadline, outcome, openedBy, closedHours }
--   nextDropId = compteur ("D1", "D2"…)
-- Chaque caisse de ravitaillement d'un largage porte son dropId en ModData
-- d'objet (Trust.ITEM_KEY). Compteur de codes faux : mémoire du serveur.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Core"
require "MilitaryDrop/MilitaryDrop_Secrets"
require "MilitaryDrop/MilitaryDrop_Teams"

local Config = MilitaryDrop.Config
local Teams = MilitaryDrop.Teams

local Trust = {}
MilitaryDrop.Trust = Trust

Trust.START = 50
Trust.MIN = 0
Trust.MAX = 100
Trust.LINE_CUT_BELOW = 15
-- Note emportée par un joueur qui quitte sa faction (ou dont la faction est dissoute).
Trust.LEAVE_CAP = 50
Trust.DROP_RECOVERED = 10
Trust.DROP_TAKEN = -5
Trust.DROP_LOST = -10
Trust.FAILED_CODE_PENALTY = -2
Trust.FAILED_CODE_LIMIT = 3
Trust.FAILED_CODE_WINDOW_HOURS = 1
-- Paliers des réponses : <25, <50, <75, ≥75.
Trust.TIER_BOUNDS = { 25, 50, 75 }
Trust.FACTOR_AT_MIN = 1.5
Trust.FACTOR_AT_START = 1
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

-- teamId → heures des codes faux récents ; pertes en attente du changement d'heure.
local failedCodes = {}
local lastCodePenalty = {}
local pendingPenalties = {}

local function state()
    local s = MilitaryDrop.Secrets.privateState()
    s.trust = s.trust or {}
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

local function entry(teamId)
    local trust = state().trust
    local e = trust[teamId]
    if not e then
        e = { value = Trust.START }
        trust[teamId] = e
    end
    return e
end

--- Ligne coupée encore active : heure de fin, ou nil.
local function activeLock(teamId)
    local e = teamId and state().trust[teamId]
    local lockedUntil = e and tonumber(e.lockedUntil)
    if lockedUntil and hoursNow() < lockedUntil then
        return lockedUntil
    end
    return nil
end

-- ----------------------------------------------------------------------------
-- Lecture
-- ----------------------------------------------------------------------------

--- Note de l'équipe, 0 à 100 (50 pour une équipe inconnue).
function Trust.get(teamId)
    local e = teamId and state().trust[teamId]
    return e and tonumber(e.value) or Trust.START
end

function Trust.isLineCut(teamId)
    return activeLock(teamId) ~= nil
end

--- Palier de 1 (<25) à 4 (≥75) : choix des répliques, jamais de chiffre.
function Trust.tier(teamId)
    local value = Trust.get(teamId)
    for index, bound in ipairs(Trust.TIER_BOUNDS) do
        if value < bound then
            return index
        end
    end
    return #Trust.TIER_BOUNDS + 1
end

--- Facteur du délai global entre deux largages pour l'équipe qui appelle.
function Trust.factor(teamId)
    local value = Trust.get(teamId)
    local span = Trust.START - Trust.MIN
    if value <= Trust.START then
        return Trust.FACTOR_AT_MIN + (Trust.FACTOR_AT_START - Trust.FACTOR_AT_MIN) * (value - Trust.MIN) / span
    end
    span = Trust.MAX - Trust.START
    return Trust.FACTOR_AT_START + (Trust.FACTOR_AT_MAX - Trust.FACTOR_AT_START) * (value - Trust.START) / span
end

-- ----------------------------------------------------------------------------
-- Gains et pertes
-- ----------------------------------------------------------------------------

--- Échange avec la base (érosion : dernier contact).
function Trust.touch(teamId)
    if teamId then
        entry(teamId).lastCallHours = hoursNow()
    end
end

local function cutLine(teamId, e)
    local days = math.max(0, tonumber(Config.get("TrustLineCutDays")) or 0)
    if days <= 0 then
        return
    end
    e.lockedUntil = hoursNow() + days * 24
    MilitaryDrop.log("team " .. tostring(teamId) .. ": trust " .. e.value .. ", line cut for " .. days .. " days", true)
end

--- Ajoute amount à la note (négatif : perte). source "drop" : hors plafond ;
--- "code" : perte ; autres sources : gains plafonnés par jour, opts.fromPost
--- applique le bonus du poste. Renvoie la variation réellement appliquée.
function Trust.add(teamId, amount, source, opts)
    amount = tonumber(amount)
    if not teamId or not amount then
        return 0
    end
    amount = amount >= 0 and round(amount) or -round(-amount)
    if amount == 0 then
        return 0
    end
    local e = entry(teamId)
    local capped = amount > 0 and source ~= "drop"
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
    if applied < 0 and e.value < Trust.LINE_CUT_BELOW and not Trust.isLineCut(teamId) then
        cutLine(teamId, e)
    end
    if applied ~= 0 then
        MilitaryDrop.log(string.format("team %s: trust %d -> %d (%s)", tostring(teamId), old, e.value, tostring(source)))
    end
    return applied
end

-- ----------------------------------------------------------------------------
-- Mouvements entre équipes (appelés par MilitaryDrop_Teams.lua)
-- ----------------------------------------------------------------------------

--- Fixe la note d'une équipe ; une ligne coupée transmise s'ajoute (la plus longue).
local function setNote(teamId, value, lockedUntil)
    local e = entry(teamId)
    e.value = clamp(round(value))
    if lockedUntil and lockedUntil > (tonumber(e.lockedUntil) or 0) then
        e.lockedUntil = lockedUntil
    end
end

--- Un joueur quitte fromTeamId pour son équipe individuelle : note plafonnée,
--- la ligne coupée le suit.
function Trust.leave(individualId, fromTeamId)
    setNote(individualId, math.min(Trust.get(fromTeamId), Trust.LEAVE_CAP), activeLock(fromTeamId))
end

--- Faction nouvelle : plus basse note des fondateurs. sources = { { teamId,
--- left } } : ancienne équipe de chaque fondateur (left : faction qu'il vient
--- de quitter, dont il n'emporte que la note plafonnée). Une ligne coupée
--- d'un fondateur suit la faction.
function Trust.founded(teamId, sources)
    local value, lockedUntil = nil, nil
    for _, source in ipairs(sources or {}) do
        local note = Trust.get(source.teamId)
        if source.left then
            note = math.min(note, Trust.LEAVE_CAP)
        end
        value = value and math.min(value, note) or note
        local lock = activeLock(source.teamId)
        if lock and (not lockedUntil or lock > lockedUntil) then
            lockedUntil = lock
        end
    end
    setNote(teamId, value or Trust.START, lockedUntil)
end

-- ----------------------------------------------------------------------------
-- Largages
-- ----------------------------------------------------------------------------

--- Nouveau largage : identifiant, équipe du demandeur au moment de l'appel.
--- Un largage admin (forced) n'a pas d'effet sur la confiance.
function Trust.registerDrop(teamId, requester, forced)
    local s = state()
    s.nextDropId = (tonumber(s.nextDropId) or 0) + 1
    local dropId = "D" .. s.nextDropId
    s.drops[dropId] = {
        team = not forced and teamId or nil,
        requester = requester,
        forced = forced == true,
        requestedHours = hoursNow(),
    }
    return dropId
end

--- Caisse posée : l'échéance du largage court.
function Trust.onDropDelivered(dropId)
    local drop = dropId and state().drops[dropId]
    if not drop or drop.deliveredHours then
        return
    end
    local hours = hoursNow()
    drop.deliveredHours = hours
    drop.deadline = hours + math.max(1, tonumber(Config.get("TrustDropLostHours")) or 48)
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
    if not drop.team then
        drop.outcome = "opened"
        return
    end
    if username == drop.requester or Teams.isMember(drop.team, username) then
        drop.outcome = "recovered"
        Trust.add(drop.team, Trust.DROP_RECOVERED, "drop")
    else
        drop.outcome = "taken"
        Trust.add(drop.team, Trust.DROP_TAKEN, "drop")
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
        elseif drop.outcome and drop.closedHours and hours - drop.closedHours > Trust.CLOSED_DROP_KEEP_HOURS then
            forgotten[#forgotten + 1] = dropId
        end
    end
    table.sort(expired)
    for _, dropId in ipairs(expired) do
        local drop = drops[dropId]
        drop.outcome = drop.team and "lost" or "expired"
        drop.closedHours = hours
        if drop.team then
            Trust.add(drop.team, Trust.DROP_LOST, "drop")
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

--- Code faux d'un joueur (Server.recordFailedCode) : compté pour son équipe.
function Trust.onFailedCode(username)
    local teamId = Teams.idFor(username)
    if not teamId then
        return
    end
    local hours = hoursNow()
    local recent = {}
    for _, at in ipairs(failedCodes[teamId] or {}) do
        if hours - at < Trust.FAILED_CODE_WINDOW_HOURS then
            recent[#recent + 1] = at
        end
    end
    recent[#recent + 1] = hours
    failedCodes[teamId] = recent
    local last = lastCodePenalty[teamId]
    if #recent >= Trust.FAILED_CODE_LIMIT and (not last or hours - last >= Trust.FAILED_CODE_WINDOW_HOURS) then
        lastCodePenalty[teamId] = hours
        failedCodes[teamId] = {}
        pendingPenalties[#pendingPenalties + 1] = teamId
    end
end

--- Applique les pertes des codes faux en attente (changement d'heure).
function Trust.flushPenalties()
    local teams = pendingPenalties
    pendingPenalties = {}
    for _, teamId in ipairs(teams) do
        Trust.add(teamId, Trust.FAILED_CODE_PENALTY, "code")
    end
end

-- ----------------------------------------------------------------------------
-- Érosion et tâche horaire
-- ----------------------------------------------------------------------------

--- Un point par jour vers 50 pour les équipes sans échange depuis 24 h.
function Trust.erode(hours)
    if not Config.get("TrustErosion") then
        return
    end
    hours = hours or hoursNow()
    local day = currentDay()
    local trust = state().trust
    local idle = {}
    for teamId, e in pairs(trust) do
        if e.erodedDay ~= day and hours - (tonumber(e.lastCallHours) or 0) >= Trust.EROSION_IDLE_HOURS then
            idle[#idle + 1] = teamId
        end
    end
    for _, teamId in ipairs(idle) do
        local e = trust[teamId]
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

--- Notes, équipes et largages ouverts dans la console du serveur.
function Trust.debugPrint()
    local s = state()
    Teams.refresh()
    local ids = {}
    for teamId in pairs(s.teams or {}) do
        ids[#ids + 1] = teamId
    end
    for teamId in pairs(s.trust) do
        if not (s.teams or {})[teamId] then
            ids[#ids + 1] = teamId
        end
    end
    table.sort(ids)
    MilitaryDrop.log("---- trust (" .. #ids .. " teams) ----", true)
    for _, teamId in ipairs(ids) do
        local team = (s.teams or {})[teamId] or {}
        local e = s.trust[teamId] or {}
        local lock = activeLock(teamId)
        MilitaryDrop.log(string.format("%s %s [%s]%s: %d, tier %d, x%.2f, today +%d%s | %s", teamId,
            tostring(team.callsign), tostring(team.name), team.dissolved and " (dissolved)" or "",
            Trust.get(teamId), Trust.tier(teamId), Trust.factor(teamId), tonumber(e.dayGain) or 0,
            lock and string.format(", line cut until %.1f h", lock) or "",
            table.concat(Teams.members(teamId), ", ")), true)
    end
    local open = {}
    for dropId, drop in pairs(s.drops) do
        if not drop.outcome then
            open[#open + 1] = dropId
        end
    end
    table.sort(open)
    for _, dropId in ipairs(open) do
        local drop = s.drops[dropId]
        MilitaryDrop.log(string.format("drop %s: team %s, requester %s, deadline %s", dropId, tostring(drop.team),
            tostring(drop.requester), drop.deadline and string.format("%.1f h", drop.deadline) or "not delivered"),
            true)
    end
end

Events.EveryHours.Add(Trust.onEveryHour)

return Trust
