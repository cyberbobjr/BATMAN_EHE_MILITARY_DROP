# Épave Mayday

Modèle original construit pour Military Drop, sans ressources d’EHE. Le fuselage et la queue sont deux véhicules distincts, exportés en FBX. Le démontage retire les lots installés dans les pièces ; le maillage reste visible jusqu’à la découpe finale vanilla.

Reconstruction depuis la racine du projet :

```powershell
python source/heli_wreck/make_texture.py
& 'D:/SteamLibrary/steamapps/common/Blender/blender.exe' -b --factory-startup --python source/heli_wreck/build_heli_wreck.py
python tests/check_mayday_assets.py
```

La recette ouvre sa propre scène et sauvegarde `heli_wreck.blend`, les modèles livrés, les trois aperçus et `metrics.json`. Blender 5.2.2 et Pillow ont été utilisés. Fuselage : 40 segments radiaux, 31 sections ; queue : 32 segments, 25 sections ovales, dérive et stabilisateurs biseautés. Export en centimètres, Y vers le haut, transformations de nœud identité ; `model scale = 0.01`, `vehicle scale = 1`.

Les dimensions, UV, textures et chemins ont été contrôlés hors jeu. Rendu, accès aux pièces et collisions restent à vérifier dans Project Zomboid 42.21.
