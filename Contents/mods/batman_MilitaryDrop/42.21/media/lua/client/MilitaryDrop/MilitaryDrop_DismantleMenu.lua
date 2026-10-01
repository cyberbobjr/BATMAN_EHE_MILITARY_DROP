-- ============================================================================
-- Military Drop — « Démonter la caisse » (menu contextuel du monde, client)
--
-- Sur la caisse de largage (véhicule reconnu par son script, trouvé comme
-- ISVehicleMenu.OnFillWorldObjectContextMenu : sous la souris, ou autour du
-- personnage à la manette) : option grisée avec la raison si le démontage est
-- impossible, infobulle avec les outils de la définition vanilla, la
-- compétence et la chance de casse. Au choix : marche jusqu'à la zone du
-- coffre, prise en main des outils (comme scrapWalkToAndEquip), puis
-- l'action MilitaryDrop.DismantleAction. Le serveur revérifie tout.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Dismantle"

local Dismantle = MilitaryDrop.Dismantle

local Menu = {}
MilitaryDrop.DismantleMenu = Menu

-- Noms d'outils affichés au plus, par jeu d'outils.
Menu.MAX_TOOL_NAMES = 3
Menu.WHITE = " <RGB:1,1,1> "
Menu.RED = " <RGB:1,0,0> "

local function addVehicle(found, vehicle)
    if vehicle and Dismantle.isCrate(vehicle) and not found.seen[vehicle] then
        found.seen[vehicle] = true
        found.list[#found.list + 1] = vehicle
    end
end

--- Caisse visée : sous la souris, autour du personnage (manette), ou sur une
--- case cliquée. nil si aucune.
function Menu.findCrate(playerNum, player, worldObjects)
    if player:getVehicle() then
        return nil
    end
    local found = { seen = {}, list = {} }
    if JoypadState and JoypadState.players[playerNum + 1] then
        local x, y, z = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
        for dx = -1, 1 do
            for dy = -1, 1 do
                local square = getCell():getGridSquare(x + dx, y + dy, z)
                addVehicle(found, square and square:getVehicleContainer())
            end
        end
    else
        addVehicle(found, IsoObjectPicker.Instance:PickVehicle(getMouseXScaled(), getMouseYScaled()))
    end
    for _, object in ipairs(worldObjects or {}) do
        local square = object and object:getSquare()
        addVehicle(found, square and square:getVehicleContainer())
    end
    return found.list[1]
end

--- Noms affichés d'un jeu d'outils (types de la définition), sans doublon.
function Menu.toolNames(def, types)
    local names, seen = {}, {}
    for _, fullType in ipairs(types) do
        local name = def.toolNames and def.toolNames[fullType] or fullType
        if not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    table.sort(names)
    if #names > Menu.MAX_TOOL_NAMES then
        local shown = {}
        for i = 1, Menu.MAX_TOOL_NAMES do
            shown[i] = names[i]
        end
        shown[#shown + 1] = "..."
        names = shown
    end
    return table.concat(names, " / ")
end

--- Ligne d'un jeu d'outils : l'outil possédé en blanc, sinon la liste en rouge.
local function toolLine(def, types, tool)
    if instanceof(tool, "InventoryItem") then
        return Menu.WHITE .. tool:getDisplayName()
    end
    return (tool and Menu.WHITE or Menu.RED) .. Menu.toolNames(def, types)
end

--- Texte de l'infobulle (texte riche) ; reason : motif de Dismantle.check.
function Menu.tooltipText(player, reason)
    local lines = { Menu.WHITE .. getText("IGUI_MilitaryDrop_DismantleTooltip") }
    local def = Dismantle.definition()
    if def then
        local tool, tool2 = Dismantle.tools(player)
        lines[#lines + 1] = Menu.WHITE .. getText("IGUI_MilitaryDrop_DismantleTools")
        if def.tools and #def.tools > 0 then
            lines[#lines + 1] = toolLine(def, def.tools, tool)
        end
        if def.tools2 and #def.tools2 > 0 then
            lines[#lines + 1] = toolLine(def, def.tools2, tool2)
        end
        if def.perkName then
            lines[#lines + 1] = Menu.WHITE .. getText("IGUI_MilitaryDrop_DismantleSkill", def.perkName)
        end
        lines[#lines + 1] = Menu.WHITE .. getText("IGUI_MilitaryDrop_DismantleBreakChance",
            tostring(100 - Dismantle.chance(player)))
    end
    if reason then
        lines[#lines + 1] = Menu.RED .. getText(Dismantle.REASONS[reason])
    end
    return table.concat(lines, " <LINE> ")
end

--- Marche jusqu'au coffre, prise en main des outils, puis démontage.
function Menu.onDismantle(player, vehicle)
    if not Dismantle.isCrate(vehicle) then
        return
    end
    local area = nil
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        if not area and part and part:getItemContainer() then
            area = part:getArea()
        end
    end
    if area then
        ISTimedActionQueue.add(ISPathFindAction:pathToVehicleArea(player, vehicle, area))
    else
        ISTimedActionQueue.add(ISPathFindAction:pathToVehicleAdjacent(player, vehicle))
    end
    local tool, tool2 = Dismantle.tools(player)
    if instanceof(tool, "InventoryItem") then
        ISWorldObjectContextMenu.equip(player, player:getPrimaryHandItem(), tool, true)
    end
    if instanceof(tool2, "InventoryItem") and tool2 ~= tool then
        ISWorldObjectContextMenu.equip(player, player:getSecondaryHandItem(), tool2, false)
    end
    ISTimedActionQueue.add(MilitaryDrop.DismantleAction.new(nil, player, vehicle))
end

function Menu.onFillWorldContextMenu(playerNum, context, worldObjects, test)
    if test then
        return
    end
    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end
    local vehicle = Menu.findCrate(playerNum, player, worldObjects)
    if not vehicle then
        return
    end
    local option = context:addOption(getText("IGUI_MilitaryDrop_Dismantle"), player, Menu.onDismantle, vehicle)
    local reason = Dismantle.check(player, vehicle, { ignoreDistance = true })
    if reason then
        option.notAvailable = true
    end
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip:setVisible(false)
    tooltip:setName(getText("IGUI_MilitaryDrop_Dismantle"))
    tooltip.description = Menu.tooltipText(player, reason)
    option.toolTip = tooltip
end

Events.OnFillWorldObjectContextMenu.Add(Menu.onFillWorldContextMenu)

return Menu
