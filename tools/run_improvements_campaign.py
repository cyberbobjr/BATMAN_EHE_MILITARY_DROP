"""Run the branch's real-game scenarios serially, using throwaway pz-autotest caches."""
import argparse
import datetime
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT.parent / '.claude/tools/pz-autotest/pz_autotest.py'
CASES = {
    'admin-sp': ['sp', 'autotest/scenarios/administration.json'],
    'admin-mp': ['mp', 'autotest/scenarios/administration.json', '--clients', '2', '--client-run'],
    'admin-mp-extra': ['mp', 'autotest/scenarios/administration.json', '--clients', '2', '--client-run', '-P', 'extended=1'],
    'jammer-visual': ['sp', 'autotest/scenarios/visual.json'],
    'features-mp': ['mp', 'autotest/scenarios/improvements.json', '--clients', '2', '--client-run'],
    'field-mp': ['mp', 'autotest/scenarios/field.json', '--clients', '2', '--client-run'],
    'nominal-mp': ['mp', '.', '--clients', '2', '--client-run', '-P', 'shots=1'],
    'fulton-sp': ['sp', '.', '-P', 'scenario=fulton', '-P', 'shots=1'],
    'fulton-mp': ['mp', '.', '--clients', '2', '--client-run', '-P', 'scenario=fulton', '-P', 'shots=1'],
    'clearance-mp': ['mp', '.', '--clients', '2', '--client-run', '-P', 'scenario=corrections', '-P', 'shots=1'],
    'persistence': ['sp', 'autotest/scenarios/persistence.json', '--keep-cache'],
    'reconnect-mp': ['mp', 'autotest/scenarios/reconnect.json', '--clients', '2', '--client-run'],
    'relay-context': ['sp', 'autotest/scenarios/relay-context.json'],
    'craft-mp': ['mp', 'autotest/scenarios/crafting.json', '--clients', '2', '--client-run'],
    'field-sp': ['sp', 'autotest/scenarios/field.json'],
}

def run(argv):
    process = subprocess.Popen([sys.executable, *map(str, argv)], cwd=ROOT,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace')
    lines = []
    for line in process.stdout:
        print(line, end='', flush=True)
        lines.append(line)
    return process.wait(), ''.join(lines)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('cases', nargs='*', choices=list(CASES))
    args = parser.parse_args()
    rows = []
    out = ROOT / ('runs/campaign-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S') + '.json')
    out.parent.mkdir(exist_ok=True)
    for name in args.cases or list(CASES):
        code, stdout = run([TOOL, *CASES[name], '--wait-idle', '3600'])
        folders = re.findall(r'results in (.+)', stdout)
        rows.append({'case': name, 'code': code, 'results': folders[-1].strip() if folders else None})
        if name == 'persistence' and code == 0:
            source = re.search(r'PZAT_CACHE=(.+)', stdout).group(1).strip()
            code, stdout = run([ROOT / 'tools/retest_cached_save.py', source, 'autotest/scenarios/persistence.json'])
            folders = re.findall(r'results in (.+)', stdout)
            rows.append({'case': 'persistence-reload', 'code': code,
                'results': folders[-1].strip() if folders else None})
        out.write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
        if code:
            print(f'Campaign stopped at {name}: exit {code}. Evidence: {out}', flush=True)
            return code
    print(f'Campaign finished: {out}', flush=True)
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
