require "MilitaryDrop/MilitaryDrop_Net"
local R = {}
MilitaryDrop.Relay = R
R.SITES = {
    { x = 4832, y = 6281, sprite = "industry_02_165", create = true },
    { x = 1625, y = 5755, sprite = "industry_02_165" },
    { x = 10277, y = 8744, sprite = "industry_02_170" },
    { x = 1513, y = 14851, sprite = "industry_02_169" },
}
MilitaryDrop.Config.addDefaults({ RelayEnabled = true, RelayRearmDays = 7 })
function R.cost(level) return math.max(2, math.min(20, math.floor(20 - 1.8 * level + 0.5))) end
function R.seconds(level) return math.max(3, math.min(15, 15 - 1.2 * level)) end
function R.near(player, site)
    if not player or player:isDead() or math.floor(player:getZ()) ~= 0 then return false end
    local dx, dy = player:getX() - (site.x + 0.5), player:getY() - (site.y + 0.5)
    return dx * dx + dy * dy <= 2.5 * 2.5
end
return R
