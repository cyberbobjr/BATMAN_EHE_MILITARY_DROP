# Helicopter crash (Mayday)

[Français](../fr/09-helicopter-crash.md) · [Guide home](Home.md) · Previous: [FAQ](08-faq.md)

Sometimes the supply helicopter never reaches the drop point. It goes down on the way, the base sends a MAYDAY on the military frequency, and the crash site becomes a place worth searching: wreck parts, the pilot's flight recorder, sometimes documents. The dead are already there.

> Capture à faire : the burning wreck and the tail on the ground, crew zombies nearby.

## Why a helicopter crashes

- **Mechanical failure**: each normal flight has a small chance to crash (5 % by default), more during a thunderstorm (+15 points by default).
- **Gunfire** (off by default): if the server enables it, shooting at an approaching helicopter can bring it down.
- **Admin order**: an admin can set the next helicopter to crash (see [Server admin](06-server-admin.md#helicopter-crash-mayday-branch)).

Admin drops and decoy drops never crash by chance or by gunfire. A crash has no effect on your trust either way.

## The MAYDAY

Keep a military radio on the military frequency: Logistics calls *"MAYDAY, MAYDAY! Logistics flight going down near grid X / Y. Search the area. No further contact."* The grid is the crash site. By default the ordered supplies are lost with the helicopter; the server can choose to deliver them at the site instead.

## The crash site

- The fuselage and the tail lie apart, burnt. Depending on the server: fire and smoke, smoke only, or nothing.
- The pilot's body carries the **flight recorder**, and, if the server allows it, a military memo and codebook. Sometimes a damaged [Fulton kit](07-fulton.md).
- Two crew members have risen in their flight suits, and the noise of the crash has drawn a horde.

## Recovering the parts

Stand next to the wreck (ground floor), right-click it and choose **Recover wreck parts**: the vehicle mechanics window opens. Each part needs a tool in your inventory and a skill level, and some parts only come off after another one:

| Part | Tool | Skill | After |
|---|---|---|---|
| Avionics | screwdriver | Electrical 2 | — |
| Radio rack | screwdriver | Electrical 1 | Avionics |
| Engine bay | wrench | Mechanics 2 | — |
| Rotor hub | wrench | Mechanics 1 | Engine bay |
| Skin panels | screwdriver | Welding 1 | Rotor hub (fuselage) |

The tail only has skin panels. Each part gives a **recovered bundle** (avionics, mechanical or metal) and a little experience. Right-click a bundle to unpack it: it holds several items drawn from the game's electronics, vehicle maintenance or metal materials, your mods' items included. The server checks tools, skills and distance again for every part.

Once every part is removed, you can cut up the wreck the vanilla way (**Dismantle Car Wreck**), with a welding mask. Before that, the option stays greyed out.

## The flight recorder

Bring the recorder to your station's [liaison post](05-liaison-post.md): insert it into the reading bay, keep the post radio on and powered for 10 in-game minutes (reading pauses on a power cut and resumes), then **Send to base**. The character who sends it gains trust, outside the daily cap, once per crash site.


## Dismantle a recorder — 0.8.0

Use **Dismantle flight recorder** in the **Electrical** category. It consumes one recorder and keeps an **unbroken screwdriver**, with no minimum skill. Returns **6 Electronics Scrap**, **1 Electric Wire** and **2 Scrap Metal**, plus **5 base Electricity XP**.

Both **transmitted and untransmitted** recorders are accepted. Transmission now returns the physical recorder to the sender; the same crash site still grants trust only once. TooltipLib identifies already-transmitted data, and these recorders no longer appear in the post’s pending list. Eject a recorder from the reading bay before dismantling it. Dismantling before transmission destroys that copy and prevents transmitting its data later. Recorders consumed by an older version are not recreated retroactively.
