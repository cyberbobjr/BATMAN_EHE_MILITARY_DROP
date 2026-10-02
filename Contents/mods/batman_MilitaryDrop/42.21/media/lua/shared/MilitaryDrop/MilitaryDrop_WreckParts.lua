-- Pièces d'épave : état porté par les pièces vanilla, action validée sur le serveur.
require "MilitaryDrop/MilitaryDrop_Salvage"
require "Vehicles/TimedActions/ISUninstallVehiclePart"
require "Vehicles/TimedActions/ISInstallVehiclePart"
require "Vehicles/TimedActions/ISRemoveBurntVehicle"

local Parts = MilitaryDrop.WreckParts or {}
MilitaryDrop.WreckParts = Parts
local Salvage = MilitaryDrop.Salvage
Parts.SCRIPTS = { ["Base.MilitaryDrop_HeliWreckBurnt"] = true, ["Base.MilitaryDrop_HeliTailBurnt"] = true }

function Parts.isWreck(vehicle)
    return vehicle and Parts.SCRIPTS[vehicle:getScriptName()] == true
end

function Parts.create(vehicle, part)
    if isClient() then return end
    local spec = Salvage.PARTS[part:getId()]
    if spec then
        part:setInventoryItem(instanceItem(Salvage.TYPES[spec.kind]))
        vehicle:transmitPartItem(part)
    end
end

function Parts.near(vehicle, character)
    if not vehicle or not character or vehicle:isRemovedFromWorld() or character:isDead()
        or math.floor(character:getZ()) ~= 0 then return false end
    local dx, dy = vehicle:getX() - character:getX(), vehicle:getY() - character:getY()
    return dx * dx + dy * dy <= 49
end

function Parts.test(vehicle, part, character)
    local spec = part and Salvage.PARTS[part:getId()]
    if not Parts.isWreck(vehicle) or not spec or not Parts.near(vehicle, character)
        or part:getVehicle() ~= vehicle or not part:getInventoryItem() then return false end
    if character:getPerkLevel(Perks.FromString(spec.skill)) < spec.level then return false end
    local tag = ItemTag.get(ResourceLocation.of(spec.tool))
    if not tag or not character:getInventory():getFirstTagRecurse(tag) then return false end
    local previous = spec.after and vehicle:getPartById(spec.after)
    return not previous or previous:getInventoryItem() == nil
end

function Parts.noInstall() return false end

function Parts.empty(vehicle)
    for id in pairs(Salvage.PARTS) do
        local part = vehicle:getPartById(id)
        if part and part:getInventoryItem() then return false end
    end
    return true
end

-- Le complete vanilla ne revérifie pas les outils ; le wrapper ne touche que nos scripts.
local UninstallAction, InstallAction, CutAction = ISUninstallVehiclePart, ISInstallVehiclePart, ISRemoveBurntVehicle
local uninstall = Parts.originalUninstall or UninstallAction.complete
Parts.originalUninstall = uninstall
Parts.uninstallWrapper = function(action, ...)
    if not Parts.isWreck(action.vehicle) then return uninstall(action, ...) end
    if isClient() or not Parts.test(action.vehicle, action.part, action.character) then return false end
    local item = action.part:getInventoryItem()
    action.part:setInventoryItem(nil)
    action.vehicle:transmitPartItem(action.part)
    Actions.addOrDropItem(action.character, item)
    addXp(action.character, Perks.FromString(Salvage.PARTS[action.part:getId()].skill), 5)
    return true
end
UninstallAction.complete = Parts.uninstallWrapper

local install = Parts.originalInstall or InstallAction.complete
Parts.originalInstall = install
Parts.installWrapper = function(action, ...)
    if Parts.isWreck(action.vehicle) then return false end
    return install(action, ...)
end
InstallAction.complete = Parts.installWrapper

local validCut = Parts.originalCutValid or CutAction.isValid
Parts.originalCutValid = validCut
Parts.cutValidWrapper = function(action, ...)
    if Parts.isWreck(action.vehicle) and not Parts.empty(action.vehicle) then return false end
    return validCut(action, ...)
end
CutAction.isValid = Parts.cutValidWrapper
local cut = Parts.originalCut or CutAction.complete
Parts.originalCut = cut
Parts.cutWrapper = function(action, ...)
    if Parts.isWreck(action.vehicle) then
        if isClient() or not Parts.near(action.vehicle, action.character) or not Parts.empty(action.vehicle)
            or not validCut(action) then return false end
        local mask = action.character:getInventory():getFirstTagRecurse(ItemTag.WELDING_MASK)
        if not mask then return false end
    end
    return cut(action, ...)
end
CutAction.complete = Parts.cutWrapper

return Parts
