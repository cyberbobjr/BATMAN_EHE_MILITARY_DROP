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

        SpawnerTEMP.spawnVehicle(carePackage, heliX, heliY, 0, extraFunctions, nil, "getOutsideSquareFromAbove_vehicle")
        if carePackage == "HTC_MilitarySupplyDrop" then
            local spawnZNumber = ZombRand(MinZSpawn, MaxZSpawn)
            --[[DEBUG]] print("HTC - EHE: spawnHorde :" .. spawnZNumber)
            spawnHorde(heliX - 2, heliY - 2, heliX + 2, heliY + 2, 0, spawnZNumber);
            sendServerCommand("HTC_EHE", "Dropped", { x = heliX, y = heliY })
        end
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
        end
    end
end

local function updateSandboxValues()
    MaxZSpawn = SandboxVars.HTC_EHE_MilitaryDrop.MaxZSpawn
    MinZSpawn = SandboxVars.HTC_EHE_MilitaryDrop.MinZSpawn
end

Events.OnClientCommand.Add(onClientCommand)--/client/ to server
Events.OnGameStart.Add(updateSandboxValues)