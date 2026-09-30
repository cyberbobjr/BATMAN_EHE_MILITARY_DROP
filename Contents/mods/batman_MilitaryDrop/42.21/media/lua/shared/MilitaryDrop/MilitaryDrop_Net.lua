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

return Net
