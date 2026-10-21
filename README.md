# Military Drop — Radio Supply Airdrops

**Project Zomboid Build 42.21 · Singleplayer & Multiplayer · Standalone**

Tune a military radio to the right frequency, give this week's code and requisition military supplies. A helicopter drops a crate far away and announces the grid to everyone listening, and the noise draws the dead. Earn the base's trust with reports, dog tags and public missions, and run your station from a liaison post.

This branch (`b42`) is a standalone rewrite for Build 42.21 of [Expanded Helicopter Events: Drop Military Cargo](https://steamcommunity.com/sharedfiles/filedetails/?id=3259615085) (Build 41, `main` branch). It no longer requires Expanded Helicopter Events.

- Mod ID: `batman_MilitaryDrop`
- Requires [Belt Walkie-Talkie](https://steamcommunity.com/sharedfiles/filedetails/?id=3817018338) (`batman_BeltRadio`, which needs [TooltipLib](https://steamcommunity.com/sharedfiles/filedetails/?id=3694097672)) and [Signal Smoke](https://steamcommunity.com/sharedfiles/filedetails/?id=3811010882) (`batman_SignalSmoke`).
- **Player's guide** (source of the [GitHub wiki](https://github.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/wiki)): [English](docs/wiki/en/Home.md) · [Français](docs/wiki/fr/Home.md) ([both](docs/wiki/Home.md))
- Server admins: [sandbox options, requisition lots file, drop zones, admin tools](docs/wiki/en/06-server-admin.md)
- Developer documentation, **in French**: [docs/README.md](docs/README.md) (index: architecture, functional and technical specifications, improvements), [docs/annexes/plans/SUIVI.md](docs/annexes/plans/SUIVI.md) (status of every feature), [docs/annexes/tests/test-protocol.md](docs/annexes/tests/test-protocol.md) (in-game test protocol), plans in [docs/annexes/plans/](docs/annexes/plans/).
- Changes: [CHANGELOG.md](CHANGELOG.md)

## Repository layout

```
Contents/mods/batman_MilitaryDrop/
  common/          Build 42 common folder (crate model)
  42.21/           mod.info and media (Lua, scripts, translations, textures)
docs/              developer documentation (French), wiki source (docs/wiki/en, fr), images, annexes (plans, tests, research)
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

Luacheck, Lua syntax, translations, Steam descriptions (8,000-byte limit), `docs/annexes/plans/SUIVI.md` and the Lua tests (game API simulated with `lupa`).

## License

MIT, see [LICENSE](LICENSE).

Sounds of the liaison post reader bay come from Wikimedia Commons (public domain and CC0): see [source/sound/CREDITS.md](source/sound/CREDITS.md).

---

## Français

Réglez une radio militaire sur la bonne fréquence, donnez le code de la semaine et réquisitionnez du matériel militaire. Un hélicoptère largue une caisse au loin et annonce la grille à tous ceux qui écoutent… et le bruit attire les morts. Gagnez la confiance de la base par des rapports, des plaques d'identité et des missions publiques, et dirigez votre station depuis un poste de liaison.

Cette branche (`b42`) est une réécriture autonome pour la Build 42.21 de [Expanded Helicopter Events: Drop Military Cargo](https://steamcommunity.com/sharedfiles/filedetails/?id=3259615085) (Build 41, branche `main`). Elle ne dépend plus d'Expanded Helicopter Events.

- Guide du joueur : [docs/wiki/fr/Home.md](docs/wiki/fr/Home.md).
- Documentation de développement : [docs/README.md](docs/README.md) (index), en particulier [docs/annexes/plans/SUIVI.md](docs/annexes/plans/SUIVI.md) et [docs/annexes/tests/test-protocol.md](docs/annexes/tests/test-protocol.md).
