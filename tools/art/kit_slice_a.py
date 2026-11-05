"""Accessories for the Uncommon slice A creatures that the shared kits do
not cover. Owner: the Common A builder.

- **ape_arms**: takes off the cub's short arms and draws long ape arms in
  color, with hands in color2 (default a darker shade). `style`:
  `long` hangs them down to the knuckles near the floor (orangutan);
  `raised` swings them up and out over the head (gibbon). `r` scales the
  arm's thickness (default 1.0).

- **puffer**: turns kit_myth's goldfish into a pufferfish: the fancy veil
  tail and tall sail fin give way to a small fan tail and a low fin, in
  color (fins) and color2 (fin edges), so the round spiky ball reads.

The arms stay in the body part, like the kit's own, so they ride the
body's walk; the legs keep their own parts. Same frame as kit.py: x right,
-y front, z up, feet at z = 0, k = H / 10."""

import math

import kit_myth as myth
from voxkit import hexc


def _find(c, name):
    for p in c.parts:
        if p.name == name:
            return p
    return None


def ape_arms(c, H, col, col2=None, a=None):
    a = a or {}
    k = H / 10.0
    body, head = _find(c, 'body'), _find(c, 'head')
    if body is None or head is None or not body.v:
        return
    # the cub's torso is an ellipse 1.6k wide at the waist; its arms are the
    # body voxels outside it
    half = 1.6 * k
    for p in [p for p in body.v if abs(p[0] + .5) > half + 0.6]:
        del body.v[p]
    hand = col2 if col2 is not None else myth.dark(col, 0.3)
    zs = [p[2] for p in body.v]
    zlo, zhi = min(zs), max(zs)
    shoulder = zlo + (zhi - zlo) * 0.8
    hz = max(p[2] for p in head.v)
    r = 0.5 * k * a.get('r', 1.0)
    for side in (1, -1):
        sx = side * (half + 0.2 * k)
        if a.get('style', 'long') == 'raised':
            # up and out, a little forward: a gibbon cheering
            elbow = (side * (half + 1.0 * k), -0.2 * k, shoulder + 1.2 * k)
            tip = (side * (half + 1.3 * k), -0.4 * k, hz + 0.9 * k)
        else:
            # down past the knees, knuckles just off the floor
            elbow = (side * (half + 0.9 * k), -0.2 * k, shoulder - 1.6 * k)
            tip = (side * (half + 1.0 * k), -0.6 * k, 0.7 * k)
        pts = myth.curve((sx, 0, shoulder), elbow, 6, (0, 0, 0)) + myth.curve(elbow, tip, 7, (0, 0, 0))[1:]
        for i, (x, y, z) in enumerate(pts):
            rr = r * (1.0 + 0.15 * (i / len(pts)))
            body.ell((x - (0.5 if side < 0 else 0), y, z), (rr, rr, rr), col)
        x, y, z = tip
        body.ell((x - (0.5 if side < 0 else 0), y, z), (r * 1.3, r * 1.3, r * 1.2), hand)


def puffer(c, H, col, col2=None, a=None):
    k = H / 10.0 * 1.4  # kit_myth draws fish 1.4x bigger
    tail = _find(c, 'tail')
    if tail is not None:
        root = tail.pivot
        c.parts.remove(tail)
        myth.fish_tail(c, k, root, 1.0, 0.8, col, col2, fork=0.25, veil=False)
    df = _find(c, 'dorsal')
    body = _find(c, 'body')
    if df is not None and body is not None and body.v:
        c.parts.remove(df)
        top = max(p[2] for p in body.v)
        ys = [p[1] for p in body.v if p[2] >= top - 1]
        myth.sail(c.part('dorsal', 'static'), 0, min(ys) + 0.2 * k, top, 1.2 * k, 0.7 * k, col,
                  edge=col2 or myth.light(col, 0.3), lean=0.6)


def eye_bridge(c, H, col, col2=None, a=None):
    """Splits two big eyes, or an eye mask, that meet over the nose into
    two (a tarsier's, a loris's, a kookaburra's): a strip `width` (in k,
    default 0.6) down the middle of the face, from below the eyes to above
    them, goes back to fur in `col`. Big dark eyes joined across the nose
    read as sunglasses at 2 studs."""
    a = a or {}
    k = H / 10.0 * (1.4 if c.rarity in ('Godly',) else 1.0)
    head = _find(c, 'head')
    e = _find(c, 'eyes')
    if not head or not head.v or not e or not e.v:
        return
    w = a.get('width', 0.6) * k
    zs = [p[2] for p in e.v]
    z0, z1 = min(zs) - 1, max(zs) + 1
    for p in [p for p in e.v if abs(p[0] + .5) < w]:
        del e.v[p]
        head.put(p, col)
    for x in {p[0] for p in head.v if abs(p[0] + .5) < w}:
        for z in range(z0, z1 + 1):
            f = head.front(x, z)
            if f:
                head.put(f, col)
    # an eye that lost its shine to the bridge gets it back, in its upper
    # inner corner
    WHITE = (255, 255, 255)
    for side in (-1, 1):
        ev = [p for p in e.v if (p[0] >= 0) == (side > 0)]
        if len(ev) >= 4 and not any(e.v[p][0] == WHITE for p in ev):
            zt = max(p[2] for p in ev)
            p = min((p for p in ev if p[2] >= zt - 1), key=lambda p: (abs(p[0] + .5), -p[2]))
            e.put(p, WHITE)


def lion_spines(c, H, col, col2=None, a=None):
    """A lionfish's venomous spines: the solid dorsal fin becomes a crest of
    separate spines along the back, tallest at the front, and each side fin
    a fan of long rays, all banded in col and col2 (red and white)."""
    a = a or {}
    k = H / 10.0 * 1.4
    body = _find(c, 'body')
    if not body or not body.v:
        return
    col2 = col2 or (255, 255, 255)
    band = max(1, round(0.35 * k))

    def ray(part, x0, y0, z0, dx, dy, dz, n):
        for i in range(n):
            cc = col if (i // band) % 2 == 0 else col2
            part.put((round(x0 + dx * i), round(y0 + dy * i), round(z0 + dz * i)), cc)

    dorsal = _find(c, 'dorsal')
    if dorsal:
        c.parts.remove(dorsal)
    sp = c.part('dorsal', 'static')
    top = {}
    for (x, y, z) in body.v:
        if x in (-1, 0):
            top[y] = max(top.get(y, -1), z)
    ys = sorted(top)
    y0, y1 = ys[0] + 1, ys[-1] - 1
    L = a.get('length', 1.0)
    for y in range(y0, y1 + 1, 2):
        t = (y - y0) / max(1, y1 - y0)
        n = max(3, round((3.2 - 1.8 * t) * k * L))
        for x in (-1, 0):
            ray(sp, x, y, top[y] + 1, 0, 0.35, 1, n)
    for name, sx in (('finL', -1), ('finR', 1)):
        f = _find(c, name)
        if not f or not f.v:
            continue
        xs = [p[0] for p in f.v]
        xr = min(xs) if sx < 0 else max(xs)
        root = [p for p in f.v if p[0] == (max(xs) if sx < 0 else min(xs))]
        ry = sum(p[1] for p in root) / len(root)
        rz = sum(p[2] for p in root) / len(root)
        rx = root[0][0]
        f.v = {}
        n = max(4, round(2.2 * k * L))
        for dy, dz in ((0.55, 0.15), (0.45, -0.35), (0.25, 0.6)):
            ray(f, rx, ry, rz, sx * 0.8, dy, dz, n)


ACCESSORIES = {'ape_arms': ape_arms, 'puffer': puffer, 'eye_bridge': eye_bridge, 'lion_spines': lion_spines}

def cone_beak(c, H, col, col2=None, a=None):
    """The bird plan's wide flat bill swapped for a small pointed cone (a
    chick's or songbird's): two voxels wide, two high at the root and one at
    the tip, `length` (default 1.0) scaling how far it sticks out. col2, if
    given, darkens the tip."""
    a = a or {}
    k = H / 10.0
    head = _find(c, 'head')
    if head is None or not head.v:
        return
    ymin = min(p[1] for p in head.v)
    old = next(v for p, v in head.v.items() if p[1] == ymin)[0]
    bill = {p for p, v in head.v.items() if v[0] == old and p[1] <= ymin + max(2, round(0.8 * k))}
    zs = sorted({p[2] for p in bill})
    zc = round((zs[0] + zs[-1]) / 2) if zs else round(min(p[2] for p in head.v) + 2 * k)
    for p in bill:
        del head.v[p]
    # close the face where the bill sat in it
    for p in sorted(bill, key=lambda p: -p[1]):
        behind = (p[0], p[1] + 1, p[2])
        if behind in head.v and head.v[behind][0] != old:
            ys = [q[1] for q in head.v if q[2] == p[2] and -2 <= q[0] <= 1]
            if ys and p[1] >= min(ys) - 1:
                head.put(p, head.v[behind][0])
    ys = [q[1] for q in head.v if q[2] == zc and -2 <= q[0] <= 1]
    yf = min(ys) if ys else min(q[1] for q in head.v)
    bp = c.part('beak', 'static')
    bp.v = {}
    n = max(2, round(0.75 * k * a.get('length', 1.0)))
    for i in range(n):
        t = i / max(1, n - 1)
        top = zc + 1 if t < 0.5 else zc
        for z in range(zc, top + 1):
            for x in (-1, 0):
                bp.put((x, yf - 1 - i, z), (col2 if (col2 and i == n - 1) else col))


ACCESSORIES['cone_beak'] = cone_beak

def eye_stripe(c, H, col, col2=None, a=None):
    """A thin dark stripe running BACK from each eye along the side of the
    head (a kookaburra's): one voxel high, at the eye's height, starting just
    behind the eye, `length` k long (default 2.0). The eye itself stays in
    pale fur, and the stripe never crosses the face front."""
    a = a or {}
    k = H / 10.0
    head, eyes = _find(c, 'head'), _find(c, 'eyes')
    if head is None or eyes is None or not eyes.v:
        return
    L = max(3, round(a.get('length', 2.0) * k))
    for side in (1, -1):
        ev = [p for p in eyes.v if (p[0] >= 0) == (side > 0)]
        if not ev:
            continue
        z = min(p[2] for p in ev)  # the lower eye row
        y0 = max(p[1] for p in ev) + 1
        for y in range(y0, y0 + L):
            row = [p for p in head.v if p[1] == y and p[2] == z and (p[0] >= 0) == (side > 0)]
            if not row:
                continue
            q = max(row, key=lambda p: abs(p[0] + .5))
            head.v[q] = (col, False)


ACCESSORIES['eye_stripe'] = eye_stripe

# ---- helpers for narrow_head (same as kit_legacy's) ----
INK, WHITE = hexc('#1B1B2F'), hexc('#FFFFFF')


def _k(H):
    return H / 10.0


def _mx(x):
    return -x - 1


def _bounds(vox):
    xs, ys, zs = zip(*vox)
    return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def _head(c):
    head = _find(c, 'head')
    return head if head and head.v else None


def _mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _hash(x, y, z, s=0):
    return (x * 73856093 ^ y * 19349663 ^ z * 83492791 ^ s * 2654435761) & 0xFFFF


def narrow_head(c, H, col, col2=None, a=None):
    """A long narrow head in place of the plan's round one (ported from
    kit_legacy's hoof_head, kept in step with it): goat (a narrow wedge,
    straight profile; also a gazelle's), horse (long and deep), sheep, badger
    (low wedge), hound (long, narrow and pointed, almost no drop). col is the head, col2 the muzzle end; options
    `blaze` (a pale stripe down the face, in that colour), `length` and
    `width` (scales), `nose` (nostril colour)."""
    a = a or {}
    k = _k(H)
    head = _head(c)
    if head is None:
        return
    style = a.get('style', 'goat')
    (hx0, hy0, hz0), (hx1, hy1, hz1) = _bounds(head.v)
    # the skull sits where the old head's upper back half was, so the neck
    # joint (the head's pivot) still lands inside it
    L = a.get('length', 1.0)
    W = a.get('width', 1.0)
    sk = {'goat': (1.35, 1.45, 1.35), 'horse': (1.3, 1.5, 1.4), 'sheep': (1.3, 1.35, 1.3),
          'badger': (1.55, 1.4, 1.1), 'hound': (1.3, 1.4, 1.2)}[style]
    rx, ry, rz = sk[0] * k * W, sk[1] * k, sk[2] * k
    cy = (hy0 + hy1) / 2 + 0.35 * k
    cz = hz1 + 1 - rz - 0.15 * k - a.get('lower', 0) * k
    # the face: from the brow, forward and down to the nose
    fl, fdrop, fr0, fr1, fz0, fz1 = {
        'goat': (2.0, 1.15, 1.0, 0.72, 0.95, 0.72),
        'horse': (3.0, 1.5, 1.05, 0.95, 1.15, 0.95),
        'sheep': (1.9, 1.0, 0.95, 0.75, 0.95, 0.75),
        'badger': (1.9, 0.45, 1.15, 0.5, 0.85, 0.5),
        'hound': (2.4, 0.6, 0.9, 0.45, 0.8, 0.45)}[style]
    head.v = {}
    head.ell((0, cy, cz), (rx, ry, rz), col)
    n = 16
    y0, z0 = cy - 0.6 * k, cz - 0.15 * k
    y1, z1 = cy - (0.6 + fl * L) * k, cz - fdrop * L * k
    for i in range(n + 1):
        t = i / n
        yy, zz = y0 + (y1 - y0) * t, z0 + (z1 - z0) * t
        r = (fr0 + (fr1 - fr0) * t) * k * W
        rzz = (fz0 + (fz1 - fz0) * t) * k
        # flat on top (the straight profile): the face's top line is the
        # line from the brow to the nose, so the ball sits under it
        head.ell((0, yy, zz), (r, 0.9, rzz), col)
    # a neck down and back into the body's front top, so the head never floats
    body = _find(c, 'body')
    if body and body.v and a.get('neck', True):
        (bx0, by0, bz0), (bx1, by1, bz1) = _bounds(body.v)
        nb = (0, by0 + 1.3 * k, bz1 - 0.9 * k)
        nt = (0, cy + 0.2 * k, cz - 0.3 * k)
        for i in range(11):
            s = i / 10
            head.ell((0, nb[1] + (nt[1] - nb[1]) * s, nb[2] + (nt[2] - nb[2]) * s),
                     (0.95 * k * W, 0.95 * k, 0.95 * k), col)
    front = min(p[1] for p in head.v)
    if style == 'horse':  # a squared-off nose: fill the front corners
        for (x, y, z) in [p for p in head.v if p[1] <= front + 1]:
            for dx in (-1, 1):
                q2 = (x + dx, y, z)
                if q2 not in head.v and abs(x + dx + 0.5) <= fr1 * k * W:
                    head.put(q2, col)
    # the pale muzzle end
    muz = col2
    if muz:
        cut = front + max(2, round(0.75 * k))
        for p, (cc, g) in list(head.v.items()):
            if p[1] <= cut and p[2] <= z1 + 0.9 * k:
                head.v[p] = (muz, False)
    # a blaze down the middle of the face, brow to nose
    if a.get('blaze'):
        bl = hexc(a['blaze'])
        for x in (-1, 0):
            for z in range(round(z1), round(cz + rz * 0.5) + 1):
                f = head.front(x, z)
                if f and f[1] <= cy - 0.4 * k:
                    head.put(f, bl)
                    # and the top face of the slope, so it shows from above
                    tp = head.top(x, f[1])
                    if tp and tp[2] <= cz + rz * 0.5:
                        head.put(tp, bl)
    # nostrils on the front of the nose, either side of the middle
    nose = hexc(a['nose']) if a.get('nose') else INK
    tip = [p for p in head.v if p[1] == front]
    tz = round(sum(p[2] for p in tip) / len(tip))
    for x in (1, _mx(1)):
        f = head.front(x, tz)
        if f:
            head.put(f, nose)
    # a mouth line under the nose
    for x in (-1, 0):
        f = head.front(x, tz - 1)
        if f:
            head.put((f[0], f[1], f[2] - 1) if (f[0], f[1], f[2] - 1) in head.v else f, _mix(muz or col, INK, 0.45))
    # a woolly topknot on the crown (a lamb's)
    if a.get('topknot'):
        tk = hexc(a['topknot'])
        for (x, y, z) in [p for p in head.v if p[1] >= cy - 0.6 * k]:
            if z >= cz + rz * 0.55 and _hash(x, y, z, 5) % 2 == 0:
                head.put((x, y, z + 1), tk)
        head.ell((0, cy + 0.1 * k, cz + rz * 0.9), (rx * 0.75, ry * 0.7, 0.7 * k), tk)
    # a beard tuft under the chin, just behind the nose
    if a.get('beard'):
        bc = hexc(a['beard'])
        bd = c.part('beard', 'static')
        bd.v = {}
        yb = front + max(2, round(1.0 * k))
        zb = min(p[2] for p in head.v if p[1] == yb and p[0] in (-1, 0))
        for i in range(max(2, round(1.2 * k))):
            for x in (-1, 0):
                bd.put((x, yb + (1 if i >= 1 else 0), zb - 1 - i), bc)
        bd.put((-1, yb + 1, zb - 1), bc)
        bd.put((0, yb + 1, zb - 1), bc)
    # eyes out on the corners of the skull, looking forward and out
    e = _find(c, 'eyes')
    if e is None:
        e = c.part('eyes', 'blink', head.pivot)
    e.v = {}
    ez = round(cz + 0.15 * k)
    xe = round(rx * 0.62)
    for x in (xe, _mx(xe)):
        f = head.front(x, ez)
        if f:
            del head.v[f]
            e.put(f, INK)
            if a.get('tall_eyes', True):
                f2 = head.front(x, ez + 1)
                if f2 and f2[1] <= f[1] + 1:
                    del head.v[f2]
                    e.put(f2, WHITE if a.get('glint') else INK)


def _fine_only(fn):
    """For the mesh build only: the small in-game stand-in keeps the plan's
    look inside its box budget."""
    def wrapped(c, H, col, col2=None, a=None):
        if getattr(c, 'fine', False):
            fn(c, H, col, col2, a)
    wrapped.__name__, wrapped.__doc__ = fn.__name__, fn.__doc__
    return wrapped


ACCESSORIES['narrow_head'] = _fine_only(narrow_head)

def beak_below_eyes(c, H, col=None, col2=None, a=None):
    """Moves the beak part down so its top sits a voxel below the eyes: a big
    dark beak whose root rises to eye height reads as a band across the
    eyes (the kookaburra)."""
    beak, eyes = _find(c, 'beak'), _find(c, 'eyes')
    if beak is None or eyes is None or not beak.v or not eyes.v:
        return
    top = max(p[2] for p in beak.v)
    ez = min(p[2] for p in eyes.v)
    d = top - (ez - 2)
    if d > 0:
        beak.v = {(x, y, z - d): v for (x, y, z), v in beak.v.items()}


ACCESSORIES['beak_below_eyes'] = beak_below_eyes

def eye_spots(c, H, col, col2=None, a=None):
    """Small pale spots just above and just below each eye (a coati's face),
    in col, on the head's front."""
    head, eyes = _find(c, 'head'), _find(c, 'eyes')
    if head is None or eyes is None or not eyes.v:
        return
    for side in (1, -1):
        ev = [p for p in eyes.v if (p[0] >= 0) == (side > 0)]
        if not ev:
            continue
        xs = sorted({p[0] for p in ev})
        z0, z1 = min(p[2] for p in ev), max(p[2] for p in ev)
        for x in xs:
            for z in (z1 + 2, z0 - 2):
                f = head.front(x, z)
                if f:
                    head.put(f, col)


ACCESSORIES['eye_spots'] = eye_spots
