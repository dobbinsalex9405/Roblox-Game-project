"""Creatures as data: every file in tools/art/roster/*.json adds creatures to
the ROSTER, so a new Common needs no code. One entry:

    {"id": "Calf", "rarity": "Common", "plan": "quadruped",
     "colors": {"col": "#FFFFFF", "snout": "#FFB3C7", "ear_col": "#3A3A4A"},
     "options": {"ears": "floppy", "tail": "short"},
     "patterns": [{"kind": "spots", "color": "#3A3A4A"}],
     "accessories": [{"kind": "bell", "color": "#E84855", "color2": "#FFD43B"}]}

- **plan** is a body plan, and `colors` and `options` are its arguments
  (PLANS below lists them). Colours are "#RRGGBB". The plans: quadruped,
  bird, blob (frog, snail, ladybug, axolotl, turtle), bug (bee, butterfly,
  beetle, caterpillar), crab and lizard (gecko, chameleon, iguana, bearded).
  kit_pond.py adds `critter` (dragonfly, ant, grasshopper, spider, firefly,
  pillbug, worm, slug, mantis) and `shore` (starfish, urchin, hermit,
  lobster, seal, walrus, newt, beaver, platypus); both take `kind`.
- **shape** changes proportions: `"body": [width, length, height]` (0.8 to
  1.35 each) and `"head"` (0.8 to 1.3), so one plan makes many silhouettes.
- **patterns** paint the body after it is built: spots, stripes, socks,
  saddle, tips, back. Each takes a colour and, optionally, `parts` (the
  part names to paint, default ["body"]).
- **accessories** add a part: beanie, bow, flower, sprout, scarf, bell,
  horns, beard. Each takes `color` and an optional `color2`.
- **element** is optional ("plain" when left out).

Files are read in name order, so a batch file per thread never collides
with another. `python3 tools/art/variants.py` checks every file and lists
the creatures; a mistake (an unknown plan, option or colour) names the file
and the entry."""
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROSTER_DIR = os.path.join(HERE, 'roster')
RARITIES = ['Common', 'Uncommon', 'Rare', 'Ultra Rare', 'Epic', 'Legendary', 'Godly']

# plan -> (colour arguments, option arguments with their allowed values)
PLANS = {
    'quadruped': (
        {'col', 'belly', 'snout', 'ear_col', 'tail_col', 'mask', 'patches', 'mane', 'spines'},
        {'ears': {'pointy', 'big', 'round', 'long', 'floppy'},
         'tail': {'short', 'curly', 'bushy', 'fox', 'long', 'striped', 'none'},
         'fluffy': {True, False}, 'pig': {True, False}},
    ),
    'bird': (
        {'col', 'belly', 'beak', 'wing', 'crest', 'tail', 'feet'},
        {'big_eyes': {True, False}, 'tuft': {True, False}, 'bill': {True, False}},
    ),
    'blob': ({'col', 'accent'}, {'kind': {'frog', 'snail', 'ladybug', 'axolotl', 'turtle'}}),
    'bug': ({'col', 'accent', 'wing'}, {'kind': {'bee', 'butterfly', 'beetle', 'caterpillar'}}),
    'crab': ({'col', 'accent'}, {}),
    'lizard': ({'col', 'accent', 'belly'}, {'kind': {'gecko', 'chameleon', 'iguana', 'bearded'}}),
}
# More plans, each kit in its own module so batches add plans without editing
# the same lines: kit_pond (critter, shore).
sys.path.insert(0, HERE)
import kit_pond  # noqa: E402

PLANS.update(kit_pond.PLANS)
EXTRA_BUILDERS = dict(kit_pond.BUILDERS)
PATTERNS = {'spots', 'stripes', 'socks', 'saddle', 'tips', 'back'}
ACCESSORIES = {'beanie', 'bow', 'flower', 'sprout', 'scarf', 'bell', 'horns', 'beard'}
HEX = re.compile(r'^#[0-9A-Fa-f]{6}$')
ID = re.compile(r'^[A-Z][A-Za-z0-9]{1,23}$')


class RosterError(ValueError):
    pass


def check(entry, where):
    def bad(msg):
        raise RosterError(f'{where}: {msg}')

    allowed = {'id', 'rarity', 'plan', 'colors', 'options', 'shape', 'patterns', 'accessories', 'element', 'note'}
    for key in entry:
        if key not in allowed:
            bad(f'unknown field "{key}" (fields: {", ".join(sorted(allowed))})')
    sid = entry.get('id')
    if not isinstance(sid, str) or not ID.match(sid):
        bad(f'id "{sid}" must be CamelCase letters and digits, like "GoatKid"')
    if entry.get('rarity') not in RARITIES:
        bad(f'{sid}: rarity must be one of {RARITIES}')
    plan = entry.get('plan')
    if plan not in PLANS:
        bad(f'{sid}: plan must be one of {sorted(PLANS)}')
    colours, options = PLANS[plan]
    cols = entry.get('colors', {})
    if 'col' not in cols:
        bad(f'{sid}: colors needs "col", the main colour')
    for name, v in cols.items():
        if name not in colours:
            bad(f'{sid}: {plan} has no colour "{name}" (it has {sorted(colours)})')
        if not isinstance(v, str) or not HEX.match(v):
            bad(f'{sid}: colour {name} = {v!r} is not "#RRGGBB"')
    for name, v in entry.get('options', {}).items():
        if name not in options:
            bad(f'{sid}: {plan} has no option "{name}" (it has {sorted(options)})')
        if v not in options[name]:
            bad(f'{sid}: option {name} = {v!r}; allowed {sorted(map(str, options[name]))}')
    if plan in ('blob', 'bug', 'lizard', 'critter', 'shore') and 'kind' not in entry.get('options', {}):
        bad(f'{sid}: a {plan} needs options.kind')
    sh = entry.get('shape', {})
    for key in sh:
        if key not in ('body', 'head'):
            bad(f'{sid}: shape has "body" [width, length, height] and "head", not "{key}"')
    if 'body' in sh and (len(sh['body']) != 3 or not all(0.8 <= v <= 1.35 for v in sh['body'])):
        bad(f'{sid}: shape.body must be 3 numbers from 0.8 to 1.35')
    if 'head' in sh and not 0.8 <= sh['head'] <= 1.3:
        bad(f'{sid}: shape.head must be from 0.8 to 1.3')
    for p in entry.get('patterns', []):
        if p.get('kind') not in PATTERNS:
            bad(f'{sid}: pattern kind must be one of {sorted(PATTERNS)}')
        if not HEX.match(str(p.get('color', ''))):
            bad(f'{sid}: pattern {p.get("kind")} needs a "#RRGGBB" color')
    for a in entry.get('accessories', []):
        if a.get('kind') not in ACCESSORIES:
            bad(f'{sid}: accessory kind must be one of {sorted(ACCESSORIES)}')
        for key in ('color', 'color2'):
            if key in a and not HEX.match(str(a[key])):
                bad(f'{sid}: accessory {a["kind"]} {key} is not "#RRGGBB"')
        if 'color' not in a:
            bad(f'{sid}: accessory {a["kind"]} needs a color')


def load(directory=ROSTER_DIR):
    """[(file, entry)] from every roster file, checked."""
    out, seen = [], {}
    for path in sorted(glob.glob(os.path.join(directory, '*.json'))):
        name = os.path.basename(path)
        with open(path) as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError as e:
                raise RosterError(f'{name}: not valid JSON ({e})')
        if not isinstance(data, dict) or not isinstance(data.get('creatures'), list):
            raise RosterError(f'{name}: expected {{"creatures": [ ... ]}}')
        for i, entry in enumerate(data['creatures']):
            check(entry, f'{name} #{i + 1}')
            if entry['id'] in seen:
                raise RosterError(f'{name}: {entry["id"]} is also in {seen[entry["id"]]}')
            seen[entry['id']] = name
            out.append((name, entry))
    return out


def builder(entry):
    """fn(c, H) that builds the entry, for the ROSTER."""
    import creatures as cr
    import kit
    from voxkit import hexc

    plan = entry['plan']
    cols = {k: hexc(v) for k, v in entry.get('colors', {}).items()}
    opts = dict(entry.get('options', {}))

    def build(c, H, cols=cols, opts=opts):
        cols, opts = dict(cols), dict(opts)  # a fresh copy each build
        if plan == 'quadruped':
            col = cols.pop('col')
            if opts.get('tail') == 'none':
                opts['tail'] = 'nothing'
            cr.quadruped(c, H, col, **cols, **opts)
        elif plan == 'bird':
            col = cols.pop('col')
            cr.bird(c, H, col, **cols, **opts)
        elif plan == 'blob':
            cr.blob(c, H, opts['kind'], cols['col'], cols.get('accent', cols['col']))
        elif plan == 'bug':
            kit.bug(c, H, opts['kind'], cols['col'], cols.get('accent', kit.INK), cols.get('wing'))
        elif plan == 'crab':
            kit.crab(c, H, cols['col'], cols.get('accent', cols['col']))
        elif plan == 'lizard':
            kit.lizard(c, H, opts['kind'], cols['col'], cols.get('accent', cols['col']), cols.get('belly'))
        elif plan in EXTRA_BUILDERS:
            EXTRA_BUILDERS[plan](c, H, dict(cols), opts)
        sh = entry.get('shape')
        if sh:
            kit.shape(c, tuple(sh.get('body', (1.0, 1.0, 1.0))), sh.get('head', 1.0))
        for p in entry.get('patterns', []):
            kit.pattern(c, H, p['kind'], p['color'], tuple(p.get('parts', ['body'])))
        for a in entry.get('accessories', []):
            kit.accessory(c, H, a['kind'], a['color'], a.get('color2'))
        return c

    return build


def roster_entries():
    return [(e['id'], e['rarity'], builder(e)) for _, e in load()]


def elements():
    return {e['id']: e['element'] for _, e in load() if e.get('element')}


if __name__ == '__main__':
    sys.path.insert(0, HERE)
    try:
        entries = load()
    except RosterError as e:
        print(f'roster error: {e}')
        sys.exit(1)
    for name, e in entries:
        print(f'{name:28s} {e["id"]:18s} {e["rarity"]:10s} {e["plan"]}')
    print(f'{len(entries)} creatures in {ROSTER_DIR}')
