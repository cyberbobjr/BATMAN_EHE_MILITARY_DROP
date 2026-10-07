-- ============================================================================
-- Military Drop — Fulton côté client : créneau de lâcher reçu de la base
-- (FULTON-06)
--
-- La réponse à « Demander un passage Fulton » porte fulton = { minutesLeft,
-- dailyLeft } (MilitaryDrop_Missions.lua, Missions.requestFulton). Le client
-- garde l'échéance dans sa propre heure de jeu, par joueur local (écran
-- partagé), pour griser le menu du kit et afficher le plafond restant. Ce n'est
-- qu'un aperçu : le serveur revérifie le créneau au lâcher.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Core"

local FultonClient = MilitaryDrop.FultonClient or {}
MilitaryDrop.FultonClient = FultonClient

-- playerNum → { expires (heures de jeu du client), dailyLeft }.
FultonClient.windows = FultonClient.windows or {}

local function hoursNow()
    return getGameTime():getWorldAgeHours()
end

--- Créneau ouvert ou rappelé par la base pour le joueur local playerNum.
function FultonClient.onWindow(playerNum, args)
    local minutes = type(args) == "table" and tonumber(args.minutesLeft)
    if not minutes or minutes <= 0 then
        return
    end
    FultonClient.windows[playerNum or 0] = {
        expires = hoursNow() + minutes / 60,
        dailyLeft = math.max(0, math.floor(tonumber(args.dailyLeft) or 0)),
    }
end

--- Créneau encore ouvert du joueur local, ou nil.
function FultonClient.window(playerNum)
    local key = playerNum or 0
    local window = FultonClient.windows[key]
    if window and hoursNow() < window.expires then
        return window
    end
    FultonClient.windows[key] = nil
    return nil
end

--- Minutes restantes du créneau (arrondies au supérieur), ou 0.
function FultonClient.minutesLeft(playerNum)
    local window = FultonClient.window(playerNum)
    if not window then
        return 0
    end
    return math.max(1, math.ceil((window.expires - hoursNow()) * 60 - 1e-6))
end

--- Oublie les créneaux (fin de session : ils ne valent que pour la partie en cours).
function FultonClient.reset()
    FultonClient.windows = {}
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(FultonClient.reset)
end

return FultonClient
