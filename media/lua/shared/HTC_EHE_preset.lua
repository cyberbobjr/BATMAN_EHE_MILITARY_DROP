require "Items/SuburbsDistributions"
require "ExpandedHelicopter02a_Presets"
require "ExpandedHelicopter07_RecipeFunctions"

local function HTC_applyLootBoxLoot()
    local distributionTable = VehicleDistributions[1]

    VehicleDistributions.HTC_MilitarySupplyDrop = {
        rolls = 6,
        items = {
            "HTC.SurvivorAmmoSupplyBox", 50,
            "HTC.SurvivorAmmoSupplyBox", 50,
            "HTC.SurvivorAmmoSupplyBox", 50,
            "HTC.SurvivorWeaponSupplyBox", 50,
            "HTC.SurvivorArmorSupplyBox", 20,
            "HTC.SurvivorAttachmentSupplyBox", 20
        }
    }

    VehicleDistributions.HTC_MilitarySupplyDrop = { TruckBed = VehicleDistributions.HTC_MilitarySupplyDrop; }
    distributionTable["HTC_MilitarySupplyDrop"] = { Normal = VehicleDistributions.HTC_MilitarySupplyDrop; }
end

local function onDrop(vehicle)
    if not vehicle then
        return
    end
    local MaxZSpawn = SandboxVars.HTC_EHE_MilitaryDrop.MaxZSpawn
    local MinZSpawn = SandboxVars.HTC_EHE_MilitaryDrop.MinZSpawn

    --if carePackage == "HTC_MilitarySupplyDrop" then
    local spawnZNumber = ZombRand(MinZSpawn, MaxZSpawn)
    local heliX, heliY, heliZ = vehicle:getX(), vehicle:getY(), vehicle:getZ()

    --[[DEBUG]] print("HTC - EHE: spawnHorde :" .. spawnZNumber)
    spawnHorde(heliX - 2, heliY - 2, heliX + 2, heliY + 2, heliZ, spawnZNumber);
    sendServerCommand("HTC_EHE", "Dropped", { x = heliX, y = heliY })
    --end
end

eHelicopter_PRESETS = eHelicopter_PRESETS or {}
eHelicopter_PRESETS["HTC_military_drop"] = {
    inherit = { "samaritan_drop" },
    forScheduling = false,
    targetIntensityThreshold = false,
    randomEdgeStart = false,
    dropPackages = { "HTC_MilitarySupplyDrop" },
    addedFunctionsToEvents = { ["OnDrop"] = onDrop },
}

HTC_EHE_Recipe = {}

function HTC_EHE_Recipe.getRandomItemFromStore(items)
    local weights = {}
    local totalWeight = 0

    -- Calculer le poids total pour la probabilité
    for i = 1, #items, 2 do
        local weight = items[i + 1]
        table.insert(weights, { name = items[i], weight = math.max(weight, 0) }) -- Assurer que les poids négatifs ne sont pas pris en compte
        totalWeight = totalWeight + math.max(weight, 0)
    end

    -- Sélectionner un élément basé sur le poids si le poids total est supérieur à zéro
    if totalWeight > 0 then
        local randomPoint = ZombRand(totalWeight + 1) -- +1 car ZombRand est exclusif
        local currentSum = 0
        for _, item in ipairs(weights) do
            currentSum = currentSum + item.weight
            if currentSum > randomPoint then
                return item.name
            end
        end
    end

    -- Si aucun élément n'est sélectionné à cause des poids zéro, choisir un élément au hasard
    if #weights > 0 then
        return weights[ZombRand(#weights) + 1].name -- +1 car les tables Lua commencent à l'indice 1
    end

    -- En dernier recours, si aucun élément n'est disponible
    return nil
end

function HTC_EHE_Recipe.MILITARYAMMOBOX(items, result, player)
    local itemContainer = player:getInventory()
    if not itemContainer then
        return
    end
    local attempts = 0
    local maxAttempts = 50
    for i = 1, 5 do
        local randomItem = nil
        attempts = 0
        while attempts < maxAttempts do
            randomItem = HTC_EHE_Recipe.getRandomItemFromStore(HTC_EHE_Recipe.getAmmoDistributionList())
            if randomItem and not string.find(randomItem, "PolyCan") and not string.find(randomItem, "AmmoCan") then
                break
            end
            attempts = attempts + 1
        end
        if randomItem then
            itemContainer:AddItem(randomItem)
        end
    end
end

function HTC_EHE_Recipe.MILITARYWEAPONBOX(items, result, player)
    local itemContainer = player:getInventory()
    if not itemContainer then
        return
    end
    local randomItem = HTC_EHE_Recipe.getRandomItemFromStore(HTC_EHE_Recipe.getWeaponDistributionList())
    if randomItem then
        itemContainer:AddItem(randomItem)
    end
end

function HTC_EHE_Recipe.MILITARYARMORBOX(items, result, player)
    local itemContainer = player:getInventory()
    if not itemContainer then
        return
    end

    for i = 1, 5 do
        -- Répète 5 fois
        local randomItem = HTC_EHE_Recipe.getRandomItemFromStore(HTC_EHE_Recipe.getArmorDistributionList())
        if randomItem then
            itemContainer:AddItem(randomItem)
        end
    end
end

function HTC_EHE_Recipe.MILITARYATTACHMENTBOX(items, result, player)
    local itemContainer = player:getInventory()
    if not itemContainer then
        return
    end
    for i = 1, 5 do
        -- Répète 5 fois
        local randomItem = HTC_EHE_Recipe.getRandomItemFromStore(HTC_EHE_Recipe.getAttachmentDistributionList())
        if randomItem then
            itemContainer:AddItem(randomItem)
        end
    end
end

function HTC_EHE_Recipe.getAmmoDistributionList()
    if getActivatedMods():contains("Arsenal(26)GunFighter[MAIN MOD 2.0]") then
        return A26ProcDistro.list.SurplusAmmo.items
    end
    return ProceduralDistributions.list.ArmyStorageAmmunition.items
end
function HTC_EHE_Recipe.getWeaponDistributionList()
    if getActivatedMods():contains("Arsenal(26)GunFighter[MAIN MOD 2.0]") then
        return A26ProcDistro.list.SurplusGuns.items
    end
    return ProceduralDistributions.list.ArmyStorageGuns.items
end
function HTC_EHE_Recipe.getArmorDistributionList()
    if getActivatedMods():contains("Arsenal(26)GunFighter[MAIN MOD 2.0]") then
        return Brita_2_ProcDistro.list.ArmySurplusOutfit.items
    end
    return ProceduralDistributions.list.ArmyStorageOutfit.items
end
function HTC_EHE_Recipe.getAttachmentDistributionList()
    if getActivatedMods():contains("Arsenal(26)GunFighter[MAIN MOD 2.0]") then
        return A26ProcDistro.list.SurplusParts.items
    end
    local attachmentTable = {
        "AmmoStraps", 6,
        --"Bayonnet", 4,
        "ChokeTubeFull", 6,
        "ChokeTubeImproved", 6,
        "FiberglassStock", 6,
        --"gunlight", 6,
        "Hat_EarMuff_Protectors", 8,
        "IronSight", 4,
        "Laser", 6,
        "RecoilPad", 6,
        "RedDot", 6,
        "Sling", 6,
        "x2Scope", 8,
        "x4Scope", 6,
        "x8Scope", 4,
    }
    if getActivatedMods():contains("VFExpansion1") then
        table.insert(attachmentTable, "Bipod")
        table.insert(attachmentTable, 4)
        table.insert(attachmentTable, "CleaningKit")
        table.insert(attachmentTable, 4)
        table.insert(attachmentTable, "FireKlean")
        table.insert(attachmentTable, 4)
        table.insert(attachmentTable, "ShellStraps")
        table.insert(attachmentTable, 4)
        table.insert(attachmentTable, "LightenedStock")
        table.insert(attachmentTable, 4)
    end
    return attachmentTable
end

Events.OnPostDistributionMerge.Add(HTC_applyLootBoxLoot)
