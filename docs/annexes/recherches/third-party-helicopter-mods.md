# Mods d'hélicoptère tiers : HEF et EHE

Notes propres au projet Military Drop, sorties le 2026-09-30 de la base `.claude/pz-knowledge` (qui ne garde que le moteur). L'hélicoptère vanilla est décrit dans `.claude/pz-knowledge/staging-effects.md`. Revérifier ces constats à chaque mise à jour des mods concernés.

## Helicopter Event Expansion Framework (Workshop 3672792485, id `HelicopterEventExpansionFramework`)
- Build 42.21 (variante chargée `42.13.0`, à tester) — Date 2026-09-29 — Statut : confirmé statiquement
- 17 événements secondaires pilotés par le serveur (préfixe `HTT`). Ils sont lancés par le passage de l'hélicoptère vanilla (chance `VanillaHookTriggerChance`) et par un planificateur propre (délai de 72 h par défaut, heure fixe quotidienne ou arrêt définitif progressif en option). État persistant dans la ModData globale `HTT_ServerAutoSchedulerState`.
- **Piège 1 — tirage pondéré incomplet :** `HTT.pickWeightedVanillaEventId` (`HTT_Core.lua:1180-1235`) oublie `air_bombardment` et `downed_heli`. Le crochet vanilla ne les tire donc jamais, et le planificateur seulement en repli, quand le tirage retombe sur l'événement précédent (`HTT_ServerEventManager.lua:1359-1385`).
- **Piège 2 — préréglage toxique :** l'option sandbox `ToxicDamagePreset` existe toujours, donc le préréglage écrase `ToxicEventDurationHours` et les dégâts toxiques par minute (`HTT_Core.lua:1403-1411`). Le journal montre `toxicEventDuration=0.25h` alors que l'option vaut 1,50 h. Seul `ToxicTickSeconds` est conservé, et seulement s'il diffère de 60.
- **Piège 3 — attraction des zombies :** `EventZombieAttractionRadiusPercent` vaut 500 % par défaut. Chaque son de rotor ou de tir déclenche un `addSound` réel dont le rayon est multiplié par 5 (`HTT_ServerEventManager.lua:975-983`), y compris pour l'hélicoptère allié.
- **Effets réels sur le monde :**
  - `incendiary_sweep` allume de vrais feux (`IsoFireManager.StartFire`, `HTT_ServerIncendiarySweep.lua:671`). Seules les cases allumées par le mod sont éteintes à la fin ; les feux propagés restent.
  - `military_vehicle_strike_event` fait exploser le véhicule militaire le plus proche (`HTT_ServerMilitaryVehicleStrike.lua:374-381`) sans vérifier s'il est occupé.
  - `fuel_reclamation_event` vide 10 % des pompes à essence chargées, de façon permanente.
  - `downed_heli` ne crée ni épave ni butin : c'est un leurre sonore seulement.
- **Canal radio du drone :** `uav_scan_event` crée un `DynamicRadioChannel` « Unseasonal Weather Network » sur 112200 (112,2 MHz, `HTT_ServerUAVScan.lua:15,106`), hors de la bande FM grand public. Il faut un talkie-walkie ou une radio amateur, allumé(e) dans l'inventaire du joueur suivi.
- **Commandes de debug :** fonctions globales `HTT.DebugStartEvent(id, heures, rayon, force)`, `HTT.DebugStopEvent()`, `HTT.DebugListEvents()`, `HTT.DebugStatus()`, `HTT.DebugHelp()` (`client/HTT_DebugCommands.lua:961-1110`), à appeler depuis la console Lua de debug.

## Expanded Helicopter Events (EHE) : disponibilité B42 et API
- Build 42.21 — Date 2026-09-30 — Statut : confirmé statiquement (API Steam `GetPublishedFileDetails`, dépôt GitHub `TEHE-Studios/ExpandedHelicopterEvents`, branche `main`)
- **Workshop 2458631365** (`id=ExpandedHelicopterEvents`) : renommé « [B41] Expanded Helicopter Events », tag `Build 41` seul, dernière mise à jour le 2025-10-13. Son `mod.info` local (`versionMin=41.66`, `require=EasyConfigChucked`) n'a aucune variante B42.
- **Version B42** : seulement sur GitHub, branche `main` (dernier commit le 2026-09-30). Dossier `Contents/mods/Expanded Helicopter Events/42.15` + `common`, `versionMin=42.20.3`, `require=\TargetSquareOnLoad` (Workshop 2969455858, variante `42.00` présente). Le contrôle anti-republication de `EHE_heliCore.lua` (après la fonction de ciblage) attend l'ID Workshop **3171846102** (« BE », codé `gekelhjedf` : chiffre + 100), que l'API Steam renvoie en `result=9` (privé ou absent) le 2026-09-30. Il n'y a donc **aucune version B42 officielle publique**.
- **3628707117** « helicoptero_B42 » (201 abonnés, 42.13) est une republication non autorisée (licence TEHE), à ne pas utiliser comme prérequis.
- **Licence TEHE** depuis le 2025-08-20 (auparavant AGPL-3.0) : un addon doit exiger le mod d'origine non modifié, ne pas redistribuer ses fichiers ou ressources, créditer et lier la page officielle, et ne pas fonctionner sans lui.
- **API B42 (réécrite)** : fichiers `EHE_*.lua` en modules (`require("EHE_heliCore.lua")`, etc.). Il n'existe plus de fichiers `ExpandedHelicopter01c_MainCore`, de global `eHelicopter_PRESETS`, de `SpawnerTEMP`, de `getOutsideSquareFromAbove_vehicle` ni de global `eventMarkerHandler`.
  - Préréglages : `require("EHE_presetCore.lua").registerPreset(id, table)`, avec `inherit`, `presetProgression` et `presetRandomSelection`. `samaritan_drop` n'existe plus ; les largages sont `military_UH1H_patrol_emergency` (`FEMASupplyDrop`) et `survivors` (`SurvivorSupplyDrop`).
  - Lancement serveur : `eHelicopter.getFreeHelicopter(presetID)` puis `heli:launch(cible)`, qui fixe `forceUnlaunchTime = {util.getWorldAgeDays(), heure+2}` (jours d'âge du monde, pas `getNightsSurvived`).
  - Crochets `addedFunctionsToEvents` : `OnLaunch`, `OnArrive`, `OnApproach`, `OnHover`, `OnFlyaway`, `OnSpawnCrew`, `OnCrash`, `OnDrop`. `OnDrop` reçoit le véhicule-caisse via `EHE_spawner`, dont le dictionnaire (`presetID..eventID`) est construit **au premier appel** : le préréglage doit être enregistré avant.
  - `dropCarePackage` passe par la commande `SpawnerAPI/spawn` puis `TargetSquareOnLoad` si la case n'est pas chargée.
  - Objets déplacés dans `module EHE` (`EHE.SurvivorSupplyBox`, `EHE.EmergencySupplyBox`, icônes `EHE/supplyBox/*`). L'ouverture passe par la `craftRecipe OpenSupplies` (tag `EHESupplyBox`).
  - Commande de debug `sendClientCommand(p, "CustomDebugPanel", "launchHeliTest", {presetID=…})`.
- Conséquence : un addon B41 d'EHE doit être réécrit contre cette API. Tant que 3171846102 n'est pas public, il ne peut pas déclarer de prérequis Workshop B42 officiel.

## HEF : lire son état depuis un autre mod (serveur)
- Build 42.21 (HEF 1.2, variante `42.13.0`) — Date 2026-09-30 — Statut : confirmé statiquement (`server/HTT_ServerEventManager.lua:794-836`)
- État courant côté serveur : `HTT.Server.state`, avec `active`, `eventId`, `centerX`, `centerY`, `centerZ`, `radius`, `startHour`, `endHour`, `flightPhase`, etc. Un autre mod peut le lire sans dépendre de HEF : `local s = HTT and HTT.Server and HTT.Server.state`. Military Drop s'en sert pour retarder son hélicoptère quand un événement HEF est actif près de sa cible.
- Globale de HEF : `HTT`. Commandes réseau : module `HTT`. ModData : `HTT_ServerAutoSchedulerState`.
