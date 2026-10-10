-- ============================================================================
-- Military Drop — récepteur commun des talkies-walkies (RADIO-08)
--
-- Belt Walkie-Talkie (batman_BeltRadio) est facultatif, sans require= dans
-- mod.info : s'il est activé, Military Drop utilise ses modules
-- (BatmanRadio/...) ; sinon la copie de secours embarquée
-- (MilitaryDrop/BeltRadioFallback/..., générée par
-- BeltRadio/tools/sync_fallback.py), qui ne fait rien quand le mod commun est
-- activé. Les deux remplissent la même globale BatmanRadioSupport.
-- Chargé partout (shared) : canTransmitWith sert aussi au serveur.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Core"

local RadioLib = {}
MilitaryDrop.RadioLib = RadioLib

RadioLib.MOD_ID = "batman_BeltRadio"
RadioLib.FALLBACK = "MilitaryDrop/BeltRadioFallback/"
-- Niveau d'API attendu de Belt Walkie-Talkie (BatmanRadioSupport.VERSION).
RadioLib.REQUIRED_VERSION = 1

local active = nil
local warned = false

--- batman_BeltRadio est activé (liste fixe pendant une partie : mise en cache).
function RadioLib.beltRadioActive()
    if active == nil then
        active = false
        local mods = getActivatedMods and getActivatedMods()
        for i = 0, (mods and mods:size() or 0) - 1 do
            if string.gsub(mods:get(i), "^\\", "") == RadioLib.MOD_ID then
                active = true
            end
        end
    end
    return active
end

--- Module du récepteur (BatmanRadio_Compat, _Support, _Core) : celui du mod
--- commun s'il est activé, sinon la copie de secours.
function RadioLib.module(name)
    local prefix = RadioLib.beltRadioActive() and "BatmanRadio/" or RadioLib.FALLBACK
    return require(prefix .. name)
end

--- Mod commun activé mais trop ancien : une ligne WARN dans le journal, une fois.
function RadioLib.checkVersion()
    if warned or not RadioLib.beltRadioActive() then
        return
    end
    local version = BatmanRadioSupport and BatmanRadioSupport.VERSION
    if (tonumber(version) or 0) < RadioLib.REQUIRED_VERSION then
        warned = true
        print("[MilitaryDrop] WARN: Belt Walkie-Talkie (" .. RadioLib.MOD_ID .. ") API version "
            .. RadioLib.REQUIRED_VERSION .. " expected, found " .. tostring(version)
            .. "; please update Belt Walkie-Talkie.")
    end
end

--- Compatibilité Better Walkie Talkies (say, microphoneAvailable).
function RadioLib.compat()
    return RadioLib.module("BatmanRadio_Compat")
end

--- Partie partagée de l'API (canTransmitWith, options), client et serveur.
function RadioLib.support()
    RadioLib.module("BatmanRadio_Support")
    RadioLib.checkVersion()
    return BatmanRadioSupport
end

--- Récepteur (client) : register, menu, fenêtre, écoute à la ceinture.
function RadioLib.receiver()
    local receiver = RadioLib.module("BatmanRadio_Core")
    RadioLib.checkVersion()
    return receiver or BatmanRadioSupport
end

--- Prédicat d'émission commun (décision 4 : jamais depuis la ceinture).
--- Renvoie true, ou false et une raison ("belt", "stowed"...) : voir
--- BatmanRadioSupport.canTransmitWith (docs/API.md de Belt Walkie-Talkie).
function RadioLib.canTransmitWith(player, radio)
    local support = RadioLib.support()
    if support and support.canTransmitWith then
        return support.canTransmitWith(player, radio)
    end
    -- API absente (version trop ancienne, déjà signalée) : règle de position seule.
    if player:getPrimaryHandItem() == radio or player:getSecondaryHandItem() == radio
        or player:getClothingItem_Back() == radio then
        return true
    end
    return false, player:isAttachedItem(radio) and "belt" or "stowed"
end

return RadioLib
