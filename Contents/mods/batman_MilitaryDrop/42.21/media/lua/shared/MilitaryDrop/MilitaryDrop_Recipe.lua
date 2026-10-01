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
-- Lot inconnu (retiré du fichier des lots après la livraison) : la caisse
-- n'est pas ouverte, elle est rendue intacte et le joueur prévenu
-- (Recipe.returnCase). Le contrôle ne peut pas se faire avant la recette
-- (OnTest côté client) : un client MP ne connaît que les lots par défaut.
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

--- Caisse de réquisition dont le lot n'est plus dans le fichier des lots
--- (retiré par l'admin après la livraison), ou nil. Sur le serveur (ou en
--- solo) seulement : c'est là que la recette s'exécute.
local function unknownLotCase(case, caseType)
    local Lots = MilitaryDrop.Lots
    if not Lots or caseType ~= Lots.CASE_TYPE then
        return false
    end
    return Lots.get(case:getModData()[Lots.ITEM_KEY]) == nil
end

--- Types complets tirés pour une caisse ouverte et son lot (réquisition), ou
--- nil si ce n'est pas une caisse du mod.
local function rollFor(case, caseType)
    local Lots = MilitaryDrop.Lots
    if Lots and caseType == Lots.CASE_TYPE then
        local lot = Lots.get(case:getModData()[Lots.ITEM_KEY])
        if not lot then
            return {}, nil
        end
        return Lots.roll(lot.id), lot
    end
    if MilitaryDrop.Loot.CASES[caseType] then
        return MilitaryDrop.Loot.roll(caseType), nil
    end
    return nil, nil
end

--- Ouverture refusée d'une caisse au lot inconnu : la recette l'a déjà
--- consommée, elle est donc rendue intacte (nouvel exemplaire, mêmes ModData
--- : lot, largage ; même nom), sans prévenir la confiance (rien n'a été
--- ouvert), et le personnage le dit (clé de traduction, langue du client).
--- Si l'admin remet le lot (enabled = false suffit), elle s'ouvrira.
function Recipe.returnCase(case, caseType, character)
    local copy = instanceItem(caseType)
    if not copy then
        return false
    end
    local data = copy:getModData()
    for key, value in pairs(case:getModData()) do
        data[key] = value
    end
    if case.isCustomName and case:isCustomName() then
        copy:setName(case:getName())
        copy:setCustomName(true)
    end
    Actions.addOrDropItem(character, copy)
    local lotId = case:getModData()[MilitaryDrop.Lots.ITEM_KEY]
    MilitaryDrop.log("requisition case of unknown lot " .. tostring(lotId) .. " returned unopened to "
        .. tostring(character:getUsername()), true)
    if MilitaryDrop.Net and character.getUsername then
        MilitaryDrop.Net.toPlayer(character, "Notice", { key = Recipe.UNKNOWN_LOT_KEY,
            username = character:getUsername() })
    end
    return true
end

Recipe.UNKNOWN_LOT_KEY = "IGUI_MilitaryDrop_UnknownLotCase"

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
        if caseType and unknownLotCase(case, caseType) then
            Recipe.returnCase(case, caseType, character)
        elseif caseType then
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
