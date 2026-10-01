-- ============================================================================
-- Military Drop — leurre : règles communes de la sirène et action « Couper la
-- sirène » (client et serveur)
--
-- MilitaryDrop.SirenRules : portées partagées par le serveur
-- (MilitaryDrop_Decoy.lua) et le client (MilitaryDrop_Siren.lua).
--
-- MP : action chronométrée B42 rangée sous MilitaryDrop (voir pz-knowledge
-- multiplayer.md). Le serveur la reconstruit par MilitaryDrop.SirenAction
-- .new(_, character, sirenId) : seul le numéro de la sirène voyage, jamais sa
-- position. Le serveur n'appelle jamais isValid : complete() confie tout à
-- MilitaryDrop.Decoy.stopByPlayer, qui revérifie la sirène active, l'étage et
-- la distance à SA position. En solo, même chemin (perform puis complete).
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MilitaryDrop/MilitaryDrop_Core"

local Rules = {}
MilitaryDrop.SirenRules = Rules

-- Distance maximale (cases) entre le personnage et la sirène pour la couper,
-- vérifiée par le serveur. La zone d'accès au coffre de la caisse s'étend à
-- ~1,8 case de son centre.
Rules.STOP_DISTANCE = 3
-- La position d'une sirène n'est envoyée qu'aux joueurs à HEAR_RANGE cases au
-- plus ; SirenOff part au-delà de HEAR_RANGE + HEAR_MARGIN (pas de va-et-vient
-- en bordure). Son vanilla VehicleSirenWall : distanceMax = 500.
Rules.HEAR_RANGE = 300
Rules.HEAR_MARGIN = 30
-- Durée de l'action (unités de maxTime : ~48 par seconde réelle à vitesse 1).
Rules.STOP_DURATION = 200

--- Personnage au même étage, à STOP_DISTANCE cases au plus de (x, y).
function Rules.isNear(character, x, y, z)
    if not character or type(x) ~= "number" or type(y) ~= "number" then
        return false
    end
    if math.floor(character:getZ()) ~= math.floor(tonumber(z) or 0) then
        return false
    end
    local dx = character:getX() - x
    local dy = character:getY() - y
    return dx * dx + dy * dy <= Rules.STOP_DISTANCE * Rules.STOP_DISTANCE
end

-- ----------------------------------------------------------------------------
-- Action chronométrée
-- ----------------------------------------------------------------------------

if ISBaseTimedAction then
    --- Rangée sous MilitaryDrop : le serveur appelle MilitaryDrop.SirenAction.new
    --- avec nil à la place de la classe. Les champs portent le nom des
    --- paramètres de new (character, sirenId).
    local Action = ISBaseTimedAction:derive("MilitaryDrop.SirenAction")
    MilitaryDrop.SirenAction = Action

    --- Sirène connue du client (position reçue), ou nil (serveur, ou sirène
    --- coupée entre-temps).
    function Action:siren()
        local Siren = MilitaryDrop.Siren
        return Siren and Siren.get(self.sirenId) or nil
    end

    --- Client et solo seulement : le serveur ne l'appelle jamais.
    function Action:isValid()
        local siren = self:siren()
        return siren ~= nil and Rules.isNear(self.character, siren.x, siren.y, siren.z)
    end

    function Action:faceSiren()
        local siren = self:siren()
        if siren then
            self.character:faceLocation(siren.x, siren.y)
        end
    end

    function Action:waitToStart()
        self:faceSiren()
        return self.character:shouldBeTurning()
    end

    function Action:update()
        self:faceSiren()
        self.character:setMetabolicTarget(Metabolics.LightWork)
    end

    function Action:start()
        self:setActionAnim(CharacterActionAnims.Disassemble)
    end

    function Action:stop()
        ISBaseTimedAction.stop(self)
    end

    function Action:perform()
        ISBaseTimedAction.perform(self)
    end

    --- Serveur en MP, local en solo : MilitaryDrop.Decoy revérifie tout.
    function Action:complete()
        local Decoy = MilitaryDrop.Decoy
        if not Decoy then
            return false
        end
        return Decoy.stopByPlayer(self.character, self.sirenId)
    end

    function Action:getDuration()
        if self.character:isTimedActionInstant() then
            return 1
        end
        return Rules.STOP_DURATION
    end

    function Action.new(_, character, sirenId)
        local o = ISBaseTimedAction.new(Action, character)
        o.sirenId = sirenId
        o.maxTime = o:getDuration()
        return o
    end
end

return Rules
