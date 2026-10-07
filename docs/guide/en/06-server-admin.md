# Server admin

[Français](../fr/06-server-admin.md) · [Guide home](README.md) · Previous: [Liaison post](05-liaison-post.md) · Next: [FAQ](07-faq.md)

## Sandbox options

All options are on the **Military Drop** page of the sandbox options. Hours and days are game time.

### Changing options during a game

Options can be changed without restarting, except the two frequencies (see below).

- **Single player**: debug menu › **Sandbox Settings**, change the values, **Apply**.
- **Multiplayer**: admin panel › **Sandbox Options** (permission to edit sandbox options), change the values, **Apply**. The server saves them in `Zomboid/Server/<server name>_SandboxVars.lua` and sends them to every connected player.
- `/reloadoptions` and `/changeoption` only reload the server settings (`<server name>.ini`), never the sandbox options. Editing `<server name>_SandboxVars.lua` by hand while the server runs does nothing until it restarts: the file is read at startup only, and an **Apply** from the panel overwrites it.

The mod reads its options each time it uses them: a new value counts for the next call, drop, order, mission or crash. What already exists keeps the value it was created with: a flight in the air, a horde already spawned, a mission deadline, a crash site. Within one in-game minute of the change, the console (`console.txt`, or the server log) shows `[MilitaryDrop] sandbox options changed: …`, and a few changes are applied at that moment:

- switching to the encrypted weekly code starts the numbers station if the game was loaded in another mode; leaving it silences the station;
- the codebook is put in army storage, or taken out, with its new drop rate (containers filled afterwards only);
- the requisition lots are prepared when the form is turned on;
- the drop zone tool, if open, shows the new placement.

**Restart required**: `Frequency` and `NumbersStationFrequency`. A radio channel keeps the frequency it was created with when the world loads; until the restart, the base keeps answering on the old frequency and memos keep giving it.


### Drops

| Option | Key | Default | Effect |
|---|---|---|---|
| Hours between drops | `CooldownHours` | 168 | Minimum wait between two drops, for the whole server. Multiplied by the caller's trust factor (x1.5 to x0.6). |
| Military frequency (MHz) | `Frequency` | 0 | 0: random free frequency between 120 and 170 MHz, written on the memos. A fixed value is visible to every player. 112.2 MHz is reserved. Restart required. |
| Minimum drop distance | `DropMinDistance` | 150 | Minimum tiles between the caller and the drop point. |
| Maximum drop distance | `DropMaxDistance` | 400 | Maximum tiles between the caller and the drop point. |
| Grid reminder every (hours) | `DropRepeatHours` | 6 | In-game hours between two reminders of the grid of a drop whose supply cases are all unopened, for up to `TrustDropLostHours`. 0 = no reminder. |
| Minimum zombies at the drop | `MinZombies` | 3 | 0 and 0: no zombies. |
| Maximum zombies at the drop | `MaxZombies` | 30 | Zombies spawned around the crate. |
| Supply cases per drop | `CaseRolls` | 6 | Loot rolls when the form is off. |
| Crate smoke (minutes) | `CrateSmokeMinutes` | 60 | Needs Signal Smoke. Green smoke on the crate. 0: none. |

### Code, notes and codebooks

| Option | Key | Default | Effect |
|---|---|---|---|
| Authentication code | `AuthCode` | Weekly code, encrypted | None / Fixed code, in clear on the notes / Weekly code, in clear on the notes / Weekly code, encrypted (numbers station and codebook). 3 wrong codes in a day: the base ignores the caller until the next day. |
| Numbers station frequency (MHz) | `NumbersStationFrequency` | 0 | 0: random free shortwave frequency, 10 to 25 MHz. Encrypted mode only. Restart required. |
| Military notes drop rate | `NoteDropRate` | Normal (1/50) | Extremely rare 1/1000, Very rare 1/500, Rare 1/100, Normal 1/50, Common 1/25, Debug 1/2. |
| Notes only on military and police zombies | `NotesOnlyArmyPolice` | true | Only outfits from the list below carry memos. |
| Outfits carrying notes | `NoteOutfits` | `Army;Police;Sheriff` | Words searched in the outfit name (also matches mod outfits). |
| Excluded outfits | `NoteOutfitsExcluded` | `Stripper` | Outfits that never carry notes or codebooks. |
| Codebook drop rate | `CodebookDropRate` | Rare (1/100) | Same scale. Also sets how often codebooks are found in army storage. |
| Outfits carrying codebooks | `CodebookOutfits` | `Army` | Words searched in the outfit name. |

### Trust

| Option | Key | Default | Effect |
|---|---|---|---|
| Daily trust cap | `TrustDailyCap` | 10 | Most trust a character earns per day from everything except drops. 0: only drops count. |
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

### Helicopter crash (Mayday branch)

| Option | Key | Default | Effect |
|---|---|---|---|
| Crash chance (%) | `CrashChance` | 5 | Per normal flight ; admin drops and decoys excluded. |
| Storm bonus | `CrashStormBonus` | 15 | Added percentage points during a thunderstorm, capped at 100 %. |
| Gunfire can down helicopters | `CrashGunfire` | false | Client signal checked on the server for weapon, ammunition, distance and heading. |
| Chance per plausible shot (%) | `CrashGunfireChance` | 10 | Approach phase only ; admin drops and decoys excluded. |
| Ground effects | `CrashFire` | Fire and smoke | None / smoke / fire and smoke ; one initial fire beside the fuselage, game fire rules apply. Existing saves keep their setting. |
| Smoke duration (minutes) | `CrashSmokeMinutes` | 60 | Game minutes ; repeated for late arrivals. Signal Smoke is not required. |
| Supplies at crash site | `CrashCrates` | false | Off: the ordered supplies are lost with the helicopter, only the wreck, salvage, crew, documents, horde and smoke remain. On: supplies delivered at the site. A crash has no reputation effect either way. Existing saves keep their setting. |
| Items per salvage bundle | `SalvageRolls` | 3 | Drawn from game and mod item categories/tags. |
| Corpse outfits | `PilotOutfits` | `Army` | Words matched against outfit names, separated by `;`. The two additional zombie pilots wear their dedicated military flight outfit. |
| Pilot documents | `PilotDocuments` | true | Memo and codebook on the body ; the flight recorder remains available. |

The MAYDAY gives an approximate sector over the military frequency. Right-click the wreck to recover its parts ; after all parts are removed, final cutting follows vanilla rules. The flight recorder is read in the liaison post's reading bay (10 in-game minutes, post radio on and powered; paused on a power cut), then transmitted to the base on the military frequency: +10 reputation to the transmitting character, outside the daily cap, once per crash site (admin crashes included).

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

## Drop zones

By default a crate falls 150 to 400 tiles from the caller. On a PvP server with safe areas, that point often lands in a safe area, and the announced crate can be picked up without any risk. **Drop zones** let the admin choose where crates fall: rectangles grouped into **sectors** (usually a town), for example a park, a mall and a block of flats in Louisville. Each drop draws one zone at random, so nobody can camp the exact spot.

Nothing changes until you change **Drop placement**: the default is still "Near the caller".

### Options

| Option | Key | Default | Effect |
|---|---|---|---|
| Drop placement | `DropPlacement` | Near the caller | **Near the caller**: a point between the minimum and maximum drop distances, as before. **Drop zones**: inside a zone of the admin; without any usable zone, a vanilla town, else near the caller (see [Fallback](#fallback)). **Zones if one is near**: only the zones closer than the drop zone range are used; if there is none, near the caller. |
| Drop zone sector | `DropZoneChoice` | Nearest to the caller | **Nearest to the caller**, **At random** or **Chosen by the player**. A zone of that sector is then drawn at random, by weight. **Chosen by the player**: the requisition form gets a **Drop sector** field (see [What players see](#what-players-see)); without the requisition form (`RequisitionForm` off), the nearest sector is used. |
| Drop zone minimum distance | `DropZoneMinDistance` | 0 | Tiles, 0 to 5000. Zones closer to the caller are skipped, so that nobody calls from inside a zone and helps himself at once. If every zone is closer, the nearest sector is used. 0: no minimum. |
| Drop zone range | `DropZoneMaxDistance` | 1500 | Tiles, 100 to 20000. Used by "Zones if one is near" only. |
| Announce the drop zone name | `DropZoneAnnounceName` | true | The announcement and its reminders give the zone name before the grid. Off: the grid only. |

Distances are measured from the caller to the nearest edge of a zone (0 inside it). In zone mode, `DropMinDistance` and `DropMaxDistance` only apply when the drop falls back near the caller. Admin drops (**Force a supply drop**, direct or through the admin form) follow the same rules as a player's call, with distances measured from the admin: drop placement, sector choice, decoy sectors.

### The `dropzones.txt` file

Zones are kept in `Zomboid/Lua/MilitaryDrop/dropzones.txt`, next to `requisition.txt`. The file is created at the first start, with no zone and a notice in English.

> Like the lots file, it is shared by **every** single-player save and **every** server started by this account. The `map` field ties the zones to a map.

You can draw zones with the [in-game tool](#in-game-tool) or write them by hand:

```lua
return {
    version = 1,
    map = "Muldraugh, KY",
    zones = {
        { id = "z1", sector = "Louisville", name = "Central Park", x1 = 12900, y1 = 2100, x2 = 12980, y2 = 2160 },
        { id = "z2", sector = "Louisville", name = "Mall", x1 = 13200, y1 = 2300, x2 = 13290, y2 = 2380, weight = 2 },
        { id = "z3", sector = "Riverside", name = "Main Street", x1 = 6400, y1 = 5380, x2 = 6480, y2 = 5440, enabled = false },
    },
}
```

The coordinates above are examples: read yours in game, or draw the zones with the tool (it shows the corners and the size).

| Field | Content |
|---|---|
| `map` | Maps the zones are drawn for: map folder names separated by `;`, as in the server's `Map=` line (vanilla map: `Muldraugh, KY`). Optional. A zone can carry its own `map`. |
| `id` | Unique name: letters, digits, `_` and `-`, 16 characters at most. The tool numbers its zones `z1`, `z2`... |
| `sector` | Group of zones, usually a town. 32 characters at most, no `<` or `>`. |
| `name` | Zone name, read in the radio announcement. Same limits. |
| `x1`, `y1`, `x2`, `y2` | Rectangle on ground level. Both corners are inside the zone; 1 to 300 tiles on each side. |
| `weight` | 1 to 100, default 1. A zone of weight 2 is drawn twice as often as a zone of weight 1 of the same sector. |
| `enabled` | `true` or `false`, default `true`. |

- **Expected map**: a zone whose map is not loaded in the current save is ignored, with a line in `console.txt`. The tool shows it as "map not loaded". When the file has no `map`, the tool writes the map of the current save at its first change.
- Only data is read, never code. A syntax error disables **every** zone (see [Fallback](#fallback)); the line number is written to `console.txt`. An invalid zone is skipped (`zone #3 (z3): ...`). 200 zones at most.
- The crate lands **anywhere inside the rectangle**: grass, field, beach, path, road, parking lot. Never inside a building, never in water. A zone needs no road.
- On each load the server checks every zone. Its remarks are shown on the zone's line in the tool's list and written to `console.txt` as plain notes (`note:`), not as file problems: **no open ground** (buildings everywhere, or water that the map data already knows: no crate can land there), **overlaps a non-PvP zone** or **a safehouse** (no crate in that part), **outside the map**, **map not loaded**. The red "problems" section of the list only shows real errors of `dropzones.txt` (syntax error, invalid zone skipped, unknown field).

Reload without restarting: the **Reload** button of the tool, or from an admin's debug console: `sendClientCommand(getPlayer(), "MilitaryDrop", "ZoneReload", {})`.

> After a manual edit, **reload before using the tool**. The tool rewrites the whole file from the version it last read: unreloaded edits would be lost, and so are your own comments. It refuses to write while the file has a syntax error, so that a manual edit is never overwritten.

### In-game tool

Who sees it: in multiplayer, the roles allowed to change and reload the server options (admin, and any role with the `ChangeAndReloadServerOptions` capability; the host of a co-op game too). In single player, debug mode only. The server checks again: a command from anyone else is refused and logged.

Where to open it:

- **Multiplayer**: the **Military Drop Zones** button of the game's admin panel.
- **Single player, debug mode**: right-click the ground › **Debug** › **Main** › **Military Drop Zones**; also in the debug window (bug icon at the bottom of the left icon bar, **Main** tab), or from the debug console: `MilitaryDrop.ZonesWindow.open(getPlayer())`.

The **Drop zones (admin)** window is modelled on the game's animal zones panel. At the top: the expected map, the placement mode and the count of usable zones. The list shows the zones grouped by sector, with their state (active, disabled, map not loaded), corners, size, weight and warnings, then the first problems of the file. Tick **Highlight** (top right of the buttons, unticked at first, remembered until you quit the game) to light up the border squares of every zone on the ground, steadily: green active, grey disabled, orange map not loaded, the selected zone in a stronger shade. Only the squares around you that the game has loaded are lit, and new ones as you move; only you see them, and they are removed when you untick the box or close the window (they stay while the editor is open). The tool's messages (zone added, refusal, file reloaded) appear in the window, never above your character, so nearby players see nothing.

![The Drop zones (admin) window, opened from the single-player debug menu: zones grouped by sector, with their state, corners, size and weight](../images/ingame-zones-list.png)

Buttons:

- **Add Zone**: draw a new zone (below).
- **Edit**: change the name, sector or weight of the selected zone, or redraw it (below).
- **Remove**: asks "Do you really want to remove ...?" first.
- **Enable** / **Disable**.
- **Teleport to Zone**: to the centre of the zone, on ground level. Needs the teleport right (`TeleportToCoordinates` capability in multiplayer).
- **Reload**: reads `dropzones.txt` again.
- **Close** (or Esc).

Gamepad: D-pad up and down selects a zone, A edits, X enables or disables, Y adds, B closes.

#### Adding a zone

1. Press **Add Zone**. The list hides and an editor opens in the top-left corner of the screen.
2. Draw the rectangle with the **left mouse button** on the ground: press, drag and release, or click one corner and then the opposite one. While you draw, clicks only draw: no attack, no walking, no door opened, no context menu. Squares are taken on ground level, whatever floor you are on. The border of the rectangle lights up on the ground as you draw (blue, red beyond 300 squares); the editor shows the corners, the **Width** and the **Length**, in red beyond 300 squares.
3. After the second corner, the rectangle is fixed. Right-click or Esc cancels the outline in progress; Esc again closes the editor.
4. Fill in **Zone Name**, **Sector** (a known sector, or **New sector...** and its name in **New sector**) and **Weight (1-100)**, then press **Add Zone**.
5. The server checks the zone and answers in the editor: "Drop zone z4 added.", with its warnings, or a refusal (too large, off the map, overlapping a non-PvP zone or a safehouse, 200 zones already, file with a syntax error). It writes `dropzones.txt` and reloads it. On success the editor closes and the new zone is selected in the list. **Cancel** returns to the list.

![Adding a zone: the editor shows the corners and the size, and the drawn rectangle lights up on the ground](../images/ingame-zones-add.png)

Gamepad: the D-pad moves the target square (starting from yours), A sets the first corner then the second one, B cancels the outline. Once the rectangle is drawn, the D-pad moves through the form and B cancels.

#### Editing a zone

Select the zone and press **Edit**. Change its **Zone Name**, **Sector** or **Weight**, or press **Redraw** and draw it again: the old rectangle stays outlined in grey until the new one is drawn, and comes back if you cancel. **Save** sends only the changed fields, with the same checks as a new zone ("Nothing to save." if nothing changed). While `dropzones.txt` has a syntax error, the change is refused and nothing is written.

### What players see

- The announcement and its reminders name the zone: "Supply crate delivered at LZ Central Park, grid 12937 / 2125." With **Announce the drop zone name** off, they give the grid only. The map marker does not change.
- The list of zones is never sent to players, and zone highlights are drawn on the admin's screen only, while the tool is open. Players learn the zones from the announcements.
- **Decoy**: in zone mode, the form offers a sector selector ("< Louisville >", arrows or gamepad left and right) instead of N, E, S and W. With a single sector, it is selected and shown, without choice. The decoy falls in a zone of that sector, like a real drop, and gets the same announcement. Near the caller, the decoy keeps N, E, S and W; the admin form follows the same rules.
- **Drop sector chosen by the player** (**Drop zone sector**: *Chosen by the player*): whenever the caller would get a zone drop (drop zones, zones in range with "Zones if one is near", or the vanilla towns of the fallback), the form shows a **Drop sector** field above the budget, with the same selector. It lists the active sectors that have at least one zone beyond the minimum distance (or only the nearest sector if none has), and the order cannot be sent until a sector is chosen. Only the sector is chosen: the zone is still drawn by weight inside it, and zone names are never shown. The decoy uses the same field, so it gets the same list. The server checks the sector again (a sector disabled or out of range meanwhile refuses the order); a sector with no possible drop point asks for another sector and reopens the form. The admin form shows the field too.
- Trust does not change: an outsider who opens the crate still costs the requester 5 points.

### Fallback

With **Drop zones** and no usable zone (none, all disabled, map not loaded, or a syntax error):

1. **Vanilla towns**, only when the vanilla map (`Muldraugh, KY`) is loaded: Louisville, Valley Station, West Point, Muldraugh, Riverside, Brandenburg, Ekron, Irvington, Echo Creek, March Ridge, Fallas Lake and Rosewood. Each town is a sector of one zone, 150 tiles around its centre, chosen with the same rules (nearest, at random or by the player, minimum distance).
2. Otherwise, **near the caller**, as before. The server writes a warning to `console.txt`, and connected admins get the message "No drop zone is usable: the crate falls near the caller. Check the drop zones."

With **Zones if one is near**, a call far from every zone simply falls near the caller, without a warning. A mod map without zones falls back near the caller.

### What the mod never does

- **A crate in water or inside a building.** The point is drawn anywhere in the zone, away from buildings and from the water the map data knows. The map data only knows the water of areas players have already approached in this save: a point drawn over an unknown lake is possible. At delivery, once the area is loaded, the four squares under the crate are checked again (outdoors, free, no water, no vehicle) and the crate moves to the nearest suitable square of the zone.
- **A crate outside its zone.** If no square of the drawn zone fits, the server tries another zone of the same sector, then answers the caller "no safe drop zone": the drop does not leave and the form stays open. At delivery, the crate is placed only on a dry, free square inside the zone; otherwise the delivery waits.
- **A crate in a non-PvP zone or a safehouse**, even one created after the zone.
- **Sending the list of zones to players.**

### Limits

- Rectangles on ground level only, 300 tiles on a side at most, 200 zones in all.
- A zone drawn over a lake or the Ohio gives no crate in water: "no safe drop zone" if the map data already knows that water (warning **no open ground**), otherwise the drop is announced but its crate waits for a dry square of the zone and never lands. Do not draw zones on water.
- Vanilla towns are known for the vanilla map only. On a mod map, draw your own zones.
- With a single sector and many players, the zone becomes a regular meeting point: that is intended on a PvP server, to be balanced with **Hours between drops**.
- In zone mode, everyone already knows where to look, so a decoy is less of a surprise. It still looks like a real drop until its siren is heard or its crate opened.

## Admin tools in game

Right-click a military radio (in the inventory or placed):

- **Force a supply drop (admin)**: opens the form stamped **ADMIN**, with every lot and 20 points. No code, no radio check, no wait. The coordinates are sent to you privately, the drop is not tracked for trust, and the wait between drops does not start. With the form disabled, the drop leaves at once with random cases. It follows **Drop placement** like a player's call, with distances measured from you: with drop zones, it falls in a zone, the form can show the **Drop sector** field, and its decoy offers the sectors.
- **Missions (admin)**: **Launch a reconnaissance**, **Launch a cleanup**, **Launch a radio check**, or close the current one (**Close the current ...**). A closed mission is announced as cancelled, without reward.
- **Crash the next helicopter**: arms one crash for the next mod helicopter to take off, including an admin drop or decoy. Private confirmation ; saved with the world ; repeated clicks do not stack crashes. Flights already airborne continue, and waiting for HEF does not consume the order. To try it, arm the crash, then force a drop and submit its form.

Who sees them: in single player, debug mode only. In multiplayer, the roles allowed to trigger events (admin, and any role with the `MakeEventsAlarmGunshot` capability). The server checks again.

Drop zones have their own tool, in the game's admin panel: see [In-game tool](#in-game-tool).

## Files kept by the mod

| File | Content |
|---|---|
| `Zomboid/Lua/MilitaryDrop/requisition.txt` | Requisition lots (above). |
| `Zomboid/Lua/MilitaryDrop/dropzones.txt` | Drop zones (above). |
| `Zomboid/Lua/MilitaryDrop/<mode>_<save>_seed.txt` | Secret seed of the save: weekly codes, codebook table, random frequencies. Server only. |
| `Zomboid/Lua/MilitaryDrop/<mode>_<save>_code.txt` | Fixed code (fixed code mode). Server only. |
| `Zomboid/Lua/MilitaryDrop/code_<sp or mp>_<save>_<player>.txt` | Code typed by a player, kept on that player's computer. |

Never share or delete the seed file during a game: memos and codebooks already found would no longer match. Trust, stations, missions and posts are saved with the world, in data that clients cannot read.

## Crate with unexpected contents

The server always writes these lines, even with the debug log off, to `Zomboid/console.txt` (single player), `Zomboid/server-console.txt` (dedicated server) or `Zomboid/coop-console.txt` (hosted game). Search for `crate contents`:

| Line | Meaning |
|---|---|
| `crate contents at start: entry MilitaryDrop_SupplyCrate present, … unchanged since this mod declared it` | Normal. `CHANGED by another mod (…)` or `missing`: another mod changed or removed the crate trunk distribution. |
| `crate contents for drop <id> at x,y (<order>): … , as ordered, our OnFillContainer fill: once` | One line per crate: trunk contents right after landing. |
| `crate contents differ from the order: drop <id>, expected …, found …` | The trunk does not match the order on landing: the extra item types usually point to the mod involved. |
| `crate container refilled by another mod (forceVehicleDistribution?) for drop <id>` | Another mod refilled the crate later; the order is given back once (`order restored`), never after the crate was emptied. |
| `crate contents changed for drop <id> …, trunk also holds …` | The trunk holds items that are not from the drop: a player stored them there, or another mod refilled it. |
| `crate contents: supply crate trunk … filled without a drop id` | The trunk of an unknown crate was filled outside a drop: random supply cases. |

The list of active mods is already in the same file (`loading <id>` lines). Crates and wrecks carry the `resetedContainers` marker that Specific Loot (KI5) respects; a mod that ignores it shows up in the lines above.

## Debug console (single player or host)

```lua
print(MilitaryDrop.Server.getCode())                                       -- current code
print(MilitaryDrop.Config.formatChannel(MilitaryDrop.Config.getChannel())) -- military frequency
print(MilitaryDrop.NumbersStation.frequency)                               -- numbers station, in kHz
MilitaryDrop.Trust.debugPrint()                                            -- trust of every character
MilitaryDrop.Trust.add(MilitaryDrop.Trust.idFor(getPlayer()), 30, "drop")                                 -- give trust (single player station)
MilitaryDrop.Missions.launch("recon")                                      -- "recon", "cleanup" or "control"
getPlayer():getInventory():AddItem("MilitaryDrop.MilitaryMemo")
getPlayer():getInventory():AddItem("MilitaryDrop.Codebook")
```

These read the server's memory: they work in single player, not from a multiplayer client.

## Multiplayer notes

- The server decides and checks everything; clients never receive the random frequency or the code (only the memos and the numbers station give them).
- A walkie-talkie must be in hand to transmit: the mod takes it in hand automatically.
- Three wrong codes from one player do not silence the base for the others.
