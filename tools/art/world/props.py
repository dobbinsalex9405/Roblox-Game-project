"""Hatchery Heist world props in the Storybook Farm direction.

Every prop is modelled once here, at 0.1-stud voxels, in the art frame (x
right, y back so the front is -y, z up, studs). From that one model:

- export.py writes games/hatchery-heist/src/shared/WorldArt.luau: the same
  shapes resampled to coarser voxels and merged into at most `budget` boxes,
  for the game to build from Parts today;
- build.py writes Blender meshes (.glb), review renders and the 3D viewer
  folders, for the mesh upload later.

A prop is a function that fills a Prop: one Grid per animated part.
"""
import math
import numpy as np

from vkit import Grid, VOX, col, hnoise, snoise
from styles import pick, egg as draw_egg, EGGS


class Prop:
    def __init__(self, pid, kind, lo, hi, budget=80, floor=None, zone=None, note='', factors=None):
        self.id, self.kind, self.lo, self.hi = pid, kind, lo, hi
        self.budget, self.floor, self.zone, self.note = budget, floor, zone, note
        self.factors = factors
        self.parts = []  # [name, anim, parent, pivot (studs, art frame), grid]
        self.anchor = None  # optional point (studs, art frame) the game places

    def part(self, name='body', anim='static', parent=None, pivot=(0, 0, 0)):
        for p in self.parts:
            if p[0] == name:
                return p[4]
        g = Grid(self.lo, self.hi)
        self.parts.append([name, anim, parent, pivot, g])
        return g


REGISTRY = {}


def prop(pid, kind, lo, hi, **kw):
    def deco(fn):
        REGISTRY[pid] = (fn, kind, lo, hi, kw)
        return fn
    return deco


def make(pid):
    fn, kind, lo, hi, kw = REGISTRY[pid]
    p = Prop(pid, kind, lo, hi, **kw)
    fn(p)
    return p


# ------------------------------------------------------------------ palette
WOOD = ['#C98E52', '#BF8549', '#D39A5E']
WOOD_D = ['#8B5A33', '#7A4D2B', '#9A6A3F']
BARK = ['#8B5A33', '#7A4D2B', '#9A6A3F']
RED = '#D2483D'
RED_D = '#A8352E'
CREAM = ['#F6EEDC', '#EDE2CB']
IRON = '#3B3B44'
STRAW = ['#F2CE5C', '#E8BF48', '#F7DA75', '#DDB040']
LAMP = ('#FFC870', 4.0)


def two_tone(dark, mid, light, z0, z1, seed=1):
    d, m, l_ = pick(dark, seed + 50), pick(mid, seed + 51), pick(light, seed + 52)

    def c(X, Y, Z):
        t = (Z - z0) / (z1 - z0) + 0.12 * snoise(X, Y, Z, 2.5, seed)
        return np.where(t < 0.15, d(X, Y, Z), np.where(t > 0.78, l_(X, Y, Z), m(X, Y, Z)))
    return c


def fruit(g, x, y, zc, r, n, rgb, seed, leaf='#2F7A2E', size=0.17):
    rng = np.random.default_rng(seed)
    fc, lc = col(rgb), col(leaf)
    for _ in range(n):
        a = rng.uniform(0, 2 * math.pi)
        e = rng.uniform(-0.4, 0.7)
        px = x + math.cos(a) * r * math.cos(e)
        py = y + math.sin(a) * r * math.cos(e)
        pz = zc + r * 0.7 * math.sin(e)
        g.ell((px, py, pz), (size, size, size), fc)
        g.box((px, py, pz + size - 0.02), (px + VOX, py + VOX, pz + size + 0.13), lc)


LEAF = dict(dark=['#3E9A3A', '#37903A'], mid=['#55B947', '#4DB043', '#5CC24F'], light=['#7AD35E', '#86DA66'])
AUTUMN = dict(dark=['#C2531F', '#B04A1C'], mid=['#E8782A', '#F08A2E', '#E06A24'], light=['#FFB547', '#FFC45E'])
PINE = dict(dark=['#1F6F45', '#1C6840'], mid=['#2E8A55', '#2A8350', '#33925B'], light=['#55B06E', '#5DB876'])
BLOSSOM = dict(dark=['#D9649F', '#CC5A93'], mid=['#F48CC4', '#EE80BC', '#F99BCF'], light=['#FFC2E2', '#FFD0E9'])


# -------------------------------------------------------------------- trees
def oak(p, leaf=LEAF, apples=0):
    g = p.part('body')
    trunk = pick(BARK, 41)
    g.cyl(0, 0, 0, 3.6, 0.55, trunk, r1=0.38)
    for a in range(4):
        ang = a * math.pi / 2 + 0.4
        g.seg((0, 0, 0.5), (math.cos(ang) * 0.9, math.sin(ang) * 0.9, 0), 0.25, trunk, r1=0.15)
    g.seg((0, 0, 3.0), (-1.3, 0.3, 4.6), 0.25, trunk, r1=0.15)
    g.seg((0, 0, 3.2), (1.2, -0.4, 4.8), 0.25, trunk, r1=0.15)
    c = two_tone(leaf['dark'], leaf['mid'], leaf['light'], 4.0, 7.6, 3)
    for i, (ctr, r) in enumerate([((0, 0, 5.4), (2.7, 2.7, 2.1)), ((-1.6, 0.4, 4.8), (1.8, 1.8, 1.5)), ((1.6, -0.5, 4.9), (1.8, 1.8, 1.5)),
                                  ((0.2, 1.3, 6.2), (1.7, 1.6, 1.4)), ((-0.4, -1.2, 6.4), (1.6, 1.6, 1.3))]):
        g.blob(ctr, r, c, amp=0.08, f=2.2, seed=3 + i)
    if apples:
        fruit(g, 0, 0, 5.4, 2.85, apples, '#E8413C', 5)


@prop('OakTree', 'tree', (-4.5, -4.5, 0), (4.5, 4.5, 8.2), budget=160, note='Round Oak, 8 tall')
def _oak(p):
    oak(p)


@prop('OakTreeAutumn', 'tree', (-4.5, -4.5, 0), (4.5, 4.5, 8.2), budget=160, note='Round Oak in autumn colours')
def _oak_autumn(p):
    oak(p, AUTUMN)


@prop('AppleTree', 'tree', (-3.6, -3.6, 0), (3.6, 3.6, 7.2), budget=160, note='Apple Tree, 7 tall')
def _apple(p):
    g = p.part('body')
    trunk = pick(BARK, 42)
    g.cyl(0, 0, 0, 3.0, 0.45, trunk, r1=0.32)
    for a in range(3):
        ang = a * 2 * math.pi / 3 + 0.2
        g.seg((0, 0, 0.4), (math.cos(ang) * 0.7, math.sin(ang) * 0.7, 0), 0.2, trunk, r1=0.12)
    g.seg((0, 0, 2.6), (0.9, 0.3, 3.8), 0.2, trunk, r1=0.13)
    c = two_tone(LEAF['dark'], LEAF['mid'], LEAF['light'], 3.2, 7.0, 6)
    g.blob((0, 0, 4.8), (2.6, 2.6, 2.1), c, amp=0.07, f=2.0, seed=6)
    g.blob((0.6, -0.4, 5.9), (1.5, 1.5, 1.1), c, amp=0.07, f=2.0, seed=7)
    fruit(g, 0, 0, 4.8, 2.65, 22, '#E8413C', 8, size=0.2)


@prop('BlossomTree', 'tree', (-3.8, -3.8, 0), (3.8, 3.8, 7.2), budget=160, note='Blossom Tree, 7 tall')
def _blossom(p):
    g = p.part('body')
    trunk = pick(['#6B4A3A', '#5E4033', '#775444'], 43)
    pts = [(0, 0, 0), (0.25, 0.1, 1.1), (-0.1, 0.25, 2.2), (0.3, -0.1, 3.1), (0.1, 0.15, 3.8)]
    for a, b in zip(pts, pts[1:]):
        g.seg(a, b, 0.42, trunk, r1=0.36)
    for a in range(4):
        ang = a * math.pi / 2 + 0.5
        g.seg((0, 0, 0.5), (math.cos(ang) * 0.9, math.sin(ang) * 0.9, 0), 0.25, trunk, r1=0.1)
    for a, b in [((0.1, 0.15, 3.6), (-1.6, 0.5, 4.8)), ((0.1, 0.15, 3.6), (1.6, -0.3, 4.7)), ((0.1, 0.15, 3.8), (0.2, 1.5, 5.2))]:
        g.seg(a, b, 0.24, trunk, r1=0.13)
    c = two_tone(BLOSSOM['dark'], BLOSSOM['mid'], BLOSSOM['light'], 4.0, 7.0, 9)
    for i, (ctr, r) in enumerate([((0, 0, 5.3), (2.1, 2.1, 1.4)), ((-1.7, 0.5, 4.9), (1.4, 1.4, 1.1)), ((1.7, -0.3, 4.8), (1.4, 1.4, 1.1)),
                                  ((0.2, 1.6, 5.3), (1.3, 1.2, 1.0)), ((-0.2, -1.4, 5.4), (1.3, 1.3, 1.0)), ((0.1, 0.1, 6.3), (1.3, 1.3, 0.8))]):
        g.blob(ctr, r, c, amp=0.12, f=2.4, seed=9 + i)
    # a few white blossoms dotted on top
    g.paint((-4, -4, 4.5), (4, 4, 7.2), lambda X, Y, Z: hnoise(X, Y, Z, 44) > 0.93, col('#FFFFFF'))


@prop('PineTree', 'tree', (-4.0, -4.0, 0), (4.0, 4.0, 11.2), budget=160, note='Tall Pine, 11 tall')
def _pine(p):
    g = p.part('body')
    trunk = pick(BARK, 45)
    g.cyl(0, 0, 0, 2.4, 0.5, trunk, r1=0.42)
    d, m, l_ = pick(PINE['dark'], 46), pick(PINE['mid'], 47), pick(PINE['light'], 48)
    for z0, r, hh in [(1.6, 3.7, 3.1), (3.7, 3.0, 2.8), (5.6, 2.3, 2.5), (7.4, 1.6, 2.2), (9.0, 0.9, 2.1)]:
        def cfn(X, Y, Z, z0=z0, hh=hh):
            t = (Z - z0) / hh + 0.08 * snoise(X, Y, Z, 3, 2)
            return np.where(t < 0.2, d(X, Y, Z), np.where(t > 0.7, l_(X, Y, Z), m(X, Y, Z)))

        def wob(X, Y, Z, z0=z0, hh=hh, r=r):
            t = np.clip((Z - z0) / hh, 0, 1)
            rr = r * (1 - t) + 0.2 * t
            a = np.arctan2(Y, X)
            rr = rr * (1 + 0.07 * np.sin(a * 7 + z0))
            return X * X + Y * Y <= rr * rr
        g.fill((-r * 1.1, -r * 1.1, z0), (r * 1.1, r * 1.1, z0 + hh), wob, cfn)
    # light snow-free tips: a few lighter voxels on the tier lips
    g.paint((-4, -4, 0), (4, 4, 11.2), lambda X, Y, Z: hnoise(X, Y, Z, 49) > 0.95, col('#6FC488'))


@prop('Bush', 'bush', (-1.6, -1.4, 0), (1.6, 1.4, 1.8), note='round bush with berries')
def _bush(p):
    g = p.part('body')
    c = two_tone(LEAF['dark'], LEAF['mid'], LEAF['light'], 0, 1.7, 11)
    g.blob((0, 0, 0.75), (1.35, 1.15, 0.95), c, amp=0.12, f=2.6, seed=11)
    g.carve((-2, -2, -1), (2, 2, 0))
    fruit(g, 0, 0, 0.8, 1.2, 7, '#FF6F91', 12, size=0.12)


@prop('BushAutumn', 'bush', (-1.6, -1.4, 0), (1.6, 1.4, 1.8), note='bush in autumn colours')
def _bush_autumn(p):
    g = p.part('body')
    c = two_tone(AUTUMN['dark'], AUTUMN['mid'], AUTUMN['light'], 0, 1.7, 13)
    g.blob((0, 0, 0.75), (1.35, 1.15, 0.95), c, amp=0.12, f=2.6, seed=13)
    g.carve((-2, -2, -1), (2, 2, 0))


@prop('Stump', 'stump', (-1.2, -1.2, 0), (1.2, 1.2, 1.1), note='tree stump with rings')
def _stump(p):
    g = p.part('body')
    g.cyl(0, 0, 0, 0.9, 0.75, pick(BARK, 50), r1=0.65)
    for a in range(4):
        ang = a * math.pi / 2 + 0.7
        g.seg((0, 0, 0.3), (math.cos(ang) * 1.05, math.sin(ang) * 1.05, 0), 0.22, pick(BARK, 51), r1=0.1)
    ring = lambda X, Y, Z: np.mod(np.sqrt(X * X + Y * Y), 0.22) < 0.1
    g.cyl(0, 0, 0.9, 1.0, 0.66, col('#E8C58E'))
    g.paint((-1, -1, 0.9), (1, 1, 1.0), ring, col('#C99E62'))
    g.ell((0.45, -0.3, 1.0), (0.18, 0.18, 0.15), col('#5DB13E'))  # little moss tuft


# ------------------------------------------------------------- eggs, belt
@prop('EggPedestal', 'pedestal', (-1.25, -1.25, 0), (1.25, 1.25, 1.1), budget=60,
      note='2.4 x 2.4 x 0.75 crate with a straw nest; part "trim" is the band in the egg colour (white here, recolour in game)')
def _pedestal(p):
    g = p.part('body')
    hw, H = 1.2, 0.75
    g.box((-hw, -hw, 0), (hw, hw, H), pick(WOOD, 81))
    g.paint((-hw, -hw, 0), (hw, hw, H - 0.1), lambda X, Y, Z: np.mod(Z, 0.25) < VOX, col('#8B5A33'))
    for sx in (-1, 1):
        for sy in (-1, 1):
            x0 = sx * hw - (0.3 if sx > 0 else 0)
            y0 = sy * hw - (0.3 if sy > 0 else 0)
            g.box((x0, y0, 0), (x0 + 0.3, y0 + 0.3, H + 0.05), col('#8B5A33'))
    g.fill((-1.0, -1.0, H), (1.0, 1.0, H + 0.35),
           lambda X, Y, Z: np.abs(np.sqrt(X ** 2 + Y ** 2) - 0.72) < 0.24 + 0.08 * snoise(X, Y, Z, 6, 3), pick(STRAW, 82))
    # the band in the egg's colour: its own part so the game can recolour it
    ring = lambda X, Y, Z: np.maximum(np.abs(X), np.abs(Y)) >= hw - 0.1
    g.carve((-hw, -hw, 0.4), (hw, hw, 0.6), ring)
    t = p.part('trim', parent='body')
    t.fill((-hw - 0.1, -hw - 0.1, 0.4), (hw + 0.1, hw + 0.1, 0.6), ring, col('#FFFFFF'))
    p.anchor = (0, 0, H + 0.05)


for _ek, _en in (('basic', 'BasicEgg'), ('meadow', 'MeadowEgg'), ('moonlit', 'MoonlitEgg'), ('premium', 'PremiumEgg')):
    _e = EGGS[_ek]

    def _mk(p, k=_ek):
        draw_egg(p.part('body'), 0, 0, 0, k)
    prop(_en, 'egg', (-_e['w'] / 2 - 0.05, -_e['w'] / 2 - 0.05, 0), (_e['w'] / 2 + 0.05, _e['w'] / 2 + 0.05, _e['h'] + 0.05), budget=90,
         note=f"{_e['w']} wide, {_e['h']} tall")(_mk)

RING_R = 22.0
BELT_W = 3.2


@prop('BeltSlat', 'belt', (-1.7, -0.3, 0), (1.7, 0.3, 0.35), budget=12, factors=(1,),
      note='one belt slat: radial along X (3.2 wide), along the belt on Z (0.55); repeat every 0.6 studs')
def _slat(p):
    g = p.part('body')
    g.box((-1.6, -0.275, 0), (1.6, 0.275, 0.3), pick(WOOD, 91))
    g.box((-1.6, -0.275, 0), (-1.3, 0.275, 0.3), col('#8B5A33'))
    g.box((1.3, -0.275, 0), (1.6, 0.275, 0.3), col('#8B5A33'))
    g.box((-0.05, -0.275, 0.3), (0.05, 0.275, 0.33), col('#E8BF48'))


@prop('BeltRail', 'belt', (-3.0, -3.2, 0), (3.0, 3.2, 1.6), budget=60,
      note='15 degree section of the round belt (radius 22): both rails, frame and legs. The anchor is the belt centreline at slat height; '
           'the ring centre is 22 studs along -X from it')
def _rail(p):
    g = p.part('body')
    # local frame: belt runs along y around x = 0; ring centre at (-R, 0)
    cx, cy = -RING_R, 0.0
    half = math.radians(7.5)
    zb = 1.0

    def ring(r0, r1, z=None):
        def m(X, Y, Z):
            r = np.sqrt((X - cx) ** 2 + (Y - cy) ** 2)
            a = np.arctan2(Y - cy, X - cx)
            return (r >= RING_R + r0) & (r <= RING_R + r1) & (np.abs(a) <= half)
        return m
    lo, hi = (-3, -3.2, 0), (3, 3.2, 1.6)
    g.fill(lo, (3, 3.2, zb - 0.3), lambda X, Y, Z: ring(-BELT_W / 2, BELT_W / 2)(X, Y, Z) & (Z > zb - 0.7), col('#7A4D2B'))
    for rr in (-BELT_W / 2 - 0.25, BELT_W / 2 + 0.25):
        g.fill(lo, (3, 3.2, zb + 0.35), lambda X, Y, Z, rr=rr: ring(rr - 0.25, rr + 0.25)(X, Y, Z) & (Z > zb - 0.6), col(RED))
        g.paint(lo, (3, 3.2, zb - 0.3), ring(rr - 0.25, rr + 0.25), col(RED_D))
        g.fill((-3, -3.2, zb + 0.35), (3, 3.2, zb + 0.45),
               lambda X, Y, Z, rr=rr: ring(rr - 0.1, rr + 0.1)(X, Y, Z) & (np.mod(np.arctan2(Y, X - cx) * (RING_R + rr), 1.45) < 0.2),
               col('#F4C542'))
    for rr in (-BELT_W / 2 + 0.3, BELT_W / 2 - 0.3):
        px = cx + (RING_R + rr)
        g.box((px - 0.2, -0.2, 0), (px + 0.2, 0.2, zb - 0.6), col('#7A4D2B'))
    p.anchor = (0, 0, zb - 0.3)


@prop('GoldenNest', 'hub', (-8.2, -8.2, 0), (8.2, 8.2, 5.4), budget=160,
      note='centre island of the Egg Market: drum, grass top, straw nest and the glowing golden egg')
def _nest(p):
    g = p.part('body')
    r = 8.0
    g.cyl(0, 0, 0, 1.4, r, pick(WOOD, 95))
    g.paint((-r, -r, 0), (r, r, 1.4), lambda X, Y, Z: np.mod(np.arctan2(Y, X) * r, 1.2) < 0.12, col('#8B5A33'))
    g.cyl(0, 0, 1.2, 1.5, r + 0.15, col(RED))
    g.cyl(0, 0, 1.5, 1.7, r - 0.2, pick(['#6CC64B', '#62BC42', '#77CF55'], 96))
    R2, rt = 2.6, 0.8

    def tor(X, Y, Z):
        d = np.sqrt(X ** 2 + Y ** 2) - R2
        return d * d + (Z - 2.3) ** 2 <= (rt + 0.1 * snoise(X, Y, Z, 5, 9)) ** 2
    g.fill((-4, -4, 1.5), (4, 4, 3.4), tor, pick(STRAW, 97))
    g.cyl(0, 0, 1.5, 1.9, R2, pick(STRAW, 98))
    e = p.part('egg', anim='spin', parent='body', pivot=(0, 0, 1.9))
    R, H = 1.3, 3.4
    zc = 1.9 + H * 0.42

    def m(X, Y, Z):
        t = (Z - zc) / (np.where(Z > zc, H * 0.58, H * 0.42))
        rr = R * np.sqrt(np.clip(1 - t * t, 0, 1)) * np.where(Z > zc, 1 - 0.12 * t, 1)
        return X ** 2 + Y ** 2 <= rr * rr
    e.fill((-R, -R, 1.9), (R, R, 1.9 + H), m, lambda X, Y, Z: np.where(hnoise(X, Y, Z, 99) > 0.85, col('#FFF1B0', 2.5), col('#FFC935', 1.2)))


# ----------------------------------------------------- elevator and ladder
# Apartment style: a slate-blue cab with brass trim running in a glass and
# iron shaft, and an iron fire-escape ladder.
#
# These are built like plain Roblox parts, not sculpted voxels: every piece
# is a flat-coloured block on the 0.2-stud grid (0.5 for the shaft, whose
# corners sit on half studs), so the game's Parts version is exactly this
# model with nothing resampled away, and the viewer mesh is a few hundred
# flat faces instead of hundreds of thousands of voxel faces.
SLATE, SLATE_D, BRASS, FIRE = '#3D5A80', '#2E4766', '#C9A24A', '#2F3A4A'
GLASS = '#BEE6FF'
DOOR = '#E8E1D2'
WARM = ('#FFC870', 3.0)


def _wall_band(g, z0, z1, c, front=True):
    """a flush band of colour c on the outer 0.2 of the cab's walls"""
    g.box((-3, 2.8, z0), (3, 3, z1), c)
    g.box((-3, -2.4, z0), (-2.8, 3, z1), c)
    g.box((2.8, -2.4, z0), (3, 3, z1), c)
    if front == 'full':
        g.box((-3, -3, z0), (3, -2.8, z1), c)
    elif front:
        g.box((-3, -3, z0), (-2.2, -2.8, z1), c)
        g.box((2.2, -3, z0), (3, -2.8, z1), c)


@prop('ElevatorCab', 'elevator', (-3.0, -3.0, 0), (3.0, 3.0, 9.0), budget=200, factors=(2,),
      note='6 x 6 x 9 cab, open front (-Z) with two sliding doors "doorL"/"doorR" (slide 1.4 studs outward to open, '
           'into slots in the side walls) and a floor button panel; plain blocks on a 0.2-stud grid')
def _cab(p):
    g = p.part('body')
    slate, slate_d, brass = col(SLATE), col(SLATE_D), col(BRASS)
    # floor: dark wood with a lighter parquet square in the middle
    g.box((-3, -3, 0), (3, 3, 0.4), col(WOOD_D[0]))
    g.box((-2.2, -2.0, 0.2), (2.2, 2.2, 0.4), col(WOOD[0]))
    # walls; the side walls stop short of the front, leaving the door slots
    g.box((-3, 2.6, 0.4), (3, 3, 8.6), slate)
    g.box((-3, -2.4, 0.4), (-2.6, 3, 8.6), slate)
    g.box((2.6, -2.4, 0.4), (3, 3, 8.6), slate)
    # front frame: two posts and a header, brass edged round the doorway
    g.box((-3, -3, 0.4), (-2.2, -2.6, 8.6), slate_d)
    g.box((2.2, -3, 0.4), (3, -2.6, 8.6), slate_d)
    g.box((-2.2, -3, 7.4), (2.2, -2.6, 8.6), slate_d)
    g.box((-2.4, -3, 0.4), (-2.2, -2.8, 7.6), brass)
    g.box((2.2, -3, 0.4), (2.4, -2.8, 7.6), brass)
    g.box((-2.4, -3, 7.4), (2.4, -2.8, 7.6), brass)
    # roof with a brass cornice, and brass bands at the base and waist
    g.box((-3, -3, 8.6), (3, 3, 9.0), slate_d)
    _wall_band(g, 8.4, 8.6, brass, front='full')
    _wall_band(g, 0.4, 0.6, brass)
    _wall_band(g, 3.2, 3.4, brass, front=False)
    # inside: darker wainscot below a brass handrail on the back wall
    g.box((-2.6, 2.4, 0.4), (2.6, 2.6, 3.2), slate_d)
    g.box((-2.6, -2.4, 0.4), (-2.4, 2.6, 3.2), slate_d)
    g.box((2.4, -2.4, 0.4), (2.6, 2.6, 3.2), slate_d)
    g.box((-2.2, 2.2, 3.4), (2.2, 2.4, 3.6), brass)
    # tall windows on both sides: brass frame, glass, a brass transom
    for x0 in (-3.0, 2.6):
        g.box((x0, -1.6, 3.8), (x0 + 0.4, 1.6, 7.4), brass)
        g.box((x0, -1.2, 4.2), (x0 + 0.4, 1.2, 7.0), col(GLASS))
        g.box((x0, -1.2, 6.0), (x0 + 0.4, 1.2, 6.2), brass)
    # floor indicator over the doors: a brass plate with a lit arrow
    g.box((-1.2, -3, 7.8), (1.2, -2.8, 8.4), brass)
    g.box((-1.0, -3, 8.0), (1.0, -2.8, 8.2), col('#FFF4E0'))
    g.box((-0.2, -3, 8.0), (0.2, -2.8, 8.2), col(*WARM))
    # button panel on the right wall, inside
    g.box((2.2, -2.2, 3.6), (2.4, -1.0, 5.8), brass)
    for i in range(4):
        z = 3.8 + i * 0.5
        g.box((2.0, -2.0, z), (2.2, -1.8, z + 0.2), col(*WARM))
        g.box((2.0, -1.4, z), (2.2, -1.2, z + 0.2), col(*WARM))
    # ceiling lamp in a brass ring
    g.box((-0.8, -0.8, 8.4), (0.8, 0.8, 8.6), brass)
    g.box((-0.6, -0.6, 8.4), (0.6, 0.6, 8.6), col(*LAMP))
    # doors: cream leaves with a brass edge and a glass light, sitting in the
    # slot behind the front frame
    for name, x0, x1 in (('doorL', -2.2, 0.0), ('doorR', 0.0, 2.2)):
        d = p.part(name, anim='slide', parent='body', pivot=((x0 + x1) / 2, -2.5, 0.6))
        d.box((x0, -2.6, 0.6), (x1, -2.4, 7.4), brass)
        d.box((x0 + 0.2, -2.6, 0.8), (x1 - 0.2, -2.4, 7.2), col(DOOR))
        d.box((x0 + 0.4, -2.6, 3.6), (x1 - 0.4, -2.4, 6.6), col(GLASS))
        d.box((x0 + 0.4, -2.6, 1.6), (x1 - 0.4, -2.4, 1.8), brass)


@prop('ElevatorShaft', 'elevator', (-3.5, -3.5, 0), (3.5, 3.5, 1.0), budget=24, factors=(5,),
      note='one stud of the 7 x 7 glass and iron shaft: iron corner posts, glass on the two outside faces (-X and +Z, the '
           'tower\'s left and back), open on the room sides; stack from the ground to the roof; plain blocks')
def _shaft(p):
    g = p.part('body')
    for x0 in (-3.5, 3.0):
        for y0 in (-3.5, 3.0):
            g.box((x0, y0, 0), (x0 + 0.5, y0 + 0.5, 1.0), col(FIRE))
    g.box((-3.0, 3.0, 0), (3.0, 3.5, 1.0), col(GLASS))  # back face
    g.box((-3.5, -3.0, 0), (-3.0, 3.0, 1.0), col(GLASS))  # left face


@prop('ElevatorShaftTop', 'elevator', (-3.8, -3.8, 0), (3.8, 3.8, 1.6), budget=40, factors=(2,),
      note='roof cap of the shaft: a stepped slate roof with a brass rim and an iron governor wheel that spins; plain blocks')
def _shaft_top(p):
    g = p.part('body')
    g.box((-3.8, -3.8, 0), (3.8, 3.8, 0.2), col(BRASS))
    g.box((-3.8, -3.8, 0.2), (3.8, 3.8, 0.4), col(SLATE_D))
    g.box((-3.2, -3.2, 0.4), (3.2, 3.2, 0.6), col(SLATE))
    g.box((-2.4, -2.4, 0.6), (2.4, 2.4, 0.8), col(SLATE_D))
    g.box((-0.4, -0.4, 0.8), (0.4, 0.4, 1.0), col(FIRE))
    w = p.part('wheel', anim='spin', parent='body', pivot=(0, 0, 1.2))
    w.box((-1.0, -0.2, 1.0), (1.0, 0.2, 1.2), col(FIRE))
    w.box((-0.2, -1.0, 1.0), (0.2, 1.0, 1.2), col(FIRE))
    w.box((-0.2, -0.2, 1.2), (0.2, 0.2, 1.4), col(BRASS))


@prop('LadderSection', 'ladder', (-1.0, -0.2, 0), (1.0, 0.2, 1.0), budget=12, factors=(2,),
      note='2 wide, 1 tall iron fire-escape ladder: two rails and one rung; stack for any height; plain blocks')
def _ladder(p):
    g = p.part('body')
    g.box((-1.0, -0.2, 0), (-0.8, 0.2, 1.0), col(FIRE))
    g.box((0.8, -0.2, 0), (1.0, 0.2, 1.0), col(FIRE))
    g.box((-0.8, -0.2, 0.4), (0.8, 0.0, 0.6), col('#4A5568'))


@prop('LadderTop', 'ladder', (-1.0, -0.6, 0), (1.0, 0.2, 1.2), budget=12, factors=(2,),
      note='rail tops that curve over the floor edge, with brass caps; plain blocks')
def _ladder_top(p):
    g = p.part('body')
    for x0 in (-1.0, 0.8):
        g.box((x0, -0.2, 0), (x0 + 0.2, 0.2, 0.8), col(FIRE))
        g.box((x0, -0.6, 0.6), (x0 + 0.2, 0.2, 0.8), col(FIRE))
        g.box((x0, -0.6, 0.8), (x0 + 0.2, -0.4, 1.0), col(BRASS))


@prop('FloorPlaque', 'plaque', (-1.6, -0.2, 0), (1.6, 0.2, 1.6), budget=20, factors=(2,),
      note='3.2 x 1.6 enamel apartment sign for the floor number, brass edged; the game draws the number on the front (-Z) '
           'face of the "board" area; plain blocks')
def _plaque(p):
    g = p.part('body')
    g.box((-1.6, 0, 0), (1.6, 0.2, 1.6), col(BRASS))
    g.box((-1.6, -0.2, 0), (1.6, 0, 1.6), col(BRASS))
    g.box((-1.4, -0.2, 0.2), (1.4, 0, 1.4), col(SLATE))
