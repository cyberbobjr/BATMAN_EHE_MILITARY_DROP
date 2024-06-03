require "ISUI/Maps/ISMap"

HTC_EHE = {}

HTC_EHE.drawSymbol = function(x, y, symbolName, playerNum)
    if not ISWorldMap_instance then
        ISWorldMap.ShowWorldMap(playerNum)
        ISWorldMap.HideWorldMap(playerNum)
    end
    local newSymbol = {}
    newSymbol.symbol = symbolName
    newSymbol.r = ISWorldMap_instance.symbolsUI.currentColor:getR()
    newSymbol.g = ISWorldMap_instance.symbolsUI.currentColor:getG()
    newSymbol.b = ISWorldMap_instance.symbolsUI.currentColor:getB()
    local textureSymbol = ISWorldMap_instance.mapAPI:getSymbolsAPI():addTexture(newSymbol.symbol, x, y)
    textureSymbol:setRGBA(newSymbol.r, newSymbol.g, newSymbol.b, 1.0)
    textureSymbol:setAnchor(0.5, 0.5)
    textureSymbol:setScale(ISMap.SCALE)
end
---@param isoRadio IsoRadio
HTC_EHE.call_drop = function(isoRadio, player)
    local playerObj = getSpecificPlayer(player)
    local dataPlayer = playerObj:getModData();
    local currentHour = getGameTime():getWorldAgeHours()
    local hoursSinceLastCall = 168

    -- Définir la dernière heure d'appel si elle n'existe pas
    if not dataPlayer['HTC_EHE_last_drop_call'] then
        dataPlayer['HTC_EHE_last_drop_call'] = currentHour
    else
        hoursSinceLastCall = currentHour - dataPlayer['HTC_EHE_last_drop_call']
    end

    -- Calculer l'intervalle depuis le dernier appel
    if isDebugEnabled() or isAdmin() then
        print("HTC_EHE - hoursSinceLastCall : " .. hoursSinceLastCall)
        HTC_EHE.drop(isoRadio, playerObj)
        return
    end
    if hoursSinceLastCall >= 168 then
        HTC_EHE.drop(isoRadio, playerObj)
    else
        playerObj:Say(getText("IGUI_HTC_EHE_Call_too_short"));
    end
end

---@param isoRadio IsoRadio
HTC_EHE.drop = function(isoRadio, playerObj)
    local randomIndex = ZombRand(5) + 1
    local selectedPhraseKey = "IGUI_HTC_EHE_Call_drop_" .. randomIndex
    local selectedPhrase = getText(selectedPhraseKey)
    local isRadioOn = isoRadio:getDeviceData():getIsTurnedOn()
    playerObj:Say(selectedPhrase);

    if not isRadioOn then
        isoRadio:getDeviceData():setIsTurnedOn(true)
        timer:Simple(10, function()
            isoRadio:getDeviceData():setIsTurnedOn(false)
        end)
    end

    timer:Simple(5, function()
        local ackRandomIndex = ZombRand(5) + 1
        local selectedAckPhraseKey = "IGUI_HTC_EHE_Ack_drop_" .. ackRandomIndex
        local selectedAckPhrase = getText(selectedAckPhraseKey)
        if isoRadio:getDeviceData():getIsTurnedOn() then
            isoRadio:AddDeviceText(selectedAckPhrase, 1, 0, 0, nil, nil, 10)
        end
    end)
    local frequency = isoRadio:getDeviceData():getChannel()
    sendClientCommand(getPlayer(), 'HTC_EHE', 'CallMilitaryDrop', { frequency = frequency })
end
HTC_EHE.getIsoRadiosInPlayerCell = function(isTurningOn, frequency)
    local radios = {}
    local cell = getCell()
    if not cell then
        return radios
    end

    for x = cell:getMinX(), cell:getMaxX() do
        for y = cell:getMinY(), cell:getMaxY() do
            for z = cell:getMinZ(), cell:getMaxZ() do
                local square = cell:getGridSquare(x, y, z)
                if square then
                    for i = 0, square:getObjects():size() - 1 do
                        local obj = square:getObjects():get(i)
                        if instanceof(obj, "IsoRadio") then
                            local deviceData = obj:getDeviceData()
                            if deviceData:getIsHighTier() and (not isTurningOn or deviceData:getIsTurnedOn()) then
                                if not deviceData:getIsPortable() or deviceData:getChannel() == frequency then
                                    table.insert(radios, obj)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return radios
end

local function addRadioOption(context, isoRadio, player)
    local tooltip = ISWorldObjectContextMenu.addToolTip()
    local deviceData = isoRadio:getDeviceData()
    local isTurnedOn = deviceData:getIsTurnedOn()

    if not isTurnedOn then
        local option = context:addOption(getText("IGUI_HTC_EHE_Ask_drop"))
        tooltip.description = getText("IGUI_HTC_EHE_Turn_on")
        option.notAvailable = true
        option.toolTip = tooltip
    else
        local option = context:addOption(getText("IGUI_HTC_EHE_Ask_drop"), isoRadio, HTC_EHE.call_drop, player, isoRadio)
        tooltip.description = getText("IGUI_HTC_EHE_Drop_tooltip")
        option.toolTip = tooltip
    end
end

local function checkEmergencyRadioWorld(player, context, worldObjects)
    local square
    local isoRadio

    for _, v in ipairs(worldObjects) do
        square = v:getSquare()
    end

    for i = 0, square:getObjects():size() - 1 do
        local object = square:getObjects():get(i)
        if object and instanceof(object, "IsoRadio") then
            local deviceData = object:getDeviceData()
            if deviceData:getIsHighTier() then
                isoRadio = object
                break
            end
        end
    end

    if isoRadio then
        addRadioOption(context, isoRadio, player)
    end
end

local function checkEmergencyRadio(player, context, _items)
    local itemObj
    local isoRadio

    for _, items in ipairs(_items) do
        if not instanceof(items, "InventoryItem") then
            itemObj = items.items[1]
        else
            itemObj = items
        end

        if itemObj and itemObj:getFullType() == "Radio.WalkieTalkie5" then
            isoRadio = itemObj
            break
        end
    end

    if isoRadio then
        addRadioOption(context, isoRadio, player)
    end
end

local function onCommand(_module, _command, _data)
    if _module == "HTC_EHE" then
        if _command == "Dropped" then
            if getDebug() then
                print("HTC_EHE - debug Dropped : " .. _data.x .. "/" .. _data.y)
            end
            local radios = HTC_EHE.getIsoRadiosInPlayerCell(true, _data.frequency)
            local ackPhrase = string.format(getText("IGUI_HTC_EHE_dropped"), _data.x, _data.y)
            local playerNum = getPlayer():getPlayerNum()
            local radioInPlayerInventory = getPlayer():getInventory():getItemFromType("Radio.WalkieTalkie5", true, true)

            if #radios > 0 or radioInPlayerInventory then
                HTC_EHE.drawSymbol(_data.x, _data.y, "Target", playerNum)
            end
            if radioInPlayerInventory then
                timer:Create("SomeUniqueTimerNameTalkieWalkie" .. i, 5, 3, function()
                    radioInPlayerInventory:AddDeviceText(ackPhrase, 0, 1, 0, nil, nil, 10)
                end)
            end
            for i, radio in ipairs(radios) do
                timer:Create("SomeUniqueTimerNameRadio" .. i, 5, 3, function()
                    if radio then
                        radio:AddDeviceText(ackPhrase, 0, 1, 0, nil, nil, 10)
                        radio:Say(ackPhrase)
                    end
                end)
            end
        end
    end
end
Events.OnFillInventoryObjectContextMenu.Add(checkEmergencyRadio);
Events.OnFillWorldObjectContextMenu.Add(checkEmergencyRadioWorld)
Events.OnServerCommand.Add(onCommand)--/server/ to client