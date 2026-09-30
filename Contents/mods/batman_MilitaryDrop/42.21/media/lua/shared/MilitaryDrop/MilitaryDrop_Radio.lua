-- ============================================================================
-- Military Drop — radios militaires
--
-- Radio militaire = appareil « haut de gamme » vanilla (DeviceData:getIsHighTier :
-- WalkieTalkie5, ManPackRadio, HamRadio2). Deux formes :
--   * objet d'inventaire (Radio) : porté en main ou dans l'inventaire principal.
--     En MP, le client n'envoie l'état d'un appareil d'inventaire (allumage,
--     canal) au serveur que dans ces deux cas (DeviceData.sendDeviceDataStatePacket,
--     42.21) : le serveur ne peut pas juger une radio rangée dans un sac ;
--   * appareil posé (IsoWaveSignal), à MAX_WORLD_DISTANCE cases au plus.
--
-- Le client désigne l'appareil par une référence ; le serveur la résout
-- lui-même et revérifie tout.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Core"

local Radio = {}
MilitaryDrop.Radio = Radio

Radio.MAX_WORLD_DISTANCE = 2

function Radio.isInventoryRadio(object)
    return object ~= nil and instanceof(object, "Radio")
end

function Radio.isWorldRadio(object)
    return object ~= nil and instanceof(object, "IsoWaveSignal")
end

--- L'objet d'inventaire est en main ou dans l'inventaire principal du joueur.
function Radio.isCarried(player, item)
    return item == player:getPrimaryHandItem() or item == player:getSecondaryHandItem()
        or item:getContainer() == player:getInventory()
end

--- L'appareil posé est assez proche du joueur, au même étage.
function Radio.isNear(player, object)
    local square = object:getSquare()
    if not square then
        return false
    end
    return math.floor(player:getZ()) == square:getZ()
        and math.abs(player:getX() - (square:getX() + 0.5)) <= Radio.MAX_WORLD_DISTANCE + 0.5
        and math.abs(player:getY() - (square:getY() + 0.5)) <= Radio.MAX_WORLD_DISTANCE + 0.5
end

--- Radio militaire utilisable pour un appel (sans regarder l'allumage ni le canal).
function Radio.isMilitary(object)
    local data = object and object:getDeviceData()
    if not data or not data:getIsHighTier() then
        return false
    end
    if Radio.isInventoryRadio(object) then
        -- Une radio fixe (HamRadio2) ne sert que posée.
        return data:getIsPortable()
    end
    return Radio.isWorldRadio(object)
end

--- Motif de refus, ou nil si l'appareil peut appeler sur ce canal.
function Radio.status(object, channel)
    if not Radio.isMilitary(object) then
        return "notMilitary"
    end
    local data = object:getDeviceData()
    if not data:getIsTurnedOn() then
        return "radioOff"
    end
    if data:getChannel() ~= channel then
        return "wrongFrequency"
    end
    return nil
end

--- Référence transmissible au serveur (client).
function Radio.makeRef(object)
    if Radio.isInventoryRadio(object) then
        return { kind = "item", id = object:getID() }
    end
    local square = object:getSquare()
    return {
        kind = "world",
        x = square:getX(), y = square:getY(), z = square:getZ(),
        index = square:getObjects():indexOf(object),
    }
end

local function isInteger(value)
    return type(value) == "number" and value == math.floor(value)
end

--- Appareil désigné par une référence du client, s'il est bien à portée du
--- joueur (serveur ou solo). Toute donnée incohérente donne nil.
function Radio.resolve(player, ref)
    if type(ref) ~= "table" then
        return nil
    end
    if ref.kind == "item" and isInteger(ref.id) then
        -- Pas d'ipairs sur les deux mains : il s'arrête à une main vide (nil).
        local hands = { player:getPrimaryHandItem(), player:getSecondaryHandItem() }
        for i = 1, 2 do
            local item = hands[i]
            if item and item:getID() == ref.id and Radio.isInventoryRadio(item) then
                return item
            end
        end
        local item = player:getInventory():getItemWithID(ref.id)
        if Radio.isInventoryRadio(item) then
            return item
        end
        return nil
    end
    if ref.kind == "world" and isInteger(ref.x) and isInteger(ref.y) and isInteger(ref.z) and isInteger(ref.index) then
        local square = getCell():getGridSquare(ref.x, ref.y, ref.z)
        local objects = square and square:getObjects()
        if not objects or ref.index < 0 or ref.index >= objects:size() then
            return nil
        end
        local object = objects:get(ref.index)
        if Radio.isWorldRadio(object) and Radio.isNear(player, object) then
            return object
        end
    end
    return nil
end

return Radio
