-- ============================================================================
-- Military Drop — Fulton : menu du kit, confirmation et action de lâcher
-- (FULTON-07), client
--
-- Le kit se gonfle POSÉ AU SOL (décision de l'utilisateur du 2026-10-07, après
-- le premier essai en jeu : poser le kit dehors puis le remplir est le geste
-- naturel). Clic droit sur le kit au sol (dans le monde, ou dans la liste du sol
-- de la fenêtre d'inventaire) → « Gonfler et lâcher le Fulton ». Dans
-- l'inventaire, l'option reste visible mais grisée : « Posez le kit au sol,
-- dehors ». Autres motifs : créneau radio absent (MilitaryDrop_FultonClient.lua),
-- kit vide, pas d'hélium, case du kit couverte ou sous un arbre, orage, vent.
-- La confirmation, toujours affichée, liste les objets que la base exploitera
-- et ceux qu'elle ignorera, sans chiffre de confiance (règle du mod) ; elle
-- prévient en mots si le plafond du jour est atteint ou sera dépassé.
-- Après confirmation : le personnage marche jusqu'au kit (luautils.walkAdj), la
-- bouteille passe dans l'inventaire principal (action vanilla), puis l'action
-- chronométrée gonfle le ballon (bruit pour les zombies) et envoie FultonLaunch
-- au serveur, qui revérifie tout (MilitaryDrop_FultonServer.lua).
-- L'action n'a pas de complete() : en MP elle reste côté client, comme
-- MilitaryDrop.ExchangeAction.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Core"
require "MilitaryDrop/MilitaryDrop_Net"
require "MilitaryDrop/MilitaryDrop_Fulton"
require "MilitaryDrop/MilitaryDrop_Exchange"
require "MilitaryDrop/MilitaryDrop_FultonClient"
require "MilitaryDrop/MilitaryDrop_Client"
require "MilitaryDrop/MilitaryDrop_Radio"

local Fulton = MilitaryDrop.Fulton
local Exchange = MilitaryDrop.Exchange
local FultonClient = MilitaryDrop.FultonClient

local FultonMenu = {}
MilitaryDrop.FultonMenu = FultonMenu

-- Durée du gonflage (unités de maxTime, environ 48 par seconde réelle : 10 s).
FultonMenu.ACTION_TIME = 480
-- Bruit du gonflage pour les zombies (rayon, volume).
FultonMenu.NOISE_RADIUS = 15
FultonMenu.NOISE_VOLUME = 15
-- Noms affichés par liste dans la confirmation avant « et N autres ».
FultonMenu.NAMES_SHOWN = 6

--- Case du kit posé au sol, ou nil (kit dans un inventaire ou un conteneur).
function FultonMenu.kitSquare(kit)
    local object = kit and kit:getWorldItem()
    return object and object:getSquare() or nil
end

--- Motif (clé de traduction) qui empêche de lâcher ce kit, ou nil.
function FultonMenu.reason(player, kit)
    if not Fulton.isEnabled() then
        return "IGUI_MilitaryDrop_SourceDisabled"
    end
    local square = FultonMenu.kitSquare(kit)
    if not square then
        return "IGUI_MilitaryDrop_Fulton_PutOnGround"
    end
    if not FultonClient.window(player:getPlayerNum()) then
        return "IGUI_MilitaryDrop_Fulton_NoWindow"
    end
    if #Fulton.kitItems(kit) == 0 then
        return "IGUI_MilitaryDrop_Fulton_EmptyKit"
    end
    if not Fulton.findTank(player:getInventory(), true) then
        return "IGUI_MilitaryDrop_Fulton_NoHelium"
    end
    return Fulton.siteReason(square)
end

--- Le personnage est assez près du kit pour le gonfler (même règle que le serveur).
function FultonMenu.isNear(player, square)
    return square ~= nil and square:getZ() == math.floor(player:getZ())
        and math.abs(square:getX() - math.floor(player:getX())) <= Fulton.REACH
        and math.abs(square:getY() - math.floor(player:getY())) <= Fulton.REACH
end

--- Noms en liste, un par ligne, puis « et N autres » au-delà de NAMES_SHOWN.
local function nameLines(names)
    local lines = {}
    for i = 1, math.min(#names, FultonMenu.NAMES_SHOWN) do
        lines[#lines + 1] = "- " .. names[i]
    end
    if #names > FultonMenu.NAMES_SHOWN then
        lines[#lines + 1] = getText("IGUI_MilitaryDrop_Fulton_ConfirmMore", tostring(#names - FultonMenu.NAMES_SHOWN))
    end
    return table.concat(lines, "\n")
end

--- Texte de la confirmation (texte simple de ISModalDialog, lignes « \n ») :
--- objets exploités, ignorés, avertissement de plafond, sans chiffre.
function FultonMenu.confirmText(player, kit)
    local paid, unpaid = {}, {}
    local vaccine = Fulton.vaccineActive()
    for _, item in ipairs(Fulton.kitItems(kit)) do
        local list = Fulton.category(item, player, vaccine) and paid or unpaid
        list[#list + 1] = tostring(item:getDisplayName())
    end
    local parts = { getText("IGUI_MilitaryDrop_Fulton_Confirm") }
    if #paid > 0 then
        parts[#parts + 1] = getText("IGUI_MilitaryDrop_Fulton_ConfirmPaid") .. "\n" .. nameLines(paid)
    else
        parts[#parts + 1] = getText("IGUI_MilitaryDrop_Fulton_ConfirmNothing")
    end
    if #unpaid > 0 then
        parts[#parts + 1] = getText("IGUI_MilitaryDrop_Fulton_ConfirmUnpaid") .. "\n" .. nameLines(unpaid)
    end
    local window = FultonClient.window(player:getPlayerNum())
    if window and #paid > 0 then
        local capped = Fulton.evaluate(Fulton.kitItems(kit), player).capped
        if window.dailyLeft <= 0 and capped > 0 then
            parts[#parts + 1] = getText("IGUI_MilitaryDrop_Fulton_ConfirmCapReached")
        elseif capped > window.dailyLeft then
            parts[#parts + 1] = getText("IGUI_MilitaryDrop_Fulton_ConfirmCapPartial")
        end
    end
    return table.concat(parts, "\n\n")
end

if ISBaseTimedAction then
    --- Gonflage puis lâcher : côté client seulement (voir l'en-tête).
    local Action = ISBaseTimedAction:derive("MilitaryDrop.FultonLaunchAction")
    MilitaryDrop.FultonLaunchAction = Action

    function Action:isValid()
        return self.character:getInventory():contains(self.tank) and Fulton.tankHasHelium(self.tank)
            and FultonMenu.isNear(self.character, FultonMenu.kitSquare(self.kit))
            and FultonMenu.reason(self.character, self.kit) == nil
    end

    function Action:start()
        self:setActionAnim("Loot")
        self.character:SetVariable("LootPosition", "Low")
        local square = FultonMenu.kitSquare(self.kit)
        if square then
            self.character:faceLocation(square:getX(), square:getY())
        end
        if square and addSound then
            addSound(self.character, square:getX(), square:getY(), square:getZ(),
                FultonMenu.NOISE_RADIUS, FultonMenu.NOISE_VOLUME)
        end
    end

    function Action:perform()
        ISBaseTimedAction.perform(self)
        local square = FultonMenu.kitSquare(self.kit)
        if not square then
            return
        end
        MilitaryDrop.Net.toServer(self.character, "FultonLaunch", { kitId = self.kit:getID(), tankId = self.tank:getID(),
            x = square:getX(), y = square:getY(), z = square:getZ() })
    end

    function Action.new(_, character, kit, tank)
        local o = ISBaseTimedAction.new(Action, character)
        o.kit = kit
        o.tank = tank
        o.maxTime = FultonMenu.ACTION_TIME
        o.stopOnWalk = true
        o.stopOnRun = true
        o.stopOnAim = true
        return o
    end
end

--- Met en file : marche jusqu'au kit, bouteille dans l'inventaire principal,
--- puis le gonflage.
function FultonMenu.queueLaunch(player, kit)
    local tank = Fulton.findTank(player:getInventory(), true)
    local square = FultonMenu.kitSquare(kit)
    if not tank or not square then
        return false
    end
    if not luautils.walkAdj(player, square, true) then
        return false
    end
    ISInventoryPaneContextMenu.transferIfNeeded(player, tank)
    ISTimedActionQueue.add(MilitaryDrop.FultonLaunchAction.new(nil, player, kit, tank))
    return true
end

function FultonMenu.onConfirm(target, button)
    if button.internal ~= "YES" then
        return
    end
    local player = getSpecificPlayer(target.playerNum)
    if player and FultonMenu.reason(player, target.kit) == nil then
        FultonMenu.queueLaunch(player, target.kit)
    end
end

--- Ouvre la confirmation (manette comprise).
function FultonMenu.confirm(player, kit)
    local playerNum = player:getPlayerNum()
    local target = { playerNum = playerNum, kit = kit }
    local modal = ISModalDialog:new(0, 0, 420, 200, FultonMenu.confirmText(player, kit), true, target,
        FultonMenu.onConfirm, playerNum)
    modal:initialise()
    modal:addToUIManager()
    if JoypadState and JoypadState.players[playerNum + 1] then
        setJoypadFocus(playerNum, modal)
    end
    return modal
end

--- Option « Gonfler et lâcher le Fulton » pour ce kit, grisée avec le motif.
function FultonMenu.addOption(player, context, kit)
    local option = context:addOption(getText("IGUI_MilitaryDrop_Fulton_Launch"), player, FultonMenu.confirm, kit)
    local reason = FultonMenu.reason(player, kit)
    if reason then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:initialise()
        tooltip:setVisible(false)
        tooltip.description = getText(reason)
        option.toolTip = tooltip
    end
    return option
end

--- Fenêtre d'inventaire : kit de l'inventaire (option grisée, « posez-le au
--- sol ») ou kit de la liste du sol.
function FultonMenu.onFillContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end
    for _, entry in ipairs(items) do
        local item = entry
        if not instanceof(entry, "InventoryItem") then
            item = entry.items and entry.items[1]
        end
        if item and item:getFullType() == Fulton.KIT_TYPE then
            FultonMenu.addOption(player, context, item)
            return
        end
    end
end

--- Kit posé sur la case, ou nil.
local function kitOn(square)
    local objects = square and square:getWorldObjects()
    if not objects then
        return nil
    end
    for i = 0, objects:size() - 1 do
        local item = objects:get(i):getItem()
        if item and item:getFullType() == Fulton.KIT_TYPE then
            return item
        end
    end
    return nil
end

--- Clic droit dans le monde : premier kit posé sur les cases visées ou à une
--- case autour. Le jeu repère les objets au sol dans un rayon d'une case autour
--- de la souris (ISWorldObjectContextMenuLogic.handleGrabWorldItem, 42.21) : le
--- modèle d'un objet posé déborde souvent sur la case voisine de celle cliquée.
function FultonMenu.onFillWorldContextMenu(playerNum, context, worldObjects, test)
    if test then
        return
    end
    local player = getSpecificPlayer(playerNum)
    local cell = getCell()
    if not player or not cell then
        return
    end
    local seen = {}
    for _, object in ipairs(worldObjects) do
        local center = object and object:getSquare()
        if center then
            for dx = -1, 1 do
                for dy = -1, 1 do
                    local square = cell:getGridSquare(center:getX() + dx, center:getY() + dy, center:getZ())
                    if square and not seen[square] then
                        seen[square] = true
                        local kit = kitOn(square)
                        if kit then
                            FultonMenu.addOption(player, context, kit)
                            return
                        end
                    end
                end
            end
        end
    end
end

--- Radio militaire allumée tenue en main par le joueur, ou nil.
function FultonMenu.handRadio(player)
    local Radio = MilitaryDrop.Radio
    for _, item in ipairs({ player:getPrimaryHandItem(), player:getSecondaryHandItem() }) do
        if Radio and Radio.isInventoryRadio(item) and Radio.isMilitary(item) and item:getDeviceData():getIsTurnedOn() then
            return item
        end
    end
    return nil
end

--- Lignes de la base : par la radio militaire tenue en main (comme une réponse
--- d'échange, avec les mêmes délais), sinon en texte au-dessus du personnage.
local function showBaseLines(player, lines)
    local device = FultonMenu.handRadio(player)
    local Client = MilitaryDrop.Client
    local count = 0
    for _, line in ipairs(lines) do
        if type(line) == "table" then
            local text = Exchange.lineText(line)
            if device and Client and Client.radioSay and Client.later then
                local request = { playerNum = player:getPlayerNum(), device = device }
                Client.later(Exchange.REPLY_DELAY_MS + count * Exchange.LINE_DELAY_MS,
                    function() Client.radioSay(request, text) end)
            else
                HaloTextHelper.addText(player, text, "", 180, 220, 140)
            end
            count = count + 1
        end
    end
end

--- Résultat du serveur : lignes de la base (accusé de réception) par la radio
--- en main ou au-dessus du personnage, ou motif de refus dit par le personnage.
function FultonMenu.onResult(args)
    local player = nil
    for i = 0, getNumActivePlayers() - 1 do
        local candidate = getSpecificPlayer(i)
        if candidate and tostring(candidate:getUsername()) == tostring(args.username) then
            player = candidate
        end
    end
    player = player or getSpecificPlayer(0)
    if not player then
        return
    end
    if args.status ~= "ok" then
        local key = type(args.reason) == "string" and args.reason:sub(1, 18) == "IGUI_MilitaryDrop_" and args.reason
            or "IGUI_MilitaryDrop_CannotCall"
        player:Say(getText(key))
        return
    end
    FultonClient.windows[player:getPlayerNum()] = nil
    showBaseLines(player, type(args.lines) == "table" and args.lines or {})
end

if MilitaryDrop.Client and MilitaryDrop.Client.HANDLERS then
    MilitaryDrop.Client.HANDLERS.FultonResult = FultonMenu.onResult
end

Events.OnFillInventoryObjectContextMenu.Add(FultonMenu.onFillContextMenu)
Events.OnFillWorldObjectContextMenu.Add(FultonMenu.onFillWorldContextMenu)

return FultonMenu
