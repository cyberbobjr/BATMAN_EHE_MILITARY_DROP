# Validation des correctifs poste et nettoyage

Date : 2026-10-26. Version 0.7.1 publiée, Build cible 42.21.

Publication demandée après présentation des limites de validation : commit `79acf75` poussé sur `main`, simulation puis envoi Workshop code 0, huit langues et 17 captures conservées. La publication ne constitue pas une validation en jeu.

## Résultats confirmés hors jeu

`python tests/run_tests.py --require-luacheck` : **code de sortie 0**, dernière ligne `Tout est bon.`. 920 cas Lua réussis et 7 contrôles Fulton avec serveur/deux clients Lua isolés ; luacheck, syntaxe, traductions et cohérence des données passent. Ces contrôles emploient une API simulée.

Cas spécifiques : actions du poste envoyées par les commandes existantes avec la radio fixe, verrou d'envoi et rafraîchissement à la réponse ; états personnels du rapport et du créneau ; contrôle déjà répondu, alimentation, distance et ligne coupée ; morts locales et suivies, bord inclus, autre étage, avant apparition et après échéance, événements répétés, contribution de deux personnages et récompense unique, morts sans tueur et migration après rechargements successifs.

`pz-autotest.py check MilitaryDrop` : **code de sortie 0**, dépendances et hooks reconnus pour sp/server/mp. `luacheck autotest/md_hooks.lua` avec la configuration du pilote : **code de sortie 0**, aucun avertissement ni erreur. Compilation Lua 5.1 des hooks : réussie.

Le journal local de la session ouverte indique `version=42.21.0`. Les références décompilées consultées sont en 42.21.0, dont les signatures `DeviceData.setIsBatteryPowered`, `setPower`, `setChannelRaw` utilisées par le scénario. Ce relevé n'est pas un passage de validation du correctif.

## Validation en jeu restant à réaliser

**Aucun passage du correctif n'a été lancé** : un processus du jeu utilisateur est ouvert. La règle d'un seul jeu à la fois interdit un lancement concurrent. Le scénario `corrections` est préparé mais son exécution n'est pas validée. Aucun dossier de résultat ni code de sortie de passage en jeu n'est donc annoncé.

Depuis le dossier de développement commun, après libération du jeu :

```powershell
python .claude/tools/pz-autotest/pz_autotest.py sp MilitaryDrop -P scenario=corrections -P shots=1 --wait-idle 3600
python .claude/tools/pz-autotest/pz_autotest.py mp MilitaryDrop --clients 2 --client-run -P scenario=corrections -P shots=1 --wait-idle 3600
```

Le scénario crée un poste fixe alimenté dans le cache de test, libère les mains du personnage, ouvre la console et utilise ses vraies actions de rapport et de contrôle. L'autorité vérifie leur acceptation et les bonus. Des zombies supplémentaires sont ensuite créés et réellement tués dans le cercle ; `OnZombieDead` doit avancer l'objectif commun, et une notification répétée ne doit pas le doubler. En MP, le serveur attribue ces morts à deux joueurs réellement connectés et vérifie le gagnant unique. Cela teste l'attribution serveur, sans prétendre reproduire les coups portés manuellement par le second client.

Après chaque passage, conserver le **code de sortie**, la **ligne `summary`**, le **dossier `runs/...`**, la version du journal et toute erreur. Un résultat favorable du scénario ne remplace pas les vérifications suivantes :

- Vrai redémarrage d'une copie de sauvegarde avec une mission ancienne partiellement remplie, puis nouvelle contribution et clôture ; le rechargement Lua hors jeu ne prouve pas cette persistance moteur.
- Poste : rapport le lendemain, contrôle expiré, refus sur mauvais canal, double demande depuis deux appareils, reconnaissance avec poste dedans/dehors, plaques, enregistreur, largage et passage Fulton.
- Nettoyage : zombies ambiants hors cercle et à un autre étage exclus, membre suivi poursuivi hors cercle inclus, feu, égalité, reconnexion et contributions via les deux clients.
- Rendu de la console, libellés longs, réponses radio, clavier et manette ; serveur dédié Linux cible si accessible.

La reconnaissance de la horde hors cercle conserve la limite connue des signatures de tenue non uniques. Le nouveau comptage géographique n'exige pas d'identifier individuellement les zombies ambiants.
