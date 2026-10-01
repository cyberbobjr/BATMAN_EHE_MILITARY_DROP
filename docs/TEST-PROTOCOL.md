# Protocole de test en jeu (phase 7)

Chaque étape donne l'action, puis le résultat attendu. Noter tout écart et garder `C:\Users\cyber\Zomboid\console.txt` (surveillé en direct par `.claude/tools/pzwatch.py` avec `PZWATCH_MOD_RE='MilitaryDrop'`).

## Préparation (solo)

1. Lancer le jeu en mode debug (`-debug` dans les options de lancement Steam).
2. Mods : activer **Military Drop** (id `batman_MilitaryDrop`) seul (HEF désactivé pour ce premier passage).
3. Nouvelle partie « bac à sable ». Page **Military Drop** des options :
   - vérifier les 34 options et leurs libellés en français ;
   - **Heures entre deux largages** : 1 ; **Fréquence des notes militaires** : Débogage (1/2) ; **Fréquence des carnets de codes** : Débogage (1/2) ; **Journal de débogage** : activé ; le reste par défaut (**Fréquence radio** : 0 = tirée au hasard, **Code d'authentification** : code de la semaine chiffré).
4. En jeu, se placer **dehors**, dans un endroit dégagé.

Commandes utiles (console Lua du mode debug, touche F11 puis onglet Lua, ou `~`) :

```lua
-- Matériel
getPlayer():getInventory():AddItem("Base.WalkieTalkie5")
getPlayer():getInventory():AddItem("Base.Battery")
getPlayer():getInventory():AddItem("MilitaryDrop.MilitaryMemo")
-- Code en vigueur (solo seulement : le code du serveur est dans le même Lua)
print(MilitaryDrop.Server.getCode())
-- Fréquence militaire de la partie (MHz, tirée au hasard ; solo seulement)
print(MilitaryDrop.Config.formatChannel(MilitaryDrop.Config.getChannel()))
-- Fréquence de la station de chiffres (kHz) et carnet de codes
print(MilitaryDrop.NumbersStation.frequency)
getPlayer():getInventory():AddItem("MilitaryDrop.Codebook")
-- Caisses de ravitaillement
getPlayer():getInventory():AddItem("MilitaryDrop.AmmoSupplyCase")
```

## A. Objets et recette (phase 1)

| # | Action | Attendu |
|---|---|---|
| A1 | Ajouter les 4 caisses `MilitaryDrop.*SupplyCase`, puis les poser au sol | Noms « Caisse de ravitaillement militaire (…) », icônes d'étuis militaires, infobulle ; au sol, étuis verts texturés (pas de damier) |
| A2 | Clic droit sur chaque caisse, dans l'inventaire | « Ouvrir la caisse de ravitaillement » ; munitions ×5, 1 arme **avec 2 chargeurs (si elle en prend) et 1 boîte de munitions**, équipement ×5, accessoires ×5 |
| A5 | Ajouter une note par la console (`AddItem("MilitaryDrop.MilitaryMemo")`), clic droit | Icône de rapport (pas de « ? ») ; « Inspecter » s'ouvre en une seconde environ ; fenêtre de journal : note de service dactylographiée, en-tête, n° de série, 151.4 MHz entourée au stylo, annotation manuscrite avec la fréquence de la station, tampon SECRET ; bouton du bas : transcription en texte simple |
| A3 | Poser une caisse au sol et l'ouvrir par clic droit | Même résultat, sans erreur |

## B. Appel radio (phase 2)

| # | Action | Attendu |
|---|---|---|
| B1 | Talkie militaire **éteint**, en main : clic droit | « Demander un largage » grisé, infobulle « La radio doit être allumée. » |
| B2 | Talkie allumé dans l'inventaire (ni en main ni sur le dos) | Option grisée, « Il faut tenir la radio en main ou la porter sur le dos. » |
| B3 | Talkie allumé en main, réglé sur **150,0 MHz**, appel avec le code juste | Le personnage parle, puis après ~5 s : « …grésillements. Personne ne répond… » |
| B4 | Régler la **fréquence militaire** (celle de la note), appel avec un **code faux** | Même réponse qu'en B3 (grésillements) : on ne peut pas distinguer fréquence et code |
| B5 | Même chose avec le **code juste** (`print(MilitaryDrop.Server.getCode())`, en minuscules, avec espaces) | Réponse d'accord de la base après ~5 s |
| B6 | Rappeler aussitôt avec le code juste | « Je ne peux pas les joindre… dans 1 heures » |
| B7 | Tuer quelques zombies policiers ou militaires | Une « Note de service militaire » sur certains cadavres ; clic droit : **Inspecter** ; même document qu'en A5 |

## C. Hélicoptère (phase 3) — après B5

| # | Action | Attendu |
|---|---|---|
| C1 | Écouter et regarder | Son d'hélicoptère qui passe au loin ; flèche de direction à moins de 400 cases de l'hélicoptère. Le point de largage est **entre 150 et 400 cases** du joueur (options « Distance minimale/maximale du largage ») |
| C2 | Au passage | Ombre qui passe au sol, vol stationnaire ~8 s au-dessus du point |
| C3 | Départ | L'hélicoptère repart, le son décroît puis s'arrête ; plus d'ombre ni de flèche |
| C4 | Pause (Échap) pendant un vol | L'hélicoptère s'arrête aussi |

## D. Annonces et carte (phase 4)

| # | Action | Attendu |
|---|---|---|
| D1 | Garder le talkie allumé sur la fréquence militaire | « À toutes les stations, ici Logistique… » au départ, puis les coordonnées répétées au largage, puis « terminé » |
| D2 | Ouvrir la carte | Symbole « cible » vert au point de largage, un seul |
| D3 | Panneau de la radio réglée sur la fréquence militaire | Chaîne affichée comme inconnue (pas « Military Logistics ») |
| D4 | Nouvel appel (attendre 1 h de jeu), radio **éteinte** au moment du largage | Pas de nouveau symbole |

## E. Caisse (phase 5)

| # | Action | Attendu |
|---|---|---|
| E1 | Aller au point de largage (repère de carte) | En arrivant, la caisse 3D (palette, caisse olive, sangles, « U.S. ARMY ») apparaît au point annoncé ou à moins de 30 cases, posée au sol, ni enfoncée ni flottante |
| E2 | Horde | Zombies autour de la caisse (3 à 30 par défaut) |
| E3 | Ouvrir le coffre (clic droit / menu véhicule) | Coffre « Caisse de largage militaire » avec 6 caisses de ravitaillement |
| E4 | Largage admin (« Forcer un largage ») sur une radio éteinte, rangée dans l'inventaire | Accepté ; coordonnées en message privé ; délai non modifié |
| E5 | Avec le mod **Signal Smoke** actif : aller au point de largage | Fumée verte sur la caisse, visible en approchant, pendant 60 minutes de jeu ; sans Signal Smoke, aucune fumée et aucune erreur |

## F. Sauvegarde

| # | Action | Attendu |
|---|---|---|
| F1 | Sauvegarder et quitter **pendant un vol**, recharger | L'hélicoptère reprend son vol (son, ombre) et largue normalement |
| F2 | Recharger une partie avec une caisse déjà posée | Caisse toujours là, contenu conservé |

## G. Code de la semaine chiffré (v1.2)

Options par défaut (code de la semaine chiffré), notes et carnets en Débogage (1/2). Le parcours nominal d'abord (G1-G5), les cas limites ensuite.

| # | Action | Attendu |
|---|---|---|
| G1 | Lire une note (cadavre militaire ou console) | Fréquence militaire, égale à `print(MilitaryDrop.Config.formatChannel(MilitaryDrop.Config.getChannel()))`, et fréquence de la station, entre 10 et 25 MHz, égale à `print(MilitaryDrop.NumbersStation.frequency)` / 1000 ; aucun code |
| G2 | Talkie militaire (ou radio HAM) allumé en main, réglé sur la fréquence de la station ; attendre au plus 30 min de jeu | « Attention. Attention. Message. », trois fois « Groupe : NN-NN-NN », puis « Fin du message » ; panneau de la radio : chaîne inconnue |
| G3 | Tuer un zombie militaire (ou `AddItem("MilitaryDrop.Codebook")`) et **Inspecter** le carnet | Icône de liasse de papiers ; ouverture en une seconde environ ; dossier kraft ouvert : étiquette « Carnet de codes », tampon SECRET, trombone ; feuille avec la grille « groupe / mot » (2 × 13 lignes), sans texte coupé ; zoom à la molette ; deux carnets ont la même table |
| G4 | Déchiffrer le groupe entendu en G2 avec la grille du carnet, puis appeler la fréquence militaire avec ce code | Le code obtenu est celui de `print(MilitaryDrop.Server.getCode())` ; la base accepte |
| G5 | Sauvegarder, quitter, recharger ; relire la note et le carnet | Textes identiques ; la station diffuse le même groupe |
| G6 | Cas limite : 3 appels avec un code faux sur la fréquence militaire, puis un appel avec le bon code | Grésillements les 4 fois ; console : `3 wrong codes today` ; le lendemain (après minuit), le bon code est accepté |
| G7 | Cas limite : avancer au lundi 00:00 (console debug, heure), puis `print(MilitaryDrop.Server.getCode())` | Nouveau code ; l'ancien reste accepté jusqu'au lundi 24:00, puis refusé |
| G8 | Cas limite : nouvelles parties avec **Code d'authentification** sur Aucun, Code fixe, Code de la semaine en clair | Aucun : pas de saisie, notes sans code ; fixe : code sur les notes ; semaine en clair : code et date de fin (dimanche) sur les notes ; aucune station ni carnet dans ces trois modes |
| G9 | Cas limite : fouiller des casiers et réserves d'une base militaire | Des carnets de codes (Débogage : assez fréquents) |

## H. Confiance, sources, missions, poste (v1.3)

Solo d'abord (une seule équipe, « SOLO »), puis serveur dédié à 2 clients dans deux factions. Console debug utile :

```lua
MilitaryDrop.Trust.debugPrint()          -- notes des équipes (admin)
MilitaryDrop.Missions.launch("recon")    -- lancer une mission : "recon", "cleanup", "control"
-- Plaque de soldat tombé (solo : renommée comme à la mort d'un zombie)
local t = getPlayer():getInventory():AddItem("Base.Necklace_DogTag"); t:setName(t:getScriptItem():getDisplayName() .. ": John Doe")
-- Démontage : outils
getPlayer():getInventory():AddItem("Base.Hammer"); getPlayer():getInventory():AddItem("Base.Saw")
```

| # | Action | Attendu |
|---|---|---|
| H1 | Talkie militaire accroché à la ceinture, réglé sur la fréquence militaire et allumé : clic droit → **Logistique** → « Envoyer un rapport de situation » | Le personnage prend le talkie en main, parle, puis la base répond avec l'indicatif ; un second rapport le même jour : la base le refuse poliment |
| H2 | Tuer des zombies militaires | Une seule plaque par soldat, la plaque vanilla à son nom (plus de plaque du mod) ; « Transmettre les matricules » : plaques consommées, remerciement de la base ; une plaque déjà transmise ne rapporte rien |
| H3 | `Missions.launch("control")` puis « Confirmer réception » | Annonce « toutes stations » sur la fréquence militaire ; réponse acceptée une fois |
| H4 | `Missions.launch("recon")` en écoutant la fréquence militaire, ouvrir la carte, aller à la grille annoncée, « Confirmer la reconnaissance » | Symbole « œil » bleu au point annoncé, posé une seule fois ; refusée loin du point, acceptée à 25 cases ; annonce de clôture |
| H5 | `Missions.launch("cleanup")`, tuer des zombies dans la zone annoncée | La progression avance (console du poste) ; au quota, annonce de clôture ; les zombies brûlés ne comptent pas |
| H6 | Radio HAM militaire posée (non portable) : clic droit → « Installer le poste de liaison », puis « Poste de liaison » | Console : journal (annonces reçues), missions en cours avec échéance, plaques à annoncer, barre d'état avec l'indicatif et un palier de confiance en mots |
| H7 | « Déposer mes plaques », puis « Annoncer les matricules » | Plaques retirées de l'inventaire et listées au poste ; le personnage annonce les matricules, la base cite les noms et remercie |
| H8 | Éteindre le poste, faire diffuser une annonce (largage ou mission), rallumer | Le journal marque « aucune réception » pour le trou |
| H9 | Largage : ouvrir une caisse | Réplique de la base plus chaleureuse au largage suivant (palier) ; `Trust.debugPrint()` montre +10 |
| H10 | Talkie dans le sac à dos, puis « Envoyer un rapport de situation » | Le personnage le prend en main (en solo, une radio sur le dos est aussi acceptée) |
| H11 | Pendant l'annonce, cliquer de nouveau « Annoncer les matricules » | Le second clic est ignoré : chaque matricule n'est compté qu'une fois (`Trust.debugPrint()`) |
| H13 | Talkie militaire à la ceinture : clic droit → « Options de l'appareil », l'allumer sur la fréquence militaire, laisser la fenêtre ouverte ; puis lancer un largage ; enfin la régler sur la station de chiffres et attendre la demi-heure | La radio reste allumée ; le code chiffré de la station s'affiche à la demi-heure ; les lignes de la base s'affichent au-dessus du personnage (une seule fois si un autre talkie est en main) et le repère du largage apparaît |
| H14 | Caisse larguée vidée, marteau et scie dans l'inventaire : clic droit → « Démonter la caisse » ; essayer aussi caisse pleine et sans scie | Grisée avec la raison si pleine ou sans outil ; sinon animation, planches (ou bois inutilisable) au sol, XP de Menuiserie, caisse disparue |
| H12 | Nouvelle partie avec **Fréquence radio** à 0 : lire une note | Fréquence militaire entre 120 et 170 MHz, différente d'une partie à l'autre, et la même après un rechargement de la partie |

## Plus tard : multijoueur (hébergé, puis serveur dédié `C:\pzserver`)

- Deux joueurs : l'un appelle, l'autre écoute la fréquence (annonce et symbole) sans avoir appelé.
- Déconnexion et reconnexion pendant un vol : l'hélicoptère réapparaît à sa position.
- Joueur non admin : pas d'option « Forcer un largage » ; commande forgée refusée (journal serveur).
- v1.3 : un client ne connaît pas la fréquence militaire tirée au hasard (seules les notes la donnent) ; deux factions ; indicatif conservé après un renommage ; appel de contrôle crédité aux deux ; reconnaissance et nettoyage à la première ; un joueur de l'autre faction ne peut ni installer ni ouvrir le poste ; talkie à la ceinture : prise en main puis échange accepté par le serveur.
- Code de la semaine : les deux clients entendent la station et lisent le même carnet ; la graine et le code restent absents de la ModData (`ModData.request("MilitaryDrop")` côté client) ; 3 codes faux d'un joueur ne font pas taire la base pour l'autre.
- Avec HEF actif : départ retardé si un événement HEF est proche.
