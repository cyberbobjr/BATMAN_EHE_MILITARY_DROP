local T = {}

function T.setup()
    MilitaryDrop = { WreckParts={} }
    local Parts = MilitaryDrop.WreckParts
    Parts.isWreck = function(vehicle) return vehicle.own end
    Parts.near = function() return NEAR end
    Parts.empty = function() return EMPTY end
    NEAR, EMPTY, CALLS = true, false, 0
    PLAYER = {}
    getSpecificPlayer = function() return PLAYER end
    getText = function(key) return key end
    ISVehicleMenu = { onMechanic=function() end,
        FillMenuOutsideVehicle=function(_, _, _, _, arg)
            CALLS = CALLS + 1
            return "vanilla", arg
        end }
    -- Table vanilla (ISCarMechanicsOverlay.lua) : une pièce partagée existe déjà.
    VANILLA_PART = { img = "vanilla", vehicles = { vanilla_ = { x = 1 } } }
    ISCarMechanicsOverlay = { CarList = {}, PartList = { SkinPanels = VANILLA_PART } }
    OPTIONS = {}
    CUT ={ toolTip={description="tools"} }
    CONTEXT = { addOption=function(_, name, player, fn, vehicle)
        OPTIONS[#OPTIONS + 1] = {name=name, player=player, fn=fn, vehicle=vehicle}
    end, getOptionFromName=function(_, name)
        assertEq(name,"ContextMenu_RemoveBurntVehicle")
        return CUT
    end }
    loadMod("client/MilitaryDrop/MilitaryDrop_WreckMenu.lua")
end

function T.other_vehicles_and_test_calls_preserve_vanilla_returns()
    local a,b = ISVehicleMenu.FillMenuOutsideVehicle(0,CONTEXT,{},false,"argument")
    assertEq(a,"vanilla")
    assertEq(b,"argument")
    ISVehicleMenu.FillMenuOutsideVehicle(0,CONTEXT,{own=true},true)
    assertEq(#OPTIONS,0)
    assertEq(CUT.notAvailable,nil)
end

function T.recovery_opens_mechanics_and_blocks_final_cut_until_parts_are_removed()
    local vehicle = {own=true}
    ISVehicleMenu.FillMenuOutsideVehicle(0,CONTEXT,vehicle,false)
    assertEq(OPTIONS[1].name,"IGUI_MilitaryDrop_RecoverWreck")
    assertEq(OPTIONS[1].fn,ISVehicleMenu.onMechanic)
    assertEq(OPTIONS[1].player,PLAYER)
    assertEq(OPTIONS[1].vehicle,vehicle)
    assertTrue(CUT.notAvailable)
    assertEq(CUT.toolTip.description,"IGUI_MilitaryDrop_RecoverWreckFirst")
    CUT, EMPTY = {toolTip={description="tools"}}, true
    ISVehicleMenu.FillMenuOutsideVehicle(0,CONTEXT,vehicle,false)
    assertEq(CUT.notAvailable,nil)
end

function T.mechanics_overlay_is_registered_without_replacing_shared_parts()
    local Overlay = ISCarMechanicsOverlay
    local wreck = Overlay.CarList["Base.MilitaryDrop_HeliWreckBurnt"]
    local tail = Overlay.CarList["Base.MilitaryDrop_HeliTailBurnt"]
    assertEq(wreck.imgPrefix, "militarydrop_heli_wreck_")
    assertEq(tail.imgPrefix, "militarydrop_heli_tail_")
    assertEq(wreck.PartList.Avionics.img, "avionics")
    assertEq(Overlay.PartList.Avionics.vehicles.militarydrop_heli_wreck_.x2, 177)
    assertTrue(Overlay.PartList.SkinPanels == VANILLA_PART, "pièce partagée conservée")
    assertEq(VANILLA_PART.vehicles.vanilla_.x, 1, "zones des autres véhicules conservées")
    assertEq(VANILLA_PART.vehicles.militarydrop_heli_tail_.y2, 504)
    assertEq(VANILLA_PART.vehicles.militarydrop_heli_wreck_.y, 439)
end

function T.distant_player_gets_no_recovery_option_and_reload_does_not_stack()
    NEAR = false
    loadMod("client/MilitaryDrop/MilitaryDrop_WreckMenu.lua")
    ISVehicleMenu.FillMenuOutsideVehicle(0,CONTEXT,{own=true},false)
    assertEq(#OPTIONS,0)
    assertEq(CALLS,1)
end

return T
