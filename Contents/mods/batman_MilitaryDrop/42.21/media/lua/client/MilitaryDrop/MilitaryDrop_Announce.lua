-- ============================================================================
-- Military Drop — repère de largage sur la carte des joueurs à l'écoute
--
-- Le serveur envoie les coordonnées à tous (DropAnnounce) et diffuse les
-- lignes de la chaîne militaire avec le code MilitaryDrop.Announce.CODE. Un
-- client ne marque sa carte que si l'une de ses radios reçoit vraiment une de
-- ces lignes (OnDeviceText : allumée, bon canal, volume > 0, pas sourd, pas
-- brouillée par un orage), et seulement une fois par largage.
--
-- Symbole « Target » ajouté par l'API de symboles d'une carte cachée (sans
-- ouvrir la carte du monde) : sauvegardé comme une note du joueur, qui peut
-- l'effacer.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Core"

local Announce = {}
MilitaryDrop.Announce = Announce

Announce.CODE = "MDRP"
Announce.SYMBOL = "Target"
Announce.COLOR = { r = 0.2, g = 0.55, b = 0.2, a = 1 }
-- Radio posée : OnDeviceText donne sa position, même loin du joueur (solo).
Announce.HEARING_DISTANCE = 5

local lastDrop = nil
local symbolsApi = nil

function Announce.onDropAnnounce(args)
    if type(args) == "table" and type(args.x) == "number" and type(args.y) == "number" then
        lastDrop = { x = args.x, y = args.y, marked = false }
    end
end

local function getSymbolsApi()
    if not symbolsApi then
        local ui = {}
        ui.javaObject = UIWorldMap.new(ui)
        local mapApi = ui.javaObject:getAPIv3()
        mapApi:setMapItem(MapItem.getSingleton())
        symbolsApi = mapApi:getSymbolsAPIv2()
    end
    return symbolsApi
end

--- Ajoute le symbole, sauf s'il existe déjà à cet endroit.
function Announce.markMap(x, y)
    local api = getSymbolsApi()
    for i = 0, api:getSymbolCount() - 1 do
        local symbol = api:getSymbolByIndex(i)
        if symbol:isTexture() and symbol:getSymbolID() == Announce.SYMBOL
            and math.floor(symbol:getWorldX()) == x and math.floor(symbol:getWorldY()) == y then
            return false
        end
    end
    local symbol = api:addTexture(Announce.SYMBOL, x, y)
    local c = Announce.COLOR
    symbol:setRGBA(c.r, c.g, c.b, c.a)
    symbol:setAnchor(0.5, 0.5)
    return true
end

--- Un joueur local entend l'appareil : radio portée (x = -1), ou posée assez près.
local function heardByLocalPlayer(x, y, z)
    if x == -1 then
        return true
    end
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        -- OnDeviceText donne des flottants (getX/getY/getZ de l'appareil).
        if player and math.floor(player:getZ()) == math.floor(z)
            and math.abs(player:getX() - x) <= Announce.HEARING_DISTANCE
            and math.abs(player:getY() - y) <= Announce.HEARING_DISTANCE then
            return true
        end
    end
    return false
end

function Announce.onDeviceText(_, codes, x, y, z)
    if not lastDrop or lastDrop.marked or type(codes) ~= "string"
        or not string.find(codes, Announce.CODE, 1, true) then
        return
    end
    if not heardByLocalPlayer(x, y, z) then
        return
    end
    lastDrop.marked = true
    Announce.markMap(lastDrop.x, lastDrop.y)
    MilitaryDrop.log("drop marked on the map at " .. lastDrop.x .. "," .. lastDrop.y)
end

Events.OnDeviceText.Add(Announce.onDeviceText)

return Announce
