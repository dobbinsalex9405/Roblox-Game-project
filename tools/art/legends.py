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

def nebula_serpent(c, H):
    k = H / 10.0
    indigo, violet, magenta, rose = hexc('#24135A'), hexc('#4B2FA0'), hexc('#9A2FB8'), hexc('#E04FD0')
    plate, plateD = hexc('#C7B8FF'), hexc('#9C88E8')
    star, star2, cyan = hexc('#FFFFFF'), hexc('#FFE6FF'), hexc('#6FF2FF')
    body = c.part('body')
    pts = []
    n = 60
    for i in range(n):
        t = i / (n - 1)
        pts.append((math.sin(t * math.pi * 2.2) * 2.3 * k,
                    math.cos(t * math.pi * 1.6) * 2.5 * k,
                    1.2 * k + t * 5.8 * k,
                    (1.35 - 0.5 * t) * k))
    for i, (x, y, z, r) in enumerate(pts):
        t = i / (n - 1)
        col = indigo if t < 0.3 else (violet if t < 0.62 else (magenta if t < 0.85 else rose))
        body.ell((x, y, z), (r, r, r), col)
    # belly plates down the inside of the coil, with seams
    body.paint(lambda p, cc, g: ((plate if (p[2] // max(1, round(0.5 * k))) % 2 else plateD), False) if p[1] < -1.5 * k and cc in (indigo, violet) else None)
    # stars scattered over the dark scales
    body.paint(lambda p, cc, g: (star if (p[0] + p[2]) % 2 else star2, True) if cc in (indigo, violet, magenta) and (p[0] * 7 + p[1] * 13 + p[2] * 5) % 37 == 0 else None)
    body.paint(lambda p, cc, g: (cyan, True) if cc in (indigo, violet) and (p[0] * 11 + p[1] * 3 + p[2] * 17) % 61 == 0 else None)

    head = c.part('head', 'head', (0, -1.0 * k, 7.4 * k))
    head.ell((0, -1.4 * k, 8.4 * k), (1.8 * k, 2.0 * k, 1.5 * k), magenta)
    head.ell((0, -3.4 * k, 8.0 * k), (1.1 * k, 1.4 * k, 0.9 * k), magenta)  # snout
    band(head, [(0, violet), (0.35, magenta), (0.75, rose)], round(6.8 * k), round(9.9 * k))
    # pale face plate and jaw
    head.paint(lambda p, cc, g: (plate, False) if p[1] < -2.6 * k and p[2] < 7.9 * k else None)
    # nostrils
    head.put((-2, round(-4.6 * k), round(8.2 * k)), INK)
    head.put((1, round(-4.6 * k), round(8.2 * k)), INK)
    eye_pair(c, head, max(1, round(0.75 * k)), round(8.7 * k), max(2, round(0.4 * k)), iris=cyan, shine=star, glow=True)
    brow(head, max(1, round(0.6 * k)), round(8.7 * k) + max(2, round(0.4 * k)) + 1, max(2, round(0.8 * k)), indigo, slope=-1)

    horns = c.part('horns', 'glow', (0, -0.8 * k, 9.6 * k))
    for sx in (1, -1):
        pts_h = []
        for i in range(12):
            s = i / 11
            pts_h.append((sx * (1.1 * k + s * 0.6 * k), -0.8 * k + s * 2.0 * k, 9.4 * k + s * 1.8 * k - s * s * 0.6 * k, max(0.5, (0.4 - 0.25 * s) * k)))
        tube(horns, pts_h, lambda s: rose if s < 0.5 else star2, lambda s: True)
    # whiskers
    for sx in (1, -1):
        for i in range(round(2.0 * k)):
            x = round(1.0 * k) + i if sx > 0 else -round(1.0 * k) - i - 1
            horns.put((x, round(-4.0 * k) + i // 2, round(7.6 * k) - i // 3), cyan, True)

    fins = c.part('crest', 'glow')
    for i in range(4, n - 6, 3):
        x, y, z, r = pts[i]
        h = max(2, round((0.9 - 0.4 * i / n) * k))
        for j in range(h):
            fins.put((round(x), round(y), round(z + r) + j), rose if j < h - 1 else star2, True)
            if j < h - 1:
                fins.put((round(x) - 1, round(y), round(z + r) + j), magenta, True)
    return c
