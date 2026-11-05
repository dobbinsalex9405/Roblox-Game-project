"""Cozy apartment decor for tower floors 1 to 7 (floors 8 to 10, the
rooftop garden, observatory and sky penthouse, and the farm-centre props
live in decor.py). Same rules: four zones per floor, front is -y, moving
pieces are their own parts."""
import math
import numpy as np

from vkit import col, hnoise
from styles import pick
from props import WOOD, WOOD_D, IRON
from decor import D, glow, bowl, water, cushion, legs

FABRIC = {
    'peach': ['#FFB38A', '#FFA97C'], 'teal': ['#4FB3B0', '#47A8A5'], 'mustard': ['#F2B94B', '#E8AE3E'], 'rose': ['#F28FA8', '#EA829C'],
    'sage': ['#9CC59A', '#91BB8F'], 'navy': ['#3D5A80', '#36507A'], 'cream': ['#FFF4E0', '#F7EAD3'], 'red': ['#D9534F', '#CF4A46'],
    'lilac': ['#B9A3E3', '#AE97DB'],
}
WARM = '#FFD89A'


# ============================================================ 1 Cozy studio
@D('BeanbagBed', 1, 'cozy', 3, 3, 1.4, 'squishy beanbag bed')
def _(p):
    g = p.part()
    g.blob((0, 0, 0.55), (1.5, 1.5, 0.85), pick(FABRIC['peach'], 401), amp=0.06, f=2)
    g.carve((-2, -2, -2), (2, 2, 0))
    g.carve((-1, -1, 1.0), (1, 1, 1.6), lambda X, Y, Z: X * X + Y * Y + (Z - 1.5) ** 2 < 1.0)


@D('FloorLamp', 1, 'lighting', 1.4, 1.4, 5, 'tall floor lamp; part "shade" glows')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 0.2, 0.6, col(IRON))
    g.box((-0.08, -0.08, 0.2), (0.08, 0.08, 4.0), col('#C9A24A'))
    s = p.part('shade', anim='pulse', parent='body')
    s.cyl(0, 0, 3.8, 5.0, 0.7, glow(WARM, 2.0), r1=0.45)
    s.carve((-1, -1, 3.8), (1, 1, 4.9), lambda X, Y, Z: X * X + Y * Y < (0.55 - (Z - 3.8) * 0.2) ** 2)


@D('FoodBowlMat', 1, 'food', 3, 2, 0.6, 'mat with two food bowls')
def _(p):
    g = p.part()
    g.rrbox((-1.5, -1, 0), (1.5, 1, 0.2), 0.3, col('#4FB3B0'))
    bowl(g, -0.7, 0, 0.2, 0.55, 0.4, col('#FFFFFF'), col('#C98E52'))
    bowl(g, 0.7, 0, 0.2, 0.55, 0.4, col('#F28FA8'), col('#E8BF48'))


@D('PetWaterFountain', 1, 'food', 1.6, 1.6, 1.4, 'little water fountain; part "water" drips')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 0.6, 0.8, col('#FFFFFF'))
    g.carve((-1, -1, 0.3), (1, 1, 0.7), lambda X, Y, Z: X * X + Y * Y < 0.6 ** 2)
    g.cyl(0, 0, 0.3, 1.2, 0.18, col('#8FD3FF'))
    w = p.part('water', anim='drip', parent='body')
    w.cyl(0, 0, 0.3, 0.45, 0.6, glow('#7FD3FF', 0.6))
    w.ell((0, 0, 1.25), (0.3, 0.3, 0.15), glow('#BFE9FF', 0.8))


# =============================================================== 2 Book nook
def book(g, x0, y0, z0, x1, y1, z1, c):
    g.box((x0, y0, z0), (x1, y1, z1), col(c))
    g.paint((x0, y0, z0), (x1, y1, z1), lambda X, Y, Z: (X > x1 - 0.12) | (Y < y0 + 0.12) & (np.abs(Z - (z0 + z1) / 2) < (z1 - z0) / 2 - 0.08), col('#FFF4E0'))


@D('ArmchairBed', 2, 'cozy', 3.5, 3, 2.5, 'deep armchair with a cushion')
def _(p):
    g = p.part()
    c = pick(FABRIC['teal'], 411)
    g.rrbox((-1.75, -1.5, 0.3), (1.75, 1.5, 1.2), 0.2, c)
    g.rrbox((-1.75, 0.8, 1.2), (1.75, 1.5, 2.5), 0.25, c)
    for x in (-1.75, 1.15):
        g.rrbox((x, -1.5, 1.2), (x + 0.6, 1.5, 1.9), 0.25, c)
    cushion(g, -1.1, -1.3, 1.1, 0.8, 1.2, 0.35, col('#F2B94B'), '#FFF4E0')
    legs(g, -1.6, -1.35, 1.6, 1.35, 0, 0.3, 0.25, col('#8B5A33'))


@D('BookStackClimb', 2, 'toys', 3, 2, 2.4, 'big stacked books to climb')
def _(p):
    g = p.part()
    cs = ['#D9534F', '#3D5A80', '#9CC59A', '#F2B94B', '#B9A3E3', '#4FB3B0']
    z = 0
    for i, (w, d, h) in enumerate(((3, 2, 0.5), (2.6, 1.8, 0.45), (2.8, 1.6, 0.4), (2.2, 1.7, 0.45), (2.4, 1.5, 0.4))):
        dx = (0.15 if i % 2 else -0.15)
        book(g, -w / 2 + dx, -d / 2, z, w / 2 + dx, d / 2, z + h, cs[i % 6])
        z += h


@D('RollingGlobe', 2, 'toys', 1.4, 1.4, 1.6, 'desk globe; part "globe" spins')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 0.15, 0.5, col('#8B5A33'))
    g.box((-0.05, -0.05, 0.15), (0.05, 0.05, 0.4), col('#C9A24A'))
    g.fill((-0.8, -0.1, 0.3), (0.8, 0.1, 1.7), lambda X, Y, Z: np.abs(np.sqrt(X * X + (Z - 1.0) ** 2) - 0.7) < 0.07, col('#C9A24A'))
    q = p.part('globe', anim='spin', parent='body', pivot=(0, 0, 1.0))
    q.ell((0, 0, 1.0), (0.6, 0.6, 0.6), lambda X, Y, Z: np.where(np.sin(X * 4) * np.sin(Y * 3) + np.sin(Z * 5) > 0.6, col('#7BD88F'), col('#4FA3E0')))


@D('PaperPlaneMobile', 2, 'toys', 3, 3, 3, 'paper planes hanging from a ring; part "planes" turns')
def _(p):
    g = p.part()
    g.box((-0.05, -0.05, 2.6), (0.05, 0.05, 3.0), col('#8B5A33'))
    q = p.part('planes', anim='turn', parent='body')
    q.fill((-1.5, -1.5, 2.5), (1.5, 1.5, 2.7), lambda X, Y, Z: np.abs(np.sqrt(X * X + Y * Y) - 1.2) < 0.08, col('#8B5A33'))
    for i, c in enumerate(('#FFFFFF', '#FFE7A8', '#BFE9FF')):
        a = i * 2 * math.pi / 3
        x, y = math.cos(a) * 1.2, math.sin(a) * 1.2
        q.box((x - 0.03, y - 0.03, 1.7), (x + 0.03, y + 0.03, 2.5), col('#B0BEC5'))
        q.fill((x - 0.5, y - 0.5, 1.4), (x + 0.5, y + 0.5, 1.75),
               lambda X, Y, Z, x=x, y=y: (np.abs(X - x) * 0.6 + np.abs(Z - 1.55) < 0.25) & (np.abs(Y - y) < 0.4) & ((Y - y) > -0.4 + np.abs(X - x)), col(c))


@D('BookshelfLights', 2, 'lighting', 4, 1, 4, 'bookshelf with warm fairy bulbs; part "bulbs" twinkles')
def _(p):
    g = p.part()
    g.box((-2, 0, 0), (2, 1, 4), pick(WOOD_D, 412))
    g.carve((-1.8, -0.1, 0.2), (1.8, 0.85, 3.8))
    for z in (1.4, 2.6):
        g.box((-1.8, 0, z), (1.8, 0.85, z + 0.15), pick(WOOD_D, 412))
    cs = ['#D9534F', '#3D5A80', '#9CC59A', '#F2B94B', '#B9A3E3', '#4FB3B0', '#FFB38A']
    rng = np.random.default_rng(3)
    for z0 in (0.2, 1.55, 2.75):
        x = -1.75
        while x < 1.6:
            w = rng.uniform(0.18, 0.32)
            h = rng.uniform(0.75, 1.0)
            g.box((x, 0.1, z0), (x + w, 0.8, z0 + h), col(cs[rng.integers(len(cs))]))
            x += w + 0.02
    b = p.part('bulbs', anim='flicker', parent='body')
    for i in range(9):
        b.ell((-1.8 + i * 0.45, -0.05, 3.85 - 0.12 * math.sin(i * 1.3)), (0.1, 0.1, 0.12), glow(WARM, 3))


@D('TeaTable', 2, 'food', 3, 2, 1.4, 'low tea table with a teapot and cakes')
def _(p):
    g = p.part()
    g.box((-1.5, -1, 0.8), (1.5, 1, 1.0), pick(WOOD, 413))
    legs(g, -1.4, -0.9, 1.4, 0.9, 0, 0.8, 0.2, pick(WOOD_D, 414))
    g.ell((-0.6, 0, 1.3), (0.35, 0.35, 0.3), col('#4FB3B0'))
    g.seg((-0.3, 0, 1.3), (-0.05, 0, 1.45), 0.07, col('#4FB3B0'))
    for x in (0.4, 0.9):
        g.cyl(x, 0.2, 1.0, 1.25, 0.22, col('#FFF4E0'))
        g.cyl(x, 0.2, 1.25, 1.35, 0.18, col('#F28FA8'))


@D('CookieJar', 2, 'food', 1.4, 1.4, 1.8, 'glass jar of cookies')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 1.4, 0.65, col('#D6F0FF'))
    g.cyl(0, 0, 0.1, 1.1, 0.55, lambda X, Y, Z: np.where(hnoise(X, Y, Z, 41) > 0.85, col('#5A3E2E'), col('#D9A766')))
    g.cyl(0, 0, 1.4, 1.65, 0.5, col('#D9534F'))
    g.ell((0, 0, 1.75), (0.15, 0.15, 0.12), col('#D9534F'))


# ========================================================== 3 Plant sunroom
@D('PlanterBed', 3, 'cozy', 4, 3, 1.6, 'raised planter box with a soft cushion and ferns')
def _(p):
    g = p.part()
    g.box((-2, -1.5, 0), (2, 1.5, 0.8), pick(WOOD, 421))
    g.paint((-2, -1.5, 0), (2, 1.5, 0.8), lambda X, Y, Z: np.mod(X + 2, 0.8) < 0.1, col('#8B5A33'))
    cushion(g, -1.8, -1.3, 1.8, 0.6, 0.8, 0.35, col('#9CC59A'), '#FFF4E0')
    for x in (-1.5, -0.5, 0.5, 1.5):
        g.blob((x, 1.0, 1.1), (0.55, 0.4, 0.5), pick(['#4FA84A', '#5DB13E', '#6CC64B'], 422), amp=0.15, f=4, seed=int(x * 3 + 9))


@D('PlantPotClimb', 3, 'toys', 3, 3, 2.6, 'stack of terracotta pots to climb, with a plant on top')
def _(p):
    g = p.part()
    terra = pick(['#D9784A', '#CF6E40'], 423)
    for (x, y, z, r) in ((-0.6, -0.4, 0, 0.75), (0.7, 0.3, 0, 0.75), (0, 0, 1.0, 0.7)):
        g.cyl(x, y, z, z + 1.0, r * 0.8, terra, r1=r)
        g.cyl(x, y, z + 0.85, z + 1.0, r + 0.05, col('#E8916A'))
    g.blob((0, 0, 2.3), (0.6, 0.6, 0.45), pick(['#4FA84A', '#5DB13E'], 424), amp=0.15, f=4)


# ========================================================= 4 Bakery kitchen
@D('BreadBasketBed', 4, 'cozy', 3.5, 3, 1.3, 'bread basket lined with a tea towel')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 1.1, 1.4, lambda X, Y, Z: np.where(np.mod(np.arctan2(Y, X) * 6 + Z * 8, 2) < 1, col('#C98E52'), col('#B07A42')), r1=1.7)
    g.carve((-1.7, -1.7, 0.3), (1.7, 1.7, 1.2), lambda X, Y, Z: X * X + Y * Y < (1.3 + Z * 0.25) ** 2)
    g.cyl(0, 0, 0.3, 0.55, 1.35, lambda X, Y, Z: np.where((np.mod(X, 0.6) < 0.3) ^ (np.mod(Y, 0.6) < 0.3), col('#FFFFFF'), col('#D9534F')))
    g.seg((1.2, 0.8, 0.8), (1.9, 1.1, 1.25), 0.25, col('#E2B273'))


@D('OvenMittNest', 4, 'cozy', 3, 3, 1, 'pile of oven mitts and tea towels')
def _(p):
    g = p.part()
    for (x, y, z, c) in ((-0.6, -0.4, 0, 'red'), (0.6, 0.2, 0, 'mustard'), (0, 0.6, 0.35, 'cream'), (-0.2, -0.2, 0.45, 'teal')):
        g.rrbox((x - 0.9, y - 0.6, z), (x + 0.9, y + 0.6, z + 0.4), 0.18, pick(FABRIC[c], 431))


@D('RollingPin', 4, 'toys', 2.4, 0.8, 0.8, 'big wooden rolling pin; rolls')
def _(p):
    g = p.part('pin', anim='roll', pivot=(0, 0, 0.4))
    g.seg((-0.8, 0, 0.4), (0.8, 0, 0.4), 0.38, pick(WOOD, 432))
    g.seg((-1.2, 0, 0.4), (1.2, 0, 0.4), 0.14, col('#B07A42'))


@D('CupcakeTower', 4, 'toys', 2.4, 2.4, 3, 'tower of giant cupcakes')
def _(p):
    g = p.part()
    for z, r, c in ((0, 1.2, '#F28FA8'), (1.0, 0.9, '#B9A3E3'), (1.9, 0.6, '#FFF4E0')):
        g.cyl(0, 0, z, z + 0.55, r * 0.8, col('#F2B94B'), r1=r)
        g.ell((0, 0, z + 0.6), (r * 1.05, r * 1.05, 0.4), col(c), cond=lambda X, Y, Z, z=z: Z >= z + 0.5)
        g.paint((-r * 1.1, -r * 1.1, z + 0.5), (r * 1.1, r * 1.1, z + 1.0), lambda X, Y, Z: hnoise(X, Y, Z, 43) > 0.9, col('#7BD88F'))
    g.ell((0, 0, 2.85), (0.2, 0.2, 0.2), col('#D9534F'))


@D('DonutRing', 4, 'toys', 1.6, 0.8, 1.6, 'giant donut toy; rolls')
def _(p):
    g = p.part('donut', anim='roll', pivot=(0, 0, 0.8))

    def tor(X, Y, Z):
        d = np.sqrt(X * X + (Z - 0.8) ** 2) - 0.5
        return d * d + Y * Y <= 0.3 ** 2
    g.fill((-0.85, -0.35, 0), (0.85, 0.35, 1.65), tor, lambda X, Y, Z: np.where(Y < -0.05, np.where(hnoise(X, Y, Z, 44) > 0.85, col('#7BD88F'), col('#F28FA8')),
                                                                                col('#E2B273')))


@D('PendantLamp', 4, 'lighting', 1.4, 1.4, 3, 'kitchen pendant lamp; part "bulb" glows')
def _(p):
    g = p.part()
    g.box((-0.04, -0.04, 1.2), (0.04, 0.04, 3), col(IRON))
    g.cyl(0, 0, 0.6, 1.3, 0.7, col('#4FB3B0'), r1=0.2)
    g.carve((-1, -1, 0.5), (1, 1, 1.1), lambda X, Y, Z: X * X + Y * Y < (0.6 - (Z - 0.6) * 0.6) ** 2)
    b = p.part('bulb', anim='pulse', parent='body')
    b.ell((0, 0, 0.75), (0.25, 0.25, 0.25), glow(WARM, 3.5))


@D('OvenGlow', 4, 'lighting', 3, 1.6, 3, 'little brick oven with a warm glow; part "fire" flickers')
def _(p):
    g = p.part()
    brick = pick(['#C2573F', '#B54D36', '#CC6248'], 433)
    g.box((-1.5, -0.8, 0), (1.5, 0.8, 2.0), brick)
    g.paint((-1.5, -0.8, 0), (1.5, 0.8, 2.0), lambda X, Y, Z: (np.mod(Z, 0.4) < 0.08) | (np.mod(X + np.floor(Z / 0.4) * 0.3, 0.6) < 0.08), col('#E8D5C0'))
    g.ell((0, 0, 2.0), (1.5, 0.8, 0.9), brick, cond=lambda X, Y, Z: Z >= 2.0)
    g.box((-0.15, -0.15, 2.6), (0.15, 0.15, 3.0), col(IRON))
    g.fill((-0.8, -0.9, 0.4), (0.8, -0.6, 1.6), lambda X, Y, Z: (Z < 1.2) | (X * X + (Z - 1.2) ** 2 < 0.64), col('#2E2A2A'))
    f = p.part('fire', anim='flicker', parent='body')
    f.fill((-0.65, -0.95, 0.45), (0.65, -0.85, 1.4), lambda X, Y, Z: (Z < 1.1) | (X * X + (Z - 1.1) ** 2 < 0.4), glow('#FF8A3D', 3))


@D('BakeryCounter', 4, 'food', 5, 2, 2, 'bakery counter with bread and pastries')
def _(p):
    g = p.part()
    g.box((-2.5, -1, 0), (2.5, 1, 1.4), pick(FABRIC['cream'], 434))
    g.box((-2.6, -1.1, 1.4), (2.6, 1.1, 1.6), pick(WOOD, 435))
    g.paint((-2.5, -1.05, 0.1), (2.5, -0.95, 1.3), lambda X, Y, Z: np.mod(X, 1.0) < 0.12, col('#4FB3B0'))
    for x, c, kind in ((-1.8, '#D9A766', 'loaf'), (-0.6, '#E2B273', 'loaf'), (0.6, '#F28FA8', 'cake'), (1.8, '#D9A766', 'pretzel')):
        if kind == 'loaf':
            g.ell((x, 0, 1.75), (0.5, 0.3, 0.25), col(c))
        elif kind == 'cake':
            g.cyl(x, 0, 1.6, 2.0, 0.4, col('#FFF4E0'))
            g.cyl(x, 0, 1.9, 2.05, 0.42, col(c))
        else:
            g.fill((x - 0.5, -0.1, 1.6), (x + 0.5, 0.1, 2.1), lambda X, Y, Z, x=x: np.abs(np.sqrt((X - x) ** 2 + (Z - 1.85) ** 2) - 0.2) < 0.09, col(c))


@D('MilkJugFountain', 4, 'food', 2, 2, 2.4, 'milk jug pouring into a bowl; part "milk" drips')
def _(p):
    g = p.part()
    bowl(g, 0, -0.3, 0, 0.8, 0.5, col('#4FB3B0'), col('#FFFFFF'))
    g.box((0.6, 0.4, 0), (0.9, 0.7, 1.6), pick(WOOD_D, 436))
    g.cyl(0.4, 0.5, 1.4, 2.3, 0.4, col('#FFFFFF'), r1=0.3)
    g.seg((0.1, 0.3, 2.1), (-0.1, 0.0, 2.2), 0.1, col('#FFFFFF'))
    m = p.part('milk', anim='drip', parent='body')
    m.box((-0.15, -0.05, 0.5), (-0.05, 0.05, 2.1), glow('#FFFFFF', 0.4))


# ========================================================== 5 Games lounge
@D('SofaBed', 5, 'cozy', 5, 2.5, 2.2, 'comfy sofa')
def _(p):
    g = p.part()
    c = pick(FABRIC['navy'], 441)
    g.rrbox((-2.5, -1.25, 0.3), (2.5, 1.25, 1.1), 0.2, c)
    g.rrbox((-2.5, 0.6, 1.1), (2.5, 1.25, 2.2), 0.25, c)
    for x in (-2.5, 1.9):
        g.rrbox((x, -1.25, 1.1), (x + 0.6, 1.25, 1.7), 0.25, c)
    for x in (-1.0, 1.0):
        cushion(g, x - 0.9, -1.1, x + 0.9, 0.6, 1.1, 0.3, col('#F2B94B' if x < 0 else '#F28FA8'), '#FFF4E0')
    legs(g, -2.3, -1.1, 2.3, 1.1, 0, 0.3, 0.2, col('#5A3E2E'))


@D('BeanBagPile', 5, 'cozy', 4, 3, 1.3, 'three beanbags in a huddle')
def _(p):
    g = p.part()
    for x, y, c in ((-1.0, -0.4, 'red'), (1.0, -0.3, 'teal'), (0, 0.7, 'mustard')):
        g.blob((x, y, 0.55), (0.95, 0.9, 0.7), pick(FABRIC[c], 442), amp=0.06, f=2, seed=int(x * 5 + 7))
    g.carve((-3, -3, -2), (3, 3, 0))


@D('ArcadeCabinet', 5, 'toys', 1.8, 1.6, 3.6, 'little arcade machine; part "screen" flickers')
def _(p):
    g = p.part()
    body = pick(['#6A4FB3', '#6248A8'], 443)
    g.box((-0.9, -0.5, 0), (0.9, 0.8, 3.6), body)
    g.fill((-0.9, -0.8, 1.1), (0.9, -0.5, 1.6), lambda X, Y, Z: Y > -0.5 - (Z - 1.1) * 0.6, col('#2E2A2A'))
    g.ell((-0.4, -0.65, 1.62), (0.1, 0.1, 0.12), col('#D9534F'))
    g.ell((0.2, -0.65, 1.62), (0.09, 0.09, 0.1), col('#F2B94B'))
    g.ell((0.45, -0.65, 1.62), (0.09, 0.09, 0.1), col('#4FB3B0'))
    g.box((-0.9, -0.6, 3.1), (0.9, -0.5, 3.6), glow('#FF6FA8', 2))
    s = p.part('screen', anim='flicker', parent='body')
    s.box((-0.7, -0.55, 1.8), (0.7, -0.45, 2.9), lambda X, Y, Z: np.where((np.mod(X * 5, 1) < 0.5) & (np.mod(Z * 5, 1) < 0.5), glow('#7BFFC4', 2), glow('#3D5A80', 1)))


@D('BallPit', 5, 'toys', 4, 4, 1.4, 'ball pit full of colourful balls')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 1.0, 2.0, col('#FFFFFF'))
    g.cyl(0, 0, 0.8, 1.0, 2.05, col('#4FB3B0'))
    g.carve((-2, -2, 0.3), (2, 2, 1.1), lambda X, Y, Z: X * X + Y * Y < 1.75 ** 2)
    ids = np.array([col(c) for c in ('#D9534F', '#F2B94B', '#4FA3E0', '#7BD88F', '#F28FA8')])
    g.fill((-1.8, -1.8, 0.3), (1.8, 1.8, 1.25), lambda X, Y, Z: (X * X + Y * Y < 1.75 ** 2) & (Z < 1.0 + 0.2 * np.sin(X * 4) * np.sin(Y * 4)),
           lambda X, Y, Z: ids[(hnoise(np.floor(X / 0.3), np.floor(Y / 0.3), np.floor(Z / 0.3), 45) * 5).astype(int) % 5])


@D('ToyTrain', 5, 'toys', 4, 1.2, 1.4, 'wooden toy train; part "train" rolls back and forth')
def _(p):
    g = p.part()
    for y in (-0.35, 0.35):
        g.box((-2, y - 0.06, 0), (2, y + 0.06, 0.1), col('#8B5A33'))
    t = p.part('train', anim='slide', parent='body')
    t.box((0.2, -0.45, 0.25), (1.6, 0.45, 0.9), col('#D9534F'))
    t.box((0.9, -0.45, 0.9), (1.6, 0.45, 1.35), col('#D9534F'))
    t.cyl(0.5, 0, 0.9, 1.25, 0.15, col('#2E2A2A'))
    t.box((-1.6, -0.45, 0.25), (0.0, 0.45, 0.75), col('#4FA3E0'))
    for x in (-1.3, -0.3, 0.5, 1.3):
        t.seg((x, -0.5, 0.25), (x, 0.5, 0.25), 0.2, col('#F2B94B'))


@D('NeonSign', 5, 'lighting', 3, 0.4, 2, 'neon "PLAY" style heart sign on the wall; part "neon" pulses')
def _(p):
    g = p.part()
    g.box((-1.5, 0.15, 0), (1.5, 0.4, 2), col('#2E2A3A'))
    n = p.part('neon', anim='pulse', parent='body')

    def heart(X, Y, Z):
        x, z = (X) / 0.9, (Z - 1.0) / 0.9
        v = (x * x + z * z - 1) ** 3 - x * x * z ** 3
        return np.abs(v) < 0.12
    n.fill((-1.2, 0.05, 0.1), (1.2, 0.15, 1.9), heart, glow('#FF6FA8', 3))


@D('LavaLamp', 5, 'lighting', 1, 1, 2.2, 'lava lamp; part "lava" bobs and glows')
def _(p):
    g = p.part()
    g.cyl(0, 0, 0, 0.5, 0.45, col('#C9A24A'), r1=0.3)
    g.cyl(0, 0, 1.8, 2.2, 0.3, col('#C9A24A'), r1=0.15)
    g.cyl(0, 0, 0.5, 1.8, 0.3, glow('#B9A3E3', 0.6), r1=0.38)
    l_ = p.part('lava', anim='bob', parent='body')
    for z, r in ((0.8, 0.2), (1.35, 0.15)):
        l_.ell((0, -0.05, z), (r, r, r * 1.3), glow('#FF8A3D', 2.5))


@D('PizzaTable', 5, 'food', 3, 3, 1.4, 'round table with a pizza')
def _(p):
    g = p.part()
    g.cyl(0, 0, 1.0, 1.15, 1.5, pick(WOOD, 446))
    g.cyl(0, 0, 0, 1.0, 0.2, col(IRON))
    g.cyl(0, 0, 0, 0.1, 0.7, col(IRON))
    g.cyl(0, 0, 1.15, 1.3, 1.0, col('#E2B273'))
    g.cyl(0, 0, 1.3, 1.35, 0.85, lambda X, Y, Z: np.where(hnoise(np.floor(X / 0.2), np.floor(Y / 0.2), Z * 0, 46) > 0.8, col('#B5302B'), col('#F2B94B')))


@D('SodaFountain', 5, 'food', 2, 1.6, 3, 'drinks machine; part "bubbles" bob')
def _(p):
    g = p.part()
    g.box((-1, -0.8, 0), (1, 0.8, 3), col('#D9534F'))
    g.box((-0.8, -0.85, 1.6), (0.8, -0.75, 2.8), glow('#BFE9FF', 0.8))
    g.box((-0.8, -0.85, 0.3), (0.8, -0.75, 0.9), col('#2E2A2A'))
    b = p.part('bubbles', anim='bob', parent='body')
    for x, z in ((-0.4, 1.9), (0.1, 2.3), (0.45, 2.0)):
        b.ell((x, -0.9, z), (0.12, 0.05, 0.12), col('#FFFFFF'))


# ============================================================ 6 Winter cabin
@D('KnitBlanketBed', 6, 'cozy', 4, 3, 1.4, 'bed piled with a chunky knit blanket')
def _(p):
    g = p.part()
    g.box((-2, -1.5, 0), (2, 1.5, 0.6), pick(WOOD_D, 451))
    g.rrbox((-1.9, -1.4, 0.6), (1.9, 1.4, 1.2), 0.25, lambda X, Y, Z: np.where(np.mod(np.floor(X / 0.3) + np.floor(Z / 0.2), 2) == 0, col('#D9534F'), col('#E8665F')))
    g.paint((-2, -1.5, 0.6), (2, 1.5, 1.3), lambda X, Y, Z: np.abs(Y + 0.4) < 0.15, col('#FFF4E0'))
    g.rrbox((-1.5, 0.6, 1.1), (1.5, 1.35, 1.45), 0.15, col('#FFF4E0'))


@D('Sled', 6, 'toys', 3, 1.6, 1.2, 'wooden sled')
def _(p):
    g = p.part()
    for y in (-0.6, 0.6):
        g.fill((-1.5, y - 0.08, 0), (1.5, y + 0.08, 0.8), lambda X, Y, Z: (Z < 0.12) | ((X < -1.2) & (np.abs(np.sqrt((X + 1.2) ** 2 + (Z - 0.45) ** 2) - 0.4) < 0.08)),
               col('#C9A24A'))
        for x in (-0.8, 0.8):
            g.box((x - 0.06, y - 0.06, 0), (x + 0.06, y + 0.06, 0.5), col('#C9A24A'))
    g.box((-1.2, -0.75, 0.5), (1.4, 0.75, 0.7), lambda X, Y, Z: np.where(np.mod(X, 0.5) < 0.08, col('#8B5A33'), col('#D9534F')))


@D('Fireplace', 6, 'lighting', 4, 1.6, 4, 'stone fireplace with a mantel; part "flames" flickers')
def _(p):
    g = p.part()
    stone = pick(['#9AA3B3', '#8C95A6', '#A6AEBD'], 452)
    g.box((-2, 0, 0), (2, 1.6, 4), stone)
    g.paint((-2, 0, 0), (2, 1.6, 4), lambda X, Y, Z: (np.mod(Z, 0.5) < 0.08) | (np.mod(X + np.floor(Z / 0.5) * 0.35, 0.7) < 0.08), col('#6E778A'))
    g.carve((-1.2, -0.1, 0.3), (1.2, 1.1, 2.0))
    g.box((-2.3, -0.3, 2.3), (2.3, 1.6, 2.6), pick(WOOD_D, 453))
    g.box((-1.2, 0.0, 0.3), (1.2, 1.1, 0.45), col('#2E2A2A'))
    for x in (-0.5, 0.4):
        g.seg((x - 0.4, 0.4, 0.55), (x + 0.4, 0.6, 0.55), 0.14, col('#6B4A3A'))
    g.box((-1.6, 0.2, 2.6), (-1.3, 0.5, 3.0), col('#D9534F'))
    g.box((1.2, 0.2, 2.6), (1.6, 0.5, 2.9), col('#9CC59A'))
    f = p.part('flames', anim='flicker', parent='body')
    for x, h in ((-0.6, 0.9), (0.0, 1.2), (0.6, 0.8)):
        f.cyl(x, 0.5, 0.6, 0.6 + h, 0.3, glow('#FF8A3D', 3.5), r1=0.04)
        f.cyl(x, 0.45, 0.6, 0.6 + h * 0.55, 0.16, glow('#FFD166', 4), r1=0.03)


@D('HotCocoaPot', 6, 'food', 2.4, 2, 1.6, 'pot of hot cocoa with mugs; part "steam" drifts')
def _(p):
    g = p.part()
    g.cyl(-0.3, 0, 0, 1.0, 0.65, col('#D9534F'), r1=0.7)
    g.cyl(-0.3, 0, 0.8, 0.95, 0.55, col('#6B3E2A'))
    for x, y in ((0.8, -0.5), (0.85, 0.5)):
        g.cyl(x, y, 0, 0.55, 0.28, col('#FFF4E0'))
        g.cyl(x, y, 0.45, 0.55, 0.22, col('#6B3E2A'))
        g.ell((x + 0.3, y, 0.3), (0.1, 0.06, 0.12), col('#FFF4E0'))
    s = p.part('steam', anim='bob', parent='body')
    s.ell((-0.3, 0, 1.3), (0.3, 0.3, 0.2), col('#F2F6FF'))


# ============================================================= 7 Art studio
PAINTS = ['#D9534F', '#F2B94B', '#4FA3E0', '#7BD88F', '#B9A3E3', '#F28FA8']


def splat(seed):
    ids = np.array([col(c) for c in PAINTS])

    def c(X, Y, Z, base):
        h = hnoise(np.floor(X / 0.4), np.floor(Y / 0.4), np.floor(Z / 0.4), seed)
        return np.where(h > 0.82, ids[(h * 97).astype(int) % len(ids)], base)
    return c


@D('PaintSplatCushion', 7, 'cozy', 3.5, 3.5, 0.8, 'big cushion with paint splats')
def _(p):
    g = p.part()
    sp = splat(461)
    g.cyl(0, 0, 0, 0.7, 1.75, lambda X, Y, Z: sp(X, Y, Z, col('#FFF4E0')))
    g.paint((-2, -2, 0.25), (2, 2, 0.4), lambda X, Y, Z: X * X + Y * Y > 1.6 ** 2, col('#3D5A80'))


@D('CanvasTent', 7, 'cozy', 3, 3, 3, 'little canvas tent made from an easel cloth')
def _(p):
    g = p.part()
    sp = splat(462)
    g.fill((-1.5, -1.5, 0), (1.5, 1.5, 2.8), lambda X, Y, Z: (np.abs(X) < 1.45 * (1 - Z / 2.8)) & (np.abs(Y) < 1.4), lambda X, Y, Z: sp(X, Y, Z, col('#F7EAD3')))
    g.carve((-1.5, -1.5, 0), (1.5, 1.2, 2.6), lambda X, Y, Z: np.abs(X) < 1.25 * (1 - Z / 2.6))
    for x in (-0.15, 0.05):
        g.seg((x, -1.5, 2.6), (x, 1.5, 2.6), 0.08, pick(WOOD_D, 463))


@D('Easel', 7, 'toys', 2, 1.6, 3.4, 'easel with a painting')
def _(p):
    g = p.part()
    w = pick(WOOD, 464)
    g.seg((-0.8, -0.5, 0), (-0.2, 0, 3.2), 0.08, w)
    g.seg((0.8, -0.5, 0), (0.2, 0, 3.2), 0.08, w)
    g.seg((0, 0.8, 0), (0, 0.1, 3.0), 0.08, w)
    g.box((-0.9, -0.45, 1.2), (0.9, -0.15, 1.3), w)
    g.box((-0.8, -0.35, 1.3), (0.8, -0.2, 2.9), col('#FFFFFF'))
    g.paint((-0.8, -0.4, 1.3), (0.8, -0.2, 2.9), lambda X, Y, Z: (Z < 1.9) & (Z < 1.7 + 0.2 * np.sin(X * 4)), col('#7BD88F'))
    g.paint((-0.8, -0.4, 1.3), (0.8, -0.2, 2.9), lambda X, Y, Z: (X - 0.3) ** 2 + (Z - 2.4) ** 2 < 0.06, col('#F2B94B'))
    g.paint((-0.8, -0.4, 1.3), (0.8, -0.2, 2.9), lambda X, Y, Z: (Z >= 1.9) & ((X - 0.3) ** 2 + (Z - 2.4) ** 2 >= 0.06), col('#8FD3FF'))


@D('PaintPotStack', 7, 'toys', 2.4, 2.4, 2.2, 'stack of paint pots to climb')
def _(p):
    g = p.part()
    for (x, y, z, c) in ((-0.55, -0.35, 0, PAINTS[0]), (0.6, 0.3, 0, PAINTS[2]), (0, 0, 1.0, PAINTS[1])):
        g.cyl(x, y, z, z + 1.0, 0.6, col('#C9CED6'))
        g.cyl(x, y, z + 0.9, z + 1.05, 0.55, col(c))
        g.paint((x - 0.7, y - 0.7, z + 0.3), (x + 0.7, y + 0.7, z + 0.9), lambda X, Y, Z, x=x: np.abs(X - x) < 0.15, col(c))


@D('ClayWheel', 7, 'toys', 2, 2, 1.6, "potter's wheel with a pot; part \"wheel\" spins")
def _(p):
    g = p.part()
    g.box((-0.9, -0.9, 0), (0.9, 0.9, 0.9), pick(WOOD_D, 465))
    w = p.part('wheel', anim='spin', parent='body', pivot=(0, 0, 0.9))
    w.cyl(0, 0, 0.9, 1.05, 0.85, col('#9AA3B3'))
    w.cyl(0, 0, 1.05, 1.55, 0.35, col('#D9784A'), r1=0.25)
    w.carve((-0.3, -0.3, 1.3), (0.3, 0.3, 1.6), lambda X, Y, Z: X * X + Y * Y < 0.15 ** 2)


@D('SpotLamp', 7, 'lighting', 1.4, 1.4, 4, 'studio spotlight on a stand; part "lamp" glows')
def _(p):
    g = p.part()
    for a in (0, 2.1, 4.2):
        g.seg((0, 0, 1.2), (math.cos(a) * 0.6, math.sin(a) * 0.6, 0), 0.08, col(IRON))
    g.box((-0.08, -0.08, 1.2), (0.08, 0.08, 3.3), col(IRON))
    g.seg((0, 0.2, 3.5), (0, -0.4, 3.2), 0.38, col('#2E2A2A'))
    q = p.part('lamp', anim='pulse', parent='body')
    q.seg((0, -0.45, 3.18), (0, -0.55, 3.13), 0.32, glow('#FFF1D0', 3))


@D('GalleryLights', 7, 'lighting', 6, 0.4, 1.2, 'rail of little gallery lights over framed pictures; part "lights" glows')
def _(p):
    g = p.part()
    g.box((-3, 0.25, 1.0), (3, 0.4, 1.15), col(IRON))
    for i, x in enumerate((-2.2, 0, 2.2)):
        g.box((x - 0.8, 0.3, -1.6), (x + 0.8, 0.4, 0.3), col('#C9A24A'))
        g.box((x - 0.65, 0.25, -1.45), (x + 0.65, 0.3, 0.15), col(PAINTS[i * 2 % 6]))
    li = p.part('lights', anim='pulse', parent='body')
    for x in (-2.2, 0, 2.2):
        li.ell((x, 0.1, 0.9), (0.2, 0.15, 0.12), glow('#FFF1D0', 3))


@D('SnackPalette', 7, 'food', 3, 2, 0.5, 'painter\'s palette used as a snack tray')
def _(p):
    g = p.part()
    g.fill((-1.5, -1, 0), (1.5, 1, 0.2), lambda X, Y, Z: (X * X / 2.25 + Y * Y < 1) & ((X - 0.9) ** 2 + (Y + 0.3) ** 2 > 0.09), pick(WOOD, 466))
    for (x, y), c in zip(((-0.9, 0.2), (-0.3, 0.55), (0.35, 0.5), (-0.4, -0.4), (0.3, -0.5)), ('#D9534F', '#F2B94B', '#7BD88F', '#F28FA8', '#B9A3E3')):
        g.ell((x, y, 0.3), (0.2, 0.2, 0.16), col(c))


@D('SinkFountain', 7, 'food', 2, 1.4, 2.4, 'studio sink with a dripping tap; part "drops" drips')
def _(p):
    g = p.part()
    g.box((-1, -0.7, 0), (1, 0.7, 1.4), col('#FFFFFF'))
    g.carve((-0.8, -0.5, 1.0), (0.8, 0.5, 1.5))
    water(g, -0.8, -0.5, 1.0, 0.8, 0.5, 1.15)
    g.box((-0.1, 0.4, 1.4), (0.1, 0.6, 2.2), col('#B0BEC5'))
    g.seg((0, 0.5, 2.2), (0, 0.0, 2.1), 0.08, col('#B0BEC5'))
    d = p.part('drops', anim='drip', parent='body')
    d.box((-0.05, -0.05, 1.3), (0.05, 0.05, 1.9), glow('#BFE9FF', 0.8))
    g.paint((-1, -0.75, 0.2), (1, -0.65, 1.3), lambda X, Y, Z: hnoise(np.floor(X / 0.3), Y * 0, np.floor(Z / 0.3), 47) > 0.8, col('#F2B94B'))
