-- RADIO-08 : Belt Walkie-Talkie (batman_BeltRadio) facultatif. Activé : la copie
-- de secours MilitaryDrop/BeltRadioFallback ne fait rien et Military Drop
-- s'inscrit auprès du mod commun. Absent : la copie de secours fait le travail.
-- Military Drop et Opération Artemis sans le mod commun : leurs deux copies se
-- remplacent (un seul récepteur). Version trop ancienne : un WARN, une fois.

local T = {}

local function list(items)
    return { size = function() return #items end, get = function(_, i) return items[i + 1] end }
end

-- Ordre du balayage du jeu : shared, puis client.
local FILES = {
    "shared/MilitaryDrop/BeltRadioFallback/BatmanRadio_Compat.lua",
    "shared/MilitaryDrop/BeltRadioFallback/BatmanRadio_Support.lua",
    "client/MilitaryDrop/BeltRadioFallback/BatmanRadio_BeltBattery.lua",
    "client/MilitaryDrop/BeltRadioFallback/BatmanRadio_Core.lua",
}
local EVENTS = { "OnTick", "OnGameStart", "OnDeviceText", "OnFillInventoryObjectContextMenu",
    "OnDisconnect", "OnMainMenuEnter" }

function T.setup()
    SandboxVars = {}
    isClient = function() return false end
    isServer = function() return false end
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
    getText = function(key) return key end
    ACTIVE = {}
    getActivatedMods = function() return list(ACTIVE) end
    ISCollapsableWindow = { update = function() end }
    ORIGINAL_UPDATE = function() end
    ISRadioWindow = { update = ORIGINAL_UPDATE }
    ISRadioAndTvMenu = { openRadioPanel = function() end }
    getNumActivePlayers = function() return 0 end
    PRINTED = {}
    print = function(...) PRINTED[#PRINTED + 1] = table.concat({ ... }, " ") end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
end

local function counts()
    local result = {}
    for _, name in ipairs(EVENTS) do result[name] = listenerCount(name) end
    return result
end

--- Mod commun simulé (globale et modules BatmanRadio/...), version donnée.
local function stubBeltRadio(version)
    local registered = {}
    BatmanRadioSupport = { VERSION = version, register = function(id, provider) registered[id] = provider end }
    MODULE_STUBS["BatmanRadio/BatmanRadio_Core"] = BatmanRadioSupport
    MODULE_STUBS["BatmanRadio/BatmanRadio_Support"] = BatmanRadioSupport
    MODULE_STUBS["BatmanRadio/BatmanRadio_Compat"] = { say = function() end }
    return registered
end

function T.belt_radio_active_leaves_the_fallback_inactive()
    ACTIVE = { "\\batman_SignalSmoke", "\\batman_BeltRadio" }
    for _, rel in ipairs(FILES) do
        assertEq(loadMod(rel), nil, rel .. " : rien renvoyé")
    end
    assertEq(BatmanRadioSupport, nil, "aucune globale du récepteur")
    assertEq(BatmanBeltRadioBattery, nil, "aucune globale de pile")
    for name, count in pairs(counts()) do assertEq(count, 0, "aucun gestionnaire " .. name) end
    assertEq(ISRadioWindow.update, ORIGINAL_UPDATE, "fenêtre radio non enveloppée")
    local registered = stubBeltRadio(1)
    loadMod("client/MilitaryDrop/MilitaryDrop_BeltRadio.lua")
    assertTrue(registered.MilitaryDrop, "Military Drop inscrit auprès du mod commun")
    assertEq(registered.MilitaryDrop.takingActions["MilitaryDrop.ExchangeAction"], "device", "fournisseur complet")
    assertEq(#PRINTED, 0, "version suffisante : aucun avertissement")
end

function T.belt_radio_absent_runs_the_fallback()
    ACTIVE = { "batman_SignalSmoke" }
    loadMod("client/MilitaryDrop/MilitaryDrop_BeltRadio.lua")
    assertTrue(BatmanRadioSupport and BatmanRadioSupport.providers.MilitaryDrop, "inscrit dans la copie de secours")
    assertEq(BatmanRadioSupport.VERSION, 1, "même API que Belt Walkie-Talkie")
    assertTrue(BatmanBeltRadioBattery and BatmanBeltRadioBattery.onTick, "pile à la ceinture")
    local c = counts()
    assertEq(c.OnTick, 1, "pile seulement avant la partie")
    assertEq(c.OnGameStart + c.OnDeviceText + c.OnFillInventoryObjectContextMenu, 3, "récepteur inscrit")
    assertTrue(ISRadioWindow.update ~= ORIGINAL_UPDATE, "fenêtre enveloppée")
    assertEq(BatmanRadioSupport.originalWindowUpdate, ORIGINAL_UPDATE, "sur l'original vanilla")
    assertEq(#PRINTED, 0, "mod commun absent : aucun avertissement")
end

--- Seconde copie de secours : celle d'Opération Artemis si le dépôt est là,
--- sinon celle de Military Drop rechargée (même code, autre chemin).
local function loadSecondCopy()
    local artemis = readArtemisFile("client/Artemis/BeltRadioFallback/BatmanRadio_Core.lua")
    if not artemis then
        for _, rel in ipairs(FILES) do loadMod(rel) end
        return "Military Drop (rechargée)"
    end
    for _, rel in ipairs(FILES) do
        local artemisRel = rel:gsub("MilitaryDrop/", "Artemis/")
        local name = artemisRel:gsub("^%a+/", ""):gsub("%.lua$", "")
        local chunk = assert(loadstring(readArtemisFile(artemisRel), "@" .. artemisRel))
        MODULE_STUBS[name] = chunk() or false
    end
    return "Opération Artemis"
end

function T.two_fallback_copies_make_one_receiver()
    ACTIVE = {}
    loadMod("client/MilitaryDrop/MilitaryDrop_BeltRadio.lua")
    local before, wrapper = counts(), ISRadioWindow.update
    local support, battery = BatmanRadioSupport, BatmanBeltRadioBattery
    local second = loadSecondCopy()
    local after = counts()
    for _, name in ipairs(EVENTS) do
        assertEq(after[name], before[name], second .. " : gestionnaires " .. name .. " remplacés, pas ajoutés")
    end
    assertEq(BatmanRadioSupport, support, "même table BatmanRadioSupport")
    assertEq(BatmanBeltRadioBattery, battery, "même table de pile")
    assertEq(ISRadioWindow.update, wrapper, "fenêtre enveloppée une seule fois")
    assertEq(BatmanRadioSupport.originalWindowUpdate, ORIGINAL_UPDATE, "toujours sur l'original vanilla")
    assertTrue(BatmanRadioSupport.providers.MilitaryDrop, "fournisseur Military Drop conservé")
    triggerEvent("OnGameStart")
    assertEq(listenerCount("OnTick"), 2, "en partie : une pile et un récepteur")
end

function T.too_old_belt_radio_warns_once()
    ACTIVE = { "batman_BeltRadio" }
    stubBeltRadio(nil) -- avant VERSION (copie d'une ancienne version au même chemin)
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
