local T = {}
local function list(values)
    return { size = function() return #values end, get = function(_,i) return values[i+1] end }
end
local function script(name,category,metal,obsolete)
    return { getFullName = function() return name end, getDisplayCategory = function() return category end,
        getObsolete = function() return obsolete end, hasTag = function() return metal end }
end
function T.setup()
    isClient = function() return false end
    SandboxVars = {}
    ItemTag = { get = function(x) return x end }
    ResourceLocation = { of = function(x) return x end }
    ITEMS = { script("Mod.Circuit","Electronics"),script("Mod.Part","VehicleMaintenance"),
        script("Mod.Metal","Material",true),script("Mod.Wood","Material"),
        script("Mod.Obsolete","Electronics",false,true),script("MilitaryDrop.MetalSalvage","Material",true) }
    getScriptManager = function() return { getAllItems = function() return list(ITEMS) end } end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Crash.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Salvage.lua")
end
function T.includes_mod_items_and_excludes_its_own_bundles_and_obsolete_items()
    local c = MilitaryDrop.Salvage.build()
    assertEq(#c.electronics,1)
    assertEq(c.electronics[1],"Mod.Circuit")
    assertEq(#c.metal,1)
    assertEq(c.metal[1],"Mod.Metal")
    assertEq(MilitaryDrop.Salvage.roll("mechanical",3,function() return 0 end)[1],"Mod.Part")
end
function T.missing_categories_fall_back_to_materials()
    ITEMS = { script("Mod.Material","Material") }
    local c = MilitaryDrop.Salvage.build()
    assertEq(c.metal[1],"Mod.Material")
    assertEq(c.electronics[1],"Mod.Material")
    assertEq(c.mechanical[1],"Mod.Material")
end
function T.no_candidate_is_safe_and_roll_count_is_bounded()
    ITEMS = {}
    MilitaryDrop.Salvage.build()
    assertEq(#MilitaryDrop.Salvage.roll("metal",100,function() return 0 end),0)
    ITEMS = { script("Mod.Material","Material",true) }
    MilitaryDrop.Salvage.build()
    assertEq(#MilitaryDrop.Salvage.roll("metal",100,function() return 0 end),20)
end
return T
