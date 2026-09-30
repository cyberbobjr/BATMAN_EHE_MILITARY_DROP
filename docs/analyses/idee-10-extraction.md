# Idée 10 — Extraction : analyse d'impact et plan

Analyse du 2026-09-30, en lecture seule (sous-agent). Sources : Military Drop, Opération Artemis (code et conception), Java 42.21 décompilé et Lua vanilla. **Rien n'a été testé en jeu.**

## 1. Opération Artemis

**Ce que fait le mod.**
- Déroulé : un carnet trouvé sur un soldat zombie, puis la chaîne ARTEMIS sur **108,0 MHz** (option `OperationArtemis.RadioFrequency`), puis quatre lieux d'enquête (acte II), puis l'évasion de la base secrète. L'acte III (exfiltration) est atteint aujourd'hui.
- Actes 0 à 4 (`Artemis_Const.ACT`), avec `EXFILTRATION = 3` et `DONE = 4`.
- État **global au monde** (coopératif), dans la ModData `batman_Artemis`, transmise aux clients. Seul `Artemis_Store` y écrit. Champs utiles : `act`, `callCode` (« 7149 », appris au relais), `flags`.
- Module réseau `batman_Artemis`.
- `Artemis_NewCharacter` (solo) remet l'enquête à zéro sur `OnNewGame`.

**Conflit majeur : Artemis prévoit déjà la même fin.** Sa phase 4 (non codée) comprend :
- la route B « Hélicoptère » : relais, code d'appel, fusées, tenir la zone d'atterrissage par vagues ;
- un écran de fin avec chronique, et le choix « Terminer » (`exitToMenu`) ou « Continuer (épilogue) » ;
- un module `Artemis_EndingUI` et un moteur de vagues.

Sans contrat commun, on aurait deux hélicoptères, deux missions et deux écrans de fin. De plus, « Continuer » (le personnage reste) contredit l'extraction (le personnage part).

**Autres conflits :**
- **Fréquences.** 108,0 pour Artemis, 151,4 pour Military Drop, 112,2 réservée à HEF. Si deux chaînes tombent sur la même valeur, `AddChannel` échoue pour la seconde. Chaque mod doit réserver la fréquence de l'autre, lue par `getSandboxOptions():getOptionByName("OperationArtemis.RadioFrequency")`.
- **Stations de chiffres.** Artemis en a déjà une (code 7149), le vanilla aussi (95,0), et l'idée 4 en ajoute une. Il faudra des styles distincts (groupes OTAN côté Military Drop).
- **Notes sur les soldats.** Le filtre `NoteOutfits` (« Army ») touchera probablement les soldats posés par Artemis. Sans gravité.
- **Hordes et Siege Night.** Une mission de zone ne doit pas démarrer en même temps que l'épreuve de la base d'Artemis.
- **ModData.** Pas de collision (`MilitaryDrop` et `batman_Artemis`). Military Drop ne doit **jamais écrire** `batman_Artemis`.

**Intégration proposée : « Artemis raconte, Military Drop transporte ».**
- **Détection douce**, en lecture seule côté serveur : `getActivatedMods():contains("batman_OperationArtemis")` et `ModData.exists("batman_Artemis")`.
- **Événements partagés** : `LuaEventManager.AddEvent(nom)`, exposé et idempotent, déclaré par chaque mod :
  - `batman_OnExtractionAvailable` (serveur) ;
  - `batman_OnExtraction(username, info)` (serveur, avant le départ) ;
  - `batman_OnExtractionSummary(lignes, joueur)` (client, pour ajouter des lignes au bilan).
- **Les deux mods actifs** :
  - à l'acte III, le `callCode` d'Artemis, donné sur la fréquence militaire, **remplace le seuil de confiance** : la base veut le dossier ;
  - la mission de zone et l'hélicoptère sont ceux de Military Drop ;
  - Artemis écoute `batman_OnExtraction` : dossier porté, alors il passe l'acte à `DONE` par son propre `Progress.commit`, choisit sa fin et ajoute sa chronique au bilan ;
  - l'option « Continuer » d'Artemis n'est proposée que sans Military Drop, ou pour les joueurs restés au sol.
- **Chaque mod seul** : Military Drop garde l'extraction par la confiance, Artemis garde sa route B avec un hélicoptère sonore minimal.

Ce contrat est **à faire valider avant la phase 4 d'Artemis**.

## 2. Faisabilité en 42.21

**Confirmé statiquement :**
- **Nouveau personnage : seulement après une mort.** `IsoPlayer.OnDeath` déclenche `OnPlayerDeath` et `removeSaveFile`, et force la sauvegarde du joueur mort (`IsoPlayer.java:6096-6120, 1573-1586`). Au rechargement, un nouveau personnage est créé (`OnNewGame`, `IsoWorld.java:2154, 2245`). Le bouton « Nouveau personnage » de l'écran de mort passe par `CoopCharacterCreation` et exige un joueur mort (`ISPostDeathUI.lua:149-158`). `exitToMenu` seul garde le personnage vivant.
  - Sortie retenue : **mort mise en scène sans cadavre**, par `Kill(nil)` (`IsoGameCharacter.java:13451`), puis `square:removeCorpse(corps, false)`, synchronisé en MP par `RemoveCorpseFromMap` (`IsoGridSquare.java:2600-2619`). Le corps se reconnaît par `isPlayer()` et `getDescriptor()` (`IsoDeadBody.java:2110, 2209`).
  - Il faut cacher `ISPostDeathUI.instance[n]` et réutiliser ses rappels `onRespawn` et `onExit`.
  - `OnDeath` lâche les objets en main (`dropHandItems`) : vider les mains avant.
- **Côté serveur** : `OnCharacterDeath` s'y déclenche aussi (`IsoGameCharacter.java:4604`). `OnPlayerDeath`, lui, n'existe que côté client.
- **Bilan** :
  - `getHoursSurvived()` et `getTimeSurvived()` ;
  - `getZombieKills()` et `getSurvivorKills()` ;
  - textes vanilla `getGameTime():getDeathString(p)` et `getZombieKilledText(p)` (`GameTime.java:232, 301`).

  Les largages récupérés sont un compteur par joueur à créer (idée 5).
- **Vagues** : `addZombiesInOutfit` (13 arguments) renvoie une `ArrayList<IsoZombie>` (`LuaManager.java:8360`), ce qui permet de compter les survivants.
- **Hélicoptère posé** : le vanilla n'a aucun modèle d'hélicoptère. Un modèle original est possible par la même chaîne que la caisse (véhicule sans roues, `permanentlyRemove()`, `BaseVehicle.java:7261`).

**Supposé, à tester en jeu :**
- En MP, la mort déclenchée par le client (commande du serveur, puis `Kill`), puis le retrait du corps par le serveur.
- La réapparition, bloquée si l'option `DropOffWhiteListAfterDeath` est active (`ISPostDeathUI.lua:81`).
- La musique de mort vanilla.
- L'emprise physique d'un véhicule de 15 à 20 m.

Recommandation : **pas de modèle posé en v1** (ombre élargie, vol stationnaire bas, son, bruit). Le modèle vient en option plus tard.

## 3. Conception

**Données du serveur** (ModData `MilitaryDrop`, rien de secret) :
- `extraction[username]` : état (`locked` → `eligible` → `mission` → `inbound` → `boarding` → `done`), zone d'atterrissage, début, échecs ;
- `stats[username]` : largages récupérés, date d'extraction, et un identifiant de personnage remis à zéro par `OnNewGame` côté serveur (`CreatePlayerPacket.java:274`), pour que la confiance et les statistiques ne passent pas au personnage suivant.

**Messages réseau :**
- client vers serveur : `ExtractRequest` (radio, code, case choisie), `Board` ;
- serveur vers client : `ExtractState`, `Extract` (bilan et ordre de départ), plus `FlightStart` étendu (drapeau `land`, sans type secret).

Tout est revalidé sur le serveur : distance, vivant, éligibilité, cadence.

**Mission :**
- la zone d'atterrissage est une case extérieure libre de 3 × 3 près du joueur, donc toujours chargée ;
- la cause des vagues est le bruit du rotor et de la fusée : les zombies apparaissent hors de vue, à 40-60 cases, et sont attirés par `addSound` ;
- durée en secondes réelles de jeu non suspendu, option `ExtractionHoldMinutes` = 10 ;
- échec : aucun joueur dans le rayon pendant N s, mort, ou zone trop chaude (plus de K zombies à moins de 3 cases pendant T s). Un échec coûte de la confiance.

**Fichiers :**
- serveur : `MilitaryDrop_Extraction.lua` (règles et état), `MilitaryDrop_ExtractionMission.lua` (vagues) ;
- partagé : `MilitaryDrop_ExtractionRules.lua` (fonctions pures), `MilitaryDrop_Bridge.lua` (événements, détection d'Artemis) ;
- client : `MilitaryDrop_ExtractionUI.lua` (menu « Monter à bord », fondu au blanc, bilan) ;
- extension du vol : phase `land` dans `MilitaryDrop_Flight.lua`.

**Options sandbox :**
- `ExtractionEnabled`, `ExtractionTrustThreshold` (80) ;
- `ExtractionHoldMinutes`, `ExtractionWaveOutfits`, `ExtractionMaxZombies` ;
- `ExtractionInventory` : emporté, ou laissé dans une consigne à la zone d'atterrissage (« pas d'armes à bord »), qui profite alors au personnage suivant.

**Dépendance :** l'idée 5 est **obligatoire**. Sans confiance, la seule voie reste le `callCode` d'Artemis.

## 4. Risques et points à tester

- Mort mise en scène en MP (mode, sauvegarde, cadavre, objets lâchés) : le point le plus incertain.
- `OnPlayerDeath` touche les autres mods, qui croient à une mort. Artemis écrira sa chronique « mort » si le pont ne l'intercepte pas.
- En solo, `Artemis_NewCharacter` réinitialise l'histoire après l'extraction. Faut-il la garder à `DONE` ? À décider.
- En MP, Artemis est coopératif et l'extraction personnelle : un joueur extrait fait-il finir l'histoire pour tous ? À trancher.
- Plusieurs joueurs à bord ensemble ; reconnexion pendant la mission ; `getOnlinePlayers` vide.
- `DropOffWhiteListAfterDeath` ; zombies de vague qui passent en virtuel ; plafond de zombies.
- Coexistence avec l'épreuve de base d'Artemis, Siege Night et HEF.

## 5. Plan par étapes

| # | Livrable testable | Tests `lupa` | Effort |
|---|---|---|---|
| 0 | Contrat partagé : noms d'événements, fréquences réservées de part et d'autre, filtre des notes. Document commun aux deux projets | réservation de fréquences, `toChannel` avec la fréquence d'Artemis | S |
| 1 | Règles pures : éligibilité (confiance ou `callCode` d'Artemis), machine à états, minuteur, conditions d'échec | transitions interdites, seuil, échec et reprise, lecture seule de `batman_Artemis` | S |
| 2 | Vol avec phase `land` (descente, stationnaire long, départ) ; ombre élargie | `Flight.position` en phase `land`, `dropTime` inchangé pour un largage | S |
| 3 | Mission de zone : vagues hors de vue, compteur, échec, reprise au chargement | taille et arc des vagues, décompte réel plafonné, zone trop chaude, liste de joueurs vide | M |
| 4 | Embarquement et départ en solo : `Kill`, retrait du corps, mains vidées, consigne, bilan, puis nouveau personnage ou menu | calcul du bilan, choix du sort de l'inventaire | M |
| 5 | MP : commande `Extract`, mort côté client, nettoyage côté serveur, plusieurs joueurs, reconnexion | commande forgée (distance, mort, cadence) | M-L |
| 6 | Pont avec Artemis (dans les deux projets) : `callCode`, `batman_OnExtraction` qui passe Artemis à `DONE`, chronique dans le bilan | événement déclenché une seule fois, absence de l'autre mod | M |
| 7 | Facultatif : modèle 3D posé (Blender, véhicule sans roues) | — | L |

Chaque étape se termine par luacheck, un test en solo puis sur serveur dédié avec deux clients.

## Décisions et points ouverts (utilisateur, 2026-09-30)

- **Solo** : après une extraction, l'histoire d'Artemis **continue**. Elle n'est pas remise à zéro pour le personnage suivant, donc `Artemis_NewCharacter` ne doit pas la réinitialiser après une extraction.
- **Multijoueur** : le fonctionnement d'Artemis en MP n'est **pas encore tranché** (histoire commune ou par joueur). La question « un joueur extrait termine-t-il l'histoire pour tous ? » est **à discuter**. Tant qu'elle ne l'est pas, les étapes 5 et 6 du plan (MP et pont avec Artemis) restent en attente.
