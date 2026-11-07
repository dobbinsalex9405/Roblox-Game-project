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
    given, darkens the tip. `strip`: also remove thin rows in front of the
    face whatever their colour (a bill a pattern painted over)."""
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
    if a.get('strip'):
        # a patterned bill (swirls painted over it) isn't one colour: also
        # take every thin row standing out in front of the face
        y = ymin
        while True:
            row = [p for p in head.v if p[1] == y]
            if not row or len(row) > 8:
                break
            bill |= set(row)
            y += 1
    for p in bill:
        del head.v[p]
    # close the face where the bill sat in it
    for p in ([] if a.get('strip') else sorted(bill, key=lambda p: -p[1])):
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
        drop = a.get('drop', 0.0)  # how far it falls per voxel back
        for i, y in enumerate(range(y0, y0 + L)):
            zz = z - math.floor(i * drop)
            row = [p for p in head.v if p[1] == y and p[2] == zz and (p[0] >= 0) == (side > 0)]
            if not row:
                continue
            q = max(row, key=lambda p: abs(p[0] + .5))
            f = head.front(q[0], q[2])
            if a.get('hide_front') and f and f[1] == q[1]:
                continue  # seen from the front it would join the eye into a bar
            head.v[q] = (col, False)
        if a.get('tall_eye'):  # a 1x2 eye: one more dark voxel under it
            for (x, y, ez) in ev:
                if (x, y, ez - 1) not in eyes.v:
                    eyes.put((x, y, ez - 1), eyes.v[(x, y, ez)][0])


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

def taller_spines(c, H, col, col2=None, a=None):
    """Makes the plan's spine bumps (the `spines` colour) into short spikes:
    each spine column grows `n` voxels (default 1) taller, the tip in col.
    Cheap in triangles, so a creature near its budget can show spines over
    a cup or shell rim (the Thimblehog)."""
    a = a or {}
    sp = _find(c, 'spines')
    if sp is None or not sp.v:
        return
    n = a.get('n', 1)
    tops = {}
    for (x, y, z) in sp.v:
        if z > tops.get((x, y), -99):
            tops[(x, y)] = z
    for (x, y), z in tops.items():
        for i in range(1, n + 1):
            sp.put((x, y, z + i), col)


ACCESSORIES['taller_spines'] = taller_spines


def ape_face(c, H, col, col2=None, a=None):
    """A baby orangutan's face: a pale disc over the front of the head (col)
    with two small dark eyes (col2), one voxel wide and two high, no glints,
    so they read as eyes and not as dark glasses; and a few spiky tufts of
    hair on the crown (a.hair, default the head's own colour, darkened)."""
    a = a or {}
    head, eyes = _find(c, 'head'), _find(c, 'eyes')
    if head is None or not head.v:
        return
    eye = col2 or INK
    (x0, y0, z0), (x1, y1, z1) = _bounds(head.v)
    old = list(eyes.v) if eyes is not None else []
    if eyes is not None:
        eyes.v = {}
    # fill the sockets the old eyes sat in, out to the face's front plane
    yfront = y0 + 1 if any(q[1] == y0 + 1 for q in head.v) else y0
    for p in old:
        for y in range(min(p[1], yfront), p[1] + 1):
            if (p[0], y, p[2]) not in head.v:
                head.put((p[0], y, p[2]), col)
    # the disc: the whole front but the outer column each side, corners off
    xa, xb = x0 + 1, x1 - 1
    zlo = z0 + 1
    for x in range(xa, xb + 1):
        for z in range(zlo, z1 + 1):
            edge_x = x in (xa, xb)
            if edge_x and z in (zlo, z1):
                continue
            f = head.front(x, z)
            if f:
                cur = head.v[f][0]
                # keep the pink cheeks and the dark nose/mouth
                if cur in (hexc('#FF8FB1'),) or sum(cur[:3]) < 200:
                    continue
                head.put(f, col)
    # small eyes, one voxel in from the disc's edge, two high, near the top
    ez = z1 - 2
    for x in (xa + 1, _mx(xa + 1)):
        for z in (ez, ez + 1):
            f = head.front(x, z)
            if f:
                head.put(f, eye)
    # hair tufts on the crown: alternate spikes, taller in the middle
    hair = hexc(a['hair']) if a.get('hair') else myth.dark(head.v[next(iter(head.v))][0], 0.15)
    for x in range(x0 + 1, 0):
        tall = 2 if (x - x0) % 2 == 0 else 1
        top = [p for p in head.v if p[0] == x and p[2] == z1]
        if not top:
            continue
        y = sorted(p[1] for p in top)[len(top) // 2]
        for dz in range(1, tall + 1):
            head.put((x, y, z1 + dz), hair)
            head.put((_mx(x), y, z1 + dz), hair)


ACCESSORIES['ape_face'] = _fine_only(ape_face)


def arm_hair(c, H, col, col2=None, a=None):
    """Long shaggy hair hanging off the outside of an ape's arms (an
    orangutan's): every other voxel down the outer side of each arm grows a
    strand one voxel out, in col, alternating with a strand one lower."""
    a = a or {}
    body = _find(c, 'body')
    if body is None or not body.v:
        return
    half = a.get('half', 1.6) * _k(H) + 0.6
    arm = [p for p in body.v if abs(p[0] + .5) > half]
    outer = {}
    for (x, y, z) in arm:
        key = (y, z, x >= 0)
        if key not in outer or abs(x + .5) > abs(outer[key][0] + .5):
            outer[key] = (x, y, z)
    for (y, z, right), (x, _, _) in outer.items():
        if (y + z) % 2:
            continue
        s = 1 if right else -1
        body.put((x + s, y, z), col)
        if (z // 2) % 2 == 0 and (x + s, y, z - 1) not in body.v:
            body.put((x + s, y, z - 1), col)


ACCESSORIES['arm_hair'] = _fine_only(arm_hair)


def mitten_plus(c, H, col, col2=None, a=None):
    """Makes kit_uncommon's mitten read as a mitten (run after it, same
    colours): the knit grows a rounded fingertip end past the rump, a big
    thumb rises from the top of the +x flank (the one the hero camera
    sees), and the white cuff rolls out one voxel all round the opening.
    All of it stays above the belly, clear of the legs."""
    a = a or {}
    k = _k(H)
    body = _find(c, 'body')
    if body is None or not body.v:
        return
    red = hexc(a.get('knit', '#E84855'))
    knit = [p for p, v in body.v.items() if v[0] == red]
    if not knit:
        return
    cuffs = {hexc('#FFFFFF'), hexc('#F1EDE6')}
    cuff = [p for p, v in body.v.items() if v[0] in cuffs]
    rib = myth.dark(red, 0.15)
    # drop kit_uncommon's small thumb (the knit with no mirror on -x)
    for (x, y, z) in knit:
        if x >= 0 and (_mx(x), y, z) not in body.v:
            del body.v[(x, y, z)]  # (redrawn below in the same place, bigger)
    knit = [p for p, v in body.v.items() if v[0] == red]
    (x0, y0, z0), (x1, y1, z1) = _bounds(knit)
    cx, cz = -0.5, (z0 + z1) / 2 + 0.5

    def knit_col(x, y, z):  # plain knit: the rib rows cost faces (tri budget)
        return red

    # the fingertip end: a half-ellipsoid behind the rump
    from voxkit import Part
    tip = Part('tip')
    tip.ell((cx + .5, y1 - 0.6 * k, cz), ((x1 - x0 + 1) / 2 * 0.95, 1.9 * k, (z1 - z0 + 1) / 2 * 0.95), red)
    for (x, y, z) in (tip.v if a.get('tip', True) else ()):
        if y > y1 - 1 and z >= z0 and (x, y, z) not in body.v:
            body.put((x, y, z), knit_col(x, y, z))
    # the thumb: a fat rod rising from the top of the +x flank (the side
    # the hero camera sees), up and a little forward. It stays inside the
    # knit's width: the export centres each part on its box, so anything
    # sticking out on one side would shift the body off the legs' mirror.
    ym = y0 + (y1 - y0) * 0.5
    sd = a.get('side', 1)
    xe = x1 if sd > 0 else x0
    base = (xe - sd * 1.0 * k, ym, z1 - 0.4 * k)
    mid = (xe - sd * 0.8 * k, ym - 0.2 * k, z1 + 0.6 * k)
    end = (xe - sd * 0.7 * k, ym - 0.5 * k, z1 + 1.4 * k)
    th = Part('thumb')
    for (p, q) in ((base, mid), (mid, end)):
        n = 6
        for i in range(n + 1):
            t = i / n
            pt = tuple(p[j] + (q[j] - p[j]) * t for j in range(3))
            th.ell(pt, (0.65 * k, 0.65 * k, 0.65 * k), red)
    for (x, y, z) in th.v:
        if x0 <= x <= x1 and z >= z0 and (x, y, z) not in body.v:
            body.put((x, y, z), knit_col(x, y, z))
    # the cuff rolls out one voxel all round the opening
    if cuff:
        yf = min(p[1] for p in cuff)
        ring = [p for p in cuff if p[1] <= yf + 1]
        for (x, y, z) in ring:
            for dx, dz in ((1, 0), (-1, 0)):
                q = (x + dx, y, z + dz)
                if q not in body.v and q[2] >= z0 + 2:  # clear of the legs
                    body.put(q, hexc('#FFFFFF'))


ACCESSORIES['mitten_plus'] = _fine_only(mitten_plus)


def slope_back(c, H, col=None, col2=None, a=None):
    """A hyena's sloping back: the front stands taller and the rump sits
    lower. Everything above the hips is lifted by `front` voxels at the
    front legs, going linearly to `back` voxels (negative: lowered) at the
    back legs; the legs grow or shrink by the same amount at their tops, so
    the feet stay on the floor. Run it after every accessory that draws on
    the body, before the legs are split off (accessories always are)."""
    import rig
    a = a or {}
    body = _find(c, 'body')
    if body is None or not body.v:
        return
    zs = [p[2] for p in body.v]
    z0, top = min(zs), max(zs)
    hip = z0
    while hip + 1 < top and rig._slab_pieces(body.v, hip + 1) >= 2:
        hip += 1
    legs = [p for p in body.v if p[2] <= hip]
    if not legs:
        return
    yf, yb = min(p[1] for p in legs), max(p[1] for p in legs)
    up, down = a.get('front', 1), a.get('back', -1)

    def lift(y):
        t = 0.0 if yb == yf else min(1.0, max(0.0, (y - yf) / (yb - yf)))
        return round(up + (down - up) * t)

    for p in c.parts:
        if not p.v:
            continue
        nv = {}
        for (x, y, z), v in p.v.items():
            u = lift(y)
            if p is body and z <= hip:
                if u < 0 and z > hip + u:
                    continue  # the top of a back leg, shortened
                nv[(x, y, z)] = v
                if u > 0 and z == hip:  # the top of a front leg, grown
                    for d in range(1, u + 1):
                        nv[(x, y, z + d)] = v
            else:
                nv[(x, y, z + u)] = v
        p.v = nv
        if p is not body and getattr(p, 'pivot', None):
            px, py, pz = p.pivot
            p.pivot = (px, py, pz + lift(py))


ACCESSORIES['slope_back'] = slope_back


def flank_spots(c, H, col, col2=None, a=None):
    """Clear dark spots on the body's sides (a spotted hyena's): 2x2 voxel
    spots on the outermost voxels of each flank, on a staggered grid
    `every` voxels apart (default 4), above the legs and below the back
    line, mirrored left and right."""
    a = a or {}
    import rig
    body = _find(c, 'body')
    if body is None or not body.v:
        return
    zs = [p[2] for p in body.v]
    z0, top = min(zs), max(zs)
    hip = z0
    while hip + 1 < top and rig._slab_pieces(body.v, hip + 1) >= 2:
        hip += 1
    n = a.get('every', 4)
    side = {}
    for (x, y, z) in body.v:
        if x < 0 or z <= hip + 1 or z >= top - 1:
            continue
        if (y, z) not in side or x > side[(y, z)][0]:
            side[(y, z)] = (x, y, z)
    for (y, z), q in side.items():
        row = (z - hip) // 2
        if (y + 2 * (row % 2)) % n in (0, 1) and (z - hip) % (n - 1) in (1, 2):
            body.put(q, col)
            body.put((_mx(q[0]), y, z), col)


ACCESSORIES['flank_spots'] = flank_spots


def origami_frog(c, H, col, col2=None, a=None):
    """Rebuilds the blob frog as a folded-paper (origami) jumping frog: a
    low pyramid body with a diamond base and a ridge down the back, a
    wedge head that narrows to a point, two folded paper eye points, and
    flat angular legs (a Z-folded back leg, a straight front leg). Every
    face is a flat plane: the facets on the left and right take two paper
    shades (col and a little darker), and the creases where facets meet,
    the back ridge and the leg folds are drawn in col2 (a pale crease
    line). Same parts, pivots and voxel scale as the blob it replaces."""
    a = a or {}
    k = _k(H)
    body, head, eyes = _find(c, 'body'), _find(c, 'head'), _find(c, 'eyes')
    if body is None or head is None:
        return
    paper = col
    side = myth.dark(col, 0.22)
    crease = col2 or myth.light(col, 0.55)
    ink = INK

    def shade(x, u, v, edge):
        if edge:
            return crease
        return paper if x >= 0 else side

    # Voxels cannot draw sloped paper without stairs, so every surface is a
    # flat plane on the grid (paper lies flat) and the folds are drawn as
    # crease lines on those planes.
    # body: two stacked flat diamond tiers (the folded base and the back
    # flap on it), flat on top, the creases from the corners and the ridge
    A, B = 3.0 * k, 2.8 * k
    yc = 0.4 * k
    zb, zm, zt = round(0.4 * k), round(1.6 * k), round(2.6 * k)
    flap = myth.light(col, 0.18)
    body.v = {}
    for z in range(zb, zt + 1):
        top = z > zm
        ax, by = (A * 0.62, B * 0.7) if top else (A, B)
        for x in range(-round(A) - 1, round(A) + 1):
            for y in range(round(yc - B) - 1, round(yc + B) + 2):
                u, v = abs(x + .5) / ax, abs(y + .5 - yc) / by
                if u + v > 1:
                    continue
                face = z == (zt if top else zm)
                edge = face and (abs(u - v) < 0.1 or (top and u < 0.1))
                # the sides: two shades split at the middle, like light on folds
                wall = side if (x < 0) == (y + .5 < yc) else myth.dark(col, 0.1)
                body.put((x, y, z), crease if edge else (flap if top else paper) if face else wall)
    # head: a flat triangle in plan, pointing forward, one tier, with a
    # crease down the middle and along its edges
    head.v = {}
    y_back, y_tip = round(yc - B * 0.55), round(yc - B - 1.6 * k)
    for y in range(y_tip, y_back + 1):
        t = (y_back - y) / max(1, y_back - y_tip)  # 0 at the back, 1 at the tip
        w = (2.3 * k) * (1 - 0.85 * t)
        for z in range(zb + 1, zt + 1):
            for x in range(-round(w) - 1, round(w) + 1):
                u = abs(x + .5) / max(0.6, w)
                if u > 1:
                    continue
                face = z == zt
                edge = face and u < 0.2 and t < 0.75
                head.put((x, y, z), crease if edge else paper if face else side)
    # eye points: small folded cones on the head's top, ink dot in front
    if eyes is not None:
        eyes.v = {}
    ey = round(y_back - 0.6 * k)
    ex = max(1, round(1.1 * k))
    ztop = max(p[2] for p in head.v if p[1] == ey) if any(p[1] == ey for p in head.v) else zt
    for x in (ex, _mx(ex)):
        for dz in range(1, 3):
            for dx in ((0, 1) if dz == 1 else (0,)):
                xx = x + (dx if x >= 0 else -dx)
                head.put((xx, ey, ztop + dz), paper if x >= 0 else side)
                if dz == 1:
                    head.put((xx, ey + 1, ztop + dz), crease)
        (eyes or head).put((x, ey - 1, ztop + 1), ink)
    # legs: flat angular folds, 2 voxels thick
    def slab(part, pts, w, zt_of):
        for (p, q) in zip(pts, pts[1:]):
            n = max(2, int(math.dist(p, q) * 2))
            for i in range(n + 1):
                tt = i / n
                x = p[0] + (q[0] - p[0]) * tt
                y = p[1] + (q[1] - p[1]) * tt
                z = p[2] + (q[2] - p[2]) * tt
                for dx in range(-w // 2, w - w // 2):
                    for dz in (0, 1):
                        part.put((math.floor(x + dx), math.floor(y), max(0, math.floor(z) - dz)),
                                 crease if dz == 0 and i in (0, n) else paper if x >= 0 else side)

    hx = A * 0.75
    drawn = {}
    for kind in ('B', 'F'):
        from voxkit import Part
        r = Part('leg')
        if kind == 'B':
            pts = [(hx - 0.4 * k, yc + 1.0 * k, 1.8 * k), (hx + 1.3 * k, yc + 2.6 * k, 1.6 * k),
                   (hx + 1.6 * k, yc - 0.4 * k, 1.0)]
        else:
            pts = [(hx - 0.6 * k, yc - 1.6 * k, 1.8 * k), (hx + 0.5 * k, yc - B - 0.2 * k, 1.0)]
        slab(r, pts, 2, None)
        fx, fy, _ = pts[-1]  # a foot: a flat patch on the floor, crease at the toes
        for dx in range(-1, 2):
            for dy in range(-1, 1):
                r.put((math.floor(fx + dx), math.floor(fy + dy), 0), crease if dy == -1 else paper)
        drawn[kind] = ({q: v for q, v in r.v.items() if q[0] >= 0}, pts[0])
    for p in c.parts:
        if p.name not in ('legFL', 'legFR', 'legBL', 'legBR'):
            continue
        right, hip = drawn[p.name[3]]
        if p.name.endswith('R'):
            p.v = dict(right)
            p.pivot = (hip[0], hip[1], hip[2])
        else:
            p.v = {(_mx(x), y, z): ((side if v[0] == paper else v[0]), v[1]) for (x, y, z), v in right.items()}
            p.pivot = (-hip[0], hip[1], hip[2])  # the leg turns where it meets the body


ACCESSORIES['origami_frog'] = _fine_only(origami_frog)


def bird_neck(c, H, col, col2=None, a=None):
    """A long neck for a ratite chick (ostrich, emu): the head and every
    part riding it (eyes, beak, crest) lift by `length` k (default 1.6),
    and a neck column in col joins the body's top front to the head's
    underside. Run it after the beak and before stilts."""
    a = a or {}
    k = _k(H)
    body, head = _find(c, 'body'), _find(c, 'head')
    if body is None or head is None or not body.v or not head.v:
        return
    n = max(3, round(a.get('length', 1.6) * k))
    riders = [p for p in c.parts if p is head or (p.name in ('eyes', 'beak', 'crest', 'ears', 'comb')
                                                    and p.v and min(q[2] for q in p.v) >= min(q[2] for q in head.v))]
    hz0 = min(q[2] for q in head.v)
    hy = sorted(q[1] for q in head.v if q[2] == hz0)
    ny = hy[len(hy) // 2]
    for p in riders:
        p.v = {(x, y, z + n): v for (x, y, z), v in p.v.items()}
        if getattr(p, 'pivot', None):
            p.pivot = (p.pivot[0], p.pivot[1], p.pivot[2] + n)
    # the neck: a column under the head, 2k wide, from inside the body up
    # into the lifted head, leaning back a little where it meets the body
    top = max(q[2] for q in body.v)
    r = max(1.0, a.get('r', 0.55) * k)
    for z in range(top - round(0.8 * k), hz0 + n + 2):
        t = (z - top) / max(1, hz0 + n - top)
        y = ny + (1 - max(0.0, t)) * 0.6 * k
        for x in range(-math.ceil(r) - 1, math.ceil(r) + 1):
            for dy in range(-math.ceil(r) - 1, math.ceil(r) + 1):
                if (x + .5) ** 2 + (dy) ** 2 <= r * r:
                    q = (x, round(y + dy), z)
                    if q not in body.v and q not in head.v:
                        head.put(q, col) if z >= hz0 + n else body.put(q, col)


ACCESSORIES['bird_neck'] = _fine_only(bird_neck)


def long_stripes(c, H, col, col2=None, a=None):
    """Lengthwise stripes, head to tail (an emu chick's). The body and the
    wings are recoloured col2 (the cream ground), then every other band of
    angle around the body's long (y) axis is painted col: `bands` wide dark
    stripes over the back and sides (default 4), the same axis for the
    wings so their stripes carry on from the body's. The belly (the lowest
    quarter) stays cream. The head stays cream except one dark stripe down
    the middle of the crown, clear of the eyes."""
    a = a or {}
    ground = col2 or hexc('#EADBB8')
    n = a.get('bands', 4)
    body = _find(c, 'body')
    if body is None or not body.v:
        return
    (bx0, by0, bz0), (bx1, by1, bz1) = _bounds(body.v)
    zc = bz0 + (bz1 - bz0) * 0.45
    belly = bz0 + (bz1 - bz0) * 0.25
    step = math.pi / (2 * n - 1)
    w = a.get('width', 2)  # voxels per stripe
    if a.get('by_face'):
        # Stripes follow the surface. Each outside voxel's facing is the
        # sum of the empty cells around it (two voxels out, so it is
        # smooth); where the body faces sideways the stripes are rows of z
        # (long lines front to back in the side view), where it faces up,
        # forward or back they are columns of |x| (lines down the back from
        # above, vertical stripes down the sides of the chest from the front;
        # the middle of the chest and the spine stay cream). Both run head to
        # tail and meet at the shoulder.
        vox = body.v
        r = 2
        offs = [(dx, dy, dz) for dx in range(-r, r + 1) for dy in range(-r, r + 1)
                for dz in range(-r, r + 1) if (dx, dy, dz) != (0, 0, 0)]
        zmid = round(belly) + 1
        for q, v in list(vox.items()):
            if v[1]:
                continue
            x, y, z = q
            if z < belly:
                vox[q] = (ground, False)
                continue
            nx = ny = nz = 0
            for dx, dy, dz in offs:
                if (x + dx, y + dy, z + dz) not in vox:
                    nx += dx; ny += dy; nz += dz
            ax = int(abs(x + .5))
            if abs(nx) > max(abs(nz), abs(ny)) * a.get('side_bias', 1.0):
                dark = ((z - zmid) // w) % 2 == 0
            else:
                dark = ax >= w and ((ax - w) // w) % 2 == 0 and ax < n * w * 2
            vox[q] = (col if dark else ground, False)
        for p in [q for q in c.parts if q.name in ('wingL', 'wingR')]:
            for q, v in list(p.v.items()):
                if v[1]:
                    continue
                x, y, z = q
                under = [b for b in vox if b[1] == y and b[2] == z]
                p.v[q] = (vox[min(under, key=lambda b: abs(b[0] - x))][0] if under else ground, False)
    else:
        for p in [body] + [q for q in c.parts if q.name in ('wingL', 'wingR')]:
            for q, v in list(p.v.items()):
                x, y, z = q
                if v[1]:
                    continue
                th = math.atan2(abs(x + .5), z + .5 - zc)  # 0 on top, pi/2 at the side
                band = int((th + step / 2) // step)  # band 0 is centred on the spine
                dark = z >= belly and band % 2 == 0 and band < n
                p.v[q] = (col if dark else ground, False)
    head = _find(c, 'head')
    if head is not None and head.v:
        ztop = max(q[2] for q in head.v)
        for q, v in list(head.v.items()):
            if v[1]:
                continue
            crown = abs(q[0] + .5) <= 1 and q[2] >= ztop - 2
            head.v[q] = (col if crown else ground, False)


ACCESSORIES['long_stripes'] = long_stripes


def spike_rows(c, H, col, col2=None, a=None):
    """Hedgehog spines that stand up: the flat 'spines' patch is replaced
    by rows of 1x1 spikes rising up and back from the top of the back,
    `length` voxels long (default 3), the last voxel in col2 (a pale tip).
    Spikes stand on a staggered grid, `every` voxels apart (default 2),
    from `from_y` of the way along the back (0 front, 1 rump; default 0.2),
    mirrored left and right. `thin_cup` (a hex colour: the cup's) puts
    back every other row of a thimble's dimples, to pay for the spikes in
    the triangle budget."""
    a = a or {}
    body = _find(c, 'body')
    if body is None or not body.v:
        return
    tip = col2 or myth.light(col, 0.6)
    sp = _find(c, 'spines')
    host = sp if sp is not None else body
    if sp is not None:
        sp.v = {}
    if a.get('thin_cup'):
        cup = hexc(a['thin_cup'])
        dim = myth.dark(cup, 0.2) if hasattr(myth, 'dark') else None
        for q, v in list(body.v.items()):
            if v[0] == dim and q[2] % 4 >= 2:
                body.v[q] = (cup, v[1])
    # the back: the top voxel of each column of the body, above the rim
    tops = {}
    for (x, y, z) in body.v:
        if (x, y) not in tops or z > tops[(x, y)]:
            tops[(x, y)] = z
    ys = [y for (_, y) in tops]
    yf, yb = min(ys), max(ys)
    zmin = a.get('min_z')
    n = a.get('length', 3)
    ev = a.get('every', 2)
    y_start = yf + round((yb - yf) * a.get('from_y', 0.2))
    for (x, y), z in tops.items():
        if x < 0 or y < y_start or (zmin is not None and z < zmin):
            continue
        if x % ev or (y + (x // ev) % 2) % ev:
            continue
        for i in range(1, n + 1):
            q = (x, y + (i - 1) // 2, z + i)
            cc = tip if i == n else col
            host.put(q, cc)
            host.put((_mx(x), q[1], q[2]), cc)


ACCESSORIES['spike_rows'] = _fine_only(spike_rows)
