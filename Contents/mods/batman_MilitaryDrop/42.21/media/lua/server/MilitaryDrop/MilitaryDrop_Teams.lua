-- ============================================================================
-- Military Drop — équipes et indicatifs (serveur MP ou solo)
--
-- Équipe = faction vanilla, ou joueur seul sans faction. En solo (aucune
-- faction), une seule équipe SOLO_ID pour la partie : le nom d'un personnage
-- solo change à chaque nouveau personnage (IsoPlayer.updateUsername : prénom
-- + nom) ; les joueurs d'un écran partagé forment la même station.
-- La réputation est personnelle et n'est jamais stockée par ce module.
--
-- Une faction vanilla n'a pas d'identifiant stable (nom et propriétaire
-- modifiables, Faction.java:255-269) ni d'événement côté serveur : le serveur
-- sonde Faction.getFactions() toutes les 10 minutes de jeu et avant chaque
-- décision, et rattache chaque faction vivante à un identifiant mémorisé :
-- même propriétaire, sinon recouvrement majoritaire des membres (Jaccard
-- ≥ 0,5), sinon même nom s'il est unique, sinon nouvelle équipe. Membres réels
-- = {getOwner()} ∪ getPlayers() (getPlayers n'inclut pas le propriétaire).
--
-- Changer de faction ne modifie jamais la note, le plafond ou la suspension
-- d'un personnage. Les factions servent aux indicatifs et postes partagés.
--
-- Faction disparue : l'équipe n'est dissoute qu'après deux sondages sans elle,
-- espacés d'au moins MISSING_HOURS heure de jeu (Faction.getFactions() peut
-- être vide au premier sondage d'un serveur qui démarre). En attendant, ses
-- membres y restent.
--
-- État privé (MilitaryDrop.Secrets.privateState, jamais transmis aux clients) :
--   teams[teamId] = { callsign, name, owner, members = { nom = true },
--                     faction = bool, dissolved = bool, missingSince = heures }
--   teamPlayers[nom] = teamId (équipe actuelle de chaque joueur connu)
--   nextTeamId = compteur des équipes de faction ("F1", "F2"…)
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Core"
require "MilitaryDrop/MilitaryDrop_Secrets"

local Teams = {}
MilitaryDrop.Teams = Teams

Teams.SOLO_ID = "SOLO"
Teams.INDIVIDUAL_PREFIX = "P:"
Teams.FACTION_PREFIX = "F"
Teams.CALLSIGN_PREFIX = "Station "
Teams.CALLSIGN_MAX_NUMBER = 99
Teams.CALLSIGN_ATTEMPTS = 50
Teams.NATO = {
    "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliett",
    "Kilo", "Lima", "Mike", "November", "Oscar", "Papa", "Quebec", "Romeo", "Sierra", "Tango",
    "Uniform", "Victor", "Whiskey", "X-ray", "Yankee", "Zulu",
}
Teams.JACCARD_MIN = 0.5
-- Sondage « avant chaque décision » : au plus une fois par seconde réelle.
Teams.REFRESH_MS = 1000
-- Faction absente : dissoute si elle manque encore MISSING_HOURS après le
-- premier sondage qui ne l'a pas trouvée.
Teams.MISSING_HOURS = 1

local lastRefreshMs = nil

local function state()
    local s = MilitaryDrop.Secrets.privateState()
    s.teams = s.teams or {}
    s.teamPlayers = s.teamPlayers or {}
    return s
end

--- Solo : ni client ni serveur MP (pas de factions).
function Teams.isSolo()
    return not isServer() and not isClient()
end

--- Identifiant de l'équipe individuelle d'un joueur (MP).
function Teams.individualId(username)
    if Teams.isSolo() then
        return Teams.SOLO_ID
    end
    return Teams.INDIVIDUAL_PREFIX .. tostring(username)
end

local function usernameOf(player)
    if type(player) == "string" then
        return player
    end
    local name = player and player:getUsername()
    return name and tostring(name) or nil
end

local function sortedKeys(t)
    local keys = {}
    for key in pairs(t) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

-- ----------------------------------------------------------------------------
-- Indicatifs
-- ----------------------------------------------------------------------------

local function callsignTaken(s, callsign)
    for _, team in pairs(s.teams) do
        if team.callsign == callsign then
            return true
        end
    end
    return false
end

local function makeCallsign(wordIndex, number)
    return Teams.CALLSIGN_PREFIX .. Teams.NATO[wordIndex] .. "-" .. number
end

--- Indicatif unique tiré au hasard (« Station Kilo-7 »).
local function newCallsign(s)
    for _ = 1, Teams.CALLSIGN_ATTEMPTS do
        local callsign = makeCallsign(ZombRand(#Teams.NATO) + 1, ZombRand(Teams.CALLSIGN_MAX_NUMBER) + 1)
        if not callsignTaken(s, callsign) then
            return callsign
        end
    end
    -- Tirages malchanceux : premier indicatif libre, dans l'ordre.
    for number = 1, Teams.CALLSIGN_MAX_NUMBER do
        for wordIndex = 1, #Teams.NATO do
            local callsign = makeCallsign(wordIndex, number)
            if not callsignTaken(s, callsign) then
                return callsign
            end
        end
    end
    return Teams.CALLSIGN_PREFIX .. "#" .. (tonumber(s.nextTeamId) or 0)
end

-- ----------------------------------------------------------------------------
-- Équipes individuelles
-- ----------------------------------------------------------------------------

local function ensureIndividual(s, username)
    local teamId = Teams.individualId(username)
    local team = s.teams[teamId]
    if not team then
        local solo = teamId == Teams.SOLO_ID
        team = {
            callsign = newCallsign(s),
            name = solo and teamId or username,
            owner = solo and teamId or username,
            members = {},
            faction = false,
            dissolved = false,
        }
        s.teams[teamId] = team
    end
    team.members[username] = true
    return teamId, team
end

-- ----------------------------------------------------------------------------
-- Factions vivantes et rattachement
-- ----------------------------------------------------------------------------

--- Factions vanilla : { name, owner, members = { nom = true }, count } (MP seulement).
local function liveFactions()
    local list = {}
    if Teams.isSolo() or not Faction then
        return list
    end
    local factions = Faction.getFactions()
    for i = 0, factions:size() - 1 do
        local faction = factions:get(i)
        local owner = faction:getOwner()
        local members = {}
        local count = 0
        if owner then
            owner = tostring(owner)
            members[owner] = true
            count = 1
        end
        local players = faction:getPlayers()
        for j = 0, players:size() - 1 do
            local name = tostring(players:get(j))
            if not members[name] then
                members[name] = true
                count = count + 1
            end
        end
        if count > 0 then
            list[#list + 1] = { name = tostring(faction:getName()), owner = owner, members = members }
        end
    end
    return list
end

local function jaccard(a, b)
    local inter, union = 0, 0
    for name in pairs(a) do
        union = union + 1
        if b[name] then
            inter = inter + 1
        end
    end
    for name in pairs(b) do
        if not a[name] then
            union = union + 1
        end
    end
    if union == 0 then
        return 0
    end
    return inter / union
end

--- Rattache chaque faction vivante (index) à une équipe de faction existante.
local function matchFactions(s, live)
    local candidates = {}
    for _, teamId in ipairs(sortedKeys(s.teams)) do
        local team = s.teams[teamId]
        if team.faction and not team.dissolved then
            candidates[#candidates + 1] = teamId
        end
    end
    local assigned, taken = {}, {}
    local function assign(index, teamId)
        assigned[index] = teamId
        taken[teamId] = true
    end
    -- 1. Même propriétaire.
    for index, faction in ipairs(live) do
        for _, teamId in ipairs(candidates) do
            if not assigned[index] and not taken[teamId] and faction.owner and s.teams[teamId].owner == faction.owner then
                assign(index, teamId)
            end
        end
    end
    -- 2. Recouvrement majoritaire des membres, meilleurs couples d'abord.
    local pairsList = {}
    for index, faction in ipairs(live) do
        if not assigned[index] then
            for order, teamId in ipairs(candidates) do
                if not taken[teamId] then
                    local score = jaccard(faction.members, s.teams[teamId].members or {})
                    if score >= Teams.JACCARD_MIN then
                        pairsList[#pairsList + 1] = { index = index, teamId = teamId, score = score, order = order }
                    end
                end
            end
        end
    end
    table.sort(pairsList, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        if a.index ~= b.index then
            return a.index < b.index
        end
        return a.order < b.order
    end)
    for _, candidate in ipairs(pairsList) do
        if not assigned[candidate.index] and not taken[candidate.teamId] then
            assign(candidate.index, candidate.teamId)
        end
    end
    -- 3. Même nom, s'il est unique parmi les factions vivantes et les équipes restantes.
    local liveNames = {}
    for _, faction in ipairs(live) do
        liveNames[faction.name] = (liveNames[faction.name] or 0) + 1
    end
    for index, faction in ipairs(live) do
        if not assigned[index] and liveNames[faction.name] == 1 then
            local found, count = nil, 0
            for _, teamId in ipairs(candidates) do
                if not taken[teamId] and s.teams[teamId].name == faction.name then
                    found, count = teamId, count + 1
                end
            end
            if count == 1 then
                assign(index, found)
            end
        end
    end
    return assigned, taken, candidates
end

--- Relit les factions et met à jour équipes, membres et rattachements.
function Teams.refresh()
    if getTimestampMs then
        lastRefreshMs = getTimestampMs()
    end
    local s = state()
    if Teams.isSolo() then
        return
    end
    local live = liveFactions()
    local assigned, taken, candidates = matchFactions(s, live)

    -- Factions nouvelles : plus basse note des fondateurs (ancien rattachement).
    for index, faction in ipairs(live) do
        if not assigned[index] then
            s.nextTeamId = (tonumber(s.nextTeamId) or 0) + 1
            local teamId = Teams.FACTION_PREFIX .. s.nextTeamId
            s.teams[teamId] = {
                callsign = newCallsign(s),
                name = faction.name,
                owner = faction.owner,
                members = {},
                faction = true,
                dissolved = false,
            }
            assigned[index] = teamId
            MilitaryDrop.log("team " .. teamId .. " (" .. s.teams[teamId].callsign .. ") for faction " .. faction.name)
        end
    end

    -- Factions disparues : équipe dissoute au second sondage sans elle, au
    -- moins MISSING_HOURS plus tard ; d'ici là, ses membres y restent.
    local hours = getGameTime():getWorldAgeHours()
    local missing = {}
    for _, teamId in ipairs(candidates) do
        local team = s.teams[teamId]
        if taken[teamId] then
            team.missingSince = nil
        else
            local since = tonumber(team.missingSince)
            if not since or hours < since then
                team.missingSince = hours
                missing[#missing + 1] = teamId
            elseif hours - since < Teams.MISSING_HOURS then
                missing[#missing + 1] = teamId
            else
                team.dissolved = true
                team.missingSince = nil
                team.members = {}
                MilitaryDrop.log("team " .. teamId .. " dissolved (faction " .. tostring(team.name) .. " gone)")
            end
        end
    end

    -- Équipe actuelle de chaque membre d'une faction vivante.
    local current = {}
    for index, faction in ipairs(live) do
        local team = s.teams[assigned[index]]
        team.name = faction.name
        team.owner = faction.owner
        team.members = {}
        for name in pairs(faction.members) do
            team.members[name] = true
            current[name] = assigned[index]
        end
    end
    -- Faction absente depuis peu : ses membres (qui ne sont pas dans une
    -- faction vivante) n'en bougent pas encore.
    for _, teamId in ipairs(missing) do
        for _, name in ipairs(sortedKeys(s.teams[teamId].members or {})) do
            if current[name] == nil then
                current[name] = teamId
            end
        end
    end

    -- Départs (vers l'équipe individuelle) et arrivées (la note de la faction
    -- s'applique d'elle-même). Kahlua : relever d'abord, modifier ensuite.
    local moves = {}
    for name, teamId in pairs(s.teamPlayers) do
        local stillAlone = current[name] == nil and teamId == Teams.individualId(name)
        if current[name] ~= teamId and not stillAlone then
            moves[#moves + 1] = { name = name, from = teamId }
        end
    end
    for name, teamId in pairs(current) do
        if s.teamPlayers[name] == nil then
            moves[#moves + 1] = { name = name, to = teamId }
        end
    end
    for _, move in ipairs(moves) do
        local name = move.name
        local to = current[name]
        local fromTeam = move.from and s.teams[move.from]
        if not to then
            -- Hors de toute faction : équipe individuelle.
            local individual = ensureIndividual(s, name)
            if fromTeam and fromTeam.faction then
                MilitaryDrop.log(name .. " left team " .. move.from .. " for " .. individual)
            end
            s.teamPlayers[name] = individual
        else
            local individual = s.teams[Teams.individualId(name)]
            if individual then
                individual.members[name] = nil
            end
            s.teamPlayers[name] = to
        end
    end
end

local function refreshIfStale()
    local now = getTimestampMs and getTimestampMs()
    if not now or not lastRefreshMs or now - lastRefreshMs >= Teams.REFRESH_MS or now < lastRefreshMs then
        Teams.refresh()
    end
end

-- ----------------------------------------------------------------------------
-- API
-- ----------------------------------------------------------------------------

--- Équipe d'un joueur (IsoPlayer ou nom de compte) : créée ou rattachée.
function Teams.idFor(player)
    local username = usernameOf(player)
    if not username then
        return nil
    end
    local s = state()
    if Teams.isSolo() then
        local teamId = ensureIndividual(s, username)
        s.teamPlayers[username] = teamId
        return teamId
    end
    refreshIfStale()
    local teamId = s.teamPlayers[username]
    local team = teamId and s.teams[teamId]
    if team and team.members[username] then
        return teamId
    end
    teamId = ensureIndividual(s, username)
    s.teamPlayers[username] = teamId
    return teamId
end

--- Faction actuelle (hors stations individuelles et SOLO), ou nil.
function Teams.factionIdFor(player)
    local id = Teams.idFor(player)
    local team = id and state().teams[id]
    return team and team.faction and not team.dissolved and id or nil
end

--- Indicatif d'une équipe (« Station Kilo-7 »), ou nil.
function Teams.callsign(teamId)
    local team = teamId and state().teams[teamId]
    return team and team.callsign or nil
end

--- Noms des membres actuels (triés). En solo : les joueurs locaux.
function Teams.members(teamId)
    local s = state()
    if teamId == Teams.SOLO_ID and Teams.isSolo() then
        local names = {}
        for i = 0, getNumActivePlayers() - 1 do
            local player = getSpecificPlayer(i)
            if player then
                names[#names + 1] = tostring(player:getUsername())
            end
        end
        table.sort(names)
        return names
    end
    if not Teams.isSolo() then
        refreshIfStale()
    end
    local team = teamId and s.teams[teamId]
    return team and sortedKeys(team.members) or {}
end

function Teams.isMember(teamId, username)
    if teamId == nil or username == nil then
        return false
    end
    if Teams.isSolo() then
        return teamId == Teams.SOLO_ID
    end
    refreshIfStale()
    local team = state().teams[teamId]
    return team ~= nil and team.members[tostring(username)] == true
end

Events.EveryTenMinutes.Add(Teams.refresh)

return Teams
