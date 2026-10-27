"""Remove personal build-root prefixes from new binary asset metadata without shifting data.

Only uncompressed .blend files or binary FBX are accepted. Replacing prefixes by an
equal-length relative placeholder preserves every block offset and string allocation.
Game textures are resolved by their explicit model-script paths.
"""
from pathlib import Path
import re
import sys

USER_ROOT = re.compile(rb'[A-Za-z]:[\\/]Users[\\/][^\\/:\x00-\x20]+', re.IGNORECASE)

def sanitize_asset_paths(path):
    path = Path(path)
    original = path.read_bytes()
    if not original.startswith((b'Kaydara FBX Binary', b'BLENDER')):
        raise ValueError('Expected binary FBX or uncompressed Blender data')
    def replace(match):
        size = len(match.group())
        return b'exportroot'[:size] + b'_' * max(0, size - 10)
    clean = USER_ROOT.sub(replace, original)
    assert len(clean) == len(original)
    path.write_bytes(clean)
    return len(USER_ROOT.findall(original))

if __name__ == '__main__':
    for name in sys.argv[1:]:
        print(Path(name).name, sanitize_asset_paths(name), 'personal path prefix(es) removed')
