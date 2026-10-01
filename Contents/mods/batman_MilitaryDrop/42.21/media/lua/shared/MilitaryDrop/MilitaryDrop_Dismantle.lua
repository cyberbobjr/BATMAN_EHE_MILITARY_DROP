-- ============================================================================
-- Military Drop — démontage de la caisse de largage (client et serveur)
--
-- La caisse vide se démonte au marteau comme un meuble en bois : outils,
-- compétence, durée, son, matériaux et XP sont ceux de la définition vanilla
-- de démontage du matériau « Wood » (ISMoveableDefinitions, lue à
-- l'exécution : un mod qui la modifie modifie aussi la caisse), appliqués par
-- les fonctions vanilla d'ISMoveableSpriteProps (hasScrapTool,
-- getScrapActionTime, getScrapItemsList, addAllScrapItemsTo…, scrapGiveXp,
-- scrapHaloNoteCheck) sur un objet de propriétés minimal (Dismantle.props).
-- Aucun nom d'objet ici : les outils de la définition sont des types résolus
-- par tags (parseItemTypes), les matériaux sont ceux de la définition.
--
-- Règles reprises du vanilla (42.21, shared/Moveables) :
--   * outils : un objet de def.tools ET un de def.tools2 dans l'inventaire
--     (sacs portés compris), sauf triche des meubles ;
--   * durée : def.baseActionTime × (1 − 0,03 × niveau de def.perk) ;
--   * matériaux : chaque essai réussit à chancePerRoll % × (10 + 10 × niveau
--     + def.baseChance) % ; taille « Large » : deux fois plus d'essais ; aucun
--     matériau utilisable → 1 ou 2 def.unusableItem ; au sol (ou dans
--     l'inventaire si def.addToInventory) ;
--   * XP : 5 × 3 (taille « Large ») sous le niveau LevelForDismantleXPCutoff ;
--   * son : « Hammering » est joué par l'animation (événement PlaySound de
--     Build.xml, sans bruit pour les zombies) ; un son non « wav » ajouterait
--     un bruit addSound (rayon 10), comme getScrapSound.
--
-- MP : action chronométrée B42 rangée sous MilitaryDrop (voir pz-knowledge
-- multiplayer.md). Le serveur la reconstruit par MilitaryDrop.DismantleAction
-- .new(_, character, vehicle) (le véhicule voyage par son identifiant) et
-- n'appelle jamais isValid : complete() revérifie tout (Dismantle.check), puis
-- donne matériaux et XP et retire le véhicule (permanentlyRemove, comme
-- ISRemoveBurntVehicle). En solo, même chemin (perform puis complete).
--
-- Confiance : le coffre doit être vide. Les caisses de ravitaillement, qui
-- portent le dropId du largage, ont donc déjà été sorties : démonter la caisse
-- ne change rien au suivi des largages (MilitaryDrop_Trust.lua).
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "Moveables/ISMoveableDefinitions"
require "Moveables/ISMoveableSpriteProps"
require "MilitaryDrop/MilitaryDrop_Core"

local Dismantle = {}
MilitaryDrop.Dismantle = Dismantle

-- Script du véhicule (MilitaryDrop.Crate.FULL_SCRIPT, fichier serveur).
Dismantle.SCRIPT = "Base.MilitaryDrop_SupplyCrate"
-- Matériau vanilla de démontage.
Dismantle.MATERIAL = "Wood"
-- Taille vanilla (propriété ScrapSize des tuiles) : caisse de 1,1 m de côté.
Dismantle.SCRAP_SIZE = "Large"
-- Distance maximale (cases) entre le personnage et le centre de la caisse,
-- vérifiée par le serveur. La zone d'accès au coffre s'étend à ~1,8 case.
Dismantle.MAX_DISTANCE = 2.5
-- Son joué par l'animation, pas par l'action (ISMoveableSpriteProps.getScrapSound).
Dismantle.ANIM_SOUND = "Hammering"
-- Bruit d'un son de démontage non « wav » (getScrapSound) : rayon, volume.
Dismantle.NOISE_RADIUS = 10
Dismantle.NOISE_VOLUME = 5
-- Note vanilla quand rien d'utilisable n'est récupéré (scrapHaloNoteCheck).
Dismantle.FAIL_NOTE = "IGUI_Moveable_Fail"

-- Motif de refus → clé de traduction.
Dismantle.REASONS = {
    gone = "IGUI_MilitaryDrop_DismantleNotPossible",
    noDefinition = "IGUI_MilitaryDrop_DismantleNotPossible",
    notEmpty = "IGUI_MilitaryDrop_DismantleEmptyFirst",
    noTools = "IGUI_MilitaryDrop_DismantleNoTools",
    safehouse = "IGUI_MilitaryDrop_DismantleSafehouse",
    tooFar = "IGUI_MilitaryDrop_DismantleTooFar",
}

-- ----------------------------------------------------------------------------
-- Règles
-- ----------------------------------------------------------------------------

--- Véhicule présent dans le monde et caisse de ce mod (reconnue par son script).
function Dismantle.isCrate(vehicle)
    return vehicle ~= nil and instanceof(vehicle, "BaseVehicle") and not vehicle:isRemovedFromWorld()
        and vehicle:getScriptName() == Dismantle.SCRIPT
end

--- Définition vanilla de démontage du bois, ou nil si absente ou sans matériau.
function Dismantle.definition()
    local defs = ISMoveableDefinitions and ISMoveableDefinitions:getInstance()
    if not defs or not defs.isScrapDefinitionValid(Dismantle.MATERIAL) then
        return nil
    end
    return defs.getScrapDefinition(Dismantle.MATERIAL)
end

--- Propriétés minimales d'un meuble en bois, pour les fonctions vanilla
--- d'ISMoveableSpriteProps qui ne lisent que le matériau et la taille.
function Dismantle.props()
    return setmetatable({
        material = Dismantle.MATERIAL,
        canScrap = true,
        scrapUseTool = true,
        scrapUseSkill = true,
        scrapSize = Dismantle.SCRAP_SIZE,
    }, { __index = ISMoveableSpriteProps })
end

--- Triche des meubles (admin ou debug) : outils non exigés, comme le vanilla.
function Dismantle.isCheat(player)
    return (ISMoveableDefinitions and ISMoveableDefinitions.cheat == true) or player:isMovablesCheat()
end

--- Outils de la définition dans l'inventaire : (outil, outil2). Chacun est un
--- objet, true (liste vide) ou false (absent), comme hasScrapTool.
function Dismantle.tools(player)
    local props = Dismantle.props()
    return props:hasScrapTool(player, false), props:hasScrapTool(player, true)
end

--- Tous les conteneurs du véhicule sont vides.
function Dismantle.isEmpty(vehicle)
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        local container = part and part:getItemContainer()
        if container and not container:isEmpty() then
            return false
        end
    end
    return true
end

--- Personnage au même étage, à MAX_DISTANCE cases au plus du centre.
function Dismantle.isNear(player, vehicle)
    if math.floor(player:getZ()) ~= math.floor(vehicle:getZ()) then
        return false
    end
    local dx = player:getX() - vehicle:getX()
    local dy = player:getY() - vehicle:getY()
    return dx * dx + dy * dy <= Dismantle.MAX_DISTANCE * Dismantle.MAX_DISTANCE
end

--- MP : refuge d'une autre équipe où le démontage est interdit (règle
--- d'ISMoveablesAction:isValid pour le mode « scrap »).
function Dismantle.isProtected(player, vehicle)
    if not (isClient() or isServer()) or not SafeHouse then
        return false
    end
    local square = vehicle:getSquare()
    if not square or not SafeHouse.isSafeHouse(square, player:getUsername(), true) then
        return false
    end
    return not SafeHouse.isSafehouseAllowInteract(square, player)
end

--- Motif de refus (clé de Dismantle.REASONS), ou nil si le démontage est
--- possible. opts.ignoreDistance : menu (le personnage s'approchera).
function Dismantle.check(player, vehicle, opts)
    if not player or not Dismantle.isCrate(vehicle) then
        return "gone"
    end
    if not Dismantle.definition() then
        return "noDefinition"
    end
    if not Dismantle.isEmpty(vehicle) then
        return "notEmpty"
    end
    if not Dismantle.isCheat(player) then
        local tool, tool2 = Dismantle.tools(player)
        if not tool or not tool2 then
            return "noTools"
        end
    end
    if Dismantle.isProtected(player, vehicle) then
        return "safehouse"
    end
    if not (type(opts) == "table" and opts.ignoreDistance) and not Dismantle.isNear(player, vehicle) then
        return "tooFar"
    end
    return nil
end

--- Durée de l'action (unités de maxTime), comme ISMoveablesAction:getDuration.
function Dismantle.duration(player)
    if player:isTimedActionInstant() or Dismantle.isCheat(player) then
        return 1
    end
    return Dismantle.props():getScrapActionTime(player)
end

--- Chance de réussite d'un essai (1 à 100), affichée par le menu.
function Dismantle.chance(player)
    return (Dismantle.props():getScrapSkillChance(player))
end

--- Son de l'action (getScrapSound) : nil quand l'animation le joue.
function Dismantle.playSound(character)
    local def = Dismantle.definition()
    if not def or not def.sound or def.sound == Dismantle.ANIM_SOUND then
        return nil
    end
    if not def.isWav then
        addSound(character, character:getX(), character:getY(), character:getZ(),
            Dismantle.NOISE_RADIUS, Dismantle.NOISE_VOLUME)
    end
    return character:playSound(def.sound)
end

--- Serveur ou solo : revérifie tout, donne matériaux et XP, retire la caisse.
--- Renvoie true si la caisse a été démontée.
function Dismantle.perform(player, vehicle)
    local reason = Dismantle.check(player, vehicle)
    if reason then
        MilitaryDrop.log("dismantle refused (" .. reason .. ") for " .. tostring(player and player:getUsername()))
        if player then
            player:transmitHaloNote(getText(Dismantle.REASONS[reason]), 255, 255, 255, 300)
        end
        return false
    end
    local def = Dismantle.definition()
    local props = Dismantle.props()
    local items = props:getScrapItemsList(player) or { usable = {}, unusable = {} }
    local added
    if def.addToInventory then
        added = props:addAllScrapItemsToInventory(player, items)
    else
        added = props:addAllScrapItemsToSquare(vehicle:getSquare(), items)
    end
    props:scrapGiveXp(player, def)
    -- Chalumeau en main : une utilisation (scrapObjectInternal), si une
    -- définition modifiée l'exige.
    local primary = player:getPrimaryHandItem()
    if primary and primary:hasTag(ItemTag.BLOW_TORCH) then
        primary:UseAndSync()
    end
    if added == 0 then
        props:transmitPlaySound(player, IsoThumpable.GetBreakFurnitureSound(""))
    end
    props:scrapHaloNoteCheck(player, added)
    MilitaryDrop.log(string.format("crate dismantled by %s (%d materials)", tostring(player:getUsername()), added))
    -- Leurre (v1.5) : la sirène de cette caisse se tait (module serveur).
    if MilitaryDrop.Decoy then
        MilitaryDrop.Decoy.onCrateRemoved(vehicle)
    end
    vehicle:permanentlyRemove()
    return true
end

-- ----------------------------------------------------------------------------
-- Action chronométrée
-- ----------------------------------------------------------------------------

if ISBaseTimedAction then
    --- Rangée sous MilitaryDrop : le serveur appelle MilitaryDrop.DismantleAction
    --- .new avec nil à la place de la classe (pz-knowledge multiplayer.md). Les
    --- champs portent le nom des paramètres de new (character, vehicle).
    local Action = ISBaseTimedAction:derive("MilitaryDrop.DismantleAction")
    MilitaryDrop.DismantleAction = Action

    function Action:isValid()
        return Dismantle.check(self.character, self.vehicle) == nil
    end

    function Action:waitToStart()
        self.character:faceThisObject(self.vehicle)
        return self.character:shouldBeTurning()
    end

    function Action:update()
        self.character:faceThisObject(self.vehicle)
        if self.sound and self.sound ~= 0 and not self.character:getEmitter():isPlaying(self.sound) then
            self.sound = Dismantle.playSound(self.character)
        end
        self.character:setMetabolicTarget(Metabolics.UsingTools)
    end

    --- Animation choisie comme ISMoveablesAction:start pour le mode « scrap ».
    function Action:start()
        local def = Dismantle.definition()
        local primary = self.character:getPrimaryHandItem()
        if def and def.recipeAnimNode then
            self:setActionAnim(def.recipeAnimNode)
            self:setOverrideHandModels(def.recipeProp1, def.recipeProp2)
        elseif self.character:hasEquippedTag(ItemTag.BLOW_TORCH) then
            self:setActionAnim("BlowTorch")
            self:setOverrideHandModels(primary, nil)
        elseif self.character:hasEquippedTag(ItemTag.HAMMER) then
            self:setActionAnim("Build")
            self:setOverrideHandModels(primary, nil)
        else
            self:setActionAnim(CharacterActionAnims.Disassemble)
            self:setOverrideHandModels(primary, nil)
        end
        self.sound = Dismantle.playSound(self.character)
    end

    function Action:stopSound()
        if self.sound and self.sound ~= 0 then
            self.character:stopOrTriggerSound(self.sound)
        end
        self.sound = nil
    end

    function Action:stop()
        self:stopSound()
        ISBaseTimedAction.stop(self)
    end

    function Action:perform()
        self:stopSound()
        ISBaseTimedAction.perform(self)
    end

    --- Serveur en MP, local en solo.
    function Action:complete()
        return Dismantle.perform(self.character, self.vehicle)
    end

    function Action:getDuration()
        return Dismantle.duration(self.character)
    end

    function Action.new(_, character, vehicle)
        local o = ISBaseTimedAction.new(Action, character)
        o.vehicle = vehicle
        o.maxTime = o:getDuration()
        return o
    end
end

return Dismantle
