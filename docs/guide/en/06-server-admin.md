# Server admin

[Français](../fr/06-server-admin.md) · [Guide home](README.md) · Previous: [Liaison post](05-liaison-post.md) · Next: [FAQ](07-faq.md)

## Sandbox options

All options are on the **Military Drop** page of the sandbox options. Hours and days are game time.


### Drops

| Option | Key | Default | Effect |
|---|---|---|---|
| Hours between drops | `CooldownHours` | 168 | Minimum wait between two drops, for the whole server. Multiplied by the caller's trust factor (x1.5 to x0.6). |
| Military frequency (MHz) | `Frequency` | 0 | 0: random free frequency between 120 and 170 MHz, written on the memos. A fixed value is visible to every player. 112.2 MHz is reserved. |
| Minimum drop distance | `DropMinDistance` | 150 | Minimum tiles between the caller and the drop point. |
| Maximum drop distance | `DropMaxDistance` | 400 | Maximum tiles between the caller and the drop point. |
| Minimum zombies at the drop | `MinZombies` | 3 | 0 and 0: no zombies. |
| Maximum zombies at the drop | `MaxZombies` | 30 | Zombies spawned around the crate. |
| Supply cases per drop | `CaseRolls` | 6 | Loot rolls when the form is off. |
| Crate smoke (minutes) | `CrateSmokeMinutes` | 60 | Needs Signal Smoke. Green smoke on the crate. 0: none. |

### Code, notes and codebooks

| Option | Key | Default | Effect |
|---|---|---|---|
| Authentication code | `AuthCode` | Weekly code, encrypted | None / Fixed code, in clear on the notes / Weekly code, in clear on the notes / Weekly code, encrypted (numbers station and codebook). 3 wrong codes in a day: the base ignores the caller until the next day. |
| Numbers station frequency (MHz) | `NumbersStationFrequency` | 0 | 0: random free shortwave frequency, 10 to 25 MHz. Encrypted mode only. |
| Military notes drop rate | `NoteDropRate` | Normal (1/50) | Extremely rare 1/1000, Very rare 1/500, Rare 1/100, Normal 1/50, Common 1/25, Debug 1/2. |
| Notes only on military and police zombies | `NotesOnlyArmyPolice` | true | Only outfits from the list below carry memos. |
| Outfits carrying notes | `NoteOutfits` | `Army;Police;Sheriff` | Words searched in the outfit name (also matches mod outfits). |
| Excluded outfits | `NoteOutfitsExcluded` | `Stripper` | Outfits that never carry notes or codebooks. |
| Codebook drop rate | `CodebookDropRate` | Rare (1/100) | Same scale. Also sets how often codebooks are found in army storage. |
| Outfits carrying codebooks | `CodebookOutfits` | `Army` | Words searched in the outfit name. |

### Trust

| Option | Key | Default | Effect |
|---|---|---|---|
| Daily trust cap | `TrustDailyCap` | 8 | Most trust a station earns per day from everything except drops. 0: only drops count. |
| Command post bonus (percent) | `TrustPostBonus` | 50 | Extra trust for exchanges made from the liaison post. |
| Line cut (days) | `TrustLineCutDays` | 3 | Days without drops when trust falls under 15. 0: never cut. |
| Hours to recover a drop | `TrustDropLostHours` | 48 | After this, an unopened drop is lost (-10). |
| Trust erosion | `TrustErosion` | false | Each day without contact, trust moves one point toward the start value. |
| Trust: daily situation report | `ReportGain` | 1 | 0 disables reports. |
| Trust: dog tag announced | `DogTagGain` | 2 | 0 disables dog tags. |
| Trust: recon | `ReconGain` | 3 | 0 disables recon orders. |
| Recon deadline (hours) | `ReconHours` | 48 | |
| Hours between recon orders | `ReconIntervalHours` | 24 | After the previous one closes, plus or minus 25%. |
| Trust: clearance | `CleanupGain` | 5 | 0 disables clearance orders. |
| Clearance deadline (hours) | `CleanupHours` | 72 | |
| Clearance horde size | `CleanupQuota` | 30 | Order fulfilled at 90% of the horde dead. |
| Hours between clearance orders | `CleanupIntervalHours` | 48 | Plus or minus 25%. |
| Trust: radio check | `ControlGain` | 1 | 0 disables radio checks. |
| Radio check duration (hours) | `ControlHours` | 4 | |
| Hours between radio checks | `ControlIntervalHours` | 24 | Plus or minus 25%. |

### Requisition and decoy

| Option | Key | Default | Effect |
|---|---|---|---|
| Requisition form | `RequisitionForm` | true | Off: random supply cases, as in the Build 41 mod. |
| Requisition budget (percent) | `RequisitionBudget` | 100 | At 100: 8 points at trust 25, 12 at 50, 16 at 75, 20 at 100. |
| Requisition costs (percent) | `RequisitionCostMultiplier` | 100 | Scales every cost, rounded, at least 1 point. |
| Trust for second tier lots | `RequisitionTier2` | 50 | |
| Trust for third tier lots | `RequisitionTier3` | 75 | |
| Explosives on requisition | `RequisitionExplosives` | true | |
| Decoy drop | `DecoyEnabled` | true | Offers the siren decoy in the form. |
| Decoy cost (points) | `DecoyCost` | 3 | |
| Decoy siren duration (hours) | `DecoySirenHours` | 6 | |
| Decoy siren noise radius (tiles) | `DecoyNoiseRadius` | 120 | Only while the area around the crate is loaded. |

### Debug

| Option | Key | Default | Effect |
|---|---|---|---|
| Debug log | `DebugLog` | false | Detailed `[MilitaryDrop]` lines in `console.txt`. |

## Requisition lots file

The lots of the form are defined in `Zomboid/Lua/MilitaryDrop/requisition.txt`, in the Zomboid folder of the system account that runs the game or the server. The file is created at the first start with the 18 default lots and a notice in English.

> This file is shared by **every** single-player save and **every** server started by this account.

- Each lot has `id`, `enabled`, `group` (tier 1 to 3), `cost` (1 to 99), `count` (items per case, 1 to 20) and a filter: `categories` (item display categories), `tags`, `notTags`, `minWeight`, `maxWeight`, `kind` (`ration`, `firearm`, `melee`, `ammo`, `armor`, `attachment`, `pack`), `fluid` (`Water`, `Petrol`), `extras`.
- To remove a lot, set `enabled = false`. Do not delete an added lot: cases already delivered keep its id and cannot be opened without it.
- You can add lots (40 in all at most) with their own texts:

```lua
{
    id = "kitchen", enabled = true, group = 1, cost = 2, count = 3,
    categories = { "Cooking" }, maxWeight = 3,
    texts = { EN = { label = "Kitchen", desc = "Pots, pans and cutlery." },
              FR = { label = "Cuisine", desc = "Casseroles, poêles et couverts." } },
},
```

- Only data is read, never code. A syntax error keeps the 18 default lots; each problem is written to `console.txt` with its line number.
- Delete the file to get the default one back at the next start.

Reload without restarting:

- single player, debug console: `MilitaryDrop.Requisition.reload()`
- multiplayer, from an admin's debug console: `sendClientCommand(getPlayer(), "MilitaryDrop", "ReloadLots", {})` (admin role only; the summary is printed in the admin's console)

## Admin tools in game

Right-click a military radio (in the inventory or placed):

- **Force a supply drop (admin)**: opens the form stamped **ADMIN**, with every lot and 20 points. No code, no radio check, no wait. The coordinates are sent to you privately, the drop is not tracked for trust, and the wait between drops does not start. With the form disabled, the drop leaves at once with random cases.
- **Missions (admin)**: **Launch a reconnaissance**, **Launch a cleanup**, **Launch a radio check**, or close the current one (**Close the current ...**). A closed mission is announced as cancelled, without reward.

Who sees them: in single player, debug mode only. In multiplayer, the roles allowed to trigger events (admin, and any role with the `MakeEventsAlarmGunshot` capability). The server checks again.

## Files kept by the mod

| File | Content |
|---|---|
| `Zomboid/Lua/MilitaryDrop/requisition.txt` | Requisition lots (above). |
| `Zomboid/Lua/MilitaryDrop/<mode>_<save>_seed.txt` | Secret seed of the save: weekly codes, codebook table, random frequencies. Server only. |
| `Zomboid/Lua/MilitaryDrop/<mode>_<save>_code.txt` | Fixed code (fixed code mode). Server only. |
| `Zomboid/Lua/MilitaryDrop/code_<sp or mp>_<save>_<player>.txt` | Code typed by a player, kept on that player's computer. |

Never share or delete the seed file during a game: memos and codebooks already found would no longer match. Trust, stations, missions and posts are saved with the world, in data that clients cannot read.

## Debug console (single player or host)

```lua
print(MilitaryDrop.Server.getCode())                                       -- current code
print(MilitaryDrop.Config.formatChannel(MilitaryDrop.Config.getChannel())) -- military frequency
print(MilitaryDrop.NumbersStation.frequency)                               -- numbers station, in kHz
MilitaryDrop.Trust.debugPrint()                                            -- trust of every station
MilitaryDrop.Trust.add("SOLO", 30, "drop")                                 -- give trust (single player station)
MilitaryDrop.Missions.launch("recon")                                      -- "recon", "cleanup" or "control"
getPlayer():getInventory():AddItem("MilitaryDrop.MilitaryMemo")
getPlayer():getInventory():AddItem("MilitaryDrop.Codebook")
```

These read the server's memory: they work in single player, not from a multiplayer client.

## Multiplayer notes

- The server decides and checks everything; clients never receive the random frequency or the code (only the memos and the numbers station give them).
- A walkie-talkie must be in hand to transmit: the mod takes it in hand automatically.
- Three wrong codes from one player do not silence the base for the others.
