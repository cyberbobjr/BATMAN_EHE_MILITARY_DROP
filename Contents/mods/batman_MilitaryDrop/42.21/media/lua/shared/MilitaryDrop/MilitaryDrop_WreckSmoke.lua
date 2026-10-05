-- Une seule fumée locale par case, renouvelée avant son stade invisible.
require "MilitaryDrop/MilitaryDrop_Core"
local Smoke = MilitaryDrop.WreckSmoke or {}
if Smoke.onServerCommand then Events.OnServerCommand.Remove(Smoke.onServerCommand) end
MilitaryDrop.WreckSmoke = Smoke
Smoke.KEY = "MilitaryDrop_crashSmoke"
Smoke.LIFE, Smoke.ENERGY = 2400, 20

function Smoke.show(args)
    if isServer() then return end
    if type(args) ~= "table" or type(args.id) ~= "string"
        or type(args.x) ~= "number" or type(args.y) ~= "number" then return end
    local square = getCell():getGridSquare(args.x, args.y, 0)
    if not square then return end
    local previous = square:getFire()
    if previous and previous:getModData()[Smoke.KEY] == args.id then
        if previous:getLife() > Smoke.LIFE * 0.78 then return end
        previous:extinctFire()
    end
    -- Ne pas supprimer un vrai incendie ou une fumée d'un autre système.
    if not IsoFire.CanAddSmoke(square, true) then return end
    local smoke = IsoFire.new(getCell(), square, true, Smoke.ENERGY, Smoke.LIFE, true)
    smoke:getModData()[Smoke.KEY] = args.id
    IsoFireManager.Add(smoke)
    square:AddTileObject(smoke)
end

function Smoke.onServerCommand(module, command, args)
    if module == "MilitaryDrop" and command == "WreckSmoke" then Smoke.show(args) end
end

if isClient() then Events.OnServerCommand.Add(Smoke.onServerCommand) end
return Smoke
