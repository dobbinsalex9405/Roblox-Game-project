"""Uncommon slice B reworks (the Common B builder's thread): accessories
that rebuild a whole look the shared plans can't draw, for the creatures the
strict review sent back. Every name starts with ub_ so it never clashes
with another kit.

Accessories (fn(c, H, color, color2, a); `a` is the roster's accessory
dict, its extra keys are the settings named below):

- **ub_spindly**: a spider crab's legs: every leg redrawn 1 voxel thin and
  long, out and up to a high knee, then down to a foot far out to the side
  (`reach`, `knee` in k); color2 the knees. The in-game build gets an L
  (out, then down) so it stays in its box budget.
- **ub_bands**: an orchid bee's metallic abdomen: bands across it in color
  and color2, a bright sheen line down the middle of the back
  (`sheen`), and a long dark tongue (`tongue`) tucked under the head and
  back along the belly.
- **ub_ghost**: a ghost: the hind legs taken away, the back of the body
  tapering into a wispy tail that curls down to touch the ground (so the
  rest hovers), the front paws short and dangling; color2 the wisp's tip.
- **ub_cauldron**: a witch's pot taller than it is wide with a rim lip, two
  handle ears and green bubbles (color2) at the rim; the creature sits in
  it, lifted so its head and shoulders show above the rim.
- **ub_leafbody**: a leaf insect's body: one wide flat leaf oval with a
  centre vein and side veins in color2, a leafy lobe on each leg, and the
  old leaf, wings and body taken away.

Same art frame as kit.py (x right, y back, front is -y, z up), k = H / 10.
Left and right halves are drawn once and mirrored (x -> -x - 1)."""
import math

from voxkit import hexc

INK, WHITE = hexc('#1B1B2F'), hexc('#FFFFFF')


def _rgb(col, default=None):
    if col is None:
        return default
    return hexc(col) if isinstance(col, str) else tuple(col)


def _find(c, name):
    return next((p for p in c.parts if p.name == name), None)


def _mx(x):
    return -x - 1


def _fine(c):
    return getattr(c, 'fine', False)


def _dark(col, t=0.3):
    return tuple(max(0, round(v * (1 - t))) for v in col)


def _light(col, t=0.3):
    return tuple(min(255, round(v + (255 - v) * t)) for v in col)


def _bb(vs):
    vs = list(vs)
    return [min(v[i] for v in vs) for i in range(3)], [max(v[i] for v in vs) for i in range(3)]


def _rod(cells, a, b, col):
    """Voxels from a to b (voxel units), each step face to face with the last."""
    n = max(2, int(math.ceil(max(abs(b[j] - a[j]) for j in range(3)))) * 2)
    last = None
    for s in range(n + 1):
        t = s / n
        v = tuple(math.floor(a[j] + (b[j] - a[j]) * t) for j in range(3))
        if last is not None:
            cur = list(last)
            for j in range(3):
                if cur[j] != v[j]:
                    cur[j] = v[j]
                    cells[tuple(cur)] = col
        cells[v] = col
        last = v


def _mirror_legs(c):
    """Every leg ...L set to the exact mirror of its ...R."""
    for p in c.parts:
        if p.name.startswith('leg') and p.name.endswith('R'):
            q = _find(c, p.name[:-1] + 'L')
            if q is None:
                continue
            q.v = {(_mx(x), y, z): v for (x, y, z), v in p.v.items()}
            q.pivot = (-p.pivot[0], p.pivot[1], p.pivot[2])


# ------------------------------------------------------------ spider crab

def ub_spindly(c, H, color, color2=None, a=None):
    """Long thin spider crab legs (see the module doc)."""
    k = H / 10.0
    a = a or {}
    col = _rgb(color)
    knee_col = _rgb(color2, col)
    body = _find(c, 'body')
    legs = sorted([p for p in c.parts if p.name.startswith('leg') and p.name.endswith('R')], key=lambda p: p.name)
    if body is None or not legs:
        return
    lo, hi = _bb(body.v)
    n = len(legs)
    zh = round((lo[2] + hi[2]) / 2)
    reach, knee = float(a.get('reach', 2.6)) * k, float(a.get('knee', 1.1)) * k
    for i, p in enumerate(legs):
        t = (i + 0.5) / n
        yh = round(lo[1] + 1 + (hi[1] - lo[1] - 2) * t)
        xs = [q[0] for q in body.v if q[1] == yh and q[2] == zh]
        xh = (max(xs) + 1) if xs else hi[0] + 1
        dy = (t - 0.5) * 2.0 * k  # the front legs reach forward, the back ones back
        cells = {}
        if _fine(c):
            kx, kz = xh + 0.45 * reach, zh + knee
            _rod(cells, (xh + .5, yh + .5, zh + .5), (kx + .5, yh + .5 + dy * 0.4, kz + .5), col)
            _rod(cells, (kx + .5, yh + .5 + dy * 0.4, kz + .5), (xh + reach + .5, yh + .5 + dy, .5), col)
            kv = max(cells, key=lambda v: v[2])
            cells[kv] = knee_col
        else:
            fx = xh + max(2, round(0.5 * reach))
            for x in range(xh, fx + 1):
                cells[(x, yh, zh)] = col
            for z in range(0, zh):
                cells[(fx, yh, z)] = col
        p.v = {}
        for v, cc in cells.items():
            if v not in body.v:
                p.put(v, cc)
        p.pivot = (xh, yh + 0.5, zh + 0.5)
    _mirror_legs(c)


# ------------------------------------------------------------ orchid bee

def ub_bands(c, H, color, color2=None, a=None):
    """An orchid bee's metallic banded abdomen and long tongue."""
    k = H / 10.0
    a = a or {}
    col = _rgb(color)
    col2 = _rgb(color2, _dark(col, 0.3))
    sheen = _rgb(a.get('sheen'), _light(col, 0.55))
    tongue = _rgb(a.get('tongue'), hexc('#2B2B35'))
    body = _find(c, 'body')
    head = _find(c, 'head')
    if body is None or not body.v:
        return
    lo, hi = _bb(body.v)
    ym = (lo[1] + hi[1]) / 2
    w = max(1, round(0.4 * k))
    mid = _light(col, 0.2)
    shades = [col, col2, mid]
    for q, (cc, g) in list(body.v.items()):
        if q[1] >= ym - 0.5 * k and cc not in (INK, WHITE):
            body.v[q] = (shades[int((q[1] - lo[1]) // w) % 3], False)
    # the sheen: the top voxel of each column down the middle of the back
    tops = {}
    for (x, y, z) in body.v:
        if x in (-1, 0):
            tops[(x, y)] = max(tops.get((x, y), z), z)
    for (x, y), z in tops.items():
        if y >= ym - 0.5 * k and body.v[(x, y, z)][0] not in (INK, WHITE):
            body.v[(x, y, z)] = (sheen, False)
    if head is None or not head.v:
        return
    # the tongue: from under the front of the head, back under the chin
    hlo, hhi = _bb(head.v)
    yf = hlo[1] + max(1, round(0.4 * k))
    zs = [q[2] for q in head.v if q[0] in (-1, 0) and q[1] == yf]
    if not zs:
        return
    z0 = min(zs) - 1
    tp = c.part('tongue', 'static', head.pivot)
    n = max(3, round(float(a.get('len', 2.0)) * k))
    taken = set().union(*[set(p.v) for p in c.parts if p is not tp])
    for i in range(n):
        v = (0, yf + i, z0 - (1 if i >= n // 2 else 0))
        if v in taken or (-1, v[1], v[2]) in taken:
            v = (0, v[1], v[2] - 1)
        tp.put(v, tongue)
        tp.put((-1, v[1], v[2]), tongue)


# ------------------------------------------------------------ ghost

def ub_ghost(c, H, color, color2=None, a=None):
    """A ghost's hovering body with a wispy tail (see the module doc)."""
    k = H / 10.0
    a = a or {}
    col = _rgb(color)
    tip = _rgb(color2, _light(col, 0.5))
    body = _find(c, 'body')
    if body is None or not body.v:
        return
    for name in ('legBL', 'legBR'):
        p = _find(c, name)
        if p is not None:
            c.parts.remove(p)
    old_tail = _find(c, 'tail')
    if old_tail is not None:
        c.parts.remove(old_tail)
    # float: everything goes up off the ground (the wisp reaches back down)
    up = max(2, round(float(a.get('float', 0.9)) * k))
    for p in c.parts:
        p.v = {(x, y, z + up): v for (x, y, z), v in p.v.items()}
        p.pivot = (p.pivot[0], p.pivot[1], p.pivot[2] + up)
    lo, hi = _bb(body.v)
    ym = (lo[1] + hi[1]) / 2
    # the back half tapers: cut it away under a line rising toward the rump
    lift = max(2, round(float(a.get('lift', 0.3)) * (hi[2] - lo[2])))
    for q in list(body.v):
        t = max(0.0, (q[1] - ym) / max(1, hi[1] - ym))
        if q[2] < lo[2] + lift + t * 0.5 * (hi[2] - lo[2]):
            del body.v[q]
    # and narrows toward the back
    for q in list(body.v):
        t = max(0.0, (q[1] - ym) / max(1, hi[1] - ym))
        if abs(q[0] + .5) > (hi[0] + 1) * (1 - 0.45 * t):
            del body.v[q]
    # the wisp: from the rump, back and down in an S to touch the ground
    blo, bhi = _bb(body.v)
    back = [q for q in body.v if q[1] == bhi[1]]
    zr = round(sum(q[2] for q in back) / len(back)) if back else round((blo[2] + bhi[2]) / 2)
    y0 = bhi[1]
    pts = [(0, y0, zr), (0, y0 + 0.9 * k, zr - 0.6 * k), (0, y0 + 1.5 * k, max(1.0, zr - 2.0 * k)),
           (0, y0 + 1.2 * k, 0.0), (0, y0 + 2.0 * k, 0.0)]
    tail = c.part('tail', 'swing', (0, y0, zr))
    cells = {}
    for i in range(len(pts) - 1):
        r = max(0.0, (1.0 - i / (len(pts) - 1)) * 0.9 * k - 0.5)
        _tube(cells, pts[i], pts[i + 1], r, col)
    n = len(cells)
    far = sorted(cells, key=lambda v: (v[1] - y0) ** 2 + (v[2] - zr) ** 2)
    for v in far[-max(1, n // 5):]:
        cells[v] = tip
    for (x, y, z), cc in cells.items():
        if x >= 0 and (x, y, z) not in body.v:
            tail.put((x, y, z), cc)
            tail.put((_mx(x), y, z), cc)
    # the front paws: short stubs dangling under the chest, off the ground
    for name in ('legFR', 'legFL'):
        p = _find(c, name)
        if p is not None:
            c.parts.remove(p)
    front = [q for q in body.v if q[1] <= blo[1] + max(3, round(1.2 * k))]
    if front:
        zc = min(q[2] for q in front)
        yc = round(sum(q[1] for q in front if q[2] == zc) / len([q for q in front if q[2] == zc]))
        w = max(1, round(0.9 * k))
        x0 = max(1, round(0.5 * k))
        paw = c.part('legFR', 'swing', (x0 + w / 2, yc + w / 2, zc))
        for x in range(x0, x0 + w):
            for y in range(yc, yc + w):
                for z in range(max(1, zc - max(3, round(1.0 * k))), zc):
                    paw.put((x, y, z), col)
        c.part('legFL', 'swing', (0, 0, 0))
    _mirror_legs(c)


def _tube(cells, a, b, r, col):
    """A round rod of radius r (voxels) from a to b."""
    n = max(2, int(math.ceil(math.dist(a, b) * 2)))
    for s in range(n + 1):
        t = s / n
        p = [a[j] + (b[j] - a[j]) * t for j in range(3)]
        R = max(0.5, r)
        for x in range(math.floor(p[0] - R), math.ceil(p[0] + R) + 1):
            for y in range(math.floor(p[1] - R), math.ceil(p[1] + R) + 1):
                for z in range(math.floor(p[2] - R), math.ceil(p[2] + R) + 1):
                    if (x + .5 - p[0]) ** 2 + (y + .5 - p[1]) ** 2 + (z + .5 - p[2]) ** 2 <= R * R + 0.25:
                        cells[(x, y, max(0, z))] = col


# ------------------------------------------------------------ cauldron

def ub_cauldron(c, H, color, color2=None, a=None):
    """A pot taller than it is wide, the creature sitting in it."""
    k = H / 10.0
    a = a or {}
    col = _rgb(color)
    goo = _rgb(color2, hexc('#7CFF6B'))
    rim_col = _light(col, 0.25)
    for name in ('cup', 'bubbles'):
        p = _find(c, name)
        if p is not None:
            c.parts.remove(p)
    others = [p for p in c.parts if p.v]
    lo, hi = _bb(v for p in others for v in p.v)
    width = max(hi[0] - lo[0] + 1, hi[1] - lo[1] + 1)
    R = max(3.0, float(a.get('r', 0.38)) * width + 0.5)
    Hp = max(round(2 * R) + 1, round(float(a.get('h', 1.12)) * 2 * R))
    cy = (lo[1] + hi[1]) / 2 + 0.5
    # lift the creature so it sits in the pot, its head and shoulders out
    sink = round(float(a.get('sink', 0.55)) * (hi[2] - lo[2]))
    up = Hp - sink - lo[2]
    for p in others:
        p.v = {(x, y, z + up): v for (x, y, z), v in p.v.items()}
        p.pivot = (p.pivot[0], p.pivot[1], p.pivot[2] + up)
    pot = c.part('cup', 'static')
    # nothing of the creature pokes through the pot's wall below the rim
    for p in others:
        p.v = {v: cc for v, cc in p.v.items()
               if v[2] >= Hp - 1 or math.hypot(v[0] + .5, v[1] + .5 - cy) <= R * 0.78 - 1.6}
    if True:
        # the pot is solid: what it hides of the creature goes
        for p in others:
            p.v = {v: cc for v, cc in p.v.items()
                   if v[2] >= Hp or max(abs(v[0] + .5), abs(v[1] + .5 - cy)) > R + 0.5}
    inside = set(v for p in others for v in p.v)
    for z in range(0, Hp):
        # a round belly: narrower foot and neck, straight sides between
        # (few ledges, so few triangles)
        rr = R * (0.72 if z < 1 else 0.88 if z < 2 else 0.86 if z >= Hp - 3 else 1.0)
        rr = round(rr)  # whole-voxel steps keep the bulge's ledges (and triangles) few
        for x in range(0, math.ceil(rr) + 1):
            for y in range(math.floor(cy - rr) - 1, math.ceil(cy + rr) + 1):
                d = math.hypot(x + .5, y + .5 - cy)
                if not _fine(c):
                    # in game: square slabs, a few boxes for the whole pot
                    rr = R * (0.7 if z < 1 else 0.85 if z >= Hp - 2 else 1.0)
                    rq = round(rr * 0.9)
                    d = max(x + .5, abs(y + .5 - cy)) if x < rq and abs(y + .5 - cy) < rq else rr + 1
                    if d <= rr and (x, y, z) not in inside:
                        pot.put((x, y, z), col)
                        pot.put((_mx(x), y, z), col)
                    continue
                if d <= rr and (x, y, z) not in inside:
                    pot.put((x, y, z), col)
                    pot.put((_mx(x), y, z), col)
    zt = Hp - 1
    if not _fine(c):
        brew = c.part('bubbles', 'static')
        for x in (0, 1):
            brew.put((round(R * 0.4) + x, round(cy - .5), zt + 1), goo)
            brew.put((_mx(round(R * 0.4) + x), round(cy - .5), zt + 1), goo)
        return
    # the rim lip: a ring sticking out one voxel at the top, a shade lighter
    rl = R * 0.78 + 1.0
    for x in range(0, math.ceil(rl) + 1):
        for y in range(math.floor(cy - rl) - 1, math.ceil(cy + rl) + 1):
            d = math.hypot(x + .5, y + .5 - cy)
            if rl - 1.8 < d <= rl and (x, y, zt) not in inside:
                pot.put((x, y, zt), rim_col)
                pot.put((_mx(x), y, zt), rim_col)
    # the handle ears: a small ring on each side under the rim
    hz = zt - max(2, round(0.5 * k))
    xo = math.ceil(R * 0.95)
    ear = [(xo, 0, 0), (xo + 1, 0, 0), (xo + 1, 0, 1), (xo + 1, 0, 2), (xo, 0, 2), (xo + 1, 0, -1)]
    for (x, dy, dz) in ear:
        v = (x, round(cy - .5), hz + dz)
        if v not in pot.v:
            pot.put(v, rim_col)
            pot.put((_mx(v[0]), v[1], v[2]), rim_col)
    # green brew: a disc just under the rim around the creature, and bubbles
    # popping up at the rim
    brew = c.part('bubbles', 'static')
    for x in range(0, math.ceil(R * 0.78)):
        for y in range(math.floor(cy - R), math.ceil(cy + R) + 1):
            v = (x, y, zt - 1)
            if math.hypot(x + .5, y + .5 - cy) <= R * 0.78 - 1.0 and v not in inside and v not in pot.v:
                brew.put(v, goo)
                brew.put((_mx(x), y, zt - 1), goo)
    spots = [(0.55, -0.5), (0.35, 0.6), (0.62, 0.25)]
    for (fx, fy) in spots:
        x = round(fx * R * 0.7)
        y = round(cy + fy * R * 0.7)
        for v in ((x, y, zt), (x, y, zt + 1)):
            if v not in inside and v not in pot.v:
                brew.put(v, _light(goo, 0.35) if v[2] > zt else goo)
                brew.put((_mx(x), y, v[2]), _light(goo, 0.35) if v[2] > zt else goo)


# ------------------------------------------------------------ leaf insect

def ub_leafbody(c, H, color, color2=None, a=None):
    """A leaf insect's flat leaf body (see the module doc)."""
    k = H / 10.0
    a = a or {}
    col = _rgb(color)
    vein = _rgb(color2, _dark(col, 0.3))
    for name in ('leaf', 'wingL', 'wingR', 'wings'):
        p = _find(c, name)
        if p is not None:
            c.parts.remove(p)
    body = _find(c, 'body')
    head = _find(c, 'head')
    if body is None:
        return
    legs = [p for p in c.parts if p.name.startswith('leg')]
    hlo, hhi = _bb(head.v) if head is not None and head.v else ([0, -3, 4], [0, -2, 6])
    zb = round(min(min(q[2] for q in p.v) for p in legs if p.v) + 0) if legs else 3
    zb = max(zb, round(0.9 * k))
    # the leaf: a wide flat oval behind the head, 2 voxels thick
    ry, rx = float(a.get('len', 2.6)) * k, float(a.get('w', 1.35)) * k
    y0 = hhi[1] + 1
    yc = y0 + ry - 0.5
    zl = max(zb, round(sum(p.pivot[2] for p in legs) / len(legs)) if legs else zb)
    body.v = {}
    # the head comes down to sit low at the leaf's front end (no neck)
    if head is not None and head.v:
        dz = zl - hlo[2]
        for p in c.parts:
            if p is head or tuple(p.pivot) == tuple(head.pivot) and p is not body:
                p.v = {(x, y, z + dz): v for (x, y, z), v in p.v.items()}
        for p in [q for q in c.parts if tuple(q.pivot) == tuple(head.pivot)]:
            p.pivot = (p.pivot[0], p.pivot[1], p.pivot[2] + dz)
        hlo, hhi = _bb(head.v)
    for x in range(0, math.ceil(rx) + 1):
        for y in range(math.floor(yc - ry), math.ceil(yc + ry) + 1):
            # a leaf: pointed at the back, rounder at the front
            t = (y + .5 - yc) / ry
            w = rx * math.sqrt(max(0.0, 1 - t * t)) * (1 - 0.25 * max(0.0, t))
            if x + .5 <= w and y >= y0:
                for z in (zl, zl + 1):
                    body.put((x, y, z), col)
                    body.put((_mx(x), y, z), col)
    # a stem joining it to the head, and the veins on top
    for y in range(hhi[1] - 1, y0 + 1):
        for z in (zl, zl + 1):
            if (0, y, z) not in (head.v if head is not None else {}):
                body.put((0, y, z), col)
                body.put((-1, y, z), col)
    top = zl + 1
    for (x, y, z) in list(body.v):
        if z != top:
            continue
        if x in (-1, 0):
            body.v[(x, y, z)] = (vein, False)
        else:
            ax = x if x >= 0 else _mx(x)
            # side veins running out and back from the midrib every few rows
            step = max(2, round(0.9 * k))
            if (y - y0 - ax) % step == 0 and ax >= 1:
                body.v[(x, y, z)] = (vein, False)
    # a leafy lobe on each leg: a small flat flap on its upper half
    for p in legs:
        if p.name.endswith('L') or not p.v:
            continue
        plo, phi = _bb(p.v)
        zmid = (plo[2] + phi[2]) / 2
        for (x, y, z) in list(p.v):
            if z >= zmid and z < phi[2]:
                for dy in (-1, 1):
                    v = (x, y + dy, z)
                    if v not in p.v and v not in body.v:
                        p.put(v, col)
    _mirror_legs(c)


PLANS = {}
BUILDERS = {}
ACCESSORIES = {
    'ub_spindly': ub_spindly, 'ub_bands': ub_bands, 'ub_ghost': ub_ghost, 'ub_cauldron': ub_cauldron,
    'ub_leafbody': ub_leafbody,
}
