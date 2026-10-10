-- Copie de secours de Belt Walkie-Talkie (batman_BeltRadio 0.1.1), générée par
-- BeltRadio/tools/sync_fallback.py depuis media/lua/shared/BatmanRadio/BatmanRadio_Support.lua :
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

-- Belt Walkie-Talkie (batman_BeltRadio) : partie partagée de l'API publique
-- BatmanRadioSupport, chargée en solo, sur un client MP et sur un serveur
-- dédié (qui n'exécute pas media/lua/client). Le récepteur (client) est dans
-- client/BatmanRadio/BatmanRadio_Core.lua, qui complète la même table.
-- Documentation de l'API : docs/API.md du dépôt.

local Compat = require "MilitaryDrop/BeltRadioFallback/BatmanRadio_Compat"

-- Table conservée si le fichier est rechargé ou si le Core est chargé avant.
BatmanRadioSupport = BatmanRadioSupport or {}
local Support = BatmanRadioSupport

--- Niveau d'API, entier croissant : augmenté à chaque ajout ou changement de
--- l'API publique (docs/API.md). Un mod qui en dépend compare
--- (BatmanRadioSupport.VERSION or 0) >= niveau requis.
Support.VERSION = 1
Support.MOD_ID = "batman_BeltRadio"

-- ----------------------------------------------------------------------------
-- Options sandbox (media/sandbox-options.txt, page BeltRadio)
-- ----------------------------------------------------------------------------

Support.OPTION_PAGE = "BeltRadio"
-- Valeurs par défaut, aussi utilisées quand l'option n'existe pas (copie de
-- secours d'un autre mod sans ce mod, sauvegarde d'avant l'option).
Support.OPTION_DEFAULTS = { MPBubble = true, BeltBattery = true, BeltListening = true }

--- Valeur d'une option du mod, lue à chaque appel : getOptionByName est à jour
--- après un changement en cours de partie (solo et MP), SandboxVars est périmé
--- en solo après l'éditeur d'options (base pz-knowledge, load-warnings.md).
function Support.option(name)
    local options = getSandboxOptions and getSandboxOptions()
    local option = options and options:getOptionByName(Support.OPTION_PAGE .. "." .. name)
    if option then
        local value = option:getValue()
        if value ~= nil then return value end
    end
    local vars = SandboxVars and SandboxVars[Support.OPTION_PAGE]
    if type(vars) == "table" and vars[name] ~= nil then
        return vars[name]
    end
    return Support.OPTION_DEFAULTS[name]
end

--- Option booléenne : seul false la désactive.
function Support.enabled(name)
    return Support.option(name) ~= false
end

-- ----------------------------------------------------------------------------
-- Prédicat d'émission (décision 4 : jamais depuis la ceinture)
-- ----------------------------------------------------------------------------

--- Le joueur peut-il émettre avec cette radio d'inventaire ? Radio portative
--- émettrice, en main (principale ou secondaire) ou portée sur le dos, allumée,
--- alimentée, micro ouvert ; jamais accrochée à la ceinture ni rangée.
--- Renvoie true, ou false et une raison :
---   "notRadio"       pas une radio portative ;
---   "notTransmitter" radio sans émission (getIsTwoWay faux ou NoTransmit) ;
---   "belt"           accrochée (ceinture, emplacement) : à prendre en main ;
---   "stowed"         rangée (inventaire, sac) ;
---   "off"            éteinte ;
---   "battery"        pile absente ou vide ;
---   "micMuted"       micro coupé (client et solo seulement, voir ci-dessous).
--- Mêmes conditions d'appareil que VoiceManagerData (allumée, bidirectionnelle,
--- !isNoTransmit, micro ouvert). Sur un serveur, le micro n'est pas vérifié
--- (setMicIsMuted n'est jamais transmis au serveur) et l'état allumé / la
--- fréquence d'une radio ne sont fiables qu'en main (état appliqué par le
--- serveur aux seules radios tenues en main) : base pz-knowledge,
--- multiplayer.md.
function Support.canTransmitWith(player, radio)
    if player == nil or radio == nil or not instanceof(radio, "Radio") then
        return false, "notRadio"
    end
    local data = radio:getDeviceData()
    if not data or not data:getIsPortable() or data:getIsTelevision() then
        return false, "notRadio"
    end
    if not data:getIsTwoWay() or data:isNoTransmit() then
        return false, "notTransmitter"
    end
    local held = player:getPrimaryHandItem() == radio or player:getSecondaryHandItem() == radio
        or player:getClothingItem_Back() == radio
    if not held then
        if player:isAttachedItem(radio) then
            return false, "belt"
        end
        return false, "stowed"
    end
    if not data:getIsTurnedOn() then
        return false, "off"
    end
    if data:getIsBatteryPowered() and not (data:getHasBattery() and data:getPower() > 0) then
        return false, "battery"
    end
    if not isServer() and not Compat.microphoneAvailable(data) then
        return false, "micMuted"
    end
    return true
end

return Support
