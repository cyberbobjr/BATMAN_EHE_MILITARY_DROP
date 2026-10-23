-- MilitaryDrop.Net.players et Net.findPlayer (C07, QUAL-13) : liste unique des
-- joueurs du serveur, connectés en MP (getOnlinePlayers), locaux en solo
-- (getSpecificPlayer 0..getNumActivePlayers - 1, emplacements vides ignorés).

local T = {}

local function player(name, dead)
    return {
        getUsername = function() return name end,
        isDead = function() return dead == true end,
    }
end

local function arrayList(items)
    return {
        size = function() return #items end,
        get = function(_, i) return items[i + 1] end,
    }
end

function T.setup()
    isClient = function() return false end
    isServer = function() return false end
    ONLINE = {}
    LOCAL = {}
    getOnlinePlayers = function() return arrayList(ONLINE) end
    getNumActivePlayers = function() return 4 end
    getSpecificPlayer = function(i) return LOCAL[i] end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
end

local function names(list)
    local out = {}
    for i, p in ipairs(list) do
        out[i] = p:getUsername()
    end
    return table.concat(out, ",")
end

function T.solo_lists_local_players_without_empty_slots()
    LOCAL[0] = player("a")
    LOCAL[2] = player("c", true)
    local Net = MilitaryDrop.Net
    assertEq(names(Net.players()), "a,c", "emplacement 1 vide ignoré, mort gardé")
    assertEq(names(Net.players({ alive = true })), "a", "mort retiré avec alive")
    assertEq(Net.findPlayer("c"), LOCAL[2], "mort trouvé par son nom")
    assertEq(Net.findPlayer("x"), nil, "inconnu")
end

function T.server_lists_online_players_only()
    isServer = function() return true end
    LOCAL[0] = player("host")
    ONLINE = { player("alice"), player("bob", true) }
    local Net = MilitaryDrop.Net
    assertEq(names(Net.players()), "alice,bob", "joueurs en ligne, pas les locaux")
    assertEq(names(Net.players({ alive = true })), "alice", "vivants seulement")
    assertEq(Net.findPlayer("bob"), ONLINE[2], "trouvé en ligne")
    assertEq(Net.findPlayer("host"), nil, "joueur local ignoré sur un serveur")
end

function T.empty_server_gives_an_empty_list()
    isServer = function() return true end
    assertEq(#MilitaryDrop.Net.players(), 0, "aucun joueur (reconnexion en cours)")
    assertEq(MilitaryDrop.Net.findPlayer("alice"), nil, "aucun joueur")
end

return T
