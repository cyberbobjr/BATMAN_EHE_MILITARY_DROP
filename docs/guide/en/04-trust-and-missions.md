# Trust and missions

[Français](../fr/04-trust-and-missions.md) · [Guide home](README.md) · Previous: [Requisition form](03-requisition-form.md) · Next: [Liaison post](05-liaison-post.md)

## Your station

For the base, your group is a **station** with a call sign, for example "Station Kilo-7". In multiplayer a station is a faction; a player without a faction is a station alone. In single player you are one station.

The base keeps a **trust** score for each station, from 0 to 100. A new station starts at **25**. You never see the number: the base tells you in words, in the tone of its answers and on the [liaison post](05-liaison-post.md) console:

| Trust | What command says |
|---|---|
| under 25 | Command distrusts you |
| 25 to 49 | Command is wary |
| 50 to 74 | Command trusts you |
| 75 and more | Command holds you in high regard |

## What trust changes

- **Wait between drops**: normal at 50, longer below (x1.25 at the start, x1.5 at 0), shorter above (x0.6 at 100).
- **Requisition**: a bigger budget and the higher tiers (II at 50, III at 75). See [Requisition form](03-requisition-form.md).
- **Line cut**: below **15**, the base refuses your drops for **3 days** of game time.

## Earn and lose trust

| Event | Trust |
|---|---|
| Your station opens the first case of its drop | +10 |
| Daily situation report | +1 |
| Each fallen soldier's dog tag announced | +2 |
| Recon confirmed first | +3 |
| Clearance: your station kills the most of the horde | +5 |
| Radio check answered in time | +1 |
| Drop lost (nothing opened within 48 h) | -10 |
| Drop opened first by another station | -5 |
| Repeated wrong codes (3 in an hour) | -2 |

- Everything except drops is limited to **+8 per day** of game time.
- Dog tags announced from your [liaison post](05-liaison-post.md) give 50% more.
- The server may enable a slow erosion: each day without contact, trust moves one point back toward 25.

These exchanges need **no code**: only a military radio tuned to the military frequency. They are in the **Logistics** section of the radio window (**Device Options**).

![Logistics section](../images/ingame-walkie-logistics-section.png)

*In game.*

## Daily report

**Send a situation report**: once per day of game time. A second report the same day is politely refused.

## Dog tags

Military zombies drop the game's own dog tags, engraved with the soldier's name. **Announce dog tags (N)** reads the names to the base:

- your own tag and blank tags do not count, nor a tag you wear or hold;
- each name counts once; an announced tag is set aside;
- when the daily limit is reached, the base says so and you keep the other tags for later.

## Missions

From time to time, the base gives an order to **all stations** on the military frequency. Missions are public: every station that hears them can compete. Only listeners get the map marker.

![Missions on the console and the announcement in game](../images/ingame-console-missions.png)

### Recon

*"All stations, Logistics. Recon required at grid X / Y. First station to confirm on site within 48 hours."*

A blue **eye** symbol marks the grid on your map. Go there and press **Confirm the recon** within **25 tiles** of the point. The first station gets +3.

### Clearance

*"All stations, Logistics. Infected horde reported within 40 tiles of grid X / Y, about 30 strong..."*

A red **skull** marks the zone. The horde appears when the first player comes near, out of sight. You have **72 hours** of game time.

- **Clearance status** asks the base how it is going: zombies of the horde brought down by your station, and how many are left.
- When **90%** of the horde is dead, the station that killed the most gets +5. Fire and traps kill zombies but credit nobody.


Map symbols of the missions: <img src="../images/map-symbol-recon.png" width="32" alt="Blue eye"> reconnaissance, <img src="../images/map-symbol-clearance.png" width="32" alt="Red skull"> clearance (see [Map symbols](02-calling-a-drop.md#map-symbols)).

### Radio check

*"All stations, Logistics. Radio check. Confirm reception on this frequency within 4 hours."*

Press **Confirm reception** in time. Every station that answers gets +1.

## Factions (multiplayer)

- Joining a faction: you take its trust.
- Leaving a faction: you keep its trust, capped at 50.
- A new faction starts at the lowest trust of its founders.
- Renaming a faction keeps its call sign.
