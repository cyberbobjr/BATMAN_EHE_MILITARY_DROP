# Changelog

Each `## <version> — <date>` section is published as the Steam Workshop change note
(`.claude/tools/steam_workshop_publish.py`). The top version must match `modversion=` in `mod.info`.

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
