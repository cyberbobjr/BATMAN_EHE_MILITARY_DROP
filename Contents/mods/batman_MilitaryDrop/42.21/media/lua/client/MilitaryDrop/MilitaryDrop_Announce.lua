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
--
-- Reconnaissance (SRC-03) : même principe. Le serveur envoie la grille à tous
-- (ReconAnnounce, { id, x, y }, MilitaryDrop.Broadcast.reconAnnounced) et
-- l'annonce de la mission porte le code RECON_CODE ; symbole « Eye », bleu,
-- posé une fois par mission (id), seulement si une radio du joueur l'entend.
-- Un talkie accroché à la ceinture compte aussi (MilitaryDrop_BeltRadio.lua
-- en solo, le vanilla sur un client MP).
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Core"

local Announce = {}
MilitaryDrop.Announce = Announce

Announce.CODE = "MDRP"
Announce.SYMBOL = "Target"
Announce.COLOR = { r = 0.2, g = 0.55, b = 0.2, a = 1 }
-- Reconnaissance : code de 4 caractères (ignoré par ISRadioInteractions) et
-- symbole vanilla distinct (MapSymbolDefinitions).
Announce.RECON_CODE = "MDRC"
Announce.RECON_SYMBOL = "Eye"
Announce.RECON_COLOR = { r = 0.15, g = 0.35, b = 0.75, a = 1 }
-- Radio posée : OnDeviceText donne sa position, même loin du joueur (solo).
Announce.HEARING_DISTANCE = 5

local lastDrop = nil
local lastRecon = nil
-- Missions de reconnaissance déjà marquées (id → true) : une fois par mission.
local markedRecons = {}
local symbolsApi = nil

function Announce.onDropAnnounce(args)
    if type(args) == "table" and type(args.x) == "number" and type(args.y) == "number" then
        lastDrop = { x = args.x, y = args.y, marked = false }
    end
end

function Announce.onReconAnnounce(args)
    if type(args) == "table" and type(args.id) == "string" and type(args.x) == "number"
        and type(args.y) == "number" then
        lastRecon = { id = args.id, x = args.x, y = args.y, marked = markedRecons[args.id] == true }
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

--- Ajoute le symbole (par défaut celui du largage), sauf s'il existe déjà à
--- cet endroit.
function Announce.markMap(x, y, symbolId, color)
    symbolId = symbolId or Announce.SYMBOL
    local api = getSymbolsApi()
    for i = 0, api:getSymbolCount() - 1 do
        local symbol = api:getSymbolByIndex(i)
        if symbol:isTexture() and symbol:getSymbolID() == symbolId
            and math.floor(symbol:getWorldX()) == x and math.floor(symbol:getWorldY()) == y then
            return false
        end
    end
    local symbol = api:addTexture(symbolId, x, y)
    local c = color or Announce.COLOR
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

local function hasCode(codes, code)
    return type(codes) == "string" and string.find(codes, code, 1, true) ~= nil
end

function Announce.onDeviceText(_, codes, x, y, z)
    local drop = lastDrop and not lastDrop.marked and hasCode(codes, Announce.CODE)
    local recon = lastRecon and not lastRecon.marked and hasCode(codes, Announce.RECON_CODE)
    if not (drop or recon) or not heardByLocalPlayer(x, y, z) then
        return
    end
    if drop then
        lastDrop.marked = true
        Announce.markMap(lastDrop.x, lastDrop.y)
        MilitaryDrop.log("drop marked on the map at " .. lastDrop.x .. "," .. lastDrop.y)
    end
    if recon then
        lastRecon.marked = true
        markedRecons[lastRecon.id] = true
        Announce.markMap(lastRecon.x, lastRecon.y, Announce.RECON_SYMBOL, Announce.RECON_COLOR)
        MilitaryDrop.log("recon " .. lastRecon.id .. " marked on the map at " .. lastRecon.x .. "," .. lastRecon.y)
    end
end

Events.OnDeviceText.Add(Announce.onDeviceText)

return Announce
