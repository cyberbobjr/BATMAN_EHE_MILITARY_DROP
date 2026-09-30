# Protocole de test en jeu (phase 7)

Chaque étape donne l'action, puis le résultat attendu. Noter tout écart et garder `C:\Users\cyber\Zomboid\console.txt` (surveillé en direct par `.claude/tools/pzwatch.py` avec `PZWATCH_MOD_RE='MilitaryDrop'`).

## Préparation (solo)

1. Lancer le jeu en mode debug (`-debug` dans les options de lancement Steam).
2. Mods : activer **Military Drop** (id `batman_MilitaryDrop`) seul (HEF désactivé pour ce premier passage).
3. Nouvelle partie « bac à sable ». Page **Military Drop** des options :
   - vérifier les 13 options et leurs libellés en français ;
   - **Heures entre deux largages** : 1 ; **Fréquence des notes militaires** : Débogage (1/2) ; **Journal de débogage** : activé ; le reste par défaut (151,4 MHz, code exigé).
4. En jeu, se placer **dehors**, dans un endroit dégagé.

Commandes utiles (console Lua du mode debug, touche F11 puis onglet Lua, ou `~`) :

```lua
-- Matériel
getPlayer():getInventory():AddItem("Base.WalkieTalkie5")
getPlayer():getInventory():AddItem("Base.Battery")
getPlayer():getInventory():AddItem("MilitaryDrop.MilitaryMemo")
-- Code de la partie (solo seulement : le code du serveur est dans le même Lua)
print(MilitaryDrop.Server.getCode())
-- Caisses de ravitaillement
getPlayer():getInventory():AddItem("MilitaryDrop.AmmoSupplyCase")
```

## A. Objets et recette (phase 1)

| # | Action | Attendu |
|---|---|---|
| A1 | Ajouter les 4 caisses `MilitaryDrop.*SupplyCase`, puis les poser au sol | Noms « Caisse de ravitaillement militaire (…) », icônes d'étuis militaires, infobulle ; au sol, étuis verts texturés (pas de damier) |
| A2 | Clic droit sur chaque caisse, dans l'inventaire | « Ouvrir la caisse de ravitaillement » ; munitions ×5, 1 arme **avec 2 chargeurs (si elle en prend) et 1 boîte de munitions**, équipement ×5, accessoires ×5 |
| A5 | Ajouter une note par la console (`AddItem("MilitaryDrop.MilitaryMemo")`) | « Lire » disponible ; texte avec 151.4 et le code |
| A3 | Poser une caisse au sol et l'ouvrir par clic droit | Même résultat, sans erreur |

## B. Appel radio (phase 2)

| # | Action | Attendu |
|---|---|---|
| B1 | Talkie militaire **éteint**, en main : clic droit | « Demander un largage » grisé, infobulle « La radio doit être allumée. » |
| B2 | Talkie allumé dans l'inventaire (ni en main ni sur le dos) | Option grisée, « Il faut tenir la radio en main ou la porter sur le dos. » |
| B3 | Talkie allumé en main, réglé sur **150,0 MHz**, appel avec le code juste | Le personnage parle, puis après ~5 s : « …grésillements. Personne ne répond… » |
| B4 | Régler **151,4 MHz**, appel avec un **code faux** | Même réponse qu'en B3 (grésillements) : on ne peut pas distinguer fréquence et code |
| B5 | Même chose avec le **code juste** (en minuscules, avec espaces) | Réponse d'accord de la base après ~5 s |
| B6 | Rappeler aussitôt avec le code juste | « Je ne peux pas les joindre… dans 1 heures » |
| B7 | Tuer quelques zombies policiers ou militaires | Une « Note de service militaire » sur certains cadavres ; clic droit : **Lire** seulement ; texte avec 151.4 et le code |

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
| D1 | Garder le talkie allumé sur 151,4 | « À toutes les stations, ici Logistique… » au départ, puis les coordonnées répétées au largage, puis « terminé » |
| D2 | Ouvrir la carte | Symbole « cible » vert au point de largage, un seul |
| D3 | Panneau de la radio réglée sur 151,4 | Chaîne affichée comme inconnue (pas « Military Logistics ») |
| D4 | Nouvel appel (attendre 1 h de jeu), radio **éteinte** au moment du largage | Pas de nouveau symbole |

## E. Caisse (phase 5)

| # | Action | Attendu |
|---|---|---|
| E1 | Aller au point de largage (repère de carte) | En arrivant, la caisse 3D (palette, caisse olive, sangles, « U.S. ARMY ») apparaît au point annoncé ou à moins de 30 cases, posée au sol, ni enfoncée ni flottante |
| E2 | Horde | Zombies autour de la caisse (3 à 30 par défaut) |
| E3 | Ouvrir le coffre (clic droit / menu véhicule) | Coffre « Caisse de largage militaire » avec 6 caisses de ravitaillement |
| E4 | Largage admin (« Forcer un largage ») sur une radio éteinte, rangée dans l'inventaire | Accepté ; coordonnées en message privé ; délai non modifié |

## F. Sauvegarde

| # | Action | Attendu |
|---|---|---|
| F1 | Sauvegarder et quitter **pendant un vol**, recharger | L'hélicoptère reprend son vol (son, ombre) et largue normalement |
| F2 | Recharger une partie avec une caisse déjà posée | Caisse toujours là, contenu conservé |

## Plus tard : multijoueur (hébergé, puis serveur dédié `C:\pzserver`)

- Deux joueurs : l'un appelle, l'autre écoute la fréquence (annonce et symbole) sans avoir appelé.
- Déconnexion et reconnexion pendant un vol : l'hélicoptère réapparaît à sa position.
- Joueur non admin : pas d'option « Forcer un largage » ; commande forgée refusée (journal serveur).
- Avec HEF actif : départ retardé si un événement HEF est proche.
