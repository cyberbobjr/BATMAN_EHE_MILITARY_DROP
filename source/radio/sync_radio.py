"""Synchronise les modules radio communs dans les deux projets, ou vérifie avec --check."""
import argparse
from pathlib import Path

SOURCE = Path(__file__).resolve().parent / "lua"
WORKSPACE = SOURCE.parents[3]
DESTINATIONS = [
    WORKSPACE / "MilitaryDrop/Contents/mods/batman_MilitaryDrop/42.21/media/lua",
    WORKSPACE / "OperationArtemis/Contents/mods/batman_OperationArtemis/42.21/media/lua",
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    errors = []
    for source in sorted(SOURCE.rglob("*.lua")):
        rel = source.relative_to(SOURCE)
        for destination in DESTINATIONS:
            if destination == DESTINATIONS[1] and not (WORKSPACE / "OperationArtemis").is_dir():
                continue  # dépôt MilitaryDrop seul (CI / clone indépendant)
            target = destination / rel
            if args.check:
                if not target.is_file() or target.read_bytes() != source.read_bytes():
                    errors.append(str(target))
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(source.read_bytes())
    if errors:
        raise SystemExit("Modules radio divergents :\n" + "\n".join(errors))
    print("Modules radio communs : copies identiques aux sources.")


if __name__ == "__main__":
    main()
