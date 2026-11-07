"""Signature features for the legacy farm and woodland Commons (strict
review of the 118 legacy Commons, Nov 5): the bird beaks, tails, combs and
face markings, and the hoofed and woodland heads (muzzles, ears, horns,
manes, tails, wool, quills) that the shared bird and quadruped plans draw
the same for every animal. Owner: the Common A builder.

Each accessory replaces the plan's version of its feature where there is
one (the beak, the tail, the ears, the crest), so an animal keeps the plan's
body, eyes and walk and gets its own signature on top. Same art frame and
fn(c, H, col, col2, a) signature as kit_quirks.py: x right, -y front, z up,
k = H / 10; colours are (r, g, b).

Birds: **bird_beak** (style small, hooked, long, chisel), **bird_tail**
(sickle, fan, long, cocked), **comb** (comb and wattles), **plume** (a
quail's teardrop topknot), **casque** (a guineafowl's horny crown) and
**polka** (small even dots all over).
Heads: **head_paint** (regions: all, cap, nape, face, mask, cheek, bib,
brow, eye, xband, throat), **muzzle** (horse, cow, goat, wolf), **ears2**
(donkey, banana, side, wolf, small_round), **horns2** (wide, curl, back),
**mane2** (ridge, thick; forelock), **ruff**, **eyes_big**.
Bodies: **tail2** (hang, down, out, stub), **wool**, **quills**,
**chest**."""
import math

import kit_quirks as q
from voxkit import hexc

INK, WHITE = hexc('#1B1B2F'), hexc('#FFFFFF')
_find, _line, _rod, _hash, _mix = q._find, q._line, q._rod, q._hash, q._mix


def _k(H):
    return H / 10.0


def _mx(x):
    """The mirror of voxel column x across the middle (x = -0.5)."""
    return -x - 1


def _both(part, x, y, z, col):
    part.put((x, y, z), col)
    part.put((_mx(x), y, z), col)


def _ball(part, cx, cy, cz, r, col, mirror=False):
    """A ball of radius r round (cx, cy, cz) (voxel centres), mirrored to the
    left side too when asked."""
    R = int(math.ceil(r)) + 1
    for x in range(math.floor(cx) - R, math.floor(cx) + R + 1):
        for y in range(math.floor(cy) - R, math.floor(cy) + R + 1):
            for z in range(math.floor(cz) - R, math.floor(cz) + R + 1):
                if (x + .5 - cx) ** 2 + (y + .5 - cy) ** 2 + (z + .5 - cz) ** 2 <= r * r:
                    part.put((x, y, z), col)
                    if mirror:
                        part.put((_mx(x), y, z), col)


def _tube(part, pts, r0, r1, col, colfn=None, mirror=False):
    """Balls along a polyline, the radius going from r0 to r1, so it reads
    as one solid tube (each ball overlaps the last)."""
    n = len(pts)
    seg = []
    for i in range(n - 1):
        a, b = pts[i], pts[i + 1]
        steps = max(1, int(math.ceil(max(abs(b[j] - a[j]) for j in range(3)) * 2)))
        for s in range(steps):
            t = s / steps
            seg.append(tuple(a[j] + (b[j] - a[j]) * t for j in range(3)))
    seg.append(pts[-1])
    for i, p in enumerate(seg):
        t = i / max(1, len(seg) - 1)
        r = r0 + (r1 - r0) * t
        _ball(part, p[0], p[1], p[2], max(0.5, r), colfn(t) if colfn else col, mirror)


def _bounds(vox):
    xs, ys, zs = zip(*vox)
    return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def _eyes(c):
    """(z centre, front y, x of the inner edge on the right) of the eyes, or
    None."""
    e = _find(c, 'eyes')
    if not e or not e.v:
        return None
    zs = [p[2] for p in e.v]
    xs = [p[0] for p in e.v if p[0] >= 0]
    return (sum(zs) / len(zs), min(p[1] for p in e.v), min(xs) if xs else 0, max(xs) if xs else 0)


def _head(c):
    head = _find(c, 'head')
    return head if head and head.v else None


def _face_y(head, z):
    """The front of the head's middle columns at height z."""
    ys = [p[1] for p in head.v if p[2] == z and -2 <= p[0] <= 1]
    return min(ys) if ys else min(p[1] for p in head.v)


def _clear(c, name):
    p = _find(c, name)
    if p is not None:
        p.v = {}
    return p


# ------------------------------------------------------------------ birds

def bird_beak(c, H, col, col2=None, a=None):
    """A bird's own beak in place of the plan's flat box: small (a songbird
    or gamebird: short, pointed), hooked (a parrot), long (a wader: long and
    thin), chisel (a woodpecker: long, straight and strong). `length` scales
    it."""
    a = a or {}
    k = _k(H)
    head = _head(c)
    if head is None:
        return
    style = a.get('style', 'small')
    # the plan's beak: the frontmost head voxels, ahead of the face
    ymin = min(p[1] for p in head.v)
    old = head.v.get((0, ymin, 0)) or next(v for p, v in head.v.items() if p[1] == ymin)
    bcol = old[0]
    beak = {p for p, v in head.v.items() if v[0] == bcol and p[1] <= ymin + max(2, round(0.8 * k))}
    hz = sorted({p[2] for p in beak})
    zc = (hz[0] + hz[-1]) / 2 if hz else min(p[2] for p in head.v) + 2 * k
    for p in beak:
        del head.v[p]
    # fill the face where the old beak sat inside it
    for p in beak:
        if (p[0], p[1] + 1, p[2]) in head.v and p[1] >= _face_y(head, p[2]) - 0:
            head.put(p, head.v[(p[0], p[1] + 1, p[2])][0])
    zc = round(zc)
    yf = _face_y(head, zc)
    bp = c.part('beak', 'static')
    L = {'small': 0.75, 'hooked': 0.8, 'long': 2.0, 'chisel': 1.35}[style] * k * a.get('length', 1.0)
    L = max(2, round(L))
    for i in range(L):
        t = i / max(1, L - 1)
        y = yf - 1 - i
        if style == 'small':  # two high at the root, one at the point
            top, bot = (zc + 1 if t < 0.5 else zc), zc
        elif style == 'hooked':  # deep at the root, curving down to the tip
            top, bot = (zc + 1 if t < 0.5 else zc), zc - 1
        elif style == 'long':
            dz = -round(t * 0.35 * k)
            top, bot = zc + dz + (1 if t < 0.35 else 0), zc + dz
        else:  # chisel: straight and strong, two high most of the way
            top, bot = zc + (1 if t < 0.7 else 0), zc
        for z in range(bot, top + 1):
            for x in (-1, 0):
                bp.put((x, y, z), col)
    if style == 'hooked':  # the tip curls down under the root
        for x in (-1, 0):
            bp.put((x, yf - L, zc - 1), col2 or col)
            bp.put((x, yf - L, zc - 2), col2 or col)


def bird_tail(c, H, col, col2=None, a=None):
    """A bird's tail where the tail is the animal: sickle (a rooster's arched
    feathers), fan (a turkey's upright fan), long (a pheasant's or magpie's
    long straight tail, barred in col2 when given), cocked (a wren's, straight
    up). It replaces the plan's stub and swings as the bird walks."""
    a = a or {}
    k = _k(H)
    body = _find(c, 'body')
    if not body or not body.v:
        return
    style = a.get('style', 'long')
    old = _find(c, 'tail')
    if old is not None:
        c.parts.remove(old)
    (x0, y0, z0), (x1, y1, z1) = _bounds(body.v)
    zc = (z0 + z1) / 2
    back = [p for p in body.v if p[0] in (-1, 0)]
    yb = max(p[1] for p in back)
    zr = round(zc + 0.4 * k)
    root = (0, yb, zr)
    t = c.part('tail', 'tail', root)
    L = a.get('length', 1.0)
    if style == 'sickle':
        # three arched feathers: up and back, then over and down
        for i, (R, th1) in enumerate(((2.0, 170), (2.6, 160), (1.6, 150))):
            R = R * k * L
            pts = []
            for d in range(0, th1 + 1, 10):
                th = math.radians(d)
                pts.append((-0.5 + (i - 1) * 0.9, yb - 0.3 * k + R * (1 - math.cos(th)) * 0.62, zr + R * math.sin(th) * 0.95))
            _tube(t, pts, 0.75, 0.6, col, colfn=lambda s: (col2 or col) if s > 0.85 else col)
    elif style == 'fan':
        # an upright half disc of feathers just behind the body, banded
        R = 3.0 * k * L
        cz = zc - 0.2 * k
        for x in range(-math.ceil(R), math.ceil(R)):
            for z in range(math.floor(cz - 0.6 * k), math.ceil(cz + R)):
                d = math.hypot(x + .5, z + .5 - cz)
                if d > R or (z + .5 - cz) < -0.6 * k:
                    continue
                band = col2 if (col2 and int(d / max(2, round(0.55 * k))) % 2 == 1 and d > 1.2 * k) else col
                if d > R - 1:
                    band = _mix(col, hexc('#F2E2C2'), 0.6)  # pale feather tips round the rim
                for dy in range(2):
                    t.put((x, yb + 1 + dy, z), band)
        # the fan's root joins the body
        for z in range(round(cz - 0.6 * k), round(cz + 1.2 * k)):
            for x in (-1, 0):
                t.put((x, yb, z), col)
    elif style == 'long':
        n = max(4, round(3.2 * k * L))
        w = max(1, round(0.35 * k))
        bars = max(2, round(0.45 * k))
        for i in range(n):
            s = i / (n - 1)
            y = yb + 1 + i
            z = zr - round(s * a.get('droop', 0.25) * 3 * k)
            ww = max(1, round(w * (1 - 0.4 * s)))
            cc = col2 if (col2 and (i // bars) % 2 == 1) else col
            for x in range(-ww, ww):
                for dz in (0, 1) if s < 0.8 else (0,):
                    t.put((x, y, z + dz), cc)
            if i:  # step down face to face, never a diagonal
                zp = zr - round((i - 1) / (n - 1) * a.get('droop', 0.25) * 3 * k)
                for zz in range(min(z, zp), max(z, zp) + 1):
                    t.put((-1, y, zz), cc)
                    t.put((0, y, zz), cc)
    elif style == 'cocked':
        n = max(4, round(2.6 * k * L))
        w = max(1, round(0.75 * k))
        for i in range(n):
            s = i / (n - 1)
            z = zr + i
            y = yb + round(0.5 * k * s)
            ww = w + (1 if s > 0.6 else 0)  # the tip fans a little
            for x in range(-ww, ww):
                for dy in range(2):
                    t.put((x, y + dy, z), col)
        # bars across the tail (a wren's)
        if col2:
            for (x, y, z) in list(t.v):
                if (z - zr) % max(2, round(0.5 * k)) == 0 and z > zr + 1:
                    t.put((x, y, z), col2)


def comb(c, H, col, col2=None, a=None):
    """A rooster's tall red comb (three rounded lobes front to back on the
    crown) and two wattles hanging under the beak, in col."""
    a = a or {}
    k = _k(H)
    head = _head(c)
    if head is None:
        return
    _clear(c, 'crest')
    cp = c.part('comb', 'static')
    top = max(p[2] for p in head.v)
    tops = [p for p in head.v if p[2] == top]
    yc = sum(p[1] for p in tops) / len(tops)
    s = a.get('size', 1.0)
    for i, (dy, h) in enumerate(((-0.75, 1.1), (0.0, 1.4), (0.75, 1.0))):
        y = yc + dy * k * s
        _ball(cp, -0.5, y, top + h * 0.55 * k * s, 0.55 * k * s + 0.3, col)
        for z in range(top, round(top + h * 0.55 * k * s) + 1):
            cp.put((-1, round(y), z), col)
            cp.put((0, round(y), z), col)
    if a.get('wattles', True):
        ey = _eyes(c)
        ymin = min(p[1] for p in head.v)
        bz = round(ey[0] - 1.1 * k) if ey else top - round(2.5 * k)
        w = c.part('wattles', 'static')
        for x in (-1, 0):
            for i in range(max(2, round(0.9 * k))):
                w.put((x, ymin + 1 + (i // 3), bz - i), col)
        _ball(w, -0.5, ymin + 1.5, bz - round(0.9 * k), 0.45 * k + 0.2, col)


def plume(c, H, col, col2=None, a=None):
    """A quail's topknot: a thin stem up from the crown that curls forward
    into a teardrop over the beak."""
    k = _k(H)
    head = _head(c)
    if head is None:
        return
    _clear(c, 'crest')
    p = c.part('plume', 'static')
    top = max(v[2] for v in head.v)
    tops = [v for v in head.v if v[2] == top]
    y0 = sum(v[1] for v in tops) / len(tops) - 0.3 * k
    pts = [(-0.5, y0, top + 0.5), (-0.5, y0 - 0.2 * k, top + 0.9 * k), (-0.5, y0 - 0.7 * k, top + 1.4 * k),
           (-0.5, y0 - 1.3 * k, top + 1.5 * k)]
    _tube(p, pts, 0.55, 0.55, col)
    _ball(p, -0.5, y0 - 1.5 * k, top + 1.15 * k, 0.3 * k + 0.45, col)


def casque(c, H, col, col2=None, a=None):
    """A guineafowl's horny casque: a short, slightly backswept knob on the
    crown, and red wattles under the beak in col2."""
    k = _k(H)
    head = _head(c)
    if head is None:
        return
    _clear(c, 'crest')
    p = c.part('casque', 'static')
    top = max(v[2] for v in head.v)
    tops = [v for v in head.v if v[2] == top]
    y0 = sum(v[1] for v in tops) / len(tops)
    _tube(p, [(-0.5, y0, top), (-0.5, y0 + 0.35 * k, top + 0.8 * k), (-0.5, y0 + 0.6 * k, top + 1.3 * k)],
          0.55 * k, 0.35 * k, col)
    if col2:
        ey = _eyes(c)
        ymin = min(v[1] for v in head.v)
        bz = round(ey[0] - 1.0 * k) if ey else top - round(2.5 * k)
        w = c.part('wattles', 'static')
        for x in (1, _mx(1)):
            for i in range(max(2, round(0.7 * k))):
                w.put((x, ymin + 2, bz - i), col2)


def polka(c, H, col, col2=None, a=None):
    """Small, even white dots all over the body, wings and tail (a
    guineafowl's): one voxel dots on a staggered grid."""
    a = a or {}
    k = _k(H)
    step = max(2, round(a.get('step', 1.3) * k))
    names = a.get('parts', ['body', 'wingL', 'wingR', 'tail'])
    for name in names:
        part = _find(c, name)
        if not part or not part.v:
            continue
        vox = part.v
        zs = [p[2] for p in vox]
        zfrom = min(zs) + (max(zs) - min(zs)) * a.get('zfrom', 0.0)
        # one dot per step-sized cell of space the surface passes through,
        # on a hashed voxel of that cell, never touching another dot: even
        # spacing on the top, the sides and the wings alike
        cells = {}
        for (x, y, z), (cc, g) in vox.items():
            if g or cc in (INK, WHITE) or z < zfrom:
                continue
            if all(n in vox for n in ((x + 1, y, z), (x - 1, y, z), (x, y + 1, z), (x, y - 1, z), (x, y, z + 1), (x, y, z - 1))):
                continue
            key = (x // step, y // step, z // step)
            h = ((x * 73856093) ^ (y * 19349663) ^ (z * 83492791)) & 0xffff
            if key not in cells or h < cells[key][0]:
                cells[key] = (h, (x, y, z))
        dots = set()
        for _, p in sorted(cells.values()):
            x, y, z = p
            if any((x + dx, y + dy, z + dz) in dots for dx in (-1, 0, 1) for dy in (-1, 0, 1) for dz in (-1, 0, 1)):
                continue
            dots.add(p)
            vox[p] = (col, False)


# ------------------------------------------------------------------ heads

def head_paint(c, H, col, col2=None, a=None):
    """Paints a region of the head (never the eyes): all, cap (the crown down
    to the eyes), nape (the back of the crown), face (the front half), mask
    (round the beak or muzzle), cheek (the sides below the eyes), bib (under
    the beak, down the throat and onto the chest), brow (a thin stripe over
    each eye, back to the nape), eye (a patch round each eye), xband (the
    columns `x0`..`x1`, in k, either side of the middle)."""
    a = a or {}
    k = _k(H)
    head = _head(c)
    if head is None:
        return
    region = a.get('region', 'all')
    ey = _eyes(c)
    (hx0, hy0, hz0), (hx1, hy1, hz1) = _bounds(head.v)
    hy = (hy0 + hy1) / 2
    ez = ey[0] if ey else (hz0 + hz1) / 2
    ef = ey[1] if ey else hy0
    exo = ey[3] if ey else 1.0 * k
    exi = ey[2] if ey else 0.5 * k
    ecx = (exi + exo + 1) / 2
    w = a.get('width', 1.0)

    def test(p):
        x, y, z = p
        ax = abs(x + .5)
        if region == 'all':
            return True
        if region == 'cap':
            back = a.get('back')  # and down the back of the head to the neck
            return z >= ez - a.get('down', 0.2) * k or (back is not None and y > hy + back * k)
        if region == 'nape':
            return ez - 0.4 * k <= z <= ez + 1.3 * k and y > hy + a.get('from', 0.45) * k
        if region == 'face':
            return y < hy - 0.2 * k
        if region == 'mask':
            return y < ef + 1.0 * k * w and abs(z + .5 - (ez - 0.5 * k)) <= 0.95 * k * w and ax <= 1.7 * k * w
        if region == 'cheek':
            return z < ez + a.get('up', -0.2) * k and z > ez - 1.6 * k * w and ax > 0.8 * k and y < hy + 0.6 * k
        if region == 'bib':
            return z < ez - 1.0 * k and y < hy + 0.2 * k and ax <= 1.3 * k * w
        if region == 'brow':
            zz = ez + 0.75 * k + (y - ef) * 0.08
            return abs(z + .5 - zz) <= max(0.6, 0.3 * k * w) and ax >= exi - 0.2 * k and y >= ef
        if region == 'eye':
            return math.hypot(ax - ecx, z + .5 - ez) <= 0.95 * k * w and y < hy + 0.4 * k
        if region == 'xband':
            return a.get('x0', 0) * k <= ax <= a.get('x1', 0.5) * k
        if region == 'throat':
            return z < ez - 0.9 * k and y < hy - 0.3 * k and ax <= 1.2 * k * w
        return False

    if region == 'cap' and a.get('trim', False):
        # a lone bump on the crown reads as the knob of a hat under a cap
        zt = max(p[2] for p in head.v)
        crown = [p for p in head.v if p[2] == zt]
        if len(crown) <= 6:
            for p in crown:
                del head.v[p]
    only = hexc(a['only']) if a.get('only') else None  # opt-in: repaint just this colour
    for p, (cc, g) in list(head.v.items()):
        if g or cc == INK or (cc == WHITE and region not in ('all', 'cap')):
            continue
        if only is not None and cc != only:
            continue
        if test(p):
            head.v[p] = (col, False)
    if region == 'bib' and a.get('chest', True):
        body = _find(c, 'body')
        if body and body.v:
            (bx0, by0, bz0), (bx1, by1, bz1) = _bounds(body.v)
            for p, (cc, g) in list(body.v.items()):
                if not g and p[1] < by0 + 0.8 * k and p[2] > bz1 - 1.2 * k and abs(p[0] + .5) <= 1.2 * k * w:
                    body.v[p] = (col, False)


def chest(c, H, col, col2=None, a=None):
    """A bright bib on the throat and chest (a pine marten's): the head's
    underside and the body's front, top to the legs."""
    a = a or {}
    k = _k(H)
    head = _head(c)
    body = _find(c, 'body')
    if body and body.v:
        (bx0, by0, bz0), (bx1, by1, bz1) = _bounds(body.v)
        for p, (cc, g) in list(body.v.items()):
            if not g and p[1] < by0 + a.get('depth', 1.4) * k and p[2] > bz0 + 1.6 * k and abs(p[0] + .5) <= 1.3 * k:
                body.v[p] = (col, False)
    if head:
        ey = _eyes(c)
        ez = ey[0] if ey else 0
        hz0 = min(p[2] for p in head.v)
        for p, (cc, g) in list(head.v.items()):
            if not g and cc != INK and p[2] < ez - 1.0 * k and p[2] < hz0 + 1.3 * k and abs(p[0] + .5) <= 1.4 * k:
                head.v[p] = (col, False)


def muzzle(c, H, col, col2=None, a=None):
    """A real muzzle in place of the plan's button snout: horse (long and
    deep, nostrils at the end), cow (broad and flat, a wide pink nose), goat
    (narrow and long), wolf (tapering, a black nose on top of the tip).
    col is the muzzle, col2 the nose (ink by default)."""
    a = a or {}
    k = _k(H)
    head = _head(c)
    if head is None:
        return
    style = a.get('style', 'horse')
    nose = col2 or INK
    ey = _eyes(c)
    ez = ey[0] if ey else max(p[2] for p in head.v) - 2 * k
    # the plan's snout and its ink nose go: everything ahead of the face
    # below the eyes
    yfe = min(p[1] for p in head.v if abs(p[2] - ez) <= 1)
    for p in [p for p in head.v if p[1] < yfe and p[2] < ez]:
        del head.v[p]
    for p, (cc, g) in list(head.v.items()):
        if cc == INK:
            head.v[p] = (col, False)
    L, R, Rz, dz = {'horse': (1.9, 0.95, 0.85, 1.25), 'cow': (1.1, 1.35, 0.85, 1.25), 'goat': (1.6, 0.75, 0.7, 1.2),
                    'wolf': (1.5, 0.85, 0.7, 1.0), 'otter': (0.8, 1.25, 0.7, 1.0)}[style]
    L *= a.get('length', 1.0)
    zc = ez - dz * k
    yb = yfe + 0.8 * k  # starts inside the face
    yt = yfe - L * k
    pts = [(-0.5, yb, zc + (0.15 * k if style == 'wolf' else 0)), (-0.5, (yb + yt) / 2, zc), (-0.5, yt + R * k * 0.6, zc - (0.2 * k if style in ('wolf', 'goat') else 0))]
    taper = {'horse': 0.95, 'cow': 1.0, 'goat': 0.8, 'wolf': 0.7, 'otter': 0.9}[style]
    n = 14
    for i in range(n + 1):
        t = i / n
        if t <= 0.5:
            p0, p1, s = pts[0], pts[1], t / 0.5
        else:
            p0, p1, s = pts[1], pts[2], (t - 0.5) / 0.5
        cx, cy, cz = (p0[j] + (p1[j] - p0[j]) * s for j in range(3))
        r = R * k * (1 - (1 - taper) * t)
        rz = Rz * k * (1 - (1 - taper) * t)
        rr = r
        for x in range(math.floor(cx - rr) - 1, math.ceil(cx + rr) + 1):
            for z in range(math.floor(cz - rz) - 1, math.ceil(cz + rz) + 1):
                for y in range(math.floor(cy - 0.6) - 1, math.ceil(cy + 0.6) + 1):
                    if ((x + .5 - cx) / rr) ** 2 + ((z + .5 - cz) / rz) ** 2 + ((y + .5 - cy) / 0.9) ** 2 <= 1:
                        if (x, y, z) not in head.v or head.v[(x, y, z)][0] != INK:
                            head.put((x, y, z), col)
    # the nose
    front = min(p[1] for p in head.v)
    tip_z = [p[2] for p in head.v if p[1] == front]
    tz = round(sum(tip_z) / len(tip_z))
    if style == 'wolf':
        for x in (-1, 0):
            for z in (tz, tz + 1):
                f = head.front(x, z)
                if f:
                    head.put(f, nose)
                    head.put((f[0], f[1] + 1, f[2]), nose)
        top = max(p[2] for p in head.v if p[1] == front)
        for x in (-1, 0):
            head.put((x, front, top), nose)
    elif style == 'otter':
        # a dark nose on top of the broad pad and whisker dots on each side
        for x in (-1, 0):
            f = head.front(x, tz + 1)
            if f:
                head.put(f, nose)
        for sx in (1, -1):
            for j, dz in enumerate((0, -1)):
                x = round(0.75 * k) + j if sx > 0 else _mx(round(0.75 * k) + j)
                f = head.front(x, tz + dz)
                if f:
                    head.put(f, _mix(col, INK, 0.55))
    elif style == 'cow':
        # a broad pink nose pad across the front, nostrils at its sides
        for p in [p for p in head.v if p[1] <= front + 1 and abs(p[2] + .5 - zc) <= 0.6 * k]:
            head.v[p] = (col2 or hexc('#E89AA0'), False)
        for x in (round(0.55 * k), _mx(round(0.55 * k))):
            f = head.front(x, round(zc))
            if f:
                head.put(f, INK)
    else:
        # nostrils, one each side of the middle near the end
        for sx in (1, -1):
            x = max(1, round(0.4 * k)) if sx > 0 else _mx(max(1, round(0.4 * k)))
            f = head.front(x, tz)
            if f:
                head.put(f, nose)
                if k >= 2:
                    f2 = head.front(x, tz + 1)
                    if f2:
                        head.put(f2, nose)
        if style == 'horse' and a.get('dark_end', True):
            # a slightly darker muzzle end
            for p, (cc, g) in list(head.v.items()):
                if cc == col and p[1] <= front + round(0.5 * k):
                    head.v[p] = (_mix(col, INK, 0.12), False)


def ears2(c, H, col, col2=None, a=None):
    """Ears in place of the plan's: donkey (long, wide apart, angled out),
    banana (a llama's: tall, curving in at the tips), side (a lamb's:
    sticking straight out to the sides), wolf (short, wide based, upright),
    small_round (a dormouse's: small, round, low). col2 is the inside."""
    a = a or {}
    k = _k(H)
    head = _head(c)
    if head is None:
        return
    ears = _find(c, 'ears')
    if ears is None:
        ears = c.part('ears', 'static', head.pivot)
    ears.v = {}
    style = a.get('style', 'wolf')
    inner = col2 or _mix(col, hexc('#FFB3C7'), 0.5)
    top = max(p[2] for p in head.v)
    (hx0, hy0, hz0), (hx1, hy1, hz1) = _bounds(head.v)
    hy = (hy0 + hy1) / 2
    s = a.get('size', 1.0)

    def surf(x, y):
        zs = [p[2] for p in head.v if p[0] == x and p[1] == y]
        return max(zs) if zs else None

    if style in ('donkey', 'banana', 'wolf'):
        n = round({'donkey': 3.0, 'banana': 2.6, 'wolf': 1.4}[style] * k * s)
        xb = round({'donkey': 1.3, 'banana': 1.1, 'wolf': 1.15}[style] * k)
        yb = round(hy + (0.1 if style != 'wolf' else -0.1) * k)
        zb = surf(xb, yb) or (top - round(0.5 * k))
        w0 = {'donkey': 0.55, 'banana': 0.45, 'wolf': 0.85}[style] * k
        for i in range(n + 2):
            t = i / max(1, n)
            if style == 'donkey':
                xo = 0.45 * i  # angled out
            elif style == 'banana':
                xo = 0.25 * i - 0.9 * max(0.0, t - 0.6) * 2.0 * k * 0.5  # out, then curving in
            else:
                xo = 0.2 * i
            half = w0 * (1 - 0.75 * t) if style != 'banana' else w0 * (1 - 0.35 * t) if t < 0.85 else w0 * 0.5
            if i > n:
                break
            z = zb + i
            x0, x1 = round(xb + xo - half), round(xb + xo + half)
            for x in range(min(x0, x1), max(x0, x1) + 1):
                for dy in range(max(1, round(0.35 * k))):
                    _both(ears, x, yb + dy, z, col)
            if half >= 1.0 and 0 < i < n - 1:  # the inside, on the front face
                for x in range(x0 + 1, x1):
                    _both(ears, x, yb - 1, z, inner)
        # rooted into the head
        for x in range(round(xb - w0), round(xb + w0) + 1):
            for z in range(zb - max(1, round(0.4 * k)), zb + 1):
                for dy in range(max(1, round(0.35 * k))):
                    _both(ears, x, yb + dy, z, col)
    elif style == 'side':
        # lamb ears: out to the sides from the top corners, drooping a touch
        zb = round(top - 0.9 * k)
        yb = round(hy + 0.1 * k)
        xs = max(p[0] for p in head.v if p[2] == zb) if any(p[2] == zb for p in head.v) else round(1.8 * k)
        n = round(1.8 * k * s)
        for i in range(n):
            t = i / max(1, n - 1)
            x = xs + 1 + i
            z = zb - round(t * 0.5 * k)
            h = max(1, round(0.5 * k * (1 - 0.3 * t)))
            for dz in range(-h, h + 1):
                for dy in range(max(2, round(0.9 * k))):
                    cc = inner if (dy == 0 and abs(dz) < h and 0 < i < n - 1) else col
                    _both(ears, x, yb + dy - round(0.45 * k), z + dz, cc)
        for x in range(xs - 1, xs + 2):
            for dz in range(-1, 2):
                for dy in range(max(2, round(0.9 * k))):
                    _both(ears, x, yb + dy - round(0.45 * k), zb + dz, col)
    elif style == 'small_round':
        r = 0.6 * k * s
        xb = 1.25 * k
        yb = hy + 0.2 * k
        zb = (surf(round(xb), round(yb)) or top) + r * 0.6
        for x in range(math.floor(xb - r) - 1, math.ceil(xb + r) + 1):
            for z in range(math.floor(zb - r) - 1, math.ceil(zb + r) + 1):
                if (x + .5 - xb) ** 2 + (z + .5 - zb) ** 2 <= r * r:
                    for dy in range(max(1, round(0.3 * k))):
                        _both(ears, x, round(yb) + dy, z, col)
                    if (x + .5 - xb) ** 2 + (z + .5 - zb) ** 2 <= (r - 1) ** 2:
                        _both(ears, x, round(yb) - 1, z, inner)


def horns2(c, H, col, col2=None, a=None):
    """Horns: wide (a highland cow's: out to the sides, then up at the
    tips), curl (a ram's: a thick spiral round each ear), back (a goat's:
    up and swept back). col2 tips them."""
    a = a or {}
    k = _k(H)
    head = _head(c)
    if head is None:
        return
    _clear(c, 'horns')
    hp = c.part('horns2', 'static')
    style = a.get('style', 'back')
    top = max(p[2] for p in head.v)
    (hx0, hy0, hz0), (hx1, hy1, hz1) = _bounds(head.v)
    hy = (hy0 + hy1) / 2
    s = a.get('size', 1.0)
    tip = col2 or col

    def cf(t):
        return tip if t > 0.8 else col

    if style == 'wide':
        x0 = 1.0 * k
        z0 = top - 0.3 * k
        pts = [(x0, hy - 0.2 * k, z0), (x0 + 1.6 * k * s, hy - 0.3 * k, z0 + 0.1 * k), (x0 + 2.8 * k * s, hy - 0.5 * k, z0 + 0.8 * k),
               (x0 + 3.2 * k * s, hy - 0.6 * k, z0 + 1.8 * k * s)]
        _tube(hp, pts, 0.6 * k, 0.35 * k, col, cf, mirror=True)
    elif style == 'curl':
        # from the crown back, down round behind the eye and forward under it
        xb = hx1 - 0.2 * k  # out on the side of the head
        zb = top - 0.4 * k
        R = 1.2 * k * s
        cy, cz = hy + 0.6 * k, zb - R * 0.95
        pts = [(xb - 0.6 * k, hy, top - 0.1 * k)]
        for d in range(0, 331, 15):
            th = math.radians(d)
            rr = R * (1 - 0.4 * d / 330)
            pts.append((xb + 0.2 * k + 0.7 * k * d / 330, cy + rr * math.sin(th), cz + rr * math.cos(th)))
        _tube(hp, pts, 0.7 * k, 0.35 * k, col, lambda t: _mix(col, INK, 0.15) if int(t * 14) % 2 else col, mirror=True)
    else:  # back: up from the crown, then swept back
        x0 = 0.8 * k
        z0 = top - 0.3 * k
        pts = [(x0, hy - 0.4 * k, z0), (x0 + 0.15 * k, hy - 0.1 * k, z0 + 1.1 * k * s), (x0 + 0.3 * k, hy + 0.9 * k * s, z0 + 1.7 * k * s)]
        _tube(hp, pts, 0.55 * k, 0.45 * k, col, cf, mirror=True)


def mane2(c, H, col, col2=None, a=None):
    """A mane: a ridge (a donkey's short upright crest) or thick (a pony's
    long mane, falling to one side) from between the ears down the back of
    the head to the shoulders, and a forelock over the brow when
    `forelock`."""
    a = a or {}
    k = _k(H)
    head = _head(c)
    body = _find(c, 'body')
    if head is None or not body or not body.v:
        return
    style = a.get('style', 'ridge')
    mp = c.part('mane', 'static')
    (hx0, hy0, hz0), (hx1, hy1, hz1) = _bounds(head.v)
    hy = (hy0 + hy1) / 2
    both = {**body.v, **head.v}

    def topz(x, y):
        zs = [p[2] for p in both if p[0] == x and p[1] == y]
        return max(zs) if zs else None

    ys = sorted({p[1] for p in body.v})
    y_end = ys[0] + round((ys[-1] - ys[0]) * a.get('reach', 0.45))
    y_start = round(hy + a.get('start', 0.6) * k)
    w = 1 if style == 'ridge' else max(2, round(0.8 * k))
    h = max(1, round((0.45 if style == 'ridge' else 0.6) * k))
    prev = None
    for y in range(y_start, y_end + 1):
        zt = max((topz(x, y) or -99) for x in (-1, 0))
        if zt < 0:
            continue
        for x in range(-w, w):
            for dz in range(1, h + 1):
                mp.put((x, y, zt + dz), col)
        if prev is not None and prev > zt:  # step down face to face
            for z in range(zt + 1, prev + h + 1):
                for x in range(-w, w):
                    mp.put((x, y, z), col)
        prev = zt
    if style == 'thick':
        # it falls to the right side: a curtain down the neck
        for (x, y, z) in list(mp.v):
            if x == w - 1:
                for i in range(1, round(1.2 * k) + 1):
                    if (x + 1, y, z - i) not in both:
                        mp.put((x + 1, y, z - i), col)
    if a.get('forelock'):
        ey = _eyes(c)
        top = max(p[2] for p in head.v)
        bottom = round(ey[0] + 0.6 * k) if ey else top - round(1.2 * k)
        for x in range(-max(1, round(0.6 * k)), max(1, round(0.6 * k))):
            low = bottom - (1 if x % 2 == 0 else 0)
            for z in range(low, top + 1):
                f = head.front(x, z)
                if f:
                    mp.put((f[0], f[1] - 1, f[2]), col)
        for x in range(-max(1, round(0.6 * k)), max(1, round(0.6 * k))):
            mp.put((x, y_start - 1, top + 1), col)


def ruff(c, H, col, col2=None, a=None):
    """A lynx's facial ruff: pale pointed tufts sweeping out and down from
    the cheeks below the eyes."""
    k = _k(H)
    head = _head(c)
    if head is None:
        return
    ey = _eyes(c)
    ez = ey[0] if ey else 0
    rp = c.part('ruff', 'static')
    (hx0, hy0, hz0), (hx1, hy1, hz1) = _bounds(head.v)
    hy = (hy0 + hy1) / 2
    for i, dzs in enumerate((-0.9, -1.4)):
        z0 = ez + dzs * k
        row = [p for p in head.v if abs(p[2] - round(z0)) <= 0 and p[1] <= hy]
        if not row:
            continue
        xs = max(p[0] for p in row)
        y0 = round(hy - 0.6 * k + i * 0.3 * k)
        n = max(2, round(1.0 * k))
        for j in range(n):
            t = j / max(1, n - 1)
            h = max(0, round((1 - t) * 0.5 * k))
            for dz in range(-h, h + 1):
                for dy in range(max(1, round(0.6 * k))):
                    _both(rp, xs + 1 + j, y0 + dy, round(z0 - t * 0.5 * k) + dz, col)


def eyes_big(c, H, col, col2=None, a=None):
    """Bigger, darker eyes (a dormouse's or bushbaby's): each eye grows by
    `grow` voxels round its edge, in the face's surface where the eye sits
    (never onto a snout in front of it)."""
    a = a or {}
    head = _head(c)
    e = _find(c, 'eyes')
    if head is None or not e or not e.v:
        return
    for _ in range(a.get('grow', 1)):
        for (x, y, z), v in list(e.v.items()):
            out = 1 if x >= 0 else -1
            for dx, dz in ((out, 0), (0, 1)):  # outwards and up: never across the nose
                for dy in (0, 1, -1):
                    p = (x + dx, y + dy, z + dz)
                    if p in head.v and (p[0], p[1] - 1, p[2]) not in head.v:
                        del head.v[p]
                        e.put(p, INK)
                        break
    # a white shine in each eye's upper inner corner, so a big dark eye
    # reads as an eye and not as a pair of sunglasses
    for side in (-1, 1):
        ev = [p for p in e.v if (p[0] >= 0) == (side > 0)]
        if len(ev) >= 4:
            zt = max(p[2] for p in ev)
            top = [p for p in ev if p[2] == zt]
            p = min(top, key=lambda p: abs(p[0] + .5))
            e.put(p, WHITE)


# ------------------------------------------------------------------ bodies

def legs_long(c, H, col, col2=None, a=None):
    """Longer legs (a fawn's, a foal's): the whole creature stands `length`
    (in k) higher and each foot's column carries down to the ground in the
    foot's own colour. Only for plans whose legs are still in the body (the
    walking legs are split off after the accessories)."""
    a = a or {}
    k = _k(H)
    body = _find(c, 'body')
    if not body or not body.v:
        return
    d = max(1, round(a.get('length', 0.6) * k))
    feet = {(x, y): v for (x, y, z), v in body.v.items() if z == 0}
    for p in c.parts:
        q._shift(p, 0, 0, d)
    for (x, y), v in feet.items():
        for z in range(d):
            body.v[(x, y, z)] = v


def tail2(c, H, col, col2=None, a=None):
    """Tails in place of the plan's: hang (a pony's: long and thick, hanging
    down to the hocks), down (a wolf's: bushy, held down and back), out (a
    marten's: long and bushy straight out behind), stub (a lynx's: short,
    tipped in col2)."""
    a = a or {}
    k = _k(H)
    body = _find(c, 'body')
    if not body or not body.v:
        return
    style = a.get('style', 'down')
    old = _find(c, 'tail')
    anim = old.anim if old is not None else 'tail'
    if old is not None:
        c.parts.remove(old)
    (bx0, by0, bz0), (bx1, by1, bz1) = _bounds(body.v)
    mid = [p for p in body.v if p[0] in (-1, 0)]
    yb = max(p[1] for p in mid)
    zr = max(p[2] for p in mid if p[1] >= yb - 1) - round(0.5 * k)
    t = c.part('tail', anim if anim != 'static' else 'tail', (0, yb, zr))
    tip = col2 or col
    L = a.get('length', 1.0)
    if style == 'hang':
        pts = [(-0.5, yb, zr), (-0.5, yb + 0.9 * k, zr - 0.6 * k), (-0.5, yb + 1.2 * k, zr - 2.0 * k * L),
               (-0.5, yb + 1.1 * k, max(1.0 * k, zr - 3.2 * k * L))]
        _tube(t, pts, 0.55 * k, 0.75 * k, col, lambda s: tip if s > 0.85 else col)
    elif style == 'down':
        pts = [(-0.5, yb, zr), (-0.5, yb + 1.0 * k, zr - 0.5 * k), (-0.5, yb + 1.8 * k * L, zr - 1.4 * k * L)]
        _tube(t, pts, 0.55 * k, 0.9 * k, col, lambda s: tip if s > 0.85 else col)
    elif style == 'out':
        pts = [(-0.5, yb, zr), (-0.5, yb + 1.5 * k * L, zr + 0.1 * k), (-0.5, yb + 3.0 * k * L, zr - 0.1 * k)]
        _tube(t, pts, 0.55 * k, 0.85 * k, col, lambda s: tip if s > 0.9 else col)
    elif style == 'otter':
        # thick at the root, tapering to a point, held low behind
        pts = [(-0.5, yb - 0.3 * k, zr), (-0.5, yb + 1.4 * k * L, zr - 0.6 * k), (-0.5, yb + 3.0 * k * L, max(0.6 * k, zr - 1.3 * k))]
        _tube(t, pts, 1.0 * k, 0.35 * k, col)
    else:  # stub
        pts = [(-0.5, yb, zr), (-0.5, yb + 0.8 * k * L, zr + 0.2 * k)]
        _tube(t, pts, 0.55 * k, 0.55 * k, col, lambda s: tip if s > 0.55 else col)


def wool(c, H, col, col2=None, a=None):
    """A woolly fleece: round curls standing out all over the body's top and
    sides, a shade lighter, so the outline is bumpy. `share` (0-1, opt-in)
    sets how many curls take col2, picked per grid cell."""
    a = a or {}
    k = _k(H)
    body = _find(c, 'body')
    if not body or not body.v:
        return
    wp = c.part('wool', 'static')
    (bx0, by0, bz0), (bx1, by1, bz1) = _bounds(body.v)
    zmin = bz0 + (bz1 - bz0) * a.get('from', 0.35)
    cx, cy, cz = -0.5, (by0 + by1) / 2, (bz0 + bz1) / 2
    step = max(2, round(a.get('step', 0.9) * k))
    lite = col2 or _mix(col, WHITE, 0.12)
    vox = body.v
    for (x, y, z) in list(vox):
        if z < zmin or (x % step) or (y % step) or (z % step):
            continue
        nb = ((x + 1, y, z), (x - 1, y, z), (x, y + 1, z), (x, y - 1, z), (x, y, z + 1))
        if all(n in vox for n in nb):
            continue
        n = (x + .5 - cx, (y + .5 - cy) * 0.6, z + .5 - cz)
        L = math.sqrt(sum(v * v for v in n)) or 1
        r = 0.42 * k + 0.3
        if a.get('share') is not None:
            # curls on an even grid all hash alike: mix by grid cell, and
            # make `share` (0-1) of them the lighter shade
            light_curl = _hash(x // step, y // step, z // step, 5) % 100 < a['share'] * 100
        else:
            light_curl = _hash(x, y, z, 5) % 2
        _ball(wp, x + .5 + n[0] / L * 0.5 * k, y + .5 + n[1] / L * 0.5 * k, z + .5 + n[2] / L * 0.5 * k, r,
              lite if light_curl else col)
    for p in list(wp.v):
        if p in vox:
            del wp.v[p]
    if a.get('share') is not None:
        # the curls are drawn from an even grid, which is not symmetric about
        # the middle: mirror the right side so the model's box stays centred
        # (an off-centre box shifts every part, legs included, in the export)
        right = {q: v for q, v in wp.v.items() if q[0] >= 0}
        wp.v = dict(right)
        for (x, y, z), v in right.items():
            wp.v[(_mx(x), y, z)] = v


def quills(c, H, col, col2=None, a=None):
    """A porcupine's quills: long spikes radiating out from the back, sides
    and rump, pale with dark tips (col2), denser on the back."""
    a = a or {}
    k = _k(H)
    body = _find(c, 'body')
    if not body or not body.v:
        return
    qp = c.part('quills', 'static')
    (bx0, by0, bz0), (bx1, by1, bz1) = _bounds(body.v)
    cx, cy, cz = -0.5, (by0 + by1) / 2 + 0.3 * k, bz0 + (bz1 - bz0) * 0.25
    zmin = bz0 + (bz1 - bz0) * a.get('from', 0.45)
    ymin = by0 + (by1 - by0) * 0.18  # none on the neck and face
    step = max(2, round(a.get('step', 0.7) * k))
    tip = col2 or INK
    vox = body.v
    for (x, y, z) in list(vox):
        if z < zmin or y < ymin:
            continue
        rows = a.get('rows', False)
        if rows:  # an even grid of quills in rows across the back
            if (y % step) or ((x + (y // step) % 2) % 2):
                continue
        elif (x + 2 * y + 3 * z) % step or _hash(x, y, z, 11) % 3 == 0:
            continue
        nb = ((x + 1, y, z), (x - 1, y, z), (x, y + 1, z), (x, y - 1, z), (x, y, z + 1))
        if all(n in vox for n in nb):
            continue
        n = (x + .5 - cx, (y + .5 - cy) * 0.8 + 0.4 * k, z + .5 - cz)
        if rows:  # swept back and up, like a hedgehog's, only longer
            L0 = math.sqrt(sum(v * v for v in n)) or 1
            n = (n[0] / L0 * 0.55, n[1] / L0 * 0.4 + 0.75, n[2] / L0 * 0.8 + 0.25)
        L = math.sqrt(sum(v * v for v in n)) or 1
        if n[2] / L < 0.15:
            continue  # never down under the belly
        ln = a.get('length', 1.5) * k * (0.8 + 0.4 * (_hash(x, y, z, 12) % 5) / 4)
        end = (x + .5 + n[0] / L * ln, y + .5 + n[1] / L * ln, z + .5 + n[2] / L * ln)
        n_ = max(2, int(ln * 2))
        for i in range(n_ + 1):
            s = i / n_
            st = (x + .5, y + .5, z + .5)
            p = tuple(math.floor(st[j] + (end[j] - st[j]) * s) for j in range(3))
            if p in vox:
                continue
            qp.put(p, tip if s > a.get('tip_from', 0.84) else col)
    # face-connect each quill (a line can step diagonally)
    for p in list(qp.v):
        x, y, z = p
        if not any(n in qp.v or n in vox for n in ((x + 1, y, z), (x - 1, y, z), (x, y + 1, z), (x, y - 1, z), (x, y, z + 1), (x, y, z - 1))):
            qp.put((x, y, z - 1), qp.v[p][0])


def _fine_only(fn):
    """These features are for the mesh build (Blender, c.fine). The small
    in-game stand-in (VoxelArt, shown until the meshes load) keeps the
    plan's look, inside its part budget."""
    def wrapped(c, H, col, col2=None, a=None):
        if getattr(c, 'fine', False):
            fn(c, H, col, col2, a)
    wrapped.__name__, wrapped.__doc__ = fn.__name__, fn.__doc__
    return wrapped


ACCESSORIES = {
    'tidy2': q.tidy, 'bird_beak': bird_beak, 'bird_tail': bird_tail, 'comb': comb, 'plume': plume, 'casque': casque,
    'polka': polka, 'head_paint': head_paint, 'chest': chest, 'muzzle': muzzle, 'ears2': ears2,
    'horns2': horns2, 'mane2': mane2, 'ruff': ruff, 'eyes_big': eyes_big, 'tail2': tail2, 'wool': wool,
    'quills': quills, 'legs_long': legs_long,
}
ACCESSORIES = {name: _fine_only(fn) for name, fn in ACCESSORIES.items()}


def llama_neck(c, H, col, col2=None, a=None):
    """A llama's neck: upright and as thick as the head, about one head
    taller than the back (kit_quirks.long_neck is a giraffe's: thinner and
    twice as tall, which read as a lollipop on a llama). The small in-game
    build keeps long_neck. `lift` and `r` (in k) tune it."""
    a = a or {}
    if not getattr(c, 'fine', False):
        return q.long_neck(c, H, col, col2)
    k = _k(H)
    body = q._find(c, 'body')
    head = q._find(c, 'head')
    if not body or not head or not head.v:
        return
    hz0 = min(p[2] for p in head.v)
    lift = round(a.get('lift', 4.0) * k)
    fwd = -round(0.4 * k)
    hy = sum(p[1] for p in head.v) / len(head.v)
    for p in c.parts:
        if p.name in q.HEAD_PARTS:
            q._shift(p, 0, fwd, lift)
    r = a.get('r', 1.35) * k
    top = hz0 + lift + round(1.0 * k)
    base = hz0 - round(1.6 * k)
    steps = max(4, top - base)
    for i in range(steps + 1):
        t = i / steps
        z = base + (top - base) * t
        y = hy + 0.8 * k + (fwd - 0.2 * k) * t
        head.ell((0, y, z), (r, r * 1.05, 0.8), col)
    head.anim = 'head'
    head.pivot = (0, hy + 0.8 * k, base + 0.5 * k)


def round_top(c, H, col=None, col2=None, a=None):
    """Shaves the small pole nub (a 2x2 or smaller cap of voxels) off the
    top of the head, which reads as a hat button or a bun on a smooth-headed
    bird."""
    if not getattr(c, 'fine', False):
        return
    head = q._find(c, 'head')
    if not head or not head.v:
        return
    for _ in range(2):
        zt = max(p[2] for p in head.v)
        top = [p for p in head.v if p[2] == zt]
        below = sum(1 for p in head.v if p[2] == zt - 1)
        if len(top) <= 4 and below >= 3 * len(top):
            for p in top:
                del head.v[p]
        else:
            break


def goatee(c, H, col, col2=None, a=None):
    """A goat's beard hanging from under the chin, just behind the muzzle
    tip, joined to the head (kit's 'beard' hangs from the bottom of the head
    plan and floated once a long muzzle was added). The small in-game build
    keeps kit's beard."""
    import kit
    if not getattr(c, 'fine', False):
        return kit.accessory(c, H, 'beard', '#%02X%02X%02X' % tuple(col[:3]))
    k = _k(H)
    head = _head(c)
    if head is None:
        return
    ymin = min(p[1] for p in head.v)
    front = [p for p in head.v if p[1] <= ymin + max(3, round(1.4 * k)) and p[0] in (-1, 0)]
    if not front:
        return
    zb = min(p[2] for p in front)
    yb = max(p[1] for p in front if p[2] == zb)
    bd = c.part('beard', 'static')
    n = max(3, round(1.4 * k))
    for i in range(n):
        for x in (-1, 0):
            bd.put((x, yb + (1 if i > n // 2 else 0), zb - 1 - i), col)


ACCESSORIES['llama_neck'] = llama_neck
ACCESSORIES['goatee'] = goatee
ACCESSORIES['round_top'] = round_top


# ------------------------------------------------------------ hoofed heads
# The strict review (18:21Z) failed the goats, the horses and the black lamb
# for one reason: the plan's head is a big round dog or cat head, and a
# muzzle on the front of it still reads as a dog. hoof_head rebuilds the
# head itself: a small narrow skull, a long face that runs forward and down
# in one straight line from the brow to the nose (the hoofed profile), eyes
# set out on the corners of the skull, and a pale muzzle end.

def hoof_head(c, H, col, col2=None, a=None):
    """A hoofed animal's head in place of the plan's round one: goat (a
    narrow wedge, straight profile), horse (long and deep, a squared nose),
    sheep (short and narrow). col is the head, col2 the muzzle end; options
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
          'badger': (1.55, 1.4, 1.1)}[style]
    rx, ry, rz = sk[0] * k * W, sk[1] * k, sk[2] * k
    cy = (hy0 + hy1) / 2 + 0.35 * k
    cz = hz1 + 1 - rz - 0.15 * k - a.get('lower', 0) * k
    # the face: from the brow, forward and down to the nose
    fl, fdrop, fr0, fr1, fz0, fz1 = {
        'goat': (2.0, 1.15, 1.0, 0.72, 0.95, 0.72),
        'horse': (3.0, 1.5, 1.05, 0.95, 1.15, 0.95),
        'sheep': (1.9, 1.0, 0.95, 0.75, 0.95, 0.75),
        'badger': (1.9, 0.45, 1.15, 0.5, 0.85, 0.5)}[style]
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


def horn_buds(c, H, col, col2=None, a=None):
    """A kid's horn buds: two short stubby horns from the top of the skull,
    up and tipping back, wide apart, darker at the tips."""
    a = a or {}
    k = _k(H)
    head = _head(c)
    if head is None:
        return
    _clear(c, 'horns')
    hp = c.part('horns2', 'static')
    s = a.get('size', 1.0)
    (hx0, hy0, hz0), (hx1, hy1, hz1) = _bounds(head.v)
    xb = round(0.55 * k)
    # the back half of the skull's top
    ys = sorted({p[1] for p in head.v if p[0] == xb})
    yb = ys[len(ys) * 2 // 3] if ys else round((hy0 + hy1) / 2)
    zb = (head.top(xb, yb) or (xb, yb, hz1))[2]
    tip = col2 or _mix(col, INK, 0.3)
    n = max(2, round(1.2 * k * s))
    for i in range(n + 1):
        cc = tip if i >= n - 0 else col
        for x in (xb, xb + 1) if i < n else (xb,):
            _both(hp, x, yb + (i * 2) // 3, zb + i, cc)
            if i < n - 1:
                _both(hp, x, yb + (i * 2) // 3 - 1, zb + i, cc)


def ears_droop(c, H, col, col2=None, a=None):
    """Long ears out to the sides and hanging down (a Boer kid's): from the
    skull's sides behind the eyes, out and then down past the jaw, the inside
    showing in col2."""
    a = a or {}
    k = _k(H)
    head = _head(c)
    if head is None:
        return
    ears = _find(c, 'ears')
    if ears is None:
        ears = c.part('ears', 'static', head.pivot)
    ears.v = {}
    inner = col2 or _mix(col, hexc('#FFB3C7'), 0.5)
    s = a.get('size', 1.0)
    (hx0, hy0, hz0), (hx1, hy1, hz1) = _bounds(head.v)
    # the skull's widest point
    xs = hx1
    row = [p for p in head.v if p[0] == xs]
    yb = round(sum(p[1] for p in row) / len(row)) + 1
    zb = round(sum(p[2] for p in row) / len(row)) + 1
    n = max(3, round(1.9 * k * s))
    w = max(2, round(0.75 * k))
    for i in range(n):
        t = i / max(1, n - 1)
        x = xs + 1 + round(min(i, n * 0.45))  # out, then hanging
        z = zb - round(t * t * 1.6 * k * s)
        for dy in range(w):
            _both(ears, x, yb - dy, z, col)
            if i >= 1 and t < 0.95:
                _both(ears, x, yb - dy, z - 1, col)
        # the inside, a pink line on the hanging part's front edge
        if i >= 2 and t < 0.9:
            _both(ears, x, yb - w + 1, z - 1, inner)
    # rooted into the skull
    for x in range(xs - 1, xs + 2):
        for dy in range(w):
            for z in (zb, zb - 1):
                _both(ears, x, yb - dy, z, col)


def tail_up(c, H, col, col2=None, a=None):
    """A goat's short tail flicked straight up off the rump."""
    a = a or {}
    k = _k(H)
    body = _find(c, 'body')
    if not body or not body.v:
        return
    old = _find(c, 'tail')
    anim = old.anim if old is not None else 'tail'
    if old is not None:
        c.parts.remove(old)
    mid = [p for p in body.v if p[0] in (-1, 0)]
    yb = max(p[1] for p in mid)
    zr = max(p[2] for p in mid if p[1] >= yb - 1)
    t = c.part('tail', anim if anim != 'static' else 'tail', (0, yb, zr - 1))
    L = a.get('length', 1.0)
    n = max(2, round(1.0 * k * L))
    tip = col2 or col
    for i in range(n + 1):
        for x in (-1, 0):
            t.put((x, yb + (1 if i < n else 0), zr - 1 + i), tip if i >= n - 0 else col)
            if i < n - 1:
                t.put((x, yb, zr - 1 + i), col)


def hooves(c, H, col, col2=None, a=None):
    """Dark hooves: the bottom `height` voxels of every leg column."""
    a = a or {}
    body = _find(c, 'body')
    if not body:
        return
    h = a.get('height', 1)
    for p, (cc, g) in list(body.v.items()):
        if p[2] < h:
            body.v[p] = (col, False)


ACCESSORIES['hooves'] = _fine_only(hooves)
ACCESSORIES['hoof_head'] = _fine_only(hoof_head)
ACCESSORIES['horn_buds'] = _fine_only(horn_buds)
ACCESSORIES['ears_droop'] = _fine_only(ears_droop)
ACCESSORIES['tail_up'] = _fine_only(tail_up)


def mole_parts(c, H, col, col2=None, a=None):
    """A mole's signature: a star nose (a ring of small pink nubs round the
    snout's tip), big pale-pink digging paws turned outward on the front
    feet, and a short pink tail. col is the pink."""
    a = a or {}
    k = _k(H)
    head = _head(c)
    body = _find(c, 'body')
    if head is None or not body:
        return
    # the star: nubs out from the snout's front face, round its edge
    front = min(p[1] for p in head.v)
    tip = [p for p in head.v if p[1] == front]
    (tx0, _, tz0), (tx1, _, tz1) = _bounds(tip)
    cx, cz = (tx0 + tx1 + 1) / 2, (tz0 + tz1 + 1) / 2
    r = max(1.6, (tx1 - tx0 + 1) / 2 + 0.8)
    for d in range(0, 360, 30):
        th = math.radians(d)
        x, z = math.floor(cx + r * math.cos(th)), math.floor(cz + r * math.sin(th))
        f = head.front(x, z)
        y = (f[1] if f else front + 1) - 1
        head.put((x, y, z), col)
        if not f:  # tie it back to the snout
            head.put((x, y + 1, z), col)
    # the nose itself: a small pink pad in the middle of the star
    for x in (-1, 0):
        for z in (math.floor(cz) - 1, math.floor(cz)):
            f = head.front(x, z)
            if f:
                head.put(f, col)
    _clear(c, 'ears')  # moles show no ears
    # digging paws: the front feet, widened outward into flat pink spades
    ys = sorted({p[1] for p in body.v if p[2] == 0})
    yf = ys[0]
    feet = [p for p in body.v if p[2] == 0 and p[1] <= yf + 2]
    xr = max(p[0] for p in feet)
    w = max(2, round(1.2 * k))
    for x in range(xr - 1, xr + w):
        for y in range(yf - 1, yf + 2):
            for z in (0, 1):
                if z == 1 and (x > xr + w - 2 or y == yf - 1):
                    continue
                _both(body, x, y, z, col)
    # claws: dark tips at the front of each paw
    for x in range(xr, xr + w, 2):
        _both(body, x, yf - 2, 0, _mix(col, INK, 0.5))
    # a short pink tail
    tl = _find(c, 'tail')
    if tl is not None:
        for p in list(tl.v):
            tl.v[p] = (col, False)


ACCESSORIES['mole_parts'] = _fine_only(mole_parts)


def badger_face(c, H, col, col2=None, a=None):
    """A badger's face on a hoof_head wedge: the head white (col2), with two
    dark bands (col) running from the nose back over each eye to the ears,
    a white stripe down the middle between them; the nose tip dark."""
    a = a or {}
    k = _k(H)
    head = _head(c)
    if head is None:
        return
    wh = col2 or hexc('#F2F2F2')
    x0, x1 = a.get('x0', 0.45) * k, a.get('x1', 1.35) * k
    zlo = min(p[2] for p in head.v)
    for p, (cc, g) in list(head.v.items()):
        if cc == INK:
            continue
        d = abs(p[0] + 0.5)
        head.v[p] = ((col if x0 <= d <= x1 and p[2] > zlo + 0.5 * k else wh), False)
    front = min(p[1] for p in head.v)
    for p in [p for p in head.v if p[1] == front]:
        head.v[p] = (INK, False)
    e = _find(c, 'eyes')
    if e is not None:  # a glint, so the eye shows inside the dark band
        for p in list(e.v):
            top = (p[0], p[1], p[2] + 1)
            if top in e.v:
                e.v[top] = (WHITE, False)


ACCESSORIES['badger_face'] = _fine_only(badger_face)


def quill_coat(c, H, col, col2=None, a=None):
    """A porcupine's coat: a dense checkerboard of long quills over the back,
    sides and rump (like the Hedgehog's spikes, only long), each a staircase
    swept up and back, splaying out on the flanks, banded col at the root
    and pale (col2) at the tip. The face and belly stay bare."""
    a = a or {}
    k = _k(H)
    body = _find(c, 'body')
    if not body or not body.v:
        return
    qp = c.part('quills', 'static')
    (bx0, by0, bz0), (bx1, by1, bz1) = _bounds(body.v)
    zmin = bz0 + (bz1 - bz0) * a.get('from', 0.45)
    ymin = by0 + (by1 - by0) * a.get('front', 0.2)
    n = max(4, round(a.get('length', 2.5) * k))
    tip = col2 or WHITE
    top = {}
    for (x, y, z) in body.v:
        if z > top.get((x, y), -99):
            top[(x, y)] = z
    xmid = (bx0 + bx1 + 1) / 2
    for (x, y), z in top.items():
        sp = a.get('spacing', 2)
        if z < zmin or y < ymin or x % 2 or (y + (x // 2) % 2 * (sp // 2)) % sp:
            continue
        side = (x + .5 - xmid) / max(1, (bx1 - bx0 + 1) / 2)  # -1 left .. 1 right
        sx = 1 if side > 0.45 else -1 if side < -0.45 else 0
        px, py, pz = x, y, z
        for i in range(n):
            if i % 2 == 0:
                pz += 1
            elif sx and i % 4 == 1:
                px += sx
            else:
                py += 1
            if (px, py, pz) not in body.v:
                qp.put((px, py, pz), tip if i >= n * a.get('tip_from', 0.6) else col)


ACCESSORIES['quill_coat'] = _fine_only(quill_coat)

def mayfly(c, H, col, col2=None, a=None):
    """Rebuilds the critter-plan dragonfly into a mayfly: two tall upright
    wings held together over the back (each on its own side of the middle,
    so they open out when they flap), pale with a few vein lines (col2);
    slim pale legs (a.legs); and two long tail threads (a.threads) curving
    up and apart from the tip of the abdomen, drawn on the right and
    mirrored so both match."""
    a = a or {}
    k = _k(H)
    body = _find(c, 'body')
    if body is None or not body.v:
        return
    wing = col
    vein = col2 or _mix(col, INK, 0.18)
    (bx0, by0, bz0), (bx1, by1, bz1) = _bounds(body.v)
    ztop = max(q[2] for q in body.v if q[1] <= by0 + 3)
    yb0 = by0 - 1  # the wing's root runs along the thorax
    root = max(3, round(a.get("root", 1.8) * k))
    tall = max(5, round(a.get('height', 2.6) * k))
    for side, name in ((1, 'wingR'), (-1, 'wingL')):
        w = _find(c, name)
        if w is None:
            continue
        w.v = {}
        x = 0 if side > 0 else -1
        for i in range(tall):
            # the leading edge stands straight up; the trailing edge slopes back
            t = i / max(1, tall - 1)
            y_lo = yb0 + round(0.3 * k * t)
            y_hi = yb0 + root + round(1.6 * k * t * (1 - t) * 2)
            if i == tall - 1:
                y_hi = y_lo + 1
            for y in range(y_lo, y_hi + 1):
                edge = y in (y_lo, y_hi) or (y - y_lo) % 3 == 2
                w.put((x, y, ztop + 1 + i), vein if edge else wing)
        w.pivot = (0.5 * side, yb0 + root / 2, ztop + 1)
    # slim pale legs
    lc = hexc(a['legs']) if a.get('legs') else None
    if lc:
        for p in c.parts:
            if p.name.startswith('leg'):
                for q in list(p.v):
                    p.v[q] = (lc, False)
    # tail threads, mirrored
    th = _find(c, 'threads')
    if th is not None:
        th.v = {}
        tc = hexc(a['threads']) if a.get('threads') else _mix(col, INK, 0.3)
        tip = max((q for q in body.v if q[0] >= 0), key=lambda q: (q[1], q[2]))
        # straight, unbranched filaments one voxel thick: one voxel per step
        # back, drifting out and curving gently up, about 1.5x the body long
        L = max(8, round(a.get('thread_len', 1.5) * (by1 - by0 + 1)))
        spread, rise = a.get('spread', 0.9) * k, a.get('rise', 1.6) * k
        for i in range(1, L + 1):
            t = i / L
            th.put((tip[0] + round(0.6 + spread * t), tip[1] + i, tip[2] + round(rise * t * t)), tc)
        for (x, y, z), v in list(th.v.items()):
            th.v[(_mx(x), y, z)] = v


ACCESSORIES['mayfly'] = _fine_only(mayfly)

def eye_shine(c, H, col=None, col2=None, a=None):
    """A white shine on each eye: the face voxel just above the eye's outer
    edge turns white (or col), so a dark eye on a dark face still reads."""
    head, eyes = _head(c), _find(c, 'eyes')
    if head is None or eyes is None or not eyes.v:
        return
    shine = col or WHITE
    for side in (1, -1):
        ev = [p for p in eyes.v if (p[0] >= 0) == (side > 0)]
        if not ev:
            continue
        x = max(ev, key=lambda p: abs(p[0] + .5))[0]
        z = max(p[2] for p in ev) + 1
        f = head.front(x, z)
        if f:
            head.put(f, shine)


ACCESSORIES['eye_shine'] = _fine_only(eye_shine)

# Every kind carries the kit's own prefix, so no other kit's accessory name can clash with it.
ACCESSORIES = {'lg_' + name: fn for name, fn in ACCESSORIES.items()}
