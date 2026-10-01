# Captures en jeu à faire

Note de travail (en français) pour compléter le guide. Les pages citent déjà ces fichiers : il suffit de déposer chaque capture dans `docs/guide/images/` sous le nom indiqué (PNG, minuscules), puis de relancer la vérification des liens.

Réglages communs : interface en **anglais** de préférence (les pages françaises réutilisent les captures anglaises, avec la mention « version anglaise »), police 1x, zoom par défaut, pas de fenêtre de debug ni de journal à l'écran, largeur 1280 à 1600 px après recadrage. Mode debug utile pour préparer la scène (voir `en/06-server-admin.md`, console de débogage).

| Fichier | Page | Quoi montrer | Réglages et cadrage |
|---|---|---|---|
| `ingame-helicopter.png` | 02 | L'ombre du rotor qui passe au sol et la flèche de direction de l'hélicoptère | Dehors, terrain dégagé, de jour. Option « Heures entre deux largages » à 1. Personnage au centre, flèche visible au bord de l'écran, ombre dans le champ. |
| `ingame-map-drop-marker.png` | 02 | La carte du monde avec le symbole « cible » vert du largage | Radio allumée sur la fréquence militaire au moment de l'annonce ; carte zoomée pour voir le symbole et quelques rues autour. |
| `ingame-crate-smoke.png` | 02 | La caisse posée au sol avec la fumée verte (Signal Smoke) | Signal Smoke actif. Plan large : caisse, fumée, quelques zombies de la horde. Peut servir d'en-tête Steam (voir plus bas). |
| `ingame-dismantle.png` | 02 | Le menu contextuel « Dismantle the crate » sur une caisse vide, avec son infobulle (outils) | Marteau et scie dans l'inventaire ; cadrer le menu et la caisse. |
| `ingame-crate-trunk.png` | 03 | Le coffre « Military Supply Crate » ouvert avec des caisses « Requisition Case: … » | Après une réquisition de 3 ou 4 lots différents ; panneau de loot lisible, caisse visible à côté. |
| `ingame-cleanup-horde.png` | 04 | La horde du nettoyage dans sa zone | « Missions (admin) » → « Launch a cleanup », aller à la grille ; plan large sur la horde. |
| `ingame-map-missions.png` | 04 | La carte avec l'œil bleu (reconnaissance) et le crâne rouge (nettoyage) | Lancer les deux missions en écoutant la fréquence militaire ; les deux symboles dans le même cadre si possible. |
| `ingame-sandbox-options.png` | 06 | La page « Military Drop » des options du bac à sable | Nouvelle partie, page Military Drop, haut de la liste ; recadrer sur la page. |

## Facultatif

- **En-tête** : `header.png` est un recadrage provisoire de `docs/shot4.png` (caisse et horde ; on y voit une caisse de leurre). Une capture de l'hélicoptère ou de la caisse fumante ferait un meilleur en-tête, au format bandeau (environ 1280 × 400).
- **Versions françaises** des captures en jeu (`ingame-console-missions.png`, `ingame-console-requisition.png`) pour les pages `fr/` : mêmes noms suffixés `-fr`, puis changer le lien dans les pages françaises.
- **Section Logistique en jeu** : la page 02 montre un rendu hors jeu ; une vraie capture de la fenêtre radio (talkie militaire, section ouverte) serait plus parlante.

## Captures déjà utilisées

Copiées depuis `docs/shot*.png` (non suivis par git, laissés en place) :

| Source | Fichier du guide |
|---|---|
| `docs/shot1.png` | `ingame-codebook-memo.png` (carnet, note, station de chiffres) |
| `docs/shot4.png` | `ingame-decoy-crate.png`, et `header.png` (recadrage) |
| `docs/shot5.png` | `ingame-console-missions.png` |
| `docs/shot6.png` | `ingame-console-requisition.png` |

Écartées : `shot2.png` (ancienne boîte de saisie du code, remplacée par la section Logistique) et `shot3.png` (console sans champ du code, version antérieure).

## Images de la page Steam

`README.steam` et `README.steam.fr` affichent les images par leur adresse brute sur la branche **`main`** :
`https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/guide/images/<fichier>`.
Elles ne s'afficheront qu'une fois `b42` fusionnée dans `main` et poussée. Aucun script ne génère ces descriptions : si la branche change, remplacer `/main/` dans les deux fichiers et dans `workshop.txt` (les trois doivent rester identiques pour l'anglais, et les liens identiques entre les deux langues : `tests/run_tests.py` le vérifie). Ne pas renommer une image utilisée par Steam sans mettre à jour ces fichiers.
