# Épave Mayday

Modèle original construit pour Military Drop, sans ressources d’EHE. Le fuselage et la queue sont deux véhicules distincts, exportés en FBX. Le démontage retire les lots installés dans les pièces ; le maillage reste visible jusqu’à la découpe finale vanilla.

Reconstruction depuis la racine du projet :

```powershell
python source/heli_wreck/make_texture.py
& 'D:/SteamLibrary/steamapps/common/Blender/blender.exe' -b --factory-startup --python source/heli_wreck/build_heli_wreck.py
python source/heli_wreck/make_shadows.py
python source/heli_wreck/make_mechanics_overlays.py
python tests/check_mayday_assets.py
```

La recette ouvre sa propre scène et sauvegarde `heli_wreck.blend`, les modèles livrés, les trois aperçus et `metrics.json`. Blender 5.2.2 et Pillow ont été utilisés. Fuselage : 40 segments radiaux, 31 sections ; queue : 32 segments, 25 sections ovales, dérive et stabilisateurs biseautés. Export en centimètres, Y vers le haut, transformations de nœud identité ; `model scale = 0.01`, `vehicle scale = 1`.

Les dimensions, UV, textures et chemins ont été contrôlés hors jeu. Le panneau de mécanique vanilla exige une entrée `ISCarMechanicsOverlay.CarList` et des masques par pièce : le générateur ci-dessous fournit un schéma 263 × 600 pour le fuselage et un pour la queue. Rendu en jeu, accès aux pièces et collisions restent à vérifier dans Project Zomboid 42.21.

## Révision du 2026-10-04

- Normales de coque et de poutre tournées vers l'extérieur ; normales des boîtes recalculées. La coque utilisait un ordre de sommets inversé, et les pièces fermées aussi.
- UV cylindriques sans étirement sur la dernière facette, projection plane pour les n-gones. Atlas avec peinture olive usée, éclats de métal, traces de suie, fissures de verre et bouts de pales contrastés. Nervures et bords métalliques visibles dans la cabine ouverte.
- Les deux ombres sont des silhouettes projetées depuis les FBX **livrés**. `make_shadows.py` écrit les textures RGBA et calcule `shadowExtents`/`shadowOffset` dans le script. Le coin UV (0,0) correspond à (+X,+Z) du FBX ; l'ombre ne dépend pas des dimensions automobiles par défaut. `shadows.json` conserve les mesures reproductibles.
- Chaque **nouveau** crash crée aussi deux zombies dans la tenue vanilla `ArmyCamoGreen`, qui existe pour les deux sexes. Le premier essai déclarait des GUID de vêtements vanilla dans `common/media/clothing/clothing.xml` ; B42 préfixe les GUID d'une tenue par l'id du mod, les quatre références ne trouvaient donc aucun vêtement et laissaient les zombies en sous-vêtements. Le cadavre existant, l'enregistreur et les documents sont conservés. `PilotOutfits` et `PilotDocuments` continuent de régler le cadavre.
- Le polygone de navigation d'un véhicule est un rectangle calculé uniquement depuis `extents.x/z` (`VehiclePoly.java:54-111`) et gonflé de 0,15 case (`BaseVehicle.java:3950-3975`). L'ancienne boîte 7,86 × 6,24 m suivait le diamètre des pales, bloquant les coins dégagés autour du fuselage. Les nouvelles dimensions 2,8 × 5,8 m suivent coque et patins ; le maillage, les pales et l'ombre gardent leur taille réelle.
- Création côté autorité seulement, sur des cases libres autour de la position réelle du fuselage. Chaque zombie a son marqueur de création indépendant, avec reprise si une case ou une création manque. Les anciens crashs sans `crewVersion` ne sont pas repeuplés. Le refus global des zombies par le moteur, hors mode debug, est respecté.
- Feu et fumée suivent désormais le fuselage, y compris après déplacement pour trouver de la place. Un foyer initial sur une seule case, énergie 40 / vie 1800 ; il n'est pas rallumé après extinction. La propagation reste régie par `FireSpread` et les interdictions du serveur. La fumée occupe une autre case : un vrai feu bloque `CanAddSmoke` sur sa case.
- La fumée est créée localement par `MilitaryDrop_WreckSmoke` en solo et chez les clients MP, avec une vie de 2400. Les notifications serveur sont espacées d'au moins dix secondes réelles, pendant `CrashSmokeMinutes` minutes de jeu ; le helper ne conserve qu'un objet et le renouvelle à 78 % de vie restante, avant son stade invisible. Une fumée ou un feu appartenant à un autre système n'est jamais supprimé. Le nouveau défaut de `CrashFire` est 3 (« Feu et fumée ») ; un choix sauvegardé à 2 reste « Fumée » et doit être changé pour les nouveaux crashs.

## Révision du 2026-10-05

- L'écran vanilla restait vide à gauche car aucun schéma `ISCarMechanicsOverlay.CarList` n'était déclaré pour les scripts d'épave. `MilitaryDrop_WreckMenu.lua` enregistre maintenant les deux véhicules, leurs images de base et les zones cliquables des pièces récupérables.
- `make_mechanics_overlays.py` génère les masques transparents 263 × 600 du fuselage et de la queue dans `common/media/ui/vehicles/mechanic overlay/`. Le premier rendu en jeu était trop schématique : la révision ajoute une coque olive contrastée, le vitrage fendu, les patins, les panneaux d'accès, les nervures, les fixations et des séparations fines dans les masques de pièces. La hitbox de la queue suit maintenant toute la zone rouge, y compris les stabilisateurs.
- Génération exécutée et PNG inspectés hors jeu. La vérification en jeu reste à refaire dans Project Zomboid 42.21, notamment le survol des stabilisateurs.

Validation : journal et sources installés 42.21.0, empreinte du JAR identique aux sources décompilées. Suite Lua simulée et contrôles FBX/UV/chemins/ombres/tenues réussis ; aperçus Blender examinés. Aucun nouveau test interactif ni test multijoueur réalisé.

Après redémarrage complet du jeu : choisir « Feu et fumée » dans les effets du crash, armer un crash puis forcer un nouveau largage, vérifier les ombres selon deux orientations, les deux zombies en combinaison, le cadavre fouillable et un foyer près de la carcasse avec fumée persistante ; quitter/recharger pour contrôler l'absence de doublons et d'incendie rallumé. En MP, refaire la vérification avec deux clients et une reconnexion, et confirmer que NoFire empêche le foyer sans empêcher la fumée.

### Demande de démembrage

Le cadavre n'est pas démembré. Les sources 42.21.0 ne donnent pas de mécanisme Lua natif confirmé pour retirer des membres d'un `IsoDeadBody` : `IsoGameCharacter.amputations` n'est pas copié au cadavre et `AnimationPlayer.dismember()` remplit une liste sans consommateur visible dans les sources installées. Une représentation dédiée (maillage/visuel de corps mutilé) demanderait un développement supplémentaire et une validation de son rendu, de sa sauvegarde et du réseau. Les sons sont traités dans une autre session et exclus de cette révision.
