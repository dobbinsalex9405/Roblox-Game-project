"""Elemental, cosmic and mythic dressing for Ultra Rare and Epic creatures,
plus the griffin body plan. Every accessory here works on any body plan: it
finds the creature's back, head, ears, tail and feet from the voxels the plan
built, so a roster entry turns a plain quadruped, bird, blob, bug or crab into
an Ember pup, a Glacial owl or a clockwork penguin with one line:

    "accessories": [{"kind": "flames", "color": "#FF7A1A", "color2": "#FFE14D"}]

Accessories that glow put their glowing voxels in parts with the "glow" anim
(they pulse in the game and are emissive in the meshes); `"glow": true` on any
accessory or pattern (variants.py) makes all of what it adds glow.

Same art frame and scale as kit.py: x right, y back (front is -y), z up,
k = H / 10. Cells are [x, x + 1), so a shape centred on x = 0 is symmetric:
the left twin of cell x is cell -x - 1."""
import math

from voxkit import hexc
from kit import _find, _hash, ball, head_of, crown

INK, WHITE = hexc('#1B1B2F'), hexc('#FFFFFF')
CREAM = hexc('#F6EBD2')
GOLD = hexc('#FFC93C')


# ------------------------------------------------------------------ helpers

def _mix(a, b, t):
    return tuple(max(0, min(255, round(a[i] + (b[i] - a[i]) * t))) for i in range(3))


def _dark(col, t=0.3):
    return _mix(col, INK, t)


def _light(col, t=0.35):
    return _mix(col, WHITE, t)


def _mx(x):
    return -x - 1


def _put2(part, x, y, z, col, glow=False):
    """A voxel and its mirror twin (x >= 0 is the right side)."""
    part.put((x, y, z), col, glow)
    part.put((_mx(x), y, z), col, glow)


def _back_parts(c):
    return [p for p in (_find(c, 'body'), _find(c, 'shell')) if p and p.v]


def _top_at(parts, x, y):
    zs = [q[2] for p in parts for q in p.v if q[0] == x and q[1] == y]
    return max(zs) if zs else None


def _yrange(part):
    ys = [p[1] for p in part.v]
    return min(ys), max(ys)


def _spine(c, n, start=0.2, end=0.8):
    """n points (y, z_top) along the middle of the back, front to rear."""
    parts = _back_parts(c)
    if not parts:
        return []
    ys = [q[1] for p in parts for q in p.v]
    y0, y1 = min(ys), max(ys)
    out = []
    for i in range(n):
        t = start + (end - start) * (i / max(1, n - 1) if n > 1 else 0.5)
        y = round(y0 + (y1 - y0) * t)
        z = max(filter(None, (_top_at(parts, 0, y), _top_at(parts, -1, y))), default=None)
        if z is not None:
            out.append((y, z))
    return out


def _tail_tip(c):
    tl = _find(c, 'tail')
    if not tl or not tl.v:
        return None
    ymax = max(p[1] for p in tl.v)
    tip = [p for p in tl.v if p[1] >= ymax - 1]
    return (sum(p[0] for p in tip) / len(tip) + 0.5, ymax, max(p[2] for p in tip))


def _ear_tips(c):
    """(x, y, z) of the top of each ear (right side; mirror for left)."""
    ears = _find(c, 'ears')
    if not ears or not ears.v:
        return None
    right = [p for p in ears.v if p[0] >= 0]
    if not right:
        return None
    zt = max(p[2] for p in right)
    top = [p for p in right if p[2] >= zt - 1]
    return (sum(p[0] for p in top) / len(top) + 0.5, sum(p[1] for p in top) / len(top) + 0.5, zt)


def _surface(part, others=()):
    """Voxels of the part with at least one open face."""
    occ = set(part.v)
    for o in others:
        occ |= set(o.v)
    out = []
    for (x, y, z) in part.v:
        for n in ((x + 1, y, z), (x - 1, y, z), (x, y + 1, z), (x, y - 1, z), (x, y, z + 1), (x, y, z - 1)):
            if n not in occ:
                out.append((x, y, z))
                break
    return out


def _norm(v):
    m = math.sqrt(sum(a * a for a in v)) or 1.0
    return tuple(a / m for a in v)


def tongue(part, base, h, r, col, col2, lean=0.35, glow=True, side=0.0):
    """A flame tongue: round at the base, tapering to a point, leaning back
    (and out by `side`) as it rises; colour runs from col to col2 at the tip."""
    h = max(2, round(h))
    for i in range(h):
        t = i / h
        w = max(0.0, r * (1 - t) ** 0.85)
        cx, cy = base[0] + side * i, base[1] + lean * i
        colr = _mix(col, col2, min(1, t * 1.3))
        part.ell((cx, cy, base[2] + i + .5), (w + .35, w + .35, 0.5), colr, glow)
        part.put((math.floor(cx), math.floor(cy), math.floor(base[2] + i)), colr, glow)


def shard(part, base, d, length, w, col, tip, tip_glow=True, body_glow=False):
    """A crystal shard from `base` along direction d, tapering to a point;
    its last third in the tip colour."""
    d = _norm(d)
    n = max(2, round(length * 2))
    for i in range(n + 1):
        s = length * i / n
        r = max(0.0, w * (1 - (s / length) ** 2.2))
        p = tuple(base[j] + d[j] * s for j in range(3))
        at_tip = s > length * 0.62
        col_s = tip if at_tip else col
        g = tip_glow if at_tip else body_glow
        if r > 0.6:
            part.ell(p, (r, r, r), col_s, g)
        part.put(tuple(math.floor(v) for v in p), col_s, g)


def line(part, a, b, col, r=0.0, glow=False):
    n = max(1, int(math.ceil(max(abs(b[i] - a[i]) for i in range(3)) * 2)))
    for i in range(n + 1):
        t = i / n
        p = tuple(a[j] + (b[j] - a[j]) * t for j in range(3))
        if r > 0.6:
            part.ell(p, (r, r, r), col, glow)
        part.put(tuple(math.floor(v) for v in p), col, glow)


def leaf(part, base, d, length, width, col, rib=None):
    """A flat pointed leaf from base along d (its flat side faces up-ish)."""
    d = _norm(d)
    side = _norm((d[1], -d[0], 0.0)) if abs(d[2]) < 0.95 else (1.0, 0.0, 0.0)
    n = max(2, round(length * 2))
    for i in range(n + 1):
        s = length * i / n
        hw = width * math.sin(math.pi * min(1, s / length) ** 0.8)
        c = tuple(base[j] + d[j] * s for j in range(3))
        m = max(1, round(hw * 2))
        for j in range(-m, m + 1):
            o = hw * j / m
            p = tuple(c[q] + side[q] * o for q in range(3))
            part.put(tuple(math.floor(v) for v in p), rib if (rib and j == 0) else col)


def puffs(part, centre, size, col, n=5, seed=0, flat=0.8):
    """A cloud: a few overlapping balls around centre."""
    cx, cy, cz = centre
    ball(part, centre, (size, size, size * flat), col)
    for i in range(n):
        h = _hash(seed, i, 31)
        a = (h % 360) * math.pi / 180
        rr = size * (0.55 + (h >> 9) % 30 / 100)
        dx, dy = math.cos(a) * size * 0.9, math.sin(a) * size * 0.7
        ball(part, (cx + dx, cy + dy, cz + ((h >> 15) % 5 - 2) * size * 0.12), (rr, rr, rr * flat), col)


def gear(part, centre, axis, R, teeth, col, hub=None, depth=1):
    """A cog in the plane across `axis` ('x', 'y' or 'z'), radius R."""
    cx, cy, cz = centre
    Ri = int(math.ceil(R + 1.5))
    for a in range(-Ri, Ri + 1):
        for b in range(-Ri, Ri + 1):
            d = math.hypot(a + .5, b + .5)
            ang = math.atan2(b + .5, a + .5)
            rim = R + (0.32 * R if math.cos(ang * teeth) > 0.2 else 0)
            if d > rim or d < 0.3 * R:
                continue
            colr = hub if (hub and d < 0.55 * R) else col
            for t in range(depth):
                if axis == 'x':
                    p = (cx + t, cy + a, cz + b)
                elif axis == 'y':
                    p = (cx + a, cy + t, cz + b)
                else:
                    p = (cx + a, cy + b, cz + t)
                part.put(tuple(math.floor(v) for v in p), colr)


def _side_x(part, y, z):
    xs = [p[0] for p in part.v if p[1] == y and p[2] == z]
    return max(xs) if xs else None


def _crown(c):
    y, zt = crown(c)
    return y, zt


# ------------------------------------------------------------- fire and lava

def flames(c, H, col, col2=None):
    """Flame tongues along the back and a flame at the tail tip."""
    k = H / 10.0
    col2 = col2 or hexc('#FFE14D')
    fl = c.part('flames', 'glow')
    for i, (y, z) in enumerate(_spine(c, 3, 0.25, 0.7)):
        h = (2.4 + 0.6 * (i == 1)) * k
        tongue(fl, (0, y, z - 0.3 * k), h, 1.1 * k, col, col2)
    tip = _tail_tip(c)
    if tip:
        tongue(c.part('tail'), (0, tip[1] - 0.3 * k, tip[2] - 0.2 * k), 2.0 * k, 0.9 * k, col, col2)


def back_flame(c, H, col, col2=None):
    """One flame on the middle of the back (a fire ant's, a salamander's)."""
    k = H / 10.0
    col2 = col2 or hexc('#FFE14D')
    sp = _spine(c, 1, 0.45, 0.45)
    if sp:
        y, z = sp[0]
        tongue(c.part('flames', 'glow'), (0, y, z - 0.2 * k), 2.8 * k, 1.1 * k, col, col2)


def ear_flames(c, H, col, col2=None):
    """Each ear burns at the tip."""
    k = H / 10.0
    col2 = col2 or hexc('#FFE14D')
    t = _ear_tips(c)
    if not t:
        return
    ears = c.part('ears')
    for sx in (-1, 1):
        x = t[0] if sx > 0 else -t[0]
        tongue(ears, (x, t[1], t[2] - 0.6 * k), 2.2 * k, 0.75 * k, col, col2, lean=0.15, side=0.1 * sx)


def tail_flame(c, H, col, col2=None):
    k = H / 10.0
    tip = _tail_tip(c)
    if tip:
        tongue(c.part('tail'), (0, tip[1] - 0.3 * k, tip[2] - 0.2 * k), 2.4 * k, 1.0 * k, col, col2 or hexc('#FFE14D'))


def cracks(c, H, col, col2=None, a=None):
    """Branching cracks over the body and head (lava seams, stone cracks).
    Add "glow": true for lava; "parts" limits them (e.g. ["body"] keeps the
    face clear)."""
    k = H / 10.0
    for name in (a or {}).get('parts', ('body', 'head', 'shell')):
        part = _find(c, name)
        if not part or not part.v:
            continue
        surf = _surface(part)
        if not surf:
            continue
        sset = set(surf)
        salt = 5 + sum(col) % 97  # two crack layers in different colours take different paths
        starts = sorted(surf, key=lambda p: _hash(*p, salt))[:max(3, len(surf) // max(16, round(48 * k * k / 9)))]
        steps = max(6, round(4.0 * k))
        for s in starts:
            p = s
            h = _hash(*s, 9 + salt)
            for i in range(steps):
                if p[0] >= 0:
                    for q in (p, (p[0], p[1], p[2] + 1), (p[0], p[1] + 1, p[2])):
                        if q in sset:
                            part.put(q, col)
                            part.put((_mx(q[0]), q[1], q[2]), col)
                h = (h * 1103515245 + 12345) & 0x7FFFFFFF
                opts = [q for q in ((p[0], p[1] + 1, p[2]), (p[0], p[1] - 1, p[2]), (p[0], p[1], p[2] + 1),
                                    (p[0], p[1], p[2] - 1), (p[0] + 1, p[1], p[2]), (p[0] - 1, p[1], p[2])) if q in sset]
                if not opts:
                    break
                p = opts[h % len(opts)]


def claws(c, H, col, col2=None):
    """The front of the body's sides (a crab's claws) glow."""
    k = H / 10.0
    body = _find(c, 'body')
    if not body:
        return
    y0 = min(p[1] for p in body.v)
    body.paint(lambda p, cc, g: (col, True) if p[1] <= y0 + 1.4 * k and abs(p[0] + .5) >= 2.2 * k else None)


# ------------------------------------------------------------- ice and gems

def ice(c, H, col, col2=None):
    """Ice shards along the back, leaning out to each side, glowing tips."""
    k = H / 10.0
    col2 = col2 or _light(col, 0.6)
    part = c.part('crystals', 'glow')
    for i, (y, z) in enumerate(_spine(c, 4, 0.15, 0.8)):
        sx = 1 if i % 2 else -1
        L = (2.6 + 0.7 * ((i + 1) % 2)) * k
        x = 0.5 * k * sx
        shard(part, (x, y, z - 0.6 * k), (0.5 * sx, 0.25, 1), L, 0.8 * k, col, col2)
        if i % 2 == 0:
            shard(part, (-x, y + 0.7 * k, z - 0.6 * k), (-0.55 * sx, 0.3, 1), L * 0.7, 0.65 * k, col, col2)


def ice_crown(c, H, col, col2=None):
    """A ring of ice spikes on the crown."""
    k = H / 10.0
    col2 = col2 or _light(col, 0.6)
    y, zt = _crown(c)
    part = c.part('crown', 'glow')
    for i in range(5):
        a = math.pi * (0.15 + 0.7 * i / 4)
        x = math.cos(a) * 1.0 * k
        L = (2.6 if i == 2 else 1.8) * k
        shard(part, (x, y - math.sin(a) * 0.6 * k, zt - 0.5 * k), (x * 0.25, -0.1, 1), L, 0.55 * k, col, col2)


def ice_crest(c, H, col, col2=None):
    """Three ice shards fanning back from the top of the head."""
    k = H / 10.0
    col2 = col2 or _light(col, 0.6)
    y, zt = _crown(c)
    part = c.part('crest', 'glow')
    for i, (dy, L) in enumerate(((-0.2, 2.4), (0.6, 3.2), (1.4, 2.2))):
        shard(part, (0, y + dy * k, zt - 0.6 * k), (0, 0.5 + 0.3 * i, 1), L * k, 0.65 * k, col, col2)


def gems(c, H, col, col2=None):
    """A cluster of gem crystals on the middle of the back. Only in the fine
    (mesh) build: at in-game box size the cluster alone would take a third
    of an Epic's box budget."""
    if not getattr(c, 'fine', False):
        return
    k = H / 10.0
    col2 = col2 or _light(col, 0.5)
    sp = _spine(c, 1, 0.5, 0.5)
    if not sp:
        return
    y, z = sp[0]
    part = c.part('crystals', 'glow')
    shard(part, (0, y, z - 0.7 * k), (0, 0.1, 1), 3.4 * k, 1.0 * k, col, col2)
    for sx in (-1, 1):
        shard(part, (sx * 0.9 * k, y - 0.9 * k, z - 0.7 * k), (sx * 0.6, -0.3, 1), 2.3 * k, 0.75 * k, col2, col)
        shard(part, (sx * 0.8 * k, y + 1.1 * k, z - 0.7 * k), (sx * 0.5, 0.5, 1), 2.0 * k, 0.7 * k, col, col2)


def gem_studs(c, H, col, col2=None):
    """Gems set into the back and flanks, alternating two colours."""
    k = H / 10.0
    col2 = col2 or _light(col, 0.4)
    body = _find(c, 'body')
    if not body:
        return
    surf = [p for p in _surface(body) if p[2] > 1.6 * k and p[0] >= 0]
    step = max(3, round(1.5 * k))
    for p in surf:
        if p[1] % step == 0 and p[2] % step == 0 and (_hash(*p, 3) % 3 == 0):
            colr = col if (p[1] // step + p[2] // step) % 2 else col2
            r = max(1, round(0.3 * k))
            for dy in range(-r + 1, r):
                for dz in range(-r + 1, r):
                    if abs(dy) + abs(dz) < r:
                        for x in (p[0], p[0] + 1):
                            q = (x, p[1] + dy, p[2] + dz)
                            body.put(q, colr, True)
                            body.put((_mx(q[0]), q[1], q[2]), colr, True)


def facets(c, H, col, col2=None, a=None):
    """Carved crystal: flat facets in two tones over the body and head (a
    rose-quartz fox, a ruby hound), with a few glinting points. Only in the
    fine (mesh) build: at in-game box size the facets would shatter the
    creature into hundreds of boxes."""
    if not getattr(c, 'fine', False):
        return
    k = H / 10.0
    a = a or {}
    col2 = col2 or _dark(col, 0.25)
    s = max(2, round(1.2 * k))
    for name in a.get('parts', ('body', 'head', 'tail', 'ears', 'shell')):
        part = _find(c, name)
        if not part:
            continue

        def face(p, cc, g, s=s):
            if g or cc in (INK, WHITE):
                return None
            cell = (abs(p[0] + .5) // s, (p[1] + p[2]) // s, (p[2] - p[1]) // s)
            h = _hash(*cell, 17) % 3
            return ((col, False), (col2, False), (_light(col, 0.3), False))[h]
        part.paint(face)
        for p in _surface(part) if a.get('glints', True) else ():
            if _hash(*p, 41) % 97 == 0:
                part.put(p, WHITE, True)
                part.put((_mx(p[0]), p[1], p[2]), WHITE, True)


def mandibles(c, H, col, col2=None):
    """An ant's mandibles: two small dark pincers under the front of the
    head, curving in toward each other (col, default near-black)."""
    k = H / 10.0
    head = head_of(c)
    if not head or not head.v:
        return
    zs = [p[2] for p in head.v]
    z0, z1 = min(zs), max(zs)
    zm = math.floor(z0 + (z1 - z0) * 0.22)
    front = [p for p in head.v if p[2] in (zm, zm + 1) and p[0] >= 0]
    if not front:
        return
    yf = min(p[1] for p in front)
    x0 = max(2, round(0.8 * k))
    L = max(2, round(0.9 * k))
    dark = _hexa(col, INK) if col else INK
    for i in range(1, L + 1):
        _put2(head, x0, yf - i, zm, dark)
    # the tips hook inward, leaving a gap between them
    _put2(head, x0 - 1, yf - L, zm, dark)


def eye_shine(c, H, col=None, col2=None):
    """Grows one-voxel eyes to 2x2 (outward and down) with a white shine
    on the upper-left corner of both, for a light face where the automatic
    contrast pass leaves tiny dots."""
    eyes = _find(c, 'eyes')
    if not eyes or not eyes.v:
        return
    ink = [q for q, (rgb, g) in eyes.v.items() if not g and sum(rgb) < 240]
    right = [q for q in ink if q[0] >= 0]
    if len(right) != 1 or len([q for q in ink if q[0] < 0]) != 1:
        return
    x, y, z = right[0]
    rgb = eyes.v[right[0]][0]
    others = [p for p in c.parts if p is not eyes]
    for sx in (1, -1):
        ex = x if sx > 0 else _mx(x)
        cells = [(ex, z), (ex + sx, z), (ex, z - 1), (ex + sx, z - 1)]
        shine = min(cells, key=lambda q: (-q[1], q[0]))  # upper left
        for cx, cz in cells:
            q = (cx, y, cz)
            for p in others:
                p.v.pop(q, None)
            eyes.v[q] = (WHITE if (cx, cz) == shine else rgb, False)


def wing_snowflakes(c, H, col, col2=None):
    """A six-point snowflake (col) on the outer face of each raised wing:
    three crossing 1-voxel bars with a small V on each arm, drawn on the
    outermost voxel of every row so the lines stay crisp on a slanted wing;
    mirrored on the two wings. col2 repaints the wing first as an even
    ground for the flake."""
    w = _find(c, 'wingR')
    if not w or not w.v:
        return
    wl = _find(c, 'wingL')
    if col2:
        for part in (w, wl):
            for q, (cc, g) in list((part.v if part else {}).items()):
                part.v[q] = (col2, g)
    outer = {}
    for (x, y, z) in w.v:
        if x > outer.get((y, z), -1e9):
            outer[(y, z)] = x
    ys = [y for y, _ in outer]
    zs = [z for _, z in outer]
    yc = round((min(ys) + max(ys)) / 2 - 0.15 * (max(ys) - min(ys)))
    zc = round((min(zs) + max(zs)) / 2 + 0.1 * (max(zs) - min(zs)))
    L = max(3, round(0.4 * min(max(ys) - min(ys), max(zs) - min(zs))))
    cells = {(yc, zc)}
    for i in range(6):
        a = math.pi / 2 + i * math.pi / 3
        uy, uz = math.cos(a), math.sin(a)
        for t in range(1, L + 1):
            cells.add((yc + round(uy * t), zc + round(uz * t)))
        # a small V two thirds of the way out
        by, bz = yc + uy * L * 0.62, zc + uz * L * 0.62
        for sgn in (-1, 1):
            b = a + sgn * math.pi / 3
            for t in (1, 2):
                cells.add((round(by + math.cos(b) * t), round(bz + math.sin(b) * t)))
    for (y, z) in cells:
        x = outer.get((y, z))
        if x is None:
            continue
        w.v[(x, y, z)] = (col, False)
        m = (_mx(x), y, z)
        if wl and m in wl.v:
            wl.v[m] = (col, False)


def pink_nose(c, H, col, col2=None):
    """The dark nose (and mouth) on the head turn col (a lamb's pink nose),
    so a pale face carries only its eyes and a soft nose."""
    head = head_of(c)
    if not head:
        return
    for q, (cc, g) in list(head.v.items()):
        if not g and sum(cc) < 200:
            head.v[q] = (col, False)


def toasted(c, H, col, col2=None):
    """A toasted marshmallow's fleece: golden-brown spots (col) scattered
    over the top of the back and rump, each ringed in a light toast (col2),
    like a marshmallow browned over a fire; the face and sides stay white."""
    k = H / 10.0
    col2 = col2 or _mix(col, WHITE, 0.55)
    body = _find(c, 'body')
    if not body or not body.v:
        return
    zs = [p[2] for p in body.v]
    zcut = min(zs) + (max(zs) - min(zs)) * 0.5
    top = {}
    for (x, y, z) in body.v:
        if z > top.get((x, y), -1e9):
            top[(x, y)] = z
    s = max(3, round(1.1 * k))
    for (x, y), z in top.items():
        if z < zcut or x < 0:
            continue
        cell = (x // s, y // s)
        if _hash(*cell, 61) % 2:
            continue
        h = _hash(*cell, 67)
        cx, cy = cell[0] * s + 1 + h % max(1, s - 2), cell[1] * s + 1 + (h >> 4) % max(1, s - 2)
        d = math.hypot(x + .5 - cx, y + .5 - cy)
        if d < 0.9:
            cc = col
        elif d < 1.6:
            cc = col2
        else:
            continue
        for q in ((x, y, z), (_mx(x), y, z)):
            if q in body.v:
                body.v[q] = (cc, False)


def jelly(c, H, col, col2=None):
    """Gummy candy lit from inside: every part shades from a deep candy
    colour (col, darkened) at its base to a glowing lighter core tint (col2)
    on top, with a glossy white highlight on the crown of the head and the
    top of the body. The mesh is opaque, so the glow carries the see-through
    look."""
    k = H / 10.0
    col2 = col2 or _light(col, 0.4)
    deep = _dark(col, 0.25)
    for part in c.parts:
        if part.name in ('eyes',) or not part.v:
            continue
        zs = [p[2] for p in part.v]
        z0, z1 = min(zs), max(zs)
        for q, (cc, g) in list(part.v.items()):
            if sum(cc) < 200:  # keep nose and mouth
                continue
            t = (q[2] - z0) / max(1, z1 - z0)
            part.v[q] = (_mix(deep, col, t * 1.8) if t < 0.5 else _mix(col, col2, (t - 0.5) * 2), t >= 0.4)
    for name in ('body',):
        part = _find(c, name)
        if not part or not part.v:
            continue
        mid = [p for p in part.v if 0 <= p[0] <= 1]
        if not mid:
            continue
        zt = max(p[2] for p in mid)
        hs = [p for p in mid if p[2] == zt]
        ym = sum(p[1] for p in hs) / len(hs)
        for p in _surface(part):
            if zt - 2 <= p[2] <= zt and 1 <= p[0] <= max(1, round(0.5 * k)) and ym - 0.8 * k <= p[1] <= ym:
                part.v[p] = (WHITE, True)
                part.v[(_mx(p[0]), p[1], p[2])] = (WHITE, True)


def ear_rims(c, H, col, col2=None):
    """A pale rim round the edge of each ear (a raccoon's)."""
    ears = _find(c, 'ears')
    if not ears or not ears.v:
        return
    right = [p for p in ears.v if p[0] >= 0]
    if not right:
        return
    cx = sum(p[0] for p in right) / len(right)
    cz = sum(p[2] for p in right) / len(right)
    rmax = max(math.hypot(p[0] - cx, p[2] - cz) for p in right)
    for p in right:
        if math.hypot(p[0] - cx, p[2] - cz) >= rmax - 1.0 and p[2] >= cz - 0.5:
            ears.v[p] = (col, False)
            m = (_mx(p[0]), p[1], p[2])
            if m in ears.v:
                ears.v[m] = (col, False)


def otter_tail(c, H, col, col2=None):
    """An otter's tail: thick where it leaves the rump, tapering to a point,
    held low and straight out behind. Replaces the plan's tail."""
    k = H / 10.0
    body = _find(c, 'body')
    tl = _find(c, 'tail')
    if not body or not tl:
        return
    y1 = max(p[1] for p in body.v)
    zs = [p[2] for p in body.v if p[1] >= y1 - 1]
    z = (min(zs) + max(zs)) / 2
    tl.v = {}
    tl.pivot = (0, y1 - 0.5, z)
    L = 2.8 * k
    n = max(4, round(L * 2))
    for i in range(n + 1):
        t = i / n
        r = 0.65 * k * (1 - t) + 0.2 * k * t
        p = (0, y1 - 0.8 * k + L * t, z - 0.5 * k * t)
        tl.ell(p, (r + .2, r + .2, r * 0.8 + .2), col)


def tiny_ears(c, H, col=None, col2=None):
    """Cuts the plan's ears down to small round nubs at their base (an
    otter's, a seal's)."""
    k = H / 10.0
    ears = _find(c, 'ears')
    if not ears or not ears.v:
        return
    z0 = min(p[2] for p in ears.v)
    ears.v = {q: v for q, v in ears.v.items() if q[2] <= z0 + max(1, round(0.5 * k))}
    if col:
        ears.v = {q: (_hexa(col, v[0]), v[1]) for q, v in ears.v.items()}


def amber_gaster(c, H, col, col2=None):
    """An amber ant's rear: glowing honey-amber resin (col) with a lighter
    core (col2) and a glossy white highlight on the upper front."""
    k = H / 10.0
    body = _find(c, 'body')
    if not body or not body.v:
        return
    ys = [p[1] for p in body.v]
    y0, y1 = min(ys), max(ys)
    cut = y0 + (y1 - y0) * 0.55
    rear = [p for p in body.v if p[1] >= cut]
    if not rear:
        return
    cy = sum(p[1] for p in rear) / len(rear)
    rr = max(p[1] for p in rear) - cy + 0.5
    core = col2 or _light(col, 0.4)
    deep = _dark(col, 0.3)
    zb, zt = min(p[2] for p in rear), max(p[2] for p in rear)
    # resin lit from inside: deep amber below, glowing honey above
    for p in rear:
        t = (p[2] - zb) / max(1, zt - zb)
        body.put(p, _mix(deep, col, t * 1.6) if t < 0.6 else _mix(col, core, (t - 0.6) / 0.4), t >= 0.45)
    for p in _surface(body):
        if p[1] >= cut and p[2] >= zt - 1 and abs(p[1] - (cy - 0.4 * rr)) <= 1 and 0 <= p[0] <= max(1, round(0.3 * k)):
            body.put(p, WHITE, True)
            body.put((_mx(p[0]), p[1], p[2]), WHITE, True)


def whiskers(c, H, col, col2=None):
    """Three thin glowing whiskers each side of the muzzle (ice whiskers)."""
    k = H / 10.0
    head = head_of(c)
    if not head:
        return
    yf = min(p[1] for p in head.v)
    zs = [p[2] for p in head.v if p[1] <= yf + 1]
    zm = (min(zs) + max(zs)) / 2
    part = c.part('whiskers', 'glow')
    for i, dz in enumerate((-0.35, 0, 0.35)):
        for sx in (-1, 1):
            a = (sx * 0.8 * k, yf + 0.6 * k, zm + dz * k)
            b = (sx * 2.4 * k, yf + 0.9 * k, zm + dz * 1.8 * k)
            line(part, a, b, col, glow=True)


# ---------------------------------------------------------- plants and moss

def leaves(c, H, col, col2=None):
    """Fern fronds along the back, curling out to each side."""
    k = H / 10.0
    rib = col2 or _dark(col, 0.25)
    part = c.part('leaves', 'static')
    for i, (y, z) in enumerate(_spine(c, 3, 0.2, 0.8)):
        L = (2.8 - 0.3 * abs(i - 1)) * k
        for sx in (-1, 1):
            leaf(part, (sx * 0.3 * k, y, z - 0.4 * k), (sx * 0.7, 0.35, 0.65), L, 0.7 * k, col, rib)


def ear_leaves(c, H, col, col2=None):
    """A leaf standing up from each ear tip (leaf tufts)."""
    k = H / 10.0
    t = _ear_tips(c)
    if not t:
        return
    ears = c.part('ears')
    for sx in (-1, 1):
        x = t[0] if sx > 0 else -t[0]
        leaf(ears, (x, t[1], t[2] - 0.2 * k), (0.2 * sx, 0.1, 1), 1.4 * k, 0.45 * k, col, col2)


def leaf_hat(c, H, col, col2=None):
    """One big leaf lying on the head (a tanuki's)."""
    k = H / 10.0
    y, zt = _crown(c)
    part = c.part('hat', 'static')
    leaf(part, (0, y + 0.6 * k, zt + 1), (0, -1, 0.35), 2.4 * k, 0.9 * k, col, col2 or _dark(col, 0.3))
    line(part, (0, y + 0.6 * k, zt + 1), (0, y + 1.2 * k, zt + 0.3 * k + 1), col2 or _dark(col, 0.3))


def leaf_collar(c, H, col, col2=None):
    """A ring of leaves around the neck."""
    k = H / 10.0
    head, body = head_of(c), _find(c, 'body')
    if not head or not body or head is body:
        return
    ys = [p[1] for p in head.v]
    yb = max(ys) - 0.2 * k
    zs = [p[2] for p in head.v]
    zb = min(zs) + 0.5 * k
    part = c.part('leaves', 'static')
    for i in range(7):
        a = math.pi * (i / 6)
        d = (math.cos(a), 0.3, -0.2 + 0.5 * math.sin(a))
        leaf(part, (math.cos(a) * 1.3 * k, yb, zb + math.sin(a) * 0.4 * k), d, 1.3 * k, 0.4 * k, col, col2)


def vines(c, H, col, col2=None):
    """A winding vine painted along each flank (and the tail), with leaves."""
    k = H / 10.0
    for name in ('body', 'tail'):
        part = _find(c, name)
        if not part or not part.v:
            continue
        zs = [p[2] for p in part.v]
        zm = (min(zs) + max(zs)) / 2

        def vine(p, cc, g, zm=zm):
            if g or abs(p[0] + .5) < 0.8 * k:
                return None
            wave = math.sin(p[1] / (0.9 * k)) * 0.9 * k
            dz = (p[2] + .5) - (zm + wave)
            if abs(dz) < 0.32 * k + .3:
                return (col, False)
            if col2 and abs(dz) < 0.8 * k and (p[1] + 2) % max(3, round(1.8 * k)) == 0:
                return (col2, False)
            return None
        part.paint(vine)


def blossoms(c, H, col, col2=None):
    """Little flowers on the antlers, else the ears, else the back."""
    k = H / 10.0
    col2 = col2 or GOLD
    anchor = _find(c, 'antlers') or _find(c, 'horns')
    part = c.part('blossoms', 'static')
    spots = []
    if anchor and anchor.v:
        tips = sorted(anchor.v, key=lambda p: (-p[2], p[0]))
        right = [p for p in tips if p[0] >= 0]
        for p in right[::max(1, len(right) // 4)][:4]:
            spots.append((p[0] + .5, p[1] + .5, p[2] + 1))
    else:
        for y, z in _spine(c, 3, 0.25, 0.75):
            spots.append((0.7 * k, y, z + 0.5))
    r = max(0.6, 0.38 * k)
    for (x, y, z) in spots:
        for sx in (-1, 1):
            xx = x if sx > 0 else -x
            for dx, dy in ((r, 0), (-r, 0), (0, r), (0, -r)):
                ball(part, (xx + dx, y + dy, z), (r, r, r * 0.6), col)
            ball(part, (xx, y, z + 0.2 * k), (r * 0.7, r * 0.7, r * 0.6), col2)


def rosebud(c, H, col, col2=None):
    """A closed rosebud on a stem on the middle of the back."""
    k = H / 10.0
    stem = col2 or hexc('#3F8F3A')
    sp = _spine(c, 1, 0.4, 0.4)
    if not sp:
        return
    y, z = sp[0]
    part = c.part('rose', 'static')
    line(part, (0, y, z - 0.3 * k), (0, y, z + 1.6 * k), stem, r=0.3 * k)
    for sx in (-1, 1):
        leaf(part, (0, y, z + 0.8 * k), (sx, 0, 0.5), 1.4 * k, 0.45 * k, stem)
    ball(part, (0, y, z + 2.4 * k), (0.95 * k, 0.95 * k, 1.2 * k), col)
    ball(part, (0, y, z + 3.4 * k), (0.5 * k, 0.5 * k, 0.6 * k), _dark(col, 0.15))


def moss(c, H, col, col2=None):
    """A lumpy layer of moss over the back (and shell)."""
    k = H / 10.0
    for part in _back_parts(c):
        zs = [p[2] for p in part.v]
        zt = max(zs)
        tops = {}
        for (x, y, z) in part.v:
            if z > tops.get((x, y), -1):
                tops[(x, y)] = z
        for (x, y), z in tops.items():
            if z < zt - 1.4 * k or x < 0:
                continue
            h = 1 + (_hash(x // 3, y // 3, 13) % 2)
            for i in range(h):
                colr = col2 if (col2 and i == h - 1 and _hash(x, y, 2) % 9 == 0) else col
                part.put((x, y, z + 1 + i), colr)
                part.put((_mx(x), y, z + 1 + i), colr)


def mushrooms(c, H, col, col2=None, where='back'):
    """Toadstools on the back: red caps (col) with glowing spots (col2)."""
    k = H / 10.0
    col2 = col2 or WHITE
    part = c.part('mushrooms', 'glow')
    if where == 'head':
        y, zt = _crown(c)
        spots = [(sx * 1.0 * k, y + 0.2 * k, zt - 0.4 * k, 2.0, 1.4, sx * 0.4) for sx in (-1, 1)]
    else:
        spots = []
        for i, (y, z) in enumerate(_spine(c, 3, 0.3, 0.75)):
            sx = (-1, 1, -0.2)[i]
            spots.append((sx * 0.8 * k, y, z - 0.3 * k, (1.3, 1.6, 1.1)[i], (1.25, 1.5, 1.1)[i], 0.0))
    for (x, y, z, hgt, size, lean) in spots:
        top = (x + lean * hgt * k, y, z + hgt * k)
        line(part, (x, y, z), top, CREAM, r=0.28 * k * size + 0.2)
        cap_r = 0.9 * k * size
        part.ell((top[0], top[1], top[2] + 0.1 * k), (cap_r, cap_r, 0.55 * k * size + .3), col,
                 cond=lambda X, Y, Z, tz=top[2]: Z >= tz - 0.1 * k)
        for (px, py, pz) in list(part.v):
            if part.v[(px, py, pz)][0] == col and _hash(px, py, pz, 77) % 6 == 0:
                part.put((px, py, pz), col2, True)


def mushroom_crown(c, H, col, col2=None):
    """Toadstools growing from the head like antlers."""
    mushrooms(c, H, col, col2, where='head')


def toadstool_shell(c, H, col, col2=None):
    """A snail's shell swapped for a toadstool cap with glowing spots."""
    k = H / 10.0
    shell = _find(c, 'shell')
    if not shell or not shell.v:
        return mushrooms(c, H, col, col2)
    xs = [p[0] for p in shell.v]
    ys = [p[1] for p in shell.v]
    zs = [p[2] for p in shell.v]
    cy, z0 = (min(ys) + max(ys)) / 2, min(zs)
    shell.v = {}
    line(shell, (0, cy, z0 - 0.3 * k), (0, cy, z0 + 1.0 * k), CREAM, r=0.9 * k)
    R = (max(xs) - min(xs)) / 2 + 0.6 * k
    shell.ell((0, cy, z0 + 1.2 * k), (R, R * 1.1, 1.9 * k), col, cond=lambda X, Y, Z: Z >= z0 + 1.0 * k)
    spots = col2 or WHITE
    for p in _surface(shell):
        if _hash(p[0] // 2, p[1] // 2, p[2] // 2, 3) % 5 == 0 and shell.v[p][0] == col:
            shell.put(p, spots, True)
    shell.anim = 'glow'


# ----------------------------------------------------------- storm and cloud

def _bolt_pts(y, z, h, k, flip=1):
    """A zigzag in the y-z plane rising h from (y, z)."""
    return [(y, z), (y - 0.5 * k * flip, z + 0.45 * h), (y + 0.3 * k * flip, z + 0.5 * h),
            (y - 0.25 * k * flip, z + h)]


def _bolt(part, x, pts, col, w, glow=True):
    for a, b in zip(pts, pts[1:]):
        line(part, (x, a[0], a[1]), (x, b[0], b[1]), col, r=w, glow=glow)
        line(part, (_mx(math.floor(x)) + (x - math.floor(x)), a[0], a[1]),
             (_mx(math.floor(x)) + (x - math.floor(x)), b[0], b[1]), col, r=w, glow=glow)


def bolt(c, H, col, col2=None):
    """A lightning bolt standing up off the back, like a fin."""
    k = H / 10.0
    sp = _spine(c, 1, 0.45, 0.45)
    if not sp:
        return
    y, z = sp[0]
    part = c.part('bolt', 'glow')
    pts = _bolt_pts(y + 0.5 * k, z - 0.3 * k, 2.4 * k, k)
    for a, b in zip(pts, pts[1:]):
        for x in (-1, 0):
            line(part, (x + .5, a[0], a[1]), (x + .5, b[0], b[1]), col, r=0.35 * k, glow=True)


def bolt_crest(c, H, col, col2=None):
    """A lightning-bolt crest on the head."""
    k = H / 10.0
    y, zt = _crown(c)
    part = c.part('crest', 'glow')
    pts = _bolt_pts(y + 0.3 * k, zt - 0.3 * k, 2.2 * k, k)
    for a, b in zip(pts, pts[1:]):
        for x in (-1, 0):
            line(part, (x + .5, a[0], a[1]), (x + .5, b[0], b[1]), col, r=0.32 * k, glow=True)


def bolt_tail(c, H, col, col2=None):
    """The tail ends in a lightning bolt."""
    k = H / 10.0
    tip = _tail_tip(c)
    if not tip:
        return
    tl = c.part('tail')
    pts = _bolt_pts(tip[1] - 0.2 * k, tip[2] - 0.3 * k, 1.8 * k, k, flip=-1)
    for a, b in zip(pts, pts[1:]):
        for x in (-1, 0):
            line(tl, (x + .5, a[0], a[1]), (x + .5, b[0], b[1]), col, r=0.3 * k, glow=True)


def bolt_ears(c, H, col, col2=None):
    """Ears that are lightning bolts: the ears are redrawn as zigzags."""
    k = H / 10.0
    ears = _find(c, 'ears')
    if not ears or not ears.v:
        return ear_bolts(c, H, col, col2)
    right = [p for p in ears.v if p[0] >= 0]
    z0 = min(p[2] for p in right)
    x0 = sum(p[0] for p in right) / len(right) + 0.5
    y0 = sum(p[1] for p in right) / len(right) + 0.5
    ears.v = {}
    for sx in (-1, 1):
        x = x0 if sx > 0 else -x0
        pts = [(x, y0, z0 - 0.2 * k), (x + sx * 0.6 * k, y0, z0 + 1.0 * k), (x - sx * 0.1 * k, y0, z0 + 1.2 * k),
               (x + sx * 0.6 * k, y0, z0 + 2.6 * k)]
        for i, (a, b) in enumerate(zip(pts, pts[1:])):
            line(ears, a, b, col, r=(0.42 - 0.08 * i) * k, glow=i > 0)
    ears.anim = 'ears'


def ear_bolts(c, H, col, col2=None):
    """A small lightning zigzag on each ear tip (lightning tufts)."""
    k = H / 10.0
    t = _ear_tips(c)
    if not t:
        return
    ears = c.part('ears')
    for sx in (-1, 1):
        x = t[0] if sx > 0 else -t[0]
        pts = [(x, t[1], t[2] - 0.3 * k), (x + sx * 0.7 * k, t[1], t[2] + 1.0 * k), (x, t[1], t[2] + 1.2 * k),
               (x + sx * 0.6 * k, t[1], t[2] + 2.5 * k)]
        for a, b in zip(pts, pts[1:]):
            line(ears, a, b, col, r=0.42 * k, glow=True)


def bolt_mark(c, H, col, col2=None):
    """Two clear zigzag lightning bolts across the back (a beetle's shell),
    glowing, one on each side of the middle."""
    k = H / 10.0
    # a bolt's centre line: x offset (in units of k) at fractions of the length
    path = ((0.0, -0.55), (0.42, 0.55), (0.46, -0.25), (0.88, 0.75), (1.0, 0.85))

    def bx(t):
        for (t0, x0), (t1, x1) in zip(path, path[1:]):
            if t <= t1:
                return x0 + (x1 - x0) * (t - t0) / max(1e-6, t1 - t0)
        return path[-1][1]
    for part in _back_parts(c):
        ys = [p[1] for p in part.v]
        y0, y1 = min(ys) + 0.15 * (max(ys) - min(ys)), max(ys) - 0.1 * (max(ys) - min(ys))
        L = max(1, y1 - y0)
        zs = [p[2] for p in part.v]
        zcut = min(zs) + (max(zs) - min(zs)) * 0.45
        w = 0.32 * k + .25

        def zig(p, cc, g):
            if p[2] < zcut or not y0 <= p[1] <= y1:
                return None
            t = (p[1] - y0) / L
            x = abs(p[0] + .5)
            return (col, True) if abs(x - (1.25 + bx(t)) * k) < w else None
        part.paint(zig)


def sparks(c, H, col, col2=None):
    """Crackling static: short lightning zigzags springing out of the body's
    sides and back (rooted in the fur, so nothing floats)."""
    k = H / 10.0
    pts = []
    for part in (_find(c, 'body'), _find(c, 'tail')):
        if part and part.v:
            zs = [p[2] for p in part.v]
            zm = (min(zs) + max(zs)) / 2
            pts += [p for p in _surface(part) if p[2] > zm and p[0] >= 1.0 * k
                    and (p[0] + 1, p[1], p[2]) not in part.v]
    if not pts:
        return
    pts.sort(key=lambda p: _hash(*p, 23))
    part = c.part('sparks', 'glow')
    used = []
    for p in pts:
        if len(used) >= 4:
            break
        if any(abs(p[1] - q[1]) + abs(p[2] - q[2]) < 2.0 * k for q in used):
            continue
        used.append(p)
        colr = col2 if (col2 and len(used) % 2 == 0) else col
        L = 1.3 * k
        d = _norm((1.0, 0.0, 0.7))
        perp = (0.0, 1.0, 0.0)
        base = (p[0] + .5, p[1] + .5, p[2] + .5)
        zig = [base]
        for t, side in ((0.4, 0.35), (0.65, -0.35), (1.0, 0.1)):
            zig.append(tuple(base[j] + d[j] * L * t + perp[j] * side * k for j in range(3)))
        for a, b in zip(zig, zig[1:]):
            for sx in (1, -1):
                aa = a if sx > 0 else (-a[0], a[1], a[2])
                bb = b if sx > 0 else (-b[0], b[1], b[2])
                line(part, aa, bb, colr, r=0.18 * k + .3, glow=True)


def embers(c, H, col, col2=None):
    """Glowing ember specks set into the fur of the back, tail and head."""
    k = H / 10.0
    r = max(1, round(0.3 * k))
    for name in ('body', 'tail', 'head'):
        part = _find(c, name)
        if not part or not part.v:
            continue
        zs = [p[2] for p in part.v]
        zm = (min(zs) + max(zs)) / 2
        for p in _surface(part):
            if p[0] < 0 or p[2] < zm or _hash(*p, 71) % 40:
                continue
            colr = col2 if (col2 and _hash(*p, 3) % 2) else col
            for q in list(part.v):
                if abs(q[0] - p[0]) < r and abs(q[1] - p[1]) < r and abs(q[2] - p[2]) < r:
                    part.put(q, colr, True)
                    part.put((_mx(q[0]), q[1], q[2]), colr, True)


def rings(c, H, col, col2=None):
    """Glowing rings around the tail, like a battery's bands."""
    k = H / 10.0
    tl = _find(c, 'tail')
    if not tl or not tl.v:
        return
    y0, y1 = _yrange(tl)
    w = max(1, round(0.45 * k))
    tl.paint(lambda p, cc, g: (col, True) if ((p[1] - y0) // w) % 2 == 1 else None)


def _cloud_part(c, name):
    return c.part(name, 'static')


def cloud_hump(c, H, col, col2=None):
    """A storm cloud sitting on the back, with a bolt poking out."""
    k = H / 10.0
    sp = _spine(c, 1, 0.45, 0.45)
    if not sp:
        return
    y, z = sp[0]
    part = c.part('cloud', 'static')
    puffs(part, (0, y, z + 0.4 * k), 1.3 * k, col, n=6, seed=1)
    if col2:
        g = c.part('bolt', 'glow')
        pts = _bolt_pts(y - 0.4 * k, z + 1.4 * k, 1.6 * k, k)
        for a, b in zip(pts, pts[1:]):
            line(g, (1.1 * k, a[0], a[1]), (1.1 * k, b[0], b[1]), col2, r=0.25 * k, glow=True)
            line(g, (-1.1 * k, a[0], a[1]), (-1.1 * k, b[0], b[1]), col2, r=0.25 * k, glow=True)


def cloud_mane(c, H, col, col2=None):
    """A puffy storm-cloud mane around the head."""
    k = H / 10.0
    head = head_of(c)
    if not head or not head.v:
        return
    ys = [p[1] for p in head.v]
    zs = [p[2] for p in head.v]
    yb, zc = max(ys) - 0.6 * k, (min(zs) + max(zs)) / 2
    part = c.part('mane', 'static')
    for i in range(9):
        a = math.pi * (-0.15 + 1.3 * i / 8)
        ball(part, (math.cos(a) * 2.0 * k, yb, zc + math.sin(a) * 1.8 * k), (0.9 * k, 0.8 * k, 0.9 * k), col)
    if col2:
        sparks(c, H, col2)


def cloud_tail(c, H, col, col2=None):
    """The tail is a little storm cloud."""
    k = H / 10.0
    tip = _tail_tip(c)
    tl = c.part('tail', 'tail')
    if tip is None:
        body = _find(c, 'body')
        y1 = max(p[1] for p in body.v)
        tip = (0, y1, max(p[2] for p in body.v if p[1] >= y1 - 1))
    puffs(tl, (0, tip[1] + 0.8 * k, tip[2] + 0.3 * k), 1.5 * k, col, n=6, seed=4)
    if col2:
        pts = _bolt_pts(tip[1] + 1.2 * k, tip[2] - 2.6 * k, 2.0 * k, k)
        for a, b in zip(pts, pts[1:]):
            line(tl, (0, a[0], a[1]), (0, b[0], b[1]), col2, r=0.3 * k, glow=True)


def cloud_feet(c, H, col, col2=None):
    """Little clouds around the hooves."""
    k = H / 10.0
    body = _find(c, 'body')
    if not body:
        return
    feet = {}
    for (x, y, z) in body.v:
        if z == 0:
            feet.setdefault((x // max(1, round(0.9 * k)), y // max(1, round(0.9 * k))), []).append((x, y))
    centres = []
    for cells in feet.values():
        cx = sum(a for a, _ in cells) / len(cells) + .5
        cy = sum(b for _, b in cells) / len(cells) + .5
        if all(abs(cx - a) + abs(cy - b) > 1.2 * k for a, b in centres):
            centres.append((cx, cy))
    for cx, cy in centres:
        if cx > 0:
            for sx in (-1, 1):
                for i in range(3):
                    a = i * 2.1
                    ball(body, (sx * cx + math.cos(a) * 0.5 * k, cy + math.sin(a) * 0.5 * k, 0.35 * k),
                         (0.5 * k, 0.5 * k, 0.4 * k), col)


def raincloud(c, H, col, col2=None, a=None):
    """A little raincloud resting on the head like a cap, with glowing
    raindrops dripping from its underside past the sides of the head (each
    drip hangs from the cloud, so nothing floats or reads as a pole).
    With "float": true the cloud hovers with a clear gap above the head and
    thin drips hang from its overhanging edges instead."""
    k = H / 10.0
    col2 = col2 or hexc('#7FD4FF')
    if (a or {}).get('float'):
        return _raincloud_float(c, k, col, col2)
    y, zt = _crown(c)
    part = c.part('cloud', 'static')
    head = head_of(c)
    eyes = _find(c, 'eyes')
    # it sits just behind the eyes (a frog's are on top) and clears them
    ztop = max([zt] + [p[2] for p in eyes.v]) if eyes and eyes.v else zt
    y += 0.9 * k
    zc = ztop + 1.0 * k
    puffs(part, (0, y, zc), 1.45 * k, col, n=7, seed=8, flat=0.6)
    drops = c.part('raindrops', 'glow')
    solid = set(head.v) | (set(eyes.v) if eyes else set())
    # underside voxels of the cloud with open air below, right half
    under = {}
    for (x, yy, z) in part.v:
        if x >= 0 and (x, yy, z - 1) not in part.v and not any(
                (x, yy, z - t) in solid for t in range(1, 4)):
            under[(x, yy)] = min(z, under.get((x, yy), z))
    picked = []
    for (x, yy), z in sorted(under.items(), key=lambda t: (-t[0][0], t[0][1])):
        if all(abs(x - a) + abs(yy - b) >= max(3, 1.4 * k) for a, b, _ in picked):
            picked.append((x, yy, z))
        if len(picked) >= 3:
            break
    L = max(2, round(0.7 * k))
    for i, (x, yy, z) in enumerate(picked):
        n = L + (i % 2)
        for t in range(1, n + 1):
            for xx in (x, _mx(x)):
                drops.put((xx, yy, z - t), col2, True)
        for xx in (x, _mx(x)):  # a bulb at the end
            drops.put((xx + (1 if xx >= 0 else -1) * 0, yy - 1, z - n), col2, True)


def _raincloud_float(c, k, col, col2):
    """A raincloud floating over the head: its underside is 5 voxels above
    the top of the head, it overhangs both sides, and 4 thin drips (col2)
    with a round drop hang from the overhang, clear of the head. It is an
    "orbit" part, so the weld pass and the loose-piece check leave it
    floating, and it turns slowly in place over the head."""
    y, zt = _crown(c)
    eyes = _find(c, 'eyes')
    solid = set()
    for p in c.parts:
        if p.name not in ('cloud', 'raindrops'):
            solid |= set(p.v)
    ztop = max(q[2] for q in solid)
    R = 1.7 * k
    zb = ztop + 5
    cloud = c.part('cloud', 'orbit')
    cloud.v = {}
    cy, cz = y + 0.3 * k, zb + 0.9 * R * 0.6
    cloud.pivot = (0, cy, cz)
    puffs(cloud, (0, cy, cz), R, col, n=6, seed=8, flat=0.6)
    right = {q: v for q, v in cloud.v.items() if q[0] >= 0}
    cloud.v = dict(right)
    for (x, yy, z), v in right.items():
        cloud.v[(_mx(x), yy, z)] = v
    shade = _dark(col, 0.12)  # a grey belly so it reads as a rain cloud
    for q in list(cloud.v):
        if (q[0], q[1], q[2] - 1) not in cloud.v:
            cloud.v[q] = (shade, False)
    drops = cloud  # one piece with the cloud, so the drips turn with it

    def clear(q):
        return all(abs(q[0] - s[0]) + abs(q[1] - s[1]) + abs(q[2] - s[2]) >= 5
                   for s in solid if abs(q[2] - s[2]) < 5)
    under = {}
    for (x, yy, z) in cloud.v:
        if x >= 0 and (x, yy, z - 1) not in cloud.v:
            under[(x, yy)] = min(z, under.get((x, yy), z))
    L = max(2, round(0.8 * k))
    picked = []
    for (x, yy), z in sorted(under.items(), key=lambda t: (-t[0][0], abs(t[0][1] - y))):
        if any(abs(x - a) + abs(yy - b) < max(3, 1.2 * k) for a, b, _ in picked):
            continue
        n = L + len(picked) % 2
        cells = [(x, yy, z - t) for t in range(1, n + 1)] + [(x, yy - 1, z - n), (x, yy, z - n - 1)]
        if all(clear(q) for q in cells):
            picked.append((x, yy, z))
            for (cx, cy, cz) in cells:
                for xx in (cx, _mx(cx)):
                    drops.put((xx, cy, cz), col2, True)
        if len(picked) >= 2:
            break


def raindrops(c, H, col, col2=None):
    """Raindrops dripping down the OUTSIDE of the fleece: from each front
    corner and from mid-flank, each a thin drip (col) that starts at the
    fleece's widest point and ends in a round drop (col2, default a lighter
    tint), hanging against the side of the fleece, well above and outside
    the legs, so they read as rain on a cloud, not as glowing ankles."""
    k = H / 10.0
    body = _find(c, 'body')
    if not body:
        return
    col2 = col2 or _light(col, 0.35)
    part = c.part('raindrops', 'static')
    legs = set()
    for p in c.parts:
        if p.name.startswith('leg'):
            legs |= set(p.v)
    y0, y1 = _yrange(body)

    zs_all = [p[2] for p in body.v]
    zh = round(min(zs_all) + 0.6 * (max(zs_all) - min(zs_all)))  # where the drips start

    def widest(y):
        """(x, z): the outer edge of slice y at 60% of the fleece's height."""
        row = [x for (x, yy, z) in body.v if yy == y and z == zh and x >= 0]
        return (max(row), zh) if row else None
    yc = (y0 + y1) / 2
    L = max(2, round(0.6 * k))
    spots = []
    for y in (round(yc - 1.1 * k), round(yc + 0.7 * k)):  # mid-flank, between the legs
        e = widest(y)
        if e:
            spots.append((e[0] + 1, y, e[1]))
    # the front of the fleece, either side of the chest
    xs = [p[0] for p in body.v if p[2] == zh and p[0] >= 0]
    if xs:
        xf = max(1, round(0.55 * max(xs)))
        ys = [p[1] for p in body.v if p[0] == xf and p[2] == zh]
        if ys:
            spots.append((xf, min(ys) - 1, zh))
    for x, y, z in spots:
        cells = [(x, y, z - d) for d in range(L)]
        bulb = [(x, y, z - L), (x, y, z - L - 1), (x, y + 1, z - L), (x, y + 1, z - L - 1)]
        if any(q in legs or q in body.v for q in cells + bulb):
            # nudge out one more voxel rather than drop the drip
            cells = [(q[0] + 1, q[1], q[2]) for q in cells]
            bulb = [(q[0] + 1, q[1], q[2]) for q in bulb]
            if any(q in legs or q in body.v for q in cells + bulb):
                continue
        for q in cells + bulb:
            colr = col2 if q in bulb else col
            part.put(q, colr)
            part.put((_mx(q[0]), q[1], q[2]), colr)


def wave(c, H, col, col2=None):
    """Riding a little wave: the creature is lifted and a curling wave of
    water (col) with foam (col2) runs under it."""
    k = H / 10.0
    col2 = col2 or WHITE
    lift = max(2, round(1.0 * k))
    for p in c.parts:
        p.v = {(x, y, z + lift): v for (x, y, z), v in p.v.items()}
        p.pivot = (p.pivot[0], p.pivot[1], p.pivot[2] + lift)
    body = _find(c, 'body')
    y0, y1 = _yrange(body)
    w = c.part('wave', 'static')
    cy = (y0 + y1) / 2
    w.ell((0, cy + 0.4 * k, lift * 0.5), (2.2 * k, (y1 - y0) / 2 + 0.9 * k, lift * 0.6 + .3), col,
          cond=lambda X, Y, Z: Z < lift)
    # the curl rising behind and over
    for i in range(8):
        t = i / 7
        a = math.pi * 1.2 * t
        y = y1 + 0.6 * k - math.sin(a) * 1.0 * k
        z = lift * 0.5 + (1 - math.cos(a)) * 1.2 * k
        r = (0.7 - 0.3 * t) * k
        w.ell((0, y, z), (1.3 * k * (1 - 0.3 * t), r, r), col2 if t > 0.75 else col)
    for p in list(w.v):
        if (p[0], p[1], p[2] + 1) not in w.v and _hash(*p, 61) % 3 == 0:
            w.put(p, col2)


def raincoat(c, H, col, col2=None):
    """A little raincoat (body, top half) and a sou'wester hat."""
    k = H / 10.0
    body = _find(c, 'body')
    if body:
        zs = [p[2] for p in body.v]
        zm = min(zs) + (max(zs) - min(zs)) * 0.35
        body.paint(lambda p, cc, g: (col, False) if p[2] >= zm and not g else None)
        if col2:
            yf = min(p[1] for p in body.v)
            body.paint(lambda p, cc, g: (col2, True) if p[1] <= yf + 1 and abs(p[0] + .5) < 0.35 * k + .5 and
                       zm + 0.5 * k < p[2] < zm + 1.8 * k else None)
    y, zt = _crown(c)
    hat = c.part('hat', 'static')
    hat.ell((0, y, zt + 0.2 * k), (1.5 * k, 1.5 * k, 0.9 * k), col, cond=lambda X, Y, Z: Z >= zt - 0.2 * k)
    hat.ell((0, y + 0.4 * k, zt - 0.2 * k), (2.3 * k, 2.3 * k, 0.3 * k + .2), col)


# --------------------------------------------------------- cosmic and spirit

def stars(c, H, col, col2=None):
    """Tiny glowing stars speckled over the body, head, wings and tail.

    A star on the right side gets a twin at the mirrored spot. On a centre
    part (body, head) the twin goes into the same part; on a sided part
    (wingR, legFR) it goes into the sibling (wingL, legFL), and only onto a
    voxel that is already there, so no part ever grows across the middle."""
    k = H / 10.0
    every = max(14, round(26 * 3 / max(1.0, k)))
    by_name = {p.name: p for p in c.parts}
    for part in c.parts:
        if part.name in ('eyes',):
            continue
        twin = part
        if part.name[-1:] in ('L', 'R'):
            twin = by_name.get(part.name[:-1] + ('R' if part.name[-1] == 'L' else 'L'))
            if part.name.endswith('L'):
                continue    # handled from its right-hand sibling
        for p in _surface(part):
            if p[0] < 0:
                continue
            h = _hash(*p, 29)
            if h % every == 0:
                colr = col2 if (col2 and (h >> 8) % 3 == 0) else col
                part.put(p, colr, True)
                q = (_mx(p[0]), p[1], p[2])
                if twin is not None and q in twin.v:
                    twin.put(q, colr, True)


def galaxy(c, H, col, col2=None):
    """A swirling galaxy painted on the shell (or body and wings), with stars."""
    k = H / 10.0
    col2 = col2 or _light(col, 0.4)
    targets = [_find(c, 'shell')] if _find(c, 'shell') else [_find(c, n) for n in ('body', 'wingL', 'wingR')]
    for part in targets:
        if not part or not part.v:
            continue
        ys = [p[1] for p in part.v]
        zs = [p[2] for p in part.v]
        cy, cz = (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2

        def swirl(p, cc, g, cy=cy, cz=cz):
            if g or cc in (INK, WHITE):
                return None
            r = math.hypot(p[1] + .5 - cy, p[2] + .5 - cz) / max(1.0, k)
            a = math.atan2(p[2] + .5 - cz, p[1] + .5 - cy)
            band = (a / math.pi + r * 0.55) % 1
            if band < 0.28:
                return (col2, band < 0.08)
            if band < 0.6:
                return (col, False)
            return None
        part.paint(swirl)
    stars(c, H, WHITE, hexc('#FFE98A'))


def crescent(c, H, col, col2=None):
    """A glowing crescent moon on the back."""
    k = H / 10.0
    sp = _spine(c, 1, 0.5, 0.5)
    if not sp:
        return
    y, z = sp[0]
    part = c.part('moon', 'glow')
    R = 2.3 * k
    cz = z + R * 0.75
    Ri = int(R) + 2
    for a in range(-Ri, Ri + 1):
        for b in range(-Ri, Ri + 1):
            yy, zz = a + .5, b + .5
            if math.hypot(yy, zz) <= R and math.hypot(yy + 0.55 * R, zz - 0.25 * R) > R * 0.85:
                for x in range(-max(1, round(0.4 * k)), max(1, round(0.4 * k))):
                    part.put((x, math.floor(y + yy), math.floor(cz + zz)), col, True)


def flank_crescent(c, H, col, col2=None):
    """A glowing crescent moon marked on each flank (a moon unicorn's)."""
    k = H / 10.0
    body = _find(c, 'body')
    if not body or not body.v:
        return
    zs = sorted(p[2] for p in body.v)
    ys = sorted(p[1] for p in body.v)
    zc = zs[len(zs) * 3 // 4]  # high on the flank, above the legs
    yc = ys[len(ys) // 2] + 0.4 * k  # toward the hindquarters
    R = 1.15 * k
    for sx in (1, -1):
        edge = {}
        for (x, y, z) in body.v:
            if (x >= 0) == (sx > 0):
                key = (y, z)
                if key not in edge or x * sx > edge[key] * sx:
                    edge[key] = x
        for (y, z), x in edge.items():
            yy, zz = y + .5 - yc, z + .5 - zc
            if math.hypot(yy, zz) <= R and math.hypot(yy + 0.5 * R, zz - 0.3 * R) > R * 0.8:
                body.v[(x, y, z)] = (col, True)


def halo(c, H, col, col2=None):
    """A glowing ring floating over the head."""
    k = H / 10.0
    y, zt = _crown(c)
    part = c.part('halo', 'glow')
    R, z = 1.1 * k, zt + 1.0 * k
    n = max(24, round(R * 10))
    for i in range(n):
        a = 2 * math.pi * i / n
        part.ell((math.cos(a) * R, y + math.sin(a) * R * 0.8, z), (0.22 * k + .3, 0.22 * k + .3, 0.2 * k + .3), col, True)


def star_trail(c, H, col, col2=None):
    """A few glowing stars drifting off the rump, smaller and smaller."""
    k = H / 10.0
    body = _find(c, 'body')
    y0, y1 = _yrange(body)
    ztop = max(p[2] for p in body.v)
    part = c.part('startrail', 'glow')
    rib = [(0, y1 - 0.4 * k, ztop - 0.8 * k), (0, y1 + 0.6 * k, ztop - 0.6 * k), (0, y1 + 1.6 * k, ztop + 0.1 * k),
           (0, y1 + 2.4 * k, ztop - 0.4 * k)]
    for a, b in zip(rib, rib[1:]):
        line(part, a, b, col2 or col, glow=True)
        line(part, (-1, a[1], a[2]), (-1, b[1], b[2]), col2 or col, glow=True)
    for i, (dy, dz, s) in enumerate(((0.6, 0.2, 0.55), (1.6, 0.9, 0.42), (2.4, 0.4, 0.3))):
        cy, cz = y1 + dy * k, ztop - 0.6 * k + dz * k
        r = max(1, round(s * k))
        colr = col2 if (col2 and i == 1) else col
        for d in range(-r, r + 1):
            for v in ((d, 0, 0), (0, 0, d), (0, d, 0)):
                part.put((math.floor(v[0]), math.floor(cy + v[1]), math.floor(cz + v[2])), colr, True)
                part.put((-1 + math.floor(v[0]), math.floor(cy + v[1]), math.floor(cz + v[2])), colr, True)


def constellation(c, H, col, col2=None):
    """Drawn as a constellation: glowing star points over the body and head,
    joined by thin glowing lines."""
    k = H / 10.0
    col2 = col2 or _mix(col, WHITE, 0.2)
    for part in (_find(c, 'body'), head_of(c), _find(c, 'antlers')):
        if not part or not part.v:
            continue
        surf = [p for p in _surface(part) if p[0] >= 0]
        if not surf:
            continue
        surf.sort(key=lambda p: _hash(*p, 47))
        nodes = []
        for p in surf:
            if all(math.dist(p, q) > 2.2 * k for q in nodes):
                nodes.append(p)
            if len(nodes) >= (7 if part.name == 'body' else 4):
                break
        nodes.sort(key=lambda p: (p[1], p[2]))
        sset = set(surf)
        for a, b in zip(nodes, nodes[1:]):
            n = max(2, round(math.dist(a, b) * 2))
            for i in range(n + 1):
                t = i / n
                q = tuple(a[j] + (b[j] - a[j]) * t for j in range(3))
                best = min(sset, key=lambda s: (s[0] - q[0]) ** 2 + (s[1] - q[1]) ** 2 + (s[2] - q[2]) ** 2) \
                    if part.name != 'body' or n < 40 else tuple(round(v) for v in q)
                if best in part.v:
                    part.put(best, col2, True)
                    part.put((_mx(best[0]), best[1], best[2]), col2, True)
        r = max(1, round(0.35 * k))
        for p in nodes:
            for d in range(-r, r + 1):
                for v in ((d, 0, 0), (0, d, 0), (0, 0, d)):
                    q = (p[0] + v[0], p[1] + v[1], p[2] + v[2])
                    part.put(q, col, True)
                    part.put((_mx(q[0]), q[1], q[2]), col, True)


def glow_eyes(c, H, col, col2=None):
    """The eyes glow (the white shine stays)."""
    e = _find(c, 'eyes')
    if not e:
        return
    for p, (cc, g) in list(e.v.items()):
        if cc != WHITE:
            e.v[p] = (col, True)


def iris_eyes(c, H, col, col2=None, a=None):
    """Big readable eyes: each eye becomes a 3x3 disc (2x2 on small builds)
    of iris colour (col) round a dark pupil (col2), with a white shine on the
    same upper corner of both eyes. For eyes that vanish into a dark or busy
    face (a lava toad's rock, an owl's pale disc). "iris_glow": true on the
    entry makes the iris glow (only the iris, not the pupil or shine)."""
    e = _find(c, 'eyes')
    if not e or not e.v:
        return
    k = H / 10.0
    glow = bool((a or {}).get('iris_glow'))
    pupil = col2 or INK
    n = 3 if k >= 1.6 else 2
    old = dict(e.v)
    e.v = {}
    hosts = [p for p in c.parts if p.name in ('head', 'body') and p.v]
    for side in (1, -1):
        pts = [q for q in old if (q[0] >= 0) == (side > 0)]
        if not pts:
            continue
        cx = sum(q[0] for q in pts) / len(pts)
        cz = sum(q[2] for q in pts) / len(pts)
        y0 = min(q[1] for q in pts)
        x0, z0 = round(cx - (n - 1) / 2), round(cz - (n - 1) / 2)
        # one flat disc at the depth of the front-most face voxel over it, so
        # no face voxel stands in front of part of the eye (a slit or blob)
        fronts = []
        for i in range(n):
            for j in range(n):
                for y in range(y0 - 2, y0 + 4):
                    if (x0 + i, y, z0 + j) in old or any((x0 + i, y, z0 + j) in h.v for h in hosts):
                        fronts.append(y)
                        break
        yd = min(fronts) if fronts else y0
        for i in range(n):
            for j in range(n):
                x, z = x0 + i, z0 + j
                for h in hosts:
                    h.v.pop((x, yd, z), None)
                spot = (x, yd, z)
                if n == 3 and i == 1 and j == 1:
                    e.v[spot] = (pupil, False)
                elif i == 0 and j == n - 1:  # the shine: upper corner toward -x
                    e.v[spot] = (WHITE, False)
                elif n == 2 and i == 1 and j == 0:
                    e.v[spot] = (pupil, False)
                else:
                    e.v[spot] = (col, glow)
    # old eye voxels outside the new discs go back to plain face
    head = next((h for h in hosts if h.name == 'head'), hosts[0] if hosts else None)
    for q, v in old.items():
        if q not in e.v and head is not None and not any((q[0], yy, q[2]) in e.v for yy in range(q[1] - 2, q[1] + 3)):
            nb = [head.v[r][0] for r in ((q[0] + 1, q[1], q[2]), (q[0] - 1, q[1], q[2]), (q[0], q[1] + 1, q[2])) if r in head.v]
            if nb:
                head.v[q] = (nb[0], False)


def zigzag_tips(c, H, col, col2=None):
    """Zigzag frost tips along the trailing edge of the wings and the end of
    the tail: the edge is painted col and every third feather pokes out one
    voxel in glowing col2."""
    body = _find(c, 'body')
    solid = set(body.v) if body else set()
    for name in ('wingL', 'wingR', 'wing', 'wings'):
        w = _find(c, name)
        if not w or not w.v:
            continue
        low = {}
        for (x, y, z) in w.v:
            if (x, y) not in low or z < low[(x, y)]:
                low[(x, y)] = z
        for (x, y), z in low.items():
            w.v[(x, y, z)] = (col, False)
            if (x + y) % 3 == 0 and (x, y, z - 1) not in solid:
                w.v[(x, y, z - 1)] = (col2 or col, True)
    t = _find(c, 'tail')
    if t and t.v:
        end = {}
        for (x, y, z) in t.v:
            if (x, z) not in end or y > end[(x, z)]:
                end[(x, z)] = y
        for (x, z), y in end.items():
            t.v[(x, y, z)] = (col, False)
            if (x + z) % 3 == 0:
                t.v[(x, y + 1, z)] = (col2 or col, True)


def sheep_ears(c, H, col, col2=None):
    """A sheep's ears: small and flat, sticking out sideways and a little
    down from the sides of the head, pink inside (col2). Replaces the plan's."""
    k = H / 10.0
    ears = _find(c, 'ears')
    head = head_of(c)
    if not ears or not head:
        return
    ears.v = {}
    zs = [p[2] for p in head.v]
    zc = round(min(zs) + (max(zs) - min(zs)) * 0.62)
    ys = [p[1] for p in head.v if p[2] == zc] or [p[1] for p in head.v]
    yc = round((min(ys) + max(ys)) / 2 + 0.3 * k)
    L = max(2, round(1.0 * k))
    hw = max(1, round(0.3 * k))
    inner = col2 or hexc('#F2B8C6')
    for sx in (1, -1):
        xs = [p[0] for p in head.v if p[2] == zc and abs(p[1] - yc) <= 1 and (p[0] >= 0) == (sx > 0)]
        if not xs:
            continue
        edge = max(xs) if sx > 0 else min(xs)
        for i in range(1, L + 1):
            x = edge + sx * i
            z = zc - (i * 2) // 3  # angled a little down
            w = hw if i < L else max(0, hw - 1)
            for y in range(yc - w, yc + w + 1):
                ears.put((x, y, z), col)
            if 1 < i < L:  # pink on the front edge
                ears.put((x, yc - w, z), inner)


def glow_color(c, H, col, col2=None):
    """Every voxel of exactly this colour glows (a snout, a beak, spots)."""
    for part in c.parts:
        for p, (cc, g) in list(part.v.items()):
            if cc == col:
                part.v[p] = (col2 or col, True)


def ghost(c, H, col, col2=None):
    """Pale and spectral: colours fade toward col, edges glow softly."""
    for part in c.parts:
        if part.name == 'eyes':
            continue
        for p, (cc, g) in list(part.v.items()):
            part.v[p] = (_mix(cc, col, 0.65), g)
    body = _find(c, 'body')
    if body and col2:
        zs = [p[2] for p in body.v]
        z0 = min(zs)
        body.paint(lambda p, cc, g: (col2, True) if p[2] <= z0 + 1 else None)


def wisps(c, H, col, col2=None):
    """Ghostly flames drifting up off the back and tail."""
    k = H / 10.0
    col2 = col2 or WHITE
    part = c.part('wisps', 'glow')
    for i, (y, z) in enumerate(_spine(c, 2, 0.4, 0.85)):
        tongue(part, ((-0.7 if i else 0.7) * k, y, z - 0.3 * k), 2.6 * k, 0.9 * k, col, col2, lean=0.45)
        tongue(part, ((0.7 if i else -0.7) * k, y, z - 0.3 * k), 2.2 * k, 0.8 * k, col, col2, lean=0.45)


def cloak(c, H, col, col2=None):
    """A glowing spirit cloak over the shoulders and back."""
    k = H / 10.0
    body = _find(c, 'body')
    if not body:
        return
    y0, y1 = _yrange(body)
    part = c.part('cloak', 'glow')
    tops = {}
    for (x, y, z) in body.v:
        if z > tops.get((x, y), -1):
            tops[(x, y)] = z
    zt = max(tops.values())
    for (x, y), z in tops.items():
        if y < y0 + (y1 - y0) * 0.15 or y > y0 + (y1 - y0) * 0.85 or z < zt - 1.6 * k:
            continue
        edge = abs(x + .5) > 1.6 * k or y > y0 + (y1 - y0) * 0.78
        part.put((x, y, z + 1), col2 if (col2 and edge) else col, True)


def opal(c, H, col, col2=None):
    """Shimmering opal skin: soft patches of col, col2, mint and lilac."""
    k = H / 10.0
    tints = [col, col2 or hexc('#FFD1F0'), hexc('#B8FFE4'), hexc('#D9C7FF'), hexc('#FFF4B8')]
    s = max(2, round(1.0 * k))
    for name in ('body', 'head'):
        part = _find(c, name)
        if not part:
            continue
        part.paint(lambda p, cc, g: None if (g or cc in (INK, WHITE)) else
                   (_mix(cc, tints[_hash(abs(p[0] + .5) // s, p[1] // s, p[2] // s, 6) % len(tints)], 0.55), False))
    stars(c, H, WHITE)


def rainbow_shell(c, H, col, col2=None):
    """Rainbow bands spiralling round the shell."""
    k = H / 10.0
    shell = _find(c, 'shell')
    if not shell:
        return
    bands = [hexc(h) for h in ('#FF5D73', '#FF9F43', '#FFE14D', '#5EE07A', '#4DB8FF', '#9B7BFF')]
    ys = [p[1] for p in shell.v]
    zs = [p[2] for p in shell.v]
    cy, cz = (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2
    w = max(1.0, 0.55 * k)
    shell.paint(lambda p, cc, g: (bands[int((math.hypot(p[1] + .5 - cy, p[2] + .5 - cz) +
                                              math.atan2(p[2] - cz, p[1] - cy) * 0.5) / w) % 6], False))


# ------------------------------------------------------ candy and clockwork

def sprinkles(c, H, col, col2=None):
    """Candy sprinkles over the top half of the body and head."""
    k = H / 10.0
    cols = [col, col2 or hexc('#FFE14D'), hexc('#7FE3FF'), hexc('#FF7AB6'), hexc('#9BF27A')]
    for name in ('body', 'head'):
        part = _find(c, name)
        if not part or not part.v:
            continue
        zs = [p[2] for p in part.v]
        zm = (min(zs) + max(zs)) / 2
        for p in _surface(part):
            if p[2] >= zm and p[0] >= 0 and _hash(*p, 53) % 9 == 0:
                cc = cols[_hash(*p, 2) % len(cols)]
                part.put(p, cc)
                part.put((_mx(p[0]), p[1], p[2]), cc)


def icing(c, H, col, col2=None):
    """Icing on the top of the body and head with drips down the sides."""
    k = H / 10.0
    for name in ('body', 'head'):
        part = _find(c, name)
        if not part or not part.v:
            continue
        tops = {}
        for (x, y, z) in part.v:
            if z > tops.get((x, y), -1):
                tops[(x, y)] = z
        zt = max(tops.values())
        for p in _surface(part):
            drip = (_hash(abs(p[0] + .5) // max(1, round(0.5 * k)), p[1] // max(1, round(0.5 * k)), 4) % 3) * 0.4 * k
            if p[2] >= zt - 0.6 * k - drip:
                part.put(p, col)
    if col2:
        sprinkles(c, H, col2, None)


def swirl(c, H, col, col2=None):
    """Big swirly patches (strawberry on vanilla)."""
    k = H / 10.0
    for name in ('body', 'head'):
        part = _find(c, name)
        if not part or not part.v:
            continue

        def sw(p, cc, g):
            if g or cc in (INK, WHITE) and name == 'head':
                return None
            a = math.atan2(p[2] - 3 * k, p[1] + .5)
            r = math.hypot(p[1] + .5, p[2] - 3 * k) / k
            return (col, False) if (a / math.pi + r * 0.35 + (abs(p[0] + .5) > 1.4 * k) * 0.25) % 1 < 0.4 else None
        part.paint(sw)


def cone_horn(c, H, col, col2=None):
    """A waffle-cone horn with a scoop on top (an ice-cream unicorn)."""
    k = H / 10.0
    y, zt = _crown(c)
    part = c.part('horn', 'static')
    n = max(4, round(3.0 * k))
    for i in range(n):
        r = 0.8 * k * (1 - i / n) + 0.3
        for dx in range(-math.ceil(r) - 1, math.ceil(r) + 1):
            for dy in range(-math.ceil(r) - 1, math.ceil(r) + 1):
                if math.hypot(dx + .5, dy + .5) <= r:
                    z = zt - round(0.4 * k) + (n - 1 - i)
                    colr = _dark(col, 0.25) if (dx + dy + z) % 3 == 0 else col
                    part.put((dx, round(y - 0.4 * k) + dy, z), colr)
    ball(part, (0, y - 0.4 * k, zt - round(0.4 * k) + n + 0.3 * k), (1.0 * k, 1.0 * k, 0.8 * k), col2 or hexc('#FF9EC4'))


def spiral_horn(c, H, col, col2=None):
    """A unicorn's horn: slender and tall, rising from the forehead with a
    spiral groove (col2) winding up it and a glowing tip."""
    k = H / 10.0
    head = head_of(c)
    y, zt = _crown(c)
    yf = min(p[1] for p in head.v)
    yb = round(y + (yf - y) * 0.45)  # forward of the crown, over the brow
    part = c.part('horn', 'glow', (0, yb, zt))
    n = max(5, round(3.2 * k))
    groove = col2 or _dark(col, 0.3)
    for i in range(n):
        t = i / (n - 1)
        r = 0.42 * k * (1 - t) + 0.3
        lean = round(t * 0.5 * k)  # a gentle forward lean
        for dx in range(-math.ceil(r) - 1, math.ceil(r) + 1):
            for dy in range(-math.ceil(r) - 1, math.ceil(r) + 1):
                if math.hypot(dx + .5, dy + .5) <= r:
                    ang = (math.atan2(dy + .5, dx + .5) / (2 * math.pi)) % 1.0
                    spiral = (ang + i / max(2.0, 1.4 * k)) % 1.0 < 0.22
                    tip = t > 0.82
                    part.put((dx, yb + dy - lean, zt - 1 + i), col if tip else (groove if spiral else col), tip)


def gears(c, H, col, col2=None):
    """A brass cog on each flank."""
    k = H / 10.0
    body = _find(c, 'body')
    if not body:
        return
    y0, y1 = _yrange(body)
    zs = [p[2] for p in body.v]
    yc, zc = round((y0 + y1) / 2), round(min(zs) + (max(zs) - min(zs)) * 0.6)
    x = _side_x(body, yc, zc)
    if x is None:
        return
    part = c.part('gears', 'static')
    R = 1.1 * k
    for sx in (1, -1):
        cx = x + 1 if sx > 0 else _mx(x) - 1
        gear(part, (cx, yc, zc), 'x', R, 8, col, col2 or _dark(col, 0.3))


def windup_key(c, H, col, col2=None):
    """A wind-up key standing on the back; it turns (orbit anim)."""
    k = H / 10.0
    sp = _spine(c, 1, 0.55, 0.55)
    if not sp:
        return
    y, z = sp[0]
    part = c.part('key', 'orbit', (0, y + .5, z))
    for x in (-1, 0):
        line(part, (x + .5, y + .5, z - 0.3 * k), (x + .5, y + .5, z + 1.6 * k), col, r=0.3 * k)
    for sx in (-1, 1):
        R = 1.0 * k
        cx = sx * 1.15 * k
        for i in range(48):
            a = 2 * math.pi * i / 48
            for t in (0, 0.5, 1.0):
                part.ell((cx + math.cos(a) * R, y + t, z + 2.3 * k + math.sin(a) * R), (0.25 * k, 0.4, 0.25 * k), col)
    if col2:
        ball(part, (0, y + .5, z + 1.5 * k), (0.45 * k, 0.45 * k, 0.45 * k), col2)


def cog_spines(c, H, col, col2=None):
    """Little cogs standing up along the back instead of spines."""
    k = H / 10.0
    part = c.part('gears', 'static')
    for y, z in _spine(c, 3, 0.2, 0.8):
        gear(part, (-1, y, z + 0.8 * k), 'x', 1.2 * k, 7, col, col2 or _dark(col, 0.3), depth=2)


def rivets(c, H, col, col2=None):
    """Rows of rivets, and panel seams round the middle."""
    k = H / 10.0
    body = _find(c, 'body')
    if not body:
        return
    zs = [p[2] for p in body.v]
    zm = round((min(zs) + max(zs)) / 2)
    s = max(2, round(0.9 * k))
    for p in _surface(body):
        if p[2] == zm:
            body.put(p, col2 or _dark(col, 0.3))
        elif abs(p[2] - zm) == s and p[1] % s == 0:
            body.put(p, col)


def clock_dial(c, H, col, col2=None):
    """A clock face on the chest, with ink hands and a gold rim."""
    k = H / 10.0
    body = _find(c, 'body')
    if not body:
        return
    zs = [p[2] for p in body.v]
    zc = min(zs) + (max(zs) - min(zs)) * 0.45
    R = 1.1 * k
    face = col2 or CREAM
    for p in _surface(body):
        if p[1] > min(q[1] for q in body.v if q[2] == p[2]) + 1 if any(q[2] == p[2] for q in body.v) else True:
            continue
        d = math.hypot(p[0] + .5, p[2] + .5 - zc)
        if d <= R:
            body.put(p, col if d > R - 0.35 * k - .5 else face, d > R - 0.35 * k - .5)
    for q in list(body.v):
        if body.v[q][0] == face:
            dx, dz = q[0] + .5, q[2] + .5 - zc
            if (abs(dx) < 0.6 and 0 < dz < R * 0.75) or (abs(dz) < 0.6 and 0 < dx < R * 0.55):
                body.put(q, INK)


def chimney(c, H, col, col2=None):
    """A little chimney on the back puffing steam."""
    k = H / 10.0
    sp = _spine(c, 1, 0.55, 0.55)
    if not sp:
        return
    y, z = sp[0]
    part = c.part('chimney', 'static')
    for x in range(-max(1, round(0.4 * k)), max(1, round(0.4 * k))):
        for yy in range(round(y - 0.4 * k), round(y + 0.4 * k) + 1):
            for zz in range(z - 1, z + round(1.4 * k)):
                part.put((x, yy, zz), col)
    for x in range(-max(1, round(0.4 * k)) - 1, max(1, round(0.4 * k)) + 1):
        for yy in range(round(y - 0.4 * k) - 1, round(y + 0.4 * k) + 2):
            part.put((x, yy, z + round(1.4 * k)), _dark(col, 0.25))
    steam = c.part('steam', 'static')
    for i, s_ in enumerate((0.6, 0.75, 0.55)):
        ball(steam, (0, y + 0.25 * k * i, z + 1.4 * k + (0.45 + 1.0 * i) * k), (s_ * k, s_ * k, s_ * k),
             col2 or hexc('#F2F2F7'))


def chest_shell(c, H, col, col2=None):
    """A tiny treasure chest worn as a shell, lid open on gold coins."""
    k = H / 10.0
    body = _find(c, 'body')
    if not body:
        return
    y0, y1 = _yrange(body)
    zt = max(p[2] for p in body.v)
    gold = col2 or GOLD
    part = c.part('chest', 'static')
    w, d, h = round(1.8 * k), round(1.3 * k), round(1.2 * k)
    yc = round((y0 + y1) / 2 + 0.2 * k)
    zb = zt - round(0.4 * k)
    for x in range(-w, w):
        for y in range(yc - d, yc + d):
            for z in range(zb, zb + h):
                edge = x in (-w, w - 1) or y in (yc - d, yc + d - 1)
                band = abs(x + .5) < 0.35 * k + .5 or z == zb + h - 1 and edge
                part.put((x, y, z), gold if band else (col if not edge else _dark(col, 0.2)))
    coins = c.part('coins', 'glow')
    for x in range(-w + 1, w - 1):
        for y in range(yc - d + 1, yc + d - 1):
            hh = 1 + _hash(abs(x + .5), y, 5) % 2
            for z in range(zb + h, zb + h + hh):
                coins.put((x, y, z), gold, True)
    # the lid, tipped open behind
    for x in range(-w, w):
        for i in range(round(1.4 * k)):
            for t in range(2):
                part.put((x, yc + d - 1 + t, zb + h + i), gold if abs(x + .5) < 0.35 * k + .5 else col)


def mimic(c, H, col, col2=None):
    """The body is a treasure chest with its lid open: teeth, a tongue and
    glowing eyes under the lid (a crab's legs carry it)."""
    k = H / 10.0
    gold = col2 or GOLD
    body, head = _find(c, 'body'), _find(c, 'head')
    eyes = _find(c, 'eyes')
    for p in (body, head, eyes):
        if p:
            p.v = {}
    w, d = round(2.4 * k), round(1.9 * k)
    zb, h = round(1.0 * k), round(1.7 * k)
    for x in range(-w, w):
        for y in range(-d, d):
            for z in range(zb, zb + h):
                edge = x in (-w, w - 1) or y in (-d, d - 1)
                corner = (x in (-w, w - 1)) and (y in (-d, d - 1))
                band = abs(x + .5) < 0.3 * k + .5 or corner or z == zb
                body.put((x, y, z), gold if band else (_dark(col, 0.2) if edge and (y + z) % 3 == 0 else col))
    # mouth: dark inside, teeth along the rim, a tongue lolling out
    for x in range(-w + 1, w - 1):
        for y in range(-d + 1, d - 1):
            body.put((x, y, zb + h - 1), INK)
    for x in range(-w + 1, w - 1, 2):
        body.put((x, -d + 1, zb + h), WHITE)
    tongue_c = hexc('#FF6B8B')
    for i in range(round(1.8 * k)):
        for x in (-1, 0):
            body.put((x, -d + 1 - i // 2, zb + h - 1 - i // 3), tongue_c)
    # the lid, opened up and back, with glowing eyes on its underside front
    lid = c.part('head', 'head', (0, d - 1, zb + h))
    lh = round(1.0 * k)
    for x in range(-w, w):
        for i in range(round(2.0 * k)):
            for t in range(lh):
                y = d - 1 - t
                z = zb + h + i
                rim = i == round(2.0 * k) - 1 or (x in (-w, w - 1) and t == 0)
                lid.put((x, y + round(i * 0.35), z), gold if (abs(x + .5) < 0.3 * k + .5 or rim) else col)
    e = c.part('eyes', 'glow', lid.pivot)
    for sx in (-1, 1):
        x = round(sx * 0.9 * k) - (1 if sx < 0 else 0)
        for dz in range(max(1, round(0.35 * k))):
            e.put((x, d - lh - 1 + round((1 + dz) * 0.35), zb + h + 1 + dz), hexc('#FFE14D'), True)


# ------------------------------------------------------ mythic bits and bobs

def tails(c, H, col, col2=None, n=2):
    """Two (or three) tails fanned out, tips in col; col2 adds a spirit
    flame on each tip."""
    k = H / 10.0
    tl = _find(c, 'tail')
    if not tl or not tl.v:
        return
    src = dict(tl.v)
    y0 = min(p[1] for p in src)
    spreads = (-0.55, 0.55) if n == 2 else (-0.75, 0.0, 0.75)
    out = {}
    for s in spreads:
        for (x, y, z), v in src.items():
            nx = math.floor((x + .5) + s * (y - y0) - .5 + .5) if s else x
            out[(nx, y, z)] = v
    ymax = max(p[1] for p in out)
    tl.v = out
    tl.paint(lambda p, cc, g: (col, bool(col2)) if p[1] >= ymax - 0.9 * k else None)
    if col2:
        for s in spreads:
            tip_y = ymax
            tip_x = s * (tip_y - y0)
            zs = [p[2] for p in out if p[1] >= tip_y - 1]
            tongue(tl, (tip_x, tip_y - 0.4 * k, max(zs) - 0.3 * k), 1.2 * k, 0.5 * k, col2, WHITE, lean=0.2)


def twin_tails(c, H, col, col2=None):
    tails(c, H, col, col2, 2)


def triple_tails(c, H, col, col2=None):
    tails(c, H, col, col2, 3)


def three_heads(c, H, col=None, col2=None):
    """Two more heads beside the first, on short necks."""
    k = H / 10.0
    head = _find(c, 'head')
    if not head or not head.v:
        return
    eyes = _find(c, 'eyes')
    xs = [p[0] for p in head.v]
    w = max(xs) - min(xs) + 1
    off = round(w * 0.78)
    back = round(0.7 * k)
    down = round(0.3 * k)
    hv = dict(head.v)
    ev = dict(eyes.v) if eyes else {}
    ys = [p[1] for p in hv]
    zs = [p[2] for p in hv]
    neck_col = hv[max(hv, key=lambda p: (p[1], -abs(p[0])))][0]
    for sx in (-1, 1):
        dx = sx * off
        for (x, y, z), v in hv.items():
            head.v.setdefault((x + dx, y + back, z - down), v)
        for (x, y, z), v in ev.items():
            eyes.v[(x + dx, y + back, z - down)] = v
        # a neck from the shoulder to the side head
        a = (sx * 0.9 * k, max(ys) + 0.4 * k, (min(zs) + max(zs)) / 2 - 0.6 * k)
        b = (dx + (0.5 if sx > 0 else -0.5), (min(ys) + max(ys)) / 2 + back + 0.4 * k, (min(zs) + max(zs)) / 2 - down)
        line(head, a, b, neck_col, r=0.65 * k)


def snake_tail(c, H, col, col2=None):
    """The tail is a little snake, with eyes and a forked tongue."""
    k = H / 10.0
    tl = c.part('tail', 'tail')
    body = _find(c, 'body')
    y1 = max(p[1] for p in body.v)
    zb = max(p[2] for p in body.v if p[1] >= y1 - 1)
    tl.v = {}
    pts = []
    for i in range(14):
        t = i / 13
        pts.append((0, y1 + 0.2 * k + math.sin(t * math.pi * 0.9) * 1.6 * k - t * 0.8 * k, zb - 0.6 * k + t * 2.6 * k))
    for i, p in enumerate(pts):
        r = 0.42 * k
        tl.ell(p, (r, r, r), col)
    hx, hy, hz = pts[-1]
    tl.ell((0, hy - 0.5 * k, hz + 0.2 * k), (0.6 * k, 0.8 * k, 0.5 * k), col)
    for sx in (-1, 1):
        x = round(sx * 0.35 * k) - (1 if sx < 0 else 0)
        tl.put((x, math.floor(hy - 0.9 * k), math.floor(hz + 0.4 * k)), INK)
    fork = col2 or hexc('#FF4D6D')
    for i in range(max(2, round(0.6 * k))):
        tl.put((0, math.floor(hy - 1.3 * k) - i, math.floor(hz)), fork)
        tl.put((-1, math.floor(hy - 1.3 * k) - i, math.floor(hz)), fork)


def dragon_tail(c, H, col, col2=None):
    """A long scaly tail with a row of spikes."""
    k = H / 10.0
    tl = c.part('tail', 'tail')
    body = _find(c, 'body')
    y1 = max(p[1] for p in body.v)
    zb = max(p[2] for p in body.v if p[1] >= y1 - 1) - 0.8 * k
    tl.v = {}
    for i in range(16):
        t = i / 15
        r = (0.65 - 0.45 * t) * k
        p = (0, y1 - 0.4 * k + t * 3.0 * k, zb + math.sin(t * math.pi) * 0.9 * k - t * 0.6 * k)
        tl.ell(p, (r, r, r), col)
        if i % 3 == 1 and col2:
            line(tl, (0, p[1], p[2] + r), (0, p[1] + 0.3 * k, p[2] + r + 0.55 * k), col2)
            line(tl, (-1, p[1], p[2] + r), (-1, p[1] + 0.3 * k, p[2] + r + 0.55 * k), col2)


def tusks(c, H, col, col2=None):
    """Two tusks curving up from the snout, berry-tipped (col2)."""
    k = H / 10.0
    head = head_of(c)
    yf = min(p[1] for p in head.v)
    zs = [p[2] for p in head.v if p[1] <= yf + 1]
    z0 = min(zs)
    part = c.part('tusks', 'static')
    for sx in (-1, 1):
        a = (sx * 0.9 * k, yf + 0.4 * k, z0 + 0.3 * k)
        b = (sx * 1.3 * k, yf - 0.2 * k, z0 + 1.3 * k)
        line(part, a, b, col, r=0.22 * k + .2)
        if col2:
            ball(part, (b[0], b[1], b[2] + 0.2 * k), (0.4 * k, 0.4 * k, 0.4 * k), col2)


def thorn_mane(c, H, col, col2=None):
    """A mane of thorny vines around the neck, with berries or roses."""
    k = H / 10.0
    head, body = head_of(c), _find(c, 'body')
    if not head or not body or head is body:
        return
    ys = [p[1] for p in head.v]
    zs = [p[2] for p in head.v]
    yb, zc = max(ys) - 0.3 * k, (min(zs) + max(zs)) / 2 - 0.4 * k
    part = c.part('mane', 'static')
    for i in range(11):
        a = math.pi * (-0.1 + 1.2 * i / 10)
        p = (math.cos(a) * 1.9 * k, yb, zc + math.sin(a) * 1.7 * k)
        ball(part, p, (0.5 * k, 0.6 * k, 0.5 * k), col)
        out = (math.cos(a), 0.4, math.sin(a))
        line(part, p, tuple(p[j] + out[j] * 0.9 * k for j in range(3)), _dark(col, 0.3))
        if col2 and i % 3 == 1:
            ball(part, tuple(p[j] + out[j] * 0.5 * k for j in range(3)), (0.35 * k, 0.35 * k, 0.35 * k), col2)


def antlers(c, H, col, col2=None, a=None):
    """Small branching antlers on any head (a jackalope's). "size" scales
    them (default 1); with col2 the tines end in that colour."""
    k = H / 10.0 * float((a or {}).get('size', 1.0))
    y, zt = _crown(c)
    part = c.part('antlers', 'static')
    if (a or {}).get('size'):
        _antlers_big(part, k, y, zt, col, col2 or col)
        return
    for sx in (-1, 1):
        a = (sx * 0.7 * k, y, zt - 0.2 * k)
        b = (sx * 1.3 * k, y + 0.2 * k, zt + 1.4 * k)
        tip = (sx * 1.1 * k, y + 0.5 * k, zt + 2.4 * k)
        line(part, a, b, col, r=0.2 * k + .2)
        line(part, b, tip, col, r=0.16 * k + .2)
        line(part, b, (sx * 2.0 * k, y, zt + 1.9 * k), col, r=0.15 * k + .2)
        line(part, ((a[0] + b[0]) / 2, y + 0.1 * k, (a[2] + b[2]) / 2), (sx * 0.4 * k, y - 0.4 * k, zt + 1.3 * k), col,
             r=0.14 * k + .2)


def _antlers_big(part, k, y, zt, col, tip):
    """Jackalope antlers that read at a glance: a main beam rising up and
    out from the front of the crown (in front of long ears), then three
    tines (front, top, back)."""
    y -= 0.8 * k
    for sx in (-1, 1):
        base = (sx * 0.5 * k, y, zt - 0.3 * k)
        mid = (sx * 1.2 * k, y - 0.2 * k, zt + 0.9 * k)
        top = (sx * 1.9 * k, y - 0.1 * k, zt + 1.9 * k)
        line(part, base, mid, col, r=0.17 * k + .2)
        line(part, mid, top, col, r=0.14 * k + .2)
        line(part, mid, (sx * 1.0 * k, y - 0.9 * k, zt + 1.6 * k), tip, r=0.1 * k + .2)
        line(part, top, (sx * 1.8 * k, y - 0.6 * k, zt + 2.8 * k), tip, r=0.1 * k + .2)
        line(part, top, (sx * 2.7 * k, y + 0.2 * k, zt + 2.5 * k), tip, r=0.1 * k + .2)


def headdress(c, H, col, col2=None):
    """A striped pharaoh headdress: over the head and down to the shoulders."""
    k = H / 10.0
    head = head_of(c)
    stripe = col2 or hexc('#2F5BD6')
    ys = [p[1] for p in head.v]
    zs = [p[2] for p in head.v]
    yf = min(ys)
    zm = min(zs) + (max(zs) - min(zs)) * 0.45
    w = max(1, round(0.4 * k))
    for (x, y, z) in _surface(head):
        if y > yf + 0.9 * k and z >= zm:
            head.put((x, y, z), stripe if (z // w) % 2 else col)
    hood = c.part('headdress', 'static', head.pivot)
    # lappets falling in front of the shoulders
    for sx in (-1, 1):
        x0 = round(sx * 1.6 * k) - (1 if sx < 0 else 0)
        for z in range(round(zm - 2.2 * k), round(zm) + 1):
            for t in range(max(1, round(0.5 * k))):
                hood.put((x0 + sx * t, round(yf + 1.2 * k), z), stripe if (z // w) % 2 else col)
    ball(hood, (0, yf + 0.6 * k, max(zs) - 0.2 * k), (0.3 * k, 0.3 * k, 0.4 * k), col)


def hardhat(c, H, col, col2=None):
    """A hard hat with a glowing lamp on the front."""
    k = H / 10.0
    y, zt = _crown(c)
    hat = c.part('hat', 'static')
    hat.ell((0, y, zt), (1.4 * k, 1.4 * k, 1.0 * k), col, cond=lambda X, Y, Z: Z >= zt - 0.1 * k)
    hat.ell((0, y, zt - 0.1 * k), (1.8 * k, 1.8 * k, 0.25 * k + .2), col)
    lamp = c.part('lamp', 'glow')
    ball(lamp, (0, y - 1.4 * k, zt + 0.4 * k), (0.4 * k, 0.3 * k, 0.4 * k), col2 or hexc('#FFF6B0'))
    for p in lamp.v:
        lamp.v[p] = (lamp.v[p][0], True)


def _pouch(c, H, col, col2, where):
    k = H / 10.0
    part = head_of(c) if where == 'chin' else _find(c, 'body')
    if not part:
        return
    yf = min(p[1] for p in part.v)
    zs = [p[2] for p in part.v]
    if where == 'chin':
        cz, cy = min(zs) + 0.4 * k, yf + 0.6 * k
        r = (1.1 * k, 0.8 * k, 0.9 * k)
    else:
        cz = min(zs) + 0.5 * k
        y0, y1 = _yrange(part)
        cy = (y0 + y1) / 2 + 0.4 * k
        r = (1.0 * k, 1.4 * k, 0.9 * k)
    lamp = c.part('lantern', 'glow')
    lamp.ell((0, cy, cz), r, col, True)
    ribs = col2 or _dark(col, 0.35)
    for p in list(lamp.v):
        if (p[2] - round(cz)) % max(2, round(0.55 * k)) == 0:
            lamp.v[p] = (ribs, False)


def lantern_pouch(c, H, col, col2=None):
    """A glowing paper-lantern throat pouch."""
    _pouch(c, H, col, col2, 'chin')


def lantern_belly(c, H, col, col2=None):
    """A glowing lantern belly."""
    _pouch(c, H, col, col2, 'belly')


def sun_crest(c, H, col, col2=None):
    """A sun disc with rays standing behind the head."""
    k = H / 10.0
    y, zt = _crown(c)
    part = c.part('crest', 'glow')
    cz, yy = zt + 0.3 * k, y + 0.9 * k
    R = 1.5 * k
    for a in range(-int(4 * k) - 1, int(4 * k) + 2):
        for b in range(-int(4 * k) - 1, int(4 * k) + 2):
            d = math.hypot(a + .5, b + .5)
            ang = math.atan2(b + .5, a + .5)
            ray = d <= R + 2.0 * k * max(0, math.cos(ang * 8)) ** 3
            if b + .5 < -0.3 * k:
                continue
            if d <= R:
                colr, g = col, True
            elif ray:
                colr, g = col2 or hexc('#FF7A1A'), True
            else:
                continue
            part.put((a, math.floor(yy), math.floor(cz + b)), colr, g)
            part.put((a, math.floor(yy) + 1, math.floor(cz + b)), colr, g)


def clover(c, H, col, col2=None):
    """A four-leaf clover marking on each flank."""
    k = H / 10.0
    body = _find(c, 'body')
    if not body:
        return
    y0, y1 = _yrange(body)
    zs = [p[2] for p in body.v]
    yc, zc = y0 + (y1 - y0) * 0.65, min(zs) + (max(zs) - min(zs)) * 0.62
    r = 0.6 * k
    for (x, y, z) in _surface(body):
        if abs(x + .5) < 1.2 * k:
            continue
        for dy, dz in ((r, r), (-r, r), (r, -r), (-r, -r)):
            if math.hypot(y + .5 - (yc + dy), z + .5 - (zc + dz)) <= r * 1.05:
                body.put((x, y, z), col)


def ribs(c, H, col, col2=None):
    """Pumpkin ribs: darker grooves running front to back over the body."""
    k = H / 10.0
    body = _find(c, 'body')
    if not body:
        return
    zs = [p[2] for p in body.v]
    zc = (min(zs) + max(zs)) / 2

    def rib(p, cc, g):
        if g:
            return None
        a = math.atan2(p[2] + .5 - zc, p[0] + .5)
        return (col, False) if (a * 5 / math.pi) % 1 < 0.18 else None
    body.paint(rib)


def stripe(c, H, col, col2=None):
    """One stripe from the nose over the head and down the back."""
    k = H / 10.0
    for name in ('head', 'body', 'tail'):
        part = _find(c, name)
        if not part or not part.v:
            continue
        tops = {}
        for (x, y, z) in part.v:
            tops[(x, y)] = max(tops.get((x, y), -1), z)
        for (x, y), z in tops.items():
            if abs(x + .5) < 0.45 * k + .5:
                for d in range(max(1, round(0.3 * k))):
                    if (x, y, z - d) in part.v:
                        part.put((x, y, z - d), col)


def gloss(c, H, col, col2=None):
    """Shiny candy: a light glint on the upper front of every round part."""
    k = H / 10.0
    for part in c.parts:
        if part.name == 'eyes' or not part.v:
            continue
        zs = [p[2] for p in part.v]
        ys = [p[1] for p in part.v]
        zt, yf = max(zs), min(ys)
        for p in _surface(part):
            if p[2] >= zt - 0.5 * k and p[1] <= yf + (max(ys) - yf) * 0.45 and 0.3 * k < abs(p[0] + .5) < 1.2 * k:
                part.put(p, col)


def paper_folds(c, H, col, col2=None):
    """Origami: crisp diagonal fold lines in a slightly darker paper."""
    k = H / 10.0
    s = max(3, round(1.6 * k))
    for part in c.parts:
        if part.name == 'eyes':
            continue
        part.paint(lambda p, cc, g: (col, False) if not g and cc not in (INK,) and
                   ((p[1] + p[2]) % s == 0 or (abs(p[0] + .5) + p[2]) % s == 0) else None)


def stained_glass(c, H, col, col2=None):
    """Wings as stained glass: glowing panes of colour in dark lead lines."""
    k = H / 10.0
    panes = [col, col2 or hexc('#7FD4FF'), hexc('#FF6FA8'), hexc('#9BF27A'), hexc('#FFE14D')]
    s = max(2, round(0.8 * k))
    for name in ('wingL', 'wingR'):
        part = _find(c, name)
        if not part:
            continue

        def pane(p, cc, g):
            cell = (abs(p[0] + .5) // s, p[1] // s, p[2] // s)
            if abs(p[0] + .5) % s < 0.6 or p[1] % s == 0:
                return (hexc('#5A3A1A'), False)
            return (panes[_hash(*cell, 7) % len(panes)], True)
        part.paint(pane)


def tipped_wings(c, H, col, col2=None):
    """Wings fading to glowing col at their outer ends."""
    for name in ('wingL', 'wingR'):
        part = _find(c, name)
        if not part or not part.v:
            continue
        xs = [abs(p[0] + .5) for p in part.v]
        x0, x1 = min(xs), max(xs)
        part.paint(lambda p, cc, g: (_mix(cc, col, min(1, (abs(p[0] + .5) - x0) / max(1, x1 - x0) * 1.4)),
                                     abs(p[0] + .5) > x0 + (x1 - x0) * 0.55))


def feather_wings(c, H, col, col2=None, span=3.2, membrane=False):
    """Big layered wings on the back (or bat/dragon wings with membrane);
    they flap (wingL, wingR). Replaces any wings the plan drew."""
    k = H / 10.0
    body = _find(c, 'body')
    if not body:
        return
    y0, y1 = _yrange(body)
    zt = max(p[2] for p in body.v)
    ry = y0 + (y1 - y0) * 0.35
    rz = zt - 0.5 * k
    tip = col2 or _light(col, 0.4)
    for sx, name in ((-1, 'wingL'), (1, 'wingR')):
        w = c.part(name, name, (sx * 0.9 * k, ry, rz))
        w.v = {}
        L = span * k
        if membrane:
            bones = [(1.0, 0.9, -0.2), (0.85, 1.0, 0.45), (0.55, 0.9, 0.9)]
            shoulder = (sx * 0.8 * k, ry, rz)
            for (fl, up, back) in bones:
                end = (sx * (0.8 * k + L * fl), ry + back * k, rz + up * k)
                line(w, shoulder, end, tip, r=0.2 * k + .2)
            for i in range(int(L) + 1):
                t = i / max(1, L)
                x = sx * (0.8 * k + i)
                top = rz + 0.9 * k * min(1, t * 1.6)
                scallop = 0.5 * k * abs(math.sin(t * math.pi * 3))
                bot = rz - 0.6 * k + t * 1.0 * k + scallop
                for z in range(math.floor(min(bot, top)), math.floor(top) + 1):
                    for yy in (math.floor(ry), math.floor(ry) + 1):
                        w.put((math.floor(x) if sx > 0 else math.floor(x) - 1, yy, z), col)
        else:
            for i in range(int(L) + 1):
                t = i / max(1, L)
                x = sx * (0.8 * k + i)
                top = rz + 1.4 * k * (1 - (t - 0.35) ** 2 * 1.4) + 0.3 * k
                bot = rz - 0.5 * k + t * 1.2 * k
                for z in range(math.floor(min(bot, top)), math.floor(top) + 1):
                    feather = (z - math.floor(bot)) % max(2, round(0.6 * k)) == 0
                    colr = tip if t > 0.62 else (_dark(col, 0.12) if feather else col)
                    for yy in (math.floor(ry), math.floor(ry) + 1):
                        w.put((math.floor(x) if sx > 0 else math.floor(x) - 1, yy, z), colr)
                # long flight feathers hanging at the back edge
                if i % max(2, round(0.6 * k)) == 0 and t > 0.2:
                    for d in range(round(0.7 * k)):
                        w.put((math.floor(x) if sx > 0 else math.floor(x) - 1, math.floor(ry) + 2 + d // 2,
                               math.floor(bot) - d // 2), tip if t > 0.5 else col)


def raised_wings(c, H, col, col2=None, span=3.6, angle=60, tip_glow=False, a=None):
    """Big feathered wings held half-raised (a griffin's, a pegasus's): they
    rise from the shoulders up and out, with rows of feathers, long flight
    feathers along the trailing edge and pale tips (col2). They flap
    (wingL, wingR). Replaces any wings the plan drew."""
    k = H / 10.0
    body = _find(c, 'body')
    if not body:
        return
    # roster settings: "span", "angle" (degrees above level) and "drop"
    # (how far below the top of the body the shoulders sit, in tenths of H)
    a = a or {}
    span, angle = float(a.get('span', span)), float(a.get('angle', angle))
    y0, y1 = _yrange(body)
    zt = max(p[2] for p in body.v)
    ry = y0 + (y1 - y0) * 0.33
    rz = zt - (0.3 + float(a.get('drop', 0.0))) * k
    tip = col2 or _light(col, 0.45)
    fine = getattr(c, 'fine', False)  # the in-game box build skips feather bands
    ang = math.radians(angle)
    d = (math.cos(ang), math.sin(ang))      # along the arm, up and out
    n = (math.sin(ang), -math.cos(ang))     # across the wing, out and down
    L = span * k
    rows = max(2, round(0.55 * k))
    for sx, name in ((-1, 'wingL'), (1, 'wingR')):
        w = c.part(name, name, (sx * 0.9 * k, ry, rz))
        w.v = {}
        x0 = 0.7 * k
        steps = int(L * 3) + 1
        for i in range(steps):
            u = i / (steps - 1)
            chord = (0.8 + 1.6 * math.sin(min(1.0, u * 1.15) * math.pi * 0.62)) * k
            if u > 0.8:
                chord *= 1.0 - (u - 0.8) * 2.2
            for j in range(int(chord * 3) + 1):
                v = j / 3.0
                fx = x0 + u * L * d[0] + v * n[0]
                fz = rz + u * L * d[1] + v * n[1]
                vv = v / max(1.0, chord)
                # feathers: darker bands across the wing, then pale tips
                if u > 0.82 or vv > 0.88:
                    colr, g = tip, tip_glow and u > 0.86
                elif fine and math.floor(v) % rows == 0 and vv > 0.3:  # bands only where voxels are fine enough
                    colr, g = _dark(col, 0.14), False
                else:
                    colr, g = col, False
                x = math.floor(fx)
                X = x if sx > 0 else -x - 1
                yb = math.floor(ry + vv * 0.6 * k)
                for yy in (yb, yb + 1):
                    w.v[(X, yy, math.floor(fz))] = (colr, g)
        # long flight feathers hanging from the trailing edge
        for i in range(1, 6):
            u = 0.25 + 0.13 * i
            chord = (0.8 + 1.6 * math.sin(min(1.0, u * 1.15) * math.pi * 0.62)) * k
            if u > 0.8:
                chord *= 1.0 - (u - 0.8) * 2.2
            base = (x0 + u * L * d[0] + chord * n[0], rz + u * L * d[1] + chord * n[1])
            for t in range(round(0.9 * k)):
                fx, fz = base[0] + t * n[0] * 0.8, base[1] + t * n[1] * 0.9
                x = math.floor(fx)
                X = x if sx > 0 else -x - 1
                yb = math.floor(ry + 0.6 * k)
                for yy in (yb, yb + 1):
                    w.v[(X, yy, math.floor(fz))] = (tip, False)


def dragon_wings(c, H, col, col2=None):
    feather_wings(c, H, col, col2, span=3.0, membrane=True)


def bat_wings(c, H, col, col2=None):
    feather_wings(c, H, col, col2, span=2.6, membrane=True)


def small_wings(c, H, col, col2=None):
    feather_wings(c, H, col, col2, span=2.2)


def nightcap(c, H, col, col2=None):
    """A floppy sleeping cap with a pom-pom."""
    k = H / 10.0
    y, zt = _crown(c)
    hat = c.part('hat', 'static')
    for i in range(round(2.4 * k)):
        t = i / (2.4 * k)
        r = 1.3 * k * (1 - t) + 0.3
        hat.ell((t * 0.9 * k, y + t * 1.6 * k, zt + 0.1 * k + i * 0.6), (r, r, 0.5), col)
    ball(hat, (0.9 * k, y + 1.7 * k, zt + 1.5 * k), (0.45 * k, 0.45 * k, 0.45 * k), col2 or WHITE)


def flame_crest(c, H, col, col2=None):
    """A crest of three flames on the head."""
    k = H / 10.0
    y, zt = _crown(c)
    part = c.part('crest', 'glow')
    for dy, h, side in ((-0.6, 2.0, 0), (0.4, 2.8, 0), (1.3, 2.0, 0)):
        tongue(part, (0, y + dy * k, zt - 0.5 * k), h * k, 0.75 * k, col, col2 or hexc('#FFE14D'), lean=0.4)


def ear_icicles(c, H, col, col2=None):
    """An icicle on each ear tip."""
    k = H / 10.0
    t = _ear_tips(c)
    if not t:
        return
    ears = c.part('ears')
    for sx in (-1, 1):
        x = t[0] if sx > 0 else -t[0]
        shard(ears, (x, t[1], t[2] - 0.8 * k), (0.15 * sx, 0.1, 1), 2.4 * k, 0.6 * k, col, col2 or WHITE)


def spikes(c, H, col, col2=None):
    """Thorny spikes all over the back, pointing outward, tips in col2."""
    k = H / 10.0
    body = _find(c, 'body')
    if not body:
        return
    zs = [p[2] for p in body.v]
    zm = min(zs) + (max(zs) - min(zs)) * 0.5
    ys = [p[1] for p in body.v]
    cy = (min(ys) + max(ys)) / 2
    part = c.part('spines', 'static')
    step = max(3, round(1.7 * k))
    for (x, y, z) in _surface(body):
        if z < zm or x < 0 or x % step or y % step or (z + x) % 2:
            continue
        d = _norm((x + .5, (y - cy) * 0.6 + 0.4 * k, z - zm + 0.5 * k))
        tip = col2 or _dark(col, 0.3)
        for sx in (1, -1):
            b = (x + .5 if sx > 0 else -x - .5, y + .5, z + .5)
            dd = (d[0] * sx, d[1], d[2])
            shard(part, b, dd, 1.3 * k, 0.4 * k, col, tip, tip_glow=False)


def paper_wings(c, H, col, col2=None):
    """Flat folded paper wings (an origami crane), a pointed paper tail and
    a long pointed beak."""
    k = H / 10.0
    body = _find(c, 'body')
    y0, y1 = _yrange(body)
    zt = max(p[2] for p in body.v)
    ry, rz = y0 + (y1 - y0) * 0.45, zt - 0.8 * k
    fold = col2 or _dark(col, 0.12)
    for sx, name in ((-1, 'wingL'), (1, 'wingR')):
        w = c.part(name, name, (sx * 1.0 * k, ry, rz))
        w.v = {}
        L = round(4.2 * k)
        for i in range(L):
            t = i / L
            x = sx * (1.0 * k + i)
            xi = math.floor(x) if sx > 0 else math.floor(x) - 1
            # a triangle: wide at the body, rising to a point
            half = 1.6 * k * (1 - t)
            yc = ry + t * 0.8 * k
            for dy in range(-round(half), round(half) + 1):
                z = rz + t * 2.6 * k
                w.put((xi, math.floor(yc + dy), math.floor(z)), fold if dy == 0 else col)
    tl = c.part('tail', 'tail', (0, y1, zt - 1.5 * k))
    tl.v = {}
    for i in range(round(3.0 * k)):
        t = i / (3.0 * k)
        w = max(0, round(0.9 * k * (1 - t)))
        for dx in range(-w, w):
            tl.put((dx, math.floor(y1 - 0.8 * k + i), math.floor(zt - 1.6 * k + t * 2.2 * k)), col)
    head = head_of(c)
    yf = min(p[1] for p in head.v)
    zs = [p[2] for p in head.v if p[1] <= yf + 1]
    zb = (min(zs) + max(zs)) / 2
    for i in range(round(1.6 * k)):
        w = max(0, round(0.5 * k * (1 - i / (1.6 * k))))
        for dx in range(-w, max(1, w)):
            head.put((dx, yf - i, math.floor(zb)), fold)


def _head_front(c):
    head = head_of(c)
    yf = min(p[1] for p in head.v)
    eyes = _find(c, 'eyes')
    ez = min(p[2] for p in eyes.v) if eyes and eyes.v else None
    zs = [p[2] for p in head.v if p[1] <= yf + 2]
    return head, yf, ez, min(zs), max(zs)


def long_muzzle(c, H, col, col2=None):
    """A longer muzzle (a pony's, a deer's, a hound's, a moose's) below the
    eyes, with a dark nose: the face stops reading as a round cub's."""
    k = H / 10.0
    head, yf, ez, z0, z1 = _head_front(c)
    top = (ez - 0.4 * k) if ez is not None else (z0 + z1) / 2
    zc = top - 0.75 * k
    head.ell((0, yf - 0.4 * k, zc), (1.15 * k, 1.5 * k, 0.9 * k), col)
    head.ell((0, yf - 1.3 * k, zc - 0.1 * k), (1.0 * k, 0.9 * k, 0.8 * k), col)
    nose = col2 or _dark(col, 0.55)
    yn = min(p[1] for p in head.v if abs(p[2] - zc) <= 1)
    for x in range(-max(1, round(0.5 * k)), max(1, round(0.5 * k))):
        for z in range(round(zc), round(zc + 0.5 * k) + 1):
            if (x, yn, z) in head.v:
                head.put((x, yn, z), nose)
            elif (x, yn + 1, z) in head.v:
                head.put((x, yn + 1, z), nose)


def long_legs(c, H, col, col2=None, a=None):
    """Longer legs (a foal's, a stag's, a wolf's): the whole creature stands
    taller on its feet. Every part and pivot moves up and each foot column is
    stretched, keeping the foot itself (a glowing paw stays a paw). Put it
    first in the accessories, before anything placed by height. "amount"
    sets the extra height in tenths of the creature's height (default 0.7)."""
    k = H / 10.0
    d = max(1, round(float((a or {}).get('amount', 0.7)) * k))
    body = _find(c, 'body')
    feet = {(x, y): v for (x, y, z), v in body.v.items() if z == 0}
    shin = {(x, y): body.v.get((x, y, 1), v) for (x, y), v in feet.items()}
    for part in c.parts:
        part.v = {(x, y, z + d): v for (x, y, z), v in part.v.items()}
        px, py, pz = part.pivot
        part.pivot = (px, py, pz + d)
    for (x, y), v in feet.items():
        body.v[(x, y, 0)] = v
        for z in range(1, d + 1):
            body.v[(x, y, z)] = shin[(x, y)] if not shin[(x, y)][1] else (col, False)


def horse_head(c, H, col, col2=None, a=None):
    """A horse's (or a deer's) head: a long, deep muzzle that reaches forward
    and down from below the eyes, flat-fronted with two nostrils and a mouth
    line. col: the muzzle, col2: nostrils. With "nose": "wolf" it is a
    canine's instead: narrower and tapering to a dark nose on the tip."""
    k = H / 10.0
    wolf = (a or {}).get('nose') == 'wolf'
    head, yf, ez, z0, z1 = _head_front(c)
    top = (ez - 0.3 * k) if ez is not None else (z0 + z1) / 2
    zc = top - 1.0 * k
    face = head.v[next(iter(head.v))][0]
    # the bridge of the nose, then the muzzle box, deeper toward the tip
    # a muzzle as wide as the lower face where it leaves the head, tapering
    # forward and a little down to a broad nose: the whole head reads long
    hw = max(p[0] for p in head.v if abs(p[2] - zc) <= 1) + 0.5
    steps = 6
    for i in range(steps):
        t = i / (steps - 1)
        y = yf + 0.6 * k - t * 2.4 * k
        z = zc + 0.2 * k - t * 0.35 * k
        tipw = 0.55 if wolf else 0.85
        rx = (hw * 0.85) * (1 - t) + tipw * k * t
        rz = 1.15 * k * (1 - t) + (0.6 if wolf else 0.8) * k * t
        head.ell((0, y, z), (rx, 0.55 * k, rz), face if t < 0.45 else col)
    # a flat bridge from the forehead down the nose
    head.ell((0, yf - 0.9 * k, zc + 0.75 * k), (0.7 * k, 1.5 * k, 0.45 * k), face)
    yn = min(p[1] for p in head.v)
    nose = col2 or _dark(col, 0.5)
    if wolf:  # a dark nose capping the tip of the muzzle
        tipz = max(p[2] for p in head.v if p[1] <= yn + 1)
        head.ell((0, yn + 0.4 * k, tipz - 0.3 * k), (0.45 * k, 0.45 * k, 0.4 * k), nose)
        return
    zn = round(zc + 0.15 * k)
    for sx in (-1, 1):
        x = round(sx * 0.55 * k) - (1 if sx < 0 else 0)
        for z in (zn, zn - 1) if k >= 1.6 else (zn,):
            for y in range(yn, yn + 3):
                if (x, y, z) in head.v:
                    head.put((x, y, z), nose)
                    break
    # mouth line on the front-bottom of the muzzle
    zm = round(zc - 0.75 * k)
    for x in range(-max(1, round(0.4 * k)), max(1, round(0.4 * k))):
        for y in range(yn, yn + 4):
            if (x, y, zm) in head.v:
                head.put((x, y, zm), _dark(col, 0.35))
                break


def hedgehog_quills(c, H, col, col2=None, a=None):
    """A hedgehog's coat: the back, flanks, crown and back of the head turn
    the quill colour (col) and bristle with short quills leaning back (tips
    col2); the face stays bare and gets a short pointed snout with a dark
    nose, and the ears shrink to little nubs at the edge of the coat."""
    k = H / 10.0
    body, head = _find(c, 'body'), head_of(c)
    if not body:
        return
    tip = col2 or _light(col, 0.4)
    quill = c.part('spines', 'static')
    head0, yf, ez, z0, z1 = _head_front(c)
    face = (a or {}).get('snout')
    face = hexc(face) if isinstance(face, str) else head.v[min(head.v, key=lambda q: (q[1], -q[2]))][0]

    def paint(part, keep):
        """Repaint the part's coat voxels; return the outer ones with a normal."""
        xs = [p[0] for p in part.v]
        ys = [p[1] for p in part.v]
        zs = [p[2] for p in part.v]
        cx, cy = (min(xs) + max(xs) + 1) / 2, (min(ys) + max(ys) + 1) / 2
        cz = min(zs) + (max(zs) - min(zs)) * 0.3
        out = []
        surf = set(_surface(part))
        for q in list(part.v):
            if keep(q):
                continue
            part.put(q, col)
            if q in surf and q[0] >= 0:
                out.append((q, _norm((q[0] + .5 - cx, (q[1] + .5 - cy) * 0.8, q[2] + .5 - cz))))
        return out

    bz = [p[2] for p in body.v]
    bcut = min(bz) + (max(bz) - min(bz)) * 0.4
    by0 = min(p[1] for p in body.v)
    outs = paint(body, lambda q: q[2] < bcut or (q[1] < by0 + 1.2 * k and q[2] < bcut + 1.5 * k))
    if head is not body:
        # the face is bare: everything in front of a line from the brow
        # down to behind the cheeks keeps its colour
        hz = [p[2] for p in head.v]
        eyes = _find(c, 'eyes')
        brow = (max(p[2] for p in eyes.v) + 1.5) if eyes and eyes.v else min(hz) + (max(hz) - min(hz)) * 0.7
        cheek = min(hz) + 0.3 * (max(hz) - min(hz))
        ears0 = _find(c, 'ears')
        if ears0 and ears0.v:
            # the coat starts behind the ears: the whole face and crown in
            # front of them stays bare, so it never wraps the face like a hood
            eyb = sum(p[1] for p in ears0.v) / len(ears0.v) + 0.3 * k
            outs += paint(head, lambda q: q[2] < cheek or q[1] < eyb)
        else:
            outs += paint(head, lambda q: q[2] < cheek or (q[2] < brow and q[1] < yf + 2.0 * k))
    # quills: short chunky spikes (2x2 at the root, one voxel at the pale
    # tip) on a staggered grid, leaning up and back, so the coat's outline
    # bristles all over
    step = max(3, round(1.1 * k / float((a or {}).get('density', 1.0))))  # "density": quills per area
    sharp = (a or {}).get('thorns')  # longer, thinner thorns swept back
    L = max(3, round((1.6 if sharp else 1.3) * k))
    for (x, y, z), n in outs:
        if (x + (z // step) % 2 * (step // 2 or 1)) % step or (y + z) % step:
            continue
        d = _norm((n[0], n[1] + (1.0 if sharp else 0.7), n[2] + (0.7 if sharp else 0.5)))
        for i in range(1, L + 1):
            px, py, pz = x + .5 + d[0] * i, y + .5 + d[1] * i, z + .5 + d[2] * i
            cc = tip if i >= L - (1 if sharp else 0) else col
            w = 1 if i <= (L // 3 if sharp else L // 2) else 0
            for ox in range(w + 1):
                for oz in range(w + 1):
                    q = (math.floor(px) + ox, math.floor(py), math.floor(pz) + oz)
                    quill.put(q, cc)
                    quill.put((_mx(q[0]), q[1], q[2]), cc)
    # little ears at the front edge of the coat
    ears = _find(c, 'ears')
    if ears:
        top = [p for p in ears.v]
        ex = max(abs(p[0] + .5) for p in top)
        ey = min(p[1] for p in top) + 0.3 * k
        ezz = min(p[2] for p in top) + 0.2 * k
        ears.v = {}
        for sx in (-1, 1):
            ears.ell((sx * (ex - 0.2 * k) - .5, ey, ezz), (0.45 * k, 0.3 * k, 0.45 * k), face)
    # a short pointed snout from below the eyes, with a dark nose
    zc = (ez - 0.6 * k) if ez is not None else (z0 + z1) / 2 - 0.4 * k
    for i in range(5):
        t = i / 4
        head.ell((0, yf + 0.3 * k - t * 1.5 * k, zc - t * 0.25 * k),
                 ((0.75 - 0.4 * t) * k, 0.4 * k, (0.6 - 0.3 * t) * k), face)
    yn = min(p[1] for p in head.v)
    tz = max(p[2] for p in head.v if p[1] <= yn + 1)
    head.ell((0, yn + 0.3 * k, tz - 0.2 * k), (0.32 * k, 0.35 * k, 0.3 * k), hexc('#2A1E1A'))


def raptor_pose(c, H, col=None, col2=None, a=None):
    """A bird of prey's stance: the body and head lean forward (sheared
    about the hips by "lean", default 0.35), the cheeks lose their blush,
    and a heavy brow ridge (col, default a dark shade of the head) juts
    out over each eye for the hawk's glare. Put it before the wings."""
    k = H / 10.0
    body = _find(c, 'body')
    if not body:
        return
    t = float((a or {}).get('lean', 0.35))
    z0 = min(p[2] for p in body.v) + 0.4 * k
    for p in c.parts:
        if p.name.startswith('leg'):
            continue
        p.v = {(x, y - round(max(0, z - z0) * t), z): v for (x, y, z), v in p.v.items()}
        px, py, pz = p.pivot
        p.pivot = (px, py - max(0, pz - z0) * t, pz)
    head = head_of(c)
    hcol = head.v[max(head.v, key=lambda q: q[2])][0]
    for q, (cc, g) in list(head.v.items()):
        if cc == hexc('#FF9EB5') or (cc[0] > 0.9 and cc[1] < 0.7 and cc[2] > 0.6 and cc[2] < 0.8):
            head.v[q] = (hcol, g)
    eyes = _find(c, 'eyes')
    if not eyes or not eyes.v:
        return
    brow = hexc(col) if isinstance(col, str) else (col or _dark(hcol, 0.35))
    zt = max(p[2] for p in eyes.v)
    for sx in (1, -1):
        side = [p for p in eyes.v if (p[0] >= 0) == (sx > 0)]
        if not side:
            continue
        xs = [p[0] for p in side]
        yf = min(p[1] for p in side)
        # a slab over the eye, sloping down toward the beak, one voxel proud
        for x in range(min(xs) - 1, max(xs) + 2):
            inner = (x <= min(xs)) if sx > 0 else (x >= max(xs))
            z = zt + 1 - (1 if inner else 0)
            for y in range(yf - 1, yf + 2):
                head.put((x, y, z), brow)
                head.put((x, y, z + 1), brow) if not inner else None


def storm_crest(c, H, col, col2=None):
    """Three crest feathers swept back from the back of the head, the middle
    one a lightning zigzag; they glow (col) with pale tips (col2). Lying
    back, they read as a crest, not a candle on the head."""
    k = H / 10.0
    head = head_of(c)
    part = c.part('crest', 'glow')
    zt = max(p[2] for p in head.v)
    yb = max(p[1] for p in head.v if p[2] >= zt - 1.2 * k)
    tip = col2 or _light(col, 0.5)
    fine = getattr(c, 'fine', False)
    base = (yb - 0.8 * k, zt - 0.4 * k)
    for x, L, rise in ((-0.9 * k, 2.0 * k, 0.5 * k), (0.9 * k, 2.0 * k, 0.5 * k)):
        a_ = (x, base[0], base[1] - 0.3 * k)
        b_ = (x * 1.3, base[0] + L, base[1] + rise)
        line(part, a_, b_, col, r=0.3 * k, glow=True)
        if fine:  # the in-game box build skips the pale tips
            part.put(tuple(math.floor(v) for v in b_), tip, True)
    # the middle feather: a zigzag lying back and up
    pts = [(base[0], base[1]), (base[0] + 0.9 * k, base[1] + 1.0 * k),
           (base[0] + 1.3 * k, base[1] + 0.5 * k), (base[0] + 2.5 * k, base[1] + 1.6 * k)]
    for a_, b_ in zip(pts, pts[1:]):
        for x in (-1, 0):
            line(part, (x + .5, a_[0], a_[1]), (x + .5, b_[0], b_[1]), col, r=0.32 * k, glow=True)
    if fine:
        for x in (-1, 0):
            part.put((x, math.floor(pts[-1][0]), math.floor(pts[-1][1])), tip, True)


def _hexa(col, default):
    if col is None:
        return default
    return hexc(col) if isinstance(col, str) else col


def puffin_face(c, H, col, col2=None):
    """A puffin's face: the front of the head turns white below a dark cap,
    and the beak becomes a big, tall triangle (col, the bill; col2, a pale
    band at its base), so it can't be read as a penguin."""
    k = H / 10.0
    head, eyes = head_of(c), _find(c, 'eyes')
    if not eyes or not eyes.v:
        return
    hz = [p[2] for p in head.v]
    cap = max(p[2] for p in eyes.v) + 0.6 * k
    ylo = min(p[1] for p in head.v)
    yc = (ylo + max(p[1] for p in head.v)) / 2
    white = hexc('#F7F9FC')
    bill = _hexa(col, hexc('#FF8A3D'))
    band = _hexa(col2, hexc('#C9D3E0'))
    # drop the old beak (anything in front of the face line that is not white/body)
    face_y = min(p[1] for p in head.v if abs(p[0] + .5) > 1.2 * k) if any(abs(p[0] + .5) > 1.2 * k for p in head.v) else ylo
    for q in [q for q in head.v if q[1] < face_y]:
        del head.v[q]
    for q, (cc, g) in list(head.v.items()):
        if q[1] < yc and q[2] < cap and q[2] > min(hz) + 0.2 * k:
            head.v[q] = (white, g)
    ez = min(p[2] for p in eyes.v)
    zc = ez - 0.7 * k
    Lb = max(3, round(1.4 * k))
    for i in range(Lb):
        t = i / Lb
        hh = 1.3 * k * (1 - t) + 0.4
        ww = 0.75 * k * (1 - 0.5 * t) + 0.3
        y = face_y - 1 - i
        cc = band if i < max(1, round(0.25 * Lb)) else bill
        for x in range(-math.ceil(ww), math.ceil(ww)):
            if abs(x + .5) > ww:
                continue
            for z in range(math.floor(zc - hh * 0.55), math.ceil(zc + hh * 0.6)):
                head.put((x, y, z), cc)


def monkey_face(c, H, col, col2=None):
    """A monkey's head: big round ears out at the sides of the head at eye
    height (inner col2), and a pale heart-shaped face (col2) round the eyes
    and over a small muzzle, so it can't be read as a bear cub."""
    k = H / 10.0
    head, eyes = head_of(c), _find(c, 'eyes')
    if not eyes or not eyes.v:
        return
    pale = _hexa(col2, hexc('#E8D8B8'))
    fur = _hexa(col, head.v[max(head.v, key=lambda q: q[2])][0])
    ez0, ez1 = min(p[2] for p in eyes.v), max(p[2] for p in eyes.v)
    ezc = (ez0 + ez1) / 2
    yf = min(p[1] for p in head.v)
    exs = [p[0] for p in eyes.v if p[0] >= 0]
    ex = (min(exs) + max(exs) + 1) / 2 if exs else 1.0 * k
    # the face: two circles round the eyes and a muzzle oval below
    for q, (cc, g) in list(head.v.items()):
        x, y, z = q
        if y > yf + 1.4 * k:
            continue
        ax = abs(x + .5)
        in_eye = math.hypot(ax - ex, (z + .5 - ezc) * 0.9) <= 1.05 * k
        in_muz = ((ax / (1.25 * k)) ** 2 + ((z + .5 - (ezc - 1.3 * k)) / (0.85 * k)) ** 2) <= 1
        if in_eye or in_muz:
            head.v[q] = (pale, g)
    head.ell((0, yf + 0.2 * k, ezc - 1.4 * k), (0.95 * k, 0.5 * k, 0.6 * k), pale)
    # nostrils
    yn = min(p[1] for p in head.v if abs(p[2] - (ezc - 1.2 * k)) <= 1)
    for sx in (-1, 1):
        x = round(sx * 0.3 * k) - (1 if sx < 0 else 0)
        head.put((x, yn, round(ezc - 1.2 * k)), _dark(pale, 0.5))
    ears = _find(c, 'ears')
    if ears:
        ears.v = {}
    else:
        ears = c.part('ears', 'static')
    hw = max(p[0] for p in head.v if abs(p[2] - ezc) <= 1) + 1
    yc = yf + 1.6 * k
    for sx in (-1, 1):
        x0 = hw if sx > 0 else -hw - 1
        for dx in range(max(1, round(0.5 * k))):
            x = x0 + sx * dx
            for y in range(math.floor(yc - 1.0 * k), math.ceil(yc + 1.0 * k)):
                for z in range(math.floor(ezc - 0.8 * k), math.ceil(ezc + 1.3 * k)):
                    if math.hypot(y + .5 - yc, z + .5 - (ezc + 0.25 * k)) <= 1.0 * k:
                        inner = dx == 0 and math.hypot(y + .5 - yc, z + .5 - (ezc + 0.25 * k)) <= 0.6 * k
                        ears.put((x, y, z), fur)
                        if inner and dx == max(1, round(0.5 * k)) - 1:
                            pass
        # the pale inner ear faces forward-out: paint the front half of the outer layer
        xo = x0 + sx * (max(1, round(0.5 * k)) - 1)
        for (x, y, z) in list(ears.v):
            if x == xo and math.hypot(y + .5 - yc, z + .5 - (ezc + 0.25 * k)) <= 0.6 * k:
                ears.put((x, y, z), pale)


def _tri(part, a, b, cc, col, crease=None, crease_col=None, glow=False):
    """A flat triangle a-b-cc, one voxel thick, filled by dense sampling. An
    optional crease runs from `crease` (a point on the triangle) to cc."""
    n = max(4, int(max(abs(a[i] - cc[i]) + abs(b[i] - cc[i]) for i in range(3)) * 2.5))
    for i in range(n + 1):
        for j in range(n + 1 - i):
            u, w = i / n, j / n
            p = tuple(a[d] + (b[d] - a[d]) * u + (cc[d] - a[d]) * w for d in range(3))
            part.put(tuple(math.floor(v) for v in p), col, glow)
    if crease is not None:
        line(part, crease, cc, crease_col or col, glow=True)


def origami_crane(c, H, col, col2=None, a=None):
    """A folded paper crane, the classic silhouette: a diamond body, a long
    thin neck rising forward to a small folded head, a thin pointed tail
    rising behind, and two flat triangular wings raised in a V, each on its
    own side. Paper in col (top faces) and col2 (undersides, default a
    shade darker), with glowing crease lines ("crease", default a pale
    tint). Replaces the plan's body, head, tail, wings and legs."""
    k = H / 10.0
    a = a or {}
    under = col2 or _dark(col, 0.15)
    cr = _hexa(a.get('crease'), _light(col, 0.6))
    for p in c.parts:
        if p.name in ('body', 'head', 'eyes', 'tail', 'wingL', 'wingR', 'beak', 'crest', 'legL', 'legR'):
            p.v = {}
    body = c.part('body')
    zc, yc = 2.4 * k, 0.6 * k
    rx, ry, rt, rb = 1.8 * k, 2.9 * k, 2.0 * k, 0.8 * k
    soft = _light(col, 0.35)  # body creases: a lighter fold, not a glow
    for x in range(0, math.ceil(rx) + 1):
        for y in range(math.floor(yc - ry) - 1, math.ceil(yc + ry) + 2):
            for z in range(math.floor(zc - rb) - 1, math.ceil(zc + rt) + 2):
                X, Y, Z = x + .5, y + .5 - yc, z + .5 - zc
                r = rt if Z >= 0 else rb
                f = X / rx + abs(Y) / ry + abs(Z) / r
                if f > 1:
                    continue
                # creases: the top ridge, the waist line and the two diagonals
                ridge = x == 0 and Z >= 0
                waist = abs(Z) < 0.5
                diag = Z >= 0 and abs(abs(Y) / ry - X / rx) < 0.12 and f > 0.75
                surf = f > 1 - 1.2 / min(rx, ry, r)
                if surf and (ridge or (waist and f > 0.6) or diag):
                    _put2(body, x, y, z, soft)
                else:
                    _put2(body, x, y, z, col if Z >= 0 else under)
    yf, yb = math.floor(yc - ry), math.ceil(yc + ry)
    # the neck: a thin folded strip from the front point up and forward,
    # in the head part so it bobs with the head
    head = c.part('head', 'head', (0, yf + 0.5, zc))
    head.pivot = (0, yf + 0.5, zc)
    top = (yf - 1.6 * k, zc + 4.2 * k)
    n = max(4, round(4.6 * k))
    for i in range(n + 1):
        t = i / n
        y = yf + 0.5 + (top[0] - yf - 0.5) * t
        z = zc + (top[1] - zc) * t
        d = max(1, round((0.7 - 0.35 * t) * k))
        for dy in range(d):
            _put2(head, 0, math.floor(y) + dy, math.floor(z), col if dy else soft)
    # the head: a small fold bent forward and down, with a pointed tip
    hy, hz = math.floor(top[0]), math.floor(top[1])
    hl = max(3, round(1.3 * k))
    for i in range(hl):
        w = 1 if i < hl - 1 else 0
        for x in range(0, w + 1):
            _put2(head, x, hy - i, hz - i // 2, col)
            _put2(head, x, hy - i, hz + 1 - i // 2, col)
    _put2(head, 0, hy + 1, hz + 1, col)
    eyes = c.part('eyes', 'blink')
    eyes.pivot = (0, hy - 0.5, hz + 1.5)
    _put2(eyes, 2, hy - 1, hz + 1, INK)
    # the tail: the same thin strip rising behind
    tl = c.part('tail', 'tail', (0, yb - 0.5, zc))
    tl.pivot = (0, yb - 0.5, zc)
    tt = (yb + 1.8 * k, zc + 4.0 * k)
    n = max(4, round(4.4 * k))
    for i in range(n + 1):
        t = i / n
        y = yb - 0.5 + (tt[0] - yb + 0.5) * t
        z = zc + (tt[1] - zc) * t
        d = max(1, round((0.8 - 0.55 * t) * k))
        for dy in range(d):
            _put2(tl, 0, math.floor(y) - dy, math.floor(z), col if dy else soft)
    # the wings: flat triangles from the back ridge, raised in a V, each on
    # its own side; a glowing crease runs from the root to the tip
    zr = zc + rt * 0.35
    for sx, name in ((1, 'wingR'), (-1, 'wingL')):
        w = c.part(name, name, (sx * 0.5 * k, yc, zr))
        w.pivot = (sx * 0.5 * k, yc, zr)
        x0 = 0.45 * k if sx > 0 else -0.45 * k
        tip = (sx * 4.6 * k, yc + 1.0 * k, zr + 3.0 * k)
        A = (x0, yc - 1.7 * k, zr)
        B = (x0, yc + 1.9 * k, zr)
        _tri(w, A, B, tip, col, crease=(x0, yc + 0.1 * k, zr), crease_col=cr)
        if sx < 0:  # keep the two wings exact mirrors
            w.v = {}
            for (x, y, z), v in c.part('wingR').v.items():
                w.v[(_mx(x), y, z)] = v
        w.v = {q: v for q, v in w.v.items() if (q[0] >= 0) == (sx > 0)}
    # thin legs tucked under the body
    zl = math.floor(zc - rb * 0.5)
    for sx, name in ((1, 'legR'), (-1, 'legL')):
        lg = c.part(name, name, (sx * 1.0, yc, zl))
        lg.pivot = (sx * 1.0, yc, zl)
        x = 1 if sx > 0 else -2
        fc = _dark(col, 0.3)
        for z in range(0, zl + 1):
            lg.put((x, math.floor(yc), z), fc)
        lg.put((x, math.floor(yc) - 1, 0), fc)
        lg.put((x, math.floor(yc) - 2, 0), fc)


def long_neck(c, H, col=None, col2=None, a=None):
    """A long neck (a crane's, a heron's): the head and eyes rise and reach
    forward by "amount" (default 2.2, in tenths of the height) on a slim
    neck from the top of the body (col, default the body colour), and the
    body slims to a boat shape. Put it before the wings."""
    k = H / 10.0
    body, head = _find(c, 'body'), head_of(c)
    if not body or head is body:
        return
    amt = float((a or {}).get('amount', 2.2)) * k
    up, fwd = round(amt), round(0.45 * amt)
    slim = float((a or {}).get('slim', 0.7))
    if slim < 1:  # a narrower, boat-shaped body: squeeze it across
        nv = {}
        for (x, y, z), v in body.v.items():
            nv[(math.floor((x + .5) * slim), y, z)] = v
        body.v = {(x, y, z): v for (x, y, z), v in nv.items() if x >= 0}
        body.v.update({(_mx(x), y, z): v for (x, y, z), v in list(body.v.items())})
    for p in c.parts:
        if p.name in ('head', 'eyes', 'crest', 'beak'):
            p.v = {(x, y - fwd, z + up): v for (x, y, z), v in p.v.items()}
            px, py, pz = p.pivot
            p.pivot = (px, py - fwd, pz + up)
    nc = _hexa(col, body.v[max(body.v, key=lambda q: q[2])][0])
    zb = max(p[2] for p in body.v) - 1.0 * k
    yb = min(p[1] for p in body.v if p[2] >= zb) + 0.6 * k
    hz0 = min(p[2] for p in head.v)
    hy = sum(p[1] for p in head.v if p[2] <= hz0 + 1) / max(1, sum(1 for p in head.v if p[2] <= hz0 + 1))
    top = (hy + 0.3 * k, hz0 + 0.8 * k)
    line(body, (0, yb, zb), (0, top[0], top[1]), nc, r=0.55 * k + 0.3)


def raptor_beak(c, H, col, col2=None):
    """A hawk's hooked beak in place of a songbird's: a deep upper mandible
    that curves down to a dark hooked tip, and fierce brows over the eyes
    (col2, default a dark shade of the head). Replaces the plan's beak."""
    k = H / 10.0
    head = head_of(c)
    eyes = _find(c, 'eyes')
    face = head.v[max(head.v, key=lambda q: q[2])][0]  # the crown's colour
    for q in [q for q, (cc, g) in head.v.items() if cc == col]:
        del head.v[q]
    ez = min(p[2] for p in eyes.v) if eyes and eyes.v else round(6.9 * k)
    yf = min(p[1] for p in head.v if abs(p[0] + 0.5) <= 1 and p[2] <= ez)
    bw = max(1, round(0.55 * k))
    ztop = ez - 1
    L = max(3, round(1.5 * k))
    tip = _dark(col, 0.45)
    for i in range(L):
        t = i / (L - 1)
        w = max(1, round(bw * (1 - 0.5 * t)))
        top = ztop - round(t * t * 0.9 * k)
        bot = ztop - round((0.9 - 0.2 * t) * k)
        head.box((-w, yf - i, bot), (w - 1, yf - i, top), col)
    # the hook: the tip curls down past the lower jaw
    hw = max(1, round(bw * 0.5))
    yh = yf - L + 1
    for j in range(max(2, round(0.6 * k))):
        head.box((-hw, yh - (1 if j == 0 else 0), ztop - round(0.9 * k) - j), (hw - 1, yh, ztop - round(0.9 * k) - j), tip)
    # brows: a dark ridge over each eye, sloping down toward the beak
    bc = col2 or _dark(face, 0.35)
    if eyes and eyes.v:
        for side in (1, -1):
            xs = [p[0] for p in eyes.v if (p[0] >= 0) == (side > 0)]
            if not xs:
                continue
            zt = max(p[2] for p in eyes.v if (p[0] >= 0) == (side > 0)) + 1
            inner, outer = (min(xs), max(xs)) if side > 0 else (max(xs), min(xs))
            for x in range(min(inner, outer) - 1, max(inner, outer) + 2):
                dz = 0 if abs(x - inner) > abs(x - outer) else -1  # lower toward the beak
                z = zt + 1 + dz
                f = head.front(x, z)
                if f:
                    head.put(f, bc)


def trunk(c, H, col, col2=None):
    """A short drooping trunk (a tapir's)."""
    k = H / 10.0
    head, yf, ez, z0, z1 = _head_front(c)
    zc = (ez - 0.6 * k) if ez is not None else (z0 + z1) / 2
    pts = [(0, yf + 0.4 * k, zc), (0, yf - 0.9 * k, zc - 0.2 * k), (0, yf - 1.6 * k, zc - 0.9 * k),
           (0, yf - 1.8 * k, zc - 1.6 * k)]
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        line(head, a, b, col, r=(0.75 - 0.15 * i) * k)
    tip = pts[-1]
    head.ell(tip, (0.45 * k, 0.45 * k, 0.3 * k), col2 or _dark(col, 0.3))


def hump(c, H, col, col2=None):
    """A big shoulder hump (a bison's)."""
    k = H / 10.0
    body = _find(c, 'body')
    y0, y1 = _yrange(body)
    zt = max(p[2] for p in body.v)
    body.ell((0, y0 + (y1 - y0) * 0.32, zt - 0.2 * k), (1.8 * k, 1.9 * k, 1.5 * k), col)


def recolor(c, H, col, col2=None):
    """Every voxel of colour col becomes col2 (a plan's own fixed colour,
    like a turtle's shell squares)."""
    for part in c.parts:
        for p, (cc, g) in list(part.v.items()):
            if cc == col:
                part.v[p] = (col2 or col, g)


def _components(vox):
    left, out = set(vox), []
    while left:
        start = left.pop()
        comp, todo = {start}, [start]
        while todo:
            x, y, z = todo.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    for dz in (-1, 0, 1):
                        n = (x + dx, y + dy, z + dz)
                        if n in left:
                            left.remove(n)
                            comp.add(n)
                            todo.append(n)
        out.append(comp)
    return sorted(out, key=len, reverse=True)


def cheek_ruff(c, H, col, col2=None):
    """Tufts of fur flaring from the lower cheeks (a lynx's ruff)."""
    k = H / 10.0
    head, yf, ez, z0, z1 = _head_front(c)
    zc = z0 + (z1 - z0) * 0.3
    xs = [p[0] for p in head.v if abs(p[2] - zc) <= 1]
    if not xs:
        return
    xr = max(xs)
    ys = [p[1] for p in head.v if p[0] == xr and abs(p[2] - zc) <= 1]
    yc = sum(ys) / len(ys)
    for sx in (-1, 1):
        x = xr if sx > 0 else -xr - 1
        for dz, L in ((0.2, 0.7), (-0.5, 0.9)):
            shard(head, (x + .5, yc + .5, zc + dz * k), (sx * 0.6, 0.35, -0.7), L * k, 0.3 * k + .2,
                  col, col2 or col, tip_glow=False)


def owl_tufts(c, H, col, col2=None):
    """Feathered triangular ear tufts on the crown's corners."""
    k = H / 10.0
    head = head_of(c)
    zt = max(p[2] for p in head.v)
    top = [p for p in head.v if p[2] >= zt - 1]
    xr = max(p[0] for p in top)
    yc = sum(p[1] for p in top) / len(top)
    part = c.part('tufts', 'ears' if c.rarity not in ('Common', 'Uncommon') else 'static', (0, yc, zt))
    n = max(3, round(1.6 * k))
    hw0 = max(1, round(0.6 * k))
    for sx in (-1, 1):
        cx = xr - hw0 if sx > 0 else -(xr - hw0) - 1
        for i in range(n):
            hw = 0 if i == n - 1 else int(hw0 * (1 - i / n) + 0.5)
            lean = round(sx * i * 0.35)
            for x in range(cx - hw + lean, cx + hw + lean + 1):
                for y in (round(yc), round(yc) + 1):
                    shade = col2 if (col2 and i >= n - 2) else (_dark(col, 0.1) if (x + i) % 2 else col)
                    part.put((x, y, zt - 1 + i), shade)


def facial_disc(c, H, col, col2=None):
    """An owl's facial disc: a ring of feathers round both eyes."""
    k = H / 10.0
    head, yf, ez, z0, z1 = _head_front(c)
    eyes = _find(c, 'eyes')
    if not eyes or not eyes.v:
        return
    for sx in (-1, 1):
        pts = [p for p in eyes.v if (p[0] >= 0) == (sx > 0)]
        if not pts:
            continue
        cx = sum(p[0] + .5 for p in pts) / len(pts)
        cz = sum(p[2] + .5 for p in pts) / len(pts)
        r_in = max(abs(p[0] + .5 - cx) for p in pts) + max(abs(p[2] + .5 - cz) for p in pts) * 0 + 1.0
        r_in = max(r_in, 0.9 * k)
        r_out = r_in + max(1.0, 0.45 * k)
        head.paint(lambda p, cc, g, cx=cx, cz=cz, r_in=r_in, r_out=r_out:
                   (col, False) if (p[1] <= yf + 2 and not g and
                                    r_in <= math.hypot(p[0] + .5 - cx, p[2] + .5 - cz) < r_out) else None)


def snowflakes(c, H, col, col2=None):
    """Little six-pointed snowflakes on the wing and tail feathers, glowing."""
    k = H / 10.0
    for name in ('wingL', 'wingR', 'tail'):
        part = _find(c, name)
        if not part or not part.v:
            continue
        surf = _surface(part)
        if not surf:
            continue
        xs = [abs(p[0] + .5) for p in part.v]
        zs = [p[2] for p in part.v]
        outer = [p for p in surf if abs(p[0] + .5) >= min(xs) + (max(xs) - min(xs)) * 0.45 or name == 'tail']
        picks = sorted(outer, key=lambda p: _hash(*p, 71))[:3 if name == 'tail' else 2]
        arm = max(1, round(0.35 * k))
        for (x, y, z) in picks:
            for d in range(-arm, arm + 1):
                for q in ((x, y, z + d), (x, y + d, z), (x, y + d, z + d), (x, y + d, z - d)):
                    if q in part.v:
                        part.v[q] = (col, True)


def turtle_beak(c, H, col, col2=None):
    """A turtle's head: a flatter skull and a rounded horn beak at the front."""
    k = H / 10.0
    head, yf, ez, z0, z1 = _head_front(c)
    eyes = _find(c, 'eyes')
    ev = set(eyes.v) if eyes else set()
    # flatten the skull: take off the top layer
    zt = max(p[2] for p in head.v)
    for p in [p for p in head.v if p[2] == zt and p not in ev]:
        del head.v[p]
    # the beak: the front of the face below the eyes, in horn colour, with a
    # rim that curls a voxel forward and down
    beak = col
    top = (ez - 1) if ez is not None else (z0 + z1) / 2
    head.paint(lambda p, cc, g: (beak, False) if p[1] <= yf + max(1, round(0.5 * k)) and p[2] < top else None)
    front = [p for p in head.v if p[1] == yf and p[2] < top]
    if front:
        zl = min(p[2] for p in front)
        for p in front:
            if p[2] <= zl + 1:
                head.put((p[0], p[1] - 1, p[2]), col2 or _dark(beak, 0.2))

def mend(c, H, col=None, col2=None):
    """Joins any piece of a part that came apart (a thin leg or tail drawn
    at a size where its rounding leaves a one-voxel gap) back to the rest of
    that part, with a line in the colour of the piece. Only small gaps are
    closed: a part made of separate pieces on purpose (two eyes, two ears)
    is left alone."""
    for part in c.parts:
        if len(part.v) < 2 or part.name == 'eyes':
            continue
        comps = [set(cp) for cp in _components(part.v)]
        if len(comps) < 2:
            continue
        # smallest pieces first: each joins the nearest other piece when it is a
        # fragment (small and close); a piece about as big as its neighbour
        # (the other ear, the other antler) is separate on purpose
        for comp in sorted(comps, key=len)[:-1]:
            others = [o for o in comps if o is not comp]
            best = None
            for o in others:
                for p in comp:
                    for q in o:
                        d2 = sum((p[i] - q[i]) ** 2 for i in range(3))
                        if best is None or d2 < best[0]:
                            best = (d2, p, q, o)
            d2, a, b, o = best
            if not (d2 <= 9 or (len(comp) < 0.4 * len(o) and d2 <= 36)):
                continue
            colr, g = part.v[a]
            line(part, (a[0] + .5, a[1] + .5, a[2] + .5), (b[0] + .5, b[1] + .5, b[2] + .5), colr, glow=g)
            o |= comp
            comps.remove(comp)

ACCESSORIES = {
    'recolor': recolor, 'mend': mend, 'cheek_ruff': cheek_ruff, 'owl_tufts': owl_tufts,
    'facial_disc': facial_disc, 'snowflakes': snowflakes, 'turtle_beak': turtle_beak, 'flame_crest': flame_crest, 'ear_icicles': ear_icicles, 'aura_spikes': spikes, 'hedgehog_quills': hedgehog_quills, 'raptor_pose': raptor_pose, 'storm_crest': storm_crest, 'puffin_face': puffin_face, 'monkey_face': monkey_face, 'aura_long_neck': long_neck,
    'origami_crane': origami_crane, 'aura_mandibles': mandibles, 'eye_shine': eye_shine, 'pink_nose': pink_nose, 'toasted': toasted, 'jelly': jelly, 'ear_rims': ear_rims, 'otter_tail': otter_tail, 'tiny_ears': tiny_ears, 'wing_snowflakes': wing_snowflakes, 'amber_gaster': amber_gaster,
    'paper_wings': paper_wings, 'long_muzzle': long_muzzle, 'long_legs': long_legs, 'raptor_beak': raptor_beak, 'horse_head': horse_head, 'trunk': trunk, 'aura_hump': hump,
    'flames': flames, 'back_flame': back_flame, 'ear_flames': ear_flames, 'tail_flame': tail_flame,
    'aura_embers': embers, 'cracks': cracks, 'claws': claws,
    'ice': ice, 'ice_crown': ice_crown, 'ice_crest': ice_crest, 'gems': gems, 'gem_studs': gem_studs,
    'facets': facets, 'aura_whiskers': whiskers,
    'leaves': leaves, 'ear_leaves': ear_leaves, 'leaf_hat': leaf_hat, 'leaf_collar': leaf_collar, 'vines': vines,
    'blossoms': blossoms, 'rosebud': rosebud, 'moss': moss, 'aura_mushrooms': mushrooms, 'mushroom_crown': mushroom_crown,
    'toadstool_shell': toadstool_shell,
    'bolt': bolt, 'bolt_crest': bolt_crest, 'bolt_tail': bolt_tail, 'bolt_ears': bolt_ears, 'ear_bolts': ear_bolts,
    'bolt_mark': bolt_mark, 'aura_sparks': sparks, 'rings': rings, 'cloud_hump': cloud_hump, 'cloud_mane': cloud_mane,
    'cloud_tail': cloud_tail, 'cloud_feet': cloud_feet, 'aura_raincloud': raincloud, 'raindrops': raindrops,
    'wave': wave, 'raincoat': raincoat,
    'stars': stars, 'galaxy': galaxy, 'crescent': crescent, 'flank_crescent': flank_crescent, 'halo': halo, 'star_trail': star_trail,
    'constellation': constellation, 'glow_eyes': glow_eyes, 'iris_eyes': iris_eyes, 'zigzag_tips': zigzag_tips, 'sheep_ears': sheep_ears, 'glow_color': glow_color, 'ghost': ghost,
    'wisps': wisps, 'cloak': cloak, 'opal': opal, 'rainbow_shell': rainbow_shell,
    'sprinkles': sprinkles, 'aura_icing': icing, 'swirl': swirl, 'cone_horn': cone_horn, 'spiral_horn': spiral_horn, 'gears': gears,
    'windup_key': windup_key, 'cog_spines': cog_spines, 'rivets': rivets, 'clock_dial': clock_dial,
    'chimney': chimney, 'chest_shell': chest_shell, 'mimic': mimic,
    'twin_tails': twin_tails, 'triple_tails': triple_tails, 'three_heads': three_heads, 'snake_tail': snake_tail,
    'dragon_tail': dragon_tail, 'aura_tusks': tusks, 'thorn_mane': thorn_mane, 'aura_antlers': antlers,
    'headdress': headdress, 'hardhat': hardhat, 'lantern_pouch': lantern_pouch, 'lantern_belly': lantern_belly,
    'sun_crest': sun_crest, 'aura_clover': clover, 'ribs': ribs, 'aura_stripe': stripe, 'gloss': gloss,
    'paper_folds': paper_folds, 'stained_glass': stained_glass, 'tipped_wings': tipped_wings,
    'feather_wings': feather_wings, 'raised_wings': raised_wings, 'dragon_wings': dragon_wings, 'bat_wings': bat_wings,
    'small_wings': small_wings, 'nightcap': nightcap,
}


# ------------------------------------------------------------------ griffin

def griffin(c, H, col, head=None, beak=None, wing=None, talon=None, glow=None, tail='long'):
    """A griffin cub: an eagle's head, chest and front talons on a four-legged
    body (a pony's or a lion's), with big feathered wings and a tail tuft."""
    import creatures as cr
    k = H / 10.0
    head_col = head or WHITE
    beak = beak or GOLD
    talon = talon or hexc('#F2B33D')
    cr.quadruped(c, H, col, belly=None, snout=None, ears='pointy', ear_col=head_col, tail=tail, tail_col=col)
    hp = _find(c, 'head')
    body = _find(c, 'body')
    # eagle head: all head colour, a hooked beak
    hp.paint(lambda p, cc, g: (head_col, False) if cc not in (INK, WHITE) or p[2] > 5.4 * k else None)
    yf = min(p[1] for p in hp.v)
    bw = max(1, round(0.8 * k))
    zb = round(5.0 * k)
    for i in range(round(1.6 * k)):
        w = max(1, round(bw * (1 - 0.45 * i / (1.6 * k))))
        top = zb + round(1.0 * k) - round(i * 0.25)
        hp.box((-w, yf + 1 - i, zb - (1 if i > 1.1 * k else 0)), (w - 1, yf + 1 - i, top), beak)
    hook = round(1.6 * k)
    hp.box((-max(1, bw // 2), yf + 1 - hook, zb - round(0.7 * k)), (max(1, bw // 2) - 1, yf + 2 - hook, zb), _dark(beak, 0.2))
    # feathered chest and front legs: head colour on the front half, talons
    y0, y1 = _yrange(body)
    ymid = y0 + (y1 - y0) * 0.42
    body.paint(lambda p, cc, g: (head_col, False) if p[1] < ymid and p[2] > 0.9 * k else None)
    body.paint(lambda p, cc, g: (talon, False) if p[1] < ymid and p[2] <= max(1, round(0.5 * k)) else None)
    # a ruff of feathers where head meets chest
    for i in range(7):
        a = math.pi * i / 6
        ball(body, (math.cos(a) * 1.6 * k, y0 + 1.2 * k, 4.4 * k + math.sin(a) * 0.5 * k), (0.5 * k, 0.5 * k, 0.6 * k),
             _mix(head_col, col, 0.25))
    raised_wings(c, H, wing or _mix(col, head_col, 0.4), glow or head_col, span=4.2, tip_glow=bool(glow))
    # tail tuft
    tl = _find(c, 'tail')
    if tl and tl.v:
        tip = _tail_tip(c)
        ball(tl, (0, tip[1], tip[2]), (0.55 * k, 0.6 * k, 0.55 * k), head_col)
    return c


PLANS = {
    'griffin': ({'col', 'head', 'beak', 'wing', 'talon', 'glow'}, {'tail': {'long', 'bushy', 'short'}}),
}
BUILDERS = {
    'griffin': lambda c, H, cols, opts: griffin(c, H, cols['col'], cols.get('head'), cols.get('beak'),
                                                cols.get('wing'), cols.get('talon'), cols.get('glow'),
                                                opts.get('tail', 'long')),
}
