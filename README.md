# Military Drop — Radio Supply Airdrops

**Build 42.21 · Singleplayer & Multiplayer · Work in progress**

Tune a military radio to the right frequency, give the authentication code, and request an airdrop of military surplus. A helicopter flies in and drops a supply crate, and the noise draws the dead.

This branch (`b42`) is a standalone rewrite for Build 42.21 of [Expanded Helicopter Events: Drop Military Cargo](https://steamcommunity.com/sharedfiles/filedetails/?id=3259615085) (Build 41, `main` branch). It no longer requires Expanded Helicopter Events.

- Mod ID: `batman_MilitaryDrop`
- Work plan and design decisions: [docs/PLAN.md](docs/PLAN.md)
- The Build 41 sources are kept in `legacy-b41/` for reference during the port. They are not published.

## Layout

```
Contents/mods/batman_MilitaryDrop/
  common/          Build 42 common folder
  42.21/           mod.info and media (Lua, scripts, translations, textures)
tests/             checks without the game: python tests/run_tests.py
```

## Checks

```
pip install lupa
python tests/run_tests.py
```

## License

MIT, see [LICENSE](LICENSE).

---

## Français

Réglez une radio militaire sur la bonne fréquence, donnez le code d'authentification et demandez un largage de surplus militaire. Un hélicoptère arrive et largue une caisse… et le bruit attire les morts.

Cette branche (`b42`) est une réécriture autonome pour la Build 42.21 de [Expanded Helicopter Events: Drop Military Cargo](https://steamcommunity.com/sharedfiles/filedetails/?id=3259615085) (Build 41, branche `main`). Elle ne dépend plus d'Expanded Helicopter Events. Plan de travail : [docs/PLAN.md](docs/PLAN.md).
