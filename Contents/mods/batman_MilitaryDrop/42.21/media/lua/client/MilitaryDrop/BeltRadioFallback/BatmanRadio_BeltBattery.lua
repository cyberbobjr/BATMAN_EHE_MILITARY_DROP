-- Copie de secours de Belt Walkie-Talkie (batman_BeltRadio 1.0.0), générée par
-- BeltRadio/tools/sync_fallback.py depuis media/lua/client/BatmanRadio/BatmanRadio_BeltBattery.lua :
-- ne pas modifier ici. Elle ne fait rien si batman_BeltRadio est activé (le mod
-- commun s'en charge) ; sinon elle garde les globales BatmanRadioSupport et
-- BatmanBeltRadioBattery, si bien que deux copies de secours (deux mods sans
-- batman_BeltRadio) se remplacent au lieu de s'additionner.
local beltRadioActive = false
do
    local mods = getActivatedMods and getActivatedMods()
    for i = 0, (mods and mods:size() or 0) - 1 do
        if string.gsub(mods:get(i), "^\\", "") == "batman_BeltRadio" then beltRadioActive = true end
    end
end
if beltRadioActive then return end

-- Belt Walkie-Talkie (batman_BeltRadio), source unique du récepteur commun BatmanRadio.
-- Usure de la pile d'un talkie accroché à la ceinture (option sandbox
-- BeltRadio.BeltBattery ; fausse : comportement vanilla, pile figée à la
-- ceinture puis consommation rattrapée par Radio.update à la reprise en main).
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

local Compat = require "MilitaryDrop/BeltRadioFallback/BatmanRadio_Compat"
local Support = require "MilitaryDrop/BeltRadioFallback/BatmanRadio_Support"

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
    -- Option désactivée : rien (relue à chaque tick, changement en cours de partie).
    if not Compat.features().beltBattery or not Support.enabled("BeltBattery") then
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
