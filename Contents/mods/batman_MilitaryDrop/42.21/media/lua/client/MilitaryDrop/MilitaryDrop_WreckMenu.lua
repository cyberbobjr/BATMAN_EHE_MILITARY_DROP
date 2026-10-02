-- Récupération explicite au clic droit ; la découpe finale attend les pièces.
require "Vehicles/ISUI/ISVehicleMenu"
require "MilitaryDrop/MilitaryDrop_WreckParts"

local Menu = MilitaryDrop.WreckMenu or {}
MilitaryDrop.WreckMenu = Menu
local VehicleMenu = ISVehicleMenu
local previous = Menu.original or VehicleMenu.FillMenuOutsideVehicle
Menu.original = previous
Menu.wrapper = function(playerIndex, context, vehicle, test, ...)
    if test or not MilitaryDrop.WreckParts.isWreck(vehicle) then
        return previous(playerIndex, context, vehicle, test, ...)
    end
    local result = previous(playerIndex, context, vehicle, test, ...)
    local player = getSpecificPlayer(playerIndex)
    if not MilitaryDrop.WreckParts.near(vehicle, player) then return result end
    context:addOption(getText("IGUI_MilitaryDrop_RecoverWreck"), player, VehicleMenu.onMechanic, vehicle)
    if not MilitaryDrop.WreckParts.empty(vehicle) then
        local option = context:getOptionFromName(getText("ContextMenu_RemoveBurntVehicle"))
        if option then
            option.notAvailable = true
            if option.toolTip then
                option.toolTip.description = getText("IGUI_MilitaryDrop_RecoverWreckFirst")
            end
        end
    end
    return result
end
VehicleMenu.FillMenuOutsideVehicle = Menu.wrapper
return Menu
