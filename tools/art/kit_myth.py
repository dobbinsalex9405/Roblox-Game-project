"""Body plans for big and mythic creatures, used by roster entries like the
plans in kit.py and kit_pond.py (see variants.py). Every plan takes `kind`
and is drawn at k = H / 10 voxels, so the same plan works from a Rare (the
fine build draws a Rare about 24 voxels tall) to a Legendary (34) or a
Godly (38): detail grows with H, the silhouette stays.

- **beast**: a grand four-legged animal: cat, canine, hoof, heavy.
  Options: mane, horns, tail, wings, tusks, saber, heads (1 or 3).
- **drake**: a dragon: drake (four legs and wings), wyvern (two legs, the
  wings are its arms), pixie (small and round, butterfly wings).
  Options: wings, heads (1 or 2), horns.
- **dino**: rex, trike, stego, raptor.
- **whale**: whale, orca, narwhal, dolphin. Floats; fins and fluke move.
- **ray**: manta. Floats; the wings are its fins.
- **fish**: koi, angler, angelfish, shark, goldfish. Floats; swims.
- **serpent**: wyrm, cobra. Options: heads (1 or 3), frills.
- **upright**: a creature on two legs with arms: golem, giant, treant,
  mushroom, seahorse, gorilla, cub, sprite, gnome, imp.

Colours: col (main), belly, accent (manes, plates, fins, horns), glow
(the glowing accents; leave it out for a creature that does not glow) and
eye (iris; ink by default). Plans keep to the parts the game animates: body,
head, eyes (blink), ears, tail, wingL/wingR, finL/finR, the legs (each its
own part through rig.leg_part, so they walk), plus static and glow extras.

Another kit adds a kind with `add_kind(plan, kind, fn)`: fn(c, k, cols,
opts) draws the whole creature (it may call the helpers here) and the plan
accepts the new kind. Same art frame as kit.py: x right, y back (front is
-y), z up, feet at z = 0."""
import math

from voxkit import hexc

INK, WHITE, BLUSH = hexc('#1B1B2F'), hexc('#FFFFFF'), hexc('#FF8FB1')

KINDS = {
    'beast': ['cat', 'canine', 'hoof', 'heavy'],
    'drake': ['drake', 'wyvern', 'pixie'],
    'dino': ['rex', 'trike', 'stego', 'raptor'],
    'whale': ['whale', 'orca', 'narwhal', 'dolphin'],
    'ray': ['manta'],
    'fish': ['koi', 'angler', 'angelfish', 'shark', 'goldfish'],
    'serpent': ['wyrm', 'cobra'],
    'upright': ['golem', 'giant', 'treant', 'mushroom', 'seahorse', 'gorilla', 'cub', 'sprite', 'gnome', 'imp'],
}
COLOURS = {'col', 'belly', 'accent', 'glow', 'eye', 'snout', 'horn', 'wing'}
OPTIONS = {
    'beast': {'mane': {'none', 'lion', 'ruff', 'crest'},
              'horns': {'none', 'ram', 'rhino', 'unicorn', 'antlers', 'bull', 'qilin'},
              'tail': {'lion', 'fox', 'bushy', 'whip', 'spike', 'short'},
              'wings': {'none', 'feather', 'bat'}, 'tusks': {True, False}, 'saber': {True, False},
              'heads': {1, 3}, 'stripes': {True, False}},
    'drake': {'wings': {'bat', 'butterfly', 'none'}, 'heads': {1, 2}, 'horns': {'none', 'swept', 'crown'}},
    'dino': {},
    'whale': {},
    'ray': {},
    'fish': {},
    'serpent': {'heads': {1, 3}, 'frills': {True, False}},
    'upright': {'wings': {'none', 'fairy'}, 'hat': {'none', 'cone', 'crown'}},
}
# gait each kind walks with (rig.KIND_GAIT); Legendary and Godly hover anyway
GAIT = {
    'beast': 'trot', 'drake': 'trot', 'dino': 'trot', 'whale': 'swim', 'ray': 'swim', 'fish': 'swim',
    'serpent': 'slither', 'upright': 'waddle',
}
KIND_GAIT = {'wyvern': 'waddle', 'pixie': 'hover', 'rex': 'waddle', 'raptor': 'waddle', 'sprite': 'hover',
             'seahorse': 'swim'}
EXTRA = {}  # (plan, kind) -> fn(c, k, cols, opts), from add_kind


def add_kind(plan, kind, fn):
    """Lets another kit add a kind to a plan here (see the docstring)."""
    if kind in KINDS[plan]:
        raise ValueError(f'{plan} already has a kind "{kind}"')
    KINDS[plan].append(kind)
    PLANS[plan][1]['kind'].add(kind)
    EXTRA[(plan, kind)] = fn


# ------------------------------------------------------------------ helpers

def mix(a, b, t):
    return tuple(max(0, min(255, round(a[i] + (b[i] - a[i]) * t))) for i in range(3))


def dark(col, t=0.3):
    return mix(col, INK, t)


def light(col, t=0.35):
    return mix(col, WHITE, t)


def mx(x):
    """x mirrored to the left (voxel cells are [x, x + 1))."""
    return -x - 1


def mirror(part, pts):
    """(x, y, z, col, glow) on the right and its mirror on the left."""
    for x, y, z, col, g in pts:
        part.put((x, y, z), col, g)
        part.put((mx(x), y, z), col, g)


def core(part, pts, col_at=None, glow_at=None, col=None, glow=False):
    """A face-connected voxel path through points (x, y, z): every step
    moves one axis at a time, so a thin tube, horn or rod never ends up as
    voxels that only touch at an edge or a corner (they would read as loose
    debris once bevelled). col_at(s) / glow_at(s) colour by s in [0, 1]."""
    n = len(pts)
    prev = None
    for i, p in enumerate(pts):
        s = i / max(1, n - 1)
        cl = col_at(s) if col_at else col
        g = glow_at(s) if glow_at else glow
        cur = [math.floor(v) for v in p[:3]]
        if prev is not None:
            q = list(prev)
            for axis in range(3):
                while q[axis] != cur[axis]:
                    q[axis] += 1 if cur[axis] > q[axis] else -1
                    if tuple(q) not in part.v:
                        part.put(tuple(q), cl, g)
        if tuple(cur) not in part.v:
            part.put(tuple(cur), cl, g)
        prev = cur


def sweep(part, pts, col_at, glow_at=lambda s: False):
    """A sphere swept along (x, y, z, r) points; colour by s in [0, 1]."""
    n = len(pts)
    for i, (x, y, z, r) in enumerate(pts):
        s = i / max(1, n - 1)
        part.ell((x, y, z), (r, r, r), col_at(s), glow_at(s))
    core(part, pts, col_at, glow_at)


def curve(a, b, n, bend=(0, 0, 0)):
    """n + 1 points from a to b, bowed by `bend` at the middle."""
    out = []
    for i in range(n + 1):
        t = i / n
        w = math.sin(t * math.pi)
        out.append(tuple(a[j] + (b[j] - a[j]) * t + bend[j] * w for j in range(3)))
    return out


def horn(part, base, tip, r0, col, tip_col=None, bend=(0, 0, 0), glow=False, both=True):
    """A tapering horn from base to tip, mirrored to the left too."""
    n = max(6, round(math.dist(base, tip) * 2.5))
    pts = curve(base, tip, n, bend)
    for side in ((1, -1) if both else (1,)):
        side_pts = []
        for i, (x, y, z) in enumerate(pts):
            s = i / n
            r = max(0.55, r0 * (1 - 0.8 * s))
            colr = tip_col if tip_col is not None and s > 0.7 else col
            g = glow and (tip_col is None or s > 0.7)
            xx = x if side > 0 else mx(x) + 1  # the mirror of a point (not a cell) is -x
            part.ell((xx, y, z), (r, r, r), colr, g)
            side_pts.append((xx, y, z))
        core(part, side_pts, lambda s: tip_col if tip_col is not None and s > 0.7 else col,
             lambda s: glow and (tip_col is None or s > 0.7))


def rod(part, a, b, r, col, glow=False):
    n = max(2, round(math.dist(a, b) * 2.5))
    pts = []
    for i in range(n + 1):
        t = i / n
        p = tuple(a[j] + (b[j] - a[j]) * t for j in range(3))
        pts.append(p)
        if r > 0.6:
            part.ell(p, (r, r, r), col, glow)
    core(part, pts, col=col, glow=glow)


def band(part, stops, z0, z1, keep=()):
    """Shades a part by height (stops: (fraction up, colour), lowest first);
    glowing voxels and colours in `keep` stay."""
    def f(p, cc, g):
        if g or cc in keep:
            return None
        t = (p[2] - z0) / max(1, z1 - z0)
        col = stops[0][1]
        for frac, cl in stops:
            if t >= frac:
                col = cl
        return (col, False)
    part.paint(f)


def eye_pair(c, head, x_off, z, size, iris=INK, glow=False, tall=1):
    """Big eyes cut into the head's front, a shine in the top outer corner,
    in their own part so they blink. `tall` extra rows make them oval."""
    e = c.part('eyes', 'blink', head.pivot)
    for sx in (1, -1):
        for dx in range(size):
            for dz in range(size + tall):
                x = x_off + dx if sx > 0 else -(x_off + dx) - 1
                f = head.front(x, z + dz)
                if f:
                    del head.v[f]
                    shine = dz == size + tall - 1 and dx == size - 1
                    e.put(f, WHITE if shine else iris, glow and not shine)


def cheeks(head, x, z, col=BLUSH):
    for sx in (1, -1):
        xx = x if sx > 0 else mx(x)
        f = head.front(xx, z)
        if f:
            head.put(f, col)


def nose(head, z, col=INK, w=1):
    for x in range(-w, w):
        f = head.front(x, z)
        if f:
            head.put(f, col)


def leg(c, side, i, n, cx, cy, top, r, col, foot=None, foot_h=0, toes=None, wide=0.0, ry=None):
    """A rounded leg column at (cx, cy) up to `top` (into the body), as its
    own walking part (rig.leg_part, hinged at the hip). `wide` flares the
    foot; `foot` colours the bottom `foot_h` voxels (hooves, paws); `toes`
    puts claws in front of the foot."""
    import rig
    x = cx if side == 'R' else -cx
    part = rig.leg_part(c, side, i, n, (x, cy, top + 1))
    ry = ry if ry is not None else r
    for z in range(0, int(top) + 1):
        grow = wide * max(0.0, 1 - z / max(1.0, 0.35 * top))
        colz = foot if foot is not None and z < foot_h else col
        part.ell((x, cy, z + .5), (r + grow, ry + grow, 0.5), colz)
    if toes is not None:
        y0 = min(p[1] for p in part.v if p[2] == 0)
        for dx in (-1, 0, 1):
            xx = math.floor(x + dx * max(1, r * 0.6))
            part.put((xx, y0 - 1, 0), toes)
    return part


def wing_feather(c, k, root, length, rise, cols, tip, edge=None, thick=2, glow_tip=True):
    """Raised, feathered wings (as legends.grand_wing)."""
    import legends
    legends.grand_wing(c, k, root, length, rise, cols, tip, edge=edge, thick=thick, tip_glow=glow_tip)


def wing_bat(c, k, root, span, col, membrane, glow=None, rise=1.0, thick=1):
    """Membrane wings: a bony arm with three fingers, skin between them."""
    rx, ry, rz = root
    L = max(4, round(span * k))
    for sx, name in ((1, 'wingR'), (-1, 'wingL')):
        w = c.part(name, name, (sx * rx, ry, rz))
        fingers = []
        for f in range(3):
            ang = 0.35 + f * 0.45
            fingers.append(ang)
        for i in range(L):
            t = i / max(1, L - 1)
            x = round(rx) + i
            top = rz + round(rise * k * math.sin(t * math.pi * 0.9) + t * 1.4 * k)
            # the membrane hangs from the arm in scallops between the fingers
            scal = abs(math.sin(t * math.pi * 3))
            depth = round((0.6 + 2.4 * (1 - t) * 0.8 + 0.9 * scal) * k * 0.9)
            for dz in range(max(1, depth)):
                bone = dz == 0 or (dz <= 1 and t > 0.9)
                colr = col if bone else membrane
                g = glow is not None and not bone and dz == depth - 1
                if g:
                    colr = glow
                for dy in range(thick):
                    xx = x if sx > 0 else mx(x)
                    w.put((xx, ry + dy, top - dz), colr, g)
            if i % max(2, L // 3) == 0 and i:
                for dz in range(round(depth * 1.0)):
                    xx = x if sx > 0 else mx(x)
                    w.put((xx, ry, top - dz), col)
        # a claw on the wrist
        xx = round(rx) + L // 3
        top = rz + round(rise * k * math.sin(1 / 3 * math.pi * 0.9) + 1.4 * k / 3)
        w.put((xx if sx > 0 else mx(xx), ry, top + 1), light(col, 0.6))


def wing_butterfly(c, k, root, size, col, col2, glow=None, edge=INK):
    """Two rounded lobes a side, spots near the edge."""
    rx, ry, rz = root
    for sx, name in ((1, 'wingR'), (-1, 'wingL')):
        w = c.part(name, name, (sx * rx, ry, rz))
        for (cx, cz, r) in ((1.5, 1.5, 1.6), (1.2, -0.6, 1.1)):
            R = r * size * k
            ox, oz = rx + cx * size * k, rz + cz * size * k
            for x in range(math.floor(ox - R), math.ceil(ox + R) + 1):
                for z in range(math.floor(oz - R), math.ceil(oz + R) + 1):
                    d = math.hypot(x + .5 - ox, z + .5 - oz) / R
                    if d > 1 or x < rx:
                        continue
                    if d > 0.86:
                        colr, g = edge, False
                    elif 0.55 < d < 0.75 and (x + z) % 3 == 0:
                        colr, g = (glow, True) if glow else (WHITE, False)
                    else:
                        colr, g = (col if d < 0.5 else col2), False
                    w.put((x if sx > 0 else mx(x), round(ry), z), colr, g)


def fins(c, k, at, length, height, col, glow=None, down=0.6, thick=1):
    """Pectoral fins (finL/finR) from `at`, swept back and a little down:
    each column out from the body is a solid run of voxels, and each
    overlaps the one before, so the fin is one face-connected piece."""
    ax, ay, az = at
    for sx, name in ((1, 'finR'), (-1, 'finL')):
        f = c.part(name, name, (sx * ax, ay, az))
        L = max(2, round(length * k))
        prev = None
        prev_end = None
        for i in range(L):
            t = i / max(1, L - 1)
            x = math.floor(ax) + i
            h = max(1, round(height * k * (1 - t * 0.6)))
            y0 = math.floor(ay + t * 0.9 * k)
            if prev_end is not None and y0 > prev_end:
                y0 = prev_end
            z = math.floor(az - t * down * k)
            th = thick + (1 if i < L // 2 else 0)
            if prev is not None and z < prev:
                z = prev  # the top of this column touches the bottom of the last
            prev = z - th + 1
            prev_end = y0 + h - 1
            for j in range(h):
                edge = glow is not None and (i == L - 1 or j == h - 1)
                for dz in range(th):
                    f.put((x if sx > 0 else mx(x), y0 + j, z - dz), glow if edge else col, edge)


def fluke(c, k, root, span, length, col, glow=None, vertical=False, name='tail'):
    """A tail stock ending in a whale fluke (flat) or a fish tail (vertical)."""
    rx, ry, rz = root
    t = c.part(name, 'tail', root)
    L = max(3, round(length * k))
    for i in range(L):
        s = i / L
        r = max(0.6, (0.9 - 0.55 * s) * k)
        t.ell((0, ry + i, rz + s * 0.5 * k), (r, 1.0, r * 0.9), col)
    ey = ry + L
    t.ell((0, ey - 0.5, rz + 0.5 * k), (max(0.8, 0.4 * k), 1.2, max(0.8, 0.4 * k)), col)  # stock into fluke
    ez = rz + 0.5 * k
    S = span * k
    for a in range(0, round(S) + 1):
        u = abs(a) / max(1, S)
        un = max(0, abs(a) - 1) / max(1, S)  # the column nearer the middle
        back = round(u * u * 1.6 * k)
        start = round(un * un * 1.6 * k)  # overlap it, so the fluke is one piece
        depth = max(1, round((1.1 - 0.6 * u) * k))
        for yy in range(start, back + depth):
            edge = glow is not None and yy >= back + depth - 1
            for aa in (a, -a - 1):
                if not vertical:
                    for dz in (0, 1):
                        t.put((aa, round(ey + yy), round(ez) + dz), glow if edge else col, edge)
                else:
                    for x in (0, -1):
                        t.put((x, round(ey + yy), round(ez) + aa), glow if edge else col, edge)
    return t


def spikes(part, pts, h, col, glow=False):
    """Little cones standing on (x, y, z) points."""
    for (x, y, z) in pts:
        for i in range(max(1, round(h))):
            r = max(0.5, (h - i) * 0.35)
            part.ell((x, y, z + i), (r, r, 0.5), col, glow)


def top_of(part, x, y):
    zs = [p[2] for p in part.v if p[0] == x and p[1] == y]
    return max(zs) if zs else None


def _cols(cols, col, belly=None, accent=None, glow=None, eye=INK):
    belly = cols.get('belly', belly or light(col, 0.45))
    accent = cols.get('accent', accent or dark(col, 0.25))
    return belly, accent, cols.get('glow', glow), cols.get('eye', eye)


# -------------------------------------------------------------------- beast

def beast(c, H, cols, opts):
    """A grand four-legged animal: a deep chest, sturdy legs, a big head,
    the kind deciding the face and feet."""
    k = H / 10.0
    kind = opts['kind']
    col = cols['col']
    belly, accent, glow, iris = _cols(cols, col)
    snout = cols.get('snout', light(col, 0.55))
    hornc = cols.get('horn', hexc('#F5E9C8'))
    heavy, hoof, canine, cat = kind == 'heavy', kind == 'hoof', kind == 'canine', kind == 'cat'
    body = c.part('body')
    # legs: rounded columns, paws or hooves
    r = (0.85 if heavy else 0.6 if hoof else 0.68) * k
    top = (3.3 if hoof else 2.9) * k
    fy, by = (-1.9 * k, 2.5 * k) if not heavy else (-1.8 * k, 2.6 * k)
    lx = (1.45 if not heavy else 1.55) * k
    footc = dark(col, 0.55) if hoof else (light(col, 0.35) if not heavy else dark(col, 0.2))
    for side in ('L', 'R'):
        for i, ly in enumerate((fy, by)):
            leg(c, side, i, 2, lx, ly, top, r, col, foot=footc, foot_h=max(1, round((0.5 if hoof else 0.35) * k)),
                toes=None if hoof or heavy else dark(col, 0.5), wide=0.15 * k if not hoof else 0)
    # body: a deep chest and a strong back
    bz = top + 0.9 * k
    body.ell((0, 0.4 * k, bz), ((2.1 if heavy else 1.85) * k, 3.3 * k, (1.9 if heavy else 1.6) * k), col)
    body.ell((0, -1.6 * k, bz + 0.3 * k), ((2.0 if heavy else 1.75) * k, 1.6 * k, (1.9 if heavy else 1.7) * k), col)
    body.paint(lambda p, cc, g: (belly, False) if p[2] < bz - 0.7 * k and abs(p[0] + .5) < 1.2 * k else None)
    # neck and head
    hy, hz = -3.3 * k, bz + 2.6 * k
    if heavy:
        hy, hz = -3.4 * k, bz + 1.6 * k
    body.ell((0, -2.6 * k, bz + 1.3 * k), (1.15 * k, 1.1 * k, 1.5 * k), col)
    head = c.part('head', 'head', (0, -2.6 * k, bz + 1.6 * k))
    hr = (1.75, 1.6, 1.5) if not heavy else (2.0, 1.8, 1.8)
    head.ell((0, hy, hz), (hr[0] * k, hr[1] * k, hr[2] * k), col)
    if cat:
        head.ell((0, hy - 1.3 * k, hz - 0.55 * k), (0.95 * k, 0.6 * k, 0.6 * k), snout)
        nose(head, round(hz - 0.2 * k), hexc('#FF7A9A'), max(1, round(0.25 * k)))
    elif canine:
        head.ell((0, hy - 1.6 * k, hz - 0.5 * k), (0.8 * k, 1.1 * k, 0.65 * k), snout)
        nose(head, round(hz - 0.1 * k), INK, max(1, round(0.3 * k)))
    elif hoof:
        head.ell((0, hy - 1.5 * k, hz - 0.8 * k), (0.95 * k, 1.1 * k, 0.8 * k), snout)
        for sx in (1, -1):
            f = head.front(round(sx * 0.4 * k) if sx > 0 else mx(round(0.4 * k)), round(hz - 0.7 * k))
            if f:
                head.put(f, dark(snout, 0.45))
    else:  # heavy: a broad face
        head.ell((0, hy - 1.4 * k, hz - 0.9 * k), (1.1 * k, 0.9 * k, 0.9 * k), snout)
    es = max(2, round(0.42 * k))
    ez = round(hz + 0.15 * k)
    eye_pair(c, head, max(1, round(0.55 * k)), ez, es, iris=iris, glow=bool(cols.get('eye')) and glow is not None)
    if not heavy:
        cheeks(head, round(1.25 * k), round(hz - 0.55 * k))
    # ears
    ears = c.part('ears', 'ears', (0, hy, hz + hr[2] * k))
    ez0 = hz + hr[2] * k * 0.6
    for i in range(round((1.5 if canine else 1.2 if cat else 1.0) * k)):
        w = max(0, round(((1.5 if canine else 1.2) * k - i) * 0.4))
        if cat or canine:
            for dx in range(-w, w + 1):
                ears.put((round(1.05 * k) + dx, round(hy + 0.1 * k), round(ez0) + i), col if dx != 0 or i < 1 else light(col, 0.5))
                ears.put((mx(round(1.05 * k) + dx), round(hy + 0.1 * k), round(ez0) + i), col if dx != 0 or i < 1 else light(col, 0.5))
    if hoof:
        # leaf ears out from the side of the head, rising a little
        ey, ez = round(hy + 0.3 * k), round(hz + 0.9 * k)
        side_x = max((p[0] for p in head.v if p[1] == ey and p[2] == ez), default=round(1.2 * k))
        for i in range(round(1.4 * k)):
            for dz in range(max(1, round(0.35 * k * (1 - i / (1.4 * k))))):
                ears.put((side_x + i, ey, ez + i // 3 + dz), col)
                ears.put((mx(side_x + i), ey, ez + i // 3 + dz), col)
    if heavy and opts.get('tusks'):
        # big flap ears (a mammoth's)
        ears.ell((1.9 * k, hy + 0.6 * k, hz), (0.5 * k, 0.9 * k, 1.2 * k), dark(col, 0.1))
        ears.ell((mx(1.9 * k) + 1, hy + 0.6 * k, hz), (0.5 * k, 0.9 * k, 1.2 * k), dark(col, 0.1))
    # tail
    tail = c.part('tail', 'tail', (0, 3.6 * k, bz + 0.6 * k))
    tk = opts.get('tail', 'lion' if cat else 'fox' if canine else 'whip' if hoof else 'short')
    if tk == 'lion':
        pts = [(0, 3.6 * k + s * 3.0 * k, bz + 0.6 * k + math.sin(s * math.pi * 0.8) * 1.6 * k, max(0.55, 0.32 * k)) for s in [i / 16 for i in range(17)]]
        sweep(tail, pts, lambda s: col)
        tail.ell((0, 6.6 * k, bz + 1.2 * k), (0.6 * k, 0.7 * k, 0.7 * k), accent)
    elif tk in ('fox', 'bushy'):
        pts = [(0, 3.6 * k + s * 3.0 * k, bz + 0.4 * k + math.sin(s * math.pi * 0.6) * 1.8 * k, (0.55 + 0.6 * math.sin(s * math.pi)) * k) for s in [i / 16 for i in range(17)]]
        sweep(tail, pts, lambda s: col if s < 0.75 or tk == 'bushy' else WHITE)
    elif tk == 'whip':
        pts = [(0, 3.6 * k + s * 2.0 * k, bz + 0.4 * k - s * 1.6 * k, max(0.55, 0.3 * k)) for s in [i / 12 for i in range(13)]]
        sweep(tail, pts, lambda s: col)
        tail.ell((0, 5.7 * k, bz - 1.4 * k), (0.45 * k, 0.5 * k, 0.8 * k), accent)
    elif tk == 'spike':
        pts = [(0, 3.6 * k + s * 3.0 * k, bz + 0.6 * k + s * s * 3.2 * k, max(0.55, 0.45 * k * (1 - 0.4 * s))) for s in [i / 16 for i in range(17)]]
        sweep(tail, pts, lambda s: col if s < 0.7 else accent)
        spikes(tail, [(0, round(6.6 * k), round(bz + 3.8 * k))], 0.9 * k, hornc, glow is not None)
    else:
        tail.ell((0, 3.8 * k, bz + 0.6 * k), (0.6 * k, 0.7 * k, 0.6 * k), col)
    # options
    mane = opts.get('mane', 'none')
    if mane == 'lion':
        m = c.part('mane', 'static')
        m.ell((0, hy + 0.6 * k, hz), (2.5 * k, 1.1 * k, 2.4 * k), accent)
        m.ell((0, hy + 1.2 * k, hz - 1.2 * k), (2.0 * k, 1.0 * k, 1.6 * k), accent)
        m.paint(lambda p, cc, g: (dark(accent, 0.15), False) if (p[0] * 3 + p[2] * 2) % 5 == 0 else None)
    elif mane == 'ruff':
        m = c.part('mane', 'static')
        m.ell((0, -2.4 * k, bz + 1.0 * k), (1.9 * k, 1.2 * k, 1.9 * k), accent)
    elif mane == 'crest':
        m = c.part('mane', 'static')
        for i in range(14):
            s = i / 13
            y = hy + 0.8 * k + s * 2.6 * k
            z = hz + 1.2 * k - s * 2.2 * k
            m.ell((0, y, z), (0.45 * k, 0.6 * k, 0.8 * k), accent)
    hk = opts.get('horns', 'none')
    if hk != 'none':
        hp = c.part('horns', 'glow' if glow is not None else 'static', (0, hy, hz + hr[2] * k))
        g = glow is not None
        tipc = glow if g else hornc
        if hk == 'ram':
            for side in (1, -1):
                pts = []
                for i in range(22):
                    a = i / 21 * math.pi * 1.5
                    rr = 1.2 * k * (1 - i / 40)
                    pts.append((side * (1.3 * k + 0.25 * k * i / 21), hy + 0.4 * k - math.sin(a) * rr * 0.4 + rr * 0.4,
                                hz + 0.9 * k + math.cos(a) * rr - rr * 0.2, max(0.6, 0.5 * k * (1 - 0.5 * i / 21))))
                for j, (x, y, z, rr2) in enumerate(pts):
                    s = j / 21
                    hp.ell((x - (0.5 if side < 0 else 0), y + (1.0 * k) * math.sin(s * math.pi * 1.5) * 0.6, z), (rr2, rr2, rr2),
                           tipc if s > 0.75 else hornc, g and s > 0.75)
        elif hk == 'rhino':
            horn(hp, (0, hy - 1.9 * k, hz - 0.3 * k), (0, hy - 2.4 * k, hz + 1.6 * k), 0.55 * k, hornc, tipc, glow=g, both=False)
        elif hk == 'unicorn' or hk == 'qilin':
            horn(hp, (0, hy - 0.6 * k, hz + 1.3 * k), (0, hy - 1.5 * k, hz + 3.2 * k), 0.4 * k, hornc, tipc, glow=g, both=False)
        elif hk == 'bull':
            horn(hp, (1.2 * k, hy, hz + 1.1 * k), (2.4 * k, hy - 0.6 * k, hz + 2.4 * k), 0.35 * k, hornc, tipc, bend=(0.4 * k, 0, -0.4 * k), glow=g)
        elif hk == 'antlers':
            for side in (1, -1):
                base = (side * 0.9 * k, hy + 0.2 * k, hz + 1.2 * k)
                tip = (side * 2.0 * k, hy + 0.8 * k, hz + 4.2 * k)
                rod(hp, base, tip, max(0.6, 0.22 * k), hornc)
                for b in range(3):
                    s = 0.35 + b * 0.25
                    p = tuple(base[j] + (tip[j] - base[j]) * s for j in range(3))
                    q = (p[0] + side * 0.9 * k, p[1] - 0.5 * k, p[2] + 1.0 * k)
                    rod(hp, p, q, max(0.55, 0.16 * k), hornc)
                    hp.put(tuple(math.floor(v) for v in q), tipc, g)
                hp.put(tuple(math.floor(v) for v in tip), tipc, g)
    if opts.get('tusks'):
        tp = c.part('tusks', 'static', (0, hy, hz))
        for side in (1, -1):
            n = max(10, round(4.0 * k))
            pts = curve((side * 0.8 * k, hy - 1.4 * k, hz - 1.2 * k), (side * 1.1 * k, hy - 3.0 * k, hz + 0.2 * k), n, (side * 0.5 * k, 0, -1.0 * k))
            for i, (x, y, z) in enumerate(pts):
                rr = max(0.75, 0.42 * k * (1 - 0.6 * i / n))
                tp.ell((x - (0.5 if side < 0 else 0), y, z), (rr, rr, rr), hornc)
            core(tp, [(x - (0.5 if side < 0 else 0), y, z) for (x, y, z) in pts], col=hornc)
    if opts.get('saber'):
        sp = c.part('fangs', 'static', (0, hy, hz))
        for side in (1, -1):
            x = round(0.45 * k) if side > 0 else mx(round(0.45 * k))
            f = head.front(x, round(hz - 0.9 * k))
            if f:
                for i in range(round(1.1 * k)):
                    sp.put((f[0], f[1] - 1, f[2] - i), hornc)
    w = opts.get('wings', 'none')
    if w == 'feather':
        wc = cols.get('wing', light(col, 0.6))
        wing_feather(c, k, (1.6 * k, 0.0 * k, round(bz + 1.0 * k)), 4.6, 2.4, (wc, light(wc, 0.3), light(wc, 0.6)), glow or WHITE, thick=2, glow_tip=glow is not None)
    elif w == 'bat':
        wc = cols.get('wing', dark(col, 0.35))
        wing_bat(c, k, (1.6 * k, 0.2 * k, round(bz + 1.0 * k)), 4.4, dark(wc, 0.3), wc, glow=glow)
    if opts.get('stripes'):
        sc = cols.get('accent', INK)
        for part in (body, head, tail):
            part.paint(lambda p, cc, g: (sc if glow is None else glow, glow is not None) if cc == col and (p[1] + abs(p[0] + .5) * 0.6) % max(3, round(1.0 * k)) < max(1, round(0.25 * k)) and p[2] > bz - 0.9 * k else None)
    if opts.get('heads', 1) == 3:
        _extra_heads(c, k, head, hy, hz, hr, col, snout, iris)
    c.gait_hint = 'trot'
    return c


def _extra_heads(c, k, head, hy, hz, hr, col, snout, iris):
    """Two more heads beside the first, a little lower and turned out."""
    for side, name in ((1, 'headR'), (-1, 'headL')):
        h2 = c.part(name, 'head', (side * 1.6 * k, hy + 0.6 * k, hz - 0.8 * k))
        for (x, y, z), v in list(head.v.items()):
            nx = x * 0.8 + side * 2.3 * k
            ny = y * 0.85 + 0.7 * k + abs(x) * 0.15
            nz = z - 0.9 * k
            h2.put((round(nx), round(ny), round(nz)), v[0], v[1])
        for (x, y, z), v in list(c.part('eyes').v.items()):
            pass
    # eyes on the side heads: cut from their fronts
    for name in ('headR', 'headL'):
        h2 = c.part(name)
        xs = [p[0] for p in h2.v]
        cx = (min(xs) + max(xs) + 1) / 2
        zs = [p[2] for p in h2.v]
        z = round(min(zs) + (max(zs) - min(zs)) * 0.55)
        e = c.part('eyes', 'blink', head.pivot)
        size = max(2, round(0.35 * k))
        for sx in (1, -1):
            for dx in range(size):
                for dz in range(size + 1):
                    x = math.floor(cx + sx * (0.45 * k + dx))
                    f = h2.front(x, z + dz)
                    if f:
                        del h2.v[f]
                        e.put(f, WHITE if (dz == size and dx == size - 1) else iris)


# -------------------------------------------------------------------- drake

def drake(c, H, cols, opts):
    k = H / 10.0
    kind = opts['kind']
    col = cols['col']
    belly, accent, glow, iris = _cols(cols, col)
    hornc = cols.get('horn', light(accent, 0.4))
    body = c.part('body')
    pixie = kind == 'pixie'
    if kind == 'wyvern':
        top = 2.6 * k
        for side in ('L', 'R'):
            leg(c, side, 0, 1, 1.25 * k, 0.9 * k, top, 0.75 * k, col, toes=hornc, wide=0.2 * k)
        bz = top + 1.5 * k
        body.ell((0, 0.6 * k, bz), (1.7 * k, 2.4 * k, 2.0 * k), col)
        body.ell((0, -1.0 * k, bz + 1.4 * k), (1.3 * k, 1.4 * k, 1.6 * k), col)
        hy, hz = -2.4 * k, bz + 3.4 * k
    else:
        s = 0.8 if pixie else 1.0
        top = 2.4 * k * s
        for side in ('L', 'R'):
            for i, ly in enumerate((-1.5 * k * s, 2.0 * k * s)):
                leg(c, side, i, 2, 1.3 * k * s, ly, top, 0.62 * k * s, col, toes=hornc if not pixie else None, wide=0.15 * k)
        bz = top + 1.3 * k * s
        body.ell((0, 0.3 * k * s, bz), (1.8 * k * s, 2.9 * k * s, 1.6 * k * s), col)
        body.ell((0, -1.6 * k * s, bz + 0.9 * k * s), (1.3 * k * s, 1.2 * k * s, 1.5 * k * s), col)
        hy, hz = -2.9 * k * s, bz + 2.6 * k * s
    body.paint(lambda p, cc, g: (belly, False) if p[1] < 1.6 * k and abs(p[0] + .5) < 1.0 * k and p[2] < bz + 1.6 * k and
               (p[1] < -0.2 * k or p[2] < bz - 0.6 * k) and cc == col else None)
    # belly plates: a darker line every few rows
    body.paint(lambda p, cc, g: (dark(belly, 0.12), False) if cc == belly and p[2] % max(2, round(0.55 * k)) == 0 else None)
    heads = opts.get('heads', 1)
    hs = 0.85 if heads == 2 else 1.0
    head_list = []
    for hi in range(heads):
        side = 0 if heads == 1 else (1 if hi == 0 else -1)
        name = 'head' if hi == 0 else 'head2'
        hx = side * 1.3 * k
        h = c.part(name, 'head', (hx, hy + 0.8 * k, hz - 1.0 * k))
        r = (1.5 * k * hs, 1.45 * k * hs, 1.35 * k * hs) if not pixie else (1.7 * k, 1.5 * k, 1.5 * k)
        h.ell((hx, hy, hz), r, col)
        # snout: a long muzzle with nostrils
        h.ell((hx, hy - 1.5 * k * hs, hz - 0.45 * k * hs), (0.95 * k * hs, 1.0 * k * hs, 0.7 * k * hs), col)
        h.paint(lambda p, cc, g, hx=hx: (belly, False) if p[2] < hz - 0.6 * k * hs and p[1] < hy - 0.4 * k else None)
        if heads == 2:
            body.ell((hx * 0.6, hy + 1.2 * k, hz - 1.4 * k), (0.8 * k, 0.9 * k, 1.3 * k), col)
        head_list.append((h, hx))
    for h, hx in head_list:
        es = max(2, round(0.38 * k * hs))
        e = c.part('eyes', 'blink', h.pivot)
        for sx in (1, -1):
            for dx in range(es):
                for dz in range(es + 1):
                    x = math.floor(hx + sx * (0.5 * k * hs + dx)) if sx > 0 else math.floor(hx - 0.5 * k * hs - dx) - 1
                    f = h.front(x, round(hz + 0.05 * k) + dz)
                    if f:
                        del h.v[f]
                        e.put(f, WHITE if (dz == es and dx == es - 1) else iris, False)
        for sx in (1, -1):
            x = math.floor(hx + sx * 0.35 * k) if sx > 0 else math.floor(hx - 0.35 * k) - 1
            f = h.front(x, round(hz - 0.25 * k))
            if f:
                h.put(f, dark(col, 0.5))
        hk = opts.get('horns', 'swept')
        if hk != 'none':
            hp = c.part('horns' if hx >= 0 else 'horns2', 'glow' if glow is not None else 'static', (hx, hy, hz + k))
            for side in (1, -1):
                base = (hx + side * 0.8 * k * hs, hy + 0.5 * k, hz + 1.0 * k * hs)
                tip = (hx + side * 1.4 * k * hs, hy + 2.4 * k * hs, hz + 2.2 * k * hs) if hk == 'swept' else (hx + side * 1.0 * k, hy + 0.3 * k, hz + 2.6 * k)
                n = max(10, round(math.dist(base, tip) * 2.5))
                hpts = []
                for i, p in enumerate(curve(base, tip, n, (0, 0, 0.5 * k))):
                    s = i / n
                    rr = max(0.55, 0.38 * k * hs * (1 - 0.75 * s))
                    tipg = glow is not None and s > 0.65
                    h_col = (glow if tipg else hornc)
                    q = (p[0] - (0.5 if side < 0 else 0), p[1], p[2])
                    hp.ell(q, (rr, rr, rr), h_col, tipg)
                    hpts.append(q)
                core(hp, hpts, lambda s: glow if (glow is not None and s > 0.65) else hornc,
                     lambda s: glow is not None and s > 0.65)
    # back spines from neck to tail
    sp = c.part('spines', 'glow' if glow is not None else 'static')
    ys = range(round(-1.8 * k), round(3.0 * k), max(2, round(0.7 * k)))
    for y in ys:
        t = top_of(body, 0, y)
        if t is not None:
            h = max(1, round(0.7 * k * (1 - abs(y - 0.6 * k) / (5 * k))))
            for i in range(h):
                for x in (0, -1):
                    sp.put((x, y + i // 2, t + 1 + i), glow if glow is not None and i == h - 1 else accent, glow is not None and i == h - 1)
    # tail: long, tapering, ending in a spade
    tail = c.part('tail', 'tail', (0, 2.8 * k, bz))
    n = 22
    pts = []
    for i in range(n + 1):
        s = i / n
        pts.append((math.sin(s * math.pi * 1.2) * 0.8 * k, 2.8 * k + s * 4.6 * k, bz - 0.4 * k - math.sin(s * math.pi) * 1.2 * k + s * s * 1.6 * k,
                    max(0.6, 0.85 * k * (1 - 0.7 * s))))
    sweep(tail, pts, lambda s: col)
    ex, ey, ez = pts[-1][:3]
    for i in range(round(1.0 * k)):
        w = round(0.9 * k * (1 - i / max(1, 1.0 * k)))
        for dx in range(-w, w + 1):
            tail.put((round(ex) + dx, round(ey) + i, round(ez)), glow if glow is not None else accent, glow is not None)
    w = opts.get('wings', 'none' if False else 'bat')
    wc = cols.get('wing', accent)
    if pixie or w == 'butterfly':
        wing_butterfly(c, k * (0.9 if pixie else 1.1), (1.0 * k, 0.6 * k, round(bz + 1.0 * k)), 1.0, wc, light(wc, 0.4), glow=glow)
    elif w == 'bat':
        wing_bat(c, k, (1.4 * k, 0.4 * k, round(bz + (2.0 if kind == 'wyvern' else 1.2) * k)), 4.2 if kind != 'wyvern' else 5.0, dark(col, 0.2), wc, glow=glow, rise=1.4)
    c.gait_hint = KIND_GAIT.get(kind, 'trot')
    return c


# --------------------------------------------------------------------- dino

def dino(c, H, cols, opts):
    k = H / 10.0
    kind = opts['kind']
    col = cols['col']
    belly, accent, glow, iris = _cols(cols, col)
    hornc = cols.get('horn', hexc('#F5E9C8'))
    body = c.part('body')
    if kind in ('rex', 'raptor'):
        rex = kind == 'rex'
        top = (2.9 if rex else 3.2) * k
        for side in ('L', 'R'):
            p = leg(c, side, 0, 1, 1.2 * k, 0.8 * k, top, (0.85 if rex else 0.55) * k, col, toes=hornc, wide=0.25 * k)
            # a thick thigh
            x = 1.2 * k if side == 'R' else -1.2 * k
            p.ell((x, 0.9 * k, top - 0.6 * k), ((0.95 if rex else 0.7) * k, 1.2 * k, 1.0 * k), col)
        bz = top + 1.2 * k
        body.ell((0, 0.6 * k, bz), (1.7 * k, 2.5 * k, 1.7 * k), col)
        body.ell((0, -1.0 * k, bz + 1.3 * k), (1.3 * k, 1.4 * k, 1.6 * k), col)
        hy, hz = -2.4 * k, bz + 3.2 * k
        head = c.part('head', 'head', (0, -1.4 * k, bz + 2.2 * k))
        hr = (1.6, 2.1, 1.4) if rex else (1.2, 1.9, 1.1)
        head.ell((0, hy - 0.4 * k, hz), (hr[0] * k, hr[1] * k, hr[2] * k), col)
        head.ell((0, hy - 1.2 * k, hz - 0.9 * k), (hr[0] * 0.85 * k, hr[1] * 0.8 * k, 0.55 * k), col)
        # a toothy smile
        for x in range(-round(hr[0] * 0.8 * k), round(hr[0] * 0.8 * k)):
            f = head.front(x, round(hz - 0.6 * k))
            if f and (x % 2 == 0):
                head.put(f, WHITE)
        eye_pair(c, head, max(1, round(0.55 * k)), round(hz + 0.3 * k), max(2, round(0.4 * k)), iris=iris)
        # tiny arms
        for side in (1, -1):
            x = round(1.2 * k) if side > 0 else mx(round(1.2 * k))
            for i in range(round(1.0 * k)):
                body.put((x, round(-2.0 * k) - i // 2, round(bz + 0.6 * k) - i), col)
                body.put((x, round(-2.0 * k) - i // 2 + 1, round(bz + 0.6 * k) - i), col)
        tail = c.part('tail', 'tail', (0, 2.6 * k, bz))
        pts = [(0, 2.6 * k + s * 4.4 * k, bz - s * 1.6 * k + s * s * 0.6 * k, max(0.6, 1.2 * k * (1 - 0.8 * s))) for s in [i / 20 for i in range(21)]]
        sweep(tail, pts, lambda s: col)
        if kind == 'raptor':
            fe = c.part('feathers', 'static')
            for x in (0, -1):
                for y in range(round(-1.0 * k), round(4.0 * k)):
                    t = top_of(body, x, y)
                    if t is not None and y % 2 == 0:
                        fe.put((x, y, t + 1), accent)
        c.gait_hint = 'waddle'
    else:
        top = 2.5 * k
        for side in ('L', 'R'):
            for i, ly in enumerate((-1.6 * k, 2.4 * k)):
                leg(c, side, i, 2, 1.55 * k, ly, top, 0.8 * k, col, foot=dark(col, 0.25), foot_h=max(1, round(0.3 * k)), wide=0.2 * k)
        bz = top + 1.3 * k
        body.ell((0, 0.4 * k, bz), (2.1 * k, 3.3 * k, 1.9 * k), col)
        body.paint(lambda p, cc, g: (belly, False) if p[2] < bz - 0.6 * k else None)
        hy, hz = -3.4 * k, bz + 0.6 * k
        head = c.part('head', 'head', (0, -2.6 * k, bz + 0.4 * k))
        head.ell((0, hy, hz), (1.5 * k, 1.6 * k, 1.35 * k), col)
        head.ell((0, hy - 1.3 * k, hz - 0.4 * k), (0.9 * k, 0.8 * k, 0.75 * k), col)
        # a beak tip
        head.ell((0, hy - 2.0 * k, hz - 0.5 * k), (0.5 * k, 0.4 * k, 0.5 * k), dark(col, 0.35))
        eye_pair(c, head, max(1, round(0.6 * k)), round(hz + 0.15 * k), max(2, round(0.38 * k)), iris=iris)
        cheeks(head, round(1.1 * k), round(hz - 0.5 * k))
        tail = c.part('tail', 'tail', (0, 3.4 * k, bz))
        pts = [(0, 3.4 * k + s * 3.2 * k, bz - 0.2 * k - s * 1.4 * k, max(0.6, 1.1 * k * (1 - 0.8 * s))) for s in [i / 16 for i in range(17)]]
        sweep(tail, pts, lambda s: col)
        if kind == 'trike':
            fr = c.part('frill', 'glow' if glow is not None else 'static', (0, hy + 1.2 * k, hz + 0.8 * k))
            R = 2.4 * k
            for x in range(-round(R), round(R)):
                for z in range(0, round(R) + 1):
                    d = math.hypot(x + .5, z) / R
                    if d <= 1:
                        edge = d > 0.85
                        fr.put((x, round(hy + 1.3 * k + d * 0.6 * k), round(hz + 0.2 * k) + z), (glow if glow is not None else accent) if edge else accent, edge and glow is not None)
                        fr.put((x, round(hy + 1.3 * k + d * 0.6 * k) + 1, round(hz + 0.2 * k) + z), accent)
            hp = c.part('horns', 'glow' if glow is not None else 'static', (0, hy, hz + k))
            horn(hp, (0.75 * k, hy - 0.2 * k, hz + 1.1 * k), (1.0 * k, hy - 2.2 * k, hz + 2.2 * k), 0.4 * k, hornc,
                 glow if glow is not None else None, glow=glow is not None)
            horn(hp, (0, hy - 1.5 * k, hz + 0.2 * k), (0, hy - 2.3 * k, hz + 1.0 * k), 0.35 * k, hornc,
                 glow if glow is not None else None, glow=glow is not None, both=False)
        if kind == 'stego':
            pl = c.part('plates', 'glow' if glow is not None else 'static')
            for j, y in enumerate(range(round(-1.8 * k), round(5.4 * k), max(2, round(0.95 * k)))):
                src = body if y < 3.4 * k else tail
                xs = (0, -1)
                t = max((top_of(src, x, y) or -1) for x in xs)
                if t < 0:
                    continue
                h = round((1.0 + 0.9 * math.sin(min(1, (y + 1.8 * k) / (7.0 * k)) * math.pi)) * k)
                side = 1 if j % 2 else -1
                for i in range(h):
                    w = max(0, round((h - i) * 0.45))
                    for dy in range(-w, w + 1):
                        edge = glow is not None and i >= h - 2
                        pl.put((side * 0 - (1 if side < 0 else 0), y + dy, t + 1 + i), glow if edge else accent, edge)
            ty = round(6.0 * k)
            for side in (1, -1):
                x = round(0.4 * k) if side > 0 else mx(round(0.4 * k))
                t = top_of(tail, x, ty)
                if t is not None:  # thagomizer spikes standing on the tail
                    horn(tail, (x + .5 if side > 0 else x + .5, ty, t), (x + .5 + side * 0.9 * k, ty + 0.3 * k, t + 1.0 * k), 0.3 * k,
                         hornc, both=False)
        c.gait_hint = 'trot'
    return c


# --------------------------------------------------------- whale, ray, fish

def whale(c, H, cols, opts):
    """Floats a little off the ground, nose forward, fins and fluke move."""
    k = H / 10.0 * 1.1  # long and low: drawn bigger so it fills the tier's height
    kind = opts['kind']
    col = cols['col']
    belly, accent, glow, iris = _cols(cols, col, belly=hexc('#F4F7FF'))
    body = c.part('body')
    lift = 0.9 * k
    cz = lift + 2.6 * k
    L = {'whale': 3.6, 'orca': 3.4, 'narwhal': 3.2, 'dolphin': 3.0}[kind]
    R = {'whale': 2.5, 'orca': 2.3, 'narwhal': 2.1, 'dolphin': 1.8}[kind]
    for i in range(31):
        s = i / 30
        y = -L * k + s * 2 * L * k
        rr = R * k * math.sin(min(1.0, (s * 0.9 + 0.12)) * math.pi) ** 0.6
        body.ell((0, y, cz + (0.25 * k if s < 0.4 else 0) - s * 0.3 * k), (rr, 0.7, rr * 0.95), col)
    body.paint(lambda p, cc, g: (belly, False) if p[2] < cz - 0.5 * k else None)
    if kind == 'whale':  # throat grooves
        body.paint(lambda p, cc, g: (dark(belly, 0.15), False) if cc == belly and p[1] < 0 and abs(p[0] + .5) % max(2, round(0.5 * k)) < 1 else None)
    if kind == 'orca':
        body.paint(lambda p, cc, g: (WHITE, False) if p[1] < -1.6 * k and abs(p[0] + .5) > 1.0 * k and cz + 0.3 * k < p[2] < cz + 1.2 * k else None)
        body.paint(lambda p, cc, g: (hexc('#C8D0E0'), False) if 0.4 * k < p[1] < 1.6 * k and p[2] > cz + 1.6 * k else None)
    head = c.part('head', 'head', (0, -L * k * 0.4, cz))
    # the face is the front of the body: move the front cap into the head
    for p in [p for p in body.v if p[1] < -L * k * 0.45]:
        head.v[p] = body.v.pop(p)
    eye_pair(c, head, round(R * k * 0.55), round(cz - 0.1 * k), max(2, round(0.36 * k)), iris=iris)
    cheeks(head, round(R * k * 0.75), round(cz - 0.7 * k))
    if kind == 'dolphin':
        head.ell((0, -L * k - 0.6 * k, cz - 0.5 * k), (0.6 * k, 0.9 * k, 0.45 * k), light(col, 0.2))
    if kind == 'narwhal':
        tusk = c.part('tusk', 'glow' if glow is not None else 'static', (0, -L * k, cz + 0.4 * k))
        n = round(4.6 * k)
        tc = cols.get('horn', hexc('#FFF4D6'))
        for i in range(n):
            s = i / n
            r = max(1.0, 0.42 * k * (1 - 0.8 * s))
            y = -L * k + 0.4 * k - i
            tusk.ell((0, y, cz + 0.4 * k + i * 0.22), (r, 1.0, r), tc)
        # the spiral: a darker (or glowing) groove winding round the tusk
        sc = glow if glow is not None else dark(tc, 0.3)
        tusk.paint(lambda p, cc, g: (sc, glow is not None) if (p[1] + (p[0] + p[2]) % 3) % 3 == 0 else None)
    # dorsal fin and blowhole
    df = c.part('dorsal', 'static')
    fh = {'whale': 0.6, 'orca': 2.2, 'narwhal': 0.4, 'dolphin': 1.4}[kind] * k
    dy0 = round(0.6 * k)
    base = top_of(body, 0, dy0)
    base = base if base is not None else round(cz + R * k * 0.8)
    sail(df, 0, dy0, base + 1, max(2, fh * 1.1), fh, dark(col, 0.1), lean=0.7)
    if kind in ('whale', 'narwhal'):  # a blowhole just behind the head
        bh = top_of(body, 0, round(-L * k * 0.3))
        if bh is not None:
            for x in (0, -1):
                body.put((x, round(-L * k * 0.3), bh), dark(col, 0.45))
    fins(c, k, (R * k * 0.85, -0.6 * k, cz - 0.6 * k), 1.8 if kind == 'whale' else 1.3, 1.0, dark(col, 0.1) if kind != 'orca' else col, glow=glow, down=0.8)
    fluke(c, k, (0, L * k * 0.85, cz - 0.1 * k), 1.9 if kind == 'whale' else 1.5, 1.4, col, glow=glow)
    c.gait_hint = 'swim'
    return c


def ray(c, H, cols, opts):
    """A manta: a raised head with curled cephalic lobes, wide wing-fins
    (finL/finR) that flap, a white underside showing at the rim, spots
    on the back and a thin whip tail.

    A manta is wide and flat, so it has far more surface (and triangles) per
    stud of height than most plans: it scales 1.5x at Legendary size (H 34)
    and less at the smaller tiers, which keeps a Rare manta near 1 stud tall
    and inside the Rare triangle budget."""
    k = H / 10.0 * max(1.25, min(1.5, 1.5 - 0.022 * (34 - H)))
    col = cols['col']
    belly, accent, glow, iris = _cols(cols, col, belly=hexc('#F4F7FF'))
    body = c.part('body')
    cz = 2.2 * k
    body.ell((0, 0.2 * k, cz), (1.6 * k, 2.3 * k, 1.4 * k), col)
    body.paint(lambda p, cc, g: (belly, False) if p[2] < cz - 0.5 * k else None)
    spot = light(col, 0.35) if glow is None else glow
    for (px, py) in ((0.7, -0.4), (-0.7, -0.4), (0.0, 0.8), (0.9, 1.4), (-0.9, 1.4)):
        body.paint(lambda p, cc, g, px=px, py=py: (spot, glow is not None) if cc == col and p[2] > cz + 0.7 * k and
                   (p[0] + .5 - px * k) ** 2 + (p[1] + .5 - py * k) ** 2 < (0.32 * k) ** 2 else None)
    head = c.part('head', 'head', (0, -1.6 * k, cz))
    head.ell((0, -2.2 * k, cz + 0.45 * k), (1.35 * k, 1.0 * k, 1.2 * k), col)
    head.paint(lambda p, cc, g: (belly, False) if p[2] < cz - 0.1 * k else None)
    eye_pair(c, head, round(0.5 * k), round(cz + 0.55 * k), max(2, round(0.3 * k)), iris=iris)
    # the wide mouth under the eyes
    for x in range(-round(0.7 * k), round(0.7 * k)):
        f = head.front(x, round(cz - 0.25 * k))
        if f:
            head.put(f, dark(col, 0.55))
    # cephalic lobes: curled paddles either side of the mouth
    lobes = c.part('lobes', 'static')
    for side in (1, -1):
        pts = curve((side * 1.05 * k, -2.8 * k, cz - 0.1 * k), (side * 0.75 * k, -3.9 * k, cz + 0.2 * k), 8, (side * 0.3 * k, 0, 0.5 * k))
        for x, y, z in pts:
            lobes.ell((x - (0.5 if side < 0 else 0), y, z), (0.32 * k + .3, 0.32 * k + .3, 0.42 * k), dark(col, 0.15))
    # wings are the fins: wide triangles, thick at the root, white rim below
    # the wings are a little smaller than the body scale (k * 0.8) and thin,
    # so a manta keeps inside the lower tiers' triangle budgets
    kw = k * 0.8
    for sx, name in ((1, 'finR'), (-1, 'finL')):
        f = c.part(name, name, (sx * 1.3 * k, 0, cz))
        S = round(3.8 * kw)
        prev = 0
        for i in range(S):
            t = i / S
            front = -1.5 * k + t * t * 2.2 * k
            back = 1.7 * k - t * 1.5 * k
            x = round(1.2 * k) + i
            # the wings sweep up in a shallow V (they flap from there)
            lift = round(math.sin(t * math.pi * 0.5) * 1.9 * kw)
            # each column reaches down to the last one's top, so a steep
            # rise never leaves the wing tip loose
            thick = max(2 if t < 0.15 else 1, lift - prev + 1)
            prev = lift
            for y in range(math.floor(front), math.ceil(back) + 1):
                edge = y >= math.ceil(back) - 1 or i >= S - 2
                for dz in range(thick):
                    under = dz == thick - 1 and thick > 1
                    if glow is not None and edge and dz == 0:
                        colr, g = glow, True
                    else:
                        colr, g = (belly if under or (edge and dz == thick - 1) else col), False
                    f.put((x if sx > 0 else mx(x), y, round(cz) + lift - dz), colr, g)
    tail = c.part('tail', 'tail', (0, 2.3 * k, cz))
    prev = round(cz)
    for i in range(round(3.4 * k)):
        z = round(cz) - i // 6
        y = round(2.3 * k) + i
        # thick at the root; where the whip steps down a row it keeps the
        # row above too, so it stays one face-connected piece
        rows = {z, prev} | ({z + 1} if i < 1.2 * k else set())
        for zz in rows:
            tail.put((0, y, zz), dark(col, 0.2))
            tail.put((-1, y, zz), dark(col, 0.2))
        prev = z
    c.gait_hint = 'swim'
    return c


def fish_tail(c, k, root, length, spread, col, col2=None, glow=None, fork=0.35, veil=False):
    """The tail fin (part `tail`, pivot at its root), trailing behind (+y):
    a fan that opens as it goes back, a notch (fork) at the end and ray
    lines. `veil` makes a fancy goldfish's double tail: two lobes that
    spread out to the sides as well as up and down, drooping at the ends.
    Every row is a solid run that overlaps the row before (one piece)."""
    rx, ry, rz = root
    t = c.part('tail', 'tail', root)
    col2 = col2 or light(col, 0.3)
    L = max(3, round(length * k))
    for j in range(L):
        u = j / max(1, L - 1)
        h = 0.45 * k + spread * k * u ** 0.75
        sag = (0.9 * k * u * u) if veil else 0
        notch = fork * spread * k * max(0.0, (u - 0.5) / 0.5)
        if veil:
            # a fancy double tail: a wide fan that spreads out to both sides
            # and droops like a veil, two voxels thick, split at the end
            # two big rounded fans, one each side, splayed out in a V and
            # drooping a little: it reads from the front, side and back
            sag = 0.6 * k * u ** 1.5
            xo = 0.2 * k + 1.1 * k * u
            hh = 0.5 * k + spread * k * math.sin(min(1.0, u * 1.15) * math.pi * 0.5)
            lobe_cut = u > 0.6 and False
            for zz in range(-math.ceil(hh), math.ceil(hh) + 1):
                if abs(zz) > hh or lobe_cut:
                    continue
                if u > 0.62 and abs(zz) < notch * 0.7:
                    continue  # the notch between the upper and lower lobe
                edge = u > 0.86 or abs(zz) > hh - 1
                colr = col2 if edge else (dark(col, 0.1) if (zz % max(3, round(0.6 * k))) == 0 else col)
                g = glow is not None and edge
                z = math.floor(rz + zz - sag)
                xa = math.floor(xo)
                for x in range(0, xa + 2):  # from the middle out to this lobe: no gaps
                    if x < xa - 1 and u > 0.25:
                        continue
                    for xx in (x, -x - 1):
                        t.put((xx, math.floor(ry + j), z), glow if g else colr, g)
            continue
        for zz in range(-math.ceil(h), math.ceil(h) + 1):
            if abs(zz) > h or abs(zz) < notch:
                continue
            edge = u > 0.84 or abs(zz) > h - 1
            ray_line = (zz % max(2, round(0.5 * k))) == 0
            colr = col2 if edge else (dark(col, 0.1) if ray_line else col)
            g = glow is not None and edge
            for x in (0, -1):
                t.put((x, math.floor(ry + j), math.floor(rz + zz - sag)), glow if g else colr, g)
    return t


def sail(part, x0, y0, z0, length, height, col, edge=None, glow=False, up=1, lean=0.6):
    """A fin standing on the body along y0..y0+length at height z0: each
    layer up is a solid run, shorter and further back than the one below
    (`lean`), so it sweeps back and stays one face-connected piece. up=-1
    hangs it underneath."""
    H = max(1, round(height))
    L = max(2, round(length))
    for i in range(H):
        t = i / H
        front = y0 + i * lean
        back = y0 + L * (1 - 0.75 * t) + i * lean * 0.5
        if back < front + 1:
            back = front + 1
        last = i == H - 1
        for y in range(math.floor(front), math.ceil(back)):
            colr = edge if (edge is not None and (last or y == math.ceil(back) - 1)) else col
            g = glow and colr is edge
            for x in ((x0, -x0 - 1) if x0 >= 0 else (x0,)):
                part.put((x, y, round(z0 + up * i)), colr, g)


def fish(c, H, cols, opts):
    """A round, cute fish that floats a little off the floor and swims: a
    fan tail, sail fins on top (and below for angelfish), paddling side
    fins and big eyes set wide on the face."""
    # fish are short and long: drawn 1.4x bigger so their height uses the
    # tier's H like other creatures (otherwise a Common fish is a few voxels)
    k = H / 10.0 * 1.4
    kind = opts['kind']
    col = cols['col']
    belly, accent, glow, iris = _cols(cols, col)
    body = c.part('body')
    shape = {'koi': (1.35, 2.8, 1.45), 'angler': (2.2, 2.2, 2.0), 'angelfish': (0.95, 1.9, 2.0), 'shark': (1.45, 3.2, 1.5),
             'goldfish': (1.6, 1.9, 1.7)}[kind]
    rx, ry, rz = (v * k for v in shape)
    lift = (0.9 if kind != 'angelfish' else 1.5) * k  # floats about a third of its height up
    cz = lift + rz
    body.ell((0, 0, cz), (rx, ry, rz), col)
    if kind == 'shark':  # a pointed nose and a tapering back
        body.ell((0, -ry * 0.75, cz + 0.2 * k), (rx * 0.7, ry * 0.45, rz * 0.65), col)
    body.paint(lambda p, cc, g: (belly, False) if p[2] < cz - rz * 0.3 else None)
    # scales: a soft darker scallop every other row on the back
    sc = dark(col, 0.1)
    body.paint(lambda p, cc, g: (sc, False) if cc == col and p[2] > cz - rz * 0.2 and (p[1] + 2 * (p[2] // 2)) % 4 == 0 and p[2] % 2 == 0 else None)
    if kind == 'koi':
        for (px, py, pz, r) in ((0.6, -1.1, 0.9, 0.9), (-0.8, 0.5, 1.0, 1.0), (0.5, 1.8, 0.6, 0.7)):
            body.paint(lambda p, cc, g, px=px, py=py, pz=pz, r=r: (accent, False) if cc in (col, sc) and (
                (p[0] + .5 - px * k) ** 2 + (p[1] + .5 - py * k) ** 2 + (p[2] + .5 - cz - pz * k) ** 2) < (r * k) ** 2 else None)
    if kind == 'angelfish':  # bold vertical bands
        body.paint(lambda p, cc, g: (accent, False) if cc in (col, sc) and int((p[1] + 0.3 * k) // max(2, round(0.55 * k))) % 3 == 0 else None)
    head = c.part('head', 'head', (0, -ry * 0.45, cz))
    for p in [p for p in body.v if p[1] < -ry * 0.5]:
        head.v[p] = body.v.pop(p)
    # gill line behind the face
    gy = round(-ry * 0.5)
    for p in [p for p in head.v if p[1] == gy and abs(p[2] - cz) < rz * 0.6]:
        head.v[p] = (dark(col, 0.2), False)
    if kind == 'angler':
        head.ell((0, -ry * 0.72, cz - rz * 0.35), (rx * 0.92, ry * 0.42, rz * 0.42), dark(col, 0.25))
        for x in range(-round(rx * 0.8), round(rx * 0.8)):
            f = head.front(x, round(cz - rz * 0.15))
            if f and x % 2 == 0:
                head.put(f, WHITE)
                head.put((f[0], f[1], f[2] - 1), WHITE)
    es = max(2, round(0.34 * k))
    eye_pair(c, head, round(rx * 0.42), round(cz + rz * 0.12), es, iris=iris)
    if kind in ('goldfish', 'koi'):
        cheeks(head, round(rx * 0.62), round(cz - rz * 0.3))
        # a little round mouth
        f = head.front(0, round(cz - rz * 0.35)) or head.front(-1, round(cz - rz * 0.35))
        if f:
            head.put(f, dark(col, 0.45))
            head.put((-f[0] - 1, f[1], f[2]), dark(col, 0.45))
    if kind == 'shark':
        for x in range(-round(rx * 0.55), round(rx * 0.55)):
            f = head.front(x, round(cz - rz * 0.5))
            if f:
                head.put(f, WHITE if x % 2 else dark(col, 0.5))
    finc = accent if kind not in ('koi',) else light(col, 0.2)
    fins(c, k, (rx * 0.8, -0.3 * k, cz - rz * 0.35), 1.5, 1.1, finc, glow=glow, down=0.7, thick=1)
    df = c.part('dorsal', 'static')
    dh = {'koi': 1.0, 'angler': 0.9, 'angelfish': 3.0, 'shark': 2.0, 'goldfish': 1.3}[kind] * k
    dl = {'koi': 2.6, 'angler': 1.6, 'angelfish': 2.0, 'shark': 1.6, 'goldfish': 2.0}[kind] * k
    top_z = max(p[2] for p in body.v)
    sail(df, 0, -0.5 * k, top_z, dl, dh, finc, edge=glow if glow is not None else light(finc, 0.3), glow=glow is not None,
         lean=0.9 if kind == 'shark' else (1.1 if kind == 'angelfish' else 0.6))
    if kind == 'angelfish':
        low_z = min(p[2] for p in body.v)
        sail(c.part('fin_low', 'static'), 0, -0.2 * k, low_z, 1.9 * k, 2.6 * k, finc, edge=light(finc, 0.3), up=-1, lean=1.1)
    tl = {'koi': (1.6, 1.4, 0.4, False), 'angler': (1.3, 1.2, 0.3, False), 'angelfish': (1.4, 1.5, 0.3, False),
          'shark': (1.8, 1.7, 0.5, False), 'goldfish': (2.4, 1.6, 0.45, True)}[kind]
    tail_col = accent if kind in ('goldfish', 'koi', 'angelfish') else col
    fish_tail(c, k, (0, ry * 0.85, cz), tl[0], tl[1], tail_col, light(tail_col, 0.35), glow=glow, fork=tl[2], veil=tl[3])
    c.gait_hint = 'swim'
    return c


# ------------------------------------------------------------------ serpent

def serpent(c, H, cols, opts):
    """A coiled serpent: a ring of coils on the ground, rising into an S
    neck; slithers. heads=3 adds two side heads on their own necks."""
    k = H / 10.0
    kind = opts['kind']
    col = cols['col']
    belly, accent, glow, iris = _cols(cols, col)
    body = c.part('body')
    pts = []
    n = 60
    for i in range(n + 1):
        s = i / n
        if s < 0.62:  # the coil on the ground, tail to front
            a = s / 0.62 * math.pi * 2.0 + math.pi * 0.5
            rr = 2.6 * k * (0.7 + 0.3 * s / 0.62)
            x, y, z = math.cos(a) * rr, math.sin(a) * rr * 0.9 + 0.8 * k, 0.9 * k + s * 0.9 * k
            r = (0.45 + 0.75 * s / 0.62) * k
        else:  # rising neck
            u = (s - 0.62) / 0.38
            x = 0.4 * k * math.sin(u * math.pi)
            y = -1.4 * k - u * 1.0 * k + math.sin(u * math.pi) * 0.9 * k
            z = 1.5 * k + u * 5.0 * k
            r = (1.2 - 0.25 * u) * k
        pts.append((x, y, max(r, z), r))
    # the coil's thin end is its own tail part (it sways), hinged where it
    # joins the rest of the coil
    cut = round(n * 0.2)
    tail = c.part('tail', 'tail', pts[cut][:3])
    for i, (x, y, z, r) in enumerate(pts):
        (tail if i <= cut else body).ell((x, y, z), (r, r, r), col)
    # belly scales: a lighter stripe on the inside of the neck and coil
    body.paint(lambda p, cc, g: (belly, False) if cc == col and (p[2] < 0.6 * k or (p[1] < -1.8 * k and p[2] > 1.6 * k)) else None)
    body.paint(lambda p, cc, g: (dark(col, 0.18), False) if cc == col and (p[0] * 3 + p[1] * 5 + p[2] * 7) % 13 == 0 else None)
    tail.paint(lambda p, cc, g: (belly, False) if cc == col and p[2] < 0.6 * k else None)
    tail.paint(lambda p, cc, g: (dark(col, 0.18), False) if cc == col and (p[0] * 3 + p[1] * 5 + p[2] * 7) % 13 == 0 else None)
    hx, hy, hz = pts[-1][0], pts[-1][1] - 0.6 * k, pts[-1][2] + 0.6 * k
    head = c.part('head', 'head', (hx, hy + 0.6 * k, hz - 0.6 * k))
    _serpent_head(c, head, k, hx, hy, hz, col, belly, iris, kind, 1.0)
    if opts.get('heads', 1) == 3:
        for side, name in ((1, 'headR'), (-1, 'headL')):
            neck = []
            for i in range(14):
                u = i / 13
                neck.append((side * (0.8 + 1.8 * u) * k, -0.9 * k - u * 0.9 * k, 2.0 * k + u * 3.4 * k, (0.95 - 0.2 * u) * k))
            for x, y, z, r in neck:
                body.ell((x, y, z), (r, r, r), col)
            sx, sy, sz = neck[-1][0], neck[-1][1] - 0.5 * k, neck[-1][2] + 0.5 * k
            h2 = c.part(name, 'head', (sx, sy + 0.5 * k, sz - 0.5 * k))
            _serpent_head(c, h2, k, sx, sy, sz, col, belly, iris, kind, 0.8)
    if opts.get('frills') or kind == 'cobra':
        fr = c.part('frill', 'static')
        for i, (x, y, z, r) in enumerate(pts[n - 12:n - 2]):
            w = (1.4 + 1.2 * math.sin(i / 9 * math.pi)) * k if kind == 'cobra' else 0.6 * k
            fr.ell((x, y + 0.4 * k, z), (r + w, 0.6, r * 0.7), accent)
    # spine fins along the coil
    sp = c.part('spines', 'glow' if glow is not None else 'static')
    for (x, y, z, r) in pts[4:-6:3]:
        for i in range(max(1, round(0.5 * k))):
            sp.put((math.floor(x), math.floor(y), math.floor(z + r) + i), glow if glow is not None else accent, glow is not None)
    c.gait_hint = 'slither'
    return c


def _serpent_head(c, head, k, hx, hy, hz, col, belly, iris, kind, s):
    head.ell((hx, hy, hz), (1.35 * k * s, 1.6 * k * s, 1.15 * k * s), col)
    head.ell((hx, hy - 1.2 * k * s, hz - 0.35 * k * s), (0.9 * k * s, 0.9 * k * s, 0.65 * k * s), col)
    head.paint(lambda p, cc, g: (belly, False) if p[2] < hz - 0.6 * k * s else None)
    es = max(2, round(0.36 * k * s))
    e = c.part('eyes', 'blink', head.pivot)
    for sx in (1, -1):
        for dx in range(es):
            for dz in range(es + 1):
                x = math.floor(hx + 0.45 * k * s + dx) if sx > 0 else math.floor(hx - 0.45 * k * s - dx) - 1
                f = head.front(x, round(hz + 0.1 * k * s) + dz)
                if f:
                    del head.v[f]
                    e.put(f, WHITE if (dz == es and dx == es - 1) else iris)
    # a forked tongue
    f = head.front(math.floor(hx), round(hz - 0.6 * k * s))
    if f:
        n = max(2, round(0.6 * k * s))
        for i in range(n):
            head.put((f[0], f[1] - 1 - i, f[2]), hexc('#FF4D6D'))
        for dx in (-1, 1):  # the fork: a prong each side of the tip, then forward
            head.put((f[0] + dx, f[1] - n, f[2]), hexc('#FF4D6D'))
            head.put((f[0] + dx, f[1] - n - 1, f[2]), hexc('#FF4D6D'))


# ------------------------------------------------------------------ upright

def upright(c, H, cols, opts):
    """Stands on two legs with arms at its sides (the arms ride the body)."""
    k = H / 10.0
    kind = opts['kind']
    col = cols['col']
    belly, accent, glow, iris = _cols(cols, col)
    body = c.part('body')
    if kind == 'seahorse':
        return _seahorse(c, k, col, belly, accent, glow, iris)
    if kind == 'mushroom':
        return _mushroom(c, k, col, belly, accent, glow, iris, opts)
    if kind == 'golem':
        return _golem(c, k, col, belly, accent, glow, iris)
    big = kind in ('golem', 'giant', 'treant', 'gorilla')
    small = kind in ('sprite', 'gnome', 'imp')
    top = (2.2 if big else 1.6 if small else 1.9) * k
    lr = (0.9 if big else 0.6) * k
    for side in ('L', 'R'):
        leg(c, side, 0, 1, (1.1 if big else 0.85) * k, 0.4 * k, top, lr, dark(col, 0.12) if kind != 'treant' else dark(col, 0.2),
            foot=dark(col, 0.35), foot_h=max(1, round(0.35 * k)), wide=0.2 * k)
    bz = top + (1.9 if big else 1.6) * k
    br = (2.2, 1.7, 2.1) if big else (1.6, 1.4, 1.7) if not small else (1.4, 1.2, 1.4)
    if kind == 'golem':
        body.box((round(-br[0] * k), round(-br[1] * k), round(top - 0.2 * k)), (round(br[0] * k) - 1, round(br[1] * k), round(bz + br[2] * k)), col)
        body.ell((0, 0, bz), (br[0] * k + 0.6, br[1] * k + 0.6, br[2] * k), col)
    else:
        body.ell((0, 0, bz), (br[0] * k, br[1] * k, br[2] * k), col)
    body.paint(lambda p, cc, g: (belly, False) if p[1] < -br[1] * k * 0.5 and abs(p[0] + .5) < br[0] * k * 0.55 and p[2] < bz + 0.6 * k and cc == col else None)
    # arms hang from the shoulders
    for side in (1, -1):
        sxp = side * (br[0] + 0.3) * k
        pts = curve((sxp, 0, bz + br[2] * k * 0.6), (side * (br[0] + 0.6) * k, -0.4 * k, top + 0.4 * k), 10, (side * 0.5 * k, 0, 0))
        for i, (x, y, z) in enumerate(pts):
            rr = (0.75 if big else 0.5) * k * (1 + 0.25 * (i / 10))
            body.ell((x - (0.5 if side < 0 else 0), y, z), (rr, rr, rr), col if kind != 'golem' else dark(col, 0.1))
    hz = bz + br[2] * k + (1.1 if big else 1.4) * k
    head = c.part('head', 'head', (0, 0, bz + br[2] * k))
    hr = (1.5, 1.4, 1.3) if big else (1.6, 1.5, 1.5)
    if kind == 'golem':
        head.box((round(-hr[0] * k), round(-hr[1] * k), round(hz - hr[2] * k)), (round(hr[0] * k) - 1, round(hr[1] * k), round(hz + hr[2] * k)), col)
    else:
        head.ell((0, -0.3 * k, hz), (hr[0] * k, hr[1] * k, hr[2] * k), col)
    ez = hz - 0.1 * k
    esize = max(2, round(0.4 * k))
    if kind in ('gorilla', 'cub'):
        snout = cols.get('snout', light(col, 0.4))
        if kind == 'gorilla':
            # a pale face mask so the dark eyes read, a heavy brow ridge
            # just above them and the muzzle below
            ez = hz - 0.25 * k
            head.ell((0, -1.3 * k, hz - 0.2 * k), (1.35 * k, 0.45 * k, 0.95 * k), snout)
            head.ell((0, -1.4 * k, round(ez) + esize + 1.5), (1.05 * k, 0.45 * k, 0.75), dark(col, 0.2))
            head.ell((0, -1.4 * k, hz - 0.95 * k), (0.95 * k, 0.55 * k, 0.45 * k), snout)
        else:
            ez = hz + 0.1 * k
            # a muzzle low on the face, below the eyes (not over them)
            head.ell((0, -1.35 * k, hz - 0.75 * k), (0.95 * k, 0.55 * k, 0.5 * k), snout)
    eye_pair(c, head, max(1, round(0.5 * k)), round(ez), esize, iris=iris,
             glow=kind in ('golem',) and glow is not None)
    if kind in ('cub', 'gnome', 'sprite', 'gorilla'):
        cheeks(head, round(1.1 * k), round(hz - 0.6 * k))
    ears = c.part('ears', 'ears', (0, -0.3 * k, hz + hr[2] * k))
    if kind in ('imp', 'sprite'):
        for i in range(round(1.4 * k)):
            ears.put((round(1.4 * k) + i, round(-0.3 * k), round(hz + 0.2 * k) + i // 2), col)
            ears.put((mx(round(1.4 * k) + i), round(-0.3 * k), round(hz + 0.2 * k) + i // 2), col)
    if kind == 'cub':
        ears.ell((1.2 * k, -0.2 * k, hz + 1.2 * k), (0.5 * k, 0.35 * k, 0.5 * k), col)
        ears.ell((mx(1.2 * k) + 1, -0.2 * k, hz + 1.2 * k), (0.5 * k, 0.35 * k, 0.5 * k), col)
    if kind == 'imp':
        hp = c.part('horns', 'static')
        horn(hp, (0.8 * k, -0.2 * k, hz + 1.0 * k), (1.2 * k, 0.3 * k, hz + 2.2 * k), 0.35 * k, cols.get('horn', dark(col, 0.4)))
    hat = opts.get('hat', 'cone' if kind == 'gnome' else 'none')
    if hat == 'cone':
        hp = c.part('hat', 'static')
        for i in range(round(3.0 * k)):
            r = max(0.6, 1.6 * k * (1 - i / (3.0 * k)))
            hp.ell((0, -0.2 * k + i * 0.1, hz + 0.6 * k + i), (r, r, 0.5), accent)
    elif hat == 'crown':
        _crown(c.part('crown', 'glow' if glow is not None else 'static', (0, 0, hz + hr[2] * k)), k, 0, -0.3 * k, hz + hr[2] * k - 0.3 * k,
               1.0 * k, cols.get('horn', hexc('#FFC21A')), glow is not None)
    if opts.get('wings', 'sprite' == kind and 'fairy' or 'none') == 'fairy':
        wing_butterfly(c, k * 0.9, (0.8 * k, 1.2 * k, round(bz + 0.6 * k)), 1.0, cols.get('wing', light(accent, 0.4)), light(accent, 0.7), glow=glow)
    c.gait_hint = KIND_GAIT.get(kind, 'waddle')
    return c


def _golem(c, k, col, belly, accent, glow, iris):
    """A hulking block golem: a barrel chest and shoulders far wider than the
    head (and deep: at least 60% as deep as wide), thick blocky arms hanging
    to big fists, short heavy legs and a small rock head jutting forward
    between the shoulders. c.joints lists the shoulder, elbow and knee
    points; c.undersides the voxels under which drips can hang."""
    u = k * 1.4
    body = c.part('body')
    top = round(1.25 * u)
    dk = dark(col, 0.12)
    for side in ('L', 'R'):
        leg(c, side, 0, 1, 0.85 * u, 0.1 * u, top, 0.75 * u, dk, foot=dark(col, 0.3), foot_h=max(1, round(0.3 * u)), wide=0.2 * u,
            ry=0.9 * u)
    # torso: a deep barrel, wider and deeper at the chest
    t0, t1 = top - round(0.2 * u), top + round(2.7 * u)
    body.box((-round(1.5 * u), -round(1.45 * u), t0), (round(1.5 * u) - 1, round(1.45 * u), t1), col)
    body.box((-round(1.9 * u), -round(1.75 * u), top + round(1.4 * u)), (round(1.9 * u) - 1, round(1.6 * u), t1), col)
    # a lighter chest plate
    body.box((-round(1.1 * u), -round(1.75 * u) - 1, top + round(1.0 * u)), (round(1.1 * u) - 1, -round(1.75 * u) - 1, t1 - round(0.4 * u)),
             belly)
    joints = []
    for sx in (1, -1):
        def bx(x0, x1, y0, y1, z0, z1, cc):
            a, b = (round(x0), round(x1) - 1) if sx > 0 else (mx(round(x1) - 1), mx(round(x0)))
            body.box((a, round(y0), round(z0)), (b, round(y1), round(z1)), cc)
        # shoulder boulder, upper arm, forearm and a big fist
        bx(1.7 * u, 2.95 * u, -1.25 * u, 1.1 * u, t1 - 1.0 * u, t1 + 0.4 * u, col)
        bx(2.0 * u, 2.8 * u, -0.8 * u, 0.8 * u, top + 0.7 * u, t1 - 0.8 * u, dk)
        bx(1.95 * u, 2.95 * u, -1.0 * u, 0.8 * u, top - 0.3 * u, top + 0.9 * u, col)
        bx(1.85 * u, 3.1 * u, -1.2 * u, 0.9 * u, top - 1.0 * u, top - 0.1 * u, dark(col, 0.2))
        joints += [(sx * 2.4 * u, -1.3 * u, t1 - 0.6 * u), (sx * 2.45 * u, -1.05 * u, top + 0.75 * u),
                   (sx * 0.85 * u, -0.95 * u, top * 0.5)]
    # small rock head jutting forward between the shoulders, a heavy brow
    # over glowing eyes; a darker rock than the body so it reads apart
    hz0, hz1 = t1 - round(0.3 * u), t1 + round(1.25 * u)
    head = c.part('head', 'head', (0, -0.6 * u, t1))
    hc = dark(col, 0.18)
    head.box((-round(0.8 * u), -round(2.05 * u), hz0), (round(0.8 * u) - 1, -round(0.4 * u), hz1), hc)
    head.box((-round(0.95 * u), -round(2.15 * u), hz1 - round(0.5 * u)), (round(0.95 * u) - 1, -round(1.9 * u), hz1 - round(0.3 * u)),
             dark(col, 0.35))
    eye_pair(c, head, max(1, round(0.3 * u)), hz1 - round(0.85 * u), max(2, round(0.3 * u)), iris=iris, glow=glow is not None, tall=0)
    c.joints = joints
    c.gait_hint = KIND_GAIT.get('golem', 'waddle')
    return c


def _crown(part, k, x, y, z, R, gold, glow, gems=(hexc('#FF3B5C'), hexc('#3FA9FF'), hexc('#3FE08A'))):
    n = 40
    for a in range(n):
        ang = a / n * math.pi * 2
        px, py = round(x + math.cos(ang) * R), round(y + math.sin(ang) * R)
        part.put((px, py, round(z)), dark(gold, 0.15), glow)
        part.put((px, py, round(z) + 1), gold, glow)
        if a % 5 == 0:
            for h in range(2, 2 + max(2, round(0.5 * k))):
                part.put((px, py, round(z) + h), gold, glow)
        if a % 10 == 5:
            part.put((px, py, round(z) + 1), gems[(a // 10) % len(gems)], glow)


def _seahorse(c, k, col, belly, accent, glow, iris):
    body = c.part('body')
    cz0 = 1.6 * k
    pts = []
    for i in range(30):
        s = i / 29
        y = 0.6 * k * math.sin(s * math.pi * 1.1) - 0.4 * k
        z = cz0 + s * 6.0 * k
        r = (0.9 + 0.9 * math.sin(min(1, s * 1.3) * math.pi)) * k * (1 if s > 0.15 else 0.6 + s * 2.6)
        pts.append((0, y, z, r))
    for x, y, z, r in pts:
        body.ell((x, y, z), (r * 0.85, r, r * 0.6), col)
    body.paint(lambda p, cc, g: (belly, False) if p[1] < -0.9 * k and cc == col else None)
    body.paint(lambda p, cc, g: (dark(belly, 0.15), False) if cc == belly and p[2] % max(2, round(0.5 * k)) == 0 else None)
    # the curled tail: down from the body, then rolling forward under the
    # belly into a tight spiral (a seahorse reads by it)
    tail = c.part('tail', 'tail', (0, -0.4 * k, cz0))
    R0, cy, czc = 1.35 * k, -0.35 * k, 1.35 * k
    pts = []
    n = 40
    for i in range(n + 1):
        t = i / n
        th = math.pi / 2 - t * 3.3 * math.pi
        R = R0 * (1 - 0.68 * t)
        pts.append((0, cy + R * math.cos(th), czc + R * math.sin(th) + (0.5 * k * (1 - t) if t < 0.25 else 0),
                    max(0.6, 0.55 * k * (1 - 0.6 * t))))
    sweep(tail, pts, lambda s: col if s < 0.85 else dark(col, 0.12))
    tail.paint(lambda p, cc, g: (dark(col, 0.12), False) if cc == col and p[2] % max(2, round(0.45 * k)) == 0 else None)
    hz = cz0 + 6.4 * k
    head = c.part('head', 'head', (0, -0.6 * k, hz - 0.8 * k))
    head.ell((0, -0.9 * k, hz), (1.1 * k, 1.4 * k, 1.1 * k), col)
    # the long snout
    for i in range(round(1.8 * k)):
        head.ell((0, -2.0 * k - i, hz - 0.3 * k - i * 0.12), (0.45 * k, 0.6, 0.45 * k), col)
    eye_pair(c, head, round(0.4 * k), round(hz + 0.1 * k), max(2, round(0.35 * k)), iris=iris)
    # back fin flutters (as a wing), and the coronet on the head
    for sx, name in ((1, 'finR'), (-1, 'finL')):
        f = c.part(name, name, (sx * 0.8 * k, 1.0 * k, cz0 + 3.0 * k))
        for i in range(round(1.4 * k)):
            for j in range(round(1.6 * k)):
                f.put(((round(0.9 * k) + i) if sx > 0 else mx(round(0.9 * k) + i), round(0.9 * k) + j // 2, round(cz0 + 2.4 * k) + j),
                      glow if glow is not None and i == round(1.4 * k) - 1 else accent, glow is not None and i == round(1.4 * k) - 1)
    c.gait_hint = 'swim'
    return c


def _mushroom(c, k, col, belly, accent, glow, iris, opts):
    body = c.part('body')
    stem = cols_stem = belly
    top = 1.6 * k
    for side in ('L', 'R'):
        leg(c, side, 0, 1, 0.8 * k, 0.2 * k, top, 0.6 * k, dark(stem, 0.15), foot=dark(stem, 0.4), foot_h=max(1, round(0.3 * k)), wide=0.2 * k)
    bz = top + 1.8 * k
    body.ell((0, 0, bz), (1.5 * k, 1.3 * k, 2.0 * k), stem)
    head = c.part('head', 'head', (0, 0, bz + 1.5 * k))
    # the face is on the stem, under the cap
    head.ell((0, 0, bz + 1.6 * k), (1.45 * k, 1.25 * k, 1.0 * k), stem)
    eye_pair(c, head, max(1, round(0.45 * k)), round(bz + 1.4 * k), max(2, round(0.38 * k)), iris=iris)
    cheeks(head, round(1.0 * k), round(bz + 0.9 * k))
    cap = c.part('cap', 'static', (0, 0, bz + 2.4 * k))
    cap.ell((0, 0, bz + 2.6 * k), (3.0 * k, 2.8 * k, 1.8 * k), col, cond=lambda x, y, z: z >= round(bz + 2.3 * k))
    cap.paint(lambda p, cc, g: (dark(col, 0.25), False) if p[2] <= round(bz + 2.4 * k) else None)
    for (px, py, r) in ((0.0, -1.6, 0.55), (1.5, -0.6, 0.45), (-1.5, -0.6, 0.45), (0.9, 1.2, 0.5), (-1.0, 1.4, 0.45), (0.0, 0.0, 0.6)):
        cap.paint(lambda p, cc, g, px=px, py=py, r=r: (accent, False) if cc == col and (p[0] + .5 - px * k) ** 2 + (p[1] + .5 - py * k) ** 2 < (r * k) ** 2 else None)
    for side in (1, -1):
        pts = curve((side * 1.4 * k, 0, bz + 0.6 * k), (side * 2.0 * k, -0.6 * k, bz - 1.0 * k), 8, (side * 0.3 * k, 0, 0))
        for x, y, z in pts:
            body.ell((x - (0.5 if side < 0 else 0), y, z), (0.45 * k,) * 3, stem)
    if opts.get('hat') == 'crown':
        _crown(c.part('crown', 'glow' if glow is not None else 'static', (0, 0, bz + 4.2 * k)), k, 0, 0, bz + 4.3 * k, 1.0 * k,
               hexc('#FFC21A'), glow is not None)
    c.gait_hint = 'waddle'
    return c


BUILDERS_BY_PLAN = {'beast': beast, 'drake': drake, 'dino': dino, 'whale': whale, 'ray': ray, 'fish': fish,
                    'serpent': serpent, 'upright': upright}


def _builder(plan):
    def build(c, H, cols, opts):
        kind = opts.get('kind')
        if (plan, kind) in EXTRA:
            k = H / 10.0
            EXTRA[(plan, kind)](c, k, cols, opts)
            c.gait_hint = getattr(c, 'gait_hint', None) or KIND_GAIT.get(kind) or GAIT[plan]
            return c
        return BUILDERS_BY_PLAN[plan](c, H, cols, opts)
    return build


PLANS = {plan: (set(COLOURS), dict({'kind': set(kinds)}, **OPTIONS[plan])) for plan, kinds in KINDS.items()}
BUILDERS = {plan: _builder(plan) for plan in KINDS}
