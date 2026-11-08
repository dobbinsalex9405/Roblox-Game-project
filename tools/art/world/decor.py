"""Floor decor for the 10-floor tower, from plans/hatchery-heist/floor-decor-assets.md.
Each floor has four upgrade zones: cozy (corners), toys (centre ring),
lighting (walls and ceiling) and food (one side bay). Sizes are W x D x H
studs as in the plan. Front is -y; wall-mounted props hang on a wall behind
them (+y). Animated pieces are their own part, named after what moves."""
import math
import numpy as np

from vkit import VOX, col, hnoise, snoise
from styles import pick
from props import prop, WOOD, WOOD_D, STRAW, RED, IRON, two_tone, fruit


def D(pid, floor, zone, w, d, h, note='', budget=80, extra=0.0):
    """decor prop footprint centred on x/y, base at z=0"""
    hw, hd = w / 2 + extra, d / 2 + extra
    return prop(pid, 'decor', (-hw, -hd, 0), (hw, hd, h + extra), budget=budget, floor=floor, zone=zone, note=note)


def glow(h, s=3.0):
    return col(h, s)


def ball(g, x, y, z, r, c, stripe=None, sc=None):
    g.ell((x, y, z), (r, r, r), c)
    if stripe:
        g.paint((x - r, y - r, z - r), (x + r, y + r, z + r), lambda X, Y, Z: np.abs(Z - z) < r * stripe, sc)


def bowl(g, x, y, z, r, h, c, inner=None):
    g.cyl(x, y, z, z + h, r * 0.8, c, r1=r)
    g.carve((x - r, y - r, z + h * 0.35), (x + r, y + r, z + h + 0.1), lambda X, Y, Z: (X - x) ** 2 + (Y - y) ** 2 < (r - 0.15) ** 2)
    if inner is not None:
        g.cyl(x, y, z + h * 0.35, z + h * 0.75, r - 0.15, inner)


def water(g, x0, y0, z0, x1, y1, z1, deep='#3FA9F5', light='#7FD3FF'):
    g.box((x0, y0, z0), (x1, y1, z1), lambda X, Y, Z: np.where(hnoise(X, Y, Z, 7) > 0.8, col(light), col(deep)))


def cushion(g, x0, y0, x1, y1, z, h, c, edge, rad=0.3):
    g.rrbox((x0, y0, z), (x1, y1, z + h), rad, c)
    g.paint((x0, y0, z), (x1, y1, z + h), lambda X, Y, Z: (np.abs(Z - (z + h * 0.5)) < 0.06), col(edge))


def legs(g, x0, y0, x1, y1, z0, z1, t, c):
    for x in (x0, x1 - t):
        for y in (y0, y1 - t):
            g.box((x, y, z0), (x + t, y + t, z1), c)


# ============================================ Farm centre (floor None, zone farm)
@D('HayBaleBed', None, 'farm', 4, 3, 1.5, 'hay bale bed with a hollow to curl up in')
def _(p):
    g = p.part()
    g.rrbox((-2, -1.5, 0), (2, 1.5, 1.5), 0.3, pick(STRAW, 201))
    for x in (-1.2, 1.2):
        g.paint((x - 0.12, -1.6, 0), (x + 0.12, 1.6, 1.6), None, col('#B5452F'))
    g.carve((-1.4, -0.9, 1.1), (1.4, 0.9, 1.6))
    g.box((-1.4, -0.9, 1.0), (1.4, 0.9, 1.1), pick(['#F7DA75', '#FFE59A'], 202))


@D('NestBox', None, 'farm', 3, 3, 1.2, 'wooden nest box with straw')
def _(p):
    g = p.part()
    g.box((-1.5, -1.5, 0), (1.5, 1.5, 1.2), pick(WOOD, 203))
    g.carve((-1.25, -1.25, 0.3), (1.25, 1.25, 1.3))
    g.paint((-1.5, -1.5, 0), (1.5, 1.5, 1.2), lambda X, Y, Z: np.mod(Z, 0.4) < VOX, col('#8B5A33'))
    g.fill((-1.25, -1.25, 0.3), (1.25, 1.25, 0.9), lambda X, Y, Z: Z < 0.6 + 0.25 * snoise(X, Y, Z, 4, 2), pick(STRAW, 204))
    g.box((-1.6, -1.6, 1.1), (1.6, -1.4, 1.3), col(RED))


@D('RubberBall', 1, 'toys', 1.2, 1.2, 1.2, 'rubber ball; the whole ball rolls')
def _(p):
    g = p.part('ball', anim='roll', pivot=(0, 0, 0.6))
    ball(g, 0, 0, 0.6, 0.6, col('#E8413C'), 0.18, col('#FFFFFF'))


@D('TyreSwing', None, 'farm', 3, 1.2, 5, 'tyre swing on a wooden frame; part "swing" sways from the top bar')
def _(p):
    g = p.part()
    w = pick(WOOD_D, 205)
    g.seg((-1.4, 0, 0), (-1.1, 0, 5), 0.15, w)
    g.seg((1.4, 0, 0), (1.1, 0, 5), 0.15, w)
    g.box((-1.4, -0.15, 4.75), (1.4, 0.15, 5.0), w)
    s = p.part('swing', anim='sway', parent='body', pivot=(0, 0, 4.75))
    s.box((-0.05, -0.05, 2.0), (0.05, 0.05, 4.75), col('#C9A06A'))

    def tyre(X, Y, Z):
        d = np.sqrt(X ** 2 + (Z - 1.4) ** 2) - 0.55
        return d * d + Y * Y <= 0.22 ** 2
    s.fill((-0.9, -0.3, 0.6), (0.9, 0.3, 2.2), tyre, col('#2E2E36'))


@D('Seesaw', None, 'farm', 5, 1.5, 1.2, 'small seesaw; part "plank" rocks')
def _(p):
    g = p.part()
    g.box((-0.4, -0.5, 0), (0.4, 0.5, 0.6), col(RED))
    k = p.part('plank', anim='rock', parent='body', pivot=(0, 0, 0.6))
    k.box((-2.5, -0.6, 0.6), (2.5, 0.6, 0.8), pick(WOOD, 206))
    for x in (-2.2, 2.2):
        k.box((x - 0.1, -0.5, 0.8), (x + 0.1, 0.5, 1.2), col(RED))


@D('HangingLantern', None, 'farm', 1, 1, 2, 'barn lantern on a chain; part "light" flickers')
def _(p):
    g = p.part()
    fr = col(IRON)
    g.box((-0.05, -0.05, 1.4), (0.05, 0.05, 2.0), fr)
    g.box((-0.45, -0.45, 0), (0.45, 0.45, 0.12), fr)
    g.box((-0.45, -0.45, 1.0), (0.45, 0.45, 1.12), fr)
    for x in (-0.45, 0.35):
        for y in (-0.45, 0.35):
            g.box((x, y, 0), (x + 0.1, y + 0.1, 1.1), fr)
    g.cyl(0, 0, 1.1, 1.45, 0.4, fr, r1=0.08)
    li = p.part('light', anim='flicker', parent='body')
    li.box((-0.3, -0.3, 0.12), (0.3, 0.3, 1.0), glow('#FFC870', 4))


@D('FeedTrough', None, 'farm', 5, 1.5, 1.2, 'wooden feed trough full of grain')
def _(p):
    g = p.part()
    g.box((-2.5, -0.75, 0.3), (2.5, 0.75, 1.2), pick(WOOD, 207))
    g.carve((-2.3, -0.55, 0.5), (2.3, 0.55, 1.3))
    g.box((-2.3, -0.55, 0.5), (2.3, 0.55, 0.95), pick(['#F2CE5C', '#E8BF48', '#C99E62'], 208))
    for x in (-2.3, 1.9):
        g.box((x, -0.75, 0), (x + 0.4, 0.75, 0.3), col('#8B5A33'))


@D('WaterBucket', None, 'farm', 1.2, 1.2, 1.2, 'metal bucket of water')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 1.0, 0.5, col('#A9B4C2'), r1=0.6)
    g.carve((-0.5, -0.5, 0.15), (0.5, 0.5, 1.1), lambda X, Y, Z: X * X + Y * Y < 0.45 ** 2)
    water(g, -0.5, -0.5, 0.15, 0.5, 0.5, 0.85)
    g.carve((-0.6, -0.6, 0.15), (0.6, 0.6, 0.85), lambda X, Y, Z: X * X + Y * Y > 0.47 ** 2 + Z * 0.2)
    g.cyl(0, 0, 0, 1.0, 0.6, col('#A9B4C2'), r1=0.62, cond=lambda X, Y, Z: X * X + Y * Y > 0.5 ** 2)
    g.paint((-1, -1, 0.75), (1, 1, 0.85), None, col('#7C8794'))
    g.fill((-0.62, -0.1, 1.0), (0.62, 0.1, 1.2), lambda X, Y, Z: np.abs(X * X / 0.36 + (Z - 1.0) ** 2 / 0.04 - 1) < 0.5, col(IRON))


@D('GrainSack', None, 'farm', 1.5, 1, 2, 'burlap grain sack, tied at the top')
def _(p):
    g = p.part()
    g.blob((0, 0, 0.8), (0.75, 0.5, 0.85), pick(['#D9B98A', '#CFAE7E', '#E2C497'], 209), amp=0.06, f=3, seed=2)
    g.carve((-1, -1, -1), (1, 1, 0))
    g.cyl(0, 0, 1.55, 1.7, 0.25, col('#8B5A33'))
    g.blob((0, 0, 1.85), (0.35, 0.3, 0.2), pick(['#D9B98A', '#CFAE7E'], 210), amp=0.1, f=5)
    g.box((-0.3, -0.52, 0.6), (0.3, -0.45, 1.0), col(RED))


# ========================================================= 2 Meadow cottage
PASTEL = ['#FF9EC7', '#FFD166', '#8FD3FF', '#A7E98F', '#C9A7FF']


@D('PatchworkCushion', 2, 'cozy', 3, 3, 0.6, 'patchwork floor cushion')
def _(p):
    g = p.part()
    ids = [col(c) for c in PASTEL]

    def c(X, Y, Z):
        k = (np.floor((X + 1.5) / 0.75) * 3 + np.floor((Y + 1.5) / 0.75)).astype(int)
        return np.array(ids)[k % len(ids)]
    g.rrbox((-1.5, -1.5, 0), (1.5, 1.5, 0.6), 0.25, c)
    g.paint((-1.5, -1.5, 0), (1.5, 1.5, 0.6), lambda X, Y, Z: (np.mod(X + 1.5, 0.75) < VOX) | (np.mod(Y + 1.5, 0.75) < VOX), col('#FFFFFF'))


@D('WickerBasketBed', 1, 'cozy', 3, 3, 1.5, 'round wicker basket bed with a blanket')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 1.2, 1.3, lambda X, Y, Z: np.where(np.mod(np.arctan2(Y, X) * 6 + Z * 8, 2) < 1, col('#C98E52'), col('#B07A42')), r1=1.5)
    g.carve((-1.5, -1.5, 0.3), (1.5, 1.5, 1.3), lambda X, Y, Z: X * X + Y * Y < (1.15 + Z * 0.2) ** 2)
    g.cyl(0, 0, 1.1, 1.35, 1.55, col('#B07A42'), cond=lambda X, Y, Z: X * X + Y * Y > 1.25 ** 2)
    g.cyl(0, 0, 0.3, 0.6, 1.2, col('#8FD3FF'))
    g.paint((-1.2, -1.2, 0.3), (1.2, 1.2, 0.6), lambda X, Y, Z: (np.mod(X, 0.5) < 0.1) | (np.mod(Y, 0.5) < 0.1), col('#FFFFFF'))


@D('YarnBall', 1, 'toys', 1, 1, 1, 'ball of yarn; rolls')
def _(p):
    g = p.part('ball', anim='roll', pivot=(0, 0, 0.5))
    g.ell((0, 0, 0.5), (0.5, 0.5, 0.5), lambda X, Y, Z: np.where(np.mod(X * 3 + Z * 4, 1) < 0.35, col('#FF6FA8'), col('#FF9EC7')))
    g.seg((0.4, -0.2, 0.2), (0.9, -0.5, 0.05), 0.05, col('#FF6FA8'))


@D('DaisyPinwheel', 3, 'toys', 1, 0.6, 3, 'daisy pinwheel on a stick; part "wheel" spins')
def _(p):
    g = p.part()
    g.box((-0.06, -0.06, 0), (0.06, 0.06, 2.3), col('#5DB13E'))
    w = p.part('wheel', anim='spin', parent='body', pivot=(0, -0.15, 2.4))
    for i in range(8):
        a = i * math.pi / 4
        w.seg((0, -0.15, 2.4), (math.cos(a) * 0.6, -0.15, 2.4 + math.sin(a) * 0.6), 0.2, col('#FFFFFF'))
    w.ell((0, -0.3, 2.4), (0.25, 0.2, 0.25), col('#FFD166'))


@D('BlockStack', 1, 'toys', 2, 2, 2, 'stack of wooden letter blocks')
def _(p):
    g = p.part()
    for (x, y, z, c) in ((-0.45, -0.45, 0, '#FF6F91'), (0.45, -0.4, 0, '#8FD3FF'), (-0.4, 0.45, 0, '#A7E98F'), (0.4, 0.45, 0, '#FFD166'),
                         (0, 0, 0.9, '#C9A7FF')):
        g.rrbox((x - 0.45, y - 0.45, z), (x + 0.45, y + 0.45, z + 0.9), 0.08, col(c))
        g.box((x - 0.2, y - 0.47, z + 0.25), (x + 0.2, y - 0.45, z + 0.65), col('#FFFFFF'))


@D('FairyLights', 1, 'lighting', 6, 0.4, 1.2, 'flower-pot fairy lights strung along a wall; part "bulbs" twinkles')
def _(p):
    g = p.part()
    b = p.part('bulbs', anim='flicker', parent='body')
    cs = ['#FFE066', '#FF9EC7', '#8FD3FF', '#A7E98F']
    for i in range(13):
        x = -3 + i * 0.5
        z = 1.0 - 0.45 * math.sin(math.pi * (i % 6) / 6)
        g.box((x, 0.1, z), (x + 0.5, 0.2, z + 0.06), col('#3E6B32'))
        if i % 2 == 0:
            b.ell((x + 0.05, 0.15, z - 0.12), (0.12, 0.12, 0.14), glow(cs[(i // 2) % 4], 3))


@D('TableLamp', 2, 'lighting', 1.5, 1.5, 3, 'cottage table lamp; part "shade" glows')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 0.2, 0.6, col('#C98E52'))
    g.cyl(0, 0, 0.2, 1.8, 0.1, col('#C98E52'))
    g.ell((0, 0, 0.6), (0.35, 0.35, 0.4), col('#8FD3FF'))
    s = p.part('shade', anim='pulse', parent='body')
    s.cyl(0, 0, 1.7, 2.9, 0.75, glow('#FFE7A8', 1.8), r1=0.45)
    s.carve((-1, -1, 1.7), (1, 1, 2.7), lambda X, Y, Z: X * X + Y * Y < (0.6 - (Z - 1.7) * 0.25) ** 2)


@D('WateringCanFountain', 3, 'food', 2, 1.5, 2, 'watering can pouring into a little basin; part "drops" drips')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 0.35, 0.75, col('#A9B4C2'))
    water(g, -0.6, -0.6, 0.25, 0.6, 0.6, 0.35)
    g.cyl(0.2, 0.2, 0.9, 1.7, 0.45, col('#5BB0E8'))
    g.seg((-0.2, 0.2, 1.3), (-0.85, -0.1, 1.75), 0.1, col('#5BB0E8'))
    g.fill((0.1, 0.1, 1.6), (0.7, 0.3, 2.0), lambda X, Y, Z: np.abs(np.sqrt((X - 0.2) ** 2 + (Z - 1.7) ** 2) - 0.3) < 0.06, col('#5BB0E8'))
    d = p.part('drops', anim='drip', parent='body')
    for z in (0.5, 0.9, 1.3):
        d.box((-0.85, -0.15, z), (-0.75, -0.05, z + 0.15), glow('#BFE9FF', 1.2))
    g.box((-0.05, -0.05, 0.35), (0.05, 0.05, 0.9), col(IRON))


# =========================================================== 3 Orchard loft
@D('JarLight', 3, 'lighting', 0.8, 0.8, 1.5, 'hanging glass jar of fireflies; part "glow" pulses')
def _(p):
    g = p.part()
    g.box((-0.05, -0.05, 1.05), (0.05, 0.05, 1.5), col('#C9A06A'))
    g.cyl(0, 0, 0.9, 1.05, 0.3, col('#B0BEC5'))
    q = p.part('glow', anim='pulse', parent='body')
    q.cyl(0, 0, 0, 0.9, 0.38, glow('#E6FF8A', 2.5))


@D('Skylight', 3, 'lighting', 8, 8, 0.4, 'ceiling skylight that glows with daylight; part "glass" glows')
def _(p):
    g = p.part()
    g.box((-4, -4, 0), (4, 4, 0.4), pick(WOOD_D, 215))
    g.carve((-3.6, -3.6, -0.1), (3.6, 3.6, 0.5))
    g.box((-0.1, -3.6, 0), (0.1, 3.6, 0.4), pick(WOOD_D, 215))
    g.box((-3.6, -0.1, 0), (3.6, 0.1, 0.4), pick(WOOD_D, 215))
    q = p.part('glass', anim='pulse', parent='body')
    q.box((-3.6, -3.6, 0.15), (3.6, 3.6, 0.25), glow('#DFF4FF', 1.2))


@D('FruitBasket', 3, 'food', 2.5, 2.5, 1.5, 'woven basket heaped with fruit')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 0.8, 1.0, lambda X, Y, Z: np.where(np.mod(np.arctan2(Y, X) * 5 + Z * 7, 2) < 1, col('#C98E52'), col('#B07A42')), r1=1.25)
    rng = np.random.default_rng(5)
    for _ in range(9):
        a, r = rng.uniform(0, 2 * math.pi), rng.uniform(0, 0.75)
        c = ['#E8413C', '#FFD166', '#A7E98F', '#FF9F1C'][rng.integers(4)]
        g.ell((math.cos(a) * r, math.sin(a) * r, 0.9 + rng.uniform(0, 0.35)), (0.27, 0.27, 0.27), col(c))


# ========================================================== 4 Mushroom grove
CAP = ['#E8413C', '#D9352F']
STEM = ['#F6EEDC', '#EDE2CB']


def mushroom(g, x, y, h, r, cap, dots=True, glowc=None):
    g.cyl(x, y, 0, h, r * 0.35, pick(STEM, 221), r1=r * 0.28)
    g.ell((x, y, h), (r, r, r * 0.55), glowc if glowc is not None else pick(cap, 222), cond=lambda X, Y, Z: Z >= h - 0.05)
    if dots:
        g.paint((x - r, y - r, h), (x + r, y + r, h + r), lambda X, Y, Z: hnoise(np.floor(X / 0.3), np.floor(Y / 0.3), np.floor(Z / 0.3), 9) > 0.8,
                col('#FFFFFF'))


@D('MossMound', 3, 'cozy', 4, 4, 1.2, 'soft moss mound')
def _(p):
    g = p.part()
    g.blob((0, 0, 0), (2, 2, 1.2), pick(['#4E9A50', '#468F49', '#58A65A', '#62B064'], 225), amp=0.1, f=2.5, seed=6)
    g.carve((-3, -3, -2), (3, 3, 0))


@D('BouncyToadstool', 3, 'toys', 3, 3, 2, 'bouncy toadstool; part "cap" squashes')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 1.3, 0.55, pick(STEM, 226), r1=0.45)
    c = p.part('cap', anim='bob', parent='body', pivot=(0, 0, 1.2))
    c.ell((0, 0, 1.2), (1.5, 1.5, 0.8), lambda X, Y, Z: np.where(hnoise(np.floor(X / 0.35), np.floor(Y / 0.35), np.floor(Z / 0.35), 11) > 0.78,
                                                                 col('#FFFFFF'), col('#B57BFF')), cond=lambda X, Y, Z: Z >= 1.2)


# =========================================================== 5 Crystal cave
CRYS = '#7FE8FF'


def crystal(g, x, y, z, r, h, c, tilt=(0, 0)):
    tx, ty = tilt
    g.seg((x, y, z), (x + tx, y + ty, z + h * 0.75), r, c, r1=r * 0.95)
    g.seg((x + tx, y + ty, z + h * 0.75), (x + tx * 1.2, y + ty * 1.2, z + h), r * 0.95, c, r1=0.03)


# =========================================================== 6 Cloud garden
CLOUD = ['#FFFFFF', '#F2F6FF', '#E6EEFF']


def cloud(g, x, y, z, w, d, h, seed=1):
    for i, (dx, dy, dz, k) in enumerate(((0, 0, 0, 1), (-w * 0.3, 0, -h * 0.1, 0.75), (w * 0.3, 0, -h * 0.1, 0.75), (0, d * 0.2, h * 0.15, 0.7))):
        g.blob((x + dx, y + dy, z + dz), (w * 0.4 * k, d * 0.5 * k, h * 0.55 * k), pick(CLOUD, 240 + seed), amp=0.08, f=3, seed=seed + i)


@D('CloudPuffBed', 8, 'cozy', 4, 3, 1.4, 'cloud puff bed; part "cloud" bobs slowly')
def _(p):
    p.part()
    c = p.part('cloud', anim='bob', parent='body')
    cloud(c, 0, 0, 0.6, 4, 3, 1.1, 1)
    c.carve((-1.2, -0.8, 1.0), (1.2, 0.8, 1.6), lambda X, Y, Z: (X / 1.2) ** 2 + (Y / 0.8) ** 2 < 1)
    c.carve((-3, -3, -1), (3, 3, 0.1))


@D('Hammock', 8, 'cozy', 6, 2, 3, 'hammock between two posts; part "net" sways')
def _(p):
    g = p.part()
    for x in (-2.8, 2.8):
        g.box((x - 0.2, -0.2, 0), (x + 0.2, 0.2, 3), pick(WOOD, 241))
        g.ell((x, 0, 3.1), (0.3, 0.3, 0.2), col('#FFD166'))
    n = p.part('net', anim='sway', parent='body', pivot=(0, 0, 2.6))

    def sag(X, Y, Z):
        zc = 1.2 + 1.4 * (X / 2.6) ** 2
        return (np.abs(Z - zc) < 0.14) & (np.abs(Y) < 0.75 - 0.15 * np.abs(X / 2.6))
    n.fill((-2.6, -0.8, 1.0), (2.6, 0.8, 2.8), sag, lambda X, Y, Z: np.where(np.mod(np.floor(X / 0.5), 2) == 0, col('#8FD3FF'), col('#FFFFFF')))


@D('KitePost', 8, 'toys', 1.2, 1.2, 6, 'kite tied to a post; part "kite" flutters')
def _(p):
    g = p.part()
    g.box((-0.12, -0.12, 0), (0.12, 0.12, 3.5), pick(WOOD, 242))
    k = p.part('kite', anim='sway', parent='body', pivot=(0, 0, 3.5))
    k.box((-0.03, -0.03, 3.5), (0.03, 0.03, 4.6), col('#FFFFFF'))
    k.fill((-0.6, -0.1, 4.5), (0.6, 0.1, 6.0), lambda X, Y, Z: np.abs(X) / 0.6 + np.abs(Z - 5.25) / 0.75 <= 1,
           lambda X, Y, Z: np.where(X * (Z - 5.25) > 0, col('#FF6F91'), col('#FFD166')))


@D('BubbleWand', 8, 'toys', 1, 1, 3, 'bubble wand stand; part "bubbles" bob and glow')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 0.25, 0.45, col('#8FD3FF'))
    g.box((-0.1, -0.1, 0.25), (0.1, 0.1, 2.0), col('#FF9EC7'))
    g.fill((-0.5, -0.1, 1.8), (0.5, 0.1, 2.8), lambda X, Y, Z: np.abs(np.sqrt(X * X + (Z - 2.3) ** 2) - 0.36) < 0.1, col('#FF9EC7'))
    b = p.part('bubbles', anim='bob', parent='body')
    for x, z, r in ((0.35, 2.6, 0.2), (-0.25, 2.85, 0.15), (0.1, 3.0, 0.12)):
        b.ell((x, 0, z), (r, r, r), glow('#DFF4FF', 1.0))


@D('RainbowSlide', 8, 'toys', 6, 2, 3, 'rainbow slide with steps')
def _(p):
    g = p.part()
    bands = [col(c) for c in ('#FF5E5E', '#FF9F1C', '#FFD166', '#7BD88F', '#5BB0E8', '#9A8CFF')]

    def slide(X, Y, Z):
        zt = 3.0 - (X + 1.5) / 4.5 * 2.8
        return (Z <= zt) & (Z >= zt - 0.25) & (X >= -1.5)
    g.fill((-1.5, -1, 0), (3, 1, 3), slide, lambda X, Y, Z: np.array(bands)[np.clip(((Y + 1) / 2 * 6).astype(int), 0, 5)])
    for i in range(6):
        z = i * 0.5
        g.box((-3 + i * 0.25, -0.8, 0), (-1.5, 0.8, z + 0.5), col(CLOUD[0]))
    g.carve((-3, -1, 0), (-2.0, 1, 3), lambda X, Y, Z: Z > (X + 3) * 2 + 0.5)


@D('SunOrbLamp', 8, 'lighting', 1.5, 1.5, 2.2, 'glowing sun orb on a little cloud; part "orb" pulses')
def _(p):
    g = p.part()
    cloud(g, 0, 0, 0.3, 1.5, 1.2, 0.6, 3)
    g.carve((-2, -2, -1), (2, 2, 0))
    o = p.part('orb', anim='pulse', parent='body')
    o.ell((0, 0, 1.35), (0.65, 0.65, 0.65), glow('#FFD166', 3))


@D('RainbowArch', 8, 'lighting', 12, 1, 6, 'rainbow arch with glowing edges', budget=80)
def _(p):
    g = p.part()
    bands = ['#FF5E5E', '#FF9F1C', '#FFD166', '#7BD88F', '#5BB0E8', '#9A8CFF']
    for i, c in enumerate(bands):
        r0 = 5.9 - i * 0.45

        def m(X, Y, Z, r0=r0):
            r = np.sqrt(X * X + Z * Z)
            return (r <= r0) & (r > r0 - 0.45) & (np.abs(Y) < 0.4)
        g.fill((-6, -0.5, 0), (6, 0.5, 6), m, glow(c, 0.8) if i in (0, 5) else col(c))
    cloud(g, -4.3, 0, 0.4, 2.4, 1.2, 1.0, 4)
    cloud(g, 4.3, 0, 0.4, 2.4, 1.2, 1.0, 5)
    g.carve((-7, -2, -1), (7, 2, 0))


@D('RaindropFountain', 8, 'food', 3, 3, 3, 'little rain cloud over a basin; part "rain" drips')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 0.6, 1.4, col('#E6EEFF'))
    water(g, -1.2, -1.2, 0.4, 1.2, 1.2, 0.5)
    g.carve((-1.2, -1.2, 0.5), (1.2, 1.2, 0.7), lambda X, Y, Z: X * X + Y * Y < 1.2 ** 2)
    g.box((-0.1, 0.9, 0.6), (0.1, 1.1, 2.4), col('#B0BEC5'))
    cloud(g, 0, 0.2, 2.5, 2.2, 1.6, 0.8, 6)
    r = p.part('rain', anim='drip', parent='body')
    for x, y in ((-0.5, 0), (0.2, -0.3), (0.5, 0.3), (-0.1, 0.4)):
        r.box((x, y, 0.8), (x + 0.1, y + 0.1, 1.1), glow('#BFE9FF', 1.0))
        r.box((x + 0.1, y, 1.4), (x + 0.2, y + 0.1, 1.7), glow('#BFE9FF', 1.0))


@D('SkyBerryBush', 8, 'food', 3, 3, 2, 'fluffy bush of glowing sky berries')
def _(p):
    g = p.part()
    c = two_tone(['#7FC8E8', '#6BB8DC'], ['#A7E0F5', '#9AD8F0'], ['#D6F3FF', '#E2F7FF'], 0, 2, 7)
    g.blob((0, 0, 0.9), (1.4, 1.4, 1.0), c, amp=0.12, f=2.6, seed=7)
    g.carve((-2, -2, -1), (2, 2, 0))
    fruit(g, 0, 0, 0.95, 1.35, 9, '#FF6FA8', 8, leaf='#FFFFFF', size=0.13)


# ============================================================ 7 Ember forge
BRICK = ['#B5452F', '#A63E2A', '#C24E37']
COAL = ['#2E2A2A', '#3B3536']


@D('FiresideRug', 6, 'cozy', 5, 4, 0.2, 'fireside rug with a slow ember glow; part "glow" pulses')
def _(p):
    g = p.part()
    g.box((-2.5, -2, 0), (2.5, 2, 0.12), col('#7A2E22'))
    q = p.part('glow', anim='pulse', parent='body')
    q.fill((-2.2, -1.7, 0.1), (2.2, 1.7, 0.18), lambda X, Y, Z: (np.abs(np.maximum(np.abs(X) / 2.2, np.abs(Y) / 1.7) - 0.8) < 0.05) | (X * X + Y * Y < 0.5),
           glow('#FF8A3D', 1.5))


# ============================================================== 8 Frost hall
ICE = ['#BEE9FF', '#A9E0FF', '#D3F1FF']
SNOW = ['#FFFFFF', '#F2F8FF']


@D('SnowballPile', 6, 'toys', 2, 2, 1, 'pile of snowballs')
def _(p):
    g = p.part()
    for x, y, z in ((-0.45, -0.35, 0), (0.45, -0.3, 0), (0, 0.45, 0), (0, 0, 0.4)):
        g.ell((x, y, z + 0.35), (0.35, 0.35, 0.35), pick(SNOW, 278))


@D('IceTop', 6, 'toys', 1.5, 1.5, 1.5, 'spinning ice top; part "top" spins')
def _(p):
    p.part()
    t = p.part('top', anim='spin', parent='body', pivot=(0, 0, 0))
    t.cyl(0, 0, 0, 0.8, 0.02, glow('#BEE9FF', 0.6), r1=0.75)
    t.cyl(0, 0, 0.8, 1.1, 0.75, pick(ICE, 279), r1=0.5)
    t.cyl(0, 0, 1.1, 1.5, 0.12, col('#5BB0E8'))


@D('IceLantern', 6, 'lighting', 1, 1, 1.5, 'carved ice lantern with a candle; part "light" flickers')
def _(p):
    g = p.part()
    g.box((-0.5, -0.5, 0), (0.5, 0.5, 1.3), pick(ICE, 280))
    g.carve((-0.35, -0.6, 0.25), (0.35, 0.6, 1.1))
    g.cyl(0, 0, 1.3, 1.5, 0.3, pick(SNOW, 281))
    li = p.part('light', anim='flicker', parent='body')
    li.box((-0.12, -0.12, 0.2), (0.12, 0.12, 0.7), glow('#FFC870', 3))


@D('FishBarrel', 6, 'food', 2, 2, 2, 'barrel of frozen fish')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 1.6, 0.85, pick(WOOD, 282), r1=0.95)
    g.paint((-1, -1, 0), (1, 1, 1.6), lambda X, Y, Z: (np.abs(Z - 0.3) < 0.08) | (np.abs(Z - 1.3) < 0.08), col(IRON))
    g.cyl(0, 0, 1.4, 1.6, 0.8, pick(SNOW, 283))
    for a in (0.3, 1.9, 3.6):
        g.seg((math.cos(a) * 0.3, math.sin(a) * 0.3, 1.5), (math.cos(a) * 0.5, math.sin(a) * 0.5, 2.0), 0.14, col('#7FA7C9'))


# ===================================================== 9 Moonlit observatory
NAVY = ['#2A2C78', '#3B3F9E', '#323690']
GOLD = ['#F4C542', '#E8B830']


def stars(c_dark, seed):
    def c(X, Y, Z):
        return np.where(hnoise(X, Y, Z, seed) > 0.93, glow('#FFF6B0', 2), c_dark(X, Y, Z))
    return c


@D('StarQuiltBed', 9, 'cozy', 4, 3, 1, 'bed with a starry quilt')
def _(p):
    g = p.part()
    g.box((-2, -1.5, 0), (2, 1.5, 0.45), pick(GOLD, 291))
    g.rrbox((-1.9, -1.4, 0.45), (1.9, 1.4, 0.95), 0.2, stars(pick(NAVY, 292), 293))
    g.rrbox((-1.6, 0.7, 0.9), (1.6, 1.35, 1.25), 0.15, col('#E6E0FF'))


@D('MoonCradle', 9, 'cozy', 4, 2, 2.5, 'crescent-moon cradle; part "moon" rocks')
def _(p):
    g = p.part()
    g.box((-1.5, -0.6, 0), (1.5, 0.6, 0.2), pick(GOLD, 294))
    m = p.part('moon', anim='rock', parent='body', pivot=(0, 0, 0.2))

    def cres(X, Y, Z):
        a = X * X + (Z - 1.4) ** 2 <= 1.35 ** 2
        b = X * X + (Z - 1.9) ** 2 <= 1.15 ** 2
        return a & ~b & (np.abs(Y) < 0.8)
    m.fill((-1.4, -0.9, 0), (1.4, 0.9, 2.6), cres, glow('#FFE680', 0.8))
    m.fill((-1.0, -0.7, 0.4), (1.0, 0.7, 0.9), lambda X, Y, Z: X * X + (Z - 1.4) ** 2 <= 1.1 ** 2, col('#9A8CFF'))


@D('PlanetMobile', 9, 'toys', 4, 4, 4, 'planet mobile on a stand; part "planets" orbits')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 0.25, 0.7, pick(GOLD, 295))
    g.box((-0.15, -0.15, 0.25), (0.15, 0.15, 3.6), pick(GOLD, 295))
    pl = p.part('planets', anim='spin', parent='body', pivot=(0, 0, 3.4))
    pl.ell((0, 0, 3.6), (0.4, 0.4, 0.4), glow('#FFD166', 3))
    for (a, r, z, s, c) in ((0, 1.6, 2.6, 0.35, '#5BB0E8'), (2.1, 1.3, 2.9, 0.25, '#E8413C'), (4.2, 1.8, 2.3, 0.45, '#B57BFF')):
        x, y = math.cos(a) * r, math.sin(a) * r
        pl.seg((0, 0, 3.4), (x, y, 3.4), 0.1, pick(GOLD, 296))
        pl.box((x - 0.05, y - 0.05, z), (x + 0.05, y + 0.05, 3.4), col('#B0BEC5'))
        pl.ell((x, y, z), (s, s, s), col(c))


@D('Telescope', 9, 'toys', 2, 2, 4, 'brass telescope on a tripod; part "tube" pans slowly')
def _(p):
    g = p.part()
    for a in (0, 2.1, 4.2):
        g.seg((0, 0, 2.2), (math.cos(a) * 0.9, math.sin(a) * 0.9, 0), 0.12, pick(WOOD_D, 297))
    t = p.part('tube', anim='turn', parent='body', pivot=(0, 0, 2.3))
    t.seg((0, 0.5, 2.0), (0, -0.9, 3.5), 0.26, pick(GOLD, 298), r1=0.32)
    t.seg((0, 0.65, 1.85), (0, 0.4, 2.1), 0.14, pick(GOLD, 298))
    t.ell((0, -0.95, 3.55), (0.28, 0.08, 0.28), glow('#BFE9FF', 1.0))


@D('CometBall', 9, 'toys', 1.2, 1.2, 1.2, 'glowing comet ball; rolls')
def _(p):
    g = p.part('ball', anim='roll', pivot=(0, 0, 0.6))
    g.ell((0, 0, 0.6), (0.6, 0.6, 0.6), lambda X, Y, Z: np.where(hnoise(X, Y, Z, 14) > 0.85, glow('#FFFFFF', 2), glow('#9A8CFF', 1.6)))


@D('StarPanel', 9, 'lighting', 6, 0.3, 4, 'star-field ceiling panel; part "stars" twinkles')
def _(p):
    g = p.part()
    g.box((-3, 0, 0), (3, 0.3, 4), pick(NAVY, 299))
    s = p.part('stars', anim='flicker', parent='body')
    s.fill((-2.9, -0.05, 0.1), (2.9, 0.0, 3.9), lambda X, Y, Z: hnoise(np.floor(X / 0.2), Y * 0, np.floor(Z / 0.2), 15) > 0.9, glow('#FFF6B0', 2.5))


@D('MoonOrb', 9, 'lighting', 3, 3, 3, 'big glowing moon orb; part "moon" pulses')
def _(p):
    p.part()
    m = p.part('moon', anim='pulse', parent='body')
    m.ell((0, 0, 1.5), (1.5, 1.5, 1.5), lambda X, Y, Z: np.where(snoise(X, Y, Z, 2.0, 3) > 0.35, glow('#D9D4F5', 1.6), glow('#F5F2FF', 2.0)))


@D('RuneRing', 9, 'lighting', 12, 12, 0.2, 'glowing rune ring on the floor; part "runes" pulses', budget=80)
def _(p):
    p.part()
    r = p.part('runes', anim='pulse', parent='body')

    def m(X, Y, Z):
        rr = np.sqrt(X * X + Y * Y)
        a = np.arctan2(Y, X)
        ring = (np.abs(rr - 5.6) < 0.15) | (np.abs(rr - 4.6) < 0.1)
        rune = (rr > 4.8) & (rr < 5.4) & (np.mod(a * 12 / math.pi, 2) < 0.4)
        return ring | rune
    r.fill((-6, -6, 0), (6, 6, 0.1), m, glow('#9A8CFF', 2.5))


@D('MoonwaterFountain', 9, 'food', 3, 3, 3, 'moonwater fountain; part "water" glows and drips')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 0.6, 1.5, pick(NAVY, 300))
    g.carve((-1.5, -1.5, 0.3), (1.5, 1.5, 0.7), lambda X, Y, Z: X * X + Y * Y < 1.3 ** 2)
    g.cyl(0, 0, 0.3, 2.2, 0.25, pick(GOLD, 301))
    g.cyl(0, 0, 2.0, 2.4, 0.7, pick(GOLD, 301), r1=0.8)
    g.ell((0, 0, 2.7), (0.3, 0.3, 0.3), col('#FFE680'))
    w = p.part('water', anim='drip', parent='body')
    w.cyl(0, 0, 0.3, 0.5, 1.3, glow('#8FA8FF', 1.2))
    w.cyl(0, 0, 2.3, 2.4, 0.6, glow('#8FA8FF', 1.2))
    for a in (0, 1.6, 3.1, 4.7):
        w.box((math.cos(a) * 0.75, math.sin(a) * 0.75, 0.5), (math.cos(a) * 0.75 + 0.1, math.sin(a) * 0.75 + 0.1, 2.0), glow('#BFD0FF', 1.0))


@D('StardustJar', 9, 'food', 1.5, 1.5, 2, 'jar of glowing stardust candy')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 1.6, 0.65, glow('#C9A7FF', 0.5))
    g.cyl(0, 0, 0.1, 1.2, 0.55, lambda X, Y, Z: np.where(hnoise(X, Y, Z, 16) > 0.6, glow('#FFF6B0', 2.5), glow('#FF9EC7', 1.5)))
    g.cyl(0, 0, 1.6, 2.0, 0.45, pick(GOLD, 302))


# ===================================================== 10 Golden sky palace
GOLDS = ['#FFC935', '#F4B820', '#FFD860']
SILK = ['#FFF4D6', '#FFEFC4']
ROYAL = ['#B33A6B', '#A12F5E']


@D('CanopyBed', 10, 'cozy', 5, 4, 4, 'royal canopy bed')
def _(p):
    g = p.part()
    g.box((-2.5, -2, 0), (2.5, 2, 0.6), pick(GOLDS, 311))
    cushion(g, -2.3, -1.8, 2.3, 1.8, 0.6, 0.5, pick(ROYAL, 312), '#FFD860')
    g.rrbox((-2.0, 1.0, 1.1), (2.0, 1.7, 1.6), 0.15, pick(SILK, 313))
    for x in (-2.4, 2.2):
        for y in (-1.9, 1.7):
            g.box((x, y, 0), (x + 0.2, y + 0.2, 3.8), pick(GOLDS, 314))
    g.box((-2.5, -2.0, 3.6), (2.5, 2.0, 3.8), pick(GOLDS, 314))
    g.fill((-2.5, -2.0, 3.0), (2.5, 2.0, 3.6), lambda X, Y, Z: ((np.abs(np.abs(X) - 2.4) < 0.1) | (np.abs(np.abs(Y) - 1.9) < 0.1)) & (np.mod(X + Y, 0.8) < 0.5),
           pick(ROYAL, 315))
    g.ell((0, 0, 3.95), (0.3, 0.3, 0.3), glow('#FFE680', 2))


@D('GoldPillowPile', 10, 'cozy', 4, 4, 1.5, 'pile of gold silk pillows')
def _(p):
    g = p.part()
    for (x, y, z, c) in ((-0.9, -0.8, 0, SILK), (0.9, -0.6, 0, GOLDS), (-0.6, 0.9, 0, GOLDS), (0.8, 0.8, 0, ROYAL), (0, 0, 0.6, SILK)):
        g.rrbox((x - 0.95, y - 0.95, z), (x + 0.95, y + 0.95, z + 0.6), 0.25, pick(c, 316))
        g.ell((x - 0.95, y - 0.95, z + 0.3), (0.12, 0.12, 0.12), col('#FFD860'))


@D('Carousel', 10, 'toys', 6, 6, 5, 'little carousel; part "ride" turns', budget=80)
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 0.4, 3.0, pick(SILK, 317))
    g.cyl(0, 0, 0.4, 4.4, 0.3, pick(GOLDS, 318))
    r = p.part('ride', anim='turn', parent='body')
    r.cyl(0, 0, 0.4, 0.6, 2.8, pick(GOLDS, 319))
    r.cyl(0, 0, 4.0, 5.0, 3.0, lambda X, Y, Z: np.where(np.mod(np.arctan2(Y, X) * 8 / math.pi, 2) < 1, col('#B33A6B'), col('#FFF4D6')), r1=0.3)
    for i in range(6):
        a = i * math.pi / 3
        x, y = math.cos(a) * 2.2, math.sin(a) * 2.2
        r.box((x - 0.06, y - 0.06, 0.6), (x + 0.06, y + 0.06, 4.0), pick(GOLDS, 320))
        r.rrbox((x - 0.3, y - 0.3, 1.6 + 0.3 * (i % 2)), (x + 0.3, y + 0.3, 2.2 + 0.3 * (i % 2)), 0.15, col(['#FF9EC7', '#8FD3FF', '#A7E98F'][i % 3]))
    r.ell((0, 0, 5.0), (0.3, 0.3, 0.3), glow('#FFE680', 2))


@D('GoldOrb', 10, 'toys', 1.5, 1.5, 1.5, 'bouncing gold orb; part "orb" bobs')
def _(p):
    p.part()
    o = p.part('orb', anim='bob', parent='body')
    o.ell((0, 0, 0.75), (0.75, 0.75, 0.75), lambda X, Y, Z: np.where(hnoise(X, Y, Z, 17) > 0.9, glow('#FFF1B0', 2), col('#FFC935', 0.6)))


@D('ThroneSteps', 10, 'toys', 5, 4, 3, 'gold and silk steps up to a little throne')
def _(p):
    g = p.part()
    for i in range(3):
        g.box((-2.5 + i * 0.3, -2 + i * 0.9, 0), (2.5 - i * 0.3, 2, (i + 1) * 0.6), pick(SILK if i % 2 else GOLDS, 321))
    g.box((-2.5, -2, 0), (2.5, -1.85, 0.6), pick(ROYAL, 322))
    g.box((-1.0, 0.8, 1.8), (1.0, 2.0, 2.3), pick(ROYAL, 323))
    g.box((-1.0, 1.7, 1.8), (1.0, 2.0, 3.0), pick(GOLDS, 324))
    g.ell((0, 1.85, 3.0), (0.25, 0.1, 0.25), glow('#FF5FA2', 2))


@D('GoldChandelier', 10, 'lighting', 4, 4, 4, 'gold chandelier; part "lights" sparkles')
def _(p):
    g = p.part()
    g.box((-0.06, -0.06, 2.6), (0.06, 0.06, 4), pick(GOLDS, 325))
    g.fill((-2, -2, 1.8), (2, 2, 2.1), lambda X, Y, Z: np.abs(np.sqrt(X * X + Y * Y) - 1.7) < 0.13, pick(GOLDS, 326))
    g.fill((-2, -2, 2.4), (2, 2, 2.7), lambda X, Y, Z: np.abs(np.sqrt(X * X + Y * Y) - 1.0) < 0.12, pick(GOLDS, 326))
    g.cyl(0, 0, 1.4, 2.7, 0.3, pick(GOLDS, 327), r1=0.15)
    li = p.part('lights', anim='glint', parent='body')
    for i in range(8):
        a = i * math.pi / 4
        li.cyl(math.cos(a) * 1.7, math.sin(a) * 1.7, 2.1, 2.5, 0.1, col('#FFFFFF'))
        li.ell((math.cos(a) * 1.7, math.sin(a) * 1.7, 2.65), (0.12, 0.12, 0.18), glow('#FFE680', 3.5))
    li.ell((0, 0, 1.2), (0.3, 0.3, 0.4), glow('#FFF1B0', 2.5))


@D('LightPillar', 10, 'lighting', 1.5, 1.5, 8, 'gold pillar with a sweeping light band; part "band" pulses')
def _(p):
    g = p.part()
    g.box((-0.75, -0.75, 0), (0.75, 0.75, 0.5), pick(GOLDS, 328))
    g.box((-0.75, -0.75, 7.5), (0.75, 0.75, 8), pick(GOLDS, 328))
    g.cyl(0, 0, 0.5, 7.5, 0.5, pick(SILK, 329))
    b = p.part('band', anim='pulse', parent='body')
    for z in (1.5, 4.0, 6.5):
        b.cyl(0, 0, z, z + 0.3, 0.56, glow('#FFE680', 2.5))


@D('TieredFountain', 10, 'food', 5, 5, 5, 'three-tier gold fountain; part "water" glows and drips', budget=80)
def _(p):
    g = p.part()
    for z, r in ((0, 2.5), (2.0, 1.5), (3.6, 0.8)):
        g.cyl(0, 0, z, z + 0.5, r - 0.2, pick(GOLDS, 330), r1=r)
        g.carve((-r, -r, z + 0.2), (r, r, z + 0.6), lambda X, Y, Z, r=r: X * X + Y * Y < (r - 0.25) ** 2)
    g.cyl(0, 0, 0.2, 4.8, 0.3, pick(SILK, 331))
    g.ell((0, 0, 4.9), (0.3, 0.3, 0.3), glow('#FFE680', 2))
    w = p.part('water', anim='drip', parent='body')
    for z, r in ((0.2, 2.25), (2.2, 1.25), (3.8, 0.55)):
        w.cyl(0, 0, z, z + 0.15, r, glow('#8FD3FF', 1.0))


@D('BanquetTable', 10, 'food', 8, 3, 1.5, 'banquet table heaped with fruit and cake', budget=80)
def _(p):
    g = p.part()
    g.box((-4, -1.5, 1.0), (4, 1.5, 1.2), pick(SILK, 332))
    g.box((-4, -1.55, 0.7), (4, -1.5, 1.2), pick(ROYAL, 333))
    legs(g, -3.9, -1.4, 3.9, 1.4, 0, 1.0, 0.3, pick(GOLDS, 334))
    for x, c in ((-2.8, '#E8413C'), (-1.2, '#FFD166'), (1.0, '#A7E98F'), (2.7, '#FF9F1C')):
        bowl(g, x, 0, 1.2, 0.5, 0.25, pick(GOLDS, 335))
        for k in range(3):
            g.ell((x - 0.18 + k * 0.18, (k - 1) * 0.15, 1.5), (0.18, 0.18, 0.18), col(c))
    g.cyl(0, 0.2, 1.2, 1.5, 0.45, col('#FFF4D6'))
    g.cyl(0, 0.2, 1.5, 1.8, 0.35, col('#FF9EC7'))
