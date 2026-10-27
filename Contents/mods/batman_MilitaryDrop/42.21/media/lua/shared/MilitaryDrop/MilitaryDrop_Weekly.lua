require "MilitaryDrop/MilitaryDrop_Codes"
local W = {}
MilitaryDrop.Weekly = W
local CATEGORIES = { "identity", "stashMap", "gasMask", "papers", "gasMaskFilter", "scba" }
MilitaryDrop.Config.addDefaults({ WeeklyBonusPercent = 50 })

function W.week()
    return MilitaryDrop.Codes.weekOf(MilitaryDrop.Codes.gameClock(getGameTime()))
end
function W.current(week)
    week = week or W.week()
    local i = (week % #CATEGORIES) + 1
    return { week = week, categories = { CATEGORIES[i], CATEGORIES[i % #CATEGORIES + 1] },
        percent = math.max(0, math.min(200, tonumber(MilitaryDrop.Config.get("WeeklyBonusPercent")) or 50)) }
end
function W.bonus(counts, values, percent, week)
    local offer = W.current(week)
    local total = 0
    for _, category in ipairs(offer.categories) do total = total + (counts[category] or 0) * (values[category] or 0) end
    return math.floor(total * offer.percent / 100 * percent / 100 + 0.5)
end
return W
