-- ============================================================================
-- Military Drop — échanges client ↔ serveur
--
-- MP : sendClientCommand / sendServerCommand (module MilitaryDrop.Net.MODULE).
-- Solo : les deux côtés vivent dans le même Lua, et sendServerCommand n'y fait
-- rien (seulement si GameServer.server) : on appelle directement le
-- gestionnaire de l'autre côté.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Core"

local Net = {}
MilitaryDrop.Net = Net

Net.MODULE = "MilitaryDrop"

--- Client → serveur.
function Net.toServer(player, command, args)
    if isClient() then
        sendClientCommand(player, Net.MODULE, command, args or {})
    elseif MilitaryDrop.Server then
        MilitaryDrop.Server.onClientCommand(Net.MODULE, command, player, args or {})
    end
end

--- Serveur → un joueur.
function Net.toPlayer(player, command, args)
    if isServer() then
        sendServerCommand(player, Net.MODULE, command, args or {})
    elseif MilitaryDrop.Client then
        MilitaryDrop.Client.onServerCommand(Net.MODULE, command, args or {})
    end
end

--- Serveur → tous les joueurs connectés.
function Net.toAll(command, args)
    if isServer() then
        sendServerCommand(Net.MODULE, command, args or {})
    elseif MilitaryDrop.Client then
        MilitaryDrop.Client.onServerCommand(Net.MODULE, command, args or {})
    end
end

--- Joueurs du serveur : connectés (serveur MP) ou locaux (solo, client).
--- options.alive : seulement les joueurs vivants. Jamais de nil dans la liste.
function Net.players(options)
    local alive = options and options.alive
    local list = {}
    local function add(player)
        if player and not (alive and player:isDead()) then
            list[#list + 1] = player
        end
    end
    if isServer() then
        local players = getOnlinePlayers()
        for i = 0, players:size() - 1 do
            add(players:get(i))
        end
    else
        for i = 0, getNumActivePlayers() - 1 do
            add(getSpecificPlayer(i))
        end
    end
    return list
end

--- Joueur connecté (serveur MP) ou local (solo) par son nom, vivant ou mort ; nil sinon.
function Net.findPlayer(username)
    for _, player in ipairs(Net.players()) do
        if player:getUsername() == username then
            return player
        end
    end
    return nil
end

return Net
