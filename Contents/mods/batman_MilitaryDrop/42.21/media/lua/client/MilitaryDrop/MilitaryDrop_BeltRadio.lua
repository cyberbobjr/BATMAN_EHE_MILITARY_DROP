-- MilitaryDrop inscrit ses chaînes et l'ouverture des radios rangées dans le
-- gestionnaire commun. Aucun second menu, wrapper, récepteur ou drain de pile.
require "MilitaryDrop/MilitaryDrop_Core"
require "MilitaryDrop/MilitaryDrop_Exchange"
local Support = require "BatmanRadio/BatmanRadio_Core"
local BeltRadio = setmetatable({}, { __index = Support })
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

Support.register("MilitaryDrop", {
    channels = BeltRadio.channels,
    isStowed = BeltRadio.isStowedMilitary,
    open = BeltRadio.takeAndOpen,
    takingActions = { ["MilitaryDrop.ExchangeAction"] = "device" },
})

return BeltRadio
