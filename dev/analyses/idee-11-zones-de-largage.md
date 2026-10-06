# Idée 11 — Zones de largage définies par l'admin (serveurs PvP) : analyse d'impact et plan

Analyse du 2026-10-05, en lecture seule. **[C]** signale ce qui est confirmé dans les sources, **[S]** ce qui est supposé ou reste à vérifier en jeu. **Rien n'a été testé en jeu.**

- **Origine** : discussion Discord des 4 et 5 octobre 2026. *umachwan [ERSC]*, admin d'un serveur PvP, l'a proposée et *batman-fr* l'a acceptée.
- **Suivi** : ZONE-01 à ZONE-08 dans [SUIVI.md](../SUIVI.md).
- **Calendrier** : prochaine évolution, après la publication de Mayday (MAY-01 à MAY-04).

## Décisions de l'utilisateur (2026-10-05)

- **Repli sans zone** : le mod utilise d'abord les villes vanilla, si la carte vanilla est chargée, puis la proximité, avec un avertissement à l'admin (2.5).
- **Leurre** : il tombe dans une zone, comme un vrai largage. Le formulaire propose le secteur (la ville) au lieu de N/E/S/O. Avec un seul secteur, le leurre tombe dans une autre zone de ce secteur, tirée au hasard (2.4).
- **Vol** : la pénalité de CONF-04 (−5 au demandeur si un joueur extérieur ouvre la caisse) reste **toujours appliquée**, sans option. ZONE-07 est abandonné (2.7).
- **Outil d'admin en jeu** : il est livré **dès la première version**, avec le fichier `dropzones.txt` (2.3).
- **Eau** : une caisse ne tombe **jamais** dans l'eau, quel que soit le mode : zone, ville vanilla ou proximité (2.4).

## 1. Contexte et faisabilité

### Ce que fait le mod aujourd'hui [C]

- Un appel accepté ouvre le formulaire de réquisition (REQ-01). Le serveur choisit ensuite le point avec `Server.chooseDropPoint(player, sector)` (`server/MilitaryDrop/MilitaryDrop_Server.lua:600`).
- Le point est tiré dans un anneau `DropMinDistance`-`DropMaxDistance` (150-400 cases) **autour du demandeur** (`Server.ringPoint`, `:362`). Il est posé sur la terre ferme : une route `Nav` (`roadPointNear`), sinon le pied d'un bâtiment (`buildingPointNear`). La métagrille ne connaît pas l'eau. Sans point valable, la caisse tombe près du demandeur (DROP-03).
- Le leurre (LEURRE-01) choisit un secteur N, E, S ou O de l'anneau (`Server.SECTOR_ANGLES`). S'il ne trouve pas de point, il est refusé plutôt que posé près du demandeur.
- La caisse est posée seulement à l'arrivée d'un joueur à 30 cases au plus, quand la case est chargée (DROP-02). La grille est annoncée à tous les auditeurs (RADIO-01), puis répétée toutes les `DropRepeatHours` (DROP-05).
- Confiance (CONF-04) : le demandeur qui ouvre gagne +10 et un membre de sa faction +5. Si un joueur extérieur ouvre, le demandeur perd 5.

### Ce que demandent les serveurs PvP

Sur un serveur qui sépare des zones PvE et PvP, un point tiré autour du demandeur tombe le plus souvent en zone PvE. La caisse annoncée peut alors être prise sans risque. L'admin veut que **chaque largage tombe dans une zone contestable qu'il a définie**, avec plusieurs points d'intérêt par ville (parc central, immeuble, centre commercial) tirés au hasard. Ainsi, personne ne peut camper le point exact.

Précisions d'umachwan :
- sans zone définie, un repli sur les villes convient ;
- si plusieurs villes sont définies (Louisville et Raven Creek), la caisse va dans **la plus proche de la station qui appelle** ;
- il faut **plusieurs zones par ville** ;
- une option d'administration choisit entre largage par zones et largage par proximité.

### Moteur et projet

- **[C] Zones non-PvP vanilla** : `NonPvpZone` est exposée à Lua (`LuaManager.java:2461`). Elle offre `getNonPvpZone(x, y)` et `getAllZones()` (`zombie/iso/areas/NonPvpZone.java:70-79`).
- **[C] Refuges** : ils se lisent par `SafeHouse.getSafeHouse(square)` ou `getSafehouseOverlapping(x1, y1, x2, y2)` (`SafeHouse.java:148-176`). Le mod peut donc refuser ou signaler une zone de largage qui chevauche une zone non-PvP ou un refuge.
- **[S] Mêmes listes côté serveur** : il reste à vérifier que ces listes sont bien remplies sur le serveur dédié au moment du chargement des zones.
- **[C] Villes vanilla** : les centres des villes (annotations de `worldmap-annotations.lua`) sont relevés dans `.claude/pz-knowledge/knox-geography.md` : Louisville 13077,2238 ; Valley Station 13447,5278 ; West Point 11654,6864 ; Muldraugh 10754,9926 ; Riverside 6450,5430 ; Brandenburg 2056,6070 ; Ekron 634,9746 ; Irvington 2427,14185 ; Echo Creek 3589,10952 ; March Ridge 10130,12801 ; Fallas Lake 7253,8279 ; Rosewood 8159,11661.
- **[C] Cartes de mod** : la liste des cartes chargées se lit par `getWorld():getMap()`, sous la forme de noms de dossiers séparés par `;`. Les villes d'une carte de mod sont inconnues du mod.
- **[C] Fichiers du serveur** : le mod lit et écrit déjà `Zomboid/Lua/MilitaryDrop/requisition.txt` (REQ-09, `MilitaryDrop_LotsFile.lua`). `getFileWriter` n'accepte que les extensions `ini`, `cfg`, `txt`, `log`…
- **[C] Secrets** : toute ModData globale publique est lisible par les clients (`MilitaryDrop_Secrets.lua`). Le choix de la zone d'un largage reste dans l'état privé jusqu'à l'annonce.
- **[C] Outil d'admin vanilla à imiter** : `ISAddNonPvpZoneUI` trace une zone non-PvP par deux coins.
- **[C] Droits** : les menus d'admin du mod (SRC-09, MAY-04) contrôlent déjà les droits par `checkPermissions`.

## 2. Conception

### 2.1 Mode de placement (ZONE-01)

Nouvelle option sandbox `DropPlacement` :

| Valeur | Comportement |
|---|---|
| 1 — Proximité (défaut) | Comportement actuel : anneau autour du demandeur. Rien ne change pour les serveurs existants. |
| 2 — Zones | Largage dans une zone d'admin. Sans zone utilisable : repli décrit en 2.5. |
| 3 — Zones si possible | Une zone si l'une d'elles est à moins de `DropZoneMaxDistance` du demandeur, sinon la proximité. Cette valeur sert aux grandes cartes où une seule ville est contestée. |

Le largage forcé de l'admin (APPEL-05) n'est pas concerné.

### 2.2 Modèle et stockage (ZONE-02)

- **Secteur** : un nom libre (`Louisville`, `Raven Creek`) qui regroupe des zones.
- **Zone** : elle comprend :
  - un secteur ;
  - un nom affichable (`Central Park`) ;
  - un rectangle `x1, y1, x2, y2` au niveau 0, au format des zones non-PvP et des refuges vanilla ;
  - un poids (1 par défaut) ;
  - un indicateur actif.
- **Fichier du serveur** : `Zomboid/Lua/MilitaryDrop/dropzones.txt`, avec le même lecteur et le même style que `requisition.txt` (données Lua, commentaires, erreurs écrites dans le journal avec le numéro de ligne). Le fichier est créé vide avec un exemple commenté.
- **Carte attendue** : le fichier porte la carte attendue (`map = "Muldraugh, KY;RavenCreek"`). Les zones dont la carte n'est pas chargée sont ignorées, avec un avertissement.
- **Pourquoi un fichier** : l'admin d'un serveur dédié peut l'éditer, le sauvegarder et le copier sans lancer le jeu, comme les lots. Les zones dépendent de la carte, pas de la partie.

### 2.3 Outil d'admin en jeu (ZONE-03), dès la première version

> **Remplacé le 2026-10-06** (demande de l'utilisateur après test en jeu) : le menu contextuel ci-dessous est supprimé au profit d'un bouton du panneau d'admin vanilla (menu de debug en solo), d'une fenêtre calquée sur les zones d'animaux et d'un tracé au clic gauche. Parcours actuel : `docs/guide/fr/06-server-admin.md`, « Outil en jeu » ; suivi : `dev/SUIVI.md`, ZONE-03.

- Clic droit sur une case, puis « Military Drop (admin) », puis « Zones de largage ».
- **Coin 1 ici**, puis **Coin 2 ici**. Une fenêtre `ISTextBox` demande ensuite le secteur et le nom. Un secteur déjà connu peut être choisi dans une liste.
- **Liste** des zones par secteur, avec activation, désactivation et suppression. Un raccourci « Aller à » sert à vérifier une zone.
- Le serveur revérifie les droits (`checkPermissions`), valide la zone (2.4 et ZONE-08), écrit `dropzones.txt` et le recharge. Le client n'envoie que des coordonnées et des noms, jamais le fichier.
- Pendant l'édition, le contour des zones s'affiche **chez l'admin seulement**.

### 2.4 Choix du point (ZONE-04)

1. **Secteur** : selon `DropZoneChoice`, le serveur prend soit **le plus proche** de la station qui appelle (défaut, demande d'umachwan ; distance au bord de la zone la plus proche du secteur), soit un secteur **au hasard**.
2. **Zone** : le serveur fait un tirage pondéré parmi les zones actives du secteur.
3. **Case** : le serveur tire une case dans le rectangle, puis contrôle la terre ferme :
   - `roadPointNear` et `buildingPointNear` sont **bornés au rectangle** ;
   - si la case est chargée, elle est contrôlée tout de suite (`landingSquareAt`, `findLandingNear` limité à la zone) ;
   - sinon, elle est revérifiée à la livraison (DROP-02).

   Le contrôle ne sort jamais de la zone.

   **Règle absolue : jamais dans l'eau.** La métagrille ne connaît pas l'eau. Le tirage ne retient donc que des routes `Nav` ou le pied d'un bâtiment, jamais une case quelconque du rectangle. La livraison n'a lieu que sur une case chargée dont les quatre cases couvertes par la caisse sont hors de l'eau. **[C]** `Server.isFreeSquare` refuse `isWaterSquare()`, et `landingSquareAt` contrôle les cases x-1..x et y-1..y (`MilitaryDrop_Server.lua:257-271`). Le repli au sol (`findOpenGroundNear`) refuse aussi l'eau (`:318`). Si aucune case sèche ne se trouve dans la zone, la caisse n'est **pas** posée : le serveur tire une autre zone du secteur, puis répond `noSite` (2.8).

   > **Règle remplacée le 2026-10-06** (décision de l'utilisateur après test en jeu : « les drops peuvent tomber partout, sauf dans l'eau et dans les bâtiments ») : en zone, la case est tirée n'importe où dans le rectangle, hors bâtiment et hors de l'eau connue de la métagrille (zones « Water » des cellules déjà approchées) ; la livraison reste le contrôle sûr de l'eau. Plus d'avertissement `risk` ni `noRoad` ; le mode proximité garde route ou pied de bâtiment. Voir `dev/SUIVI.md` (2026-10-06).
4. **Distance minimale** : `DropZoneMinDistance`, 0 par défaut. Une valeur positive exclut les zones trop proches du demandeur, ce qui empêche d'appeler depuis l'intérieur d'une zone pour se servir aussitôt. Si toutes les zones sont exclues, le serveur revient au secteur le plus proche.
5. **Contrôle PvP** : une case dans une zone non-PvP ou un refuge est refusée.
6. **Leurre** (décision du 2026-10-05) : en mode zones, le leurre tombe dans une zone, comme un vrai largage.
   - Le formulaire remplace « secteur N/E/S/O » par la liste des secteurs de zones. Le nom de la ville est affiché, pas le nom des zones.
   - Avec un seul secteur, le choix disparaît : le serveur tire une zone de ce secteur au hasard.
   - Le contrat `RequisitionOrder` accepte alors `decoy = "<secteur>"`. Le serveur revérifie que ce secteur existe et qu'il est actif.
   - En mode proximité, le leurre garde N/E/S/O.

### 2.5 Repli sans zone (ZONE-05), décision du 2026-10-05

Quand `DropPlacement = 2` et qu'aucune zone n'est utilisable :

1. **Villes vanilla** : le mod utilise une table intégrée des centres de ville de Knox (§1), avec un rayon d'environ 150 cases.
   - La table ne sert que si la carte vanilla figure dans `getMap()` et que la métagrille connaît la case.
   - Chaque ville forme un secteur d'une seule zone. Le serveur la choisit avec la règle de 2.4 (la plus proche ou au hasard), puis cherche une case de terre ferme avec le contrôle actuel (route, puis bâtiment).
2. **Proximité** : à défaut, le mod reprend le comportement actuel. Il écrit un avertissement dans le journal du serveur et envoie un message à l'admin connecté.

Une carte de mod sans zone définie par l'admin retombe donc sur la proximité.

### 2.6 Annonce et visibilité (ZONE-06)

- L'annonce radio garde la grille. En mode zones, elle ajoute le **nom de la zone** (« LZ Central Park, grille … »). Option `DropZoneAnnounceName`, vraie par défaut.
- Le nom de la zone fait partie de l'annonce publique, comme la grille. Pour un leurre, le nom annoncé est celui de la zone tirée : il reste indiscernable.
- La liste des zones n'est **jamais** envoyée aux clients. Les joueurs les découvrent par les annonces.
- Le repère de carte (RADIO-02) reste inchangé.

### 2.7 Confiance (ZONE-07, abandonné)

Décision du 2026-10-05 : CONF-04 s'applique tel quel en mode zones. Le demandeur perd donc toujours 5 points quand un joueur extérieur ouvre sa caisse. Il n'y a pas d'option de pénalité de vol.

### 2.8 Diagnostic des zones (ZONE-08)

- Au chargement et à chaque création par l'outil, le serveur relève pour chaque zone :
  - la surface ;
  - les routes `Nav` trouvées dans le rectangle ;
  - les bâtiments ;
  - le chevauchement d'une zone non-PvP ou d'un refuge ;
  - la présence de la zone sur la carte (`isValidSquare`).

  Une zone sans route ni bâtiment est signalée comme **à risque**, parce que la métagrille ne connaît pas l'eau.
- Si aucune case de la zone tirée ne convient à la livraison, le serveur essaie une autre zone du même secteur, puis répond `noSite`. Il ne pose jamais la caisse hors zone.

### 2.9 Options sandbox

| Option | Défaut | Rôle |
|---|---|---|
| `DropPlacement` | 1 (proximité) | Mode de placement (2.1) |
| `DropZoneChoice` | 1 (le plus proche) | Choix du secteur (2.4) |
| `DropZoneMinDistance` (cases) | 0 | Exclusion des zones trop proches du demandeur |
| `DropZoneMaxDistance` (cases) | 1500 | Portée de la valeur « Zones si possible » |
| `DropZoneAnnounceName` | vrai | Nom de la zone dans l'annonce |

Textes et options dans les 8 langues du mod.

### 2.10 Hors périmètre

- Zones à plusieurs niveaux, toits et sous-sols : les zones restent au niveau 0.
- Polygones : seuls les rectangles sont pris en charge, comme en vanilla.
- Création de zones non-PvP par le mod : l'admin les gère lui-même.

## 3. Risques et limites

- **Zone mal tracée** : une zone sur l'eau ou entièrement bâtie peut ne fournir aucune case. Le diagnostic (ZONE-08) la signale, et un largage impossible répond `noSite` au lieu de tomber hors zone.
- **Point de rassemblement permanent** : avec un seul secteur et beaucoup de joueurs, la zone devient un lieu de rendez-vous fixe. C'est voulu sur un serveur PvP, à régler avec le délai global (APPEL-04).
- **Leurre moins surprenant** : en mode zones, tout le monde sait déjà où regarder, et seule la sirène le distingue. Il reste indiscernable avant l'ouverture.
- **Villes vanilla et zones au bord de l'eau** : Louisville, Riverside et Brandenburg bordent l'Ohio, et un admin peut tracer une zone sur un lac. La règle « jamais dans l'eau » (2.4) s'applique : seules des routes ou des pieds de bâtiment sont tirés, et la livraison revérifie l'eau sur les quatre cases. Le risque est donc un **largage refusé** (`noSite`), pas une caisse noyée. Tests `lupa` et test en jeu dédiés (5).
- **[S] Zones non-PvP sur le serveur dédié** : il faut vérifier en MP que `NonPvpZone.getAllZones()` est rempli sur le serveur dédié au moment du chargement des zones.

## 4. Options écartées

| Option | Raison |
|---|---|
| « Larguer hors de toute zone non-PvP » | Le reste de la carte est immense et sans intérêt : l'admin veut des lieux choisis. On garde seulement le contrôle de chevauchement. |
| Zones gardées seulement dans la ModData de la partie | Elles ne s'éditent pas hors du jeu et ne se copient pas d'un serveur à l'autre. |
| Zones envoyées aux clients et marquées sur la carte | Cela encourage le camping et contredit l'imprévisibilité demandée. |
| Table intégrée de villes pour les cartes de mod | Elle serait impossible à maintenir et fausse au premier changement de la carte. |
| Option de pénalité de vol | Décision du 2026-10-05 : CONF-04 reste identique dans tous les modes. |
| Leurre gardé autour du demandeur, ou désactivé, en mode zones | Décision du 2026-10-05 : le leurre suit les zones. Gardé hors zone, il serait le seul largage reconnaissable. |

## 5. Plan par étapes

1. **Données** : lecteur et écrivain de `dropzones.txt` (réutilisation de `MilitaryDrop_LotsFile`), modèle secteur et zone, carte attendue, diagnostic (ZONE-02, ZONE-08). Tests `lupa` : fichier invalide (ligne citée), carte non chargée, zone à risque, chevauchement non-PvP ou refuge.
2. **Choix du point** : `DropPlacement`, choix du secteur, tirage pondéré, case dans le rectangle, distance minimale, repli vers les villes vanilla puis vers la proximité (ZONE-01, ZONE-04, ZONE-05). Tests `lupa` avec métagrille simulée, dont une zone à moitié sur l'eau et une zone entièrement sur l'eau : aucune caisse posée sur une case d'eau, et `noSite` pour la seconde.
3. **Leurre** : secteurs dans la réponse « form » et dans `RequisitionOrder`, revalidation au serveur, formulaire (ZONE-04).
4. **Annonce** : nom de la zone dans les messages radio, traductions (ZONE-06).
5. **Outil d'admin** : menu, coins, fenêtre de saisie, liste, contour local, commandes réseau et droits (ZONE-03). Tests `lupa` : commande forgée par un non-admin, coordonnées hors carte.
6. **Validation en jeu** :
   - **Solo** : tracer deux secteurs avec l'outil, puis appeler depuis chacun. Vérifier que la caisse tombe dans la bonne zone, que l'annonce porte le nom de la zone, que le fichier se recharge, qu'un leurre tombe en zone et que le repli fonctionne sans zone. Tracer aussi une zone à cheval sur un plan d'eau et une ville au bord de l'Ohio (Riverside), puis forcer plusieurs largages : aucune caisse dans l'eau.
   - **MP** (serveur dédié, 2 clients, PvP actif avec une zone non-PvP) : le largage tombe dans la zone PvP, le vol par l'autre client retire bien 5 points, et l'outil est refusé à un non-admin.
7. **Documentation** : guide de l'admin (`docs/guide/*/06-server-admin.md`), pages Steam, CHANGELOG.
