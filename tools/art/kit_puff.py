"""The `puff` body plan: small round invented critters (a pebble, a seed, a
puddle, a gumball...) that hop about on two stubby feet. Used by roster
entries like the plans in kit.py (see variants.py):

    {"id": "Pebblet", "rarity": "Common", "plan": "puff",
     "colors": {"col": "#9A9AA6", "accent": "#7C7C88", "tuft": "#6CBF4F"},
     "options": {"kind": "pebble"}}

Colours: col (the body), accent (markings: speckles, scales, a cap's
pattern, a puddle's rim), belly, tuft (moss, leaves, a cap), feet.
Options: kind, big_eyes (true for bigger eyes).

Every kind is one ball-shaped body with a face, so a new kind is a few lines.
Kinds live in KINDS; another kit module adds its own with `add_kind`, and
the plan accepts it straight away (the allowed set is shared, not copied):

    import kit_puff
    def cloud(c, H, k, body, head, cols, opts): ...
    kit_puff.add_kind('cloud', cloud, gait='hover')

A kind function draws into `body` and `head` (already made) and may return a
dict of changes to the defaults below (radius, feet...).

Same art frame as kit.py (x right, y back, front is -y, z up) and scale
(k = H / 10). Feet are drawn straight into leg parts (rig.leg_part), so the
game swings them as it hops."""
import math

from voxkit import hexc

INK, WHITE = hexc('#1B1B2F'), hexc('#FFFFFF')

KINDS = {}  # kind -> fn(c, H, k, body, head, cols, opts)
KIND_SET = set()  # the plan's allowed kinds (shared with PLANS, so add_kind shows up)
GAITS = {}  # kind -> the gait a roster entry of this kind should name


def add_kind(name, fn, gait='hop'):
    """Registers a puff kind: fn(c, H, k, body, head, cols, opts)."""
    if name in KINDS:
        raise ValueError(f'puff kind "{name}" is already registered')
    KINDS[name] = fn
    KIND_SET.add(name)
    GAITS[name] = gait


PLANS = {
    'puff': ({'col', 'accent', 'belly', 'tuft', 'feet'}, {'kind': KIND_SET, 'big_eyes': {True, False}}),
}


def gait(opts):
    """The default gait of a puff with these options."""
    return GAITS.get(opts.get('kind'), 'hop')


# ---------------------------------------------------------------- helpers

def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def dark(col, t=0.3):
    return mix(col, INK, t)


def light(col, t=0.35):
    return mix(col, WHITE, t)


def _hash(*v):
    h = 2166136261
    for x in v:
        h = ((h ^ (int(x) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    return h


def ball_body(c, k, centre, r, col):
    """The puff's ball, split in two parts the game knows: the back and
    bottom are `body`, the front upper half is `head` (where the face goes).
    Both share the colour, so it reads as one ball."""
    body = c.part('body')
    head = c.part('head', 'static', (0, centre[1] - 0.3 * r[1], centre[2]))
    body.ell(centre, r, col)
    head.ell(centre, r, col, cond=lambda x, y, z: y + .5 < centre[1] - 0.15 * r[1] and z + .5 > centre[2] - 0.45 * r[2])
    for p in head.v:
        body.v.pop(p, None)
    return body, head


def feet(c, k, col, height, x=1.2, y=-0.2, w=0.75, toe=0.5):
    """Two stubby feet, each its own leg part hinged at the hip, so they step
    as the puff hops. The right foot is the exact mirror of the left (cells
    x -> -x-1, hip x negated), and each is at least three voxels tall.
    `height` in voxels; x, y, w, toe in k."""
    hw = max(1, round(w * k))
    height = max(3, height)
    x0 = math.floor(-x * k - hw / 2)
    x1 = x0 + hw - 1
    y0 = round(y * k - hw / 2)
    t = max(1, round(toe * k))
    out = []
    for sx in (-1, 1):
        a, b = (x0, x1) if sx < 0 else (-x1 - 1, -x0 - 1)
        leg = _leg(c, sx, (a + b + 1) / 2, y0 + hw / 2, height)
        leg.box((a, y0, 0), (b, y0 + hw - 1, height - 1), col)
        # a rounded toe reaching forward
        leg.box((a, y0 - t, 0), (b, y0 - 1, max(0, round(0.35 * k) - 1)), col)
        out.append(leg)
    return out


def _leg(c, sx, hx, hy, top):
    import rig
    return rig.leg_part(c, 'L' if sx < 0 else 'R', 0, 1, (hx, hy, top))


def face(c, head, k, z, x_off=0.9, size=0.6, smile=True, cheeks=True):
    """Blinking eyes, cheeks and (on the finer build) a little smile."""
    from creatures import eyes, blush
    eyes(c, head, max(1, round(x_off * k)), round(z * k), max(1, round(size * k)))
    if cheeks and k >= 1:
        blush(head, round((x_off + 0.9) * k), round((z - 0.7) * k))
    if smile and getattr(c, 'fine', False):
        # a small mouth, two voxels wide, a little below and between the eyes
        zm = round((z - 1.2) * k)
        for x in (-1, 0):
            f = head.front(x, zm)
            if f:
                head.put(f, INK)


def shine(part, centre, r, k, col=WHITE):
    """A glossy highlight: a small light square on the upper front left."""
    n = max(2, round(0.6 * k))
    x0 = math.floor(centre[0] - 0.45 * r[0])
    z0 = math.floor(centre[2] + 0.35 * r[2])
    for x in range(x0, x0 + n):
        for z in range(z0, z0 + n):
            if (x - x0, z - z0) == (n - 1, 0):
                continue  # a rounded corner
            f = part.front(x, z)
            if f:
                part.v[f] = (col, False)


# ------------------------------------------------------------------- kinds

def _pebble(c, H, k, body, head, cols, opts):
    """A grey stone with darker speckles and a tuft of moss on top."""
    acc = cols.get('accent') or dark(cols['col'], 0.2)
    for part in (body, head):
        part.paint(lambda p, cc, g: (acc, False) if _hash(p[0] // 2, p[1] // 2, p[2] // 2, 3) % 100 < 18 else None)
    moss = c.part('moss', 'static')
    tuft = cols.get('tuft') or hexc('#6CBF4F')
    solid = set(body.v) | set(head.v)
    top = max(p[2] for p in solid)
    cy = 0.5 * k
    # a cushion of moss draped over the top, then a few blades sticking up
    for (x, y, z) in solid:
        if z >= top - round(0.6 * k) and (x + .5 - 0.3 * k) ** 2 / (1.9 * k) ** 2 + (y + .5 - cy) ** 2 / (1.6 * k) ** 2 <= 1:
            moss.put((x, y, z + 1), tuft)
    for i, (dx, dy) in enumerate(((-0.7, 0.1), (0.9, -0.2), (0.2, 0.9), (0.4, -0.6))):
        for j in range(max(1, round((0.7 + 0.2 * (i % 2)) * k))):
            moss.put((round(dx * k), round(cy + dy * k), top + 2 + j), light(tuft, 0.2))


def _seed(c, H, k, body, head, cols, opts):
    """A seed: the ball drawn taller and drawn to a soft point on top."""
    col = cols['col']
    acc = cols.get('accent') or dark(col, 0.18)
    top = max(p[2] for p in list(body.v) + list(head.v))
    zc = top - 2.0 * k
    tip = c.part('tip', 'static')
    tip.ell((0, 0.2 * k, zc + 1.2 * k), (1.6 * k, 1.6 * k, 1.6 * k), col)
    for p in list(tip.v):
        if p in body.v or p in head.v:
            del tip.v[p]
    # a darker seam from top to bottom down the back
    body.paint(lambda p, cc, g: (acc, False) if abs(p[0] + .5) < 0.35 * k and p[1] > 0.6 * k else None)
    # a two-leaf sprout on top: a short stem, a leaf out to each side
    leaf = cols.get('tuft') or hexc('#4FB848')
    sp = c.part('sprout', 'static')
    ztop = max(p[2] for p in tip.v) if tip.v else top
    stem = max(2, round(1.0 * k))
    for i in range(stem):
        sp.put((0, round(0.2 * k), ztop + 1 + i), dark(leaf, 0.2))
        sp.put((-1, round(0.2 * k), ztop + 1 + i), dark(leaf, 0.2))
    zl = ztop + stem + 0.3 * k
    for sx in (-1, 1):
        # a round leaf tipped up and out
        cx, cz = sx * 1.2 * k, zl + 0.5 * k
        sp.ell((cx, 0.2 * k + .5, cz), (1.2 * k, 0.8 * k, 0.75 * k), leaf,
               cond=lambda x, y, z, cx=cx, cz=cz, sx=sx: abs((z + .5 - cz) - 0.45 * sx * (x + .5 - cx)) < 0.75 * k)
    sp.paint(lambda p, cc, g: (light(leaf, 0.25), False) if p[2] >= zl + 0.9 * k else None)


def _puddle(c, H, k, body, head, cols, opts):
    """A wide flat water blob: a lighter top, a darker rim, a shine."""
    col = cols['col']
    acc = cols.get('accent') or dark(col, 0.25)
    zs = [p[2] for p in list(body.v) + list(head.v)]
    lo, hi = min(zs), max(zs)
    for part in (body, head):
        part.paint(lambda p, cc, g: (light(col, 0.3), False) if p[2] >= hi - round(0.5 * k) else None)
        part.paint(lambda p, cc, g: (acc, False) if p[2] <= lo + round(0.4 * k) else None)
    return {'shine': True}


def _tadpole(c, H, k, body, head, cols, opts):
    """A tadpole: the round ball is all head; a long tail ripples behind."""
    col = cols['col']
    tail = c.part('tail', 'tail', (0, 2.0 * k, 2.0 * k))
    fin = cols.get('accent') or light(col, 0.3)
    # a flat tail fin two voxels thick, tall at the root and tapering to a
    # point, with a gentle S along its length and a paler rim
    y0 = round(1.8 * k)
    n = max(6, round(5.5 * k))
    zc0 = 2.0 * k
    for i in range(n):
        t = i / (n - 1)
        half = max(0.5, (1.5 * (1 - t) ** 0.8) * k)
        zc = zc0 + 0.35 * k * math.sin(t * math.pi * 1.4)
        lo, hi = math.floor(zc - half), math.ceil(zc + half) - 1
        for z in range(max(0, lo), hi + 1):
            rim = z in (max(0, lo), hi) and hi - lo >= 2
            for x in (-1, 0):
                tail.put((x, y0 + i, z), fin if rim else col)
    for p in list(tail.v):
        if p in body.v or p in head.v:
            del tail.v[p]
    belly = cols.get('belly') or light(col, 0.25)
    body.paint(lambda p, cc, g: (belly, False) if p[2] < 1.4 * k else None)
    head.paint(lambda p, cc, g: (belly, False) if p[2] < 1.4 * k else None)
    return {'big_eyes': True}


def _fuzz(c, H, k, body, head, cols, opts):
    """A fuzzball: tufts of fur stand out all over the ball."""
    col = cols['col']
    tone = cols.get('accent') or light(col, 0.15)
    fur = c.part('fur', 'static')
    for part in (body, head):
        vs = set(part.v)
        for p in list(part.v):
            x, y, z = p
            if z < 1.4 * k:
                continue
            h = _hash(x, y, z, 11)
            if h % 100 >= 22:
                continue
            for n in ((x + 1, y, z), (x - 1, y, z), (x, y + 1, z), (x, y - 1, z), (x, y, z + 1)):
                if n not in vs and not (part is head and n[1] < y):
                    fur.put(n, tone if h % 3 == 0 else col)
                    break
    for p in list(fur.v):
        if p in body.v or p in head.v:
            del fur.v[p]
    return {'big_eyes': True}


def _gum(c, H, k, body, head, cols, opts):
    """A shiny gumball."""
    return {'shine': True}


def _mushroom(c, H, k, body, head, cols, opts):
    """A mushroom: a pale stalk body under a wide spotted cap."""
    cap_col = cols.get('tuft') or hexc('#E8453C')
    spot = cols.get('accent') or WHITE
    top = max(p[2] for p in list(body.v) + list(head.v))
    cap = c.part('cap', 'static')
    cz = top - 0.2 * k
    # a dome sitting on the stalk's top, wider than it
    cap.ell((0, 0.2 * k, cz), (3.8 * k, 3.4 * k, 2.4 * k), cap_col, cond=lambda x, y, z: z + .5 >= cz - 0.4 * k)
    for p in list(cap.v):
        if p in head.v:
            del head.v[p]
        body.v.pop(p, None)
    # round white spots: cells of the cap's surface picked by a hash, each
    # painted as a dot about the cell's centre
    g = max(3, round(1.5 * k))

    def dot(p, cc, gl):
        cell = (p[0] // g, p[1] // g, p[2] // g)
        if _hash(*cell, 5) % 100 >= 45:
            return None
        centre = tuple(cell[i] * g + g / 2 for i in range(3))
        return (spot, False) if math.dist((p[0] + .5, p[1] + .5, p[2] + .5), centre) < g * 0.42 else None
    cap.paint(dot)
    # the cap's rim is a shade darker underneath
    lo = min(p[2] for p in cap.v)
    cap.paint(lambda p, cc, g: (dark(cap_col, 0.2), False) if p[2] == lo else None)
    return {'face_z': -0.05}


def _acorn(c, H, k, body, head, cols, opts):
    """An acorn: a smooth nut with a textured cap and a stalk on top."""
    cap_col = cols.get('tuft') or hexc('#8A5A33')
    top = max(p[2] for p in list(body.v) + list(head.v))
    cap = c.part('cap', 'static')
    bottom = min(p[2] for p in list(body.v) + list(head.v))
    # the brim covers the top third, above the eyes; the small in-game build
    # has too few voxels for that, so its cap sits on top
    brim = top - 0.3 * (top - bottom) if getattr(c, 'fine', False) else top + 0.5
    cz = brim + 1.2 * k
    cap.ell((0, 0.3 * k, cz), (3.6 * k, 3.4 * k, 1.9 * k), cap_col, cond=lambda x, y, z: z + .5 >= brim)
    for p in list(cap.v):
        head.v.pop(p, None)
        body.v.pop(p, None)
    cap.paint(lambda p, cc, g: (dark(cap_col, 0.25), False) if (p[0] + p[1] + p[2]) % 3 == 0 else None)
    cz2 = max(p[2] for p in cap.v)
    for i in range(max(2, round(1.0 * k))):
        cap.put((0, round(0.3 * k), cz2 + 1 + i), dark(cap_col, 0.35))
        cap.put((-1, round(0.3 * k), cz2 + 1 + i), dark(cap_col, 0.35))
    return {'face_z': 0.05}


def _cone(c, H, k, body, head, cols, opts):
    """A pinecone: overlapping scales in rows, a tuft of needles on top."""
    col = cols['col']
    acc = cols.get('accent') or dark(col, 0.3)
    band = max(1, round(0.7 * k))
    for part in (body, head):
        part.paint(lambda p, cc, g: (acc, False) if ((p[2] // band) + (p[0] // band)) % 2 == 0 and part is body else None)
    tuft = cols.get('tuft') or hexc('#4FA84A')
    top = max(p[2] for p in list(body.v) + list(head.v))
    tp = c.part('tuft', 'static')
    for i, (dx, dy) in enumerate(((0, 0), (-0.7, 0.2), (0.7, 0.2), (0, 0.8))):
        for j in range(max(2, round((1.4 - 0.2 * i) * k))):
            tp.put((round(dx * k) + (j // 3) * (1 if dx > 0 else -1 if dx < 0 else 0), round((0.4 + dy) * k), top + 1 + j), tuft)
    return {'feet_w': 0.45, 'feet_h': 1.2}


def _pip(c, H, k, body, head, cols, opts):
    """A round fluffball bird: a ball with a short beak and bird feet, no
    wings to be seen."""
    return {'beak': cols.get('accent') or hexc('#FF9418'), 'big_eyes': True, 'no_mouth': True}


def _ball(c, H, k, body, head, cols, opts):
    """A plain ball (the default)."""
    return None


for _name, _fn, _gait in (
        ('ball', _ball, 'hop'), ('pebble', _pebble, 'hop'), ('seed', _seed, 'hop'), ('puddle', _puddle, 'hop'),
        ('tadpole', _tadpole, 'slither'), ('fuzz', _fuzz, 'hop'), ('gum', _gum, 'hop'),
        ('mushroom', _mushroom, 'hop'), ('acorn', _acorn, 'hop'), ('cone', _cone, 'hop'), ('pip', _pip, 'waddle')):
    add_kind(_name, _fn, _gait)

# Ball proportions per kind (in k): radius (x, y, z) and how high the
# ball's centre sits above its feet.
SHAPES = {
    'ball': (3.0, 2.8, 2.8),
    'pebble': (3.2, 2.9, 2.4),
    'seed': (2.6, 2.5, 3.2),
    'puddle': (3.8, 3.4, 1.9),
    'tadpole': (2.6, 2.6, 2.4),
    'fuzz': (3.0, 2.9, 2.9),
    'gum': (3.0, 3.0, 3.0),
    'mushroom': (2.1, 2.0, 2.7),
    'acorn': (2.6, 2.5, 2.9),
    'cone': (2.4, 2.4, 3.3),
    'pip': (3.0, 3.0, 3.0),
}


def puff(c, H, kind, cols, opts):
    k = H / 10.0
    col = cols['col']
    rx, ry, rz = SHAPES.get(kind, SHAPES['ball'])
    legged = kind != 'tadpole'
    # feet keep at least three voxels of their own below the ball (the
    # voxel they sink into goes to the body when parts are merged)
    fh = max(3, round(0.9 * k)) if legged else 0
    # the ball sits on its feet, sinking into them a little
    cz = fh + rz * k - (0.35 * k if legged else 0.1 * k)
    centre = (0, 0, cz)
    r = (rx * k, ry * k, rz * k)
    body, head = ball_body(c, k, centre, r, col)
    if cols.get('belly'):
        bel = cols['belly']
        head.paint(lambda p, cc, g: (bel, False) if p[2] < cz - 0.2 * r[2] else None)
    extra = KINDS[kind](c, H, k, body, head, cols, opts) or {}
    if extra.get('shine'):
        shine(head, centre, r, k)
    big = opts.get('big_eyes', False) or extra.get('big_eyes', False)
    fz = cz / k + extra.get('face_z', 0.15) * rz
    face(c, head, k, fz, x_off=0.9 if not big else 1.0, size=0.6 if not big else 0.85, smile=not extra.get('no_mouth'))
    if extra.get('beak'):
        # a short beak, two voxels wide, just proud of the face below the eyes
        zb = round((fz - 1.0) * k)
        for x in (-1, 0):
            for z in (zb - 1, zb):
                f = head.front(x, z)
                if f:
                    head.put((f[0], f[1] - 1, f[2]), extra['beak'])
                    if z == zb:
                        head.put((f[0], f[1] - 2, f[2]), extra['beak'])
    if legged:
        feet(c, k, cols.get('feet') or dark(col, 0.25), fh + max(1, round(0.35 * k)),
             x=min(1.4, rx * 0.45), w=extra.get('feet_w', 0.8), toe=0.5)
    return c


BUILDERS = {
    'puff': lambda c, H, cols, opts: puff(c, H, opts.get('kind', 'ball'), cols, opts),
}


if __name__ == '__main__':
    # Self-check: every kind builds at the in-game size and the finer
    # Blender size, with eyes, and (all but the tadpole) two feet.
    import sys
    from voxkit import Creature
    bad = []
    for kind in sorted(KINDS):
        for H, fine in ((8, False), (20, True)):
            c = Creature('Test', 'Common')
            c.fine = fine
            puff(c, H, kind, {'col': hexc('#A3A3AE')}, {'kind': kind})
            names = {p.name for p in c.parts if p.v}
            want = {'body', 'head', 'eyes'} | (set() if kind == 'tadpole' else {'legL', 'legR'})
            if want - names:
                bad.append(f'{kind} at H={H}: missing {sorted(want - names)}')
            legs = {p.name: p for p in c.parts if p.name in ('legL', 'legR')}
            if len(legs) == 2:
                L, R = legs['legL'], legs['legR']
                if {(-x - 1, y, z) for (x, y, z) in L.v} != set(R.v):
                    bad.append(f'{kind} at H={H}: legR is not the mirror of legL')
                if abs(L.pivot[0] + R.pivot[0]) > 1e-6:
                    bad.append(f'{kind} at H={H}: leg hips not mirrored')
                # count only the leg's own voxels: ones shared with another
                # part go to that part when the build merges them
                others = set().union(*(p.v for p in c.parts if p.name not in legs))
                own = [z for v in (L.v, R.v) for (x, y, z) in v if (x, y, z) not in others]
                if not own or max(own) - min(own) + 1 < 3:
                    bad.append(f'{kind} at H={H}: legs keep under three voxels of their own')
    print('\n'.join(bad) or f'puff: {len(KINDS)} kinds OK')
    sys.exit(1 if bad else 0)
