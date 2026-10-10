-- MilitaryDrop inscrit ses chaînes et l'ouverture des radios rangées dans le
-- gestionnaire commun. Aucun second menu, wrapper, récepteur ou drain de pile.
-- Gestionnaire commun : Belt Walkie-Talkie s'il est activé, sinon la copie de
-- secours embarquée (MilitaryDrop.RadioLib, RADIO-08) ; même globale
-- BatmanRadioSupport dans les deux cas.
require "MilitaryDrop/MilitaryDrop_Core"
require "MilitaryDrop/MilitaryDrop_Exchange"
require "MilitaryDrop/MilitaryDrop_RadioLib"
-- Charge le récepteur (mod commun ou copie de secours) avant l'inscription.
MilitaryDrop.RadioLib.receiver()
-- Aides du gestionnaire (isPortableRadio...) lues sur la globale à l'appel.
local BeltRadio = setmetatable({}, { __index = function(_, key)
    return BatmanRadioSupport and BatmanRadioSupport[key]
end })
MilitaryDrop.BeltRadio = BeltRadio

--- Radio militaire portative rangée dans l'inventaire du joueur (sacs portés
--- compris), ni en main, ni sur le dos, ni accrochée : le vanilla n'offre pas
--- « Options de l'appareil » (ISInventoryPaneContextMenu.lua:896), or la
--- section « Logistique » de cette fenêtre est le seul accès joueur aux
--- échanges du mod (le menu contextuel ne les propose plus).
function BeltRadio.isStowedMilitary(player, item)
    local Radio = MilitaryDrop.Radio
    if not (Radio and Radio.isMilitary) or not BeltRadio.isPortableRadio(item) or not Radio.isMilitary(item) then
        return false
    end
    if player:isAttachedItem(item) or player:getPrimaryHandItem() == item or player:getSecondaryHandItem() == item
        or player:getClothingItem_Back() == item then
        return false
    end
    local container = item:getContainer()
    return container ~= nil and (container == player:getInventory() or container:isInCharacterInventory(player))
end

--- Radio rangée : le personnage la prend en main (action vanilla,
--- Exchange.takeInHand) et la fenêtre s'ouvre aussitôt ; elle reste ouverte
--- pendant la prise en main (BeltRadio.keepsWindow).
function BeltRadio.takeAndOpen(player, item)
    MilitaryDrop.Exchange.takeInHand(player, item)
    ISRadioAndTvMenu.openRadioPanel(player, item)
end

function BeltRadio.channels()
    local list = {}
    local broadcast = MilitaryDrop.Broadcast
    local station = MilitaryDrop.NumbersStation
    if broadcast and broadcast.channel then list[#list + 1] = broadcast.channel end
    if station and station.channel then list[#list + 1] = station.channel end
    return list
end

--- Fréquences des chaînes connues de ce client, pour la bulle MP d'une radio
--- non tenue (BatmanRadio_Core.onDeviceTextMP). Chaîne créée (solo, hôte) :
--- sa fréquence. Client MP : seulement celles que fixent les options sandbox,
--- publiques (Config.isFixedFrequency). Une fréquence libre tirée par le
--- serveur reste secrète (Config.getChannel ne doit pas servir ici : elle
--- calculerait un candidat sans la graine du serveur) : elle est reconnue à la
--- première ligne reçue (BeltRadio.recognize).
function BeltRadio.frequencies()
    local Config = MilitaryDrop.Config
    local broadcast = MilitaryDrop.Broadcast
    local station = MilitaryDrop.NumbersStation
    local list = {}
    -- Couleur des lignes de la chaîne (fichiers server/, chargés aussi par un client MP).
    local function add(frequency, module)
        local color = module and module.COLOR or {}
        if frequency then
            list[#list + 1] = { frequency = frequency, r = color.r, g = color.g, b = color.b }
        end
    end
    local military = broadcast and broadcast.frequency
    if not military and Config.isFixedFrequency() then
        military = Config.toChannel(Config.get("Frequency"))
    end
    add(military, broadcast)
    local numbers = station and station.frequency
    local configured = tonumber(Config.get("NumbersStationFrequency")) or 0
    if not numbers and configured > 0 and Config.codeMode() == MilitaryDrop.Codes.MODE_WEEKLY_CIPHER then
        numbers = Config.toChannel(configured)
        if numbers == military then -- même décalage que NumbersStation.candidates
            numbers = Config.toChannel((numbers + Config.CHANNEL_STEP) / 1000)
        end
    end
    add(numbers, station)
    return list
end

-- Codes portés par les lignes des deux chaînes (MilitaryDrop_Broadcast.lua,
-- MilitaryDrop_NumbersStation.lua, MilitaryDrop_Announce.lua) -> chaîne.
BeltRadio.LINE_CODES = { MDRP = "broadcast", MDRC = "broadcast", MDCU = "broadcast", MDAY = "broadcast",
    MDTX = "broadcast", MDNS = "station" }

--- Couleur d'une ligne du mod reconnue à ses codes, ou nil : la fréquence
--- libre reste secrète, le client reconnaît la chaîne à la ligne reçue.
function BeltRadio.recognize(codes)
    local kind = BeltRadio.LINE_CODES[string.sub(codes, 1, 4)]
    if not kind then
        return nil
    end
    local module = kind == "station" and MilitaryDrop.NumbersStation or MilitaryDrop.Broadcast
    return module and module.COLOR or {}
end

local PROVIDER = {
    channels = BeltRadio.channels,
    frequencies = BeltRadio.frequencies,
    recognize = BeltRadio.recognize,
    isStowed = BeltRadio.isStowedMilitary,
    open = BeltRadio.takeAndOpen,
    takingActions = { ["MilitaryDrop.ExchangeAction"] = "device" },
}

--- Inscription auprès du gestionnaire ; false s'il n'est pas (encore) chargé.
function BeltRadio.registerProvider()
    local support = BatmanRadioSupport
    if not (support and support.register) then
        return false
    end
    support.register("MilitaryDrop", PROVIDER)
    return true
end

if not BeltRadio.registerProvider() then
    -- Gestionnaire absent au chargement (ordre inattendu) : nouvel essai au
    -- début de la partie, puis abandon signalé dans le journal.
    Events.OnGameStart.Add(function()
        if not BeltRadio.registerProvider() then
            print("[MilitaryDrop] WARN: shared walkie-talkie receiver (BatmanRadioSupport) not loaded;"
                .. " belt walkie-talkie features are unavailable.")
        end
    end)
end

return BeltRadio
