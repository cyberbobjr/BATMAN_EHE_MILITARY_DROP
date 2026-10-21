"""Lanceur de l'outil générique Workshop/.claude/tools/wiki_sync.py pour ce projet.

Usage historique (conservé) :
    python tools/wiki_sync.py docs/wiki <wiki> [--check]
        écrit les pages converties dans le clone <wiki> et supprime les pages EN-/FR-
        orphelines (comme avant) ; --check compare à <wiki> sans rien écrire.
Usage générique (options transmises telles quelles) :
    python tools/wiki_sync.py [--out DIR | --check | --push] [--prune] ...
        voir l'outil générique (--help). Pousser le wiki seulement après avoir poussé main.
"""
import runpy
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
TOOL = PROJECT.parent / ".claude" / "tools" / "wiki_sync.py"


def main():
    if not TOOL.exists():
        raise SystemExit(f"generic tool not found: {TOOL}")
    args = sys.argv[1:]
    positional = [a for a in args if not a.startswith("-")]
    options = [a for a in args if a.startswith("-")]
    if len(positional) == 2 and set(options) <= {"--check"}:
        source, wiki = Path(positional[0]).resolve(), positional[1]
        if source != PROJECT / "docs" / "wiki":
            raise SystemExit(f"source must be {PROJECT / 'docs' / 'wiki'}, got {source}")
        forwarded = ["--check", "--wiki", wiki, "--prune"] if options else ["--out", wiki, "--prune"]
        args = forwarded + ["--title", "Military Drop"]
    sys.exit(runpy.run_path(str(TOOL))["main"]([str(PROJECT), *args]))


if __name__ == "__main__":
    main()
