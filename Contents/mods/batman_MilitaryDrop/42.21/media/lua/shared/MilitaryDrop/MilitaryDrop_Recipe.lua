-- ============================================================================
-- Military Drop — ouverture d'une caisse de ravitaillement
--
-- OnCreate de la craftRecipe OpenMilitarySupplyCase. Appelé en solo, ou sur le
-- serveur en MP, jamais sur un client (ISHandcraftAction:performRecipe, 42.21).
-- Actions.addOrDropItem ajoute l'objet à l'inventaire (ou le pose au sol si le
-- personnage est trop chargé) et l'envoie au client (sendAddItemToContainer).
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Loot"

local Recipe = {}
MilitaryDrop.Recipe = Recipe

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
        if caseType and MilitaryDrop.Loot.CASES[caseType] then
            for _, fullType in ipairs(MilitaryDrop.Loot.roll(caseType)) do
                local item = instanceItem(fullType)
                if item then
                    Actions.addOrDropItem(character, item)
                end
            end
            MilitaryDrop.log("opened " .. caseType .. " for " .. tostring(character:getUsername()))
        end
    end
end

return Recipe
