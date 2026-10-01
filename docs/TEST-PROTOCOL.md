# Protocole de test en jeu (phase 7)

Chaque étape donne l'action, puis le résultat attendu. Noter tout écart et garder `C:\Users\cyber\Zomboid\console.txt` (surveillé en direct par `.claude/tools/pzwatch.py` avec `PZWATCH_MOD_RE='MilitaryDrop'`).

## Préparation (solo)

1. Lancer le jeu en mode debug (`-debug` dans les options de lancement Steam).
2. Mods : activer **Military Drop** (id `batman_MilitaryDrop`) seul (HEF désactivé pour ce premier passage).
3. Nouvelle partie « bac à sable ». Page **Military Drop** des options :
   - vérifier les 44 options et leurs libellés en français ;
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

Depuis le 2026-10-01 (RADIO-06), tout passe par la section « Logistique » de la fenêtre radio (clic droit → « Options de l'appareil ») : le menu contextuel « Logistique » et « Demander un largage » n'existent plus (seul le largage forcé de l'admin reste au clic droit).

| # | Action | Attendu |
|---|---|---|
| B1 | Talkie militaire **éteint**, en main : « Options de l'appareil », section « Logistique » | « Demander un largage » grisé, infobulle « La radio doit être allumée. » ; au clic droit, plus d'option « Demander un largage » ni de menu « Logistique » |
| B2 | Talkie militaire dans un sac porté : clic droit → « Options de l'appareil » | Le personnage le prend en main et sa fenêtre s'ouvre aussitôt, allumée, avec la section « Logistique » |
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
| H1 | Talkie militaire accroché à la ceinture, réglé sur la fréquence militaire et allumé : « Options de l'appareil » → section **Logistique** → « Envoyer un rapport de situation » | Le personnage prend le talkie en main, parle, puis la base répond avec l'indicatif ; un second rapport le même jour : la base le refuse poliment |
| H2 | Tuer des zombies militaires | Une seule plaque par soldat, la plaque vanilla à son nom (plus de plaque du mod) ; « Annoncer les matricules » : plaques consommées, la base cite les noms et remercie ; une plaque déjà annoncée ne rapporte rien |
| H3 | `Missions.launch("control")` puis « Confirmer réception » | Annonce « toutes stations » sur la fréquence militaire ; réponse acceptée une fois |
| H4 | `Missions.launch("recon")` (plusieurs fois, dont près d'un lac ; journal « mission site … (building) ») en écoutant la fréquence militaire, ouvrir la carte, aller à la grille annoncée, « Confirmer la reconnaissance » | Symbole « œil » bleu au point annoncé, posé une seule fois ; refusée loin du point, acceptée à 25 cases ; annonce de clôture |
| H5 | `Missions.launch("cleanup")` en écoutant la fréquence militaire, tuer des zombies dans la zone annoncée | Crâne rouge sur la carte au centre de la zone (un hameau), une seule fois ; la progression avance (console du poste) ; au quota, annonce de clôture ; les zombies brûlés ne comptent pas |
| H6 | Radio HAM militaire posée (non portable) : clic droit → « Installer le poste de liaison », puis « Poste de liaison » | Console : journal (annonces reçues), missions en cours avec échéance, plaques à annoncer, barre d'état avec l'indicatif et un palier de confiance en mots |
| H7 | « Déposer mes plaques », puis « Annoncer les matricules » | Plaques retirées de l'inventaire et listées au poste ; le personnage annonce les matricules, la base cite les noms et remercie |
| H8 | Éteindre le poste, faire diffuser une annonce (largage ou mission), rallumer | Le journal marque « aucune réception » pour le trou |
| H9 | Largage : ouvrir une caisse | Réplique de la base plus chaleureuse au largage suivant (palier) ; `Trust.debugPrint()` montre +10 |
| H10 | Talkie dans le sac à dos, puis « Envoyer un rapport de situation » | Le personnage le prend en main (en solo, une radio sur le dos est aussi acceptée) |
| H11 | Pendant l'annonce, cliquer de nouveau « Annoncer les matricules » | Le second clic est ignoré : chaque matricule n'est compté qu'une fois (`Trust.debugPrint()`) |
| H13 | Talkie militaire à la ceinture : clic droit → « Options de l'appareil », l'allumer sur la fréquence militaire, laisser la fenêtre ouverte ; puis lancer un largage ; enfin la régler sur la station de chiffres et attendre la demi-heure | La radio reste allumée ; le code chiffré de la station s'affiche à la demi-heure ; les lignes de la base s'affichent au-dessus du personnage (une seule fois si un autre talkie est en main) et le repère du largage apparaît |
| H14 | Caisse larguée vidée, marteau et scie dans l'inventaire : clic droit → « Démonter la caisse » ; essayer aussi caisse pleine et sans scie | Grisée avec la raison si pleine ou sans outil ; sinon animation, planches (ou bois inutilisable) au sol, XP de Menuiserie, caisse disparue |
| H15 | Admin (solo debug) : clic droit sur une radio militaire → « Missions (admin) » → « Lancer un nettoyage », radio allumée sur la fréquence militaire ; puis relancer le même | Le personnage confirme le lancement ; la base annonce le nettoyage à toutes les stations et le crâne rouge apparaît ; le second lancement répond qu'une mission de ce type est déjà en cours |
| H12 | Nouvelle partie avec **Fréquence radio** à 0 : lire une note | Fréquence militaire entre 120 et 170 MHz, différente d'une partie à l'autre, et la même après un rechargement de la partie |

## I. Formulaire de réquisition (v1.4)

Options par défaut (formulaire actif). Confiance réglable pour les essais : `MilitaryDrop.Trust.add("SOLO", 30, "drop")` (console Lua, solo).

| # | Action | Attendu |
|---|---|---|
| I1 | Appel de largage avec le bon code (talkie ou radio posée) | La base répond « transmettez votre réquisition », puis la feuille s'ouvre avec le budget, le délai qui décroît et les lots par palier |
| I2 | Remplir avec + et − jusqu'à épuiser le budget | « + » grisé quand le budget ne suffit plus ; paliers II et III grisés selon la confiance, avec la raison ; « points non utilisés perdus » |
| I3 | « Transmettre la réquisition » | Le personnage annonce sa réquisition, la base accepte, puis l'hélicoptère et l'annonce habituelle (sans le contenu) |
| I4 | Annuler, Échap, ou s'éloigner d'une radio posée ; puis rappeler | Rien n'est consommé, le délai entre largages n'est pas déclenché |
| I5 | Ouvrir les caisses de réquisition du coffre (2 Rations, 1 Eau potable, 1 Carburant si permis) | Une caisse nommée par lot commandé ; contenu du lot ; bouteille pleine d'eau propre, bidon plein d'essence |
| I6 | Option « Formulaire de réquisition » désactivée, nouvel appel | Largage direct avec les caisses aléatoires de la v1 |
| I7 | Console du poste : « Demander un largage » | Saisie du code, puis la feuille |
| I9 | Clic droit sur une radio militaire → « Largage forcé (admin) » | Feuille tamponnée ADMIN : tous les lots et le leurre, 20 points ; elle reste ouverte loin de la radio ; après commande, coordonnées en privé et un appel normal juste après n'est pas bloqué par le délai |
| I10 | Nouvelle partie, premier appel | Seul le palier I est permis ; le palier II affiche « confiance 60+ » |
| I8 | Console au démarrage : chercher `requisition lots ready in` ; puis leurre vers un secteur hors de la carte (bord de carte) | Durée de préparation des lots notée au journal ; pour le leurre, la base dit qu'aucun point n'existe dans ce secteur et la feuille se rouvre |

## J. Largage leurre (v1.5)

| # | Action | Attendu |
|---|---|---|
| J1 | Formulaire : « Leurre à sirène », secteur Nord, transmettre | Les autres lots se désactivent ; même réponse, même hélicoptère, même annonce qu'un vrai largage ; point annoncé au nord |
| J2 | Aller à la caisse | Sirène audible en approchant, zombies attirés ; le coffre ne contient qu'une balise « DIVERSION » |
| J3 | Clic droit sur la caisse → « Couper la sirène » | Action de quelques secondes, puis silence |
| J4 | Nouveau leurre : attendre l'échéance (6 h de jeu), ou démonter la caisse | La sirène s'arrête ; la confiance ne change pas (`Trust.debugPrint()`) |

## K. Module radio et fichier de lots (RADIO-06, REQ-09)

| # | Action | Attendu |
|---|---|---|
| K1 | Ouvrir les options d'un talkie militaire, puis d'une radio civile | Section « Logistique » sur la radio militaire seulement ; les autres sections du jeu inchangées |
| K2 | Code vide, puis taper le code et « Demander un largage » | Bouton grisé avec sa raison tant que le code manque ; puis la feuille s'ouvre collée à droite de la fenêtre radio (à gauche si la fenêtre est au bord droit de l'écran) |
| K3 | Rapport, matricules, contrôle depuis la section | Mêmes échanges qu'au menu ; la dernière réponse de la base s'affiche dans la section |
| K4 | Refermer et rouvrir la fenêtre radio, nouvel appel | Code prérempli (mémorisé pendant la session, pas sauvegardé) |
| K5 | Manette : entrer dans la section, saisir le code au clavier à l'écran | Navigation haut et bas, A valide, B ressort |
| K6 | Premier démarrage : dossier `Zomboid/Lua/MilitaryDrop/` | `requisition.txt` créé, notice en anglais ; journal « requisition lots: 18 » |
| K7 | Mettre `enabled = false` sur un lot, ajouter le lot d'exemple de la notice, recharger (`MilitaryDrop.Requisition.reload()` en solo) | Le lot disparaît du formulaire ; le lot ajouté apparaît avec ses textes ; ses caisses portent son nom |
| K8 | Introduire une erreur de syntaxe, recharger | Journal avec le numéro de ligne ; les 18 lots par défaut restent |

## Plus tard : multijoueur (hébergé, puis serveur dédié `C:\pzserver`)

- Deux joueurs : l'un appelle, l'autre écoute la fréquence (annonce et symbole) sans avoir appelé.
- Déconnexion et reconnexion pendant un vol : l'hélicoptère réapparaît à sa position.
- Joueur non admin : pas d'option « Forcer un largage » ; commande forgée refusée (journal serveur).
- v1.4 : commande forgée refusée ; un autre joueur qui appelle pendant qu'une feuille est ouverte consomme le délai, la commande est alors refusée (« délai »). v1.5 : l'autre joueur n'entend la sirène qu'à portée, et ne distingue pas le leurre avant d'ouvrir le coffre ; reconnexion près d'une sirène.
- v1.3 : un client ne connaît pas la fréquence militaire tirée au hasard (seules les notes la donnent) ; deux factions ; indicatif conservé après un renommage ; appel de contrôle crédité aux deux ; reconnaissance et nettoyage à la première ; un joueur de l'autre faction ne peut ni installer ni ouvrir le poste ; talkie à la ceinture : prise en main puis échange accepté par le serveur.
- Code de la semaine : les deux clients entendent la station et lisent le même carnet ; la graine et le code restent absents de la ModData (`ModData.request("MilitaryDrop")` côté client) ; 3 codes faux d'un joueur ne font pas taire la base pour l'autre.
- Avec HEF actif : départ retardé si un événement HEF est proche.
