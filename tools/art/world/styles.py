"""Hatchery Heist world reference assets, three style directions.
Every function draws into a vkit.Grid at a location given in studs."""
import math
import numpy as np
from vkit import col, hnoise, snoise, VOX

# ------------------------------------------------------------------ styles
STYLES = {
    'A': dict(
        key='A', name='Storybook Farm',
        grass=['#6CC64B', '#62BC42', '#77CF55'], grass2=['#5DB13E', '#55A838', '#66B946'],
        seam='#4E9A35', soil='#8A5A35', soil2='#7A4E2E',
        tuft=['#7FD85A', '#5FB842', '#8EE068'], flowers=[('#FF6F91', '#FFE066'), ('#FFFFFF', '#FFC93C'), ('#6FA8FF', '#FFFFFF')],
        path=['#D8B07A', '#CFA36B', '#E0BC8A'], pebble='#B98C5A',
        fence='picket', fence_c=['#F6EEDC', '#EDE2CB'], post='#F6EEDC', post_cap='#D2483D',
        tree='oak', trunk=['#8B5A33', '#7A4D2B', '#9A6A3F'], leaf_dark=['#3E9A3A', '#37903A'], leaf=['#55B947', '#4DB043', '#5CC24F'],
        leaf_top=['#7AD35E', '#86DA66'], fruit=('#E8413C', 0.0),
        ped='crate', ped_c=['#C98E52', '#B97F45'], ped_trim='#8B5A33', straw=['#F2CE5C', '#E8BF48', '#F7DA75'],
        belt_slat=['#C6904F', '#B98446'], belt_gap='#6E4526', rail='#D2483D', rail2='#A8352E', bolt=('#F4C542', 0.0),
        belt_accent=None, leg='#7A4D2B',
        hub_base=['#C98E52', '#B97F45'], hub_trim='#D2483D', nest=['#F2CE5C', '#DDB040', '#F7DA75'], gold=('#FFC935', 1.2),
        wall=['#D2483D', '#C8413A', '#DB5247'], wall_seam='#A8352E', trim='#F6EEDC', floor=['#D9A766', '#CF9C5C', '#E2B273'],
        floor_seam='#A87440', lamp=('#FFC870', 4.0), lamp_frame='#3B3B44', window=('#FFE7A8', 1.6),
        sky_top=(0.20, 0.45, 1.0), sky_hor=(0.45, 0.68, 1.0), sun=3.2, sun_col=(1.0, 0.95, 0.85), sun_rot=(48, 0, 140),
        amb=0.85, exposure=-0.1, rough=0.6, glow=3.0, look='AgX - Medium High Contrast',
    ),
    'B': dict(
        key='B', name='Toybox Bright',
        grass=['#55D65A', '#4FCF55', '#5EDD63'], grass2=['#3EBE4C', '#38B647', '#45C553'],
        seam='#2E9E3E', soil='#B86B3E', soil2='#A65E35',
        tuft=['#7CF06E', '#5BDB5E'], flowers=[('#FF4FA3', '#FFFFFF'), ('#FFD23F', '#FF7A2F'), ('#4FC3FF', '#FFFFFF')],
        path=['#FFF4DE', '#FFEFD2'], path_edge='#4C8DFF', pebble='#FFE2B0',
        fence='candy', fence_c=['#FF5FA2', '#2EC9C3', '#FFC93C'], post='#FFFFFF', post_cap='#FFFFFF',
        tree='pine', trunk=['#C97A3A', '#B96C30'], leaf_dark=['#1FA36B', '#1A9A63'], leaf=['#2EC27E', '#33CC86'],
        leaf_top=['#7EF0A8', '#8FF5B5'], fruit=('#FFFFFF', 0.0),
        ped='neon', ped_c=['#FFFFFF', '#F4F4FA'], ped_trim='#3B3F6B', straw=['#FFFFFF'],
        belt_slat=['#2B2F55', '#30355E'], belt_gap='#15172E', rail='#FFFFFF', rail2='#DADCF0', bolt=('#FFD23F', 0.0),
        belt_accent=('#FFD23F', 2.0), leg='#3B3F6B',
        hub_base=['#FF5FA2', '#FFFFFF'], hub_trim='#2EC9C3', nest=['#FFC935', '#FFB01F', '#FFD860'], gold=('#FFD23F', 1.4),
        wall=['#B79CFF', '#AE92FA', '#C2A9FF'], wall_seam='#8E70E8', trim='#FFFFFF', floor=['#FFE7F1', '#FFD4E6'],
        floor_seam='#E8A9C8', lamp=('#7FF7FF', 3.0), lamp_frame='#FFFFFF', window=('#C9F4FF', 1.2),
        sky_top=(0.08, 0.42, 1.0), sky_hor=(0.38, 0.75, 1.0), sun=3.6, sun_col=(1.0, 0.98, 0.95), sun_rot=(40, 0, 150),
        amb=0.95, exposure=-0.05, rough=0.35, glow=3.5, look='AgX - Punchy',
    ),
    'C': dict(
        key='C', name='Enchanted Grove',
        grass=['#4DB25C', '#45A854', '#55BC63'], grass2=['#3FA052', '#38974A', '#46A957'],
        seam='#2A6E3A', soil='#5E4636', soil2='#4F3A2D',
        tuft=['#5DBB5E', '#4AAA55', '#7ACB68'], flowers=[('#B48CFF', '#FFF2A8'), ('#7FE3FF', '#FFFFFF')],
        glowshroom=('#7DF9E8', 2.5), path=['#8E98A8', '#868FA0', '#97A1B2'], path_moss='#4E9A50', rune=('#5CF2FF', 3.5),
        fence='stone', fence_c=['#9AA3B3', '#8C95A6', '#A6AEBD'], post='#9AA3B3', post_cap='#B7BFCC', rail_wood='#5A3E2E',
        crystal=('#6CF5FF', 4.0),
        tree='blossom', trunk=['#6B4A3A', '#5E4033', '#775444'], leaf_dark=['#C2649F', '#B5598F'], leaf=['#F08CC6', '#EA7FBE', '#F59BD0'],
        leaf_top=['#FFC2E4', '#FFB3DC'], fruit=('#FFD27A', 3.5),
        ped='altar', ped_c=['#9AA3B3', '#8C95A6', '#A6AEBD'], ped_trim='#6E778A', straw=['#D9B35A'],
        belt_slat=['#6E778A', '#666F82'], belt_gap='#3C4252', rail='#C9A24A', rail2='#A9842F', bolt=('#6CF5FF', 3.0),
        belt_accent=('#6CF5FF', 3.0), leg='#5A3E2E',
        hub_base=['#9AA3B3', '#8C95A6'], hub_trim='#C9A24A', nest=['#E8B84A', '#D9A63A', '#F2C862'], gold=('#FFD27A', 2.0),
        wall=['#E9DCC4', '#E2D4BA', '#EFE4CF'], wall_seam='#B9A98E', stone=['#8C95A6', '#9AA3B3', '#7F8899'],
        timber='#5A3E2E', trim='#5A3E2E', floor=['#8C95A6', '#9AA3B3', '#838C9D'], floor_seam='#5E6676',
        lamp=('#FFC870', 4.5), lamp_frame='#2E2A2A', window=('#FFC870', 2.5),
        sky_top=(0.20, 0.25, 0.70), sky_hor=(1.0, 0.70, 0.55), sun=3.4, sun_col=(1.0, 0.80, 0.60), sun_rot=(62, 0, 125),
        amb=0.75, exposure=0.0, rough=0.7, glow=4.0, look='AgX - Punchy', vt='AgX',
    ),
}


def pick(names, seed=0, scale=1.0):
    """colour function: per-voxel random choice among names"""
    base = col(names[0])
    ids = np.array([base] + [col(n, of=base) for n in names[1:]])
    from vkit import NOISE
    NOISE.update(int(i) for i in ids[1:])

    def f(X, Y, Z):
        h = hnoise(X * scale, Y * scale, Z * scale, seed)
        return ids[np.minimum((h * len(ids)).astype(int), len(ids) - 1)]
    return f


def patch(namesA, namesB, f=0.35, seed=0, thr=0.0):
    """two colour sets in soft patches, each speckled"""
    a, b = pick(namesA, seed), pick(namesB, seed + 7)

    def g(X, Y, Z):
        return np.where(snoise(X, Y, Z * 0 + 3.1, f, seed) > thr, a(X, Y, Z), b(X, Y, Z))
    return g


# ------------------------------------------------------------------ ground
def ground(g, st, x0, y0, x1, y1, tile=4.0, top=0.0, depth=0.8):
    """baseplate tiles: tile x tile studs, checker of two greens, thin seams"""
    A, B = pick(st['grass'], 1), pick(st['grass2'], 2)

    def c(X, Y, Z):
        ch = (np.floor(X / tile) + np.floor(Y / tile)) % 2 == 0
        return np.where(ch, A(X, Y, Z), B(X, Y, Z))
    g.box((x0, y0, top - depth), (x1, y1, top - 0.2), pick([st['soil'], st['soil2']], 3))
    g.box((x0, y0, top - 0.2), (x1, y1, top), c)
    # seams: lower the top voxel along tile edges
    def seam(X, Y, Z):
        fx = np.mod(X, tile)
        fy = np.mod(Y, tile)
        return (fx < VOX) | (fy < VOX)
    g.carve((x0, y0, top - VOX), (x1, y1, top), seam)
    g.paint((x0, y0, top - 2 * VOX), (x1, y1, top - VOX), seam, col(st['seam']))


def tufts(g, st, x0, y0, x1, y1, n, seed=5, avoid=None, top=0.0):
    rng = np.random.default_rng(seed)
    cs = [col(c) for c in st['tuft']]
    for _ in range(n):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        if avoid and avoid(x, y):
            continue
        c = cs[rng.integers(len(cs))]
        for _b in range(rng.integers(3, 6)):
            bx = x + rng.integers(-3, 4) * VOX
            by = y + rng.integers(-3, 4) * VOX
            h = rng.integers(1, 4) * VOX
            g.box((bx, by, top), (bx + VOX, by + VOX, top + h), c, only_empty=True)


def flowers(g, st, x0, y0, x1, y1, n, seed=9, avoid=None, top=0.0):
    rng = np.random.default_rng(seed)
    stem = col(st['tuft'][1])
    for _ in range(n):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        if avoid and avoid(x, y):
            continue
        x, y = round(x / VOX) * VOX, round(y / VOX) * VOX
        pet, ctr = st['flowers'][rng.integers(len(st['flowers']))]
        h = rng.integers(3, 6) * VOX
        g.box((x, y, top), (x + VOX, y + VOX, top + h), stem, only_empty=True)
        g.box((x - VOX, y - VOX, top + h), (x + 2 * VOX, y + 2 * VOX, top + h + VOX), col(pet))
        g.box((x, y, top + h), (x + VOX, y + VOX, top + h + VOX), col(ctr))
        g.box((x, y, top + h + VOX), (x + VOX, y + VOX, top + h + 2 * VOX), col(pet))


def glowshrooms(g, st, x0, y0, x1, y1, n, seed=11, avoid=None, top=0.0):
    rng = np.random.default_rng(seed)
    cap = col(*st['glowshroom'])
    stem = col('#E8E2D0')
    for _ in range(n):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        if avoid and avoid(x, y):
            continue
        for k in range(rng.integers(1, 4)):
            bx, by = x + rng.uniform(-0.4, 0.4), y + rng.uniform(-0.4, 0.4)
            h = rng.uniform(0.2, 0.45)
            g.cyl(bx, by, top, top + h, 0.06, stem)
            g.ell((bx, by, top + h), (0.17, 0.17, 0.1), cap, cond=lambda X, Y, Z, z=top + h: Z >= z - 0.02)


def path(g, st, x0, y0, x1, y1, top=0.0):
    k = st['key']
    if k == 'A':
        g.box((x0, y0, top - 0.2), (x1, y1, top - VOX), pick(st['path'], 21))
        g.carve((x0, y0, top - VOX), (x1, y1, top + 0.3))
        # pebbles
        g.fill((x0, y0, top - VOX), (x1, y1, top), lambda X, Y, Z: hnoise(X, Y, Z, 4) > 0.94, col(st['pebble']))
        # soft edge: random notches
        g.fill((x0 - 0.3, y0, top - VOX), (x0 + 0.3, y1, top), lambda X, Y, Z: hnoise(X, Y, Z * 0, 5) > 0.5, pick(st['path'], 22))
        g.fill((x1 - 0.3, y0, top - VOX), (x1 + 0.3, y1, top), lambda X, Y, Z: hnoise(X, Y, Z * 0, 6) > 0.5, pick(st['path'], 23))
    elif k == 'B':
        # rounded pavers 1.6 studs with gaps, blue edging
        g.carve((x0, y0, top - VOX), (x1, y1, top + 0.3))
        g.box((x0, y0, top - 0.3), (x1, y1, top - VOX), col('#C9CCE8'))
        P = 1.6

        def paver(X, Y, Z):
            fx, fy = np.mod(X - x0, P), np.mod(Y - y0, P)
            dx = np.maximum(np.maximum(0.35 - fx, fx - (P - 0.35)), 0)
            dy = np.maximum(np.maximum(0.35 - fy, fy - (P - 0.35)), 0)
            return dx * dx + dy * dy <= 0.25 ** 2
        g.fill((x0, y0, top - VOX), (x1, y1, top + VOX), paver, pick(st['path'], 24))
        g.box((x0 - 0.3, y0, top - VOX), (x0, y1, top + VOX), col(st['path_edge']))
        g.box((x1, y0, top - VOX), (x1 + 0.3, y1, top + VOX), col(st['path_edge']))
    else:
        # flagstones with mossy gaps and glowing rune inlays
        g.carve((x0, y0, top - VOX), (x1, y1, top + 0.3))
        g.box((x0, y0, top - 0.3), (x1, y1, top - VOX), col(st['path_moss']))
        S = 1.3

        def stone(X, Y, Z):
            row = np.floor((Y - y0) / S)
            xx = X - x0 + (row % 2) * S * 0.5 + snoise(X, Y, Z * 0, 2.0, 3) * 0.15
            fx, fy = np.mod(xx, S), np.mod(Y - y0 + snoise(X, Y, Z * 0, 2.3, 4) * 0.12, S)
            return (fx > 0.12) & (fx < S - 0.12) & (fy > 0.12) & (fy < S - 0.12)
        g.fill((x0, y0, top - VOX), (x1, y1, top + VOX), stone, pick(st['path'], 25))

        def rune(X, Y, Z):
            # a few stones get a glowing ring inlay
            row = np.floor((Y - y0) / S)
            xx = X - x0 + (row % 2) * S * 0.5
            cx, cy = np.floor(xx / S), row
            sel = hnoise(cx * VOX * 10, cy * VOX * 10, cx * 0, 8) > 0.82
            fx, fy = np.mod(xx, S) - S / 2, np.mod(Y - y0, S) - S / 2
            r = np.sqrt(fx * fx + fy * fy)
            return sel & (np.abs(r - 0.32) < 0.06)
        g.paint((x0, y0, top), (x1, y1, top + VOX), rune, col(*st['rune']))


# ------------------------------------------------------------------- fence
def fence(g, st, x0, x1, y, top=0.0, h=3.0, every=4.0):
    k = st['key']
    xs = np.arange(x0, x1 + 1e-6, every)
    if k == 'A':
        wood = pick(st['fence_c'], 31)
        g.box((x0, y - 0.06, top + 0.7), (x1, y + 0.14, top + 0.95), wood)
        g.box((x0, y - 0.06, top + 2.0), (x1, y + 0.14, top + 2.25), wood)
        px = x0
        while px < x1 - 0.2:
            def pk(X, Y, Z, px=px):
                tip = top + h - 0.35 + 0.35 * (1 - np.abs(X - (px + 0.15)) / 0.2)
                return Z < tip
            g.fill((px, y + 0.14, top), (px + 0.3, y + 0.34, top + h), pk, wood)
            px += 0.5
        for x in xs:
            g.box((x - 0.25, y - 0.1, top), (x + 0.25, y + 0.4, top + h + 0.2), wood)
            g.box((x - 0.3, y - 0.15, top + h + 0.2), (x + 0.3, y + 0.45, top + h + 0.4), col(st['post_cap']))
            g.box((x - 0.2, y - 0.05, top + h + 0.4), (x + 0.2, y + 0.35, top + h + 0.5), col(st['post_cap']))
    elif k == 'B':
        cs = [col(c) for c in st['fence_c']]
        white = col('#FFFFFF')
        # two chunky tube rails
        for z in (top + 1.0, top + 2.1):
            g.seg((x0, y, z), (x1, y, z), 0.22, white)
        for i, x in enumerate(xs):
            c = cs[i % len(cs)]
            g.rbox((x - 0.45, y - 0.45, top), (x + 0.45, y + 0.45, top + h - 0.2), 0.25, c)
            g.ell((x, y, top + h + 0.2), (0.55, 0.55, 0.55), c)
            g.cyl(x, y, top + h - 0.35, top + h - 0.15, 0.55, white)
        # little round pickets between posts
        for x in np.arange(x0 + 0.8, x1, 0.8):
            if np.min(np.abs(xs - x)) < 0.6:
                continue
            g.rbox((x - 0.18, y - 0.18, top), (x + 0.18, y + 0.18, top + 2.3), 0.12, col('#FFFFFF'))
            g.ell((x, y, top + 2.35), (0.2, 0.2, 0.2), cs[int(x * 7) % len(cs)])
    else:
        stone = pick(st['fence_c'], 33)
        wood = col(st['rail_wood'])
        for z in (top + 0.9, top + 1.9):
            g.box((x0, y - 0.12, z), (x1, y + 0.12, z + 0.28), wood)
        for i, x in enumerate(xs):
            g.box((x - 0.45, y - 0.45, top), (x + 0.45, y + 0.45, top + h - 0.3), stone)
            g.fill((x - 0.45, y - 0.45, top), (x + 0.45, y + 0.45, top + h - 0.3),
                   lambda X, Y, Z: (np.mod(Z - top, 0.6) < VOX), col('#6E778A'), only_filled=True)
            g.box((x - 0.55, y - 0.55, top + h - 0.3), (x + 0.55, y + 0.55, top + h), col(st['post_cap']))
            # moss on the cap
            g.fill((x - 0.55, y - 0.55, top + h - 0.1), (x + 0.55, y + 0.55, top + h + 0.1),
                   lambda X, Y, Z: snoise(X, Y, Z, 3, 2) > 0.1, col('#4E9A50'), only_filled=True)
            if i % 2 == 0:
                # crystal lantern on top
                fr = col(st['lamp_frame'])
                g.box((x - 0.3, y - 0.3, top + h), (x + 0.3, y + 0.3, top + h + 0.1), fr)
                g.box((x - 0.3, y - 0.3, top + h + 0.9), (x + 0.3, y + 0.3, top + h + 1.0), fr)
                for dx in (-0.3, 0.2):
                    for dy in (-0.3, 0.2):
                        g.box((x + dx, y + dy, top + h), (x + dx + 0.1, y + dy + 0.1, top + h + 1.0), fr)
                g.ell((x, y, top + h + 0.5), (0.17, 0.17, 0.35), col(*st['crystal']))
                g.cyl(x, y, top + h + 1.0, top + h + 1.3, 0.25, fr, r1=0.0)


# -------------------------------------------------------------------- trees
def tree(g, st, x, y, top=0.0, s=1.0, seed=1):
    k = st['tree']
    trunk = pick(st['trunk'], 41)
    if k == 'oak':
        H = 8.0 * s
        # roots + tapered trunk
        g.cyl(x, y, top, top + 3.6 * s, 0.55 * s, trunk, r1=0.38 * s)
        for a in range(4):
            ang = a * math.pi / 2 + 0.4
            g.seg((x, y, top + 0.5 * s), (x + math.cos(ang) * 0.9 * s, y + math.sin(ang) * 0.9 * s, top), 0.25 * s, trunk, r1=0.15 * s)
        g.seg((x, y, top + 3.0 * s), (x - 1.3 * s, y + 0.3 * s, top + 4.6 * s), 0.25 * s, trunk, r1=0.15 * s)
        g.seg((x, y, top + 3.2 * s), (x + 1.2 * s, y - 0.4 * s, top + 4.8 * s), 0.25 * s, trunk, r1=0.15 * s)
        blobs = [((0, 0, 5.6), (2.7, 2.7, 2.1)), ((-1.6, 0.4, 4.9), (1.8, 1.8, 1.5)), ((1.6, -0.5, 5.0), (1.8, 1.8, 1.5)),
                 ((0.2, 1.3, 6.4), (1.7, 1.6, 1.4)), ((-0.4, -1.2, 6.6), (1.6, 1.6, 1.3))]
        leaf_c = _two_tone(st, top + 4.6 * s, top + 6.6 * s, seed)
        for i, (c, r) in enumerate(blobs):
            g.blob((x + c[0] * s, y + c[1] * s, top + c[2] * s), (r[0] * s, r[1] * s, r[2] * s), leaf_c, amp=0.08, f=2.2, seed=seed + i)
        _fruit(g, st, x, y, top + 5.5 * s, 3.0 * s, 26, seed)
    elif k == 'pine':
        H = 10.0 * s
        g.cyl(x, y, top, top + 2.2 * s, 0.5 * s, trunk, r1=0.42 * s)
        tiers = [(1.6, 3.8, 3.0), (3.6, 3.0, 2.6), (5.4, 2.3, 2.3), (7.0, 1.6, 2.0), (8.4, 0.9, 1.6)]
        dark, mid, light = pick(st['leaf_dark'], 42), pick(st['leaf'], 43), pick(st['leaf_top'], 44)
        for i, (z0, r, hh) in enumerate(tiers):
            zz0, zz1 = top + z0 * s, top + (z0 + hh) * s

            def cfn(X, Y, Z, zz0=zz0, zz1=zz1):
                t = (Z - zz0) / (zz1 - zz0)
                return np.where(t < 0.18, dark(X, Y, Z), np.where(t > 0.72, light(X, Y, Z), mid(X, Y, Z)))
            # rounded cone tier: radius shrinks with height, lip at bottom
            g.cyl(x, y, zz0, zz1, r * s, cfn, r1=0.25 * s)
            g.cyl(x, y, zz0 - 0.2 * s, zz0 + 0.25 * s, (r - 0.2) * s, dark)
        # star on top
        g.ell((x, y, top + 10.3 * s), (0.45 * s, 0.25 * s, 0.45 * s), col('#FFD23F', 2.0))
        g.ell((x, y, top + 10.3 * s), (0.2 * s, 0.25 * s, 0.7 * s), col('#FFD23F', 2.0))
        # candy baubles
        rng = np.random.default_rng(seed)
        bc = [col('#FF4FA3'), col('#4FC3FF'), col('#FFD23F')]
        for i, (z0, r, hh) in enumerate(tiers[:-1]):
            for j in range(5):
                a = rng.uniform(0, 2 * math.pi)
                zz = z0 + 0.25
                rr = r - 0.1
                g.ell((x + math.cos(a) * rr * s, y + math.sin(a) * rr * s, top + zz * s), (0.22 * s,) * 3, bc[(i + j) % 3])
    else:  # blossom, twisty
        pts = [(0, 0, 0), (0.3, 0.1, 1.2), (-0.1, 0.3, 2.4), (0.4, -0.1, 3.4), (0.1, 0.2, 4.4)]
        for a, b in zip(pts, pts[1:]):
            g.seg((x + a[0] * s, y + a[1] * s, top + a[2] * s), (x + b[0] * s, y + b[1] * s, top + b[2] * s), 0.5 * s, trunk, r1=0.42 * s)
        for a in range(5):
            ang = a * 2 * math.pi / 5 + 0.3
            g.seg((x, y, top + 0.6 * s), (x + math.cos(ang) * 1.1 * s, y + math.sin(ang) * 1.1 * s, top), 0.3 * s, trunk, r1=0.12 * s)
        brs = [((0.1, 0.2, 4.2), (-1.9, 0.6, 5.6)), ((0.1, 0.2, 4.2), (1.9, -0.4, 5.4)), ((0.1, 0.2, 4.4), (0.3, 1.8, 6.0)),
               ((0.1, 0.2, 4.4), (-0.3, -1.6, 6.0))]
        for a, b in brs:
            g.seg((x + a[0] * s, y + a[1] * s, top + a[2] * s), (x + b[0] * s, y + b[1] * s, top + b[2] * s), 0.28 * s, trunk, r1=0.15 * s)
        blobs = [((0, 0, 6.2), (2.4, 2.4, 1.6)), ((-2.0, 0.6, 5.7), (1.6, 1.6, 1.2)), ((2.0, -0.4, 5.6), (1.6, 1.6, 1.2)),
                 ((0.3, 1.9, 6.2), (1.5, 1.4, 1.2)), ((-0.3, -1.7, 6.3), (1.5, 1.5, 1.1)), ((0.1, 0.1, 7.3), (1.5, 1.5, 1.0))]
        leaf_c = _two_tone(st, top + 5.0 * s, top + 7.6 * s, seed)
        for i, (c, r) in enumerate(blobs):
            g.blob((x + c[0] * s, y + c[1] * s, top + c[2] * s), (r[0] * s, r[1] * s, r[2] * s), leaf_c, amp=0.12, f=2.4, seed=seed + i)
        # hanging glowing lantern fruits under the canopy
        rng = np.random.default_rng(seed + 3)
        fr = col(*st['fruit'])
        stem = col('#3E2A22')
        for _ in range(9):
            a = rng.uniform(0, 2 * math.pi)
            rr = rng.uniform(1.0, 2.6) * s
            px, py = x + math.cos(a) * rr, y + math.sin(a) * rr
            # find canopy underside: start at 5.0 and hang down
            zt = top + 5.0 * s
            g.box((px, py, zt - 0.6 * s), (px + VOX, py + VOX, zt), stem, only_empty=True)
            g.ell((px + 0.05, py + 0.05, zt - 0.85 * s), (0.18 * s, 0.18 * s, 0.25 * s), fr)
        # fallen petals on the ground
        g.fill((x - 4, y - 4, top - VOX), (x + 4, y + 4, top), lambda X, Y, Z: (hnoise(X, Y, Z, 61) > 0.93) & ((X - x) ** 2 + (Y - y) ** 2 < 12),
               pick(st['leaf_top'] + st['leaf'], 62), only_filled=True)


def _two_tone(st, z0, z1, seed):
    dark, mid, light = pick(st['leaf_dark'], seed + 50), pick(st['leaf'], seed + 51), pick(st['leaf_top'], seed + 52)

    def c(X, Y, Z):
        t = (Z - z0) / (z1 - z0) + 0.12 * snoise(X, Y, Z, 2.5, seed)
        return np.where(t < 0.15, dark(X, Y, Z), np.where(t > 0.78, light(X, Y, Z), mid(X, Y, Z)))
    return c


def _fruit(g, st, x, y, zc, r, n, seed):
    rng = np.random.default_rng(seed)
    fc = col(*st['fruit'])
    leafc = col('#2F7A2E')
    for _ in range(n):
        a = rng.uniform(0, 2 * math.pi)
        e = rng.uniform(-0.4, 0.7)
        rr = r * 0.97
        px = x + math.cos(a) * rr * math.cos(e)
        py = y + math.sin(a) * rr * math.cos(e)
        pz = zc + r * 0.7 * math.sin(e)
        g.ell((px, py, pz), (0.17, 0.17, 0.17), fc)
        g.box((px, py, pz + 0.15), (px + VOX, py + VOX, pz + 0.3), leafc)


# --------------------------------------------------------------------- eggs
EGGS = {
    'basic': dict(w=1.5, h=2.0, base='#FFF3DC', spot='#C9A06A', kind='speckle'),
    'meadow': dict(w=1.5, h=2.0, base='#8EE07A', spot='#3E9A3A', kind='zigzag'),
    'moonlit': dict(w=1.6, h=2.25, base='#3B3F9E', spot='#FFF6B0', kind='stars'),
    'premium': dict(w=1.75, h=2.5, base='#FFC935', spot='#FF5FA2', kind='gem'),
}


def egg(g, x, y, z, kind='moonlit', s=1.0):
    e = EGGS[kind]
    R, H = e['w'] / 2 * s, e['h'] * s
    zc = z + H * 0.42

    def m(X, Y, Z):
        t = (Z - zc) / (np.where(Z > zc, H * 0.58, H * 0.42))
        rr = R * np.sqrt(np.clip(1 - t * t, 0, 1)) * np.where(Z > zc, 1 - 0.12 * t, 1)
        return (X - x) ** 2 + (Y - y) ** 2 <= rr * rr
    base = col(e['base'])
    if e['kind'] == 'speckle':
        c = lambda X, Y, Z: np.where(hnoise(X, Y, Z, 71) > 0.9, col(e['spot']), base)
    elif e['kind'] == 'zigzag':
        c = lambda X, Y, Z: np.where(np.abs(Z - (zc + 0.15 * s) - 0.18 * s * np.abs(np.mod(np.arctan2(Y - y, X - x) * 4 / math.pi, 2) - 1)) < 0.14 * s,
                                     col(e['spot']), base)
    elif e['kind'] == 'stars':
        star = col(e['spot'], 2.5)
        deep = col('#2A2C78')

        def c(X, Y, Z):
            h = hnoise(np.floor(X / 0.2) * 0.2, np.floor(Y / 0.2) * 0.2, np.floor(Z / 0.2) * 0.2, 72)
            sp = (h > 0.86) & (hnoise(X, Y, Z, 73) > 0.6)
            return np.where(sp, star, np.where(Z < zc - 0.3 * s, deep, base))
    else:
        gem = col('#FF5FA2', 2.5)
        c = lambda X, Y, Z: np.where(np.abs(Z - zc) < 0.12 * s, gem, base)
    g.fill((x - R, y - R, z), (x + R, y + R, z + H), m, c)


def pedestal(g, st, x, y, top=0.0, egg_kind='moonlit', W=2.4, Hh=0.75, trim_col=None):
    k = st['ped']
    hw = W / 2
    eg = EGGS[egg_kind]
    trim = trim_col or eg['base']
    if k == 'crate':
        wood = pick(st['ped_c'], 81)
        g.box((x - hw, y - hw, top), (x + hw, y + hw, top + Hh), wood)
        # plank seams + dark frame corners
        g.paint((x - hw, y - hw, top), (x + hw, y + hw, top + Hh), lambda X, Y, Z: np.mod(Z - top, 0.25) < VOX, col(st['ped_trim']))
        for sx in (-1, 1):
            for sy in (-1, 1):
                g.box((x + sx * hw - 0.15 - 0.15 * sx, y + sy * hw - 0.15 - 0.15 * sy, top),
                      (x + sx * hw + 0.15 - 0.15 * sx, y + sy * hw + 0.15 - 0.15 * sy, top + Hh + 0.05), col(st['ped_trim']))
        # coloured band in the egg's colour
        g.box((x - hw - VOX, y - hw - VOX, top + Hh - 0.25), (x + hw + VOX, y + hw + VOX, top + Hh - 0.12), col(trim))
        # straw nest ring
        straw = pick(st['straw'], 82)
        g.fill((x - 1.0, y - 1.0, top + Hh), (x + 1.0, y + 1.0, top + Hh + 0.35),
               lambda X, Y, Z: (np.abs(np.sqrt((X - x) ** 2 + (Y - y) ** 2) - 0.72) < 0.24 + 0.08 * snoise(X, Y, Z, 6, 3)), straw)
        egg(g, x, y, top + Hh + 0.05, egg_kind)
    elif k == 'neon':
        white = pick(st['ped_c'], 83)
        g.cyl(x, y, top, top + Hh, hw, white, r1=hw - 0.1)
        g.cyl(x, y, top + 0.15, top + 0.3, hw + 0.05, col(trim, 2.0))
        g.cyl(x, y, top + Hh, top + Hh + 0.12, hw - 0.3, col(st['ped_trim']))
        g.cyl(x, y, top + Hh + 0.12, top + Hh + 0.22, hw - 0.5, col(trim, 2.0))
        egg(g, x, y, top + Hh + 0.12, egg_kind)
    else:
        stone = pick(st['ped_c'], 84)
        # octagonal altar: two tiers
        oct_ = lambda r: (lambda X, Y, Z: (np.abs(X - x) <= r) & (np.abs(Y - y) <= r) & (np.abs(X - x) + np.abs(Y - y) <= r * 1.42))
        g.fill((x - hw, y - hw, top), (x + hw, y + hw, top + 0.3), oct_(hw), stone)
        g.fill((x - hw, y - hw, top + 0.3), (x + hw, y + hw, top + Hh), oct_(hw - 0.2), stone)
        g.paint((x - hw, y - hw, top + 0.3), (x + hw, y + hw, top + 0.4), None, col(st['ped_trim']))
        # glowing rune ring on top, egg colour
        g.fill((x - hw, y - hw, top + Hh - VOX), (x + hw, y + hw, top + Hh),
               lambda X, Y, Z: np.abs(np.sqrt((X - x) ** 2 + (Y - y) ** 2) - 0.92) < 0.06, col(st['rune'][0] if 'rune' in st else trim, 3.0),
               only_filled=True)
        # rune ticks on the side
        g.paint((x - hw, y - hw, top + 0.45), (x + hw, y + hw, top + 0.6),
                lambda X, Y, Z: np.mod(np.arctan2(Y - y, X - x) * 12 / math.pi, 2) < 0.35, col(st['rune'][0], 3.0))
        egg(g, x, y, top + Hh, egg_kind)


# ---------------------------------------------------------------- conveyor
def conveyor(g, st, cx, cy, R, top=0.0, a0=-math.pi, a1=math.pi, width=3.2, eggs=True, egg_cycle=('basic', 'meadow', 'basic', 'moonlit')):
    """ring belt around (cx, cy), centre radius R; draws angles a0..a1"""
    k = st['key']
    zb = top + 1.0  # belt surface
    w2 = width / 2

    def ang(X, Y):
        return np.arctan2(Y - cy, X - cx)

    def inarc(X, Y):
        a = ang(X, Y)
        return (a >= a0) & (a <= a1)

    def ring(r0, r1):
        return lambda X, Y, Z: (lambda r: (r >= r0) & (r <= r1))(np.sqrt((X - cx) ** 2 + (Y - cy) ** 2)) & inarc(X, Y)
    lo = (cx - R - w2 - 1, cy - R - w2 - 1, top)
    hi = (cx + R + w2 + 1, cy + R + w2 + 1, zb + 0.8)
    # frame
    g.fill(lo, (hi[0], hi[1], zb - 0.3), lambda X, Y, Z: ring(R - w2, R + w2)(X, Y, Z) & (Z > zb - 0.7), col(st['leg']))
    # slats
    slat = pick(st['belt_slat'], 91)
    S = 0.6

    def slat_m(X, Y, Z):
        a = ang(X, Y)
        arc = a * R
        return ring(R - w2 + 0.1, R + w2 - 0.1)(X, Y, Z) & (np.mod(arc, S) > VOX * 1.2)
    g.fill((lo[0], lo[1], zb - 0.3), (hi[0], hi[1], zb), ring(R - w2, R + w2), col(st['belt_gap']))
    g.fill((lo[0], lo[1], zb - 0.3), (hi[0], hi[1], zb), slat_m, slat)
    if st['belt_accent'] is not None:
        acc = col(*st['belt_accent'])
        if k == 'B':
            # glowing chevrons every 1.2 studs
            def chev(X, Y, Z):
                a = ang(X, Y)
                arc = np.mod(a * R, 2.4)
                rr = np.sqrt((X - cx) ** 2 + (Y - cy) ** 2) - R
                return ring(R - w2, R + w2)(X, Y, Z) & (np.abs(arc - 1.2 - np.abs(rr) * 0.45) < 0.12) & (np.abs(rr) < 1.1)
            g.paint((lo[0], lo[1], zb - VOX), (hi[0], hi[1], zb), chev, acc)
    # rails
    rail = col(st['rail'])
    rail2 = col(st['rail2'])
    for rr in (R - w2 - 0.25, R + w2 + 0.25):
        g.fill((lo[0], lo[1], zb - 0.6), (hi[0], hi[1], zb + 0.35), ring(rr - 0.25, rr + 0.25), rail)
        g.paint((lo[0], lo[1], zb - 0.6), (hi[0], hi[1], zb - 0.3), ring(rr - 0.25, rr + 0.25), rail2)
        # bolts / studs on rail tops every ~1.5 studs
        g.fill((lo[0], lo[1], zb + 0.35), (hi[0], hi[1], zb + 0.45),
               lambda X, Y, Z, rr=rr: ring(rr - 0.1, rr + 0.1)(X, Y, Z) & (np.mod(ang(X, Y) * rr, 1.5) < 0.2), col(*st['bolt']))
    # legs
    n = int(2 * math.pi * R / 4)
    for i in range(n):
        a = i * 2 * math.pi / n
        if not (a0 <= ((a + math.pi) % (2 * math.pi)) - math.pi <= a1):
            continue
        for rr in (R - w2 + 0.3, R + w2 - 0.3):
            px, py = cx + math.cos(a) * rr, cy + math.sin(a) * rr
            g.box((px - 0.2, py - 0.2, top), (px + 0.2, py + 0.2, zb - 0.6), col(st['leg']))
    # eggs on pedestals every 4 studs
    if eggs:
        n = int(2 * math.pi * R / 4)
        for i in range(n):
            a = i * 2 * math.pi / n + 0.05
            aa = ((a + math.pi) % (2 * math.pi)) - math.pi
            if not (a0 + 0.12 <= aa <= a1 - 0.12):
                continue
            px, py = cx + math.cos(a) * R, cy + math.sin(a) * R
            kind = egg_cycle[i % len(egg_cycle)]
            small_ped(g, st, px, py, zb, kind)


def small_ped(g, st, x, y, z, kind):
    """belt pedestal 1.9 wide, 0.45 tall"""
    k = st['key']
    eg = EGGS[kind]
    if k == 'A':
        g.box((x - 0.95, y - 0.95, z), (x + 0.95, y + 0.95, z + 0.45), pick(st['ped_c'], 85))
        g.box((x - 1.0, y - 1.0, z + 0.2), (x + 1.0, y + 1.0, z + 0.32), col(eg['base']))
        g.fill((x - 0.9, y - 0.9, z + 0.45), (x + 0.9, y + 0.9, z + 0.7),
               lambda X, Y, Z: np.abs(np.sqrt((X - x) ** 2 + (Y - y) ** 2) - 0.6) < 0.18, pick(st['straw'], 86))
        egg(g, x, y, z + 0.47, kind, s=0.9)
    elif k == 'B':
        g.cyl(x, y, z, z + 0.45, 0.95, col('#FFFFFF'))
        g.cyl(x, y, z + 0.15, z + 0.27, 1.0, col(eg['base'], 2.0))
        egg(g, x, y, z + 0.45, kind, s=0.9)
    else:
        g.cyl(x, y, z, z + 0.45, 0.95, pick(st['ped_c'], 87))
        g.fill((x - 1, y - 1, z + 0.45 - VOX), (x + 1, y + 1, z + 0.45),
               lambda X, Y, Z: np.abs(np.sqrt((X - x) ** 2 + (Y - y) ** 2) - 0.75) < 0.06, col(st['rune'][0], 3.0), only_filled=True)
        egg(g, x, y, z + 0.45, kind, s=0.9)


def hub(g, st, cx, cy, r, top=0.0):
    """the Golden Nest island inside the belt ring"""
    k = st['key']
    base = pick(st['hub_base'], 95)
    if k == 'B':
        stripes = [col(c) for c in st['hub_base']]
        g.cyl(cx, cy, top, top + 1.4, r, lambda X, Y, Z: np.where(np.mod(np.arctan2(Y - cy, X - cx) * 8 / math.pi, 2) < 1, stripes[0], stripes[1]))
    else:
        g.cyl(cx, cy, top, top + 1.4, r, base)
    g.cyl(cx, cy, top + 1.2, top + 1.5, r + 0.15, col(st['hub_trim']))
    # grass top
    g.cyl(cx, cy, top + 1.5, top + 1.7, r - 0.2, pick(st['grass'], 96))
    # nest: a torus of twigs
    nest = pick(st['nest'], 97)
    R2, rt = 2.6, 0.8

    def tor(X, Y, Z):
        d = np.sqrt((X - cx) ** 2 + (Y - cy) ** 2) - R2
        return d * d + (Z - (top + 2.3)) ** 2 <= (rt + 0.1 * snoise(X, Y, Z, 5, 9)) ** 2
    g.fill((cx - R2 - rt - .3, cy - R2 - rt - .3, top + 1.5), (cx + R2 + rt + .3, cy + R2 + rt + .3, top + 3.4), tor, nest)
    g.cyl(cx, cy, top + 1.5, top + 1.9, R2, nest)
    # golden egg
    gold = col(*st['gold'])
    R, H = 1.3, 3.4
    zc = top + 1.9 + H * 0.42

    def m(X, Y, Z):
        t = (Z - zc) / (np.where(Z > zc, H * 0.58, H * 0.42))
        rr = R * np.sqrt(np.clip(1 - t * t, 0, 1)) * np.where(Z > zc, 1 - 0.12 * t, 1)
        return (X - cx) ** 2 + (Y - cy) ** 2 <= rr * rr
    g.fill((cx - R, cy - R, top + 1.9), (cx + R, cy + R, top + 1.9 + H), m,
           lambda X, Y, Z: np.where(hnoise(X, Y, Z, 98) > 0.85, col('#FFF1B0', 2.5), gold))


# ------------------------------------------------------------------ rooms
def room(g, st, x0, y0, x1, y1, top=0.0, H=7.0, floor_h=0.6):
    """a floor shell corner: floor slab, back wall (y1) and right wall (x1)"""
    k = st['key']
    fz = top + floor_h
    T = 0.6
    # floor slab with planks/tiles
    g.box((x0, y0, top), (x1, y1, fz - 0.2), col(st['floor_seam']))
    if k == 'A':
        def fc(X, Y, Z):
            row = np.floor((Y - y0) / 0.6)
            off = (row * 1.37) % 2.4
            seam = (np.mod(Y - y0, 0.6) < VOX) | (np.mod(X - x0 + off, 2.4) < VOX)
            return np.where(seam, col(st['floor_seam']), pick(st['floor'], 101)(X, Y * 0 + row, Z * 0))
        g.box((x0, y0, fz - 0.2), (x1, y1, fz), fc)
    elif k == 'B':
        def fc(X, Y, Z):
            ch = (np.floor((X - x0) / 1.2) + np.floor((Y - y0) / 1.2)) % 2 == 0
            seam = (np.mod(X - x0, 1.2) < VOX) | (np.mod(Y - y0, 1.2) < VOX)
            return np.where(seam, col(st['floor_seam']), np.where(ch, col(st['floor'][0]), col(st['floor'][1])))
        g.box((x0, y0, fz - 0.2), (x1, y1, fz), fc)
    else:
        def fc(X, Y, Z):
            row = np.floor((Y - y0) / 1.0)
            xx = X - x0 + (row % 2) * 0.7
            seam = (np.mod(Y - y0, 1.0) < VOX) | (np.mod(xx, 1.4) < VOX)
            return np.where(seam, col(st['floor_seam']), pick(st['floor'], 102)(np.floor(xx / 1.4), row, Z * 0))
        g.box((x0, y0, fz - 0.2), (x1, y1, fz), fc)
    # slab edge trim
    g.box((x0, y0, top), (x1, y0 + 0.2, fz), col(st['trim']))
    g.box((x0, y0, top), (x0 + 0.2, y1, fz), col(st['trim']))

    # walls
    def wall_c(along):
        if k == 'A':
            wc = pick(st['wall'], 103)
            return lambda X, Y, Z: np.where(np.mod(along(X, Y), 0.8) < VOX, col(st['wall_seam']), wc(np.floor(along(X, Y) / 0.8), Y * 0, Z * 0 + 1))
        if k == 'B':
            wc = pick(st['wall'], 104)

            def c(X, Y, Z):
                a = np.mod(along(X, Y), 2.5)
                zz = np.mod(Z - fz, 3.4)
                frame = ((np.abs(a - 0.3) < 0.1) | (np.abs(a - 2.2) < 0.1)) & (zz > 0.4) & (zz < 3.0) | ((np.abs(zz - 0.4) < 0.1) | (np.abs(zz - 3.0) < 0.1)) & (a > 0.2) & (a < 2.3)
                return np.where(frame, col('#FFFFFF'), wc(X, Y, Z))
            return c
        stone = pick(st['stone'], 105)
        plaster = pick(st['wall'], 106)

        def c(X, Y, Z):
            row = np.floor((Z - fz) / 0.5)
            a = along(X, Y) + (row % 2) * 0.45
            st_ = np.where((np.mod(Z - fz, 0.5) < VOX) | (np.mod(a, 0.9) < VOX), col('#5E6676'), stone(np.floor(a / 0.9), row, Z * 0))
            return np.where(Z < fz + 2.5, st_, plaster(X, Y, Z))
        return c
    g.box((x0, y1 - T, fz), (x1, y1, fz + H), wall_c(lambda X, Y: X))
    g.box((x1 - T, y0, fz), (x1, y1, fz + H), wall_c(lambda X, Y: Y))
    trim = col(st['trim'])
    # top trim, corner post, base trim
    g.box((x0, y1 - T - 0.1, fz + H), (x1 + 0.1, y1 + 0.1, fz + H + 0.35), trim)
    g.box((x1 - T - 0.1, y0, fz + H), (x1 + 0.1, y1 + 0.1, fz + H + 0.35), trim)
    g.box((x0, y0, fz + H - 0.01), (x0 + 0.01, y0 + 0.01, fz + H), trim)
    g.box((x1 - T - 0.2, y1 - T - 0.2, fz), (x1 + 0.1, y1 + 0.1, fz + H + 0.35), trim)
    g.box((x0, y1 - T - 0.1, fz), (x1, y1 - T, fz + 0.3), trim)
    g.box((x1 - T - 0.1, y0, fz), (x1 - T, y1, fz + 0.3), trim)
    # wall open ends get a post
    g.box((x0, y1 - T - 0.1, fz), (x0 + 0.4, y1 + 0.1, fz + H + 0.35), trim)
    g.box((x1 - T - 0.1, y0, fz), (x1 + 0.1, y0 + 0.4, fz + H + 0.35), trim)
    if k == 'C':
        # timber frame on the plaster
        tb = col(st['timber'])
        g.box((x0, y1 - T - 0.08, fz + 2.5), (x1, y1 - T + 0.05, fz + 2.8), tb)
        g.box((x1 - T - 0.08, y0, fz + 2.5), (x1 - T + 0.05, y1, fz + 2.8), tb)
        for xx in np.arange(x0 + 2.0, x1 - 1, 3.0):
            g.box((xx, y1 - T - 0.08, fz + 2.5), (xx + 0.3, y1 - T + 0.05, fz + H), tb)
    if k == 'A':
        # white X-brace door shape on the back wall
        dx0, dx1 = x0 + 2.0, x0 + 6.0
        g.box((dx0, y1 - T - 0.1, fz), (dx1, y1 - T, fz + 4.6), trim)
        g.carve((dx0 + 0.3, y1 - T - 0.1, fz + 0.3), (dx1 - 0.3, y1 - T, fz + 4.3))
        L = math.hypot(dx1 - dx0 - 0.6, 4.0)

        def xb(X, Y, Z):
            u = (X - dx0 - 0.3) / (dx1 - dx0 - 0.6)
            v = (Z - fz - 0.3) / 4.0
            return (np.abs(u - v) < 0.07) | (np.abs(u + v - 1) < 0.07)
        g.fill((dx0 + 0.3, y1 - T - 0.1, fz + 0.3), (dx1 - 0.3, y1 - T, fz + 4.3), xb, trim)
    # window on the right wall
    wy0, wy1, wz0, wz1 = y0 + (y1 - y0) * 0.45, y0 + (y1 - y0) * 0.45 + 2.6, fz + 2.6, fz + 5.0
    if k == 'C':
        # arched window
        g.fill((x1 - T - 0.1, wy0 - 0.3, wz0 - 0.3), (x1, wy1 + 0.3, wz1 + 1.6),
               lambda X, Y, Z: (Z < wz1) | ((Y - (wy0 + wy1) / 2) ** 2 + (Z - wz1) ** 2 < ((wy1 - wy0) / 2 + 0.3) ** 2), trim)
        g.fill((x1 - T - 0.1, wy0, wz0), (x1, wy1, wz1 + 1.4),
               lambda X, Y, Z: (Z < wz1) | ((Y - (wy0 + wy1) / 2) ** 2 + (Z - wz1) ** 2 < ((wy1 - wy0) / 2) ** 2), col(*st['window']))
        g.fill((x1 - T - 0.15, wy0, wz0), (x1, wy1, wz1 + 1.4),
               lambda X, Y, Z: (np.abs(Y - (wy0 + wy1) / 2) < 0.08) | (np.abs(Z - (wz0 + 1.3)) < 0.08), col(st['lamp_frame']), only_filled=True)
    else:
        g.box((x1 - T - 0.15, wy0 - 0.3, wz0 - 0.3), (x1, wy1 + 0.3, wz1 + 0.3), trim)
        g.box((x1 - T - 0.15, wy0, wz0), (x1, wy1, wz1), col(*st['window']))
        g.box((x1 - T - 0.2, wy0, (wz0 + wz1) / 2 - 0.07), (x1, wy1, (wz0 + wz1) / 2 + 0.07), trim)
        g.box((x1 - T - 0.2, (wy0 + wy1) / 2 - 0.07, wz0), (x1, (wy0 + wy1) / 2 + 0.07, wz1), trim)
    # lanterns on the back wall
    for lx in (x0 + 8.0, x1 - 3.0):
        lantern(g, st, lx, y1 - T - 0.45, fz + 4.2)
    if k == 'B':
        # neon strip under the top trim
        g.box((x0 + 0.4, y1 - T - 0.15, fz + H - 0.4), (x1 - T - 0.2, y1 - T, fz + H - 0.25), col(*st['lamp']))
        g.box((x1 - T - 0.15, y0 + 0.4, fz + H - 0.4), (x1 - T, y1 - T - 0.2, fz + H - 0.25), col(*st['lamp']))
    return fz


def lantern(g, st, x, y, z):
    fr = col(st['lamp_frame'])
    lc = col(*st['lamp'])
    k = st['key']
    if k == 'B':
        g.ell((x, y, z), (0.45, 0.35, 0.45), lc)
        g.cyl(x, y, z + 0.35, z + 0.55, 0.3, fr)
        g.box((x - 0.1, y, z + 0.5), (x + 0.1, y + 0.45, z + 0.65), fr)
        return
    g.box((x - 0.1, y, z + 0.9), (x + 0.1, y + 0.45, z + 1.05), fr)  # bracket
    g.box((x - 0.35, y - 0.35, z - 0.5), (x + 0.35, y + 0.35, z - 0.4), fr)
    g.box((x - 0.35, y - 0.35, z + 0.4), (x + 0.35, y + 0.35, z + 0.5), fr)
    for dx in (-0.35, 0.25):
        for dy in (-0.35, 0.25):
            g.box((x + dx, y + dy, z - 0.5), (x + dx + 0.1, y + dy + 0.1, z + 0.5), fr)
    g.box((x - 0.25, y - 0.25, z - 0.4), (x + 0.25, y + 0.25, z + 0.4), lc)
    g.cyl(x, y, z + 0.5, z + 0.9, 0.35, fr, r1=0.05)


def cozy(g, st, x, y, z):
    k = st['key']
    if k == 'A':  # hay bale bed
        hay = pick(['#F2CE5C', '#E8BF48', '#F7DA75', '#DDB040'], 111)
        g.rrbox((x - 2.0, y - 1.5, z), (x + 2.0, y + 1.5, z + 1.5), 0.3, hay)
        for xx in (x - 1.2, x + 1.2):
            g.paint((xx - 0.12, y - 1.6, z), (xx + 0.12, y + 1.6, z + 1.6), None, col('#B5452F'))
        g.carve((x - 1.4, y - 0.9, z + 1.2), (x + 1.4, y + 0.9, z + 1.6))
    elif k == 'B':  # big round cushion
        g.cyl(x, y, z, z + 0.7, 1.8, col('#FF8FC6'))
        g.cyl(x, y, z + 0.7, z + 0.9, 1.5, col('#FFFFFF'))
        g.cyl(x, y, z + 0.2, z + 0.4, 1.85, col('#FFD23F'))
    else:  # moss bed with glow mushrooms
        g.blob((x, y, z), (2.0, 1.6, 0.8), pick(['#4E9A50', '#468F49', '#58A65A'], 112), amp=0.1, f=3, seed=4, only_empty=True)
        for dx, dy in ((-1.5, 1.0), (1.6, 0.9), (1.2, -1.1)):
            g.cyl(x + dx, y + dy, z, z + 0.6, 0.08, col('#E8E2D0'))
            g.ell((x + dx, y + dy, z + 0.6), (0.25, 0.25, 0.14), col(*st['glowshroom'] if 'glowshroom' in st else st['crystal']),
                  cond=lambda X, Y, Z, zz=z + 0.6: Z >= zz - 0.02)


def bush(g, st, x, y, top=0.0, r=1.2, seed=3):
    c = _two_tone(st, top, top + r * 1.4, seed)
    g.blob((x, y, top + r * 0.55), (r, r * 0.9, r * 0.75), c, amp=0.12, f=2.6, seed=seed)
    if st['tree'] == 'oak':
        _fruit(g, dict(st, fruit=('#FF6F91', 0.0)), x, y, top + r * 0.6, r * 0.95, 6, seed)
