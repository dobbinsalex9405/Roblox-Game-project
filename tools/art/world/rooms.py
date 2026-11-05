"""The apartment upgrade path: the room-wide layer each floor upgrade adds
(plans/hatchery-heist/apartment-upgrade-path.md).

Floors 2 to 10 each get, in upgrade order:
  1 Cozy   -> `bed`:     a creature bed for every pad (6.6 x 6.6, low: the pad
                         is 6 x 6 x 0.4 and the creature stands on it)
  2 Toys   -> `rug`:     one area rug under the whole creature grid (40 x 20)
  3 Lights -> `ceiling`: a ceiling light, hung four times between the pad rows
                         (its top touches the ceiling; placement data sets the height)
  4 Finish -> `plant`:   a big potted plant for the corners, and
              `crest`:   the floor's glowing crest over the back wall
                         (back of the prop at +y, against the wallpaper)

Kind "room" so the world thread's decor zones (cozy, toys, lighting, food)
and its review layout stay as they are; the corner props of those zones
come with the same upgrades (config/towerDecor.luau says which).

Same frame and rules as decor.py: studs, front is -y, z up, base at z = 0,
moving bits are their own part. Patterns that must survive the Parts version
are drawn on a 0.2 or 0.4-stud grid so they merge into few boxes.
"""
import math
import numpy as np

from vkit import col, hnoise, snoise
from styles import pick
from props import prop, WOOD, WOOD_D, IRON

GOLD, GOLD_D = '#F4C542', '#C99A2E'
WARM = '#FFD89A'


# Most Parts boxes per prop, by zone: beds come 8 to a floor and lights 4,
# so they stay light; a fully upgraded floor adds about 1,000 boxes.
BUDGET = {'bed': 60, 'rug': 120, 'ceiling': 60, 'plant': 80, 'crest': 50}


def R(pid, floor, zone, w, d, h, note='', budget=None):
    budget = budget or BUDGET[zone]
    hw, hd = w / 2, d / 2
    return prop(pid, 'room', (-hw, -hd, 0), (hw, hd, h), budget=budget, floor=floor, zone=zone, note=note)


def glow(h, s=3.0):
    return col(h, s)


def snap(v, q):
    return np.floor(v / q)


def ring(g, cx, cy, z0, z1, ro, ri, c):
    g.cyl(cx, cy, z0, z1, ro, c)
    g.carve((cx - ri, cy - ri, z0), (cx + ri, cy + ri, z1), lambda X, Y, Z: (X - cx) ** 2 + (Y - cy) ** 2 < ri * ri)


# =================================================================== beds
# Every bed: 6.6 x 6.6 footprint, a soft middle at about 0.5 (just over the
# 0.4 pad, so the creature looks tucked in) and a rim no higher than 1.1.
BW = 6.6
BH = 1.1


@R('ReadingCushion', 2, 'bed', BW, BW, BH, 'Book Nook bed: patchwork floor cushion with a rolled bolster at the back')
def _(p):
    g = p.part()
    patch = [col('#F2B94B'), col('#4FB3B0'), col('#FFF4E0'), col('#E38B6F'), col('#5E8C6A')]
    ids = np.array(patch)

    def quilt(X, Y, Z):
        i = (snap(X + 3.3, 1.2) * 3 + snap(Y + 3.3, 1.2) * 7).astype(int)
        return ids[i % len(ids)]
    g.rrbox((-3.2, -3.2, 0), (3.2, 3.2, 0.55), 0.25, quilt)
    # piping round the edge and tufted buttons where four patches meet
    g.paint((-3.3, -3.3, 0), (3.3, 3.3, 0.55), lambda X, Y, Z: np.abs(Z - 0.3) < 0.07, col('#7A4D2B'))
    for x in (-1.0, 1.4):
        for y in (-1.0, 1.4):
            g.box((x - 0.1, y - 0.1, 0.5), (x + 0.1, y + 0.1, 0.6), col('#7A4D2B'))
    g.seg((-2.9, 2.75, 0.75), (2.9, 2.75, 0.75), 0.42, pick(['#5E8C6A', '#55805F'], 501))
    for x in (-2.9, 2.9):
        g.cyl(x, 2.75, 0.33, 1.17, 0.12, col(GOLD))


@R('MossNest', 3, 'bed', BW, BW, BH, 'Plant Sunroom bed: round woven wicker nest lined with moss')
def _(p):
    g = p.part()
    tan, tan2 = col('#D9B27A'), col('#C49A5E')
    g.cyl(0, 0, 0, 0.4, 3.2, tan2)
    ring(g, 0, 0, 0.4, 1.0, 3.2, 2.5, tan)
    g.paint((-3.3, -3.3, 0.4), (3.3, 3.3, 0.6), None, col('#B98A50'))
    moss = pick(['#6DAA45', '#5F9A3C', '#7DBB52', '#86C95A'], 502)
    g.cyl(0, 0, 0.4, 0.6, 2.5, moss)
    for a, c in ((0.6, '#FF8FB1'), (2.4, '#FFFFFF'), (4.1, '#FFD166')):
        g.ell((math.cos(a) * 2.85, math.sin(a) * 2.85, 1.0), (0.25, 0.25, 0.15), col(c))


@R('ProofingBasketBed', 4, 'bed', BW, BW, BH, 'Bakery Kitchen bed: round proofing basket with a striped tea towel over one side')
def _(p):
    g = p.part()
    cane, cane2 = col('#E3B878'), col('#C9955A')
    g.cyl(0, 0, 0, 0.35, 3.2, cane)
    ring(g, 0, 0, 0.35, 0.95, 3.25, 2.6, lambda X, Y, Z: np.where(snap(Z, 0.2) % 2 == 0, cane, cane2))
    flour = pick(['#FFF4E0', '#F7EAD3'], 521)
    g.cyl(0, 0, 0.35, 0.5, 2.6, flour)
    # spiral ridges of the basket inside
    g.paint((-2.6, -2.6, 0.45), (2.6, 2.6, 0.5), lambda X, Y, Z: (np.sqrt(X * X + Y * Y) % 0.6) < 0.15, col('#E8D3B0'))
    towel_w, towel_b = col('#FFFFFF'), col('#5B8DD9')
    g.fill((-3.4, 0.6, 0.3), (-0.6, 3.4, 1.1),
           lambda X, Y, Z: (np.abs(Z - (0.95 - 0.12 * np.maximum(0, np.sqrt((X + 3.3) ** 2 + (Y - 3.3) ** 2) - 2.6))) < 0.1)
           & ((X + 3.3) ** 2 + (Y - 3.3) ** 2 < 3.3 ** 2),
           lambda X, Y, Z: np.where(snap(X - Y, 0.4) % 3 == 0, towel_b, towel_w))


@R('GamerPod', 5, 'bed', BW, BW, BH, 'Games Lounge bed: purple pod cushion with a glowing neon stripe')
def _(p):
    g = p.part()
    purple = pick(['#6E56B8', '#664FAE'], 531)
    g.rrbox((-3.2, -3.2, 0), (3.2, 3.2, 0.95), 0.45, purple)
    g.rrbox((-2.5, -2.5, 0.45), (2.5, 2.5, 1.2), 0.3, 0)
    g.carve((-2.5, -2.5, 0.5), (2.5, 2.5, 1.2))
    g.rrbox((-2.5, -2.5, 0.2), (2.5, 2.5, 0.5), 0.3, pick(['#8F79D6', '#8670CC'], 532))
    g.paint((-3.3, -3.3, 0.35), (3.3, 3.3, 0.5), lambda X, Y, Z: (np.abs(X) > 3.0) | (np.abs(Y) > 3.0), glow('#4FF0E8', 2.5))
    for (x, y), c in (((-2.85, -2.85), '#FF5FA2'), ((2.85, -2.85), '#4FF0E8'), ((2.85, 2.85), '#FFE066'), ((-2.85, 2.85), '#7CFF6B')):
        g.ell((x, y, 0.95), (0.22, 0.22, 0.14), glow(c, 2.0))


@R('PlaidBed', 6, 'bed', BW, BW, BH, 'Winter Cabin bed: red tartan flannel bed with a bolster on three sides')
def _(p):
    g = p.part()
    red, red2, green, cream = col('#C8413A'), col('#A8352E'), col('#2F5D3A'), col('#FFF1D6')

    def tartan(X, Y, Z):
        u, v = snap(X + 3.3, 0.6) % 4, snap(Y + 3.3, 0.6) % 4
        out = np.where((u == 0) | (v == 0), red2, red)
        out = np.where((u == 2) & (v == 2), green, out)
        return np.where((u == 0) & (v == 0), cream, out)
    g.rrbox((-3.2, -3.2, 0), (3.2, 3.2, 0.5), 0.2, tartan)
    for a, b in (((-2.85, 2.85), (2.85, 2.85)), ((-2.85, -2.6), (-2.85, 2.85)), ((2.85, -2.6), (2.85, 2.85))):
        g.seg((a[0], a[1], 0.7), (b[0], b[1], 0.7), 0.42, tartan)
    g.rrbox((-2.4, -2.9, 0.3), (2.4, 2.4, 0.55), 0.2, pick(['#F3E3C3', '#EAD7B2'], 541))


@R('DropClothBed', 7, 'bed', BW, BW, BH, 'Art Studio bed: lumpy canvas cushion spattered with paint')
def _(p):
    g = p.part()
    canvas = col('#EFE6D2')
    g.blob((0, 0, 0.35), (3.2, 3.2, 0.55), canvas, amp=0.06, f=1.2, seed=551)
    g.carve((-4, -4, -1), (4, 4, 0))
    g.blob((0, 0.4, 1.0), (2.2, 1.6, 0.5), 0, amp=0.1, seed=552)
    g.carve((-2.2, -2.2, 0.55), (2.2, 2.2, 1.2), lambda X, Y, Z: X * X / 4.4 + Y * Y / 4.4 < 1)
    splats = ['#FF6FA8', '#4FB3B0', '#FFD166', '#9C6ADE', '#5B8DD9']
    rng = np.random.default_rng(55)
    for i in range(14):
        a, r = rng.uniform(0, 2 * math.pi), rng.uniform(0.3, 3.0)
        x, y = math.cos(a) * r, math.sin(a) * r
        s = rng.uniform(0.25, 0.5)
        g.paint((x - s, y - s, 0), (x + s, y + s, 1.2), lambda X, Y, Z, x=x, y=y, s=s: (X - x) ** 2 + (Y - y) ** 2 < s * s, col(splats[i % 5]))
    g.seg((2.2, -2.6, 0.62), (3.0, -1.4, 0.62), 0.12, col('#C98E52'))
    g.ell((1.95, -2.95, 0.62), (0.22, 0.22, 0.16), col('#3B3B44'))


@R('PetalBed', 8, 'bed', BW, BW, BH, 'Rooftop Garden bed: a daisy, white petal cushions round a soft yellow middle')
def _(p):
    g = p.part()
    petal = pick(['#FFFFFF', '#F6F2FF'], 561)
    for i in range(8):
        a = i * math.pi / 4
        x, y = math.cos(a) * 2.25, math.sin(a) * 2.25
        g.ell((x, y, 0.35), (1.2, 1.2, 0.4), petal, cond=lambda X, Y, Z: Z >= 0)
        g.paint((x - 1.2, y - 1.2, 0), (x + 1.2, y + 1.2, 0.8),
                lambda X, Y, Z, x=x, y=y: ((X - x) ** 2 + (Y - y) ** 2 < 0.35) & (Z > 0.5), col('#FFE3F0'))
    g.cyl(0, 0, 0, 0.5, 2.1, pick(['#FFC93C', '#F7B731', '#FFD45E'], 562))
    g.paint((-2.1, -2.1, 0.4), (2.1, 2.1, 0.5), lambda X, Y, Z: (snap(X, 0.4) + snap(Y, 0.4)) % 3 == 0, col('#E89A1E'))
    g.seg((2.6, 2.4, 0.15), (3.2, 3.2, 0.15), 0.15, col('#4E9A35'))
    g.ell((3.0, 2.6, 0.2), (0.35, 0.2, 0.08), col('#55B947'))


@R('MoonCushion', 9, 'bed', BW, BW, BH, 'Starlit Observatory bed: round navy cushion with a crescent moon rim and stitched stars')
def _(p):
    g = p.part()
    navy = pick(['#24346B', '#203060'], 571)
    g.cyl(0, 0, 0, 0.5, 3.0, navy)
    g.ell((0, 0, 0.5), (3.0, 3.0, 0.08), navy)
    moon = pick(['#FFE7A0', '#FFDF8A'], 572)
    g.fill((-3.3, -0.8, 0), (3.3, 3.3, 1.1),
           lambda X, Y, Z: ((X * X + Y * Y) < 3.3 ** 2) & ((X * X + (Y + 1.2) ** 2) > 3.55 ** 2) & (Z < 0.35 + 0.75 * np.clip(1 - (X / 3.3) ** 2, 0, 1)),
           moon)
    for x, y in ((-1.4, -1.2), (0.9, -1.8), (1.6, 0.4), (-0.6, 0.2), (-2.0, -0.1), (0.2, -0.8)):
        g.box((x - 0.1, y - 0.3, 0.5), (x + 0.1, y + 0.3, 0.6), glow('#FFF1B0', 2.0))
        g.box((x - 0.3, y - 0.1, 0.5), (x + 0.3, y + 0.1, 0.6), glow('#FFF1B0', 2.0))


@R('RoyalCushion', 10, 'bed', BW, BW, BH, 'Golden Sky Penthouse bed: round velvet cushion, gold piping, tassels and a tiny crown')
def _(p):
    g = p.part()
    velvet = pick(['#8E2C5A', '#842852', '#972F60'], 581)
    g.cyl(0, 0, 0, 0.45, 3.1, velvet)
    g.ell((0, 0, 0.45), (3.1, 3.1, 0.12), velvet)
    g.paint((-3.2, -3.2, 0), (3.2, 3.2, 0.6), lambda X, Y, Z: (X * X + Y * Y > 2.9 ** 2) & (np.abs(Z - 0.4) < 0.1), col(GOLD))
    for a in (0.785, 2.356, 3.927, 5.498):
        x, y = math.cos(a) * 3.05, math.sin(a) * 3.05
        g.seg((x, y, 0.45), (x * 1.04, y * 1.04, 0.1), 0.14, col(GOLD_D))
        g.ell((x * 1.04, y * 1.04, 0.12), (0.22, 0.22, 0.14), col(GOLD))
    # tiny crown at the back edge
    g.cyl(0, 2.55, 0.5, 0.9, 0.55, col(GOLD))
    g.carve((-0.4, 2.15, 0.65), (0.4, 2.95, 1.0), lambda X, Y, Z: (X * X + (Y - 2.55) ** 2) < 0.4 ** 2)
    for a in range(5):
        t = a * 2 * math.pi / 5
        g.box((math.cos(t) * 0.45 - 0.08, 2.55 + math.sin(t) * 0.45 - 0.08, 0.9), (math.cos(t) * 0.45 + 0.08, 2.55 + math.sin(t) * 0.45 + 0.08, 1.1), col(GOLD))
    g.ell((0, 2.0, 0.72), (0.12, 0.08, 0.12), glow('#FF4F7A', 2.0))


# =================================================================== rugs
# 40 x 20 under the creature grid. Drawn on a 0.4-stud grid; 0.2 thick.
RW, RD, RH = 40.0, 20.0, 0.2


def rug(p, field, border, inner=None, motif=None, frame=1.2, line=0.4):
    """field everywhere, a `border` band `frame` wide, an optional `inner`
    line just inside it, and `motif(X, Y) -> palette or 0` over the field"""
    g = p.part()

    def c(X, Y, Z):
        ex = np.minimum(RW / 2 - np.abs(X), RD / 2 - np.abs(Y))
        out = np.full(X.shape, field, np.int64)
        if motif is not None:
            m = motif(X, Y)
            out = np.where(m > 0, m, out)
        if inner is not None:
            out = np.where((ex >= frame + line) & (ex < frame + 2 * line), inner, out)
        return np.where(ex < frame, border, out)
    g.box((-RW / 2, -RD / 2, 0), (RW / 2, RD / 2, RH), c)
    notch(p)


def notch(p):
    """the back-left corner gives way to the elevator shaft (base X -24..-17,
    Z 17..24; the rug's centre sits at Z 10), with its border turned round it"""
    g = p.part()
    g.carve((-RW / 2, 6.8, 0), (-16.8, RD / 2, 1))


def scatter(cells, step_x, step_y, ox=0.0, oy=0.0):
    """motif centres on a staggered grid, kept off the border"""
    pts = []
    for j, y in enumerate(np.arange(-RD / 2 + 2.8 + oy, RD / 2 - 2.2, step_y)):
        for x in np.arange(-RW / 2 + 2.8 + ox + (step_x / 2 if j % 2 else 0), RW / 2 - 2.2, step_x):
            pts.append((x, y))
    return pts


def stamp(pts, shape):
    """motif function from a list of centres and shape(dx, dy) -> palette or 0"""
    def m(X, Y):
        out = np.zeros(X.shape, np.int64)
        for x, y in pts:
            dx, dy = snap(X - x, 0.4) * 0.4 + 0.2, snap(Y - y, 0.4) * 0.4 + 0.2
            near = (np.abs(dx) < 2) & (np.abs(dy) < 2)
            if near.any():
                s = shape(dx, dy)
                out = np.where(near & (s > 0), s, out)
        return out
    return m


@R('StorytimeRug', 2, 'rug', RW, RD, RH, 'Book Nook rug: deep green, gold border, little open books')
def _(p):
    page, spine = col('#FFF4E0'), col('#C8413A')

    def book(dx, dy):
        inside = (np.abs(dx) < 1.0) & (np.abs(dy) < 0.6)
        return np.where(inside & (np.abs(dx) < 0.2), spine, np.where(inside, page, 0))
    rug(p, col('#2F6B4F'), col(GOLD), inner=col('#1F4D38'), motif=stamp(scatter(None, 6.0, 4.8), book))


@R('LeafyJuteRug', 3, 'rug', RW, RD, RH, 'Plant Sunroom rug: jute with leaf sprigs in the corners and a leaf in the middle')
def _(p):
    leaf, vein = col('#5FA046'), col('#3E7A3A')
    sprigs = [(-16.4, -6.4, 1), (16.4, -6.4, -1), (-16.4, 6.4, 1), (16.4, 6.4, -1)]

    def m(X, Y):
        qx, qy = snap(X, 0.4) * 0.4 + 0.2, snap(Y, 0.4) * 0.4 + 0.2
        out = np.zeros(X.shape, np.int64)
        for x, y, s in sprigs:
            out = np.where((np.abs(qx - x) < 1.4) & (np.abs(qy - y) < 0.6), leaf, out)
            out = np.where((np.abs(qx - x) < 0.6) & (np.abs(qy - y) < 1.4), leaf, out)
        # the middle leaf: a stack of bars, widest in the middle, and its vein
        for k, w in enumerate((0.8, 1.6, 2.4, 2.8, 2.4, 1.6, 0.8)):
            out = np.where((np.abs(qy - (k - 3) * 0.8) < 0.4) & (np.abs(qx) < w), leaf, out)
        out = np.where((np.abs(qy) < 0.2) & (np.abs(qx) < 2.4), vein, out)
        return out
    rug(p, col('#D9BF8C'), col('#8B6B3E'), inner=col('#B8955E'), motif=m)


@R('GinghamRug', 4, 'rug', RW, RD, RH, 'Bakery Kitchen rug: big red and cream gingham checks')
def _(p):
    red, pink, cream = col('#D9534F'), col('#F2A9A3'), col('#FFF4E0')

    def check(X, Y):
        a, b = snap(X + 20, 4.0) % 2 == 0, snap(Y + 10, 4.0) % 2 == 0
        return np.where(a & b, red, np.where(a | b, pink, cream))
    rug(p, cream, col('#B5302B'), motif=check, frame=0.8)


@R('ArcadeCarpet', 5, 'rug', RW, RD, RH, 'Games Lounge rug: navy arcade carpet with glowing neon shapes')
def _(p):
    shapes = [glow('#4FF0E8', 1.2), glow('#FF5FA2', 1.2), glow('#FFE066', 1.2), glow('#7CFF6B', 1.2)]
    pts = [(-14, -5), (-6, 4.8), (2, -4.8), (10, 4.8), (16, -3), (-16, 4), (-6, -2), (6, 1), (14, 4), (-11, 0.4), (1, 6), (0, -1.2)]

    def m(X, Y):
        out = np.zeros(X.shape, np.int64)
        for i, (x, y) in enumerate(pts):
            dx, dy = snap(X - x, 0.4) * 0.4 + 0.2, snap(Y - y, 0.4) * 0.4 + 0.2
            k = i % 4
            if k == 0:  # square ring
                s = (np.maximum(np.abs(dx), np.abs(dy)) < 1.0) & (np.maximum(np.abs(dx), np.abs(dy)) > 0.5)
            elif k == 1:  # stepped triangle
                s = (dy > -0.8) & (dy < 0.8) & (np.abs(dx) < (0.8 - dy) * 0.6)
            elif k == 2:  # lightning bolt
                s = ((np.abs(dx + 0.2) < 0.25) & (dy > 0) & (dy < 1.0)) | ((np.abs(dy) < 0.2) & (np.abs(dx) < 0.45)) | ((np.abs(dx - 0.2) < 0.25) & (dy < 0) & (dy > -1.0))
            else:  # plus
                s = ((np.abs(dx) < 0.25) & (np.abs(dy) < 0.85)) | ((np.abs(dy) < 0.25) & (np.abs(dx) < 0.85))
            out = np.where(s, shapes[k], out)
        return out
    rug(p, col('#3B2A7A'), col('#FF5FA2'), inner=col('#4FB3B0'), motif=m)


@R('BraidedRug', 6, 'rug', RW, RD, RH, 'Winter Cabin rug: braided rag rug in bands of navy, cream, denim and pine')
def _(p):
    # cool bands, so the red plaid beds stand out on it
    cs = [col('#34507A'), col('#FFF1D6'), col('#2F5D3A'), col('#6F92C4'), col('#E8D3B0')]

    def m(X, Y):
        ex = np.minimum(RW / 2 - np.abs(X), RD / 2 - np.abs(Y))
        band = snap(ex, 1.2).astype(int)
        out = np.zeros(X.shape, np.int64)
        for k in range(1, 9):
            out = np.where(band == k, cs[k % len(cs)], out)
        return out
    rug(p, col('#E8D3B0'), col('#5A3A22'), motif=m)


@R('SplatterRug', 7, 'rug', RW, RD, RH, 'Art Studio rug: canvas drop cloth with big paint splats')
def _(p):
    splats = [col('#FF6FA8'), col('#4FB3B0'), col('#FFD166'), col('#9C6ADE'), col('#5B8DD9')]
    blobs = [(-15, -4, 1.6), (-9, 5, 1.2), (-3, -6, 1.0), (2, 3, 1.8), (8, -5, 1.2), (13, 5, 1.4), (17, -2, 0.8), (-17, 6, 0.8), (-5, 1, 0.8), (10, 0.5, 0.8)]

    def m(X, Y):
        out = np.zeros(X.shape, np.int64)
        qx, qy = snap(X, 0.4) * 0.4 + 0.2, snap(Y, 0.4) * 0.4 + 0.2
        for i, (x, y, r) in enumerate(blobs):
            c = splats[i % 5]
            body = (np.abs(qx - x) < r) & (np.abs(qy - y) < r * 0.6) | (np.abs(qx - x) < r * 0.6) & (np.abs(qy - y) < r)
            drop = (np.abs(qx - (x + r * 1.5)) < 0.3) & (np.abs(qy - (y - r * 0.4)) < 0.3)
            out = np.where(body | drop, c, out)
        return out
    rug(p, col('#EFE6D2'), col('#D8CCB2'), motif=m, frame=0.4)


@R('CloverLawn', 8, 'rug', RW, RD, RH, 'Rooftop Garden rug: soft clover turf with stepping stones and daisies')
def _(p):
    stone, daisy, eye = col('#D8D2C4'), col('#FFFFFF'), col('#FFC93C')
    stones = [(-14, 0), (-7, 3), (0, -1), (7, 3), (14, 0)]

    def m(X, Y):
        qx, qy = snap(X, 0.4) * 0.4 + 0.2, snap(Y, 0.4) * 0.4 + 0.2
        out = np.zeros(X.shape, np.int64)
        for x, y in stones:
            out = np.where((np.abs(qx - x) < 1.8) & (np.abs(qy - y) < 1.0) | (np.abs(qx - x) < 1.0) & (np.abs(qy - y) < 1.4), stone, out)
        for x, y in ((-10, -6), (4, 6), (11, -5), (-3, 7), (17, 6), (-17, -6)):
            out = np.where((np.abs(qx - x) < 0.6) & (np.abs(qy - y) < 0.6), daisy, out)
            out = np.where((np.abs(qx - x) < 0.2) & (np.abs(qy - y) < 0.2), eye, out)
        return out
    # a light spring lawn edged in pale stone, so it reads on the green floor
    rug(p, col('#B4E070'), col('#F1EBDC'), inner=col('#97CF55'), motif=m, frame=0.8)


@R('StarChartRug', 9, 'rug', RW, RD, RH, 'Starlit Observatory rug: indigo star chart with gold stars and a moon')
def _(p):
    star, small = glow('#FFF1B0', 1.5), col(GOLD_D)
    big = [(-15, -4), (-12, 1), (-8, -2), (-5, 3), (3, -5), (6, -1), (10, -4), (14, 1), (16, 5), (-17, 6)]
    tiny = [(-3, 5), (1, 6), (-2, -6), (8, 6), (17, -6), (-6, -7), (12, -7), (-10, 6)]

    def m(X, Y):
        qx, qy = snap(X, 0.4) * 0.4 + 0.2, snap(Y, 0.4) * 0.4 + 0.2
        out = np.zeros(X.shape, np.int64)
        for x, y in big:
            out = np.where(((np.abs(qx - x) < 0.25) & (np.abs(qy - y) < 0.65)) | ((np.abs(qy - y) < 0.25) & (np.abs(qx - x) < 0.65)), star, out)
        for x, y in tiny:
            out = np.where((np.abs(qx - x) < 0.25) & (np.abs(qy - y) < 0.25), small, out)
        moon = ((qx * qx + qy * qy) < 2.0 ** 2) & (((qx - 0.8) ** 2 + (qy - 0.4) ** 2) > 1.7 ** 2)
        return np.where(moon, star, out)
    # a brighter indigo than the navy floor, so the chart reads
    rug(p, col('#4A4FB0'), col(GOLD), inner=col('#3A3F96'), motif=m)


@R('GoldKeyRug', 10, 'rug', RW, RD, RH, 'Golden Sky Penthouse rug: royal blue plush, gold border, gold dashes and a gold medallion')
def _(p):
    gold = col(GOLD)

    def m(X, Y):
        ex = np.minimum(RW / 2 - np.abs(X), RD / 2 - np.abs(Y))
        qx, qy = snap(X, 0.4) * 0.4 + 0.2, snap(Y, 0.4) * 0.4 + 0.2
        u = np.where(np.abs(Y) > RD / 2 - 3.2, X, Y)
        dash = (ex >= 1.6) & (ex < 2.4) & (snap(u + 50, 0.4) % 10 < 4)
        line = (ex >= 2.8) & (ex < 3.2)
        sq = np.maximum(np.abs(qx), np.abs(qy) * 1.0)
        med = ((sq < 2.4) & (sq > 2.0)) | (sq < 1.2) & (sq > 0.8) | (sq < 0.3)
        return np.where(dash | line | med, gold, 0)
    # royal blue on the cream floor; the wine cushions stand out on it
    rug(p, col('#2E4A9A'), col(GOLD_D), motif=m, frame=0.8)


# ======================================================== ceiling lights
# Hung from the ceiling (their top at the ceiling); 3 x 3 x up to 2.8 studs.

def chain(g, x, y, z0, z1, c):
    for z in np.arange(z0, z1, 0.4):
        g.box((x - 0.1, y - 0.1, z), (x + 0.1, y + 0.1, min(z + 0.25, z1)), c)


@R('ReadingPendant', 2, 'ceiling', 2.4, 2.4, 2.6, 'Book Nook ceiling light: brass rod and a green glass shade')
def _(p):
    g = p.part()
    g.cyl(0, 0, 2.4, 2.6, 0.45, col('#B8892E'))
    g.box((-0.2, -0.2, 1.2), (0.2, 0.2, 2.4), col('#B8892E'))
    g.cyl(0, 0, 0.6, 1.3, 1.15, col('#2F7A4E'), r1=0.35)
    g.carve((-1.1, -1.1, 0.6), (1.1, 1.1, 1.1), lambda X, Y, Z: X * X + Y * Y < (1.0 - (Z - 0.6) * 1.2) ** 2)
    g.paint((-1.2, -1.2, 0.6), (1.2, 1.2, 0.75), None, col('#B8892E'))
    s = p.part('bulb', anim='pulse', parent='body')
    s.ell((0, 0, 0.75), (0.45, 0.45, 0.35), glow(WARM, 3.0))


@R('IvyHanger', 3, 'ceiling', 2.6, 2.6, 2.8, 'Plant Sunroom ceiling light: macrame hanger, ivy pot and a glowing globe')
def _(p):
    g = p.part()
    cord = col('#F3E3C3')
    g.cyl(0, 0, 2.55, 2.8, 0.3, cord)
    for a in range(3):
        t = a * 2 * math.pi / 3
        g.seg((0, 0, 2.6), (math.cos(t) * 0.8, math.sin(t) * 0.8, 1.15), 0.17, cord)
    g.cyl(0, 0, 0.75, 1.25, 0.8, col('#E8EEF0'), r1=0.95)
    ivy = pick(['#3E9A3A', '#55B947', '#2F7A2E'], 591)
    g.blob((0, 0, 1.3), (0.95, 0.95, 0.3), ivy, amp=0.2, seed=592)
    for a in range(5):
        t = a * 2 * math.pi / 5 + 0.4
        x, y = math.cos(t) * 0.95, math.sin(t) * 0.95
        g.seg((x, y, 1.2), (x * 1.15, y * 1.15, 0.2 + 0.2 * (a % 2)), 0.14, ivy)
    s = p.part('globe', anim='pulse', parent='body')
    s.ell((0, 0, 0.42), (0.35, 0.35, 0.35), glow(WARM, 3.0))


@R('CopperPendant', 4, 'ceiling', 2.6, 2.6, 2.4, 'Bakery Kitchen ceiling light: copper dome with a warm glow')
def _(p):
    g = p.part()
    copper = pick(['#C8763A', '#B96A31', '#D9874A'], 601)
    g.box((-0.2, -0.2, 1.3), (0.2, 0.2, 2.4), col(IRON))
    g.cyl(0, 0, 2.25, 2.4, 0.4, copper)
    g.ell((0, 0, 0.5), (1.25, 1.25, 0.95), copper, cond=lambda X, Y, Z: Z >= 0.5)
    g.carve((-1.2, -1.2, 0.4), (1.2, 1.2, 1.25), lambda X, Y, Z: (X / 1.1) ** 2 + (Y / 1.1) ** 2 + ((Z - 0.5) / 0.8) ** 2 < 1)
    g.cyl(0, 0, 1.35, 1.5, 0.3, copper)
    s = p.part('bulb', anim='pulse', parent='body')
    s.ell((0, 0, 0.6), (0.6, 0.6, 0.35), glow(WARM, 3.5))


@R('NeonRing', 5, 'ceiling', 3.0, 3.0, 2.4, 'Games Lounge ceiling light: two glowing neon rings, cyan and pink')
def _(p):
    g = p.part()
    g.cyl(0, 0, 2.2, 2.4, 0.4, col('#2E3A6B'))
    for a in range(3):
        t = a * 2 * math.pi / 3
        g.seg((0, 0, 2.3), (math.cos(t) * 1.4, math.sin(t) * 1.4, 0.6), 0.16, col('#B0BEC5'))
    r = p.part('rings', anim='turn', parent='body')
    ring(r, 0, 0, 0.45, 0.75, 1.5, 1.2, glow('#4FF0E8', 3.0))
    ring(r, 0, 0, 1.05, 1.3, 0.95, 0.7, glow('#FF5FA2', 3.0))


@R('LanternChandelier', 6, 'ceiling', 3.0, 3.0, 2.8, 'Winter Cabin ceiling light: iron ring of candles on chains')
def _(p):
    g = p.part()
    iron = col(IRON)
    g.cyl(0, 0, 2.6, 2.8, 0.35, iron)
    for a in range(3):
        t = a * 2 * math.pi / 3
        g.seg((0, 0, 2.6), (math.cos(t) * 1.3, math.sin(t) * 1.3, 0.75), 0.17, iron)
    ring(g, 0, 0, 0.5, 0.75, 1.45, 1.15, iron)
    s = p.part('flames', anim='flicker', parent='body')
    for a in range(6):
        t = a * math.pi / 3
        x, y = math.cos(t) * 1.3, math.sin(t) * 1.3
        g.cyl(x, y, 0.75, 1.35, 0.17, col('#FFF4E0'))
        s.ell((x, y, 1.5), (0.12, 0.12, 0.2), glow('#FFB347', 4.0))


@R('StudioSpot', 7, 'ceiling', 2.6, 2.6, 2.4, 'Art Studio ceiling light: white cone spot on a short rod')
def _(p):
    g = p.part()
    white = pick(['#FAFAF5', '#EFEFEA'], 611)
    g.box((-0.2, -0.2, 1.4), (0.2, 0.2, 2.4), col('#3B3B44'))
    g.cyl(0, 0, 2.25, 2.4, 0.45, col('#3B3B44'))
    g.cyl(0, 0, 0.3, 1.5, 1.2, white, r1=0.4)
    g.carve((-1.2, -1.2, 0.3), (1.2, 1.2, 1.0), lambda X, Y, Z: X * X + Y * Y < (1.05 - (Z - 0.3) * 0.9) ** 2)
    g.paint((-1.3, -1.3, 0.3), (1.3, 1.3, 0.45), None, col('#9C6ADE'))
    s = p.part('bulb', anim='pulse', parent='body')
    s.cyl(0, 0, 0.45, 0.65, 0.8, glow('#FFFFFF', 3.0))


@R('PaperLanterns', 8, 'ceiling', 3.0, 1.2, 2.8, 'Rooftop Garden ceiling light: three round paper lanterns on a string')
def _(p):
    g = p.part()
    g.box((-1.4, -0.2, 2.4), (1.4, 0.2, 2.8), col('#8B5A33'))
    s = p.part('lanterns', anim='sway', parent='body', pivot=(0, 0, 2.7))
    for x, z, c in ((-1.0, 1.0, '#FF8FB1'), (0, 0.55, '#FFE066'), (1.0, 1.15, '#8FE3C5')):
        s.box((x - 0.15, -0.15, z + 0.4), (x + 0.15, 0.15, 2.6), col('#3B3B44'))
        s.ell((x, 0, z), (0.5, 0.5, 0.45), glow(c, 2.2))
        s.paint((x - 0.5, -0.5, z - 0.45), (x + 0.5, 0.5, z + 0.45), lambda X, Y, Z, z=z: np.abs(Z - z) % 0.3 < 0.06, col('#FFFFFF'))


@R('StarCluster', 9, 'ceiling', 3.0, 3.0, 2.8, 'Starlit Observatory ceiling light: glowing star orbs floating under the ceiling')
def _(p):
    g = p.part()
    g.cyl(0, 0, 2.6, 2.8, 0.5, col('#141C40'))
    g.paint((-0.5, -0.5, 2.6), (0.5, 0.5, 2.8), lambda X, Y, Z: X * X + Y * Y < 0.15, glow('#FFF1B0', 2.0))
    s = p.part('stars', anim='bob', parent='body')
    for x, y, z, r, c in ((-0.9, -0.3, 1.6, 0.35, '#FFF1B0'), (0.8, 0.5, 1.1, 0.45, '#BFD7FF'), (0.1, -0.8, 0.5, 0.3, '#FFF1B0'),
                          (-0.2, 0.9, 2.0, 0.25, '#D9C2FF'), (1.1, -0.9, 1.9, 0.22, '#FFF1B0')):
        s.ell((x, y, z), (r, r, r), glow(c, 3.0))
        s.box((x - 0.06, y - r - 0.25, z - 0.06), (x + 0.06, y + r + 0.25, z + 0.06), glow(c, 2.0))
        s.box((x - r - 0.25, y - 0.06, z - 0.06), (x + r + 0.25, y + 0.06, z + 0.06), glow(c, 2.0))


@R('CrystalChandelier', 10, 'ceiling', 3.0, 3.0, 2.8, 'Golden Sky Penthouse ceiling light: gold and crystal chandelier')
def _(p):
    g = p.part()
    gold = col(GOLD)
    g.cyl(0, 0, 2.6, 2.8, 0.45, gold)
    g.box((-0.2, -0.2, 1.5), (0.2, 0.2, 2.6), gold)
    ring(g, 0, 0, 1.0, 1.2, 1.45, 1.2, gold)
    ring(g, 0, 0, 1.6, 1.75, 0.8, 0.6, gold)
    g.ell((0, 0, 1.15), (0.35, 0.35, 0.45), gold)
    s = p.part('crystals', anim='glint', parent='body')
    for a in range(8):
        t = a * math.pi / 4
        x, y = math.cos(t) * 1.32, math.sin(t) * 1.32
        s.ell((x, y, 0.65), (0.14, 0.14, 0.32), glow('#DDF3FF', 2.5))
        g.cyl(x, y, 1.2, 1.5, 0.12, col('#FFF4E0'))
        s.ell((x, y, 1.62), (0.09, 0.09, 0.15), glow('#FFC870', 4.0))
    s.ell((0, 0, 0.45), (0.25, 0.25, 0.4), glow('#DDF3FF', 2.5))


# ================================================================ plants
# Big corner plants, about 2.6 x 2.6 x 5.

def pot(g, r0, r1, h, c, rim=None):
    g.cyl(0, 0, 0, h, r0, c, r1=r1)
    if rim is not None:
        g.cyl(0, 0, h - 0.3, h, r1 + 0.12, rim)
    g.carve((-r1, -r1, h - 0.25), (r1, r1, h + 0.1), lambda X, Y, Z: X * X + Y * Y < (r1 - 0.15) ** 2)
    g.cyl(0, 0, h - 0.4, h - 0.2, r1 - 0.15, col('#5A3A22'))


@R('FiddleLeafFig', 2, 'plant', 2.8, 2.8, 5.4, 'Book Nook plant: fiddle-leaf fig in a terracotta pot')
def _(p):
    g = p.part()
    pot(g, 0.85, 1.1, 1.4, pick(['#C96F45', '#BF6640'], 621), col('#B25D38'))
    g.seg((0, 0, 1.2), (0.1, 0.05, 4.2), 0.18, col('#7A4D2B'))
    leaf = pick(['#3E8A3A', '#4E9E45', '#357A32'], 622)
    rng = np.random.default_rng(62)
    for i in range(13):
        t = i * 2.4
        z = 2.0 + i * 0.25
        r = 0.6 + 0.4 * rng.random()
        x, y = math.cos(t) * r, math.sin(t) * r
        g.ell((x, y, z), (0.55, 0.55, 0.42), leaf, cond=lambda X, Y, Z, x=x, y=y, z=z: np.abs((X - x) * math.sin(t) - (Y - y) * math.cos(t)) < 0.18 + 0.4 * (1 - np.abs(Z - z) / 0.42))
        g.seg((x * 0.2, y * 0.2, z - 0.3), (x * 0.8, y * 0.8, z - 0.1), 0.14, col('#7A4D2B'))


@R('MonsteraPot', 3, 'plant', 3.2, 3.2, 4.8, 'Plant Sunroom plant: monstera with split leaves in a white pot')
def _(p):
    g = p.part()
    pot(g, 0.8, 1.0, 1.3, pick(['#FAFAF5', '#EFEFEA'], 631))
    g.paint((-1.2, -1.2, 0.5), (1.2, 1.2, 0.7), None, col('#4FB3B0'))
    leaf, vein = pick(['#2F8A3E', '#37964A'], 632), col('#5DB86A')
    for i, (t, z, L) in enumerate(((0.3, 3.6, 1.5), (2.2, 3.2, 1.4), (4.0, 3.9, 1.4), (5.3, 2.8, 1.3), (1.2, 4.3, 1.2), (3.2, 2.5, 1.1))):
        cx, cy = math.cos(t) * L * 0.75, math.sin(t) * L * 0.75
        g.seg((0, 0, 1.2), (cx * 0.8, cy * 0.8, z - 0.1), 0.16, col('#3E7A3A'))
        g.ell((cx, cy, z), (0.85, 0.85, 0.16), leaf)
        # the splits: slots cut in from the edge
        g.carve((cx - 0.9, cy - 0.9, z - 0.2), (cx + 0.9, cy + 0.9, z + 0.2),
                lambda X, Y, Z, cx=cx, cy=cy: (np.sqrt((X - cx) ** 2 + (Y - cy) ** 2) > 0.45) & (np.abs(np.sin(np.arctan2(Y - cy, X - cx) * 4)) < 0.22))
        g.paint((cx - 0.9, cy - 0.9, z - 0.2), (cx + 0.9, cy + 0.9, z + 0.2),
                lambda X, Y, Z, cx=cx, cy=cy, t=t: np.abs((X - cx) * math.sin(t) - (Y - cy) * math.cos(t)) < 0.07, vein)


@R('LemonTree', 4, 'plant', 2.8, 2.8, 5.0, 'Bakery Kitchen plant: little lemon tree in a blue-glazed pot')
def _(p):
    g = p.part()
    pot(g, 0.8, 1.05, 1.4, pick(['#3D6FB5', '#3566AB'], 641), col('#FFFFFF'))
    g.paint((-1.2, -1.2, 0.6), (1.2, 1.2, 0.8), lambda X, Y, Z: snap(np.arctan2(Y, X) * 3, 1) % 2 == 0, col('#FFFFFF'))
    g.seg((0, 0, 1.2), (0, 0, 3.0), 0.22, col('#7A4D2B'))
    leaf = pick(['#3E9A3A', '#55B947', '#37903A'], 642)
    g.blob((0, 0, 3.7), (1.25, 1.25, 1.15), leaf, amp=0.12, f=2.0, seed=643)
    rng = np.random.default_rng(64)
    for _ in range(11):
        a, e = rng.uniform(0, 2 * math.pi), rng.uniform(-0.5, 0.7)
        x, y, z = math.cos(a) * 1.3 * math.cos(e), math.sin(a) * 1.3 * math.cos(e), 3.7 + 1.1 * math.sin(e)
        g.ell((x, y, z), (0.2, 0.2, 0.24), col('#FFE14A'))


@R('SnakePlant', 5, 'plant', 2.4, 2.4, 4.6, 'Games Lounge plant: snake plant in a pot with a neon band')
def _(p):
    g = p.part()
    pot(g, 0.85, 0.95, 1.5, pick(['#2E3A6B', '#283462'], 651))
    g.paint((-1.1, -1.1, 0.6), (1.1, 1.1, 0.8), None, glow('#FF5FA2', 2.5))
    dark, light, edge = col('#2F6B3A'), col('#4E9A55'), col('#E8D86A')
    for i in range(9):
        t = i * 2.4
        r = 0.25 + 0.3 * (i % 3) / 2
        x, y = math.cos(t) * r, math.sin(t) * r
        top = 3.2 + 1.2 * ((i * 7) % 5) / 4
        lean = 0.12 * (i % 3)
        g.fill((x - 0.5, y - 0.5, 1.3), (x + 0.5 + lean, y + 0.5 + lean, top),
               lambda X, Y, Z, x=x, y=y, t=t, top=top, lean=lean: (np.abs((X - x - lean * (Z - 1.3) / 3) * math.sin(t) - (Y - y) * math.cos(t)) < 0.32 * np.clip((top - Z) / 1.0, 0.15, 1))
               & (np.abs((X - x) * math.cos(t) + (Y - y) * math.sin(t)) < 0.1),
               lambda X, Y, Z, top=top: np.where(Z > top - 0.25, edge, np.where(snap(Z, 0.4) % 2 == 0, dark, light)))


@R('SnowyPine', 6, 'plant', 2.8, 2.8, 5.2, 'Winter Cabin plant: little potted pine with snow on its branches')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 1.2, 0.9, pick(WOOD_D, 661), r1=1.0)
    for z in (0.25, 0.9):
        g.paint((-1.1, -1.1, z), (1.1, 1.1, z + 0.15), None, col(IRON))
    g.box((-0.15, -0.15, 1.0), (0.15, 0.15, 1.6), col('#7A4D2B'))
    pine = pick(['#1F6F45', '#2E8A55', '#1C6840'], 662)
    snow = col('#F4FAFF')
    for z0, r in ((1.4, 1.35), (2.4, 1.05), (3.3, 0.75), (4.1, 0.45)):
        g.cyl(0, 0, z0, z0 + 1.1, r, pine, r1=0.08)
        g.paint((-r, -r, z0), (r, r, z0 + 1.1), lambda X, Y, Z, z0=z0, r=r: (Z > z0 + 0.15) & (hnoise(X, Y, Z, 663) > 0.55) & (X * X + Y * Y > (r * 0.55 * (1 - (Z - z0) / 1.1)) ** 2), snow)
    g.ell((0, 0, 5.05), (0.22, 0.22, 0.22), glow('#FFE066', 2.0))


@R('PaintBucketPothos', 7, 'plant', 2.8, 2.8, 4.0, 'Art Studio plant: pothos trailing out of a paint bucket')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 1.5, 0.85, col('#E8E8EE'), r1=0.95)
    g.carve((-1, -1, 1.25), (1, 1, 1.6), lambda X, Y, Z: X * X + Y * Y < 0.8 ** 2)
    g.cyl(0, 0, 1.0, 1.3, 0.8, col('#5A3A22'))
    for t, c in ((0.4, '#FF6FA8'), (2.3, '#4FB3B0'), (4.2, '#FFD166')):
        g.paint((-1.1, -1.1, 0.2), (1.1, 1.1, 1.5),
                lambda X, Y, Z, t=t: (np.abs(np.arctan2(Y, X) - t) < 0.25) & (Z > 1.5 - 0.9 * (1 - np.abs(np.arctan2(Y, X) - t) / 0.25)), col(c))
    g.seg((-0.9, 0, 1.5), (0.9, 0, 1.5), 0.15, col('#8A8A94'))
    leaf = pick(['#3E9A3A', '#55B947', '#C9D94A'], 671)
    g.blob((0, 0, 2.2), (1.05, 1.05, 0.85), leaf, amp=0.2, f=2.5, seed=672)
    for i in range(6):
        t = i * 1.05 + 0.2
        x, y = math.cos(t), math.sin(t)
        pts = [(x * (1.0 + 0.15 * k), y * (1.0 + 0.15 * k), 1.8 - 0.35 * k) for k in range(5)]
        for a, b in zip(pts, pts[1:]):
            g.seg(a, b, 0.15, col('#3E7A3A'))
        for a in pts[1:]:
            g.ell(a, (0.24, 0.24, 0.16), leaf)


@R('SunflowerPot', 8, 'plant', 2.8, 2.8, 5.8, 'Rooftop Garden plant: three sunflowers in a tall terracotta pot')
def _(p):
    g = p.part()
    pot(g, 0.8, 1.05, 1.6, pick(['#C96F45', '#BF6640'], 681), col('#B25D38'))
    stem, leaf = col('#3E8A3A'), pick(['#4E9E45', '#55B947'], 682)
    for i, (dx, dy, h, t) in enumerate(((-0.35, 0.1, 5.0, -0.3), (0.4, -0.15, 4.4, 0.4), (0.0, 0.4, 3.8, 0.1))):
        g.seg((dx * 0.3, dy * 0.3, 1.3), (dx, dy, h), 0.17, stem)
        g.ell((dx + 0.35, dy, h - 1.5), (0.4, 0.15, 0.2), leaf)
        g.ell((dx - 0.35, dy, h - 2.1), (0.4, 0.15, 0.2), leaf)
        # faces turned to the front (-y)
        fy = dy - 0.15
        g.fill((dx - 0.8, fy - 0.2, h - 0.8), (dx + 0.8, fy + 0.2, h + 0.8),
               lambda X, Y, Z, dx=dx, h=h: ((X - dx) ** 2 + (Z - h) ** 2 < 0.75 ** 2) & (np.abs(np.sin(np.arctan2(Z - h, X - dx) * 6)) > 0.25) | ((X - dx) ** 2 + (Z - h) ** 2 < 0.45 ** 2),
               lambda X, Y, Z, dx=dx, h=h: np.where((X - dx) ** 2 + (Z - h) ** 2 < 0.4 ** 2, col('#6B3E1F'), col('#FFC93C')))


@R('Moonflower', 9, 'plant', 2.6, 2.6, 4.8, 'Starlit Observatory plant: crystal moonflowers that glow, in a starry pot')
def _(p):
    g = p.part()
    pot(g, 0.85, 1.0, 1.4, pick(['#1E2A5A', '#24346B'], 691), col(GOLD))
    g.paint((-1.1, -1.1, 0.2), (1.1, 1.1, 1.1), lambda X, Y, Z: hnoise(X, Y, Z, 692) > 0.96, glow('#FFF1B0', 2.0))
    stem = col('#5E7FB8')
    s = p.part('flowers', anim='pulse', parent='body')
    for i, (t, h) in enumerate(((0.3, 4.4), (2.4, 3.7), (4.3, 4.0), (1.4, 3.2), (5.2, 3.0))):
        x, y = math.cos(t) * 0.55, math.sin(t) * 0.55
        g.seg((x * 0.3, y * 0.3, 1.2), (x, y, h - 0.3), 0.17, stem)
        g.ell((x * 1.4, y * 1.4, h - 1.3), (0.35, 0.35, 0.12), col('#3E5F9A'))
        s.cyl(x, y, h - 0.4, h + 0.1, 0.12, glow('#BFE9FF', 2.5), r1=0.5)
        s.ell((x, y, h - 0.3), (0.13, 0.13, 0.13), glow('#FFF1B0', 3.0))


@R('GoldTopiary', 10, 'plant', 2.8, 2.8, 5.6, 'Golden Sky Penthouse plant: spiral topiary with gold leaves in a marble urn')
def _(p):
    g = p.part()
    marble = pick(['#FFF8EC', '#EADFC8', '#F3EBDD'], 701)
    g.cyl(0, 0, 0, 0.3, 0.75, marble)
    g.cyl(0, 0, 0.3, 0.6, 0.35, marble)
    g.cyl(0, 0, 0.6, 1.6, 0.6, marble, r1=1.1)
    g.cyl(0, 0, 1.45, 1.65, 1.2, col(GOLD))
    g.carve((-1, -1, 1.5), (1, 1, 1.7), lambda X, Y, Z: X * X + Y * Y < 0.95 ** 2)
    g.box((-0.12, -0.12, 1.5), (0.12, 0.12, 2.3), col('#7A4D2B'))
    leaf = pick(['#3E9A3A', '#55B947'], 702)
    gold = col(GOLD, 0.6)
    g.fill((-1.2, -1.2, 2.1), (1.2, 1.2, 5.3),
           lambda X, Y, Z: (X * X + Y * Y < (1.15 * (5.3 - Z) / 3.2) ** 2 + 0.05) & (np.sin(Z * 4.5 - np.arctan2(Y, X)) > -0.35),
           lambda X, Y, Z: np.where(np.sin(Z * 4.5 - np.arctan2(Y, X)) > 0.55, gold, leaf(X, Y, Z)))
    s = p.part('star', anim='glint', parent='body')
    s.ell((0, 0, 5.4), (0.22, 0.22, 0.22), glow('#FFE066', 3.0))


# ================================================================ crests
# The "fully furnished" badge: a shield on the back wall above the
# pictures, 3 wide, 2.6 tall, 0.6 deep; back at +y against the wall. Drawn
# in three 0.2-stud layers (gold back, coloured field, glowing emblem) and
# the emblem as a flat picture on a 0.2 grid, so the Parts version keeps it.
CW, CD, CH = 3.0, 0.6, 2.6


def q(v):
    return snap(v, 0.2) * 0.2 + 0.1


def crest(p, field, emblem, rim=GOLD):
    """emblem(X, Z) -> palette index or 0, X across, Z up (0..2.6)"""
    g = p.part()

    def inside(X, Z, m):
        w = 1.5 - m
        return (Z >= m) & (Z <= 2.3 - m * 0.5) & (np.abs(X) <= np.where(Z > 1.0, w, w * np.sqrt(np.clip((Z - m) / (1.0 - m), 0, 1)) + 0.1))
    g.fill((-1.5, 0.1, 0), (1.5, 0.3, 2.6), lambda X, Y, Z: inside(X, Z, 0.0), col(rim))
    g.fill((-1.5, -0.1, 0), (1.5, 0.1, 2.6), lambda X, Y, Z: inside(X, Z, 0.2), col(field))
    g.fill((-1.5, -0.1, 0), (1.5, 0.1, 2.6), lambda X, Y, Z: inside(X, Z, 0.0) & ~inside(X, Z, 0.2), col(rim))
    g.box((-1.6, -0.1, 2.2), (1.6, 0.3, 2.6), col(GOLD_D))
    g.box((-0.2, -0.3, 2.2), (0.2, -0.1, 2.6), glow('#FF4F7A', 2.0))
    e = p.part('emblem', anim='pulse', parent='body')

    def m(X, Y, Z):
        return emblem(q(X), q(Z)) > 0
    e.fill((-1.3, -0.3, 0.2), (1.3, -0.1, 2.2), lambda X, Y, Z: m(X, Y, Z) & inside(X, Z, 0.2), lambda X, Y, Z: emblem(q(X), q(Z)))


def shape(*layers):
    """emblem from (mask(X, Z), colour) layers, later ones on top"""
    def f(X, Z):
        out = np.zeros(X.shape, np.int64)
        for mk, c in layers:
            out = np.where(mk(X, Z), c, out)
        return out
    return f


@R('BookCrest', 2, 'crest', CW, CD, CH, 'Book Nook crest: an open book that glows')
def _(p):
    page, spine, line = glow('#FFF4E0', 1.6), col('#C8413A'), col('#7A4D2B')
    crest(p, '#2F6B4F', shape(
        (lambda X, Z: (np.abs(X) < 0.95) & (Z > 0.8) & (Z < 1.75 - 0.15 * (np.abs(X) < 0.5)), page),
        (lambda X, Z: (np.abs(X) < 0.15) & (Z > 0.7) & (Z < 1.7), spine),
        (lambda X, Z: (np.abs(X) > 0.3) & (np.abs(X) < 0.8) & ((np.abs(Z - 1.1) < 0.1) | (np.abs(Z - 1.4) < 0.1)), line)))


@R('LeafCrest', 3, 'crest', CW, CD, CH, 'Plant Sunroom crest: a sun over a leaf')
def _(p):
    crest(p, '#3E7A5A', shape(
        (lambda X, Z: (np.abs(X) + np.abs(Z - 1.75) < 0.75) & ((np.abs(X) < 0.15) | (np.abs(Z - 1.75) < 0.15) | (np.abs(np.abs(X) - np.abs(Z - 1.75)) < 0.15)), glow('#FFD166', 2.0)),
        (lambda X, Z: X * X + (Z - 1.75) ** 2 < 0.3 ** 2, glow('#FFE7A0', 2.5)),
        (lambda X, Z: (X / 0.5) ** 2 + ((Z - 0.85) / 0.5) ** 2 < 1, col('#7DCB55')),
        (lambda X, Z: (np.abs(X) < 0.1) & (Z < 1.25) & (Z > 0.4), col('#2F7A2E'))))


@R('CupcakeCrest', 4, 'crest', CW, CD, CH, 'Bakery Kitchen crest: a cupcake with a cherry')
def _(p):
    crest(p, '#D9534F', shape(
        (lambda X, Z: (Z > 0.5) & (Z < 1.1) & (np.abs(X) < 0.35 + (Z - 0.5) * 0.4), col('#E3B878')),
        (lambda X, Z: (Z > 0.5) & (Z < 1.1) & (np.abs(X) < 0.35 + (Z - 0.5) * 0.4) & (snap(X + 2, 0.2) % 2 == 0), col('#C9955A')),
        (lambda X, Z: (Z >= 1.1) & ((X / 0.7) ** 2 + ((Z - 1.1) / 0.6) ** 2 < 1), glow('#FFB3CC', 1.4)),
        (lambda X, Z: X * X + (Z - 1.85) ** 2 < 0.18 ** 2, glow('#E8413C', 1.5))))


@R('GamepadCrest', 5, 'crest', CW, CD, CH, 'Games Lounge crest: a neon game pad')
def _(p):
    dark = col('#1E2550')
    crest(p, '#1E2550', shape(
        (lambda X, Z: ((np.abs(X) < 0.6) & (np.abs(Z - 1.2) < 0.35)) | (((np.abs(X) - 0.6) ** 2 + (Z - 1.1) ** 2) < 0.4 ** 2), glow('#4FF0E8', 2.0)),
        (lambda X, Z: ((np.abs(X + 0.6) < 0.3) & (np.abs(Z - 1.2) < 0.1)) | ((np.abs(X + 0.6) < 0.1) & (np.abs(Z - 1.2) < 0.3)), dark),
        (lambda X, Z: (X - 0.45) ** 2 + (Z - 1.3) ** 2 < 0.12 ** 2, glow('#FF5FA2', 2.5)),
        (lambda X, Z: (X - 0.75) ** 2 + (Z - 1.1) ** 2 < 0.12 ** 2, glow('#FFE066', 2.5))), rim='#4FB3B0')


@R('SnowflakeCrest', 6, 'crest', CW, CD, CH, 'Winter Cabin crest: a glowing snowflake')
def _(p):
    def flake(X, Z):
        dx, dz = X, Z - 1.25
        r = np.sqrt(dx * dx + dz * dz)
        a = np.arctan2(dz, dx)
        arm = np.abs(np.sin(3 * a)) * r < 0.13
        tips = (np.abs(r - 0.45) < 0.12) & (np.abs(np.sin(3 * a)) * r < 0.3)
        return (r < 0.75) & (arm | tips | (r < 0.18))
    crest(p, '#2F5D3A', shape((flake, glow('#DDF3FF', 2.2))), rim='#C8413A')


@R('PaletteCrest', 7, 'crest', CW, CD, CH, 'Art Studio crest: a paint palette with a brush')
def _(p):
    crest(p, '#9C6ADE', shape(
        (lambda X, Z: ((X / 0.9) ** 2 + ((Z - 1.2) / 0.6) ** 2 < 1) & ((X - 0.4) ** 2 + (Z - 0.95) ** 2 > 0.16 ** 2), col('#E3B878')),
        (lambda X, Z: (X + 0.45) ** 2 + (Z - 1.4) ** 2 < 0.16 ** 2, glow('#FF6FA8', 1.5)),
        (lambda X, Z: X ** 2 + (Z - 1.55) ** 2 < 0.16 ** 2, glow('#4FB3B0', 1.5)),
        (lambda X, Z: (X - 0.45) ** 2 + (Z - 1.4) ** 2 < 0.16 ** 2, glow('#FFD166', 1.5)),
        (lambda X, Z: (X + 0.55) ** 2 + (Z - 1.0) ** 2 < 0.16 ** 2, glow('#5B8DD9', 1.5))))


@R('FlowerCrest', 8, 'crest', CW, CD, CH, 'Rooftop Garden crest: a five-petal flower')
def _(p):
    def petals(X, Z):
        out = np.zeros(X.shape, bool)
        for a in range(5):
            t = a * 2 * math.pi / 5 + math.pi / 2
            out |= (X - math.cos(t) * 0.42) ** 2 + (Z - 1.3 - math.sin(t) * 0.42) ** 2 < 0.28 ** 2
        return out
    crest(p, '#4E9A35', shape(
        (lambda X, Z: (np.abs(X) < 0.1) & (Z < 1.0) & (Z > 0.35), col('#2F7A2E')),
        (petals, glow('#FFFFFF', 1.2)),
        (lambda X, Z: X * X + (Z - 1.3) ** 2 < 0.22 ** 2, glow('#FFC93C', 2.0))))


@R('MoonStarCrest', 9, 'crest', CW, CD, CH, 'Starlit Observatory crest: a crescent moon and a star')
def _(p):
    crest(p, '#1E2A5A', shape(
        (lambda X, Z: ((X + 0.15) ** 2 + (Z - 1.25) ** 2 < 0.62 ** 2) & ((X + 0.15 - 0.3) ** 2 + (Z - 1.38) ** 2 > 0.52 ** 2), glow('#FFE7A0', 2.5)),
        (lambda X, Z: ((np.abs(X - 0.45) < 0.1) & (np.abs(Z - 1.3) < 0.35)) | ((np.abs(Z - 1.3) < 0.1) & (np.abs(X - 0.45) < 0.35)), glow('#FFF1B0', 3.0))))


@R('CrownCrest', 10, 'crest', CW, CD, CH, 'Golden Sky Penthouse crest: a golden crown with a gem')
def _(p):
    crest(p, '#8E2C5A', shape(
        (lambda X, Z: (np.abs(X) < 0.8) & (Z > 0.7) & ((Z < 1.05) | (Z - 1.05 < 0.7 * (1 - np.abs(((X + 0.8) % 0.8) / 0.4 - 1)))), glow(GOLD, 1.2)),
        (lambda X, Z: ((X + 0.8) ** 2 + (Z - 1.82) ** 2 < 0.13 ** 2) | (X ** 2 + (Z - 1.82) ** 2 < 0.13 ** 2) | ((X - 0.8) ** 2 + (Z - 1.82) ** 2 < 0.13 ** 2), glow('#FFFFFF', 2.0)),
        (lambda X, Z: X ** 2 + (Z - 0.88) ** 2 < 0.15 ** 2, glow('#4FB3FF', 2.5))))


# floor 1's starter rug (floor 1 has no upgrades; it is always there)
@R('StarterRug', 1, 'rug', 12, 7.2, RH, 'Cozy Studio rug: small braided starter rug in mustard, cream and teal', budget=80)
def _(p):
    g = p.part()
    cs = [col('#F2B94B'), col('#FFF4E0'), col('#4FB3B0')]

    def c(X, Y, Z):
        ex = np.minimum(6 - np.abs(X), 3.6 - np.abs(Y))
        band = snap(ex, 0.8).astype(int)
        return np.array(cs)[band % 3]
    # corners cut in steps so it reads as a soft oval
    g.fill((-6, -3.6, 0), (6, 3.6, RH), lambda X, Y, Z: (np.abs(X) < 5.2) | (np.abs(Y) < 2.8), c)


THEMES_ROOM = {
    2: ('ReadingCushion', 'StorytimeRug', 'ReadingPendant', 'FiddleLeafFig', 'BookCrest'),
    3: ('MossNest', 'LeafyJuteRug', 'IvyHanger', 'MonsteraPot', 'LeafCrest'),
    4: ('ProofingBasketBed', 'GinghamRug', 'CopperPendant', 'LemonTree', 'CupcakeCrest'),
    5: ('GamerPod', 'ArcadeCarpet', 'NeonRing', 'SnakePlant', 'GamepadCrest'),
    6: ('PlaidBed', 'BraidedRug', 'LanternChandelier', 'SnowyPine', 'SnowflakeCrest'),
    7: ('DropClothBed', 'SplatterRug', 'StudioSpot', 'PaintBucketPothos', 'PaletteCrest'),
    8: ('PetalBed', 'CloverLawn', 'PaperLanterns', 'SunflowerPot', 'FlowerCrest'),
    9: ('MoonCushion', 'StarChartRug', 'StarCluster', 'Moonflower', 'MoonStarCrest'),
    10: ('RoyalCushion', 'GoldKeyRug', 'CrystalChandelier', 'GoldTopiary', 'CrownCrest'),
}
