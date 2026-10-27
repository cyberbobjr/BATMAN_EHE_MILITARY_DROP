# RJ-93 radio jammer

[Français](../fr/10-radio-jammer.md) · [Guide home](Home.md) · [Administration](06-server-admin.md)

Part of the **unpublished 0.8.0 local testing build**. The RJ-93 belongs to the **optional** `batman_MilitaryDropJammer` submod in the same project. Enable it alongside `batman_MilitaryDrop` only if you want jamming. The main mod alone adds none. On servers add this ID to `Mods=`; no additional Workshop subscription.

## Crafting

The **Make radio jammer** recipe, in the Electrical category, requires **Electricity 3**.

| Item | Quantity | Use |
|---|---|---|
| Electronics Scrap | 20 | Consumed |
| Scrap Metal (`Base.ScrapMetal`) | 4 | Consumed |
| Electric Wire (`Base.ElectricWire`) | 2 | Consumed |
| Duct Tape (`Base.DuctTape`) | 2 | Consumed |
| Unbroken screwdriver | 1 | Kept |

Produces one `MilitaryDropJammer.RJ93`. The recipe does not include a battery.

## Insert a battery and switch on

1. Place the RJ-93 **on the ground**; a carried device does not transmit.
2. Stay nearby on the same floor, then right-click → **Control jammer**.
3. Select a compatible battery from your inventory and **Insert battery**.
4. Check the charge and use **Turn on**. The window shows state, remaining charge and range.
5. **Turn off** stops transmission without removing the battery. **Remove battery** returns its remaining charge and stops jamming. Closing the window leaves the device running; picking it up stops transmission.

A full battery lasts **24 game hours** by default; a used battery lasts less. An empty battery cannot power transmission. Charge and state survive saves/reconnections. The server resolves simultaneous actions: only one battery can be inserted or returned.

## Recognizing interference

Default radius: **100 tiles**. It affects the owner, allies and upper floors too: no faction or floor filter. It blocks new **Military Drop** requests and transmissions, rather than all radios in the game. Public base broadcasts remain audible; flights already underway continue.

Affected players hear static, receive an explicit **radio jamming detected** message and see **Link jammed**. Move away, switch off the device or remove its battery. A request rejected by the jammer consumes no credit, starts no cooldown and applies no trust penalty. The game also reports when the link returns.

The **MilitaryDropJammer** sandbox page controls activation, range and battery life; see [Administration](06-server-admin.md). For solo without this mechanic, leave the submod disabled.
