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
- **gait** is optional: how it moves (trot, waddle, hop, scuttle, slither,
  hover, swim). Left out, rig.py guesses it from the plan, kind and legs.
- **glow**: `"glow": true` on a pattern or accessory makes the voxels it
  painted or added glow (emissive in the meshes, lit in the game).

More plans and accessories live in kit modules: every `kit_*.py` next to
this file is imported, and its `PLANS` ({plan: (colours, options)}),
`BUILDERS` ({plan: fn(c, H, cols, opts)}), `ACCESSORIES` ({kind: fn(c,
H, col, col2[, a])}, a parameter named `a` gets the roster dict, for its own
settings) and
`PATTERNS` ({kind: fn(c, H, col, parts, p)}) are added here. A name two modules both define is an error,
so batches never overwrite each other's plans.

Files are read in name order, so a batch file per thread never collides
with another. `python3 tools/art/variants.py` checks every file and lists
the creatures; a mistake (an unknown plan, option or colour) names the file
and the entry."""
import glob
import inspect
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
        {'col', 'belly', 'snout', 'ear_col', 'tail_col', 'mask', 'patches', 'mane', 'spines', 'glow', 'horn',
         'antlers', 'wings'},
        {'ears': {'pointy', 'cat', 'big', 'round', 'long', 'floppy', 'hanging'},
         'tail': {'short', 'curly', 'bushy', 'fox', 'long', 'striped', 'flame', 'none'},
         'fluffy': {True, False}, 'pig': {True, False}, 'cow': {True, False}, 'bunny': {True, False}},
    ),
    'bird': (
        {'col', 'belly', 'beak', 'wing', 'crest', 'tail', 'feet', 'glow'},
        {'big_eyes': {True, False}, 'tuft': {True, False}, 'bill': {True, False}},
    ),
    'blob': ({'col', 'accent'}, {'kind': {'frog', 'snail', 'ladybug', 'axolotl', 'turtle'}}),
    'bug': ({'col', 'accent', 'wing'}, {'kind': {'bee', 'butterfly', 'beetle', 'caterpillar'}}),
    'crab': ({'col', 'accent'}, {}),
    'lizard': ({'col', 'accent', 'belly'}, {'kind': {'gecko', 'chameleon', 'iguana', 'bearded'}}),
}
# More plans and accessories, each kit in its own module (kit_*.py, found by
# name) so batches add them without editing the same lines.
sys.path.insert(0, HERE)
EXTRA_BUILDERS, EXTRA_ACCESSORIES, EXTRA_PATTERNS = {}, {}, {}
_OWNER = {}


def _load_kits():
    import importlib
    for path in sorted(glob.glob(os.path.join(HERE, 'kit_*.py'))):
        name = os.path.splitext(os.path.basename(path))[0]
        mod = importlib.import_module(name)
        for table, into in ((getattr(mod, 'PLANS', {}), PLANS), (getattr(mod, 'BUILDERS', {}), EXTRA_BUILDERS),
                            (getattr(mod, 'ACCESSORIES', {}), EXTRA_ACCESSORIES),
                            (getattr(mod, 'PATTERNS', {}), EXTRA_PATTERNS)):
            for key, val in table.items():
                kind = {id(EXTRA_ACCESSORIES): 'accessory', id(EXTRA_PATTERNS): 'pattern'}.get(id(into), 'plan')
                if (kind, key) in _OWNER and _OWNER[(kind, key)] != name:
                    raise RuntimeError(f'{name}.py and {_OWNER[(kind, key)]}.py both define the {kind} "{key}"')
                _OWNER[(kind, key)] = name
                into[key] = val


_load_kits()
PATTERNS = {'spots', 'stripes', 'socks', 'saddle', 'tips', 'back'} | set(EXTRA_PATTERNS)
ACCESSORIES = {'beanie', 'bow', 'flower', 'sprout', 'scarf', 'bell', 'horns', 'beard'} | set(EXTRA_ACCESSORIES)
GAITS = ('trot', 'waddle', 'hop', 'scuttle', 'slither', 'hover', 'swim')
HEX = re.compile(r'^#[0-9A-Fa-f]{6}$')
ID = re.compile(r'^[A-Z][A-Za-z0-9]{1,23}$')


class RosterError(ValueError):
    pass


def check(entry, where):
    def bad(msg):
        raise RosterError(f'{where}: {msg}')

    allowed = {'id', 'rarity', 'plan', 'colors', 'options', 'shape', 'patterns', 'accessories', 'element', 'gait',
               'note'}
    for key in entry:
        if key not in allowed:
            bad(f'unknown field "{key}" (fields: {", ".join(sorted(allowed))})')
    sid = entry.get('id')
    if not isinstance(sid, str) or not ID.match(sid):
        bad(f'id "{sid}" must be CamelCase letters and digits, like "GoatKid"')
    if entry.get('rarity') not in RARITIES:
        bad(f'{sid}: rarity must be one of {RARITIES}')
    if 'gait' in entry and entry['gait'] not in GAITS:
        bad(f'{sid}: gait must be one of {list(GAITS)}')
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
        if p.get('glow', False) not in (True, False):
            bad(f'{sid}: pattern {p.get("kind")} glow must be true or false')
    for a in entry.get('accessories', []):
        if a.get('kind') not in ACCESSORIES:
            bad(f'{sid}: accessory kind must be one of {sorted(ACCESSORIES)}')
        for key in ('color', 'color2'):
            if key in a and not HEX.match(str(a[key])):
                bad(f'{sid}: accessory {a["kind"]} {key} is not "#RRGGBB"')
        if 'color' not in a:
            bad(f'{sid}: accessory {a["kind"]} needs a color')
        if a.get('glow', False) not in (True, False):
            bad(f'{sid}: accessory {a["kind"]} glow must be true or false')


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


def _lum(rgb):
    r, g, b = (v / 255.0 for v in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


DARK_FACE = 0.35
RING_CONTRAST = 0.12  # below this the deepened eye still sinks into the face


def eye_contrast(c):
    """Dark eyes vanish on a dark face (or a dark mask). When the face around
    an eye is dark, every eye gets a one-voxel white shine on its upper outer
    corner (a one-voxel eye grows to 2x2 to carry it, outward and down).
    The eye's ink is deepened toward black; only when that still leaves too
    little contrast does a big eye also get a faint ring, 25% toward white. The two
    rings never touch: where they would, the ring between the eyes is
    dropped, so they never read as goggles. Glowing eyes are left alone."""
    eyes = next((p for p in c.parts if p.name == 'eyes'), None)
    if not eyes or not eyes.v:
        return
    ink = [q for q, (rgb, g) in eyes.v.items() if not g and _lum(rgb) < 0.25]
    if not ink:
        return
    face = [p for p in c.parts if p is not eyes and p.name in ('head', 'body')]
    WHITE = (255, 255, 255)
    sides = []
    for sx, side in ((1, lambda x: x >= 0), (-1, lambda x: x < 0)):
        dots = [q for q in ink if side(q[0])]
        if not dots:
            continue
        ring = {}
        for (x, y, z) in dots:
            for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                for dy in (0, 1, -1):
                    q = (x + dx, y + dy, z + dz)
                    if q in eyes.v:
                        break
                    hit = next((p for p in face if q in p.v), None)
                    if hit:
                        ring[q] = hit
                        break
        if not ring:
            continue
        cols = [ring[q].v[q][0] for q in ring]
        if sum(_lum(col) for col in cols) / len(cols) >= DARK_FACE:
            continue
        sides.append((sx, side, dots, ring))

    def flat(qs):
        return {(q[0], q[2]) for q in qs}

    # rings that would touch lose the voxels between the eyes
    if len(sides) == 2:
        (_, _, d0, r0), (_, _, d1, r1) = sides
        a, b = flat(r0) | flat(d0), flat(r1) | flat(d1)
        if any((x + dx, z + dz) in b for (x, z) in a for dx, dz in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1))):
            inner0 = min(q[0] for q in d0)  # the right eye's inner edge
            inner1 = max(q[0] for q in d1)  # the left eye's inner edge
            for ring in (r0, r1):
                for q in [q for q in ring if inner1 < q[0] < inner0]:
                    del ring[q]

    for sx, side, dots, ring in sides:
        for q in dots:  # deepen the ink so the eye separates from the face
            eyes.v[q] = (tuple(round(v * 0.45) for v in eyes.v[q][0]), False)
        face_lum = sum(_lum(part.v[q][0]) for q, part in ring.items()) / max(1, len(ring))
        ink_lum = sum(_lum(eyes.v[q][0]) for q in dots) / len(dots)
        if len(dots) > 2 and face_lum - ink_lum < RING_CONTRAST:
            for q, part in ring.items():
                rgb, g = part.v[q]
                if not g:
                    part.v[q] = (tuple(round(v + (255 - v) * 0.25) for v in rgb), False)
        if any(eyes.v[q][0] == WHITE for q in eyes.v if side(q[0])):
            continue
        top = max(dots, key=lambda q: (q[2], q[0] * sx, -q[1]))
        if len(dots) >= 2:
            eyes.v[top] = (WHITE, False)
            continue
        # a one-voxel eye is too small to carry a shine, so it grows to a
        # 2x2 eye (outward and down) with the shine on its upper outer voxel
        x, y, z = top
        ink_rgb = eyes.v[top][0]  # already deepened
        grow = {(x + sx, z): WHITE, (x, z - 1): ink_rgb, (x + sx, z - 1): ink_rgb}
        spots = {k: _front(face, k[0], k[1], y) for k in grow}
        if all(spots.values()) and not any(sp[0] in eyes.v or sp[1].v[sp[0]][1] for sp in spots.values()):
            for k, (q, part) in spots.items():
                del part.v[q]
                eyes.v[q] = (grow[k], False)


def _front(parts, x, z, y0):
    """The front-most face voxel at (x, z) near depth y0, and its part."""
    for y in range(y0 - 2, y0 + 4):
        part = next((p for p in parts if (x, y, z) in p.v), None)
        if part:
            return (x, y, z), part
    return None


def builder(entry):
    """fn(c, H) that builds the entry, for the ROSTER."""
    import creatures as cr
    import rig
    import kit
    from voxkit import hexc

    plan = entry['plan']
    cols = {k: hexc(v) for k, v in entry.get('colors', {}).items()}
    opts = dict(entry.get('options', {}))

    def build(c, H, cols=cols, opts=opts):
        cols, opts = dict(cols), dict(opts)  # a fresh copy each build
        c.gait_hint = entry.get('gait') or rig.KIND_GAIT.get(opts.get('kind', plan))
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
            with _glowing(c, p.get('glow')):
                if p['kind'] in EXTRA_PATTERNS:
                    EXTRA_PATTERNS[p['kind']](c, H, hexc(p['color']), tuple(p.get('parts', ['body'])), p)
                else:
                    kit.pattern(c, H, p['kind'], p['color'], tuple(p.get('parts', ['body'])))
        for a in entry.get('accessories', []):
            with _glowing(c, a.get('glow')):
                if a['kind'] in EXTRA_ACCESSORIES:
                    fn = EXTRA_ACCESSORIES[a['kind']]
                    args = (c, H, hexc(a['color']), hexc(a['color2']) if a.get('color2') else None)
                    # a kit accessory may take the roster entry too, for its own
                    # settings: as a parameter named `a` (positional or keyword-only)
                    fn(*args, a=a) if 'a' in inspect.signature(fn).parameters else fn(*args)
                else:
                    kit.accessory(c, H, a['kind'], a['color'], a.get('color2'))
        if entry.get('gait'):
            c.gait_hint = entry['gait']  # the sheet's gait wins over one a body plan set
        eye_contrast(c)
        return c

    return build


class _glowing:
    """With glow on, every voxel the block adds or repaints glows."""

    def __init__(self, c, on):
        self.c, self.on = c, bool(on)

    def __enter__(self):
        if self.on:
            self.before = {id(p): dict(p.v) for p in self.c.parts}

    def __exit__(self, *exc):
        if self.on and exc[0] is None:
            for p in self.c.parts:
                old = self.before.get(id(p), {})
                for q, (col, g) in p.v.items():
                    if old.get(q) != (col, g):
                        p.v[q] = (col, True)
                if id(p) not in self.before and p.anim == 'static':
                    p.anim = 'glow'  # a new part that glows pulses
        return False


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
