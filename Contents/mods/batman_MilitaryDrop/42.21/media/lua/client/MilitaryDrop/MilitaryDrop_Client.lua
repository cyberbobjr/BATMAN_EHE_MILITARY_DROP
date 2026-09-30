-- ============================================================================
-- Military Drop — interface client : appel radio et réponses de la base
--
-- Menu contextuel « Demander un largage » sur une radio militaire (objet
-- d'inventaire en main ou sur le dos, ou appareil posé à portée). Le client ne décide rien :
-- il demande le code si l'option l'exige, fait parler le personnage, envoie
-- la demande au serveur, puis affiche la réponse par la radio.
--
-- La fréquence militaire n'est jamais vérifiée ici : griser l'option sur une
-- mauvaise fréquence permettrait de la trouver en balayant les canaux.
-- ============================================================================

require "ISUI/ISTextBox"
require "MilitaryDrop/MilitaryDrop_Net"
require "MilitaryDrop/MilitaryDrop_Radio"
require "MilitaryDrop/MilitaryDrop_Heli"
require "MilitaryDrop/MilitaryDrop_Announce"

local Config = MilitaryDrop.Config
local Net = MilitaryDrop.Net
local Radio = MilitaryDrop.Radio

local Client = {}
MilitaryDrop.Client = Client

Client.CALL_COUNT = 5
Client.ACK_COUNT = 5
-- Délais réels (ms) : code après l'appel, réponse de la base, confirmation
-- après le largage (envoyé par le serveur au passage de l'hélicoptère).
Client.CODE_DELAY_MS = 2500
Client.REPLY_DELAY_MS = 5000
Client.DROPPED_DELAY_MS = 4000
Client.RADIO_COLOR = { r = 0.45, g = 0.85, b = 0.45 }

local pending = {}
local nextRequestId = 1

-- ----------------------------------------------------------------------------
-- Tâches différées (abonnement à OnTick seulement quand il y en a)
-- ----------------------------------------------------------------------------

local tasks = {}
local ticking = false

local function runTasks()
    local now = getTimestampMs()
    for i = #tasks, 1, -1 do
        local task = tasks[i]
        if now >= task.at then
            table.remove(tasks, i)
            task.fn()
        end
    end
    if #tasks == 0 then
        Events.OnTick.Remove(runTasks)
        ticking = false
    end
end

function Client.later(delayMs, fn)
    tasks[#tasks + 1] = { at = getTimestampMs() + delayMs, fn = fn }
    if not ticking then
        ticking = true
        Events.OnTick.Add(runTasks)
    end
end

-- ----------------------------------------------------------------------------
-- Paroles
-- ----------------------------------------------------------------------------

local function randomText(prefix, count)
    return getText(prefix .. (ZombRand(count) + 1))
end

--- La base répond par la radio ; si elle est éteinte ou perdue, par le
--- personnage (il répète ce qu'il a entendu).
function Client.radioSay(request, text)
    local player = getSpecificPlayer(request.playerNum)
    local device = request.device
    local data = device and device:getDeviceData()
    if data and data:getIsTurnedOn() and data:getDeviceVolume() > 0 then
        local color = Client.RADIO_COLOR
        device:AddDeviceText(text, color.r, color.g, color.b, nil, nil, -1)
    elseif player then
        player:Say(text)
    end
end

local function playerSay(request, text)
    local player = getSpecificPlayer(request.playerNum)
    if player then
        player:Say(text)
    end
end

-- ----------------------------------------------------------------------------
-- Demande
-- ----------------------------------------------------------------------------

--- Droit d'afficher le largage forcé (le serveur revérifie).
function Client.canForce(player)
    if isClient() then
        local role = player:getRole()
        return role ~= nil and role:hasCapability(Capability.MakeEventsAlarmGunshot)
    end
    return isDebugEnabled()
end

function Client.sendRequest(player, device, code, force)
    local requestId = nextRequestId
    nextRequestId = nextRequestId + 1
    local request = { playerNum = player:getPlayerNum(), device = device, force = force == true }
    pending[requestId] = request

    player:Say(randomText("IGUI_MilitaryDrop_Call_", Client.CALL_COUNT))
    local args = { requestId = requestId, radio = Radio.makeRef(device), force = force == true }
    if code then
        args.code = code
        Client.later(Client.CODE_DELAY_MS, function()
            playerSay(request, getText("IGUI_MilitaryDrop_CallCode", code))
        end)
    end
    Net.toServer(player, "Request", args)
end

local function onCodeEntered(_, button, player, device)
    if button.internal ~= "OK" then
        return
    end
    local code = button.parent.entry:getText()
    if code and code ~= "" then
        Client.sendRequest(player, device, code, false)
    end
end

function Client.onRequest(player, device, force)
    if force or not Config.get("RequireAuthCode") then
        Client.sendRequest(player, device, nil, force)
        return
    end
    local modal = ISTextBox:new(0, 0, 280, 180, getText("IGUI_MilitaryDrop_EnterCode"), "", nil,
        onCodeEntered, player:getPlayerNum(), player, device)
    modal:initialise()
    modal:addToUIManager()
end

-- ----------------------------------------------------------------------------
-- Réponses du serveur
-- ----------------------------------------------------------------------------

-- Mauvais canal ou mauvais code : même réponse du serveur (« noAnswer »).
local RADIO_REPLIES = {
    noAnswer = "IGUI_MilitaryDrop_NoAnswer",
    noSite = "IGUI_MilitaryDrop_NoSite",
}

local function onResult(request, args)
    local status = args.status
    if status == "accepted" then
        Client.later(Client.REPLY_DELAY_MS, function()
            Client.radioSay(request, randomText("IGUI_MilitaryDrop_Ack_", Client.ACK_COUNT))
        end)
    elseif RADIO_REPLIES[status] then
        Client.later(Client.REPLY_DELAY_MS, function()
            Client.radioSay(request, getText(RADIO_REPLIES[status]))
        end)
    elseif status == "cooldown" then
        playerSay(request, getText("IGUI_MilitaryDrop_Cooldown", tostring(args.hours or "?")))
    elseif status == "radioOff" then
        playerSay(request, getText("IGUI_MilitaryDrop_TurnOn"))
    else
        playerSay(request, getText("IGUI_MilitaryDrop_CannotCall"))
    end
end

local function onDropped(request, args)
    Client.later(Client.DROPPED_DELAY_MS, function()
        Client.radioSay(request, getText("IGUI_MilitaryDrop_Dropped", tostring(args.x), tostring(args.y)))
    end)
end

local FLIGHT_COMMANDS = {
    FlightStart = "onFlightStart",
    FlightSync = "onFlightSync",
    FlightEnd = "onFlightEnd",
}

function Client.onServerCommand(module, command, args)
    if module ~= Net.MODULE or type(args) ~= "table" then
        return
    end
    if FLIGHT_COMMANDS[command] then
        MilitaryDrop.Heli[FLIGHT_COMMANDS[command]](args)
        return
    end
    if command == "DropAnnounce" then
        MilitaryDrop.Announce.onDropAnnounce(args)
        return
    end
    local request = pending[args.requestId]
    if not request then
        return
    end
    if command == "Result" then
        onResult(request, args)
        -- Seul un largage admin attend encore un message (coordonnées privées) ;
        -- les autres les entendent sur la chaîne militaire.
        if args.status ~= "accepted" or not request.force then
            pending[args.requestId] = nil
        end
    elseif command == "Dropped" then
        onDropped(request, args)
        pending[args.requestId] = nil
    end
end

-- ----------------------------------------------------------------------------
-- Menus contextuels
-- ----------------------------------------------------------------------------

local function addTooltip(option, key)
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip:setVisible(false)
    tooltip.description = getText(key)
    option.toolTip = tooltip
end

--- Motif d'indisponibilité affichable sans révéler la fréquence, ou nil.
local function unavailableReason(player, device)
    if Radio.isInventoryRadio(device) then
        if not Radio.isCarried(player, device) then
            return "IGUI_MilitaryDrop_NotCarried"
        end
    elseif not Radio.isNear(player, device) then
        return "IGUI_MilitaryDrop_TooFar"
    end
    if not device:getDeviceData():getIsTurnedOn() then
        return "IGUI_MilitaryDrop_TurnOn"
    end
    return nil
end

function Client.addOptions(player, context, device)
    local reason = unavailableReason(player, device)
    local option = context:addOption(getText("IGUI_MilitaryDrop_RequestDrop"), player, Client.onRequest, device, false)
    if reason then
        option.notAvailable = true
        addTooltip(option, reason)
    else
        addTooltip(option, "IGUI_MilitaryDrop_RequestTooltip")
    end
    -- Largage admin : jamais grisé, le serveur n'exige pas la radio en main.
    if Client.canForce(player) then
        context:addOption(getText("IGUI_MilitaryDrop_RequestDropAdmin"), player, Client.onRequest, device, true)
    end
end

function Client.onFillInventoryContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end
    for _, entry in ipairs(items) do
        local item = entry
        if not instanceof(entry, "InventoryItem") then
            item = entry.items and entry.items[1]
        end
        if Radio.isInventoryRadio(item) and Radio.isMilitary(item) then
            Client.addOptions(player, context, item)
            return
        end
    end
end

function Client.onFillWorldContextMenu(playerNum, context, worldObjects, test)
    if test then
        return
    end
    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end
    local seen = {}
    for _, object in ipairs(worldObjects) do
        local square = object and object:getSquare()
        if square and not seen[square] then
            seen[square] = true
            local objects = square:getObjects()
            for i = 0, objects:size() - 1 do
                local candidate = objects:get(i)
                if Radio.isWorldRadio(candidate) and Radio.isMilitary(candidate) then
                    Client.addOptions(player, context, candidate)
                    return
                end
            end
        end
    end
end

--- MP : à l'arrivée en jeu, demande les vols déjà en cours (reconnexion).
function Client.onGameStart()
    local player = getSpecificPlayer(0)
    if isClient() and player then
        Net.toServer(player, "Sync", {})
    end
end

Events.OnGameStart.Add(Client.onGameStart)
Events.OnFillInventoryObjectContextMenu.Add(Client.onFillInventoryContextMenu)
Events.OnFillWorldObjectContextMenu.Add(Client.onFillWorldContextMenu)
Events.OnServerCommand.Add(Client.onServerCommand)

return Client
