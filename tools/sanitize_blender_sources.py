"""Run with headless Blender to keep only the source scenes and relative build paths."""
from pathlib import Path
import sys
import bpy

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from sanitize_asset_paths import sanitize_asset_paths

for path in [ROOT / 'source/radio_jammer/radio_jammer.blend']:
    with bpy.data.libraries.load(str(path), link=False) as (source, target):
        target.scenes = source.scenes
    scenes = set(target.scenes)
    for scene in scenes:
        scene.render.filepath = '//preview.png'
        props = scene.get('pz_forge')
        if props is not None:
            props['output_dir'] = '//cells'
    bpy.data.libraries.write(str(path), scenes, path_remap='RELATIVE', compress=False)
    print(path.name, len(scenes), 'source scene(s)', sanitize_asset_paths(path), 'path prefix(es) removed')
