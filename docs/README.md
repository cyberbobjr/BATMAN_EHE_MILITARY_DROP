# Military Drop — documentation

Mod Project Zomboid Build 42.21 (`batman_MilitaryDrop`) : appeler l'armée par radio militaire, réquisitionner du matériel largué par hélicoptère, gagner la confiance de la base par des missions et diriger sa station depuis un poste de liaison.

La documentation de développement est en français ; le wiki joueur existe en anglais et en français. La présentation GitHub est le [README](../README.md) du dépôt, l'historique des versions le [CHANGELOG](../CHANGELOG.md).

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
| [annexes/](annexes/) | Plans, suivi, protocoles de test et recherches. |

### Annexes

Plan en cours : [améliorations sélectionnées I01 à I16](annexes/plans/plan-ameliorations-i01-i16.md), découpage, dépendances et critères de validation des 12 idées demandées le 2026-10-23.

Plan correctif : [échanges depuis le poste et comptage du nettoyage](annexes/plans/plan-poste-et-nettoyage.md), demandé le 2026-10-26 ; actions radio manquantes, règle de comptage mixte, migration et validations solo/MP.

Correctif local 0.7.1 : [résultats hors jeu et protocole restant](annexes/tests/correctifs-poste-nettoyage.md).

| Dossier | Contenu |
|---|---|
| [annexes/plans/](annexes/plans/) | [SUIVI.md](annexes/plans/SUIVI.md) (état de chaque élément, vérifié par `tests/run_tests.py`), plans d'implémentation [plan.md](annexes/plans/plan.md) (v1), [plan-v2.md](annexes/plans/plan-v2.md) (v1.1 à v1.5), [plan-v13.md](annexes/plans/plan-v13.md), [plan-v14.md](annexes/plans/plan-v14.md), [fulton-prototype.md](annexes/plans/fulton-prototype.md). |
| [annexes/tests/](annexes/tests/) | [test-protocol.md](annexes/tests/test-protocol.md) : protocole de test en jeu. |
| [annexes/recherches/](annexes/recherches/) | Analyses des idées 3 (balises), 8 (Mayday), 10 (extraction), 11 (zones de largage), 12 (Fulton : idée, conception, rendu) et [third-party-helicopter-mods.md](annexes/recherches/third-party-helicopter-mods.md). |

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
