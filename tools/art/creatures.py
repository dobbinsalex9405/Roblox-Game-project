"""All 33 Hatchery Heist creatures as voxel models, built from a few body
plans. Detail grows with rarity: Commons are small and simple (one or two
parts, a bob), Rares get moving ears, tails and wings, Ultra Rare and up get
glowing voxels, and Legendary and Godly creatures are huge, with many moving
parts. Heights are in voxels; the game draws one voxel as VOXEL studs."""
import math
from voxkit import Creature, hexc
import legends

VOXEL = 0.25  # studs per voxel in game
HEIGHT = {'Common': 8, 'Uncommon': 10, 'Rare': 13, 'Ultra Rare': 16, 'Epic': 20, 'Legendary': 34, 'Godly': 42}

INK, WHITE, BLUSH = hexc('#1B1B2F'), hexc('#FFFFFF'), hexc('#FF8FB1')


def eyes(c, head, x_off, z, size, y_shift=0):
    """Ink eyes with a white shine, cut into the head's front so they can blink."""
    e = c.part('eyes', 'blink', head.pivot)
    for sx in (-1, 1):
        for dx in range(size):
            for dz in range(size + (1 if size >= 2 else 0)):
                x = sx * (x_off + dx) if sx > 0 else -(x_off + dx) - 1
                f = head.front(x, z + dz)
                if f:
                    del head.v[f]
                    shine = size >= 2 and dz == size and dx == (0 if sx > 0 else 0)
                    e.put((f[0], f[1] + y_shift, f[2]), WHITE if shine else INK)


def blush(head, x_off, z):
    for sx in (-1, 1):
        x = x_off if sx > 0 else -x_off - 1
        f = head.front(x, z)
        if f:
            head.put(f, BLUSH)


# ---------------------------------------------------------------- body plans

def quadruped(c, H, col, belly=None, snout=None, ears='pointy', ear_col=None, tail='short', tail_col=None,
              mask=None, patches=None, horn=None, antlers=None, spines=None, mane=None, glow=None, wings=None,
              fluffy=False):
    k = H / 10.0
    detailed = c.rarity not in ('Common',)
    body = c.part('body')
    head = c.part('head', 'head' if detailed else 'static', (0, -1.6 * k, 4.6 * k))
    # legs
    # legs: the finer Blender build (detail > 1) gets sturdier legs, which
    # would round to one voxel otherwise; the in-game boxes keep theirs
    lw = max(1, round(0.9 * k * (1.4 if getattr(c, 'detail', 1) > 1 else 1)))
    for sx in (-1, 1):
        for ly in (-1.2 * k, 2.2 * k):
            x0 = round(sx * 1.3 * k) - (lw - 1 if sx < 0 else 0) - (1 if sx < 0 else 0)
            body.box((x0, round(ly), 0), (x0 + lw - 1, round(ly) + lw - 1, round(1.6 * k)), col)
    body.ell((0, 0.6 * k, 3.0 * k), (2.0 * k, 2.9 * k, 1.9 * k), col)
    if fluffy:
        body.ell((0, 0.6 * k, 3.2 * k), (2.4 * k, 3.0 * k, 2.1 * k), col)
    if belly:
        body.paint(lambda p, cc, g: (belly, False) if p[2] < 2.8 * k and abs(p[0] + .5) < 1.3 * k and p[1] < 2 * k else None)
    head.ell((0, -2.4 * k, 6.0 * k), (2.3 * k, 2.1 * k, 2.1 * k), col)
    if snout:
        head.ell((0, -4.3 * k, 5.2 * k), (1.1 * k, 0.9 * k, 0.8 * k), snout)
        f = head.front(0, round(5.6 * k)) or head.front(-1, round(5.6 * k))
        if f:
            head.put(f, INK)
            if k >= 1.2:
                head.put((f[0] - 1, f[1], f[2]), INK)
    if mask:  # bandit mask across the eyes
        head.paint(lambda p, cc, g: (mask, False) if abs(p[2] + .5 - 6.5 * k) <= 0.6 * k and p[1] < -3.0 * k else None)
    if patches:  # panda eye patches
        head.paint(lambda p, cc, g: (patches, False) if abs(p[2] + .5 - 6.4 * k) <= 0.7 * k and 0.4 * k <= abs(p[0] + .5) <= 1.6 * k and p[1] < -3.0 * k else None)
    es = max(1, round(0.55 * k))
    eyes(c, head, max(1, round(0.7 * k)), round(6.2 * k), es)
    if k >= 1:
        blush(head, round(1.5 * k), round(5.4 * k))
    # ears
    ec = ear_col or col
    earp = c.part('ears', 'ears' if c.rarity not in ('Common', 'Uncommon') else 'static', (0, -2.4 * k, 7.8 * k))
    for sx in (-1, 1):
        bx = sx * 1.2 * k
        if ears == 'pointy':
            for i in range(max(2, round(1.8 * k))):
                w = max(0, round((1.8 * k - i) * 0.35))
                earp.box((round(bx - w), round(-2.4 * k), round(7.6 * k) + i), (round(bx + w), round(-2.4 * k) + max(0, round(0.4 * k)), round(7.6 * k) + i), ec)
        elif ears == 'big':  # fennec
            for i in range(max(3, round(3.2 * k))):
                w = max(0, round((3.2 * k - i) * 0.4))
                earp.box((round(bx * 1.3 - w), round(-2.2 * k), round(7.4 * k) + i), (round(bx * 1.3 + w), round(-2.2 * k), round(7.4 * k) + i), ec)
        elif ears == 'round':
            earp.ell((bx * 1.15, -2.2 * k, 7.9 * k), (0.8 * k, 0.4 * k + .5, 0.8 * k), ec)
        elif ears == 'long':  # bunny
            earp.box((round(bx - 0.4 * k), round(-2.0 * k), round(7.6 * k)), (round(bx + 0.4 * k), round(-2.0 * k) + max(0, round(0.3 * k)), round(10.6 * k)), ec)
            earp.box((round(bx), round(-2.0 * k) - 1, round(8.0 * k)), (round(bx), round(-2.0 * k) - 1, round(10.0 * k)), BLUSH)
        elif ears == 'floppy':
            earp.box((round(bx * 1.7), round(-2.4 * k), round(5.0 * k)), (round(bx * 1.7) + (0 if k < 1.2 else 1), round(-1.8 * k), round(7.4 * k)), ec)
    # tail
    tc = tail_col or col
    tl = c.part('tail', 'tail' if c.rarity != 'Common' else 'static', (0, 3.4 * k, 3.4 * k))
    if tail == 'short':
        tl.ell((0, 3.6 * k, 3.6 * k), (0.6 * k, 0.6 * k, 0.6 * k), tc)
    elif tail == 'curly':
        for i, (yy, zz) in enumerate(((3.5, 3.8), (3.9, 4.4), (3.6, 4.9))):
            tl.ell((0, yy * k, zz * k), (0.4 * k, 0.4 * k, 0.4 * k), tc)
    elif tail == 'bushy':
        tl.ell((0, 4.2 * k, 4.6 * k), (1.0 * k, 1.3 * k, 1.9 * k), tc)
        tl.ell((0, 4.6 * k, 6.2 * k), (0.8 * k, 0.9 * k, 0.9 * k), tc)
    elif tail == 'fox':
        tl.ell((0, 4.4 * k, 3.8 * k), (0.9 * k, 1.8 * k, 0.9 * k), tc)
        tl.paint(lambda p, cc, g: (hexc('#FFFFFF'), False) if p[1] > 5.4 * k else None)
    elif tail == 'long':
        for i in range(max(3, round(3 * k))):
            tl.put((0, round(3.4 * k) + i, round(3.4 * k + 0.4 * i)), tc)
    elif tail == 'striped':
        tl.ell((0, 4.2 * k, 4.2 * k), (0.8 * k, 1.6 * k, 0.8 * k), tc)
        tl.paint(lambda p, cc, g: (INK, False) if int(p[1] / max(1, round(0.5 * k))) % 2 == 0 else None)
    elif tail == 'flame':
        tl.ell((0, 4.2 * k, 4.4 * k), (0.9 * k, 1.6 * k, 1.1 * k), tc)
        tl.paint(lambda p, cc, g: (hexc('#FFD43B'), True) if p[1] > 4.8 * k else None)
    if horn:  # unicorn
        hp = c.part('horn', 'glow', (0, -3.4 * k, 8.0 * k))
        for i in range(max(3, round(3 * k))):
            w = max(0, round((3 * k - i) * 0.12))
            hp.box((-w - 1 if w else -1, round(-3.6 * k) - w, round(7.8 * k) + i), (w, round(-3.6 * k) + w, round(7.8 * k) + i), horn, True)
    if antlers:
        ap = c.part('antlers', 'glow', (0, -2.2 * k, 8 * k))
        for sx in (-1, 1):
            x = round(sx * 1.3 * k)
            for i in range(round(3.5 * k)):
                ap.put((x + sx * (i // max(1, round(1.2 * k))), round(-2.2 * k), round(7.8 * k) + i), antlers, True)
            for b in range(3):
                bz = round(8.6 * k + b * 0.9 * k)
                for j in range(max(1, round(0.9 * k))):
                    ap.put((x + sx * (round(b * 0.8 * k) + j + 1), round(-2.2 * k), bz + j // 2), antlers, True)
    if spines:
        sp = c.part('spines', 'static')
        for p in list(body.v):
            if p[2] > 3.6 * k and (p[0] + p[1] + p[2]) % 2 == 0 and p[2] >= max(q[2] for q in body.v if q[0] == p[0] and q[1] == p[1]):
                sp.put((p[0], p[1], p[2] + 1), spines)
    if mane:
        mp = c.part('mane', 'glow' if glow else 'static')
        for z in range(round(4.2 * k), round(8.4 * k)):
            for x in (-1, 0):
                mp.put((x, round(-1.0 * k + (8.4 * k - z) * 0.3), z), mane, bool(glow))
    if wings:
        add_wings(c, k, wings, (0, 0.4 * k, 4.4 * k), span=2.6, glow_edge=glow)
    if glow:
        # glowing paws and a glowing tail tip
        body.paint(lambda p, cc, g: (glow, True) if p[2] == 0 else None)
    return c


def add_wings(c, k, colr, root, span=2.6, glow_edge=None, feather=None):
    for sx, name in ((-1, 'wingL'), (1, 'wingR')):
        w = c.part(name, name, (sx * 1.6 * k, root[1], root[2]))
        L = round(span * k)
        for i in range(L):
            x = round(sx * (1.8 * k + i))
            top = round(root[2] + 1.8 * k - i * 0.35)
            bot = round(root[2] - 0.4 * k + i * 0.5)
            for z in range(min(bot, top), top + 1):
                edge = glow_edge is not None and (z == top or i == L - 1)
                colz = glow_edge if edge else (feather if feather and (i + z) % 3 == 0 else colr)
                w.put((x if sx > 0 else x - 1, round(root[1]), z), colz, edge)
                if k >= 1.6:
                    w.put((x if sx > 0 else x - 1, round(root[1]) + 1, z), colz, edge)


def bird(c, H, col, belly=None, beak=hexc('#FFB627'), wing=None, crest=None, tail=None, glow=None, big_eyes=False,
         tuft=False, feet=hexc('#FF9F1C'), wing_span=1.4):
    k = H / 10.0
    body = c.part('body')
    head = c.part('head', 'head' if c.rarity != 'Common' else 'static', (0, -0.4 * k, 5.8 * k))
    body.ell((0, 0.6 * k, 3.4 * k), (2.6 * k, 2.4 * k, 2.9 * k), col)
    if belly:
        body.paint(lambda p, cc, g: (belly, False) if p[1] < -0.6 * k and abs(p[0] + .5) < 1.6 * k and p[2] < 4.6 * k else None)
    head.ell((0, -0.6 * k, 6.8 * k), (2.2 * k, 2.1 * k, 2.0 * k), col)
    # beak
    bw = max(1, round(0.5 * k))
    head.box((-bw, round(-3.2 * k) - max(1, round(0.6 * k)), round(6.0 * k)), (bw - 1, round(-3.0 * k), round(6.0 * k) + max(0, round(0.5 * k))), beak)
    es = max(1, round((0.75 if big_eyes else 0.5) * k))
    eyes(c, head, max(1, round(0.7 * k)), round(6.9 * k), es)
    if k >= 1:
        blush(head, round(1.5 * k), round(6.0 * k))
    for sx in (-1, 1):
        x = round(sx * 1.0 * k) - (1 if sx < 0 else 0)
        body.box((x - (max(1, round(0.3 * k)) - 1 if sx < 0 else 0), round(-0.8 * k), 0), (x + (max(1, round(0.3 * k)) - 1 if sx > 0 else 0), round(-0.2 * k), round(0.7 * k)), feet)
    wc = wing or col
    if c.rarity in ('Common', 'Uncommon'):
        for sx in (-1, 1):
            body.ell((sx * 2.4 * k, 0.8 * k, 3.6 * k), (0.5 * k + .3, 1.4 * k, 1.4 * k), wc)
    else:
        add_wings(c, k, wc, (0, 0.8 * k, 4.2 * k), span=wing_span, glow_edge=glow)
    if crest:
        cp = c.part('crest', 'glow' if glow else 'static')
        for i in range(max(2, round(1.6 * k))):
            cp.put((0 if i % 2 else -1, round(-0.8 * k + i * 0.5 * k), round(8.6 * k) + i // 2), crest, bool(glow))
    if tuft:
        for sx in (-1, 1):
            head.box((round(sx * 1.4 * k) - (1 if sx < 0 else 0), round(-0.6 * k), round(8.6 * k)), (round(sx * 1.4 * k) - (1 if sx < 0 else 0), round(-0.6 * k), round(9.2 * k)), crest or col)
    if tail:
        tp = c.part('tail', 'tail', (0, 3.0 * k, 3.4 * k))
        for i in range(max(2, round(2.4 * k))):
            for x in range(-max(1, round(0.8 * k)) + (i // 2), max(1, round(0.8 * k)) - (i // 2)):
                g = glow is not None and i >= round(1.2 * k)
                tp.put((x, round(3.0 * k) + i, round(3.6 * k) + i // 2), (glow if g else tail), g)
    return c


def blob(c, H, kind, col, accent, glow=None):
    """Small round creatures: frog, snail, ladybug, axolotl, turtle."""
    k = H / 10.0
    body = c.part('body')
    head = c.part('head', 'head' if c.rarity != 'Common' else 'static', (0, -2.0 * k, 3.6 * k))
    if kind == 'frog':
        body.ell((0, 0.4 * k, 2.4 * k), (3.0 * k, 2.6 * k, 2.2 * k), col)
        body.paint(lambda p, cc, g: (accent, False) if p[1] < -1.2 * k and p[2] < 2.6 * k else None)
        head.ell((0, -1.0 * k, 4.4 * k), (2.8 * k, 2.0 * k, 1.6 * k), col)
        for sx in (-1, 1):
            head.ell((sx * 1.5 * k, -1.4 * k, 5.9 * k), (0.9 * k, 0.9 * k, 0.9 * k), col)
        eyes(c, head, max(1, round(1.0 * k)), round(5.8 * k), max(1, round(0.6 * k)))
        f = head.front(0, round(3.6 * k))
        if f:
            for x in range(-round(1.0 * k), round(1.0 * k)):
                g = head.front(x, round(3.6 * k))
                if g:
                    head.put(g, INK)
    elif kind == 'snail':
        body.ell((0, -0.5 * k, 1.0 * k), (1.4 * k, 4.0 * k, 1.0 * k), col)
        shell = c.part('shell', 'static')
        shell.ell((0, 1.2 * k, 3.6 * k), (1.6 * k, 2.6 * k, 2.6 * k), accent)
        shell.paint(lambda p, cc, g: (hexc('#B9862A'), False) if int(math.hypot(p[1] - 1.2 * k, p[2] - 3.6 * k) / max(1, 0.7 * k)) % 2 == 0 else None)
        head.ell((0, -3.6 * k, 2.4 * k), (1.2 * k, 1.0 * k, 1.4 * k), col)
        for sx in (-1, 1):
            x = round(sx * 0.7 * k) - (1 if sx < 0 else 0)
            head.box((x, round(-3.8 * k), round(3.6 * k)), (x, round(-3.8 * k), round(5.0 * k)), col)
            head.put((x, round(-3.8 * k), round(5.0 * k) + 1), INK)
        eyes(c, head, max(1, round(0.4 * k)), round(2.6 * k), 1)
    elif kind == 'ladybug':
        body.ell((0, 0.4 * k, 1.8 * k), (2.8 * k, 3.2 * k, 1.9 * k), accent)
        body.paint(lambda p, cc, g: (INK, False) if (abs(p[0] + .5) < 0.6 or ((p[0] * 3 + p[1] * 5) % 7 == 0 and p[2] > 1.8 * k)) else None)
        head.ell((0, -2.6 * k, 1.6 * k), (1.6 * k, 1.2 * k, 1.3 * k), INK)
        eyes(c, head, max(1, round(0.5 * k)), round(1.8 * k), 1)
        for p in [q for q in c.part('eyes').v]:
            c.part('eyes').v[p] = (WHITE, False)
        for sx in (-1, 1):
            x = round(sx * 0.6 * k) - (1 if sx < 0 else 0)
            head.put((x, round(-3.0 * k), round(3.2 * k)), INK)
            head.put((x + sx, round(-3.2 * k), round(3.8 * k)), INK)
    elif kind == 'axolotl':
        body.ell((0, 0.8 * k, 2.2 * k), (1.8 * k, 3.4 * k, 1.6 * k), col)
        head.ell((0, -2.4 * k, 3.4 * k), (2.4 * k, 1.8 * k, 1.8 * k), col)
        gills = c.part('gills', 'glow')
        for sx in (-1, 1):
            for i in range(3):
                for j in range(max(2, round(1.4 * k))):
                    gills.put((round(sx * (2.4 * k + j * 0.6)) - (1 if sx < 0 else 0), round(-2.0 * k), round(3.0 * k + i * 1.0 * k + j * 0.4)), accent, True)
        eyes(c, head, max(1, round(1.0 * k)), round(3.8 * k), max(1, round(0.4 * k)))
        tl = c.part('tail', 'tail', (0, 3.6 * k, 2.2 * k))
        tl.ell((0, 5.0 * k, 2.4 * k), (0.5 * k, 2.0 * k, 1.2 * k), col)
        tl.paint(lambda p, cc, g: (accent, True) if p[2] >= 3.2 * k else None)
        for sx in (-1, 1):
            for ly in (-1.0 * k, 2.4 * k):
                body.box((round(sx * 1.6 * k) - (1 if sx < 0 else 0), round(ly), 0), (round(sx * 1.6 * k) - (1 if sx < 0 else 0), round(ly), round(0.8 * k)), col)
        blush(head, round(1.6 * k), round(3.0 * k))
    elif kind == 'turtle':
        shell = c.part('shell', 'static')
        shell.ell((0, 0.6 * k, 2.6 * k), (2.8 * k, 3.2 * k, 2.0 * k), accent, cond=lambda x, y, z: z >= round(1.2 * k))
        shell.paint(lambda p, cc, g: (hexc('#2F7A3A'), False) if (p[0] + p[1]) % 4 == 0 else None)
        body.ell((0, 0.6 * k, 1.4 * k), (2.6 * k, 3.0 * k, 0.8 * k), col)
        head.ell((0, -3.4 * k, 2.6 * k), (1.3 * k, 1.2 * k, 1.2 * k), col)
        eyes(c, head, max(1, round(0.5 * k)), round(2.8 * k), max(1, round(0.4 * k)))
        for sx in (-1, 1):
            for ly in (-1.4 * k, 2.6 * k):
                body.box((round(sx * 2.0 * k) - (1 if sx < 0 else 0), round(ly), 0), (round(sx * 2.0 * k) - (1 if sx < 0 else 0) + (1 if k > 1 else 0) * sx, round(ly) + 1, round(0.9 * k)), col)
    return c


def dragon(c, H, col, belly, wing, glow, horn, griffin=False):
    k = H / 10.0
    if griffin:
        quadruped(c, H, col, belly=belly, snout=None, ears='pointy', ear_col=col, tail='long', tail_col=col, glow=glow)
        head = c.part('head')
        # eagle head: white, gold beak
        head.paint(lambda p, cc, g: (belly, False) if p[2] > 4.6 * k else None)
        bw = max(1, round(0.6 * k))
        head.box((-bw, round(-4.8 * k), round(5.2 * k)), (bw - 1, round(-4.2 * k), round(6.0 * k)), hexc('#FFB627'))
        head.box((-max(1, bw - 1), round(-5.2 * k), round(5.0 * k)), (max(1, bw - 1) - 1, round(-4.9 * k), round(5.4 * k)), hexc('#FFB627'))
        add_wings(c, k, wing, (0, 0.6 * k, 4.6 * k), span=4.2, glow_edge=glow, feather=hexc('#FFFFFF'))
        # lightning stripes
        c.part('body').paint(lambda p, cc, g: (glow, True) if (p[1] * 2 + p[2]) % max(3, round(2.2 * k)) == 0 and abs(p[0]) >= round(1.6 * k) else None)
    else:
        quadruped(c, H, col, belly=belly, snout=col, ears='pointy', ear_col=horn, tail='long', tail_col=col, glow=None)
        add_wings(c, k, wing, (0, 0.6 * k, 4.6 * k), span=3.0, glow_edge=glow)
        sp = c.part('spines', 'glow')
        for y in range(round(-0.4 * k), round(4.5 * k), max(1, round(0.7 * k))):
            top = max((p[2] for p in c.part('body').v if p[1] == y and p[0] in (0, -1)), default=None)
            if top is not None:
                sp.put((0, y, top + 1), glow, True)
                sp.put((-1, y, top + 1), glow, True)
        hp = c.part('horns', 'glow')
        for sx in (-1, 1):
            x = round(sx * 1.0 * k) - (1 if sx < 0 else 0)
            for i in range(max(2, round(1.6 * k))):
                hp.put((x, round(-1.6 * k) + i // 2, round(7.8 * k) + i), horn, i >= round(1.0 * k))
    return c


def serpent(c, H, col, belly, glow):
    k = H / 10.0
    body = c.part('body')
    # an S coil rising from the ground
    pts = []
    for i in range(40):
        t = i / 39
        pts.append((math.sin(t * math.pi * 2.2) * 2.2 * k, math.cos(t * math.pi * 1.6) * 2.4 * k, 1.2 * k + t * 5.6 * k, (1.3 - 0.5 * t) * k))
    for x, y, z, r in pts:
        body.ell((x, y, z), (r, r, r), col)
    body.paint(lambda p, cc, g: (glow, True) if (p[0] * 7 + p[1] * 3 + p[2] * 5) % 23 == 0 else None)
    body.paint(lambda p, cc, g: (belly, False) if p[1] < -1.6 * k and cc == col else None)
    head = c.part('head', 'head', (0, -1.0 * k, 7.6 * k))
    head.ell((0, -1.6 * k, 8.4 * k), (1.9 * k, 2.2 * k, 1.6 * k), col)
    head.ell((0, -3.4 * k, 8.0 * k), (1.2 * k, 1.2 * k, 0.9 * k), col)
    eyes(c, head, max(1, round(0.7 * k)), round(8.8 * k), max(1, round(0.4 * k)))
    for p in list(c.part('eyes').v):
        c.part('eyes').v[p] = (glow, True)
    hp = c.part('horns', 'glow')
    for sx in (-1, 1):
        x = round(sx * 1.2 * k) - (1 if sx < 0 else 0)
        for i in range(round(2.2 * k)):
            hp.put((x + (sx * (i // 4)), round(-0.6 * k) + i // 2, round(9.6 * k) + i), glow, True)
    fins = c.part('crest', 'glow')
    for x, y, z, r in pts[::3]:
        fins.put((round(x), round(y), round(z + r)), glow, True)
        fins.put((round(x), round(y), round(z + r) + 1), glow, True)
    return c


def goose(c, H):
    gold, goldD = hexc('#FFC21A'), hexc('#E59A1A')
    bird(c, H, hexc('#FFF8E7'), belly=hexc('#FFFFFF'), beak=hexc('#FF9F1C'), wing=hexc('#FFF1C9'),
         crest=None, tail=hexc('#FFF1C9'), glow=gold, wing_span=4.4)
    k = H / 10.0
    head = c.part('head')
    # long neck: the head sits higher
    head.v = {(x, y, z + round(1.6 * k)): v for (x, y, z), v in head.v.items()}
    c.part('eyes').v = {(x, y, z + round(1.6 * k)): v for (x, y, z), v in c.part('eyes').v.items()}
    c.part('body').ell((0, -0.4 * k, 6.4 * k), (1.0 * k, 1.0 * k, 1.8 * k), hexc('#FFF8E7'))
    crown = c.part('crown', 'glow')
    for x in range(-round(1.2 * k), round(1.2 * k)):
        for y in range(-round(1.6 * k), round(0.4 * k)):
            if abs(x + .5) >= 1.0 * k - 1 or y in (-round(1.6 * k), round(0.4 * k) - 1):
                crown.put((x, y, round(10.6 * k)), gold, True)
                if (x + y) % 2 == 0:
                    crown.put((x, y, round(10.6 * k) + 1), gold, True)
    crown.put((0, -round(1.6 * k), round(10.6 * k) + 2), hexc('#FF4D5E'), True)
    # golden egg it guards
    egg = c.part('egg', 'glow')
    egg.ell((0, -4.0 * k, 1.2 * k), (1.0 * k, 1.0 * k, 1.3 * k), gold, True)
    return c


# ------------------------------------------------------------------ roster

def P(h):
    return hexc(h)


ROSTER = [
    # Common
    ('Chick', 'Common', lambda c, H: bird(c, H, P('#FFD93B'), belly=P('#FFE97A'))),
    ('Duckling', 'Common', lambda c, H: bird(c, H, P('#FFF06A'), beak=P('#FF8C1A'), belly=P('#FFF6A8'))),
    ('Bunny', 'Common', lambda c, H: quadruped(c, H, P('#F4F1EC'), belly=P('#FFFFFF'), snout=P('#FFFFFF'), ears='long', tail='short', tail_col=P('#FFFFFF'))),
    ('Piglet', 'Common', lambda c, H: quadruped(c, H, P('#FFB3C7'), snout=P('#FF8FB1'), ears='pointy', tail='curly')),
    ('Mouse', 'Common', lambda c, H: quadruped(c, H, P('#B8B8C8'), belly=P('#E6E6EE'), snout=P('#E6E6EE'), ears='round', ear_col=P('#FFB3C7'), tail='long', tail_col=P('#FFB3C7'))),
    ('Hamster', 'Common', lambda c, H: quadruped(c, H, P('#F2B05E'), belly=P('#FFF1DC'), snout=P('#FFF1DC'), ears='round', tail='short', fluffy=True)),
    ('Frog', 'Common', lambda c, H: blob(c, H, 'frog', P('#6CCB5F'), P('#C8F2A8'))),
    ('Snail', 'Common', lambda c, H: blob(c, H, 'snail', P('#CFE8A8'), P('#E9B949'))),
    ('Lamb', 'Common', lambda c, H: quadruped(c, H, P('#FFFDF5'), snout=P('#3A3A4A'), ears='floppy', ear_col=P('#3A3A4A'), tail='short', fluffy=True)),
    ('Ladybug', 'Common', lambda c, H: blob(c, H, 'ladybug', P('#1B1B2F'), P('#FF4D5E'))),
    # Uncommon
    ('Gosling', 'Uncommon', lambda c, H: bird(c, H, P('#D8D2B0'), belly=P('#F1EBD0'), beak=P('#3A3A4A'))),
    ('Turtle', 'Uncommon', lambda c, H: blob(c, H, 'turtle', P('#9BD36A'), P('#4FA84A'))),
    ('FoxKit', 'Uncommon', lambda c, H: quadruped(c, H, P('#FF8A3D'), belly=P('#FFF1DC'), snout=P('#FFF1DC'), ears='pointy', ear_col=P('#3A2A2A'), tail='fox')),
    ('Hedgehog', 'Uncommon', lambda c, H: quadruped(c, H, P('#E8C9A0'), snout=P('#F6E3C8'), ears='round', tail='short', spines=P('#7A5230'))),
    ('Squirrel', 'Uncommon', lambda c, H: quadruped(c, H, P('#C9763A'), belly=P('#FFE3BF'), snout=P('#FFE3BF'), ears='pointy', tail='bushy')),
    ('Puppy', 'Uncommon', lambda c, H: quadruped(c, H, P('#E3B27A'), belly=P('#FFF1DC'), snout=P('#FFF1DC'), ears='floppy', ear_col=P('#8A5A33'), tail='short')),
    ('Kitten', 'Uncommon', lambda c, H: quadruped(c, H, P('#9AA3B5'), belly=P('#FFFFFF'), snout=P('#FFFFFF'), ears='pointy', ear_col=P('#FFB3C7'), tail='striped', tail_col=P('#9AA3B5'))),
    # Rare
    ('Raccoon', 'Rare', lambda c, H: quadruped(c, H, P('#9A9AA8'), belly=P('#D8D8E0'), snout=P('#F0F0F4'), ears='pointy', ear_col=P('#3A3A4A'), tail='striped', mask=P('#2A2A3A'))),
    ('Penguin', 'Rare', lambda c, H: bird(c, H, P('#2A2F45'), belly=P('#FFFFFF'), beak=P('#FFB627'), wing=P('#1F2335'))),
    ('Owlet', 'Rare', lambda c, H: bird(c, H, P('#B07A4A'), belly=P('#F2D49B'), beak=P('#FFB627'), wing=P('#8A5A33'), big_eyes=True, tuft=True, crest=P('#8A5A33'))),
    ('Fennec', 'Rare', lambda c, H: quadruped(c, H, P('#F2CC8F'), belly=P('#FFF6E3'), snout=P('#FFF6E3'), ears='big', ear_col=P('#F2CC8F'), tail='fox', tail_col=P('#F2CC8F'))),
    ('PandaCub', 'Rare', lambda c, H: quadruped(c, H, P('#FFFFFF'), snout=P('#FFFFFF'), ears='round', ear_col=P('#1B1B2F'), tail='short', patches=P('#1B1B2F'), fluffy=True)),
    # Ultra Rare
    ('EmberFox', 'Ultra Rare', lambda c, H: quadruped(c, H, P('#E8452C'), belly=P('#FFD6A0'), snout=P('#FFD6A0'), ears='pointy', ear_col=P('#7A1E14'), tail='flame', tail_col=P('#FF7A1A'), glow=P('#FFB627'))),
    ('FrostWolf', 'Ultra Rare', lambda c, H: quadruped(c, H, P('#D6ECFF'), belly=P('#FFFFFF'), snout=P('#FFFFFF'), ears='pointy', ear_col=P('#9CC9F2'), tail='bushy', tail_col=P('#9CC9F2'), mane=P('#7FDBFF'), glow=P('#7FDBFF'))),
    ('Axolotl', 'Ultra Rare', lambda c, H: blob(c, H, 'axolotl', P('#FFB3D1'), P('#FF4FA3'))),
    ('StormHawk', 'Ultra Rare', lambda c, H: bird(c, H, P('#4A5A8A'), belly=P('#DCE6FF'), beak=P('#FFD43B'), wing=P('#33406A'), crest=P('#7FDBFF'), tail=P('#33406A'), glow=P('#7FDBFF'), wing_span=2.6)),
    # Epic
    ('Dragonling', 'Epic', lambda c, H: dragon(c, H, P('#2EC4B6'), P('#FFE8B0'), P('#FF6B6B'), P('#FFB627'), P('#FFE8B0'))),
    ('CrystalStag', 'Epic', lambda c, H: quadruped(c, H, P('#B9A3FF'), belly=P('#F1EBFF'), snout=P('#F1EBFF'), ears='pointy', tail='short', antlers=P('#7FF2FF'), glow=P('#7FF2FF'))),
    ('MoonUnicorn', 'Epic', lambda c, H: quadruped(c, H, P('#F7F3FF'), belly=P('#FFFFFF'), snout=P('#FFE3F1'), ears='pointy', tail='bushy', tail_col=P('#C9A3FF'), horn=P('#FFD43B'), mane=P('#C9A3FF'), glow=P('#E3C9FF'))),
    # Legendary
    ('Phoenix', 'Legendary', legends.phoenix),
    ('ThunderGriffin', 'Legendary', legends.thunder_griffin),
    # Godly
    ('GoldenGoose', 'Godly', legends.golden_goose),
    ('NebulaSerpent', 'Godly', legends.nebula_serpent),
]


def build_all(detail=None):
    """Every creature in the ROSTER. `detail` (rarity -> multiplier, default
    1) builds a tier with more, smaller voxels at the same size in studs: the
    Blender meshes use it (tools/art/blender), the in-game boxes do not.
    Each creature's `voxel` is its studs per voxel."""
    out = []
    for species, rarity, fn in ROSTER:
        c = Creature(species, rarity)
        mult = (detail or {}).get(rarity, 1)
        c.detail = mult
        fn(c, HEIGHT[rarity] * mult)
        c.voxel = VOXEL / mult
        # A voxel belongs to one part only: the later, more specific part
        # (head over body, ears over head) keeps it, so no two parts draw the
        # same spot and flicker against each other.
        for i, part in enumerate(c.parts):
            for later in c.parts[i + 1:]:
                for v in set(part.v) & set(later.v):
                    del part.v[v]
        c.parts = [p for p in c.parts if p.v]
        out.append(c)
    return out
