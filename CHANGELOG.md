# Changelog

Each `## <version> — <date>` section is published as the Steam Workshop change note
(`.claude/tools/steam_workshop_publish.py`). The top version must match `modversion=` in `mod.info`.

## 0.4.4 — 2026-10-09

### Fixed

- Singleplayer: a walkie-talkie switched on and clipped to the belt received the mod's broadcasts (military channel, numbers station) but showed nothing on screen. Each line is shown again above your character, once, as with a radio in hand. Deaf characters still hear nothing.
- Multiplayer: a radio carried in the main inventory but not held (belt included) now also shows the lines of the mod's channels above your character, once, instead of only in the radio chat. This works for frequencies set in the sandbox options; with the default random military frequency, which only the server knows, the lines stay in the radio chat. Nothing is added when Better Walkie Talkies is active.

## 0.4.3 — 2026-10-07

### Fixed

- Multiplayer: a server whose world was wiped kept the secrets of the previous world (military and numbers station frequencies, codebook table, weekly and fixed codes), because they are stored under the server name. A new world now draws new ones; a world that goes on keeps its own. Servers wiped before this update: see the admin guide (delete the two secret files once).
- Multiplayer, "Helicopters can be shot down by players" option (off by default): a shot could be ignored because the server judged ammunition from a stale copy of the weapon. The server now counts any real shot, still checking the weapon, distance and heading.
- Multiplayer: mission titles on the liaison post console were shown in the server's language (or as raw keys); they now follow each player's language.

## 0.4.2 — 2026-10-07

### Fixed

- Multiplayer (dedicated and hosted servers): the numbers station, military memos, codebooks and handwritten notes showed translation keys such as `IGUI_MilitaryDrop_Numbers_Group` instead of text. They are now written in the server's language. Documents created before this update keep their old text: new ones are correct.

## 0.4.1 — 2026-10-07

### Fixed

- The Fulton test menu (right-click in the world) is shown to admins only in multiplayer, and the server refuses its commands from other players. In singleplayer it stays a debug-mode tool.

## 0.4.0 — 2026-10-07

### Added

- **Fulton extraction.** Send intelligence and gear to Command by balloon and earn trust.
- How: on a military radio, **Logistics** section, **Request a Fulton pick-up** (30 game minutes to release). Put a **Fulton recovery kit** on the ground outside and fill it like a bag (the balloon is already inside). Right-click the kit, **Inflate and release the Fulton**, with a **Helium tank** in your inventory.
- A confirmation lists what Command will use. The balloon rises, an aircraft snatches it, Command acknowledges on the radio in your hand and in the liaison post log, and the military channel announces the sector.
- Command pays for ID cards, passports and badges of other people, paperwork, stash maps and military NBC gear, within the daily cap. With Zombie Virus Vaccine: samples and vaccines too, and the cure outside the cap.
- Craft the kit (balloon envelope and harness bag parts, vanilla wire) or repair a damaged one found in army storage, on a downed helicopter's pilot or in a supply crate without an order. Helium tanks hold four inflations (gift and toy stores, army storage); an empty tank can be cut up with a blowtorch.
- New sandbox options: `FultonValue`, `FultonWindowMinutes`, `FultonLootRate`.
- Simpler Workshop page: fewer screenshots, the full guide stays on the wiki.

### Changed

- The daily trust cap (`TrustDailyCap` sandbox option) now defaults to 10 instead of 8. Existing games keep their saved value.

### Fixed

- Opening the liaison post console no longer throws a Lua error in games whose post journal still holds entries written before 0.3.3: those older lines are shown as they were recorded.
- The recipes that unpack recovered avionics, mechanical and metal bundles now show their translated names instead of their internal recipe names.

## 0.3.3 — 2026-10-07

### Fixed

- Private radio replies from Logistics now display normal dialogue in hosted multiplayer games instead of translation keys such as `IGUI_MilitaryDrop_Reply_ReportAlready`. Replies are translated on each player's client, in their chosen language, rather than on the server. This covers situation reports, dog tags, reconnaissance, cleanup status and radio checks.
- New liaison-post journal entries keep the reply's translation key and parameters and are translated when viewed, including lists of soldiers' names and flight-recorder acknowledgements. Repeated entries still group correctly. Older journal entries are not migrated or supported by the new format.

## 0.3.2 — 2026-10-06

### Fixed

- The base now stops repeating a drop's grid on the radio as soon as its crate has been emptied: taking at least one case out of the crate (or picking up one of the cases left on the ground), or dismantling the crate, counts as found. Before, only opening a supply case stopped the reminders. Reputation rules are unchanged: only opening a case decides who recovered the drop.
- With **Supplies survive a crash** on, a crashed drop keeps its order until the supplies land at the wreck, even more than a week later: they no longer fall back to random supply cases.
- The server log now always reports a supply crate that gets random supply cases although a drop was expected (drop record missing, or no order while the requisition form is on), and a crate trunk filled outside a drop. This should explain an admin order reported as delivered with random cases after several quick admin drops, which could not be reproduced.
- Compatibility with Specific Loot (KI5) and other mods that refill vehicle containers: such a mod refilled the supply crate a few seconds after it landed, and the order was replaced by random supply cases. Supply crates and helicopter wrecks now carry the marker these mods respect, crates of existing saves get it when loaded, and if another mod still refills a crate, the crate gets its own order back once (never twice, and never after it has been emptied).
- New server log lines to diagnose a crate with unexpected contents (search `console.txt` or `server-console.txt` for `crate contents`): what the engine will use to fill the crate at start, the contents of each crate as it lands, an alert when they differ from the order, and a line when a crate is refilled or its contents replaced later.

## 0.3.1 — 2026-10-06

### Mayday: the order is lost in a crash

- When a supply helicopter crashes, the ordered supplies are now lost with it by default: the crash site keeps the wrecks, salvage, crew, documents, horde and smoke, but no supply crate. A crash still never costs reputation.
- Server admins can bring back the old behaviour with the sandbox option **Supplies survive a crash**, now off by default. An existing game keeps the value saved with it.

## 0.3.0 — 2026-10-06

### Drop zones for PvP servers

- Server admins can now choose where supply crates fall, so that every drop lands in a contested area. New sandbox option **Drop placement**: near the caller (default, unchanged), drop zones, or zones only when one is near.
- Drop zones are rectangles grouped into sectors, usually towns: for example a park, a mall and a block of flats in Louisville. The nearest sector is used (or one at random), then one of its zones is drawn by weight, so nobody can camp the exact spot.
- The radio announcement and its reminders name the zone: "LZ Central Park, grid ...". An option turns this off.
- Players can pick the town: with **Drop zone sector** set to "Chosen by the player", the requisition form gets a **Drop sector** field. The exact zone and spot are still drawn inside that sector.
- In zone mode, the siren decoy falls in a zone too: the form offers the sectors instead of N, E, S and W.
- In a zone, the crate can land anywhere: grass, field, beach, path, road, parking lot. Never inside a building, in water, outside its zone, in a non-PvP zone or in a safehouse. A zone with no usable spot gives no drop, and the caller is asked to try again.
- Without any usable zone, drops use the vanilla towns (vanilla map only), then fall near the caller with a warning to the admins.
- Admin drops (**Force a supply drop**) follow the same rules as a player's call, with distances measured from the admin.
- Other new options: minimum distance to a zone, range of "zones if one is near", zone name in the announcement.

### Zone panel for admins

- Zones are kept in Zomboid/Lua/MilitaryDrop/dropzones.txt (created empty, with a notice) and can be managed in game: a **Military Drop Zones** button in the game's admin panel (debug menu in single player) opens a zone list modelled on the game's animal zones panel.
- Draw a zone on the ground with the left mouse button (drag, or two clicks), then give its name, sector and weight. Zones can be edited, redrawn, removed, enabled or disabled, and you can teleport to them.
- **Highlight** lights up the border of every zone on the ground, on the admin's screen only. The tool's messages stay in its window, and the zone list is never sent to players.
- Each zone's line shows its remarks (no open ground, overlap with a non-PvP zone or a safehouse, map not loaded); the red "problems" section lists only real errors of the file.

### Sandbox options without restarting

- Military Drop options changed during a game now apply right away, in single player (debug menu › Sandbox Settings) as on servers (admin panel › Sandbox Options). Before, a single-player change waited for the next load.
- Switching to the encrypted weekly code during a game starts the numbers station and puts the codebook in army storage.
- The two frequencies (military and numbers station) still need a restart: their tooltip now says so.

## 0.2.0 — 2026-10-05

### Mayday: supply helicopters can crash

- A supply helicopter can now go down (5% per flight by default, +15 points during a thunderstorm). Its MAYDAY on the military frequency marks an approximate sector on the map of players who hear it.
- The crash site holds two 3D wrecks (fuselage and tail), debris and the pilot's body, along with two zombie pilots in flight gear. The pilot carries a memo, a codebook and the **flight recorder**. Fire and smoke follow the game's fire rules; smoke is renewed for late arrivals.
- The ordered supplies are still delivered at the crash site, and a crash never costs reputation.
- Right-click a wreck to strip its parts step by step, then cut what remains with the game's usual rules. The server checks the required tools and skills. Each part yields a bundle drawn from the game's and mods' item categories.
- Server options: crash chance, storm bonus, effects (none, smoke, or fire and smoke), smoke duration, supplies at the crash site, salvage bundle size, pilot outfits and documents. Shooting helicopters down is optional and off by default; the server checks weapon, distance and heading.
- Admins can arm a crash for the next helicopter that takes off, including a forced drop or a decoy. The order is saved with the world and does not stack.

### Flight recorder and liaison post

- The liaison post console is now an affairs board. A list on the left shows what to process (flight recorders, dog tags), and the base's orders, with the game's item icons. The panel on the right shows the selected affair and its actions. Gamepad supported.
- Put a recovered flight recorder in the post's reading bay. Reading takes 10 in-game minutes while the post radio is on and powered. It pauses on a power cut and resumes later, and an ejected recorder keeps its progress. Once read, transmit it to the base on the military frequency for **+10 reputation**. This bonus ignores the daily cap and goes to the character who transmits, once per crash site (admin crashes included).
- Reading sounds: a tape-deck click on insertion, a quiet modem carrier while reading and a double click when done. Only players near the post hear them, zombies never do. They follow the sound effects volume and are adjustable in the game's advanced audio options.

### Walkie-talkies

- A walkie-talkie clipped to the belt now uses its battery while it is on, as it does in hand.
- Compatible with Better Walkie Talkies. When it is active, it keeps control of push-to-talk, voice chat and belt battery drain, and the base still hears what you say into your radio.

## 0.1.2 — 2026-10-02

### Breaking changes

- Existing collective reputation is not transferred: existing characters start at 25. Previous shared suspensions do not carry over. Earlier drops cannot change the new personal scores.

### Changes

- Reputation now belongs to each character, independently of account and faction. It persists through saves and reconnects; a new character starts at 25.
- Reports, daily gain caps, radio checks, clearance kills, requisition budgets and suspensions are personal. The requester earns +10 by opening their drop, +5 when a member of the calling faction opens it, or -5 when an outsider does. A different opener earns nothing.
- Shared liaison posts show the acting character's standing. Joining or leaving a faction never transfers reputation.
- Existing collective scores are preserved as legacy data, without transferring them to characters. Earlier drops do not affect the new scores.
- Player guide and all eight Workshop descriptions include the reputation gains/losses table, daily caps, liaison post bonuses and migration warning.

## 0.1.1 — 2026-10-02

- Missed the drop announcement? The base now repeats the grid on the military frequency every 6 hours of game time until someone opens a supply case of that drop (for up to 48 hours). As with the first announcement, only a radio that is on and tuned to the military frequency hears it and gets the map marker. Server admins can change the interval or turn it off (new sandbox option "Grid reminder every (hours)", 0 = off).
- Guide and Workshop page: real in-game screenshots of the walkie-talkie and of the codebook with a memo, smaller images on the Workshop page, and a clear reminder to keep a radio on and tuned.

## 0.1.0 — 2026-10-02

- First Build 42.21 release: standalone rewrite of Expanded Helicopter Events: Drop Military Cargo (Build 41), multiplayer-safe.
- Military documents shown like the game's newspapers: a typed memorandum with handwritten notes, and the codebook as an open kraft folder with a clear code grid.
- Requisition form: after a successful call, spend a budget of points (set by your trust) on 18 supply lots drawn from the game's own item categories (rations, water, medical, tools, ammunition, firearms, fuel...); higher lots unlock with trust. Mod items join their lot automatically.
- Military radios get a "Logistics" section in the game's radio window: enter the code, request a drop and make every exchange with the base (it replaces the right-click menu; open it with "Device Options").
- Server admins can edit, disable or add requisition lots in Zomboid/Lua/MilitaryDrop/requisition.txt (created with the defaults).
- Decoy drop: order a siren beacon in a chosen sector to pull hordes away; it looks exactly like a real drop until someone opens it.
- Faction trust with the base (call signs such as "Station Kilo-7"): recovered, lost or stolen drops, daily situation reports, soldiers' dog tags, public missions (reconnaissance, cleanup, radio check) and a command post console (log, missions, the team's dog tags to announce). Trust changes the drop delay and the base's replies; below 15 the line is cut for a few days.
- The military frequency is drawn at random for each game by default and written on the military notes (a fixed frequency can still be set in the sandbox options).
- A walkie-talkie clipped to the belt can be tuned ("Device Options") and stays on; in single player it hears the base, missions and drops.
- Reconnaissance missions put a marker on the map of players who hear the announcement.
- Dog tags are the game's own: the tags of fallen soldiers, named after them.
- Empty supply crates can be dismantled for wood, with the game's rules for wooden furniture (hammer and saw).
- The walkie-talkie is taken in hand automatically to transmit (belt or back); in multiplayer the server only trusts a radio held in hand.
- Optional Signal Smoke integration: when that mod is active, green smoke marks the crate for 60 in-game minutes (sandbox option).
- Weekly authentication code (changes every Monday at 00:00, previous code accepted for 24 hours): encrypted by a numbers station on shortwave and deciphered with military codebooks found on army zombies and in army storage. Sandbox option: no code, fixed code or weekly code in clear on the notes. After 3 wrong codes in a day, the base stops answering the caller until the next day.
