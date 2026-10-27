# Military Drop — Radio Supply Airdrops

**Project Zomboid Build 42.21 · Singleplayer & Multiplayer · Standalone**

Tune a military radio to the right frequency, give this week's code and requisition military supplies. A helicopter drops a crate far away and announces the grid to everyone listening, and the noise draws the dead. Earn the base's trust with reports, dog tags and public missions, and run your station from a liaison post.

This project is a standalone rewrite for Build 42.21 of [Expanded Helicopter Events: Drop Military Cargo](https://steamcommunity.com/sharedfiles/filedetails/?id=3259615085) (Build 41). It no longer requires Expanded Helicopter Events.

- Mod ID: `batman_MilitaryDrop`
- Requires [Belt Walkie-Talkie](https://steamcommunity.com/sharedfiles/filedetails/?id=3817018338) (`batman_BeltRadio`, which needs [TooltipLib](https://steamcommunity.com/sharedfiles/filedetails/?id=3694097672)) and [Signal Smoke](https://steamcommunity.com/sharedfiles/filedetails/?id=3811010882) (`batman_SignalSmoke`).
- **Player's guide** (source of the [GitHub wiki](https://github.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/wiki)): [English](docs/wiki/en/Home.md) · [Français](docs/wiki/fr/Home.md) ([both](docs/wiki/Home.md))
- Server admins: [sandbox options, requisition lots file, drop zones, admin tools](docs/wiki/en/06-server-admin.md)
- Developer documentation, **in French**: [docs/README.md](docs/README.md) (architecture, functional and technical specifications, improvements).
- Changes: [CHANGELOG.md](CHANGELOG.md)

## Version 0.8.0 — local testing branch

Prepared on `feature/planned-improvements-testing`, **not published**. The wiki below describes this branch; the public GitHub wiki and Steam page are updated only after release.

- Helicopter and delivery noise attract existing infected; the configured drop horde remains.
- Repair relay cabinets with electronic scrap and earn Electricity XP. No generator required.
- Weekly Fulton bonuses, horde reports, supply-drop receipts and personal tier commendations.
- Administration: **Debug → Main → Military Drop Admin Menu** in solo debug; **right-click anywhere → Military Drop Admin Menu** for authorized MP admins. Includes communications (current code/frequencies), consolidated tools and separate mission success/closure. Drop-zone menus stay in place.
- Optional battery-powered **RJ-93 radio jammer** for PvP. Leave `batman_MilitaryDropJammer` disabled for a game without jamming. See [the jammer guide](docs/wiki/en/10-radio-jammer.md).

For a local test, enable `batman_MilitaryDrop` and its dependencies in the game's mod list. The game can load this project's `Contents/mods` directly. To test jamming, also enable `batman_MilitaryDropJammer`; on a dedicated server add this ID to `Mods=` alongside the main mod, using the same project build on server and clients. It is a second mod in this project, with no separate Workshop subscription.

Suggested player checks: [relay repair and radio actions](docs/wiki/en/04-trust-and-missions.md), [Fulton bonuses](docs/wiki/en/07-fulton.md), [administration](docs/wiki/en/06-server-admin.md) and [jammer battery controls](docs/wiki/en/10-radio-jammer.md). Verify nearby infected react to noise, rewards are granted once, the battery retains its charge after removal/reconnection, and broadcasts remain audible while calls are jammed.

## Repository layout

```
Contents/mods/batman_MilitaryDrop/
  common/          Build 42 common folder (crate model)
  42.21/           mod.info and media (Lua, scripts, translations, textures)
Contents/mods/batman_MilitaryDropJammer/  optional RJ-93 submod (common + 42.21)
docs/              developer documentation (French), wiki source (docs/wiki/en, fr), images
source/            asset sources and out-of-game preview tools (documents, console, form, radio section, crate)
tests/             checks without the game
legacy-b41/        Build 41 sources, kept for reference during the port (not published)
README.steam*      Steam Workshop descriptions (English = workshop.txt, French)
```

## Checks

```
pip install lupa pillow
python tests/run_tests.py
python tests/check_mayday_assets.py
```

Luacheck, Lua syntax, translations, Steam descriptions (8,000-byte limit), and the Lua tests (game API simulated with `lupa`).

## License

MIT, see [LICENSE](LICENSE).

Sounds of the liaison post reader bay come from Wikimedia Commons (public domain and CC0): see [source/sound/CREDITS.md](source/sound/CREDITS.md).

---

## Français

Réglez une radio militaire sur la bonne fréquence, donnez le code de la semaine et réquisitionnez du matériel militaire. Un hélicoptère largue une caisse au loin et annonce la grille à tous ceux qui écoutent… et le bruit attire les morts. Gagnez la confiance de la base par des rapports, des plaques d'identité et des missions publiques, et dirigez votre station depuis un poste de liaison.

Ce projet est une réécriture autonome pour la Build 42.21 de [Expanded Helicopter Events: Drop Military Cargo](https://steamcommunity.com/sharedfiles/filedetails/?id=3259615085) (Build 41). Il ne dépend plus d'Expanded Helicopter Events.

- Guide du joueur : [docs/wiki/fr/Home.md](docs/wiki/fr/Home.md).
- Documentation de développement : [docs/README.md](docs/README.md) (architecture, spécifications et améliorations).


### Version 0.8.0 — essai local

Préparée sur `feature/planned-improvements-testing`, **non publiée**. Le wiki du dépôt décrit cette branche ; les pages publiques restent celles de la version publiée.

Relais à réparer avec des déchets électroniques, primes Fulton hebdomadaires, signalements de hordes, accusés de réception, citations nominatives et nouvelle console d'administration sont prêts à essayer. La silhouette d'hélicoptère est retirée ; les sons et repères habituels restent.

Activez le principal `batman_MilitaryDrop` et ses dépendances dans le jeu. Le projet est chargé directement depuis `Contents/mods`. Le brouillage exige d'activer **en plus** `batman_MilitaryDropJammer`, fourni dans le même projet ; laissez-le désactivé pour jouer sans brouilleur. En MP, ajoutez cet ID à `Mods=` avec le principal et utilisez la même version du projet côté serveur et clients. Aucun abonnement Workshop distinct.

Pour l'essai réel : [missions et relais](docs/wiki/fr/04-trust-and-missions.md), [primes Fulton](docs/wiki/fr/07-fulton.md), [console admin](docs/wiki/fr/06-server-admin.md), [fabrication et interface du RJ-93](docs/wiki/fr/10-radio-jammer.md). Vérifiez notamment les gains uniques, la réaction des zombies aux bruits, la charge après retrait/reconnexion, et la réception des annonces malgré le brouillage.


Accès admin : **SP debug → fenêtre Debug → Main → Military Drop Admin Menu** ; **MP admin → clic droit n’importe où → Military Drop Admin Menu**. Aucune radio requise. Rubriques **Communications** (code en vigueur, fréquences) et **Outils** (largage forcé, crash programmé, tests Fulton). Les zones de largage gardent leur accès actuel. Redémarrer complètement le jeu après cette modification.
