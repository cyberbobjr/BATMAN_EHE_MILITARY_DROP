-- Récupération explicite au clic droit ; la découpe finale attend les pièces.
require "Vehicles/ISUI/ISVehicleMenu"
require "Vehicles/ISUI/ISCarMechanicsOverlay"
require "MilitaryDrop/MilitaryDrop_WreckParts"

local Menu = MilitaryDrop.WreckMenu or {}
MilitaryDrop.WreckMenu = Menu
local VehicleMenu = ISVehicleMenu
local Overlay = ISCarMechanicsOverlay

local function registerOverlay(scriptName, prefix, images, hitboxes)
    local partImages = {}
    for partId, image in pairs(images) do
        partImages[partId] = { img = image }
        local shared = Overlay.PartList[partId]
        if not shared then
            shared = { img = image, vehicles = {} }
            Overlay.PartList[partId] = shared
        end
        shared.vehicles = shared.vehicles or {}
        shared.vehicles[prefix] = hitboxes[partId]
    end
    Overlay.CarList[scriptName] = { imgPrefix = prefix, x = 10, y = 0, PartList = partImages }
end

registerOverlay("Base.MilitaryDrop_HeliWreckBurnt", "militarydrop_heli_wreck_", {
    Avionics = "avionics", RadioRack = "radiorack", EngineBay = "enginebay",
    RotorHub = "rotorhub", SkinPanels = "skinpanels",
}, {
    Avionics = { x = 87, y = 57, x2 = 177, y2 = 129 },
    RadioRack = { x = 97, y = 197, x2 = 166, y2 = 274 },
    EngineBay = { x = 86, y = 359, x2 = 177, y2 = 437 },
    RotorHub = { x = 109, y = 286, x2 = 153, y2 = 334 },
    SkinPanels = { x = 96, y = 439, x2 = 168, y2 = 491 },
})

registerOverlay("Base.MilitaryDrop_HeliTailBurnt", "militarydrop_heli_tail_", {
    SkinPanels = "skinpanels",
}, {
    SkinPanels = { x = 55, y = 153, x2 = 207, y2 = 504 },
})

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
