-- Signal facultatif d'un tir : seul le serveur choisit un vol plausible.
require "MilitaryDrop/MilitaryDrop_Net"
require "MilitaryDrop/MilitaryDrop_Crash"
local function onShot(player, weapon)
    if MilitaryDrop.Config.get("CrashGunfire") ~= true or not player or player:isDead()
        or player ~= getSpecificPlayer(player:getPlayerNum()) or not weapon or not weapon:isRanged()
        or weapon:getMaxDamage() <= 0 or weapon:isJammed() then return end
    MilitaryDrop.Net.toServer(player, "GroundFire", {})
end
Events.OnWeaponSwingHitPoint.Add(onShot)
