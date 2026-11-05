"""Hatchery Heist's outdoor nature, as voxel models: a family of five tree
species in three sizes, bushes, rocks, flower patches, grass tufts and
toadstools. Polished voxel style, saturated storybook colours, a few glowing
accents (Star Pine lanterns, Moonberry Willow berries, toadstool gills).

Every model is a function that fills one envkit grid. `MODELS[id]` gives
(kind, voxel size, bounds lo, hi, builder, note). Studs, Z up, base at z = 0,
centred on x, y. Colours reuse the world props' palettes
(tools/art/world/props.py) so the outdoors matches the Egg Market and decor.
"""
import math

import numpy as np

import envkit
import vkit

# palettes (world props: LEAF, PINE, BLOSSOM, BARK)
LEAF = dict(dark=['#3E9A3A', '#37903A'], mid=['#55B947', '#4DB043', '#5CC24F'], light=['#7AD35E', '#86DA66'])
AMBER = dict(dark=['#C2531F', '#B04A1C'], mid=['#E8782A', '#F08A2E', '#E06A24'], light=['#FFB547', '#FFC45E'])
PINE = dict(dark=['#1F6F45', '#1C6840'], mid=['#2F9A5C', '#2B9156', '#35A262'], light=['#5CC07A', '#66C883'])
BLOSSOM = dict(dark=['#D9649F', '#CC5A93'], mid=['#F48CC4', '#EE80BC', '#F99BCF'], light=['#FFC2E2', '#FFD0E9'])
WILLOW = dict(dark=['#4E5FB8', '#4757AE'], mid=['#6F86D6', '#6A7FD0', '#7890DC'], light=['#A3B8F0', '#AEC2F4'])
BARK = ['#8B5A33', '#7A4D2B', '#9A6A3F']
BARK_DARK = ['#6B4A3A', '#5E4033', '#775444']
BARK_PALE = ['#B8A08A', '#A99079', '#C4AE98']
STONE = dict(dark=['#7D7F99', '#77798F'], mid=['#9A9CB5', '#A2A4BC', '#9497AF'], light=['#C3C5D8', '#CBCDE0'])
MOSS = ['#6DBE4E', '#62B347', '#79C957']

MODELS = {}


def model(mid, kind, voxel, lo, hi, note):
    def deco(fn):
        MODELS[mid] = dict(id=mid, kind=kind, voxel=voxel, lo=lo, hi=hi, fn=fn, note=note)
        return fn
    return deco


def build(mid):
    m = MODELS[mid]
    envkit.set_voxel(m['voxel'])
    g = vkit.Grid(m['lo'], m['hi'])
    m['fn'](g, np.random.default_rng(sum(map(ord, mid))))
    g.carve((m['lo'][0] - 1, m['lo'][1] - 1, -5), (m['hi'][0] + 1, m['hi'][1] + 1, 0))
    return g


# ------------------------------------------------------------------ helpers
def roots(g, r, n, z, trunk, rng, spread=1.9, thick=0.5):
    """root flare: n roots leaving the trunk foot and diving into the ground"""
    for i in range(n):
        a = i * 2 * math.pi / n + rng.uniform(-0.3, 0.3)
        g.seg((0, 0, z), (math.cos(a) * r * spread, math.sin(a) * r * spread, -0.1), r * thick, trunk, r1=r * 0.18)


def trunk_path(g, pts, r0, r1, c):
    n = len(pts) - 1
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        ra = r0 + (r1 - r0) * i / n
        rb = r0 + (r1 - r0) * (i + 1) / n
        g.seg(a, b, ra, c, r1=rb)


def berries(g, ctr, r, n, hexc, seed, size, glow=0.0, below=0.75):
    """little round fruit on the surface of a canopy blob"""
    rng = np.random.default_rng(seed)
    fc = vkit.col(hexc, glow)
    for _ in range(n):
        a = rng.uniform(0, 2 * math.pi)
        e = rng.uniform(-below, 0.8)
        p = (ctr[0] + math.cos(a) * r[0] * math.cos(e), ctr[1] + math.sin(a) * r[1] * math.cos(e), ctr[2] + r[2] * math.sin(e))
        g.ell(p, (size, size, size), fc)


# -------------------------------------------------------------- Puff Oak
def puff_oak(g, rng, h, pal=LEAF, apples=0):
    """round storybook oak: flared roots, a stout trunk forking in two or
    three limbs, a cloud of lumpy leaf balls"""
    s = h / 20.0
    trunk = envkit.pick(BARK, 41)
    r = 1.15 * s
    tz = 9.0 * s
    g.cyl(0, 0, 0, tz, r * 1.05, trunk, r1=r * 0.8)
    roots(g, r, 5, 1.2 * s, trunk, rng)
    limbs = []
    for i in range(3):
        a = i * 2 * math.pi / 3 + rng.uniform(-0.4, 0.4)
        end = (math.cos(a) * 3.2 * s, math.sin(a) * 3.2 * s, tz + 3.2 * s)
        g.seg((0, 0, tz - 1.5 * s), end, r * 0.62, trunk, r1=r * 0.32)
        limbs.append(end)
    c = envkit.tones(pal, tz + 0.5 * s, h, 3)
    blobs = [((0, 0, tz + 5.0 * s), (5.4 * s, 5.4 * s, 4.2 * s))]
    for i, e in enumerate(limbs):
        blobs.append(((e[0] * 1.15, e[1] * 1.15, e[2] + 0.6 * s), (3.9 * s, 3.9 * s, 3.2 * s)))
    for i in range(4):
        a = i * math.pi / 2 + 0.8 + rng.uniform(-0.3, 0.3)
        blobs.append(((math.cos(a) * 2.6 * s, math.sin(a) * 2.6 * s, tz + 7.6 * s), (3.0 * s, 3.0 * s, 2.5 * s)))
    blobs.append(((0.4 * s, -0.3 * s, h - 2.3 * s), (2.6 * s, 2.6 * s, 2.2 * s)))
    # each clump shaded on its own (dark underneath, sunlit on top), so the
    # crown reads as a bunch of leaf balls rather than one lump
    for i, (ctr, rr) in enumerate(blobs):
        cc = envkit.tones(pal, ctr[2] - rr[2] * 0.9, ctr[2] + rr[2] * 0.8, 3 + i, sx=0.08)
        g.blob(ctr, rr, cc, amp=0.07, f=1.6 / s, seed=3 + i)
    # small leaf clumps poking out of the silhouette
    for i in range(12):
        a = rng.uniform(0, 2 * math.pi)
        e = rng.uniform(-0.3, 0.8)
        ctr0, rr0 = blobs[0]
        p = (math.cos(a) * rr0[0] * 1.08 * math.cos(e), math.sin(a) * rr0[1] * 1.08 * math.cos(e), ctr0[2] + rr0[2] * 1.15 * math.sin(e))
        cc = envkit.tones(pal, p[2] - 1.2 * s, p[2] + 0.9 * s, 30 + i, sx=0.05)
        g.blob(p, (1.4 * s, 1.4 * s, 1.05 * s), cc, amp=0.1, f=2.5 / s, seed=30 + i, only_empty=True)
    _ = c
    if apples:
        berries(g, blobs[0][0], (5.9 * s, 5.9 * s, 4.7 * s), apples, '#E8413C', 5, 0.42 * s)


@model('PuffOakS', 'tree', 0.4, (-6, -6, 0), (6, 6, 13), 'Puff Oak, small (12 studs)')
def _oak_s(g, rng):
    puff_oak(g, rng, 12)


@model('PuffOakM', 'tree', 0.4, (-8, -8, 0), (8, 8, 18.5), 'Puff Oak, medium (18 studs)')
def _oak_m(g, rng):
    puff_oak(g, rng, 18)


@model('PuffOakL', 'tree', 0.4, (-11, -11, 0), (11, 11, 25), 'Puff Oak, large (24 studs)')
def _oak_l(g, rng):
    puff_oak(g, rng, 24)


@model('AmberOakM', 'tree', 0.4, (-8, -8, 0), (8, 8, 18.5), 'Puff Oak in amber autumn colours, medium')
def _amber_m(g, rng):
    puff_oak(g, rng, 18, AMBER)


@model('AmberOakL', 'tree', 0.4, (-11, -11, 0), (11, 11, 25), 'Puff Oak in amber autumn colours, large')
def _amber_l(g, rng):
    puff_oak(g, rng, 24, AMBER)


# --------------------------------------------------------- Blossom Tree
def blossom(g, rng, h):
    """a crooked dark trunk and a wide, flat-topped cloud of pink blossom"""
    s = h / 16.0
    trunk = envkit.pick(BARK_DARK, 43)
    pts = [(0, 0, 0), (0.6 * s, 0.2 * s, 2.4 * s), (-0.2 * s, 0.5 * s, 4.8 * s), (0.5 * s, -0.1 * s, 6.8 * s), (0.2 * s, 0.2 * s, 8.0 * s)]
    trunk_path(g, pts, 0.95 * s, 0.6 * s, trunk)
    roots(g, 0.9 * s, 4, 1.0 * s, trunk, rng)
    top = pts[-1]
    ends = []
    for i in range(4):
        a = i * math.pi / 2 + 0.5 + rng.uniform(-0.3, 0.3)
        e = (math.cos(a) * 4.0 * s, math.sin(a) * 4.0 * s, 10.2 * s + rng.uniform(-0.5, 0.5) * s)
        g.seg(top, e, 0.5 * s, trunk, r1=0.25 * s)
        ends.append(e)
    c = envkit.tones(BLOSSOM, 8.5 * s, h, 9, sx=0.16)
    g.blob((0, 0, 11.4 * s), (5.2 * s, 5.2 * s, 2.9 * s), c, amp=0.1, f=1.8 / s, seed=9)
    for i, e in enumerate(ends):
        g.blob((e[0] * 1.1, e[1] * 1.1, e[2] + 0.4 * s), (3.0 * s, 3.0 * s, 2.0 * s), c, amp=0.12, f=2.2 / s, seed=10 + i)
    g.blob((0.3 * s, 0.2 * s, 13.6 * s), (3.0 * s, 3.0 * s, 1.8 * s), c, amp=0.1, f=2.0 / s, seed=15)
    # white blossoms dotted over the top
    g.paint((-20, -20, 10 * s), (20, 20, h + 1), lambda X, Y, Z: vkit.hnoise(X, Y, Z, 44) > 0.94, vkit.col('#FFF4FA'))


@model('BlossomS', 'tree', 0.35, (-6, -6, 0), (6, 6, 11), 'Blossom Tree, small (10 studs)')
def _bl_s(g, rng):
    blossom(g, rng, 10)


@model('BlossomM', 'tree', 0.4, (-8, -8, 0), (8, 8, 16), 'Blossom Tree, medium (15 studs)')
def _bl_m(g, rng):
    blossom(g, rng, 15)


@model('BlossomL', 'tree', 0.4, (-10.5, -10.5, 0), (10.5, 10.5, 21), 'Blossom Tree, large (20 studs)')
def _bl_l(g, rng):
    blossom(g, rng, 20)


# ------------------------------------------------------------ Star Pine
def star_pine(g, rng, h):
    """tiered pine with soft drooping skirts and a glowing star lantern on top"""
    s = h / 24.0
    trunk = envkit.pick(BARK, 45)
    g.cyl(0, 0, 0, 5.0 * s, 0.95 * s, trunk, r1=0.8 * s)
    roots(g, 0.9 * s, 4, 0.8 * s, trunk, rng, spread=1.6)
    d, m, l_ = envkit.pick(PINE['dark'], 46), envkit.pick(PINE['mid'], 47), envkit.pick(PINE['light'], 48)
    tiers = [(2.6, 7.6, 3.8), (6.0, 6.2, 3.6), (9.2, 4.9, 3.4), (12.2, 3.7, 3.2), (15.0, 2.6, 3.0), (17.6, 1.5, 3.4)]
    for k, (z0, r, hh) in enumerate(tiers):
        z0, r, hh = z0 * s, r * s, hh * s

        def cfn(X, Y, Z, z0=z0, hh=hh):
            t = (Z - z0 + 0.9 * s) / (hh + 0.9 * s) + 0.06 * vkit.snoise(X, Y, Z, 1.2 / s, 2)
            return np.where(t < 0.3, d(X, Y, Z), np.where(t > 0.5, l_(X, Y, Z), m(X, Y, Z)))

        def mask(X, Y, Z, z0=z0, hh=hh, r=r, k=k):
            t = np.clip((Z - z0) / hh, 0, 1)
            a = np.arctan2(Y, X)
            # scalloped skirt: lobes droop a little at the rim
            lobe = 1 + 0.09 * np.sin(a * 7 + k * 1.3)
            rr = (r * (1 - t) ** 1.45 + 0.3 * s * t) * lobe
            rim = np.sqrt(X * X + Y * Y) / np.maximum(r * lobe, 1e-6)
            droop = (Z - z0) >= -0.9 * s * np.clip(rim - 0.55, 0, 1) * 1.6
            return (X * X + Y * Y <= rr * rr) & droop
        g.fill((-r * 1.15, -r * 1.15, z0 - 1.6 * s), (r * 1.15, r * 1.15, z0 + hh), mask, cfn)
    # the lantern: a little glowing star on a stalk
    top = tiers[-1][0] * s + tiers[-1][2] * s
    gold = vkit.col('#FFD45A', 3.0)
    g.box((-0.2 * s, -0.2 * s, top - 0.4 * s), (0.2 * s, 0.2 * s, top + 0.6 * s), vkit.col('#C8963A'))
    cz = top + 1.5 * s
    g.ell((0, 0, cz), (0.75 * s, 0.75 * s, 0.75 * s), gold)
    for ax in ((1, 0, 0), (0, 1, 0), (0, 0, 1)):
        L = 1.5 * s
        g.seg((-ax[0] * L, -ax[1] * L, cz - ax[2] * L), (ax[0] * L, ax[1] * L, cz + ax[2] * L), 0.32 * s, gold, r1=0.32 * s)
    # snow-free frosting: a few pale tips on the tier rims
    g.paint((-20, -20, 0), (20, 20, top), lambda X, Y, Z: vkit.hnoise(X, Y, Z, 49) > 0.985, vkit.col('#7FD39A'))
    # tiny glowing seed-lights hanging in the skirts
    rng2 = np.random.default_rng(7)
    lamp = vkit.col('#FFE9A0', 2.5)
    for z0, r, hh in tiers[:4]:
        for _ in range(3):
            a = rng2.uniform(0, 2 * math.pi)
            rr = r * s * 0.86
            p = (math.cos(a) * rr, math.sin(a) * rr, z0 * s - 0.2 * s)
            g.ell(p, (0.3 * s, 0.3 * s, 0.3 * s), lamp)


@model('StarPineS', 'tree', 0.4, (-6.5, -6.5, 0), (6.5, 6.5, 15), 'Star Pine, small (14 studs)')
def _pn_s(g, rng):
    star_pine(g, rng, 14)


@model('StarPineM', 'tree', 0.4, (-9.5, -9.5, 0), (9.5, 9.5, 21.5), 'Star Pine, medium (20 studs)')
def _pn_m(g, rng):
    star_pine(g, rng, 20)


@model('StarPineL', 'tree', 0.45, (-13, -13, 0), (13, 13, 30), 'Star Pine, large (28 studs)')
def _pn_l(g, rng):
    star_pine(g, rng, 28)


# ------------------------------------------------------- Moonberry Willow
def willow(g, rng, h):
    """a pale twisting trunk under a dome of periwinkle leaves that hangs in
    long curtains, with glowing moonberries"""
    s = h / 18.0
    trunk = envkit.pick(BARK_PALE, 51)
    pts = [(0, 0, 0), (-0.5 * s, 0.3 * s, 2.5 * s), (0.4 * s, 0.1 * s, 5.0 * s), (0.0, -0.3 * s, 7.5 * s), (0.2 * s, 0, 9.5 * s)]
    trunk_path(g, pts, 1.1 * s, 0.7 * s, trunk)
    roots(g, 1.0 * s, 5, 1.0 * s, trunk, rng)
    cz = 12.4 * s
    c = envkit.tones(WILLOW, 7.0 * s, h, 21, sx=0.1)
    R = 6.0 * s
    g.blob((0, 0, cz), (R * 1.08, R * 1.08, 3.9 * s), c, amp=0.06, f=1.5 / s, seed=21)
    g.blob((0, 0, cz + 2.6 * s), (3.8 * s, 3.8 * s, 3.0 * s), c, amp=0.08, f=1.8 / s, seed=22)
    # the curtain: a thin leafy wall hanging from the rim, slit into ragged
    # fronds of different lengths, lighter towards the tips
    lt = envkit.pick(WILLOW['light'], 24)
    tipc = vkit.col('#C9D6FA')
    z_top = cz - 0.6 * s
    nf = 30
    lens = rng.uniform(3.5, 8.5, nf) * s
    for k_ in range(0, nf, 5):
        lens[k_] = 9.0 * s  # a few reach almost to the ground

    def curtain(X, Y, Z):
        a_ = np.arctan2(Y, X)
        f = (a_ + math.pi) / (2 * math.pi) * nf
        i_ = np.floor(f).astype(int) % nf
        frac = f - np.floor(f)
        rr = np.sqrt(X * X + Y * Y)
        sway = 0.25 * s * np.sin((z_top - Z) / s * 0.9 + i_)
        wall = (rr >= R * 0.9 + sway) & (rr <= R * 0.9 + sway + 0.75 * s)
        gap = (frac > 0.28) & (frac < 0.72)
        zb = z_top - lens[i_] * (0.75 + 0.25 * np.sin(frac * math.pi))
        return wall & gap & (Z >= np.maximum(zb, 1.0 * s)) & (Z <= z_top)

    def ccol(X, Y, Z):
        a_ = np.arctan2(Y, X)
        i_ = np.floor((a_ + math.pi) / (2 * math.pi) * nf).astype(int) % nf
        zb = z_top - lens[i_]
        t = (Z - zb) / np.maximum(lens[i_], 1e-6)
        base = c(X, Y, Z)
        return np.where(t < 0.12, tipc, np.where(t < 0.4, lt(X, Y, Z), base))
    g.fill((-R * 1.2, -R * 1.2, 0.5 * s), (R * 1.2, R * 1.2, z_top), curtain, ccol)
    berry = vkit.col('#E9F1FF', 2.2)
    for i_ in range(0, nf, 5):
        ang = (i_ + 0.5) / nf * 2 * math.pi - math.pi
        zb = max(z_top - lens[i_], 1.0 * s)
        g.ell((math.cos(ang) * (R * 0.9 + 0.4 * s), math.sin(ang) * (R * 0.9 + 0.4 * s), zb), (0.4 * s,) * 3, berry)
    # glowing moonberries
    berries(g, (0, 0, cz), (R * 1.02, R * 1.02, 4.7 * s), 10, '#E9F1FF', 23, 0.35 * s, glow=2.2, below=-0.1)


@model('WillowS', 'tree', 0.35, (-6, -6, 0), (6, 6, 13), 'Moonberry Willow, small (12 studs)')
def _wl_s(g, rng):
    willow(g, rng, 12)


@model('WillowM', 'tree', 0.4, (-8, -8, 0), (8, 8, 19), 'Moonberry Willow, medium (18 studs)')
def _wl_m(g, rng):
    willow(g, rng, 18)


@model('WillowL', 'tree', 0.45, (-10.5, -10.5, 0), (10.5, 10.5, 25), 'Moonberry Willow, large (24 studs)')
def _wl_l(g, rng):
    willow(g, rng, 24)


# -------------------------------------------------------- Toadstool Tree
def toadstool(g, rng, h, cap=('#E8413C', '#D93A36', '#F04B45'), dots='#FFF6E8'):
    """a giant mushroom: a plump cream stem with a frill, a domed spotted cap
    and softly glowing gills underneath"""
    s = h / 10.0
    stem = envkit.pick(['#F4E9D2', '#EDE0C4', '#F8F0DE'], 61)
    g.cyl(0, 0, 0, 6.6 * s, 1.35 * s, stem, r1=1.0 * s)
    g.ell((0, 0, 0.7 * s), (1.7 * s, 1.7 * s, 0.9 * s), stem)
    g.cyl(0, 0, 4.4 * s, 4.9 * s, 1.75 * s, vkit.col('#E6D6B4'))  # frill
    capc = envkit.pick(list(cap), 62)
    cz = 6.4 * s
    R = 4.6 * s

    def dome(X, Y, Z):
        d = (X * X + Y * Y) / (R * R) + ((Z - cz) / (3.6 * s)) ** 2
        return (d <= 1.0) & (Z >= cz)
    g.fill((-R, -R, cz), (R, R, cz + 3.7 * s), dome, capc)
    # rim curls down a little
    g.fill((-R, -R, cz - 0.6 * s), (R, R, cz), lambda X, Y, Z: (X * X + Y * Y <= R * R) & (X * X + Y * Y >= (R - 0.9 * s) ** 2), capc)
    gills = vkit.col('#FFD9A8', 1.2)
    g.fill((-R, -R, cz - 0.4 * s), (R, R, cz), lambda X, Y, Z: X * X + Y * Y < (R - 0.9 * s) ** 2, gills)
    # white spots on the cap
    rng2 = np.random.default_rng(int(h * 10))
    dc = vkit.col(dots)
    for _ in range(int(14 + h * 0.8)):
        a = rng2.uniform(0, 2 * math.pi)
        e = rng2.uniform(0.05, 1.1)
        p = (math.cos(a) * R * math.cos(e), math.sin(a) * R * math.cos(e), cz + 3.6 * s * math.sin(e))
        rr = rng2.uniform(0.6, 1.0) * s
        g.paint((p[0] - rr, p[1] - rr, p[2] - rr), (p[0] + rr, p[1] + rr, p[2] + rr),
                lambda X, Y, Z, p=p, rr=rr: (X - p[0]) ** 2 + (Y - p[1]) ** 2 + (Z - p[2]) ** 2 <= rr * rr, dc)


@model('ToadstoolS', 'tree', 0.2, (-3, -3, 0), (3, 3, 6.5), 'Toadstool Tree, small (6 studs)')
def _ts_s(g, rng):
    toadstool(g, rng, 6)


@model('ToadstoolM', 'tree', 0.25, (-4.5, -4.5, 0), (4.5, 4.5, 9.5), 'Toadstool Tree, medium (9 studs)')
def _ts_m(g, rng):
    toadstool(g, rng, 9, cap=('#9B6BE0', '#8E5ED6', '#A878EA'))


@model('ToadstoolL', 'tree', 0.3, (-6.5, -6.5, 0), (6.5, 6.5, 13.5), 'Toadstool Tree, large (13 studs)')
def _ts_l(g, rng):
    toadstool(g, rng, 13)


# ------------------------------------------------------------- bushes
def bush(g, rng, w, h, pal, fruit=None, seed=11):
    c = envkit.tones(pal, 0, h, seed)
    g.blob((0, 0, h * 0.42), (w * 0.5, w * 0.44, h * 0.55), c, amp=0.1, f=2.6 / w, seed=seed)
    for i in range(4):
        a = i * math.pi / 2 + rng.uniform(0, 1)
        g.blob((math.cos(a) * w * 0.3, math.sin(a) * w * 0.28, h * 0.32), (w * 0.28, w * 0.28, h * 0.36), c, amp=0.1, f=3 / w, seed=seed + i)
    if fruit:
        berries(g, (0, 0, h * 0.45), (w * 0.52, w * 0.46, h * 0.56), fruit[1], fruit[0], seed + 7, 0.14 * w / 3, below=0.3)


@model('BerryBush', 'bush', 0.2, (-2.2, -2.0, 0), (2.2, 2.0, 2.8), 'round bush with pink berries')
def _bush(g, rng):
    bush(g, rng, 3.8, 2.6, LEAF, ('#FF6F91', 14))


@model('HydrangeaBush', 'bush', 0.2, (-2.2, -2.0, 0), (2.2, 2.0, 2.8), 'leafy bush with blue flower heads')
def _hyd(g, rng):
    bush(g, rng, 3.8, 2.4, LEAF, seed=12)
    for i in range(7):
        a = i * 2 * math.pi / 7 + rng.uniform(-0.2, 0.2)
        e = rng.uniform(0.1, 0.9)
        p = (math.cos(a) * 1.6 * math.cos(e), math.sin(a) * 1.4 * math.cos(e), 1.1 + 1.3 * math.sin(e))
        hc = envkit.pick(['#8FA8FF', '#A08CF2', '#7F9CF5', '#B7A6FF'], 70 + i)
        g.blob(p, (0.5, 0.5, 0.42), hc, amp=0.15, f=6, seed=70 + i)


@model('HedgeBlock', 'bush', 0.2, (-3.2, -1.3, 0), (3.2, 1.3, 2.6), 'neat clipped hedge block, 6 studs long')
def _hedge(g, rng):
    c = envkit.tones(LEAF, 0, 2.4, 13, sx=0.08)
    g.rrbox((-3.0, -1.1, 0), (3.0, 1.1, 2.4), 0.45, c)


# --------------------------------------------------------------- rocks
def rock(g, rng, w, h, seed):
    c = envkit.tones(STONE, 0, h, seed, sx=0.2)
    g.blob((0, 0, h * 0.35), (w * 0.5, w * 0.42, h * 0.7), c, amp=0.16, f=2.2 / w, seed=seed)
    g.blob((w * 0.25, w * 0.1, h * 0.2), (w * 0.3, w * 0.3, h * 0.45), c, amp=0.15, f=2.6 / w, seed=seed + 1)
    # moss on the top
    moss = envkit.pick(MOSS, seed + 5)
    g.paint((-w, -w, h * 0.5), (w, w, h * 1.2), lambda X, Y, Z: (vkit.snoise(X, Y, Z, 4.0 / w, seed) > -0.2) & (Z > h * 0.55 + 0.15 * h * vkit.snoise(X, Y, Z, 6.0 / w, seed + 3)), moss)


@model('RockS', 'rock', 0.15, (-1.2, -1.1, 0), (1.4, 1.1, 1.3), 'small mossy rock')
def _rock_s(g, rng):
    rock(g, rng, 2.0, 1.2, 81)


@model('RockM', 'rock', 0.2, (-2.4, -2.1, 0), (2.8, 2.1, 2.6), 'medium mossy boulder')
def _rock_m(g, rng):
    rock(g, rng, 4.0, 2.4, 83)


@model('RockL', 'rock', 0.3, (-4.6, -4.0, 0), (5.2, 4.0, 5.2), 'big mossy boulder')
def _rock_l(g, rng):
    rock(g, rng, 7.6, 4.8, 85)


@model('SteppingStones', 'rock', 0.15, (-3.5, -1.5, 0), (3.5, 1.5, 0.4), 'three flat stepping stones for paths')
def _steps(g, rng):
    c = envkit.tones(STONE, 0, 0.3, 87, sx=0.4)
    for i, (x, y, r) in enumerate(((-2.3, 0.3, 1.0), (0, -0.3, 1.15), (2.3, 0.25, 0.95))):
        g.blob((x, y, 0.0), (r, r * 0.85, 0.3), c, amp=0.12, f=3, seed=87 + i)


# ------------------------------------------------- flowers, grass, shrooms
def flower(g, x, y, h, petal, center, seed, r=0.25):
    stem = vkit.col('#3E9A3A')
    g.box((x - 0.05, y - 0.05, 0), (x + 0.05, y + 0.05, h), stem)
    g.box((x - 0.05, y, h * 0.45), (x + 0.15, y + 0.1, h * 0.55), vkit.col('#55B947'))
    pc = vkit.col(petal)
    for dx, dy in ((r, 0), (-r, 0), (0, r), (0, -r)):
        g.ell((x + dx * 0.8, y + dy * 0.8, h), (r * 0.62, r * 0.62, 0.11), pc)
    g.ell((x, y, h + 0.04), (0.12, 0.12, 0.1), vkit.col(center))


def patch(g, rng, petals, n, rad, seed):
    rng = np.random.default_rng(seed)
    leaves = envkit.tones(LEAF, 0, 0.5, seed)
    g.blob((0, 0, 0.0), (rad, rad * 0.85, 0.35), leaves, amp=0.2, f=3, seed=seed)
    for i in range(n):
        a = rng.uniform(0, 2 * math.pi)
        d = rad * math.sqrt(rng.uniform(0.02, 0.8))
        flower(g, math.cos(a) * d, math.sin(a) * d, rng.uniform(0.55, 1.05), petals[i % len(petals)], '#FFD93D', seed + i)


@model('FlowerPatchPink', 'flowers', 0.1, (-1.6, -1.6, 0), (1.6, 1.6, 1.3), 'patch of pink and white flowers')
def _fp1(g, rng):
    patch(g, rng, ['#FF7FB0', '#FFFFFF', '#FF9CC4'], 9, 1.3, 101)


@model('FlowerPatchSunny', 'flowers', 0.1, (-1.6, -1.6, 0), (1.6, 1.6, 1.3), 'patch of yellow and orange flowers')
def _fp2(g, rng):
    patch(g, rng, ['#FFD23D', '#FF9F43', '#FFE680'], 9, 1.3, 103)


@model('FlowerPatchViolet', 'flowers', 0.1, (-1.6, -1.6, 0), (1.6, 1.6, 1.3), 'patch of violet and blue flowers')
def _fp3(g, rng):
    patch(g, rng, ['#A77BFF', '#7FA6FF', '#C9A8FF'], 9, 1.3, 105)


def tuft(g, rng, n, h, seed):
    """thin one-voxel blades fanning out from a clump, dark at the root and
    light at the tip"""
    rng = np.random.default_rng(seed)
    root, mid, tip = vkit.col('#3E9A3A'), vkit.col('#55B947'), vkit.col('#8EDB6A')
    for i in range(n):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0, 0.35)
        x, y = math.cos(a) * d, math.sin(a) * d
        lean = rng.uniform(0.2, 0.6)
        hh = h * rng.uniform(0.55, 1.0)
        bend = rng.uniform(0.3, 0.6)
        pts = []
        for j in range(7):
            t = j / 6
            pts.append((x + math.cos(a) * lean * t ** (1 + bend), y + math.sin(a) * lean * t ** (1 + bend), hh * t))
        for j, (pa, pb) in enumerate(zip(pts, pts[1:])):
            c = root if j < 2 else (mid if j < 4 else tip)
            g.seg(pa, pb, 0.06, c)


@model('GrassTuft', 'grass', 0.1, (-1, -1, 0), (1, 1, 1.2), 'clump of grass blades')
def _gt1(g, rng):
    tuft(g, rng, 22, 1.1, 111)


@model('GrassTuftTall', 'grass', 0.1, (-1.1, -1.1, 0), (1.1, 1.1, 1.8), 'tall clump of grass with a bloom')
def _gt2(g, rng):
    tuft(g, rng, 26, 1.6, 113)
    g.ell((0.35, 0.1, 1.55), (0.14, 0.14, 0.14), vkit.col('#FFFFFF'))
    g.ell((-0.3, -0.25, 1.35), (0.14, 0.14, 0.14), vkit.col('#FFD93D'))


@model('MushroomRing', 'shrooms', 0.1, (-1.4, -1.4, 0), (1.4, 1.4, 1.1), 'little ring of glowing mushrooms')
def _mr(g, rng):
    rng = np.random.default_rng(121)
    for i in range(6):
        a = i * 2 * math.pi / 6 + rng.uniform(-0.2, 0.2)
        x, y = math.cos(a) * 0.95, math.sin(a) * 0.95
        h = rng.uniform(0.4, 0.8)
        g.cyl(x, y, 0, h, 0.11, vkit.col('#F4E9D2'))
        capc = vkit.col(['#7FE3FF', '#B98CFF', '#7FE3FF'][i % 3], 1.6)
        g.ell((x, y, h), (0.3, 0.3, 0.18), capc)
