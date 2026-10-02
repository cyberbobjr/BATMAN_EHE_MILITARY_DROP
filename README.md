# Military Drop — Radio Supply Airdrops

**Project Zomboid Build 42.21 · Singleplayer & Multiplayer · Standalone**

Tune a military radio to the right frequency, give this week's code and requisition military supplies. A helicopter drops a crate far away and announces the grid to everyone listening, and the noise draws the dead. Earn the base's trust with reports, dog tags and public missions, and run your station from a liaison post.

This branch (`b42`) is a standalone rewrite for Build 42.21 of [Expanded Helicopter Events: Drop Military Cargo](https://steamcommunity.com/sharedfiles/filedetails/?id=3259615085) (Build 41, `main` branch). It no longer requires Expanded Helicopter Events.

- Mod ID: `batman_MilitaryDrop`
- **Player's guide**: [English](docs/guide/en/README.md) · [Français](docs/guide/fr/README.md) ([both](docs/guide/README.md))
- Server admins: [sandbox options, requisition lots file, admin tools](docs/guide/en/06-server-admin.md)
- Design notes, work plans and implementation status: [dev/](dev/) — internal working notes, **in French**: [dev/SUIVI.md](dev/SUIVI.md) (status of every feature), [dev/TEST-PROTOCOL.md](dev/TEST-PROTOCOL.md) (in-game test protocol), plans `dev/PLAN*.md`.
- Changes: [CHANGELOG.md](CHANGELOG.md)

## Repository layout

```
Contents/mods/batman_MilitaryDrop/
  common/          Build 42 common folder (crate model)
  42.21/           mod.info and media (Lua, scripts, translations, textures)
docs/guide/        player's guide (en/, fr/) and its images
dev/               internal design notes and status (French)
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

Luacheck, Lua syntax, translations, Steam descriptions (8,000-byte limit), `dev/SUIVI.md` and the Lua tests (game API simulated with `lupa`).

## License

MIT, see [LICENSE](LICENSE).

---

## Français

Réglez une radio militaire sur la bonne fréquence, donnez le code de la semaine et réquisitionnez du matériel militaire. Un hélicoptère largue une caisse au loin et annonce la grille à tous ceux qui écoutent… et le bruit attire les morts. Gagnez la confiance de la base par des rapports, des plaques d'identité et des missions publiques, et dirigez votre station depuis un poste de liaison.

Cette branche (`b42`) est une réécriture autonome pour la Build 42.21 de [Expanded Helicopter Events: Drop Military Cargo](https://steamcommunity.com/sharedfiles/filedetails/?id=3259615085) (Build 41, branche `main`). Elle ne dépend plus d'Expanded Helicopter Events.

- Guide du joueur : [docs/guide/fr/README.md](docs/guide/fr/README.md).
- Notes de conception et suivi (internes) : [dev/](dev/), en particulier [dev/SUIVI.md](dev/SUIVI.md) et [dev/TEST-PROTOCOL.md](dev/TEST-PROTOCOL.md).
