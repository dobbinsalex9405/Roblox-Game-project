"""Extra accessories for roster entries (see variants.py), beside the ones in
kit.accessory:

- **ridge**: a row of spikes down the middle of the back, like a hedgehog's
  or a little dragon's (color; color2 tips the spikes).
- **third_eye**: a third eye in the middle of the forehead (color is its
  ring; it blinks with the other two).
- **butter**: a pat of butter on top of the head (color; color2 is the
  shine on top).
- **twin_tail**: the tail split into two that fork apart (color tints the
  tips; the tails keep their own colour).

- **droopy_ears**: soft rounded ears hanging down the sides of the head.
- **fringe**: a shaggy fringe over the eyes and crown (a sheepdog's).
- **shag**: ragged fur tufts along the body's sides.
- **long_snout**: a long tapered snout with a coloured tip (color2).
- **streaks**: short dark streaks on the back and folded wings.
- **cap**: the top of the head painted down to the eyes.
- **eye_ring**: a light ring around each eye on a dark face.
- **speckles**: small scattered light dots all over.

- **button_eye**: one big sewn-on button for an eye (a sock puppet's).
- **knit_head**: knitted bands across the head (a sock's cuff).
- **small_ears**: small round ears low on the head (a weasel's).
- **stand_tall**: an alert pose, the head lifted on a longer neck.
- **rostrum**: a weevil's long snout curving down, with elbowed antennae.
- **bristles**: stray bristles out of every segment, so the outline is fuzzy.
- **frog_eyes**: big forward frog eyes on the bumps and a small gold third eye.

And six plans: **twig**, a stick insect, thin everywhere (colours col,
accent); **termite**, a pale banded ant shape with a brown head, a pinched
waist, thin dark legs and forward antennae (colours col, accent, leg);
**wasp**, slim and narrow-waisted with a banded tapered abdomen, a stinger
and narrow amber wings (colours col, accent, wing); **strider**, a water
strider on four long splayed legs with ripple rings (colours col, accent,
ripple); **shieldbug**, a flat shield back with a triangular plate;
**shrimp**, an arched banded body with long feelers (both col, accent, leg).

Each is fn(c, H, color, color2, a) (variants.py's kit hook): colours are RGB
tuples, color2 may be None, `a` is the roster entry's accessory dict.
Same art frame as kit.py (x right, y back, front is -y, z up), k = H / 10."""

import math

from voxkit import hexc

INK, WHITE = hexc('#1B1B2F'), hexc('#FFFFFF')


def _rgb(col, default=None):
    if col is None:
        return default
    return hexc(col) if isinstance(col, str) else col


def _hash(*v):
    h = 2166136261
    for x in v:
        h = ((h ^ (int(x) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    return h


def _find(c, name):
    return next((p for p in c.parts if p.name == name), None)


def ridge(c, H, color, color2=None, a=None):
    """Spikes along the back's midline, from behind the head to the tail."""
    k = H / 10.0
    col = _rgb(color)
    tip = _rgb(color2, col)
    body = _find(c, 'body')
    head = _find(c, 'head')
    if body is None or not body.v:
        return
    sp = c.part('ridge', 'static')
    # from the front of the crown down the back to the tail: the top of the
    # head and body together, along the midline
    solid = set(body.v) | (set(head.v) if head is not None else set())
    if head is not None and head.v:
        hy = [p[1] for p in head.v]
        y_front = min(hy) + (max(hy) - min(hy)) * 0.3
    else:
        ys = [p[1] for p in body.v]
        y_front = min(ys) + (max(ys) - min(ys)) * 0.2
    step = max(2, round(0.8 * k))
    height = max(3, round(1.4 * k))
    tops = {}
    for (x, y, z) in solid:
        if x in (-1, 0) and y >= y_front:
            tops[(x, y)] = max(z, tops.get((x, y), z))
    if not tops:
        return
    y0 = min(y for _, y in tops)
    for (x, y), z in sorted(tops.items()):
        # a continuous base along the spine joins the spikes into one ridge
        sp.put((x, y, z + 1), col)
        if (y - y0) % step:
            continue
        # a spike two voxels wide, leaning back a voxel near its tip
        for i in range(1, height):
            lean = 1 if i >= height - 1 else 0
            sp.put((x, y + lean, z + 1 + i), tip if i == height - 1 else col)


def third_eye(c, H, color, color2=None, a=None):
    """A third eye on the forehead, above and between the other two."""
    k = H / 10.0
    ring = _rgb(color)
    head = _find(c, 'head')
    eyes = _find(c, 'eyes')
    if head is None or eyes is None or not eyes.v:
        return
    ez = max(p[2] for p in eyes.v)
    s = max(1, round(0.5 * k))
    z0 = ez + max(1, round(0.4 * k))
    # find the forehead: the highest row at the centre that still has face
    zs = [z for z in range(z0 + 3 * s, ez - 3 * s - 2, -1) if head.front(0, z) and head.front(-1, z)]
    if not zs:
        return
    zc = min(zs[0] - s, z0)  # under the top of the face, a little above the eyes if it fits
    for x in range(-s - 1, s + 1):
        for z in range(zc - 1, zc + max(2, s) + 1):
            f = head.front(x, z)
            if not f:
                continue
            inner = -s <= x < s and zc <= z < zc + max(2, s)
            if inner:
                del head.v[f]
                shine = z == zc + max(2, s) - 1 and x == -s
                eyes.put(f, WHITE if shine else INK)
            else:
                head.put(f, ring)


def butter(c, H, color, color2=None, a=None):
    """A flat square pat of butter sitting on the crown."""
    k = H / 10.0
    col = _rgb(color)
    top = _rgb(color2, tuple(min(255, round(v + (255 - v) * 0.45)) for v in col))
    head = _find(c, 'head') or _find(c, 'body')
    zt = max(p[2] for p in head.v)
    crown = [p for p in head.v if p[2] >= zt - 1]
    y = round(sum(p[1] for p in crown) / len(crown))
    pat = c.part('butter', 'static')
    w = max(1, round(0.8 * k))
    h = max(1, round(0.45 * k))
    for x in range(-w, w):
        for yy in range(y - w, y + w):
            for z in range(zt + 1, zt + 1 + h):
                pat.put((x, yy, z), top if z == zt + h else col)
    # a drip down one side
    for i in range(max(1, round(0.5 * k))):
        pat.put((w - 1, y - w, zt - i), col)


def twin_tail(c, H, color, color2=None, a=None):
    """Splits the tail into two that fork apart, left and right."""
    k = H / 10.0
    tip = _rgb(color)
    tail = _find(c, 'tail')
    if tail is None or not tail.v:
        return
    ys = [p[1] for p in tail.v]
    y0, y1 = min(ys), max(ys)
    span = max(1, y1 - y0)
    spread = max(1.0, 1.2 * k)
    out = {}
    for (x, y, z), v in tail.v.items():
        t = (y - y0) / span
        dx = round(spread * (0.4 + t))
        for sx in (-1, 1):
            xx = x + dx if sx > 0 else -(x + dx) - 1  # mirrored (cells are [x, x+1))
            col = (tip, False) if t > 0.8 else v
            out[(xx, y, z)] = col
    tail.v = out


def fringe(c, H, color, color2=None, a=None):
    """A shaggy fringe hanging over the eyes from the top of the head (a
    sheepdog's): a layer in front of the face down to mid-eye, ragged at the
    bottom, so the eyes peek out underneath."""
    k = H / 10.0
    col = _rgb(color)
    head = _find(c, 'head')
    eyes = _find(c, 'eyes')
    if head is None or not head.v:
        return
    fr = c.part('fringe', 'static')
    ez = max(p[2] for p in eyes.v) if eyes is not None and eyes.v else None
    zt = max(p[2] for p in head.v)
    bottom = ez if ez is not None else zt - round(1.5 * k)
    xs = [p[0] for p in head.v]
    for x in range(min(xs), max(xs) + 1):
        # ragged: every other column hangs down to the eyes, the rest stop
        # just above them, so the eyes peek out between the locks
        low = bottom + (1 if x % 2 else 0)
        for z in range(low, zt + 1):
            f = head.front(x, z)
            if f:
                fr.put((f[0], f[1] - 1, f[2]), col)
    # over the crown too, so it reads as a mop of hair
    for p in list(head.v):
        if p[2] >= zt - max(1, round(0.4 * k)):
            fr.put((p[0], p[1], p[2] + 1), col)


def shag(c, H, color, color2=None, a=None):
    """Shaggy fur: ragged tufts hanging from the body's sides and belly
    edge, in color (default the body's own)."""
    k = H / 10.0
    body = _find(c, 'body')
    if body is None or not body.v:
        return
    sh = c.part('shag', 'static')
    zs = [p[2] for p in body.v]
    zlo, zhi = min(zs), max(zs)
    mid = zlo + (zhi - zlo) * 0.45
    solid = set(body.v)
    for (x, y, z), (cc, g) in list(body.v.items()):
        if z < mid or z > zhi - 1:
            continue
        side = 1 if x >= 0 else -1
        out = (x + side, y, z)
        if out in solid or (x + y * 3 + z * 7) % 3:
            continue
        col = _rgb(color, cc)
        for i in range(max(1, round(0.5 * k))):
            if (x + side, y, z - i) not in solid:
                sh.put((x + side, y, z - i), col)


def long_snout(c, H, color, color2=None, a=None):
    """A long tapered snout (a shrew's), out from the middle of the face,
    ending in a coloured tip (color2, default pink)."""
    k = H / 10.0
    col = _rgb(color)
    tip = _rgb(color2, hexc('#FF9FBF'))
    head = _find(c, 'head')
    eyes = _find(c, 'eyes')
    if head is None or not head.v:
        return
    ez = min(p[2] for p in eyes.v) if eyes is not None and eyes.v else max(p[2] for p in head.v) - round(1.5 * k)
    z0 = ez - max(1, round(0.6 * k))
    front = head.front(0, z0) or head.front(-1, z0)
    if not front:
        return
    sn = c.part('snout', 'static')
    n = max(3, round(1.8 * k))
    for i in range(n):
        t = i / max(1, n - 1)
        tall = t < 0.5  # two voxels tall near the face, one at the end
        dz = -round(0.3 * t * k)  # tipping down a little
        for x in (-1, 0):
            for z in ((z0 + dz - 1, z0 + dz) if tall else (z0 + dz,)):
                sn.put((x, front[1] - 1 - i, z), tip if i == n - 1 else col)


def streaks(c, H, color, color2=None, a=None):
    """Short dark streaks on the back and the folded wings (a sparrow's)."""
    col = _rgb(color)
    for name in ('body', 'wingL', 'wingR'):
        part = _find(c, name)
        if part is None or not part.v:
            continue
        zs = [p[2] for p in part.v]
        mid = min(zs) + (max(zs) - min(zs)) * (0.45 if name == 'body' else 0.0)
        part.paint(lambda p, cc, g: (col, False) if not g and p[2] >= mid and p[1] >= -1
                   and (p[1] * 2 + p[2] + (p[0] // 2) * 3) % 5 == 0 else None)


def cap(c, H, color, color2=None, a=None):
    """Paints the top of the head (a bird's cap) down to just above the eyes."""
    k = H / 10.0
    col = _rgb(color)
    head = _find(c, 'head')
    eyes = _find(c, 'eyes')
    if head is None or not head.v:
        return
    ez = max(p[2] for p in eyes.v) if eyes is not None and eyes.v else max(p[2] for p in head.v) - round(1.2 * k)
    head.paint(lambda p, cc, g: (col, False) if not g and p[2] > ez else None)


def _main_colour(part):
    """The colour most of a part is painted in."""
    counts = {}
    for cc, g in part.v.values():
        counts[cc] = counts.get(cc, 0) + 1
    return max(counts, key=counts.get) if counts else None


def eye_ring(c, H, color, color2=None, a=None):
    """A light ring around each eye, so dark eyes show on a dark face. Only
    the face's own colour is repainted (never a beak or cheek)."""
    col = _rgb(color)
    head = _find(c, 'head')
    eyes = _find(c, 'eyes')
    if head is None or eyes is None or not eyes.v:
        return
    base = _main_colour(head)
    cells = {(e[0], e[2]) for e in eyes.v}
    for (x, y, z) in list(eyes.v):
        out = 1 if x >= 0 else -1
        # above, below and on the outer side: the inner side stays dark, so
        # the two rings never join across the face
        for dx, dz in ((0, 1), (out, 0), (out, 1)):
            if (x + dx, z + dz) in cells:
                continue
            f = head.front(x + dx, z + dz)
            if f and head.v[f][0] == base:
                head.put(f, col)


def speckles(c, H, color, color2=None, a=None):
    """Small scattered light dots all over (a starling's), on each part's own
    colour only (never the beak, feet or eyes)."""
    col = _rgb(color)
    for name in ('body', 'head', 'wingL', 'wingR'):
        part = _find(c, name)
        if part is None or not part.v:
            continue
        counts = {}
        for cc, g in part.v.values():
            counts[cc] = counts.get(cc, 0) + 1
        base = set(sorted(counts, key=counts.get)[-2:])  # its own colour and belly, not beak or feet
        part.paint(lambda p, cc, g, base=base: (col, False) if not g and cc in base and cc != col
                   and _hash(p[0], p[1], p[2], 17) % 100 < 12 and p[2] > 1 else None)


def droopy_ears(c, H, color, color2=None, a=None):
    """Replaces the ears with soft rounded ears that hang down the sides of
    the head (a sheepdog's or spaniel's), in color."""
    k = H / 10.0
    col = _rgb(color)
    head = _find(c, 'head')
    ears = _find(c, 'ears')
    if head is None or not head.v:
        return
    if ears is None:
        ears = c.part('ears', 'static', head.pivot)
    ears.v = {}
    xs = [p[0] for p in head.v]
    ys = [p[1] for p in head.v]
    zs = [p[2] for p in head.v]
    half = (max(xs) - min(xs) + 1) / 2
    yc = (min(ys) + max(ys)) / 2 + 0.2 * k
    ztop = max(zs) - 0.6 * k
    for sx in (-1, 1):
        cx = sx * (half - 0.1 * k)
        ears.ell((cx, yc, ztop - 1.3 * k), (0.55 * k, 0.9 * k, 1.5 * k), col,
                 cond=lambda x, y, z, sx=sx: (x + .5) * sx >= half - 0.5 * k)


def button_eye(c, H, color, color2=None, a=None):
    """One big round sewn-on button for an eye (a sock puppet's): a disc in
    color with two thread holes (color2, default dark) over the right eye.
    The other eye is closed (painted over in the face's colour)."""
    k = H / 10.0
    col = _rgb(color)
    hole = _rgb(color2, INK)
    head = _find(c, 'head')
    eyes = _find(c, 'eyes')
    if head is None or eyes is None or not eyes.v:
        return
    base = _main_colour(head)
    right = [p for p in eyes.v if p[0] >= 0]
    if not right:
        return
    cx = sum(p[0] for p in right) / len(right) + .5
    cz = sum(p[2] for p in right) / len(right) + .5
    r = max(1.6, 0.9 * k)
    for p in list(eyes.v):
        eyes.v[p] = (base, False)  # closed: the button covers one, the other is shut
    bt = c.part('button', 'static')
    for x in range(int(cx - r) - 1, int(cx + r) + 2):
        for z in range(int(cz - r) - 1, int(cz + r) + 2):
            if (x + .5 - cx) ** 2 + (z + .5 - cz) ** 2 > r * r:
                continue
            f = head.front(x, z)
            if not f:
                continue
            centre = abs(x + .5 - cx) < 1.0 and abs(z + .5 - cz) < 1.0
            for e in eyes.v:
                if (e[0], e[2]) == (x, z):
                    f = e if e[1] < f[1] else f
            holes = centre and (x + z) % 2 == 0
            bt.put((f[0], f[1] - 1, f[2]), hole if holes else col)


def knit_head(c, H, color, color2=None, a=None):
    """Knitted bands across the head, top to bottom, alternating its own
    colour and color (a sock's cuff)."""
    k = H / 10.0
    col = _rgb(color)
    head = _find(c, 'head')
    if head is None or not head.v:
        return
    w = max(1, round(0.6 * k))
    zlo = min(p[2] for p in head.v)
    head.paint(lambda p, cc, g: (col, False) if not g and ((p[2] - zlo) // w) % 2 == 1 else None)


def small_ears(c, H, color, color2=None, a=None):
    """Replaces the ears with small round ears set low on the sides of the
    top of the head (a weasel's or an otter's), in color, with an inner
    colour (color2) on the front face."""
    k = H / 10.0
    col = _rgb(color)
    inner = _rgb(color2)
    head = _find(c, 'head')
    ears = _find(c, 'ears')
    if head is None or not head.v:
        return
    if ears is None:
        ears = c.part('ears', 'static', head.pivot)
    ears.v = {}
    top = max(p[2] for p in head.v)
    back = [p for p in head.v if p[2] >= top - 1]
    yc = sum(p[1] for p in back) / len(back) + 0.3 * k
    xs = [p[0] for p in head.v if p[2] >= top - round(0.8 * k)]
    half = (max(xs) - min(xs) + 1) / 2
    r = max(1.0, 0.45 * k)
    for sx in (-1, 1):
        cx = sx * max(1.0, half - 0.1 * k)
        ears.ell((cx, yc, top - 0.1 * k), (r, max(0.6, 0.3 * k), r), col)
    if inner:
        front = min(p[1] for p in ears.v)
        for p in list(ears.v):
            if p[1] == front and p[2] < top + r - 1:
                ears.v[p] = (inner, False)


def stand_tall(c, H, color, color2=None, a=None):
    """An alert, standing-tall pose: the head (and its eyes, ears, snout)
    lifted on a longer neck in color, the front of the neck in color2."""
    k = H / 10.0
    col = _rgb(color)
    front_col = _rgb(color2, col)
    head = _find(c, 'head')
    body = _find(c, 'body')
    if head is None or body is None or not head.v:
        return
    d = max(2, round(float((a or {}).get('lift', 1.2)) * k))
    pz = head.pivot[2]
    moved = [p for p in c.parts if p.name in ('head', 'eyes', 'ears', 'snout')
             or (p.name not in ('body', 'tail') and not p.name.startswith('leg') and abs(p.pivot[2] - pz) < 1e-6 and p.v)]
    for p in moved:
        p.v = {(x, y, z + d): cg for (x, y, z), cg in p.v.items()}
        p.pivot = (p.pivot[0], p.pivot[1], p.pivot[2] + d)
    # the neck: fill from the body's top up to the head's underside
    low = {}
    for (x, y, z) in head.v:
        if (x, y) not in low or z < low[(x, y)]:
            low[(x, y)] = z
    tops = {}
    for (x, y, z) in body.v:
        if (x, y) not in tops or z > tops[(x, y)]:
            tops[(x, y)] = z
    neck = []
    for (x, y), zb in low.items():
        if (x, y) in tops and tops[(x, y)] < zb:
            for z in range(tops[(x, y)] + 1, zb):
                neck.append((x, y, z))
    if not neck:
        return
    # the front face of the neck (the throat) in color2, the rest in color
    ys = [y for (x, y, z) in neck]
    xs = [x for (x, y, z) in neck]
    ymid = (min(ys) + max(ys)) / 2
    for (x, y, z) in neck:
        throat = y < ymid and min(xs) < x < max(xs)
        body.put((x, y, z), front_col if throat else col)


def rostrum(c, H, color, color2=None, a=None):
    """A weevil's long thin snout curving forward and down from the face,
    about half the body's length, in color, with small elbowed antennae
    (color2, default dark) from its middle. Removes any horn on the head."""
    k = H / 10.0
    col = _rgb(color)
    ant = _rgb(color2, INK)
    head = _find(c, 'head')
    if head is None or not head.v:
        return
    body_parts = [p for p in c.parts if p.name in ('body', 'shell')]
    ys = [v[1] for p in body_parts for v in p.v]
    length = max(4, round((max(ys) - min(ys) + 1) * 0.5)) if ys else round(3 * k)
    # drop a horn: head voxels that stand above the head's dome at the front
    main = _main_colour(head)
    for p in [p for p, (cc, g) in head.v.items() if cc != main and p not in _find(c, 'eyes').v]:
        if p[2] > min(v[2] for v in head.v) + 1:
            del head.v[p]
    zs = sorted(v[2] for v in head.v)
    z0 = zs[len(zs) // 2]
    front = min(v[1] for v in head.v if v[2] in (z0, z0 - 1) and v[0] in (-1, 0))
    path = []
    for i in range(length):
        t = i / max(1, length - 1)
        z = z0 - round(1.4 * k * t * t)
        path.append((front - 1 - i, z))
    prev = None
    for i, (y, z) in enumerate(path):
        thick = i < length * 0.6
        for x in (-1, 0):
            head.put((x, y, z), col)
            if thick:
                head.put((x, y, z - 1), col)
            if prev is not None and prev[1] != z:
                for zz in range(min(prev[1], z), max(prev[1], z) + 1):
                    head.put((x, y, zz), col)  # keep each step face to face
        prev = (y, z)
    # the antennae: out from the middle of the snout, then up (elbowed),
    # ending in a small club
    my, mz = path[length // 2]
    out = max(2, round(0.9 * k))
    up = max(2, round(1.0 * k))
    for sx in (-1, 1):
        for i in range(1, out + 1):
            x = i if sx > 0 else -1 - i
            head.put((x, my, mz), ant)
        xe = out if sx > 0 else -1 - out
        for j in range(1, up + 1):
            head.put((xe, my - (j // 2), mz + j), ant)
            if j // 2 != (j - 1) // 2:
                head.put((xe, my - (j // 2), mz + j - 1), ant)
        head.put((xe + (1 if sx > 0 else -1), my - (up // 2), mz + up), ant)


def bristles(c, H, color=None, color2=None, a=None):
    """Stray bristle voxels sticking out of every segment, in the colour of
    the voxel they grow from, so the outline reads fuzzy. color is unused
    (the bands' own colours are kept); a["rate"] sets how many (default
    0.35 of the outer voxels)."""
    k = H / 10.0
    rate = float((a or {}).get('rate', 0.35))
    for name in ('body', 'head'):
        part = _find(c, name)
        if part is None or not part.v:
            continue
        occ = set().union(*(p.v for p in c.parts))
        eyes = _find(c, 'eyes')
        face = set(eyes.v) if eyes is not None else set()
        add = {}
        for (x, y, z), (cc, g) in list(part.v.items()):
            if z < round(0.6 * k):
                continue  # not underneath, where it rests
            if name == 'head' and any(abs(x - e[0]) + abs(y - e[1]) + abs(z - e[2]) <= 2 for e in face):
                continue  # keep the face clear
            h = _hash(x, y, z, 77) % 1000
            if h >= rate * 1000:
                continue
            near = sum((x + ax, y + ay, z + az) in part.v for ax, ay, az in
                       ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)))
            if near < 3:
                continue  # not from thin features (antennae), so they stay clean
            dirs = [(0, 0, 1), (1, 0, 0), (-1, 0, 0)]
            dx, dy, dz = dirs[h % 3]
            q = (x + dx, y + dy, z + dz)
            if q in occ or q in add:
                continue
            add[q] = (cc, g)
            if h % 5 == 0 and k >= 1.5:  # now and then a longer one
                q2 = (q[0] + dx, q[1] + dy, q[2] + dz)
                if q2 not in occ:
                    add[q2] = (cc, g)
        for q, cg in add.items():
            # mirrored, so the creature stays symmetric
            part.v.setdefault(q, cg)
            m = (-q[0] - 1, q[1], q[2])
            if m not in occ:
                part.v.setdefault(m, cg)


def frog_eyes(c, H, color, color2=None, a=None):
    """A frog's eyes made to read from the front, with a third eye: the two
    usual eyes big and forward-facing on the top bumps (white, a dark pupil
    and a highlight), and a smaller third eye on its own little bump between
    and above them, its iris in color2 (default gold) so it is the odd one.
    color is the skin (for the new bump)."""
    k = H / 10.0
    skin = _rgb(color)
    iris = _rgb(color2, hexc('#FFC23A'))
    head = _find(c, 'head')
    eyes = _find(c, 'eyes')
    if head is None or eyes is None:
        return
    main = _main_colour(head)
    for p in list(eyes.v):
        head.put(p, main)  # fill in the old small eyes
    eyes.v = {}

    def disc(cx, cz, R, ring, pupil, shine=True):
        czi = round(cz)
        for x in range(math.floor(cx - R) - 1, math.ceil(cx + R) + 1):
            for z in range(czi - math.ceil(R) - 1, czi + math.ceil(R) + 1):
                if math.hypot(x + .5 - cx, z - czi) > R:
                    continue
                f = head.front(x, z)
                if not f:
                    continue
                del head.v[f]
                inner = math.hypot(x + .5 - cx, z - czi) <= 1.0
                if inner:
                    top_out = z == czi and ((x + .5 - cx) < 0)
                    eyes.put(f, WHITE if (shine and top_out) else pupil)
                else:
                    eyes.put(f, ring)

    R = max(1.0, 1.3 * k)
    for sx in (-1, 1):
        # the bump centres of blob(frog): x 1.5k, z 5.9k
        cx = sx * 1.5 * k
        cx = round(cx) if sx > 0 else -round(-cx)
        disc(cx, 5.9 * k, R, WHITE, INK)
    head.ell((0, -1.5 * k, 6.6 * k), (0.75 * k, 0.6 * k, 0.65 * k), skin)
    disc(0.0, 6.7 * k, max(1.0, 0.95 * k), iris, INK, shine=False)


ACCESSORIES = {'button_eye': button_eye, 'knit_head': knit_head, 'droopy_ears': droopy_ears, 'ridge': ridge, 'third_eye': third_eye, 'butter': butter, 'twin_tail': twin_tail, 'fringe': fringe,
               'shag': shag, 'long_snout': long_snout, 'streaks': streaks, 'cap': cap, 'eye_ring': eye_ring,
               'speckles': speckles, 'small_ears': small_ears, 'stand_tall': stand_tall, 'rostrum': rostrum,
               'bristles': bristles, 'frog_eyes': frog_eyes}


# ------------------------------------------------------------------ plans

def _rod(cells, a, b, col):
    """Voxels from a to b (voxel units), each step touching the last face
    to face, into the dict cells."""
    n = max(2, int(math.ceil(max(abs(b[j] - a[j]) for j in range(3)))) * 2)
    last = None
    for s_ in range(n + 1):
        t = s_ / n
        v = tuple(math.floor(a[j] + (b[j] - a[j]) * t) for j in range(3))
        if last is not None:
            cur = list(last)
            for j in range(3):
                if cur[j] != v[j]:
                    cur[j] = v[j]
                    cells[tuple(cur)] = col
        cells[v] = col
        last = v


def _insect_legs(c, k, ys, col, hip, knee, foot, splay):
    """Six legs, one leg part each, solid face to face: for each y (in k) a
    hip at (x, z), a knee further out and higher, a foot on the ground; the
    front pair reaches forward and the back pair back by `splay`. Drawn on
    the right and mirrored exactly for the left."""
    ys = sorted(ys)
    mid = (ys[0] + ys[-1]) / 2
    for i, y in enumerate(ys):
        dy = (y - mid) * splay
        cells = {}
        a = (hip[0] * k, y * k, hip[1] * k)
        b = (knee[0] * k, (y + dy * 0.5) * k, knee[1] * k)
        f = (foot * k, (y + dy) * k, 0)
        _rod(cells, a, b, col)
        _rod(cells, b, f, col)
        for sx in (-1, 1):
            import rig
            part = rig.leg_part(c, 'L' if sx < 0 else 'R', i, len(ys), (sx * hip[0] * k, y * k, hip[1] * k))
            for (x, yy, z), cc in cells.items():
                part.put((x if sx > 0 else -x - 1, yy, z), cc)


def twig(c, H, cols, opts):
    """Plan "twig": a stick insect, thin everywhere: a body two voxels
    across like a twig, a small narrow head, six long thin legs (each its own
    leg part), long thin antennae. Colours col (the twig), accent (knots)."""
    k = H / 10.0
    col = cols['col']
    acc = cols.get('accent') or tuple(round(v * 0.75) for v in col)
    body = c.part('body')
    hz = round(2.2 * k)  # the twig's underside, held up on the legs
    y0, y1 = round(-1.6 * k), round(6.4 * k)
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, y1 - y0)
        knot = (y - y0) % max(3, round(1.6 * k)) == 0
        for x in (-1, 0):
            body.put((x, y, hz), acc if knot else col)
            if t < 0.8:  # two voxels tall, thinning to one at the tail end
                body.put((x, y, hz + 1), acc if knot else col)
    head = c.part('head', 'static', (0, y0, hz + 1))
    hy = y0 - max(2, round(1.0 * k))
    for x in (-2, -1, 0, 1):
        for y in range(hy, y0):
            for z in (hz, hz + 1, hz + 2):
                if abs(x + .5) > 1 and z == hz + 2:
                    continue  # rounded top corners
                head.put((x, y, z), col)
    from creatures import eyes
    eyes(c, head, 1, hz + 1, 1)
    # antennae: long and thin, up and forward from the top of the head
    n = max(4, round(2.4 * k))
    for sx in (-1, 1):
        for i in range(n):
            x = (0 + i // 3) if sx > 0 else -1 - i // 3
            head.put((x, hy - 1 - i, hz + 3 + i // 2), acc)
    # six long thin legs, splayed out to the ground
    _insect_legs(c, k, (-0.6, 1.8, 4.2), acc, hip=(0.5, hz / k), knee=(1.7, hz / k + 0.9), foot=2.8, splay=0.35)
    return c


def termite(c, H, cols, opts):
    """Plan "termite": a pale ant-shaped bug that reads as an insect: a
    brown head (accent) with small dark jaws, a pale thorax, a pinched
    waist and a round banded abdomen; six thin dark legs angled out from
    the thorax (each its own leg part) and thin antennae pointing forward
    and out. Colours col (the pale body), accent (the head), leg (legs,
    antennae, jaws; default a dark brown)."""
    import kit_pond
    k = H / 10.0
    col = cols['col']
    acc = cols.get('accent') or tuple(round(v * 0.6) for v in col)
    leg = cols.get('leg') or tuple(round(v * 0.45) for v in acc)
    band = tuple(round(v * 0.72) for v in col)
    body = c.part('body')
    head = c.part('head', 'static', (0, -2.0 * k, 3.0 * k))
    # three segments with clear gaps, held low: head, thorax, waist, abdomen
    head.ell((0, -3.0 * k, 2.6 * k), (1.2 * k, 1.05 * k, 1.1 * k), acc)
    body.ell((0, -1.2 * k, 2.2 * k), (0.8 * k, 1.1 * k, 0.7 * k), col)
    body.ell((0, 0.05 * k, 2.15 * k), (0.3 * k + .2, 0.4 * k, 0.3 * k + .2), col)
    body.ell((0, 1.85 * k, 2.4 * k), (1.4 * k, 1.65 * k, 1.2 * k), col)
    # darker bands across the abdomen, so it reads as segmented
    step = max(2, round(0.7 * k))
    y0 = round(0.7 * k)
    body.paint(lambda p, cc, g: (band, False) if p[1] > y0 and (p[1] - y0) % step == 0 else None)
    kit_pond.face(c, head, k, 2.7, x_off=0.45, size=0.45, cheek_z=2.0)
    # small dark jaws at the front of the head
    jy, jz = round(-4.05 * k), round(1.8 * k)
    for sx in (-1, 1):
        for i in range(max(1, round(0.6 * k))):
            x = round(0.3 * k) + (1 if i > 0 else 0) - 1
            head.put((x if sx > 0 else kit_pond._mx(x), jy - i, jz), leg)
    # antennae: thin, forward and out from the top front of the head
    n = max(3, round(2.0 * k))
    for sx in (-1, 1):
        x, z = round(0.4 * k), round(3.5 * k)
        for i in range(n):
            y = round(-3.6 * k) - i
            # out one every other step, up one every third, each step touching
            # the last face to face
            if i and i % 2 == 0:
                x += 1
                head.put((x if sx > 0 else kit_pond._mx(x), y + 1, z), leg)
            if i and i % 3 == 0:
                z += 1
                head.put((x if sx > 0 else kit_pond._mx(x), y + 1, z), leg)
            head.put((x if sx > 0 else kit_pond._mx(x), y, z), leg)
    # six thin dark legs from the thorax, the front pair forward, the back pair back
    _insect_legs(c, k, (-2.0, -1.2, -0.4), leg, hip=(0.55, 2.0), knee=(1.5, 2.6), foot=2.4, splay=1.6)
    return c


def wasp(c, H, cols, opts):
    """Plan "wasp": slim and narrow-waisted: a small yellow head, a black
    thorax, a waist as thin as the mirror allows (two voxels wide, one
    tall), a long tapered abdomen in yellow and black bands ending in a dark
    stinger; two narrow pale-amber wings (wingL, wingR), six thin dark legs
    (each its own leg part) and thin antennae. Colours col (yellow), accent
    (black), wing."""
    import kit_pond
    from creatures import eyes
    k = H / 10.0
    col = cols['col']
    acc = cols.get('accent') or INK
    wc = cols.get('wing') or hexc('#F5DFA0')
    body = c.part('body')
    head = c.part('head', 'static', (0, -1.7 * k, 3.2 * k))
    zc = 3.2 * k  # the body's centre line, up on the legs
    # head: small and round, yellow face under a black crown
    head.ell((0, -2.5 * k, zc + 0.1 * k), (1.05 * k, 0.9 * k, 0.95 * k), col)
    crown = zc + 0.8 * k
    head.paint(lambda p, cc, g: (acc, False) if p[2] >= crown else None)
    eyes(c, head, max(1, round(0.4 * k)), round(zc + 0.05 * k), max(1, round(0.4 * k)))
    # thorax: black, with two small yellow marks on the shoulders
    body.ell((0, -1.0 * k, zc), (0.75 * k, 0.85 * k, 0.75 * k), acc)
    for sx in (-1, 1):
        x = round(0.35 * k)
        body.put((x if sx > 0 else kit_pond._mx(x), round(-1.3 * k), round(zc + 0.7 * k) - 1), col)
    # the waist: a thin stalk from the thorax to the abdomen
    wz = round(zc) - 1
    for y in range(round(-0.25 * k), round(0.55 * k) + 1):
        for x in (-1, 0):
            body.put((x, y, wz), acc)
    # the abdomen: swelling quickly, then tapering to the tip, tilted down
    y0, y1 = 0.5 * k, 4.6 * k
    n = max(4, round((y1 - y0) * 1.2))
    band = max(1, round(0.5 * k))
    tip = None
    for i in range(n + 1):
        t = i / n
        prof = math.sin(math.pi * min(1.0, 0.18 + t * 0.95)) ** 0.8
        r = max(0.55, 1.15 * k * prof)
        y = y0 + (y1 - y0) * t
        z = zc - 0.1 * k - 0.5 * k * t * t
        body.ell((0, y, z), (r, 0.6, r * 0.95), col)
        tip = (y, z)
    yb = round(y0 + 0.6 * k)
    body.paint(lambda p, cc, g: (acc, False) if cc == col and p[1] >= yb and ((p[1] - yb) // band) % 2 == 1 else None)
    # the stinger: dark voxels straight back from the tip, touching it
    tail = max((v for v in body.v if v[0] in (-1, 0)), key=lambda v: (v[1], -abs(v[2] - tip[1])))
    for x in (-1, 0):
        for j in range(1, max(2, round(0.6 * k)) + 1):
            body.put((x, tail[1] + j, tail[2]), acc)
    # wings: long and narrow, laid back over the abdomen at a slight angle
    wz2 = round(zc + 0.85 * k)
    for sx in (-1, 1):
        name = 'wingL' if sx < 0 else 'wingR'
        wp = c.part(name, name, (sx * 0.5 * k, -0.9 * k, wz2))
        L, Wd = 3.0 * k, 0.45 * k
        for y in range(round(-1.0 * k), round(-1.0 * k + L) + 1):
            t = (y - (-1.0 * k)) / L
            half = Wd * math.sqrt(max(0.0, 1 - (2 * t - 1) ** 2))
            cx = 0.45 * k + t * 0.9 * k  # angled out towards the tip
            for x in range(math.floor(cx - half), math.ceil(cx + half)):
                xx = max(0, x)
                edge = abs(x + 0.5 - cx) > half - 1 or t > 0.9
                wp.put((xx if sx > 0 else kit_pond._mx(xx), y, wz2), _mix(wc, (214, 140, 40), 0.55) if edge else wc)
    # antennae: thin and dark, up and forward from the top of the head,
    # each voxel touching the last face to face
    m = max(3, round(1.6 * k))
    y0a = round(-2.7 * k)
    for sx in (-1, 1):
        x = round(0.3 * k)
        z = max(v[2] for v in head.v if v[0] == x and v[1] == y0a) + 1
        for i in range(m):
            y = y0a - i
            if i and i % 2 == 0:
                x += 1
                head.put((x if sx > 0 else kit_pond._mx(x), y + 1, z), acc)
            if i and i <= m // 2:
                z += 1
                head.put((x if sx > 0 else kit_pond._mx(x), y + 1, z), acc)
            head.put((x if sx > 0 else kit_pond._mx(x), y, z), acc)
    # six short legs folded under the thorax and angled back, as a flying
    # wasp holds them (it hovers, so they never reach the ground)
    import rig
    zb = round(zc - 0.6 * k)  # just under the thorax
    for i, y in enumerate((-1.5, -1.0, -0.5)):
        cells = {}
        a0 = (0.5 * k, y * k, zb)
        b0 = (0.9 * k, (y + 0.3) * k, zb - 0.8 * k)
        f0 = (1.0 * k, (y + 0.9) * k, zb - 1.3 * k)
        _rod(cells, a0, b0, acc)
        _rod(cells, b0, f0, acc)
        for sx in (-1, 1):
            part = rig.leg_part(c, 'L' if sx < 0 else 'R', i, 3, (sx * 0.5 * k, y * k, zb + 0.5))
            for (x, yy, z), cc in cells.items():
                part.put((x if sx > 0 else -x - 1, yy, z), cc)
    return c


def strider(c, H, cols, opts):
    """Plan "strider": a water strider, skating: a thin body about four
    times longer than wide held low, a small head, one short front pair of
    legs and two very long pairs splayed flat and wide (a span three times
    the body's length), with pale ripple rings under the four long feet.
    Each leg is its own leg part. Colours col (body), accent (legs),
    ripple."""
    import kit_pond
    from creatures import eyes
    k = H / 10.0
    col = cols['col']
    acc = cols.get('accent') or tuple(round(v * 0.7) for v in col)
    rip = cols.get('ripple') or hexc('#CFEFFF')
    back = tuple(min(255, round(v * 1.25)) for v in col)
    body = c.part('body')
    zc = 2.0 * k
    # the body: two voxels wide (one each side of the midline), eight long
    y0, y1 = round(-1.2 * k), round(2.8 * k)
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, y1 - y0)
        for x in (-1, 0):
            body.put((x, y, round(zc)), col)
            body.put((x, y, round(zc) + 1), col)
        if 0.1 < t < 0.7 and k >= 1.5:  # a little wider and a lighter back at the middle
            for x in (-2, 1):
                body.put((x, y, round(zc)), col)
            for x in (-1, 0):
                body.put((x, y, round(zc) + 2), back)
    head = c.part('head', 'static', (0, y0, round(zc) + 1))
    hy = y0 - max(2, round(0.9 * k))
    for x in (-2, -1, 0, 1):
        for y in range(hy, y0):
            for z in (round(zc), round(zc) + 1, round(zc) + 2):
                if abs(x + .5) > 1 and z == round(zc) + 2:
                    continue
                head.put((x, y, z), col)
    eyes(c, head, 1, round(zc) + 1, 1)
    # short antennae forward
    for sx in (-1, 1):
        for i in range(max(2, round(0.8 * k))):
            x = 0 if sx > 0 else -1
            head.put((x + sx * (i // 2), hy - 1 - i, round(zc) + 2), acc)

    def leg(i, hip_y, foot, knee_z, ripple):
        # drawn on the right, then mirrored exactly for the left
        cells = {}
        a = (1.0, hip_y, zc)
        b = (foot[0] * 0.35, hip_y + (foot[1] - hip_y) * 0.35, knee_z)
        f = (foot[0], foot[1], 0)
        _rod(cells, a, b, acc)
        _rod(cells, b, f, acc)
        if ripple:
            fx, fy = math.floor(foot[0]), math.floor(foot[1])
            R = max(1.6, 0.9 * k)
            for x in range(math.floor(fx - R - 1), math.ceil(fx + R + 2)):
                for y in range(math.floor(fy - R - 1), math.ceil(fy + R + 2)):
                    d = math.hypot(x - fx, y - fy)
                    if R - 0.75 <= d <= R + 0.25:
                        cells[(x, y, 0)] = rip
        for sx in (-1, 1):
            part = kit_pond._leg(c, sx, i, 3, (sx * 1.0, hip_y, zc + 0.5))
            for (x, y, z), cc in cells.items():
                part.put((x if sx > 0 else -x - 1, y, z), cc)
    L = 5.2 * k  # how far out the long feet reach
    leg(0, y0 + 1, (1.6 * k, -2.4 * k), zc + 0.5 * k, False)          # short front pair
    leg(1, round(0.4 * k), (L, -1.0 * k), zc + 1.5 * k, True)      # long middle pair
    leg(2, round(1.0 * k), (L * 0.9, 4.6 * k), zc + 1.3 * k, True)  # long back pair
    return c


def shieldbug(c, H, cols, opts):
    """Plan "shieldbug": a flat-topped shield for a back, broad squared
    shoulders tapering to a point at the rear, with a darker triangular
    plate in the middle; a small head in front with eyes and thin antennae,
    six short dark legs (each its own leg part). Colours col (the shield),
    accent (the plate), leg."""
    from creatures import eyes
    k = H / 10.0
    col = cols['col']
    acc = cols.get('accent') or tuple(round(v * 0.6) for v in col)
    leg = cols.get('leg') or tuple(round(v * 0.55) for v in col)
    rim = tuple(min(255, round(v * 1.15)) for v in col)
    body = c.part('body')
    z0, z1 = round(2.0 * k), round(3.5 * k)  # underside, flat top
    yf, ys, yb = -1.0 * k, 0.4 * k, 3.4 * k  # front, end of the shoulders, the point
    W = 2.5 * k
    for y in range(math.floor(yf), math.ceil(yb) + 1):
        yc = y + 0.5
        if yc < yf or yc > yb:
            continue
        half = W if yc <= ys else W * (yb - yc) / (yb - ys)
        if yc < yf + 0.5 * k:  # squared shoulders, just the corners rounded
            half = W - max(0.0, (yf + 0.5 * k - yc)) * 0.8
        n = math.floor(half)
        for x in range(0, n):
            for z in range(z0, z1 + 1):
                edge = x == n - 1
                if edge and z >= z1 - 1 or x == n - 2 and z == z1:
                    continue  # bevel the top edge down, two steps
                cc = rim if (edge and z == z1 - 2) or (x == n - 2 and z == z1 - 1) else col
                body.put((x, y, z), cc)
                body.put((-x - 1, y, z), cc)
    # the triangular plate in the middle of the back
    py0, py1, pw = 0.0 * k, 2.4 * k, 1.3 * k
    for (x, y, z), (cc, g) in list(body.v.items()):
        if z == z1 and py0 <= y + 0.5 <= py1:
            half = pw * (py1 - (y + 0.5)) / (py1 - py0)
            if abs(x + 0.5) <= half:
                body.v[(x, y, z)] = (acc, False)
    # a dark underside
    for x in range(-math.floor(W * 0.7), math.floor(W * 0.7)):
        for y in range(math.floor(yf + 0.4 * k), math.floor(yb - 0.8 * k)):
            body.put((x, y, z0 - 1), leg)
    head = c.part('head', 'static', (0, yf, round(2.4 * k)))
    for x in range(-round(0.8 * k), round(0.8 * k)):
        for y in range(round(yf - 0.9 * k), round(yf)):
            for z in range(round(2.0 * k), round(3.2 * k)):
                head.put((x, y, z), col)
    eyes(c, head, max(1, round(0.4 * k)), round(2.5 * k), max(1, round(0.35 * k)))
    # antennae: one voxel thin, a step up then forward and out
    hy = round(yf - 0.9 * k)
    zt = round(3.2 * k) - 1
    n = max(3, round(1.2 * k))
    for sx in (-1, 1):
        cells = []
        x, y, z = max(0, round(0.3 * k)), hy, zt
        cells.append((x, y, z))
        z += 1
        cells.append((x, y, z))
        for i in range(n):
            y -= 1
            cells.append((x, y, z))
            if i % 2 == 1:
                x += 1
                cells.append((x, y, z))
        for (x, y, z) in cells:
            head.put((x if sx > 0 else -x - 1, y, z), leg)
    # six thin legs: straight out from under the shield's edge, then down
    import rig
    xe = math.floor(W * 0.75)
    for i, ly in enumerate((-0.4, 0.8, 2.0)):
        y = round(ly * k)
        out = max(2, round(0.6 * k))
        for sx in (-1, 1):
            part = rig.leg_part(c, 'L' if sx < 0 else 'R', i, 3, (sx * (xe + 0.5), y + 0.5, z0 - 0.5))
            for j in range(out + 1):
                xx = xe + j
                part.put((xx if sx > 0 else -xx - 1, y, z0 - 1), leg)
            xx = xe + out
            for z in range(0, z0 - 1):
                part.put((xx if sx > 0 else -xx - 1, y, z), leg)
    return c


def shrimp(c, H, cols, opts):
    """Plan "shrimp": a body arched in a gentle curve from a small head to a
    fan tail, in bands; two thin feelers sweeping back past the tail (about
    one and a half body lengths), eyes on the head, six short legs (each its
    own leg part). Colours col, accent (bands and fan), leg."""
    from creatures import eyes
    k = H / 10.0
    col = cols['col']
    acc = cols.get('accent') or tuple(round(v * 0.8) for v in col)
    leg = cols.get('leg') or acc
    body = c.part('body')
    n = 7
    y0, y1 = -0.6 * k, 4.0 * k
    pts = []
    for i in range(n):
        t = i / (n - 1)
        y = y0 + (y1 - y0) * t
        z = 1.5 * k + 1.0 * k * math.sin(math.pi * min(1.0, t * 1.15)) - 0.4 * k * t
        r = 1.15 * k * (1 - 0.55 * t)
        pts.append((y, z, r))
        body.ell((0, y, z), (r, 0.55 * k + .3, r * 0.95), col if i % 2 == 0 else acc)
    # the fan tail
    ty, tz, _ = pts[-1]
    for sx in (-1, 1):
        body.ell((sx * 0.55 * k, ty + 0.9 * k, tz - 0.3 * k), (0.6 * k, 0.8 * k, 0.25 * k + .3), acc)
    head = c.part('head', 'static', (0, y0, 1.8 * k))
    head.ell((0, -1.4 * k, 1.9 * k), (0.95 * k, 1.0 * k, 0.9 * k), col)
    eyes(c, head, max(1, round(0.35 * k)), round(2.0 * k), max(1, round(0.4 * k)))
    # a small spike over the face
    for i in range(max(2, round(0.8 * k))):
        for x in (-1, 0):
            head.put((x, round(-2.2 * k) - i, round(2.6 * k)), acc)
    # feelers: up from the head, then sweeping back past the tail
    length = (y1 - y0) * 1.5
    cells = {}
    p0 = (0.4 * k, -2.0 * k, 2.6 * k)
    p1 = (1.1 * k, -2.8 * k, 3.8 * k)
    p2 = (1.8 * k, -1.0 * k, 4.4 * k)
    p3 = (2.3 * k, -2.0 * k + length * 0.75, 2.8 * k)
    p4 = (2.4 * k, -2.0 * k + length, 1.6 * k)
    for a0, b0 in ((p0, p1), (p1, p2), (p2, p3), (p3, p4)):
        _rod(cells, a0, b0, leg)
    for sx in (-1, 1):
        for (x, y, z), cc in cells.items():
            head.put((x if sx > 0 else -x - 1, y, z), cc)
    _insect_legs(c, k, (-0.4, 0.5, 1.4), leg, hip=(0.5, 1.2), knee=(1.3, 1.4), foot=1.6, splay=0.4)
    return c


def _mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


PLANS = {'twig': ({'col', 'accent'}, {}), 'termite': ({'col', 'accent', 'leg'}, {}),
         'wasp': ({'col', 'accent', 'wing'}, {}), 'strider': ({'col', 'accent', 'ripple'}, {}),
         'shieldbug': ({'col', 'accent', 'leg'}, {}), 'shrimp': ({'col', 'accent', 'leg'}, {})}
BUILDERS = {'twig': twig, 'termite': termite, 'wasp': wasp, 'strider': strider, 'shieldbug': shieldbug,
            'shrimp': shrimp}
