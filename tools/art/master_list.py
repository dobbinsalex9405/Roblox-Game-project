"""Hatchery Heist master creature list: check it and see what is left to build.

The list lives in tools/art/roster/master/master-list.json (a subfolder, so
variants.py does not load it as roster entries). Every creature the game plans
to have is on it, all seven tiers, with its family, body plan, gait, element and
a one-line look. Builder threads pick their batches from it.

    python3 tools/art/master_list.py                 check the list, print counts
    python3 tools/art/master_list.py --todo [TIER]   creatures not built yet
    python3 tools/art/master_list.py --plans         new body plans the list needs

"Built" means the id is in tools/art/roster/*.json or in the game's
config/creatures.luau. The check fails (exit 1) on a duplicate or badly formed
id, an unknown tier, gait or element, a tier count that misses its target, or
an existing creature that is missing from the list.
"""

import collections
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
MASTER = os.path.join(HERE, 'roster', 'master', 'master-list.json')
ROSTER = os.path.join(HERE, 'roster', '*.json')
CONFIG = os.path.join(ROOT, 'games', 'hatchery-heist', 'config', 'creatures.luau')

TIERS = ['Common', 'Uncommon', 'Rare', 'Ultra Rare', 'Epic', 'Legendary', 'Godly']
GAITS = {'trot', 'waddle', 'hop', 'scuttle', 'slither', 'hover', 'swim'}
ELEMENTS = {'plain', 'Ember', 'Glacial', 'Nature', 'Storm'}
STATUSES = {'in-game', 'designed', 'rework', 'new'}
# Body plans tools/art can build today (variants.py, kit_pond.py, legends.py).
BUILT_PLANS = {'quadruped', 'bird', 'blob', 'bug', 'crab', 'lizard', 'critter', 'shore'}
BUILT_KINDS = {'scorpion': False}  # critter kinds still to add
ID_RE = re.compile(r'^[A-Z][A-Za-z0-9]{1,23}$')
FIELDS = ('id', 'name', 'tier', 'family', 'plan', 'gait', 'element', 'look', 'feature', 'status')


def load(path=MASTER):
    with open(path) as f:
        return json.load(f)


def existing():
    """{id: (where, tier)} for every creature already designed or in the game."""
    out = {}
    for path in sorted(glob.glob(ROSTER)):
        with open(path) as f:
            for c in json.load(f)['creatures']:
                out[c['id']] = ('roster', c['rarity'])
    if os.path.exists(CONFIG):
        with open(CONFIG) as f:
            src = f.read()
        for m in re.finditer(r'^\t\t(\w+) = \{\s*rarity = "([^"]+)"', src, re.M):
            out[m.group(1)] = ('game', m.group(2))
    return out


def base_plan(plan):
    return plan.split(' ')[0]


def needs_new_plan(c):
    plan = c['plan']
    if base_plan(plan) not in BUILT_PLANS:
        return True
    kind = re.search(r'\((\w+)\)', plan)
    return bool(kind and BUILT_KINDS.get(kind.group(1)) is False)


def check(doc, have):
    errors = []
    rows = doc['creatures']
    seen = set()
    for c in rows:
        cid = c.get('id', '?')
        for k in FIELDS:
            if not c.get(k):
                errors.append(f'{cid}: missing {k}')
        if not ID_RE.match(cid):
            errors.append(f'{cid}: id must be CamelCase, at most 24 characters')
        if cid in seen:
            errors.append(f'{cid}: listed twice')
        seen.add(cid)
        if c.get('tier') not in TIERS:
            errors.append(f'{cid}: unknown tier {c.get("tier")}')
        if c.get('gait') not in GAITS:
            errors.append(f'{cid}: unknown gait {c.get("gait")}')
        if c.get('element') not in ELEMENTS:
            errors.append(f'{cid}: unknown element {c.get("element")}')
        if c.get('status') not in STATUSES:
            errors.append(f'{cid}: unknown status {c.get("status")}')
        if c.get('status') == 'new' and cid in have:
            errors.append(f'{cid}: marked new but already exists ({have[cid][0]})')
        if c.get('status') != 'new' and cid not in have:
            errors.append(f'{cid}: marked {c.get("status")} but not found in the roster or config')
    for cid, (where, _) in sorted(have.items()):
        if cid not in seen:
            errors.append(f'{cid}: exists in the {where} but is not on the master list')
    counts = collections.Counter(c.get('tier') for c in rows)
    for tier, want in doc.get('targets', {}).items():
        if counts[tier] != want:
            errors.append(f'{tier}: {counts[tier]} creatures, target {want}')
    names = collections.Counter(c.get('name', '').lower() for c in rows)
    errors += [f'name "{n}" used twice' for n, k in names.items() if k > 1]
    return errors


def main(argv):
    doc = load()
    have = existing()
    rows = doc['creatures']
    if '--todo' in argv:
        i = argv.index('--todo')
        tier = ' '.join(argv[i + 1:]) or None
        for c in rows:
            if c['id'] in have or (tier and c['tier'] != tier):
                continue
            flag = '  NEW PLAN' if needs_new_plan(c) else ''
            print(f"{c['tier']:<11} {c['id']:<24} {c['family']:<11} {c['plan']:<22} {c['gait']:<8} {c['element']:<8}{flag}")
        return 0
    if '--plans' in argv:
        need = collections.Counter(c['plan'] for c in rows if c['id'] not in have and needs_new_plan(c))
        for plan, n in need.most_common():
            print(f'{n:4}  {plan}')
        return 0
    errors = check(doc, have)
    built = sum(1 for c in rows if c['id'] in have)
    print(f"master list: {len(rows)} creatures, {built} already exist, {len(rows) - built} to build "
          f"(approval: {doc.get('approval', 'unknown')})")
    for tier in TIERS:
        tier_rows = [c for c in rows if c['tier'] == tier]
        done = sum(1 for c in tier_rows if c['id'] in have)
        print(f'  {tier:<11} {len(tier_rows):4}  ({done} exist)')
    moves = [c for c in rows if c['id'] in have and have[c['id']][1] != c['tier']]
    for c in moves:
        print(f"  move pending: {c['id']} is {have[c['id']][1]} in the {have[c['id']][0]}, {c['tier']} on the list")
    for e in errors:
        print('ERROR', e)
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
