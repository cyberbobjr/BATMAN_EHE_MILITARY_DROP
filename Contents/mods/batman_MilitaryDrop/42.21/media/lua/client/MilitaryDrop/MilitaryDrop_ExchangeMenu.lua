-- ============================================================================
-- Military Drop — sous-menu « Logistique » d'une radio militaire (client)
--
-- Sur une radio militaire (objet de l'inventaire, ou appareil posé) :
-- rapport de situation, transmission des plaques d'identité vanilla
-- renommées d'après leur porteur (MilitaryDrop.Exchange.isDogTag : pas celle
-- du personnage ; l'infobulle cite les noms),
-- confirmation de la reconnaissance, confirmation de réception (appel de
-- contrôle). Le client ne décide rien : il grise une option avec la raison
-- visible (radio hors de l'inventaire ou trop loin, éteinte, source désactivée
-- sur le serveur, aucune plaque), puis passe par MilitaryDrop.Exchange : prise
-- en main du talkie si besoin (AUTH-03), parole du personnage, commande au
-- serveur, réponse de la base par la radio.
--
-- Comme pour l'appel de largage, la fréquence n'est jamais vérifiée ici, ni
-- l'existence d'une mission : le serveur répond.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Radio"
require "MilitaryDrop/MilitaryDrop_Exchange"
require "MilitaryDrop/MilitaryDrop_Client"

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
}

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
    local reason = Exchange.unavailableReason(player, device)
    if reason then
        return reason
    end
    if option.source == "dogtag" and Menu.dogTagCount(player) == 0 then
        return "IGUI_MilitaryDrop_NoDogTags"
    end
    return nil
end

function Menu.onOption(player, device, option)
    local speech = getText(option.speech .. (ZombRand(option.speechCount) + 1), tostring(Menu.dogTagCount(player)))
    Exchange.send(player, device, Exchange.COMMANDS[option.source], {}, speech)
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

Events.OnFillInventoryObjectContextMenu.Add(Menu.onFillInventoryContextMenu)
Events.OnFillWorldObjectContextMenu.Add(Menu.onFillWorldContextMenu)

return Menu
