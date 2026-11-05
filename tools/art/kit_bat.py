"""The `bat` body plan: a round furry body with a big-eared head and two
leathery wings that flap (wingL / wingR), for bats and baby pterosaurs.
Used by roster entries like the plans in kit.py (see variants.py):

    {"id": "FruitBat", "rarity": "Uncommon", "plan": "bat", "gait": "hover",
     "colors": {"col": "#7A4A2E", "wing": "#4A2E22", "belly": "#C98A55"},
     "options": {"face": "fox", "hold": "berry", "wrap": true}}

Colours: col (fur), wing (the membrane), belly, accent (the arm and finger
bones; default a darker wing), ear (inside the ears), cape and lining (the
cape option), crest and beak (the ptero kind).

Options:
- kind: bat (default) or ptero (a baby pterosaur: no ears, a long beak, a
  crest swept back off the head, smooth wings from one long finger).
- face: fox (a pointed fox muzzle, default) or pug (a flat little nose).
- cape: true for a tiny high-collared cape on the back (cape / lining).
- fangs: true for two little white fangs.
- hold: berry (a berry held under the chin).
- wrap: true holds the wing tips forward round the body, like a cape.
- mask: true paints a pale mask (colour `mask`) round the eyes, so they read
  on a dark face.
- colours: `berry` sets the held berry's colour (clear red by default).

Same art frame as kit.py (x right, y back, front is -y, z up) and scale
(k = H / 10). The wings are their own parts hinged at the shoulder, so the
game flaps them as the bat hovers; the gait is hover."""
import math

from voxkit import hexc

INK, WHITE = hexc('#1B1B2F'), hexc('#FFFFFF')
KINDS = {'bat', 'ptero'}

PLANS = {
    'bat': (
        {'col', 'wing', 'belly', 'accent', 'ear', 'cape', 'lining', 'crest', 'beak', 'mask', 'berry'},
        {'kind': KINDS, 'face': {'fox', 'pug'}, 'cape': {True, False}, 'fangs': {True, False},
         'hold': {'berry'}, 'wrap': {True, False}, 'mask': {True, False}},
    ),
}


def gait(opts):
    return 'hover'


def dark(col, t=0.3):
    return tuple(round(c * (1 - t)) for c in col)


def light(col, t=0.35):
    return tuple(round(c + (255 - c) * t) for c in col)


def _ell(part, c, r, col, cond=None):
    part.ell(c, r, col, cond=cond)


def _tube(part, pts, r0, r1, col, colfn=None):
    """Balls along a polyline, radius r0 to r1."""
    total = sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1)) or 1
    run = 0.0
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        seg = math.dist(a, b)
        n = max(1, math.ceil(seg * 2))
        for j in range(n + 1):
            t = (run + seg * j / n) / total
            p = tuple(a[q] + (b[q] - a[q]) * j / n for q in range(3))
            r = max(0.5, r0 + (r1 - r0) * t)
            cc = colfn(t) if colfn else col
            part.ell(p, (r, r, r), cc)
        run += seg


def _mirror(part):
    """Keeps a part exactly symmetric: its right half copied to the left."""
    right = {p: v for p, v in part.v.items() if p[0] >= 0}
    part.v = dict(right)
    for (x, y, z), v in right.items():
        part.v[(-x - 1, y, z)] = v


def bat(c, H, cols, opts):
    from creatures import eyes
    k = H / 10.0
    kind = opts.get('kind', 'bat')
    col = cols['col']
    wing = cols.get('wing') or dark(col, 0.35)
    bone = cols.get('accent') or dark(wing, 0.35)
    belly = cols.get('belly') or light(col, 0.3)
    ptero = kind == 'ptero'

    body = c.part('body')
    # a round body, a little longer than wide, its belly paler
    bz = 3.4 * k
    if ptero:
        body.ell((0, 0.5 * k, bz), (1.2 * k, 1.5 * k, 1.3 * k), col)
    else:
        body.ell((0, 0.4 * k, bz), (1.5 * k, 1.35 * k, 1.7 * k), col)
    body.paint(lambda p, cc, g: (belly, False) if p[1] < 0.1 * k and abs(p[0] + .5) < 1.0 * k else None)

    hz = bz + (2.0 if not ptero else 1.6) * k
    head = c.part('head', 'static', (0, -0.6 * k, hz - 1.0 * k))
    if ptero:
        head.ell((0, -1.0 * k, hz), (1.05 * k, 1.35 * k, 1.05 * k), col)
        beak = cols.get('beak') or hexc('#F2C14E')
        # a long tapering beak, slightly down-turned
        _tube(head, [(0, -2.0 * k, hz - 0.2 * k), (0, -3.3 * k, hz - 0.4 * k), (0, -4.5 * k, hz - 0.8 * k)],
              0.55 * k, 0.2 * k, beak)
        crest = cols.get('crest') or light(col, 0.25)
        # the crest: a flat blade swept back off the top of the head
        _tube(head, [(0, -0.6 * k, hz + 0.8 * k), (0, 0.6 * k, hz + 1.6 * k), (0, 1.8 * k, hz + 2.2 * k)],
              0.55 * k, 0.2 * k, crest)
        for p in list(head.v):
            if head.v[p][0] == crest and abs(p[0] + .5) > 0.6:
                del head.v[p]
        eyes(c, head, max(0 if k < 1.2 else 1, round(0.55 * k)), round(hz + 0.1 * k), max(1, math.ceil(0.55 * k)))
    else:
        head.ell((0, -0.9 * k, hz), (1.55 * k, 1.3 * k, 1.35 * k), col)
        face = opts.get('face', 'fox')
        if face == 'fox':
            # a pointed fox muzzle with a dark nose
            _tube(head, [(0, -1.9 * k, hz - 0.35 * k), (0, -2.7 * k, hz - 0.45 * k)], 0.75 * k, 0.4 * k, belly)
            ny = min(p[1] for p in head.v if abs(p[0] + .5) < 1)
            for x in (-1, 0):
                head.put((x, ny, round(hz - 0.35 * k)), INK)
        else:
            # a flat pug nose: two dark nostrils on a pale pad
            f = [p for p in head.v if abs(p[0] + .5) < 1.0 and abs(p[2] + .5 - (hz - 0.3 * k)) < 0.7 * k + .5]
            ny = min(p[1] for p in f)
            for p in f:
                if p[1] == ny:
                    head.put((p[0], ny - 1, p[2]), belly)
            for x in (-1, 0):
                head.put((x, ny - 1, round(hz - 0.2 * k)), INK)
        if opts.get('fangs'):
            mz = round(hz - 0.9 * k)
            fy = min(p[1] for p in head.v if p[2] <= mz + 1 and abs(p[0] + .5) < 1.5)
            for x in (-1, 0):
                xx = x * 2 + (1 if x == 0 else 0) if k >= 1.5 else x
                head.put((xx, fy, mz - 1), WHITE)
        if opts.get('mask'):
            # a pale mask round the eyes, so dark eyes read on a dark face
            mask = cols.get('mask') or light(col, 0.5)
            ez = hz + 0.15 * k + 0.3 * k
            for p in list(head.v):
                if p[1] < -0.9 * k - 0.4 * k and abs(abs(p[0] + .5) - 0.75 * k) < 0.75 * k \
                        and abs(p[2] + .5 - ez) < 0.65 * k:
                    head.v[p] = (mask, False)
        eyes(c, head, max(0 if k < 1.2 else 1, round(0.5 * k)), round(hz + 0.15 * k), max(1, math.ceil(0.55 * k)))
        if opts.get('mask'):
            _glint(c)
        # big pointed ears, up and out, pale inside
        ears = c.part('ears', 'static', (0, -0.6 * k, hz + 1.0 * k))
        inner = cols.get('ear') or light(col, 0.45)
        for sx in (1,):
            base = (sx * 0.85 * k, -0.6 * k, hz + 0.8 * k)
            tip = (sx * 1.9 * k, -0.2 * k, hz + 3.0 * k)
            n = max(4, round(2.4 * k))
            for i in range(n + 1):
                t = i / n
                cx = base[0] + (tip[0] - base[0]) * t
                cy = base[1] + (tip[1] - base[1]) * t
                cz = base[2] + (tip[2] - base[2]) * t
                w = (0.95 - 0.8 * t) * k
                for dx in range(-math.ceil(w), math.ceil(w) + 1):
                    if abs(dx) > w:
                        continue
                    x = math.floor(cx + dx)
                    for dy in (0, 1):
                        cc = inner if (dy == 0 and abs(dx) < w - 0.8 and t < 0.8) else col
                        ears.put((x, math.floor(cy) + dy, math.floor(cz)), cc)
        _mirror(ears)
        for p in [p for p in ears.v if p in head.v]:
            del ears.v[p]

    _wings(c, k, bz, wing, bone, ptero, opts.get('wrap', False))
    if opts.get('cape'):
        _cape(c, k, body, head, bz, hz, cols.get('cape') or hexc('#2B1B3A'), cols.get('lining') or hexc('#D7263D'))
    if opts.get('hold') == 'berry':
        b = c.part('berry', 'static')
        # a round berry about three voxels across, held against the chest
        # (a 3x3x3 block without its corners, more for a bigger bat)
        n = max(1, round(0.45 * k) - 1)
        zc = round(bz + 0.3 * k)
        ys = [p[1] for p in body.v if abs(p[0] + .5) < 1 and abs(p[2] - zc) <= 1]
        yc = (min(ys) if ys else round(-0.9 * k)) - n - 1
        red = cols.get('berry') or hexc('#E0182D')
        for dx in range(-n - 1, n + 1):
            for dy in range(-n, n + 1):
                for dz in range(-n, n + 1):
                    cx = dx + .5
                    if (abs(cx) + .5 > n + .5) + (abs(dy) == n) + (abs(dz) == n) >= 3 - (n > 1):
                        continue
                    b.put((dx, yc + dy, zc + dz), red)
        for dx in (-1, 0):  # a little green stalk on top
            b.put((dx, yc, zc + n + 1), hexc('#5DBB63'))
        cen = (0, yc, zc)
        # little paws holding it
        for x in (-1, 0):
            xx = round(-0.8 * k) - 1 if x < 0 else round(0.8 * k)
            b.put((xx, round(cen[1]), round(cen[2])), col)
    return c


def _glint(c):
    """A white glint in the top outer corner of each eye."""
    e = next(p for p in c.parts if p.name == 'eyes')
    for side in (1, -1):
        mine = [p for p in e.v if (p[0] + .5) * side > 0]
        if mine:  # on the front face (a voxel further back can end up under an ear)
            yf = min(p[1] for p in mine)
            mine = [p for p in mine if p[1] == yf]
        if len(mine) > 1:
            top = max(p[2] for p in mine)
            e.v[max((p for p in mine if p[2] == top), key=lambda p: (p[0] + .5) * side)] = (WHITE, False)


def _wings(c, k, bz, wing, bone, ptero, wrap):
    """Each wing: a membrane in the x-z plane hung from the arm. The arm runs
    out and up to the wrist, then the long fingers fan to the trailing edge,
    which scallops between them (smooth on a pterosaur)."""
    sx0 = 1.1 * k
    span = (5.2 if not ptero else 5.8) * k
    sz = bz + 0.9 * k
    thick = 2 if k >= 1.6 else 1
    for sx, name in ((1, 'wingR'), (-1, 'wingL')):
        w = c.part(name, name, (sx * sx0, 0.3 * k, sz))
        n = max(6, math.ceil(span))
        wrist_u = 0.42
        for i in range(n + 1):
            u = i / n
            x = sx0 + span * u
            if u <= wrist_u:
                top = sz + 1.2 * k * (u / wrist_u)
            else:
                top = sz + 1.2 * k - 2.0 * k * ((u - wrist_u) / (1 - wrist_u))
            if ptero:
                bot = bz - 1.1 * k + 2.4 * k * u ** 1.6
            else:
                bot = bz - 1.4 * k + 1.8 * k * u + 0.75 * k * abs(math.sin(u * math.pi * 3.0))
            bot = min(bot, top - 0.6)
            yb = 0.3 * k + 0.4 * k * u
            if wrap:
                # wrapped: the wing curls round the body like a cape, its tip
                # in front at the side, leaving the chest (and berry) open
                R = sx0 + 0.8 * k * min(1.0, 3 * u)
                phi = 1.15 * u
                x, yb = R * math.cos(phi), 0.4 * k - R * math.sin(phi)
            for zi in range(math.floor(bot), math.ceil(top) + 1):
                if zi + .5 < bot or zi - .5 > top:
                    continue
                arm = top - zi < 1.0
                # finger bones: lines from the wrist to the trailing edge
                finger = False
                if u > wrist_u and not arm:
                    wz = sz + 1.2 * k
                    for fu in ((0.62, 0.82, 1.0) if not ptero else (1.0,)):
                        fx = sx0 + span * fu
                        fz = bz - 1.4 * k + 1.8 * k * fu if not ptero else top
                        t = (x - (sx0 + span * wrist_u)) / max(1e-6, fx - (sx0 + span * wrist_u))
                        if 0 <= t <= 1 and abs(zi + .5 - (wz + (fz - wz) * t)) < 0.6:
                            finger = True
                cc = bone if (arm or finger) else wing
                xx = math.floor(x) if sx > 0 else -math.floor(x) - 1
                for d in range(thick):
                    w.put((xx, math.floor(yb) + d, zi), cc)
        for p in [p for p in w.v if any(p in q.v for q in c.parts if q is not w)]:
            del w.v[p]


def _cape(c, k, body, head, bz, hz, cape, lining):
    """A tiny cape: a shell over the back of the body from the shoulders
    down, red-lined edges, and a high collar standing up behind the head."""
    cp = c.part('cape', 'static', (0, 0.8 * k, bz + 1.4 * k))
    cy = sum(p[1] for p in body.v) / len(body.v)
    ztop = bz + 1.3 * k
    for (x, y, z) in list(body.v):
        if y < cy or z > ztop:
            continue
        for q in ((x + 1, y, z), (x - 1, y, z), (x, y + 1, z)):
            if q not in body.v and q[1] >= cy and abs(q[0] + .5) <= 1.7 * k:
                cp.put(q, cape)
    if not cp.v:
        return
    zlo = min(p[2] for p in cp.v)
    for p in list(cp.v):
        edge = p[2] == zlo or abs(p[0] + .5) >= max(abs(q[0] + .5) for q in cp.v if q[2] == p[2]) - 0.5
        if edge:
            cp.v[p] = (lining, False)
    # the collar: two flared points standing up behind the head, framing it
    hy = max(p[1] for p in head.v)
    n = max(3, round(2.6 * k))
    for i in range(n + 1):
        t = i / n
        x = 0.8 * k + 1.1 * k * t
        z = ztop + (hz + 1.0 * k - ztop) * t
        y = hy - 0.6 * k - 0.4 * k * t
        for dx in range(max(1, round(0.7 * k * (1 - 0.6 * t)))):
            cp.put((math.floor(x) + dx, math.floor(y), round(z)), lining if dx == 0 else cape)
    _mirror(cp)
    for p in [p for p in cp.v if any(p in q.v for q in c.parts if q is not cp)]:
        del cp.v[p]


BUILDERS = {
    'bat': bat,
}


if __name__ == '__main__':
    # Self-check: every kind and option builds at the in-game size and the
    # finer size, with eyes and two wings.
    from voxkit import Creature
    bad = []
    for opts in ({}, {'kind': 'ptero'}, {'face': 'pug', 'fangs': True, 'cape': True},
                 {'hold': 'berry', 'wrap': True}):
        for H, fine in ((8, False), (22, True)):
            c = Creature('Test', 'Uncommon')
            c.fine = fine
            bat(c, H, {'col': hexc('#7A4A2E')}, opts)
            names = {p.name for p in c.parts if p.v}
            for need in ('body', 'head', 'eyes', 'wingL', 'wingR'):
                if need not in names:
                    bad.append(f'{opts} H={H}: no {need}')
    print('\n'.join(bad) or 'ok')
    raise SystemExit(1 if bad else 0)
