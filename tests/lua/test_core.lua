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

-- Chaînes : caractères entiers (Kahlua : unités UTF-16 ; lupa : octets UTF-8).

function T.drop_last_char_always_shortens_utf8_text()
    local drop = MilitaryDrop.dropLastChar
    assertEq(drop("aé"), "a", "é (deux octets) retiré entier")
    assertEq(drop("é"), "", "un seul caractère")
    assertEq(drop(""), "", "vide")
    assertEq(drop("abc"), "ab", "ASCII")
    local stray = "yyy"
    assertTrue(#drop(stray) < #stray, "octets de suite sans tête : raccourci quand même")
    assertEq(MilitaryDrop.cutText("éé", 3), "é", "coupe au milieu d'un caractère : retiré")
    assertEq(MilitaryDrop.cutText("aé", 2), "a", "tête seule retirée")
    assertEq(MilitaryDrop.cutText("abc", 5), "abc", "assez court : inchangé")
    assertEq(MilitaryDrop.cutText("abcd", 2), "ab", "ASCII")
end

function T.kahlua_strings_drop_one_unit_or_a_surrogate_pair()
    -- Kahlua : string.char accepte tout code (StringLib.java:674-678) et
    -- string.byte renvoie l'unité UTF-16 (StringLib.java:637-662).
    local realChar, realByte = string.char, string.byte
    string.char = function() return "" end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    string.char = realChar
    -- Unités simulées : H = début de paire (0xD83D), L = fin de paire (0xDE00).
    string.byte = function(text, i, j)
        local code = realByte(text, i, j)
        if code == 72 then
            return 0xD83D
        elseif code == 76 then
            return 0xDE00
        end
        return code
    end
    local drop = MilitaryDrop.dropLastChar
    assertEq(drop("aby"), "ab", "unité 128-191 («, °) : un caractère, une unité")
    assertEq(drop("yy"), "y", "jamais plus d'un caractère")
    assertEq(drop("abHL"), "ab", "paire de substitution retirée entière")
    assertEq(MilitaryDrop.cutText("abHLc", 3), "ab", "pas de coupe dans une paire")
    assertEq(MilitaryDrop.cutText("abcyd", 4), "abcy", "unité entre 128 et 191 gardée")
    string.byte = realByte
end

-- ----------------------------------------------------------------------------
-- Options changées en cours de partie (à chaud)
-- ----------------------------------------------------------------------------

function T.java_options_win_over_a_stale_sandbox_vars()
    -- Solo : l'éditeur d'options change les options Java, pas SandboxVars.
    SandboxVars.MilitaryDrop = { CooldownHours = 24, AuthCode = 2, NotesOnlyArmyPolice = true }
    local java = useJavaSandboxOptions({ ["MilitaryDrop.CooldownHours"] = 24, ["MilitaryDrop.AuthCode"] = 2,
        ["MilitaryDrop.NotesOnlyArmyPolice"] = true })
    assertEq(MilitaryDrop.Config.get("CooldownHours"), 24, "valeur de la partie")
    java["MilitaryDrop.CooldownHours"] = 12
    java["MilitaryDrop.AuthCode"] = 1
    java["MilitaryDrop.NotesOnlyArmyPolice"] = false
    assertEq(MilitaryDrop.Config.get("CooldownHours"), 12, "changement vu tout de suite")
    assertEq(MilitaryDrop.Config.codeMode(), 1, "mode du code aussi")
    assertEq(MilitaryDrop.Config.get("NotesOnlyArmyPolice"), false, "false Java gagne sur true périmé")
end

function T.sandbox_vars_then_default_when_the_java_option_is_unknown()
    useJavaSandboxOptions({})
    SandboxVars.MilitaryDrop = { CooldownHours = 48 }
    assertEq(MilitaryDrop.Config.get("CooldownHours"), 48, "option inconnue de Java : SandboxVars")
    SandboxVars.MilitaryDrop.CooldownHours = 6
    assertEq(MilitaryDrop.Config.get("CooldownHours"), 6, "SandboxVars réécrit (MP) : vu tout de suite")
    SandboxVars.MilitaryDrop = nil
    assertEq(MilitaryDrop.Config.get("CooldownHours"), 168, "rien : défaut")
end

function T.vanilla_option_is_read_live()
    local java = useJavaSandboxOptions({ GeneratorTileRange = 20 })
    assertEq(MilitaryDrop.Config.sandboxValue("GeneratorTileRange"), 20, "option vanilla par son nom")
    java.GeneratorTileRange = 35
    assertEq(MilitaryDrop.Config.sandboxValue("GeneratorTileRange"), 35, "à jour")
    assertEq(MilitaryDrop.Config.sandboxValue("Nope"), nil, "inconnue : nil")
    getSandboxOptions = function() return {} end
    assertEq(MilitaryDrop.Config.sandboxValue("GeneratorTileRange"), nil, "sans getOptionByName : nil")
end

function T.poll_calls_listeners_only_on_a_real_change()
    local logs = {}
    print = function(text) logs[#logs + 1] = tostring(text) end
    local java = useJavaSandboxOptions({ ["MilitaryDrop.AuthCode"] = 4, ["MilitaryDrop.DropPlacement"] = 1 })
    local calls = {}
    MilitaryDrop.Config.onChange("test", { "DropPlacement" }, function(changed)
        calls[#calls + 1] = table.concat(changed, ",")
    end)
    assertEq(#MilitaryDrop.Config.poll(), 0, "première lecture : référence")
    assertEq(#calls, 0, "aucun appel à la première lecture")
    java["MilitaryDrop.AuthCode"] = 2
    assertEq(table.concat(MilitaryDrop.Config.poll(), ","), "AuthCode", "option connue changée")
    assertEq(#calls, 0, "abonné non concerné")
    assertTrue(logs[#logs]:find("sandbox options changed: AuthCode", 1, true) ~= nil, "journalisé")
    java["MilitaryDrop.DropPlacement"] = 2
    java["MilitaryDrop.AuthCode"] = 3
    MilitaryDrop.Config.poll()
    assertEq(table.concat(calls, ";"), "AuthCode,DropPlacement", "un appel, noms triés")
    MilitaryDrop.Config.poll()
    assertEq(#calls, 1, "rien de neuf : pas d'appel")
    -- Même clé (fichier rechargé) : abonné remplacé, jamais doublé.
    local second = 0
    MilitaryDrop.Config.onChange("test", { "DropPlacement" }, function() second = second + 1 end)
    java["MilitaryDrop.DropPlacement"] = 3
    MilitaryDrop.Config.poll()
    assertEq(#calls, 1, "ancien abonné retiré")
    assertEq(second, 1, "nouvel abonné appelé une fois")
end

function T.poll_runs_every_game_minute_once_even_after_a_reload()
    assertEq(listenerCount("EveryOneMinute"), 1, "un abonné")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    assertEq(listenerCount("EveryOneMinute"), 1, "fichier rechargé : toujours un")
    local java = useJavaSandboxOptions({ ["MilitaryDrop.CooldownHours"] = 168 })
    local seen = 0
    MilitaryDrop.Config.onChange("test", { "CooldownHours" }, function() seen = seen + 1 end)
    triggerEvent("EveryOneMinute")
    java["MilitaryDrop.CooldownHours"] = 1
    triggerEvent("EveryOneMinute")
    assertEq(seen, 1, "changement vu à la minute de jeu suivante")
end

function T.created_channel_keeps_its_frequency_until_restart()
    local java = useJavaSandboxOptions({ ["MilitaryDrop.Frequency"] = 151.4 })
    MilitaryDrop.Broadcast = { frequency = 151400 }
    java["MilitaryDrop.Frequency"] = 140
    assertEq(MilitaryDrop.Config.getChannel(), 151400, "chaîne créée : sa fréquence fait foi")
    MilitaryDrop.Broadcast = nil
    assertEq(MilitaryDrop.Config.getChannel(), 140000, "sans chaîne (client MP) : l'option")
end

return T
