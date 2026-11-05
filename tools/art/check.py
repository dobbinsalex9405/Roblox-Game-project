"""Hatchery Heist creature consistency check. Run from the repo root on your
PR branch before marking it ready:

    python3 tools/art/check.py [--base origin/main] [--fast]

It runs every check the creature thread runs by hand and prints PASS/FAIL
lines plus a table of the creatures your branch adds or changes. Paste the
summary into your message asking for the consistency check. Exit code 1 on
any FAIL. --fast skips the Luau tests and stylua (do the full run once).

Checks:
 1. roster files load (tools/art/variants.py): fields, plans, colours, unique ids
 2. generated files are current: export.py + blender/luau.py leave no git diff
 3. per creature (all of build_all, not only the game's config):
    - triangles within the tier budget, LOD1 <= 4,000, every mesh <= 20,000
    - height 0.8 .. 4.6 studs; width/depth <= 7 studs (WARN: pads are ~7 apart)
    - parents valid, every leg parented to body, legs paired left/right
    - gait is one of trot/waddle/hop/scuttle/slither/hover/swim and fits the legs:
      trot 4, waddle 2, hop 0/2/4/6 (hopping insects), scuttle 0 or 4+,
      slither 0, hover any, swim 0 (fins are finL/finR, not legs)
    - Legendary/Godly are hand-built (not in tools/art/roster)
 4. ids unique, CamelCase <= 24 chars, never reuse a removed id
 5. hatchery tests pass (lune run tools/test/run hatchery), stylua --check
"""
import argparse
import os
import re
import subprocess
import sys

ROOT = os.getcwd()
sys.path[:0] = [os.path.join(ROOT, 'tools/art'), os.path.join(ROOT, 'tools/art/blender')]
BUDGET = {'Common': 15000, 'Uncommon': 15000, 'Rare': 15000, 'Ultra Rare': 20000,
          'Epic': 28000, 'Legendary': 40000, 'Godly': 100000}
GAITS = {'trot', 'waddle', 'hop', 'scuttle', 'slither', 'hover', 'swim'}
GENERATED = ['games/hatchery-heist/src/shared/VoxelArt.luau', 'games/hatchery-heist/src/shared/CreatureMeshes.luau']
fails, warns = [], []


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=ROOT)


def fail(msg):
    fails.append(msg)
    print('FAIL', msg)


def warn(msg):
    warns.append(msg)
    print('WARN', msg)


def legs_ok(gait, n):
    return {'trot': n == 4, 'waddle': n == 2, 'hop': n in (0, 2, 4, 6), 'scuttle': n == 0 or n >= 4,
            'slither': n == 0, 'hover': True, 'swim': n == 0}.get(gait, False)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--base', default='origin/main')
    ap.add_argument('--fast', action='store_true')
    a = ap.parse_args()
    if not os.path.isdir('tools/art'):
        sys.exit('run from the repo root')

    import variants
    try:
        roster = {e['id'] for _, e in variants.load()}
        print(f'PASS roster: {len(roster)} roster creatures load')
    except variants.RosterError as e:
        fail(f'roster: {e}')
        roster = set()

    for cmd in ('python3 tools/art/export.py', 'python3 tools/art/blender/luau.py'):
        r = sh(cmd)
        if r.returncode:
            fail(f'{cmd}: {(r.stderr or r.stdout).strip().splitlines()[-1:]}')
    diff = sh('git status --porcelain -- ' + ' '.join(GENERATED)).stdout.strip()
    if diff:
        fail(f'generated files were stale (now regenerated, commit them): {diff}')
    else:
        print('PASS generated files current')

    import describe as D
    metas = D.manifest()['creatures']
    ids = [m['id'] for m in metas]
    dup = {i for i in ids if ids.count(i) > 1}
    if dup:
        fail(f'duplicate ids {sorted(dup)}')
    r = sh(f'git show {a.base}:games/hatchery-heist/src/shared/VoxelArt.luau')
    base_ids = set(re.findall(r'^\t\t([A-Z][A-Za-z0-9]*) = \{', r.stdout, re.M)) if r.returncode == 0 else set()
    for path in sh(f'git ls-tree --name-only {a.base} tools/art/roster/').stdout.split():
        if path.endswith('.json'):
            base_ids |= set(re.findall(r'"id":\s*"([A-Za-z0-9]+)"', sh(f'git show {a.base}:{path}').stdout))
    changed = set(sh(f'git diff --name-only {a.base}...HEAD').stdout.split())
    rows = []
    for m in metas:
        sid, tier = m['id'], m['rarity']
        where = f'{sid} ({tier})'
        if not re.match(r'^[A-Z][A-Za-z0-9]{1,23}$', sid):
            fail(f'{where}: id must be CamelCase, at most 24 chars')
        if m['tris'] > BUDGET[tier]:
            fail(f'{where}: {m["tris"]} tris > {BUDGET[tier]}')
        if m['trisLod1'] > 4000:
            fail(f'{where}: LOD1 {m["trisLod1"]} tris > 4000')
        for p in m['parts']:
            for me in p['meshes']:
                if me['tris'] > 20000:
                    fail(f'{where}: mesh {me["name"]} {me["tris"]} tris > 20000 (Roblox limit)')
        h = m['heightStuds']
        if not 0.8 <= h <= 4.6:
            fail(f'{where}: height {h} outside 0.8..4.6')
        w, _, d = m['sizeStuds']
        if max(w, d) > 7:
            warn(f'{where}: footprint {w:.1f} x {d:.1f} studs; pads are ~7 apart, check in Studio')
        legs = [p for p in m['parts'] if p['name'].startswith('leg')]
        for p in legs:
            if p['parent'] != 'body':
                fail(f'{where}: {p["name"]} parent {p["parent"]}, must be body')
        nl = sum(p['name'].endswith('L') for p in legs)
        nr = sum(p['name'].endswith('R') for p in legs)
        if nl != nr:
            fail(f'{where}: {nl} left legs vs {nr} right legs')
        if 'gait' not in m:
            warn(f'{where}: no gait (branch is older than the walking-legs PR #70; merge main)')
        elif m['gait'] not in GAITS:
            fail(f'{where}: gait {m["gait"]!r}')
        elif not legs_ok(m['gait'], len(legs)):
            fail(f'{where}: gait {m["gait"]} with {len(legs)} legs')
        if tier in ('Legendary', 'Godly') and sid in roster:
            fail(f'{where}: Legendary/Godly must be hand-built, not a roster entry')
        if sid not in base_ids:
            rows.append(('new', m, len(legs)))
    for sid in base_ids - set(ids):
        fail(f'{sid}: in {a.base} but no longer built (never remove or rename an id)')

    if not a.fast:
        r = sh('lune run tools/test/run hatchery')
        last = (r.stdout.strip().splitlines() or [''])[-1]
        (fail if r.returncode else print)(f'{"" if r.returncode else "PASS "}tests: {last}')
        r = sh('stylua --check games tools packages playtests')
        if r.returncode:
            fail('stylua --check: run stylua packages games tools playtests')
        else:
            print('PASS stylua')

    print(f'\n{len(metas)} creatures built; {len(rows)} new vs {a.base}; files changed: {len(changed)}')
    print(f'{"":4s}{"id":18s}{"tier":11s}{"gait":8s}{"legs":>4s}{"height":>7s}{"tris":>8s}{"lod1":>6s}')
    for tag, m, nl in rows:
        print(f'{tag:4s}{m["id"]:18s}{m["rarity"]:11s}{m.get("gait", "-"):8s}{nl:4d}{m["heightStuds"]:7.2f}{m["tris"]:8d}{m["trisLod1"]:6d}')
    print(f'\nRESULT: {"FAIL" if fails else "PASS"} ({len(fails)} fail, {len(warns)} warn)')
    print('Also send: renders of every new creature in the viewer folder (lineup.py), head commit, PR number.')
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
