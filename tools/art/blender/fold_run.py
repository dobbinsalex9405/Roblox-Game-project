"""Folds chosen creatures' assets.json entries from an upload run's branch
into this one, leaving every other entry and the file's order untouched.

    python3 tools/art/blender/fold_run.py RUN_ID Name,Name,...

RUN_ID names the branch creature-meshes/RUN_ID (fetched first). Then run
luau.py so CreatureMeshes takes the ids."""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, 'assets.json')


def main():
    run, names = sys.argv[1], [n for n in sys.argv[2].split(',') if n]
    theirs = json.loads(subprocess.check_output(
        ['git', 'show', f'origin/creature-meshes/{run}:tools/art/blender/assets.json']))['models']
    with open(ASSETS) as f:
        data = json.load(f)
    for n in names:
        if n not in theirs:
            raise SystemExit(f'{n}: not in run {run}')
        if data['models'].get(n) == theirs[n]:
            raise SystemExit(f'{n}: run {run} has the same entry (not uploaded there)')
        data['models'][n] = theirs[n]
    with open(ASSETS, 'w') as f:
        json.dump(data, f, indent=1)
        f.write('\n')
    print(f'folded {len(names)} from run {run}')


if __name__ == '__main__':
    main()
