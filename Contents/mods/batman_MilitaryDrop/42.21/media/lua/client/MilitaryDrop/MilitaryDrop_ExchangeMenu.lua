-- ============================================================================
-- Military Drop — échanges « Logistique » d'une radio militaire (client)
--
-- Plus inscrit au menu contextuel depuis le 2026-10-01 : la section
-- « Logistique » de la fenêtre radio (MilitaryDrop_RadioModule.lua) le
-- remplace et utilise ces options (Menu.OPTIONS), leurs raisons de grisé
-- (Menu.reason), leurs infobulles (Menu.tooltipText) et leur envoi
-- (Menu.onOption). Menu.addOptions et les fonctions onFill* restent, non
-- inscrites.
--
-- Sur une radio militaire (objet de l'inventaire, ou appareil posé) :
-- rapport de situation, transmission des plaques d'identité vanilla
-- renommées d'après leur porteur (MilitaryDrop.Exchange.isDogTag : pas celle
-- du personnage ; l'infobulle cite les noms),
-- confirmation de la reconnaissance, confirmation de réception (appel de
-- contrôle), « Faire le point » sur le nettoyage (horde abattue par la
-- station, reste ; sans gain). Le client ne décide rien : il grise une option
-- avec la raison visible (radio hors de l'inventaire ou trop loin, éteinte,
-- source désactivée sur le serveur, aucune plaque, aucun nettoyage en cours),
-- puis passe par MilitaryDrop.Exchange : prise en main d'une radio rangée si
-- besoin (jamais à la ceinture, AUTH-04), parole du personnage, commande au
-- serveur, réponse de la base
-- par la radio.
--
-- Comme pour l'appel de largage, la fréquence n'est jamais vérifiée ici, ni
-- l'existence d'une reconnaissance ou d'un appel de contrôle : le serveur
-- répond. Seul « Faire le point » est grisé sans nettoyage en cours : le
-- serveur l'annonce à tous (CleanupState { open }, à l'ouverture, à la
-- clôture et à l'arrivée d'un client MP par Sync) ; en solo, l'état du
-- serveur est lu directement (MilitaryDrop.Missions.openMission). Rien de la
-- horde n'est envoyé.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Radio"
require "MilitaryDrop/MilitaryDrop_Exchange"
require "MilitaryDrop/MilitaryDrop_Client"
require "MilitaryDrop/MilitaryDrop_FultonClient"

local Radio = MilitaryDrop.Radio
local Exchange = MilitaryDrop.Exchange

local Menu = {}
MilitaryDrop.ExchangeMenu = Menu

-- Options dans l'ordre du sous-menu. speech : préfixe des répliques du
-- personnage (1 à speechCount).
Menu.OPTIONS = {
    { source = "report", label = "IGUI_MilitaryDrop_Exchange_Report",
        tooltip = "IGUI_MilitaryDrop_Exchange_ReportTooltip", speech = "IGUI_MilitaryDrop_Say_Report_", speechCount = 3 },
    { source = "dogtag", label = "IGUI_MilitaryDrop_Exchange_DogTags",
        tooltip = "IGUI_MilitaryDrop_Exchange_DogTagsTooltip", speech = "IGUI_MilitaryDrop_Say_DogTags_", speechCount = 2 },
    { source = "recon", label = "IGUI_MilitaryDrop_Exchange_Recon",
        tooltip = "IGUI_MilitaryDrop_Exchange_ReconTooltip", speech = "IGUI_MilitaryDrop_Say_Recon_", speechCount = 2 },
    { source = "control", label = "IGUI_MilitaryDrop_Exchange_Control",
        tooltip = "IGUI_MilitaryDrop_Exchange_ControlTooltip", speech = "IGUI_MilitaryDrop_Say_Control_", speechCount = 2 },
    -- Passage Fulton (FULTON-06) : ouvre un créneau de lâcher (MilitaryDrop_FultonClient.lua).
    { source = "fulton", label = "IGUI_MilitaryDrop_Exchange_Fulton",
        tooltip = "IGUI_MilitaryDrop_Exchange_FultonTooltip", speech = "IGUI_MilitaryDrop_Say_Fulton_", speechCount = 2 },
    -- « Faire le point » : source « cleanup » (désactivée avec les nettoyages),
    -- commande propre, grisé sans nettoyage en cours.
    { source = "cleanup", command = "cleanupStatus", needsCleanup = true,
        label = "IGUI_MilitaryDrop_Exchange_CleanupStatus", tooltip = "IGUI_MilitaryDrop_Exchange_CleanupStatusTooltip",
        speech = "IGUI_MilitaryDrop_Say_CleanupStatus_", speechCount = 2 },
}

-- Nettoyage en cours d'après le serveur (CleanupState) : client MP.
Menu.cleanupState = { open = false }

--- CleanupState du serveur : { open }.
function Menu.onCleanupState(args)
    Menu.cleanupState.open = type(args) == "table" and args.open == true
end

--- Un nettoyage est en cours : solo, état du serveur lu directement ; client
--- MP, dernier CleanupState reçu.
function Menu.cleanupOpen()
    local Missions = MilitaryDrop.Missions
    if not isClient() and type(Missions) == "table" and type(Missions.openMission) == "function" then
        return Missions.openMission("cleanup") ~= nil
    end
    return Menu.cleanupState.open == true
end

--- Plaques transmissibles en un échange (sacs portés compris, hors objets
--- portés ou en main), comme le serveur les choisira.
function Menu.dogTags(player)
    return Exchange.findDogTags(player, Exchange.DOGTAGS_PER_CALL)
end

function Menu.dogTagCount(player)
    return #Menu.dogTags(player)
end

--- Infobulle de l'option : texte, puis noms des soldats.
function Menu.tooltipText(player, option)
    local text = getText(option.tooltip)
    if option.source ~= "dogtag" then
        return text
    end
    local names = {}
    for i, item in ipairs(Menu.dogTags(player)) do
        names[i] = Exchange.dogTagLabel(item)
    end
    if #names == 0 then
        return text
    end
    return text .. " <LINE> <LINE> " .. Exchange.namesText(names, 5)
end

--- Raison d'indisponibilité d'une option (clé de traduction), ou nil.
function Menu.reason(player, device, option)
    if not Exchange.isEnabled(option.source) then
        return "IGUI_MilitaryDrop_SourceDisabled"
    end
    if option.needsCleanup and not Menu.cleanupOpen() then
        return "IGUI_MilitaryDrop_NoCleanup"
    end
    local reason = Exchange.unavailableReason(player, device)
    if reason then
        return reason
    end
    if option.source == "dogtag" and Menu.dogTagCount(player) == 0 then
        return "IGUI_MilitaryDrop_NoDogTags"
    end
    return nil
end

--- Lance l'échange (aussi utilisé par le module « Logistique » de la fenêtre
--- radio, MilitaryDrop_RadioModule.lua) ; renvoie false si la radio n'est pas
--- utilisable.
function Menu.onOption(player, device, option)
    local speech = getText(option.speech .. (ZombRand(option.speechCount) + 1), tostring(Menu.dogTagCount(player)))
    return Exchange.send(player, device, Exchange.COMMANDS[option.command or option.source], {}, speech)
end

local function addTooltip(option, text)
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip:setVisible(false)
    tooltip.description = text
    option.toolTip = tooltip
end

--- Sous-menu « Logistique » (absent si toutes les sources sont désactivées).
function Menu.addOptions(player, context, device)
    local any = false
    for _, option in ipairs(Menu.OPTIONS) do
        any = any or Exchange.isEnabled(option.source)
    end
    if not any then
        return
    end
    local parent = context:addOption(getText("IGUI_MilitaryDrop_Logistics"))
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)
    for _, option in ipairs(Menu.OPTIONS) do
        local entry = sub:addOption(getText(option.label), player, Menu.onOption, device, option)
        local reason = Menu.reason(player, device, option)
        if reason then
            entry.notAvailable = true
            addTooltip(entry, getText(reason))
        else
            addTooltip(entry, Menu.tooltipText(player, option))
        end
    end
end

function Menu.onFillInventoryContextMenu(playerNum, context, items)
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
            Menu.addOptions(player, context, item)
            return
        end
    end
end

function Menu.onFillWorldContextMenu(playerNum, context, worldObjects, test)
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
                    Menu.addOptions(player, context, candidate)
                    return
                end
            end
        end
    end
end

if MilitaryDrop.Client and MilitaryDrop.Client.HANDLERS then
    MilitaryDrop.Client.HANDLERS.CleanupState = Menu.onCleanupState
end

-- Plus inscrit au menu contextuel (2026-10-01) : la section « Logistique » de
-- la fenêtre radio (MilitaryDrop_RadioModule.lua) le remplace et réutilise
-- Menu.reason, Menu.tooltipText et Menu.onOption. Menu.addOptions et les
-- fonctions onFill* restent pour un éventuel retour et pour les tests.

return Menu
