# Military Drop — documentation

Mod Project Zomboid Build 42.21 (`batman_MilitaryDrop`) : appeler l'armée par radio militaire, réquisitionner du matériel largué par hélicoptère, gagner la confiance de la base par des missions et diriger sa station depuis un poste de liaison.

La documentation de développement est en français ; le wiki joueur existe en anglais et en français. La présentation GitHub est le [README](../README.md) du dépôt, l'historique des versions le [CHANGELOG](../CHANGELOG.md).

Version : **0.8.0**, publiée le 2026-10-27. Le [guide français](wiki/fr/Home.md) et le [guide anglais](wiki/en/Home.md) décrivent cette version, dont les [relais](wiki/fr/04-trust-and-missions.md), la [console admin](wiki/fr/06-server-admin.md) et le [sous-mod RJ-93](wiki/fr/10-radio-jammer.md). Les fichiers `README.steam*` portent les descriptions multilingues ; la note Steam destinée aux joueurs est [workshop-changenote.md](../workshop-changenote.md), distincte du changelog technique.

## Documents

| Document | Rôle |
|---|---|
| [architecture.md](architecture.md) | Architecture logicielle : arborescence du mod, modules Lua par côté, flux, persistance, intégrations, outillage. |
| [developpement.md](developpement.md) | Architecture modulaire validée, responsabilités et migration du correctif poste/nettoyage. |
| [specifications-fonctionnelles.md](specifications-fonctionnelles.md) | Fonctionnalités vues par le joueur et l'admin (F01 à F16), solo et MP, limites connues. |
| [specifications-techniques.md](specifications-techniques.md) | Contrats : objets et recettes, commandes réseau et contrôles serveur, ModData, fichiers, migrations, traductions, options du bac à sable. |
| [ameliorations-et-idees.md](ameliorations-et-idees.md) | Améliorations de code et idées de fonctionnalités, états et sélection planifiée. |
| [wiki/](wiki/Home.md) | Source du wiki GitHub : guides joueur et admin en anglais (`en/`) et en français (`fr/`). |
| [images/](images/) | Images de la documentation, du README et de la page Steam. |

### Images

| Dossier | Contenu |
|---|---|
| [images/screenshots/](images/screenshots/) | Captures en jeu et rendus hors jeu utilisés par le wiki (`ingame-*`, `map-symbol-*`, `*-en`/`*-fr`…), la page Steam (`walkie-logistics.png`, `crate-trunk.png`…) et les captures brutes `shot1.png` à `shot18.png`. |
| [images/art/](images/art/) | Illustrations : bannière Steam (`banner.png`), bandeaux de section (`art-*.png`) et grandes illustrations (`steam-*.png`). |

Les URL `raw.githubusercontent.com/.../main/docs/images/...` des descriptions Steam (`README.steam*`, `workshop.txt`) et du wiki pointent vers ces dossiers.

## Wiki

Les pages de `wiki/` sont rédigées avec des liens relatifs (pages voisines, `../../images/...`). `tools/wiki_sync.py` les convertit pour le wiki GitHub : `wiki/Home.md` devient `Home`, `wiki/<langue>/Home.md` devient `EN-Home` ou `FR-Home`, `NN-sujet.md` devient `EN-NN-sujet` ; la barre latérale du wiki est assemblée à partir de `wiki/<langue>/_Sidebar.md`, et les images pointent vers la branche `main`.

```
git clone https://github.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP.wiki.git <wiki>
python tools/wiki_sync.py docs/wiki <wiki> --check   # liste sans écrire
python tools/wiki_sync.py docs/wiki <wiki>           # écrit, puis commit et push du wiki
```

Pousser d'abord `main` (images), puis le wiki. Une capture manquante est signalée dans la page par `> Capture à faire : <description>`.

## Vérifications

```
pip install lupa pillow
python tests/run_tests.py
python tests/check_mayday_assets.py
```
