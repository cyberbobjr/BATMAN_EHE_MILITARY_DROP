"""Reopen a copied test save, including this mod's seed files, in a NEW throwaway cache.

Usage: python tools/retest_cached_save.py <pzat-sp-cache> <config.json>
The original user profile, user saves and Steam Workshop remain read-only.
"""
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / '.claude/tools/pz-autotest'))
import pz_autotest
from pzat import runner

source = Path(sys.argv[1]).resolve()
if not source.is_relative_to(Path(tempfile.gettempdir()).resolve()) or not source.name.startswith('pzat-sp-'):
    raise SystemExit('Only a temporary pzat-sp cache may be used as the source')
original = runner.build_client_cache

def build(env, cache, *args, **kwargs):
    original(env, cache, *args, **kwargs)
    seeds = source / 'Lua/MilitaryDrop'
    if seeds.is_dir():
        shutil.copytree(seeds, cache / 'Lua/MilitaryDrop', dirs_exist_ok=True)

runner.build_client_cache = build
raise SystemExit(pz_autotest.main(['sp', sys.argv[2], '--wait-idle', '3600', '-P', 'phase=reload'],
    env=runner.Env(zomboid=source)))
