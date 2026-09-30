-- MilitaryDrop_Flight : trajectoire (approche, vol stationnaire, départ).

local T = {}

function T.setup()
    SandboxVars = {}
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Flight.lua")
end

local function near(a, b)
    return math.abs(a - b) < 1e-6
end

function T.flight_passes_over_target_on_heading()
    local F = MilitaryDrop.Flight
    local flight = F.new(1, 1000, 2000, 0)
    assertTrue(near(flight.sx, 1000 - F.APPROACH_DISTANCE) and near(flight.sy, 2000), "départ à l'ouest")
    assertTrue(near(flight.ex, 1000 + F.EXIT_DISTANCE) and near(flight.ey, 2000), "sortie à l'est")
end

function T.position_follows_the_three_phases()
    local F = MilitaryDrop.Flight
    local flight = F.new(1, 1000, 2000, 0)
    local approach, hover = F.timeline(flight)
    assertTrue(near(approach, F.APPROACH_DISTANCE / F.SPEED), "durée d'approche")
    local x, _, phase = F.position(flight, approach / 2)
    assertEq(phase, "approach", "mi-approche")
    assertTrue(near(x, 1000 - F.APPROACH_DISTANCE / 2), "à mi-chemin")
    x, _, phase = F.position(flight, approach + hover / 2)
    assertEq(phase, "hover", "stationnaire")
    assertTrue(near(x, 1000), "au-dessus de la cible")
    _, _, phase = F.position(flight, approach + hover + 1)
    assertEq(phase, "leave", "départ")
    _, _, phase = F.position(flight, F.totalTime(flight) + 1)
    assertEq(phase, "done", "terminé")
end

function T.drop_happens_during_hover()
    local F = MilitaryDrop.Flight
    local flight = F.new(1, 0, 0, 1.3)
    local approach, hover = F.timeline(flight)
    local drop = F.dropTime(flight)
    assertTrue(drop > approach and drop < approach + hover, "largage pendant le vol stationnaire")
end

function T.from_args_rejects_incomplete_data()
    local F = MilitaryDrop.Flight
    assertEq(F.fromArgs(nil), nil, "nil")
    assertEq(F.fromArgs({ id = 1 }), nil, "champs manquants")
    local args = F.toArgs(F.new(3, 10, 20, 0))
    args.sx = "x"
    assertEq(F.fromArgs(args), nil, "valeur non numérique")
    local copy = F.fromArgs(F.toArgs(F.new(3, 10, 20, 0)))
    assertEq(copy.id, 3, "copie valide")
end

return T
