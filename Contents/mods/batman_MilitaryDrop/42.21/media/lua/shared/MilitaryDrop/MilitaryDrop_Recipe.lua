-- ============================================================================
-- Military Drop — ouverture d'une caisse de ravitaillement
--
-- OnCreate de la craftRecipe OpenMilitarySupplyCase. Appelé en solo, ou sur le
-- serveur en MP, jamais sur un client (ISHandcraftAction:performRecipe, 42.21).
-- Actions.addOrDropItem ajoute l'objet à l'inventaire (ou le pose au sol si le
-- personnage est trop chargé) et l'envoie au client (sendAddItemToContainer).
--
-- Confiance (v1.3) : la caisse porte le dropId de son largage ; la première
-- ouverte le clôt (MilitaryDrop.Trust.onCaseOpened, fichier serveur, absent
-- d'un client).
--
-- Caisse de réquisition (v1.4) : même recette ; son lot est en ModData
-- (MilitaryDrop.Lots.ITEM_KEY), le contenu est tiré à l'ouverture parmi les
-- candidats du lot. Un récipient d'eau ou d'essence est rempli avant d'être
-- remis au joueur (donc envoyé plein au client).
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Loot"
require "MilitaryDrop/MilitaryDrop_Lots"

local Recipe = {}
MilitaryDrop.Recipe = Recipe

local function give(character, fullType, lot)
    local item = instanceItem(fullType)
    if not item then
        return
    end
    if lot then
        MilitaryDrop.Lots.prepare(lot, item)
    end
    Actions.addOrDropItem(character, item)
    if lot and not lot.extras then
        return
    end
    for _, extraType in ipairs(MilitaryDrop.Loot.weaponExtras(item)) do
        local extra = instanceItem(extraType)
        if extra then
            Actions.addOrDropItem(character, extra)
        end
    end
end

--- Types complets tirés pour une caisse ouverte et son lot (réquisition), ou
--- nil si ce n'est pas une caisse du mod.
local function rollFor(case, caseType)
    local Lots = MilitaryDrop.Lots
    if Lots and caseType == Lots.CASE_TYPE then
        local lot = Lots.get(case:getModData()[Lots.ITEM_KEY])
        if not lot then
            MilitaryDrop.log("requisition case without a known lot", true)
            return {}, nil
        end
        return Lots.roll(lot.id), lot
    end
    if MilitaryDrop.Loot.CASES[caseType] then
        return MilitaryDrop.Loot.roll(caseType), nil
    end
    return nil, nil
end

---@param craftRecipeData CraftRecipeData
---@param character IsoGameCharacter
function Recipe.openSupplyCase(craftRecipeData, character)
    if not character then
        return
    end
    local consumed = craftRecipeData:getAllConsumedItems()
    for i = 0, consumed:size() - 1 do
        local case = consumed:get(i)
        local caseType = case and case:getFullType()
        local types, lot = nil, nil
        if caseType then
            types, lot = rollFor(case, caseType)
        end
        if types then
            if MilitaryDrop.Trust and MilitaryDrop.Trust.onCaseOpened then
                MilitaryDrop.Trust.onCaseOpened(case, character)
            end
            for _, fullType in ipairs(types) do
                give(character, fullType, lot)
            end
            MilitaryDrop.log("opened " .. caseType .. (lot and (" (" .. lot.id .. ")") or "")
                .. " for " .. tostring(character:getUsername()))
        end
    end
end

return Recipe
