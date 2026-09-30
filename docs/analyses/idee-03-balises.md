# Idée 3 — Balises, détecteur et chasses au trésor : analyse d'impact et plan

Analyse du 2026-09-30, en lecture seule (sous-agent). Sources : Military Drop, Java 42.21 décompilé, Lua et scripts vanilla. **Rien n'a été testé en jeu.**

## 1. Faisabilité en 42.21

**Confirmé par les sources :**
- **Brouillage radio vanilla : inutilisable en MP.** `SendTransmission(..., signalStrength)` brouille le texte au-delà de 90 % de la portée et coupe à 3 cases ou moins (`ZomboidRadio.java:579-592, 693-704`). Mais le serveur envoie `sourceX` et `sourceY` à toutes les connexions (`GameServer.java:3537-3547`, `WaveSignalPacket.java:72`) : un client modifié lirait la position exacte de la balise.
- **Direction du joueur côté serveur : possible.** Le serveur applique la direction envoyée par le client (`NetworkPlayerAI.java:469-492`), et `getForwardDirection` et `getDirectionAngle` existent (`IsoGameCharacter.java:2570-2626`). On peut donc simuler côté serveur une antenne directionnelle.
- **Détecteur à pile en objet `base:drainable`, comme la lampe `Torch`** : `ActivatedItem`, `UseDelta`, `KeepOnDeplete` et le tag `base:usesbattery`.
  - Les recettes vanilla `InsertBattery` et `RemoveBattery` visent ce tag (`recipes_electrical.txt:3-35`).
  - « Allumer » est proposé en main ou attaché (`ISInventoryPaneContextMenu.lua:248-252, 866-872, 2880-2884`), et `syncItemActivated` pose l'état sur le serveur.
  - Limite : l'usure de la pile est décidée par le client.
- **Objet de type `Radio` écarté** : le personnage n'a qu'une `equipedRadio`, et en solo seule elle reçoit les chaînes. Tenir le détecteur rendrait le talkie militaire sourd.
- **Secret à protéger.** Toute ModData globale est lisible par tout client (`GlobalModData.java:174-193`). Or le code actuel y écrit `pending`, `flights` (avec `tx`, `ty`) et `lastDrop`. `FlightStart` envoie aussi `tx`/`ty` à tous, et `DropAnnounce` envoie `x`/`y` à tous. **Si l'annonce ne donne plus qu'un secteur, ces fuites deviennent bloquantes** (même problème pour le leurre de l'idée 9).
- **Chunks non chargés** : la distance se calcule sur des données. `IsoMetaGrid` est exposé (`getZoneAt`, `getBuildingAt`, `getMinX`/`getMaxX`, `IsoMetaGrid.java:186-340`), ce qui permet de choisir un point lointain sans le charger.
- **Son** : bip local sans paquet (`getFreeEmitter`, puis `playSoundImpl(nom, case)`). Parasites vanilla `RadioStatic` et `RadioZap`. Pour le bip, un son propre (fichier CC0), avec la parade `setVolume`.
- **Carte** : symboles `Question` et `Circle`, et la carte cachée d'`Announce` existe déjà.
- **Contenu** : `MilitaryDrop.Loot` sait déjà tirer des tables par catégorie.

**Supposé, à vérifier :**
- détection de l'eau hors chargement (aucune zone « eau » trouvée dans le metagrid) ;
- parcours de `getCell():getVehicles()` depuis Lua ;
- rendu d'un anneau de symboles sur la carte ;
- `playSoundImpl` pour un admin invisible.

## 2. Conception proposée

**Données du serveur.** Registre `beacons[id]` : `kind` (`drop`, `lost`, `cache`, `decoy`), `x`, `y`, `freq` (kHz, bande dédiée au pas de 200), `tag` (par exemple `MD-4K7`), `state` (`pending`, `placed`, `off`), `expires`, `sector` (`cx`, `cy`, `r`), `source` (tables de butin).
- Stocké dans la ModData « MilitaryDrop », avec les coordonnées et la fréquence **masquées** par une clé du serveur gardée dans un fichier, comme le code d'authentification.
- Sauvegardé avec le monde, donc sans désynchronisation. Si la clé est perdue, les balises sont perdues (le journal le signale).
- `pending`, `flights` et `lastDrop` passent dans ce même format.

**Messages réseau :**
- client vers serveur `Tune {freq}` : validé (pas de 200, dans la bande, une commande par seconde au plus) ;
- le serveur sonde lui-même, toutes les secondes, les joueurs qui ont en main un détecteur allumé et non vide ;
- serveur vers client `Reading {level 0-6, tag?}` : `tag` seulement au niveau maximal (8 cases ou moins) ;
- `DropAnnounce {cx, cy, r}` : secteur seulement ;
- `FlightStart` : réservé aux joueurs à moins d'environ 600 cases de la trajectoire.

**Modèle de signal (partagé, pur) :**
- distance effective = d / gain(θ), avec gain = 0,35 + 0,65·max(0, cos θ)², θ étant l'écart entre la direction du joueur et celle de la balise ;
- niveaux par paliers logarithmiques jusqu'à `BeaconRange`, avec des parasites au loin ;
- rendu : 0-2 parasites, 3-4 bips lents, 5 bips rapides, 6 identifiant.

Le joueur tourne sur lui-même pour chercher le signal maximal.

**Décision de l'utilisateur (2026-09-30) : indicateur visuel et sonore**, sur le modèle des détecteurs de caches de S.T.A.L.K.E.R. GAMMA (inspiration seulement). Le voyant clignote et le bip s'accélère à mesure que la distance effective diminue. Affinage proposé (maquette interactive de la page de présentation) :
- 12 niveaux au lieu de 6, seuils ≈ ×0,7 : 600, 420, 300, 210, 150, 105, 75, 52, 36, 25, 17, 8 cases (distance effective) ; au-delà de 600, parasites sans bip ;
- intervalle entre deux impulsions : 2,0 s × 0,8^(niveau − 1), soit 2 s au niveau 1 et ≈ 0,2 s au niveau 11 ; niveau 12 (≤ 8 cases) : voyant fixe et identifiant ;
- le serveur n'envoie que le niveau (0 à 12). Le client en déduit seul la cadence du voyant et du bip (son local, sans paquet).

**Interface.** Panneau déplaçable, visible quand le détecteur est allumé en main :
- fréquence avec boutons ±0,2 ;
- jauge et ligne de texte traduite ;
- niveau de pile ;
- bips locaux dont la cadence suit le niveau.

**Obtention du détecteur (`MilitaryDrop.BeaconDetector`) :**
- sur les zombies militaires ;
- par une `craftRecipe` qui accepte n'importe quelle radio (`OnTest` par `instanceof`, aucun nom vanilla) ;
- un exemplaire dans chaque caisse larguée.

**Chasses au trésor (`MilitaryDrop_Hunts.lua`, serveur) :**
- tirage périodique (options) ;
- point loin de **tous** les joueurs, dans une zone du metagrid (forêt, ferme, végétation), hors bâtiment ;
- causes dans le monde : « balise de détresse captée » annoncée sur la chaîne militaire, ou document trouvé sur un zombie ;
- types :
  - « largage perdu » : caisse du mod ;
  - « cache militaire » : conteneur posé et rempli par `Loot`. Le nom de sprite est à valider au regard de la règle « aucun nom codé en dur ».

**Fichiers :**
- nouveaux :
  - partagés : `MilitaryDrop_Signal.lua`, `MilitaryDrop_Cipher.lua` ;
  - serveur : `MilitaryDrop_Beacons.lua`, `MilitaryDrop_Hunts.lua` ;
  - client : `MilitaryDrop_Detector.lua` ;
  - scripts : objet, recette, son ;
  - traductions ;
- modifiés : `Server.deliver`, `Broadcast.dropped`, `Announce`, `Flights`, `Crate`, `Core`, `Notes`.

**Options sandbox :**
- `BeaconMode` (Exact / Secteur / Secteur + balise) ;
- `SectorRadius`, `BeaconRange`, `BeaconLifeHours`, `BeaconBand` ;
- `DetectorDropRate` ;
- `Hunts*`.

**Interactions avec les autres idées :**
- 4 : la station de chiffres diffuse la sous-fréquence et le secteur chiffrés, le carnet les déchiffre. Le module `Codes` et la clé serveur sont partagés.
- 5 : la confiance règle le rayon du secteur et la fourniture de la sous-fréquence.
- 6 : le formulaire peut demander un détecteur.
- 9 : un leurre est une balise `decoy`, avec sirène.

## 3. Risques et limites

- Triangulation et balayage patient des fréquences : c'est inhérent au jeu (on peut ralentir le réglage).
- La pile est décidée par le client (vanilla).
- Point lointain dans l'eau : recherche en rayon croissant au chargement.
- Une balise jamais chargée reste en attente jusqu'à son expiration.
- Coût du sondage : il ne porte que sur les joueurs équipés d'un détecteur.
- Tout est à tester en jeu, notamment `ModData.request` depuis un client : il ne doit voir que des valeurs masquées.

## 4. Plan par étapes

| # | Livrable | Tests `lupa` | Effort |
|---|---|---|---|
| 1 | `Signal` et `Cipher` (fonctions pures) | niveaux qui ne montent jamais quand la distance croît, gain directionnel, bornes, aller-retour du masquage | 0,5-1 j |
| 2 | Registre des balises et migration de `pending`/`flights`/`lastDrop` | aucune coordonnée en clair dans la ModData, fréquences uniques hors fréquences réservées | 1 j |
| 3 | Largage → secteur, balise, repère (`BeaconMode`) | caisse toujours dans le secteur, `DropAnnounce` sans x/y | 1-1,5 j |
| 4 | Détecteur : objet, panneau, sons, `Tune`, sondage serveur | commandes forgées refusées, cadence limitée, pas de mesure si l'objet est éteint, vide ou hors de la main, `tag` seulement au niveau 6 | 2 j |
| 5 | Obtention : zombies, recette `OnTest`, caisse | tirage, `OnTest` sans nom vanilla | 0,5-1 j |
| 6 | Largage lointain sans case chargée (étape 0 du plan v2) | point dans les bornes et hors bâtiment, déplacement en rayon croissant | 1 j |
| 7 | Chasses : causes, pose au `LoadChunk`, contenu tiré des tables | point loin de tous les joueurs, liste de joueurs vide = aucune décision | 2 j |
| 8 | Tests en jeu : solo, serveur dédié avec 2 clients, client qui lit la ModData | protocole | 1 j |

Total estimé : 9 à 11 jours.
