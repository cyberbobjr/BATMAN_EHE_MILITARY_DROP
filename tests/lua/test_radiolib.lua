-- RADIO-08 : Belt Walkie-Talkie (batman_BeltRadio) est un prérequis. Military
-- Drop charge ses modules BatmanRadio/... et s'inscrit auprès de lui ; une
-- version trop ancienne donne un WARN, une fois.

local T = {}

function T.setup()
    SandboxVars = {}
    isClient = function() return false end
    isServer = function() return false end
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
    getText = function(key) return key end
    PRINTED = {}
    print = function(...) PRINTED[#PRINTED + 1] = table.concat({ ... }, " ") end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
end

--- Belt Walkie-Talkie simulé (globale et modules BatmanRadio/...), version donnée.
local function stubBeltRadio(version)
    local registered = {}
    BatmanRadioSupport = { VERSION = version, register = function(id, provider) registered[id] = provider end }
    MODULE_STUBS["BatmanRadio/BatmanRadio_Core"] = BatmanRadioSupport
    MODULE_STUBS["BatmanRadio/BatmanRadio_Support"] = BatmanRadioSupport
    MODULE_STUBS["BatmanRadio/BatmanRadio_Compat"] = { say = function() end }
    return registered
end

function T.military_drop_registers_with_belt_radio()
    local registered = stubBeltRadio(1)
    loadMod("client/MilitaryDrop/MilitaryDrop_BeltRadio.lua")
    assertTrue(registered.MilitaryDrop, "Military Drop inscrit auprès de Belt Walkie-Talkie")
    assertEq(registered.MilitaryDrop.takingActions["MilitaryDrop.ExchangeAction"], "device", "fournisseur complet")
    assertEq(#PRINTED, 0, "version suffisante : aucun avertissement")
end

function T.too_old_belt_radio_warns_once()
    stubBeltRadio(nil) -- avant VERSION
    local RadioLib = require "MilitaryDrop/MilitaryDrop_RadioLib"
    RadioLib.support()
    RadioLib.receiver()
    RadioLib.support()
    assertEq(#PRINTED, 1, "une seule ligne")
    assertTrue(PRINTED[1]:find("WARN", 1, true) and PRINTED[1]:find("batman_BeltRadio", 1, true), PRINTED[1])
    -- Sans canTransmitWith : règle de position seule, ceinture toujours refusée.
    local radio = { kind = "Radio" }
    local player = { getPrimaryHandItem = function() end, getSecondaryHandItem = function() end,
        getClothingItem_Back = function() end, isAttachedItem = function() return true end }
    local ok, reason = RadioLib.canTransmitWith(player, radio)
    assertEq(ok, false, "refus")
    assertEq(reason, "belt", "raison belt")
end

return T
