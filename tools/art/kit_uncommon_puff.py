"""Puff kinds for the Uncommon batch (master creature sheet, Nov 5), added to
the `puff` plan of kit_puff.py with its add_kind:

- dandelion: a white seed clock with seeds standing out all over (hop).
- cloud: a lumpy little cloud, paler on top, grey underneath (hover; use
  the `drizzle` accessory for rain in place of feet).
- tardigrade: a plump segmented water bear on eight stubby legs (scuttle;
  use `nofeet` so only its own eight legs stay).
- bobble: a small body with a big round head on a coiled spring (hop).
- turnip, carrot, radish, corn: vegetables with faces; tuft colours their
  leaves (corn: its husks), accent their second colour.
- peapod: a green pod with three peas looking out (hop).

A brown fluffball with a squirrel tail is kind fuzz with a tailset
accessory (kit_uncommon.py), so it needs no kind of its own.

Accessories:
- **nofeet**: takes away the puff's two stubby feet (legL / legR).
- **furtrim**: thins the fur tufts on the back half (under a big tail).
- **drizzle**: no feet; a few short streaks of rain under the creature in
  color (it floats)."""
import math

import kit_puff as P
import rig
from voxkit import hexc

INK, WHITE = P.INK, P.WHITE
dark, light, _hash = P.dark, P.light, P._hash


def _all(body, head):
    return list(body.v) + list(head.v)


def _paint_both(body, head, fn):
    body.paint(fn)
    head.paint(fn)


def _dandelion(c, H, k, body, head, cols, opts):
    """A seed clock: a white ball, every few voxels a seed on a short stalk
    standing out from it, paler tips."""
    col = cols['col']
    seeds = c.part('seeds', 'static')
    stalk = cols.get('accent') or hexc('#D8DCCF')
    solid = set(_all(body, head))
    zs = [p[2] for p in solid]
    cz = (min(zs) + max(zs) + 1) / 2
    for (x, y, z) in solid:
        # the right half only, mirrored after: both eyes get the same frame
        if x < 0 or z < cz - 0.6 * k or _hash(x, y, z, 7) % 100 >= 16:
            continue
        d = (x + .5, y + .5, z + .5 - cz)
        n = math.sqrt(sum(a * a for a in d)) or 1
        u = tuple(a / n for a in d)
        if u[1] < -0.2 and u[2] < 0.8:
            continue  # keep the whole face clear: seeds only over the top
        out = [(math.floor(x + .5 + u[0] * s), math.floor(y + .5 + u[1] * s), math.floor(z + .5 + u[2] * s))
               for s in (1.0, 2.0)]
        if any(q in solid for q in out):
            continue
        seeds.put(out[0], stalk)
        seeds.put(out[1], light(col, 0.4) if col != WHITE else hexc('#F4F6F8'))
    for (x, y, z), v in list(seeds.v.items()):
        seeds.v[(-x - 1, y, z)] = v
    for q in [q for q in seeds.v if q in solid]:
        del seeds.v[q]
    return {'big_eyes': True, 'face_z': -0.02}


def _cloud(c, H, k, body, head, cols, opts):
    """A cloud: three puffs on top of the ball, the underside a soft grey."""
    col = cols['col']
    under = cols.get('accent') or hexc('#C9D3E3')
    zs = [p[2] for p in _all(body, head)]
    top, lo = max(zs), min(zs)
    for (dx, dy, r) in ((-1.4, 0.4, 1.5), (1.2, 0.6, 1.3), (0.0, 1.3, 1.6)):
        body.ell((dx * k, dy * k, top - 0.5 * k), (r * k, r * k, r * k * 0.9), col)
    for p in list(body.v):
        if p in head.v:
            del body.v[p]
    _paint_both(body, head, lambda p, cc, g: (under, False) if p[2] <= lo + round(0.6 * k) else None)
    return {'face_z': -0.05}


def _tardigrade(c, H, k, body, head, cols, opts):
    """A water bear: a plump capsule in four soft segment bands, a round tube
    snout at the front with small eyes beside it, and four pairs of stubby
    clawed legs (leg1..leg4, mirrored, each 3+ voxels, so it scuttles)."""
    col = cols['col']
    ring = cols.get('accent') or dark(col, 0.12)
    vox = _all(body, head)
    ys = [p[1] for p in vox]
    y0, y1 = min(ys), max(ys)
    # four segment bands: a darker ring at each of four even steps along it
    seg = (y1 - y0 + 1) / 5
    marks = {round(y0 + seg * i) for i in range(1, 5)}
    _paint_both(body, head, lambda p, cc, g: (ring, False) if p[1] in marks else None)
    # a round tube snout pointing forward, tapering a little, its tip a pale
    # lip ring round a small dark mouth (a ring, not a dog's nose)
    zs = [p[2] for p in vox]
    zc = (min(zs) + max(zs)) / 2 - 0.3 * k
    n = max(2, round(0.85 * k))  # half the tube's width, in voxels
    z0 = round(zc)
    front = min(p[1] for p in vox if abs(p[0] + .5) < 1.5 and abs(p[2] - z0) < 1.5)
    ln = max(3, round(1.0 * k))
    tube = light(col, 0.08)
    lip = light(col, 0.3)
    for y in range(front - ln, front + 1):
        for x in range(-n, n):
            for z in range(z0 - n, z0 + n):
                if x in (-n, n - 1) and z in (z0 - n, z0 + n - 1):
                    continue  # rounded corners
                cc = tube
                if y == front - ln:
                    cc = dark(col, 0.8) if x in (-1, 0) and z in (z0 - 1, z0) else lip
                head.put((x, y, z), cc)
    lo = min(zs)
    rx = max(abs(p[0] + .5) for p in body.v)
    claw = cols.get('feet') or dark(col, 0.35)
    hgt = max(3, round(1.0 * k))
    w = max(2, round(0.6 * k))
    x1 = round(rx * 0.75 + w / 2) - 1  # the right leg's outer column
    x0 = x1 - w + 1
    for i, fy in enumerate((-0.42, -0.14, 0.14, 0.42)):
        y = round(fy * (y1 - y0) + (y1 + y0) / 2)
        for side, sx in (('L', -1), ('R', 1)):
            a, b = (x0, x1) if sx > 0 else (-x1 - 1, -x0 - 1)
            leg = rig.leg_part(c, side, i, 4, ((a + b + 1) / 2 * 1.0, y + w / 2, lo + hgt))
            leg.box((a, y, 0), (b, y + w - 1, lo + hgt), col)
            if getattr(c, 'fine', False):  # claws: the Blender build only (box budget)
                leg.put((a, y - 1, 0), claw)
                leg.put((b, y - 1, 0), claw)
    return {'big_eyes': False, 'face_z': 0.32, 'no_mouth': True}


def _bobble(c, H, k, body, head, cols, opts):
    """A small round body; on top, a coiled spring and a big round head
    (where the face goes)."""
    col = cols['col']
    spring = cols.get('accent') or hexc('#C0C6D0')
    zs = [p[2] for p in _all(body, head)]
    top = max(zs)
    # the ball is all body; the head is a new, bigger ball up on the spring
    for p in list(head.v):
        body.v[p] = head.v[p]
    head.v = {}
    coil = max(3, round(1.6 * k))
    R = 0.7 * k + 0.4
    for i in range(coil * 8):
        t = i / 8
        th = t * 2 * math.pi
        head_z = top + 1 + t * (1.0 if k < 1.5 else 1.0) * 0.9
        body.put((math.floor(R * math.cos(th)), math.floor(0.2 * k + R * math.sin(th)), math.floor(head_z)), spring)
    hr = 2.6 * k
    hz = top + 1 + coil * 0.9 + hr * 0.85
    head.ell((0, 0, hz), (hr, hr * 0.95, hr * 0.9), col)
    for p in list(body.v):
        if p in head.v:
            del body.v[p]
    head.pivot = (0, 0, top + 1)
    cz = min(p[2] for p in body.v) + (top - min(p[2] for p in body.v)) / 2
    return {'face_z': (hz - cz) / (P.SHAPES['bobble'][2] * k) + 0.05, 'big_eyes': True}


def _leaves(c, k, top, cy, col, n=3, h=1.6, part_name='leaves'):
    """A tuft of leaves straight up from the top, fanned out."""
    lp = c.part(part_name, 'static')
    for i in range(n):
        a = (i - (n - 1) / 2) * 0.55
        L = max(2, round((h - 0.25 * abs(i - (n - 1) / 2)) * k))
        for j in range(L):
            x = round(math.sin(a) * j * 0.8)
            z = top + 1 + round(math.cos(a) * j)
            w = 2 if (k >= 1.5 and 0 < j < L - 1) else 1
            for dx in range(w):
                lp.put((x + dx - (1 if w == 2 else 0) + (0 if x else 0), round(cy), z), col if j % 3 else light(col, 0.15))
    return lp


def _turnip(c, H, k, body, head, cols, opts):
    """A turnip: purple shoulders over a white body, a little root below the
    feet line, and leaf hair."""
    col = cols['col']
    top_col = cols.get('accent') or hexc('#8E4FC2')
    zs = [p[2] for p in _all(body, head)]
    lo, top = min(zs), max(zs)
    _paint_both(body, head, lambda p, cc, g: (top_col, False) if p[2] >= lo + (top - lo) * 0.62 else None)
    _leaves(c, k, top, 0.2 * k, cols.get('tuft') or hexc('#4FB848'), n=3, h=1.9)
    return {'face_z': -0.15}


def _taper(body, head, k, lo, zc, rmax, frac=0.35, power=1.0):
    """Draws the bottom half of the ball in to a point (a carrot, a radish
    root): below zc, the further down the narrower (power < 1 keeps it full
    longer and pinches it in sharply at the very bottom)."""
    for part in (body, head):
        for p in list(part.v):
            if p[2] + .5 < zc:
                t = max(0.0, (p[2] + .5 - lo) / max(1, zc - lo)) ** power
                if math.hypot(p[0] + .5, p[1] + .5) > rmax * (frac + (1 - frac) * t):
                    del part.v[p]


def _carrot(c, H, k, body, head, cols, opts):
    """A carrot: drawn in to a point at the bottom, little ridges round it,
    a leafy green top."""
    col = cols['col']
    ridge = cols.get('accent') or dark(col, 0.15)
    zs = [p[2] for p in _all(body, head)]
    lo, top = min(zs), max(zs)
    zc = (lo + top) / 2 + 1.0 * k
    _taper(body, head, k, lo, zc, P.SHAPES['carrot'][0] * k, 0.08, 0.9)
    _paint_both(body, head, lambda p, cc, g: (ridge, False) if (p[2] % max(2, round(1.1 * k)) == 0 and
                                                               _hash(p[0] // 2, p[2], 3) % 3 == 0) else None)
    _leaves(c, k, top, 0.0, cols.get('tuft') or hexc('#4FB848'), n=4, h=2.0)
    return {'face_z': 0.25, 'feet_w': 0.6, 'big_eyes': True}


def _radish(c, H, k, body, head, cols, opts):
    """A radish: red, a white bottom, a thin white root tail curling out
    behind, short leaves on top."""
    col = cols['col']
    white = cols.get('accent') or hexc('#FFF4F4')
    zs = [p[2] for p in _all(body, head)]
    lo, top = min(zs), max(zs)
    _paint_both(body, head, lambda p, cc, g: (white, False) if p[2] <= lo + (top - lo) * 0.28 else None)
    root = c.part('tail', 'tail', (0, 1.6 * k, lo + 1.2 * k))
    ys = [p[1] for p in _all(body, head)]
    yb = max(ys)
    pts = [(0, yb - 0.6 * k, lo + 1.2 * k), (0, yb + 0.8 * k, lo + 0.8 * k), (0, yb + 1.8 * k, lo + 1.4 * k),
           (0, yb + 2.4 * k, lo + 2.4 * k)]
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        n = max(2, math.ceil(math.dist(a, b) * 1.5))
        for j in range(n + 1):
            q = tuple(a[m] + (b[m] - a[m]) * j / n for m in range(3))
            r = max(0.5, (0.55 - 0.15 * i) * k)
            root.ell(q, (r, r, r), white)
    for p in list(root.v):
        if p in body.v or p in head.v:
            del root.v[p]
    _leaves(c, k, top, 0.3 * k, cols.get('tuft') or hexc('#4FB848'), n=3, h=1.3)
    return {'face_z': 0.1}


def _corn(c, H, k, body, head, cols, opts):
    """A corn cob: rows of kernels, green husks curling out like arms and up
    round the top."""
    col = cols['col']
    kern = cols.get('accent') or dark(col, 0.12)
    _paint_both(body, head, lambda p, cc, g: (kern, False) if (p[2] + (p[0] + p[1]) // 2) % 2 == 0 else None)
    husk = c.part('husk', 'static')
    hc = cols.get('tuft') or hexc('#6DBE45')
    zs = [p[2] for p in _all(body, head)]
    lo, top = min(zs), max(zs)
    rx = max(abs(p[0] + .5) for p in _all(body, head))
    # an arm-like husk each side, out and up from the middle
    for sx in (1,):
        zb = lo + (top - lo) * 0.35
        for j in range(max(4, round(2.6 * k))):
            t = j / max(1, round(2.6 * k))
            x = rx - 0.5 + t * 1.6 * k
            z = zb + t * 1.6 * k + 1.0 * k * t * t
            w = max(1, round((0.9 - 0.5 * t) * k))
            for dz in range(w):
                for dy in (0, 1):
                    husk.put((math.floor(x), round(0.4 * k) + dy, math.floor(z) + dz), hc if dz else dark(hc, 0.15))
    # husk leaves hugging the top
    for i, (dx, dy) in enumerate(((-0.9, 0.4), (0.9, 0.4), (0, 1.1))):
        for j in range(max(2, round(1.4 * k))):
            husk.put((round(dx * k * (1 - j * 0.12)), round(dy * k), top - round(0.4 * k) + j), hc)
    right = {p: v for p, v in husk.v.items() if p[0] >= 0}
    for (x, y, z), v in right.items():
        husk.v[(-x - 1, y, z)] = v
    for p in list(husk.v):
        if p in body.v or p in head.v:
            del husk.v[p]
    return {'face_z': 0.1, 'feet_w': 0.6}


def _peapod(c, H, k, body, head, cols, opts):
    """A pea pod lying long side to side, split along the front, three round
    peas looking out (the middle one gets the face; the side ones their own
    little eyes)."""
    col = cols['col']
    pea = cols.get('accent') or light(col, 0.25)
    ys = [p[1] for p in _all(body, head)]
    zs = [p[2] for p in _all(body, head)]
    yf = min(ys)
    zc = (min(zs) + max(zs) + 1) / 2
    # a darker seam round the pod's front opening
    seam = dark(col, 0.2)
    _paint_both(body, head, lambda p, cc, g: (seam, False) if p[1] <= yf + 1 and abs(p[2] + .5 - zc) > 0.9 * k else None)
    pr = 1.05 * k + 0.2
    for sx in (-1, 0, 1):
        cen = (sx * 2.3 * k, yf + 0.5 * k, zc)
        head.ell(cen, (pr, pr, pr), pea)
    for sx in (-1, 1):
        ex = sx * 2.3 * k
        for dx in (-0.45 * k, 0.45 * k):
            x = math.floor(ex + dx)
            z = round(zc + 0.2 * k)
            f = head.front(x, z)
            if f:
                head.put(f, INK)
    # a curly stem on top
    top = max(zs)
    st = c.part('stem', 'static')
    for j in range(max(2, round(1.0 * k))):
        st.put((round(3.0 * k) - j // 2, round(0.4 * k), top + 1 + j), dark(col, 0.25))
    return {'face_z': 0.12, 'big_eyes': False}


SHAPES = {
    'dandelion': (2.5, 2.5, 2.5),
    'cloud': (3.3, 2.6, 2.0),
    'tardigrade': (2.3, 3.4, 2.1),
    'bobble': (1.7, 1.7, 1.5),
    'turnip': (2.8, 2.7, 2.6),
    'carrot': (2.1, 2.1, 3.4),
    'radish': (2.6, 2.6, 2.5),
    'corn': (2.0, 2.0, 3.3),
    'peapod': (3.9, 1.7, 1.7),
}
P.SHAPES.update(SHAPES)
for _name, _fn, _gait in (('dandelion', _dandelion, 'hop'), ('cloud', _cloud, 'hover'),
                          ('tardigrade', _tardigrade, 'scuttle'), ('bobble', _bobble, 'hop'),
                          ('turnip', _turnip, 'hop'), ('carrot', _carrot, 'hop'), ('radish', _radish, 'hop'),
                          ('corn', _corn, 'hop'), ('peapod', _peapod, 'hop')):
    if _name not in P.KINDS:
        P.add_kind(_name, _fn, _gait)


def nofeet(c, H, col, col2, a):
    for p in c.parts:
        if p.name in ('legL', 'legR'):
            p.v = {}
    c.parts = [p for p in c.parts if p.v]


def drizzle(c, H, col, col2, a):
    """No feet: rain under the creature, six single droplets (one voxel
    wide, two tall: a pale top, color below) scattered under it at staggered
    heights with clear gaps, the highest a voxel or two below the cloud, so
    they read as falling rain, not legs. The rain is an "orbit" part: it turns
    slowly about the cloud's middle."""
    k = H / 10.0
    nofeet(c, H, col, col2, a)
    vox = [p for q in c.parts for p in q.v]
    lo = min(p[2] for p in vox)
    ym = (min(p[1] for p in vox) + max(p[1] for p in vox)) / 2
    rain = c.part('rain', 'orbit', (0, ym, lo))
    c1, c2 = col or hexc('#7FB8F0'), col2 or hexc('#D6EBFB')
    step = max(1, round(0.5 * k))
    spots = ((-2.4, -0.5, 0), (-1.1, 0.9, 3), (0.2, -1.0, 1), (1.4, 0.7, 4), (-0.5, 2.0, 2), (2.5, -0.3, 5))
    for dx, dy, h in spots:
        x, y = round(dx * k), round(ym + dy * k)
        z = lo - 2 - (h % 3) * step - (h // 3)
        rain.put((x, y, z), c2)
        rain.put((x, y, z - 1), c1)
    # everything up so the lowest drop touches the ground
    drop = min(p[2] for p in rain.v)
    if drop < 0:
        for q in c.parts:
            q.v = {(x, y, z - drop): v for (x, y, z), v in q.v.items()}
            q.pivot = (q.pivot[0], q.pivot[1], q.pivot[2] - drop)


def furtrim(c, H, col, col2, a):
    """Thins a fuzzball's fur tufts on its back half, where a big tail
    hides them anyway (keeps the triangle count down for a bushy tail)."""
    fur = next((p for p in c.parts if p.name == 'fur'), None)
    if fur is None or not fur.v:
        return
    ys = [p[1] for p in fur.v]
    mid = (min(ys) + max(ys)) / 2
    keep = round(a.get('keep', 0.3) * 100)
    for p in list(fur.v):
        if p[1] > mid and _hash(*p, 53) % 100 >= keep:
            del fur.v[p]


ACCESSORIES = {'nofeet': nofeet, 'drizzle': drizzle, 'furtrim': furtrim}
