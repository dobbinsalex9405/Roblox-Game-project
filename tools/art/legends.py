"""The four showpiece creatures: the two Legendaries and the two Godlies.

They are one in thousands to one in fifty thousand, so they get far more than
the body plans in creatures.py: colour that shades from top to bottom,
layered feathers on raised wings, flame and star patterns that glow, faces
with brows and beaks, and props (a crown, a golden egg in a nest). Same axes
as creatures.py: x right, y back (front is -y), z up, in voxels."""
import math
from voxkit import hexc

INK, WHITE, BLUSH = hexc('#1B1B2F'), hexc('#FFFFFF'), hexc('#FF8FB1')


def band(part, stops, z0, z1, keep=()):
    """Shade a part by height: stops are (fraction up, colour), lowest first.
    Glowing voxels and colours in `keep` stay as they are."""
    def f(p, cc, g):
        if g or cc in keep:
            return None
        t = (p[2] - z0) / max(1, z1 - z0)
        col = stops[0][1]
        for frac, c in stops:
            if t >= frac:
                col = c
        return (col, False)
    part.paint(f)


def mirror(part, pts):
    """Put (x, y, z, colour, glow) on the right and its mirror on the left."""
    for x, y, z, col, g in pts:
        part.put((x, y, z), col, g)
        part.put((-x - 1, y, z), col, g)


def eye_pair(c, head, x_off, z, size, iris=INK, shine=WHITE, glow=False):
    """Big eyes cut into the head's front: an iris block with a shine in the
    top outer corner, in their own part so they blink."""
    e = c.part('eyes', 'blink', head.pivot)
    for sx in (1, -1):
        for dx in range(size):
            for dz in range(size + 1):
                x = x_off + dx if sx > 0 else -(x_off + dx) - 1
                f = head.front(x, z + dz)
                if f:
                    del head.v[f]
                    is_shine = dz == size and dx == size - 1
                    e.put(f, shine if is_shine else iris, glow and not is_shine)


def brow(head, x_off, z, length, col, slope=1):
    """Angled brows over the eyes: fiercer creatures slope inward-down."""
    for sx in (1, -1):
        for i in range(length):
            x = x_off + i if sx > 0 else -(x_off + i) - 1
            zz = z + (i * slope) // 2
            f = head.front(x, zz)
            if f:
                head.put((f[0], f[1] - 1, f[2]), col)


def grand_wing(c, k, root, length, rise, cols, tip, edge=None, thick=2, fan=1.0, tip_glow=True):
    """A raised, feathered wing pair. Feathers hang from an arched leading
    edge; colour runs from the shoulder (cols[0]) out to glowing tips."""
    rx, ry, rz = root
    L = round(length * k)
    for sx, name in ((1, 'wingR'), (-1, 'wingL')):
        w = c.part(name, name, (sx * rx, ry, rz))
        for i in range(L):
            t = i / max(1, L - 1)
            x = round(rx) + i
            top = rz + round(rise * k * math.sin(t * math.pi * 0.8) + t * 1.0 * k)
            flen = round((1.4 + 2.8 * fan * math.sin(min(1.0, t * 1.15) * math.pi * 0.9)) * k)
            if i % 2:
                flen -= max(1, round(0.4 * k))  # toothed feather ends
            flen = max(2, flen)
            for dz in range(flen):
                d = dz / max(1, flen - 1)
                if t > 0.84 or (d > 0.82 and t > 0.4):
                    col, g = tip, tip_glow
                elif t > 0.55 or d > 0.7:
                    col, g = cols[2], False
                elif t > 0.25 or d > 0.45:
                    col, g = cols[1], False
                else:
                    col, g = cols[0], False
                if edge is not None and dz == 0 and t > 0.15:
                    col, g = edge, True
                for dy in range(thick):
                    xx = x if sx > 0 else -x - 1
                    w.put((xx, ry + dy, top - dz), col, g)


def tube(part, pts, col_at, glow_at=lambda s: False):
    """Sweep a sphere along points (x, y, z, r) with s from 0 to 1."""
    n = len(pts)
    for i, (x, y, z, r) in enumerate(pts):
        s = i / max(1, n - 1)
        part.ell((x, y, z), (r, r, r), col_at(s), glow_at(s))


# ------------------------------------------------------------------ Phoenix

def phoenix(c, H):
    k = H / 10.0
    crimson, red, orange, amber = hexc('#C81E1E'), hexc('#F2381F'), hexc('#FF6A1A'), hexc('#FF9A1A')
    gold, goldD, flare, white_hot = hexc('#FFC21A'), hexc('#D98A10'), hexc('#FFE14D'), hexc('#FFF6B0')
    body = c.part('body')
    # legs and talons
    for sx in (1, -1):
        x = round(0.8 * k) if sx > 0 else -round(0.8 * k) - 1
        body.box((x, round(-0.2 * k), 0), (x, round(0.2 * k), round(1.4 * k)), gold)
        for t in range(-1, 2):
            body.put((x + t, round(-0.6 * k), 0), goldD)
        body.put((x, round(-0.9 * k), 0), goldD)
    body.ell((0, 0.5 * k, 3.6 * k), (2.3 * k, 2.1 * k, 2.4 * k), red)
    body.ell((0, 0.9 * k, 4.9 * k), (1.7 * k, 1.6 * k, 1.4 * k), red)  # shoulders
    band(body, [(0, amber), (0.25, orange), (0.55, red), (0.8, crimson)], round(1.2 * k), round(6.2 * k), keep=(gold, goldD))
    # golden breast with a hot glowing core
    body.paint(lambda p, cc, g: (flare, False) if p[1] < -0.9 * k and abs(p[0] + .5) < 1.4 * k and 1.8 * k < p[2] < 5.0 * k and cc not in (gold, goldD) else None)
    # a glowing ember diamond at the heart
    body.paint(lambda p, cc, g: (white_hot, True) if p[1] < -1.2 * k and abs(p[0] + .5) / (0.7 * k) + abs(p[2] + .5 - 3.6 * k) / (0.9 * k) <= 1 and cc == flare else None)
    # ember freckles on the back
    body.paint(lambda p, cc, g: (flare, True) if p[1] > 1.8 * k and (p[0] * 5 + p[2] * 3 + p[1]) % 11 == 0 and cc in (red, crimson) else None)

    head = c.part('head', 'head', (0, -0.6 * k, 6.0 * k))
    head.ell((0, -0.7 * k, 7.2 * k), (1.8 * k, 1.7 * k, 1.7 * k), red)
    band(head, [(0, orange), (0.4, red), (0.8, crimson)], round(5.6 * k), round(8.9 * k))
    # face mask: lighter around the eyes
    head.paint(lambda p, cc, g: (orange, False) if p[1] < -1.8 * k and 6.6 * k < p[2] < 7.8 * k else None)
    # hooked beak
    bw = max(1, round(0.45 * k))
    head.box((-bw, round(-3.3 * k), round(6.3 * k)), (bw - 1, round(-2.3 * k), round(6.9 * k)), gold)
    head.box((-bw + 1, round(-3.7 * k), round(5.9 * k)), (bw - 2, round(-3.2 * k), round(6.4 * k)), goldD)
    eye_pair(c, head, max(1, round(0.55 * k)), round(7.1 * k), max(2, round(0.45 * k)))
    brow(head, max(1, round(0.5 * k)), round(7.1 * k) + max(2, round(0.45 * k)) + 1, max(2, round(0.7 * k)), crimson, slope=-1)

    # crest: three flame plumes sweeping back off the crown
    crest = c.part('crest', 'glow', (0, -0.6 * k, 8.6 * k))
    for pidx, dx in enumerate((-0.7, 0.0, 0.7)):
        tall = 3.0 if pidx == 1 else 2.3
        pts = []
        for i in range(14):
            s = i / 13
            pts.append((dx * k * (1 - 0.3 * s), -0.6 * k + s * s * 2.2 * k, 8.4 * k + s * tall * k, max(0.6, (0.55 - 0.35 * s) * k)))
        tube(crest, pts, lambda s: orange if s < 0.3 else (flare if s < 0.75 else white_hot), lambda s: s >= 0.3)

    grand_wing(c, k, (1.7 * k, 0.6 * k, round(5.4 * k)), 5.0, 2.4, (red, orange, amber), flare, edge=None, thick=2)
    # glowing tips
    for name in ('wingL', 'wingR'):
        w = c.part(name)
        w.paint(lambda p, cc, g: (white_hot, True) if g and abs(p[0] + .5) > 6.4 * k else None)

    # tail: five long flame feathers that sweep back and curl up
    tail = c.part('tail', 'tail', (0, 2.2 * k, 2.8 * k))
    for f in range(5):
        spread = (f - 2) * 0.55
        pts = []
        length = 1.0 - abs(f - 2) * 0.12
        for i in range(22):
            s = i / 21
            y = 2.2 * k + s * 4.8 * k * length
            z = 2.8 * k - 1.9 * k * math.sin(s * math.pi * 0.85) + 3.2 * k * s ** 3
            x = spread * k * (0.4 + 1.6 * s)
            pts.append((x, y, max(0.5 * k, z), max(0.5, (0.55 - 0.3 * s) * k)))
        tube(tail, pts, lambda s: red if s < 0.35 else (orange if s < 0.6 else (flare if s < 0.85 else white_hot)), lambda s: s >= 0.6)
    return c


# ------------------------------------------------------------ Thunder Griffin

def thunder_griffin(c, H):
    k = H / 10.0
    tan, tanD, cream = hexc('#D29A45'), hexc('#A8722C'), hexc('#F5DDAA')
    white, grey, greyD = hexc('#FFFFFF'), hexc('#DCE2EE'), hexc('#5A6274')
    beak, beakD, claw = hexc('#FFC21A'), hexc('#D98A10'), hexc('#3A3A4A')
    brown, brownL, volt, volt_hot = hexc('#7A4E2A'), hexc('#A8743F'), hexc('#4FD8FF'), hexc('#D8FBFF')
    body = c.part('body')
    lw = max(1, round(0.9 * k))
    for sx in (1, -1):
        for ly, front in ((-1.4 * k, True), (2.4 * k, False)):
            x0 = round(1.3 * k) if sx > 0 else -round(1.3 * k) - lw
            col = beak if front else tan
            body.box((x0, round(ly), 0), (x0 + lw - 1, round(ly) + lw - 1, round(1.7 * k)), col)
            if front:  # eagle talons
                for t in range(lw):
                    body.put((x0 + t, round(ly) - 1, 0), claw)
            else:  # lion paw
                body.box((x0, round(ly) - 1, 0), (x0 + lw - 1, round(ly) - 1, round(0.4 * k)), cream)
    body.ell((0, 0.6 * k, 3.1 * k), (2.1 * k, 3.0 * k, 1.9 * k), tan)
    band(body, [(0, cream), (0.35, tan), (0.8, tanD)], round(1.4 * k), round(5.0 * k), keep=(beak, claw))
    # feather ruff where the eagle front meets the lion back
    ruff = c.part('ruff', 'static')
    for z in range(round(2.6 * k), round(6.0 * k)):
        for x in range(-round(2.2 * k), round(2.2 * k)):
            y = round(-1.0 * k + (z - 2.6 * k) * 0.2)
            if (x + .5) ** 2 / (2.2 * k) ** 2 + ((z - 4.4 * k) / (1.9 * k)) ** 2 <= 1:
                ruff.put((x, y, z), white if (x + z) % 3 else grey)
                ruff.put((x, y - 1, z), white)

    head = c.part('head', 'head', (0, -1.8 * k, 5.6 * k))
    head.ell((0, -2.6 * k, 6.6 * k), (1.8 * k, 1.8 * k, 1.7 * k), white)
    band(head, [(0, grey), (0.3, white)], round(5.2 * k), round(8.3 * k))
    bw = max(1, round(0.55 * k))
    head.box((-bw, round(-5.0 * k), round(5.9 * k)), (bw - 1, round(-4.1 * k), round(6.7 * k)), beak)
    head.box((-bw + 1, round(-5.4 * k), round(5.3 * k)), (bw - 2, round(-4.9 * k), round(6.1 * k)), beakD)
    eye_pair(c, head, max(1, round(0.6 * k)), round(6.8 * k), max(2, round(0.4 * k)), iris=hexc('#2A2F45'))
    brow(head, max(1, round(0.5 * k)), round(6.8 * k) + max(2, round(0.4 * k)) + 1, max(2, round(0.8 * k)), greyD, slope=-1)
    ears = c.part('ears', 'ears', (0, -2.4 * k, 8.0 * k))
    for i in range(round(1.6 * k)):
        mirror(ears, [(round(1.0 * k) + i // 3, round(-2.0 * k) + i // 2, round(8.0 * k) + i, white if i < 1.0 * k else grey, False)])

    grand_wing(c, k, (1.8 * k, 0.6 * k, round(5.0 * k)), 4.8, 2.6, (brown, brownL, white), volt_hot, edge=volt, thick=2)
    # lightning zig-zags down each wing
    for name in ('wingL', 'wingR'):
        w = c.part(name)
        w.paint(lambda p, cc, g: (volt, True) if not g and (abs(p[0] + .5) + p[2] * 0.5) % round(2.2 * k) < 1 and cc == brownL else None)

    tail = c.part('tail', 'tail', (0, 3.4 * k, 3.4 * k))
    pts = []
    for i in range(16):
        s = i / 15
        pts.append((0, 3.4 * k + s * 3.2 * k, 3.4 * k + 1.4 * k * math.sin(s * math.pi * 0.7), max(0.5, 0.35 * k)))
    tube(tail, pts, lambda s: tan)
    tail.ell((0, 6.6 * k, 4.6 * k), (0.8 * k, 0.9 * k, 0.9 * k), volt, True)
    tail.ell((0, 6.8 * k, 4.8 * k), (0.4 * k, 0.4 * k, 0.4 * k), volt_hot, True)
    return c


# ------------------------------------------------------------ Golden Goose

def golden_goose(c, H):
    k = H / 10.0
    gold, goldL, goldD, goldDD = hexc('#FFC72E'), hexc('#FFE27A'), hexc('#E8A21A'), hexc('#B87510')
    shine, beak, beakD = hexc('#FFF7C2'), hexc('#FF8C1A'), hexc('#D96A10')
    ruby, sapphire, emerald = hexc('#FF3B5C'), hexc('#3FA9FF'), hexc('#3FE08A')
    straw, strawD = hexc('#C99A55'), hexc('#8A6230')
    body = c.part('body')
    # webbed feet
    for sx in (1, -1):
        x = round(0.9 * k) if sx > 0 else -round(0.9 * k) - 1
        body.box((x, round(-0.1 * k), 0), (x, round(0.2 * k), round(1.2 * k)), beak)
        for t in range(-1, 2):
            body.put((x + t, round(-0.6 * k), 0), beak)
            body.put((x + t, round(-0.9 * k), 0), beakD)
    body.ell((0, 0.6 * k, 3.4 * k), (2.5 * k, 2.6 * k, 2.3 * k), gold)
    # long elegant neck rising from the chest
    for i in range(18):
        s = i / 17
        body.ell((0, -0.9 * k - 0.5 * k * math.sin(s * math.pi), 4.8 * k + s * 3.4 * k), (0.85 * k, 0.85 * k, 0.6 * k), gold)
    band(body, [(0, goldD), (0.3, gold), (0.7, goldL)], round(1.0 * k), round(8.0 * k), keep=(beak, beakD))
    # a soft sheen on the breast
    body.paint(lambda p, cc, g: (goldL, False) if p[1] < -1.4 * k and ((p[0] + .5) / (1.3 * k)) ** 2 + ((p[2] + .5 - 3.6 * k) / (1.3 * k)) ** 2 <= 1 else None)
    body.paint(lambda p, cc, g: (shine, False) if p[1] < -1.6 * k and ((p[0] + .5 - 0.4 * k) / (0.5 * k)) ** 2 + ((p[2] + .5 - 4.0 * k) / (0.6 * k)) ** 2 <= 1 else None)

    # golden egg in a straw nest, in front of its feet
    nest = c.part('nest', 'static')
    ny, nz = -3.6 * k, 0
    for a in range(48):
        ang = a / 48 * math.pi * 2
        for r in (1.3 * k, 1.6 * k):
            nest.put((round(math.cos(ang) * r), round(ny + math.sin(ang) * r), round(nz + 0.2 * k)), straw if a % 3 else strawD)
            nest.put((round(math.cos(ang) * r), round(ny + math.sin(ang) * r), round(nz)), strawD)
    egg = c.part('egg', 'glow', (0, ny, 0))
    egg.ell((0, ny, 1.5 * k), (1.0 * k, 1.0 * k, 1.35 * k), gold, True)
    egg.paint(lambda p, cc, g: (shine, True) if p[0] >= 0.2 * k and p[1] < ny - 0.3 * k and p[2] > 1.9 * k else None)

    head = c.part('head', 'head', (0, -1.4 * k, 8.0 * k))
    head.ell((0, -1.5 * k, 9.0 * k), (1.5 * k, 1.6 * k, 1.4 * k), gold)
    band(head, [(0, gold), (0.6, goldL)], round(7.8 * k), round(10.4 * k))
    bw = max(1, round(0.45 * k))
    head.box((-bw, round(-4.0 * k), round(8.4 * k)), (bw - 1, round(-2.9 * k), round(8.9 * k)), beak)
    head.box((-bw, round(-4.0 * k), round(8.1 * k)), (bw - 1, round(-3.0 * k), round(8.3 * k)), beakD)
    head.put((-1, round(-3.4 * k), round(8.9 * k) + 1), INK)
    head.put((0, round(-3.4 * k), round(8.9 * k) + 1), INK)
    eye_pair(c, head, max(1, round(0.5 * k)), round(9.2 * k), max(2, round(0.35 * k)))
    for sx in (1, -1):
        x = round(1.1 * k) if sx > 0 else -round(1.1 * k) - 1
        f = head.front(x, round(8.7 * k))
        if f:
            head.put(f, BLUSH)

    # jewelled crown
    crown = c.part('crown', 'glow', (0, -1.5 * k, 10.4 * k))
    cz = round(10.3 * k)
    R = 1.0 * k
    for a in range(40):
        ang = a / 40 * math.pi * 2
        x, y = round(math.cos(ang) * R), round(-1.5 * k + math.sin(ang) * R)
        crown.put((x, y, cz), goldD, True)
        crown.put((x, y, cz + 1), gold, True)
        if a % 5 == 0:
            for h in range(2, 2 + max(2, round(0.6 * k))):
                crown.put((x, y, cz + h), gold, True)
            crown.put((x, y, cz + 2 + max(2, round(0.6 * k))), shine, True)
        if a % 10 == 5:
            crown.put((x, y, cz + 1), (ruby, sapphire, emerald, ruby)[a // 10], True)

    grand_wing(c, k, (2.0 * k, 0.9 * k, round(5.0 * k)), 5.2, 2.4, (goldD, gold, goldL), shine, edge=None, thick=2)
    for name in ('wingL', 'wingR'):
        w = c.part(name)
        w.paint(lambda p, cc, g: (goldDD, False) if not g and cc == goldD and p[2] % 3 == 0 else None)

    tail = c.part('tail', 'tail', (0, 2.8 * k, 3.6 * k))
    for i in range(round(2.4 * k)):
        for x in range(-round(0.9 * k) + i // 3, round(0.9 * k) - i // 3):
            tail.put((x, round(3.0 * k) + i, round(3.6 * k) + i // 2), goldL if i % 2 else gold)
    return c


# ---------------------------------------------------------- Nebula Serpent

def _hash(*v):
    h = 2166136261
    for x in v:
        h = ((h ^ (int(x) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    return h


def planet(part, centre, r, col, col2=None, bands=False, ring=None, craters=None, glow=False):
    """A small floating planet: a ball shaded light on top, with optional
    swirl bands, a tilted ring or craters."""
    cx, cy, cz = centre
    mine = set(_ball_pts(centre, r))  # paint this planet only, not its neighbours in the part
    part.ell(centre, (r, r, r), col, glow)
    if col2 is not None:
        def f(p, cc, g):
            if p not in mine:
                return None
            dz = (p[2] + .5 - cz) / max(r, 1)
            if bands and math.sin(dz * 7.0 + (p[0] + .5 - cx) * 0.35) > 0.45:
                return (col2, glow)
            if not bands and dz > 0.35:
                return (col2, glow)
            return None
        part.paint(f)
    if craters is not None:
        part.paint(lambda p, cc, g: (craters, glow) if p in mine and _hash(p[0] // 2, p[1] // 2, p[2] // 2, 7) % 5 == 0 else None)
    if ring is not None:
        R0, R1 = r * 1.35, r * 2.0
        for x in range(math.floor(cx - R1) - 1, math.ceil(cx + R1) + 2):
            for y in range(math.floor(cy - R1) - 1, math.ceil(cy + R1) + 2):
                d = math.hypot(x + .5 - cx, y + .5 - cy)
                if R0 <= d <= R1:
                    z = math.floor(cz + (x + .5 - cx) * 0.3)
                    if (x, y, z) not in part.v:
                        part.put((x, y, z), ring if d < (R0 + R1) / 2 else (col2 or ring), True)


def _vnoise(x, y, z, scale, seed):
    """Smooth value noise in 0..1 (trilinear between hashed lattice points),
    for nebula clouds and continents that drift across many voxels."""
    fx, fy, fz = x / scale, y / scale, z / scale
    ix, iy, iz = math.floor(fx), math.floor(fy), math.floor(fz)
    tx, ty, tz = fx - ix, fy - iy, fz - iz
    tx, ty, tz = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty), tz * tz * (3 - 2 * tz)

    def h(a, b, c):
        return (_hash(a, b, c, seed) % 1024) / 1023

    def lerp(a, b, t):
        return a + (b - a) * t
    x00 = lerp(h(ix, iy, iz), h(ix + 1, iy, iz), tx)
    x10 = lerp(h(ix, iy + 1, iz), h(ix + 1, iy + 1, iz), tx)
    x01 = lerp(h(ix, iy, iz + 1), h(ix + 1, iy, iz + 1), tx)
    x11 = lerp(h(ix, iy + 1, iz + 1), h(ix + 1, iy + 1, iz + 1), tx)
    return lerp(lerp(x00, x10, ty), lerp(x01, x11, ty), tz)


def _fbm(x, y, z, scale, seed):
    return 0.65 * _vnoise(x, y, z, scale, seed) + 0.35 * _vnoise(x, y, z, scale / 2.3, seed + 17)


def _norm(v):
    m = math.sqrt(v[0] ** 2 + v[1] ** 2 + v[2] ** 2) or 1.0
    return (v[0] / m, v[1] / m, v[2] / m)


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _bezier(p0, p1, p2, p3, t):
    u = 1 - t
    return tuple(u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d for a, b, c, d in zip(p0, p1, p2, p3))


def _shade(rgb, f):
    return tuple(max(0, min(255, round(v * f))) for v in rgb)


def _mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def nebula_serpent(c, H):
    """The Nebula Serpent (v4): a cosmic eastern dragon coiled on the ground
    and rising in an S. Its scales hold a nebula (deep space blue to violet
    to magenta, with drifting teal and pink clouds and glowing stars); pale
    belly plates run down its front; a glowing frill runs along its back. The
    head has a long snout with fangs, big glowing eyes that sit proud of the
    face (so a blink shows closed lids), brow ridges, a star gem, crystal
    antlers with tines, a flowing nebula mane and long whiskers. Two small
    clawed arms hold a glowing star pearl, the tail ends in a comet burst,
    and four small worlds circle it (the `orbit` part, which the game turns):
    a ringed giant, an ocean world with clouds, a lava world and a cratered
    moon, with star crystals between them. Each world sits outside the
    space the rest sweeps through, so none ever passes through the body."""
    k = H / 10.0
    # the in-game boxes (VoxelArt, the fallback while meshes load) skip the
    # fine surface detail, which only the Blender meshes can afford
    fine = getattr(c, 'fine', False)
    INKD = hexc('#0B0620')
    stops = [hexc('#170E45'), hexc('#25177A'), hexc('#3C25A6'), hexc('#6230BE'), hexc('#9236C6'), hexc('#C247C9'), hexc('#E465CF')]
    teal, pinkc = hexc('#2CC7D6'), hexc('#FF86DE')
    plate, plateL, plateD = hexc('#A893F2'), hexc('#C2B3FA'), hexc('#7E69D8')
    star, starP, starC, gold, goldL = hexc('#FFFFFF'), hexc('#FFD1F6'), hexc('#7FF6FF'), hexc('#FFD45A'), hexc('#FFF0B0')
    ivory, lid = hexc('#F6F0FF'), hexc('#5A1F7A')
    magenta_f = hexc('#C23FD0')
    rose, pink = hexc('#F046D2'), hexc('#FF7FE6')

    # ---------------------------------------------------------- the spine
    # coil on the ground: tail tip at the front right, round the back, to
    # the front left; then the neck rises in an S to the head
    cx0, cy0, R0 = 0.0, 1.0 * k, 2.55 * k
    a0, a1 = -math.pi / 2 + 0.95, 3 * math.pi / 2 - 0.55
    pts = []  # (x, y, z, r, t)

    def radius(t):
        if t < 0.5:
            return (0.22 + 0.86 * math.sin(min(1.0, t / 0.5) * math.pi / 2)) * k
        if t < 0.72:
            return 1.08 * k
        return (1.08 - 0.3 * (t - 0.72) / 0.28) * k

    n_coil = 260
    for i in range(n_coil):
        u = i / (n_coil - 1)
        a = a0 + (a1 - a0) * u
        rr = R0 * (1.0 + 0.1 * (1 - u))
        t = 0.5 * u
        r = radius(t)
        x, y = cx0 + math.cos(a) * rr, cy0 + math.sin(a) * rr
        z = r
        if u < 0.16:  # the tail tip flicks up and out
            f = (1 - u / 0.16) ** 2
            z += f * 1.5 * k
            x += f * 0.5 * k
        pts.append((x, y, z, r))
    end = pts[-1]
    tan = _norm((pts[-1][0] - pts[-6][0], pts[-1][1] - pts[-6][1], 0))
    p0 = (end[0], end[1], end[2])
    p1 = (p0[0] + tan[0] * 1.8 * k, p0[1] + tan[1] * 1.8 * k, p0[2] + 0.3 * k)
    p2 = (0.2 * k, 1.9 * k, 5.4 * k)
    p3 = (0.0, -0.7 * k, 6.9 * k)
    n_neck = 220
    for i in range(1, n_neck):
        u = i / (n_neck - 1)
        x, y, z = _bezier(p0, p1, p2, p3, u)
        pts.append((x, y, z, radius(0.5 + 0.5 * u)))
    n = len(pts)
    ts = [0.5 * i / (n_coil - 1) if i < n_coil else 0.5 + 0.5 * (i - n_coil + 1) / (n_neck - 1) for i in range(n)]

    # a frame at every spine point: T along the body, B towards the belly
    # (down on the coil, forward-down up the neck), S to the side
    arc, frames, s_acc = [], [], 0.0
    for i in range(n):
        a, b = pts[max(0, i - 2)], pts[min(n - 1, i + 2)]
        T = _norm((b[0] - a[0], b[1] - a[1], b[2] - a[2]))
        w = max(0.0, min(1.0, (ts[i] - 0.48) / 0.2))
        ref = _norm((0, -0.9 * w, -(1 - w) - 0.25 * w))
        d = _dot(ref, T)
        B = _norm((ref[0] - d * T[0], ref[1] - d * T[1], ref[2] - d * T[2]))
        S = _cross(T, B)
        if i:
            q = pts[i - 1]
            s_acc += math.dist(pts[i][:3], q[:3])
        arc.append(s_acc)
        frames.append((T, B, S))

    owner = {}
    for i, (x, y, z, r) in enumerate(pts):
        for p in _ball_pts((x, y, z), r):
            q = math.dist((p[0] + .5, p[1] + .5, p[2] + .5), (x, y, z)) / r
            if p not in owner or owner[p][1] > q:
                owner[p] = (i, q)

    scale_len = 0.42 * k

    def body_colour(p, i):
        x, y, z, r = pts[i]
        T, B, S = frames[i]
        d = (p[0] + .5 - x, p[1] + .5 - y, p[2] + .5 - z)
        phi = math.atan2(_dot(d, S), _dot(d, B))  # 0 = middle of the belly
        s = arc[i]
        if abs(phi) < 0.8:
            if not fine:
                return plate
            seam = (s / (0.5 * k)) % 1.0 < 0.2
            if seam:
                return plateD
            return plateL if abs(phi) < 0.3 else plate
        t = ts[i]
        if not fine:
            return stops[1] if t < 0.3 else (stops[3] if t < 0.6 else (stops[4] if t < 0.8 else stops[5]))
        g = t * (len(stops) - 1)
        lo = int(g)
        hi = min(len(stops) - 1, lo + 1)
        if fine:
            base = stops[hi] if (_hash(*p, 3) % 100) / 100 < g - lo else stops[lo]
        else:
            base = stops[hi] if g - lo > 0.5 else stops[lo]
        if not fine:
            return base
        cloud = _fbm(p[0], p[1], p[2], 1.9 * k, 41)
        cloud2 = _fbm(p[0], p[1], p[2], 1.6 * k, 77)
        if cloud > 0.66:
            base = _mix(base, teal, 0.55 if cloud > 0.74 else 0.3)
        elif cloud2 > 0.68:
            base = _mix(base, pinkc, 0.5 if cloud2 > 0.76 else 0.28)
        # scales: rows along the body, offset every other ring
        u = s / scale_len
        v = phi * r / scale_len
        if math.floor(v) % 2:
            u += 0.5
        fu, fv = u % 1.0, v % 1.0
        if fu > 0.74 + 0.9 * (fv - 0.5) ** 2:
            return _shade(base, 0.8)
        if fu < 0.18:
            return _shade(base, 1.08)
        return base

    body = c.part('body')
    for p, (i, q) in owner.items():
        body.put(p, body_colour(p, i))
    # stars in the scales: twinkling glowing points, a few as small crosses
    def surface(p):
        x, y, z = p
        return any(nb not in body.v for nb in ((x + 1, y, z), (x - 1, y, z), (x, y + 1, z), (x, y - 1, z), (x, y, z + 1)))
    for p in [q for q in body.v if surface(q)]:
        col = body.v[p][0]
        if col in (plate, plateL, plateD):
            continue
        h = _hash(*p, 11) % (160 if fine else 900)
        if h < 2:
            body.put(p, star, True)
        elif h == 2:
            body.put(p, starC, True)
        elif h == 3:
            body.put(p, starP, True)

    # ---------------------------------------------------------- dorsal frill
    frill = c.part('crest', 'glow')
    lo_i, hi_i = int(n * 0.3), int(n * 0.97)
    fin_len = 0.9 * k
    for i in range(lo_i, hi_i):
        x, y, z, r = pts[i]
        T, B, S = frames[i]
        t = ts[i]
        ph = (arc[i] / fin_len) % 1.0
        if ph > 0.86 or (not fine and int(arc[i] / fin_len) % 2):
            continue  # gaps between the fins (every other fin in the boxes)
        h = (0.25 + 0.75 * math.sin(ph / 0.86 * math.pi)) * (0.15 + 0.85 * t) * k
        steps = max(2, round(h))
        for j in range(steps):
            f = j / max(1, steps - 1)
            col = hexc('#8E2FB8') if f < 0.35 else (magenta_f if f < 0.7 else (rose if j < steps - 1 else pink))
            for side in (0.0,):
                px = x - B[0] * (r - 0.5 + j) + S[0] * side
                py = y - B[1] * (r - 0.5 + j) + S[1] * side
                pz = z - B[2] * (r - 0.5 + j) + S[2] * side
                q = (math.floor(px), math.floor(py), math.floor(pz))
                if q not in body.v:
                    frill.put(q, col, True)

    # ---------------------------------------------------------- comet tail
    tx, ty, tz, _ = pts[0]
    tip = c.part('tailtip', 'glow')
    tip.ell((tx, ty, tz), (0.42 * k, 0.42 * k, 0.42 * k), star, True)
    tip.ell((tx, ty, tz), (0.62 * k, 0.62 * k, 0.62 * k), starC, True, cond=lambda x, y, z: (x, y, z) not in tip.v and _hash(x, y, z, 5) % 3 == 0)
    for dx, dy, dz in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1)):
        for j in range(1, round(0.8 * k)):
            q = (math.floor(tx + dx * (0.42 * k + j)), math.floor(ty + dy * (0.42 * k + j)), max(0, math.floor(tz + dz * (0.42 * k + j))))
            tip.put(q, starC if j > 0.45 * k else star, True)
    # a trail of sparks drifting back from the tip along the coil
    for j in range(7 if fine else 0):
        px, py, pz, pr = pts[8 + j * 5]
        q = (math.floor(px + 0.9 * k), math.floor(py - 0.2 * k * j), math.floor(pz + pr + 0.3 * k + j % 2))
        tip.put(q, starP if j % 2 else starC, True)
    for v in [q for q in tip.v if q in body.v]:
        del tip.v[v]

    # ---------------------------------------------------------- the head
    hx, hy, hz = p3[0], p3[1] - 0.6 * k, p3[2] + 0.5 * k
    head = c.part('head', 'head', (p3[0], p3[1], p3[2]))
    skin_t = [hexc('#7A2FBF'), hexc('#A33BC9'), hexc('#C94BCB'), hexc('#E46BD2')]
    head.ell((hx, hy + 0.1 * k, hz + 0.45 * k), (1.35 * k, 1.55 * k, 1.12 * k), skin_t[1])          # cranium
    head.ell((hx, hy - 1.75 * k, hz + 0.05 * k), (0.92 * k, 1.45 * k, 0.66 * k), skin_t[1])        # snout
    head.ell((hx, hy - 3.0 * k, hz + 0.12 * k), (0.78 * k, 0.5 * k, 0.6 * k), skin_t[1])           # nose end
    for sx in (1, -1):
        head.ell((hx + sx * 1.0 * k, hy - 0.2 * k, hz - 0.05 * k), (0.62 * k, 0.85 * k, 0.62 * k), skin_t[1])  # cheeks
    band(head, [(0, skin_t[0]), (0.3, skin_t[1]), (0.62, skin_t[2]), (0.86, skin_t[3])] if fine else [(0, skin_t[0]), (0.4, skin_t[1]), (0.8, skin_t[2])],
         round(hz - 1.0 * k), round(hz + 1.6 * k))
    # small scales over the crown and snout, offset row to row
    hs = 0.34 * k

    def head_scales(p, cc, g):
        if g or cc not in skin_t:
            return None
        u = (p[1] + .5 - hy) / hs
        v = (p[0] + .5 - hx) / hs
        if math.floor(v) % 2:
            u += 0.5
        fu, fv = u % 1.0, v % 1.0
        if fu < 0.2 + 0.8 * (fv - 0.5) ** 2:
            return (_shade(cc, 0.84), False)
        return None
    if fine:
        head.paint(head_scales)
    # lower jaw, pale, a little open, with a row of scutes
    jaw = (hx, hy - 1.45 * k, hz - 0.74 * k)
    head.ell(jaw, (0.78 * k, 1.3 * k, 0.34 * k), plate)
    head.paint(lambda p, cc, g: (plateD, False) if cc == plate and (p[1] // max(1, round(0.3 * k))) % 3 == 0 else None)
    # a dark mouth line between snout and jaw
    for p in list(head.v):
        if abs(p[2] + .5 - (hz - 0.42 * k)) < 0.5 and p[1] < hy - 0.6 * k:
            x, y, z = p
            if (x, y - 1, z) not in head.v or (x + 1, y, z) not in head.v or (x - 1, y, z) not in head.v:
                head.put(p, INKD)
    # fangs at the front of the mouth
    for sx in (1, -1):
        fx = math.floor(hx + sx * 0.5 * k) - (0 if sx > 0 else 0)
        fy = math.floor(hy - 2.7 * k)
        top = math.floor(hz - 0.42 * k)
        for dz in range(max(2, round(0.35 * k))):
            head.put((fx, fy - 1, top - dz), ivory)
    # nose pad and nostrils
    nz = round(hz + 0.35 * k)
    for sx in (1, -1):
        for dx in range(max(1, round(0.22 * k))):
            x = math.floor(hx + sx * (0.3 * k + dx))
            f = head.front(x, nz)
            if f:
                head.put(f, INKD)
    # brow ridges
    for sx in (1, -1):
        head.ell((hx + sx * 0.72 * k, hy - 0.95 * k, hz + 1.0 * k), (0.55 * k, 0.6 * k, 0.24 * k), skin_t[0])
    # eyes: they stand one voxel proud of the face so a blink shows the lid
    eyes = c.part('eyes', 'blink', (hx, hy, hz))
    er = 0.5 * k
    behind = hy - 1.25 * k  # the eyes sit on the brow, behind the snout

    def face_at(x, z):
        ys = [p[1] for p in head.v if p[0] == x and p[2] == z and p[1] >= behind]
        return (x, min(ys), z) if ys else None
    for sx in (1, -1):
        ex, ez = hx + sx * 0.8 * k, hz + 0.68 * k
        for x in range(math.floor(ex - er), math.ceil(ex + er) + 1):
            for z in range(math.floor(ez - er * 0.8), math.ceil(ez + er * 0.8) + 1):
                dx, dz = (x + .5 - ex) / er, (z + .5 - ez) / (er * 0.8)
                if dx * dx + dz * dz > 1.0:
                    continue
                f = face_at(x, z)
                if not f:
                    continue
                head.put(f, lid)
                ring = dx * dx + dz * dz > 0.62 and dz < 0.35  # no lid line on top: wide awake
                pupil = abs(dx + 0.05 * sx) < 0.2 and abs(dz) < 0.75
                shine = 0.15 < dz < 0.6 and -0.55 < dx * sx < -0.1
                if shine:
                    col, g = star, True
                elif ring:
                    col, g = INKD, False
                elif pupil:
                    col, g = INKD, False
                else:
                    col, g = (starC if dz > 0 else teal), True
                eyes.put((f[0], f[1] - 1, f[2]), col, g)
    # star gem on the forehead
    gem = c.part('gem', 'glow', (hx, hy, hz))
    gx, gy = math.floor(hx), math.floor(hy - 0.55 * k)
    gz = max(p[2] for p in head.v if p[0] in (gx, gx - 1) and p[1] == gy) + 1
    gr = max(2, round(0.3 * k))
    for dx in range(-gr, gr):
        for dy in range(-gr, gr):
            if abs(dx + .5) + abs(dy + .5) <= gr:
                gem.put((gx + dx, gy + dy, gz), gold, True)
    for j in range(1, gr + 1):
        for q in ((gx + j - 1 + 1, gy, gz), (gx - j - 1 + 1 - 1, gy, gz), (gx, gy + j, gz), (gx, gy - j - 1, gz)):
            gem.put(q, goldL, True)
        gem.put((gx, gy, gz + j - 1 + 1), star if j == 1 else goldL, True)
        gem.put((gx - 1, gy, gz + j - 1 + 1), star if j == 1 else goldL, True)

    # crystal antlers: a swept main beam with three tines each
    horns = c.part('horns', 'glow', (hx, hy + 0.5 * k, hz + 1.3 * k))
    for sx in (1, -1):
        beam = []
        for i in range(24):
            s = i / 23
            beam.append((hx + sx * (0.8 * k + s * 1.25 * k), hy + 0.5 * k + s * 2.1 * k, hz + 1.3 * k + s * 2.5 * k - s * s * 0.9 * k,
                         max(0.55, (0.38 - 0.24 * s) * k)))
        tube(horns, beam, lambda s: magenta_f if s < 0.3 else (rose if s < 0.62 else (hexc('#B58CFF') if s < 0.88 else starC)), lambda s: True)
        for at, up, out in ((6, 1.3, 0.2), (12, 1.1, 0.5), (18, 0.8, 0.1))[:3 if fine else 2]:
            bx, by, bz, _ = beam[at]
            tine = []
            for i in range(10):
                s = i / 9
                tine.append((bx + sx * s * out * k, by - s * 0.55 * k, bz + s * up * k, max(0.5, (0.22 - 0.13 * s) * k)))
            tube(horns, tine, lambda s: rose if s < 0.5 else (hexc('#B58CFF') if s < 0.85 else starC), lambda s: True)

    # mane: nebula wisps streaming back from the cheeks and the back of the head
    mane = c.part('fins', 'glow', (hx, hy, hz))
    for sx in (1, -1):
        for m in range(4 if fine else 2):
            ox = hx + sx * (0.95 + 0.1 * m) * k
            oy = hy + (0.25 + 0.3 * m) * k
            oz = hz + (1.0 - 0.38 * m) * k
            L = (1.6 + 0.3 * (m % 2)) * k
            lock = []
            for j in range(18):
                s_ = j / 17
                lock.append((ox + sx * s_ * (0.45 + 0.12 * m) * k,
                             oy + s_ * L,
                             oz - s_ * (0.35 + 0.2 * m) * k + math.sin(s_ * math.pi * 1.5 + m) * 0.2 * k,
                             max(0.5, (0.26 - 0.17 * s_) * k)))
            cols = (rose, magenta_f) if m % 2 else (starC, teal)
            tube(mane, lock, lambda s_, cols=cols: cols[1] if s_ < 0.35 else (cols[0] if s_ < 0.8 else starP), lambda s_: True)
    for q in [q for q in mane.v if q in head.v or q in body.v]:
        del mane.v[q]

    # long whiskers from the snout, drooping and flowing back
    whisk = c.part('whiskers', 'glow', (hx, hy - 2.8 * k, hz))
    for sx in (1, -1):
        L = round(3.6 * k)
        for i in range(L):
            s = i / max(1, L - 1)
            x = hx + sx * (0.7 * k + s * 2.0 * k)
            y = hy - 2.75 * k + s * 1.9 * k
            z = hz - 0.1 * k - math.sin(s * math.pi * 0.9) * 1.25 * k + s * 0.5 * k + math.sin(s * math.pi * 3) * 0.12 * k
            q = (math.floor(x), math.floor(y), math.floor(z))
            if q not in head.v:
                whisk.put(q, starC if s < 0.75 else star, True)
                whisk.put((q[0], q[1], q[2] + 1), starC if s < 0.75 else star, True)

    # ---------------------------------------------------------- arms and pearl
    # two small arms reach from the chest and cup a glowing star pearl
    i_arm = n_coil + int((n_neck - 1) * 0.42)
    ax, ay, az, ar = pts[i_arm]
    T, B, S = frames[i_arm]
    pearl_c = (ax + B[0] * (ar + 0.85 * k), ay + B[1] * (ar + 0.85 * k), az + B[2] * (ar + 0.85 * k) - 0.2 * k)
    claws = []
    for sx in (1, -1):
        sh = (ax + B[0] * ar * 0.6 + S[0] * sx * ar * 0.7, ay + B[1] * ar * 0.6 + S[1] * sx * ar * 0.7, az + B[2] * ar * 0.6 + 0.2 * k)
        el = (pearl_c[0] + sx * 0.95 * k, pearl_c[1] + 0.25 * k, pearl_c[2] - 0.35 * k)
        wr = (pearl_c[0] + sx * 0.55 * k, pearl_c[1] - 0.05 * k, pearl_c[2] - 0.2 * k)
        seg = []
        for i in range(10):
            s = i / 9
            seg.append((sh[0] + (el[0] - sh[0]) * s, sh[1] + (el[1] - sh[1]) * s, sh[2] + (el[2] - sh[2]) * s, (0.32 - 0.06 * s) * k))
        for i in range(8):
            s = i / 7
            seg.append((el[0] + (wr[0] - el[0]) * s, el[1] + (wr[1] - el[1]) * s, el[2] + (wr[2] - el[2]) * s, (0.26 - 0.05 * s) * k))
        tube(body, seg, lambda s: stops[4] if s < 0.5 else stops[5])
        claws.append((sx, wr))
    pearl = c.part('pearl', 'glow', pearl_c)
    pr = 0.62 * k
    for p in _ball_pts(pearl_c, pr):
        d = (p[0] + .5 - pearl_c[0], p[1] + .5 - pearl_c[1], p[2] + .5 - pearl_c[2])
        swirl = math.sin(math.atan2(d[1], d[0]) * 2 + d[2] / pr * 3.0)
        col = (goldL if swirl > 0.35 else (star if swirl > -0.3 else hexc('#FFE27A'))) if fine else goldL
        pearl.put(p, col, True)
    for sx, wr in claws:
        for f in range(3):
            ang = -0.7 + f * 0.7
            for j in range(max(2, round(0.45 * k))):
                x = wr[0] - sx * j * 0.55 * math.cos(ang) * 0.9
                y = wr[1] + math.sin(ang) * j * 0.6 - j * 0.15
                z = wr[2] + j * 0.45
                q = (math.floor(x), math.floor(y), math.floor(z))
                if q not in pearl.v:
                    body.put(q, ivory if j >= max(2, round(0.45 * k)) - 1 else stops[5])

    # ---------------------------------------------------------- worlds in orbit
    taken = {}
    for part in c.parts:
        taken.update(part.v)
    mid_x = cx0
    mid_y = cy0
    orbit = c.part('orbit', 'orbit', (mid_x, mid_y, 0))

    def reach(z0, z1):
        """How far from the turning axis anything else reaches between z0 and z1."""
        far = 0.0
        for (x, y, z) in taken:
            if z0 <= z <= z1:
                far = max(far, math.hypot(x + .5 - mid_x, y + .5 - mid_y))
        return far

    worlds = (
        # angle, height, radius, kind
        (math.radians(-35), 2.4, 0.95, 'ringed'),
        (math.radians(70), 6.6, 0.82, 'ocean'),
        (math.radians(150), 3.4, 0.58, 'lava'),
        (math.radians(215), 6.0, 0.56, 'moon'),
    )
    for ang, zc, rr, kind in worlds:
        r = rr * k
        span = r * (2.0 if kind == 'ringed' else 1.0)
        z = zc * k
        # clear of everything else at its height, with room for the head to turn
        dist = max(reach(z - r - 2, z + r + 2) + span + 1.0 * k, 3.6 * k)
        centre = (mid_x + math.cos(ang) * dist, mid_y + math.sin(ang) * dist, z)
        mine = _ball_pts(centre, r)
        if kind == 'ringed':
            for p in mine:
                dz = (p[2] + .5 - z) / r
                b = math.sin(dz * 7.5 + (_vnoise(p[0], p[1], p[2], 0.6 * k, 9) * 2.0 if fine else 0))
                col = hexc('#FFB45A') if b > 0.35 else (hexc('#FFE2A6') if b > -0.35 else hexc('#D9773A'))
                orbit.put(p, col)
            R1, R2 = r * 1.4, r * 2.0
            cxp, cyp, czp = centre
            for x in range(math.floor(cxp - R2) - 1, math.ceil(cxp + R2) + 2):
                for y in range(math.floor(cyp - R2) - 1, math.ceil(cyp + R2) + 2):
                    d = math.hypot(x + .5 - cxp, y + .5 - cyp)
                    if R1 <= d <= R2:
                        zz = math.floor(czp + ((x + .5 - cxp) * 0.32 - (y + .5 - cyp) * 0.12 if fine else 0))
                        if (x, y, zz) not in orbit.v:
                            band_i = int((d - R1) / (R2 - R1) * 3)
                            if not fine:
                                band_i = 0
                            orbit.put((x, y, zz), (hexc('#F4E3FF'), hexc('#D7B8FF'), hexc('#FFF4D6'))[min(2, band_i)], band_i == 1)
        elif kind == 'ocean':
            for p in mine:
                land = _fbm(p[0], p[1], p[2], 0.7 * k, 23) > (0.56 if fine else 0.6)
                cloud = _vnoise(p[0] * 1.0, p[1] * 1.0, p[2] * 2.2, 0.45 * k, 31) > 0.8
                pole = (p[2] + .5 - z) > r * 0.9
                col = hexc('#FFFFFF') if (cloud or pole) else (hexc('#5DD67A') if land else hexc('#2E86E8'))
                orbit.put(p, col)
        elif kind == 'lava':
            for p in mine:
                crack = abs(_vnoise(p[0], p[1], p[2], 0.35 * k, 51) - 0.5) < 0.07
                col, g = (hexc('#FF7A1A'), True) if crack else ((hexc('#3A1E2A'), False) if _hash(*p, 4) % 3 or not fine else (hexc('#57283A'), False))
                orbit.put(p, col, g)
        else:
            for p in mine:
                crater = _vnoise(p[0], p[1], p[2], 0.3 * k, 61) > 0.7
                orbit.put(p, hexc('#8E89A8') if crater else (hexc('#D6D2E6') if _hash(*p, 6) % 3 or not fine else hexc('#BEB9D2')))
        # the worlds turn together, so they only need to be clear of the
        # body (above) and of each other at rest, which their angles see to
    # four-point star crystals between the worlds
    for ang, zc in ((math.radians(20), 5.2), (math.radians(118), 3.0), (math.radians(205), 7.4), (math.radians(300), 4.6))[:4 if fine else 0]:
        z = zc * k
        dist = max(reach(z - 3, z + 3) + 0.5 * k, 3.4 * k)
        px, py = mid_x + math.cos(ang) * dist, mid_y + math.sin(ang) * dist
        L = max(2, round(0.32 * k))
        bx, by, bz = math.floor(px), math.floor(py), math.floor(z)
        orbit.put((bx, by, bz), star, True)
        for j in range(1, L + 1):
            col = starC if j > L // 2 else star
            for q in ((bx + j, by, bz), (bx - j, by, bz), (bx, by, bz + j), (bx, by, bz - j)):
                orbit.put(q, col, True)
    return c


def _ball_pts(c, r):
    cx, cy, cz = c
    out = []
    for x in range(math.floor(cx - r), math.ceil(cx + r) + 1):
        for y in range(math.floor(cy - r), math.ceil(cy + r) + 1):
            for z in range(max(0, math.floor(cz - r)), math.ceil(cz + r) + 1):
                if ((x + .5 - cx) / r) ** 2 + ((y + .5 - cy) / r) ** 2 + ((z + .5 - cz) / r) ** 2 <= 1.0:
                    out.append((x, y, z))
    return out
