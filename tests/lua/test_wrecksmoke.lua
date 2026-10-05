local T = {}
function T.setup()
    CLIENT,SERVER = false,false
    isClient = function() return CLIENT end
    isServer = function() return SERVER end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    PRESENT,CREATED,REMOVED,LOADED = nil,0,0,true
    local sq = {getFire=function() return PRESENT end, AddTileObject=function(_,f) PRESENT=f end}
    getCell = function() return {getGridSquare=function() return LOADED and sq or nil end} end
    IsoFire = {CanAddSmoke=function() return PRESENT == nil end,
        new=function(_,square,_,energy,life,smoke)
            assertEq(square,sq)
            assertEq(energy,20)
            assertEq(life,2400)
            assertEq(smoke,true)
            CREATED = CREATED+1
            local data = {}
            return {life=life,getModData=function() return data end,
                getLife=function(self) return self.life end,
                extinctFire=function() REMOVED=REMOVED+1 PRESENT=nil end}
        end}
    IsoFireManager = {Add=function() end}
    loadMod("shared/MilitaryDrop/MilitaryDrop_WreckSmoke.lua")
    ARGS = {id="W1",x=100,y=100}
end
function T.repeated_commands_keep_one_visible_smoke()
    local smoke = MilitaryDrop.WreckSmoke
    smoke.show(ARGS)
    smoke.show(ARGS)
    assertEq(CREATED,1)
    PRESENT.life=1800
    smoke.show(ARGS)
    assertEq(CREATED,2)
    assertEq(REMOVED,1)
    assertEq(PRESENT.life,2400)
end
function T.other_fire_or_smoke_is_never_extinguished()
    PRESENT = {getModData=function() return {} end}
    MilitaryDrop.WreckSmoke.show(ARGS)
    assertEq(CREATED,0)
    assertEq(REMOVED,0)
end
function T.late_loading_and_server_messages_are_handled_without_server_objects()
    LOADED=false
    MilitaryDrop.WreckSmoke.onServerCommand("MilitaryDrop","WreckSmoke",ARGS)
    assertEq(CREATED,0)
    LOADED=true
    MilitaryDrop.WreckSmoke.onServerCommand("OtherMod","WreckSmoke",ARGS)
    assertEq(CREATED,0)
    SERVER=true
    MilitaryDrop.WreckSmoke.show(ARGS)
    assertEq(CREATED,0)
    SERVER=false
    MilitaryDrop.WreckSmoke.onServerCommand("MilitaryDrop","WreckSmoke",ARGS)
    assertEq(CREATED,1)
end
function T.client_event_is_registered_once_after_reload()
    CLIENT=true
    loadMod("shared/MilitaryDrop/MilitaryDrop_WreckSmoke.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_WreckSmoke.lua")
    assertEq(listenerCount("OnServerCommand"),1)
    triggerEvent("OnServerCommand","MilitaryDrop","WreckSmoke",ARGS)
    assertEq(CREATED,1)
end
return T
