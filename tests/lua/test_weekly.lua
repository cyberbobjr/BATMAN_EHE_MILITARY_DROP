local T = {}
function T.setup()
    SandboxVars = { MilitaryDrop = {} }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Weekly.lua")
    W = MilitaryDrop.Weekly
end
function T.monday_rollover_and_two_distinct_vanilla_categories()
    local C = MilitaryDrop.Codes
    local sunday = C.weekOf(C.clockHours(1993, 6, 17, 23.99))
    local monday = C.weekOf(C.clockHours(1993, 6, 18, 0))
    assertEq(monday, sunday + 1)
    for week = sunday, sunday + 30 do
        local offer = W.current(week)
        assertEq(#offer.categories, 2)
        assertTrue(offer.categories[1] ~= offer.categories[2])
        assertTrue(offer.categories[1] ~= "cure" and offer.categories[2] ~= "cure")
    end
    assertTrue(W.current(sunday).categories[1] ~= W.current(monday).categories[1])
end
function T.zero_bonus_and_percentage_scaling_do_not_reward_special_cure()
    local counts, values = { cure = 100 }, { cure = 25 }
    assertEq(W.bonus(counts, values, 100, 1), 0)
    local category = W.current(1).categories[1]
    counts[category], values[category] = 4, 3
    assertEq(W.bonus(counts, values, 200, 1), 12)
    SandboxVars.MilitaryDrop.WeeklyBonusPercent = 0
    assertEq(W.bonus(counts, values, 200, 1), 0)
end
return T
