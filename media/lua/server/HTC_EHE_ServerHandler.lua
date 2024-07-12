if isClient() then
    return
end
require "ExpandedHelicopter01c_MainCore"
require "ExpandedHelicopter01a_MainVariables"
require "ExpandedHelicopter01f_ShadowSystem"
require "ExpandedHelicopter00c_SpawnerAPI"
local eventSoundHandler = require "ExpandedHelicopter01b_Sounds"
local MaxZSpawn = SandboxVars.HTC_EHE_MilitaryDrop.MaxZSpawn
local MinZSpawn = SandboxVars.HTC_EHE_MilitaryDrop.MinZSpawn

--- Override
---Heli drop carePackage
---@param fuzz number
---@return BaseVehicle package
function eHelicopter:dropCarePackage(fuzz)
    fuzz = fuzz or 0

    if not self.dropPackages then
        return
    end

    local carePackage = self.dropPackages[ZombRand(1, #self.dropPackages + 1)]

    local heliX, heliY, _ = self:getXYZAsInt()

    if heliX and heliY then
        local minX, maxX = 2, 3 + fuzz
        if ZombRand(1, 101) <= 50 then
            minX, maxX = -2, 0 - (3 + fuzz)
        end
        heliX = heliX + ZombRand(minX, maxX + 1)
        local minY, maxY = 2, 3 + fuzz
        if ZombRand(1, 101) <= 50 then
            minY, maxY = -2, 0 - (3 + fuzz)
        end
        heliY = heliY + ZombRand(minY, maxY + 1)
    end

    local returned_sq
    local square = getSquare(heliX, heliY, 0) or pseudoSquare:new(heliX, heliY, 0)
    if square then
        ---@type IsoGridSquare
        returned_sq = getOutsideSquareFromAbove_vehicle(square)
        if returned_sq then
            heliX = returned_sq:getX()
            heliY = returned_sq:getY()
        end
    end

    if returned_sq then
        local extraFunctions = { "applyFlaresToEvent" }
        if self.addedFunctionsToEvents then
            local eventFunction = self.currentPresetID .. "OnDrop"--self.addedFunctionsToEvents["OnCrash"]
            if eventFunction then
                table.insert(extraFunctions, eventFunction)
            end
        end
        SpawnerTEMP.spawnVehicle(carePackage, heliX, heliY, 0, extraFunctions, nil, "getOutsideSquareFromAbove_vehicle")
        --[[DEBUG]] print("HTC - EHE: " .. carePackage .. " dropped: " .. heliX .. ", " .. heliY)
        eventSoundHandler:playEventSound(self, "droppingPackage")
        addSound(nil, heliX, heliY, 0, 200, 150)
        eventMarkerHandler.setOrUpdate(getRandomUUID(), "media/ui/airdrop.png", 2000, heliX, heliY)
        self.dropPackages = false
        return true
    end
end

local function onClientCommand(_module, _command, _player, _data)
    if _module == "HTC_EHE" then
        if _command == "CallMilitaryDrop" then
            print("HTC - EHE: Receive command " .. _module .. " " .. _command)
            local heli = getFreeHelicopter("HTC_military_drop")
            print("HTC - EHE: Launch Military Drop " .. _player:getUsername())
            heli:launch(_player)

            local GT = getGameTime()
            local DAY = GT:getNightsSurvived()
            local HOUR = GT:getHour()

            HOUR = HOUR + 8 -- return the helico after 8 hours
            if HOUR > 24 then
                HOUR = HOUR - 24
                DAY = DAY + 1
            end

            heli.forceUnlaunchTime = { DAY, HOUR }
            --heli.forceUnlaunchTime = false --for preventing the return after 2 hours
        end
    end
end

local function updateSandboxValues()
    MaxZSpawn = SandboxVars.HTC_EHE_MilitaryDrop.MaxZSpawn
    MinZSpawn = SandboxVars.HTC_EHE_MilitaryDrop.MinZSpawn
end

Events.OnClientCommand.Add(onClientCommand)--/client/ to server
Events.OnGameStart.Add(updateSandboxValues)