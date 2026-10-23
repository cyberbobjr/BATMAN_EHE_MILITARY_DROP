-- Persistent character identity: same account/name, reconnect, factions, old saves.
local T = {}
local function player(username, data)
    data = data or {}
    return { getUsername = function() return username end,
        getModData = function() return data end, getDescriptor = function() return nil end,
        getPlayerNum = function() return 0 end }
end

function T.setup()
    isClient = function() return false end
    isServer = function() return true end
    SandboxVars = { MilitaryDrop = {} }
    STATE = {}
    HOURS = 100
    getGameTime = function() return { getWorldAgeHours = function() return HOURS end } end
    local serial = 0
    getRandomUUID = function() serial = serial + 1; return "uuid-" .. serial end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    MilitaryDrop.Secrets = { privateState = function() return STATE end }
    MilitaryDrop.Server = { clock = function() return HOURS end }
    loadMod("server/MilitaryDrop/MilitaryDrop_Trust.lua")
    Trust = MilitaryDrop.Trust
end

function T.same_character_keeps_note_cap_and_lock_after_reconnect_and_reload()
    local data = {}
    local original = player("batman", data)
    local id = Trust.idFor(original)
    Trust.add(id, 10, "report")
    Trust.add(id, -25, "drop")
    loadMod("server/MilitaryDrop/MilitaryDrop_Trust.lua")
    Trust = MilitaryDrop.Trust
    local reconnected = player("batman", data)
    assertEq(Trust.idFor(reconnected), id, "saved identity survives reload")
    assertEq(Trust.get(id), 10, "same note")
    assertTrue(Trust.isLineCut(id), "same suspension")
    assertEq(Trust.add(id, 1, "report"), 0, "same daily cap")
end

function T.new_character_with_same_account_and_name_starts_fresh()
    local oldId = Trust.idFor(player("batman"))
    Trust.add(oldId, 8, "report")
    Trust.add(oldId, -30, "drop")
    local newId = Trust.idFor(player("batman"))
    assertTrue(oldId ~= newId, "two characters on the same account")
    assertEq(Trust.get(newId), 25, "new character starts at 25")
    assertTrue(not Trust.isLineCut(newId), "no inherited suspension")
    assertEq(Trust.add(newId, 8, "report"), 8, "new daily cap")
end

function T.split_screen_characters_have_separate_reputation()
    isServer = function() return false end
    local a, b = Trust.idFor(player("same name")), Trust.idFor(player("same name"))
    Trust.add(a, 50, "drop")
    assertEq(Trust.get(a), 75, "first character")
    assertEq(Trust.get(b), 25, "second character in same world")
end

function T.old_collective_scores_are_preserved_but_never_inherited()
    STATE.trust = { SOLO = { value = 99 }, F1 = { value = 90 }, ["P:batman"] = { value = 80 } }
    STATE.drops = { D1 = { team = "P:batman", requester = "batman", deadline = HOURS + 1 } }
    local id = Trust.idFor(player("batman"))
    assertEq(Trust.get(id), 25, "ambiguous collective scores are not transferred")
    HOURS = HOURS + 2
    Trust.checkDrops()
    assertEq(Trust.get(id), 25, "old drop does not penalize current character")
    assertEq(STATE.trust.SOLO.value, 99, "legacy data kept")
end

function T.old_drop_and_pending_code_penalty_never_target_the_successor()
    local old = player("batman")
    local oldId = Trust.idFor(old)
    local drop = Trust.registerDrop(oldId, "batman")
    Trust.onDropDelivered(drop)
    for _ = 1, 3 do Trust.onFailedCode(old) end
    local successor = player("batman")
    local newId = Trust.idFor(successor)
    local case = { getModData = function() return { [Trust.ITEM_KEY] = drop } end }
    Trust.onCaseOpened(case, successor)
    Trust.flushPenalties()
    assertEq(Trust.get(oldId), 18, "old character loses 5 and 2")
    assertEq(Trust.get(newId), 25, "successor unaffected")
end

function T.cached_identity_repairs_a_replaced_moddata_table()
    local p = player("batman")
    local id = Trust.idFor(p)
    p:getModData()[Trust.CHARACTER_KEY] = nil
    assertEq(Trust.idFor(p), id, "server object retains its identity")
    assertEq(p:getModData()[Trust.CHARACTER_KEY], id, "restored before save")
end

function T.identity_sync_sends_no_score_or_private_state()
    local sent
    MilitaryDrop.Net = { toPlayer = function(_, command, args) sent = { command, args } end }
    local p = player("batman")
    Trust.sync(p)
    assertEq(sent[1], "CharacterIdentity", "identity to own client")
    assertEq(sent[2].id, Trust.idFor(p), "same persistent identity")
    assertEq(sent[2].value, nil, "no score")
    assertEq(sent[2].trust, nil, "no private state")
end

function T.idle_entries_at_the_starting_value_are_forgotten_after_30_days()
    local idle = Trust.idFor(player("idle"))
    local raised = Trust.idFor(player("raised"))
    Trust.add(raised, 5, "report")
    local locked = Trust.idFor(player("locked"))
    STATE.characterTrust[locked].lockedUntil = HOURS + 2000
    local recent = Trust.idFor(player("recent"))
    HOURS = HOURS + Trust.FORGET_IDLE_HOURS - 1
    Trust.touch(recent)
    assertEq(Trust.forgetIdle(), 0, "moins de 30 jours : rien d'oublié")
    HOURS = HOURS + 1
    assertEq(Trust.forgetIdle(), 1, "une seule entrée oubliée")
    assertEq(STATE.characterTrust[idle], nil, "note de départ, sans contact : oubliée")
    assertTrue(STATE.characterTrust[raised] ~= nil, "note changée : gardée")
    assertTrue(STATE.characterTrust[locked] ~= nil, "ligne coupée en cours : gardée")
    assertTrue(STATE.characterTrust[recent] ~= nil, "contact récent : gardée")
    assertEq(Trust.get(idle), Trust.START, "même note qu'avant l'oubli")
end

function T.forgotten_entry_is_recreated_identically_for_a_connected_player()
    local p = player("batman")
    local id = Trust.idFor(p)
    HOURS = HOURS + Trust.FORGET_IDLE_HOURS
    Trust.forgetIdle()
    assertEq(STATE.characterTrust[id], nil, "oubliée")
    assertEq(Trust.idFor(p), id, "même identifiant")
    assertEq(STATE.characterTrust[id].username, "batman", "nom recréé")
    assertEq(Trust.get(id), Trust.START, "note de départ")
end

function T.saved_entries_without_dates_get_one_before_being_forgotten()
    STATE.characterTrust = { ["C:old"] = { value = Trust.START } }
    assertEq(Trust.forgetIdle(), 0, "pas de date : rien d'oublié")
    assertEq(STATE.characterTrust["C:old"].createdHours, HOURS, "date posée à la migration")
    HOURS = HOURS + Trust.FORGET_IDLE_HOURS
    assertEq(Trust.forgetIdle(), 1, "oubliée 30 jours plus tard")
end

return T
