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
            "HTC.SurvivorWeaponSupplyBox", 30,
            "HTC.SurvivorArmorSupplyBox", 20,
            "HTC.SurvivorAttachmentSupplyBox", 20
        }
    }

    VehicleDistributions.HTC_MilitarySupplyDrop = { TruckBed = VehicleDistributions.HTC_MilitarySupplyDrop; }
    distributionTable["HTC_MilitarySupplyDrop"] = { Normal = VehicleDistributions.HTC_MilitarySupplyDrop; }
end

eHelicopter_PRESETS = eHelicopter_PRESETS or {}
eHelicopter_PRESETS["HTC_military_drop"] = {
    inherit = { "samaritan_drop" },
    dropPackages = { "HTC_MilitarySupplyDrop" }
}

function EHE_Recipe.getRandomItemFromStore(items)
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

function EHE_Recipe.MILITARYAMMOBOX(items, result, player)
    local itemContainer = player:getInventory()
    if not itemContainer then
        return
    end
    local attempts = 0
    local maxAttempts = 50
    for i = 1, 10 do
        local randomItem = nil
        attempts = 0
        while attempts < maxAttempts do
            randomItem = EHE_Recipe.getRandomItemFromStore(A26ProcDistro.list.SurplusAmmo.items)
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

function EHE_Recipe.MILITARYWEAPONBOX(items, result, player)
    local itemContainer = player:getInventory()
    if not itemContainer then
        return
    end
    local randomItem = EHE_Recipe.getRandomItemFromStore(A26ProcDistro.list.SurplusGuns.items)
    if randomItem then
        itemContainer:AddItem(randomItem)
    end
end

function EHE_Recipe.MILITARYARMORBOX(items, result, player)
    local itemContainer = player:getInventory()
    if not itemContainer then
        return
    end

    for i = 1, 5 do
        -- Répète 5 fois
        local randomItem = EHE_Recipe.getRandomItemFromStore(Brita_2_ProcDistro.list.ArmySurplusOutfit.items)
        if randomItem then
            itemContainer:AddItem(randomItem)
        end
    end
end

function EHE_Recipe.MILITARYATTACHMENTBOX(items, result, player)
    local itemContainer = player:getInventory()
    if not itemContainer then
        return
    end
    for i = 1, 5 do
        -- Répète 5 fois
        local randomItem = EHE_Recipe.getRandomItemFromStore(A26ProcDistro.list.SurplusParts.items)
        if randomItem then
            itemContainer:AddItem(randomItem)
        end
    end
end

Events.OnPostDistributionMerge.Add(HTC_applyLootBoxLoot)