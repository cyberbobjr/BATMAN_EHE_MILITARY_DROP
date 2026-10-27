"""Publish this project with player-facing notes, keeping CHANGELOG.md technical.

Uses the shared publisher for validation, preview preservation and translated uploads.
Without --submit this is a dry run and does not contact Steam.
"""
from pathlib import Path
import argparse
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / '.claude' / 'tools'))
from pz_workshop_project import Project
from steam_workshop_publish import check_release, print_plan, publish


class ReleaseProject(Project):
    def latest_changelog(self):
        technical = super().latest_changelog()
        text = (self.root / 'workshop-changenote.md').read_text(encoding='utf-8')
        header, body = text.split('\n', 1)
        match = re.fullmatch(r'## ([0-9]+\.[0-9]+\.[0-9]+) .+ [0-9]{4}-[0-9]{2}-[0-9]{2}', header)
        if not match or not technical or match.group(1) != technical[0]:
            raise ValueError('Steam change note version must match the technical changelog')
        return technical[0], body.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--submit', action='store_true')
    parser.add_argument('--tag', action='store_true')
    args = parser.parse_args()
    args.create = args.allow_dirty = args.allow_republish = args.skip_tests = False
    args.skip_language = ''
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    project = ReleaseProject.load(ROOT)
    errors, version, note = check_release(project, args)
    print_plan(project, version, note, set())
    if errors:
        for error in errors:
            print('BLOCKED: ' + error)
        return 1
    if not args.submit:
        print('Dry run: nothing sent to Steam.')
        return 0
    return publish(project, version, note, args, set())


if __name__ == '__main__':
    sys.exit(main())
