-- MilitaryDrop_Core : lecture des options sandbox et canal radio.

local T = {}

function T.setup()
    SandboxVars = {}
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
end

function T.defaults_without_sandbox()
    assertEq(MilitaryDrop.Config.get("CooldownHours"), 168, "délai par défaut")
    assertEq(MilitaryDrop.Config.isFixedFrequency(), false, "défaut : fréquence libre, secrète")
    assertEq(MilitaryDrop.Config.getChannel(), nil, "sans module serveur (client MP) : jamais connue")
end

function T.fixed_frequency_is_used_as_is()
    SandboxVars.MilitaryDrop = { Frequency = 151.4 }
    assertTrue(MilitaryDrop.Config.isFixedFrequency(), "valeur > 0 : fixe")
    assertEq(MilitaryDrop.Config.getChannel(), 151400, "canal fixe")
end

function T.free_frequency_comes_from_the_server_module()
    SandboxVars.MilitaryDrop = { Frequency = 0 }
    MilitaryDrop.Broadcast = { freeChannel = function() return 133600 end }
    assertEq(MilitaryDrop.Config.getChannel(), 133600, "serveur ou solo : fréquence tirée")
end

function T.sandbox_value_wins_even_when_false()
    SandboxVars.MilitaryDrop = { NotesOnlyArmyPolice = false, CooldownHours = 24 }
    assertEq(MilitaryDrop.Config.get("NotesOnlyArmyPolice"), false, "false n'est pas remplacé par le défaut")
    assertEq(MilitaryDrop.Config.get("CooldownHours"), 24, "valeur sandbox")
end

function T.code_mode_defaults_to_encrypted_and_is_bounded()
    assertEq(MilitaryDrop.Config.codeMode(), 4, "défaut : code de la semaine chiffré")
    SandboxVars.MilitaryDrop = { AuthCode = 2 }
    assertEq(MilitaryDrop.Config.codeMode(), 2, "valeur sandbox")
    SandboxVars.MilitaryDrop.AuthCode = 9
    assertEq(MilitaryDrop.Config.codeMode(), 4, "au-dessus : borné")
    SandboxVars.MilitaryDrop.AuthCode = 0
    assertEq(MilitaryDrop.Config.codeMode(), 1, "en dessous : borné")
end

function T.channel_snaps_to_tuning_step()
    local toChannel = MilitaryDrop.Config.toChannel
    assertEq(toChannel(151.4), 151400, "151.4 exact")
    assertEq(toChannel(151.5), 151600, "151.5 arrondi au pas de 200 supérieur")
    assertEq(toChannel(151.45), 151400, "151.45 arrondi au plus proche")
    assertEq(toChannel(107.3), 107400, "erreur de flottant absorbée")
end

function T.channel_is_clamped()
    local toChannel = MilitaryDrop.Config.toChannel
    assertEq(toChannel(0), 200, "minimum des radios militaires")
    assertEq(toChannel(5000), 1000000, "maximum des radios militaires")
end

function T.hef_channel_is_skipped()
    assertEq(MilitaryDrop.Config.toChannel(112.2), 112400, "112.2 MHz est réservé à HEF")
end

function T.format_channel()
    local format = MilitaryDrop.Config.formatChannel
    assertEq(format(151400), "151.4", "une décimale")
    assertEq(format(151000), "151", "pas de .0")
end

return T
