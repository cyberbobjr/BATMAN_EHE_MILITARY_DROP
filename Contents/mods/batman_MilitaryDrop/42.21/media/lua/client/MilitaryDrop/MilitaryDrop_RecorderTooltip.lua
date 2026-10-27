require "MilitaryDrop/MilitaryDrop_Recorders"
require "TooltipLib/Core"
local Recorders = MilitaryDrop.Recorders
local provider = {
    id = "batman_MilitaryDrop_RecorderStatus", target = "item", cacheable = false,
    description = "IGUI_MilitaryDrop_RecorderTooltipProvider",
    enabled = function(item) return Recorders.isTransmitted(item) end,
    callback = function(ctx)
        ctx:addLabel(getText("IGUI_MilitaryDrop_RecorderTransmitted"), { 0.65, 0.9, 0.65, 1 })
        ctx:addLabel(getText("IGUI_MilitaryDrop_RecorderDismantleHint"), { 0.8, 0.8, 0.8, 1 })
    end,
}
if TooltipLib.hasProvider(provider.id) then TooltipLib.replaceProvider(provider.id, provider)
else TooltipLib.registerProvider(provider) end
return provider
