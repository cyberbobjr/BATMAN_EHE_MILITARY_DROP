-- Lots de récupération : catégories du jeu et tags, objets des mods inclus.
require "MilitaryDrop/MilitaryDrop_Crash"
local Salvage = {}
MilitaryDrop.Salvage = Salvage
Salvage.PARTS = {
    Avionics = { kind = "electronics", tool = "base:screwdriver", skill = "Electricity", level = 2 },
    RadioRack = { kind = "electronics", tool = "base:screwdriver", skill = "Electricity", level = 1,
        after = "Avionics" },
    EngineBay = { kind = "mechanical", tool = "base:wrench", skill = "Mechanics", level = 2 },
    RotorHub = { kind = "metal", tool = "base:wrench", skill = "Mechanics", level = 1, after = "EngineBay" },
    SkinPanels = { kind = "metal", tool = "base:screwdriver", skill = "MetalWelding", level = 1,
        after = "RotorHub" },
}
Salvage.TYPES = {
    electronics = "MilitaryDrop.AvionicsSalvage", mechanical = "MilitaryDrop.MechanicalSalvage",
    metal = "MilitaryDrop.MetalSalvage",
}
local candidates

local function hasMetal(script)
    for _, name in ipairs({ "base:hasmetal", "base:scrapaluminum", "base:wire", "base:metalpiece",
        "base:smeltableiron", "base:smeltablesteel", "base:smeltablealuminum", "base:smeltablecopper" }) do
        local tag = ItemTag.get(ResourceLocation.of(name))
        if tag and script:hasTag(tag) then return true end
    end
    return false
end

function Salvage.build()
    local result = { electronics = {}, mechanical = {}, metal = {} }
    local fallback = {}
    local scripts = getScriptManager():getAllItems()
    for i = 0, scripts:size() - 1 do
        local script = scripts:get(i)
        local name, category = script:getFullName(), script:getDisplayCategory()
        if not script:getObsolete() and name:sub(1, 13) ~= "MilitaryDrop." then
            if category == "Electronics" then result.electronics[#result.electronics + 1] = name end
            if category == "VehicleMaintenance" then result.mechanical[#result.mechanical + 1] = name end
            if category == "Material" then
                fallback[#fallback + 1] = name
                if hasMetal(script) then result.metal[#result.metal + 1] = name end
            end
        end
    end
    if #result.metal == 0 then result.metal = fallback end
    for _, kind in ipairs({ "electronics", "mechanical" }) do
        if #result[kind] == 0 then result[kind] = result.metal end
    end
    candidates = result
    return result
end

function Salvage.roll(kind, count, rand)
    local pool = (candidates or Salvage.build())[kind] or {}
    local types = {}
    for _ = 1, math.max(0, math.min(20, math.floor(count or MilitaryDrop.Config.get("SalvageRolls")))) do
        if #pool > 0 then types[#types + 1] = pool[(rand or ZombRand)(#pool) + 1] end
    end
    return types
end

function Salvage.open(data, character)
    if isClient() or not character then return end
    local consumed = data:getAllConsumedItems()
    for i = 0, consumed:size() - 1 do
        local item = consumed:get(i)
        for kind, fullType in pairs(Salvage.TYPES) do
            if item:getFullType() == fullType then
                for _, name in ipairs(Salvage.roll(kind)) do
                    local recovered = instanceItem(name)
                    if recovered then Actions.addOrDropItem(character, recovered) end
                end
            end
        end
    end
end

Events.OnGameStart.Add(Salvage.build)
Events.OnServerStarted.Add(Salvage.build)
return Salvage
