-- SOURCE COMMUNE : MilitaryDrop/source/radio/lua ; copies générées par sync_radio.py.
-- Un seul gestionnaire global, quel que soit le fichier gagnant / l'ordre des mods.
-- Implémentation propre : utilise DeviceData.update de 42.21, sans copier BWT.
-- Radio.update ne le fait que pour getEquipedRadio() (main/dos). À la ceinture,
-- appeler la même méthode avance lastMinuteStamp : aucun second décompte à la
-- reprise en main. Cette méthode garde aussi les paquets batterie/extinction vanilla.

BatmanBeltRadioBattery = BatmanBeltRadioBattery or {}
local Battery = BatmanBeltRadioBattery
local tracked = Battery.tracked or {}
Battery.tracked = tracked

-- Rechargement Lua / seconde copie : remplacer le handler, sans en ajouter un autre.
if Battery.onTick then Events.OnTick.Remove(Battery.onTick) end
if Battery.reset then
    Events.OnDisconnect.Remove(Battery.reset)
    Events.OnMainMenuEnter.Remove(Battery.reset)
end

local Compat = require "BatmanRadio/BatmanRadio_Compat"

local function attachedDevice(player, item)
    if not item or not instanceof(item, "Radio") or not player:isAttachedItem(item)
        or item:getContainer() ~= player:getInventory() or player:getEquipedRadio() == item
        or player:getPrimaryHandItem() == item or player:getSecondaryHandItem() == item
        or player:getClothingItem_Back() == item then
        return nil
    end
    local data = item:getDeviceData()
    if data and data:getIsPortable() and data:getIsBatteryPowered() and data:getHasBattery() then
        return data
    end
end

function Battery.onTick()
    -- Les clients mettent à jour leurs propres appareils ; jamais les joueurs
    -- distants ou le serveur dédié. Si BWT gère la pile, lui laisser la main.
    if not Compat.features().beltBattery then
        Battery.reset()
        return
    end
    local stamp = getGameTime():getMinutesStamp()
    local present = {}
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player and not player:isDead() then
            local attached = player:getAttachedItems()
            for index = 0, attached:size() - 1 do
                local data = attachedDevice(player, attached:getItemByIndex(index))
                if data and not present[data] then
                    present[data] = true
                    local on = data:getIsTurnedOn()
                    local state = tracked[data]
                    if on and (not state or state.stamp ~= stamp or state.on ~= on) then
                        -- Même appel que Radio.update : appareil d'inventaire,
                        -- joueur à portée. Initialise aussi le compteur dès l'allumage.
                        data:update(false, true)
                    end
                    tracked[data] = { stamp = stamp, on = data:getIsTurnedOn() }
                end
            end
        end
    end
    for data in pairs(tracked) do
        if not present[data] then tracked[data] = nil end
    end
end

function Battery.reset()
    tracked = {}
    Battery.tracked = tracked
end

Events.OnTick.Add(Battery.onTick)
Events.OnDisconnect.Add(Battery.reset)
Events.OnMainMenuEnter.Add(Battery.reset)

return Battery
