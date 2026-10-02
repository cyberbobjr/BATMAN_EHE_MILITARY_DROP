-- MilitaryDrop_Teams : équipes (faction vanilla, joueur seul, solo), indicatifs,
-- rattachement d'une faction après renommage, changement de propriétaire ou
-- départ de membres, et mouvements de confiance (CONF-03).
--
-- Factions simulées comme l'API réelle (Faction.java, 42.21) :
-- Faction.getFactions() (ArrayList : size/get), f:getName(), f:getOwner(),
-- f:getPlayers() (ArrayList SANS le propriétaire), Faction.getPlayerFaction.

local T = {}

--- ArrayList Java simulée.
local function arrayList(values)
    return {
        size = function() return #values end,
        get = function(_, i) return values[i + 1] end,
    }
end

--- Faction simulée (players : membres hors propriétaire).
local function makeFaction(name, owner, players)
    local faction = { name = name, owner = owner, players = players }
    function faction.getName(self) return self.name end
    function faction.getOwner(self) return self.owner end
    function faction.getPlayers(self) return arrayList(self.players) end
    FACTIONS[#FACTIONS + 1] = faction
    return faction
end

local function removeFaction(faction)
    for i = #FACTIONS, 1, -1 do
        if FACTIONS[i] == faction then
            table.remove(FACTIONS, i)
        end
    end
end

function T.setup()
    SandboxVars = { MilitaryDrop = {} }
    isClient = function() return false end
    isServer = function() return true end
    STATE = {}
    WORLD_HOURS = 1000
    getGameTime = function() return { getWorldAgeHours = function() return WORLD_HOURS end } end
    NOW_MS = 0
    getTimestampMs = function() return NOW_MS end
    ZombRand = function() return 0 end
    FACTIONS = {}
    Faction = {
        getFactions = function() return arrayList(FACTIONS) end,
        getPlayerFaction = function(who)
            local name = type(who) == "string" and who or who:getUsername()
            for _, faction in ipairs(FACTIONS) do
                if faction.owner == name then
                    return faction
                end
                for _, player in ipairs(faction.players) do
                    if player == name then
                        return faction
                    end
                end
            end
            return nil
        end,
    }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    -- État privé (ModData au nom tiré de la graine, jamais transmise).
    PUBLIC = {}
    MilitaryDrop.Secrets = { privateState = function() return STATE end }
    MilitaryDrop.Server = {
        -- État public (lisible par les clients) : rien de la v1.3 n'y va.
        getState = function() return PUBLIC end,
        clock = function() return WORLD_HOURS end,
    }
    loadMod("server/MilitaryDrop/MilitaryDrop_Teams.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Trust.lua")
end

local Teams, Trust

--- Relit les factions (le serveur sonde au plus une fois par seconde réelle).
local function poll()
    NOW_MS = NOW_MS + 1000
    Teams = MilitaryDrop.Teams
    Trust = MilitaryDrop.Trust
end

--- Avance le temps de jeu, puis relit les factions.
local function pollLater(hours)
    WORLD_HOURS = WORLD_HOURS + hours
    poll()
    Teams.refresh()
end

local function setNote(teamId, value)
    MilitaryDrop.Trust.get(teamId)
    STATE.trust = STATE.trust or {}
    STATE.trust[teamId] = STATE.trust[teamId] or {}
    STATE.trust[teamId].value = value
end

function T.faction_members_are_the_owner_and_its_players()
    makeFaction("Rangers", "alice", { "bob" })
    poll()
    local team = Teams.idFor("alice")
    assertEq(Teams.idFor("bob"), team, "propriétaire et membre dans la même équipe")
    assertTrue(team ~= Teams.idFor("carol"), "joueur sans faction : autre équipe")
    assertEq(table.concat(Teams.members(team), ","), "alice,bob", "getPlayers n'inclut pas le propriétaire")
    assertTrue(Teams.isMember(team, "alice") and Teams.isMember(team, "bob"), "membres")
    assertTrue(not Teams.isMember(team, "carol"), "non-membre")
    assertEq(STATE.teams[team].faction, true, "équipe de faction")
end

function T.player_object_or_username_give_the_same_team()
    makeFaction("Rangers", "alice", {})
    poll()
    local player = { getUsername = function() return "alice" end }
    assertEq(Teams.idFor(player), Teams.idFor("alice"), "IsoPlayer ou nom de compte")
end

function T.callsigns_are_unique_nato_names()
    makeFaction("Rangers", "alice", {})
    makeFaction("Wolves", "bob", {})
    poll()
    local a, b, c = Teams.callsign(Teams.idFor("alice")), Teams.callsign(Teams.idFor("bob")),
        Teams.callsign(Teams.idFor("carol"))
    for _, callsign in ipairs({ a, b, c }) do
        assertTrue(callsign:find("^Station %u[%a%-]*%-%d+$") ~= nil, "format « Station Kilo-7 » : " .. callsign)
    end
    assertTrue(a ~= b and b ~= c and a ~= c, "indicatifs uniques")
    local before = a
    poll()
    assertEq(Teams.callsign(Teams.idFor("alice")), before, "indicatif conservé")
end

function T.renamed_faction_keeps_its_team()
    local faction = makeFaction("Rangers", "alice", { "bob" })
    poll()
    local team = Teams.idFor("alice")
    faction.name = "Night Rangers"
    poll()
    assertEq(Teams.idFor("bob"), team, "même équipe après renommage")
    assertEq(STATE.teams[team].name, "Night Rangers", "nom mis à jour")
end

function T.new_owner_is_matched_by_member_overlap()
    local faction = makeFaction("Rangers", "alice", { "bob", "carol" })
    poll()
    local team = Teams.idFor("alice")
    -- Le propriétaire passe la main et la faction est renommée : seul le recouvrement reste.
    faction.name, faction.owner, faction.players = "Wolves", "bob", { "alice", "carol" }
    poll()
    assertEq(Teams.idFor("bob"), team, "Jaccard 1 : même équipe")
    assertEq(STATE.teams[team].owner, "bob", "propriétaire mis à jour")
end

function T.majority_overlap_is_half_or_more()
    local faction = makeFaction("Rangers", "alice", { "bob", "dave" })
    poll()
    local team = Teams.idFor("alice")
    -- Anciens {alice, bob, dave}, nouveaux {carol, alice, bob} : 2 / 4 = 0,5.
    faction.name, faction.owner, faction.players = "Wolves", "carol", { "alice", "bob" }
    poll()
    assertEq(Teams.idFor("carol"), team, "recouvrement de 0,5 : rattachée")
end

function T.members_leaving_keep_the_team_with_the_owner()
    local faction = makeFaction("Rangers", "alice", { "bob", "carol", "dave" })
    poll()
    local team = Teams.idFor("alice")
    faction.players = { "dave" }
    poll()
    assertEq(Teams.idFor("alice"), team, "même propriétaire")
    assertEq(Teams.idFor("dave"), team, "membre resté")
    assertTrue(Teams.idFor("bob") ~= team, "membre parti : équipe individuelle")
    assertTrue(not Teams.isMember(team, "bob"), "plus membre")
end

function T.unique_name_is_the_last_resort()
    local faction = makeFaction("Rangers", "alice", { "bob" })
    poll()
    local team = Teams.idFor("alice")
    faction.owner, faction.players = "erin", { "frank" }
    poll()
    assertEq(Teams.idFor("erin"), team, "même nom, unique : rattachée")
end

function T.duplicate_names_do_not_match_by_name()
    local faction = makeFaction("Rangers", "alice", { "bob" })
    poll()
    local team = Teams.idFor("alice")
    faction.owner, faction.players = "erin", { "frank" }
    makeFaction("Rangers", "gina", {})
    poll()
    assertTrue(Teams.idFor("erin") ~= team, "nom porté par deux factions : pas de rattachement par le nom")
    pollLater(Teams.MISSING_HOURS)
    assertEq(STATE.teams[team].dissolved, true, "ancienne équipe dissoute (absente une heure)")
end



function T.dissolved_faction_sends_everyone_back_alone()
    local faction = makeFaction("Rangers", "alice", { "bob" })
    poll()
    local team = Teams.idFor("alice")
    setNote(team, 90)
    removeFaction(faction)
    poll()
    assertEq(Teams.idFor("alice"), team, "premier sondage sans la faction : rien ne bouge")
    pollLater(Teams.MISSING_HOURS / 2)
    assertEq(Teams.idFor("bob"), team, "absente depuis moins d'une heure : toujours là")
    pollLater(Teams.MISSING_HOURS / 2)
    assertTrue(Teams.idFor("alice") ~= team and Teams.idFor("bob") ~= team, "membres rendus à eux-mêmes")
    assertEq(STATE.teams[team].dissolved, true, "équipe dissoute")
    assertEq(Trust.get(Teams.idFor("alice")), 25, "propriétaire : note plafonnée")
    assertEq(Trust.get(Teams.idFor("bob")), 25, "membre : note plafonnée")
    assertEq(#Teams.members(team), 0, "plus aucun membre")
end

function T.empty_faction_list_at_startup_keeps_the_teams()
    local faction = makeFaction("Rangers", "alice", { "bob" })
    poll()
    local team = Teams.idFor("alice")
    setNote(team, 90)
    -- Serveur qui démarre : Faction.getFactions() encore vide au premier sondage.
    removeFaction(faction)
    poll()
    assertEq(Teams.idFor("bob"), team, "membre gardé")
    assertEq(STATE.teams[team].dissolved, false, "pas dissoute")
    assertEq(Trust.get(Teams.idFor("alice")), 25, "aucune note plafonnée")
    FACTIONS[#FACTIONS + 1] = faction
    pollLater(1 / 6)
    assertEq(STATE.teams[team].missingSince, nil, "retrouvée : l'absence est oubliée")
    removeFaction(faction)
    pollLater(Teams.MISSING_HOURS * 0.9)
    pollLater(Teams.MISSING_HOURS * 0.5)
    assertEq(STATE.teams[team].dissolved, false, "absente de nouveau, mais depuis moins d'une heure")
    assertEq(Teams.idFor("alice"), team, "toujours membre")
    pollLater(Teams.MISSING_HOURS * 0.5)
    assertEq(STATE.teams[team].dissolved, true, "absente une heure : dissoute")
end



function T.unknown_founders_count_as_25()
    makeFaction("Rangers", "alice", {})
    poll()
    assertEq(Trust.get(Teams.idFor("alice")), 25, "départ à 25")
end

function T.no_refresh_more_than_once_per_second()
    local faction = makeFaction("Rangers", "alice", { "bob" })
    poll()
    local team = Teams.idFor("alice")
    faction.players = {}
    assertEq(Teams.idFor("bob"), team, "même seconde : dernier sondage")
    poll()
    assertTrue(Teams.idFor("bob") ~= team, "seconde suivante : départ constaté")
end

function T.periodic_poll_every_ten_minutes()
    local faction = makeFaction("Rangers", "alice", { "bob" })
    poll()
    local team = Teams.idFor("alice")
    faction.players = {}
    triggerEvent("EveryTenMinutes")
    assertTrue(STATE.teamPlayers.bob ~= team, "départ constaté par le sondage périodique")
    assertTrue(not Teams.isMember(team, "bob"), "plus membre")
end

function T.solo_is_one_team_for_the_whole_game()
    isServer = function() return false end
    makeFaction("Rangers", "alice", {})
    PLAYERS = { { getUsername = function() return "JohnDoe" end } }
    getNumActivePlayers = function() return #PLAYERS end
    getSpecificPlayer = function(i) return PLAYERS[i + 1] end
    poll()
    local team = Teams.idFor(PLAYERS[1])
    assertEq(team, Teams.SOLO_ID, "équipe de la partie")
    -- Nouveau personnage après une mort : autre nom (prénom + nom), même équipe.
    PLAYERS[1] = { getUsername = function() return "JaneRoe" end }
    assertEq(Teams.idFor(PLAYERS[1]), team, "même équipe")
    assertTrue(Teams.isMember(team, "JaneRoe"), "membre")
    assertEq(table.concat(Teams.members(team), ","), "JaneRoe", "joueurs locaux")
    assertTrue(Teams.callsign(team) ~= nil, "indicatif")
    assertTrue(STATE.teams.F1 == nil, "aucune faction lue en solo")
end

return T
