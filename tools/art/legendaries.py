"""The Legendary batch from the master creature sheet (approved by Alex,
Nov 5): 48 hand-built Legendaries, each a prize at one in thousands.

Each starts from a body plan (kit_myth.py for beasts, drakes, dinos, sea
creatures, serpents and upright creatures; creatures.py and kit.py for
birds, bugs and blobs) and is then finished by hand with its showpiece from
the sheet: the mammoth's ice tusks, the lighthouse on the Sky Whale, the
Treasure Dragon's coin pile. Every one glows somewhere (emissive accents),
hovers in the game (rig.FLYING_TIERS) and keeps the moving parts the game
animates (legs, wings, fins, tail, head, ears, eyes); floating props are
their own `orbit` part, turning slowly about the creature.

Same art frame as the other kits: x right, y back (front is -y), z up, in
voxels; k = H / 10. ROSTER is added to creatures.ROSTER; ELEMENT holds the
sheet's element for each."""
import math

from voxkit import hexc
import kit_myth as km
from kit_myth import mix, dark, light, mx, curve, sweep, top_of, horn, rod

INK, WHITE = hexc('#1B1B2F'), hexc('#FFFFFF')
P = hexc

GOLD, GOLD_D, GOLD_L = P('#FFC21A'), P('#D98A10'), P('#FFE27A')
FIRE = (P('#C81E1E'), P('#FF6A1A'), P('#FFC21A'), P('#FFF6B0'))  # deep to white-hot
ICE, ICE_L, ICE_D = P('#9FE7FF'), P('#E6FBFF'), P('#5FB8E8')
BOLT, BOLT_HOT = P('#4FD8FF'), P('#E8FCFF')
LEAF, LEAF_D, BLOSSOM = P('#5CC85A'), P('#2E8A3E'), P('#FFB3D1')


# ------------------------------------------------------------------ helpers

def plan(name, c, H, cols, **opts):
    """Draw a kit_myth plan; cols are '#RRGGBB' strings or rgb tuples."""
    cc = {key: (P(v) if isinstance(v, str) else v) for key, v in cols.items()}
    return km.BUILDERS[name](c, H, cc, opts)


def part_or_none(c, name):
    return next((p for p in c.parts if p.name == name), None)


def drop(c, *names):
    c.parts = [p for p in c.parts if p.name not in names]


def flame(part, x, y, z, h, k, cols=FIRE, w=0.5):
    """A flame tongue standing on (x, y, z), h voxels tall, glowing."""
    n = max(3, round(h))
    for i in range(n):
        s = i / n
        r = max(0.6, w * k * (1 - s) ** 0.8)
        col = cols[min(len(cols) - 1, int(s * len(cols)))]
        wob = math.sin(s * math.pi * 1.5) * 0.25 * k
        part.ell((x + wob, y + wob * 0.5, z + i), (r, r, 0.6), col, True)


def crystal(part, x, y, z, h, r, col, tip=None, lean=(0.0, 0.0), glow=True):
    """A pointed crystal prism from (x, y, z) up h, leaning by (dx, dy)."""
    n = max(2, round(h))
    for i in range(n):
        s = i / n
        rr = max(0.55, r * (1 - max(0.0, s - 0.55) / 0.45))
        cl = tip if tip is not None and s > 0.6 else col
        part.ell((x + lean[0] * i, y + lean[1] * i, z + i), (rr, rr, 0.6), cl, glow)


def bolt(part, a, b, col, glow=True, zig=1.2, r=0.6):
    """A zig-zag lightning bolt from a to b."""
    n = max(3, round(math.dist(a, b) / 2.2))
    pts = [a]
    for i in range(1, n):
        t = i / n
        side = zig if i % 2 else -zig
        pts.append((a[0] + (b[0] - a[0]) * t + side, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t))
    pts.append(b)
    for p, q in zip(pts, pts[1:]):
        rod(part, p, q, r, col, glow)


def flower(part, x, y, z, k, petal=BLOSSOM, heart=GOLD, glow=False, up=True):
    """A five-petal blossom (petals round a gold heart) lying on a surface."""
    r = max(1, round(0.35 * k))
    for a in range(5):
        ang = a / 5 * math.pi * 2
        px, py = x + math.cos(ang) * r, y + math.sin(ang) * r
        part.ell((px, py, z), (max(0.6, 0.28 * k), max(0.6, 0.28 * k), 0.6), petal)
    part.ell((x, y, z + (1 if up else 0)), (0.6, 0.6, 0.6), heart, glow)


def star(part, x, y, z, s, col, glow=True, plane='xz'):
    """A small plus-shaped star (arm length s)."""
    x, y, z = round(x), round(y), round(z)
    part.put((x, y, z), col, glow)
    for i in range(1, s + 1):
        if plane == 'xz':
            for p in ((x + i, y, z), (x - i, y, z), (x, y, z + i), (x, y, z - i)):
                part.put(p, col, glow)
        else:
            for p in ((x + i, y, z), (x - i, y, z), (x, y + i, z), (x, y - i, z)):
                part.put(p, col, glow)


def ring(part, cx, cy, cz, R, col, glow=True, thick=0.7, axis='z', tilt=0.0, gaps=0):
    """A torus: around the z axis (flat) or the y axis (facing front)."""
    n = max(24, round(R * 7))
    for i in range(n):
        if gaps and (i * gaps // n) % 2 == 1 and False:
            continue
        a = i / n * math.pi * 2
        if axis == 'z':
            p = (cx + math.cos(a) * R, cy + math.sin(a) * R, cz + math.sin(a) * R * tilt)
        else:
            p = (cx + math.cos(a) * R, cy, cz + math.sin(a) * R)
        part.ell(p, (thick, thick, thick), col, glow)


def speckle(part, cols_from, col, every, glow=False, zmin=None):
    """Repaints a scatter of voxels (a stable hash picks them)."""
    def f(p, cc, g):
        if cc not in cols_from or (zmin is not None and p[2] < zmin):
            return None
        h = (p[0] * 73856093) ^ (p[1] * 19349663) ^ (p[2] * 83492791)
        return (col, glow) if (h >> 4) % every == 0 else None
    part.paint(f)


def cracks(part, cols_from, col, k, glow=True, scale=1.0):
    """Glowing seams: lines where two jittered rock cells meet (a Voronoi
    pattern), so lava runs in clean veins between plates."""
    s = max(5, round(2.4 * k * scale))

    def seed(i, j, l):
        h = (i * 92837111) ^ (j * 689287499) ^ (l * 283923481)
        return tuple((n + 0.15 + ((h >> sh) % 70) / 100.0) * s for n, sh in ((i, 3), (j, 11), (l, 19)))

    def f(p, cc, g):
        if cc not in cols_from:
            return None
        x, y, z = (p[0] + 0.5, p[1] + 0.5, p[2] + 0.5)
        ci, cj, cl = int(x // s), int(y // s), int(z // s)
        ds = sorted((sx - x) ** 2 + (sy - y) ** 2 + (sz - z) ** 2
                    for i in (ci - 1, ci, ci + 1) for j in (cj - 1, cj, cj + 1) for l in (cl - 1, cl, cl + 1)
                    for (sx, sy, sz) in (seed(i, j, l),))
        return (col, glow) if ds[1] ** 0.5 - ds[0] ** 0.5 < 0.65 else None
    part.paint(f)


def tidy(c, keep=8):
    """Drops stray bits: pieces of a non-orbit part that touch nothing else
    of the creature (face to face) and are at most `keep` voxels. Plans
    round small details to a voxel or two that can come loose."""
    from collections import deque
    solid = {}
    for p in c.parts:
        if p.anim != 'orbit':
            for v in p.v:
                solid[v] = p
    left = set(solid)
    pieces = []
    while left:
        s0 = left.pop()
        comp, q = [s0], deque([s0])
        while q:
            x, y, z = q.popleft()
            for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
                m = (x + d[0], y + d[1], z + d[2])
                if m in left:
                    left.remove(m)
                    q.append(m)
                    comp.append(m)
        pieces.append(comp)
    pieces.sort(key=len, reverse=True)
    for comp in pieces[1:]:
        if len(comp) <= keep:
            for v in comp:
                for p in c.parts:
                    if p.anim != 'orbit':
                        p.v.pop(v, None)
    c.parts = [p for p in c.parts if p.v]
    return c


def orbit_part(c, name, centre):
    """A floating prop that turns slowly about the creature (anim orbit)."""
    return c.part(name, 'orbit', centre)


def body_top(c, y, x=0):
    b = part_or_none(c, 'body')
    return top_of(b, x, y) if b else None


def bounds_of(part):
    xs = [p[0] for p in part.v]
    ys = [p[1] for p in part.v]
    zs = [p[2] for p in part.v]
    return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def feather_wings(c, k, root, length, rise, cols, tip, edge=None, glow=True):
    drop(c, 'wingL', 'wingR')
    km.wing_feather(c, k, root, length, rise, cols, tip, edge=edge, thick=2, glow_tip=glow)


def grand_bird(c, H, col, belly, beak, wing, wing_cols, tip, crest=None, feet=P('#FF9F1C'), big_eyes=True, tuft=False,
               edge=None, length=5.0, rise=2.4):
    """A Legendary bird: the bird plan's round body and face, grand raised
    feathered wings instead of the small ones, legs it stands on."""
    import creatures as cr
    cr.bird(c, H, col, belly=belly, beak=beak, wing=wing, crest=None, tail=None, glow=None, big_eyes=big_eyes,
            tuft=False, feet=feet, wing_span=1.6)
    k = H / 10.0
    lift = max(2, round(0.6 * k))
    feather_wings(c, k, (2.3 * k, 0.8 * k, round(5.2 * k) + lift), length, rise, wing_cols, tip, edge=edge)
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    mid_y = (y0 + y1) / 2
    if tuft:  # owl ear tufts: two tapering feather horns from the crown
        hp = c.part('tufts', 'static', head.pivot)
        top = top_of(head, round(1.2 * k), round(mid_y)) or z1
        horn(hp, (1.2 * k, mid_y, top - 0.5), (1.9 * k, mid_y + 0.5 * k, top + 1.3 * k), 0.45 * k, col, light(col, 0.4))
    if crest is not None:  # a swept crest of three feathers on the crown
        cp = c.part('crest', 'static', head.pivot)
        top = top_of(head, 0, round(mid_y)) or z1
        for i, dx in enumerate((-0.4, 0.0, 0.4)):
            horn(cp, (dx * k, mid_y - 0.3 * k, top - 0.5), (dx * 1.6 * k, mid_y + 1.6 * k, top + (1.6 if i == 1 else 1.1) * k), 0.35 * k,
                 crest, light(crest, 0.5), bend=(0, 0, 0.4 * k), both=False)
    return k, lift


# ------------------------------------------------------- Ember (fire) set

def lava_drake(c, H):
    plan('drake', c, H, {'col': '#2A2230', 'belly': '#4A3A44', 'accent': '#3A2E3A', 'glow': '#FF7A1A', 'horn': '#5A4A55',
                         'wing': '#3A2A30'}, kind='drake', wings='bat', horns='swept')
    k = H / 10.0
    for name in ('body', 'tail', 'head', 'wingL', 'wingR', 'legFL', 'legFR', 'legBL', 'legBR'):
        p = part_or_none(c, name)
        if p:
            cracks(p, (P('#2A2230'), P('#4A3A44'), P('#3A2230'), dark(P('#2A2230'), 0.2)), FIRE[1], k, scale=0.9)
    # a glowing magma belly and molten tail tip
    c.part('body').paint(lambda p, cc, g: (FIRE[1], True) if cc == P('#4A3A44') and p[2] % 3 == 0 else None)
    tail = c.part('tail')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(tail)
    tip = c.part('tailflame', 'glow')
    for dx in (-0.6 * k, 0, 0.6 * k):
        flame(tip, dx, y1 - 0.5 * k, z1 - 0.6 * k, 1.8 * k, k, w=0.35)
    return c


def sun_scarab(c, H):
    import kit
    kit.bug(c, H, 'beetle', GOLD, P('#8A5A10'), None)
    k = H / 10.0
    shell = part_or_none(c, 'shell')
    if shell:
        shell.paint(lambda p, cc, g: (GOLD_L, False) if cc == GOLD and p[2] > max(q[2] for q in shell.v) - 0.5 * k else None)
        speckle(shell, (GOLD,), GOLD_D, 9)
        # a sun-disc emblem on the back
        top = max(q[2] for q in shell.v)
        shell.paint(lambda p, cc, g: (FIRE[2], True) if p[2] >= top - 2 and (p[0] + .5) ** 2 + (p[1] - 0.8 * k) ** 2 < (0.7 * k) ** 2 else None)
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    hn = c.part('beetlehorn', 'static', head.pivot)
    f = head.front(0, z1 - round(0.3 * k)) or (0, y0, z1)
    horn(hn, (0.0, f[1] + 0.5, f[2]), (0.0, f[1] - 1.0 * k, f[2] + 1.2 * k), 0.4 * k, GOLD_D, GOLD_L, bend=(0, -0.2 * k, 0.3 * k), both=False)
    # the small sun it rolls, out in front
    sun = c.part('sun', 'glow', (0, -4.8 * k, 1.6 * k))
    sun.ell((0, -5.2 * k, 1.7 * k), (1.7 * k, 1.7 * k, 1.7 * k), FIRE[2], True)
    sun.paint(lambda p, cc, g: (FIRE[3], True) if p[1] < -5.8 * k and p[2] > 2.0 * k else None)
    sun.paint(lambda p, cc, g: (FIRE[1], True) if (p[0] * 3 + p[2] * 5 + p[1]) % 9 == 0 else None)
    for a in range(8):
        ang = a / 8 * math.pi * 2
        x, z = math.cos(ang) * 2.1 * k, 1.7 * k + math.sin(ang) * 2.1 * k
        if z > 0.3 * k:
            sun.ell((x, -5.2 * k, z), (0.45 * k, 0.45 * k, 0.45 * k), FIRE[1], True)
    return c


def cerberus_pup(c, H):
    plan('beast', c, H, {'col': '#3A3340', 'belly': '#5A5060', 'snout': '#5A5060', 'accent': '#2A2430', 'glow': '#FF7A1A',
                         'eye': '#FF5A1A'}, kind='canine', heads=3, tail='whip')
    k = H / 10.0
    # an ember collar with studs round the neck
    col = c.part('collar', 'glow', (0, -2.6 * k, 5.2 * k))
    body = c.part('body')
    bz = 2.9 * k + 0.9 * k
    for a in range(40):
        ang = a / 40 * math.pi * 2
        x, z = math.cos(ang) * 1.45 * k, bz + 1.4 * k + math.sin(ang) * 1.3 * k
        colr = FIRE[2] if a % 5 == 0 else FIRE[1]
        col.ell((x, -2.7 * k, z), (0.5, 0.9, 0.5), colr, True)
    # flame tip on the tail
    tail = c.part('tail')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(tail)
    tf = c.part('tailflame', 'glow')
    flame(tf, -0.5, y1 - 0.5 * k, z0 - 0.4 * k, 1.6 * k, k, w=0.4)
    # glowing paw pads
    for name in ('legFL', 'legFR', 'legBL', 'legBR'):
        lp = part_or_none(c, name)
        if lp:
            lp.paint(lambda p, cc, g: (FIRE[1], True) if p[2] == 0 else None)
    return c


def magma_golem(c, H):
    plan('upright', c, H, {'col': '#3A3438', 'belly': '#4A4248', 'glow': '#FF7A1A', 'eye': '#FFB627'}, kind='golem')
    k = H / 10.0
    rock = (P('#3A3438'), P('#4A4248'), dark(P('#3A3438'), 0.12), dark(P('#3A3438'), 0.35))
    for p in c.parts:
        if p.name not in ('eyes',):
            cracks(p, rock, FIRE[1], k, scale=0.8)
    # a glowing core in the chest and lava dripping from the arms
    body = c.part('body')
    body.paint(lambda p, cc, g: (FIRE[2], True) if p[1] < -1.5 * k and (p[0] + .5) ** 2 + (p[2] - 5.8 * k) ** 2 < (0.8 * k) ** 2 else None)
    drips = c.part('drips', 'glow')
    for side in (1, -1):
        x = side * 2.9 * k
        for i in range(round(1.4 * k)):
            drips.ell((x - (0.5 if side < 0 else 0), -0.4 * k, 2.0 * k - i), (0.5, 0.5, 0.6), FIRE[1] if i < 0.8 * k else FIRE[2], True)
    # rocky shoulder spikes
    sp = c.part('spikes', 'static')
    for side in (1, -1):
        horn(sp, (side * 2.0 * k, 0.4 * k, 6.6 * k), (side * 2.8 * k, 0.6 * k, 8.0 * k), 0.6 * k, rock[0], FIRE[2], glow=True, both=False)
    return c


def blaze_rhino(c, H):
    plan('beast', c, H, {'col': '#8A7A80', 'belly': '#A89AA0', 'snout': '#A89AA0', 'horn': '#E8D8C8', 'glow': '#FF8A1A',
                         'accent': '#5A4A55'}, kind='heavy', horns='rhino', tail='whip')
    k = H / 10.0
    # armour plates over the back and shoulders
    body = c.part('body')
    plates = c.part('armour', 'static')
    for (yy, w) in ((-1.6, 2.0), (0.2, 2.2), (2.0, 2.0)):
        for x in range(-round(w * k), round(w * k)):
            for dy in range(round(1.0 * k)):
                y = round(yy * k) + dy
                t = top_of(body, x, y)
                if t is not None and t > 4.0 * k:
                    plates.put((x, y, t + 1), P('#5A4A55'))
                    if dy == 0:
                        plates.put((x, y, t + 2), FIRE[1], True)
    # the flaming horn
    hp = c.part('horns')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(hp)
    fl = c.part('hornflame', 'glow')
    flame(fl, 0, y0 + 0.4 * k, z1 + 1, 2.0 * k, k, w=0.5)
    return c


def golden_sphinx(c, H):
    plan('beast', c, H, {'col': '#F2C14E', 'belly': '#FFE3A0', 'snout': '#FFE3A0', 'accent': '#E8A21A', 'glow': '#4FD8FF',
                         'wing': '#FFE8B0'}, kind='cat', tail='lion', wings='feather')
    k = H / 10.0
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    hy, hz = (y0 + y1) / 2, (z0 + z1) / 2
    # the striped nemes headdress, falling to the shoulders, with a jewel
    nemes = c.part('headdress', 'static', (0, hy, z1))
    blue = P('#2E5AC8')
    for z in range(round(hz - 1.8 * k), z1 + 2):
        for x in range(x0 - 1, x1 + 2):
            for y in range(round(hy - 0.2 * k), y1 + 2):
                inside = ((x + .5) / (1.0 + (x1 - x0) / 2)) ** 2 + ((y - hy - 0.4 * k) / (1.1 * k + (y1 - y0) / 2)) ** 2
                if inside <= 1 and (x, y, z) not in head.v:
                    shell = inside > 0.7 or z > z1
                    if shell:
                        nemes.put((x, y, z), blue if (z // max(2, round(0.45 * k))) % 2 else GOLD)
    f = head.front(0, z1 - round(0.4 * k)) or head.front(-1, z1 - round(0.4 * k))
    if f:
        nemes.ell((0, f[1] - 0.2 * k, f[2]), (0.45 * k, 0.5 * k, 0.5 * k), P('#FF3B5C'), True)
    # hieroglyph glow along the flanks
    body = c.part('body')
    body.paint(lambda p, cc, g: (BOLT, True) if abs(p[0] + .5) > 1.5 * k and cc in (P('#F2C14E'),) and
               ((p[1] // 2) % 3 == 0) and (p[2] // 2) % 2 == 0 and (p[1] + p[2]) % 3 == 0 else None)
    return c


def ember_manta(c, H):
    plan('ray', c, H, {'col': '#8A1E1E', 'belly': '#FFB36A', 'glow': '#FFC21A', 'eye': INK}, kind='manta')
    k = H / 10.0 * 1.5
    for name in ('finL', 'finR'):
        f = c.part(name)
        f.paint(lambda p, cc, g: (FIRE[1], True) if not g and cc == P('#8A1E1E') and (p[0] * 2 + p[1]) % 5 == 0 else None)
    # the fire trail: a flame-lit tail
    tail = c.part('tail')
    tail.paint(lambda p, cc, g: (FIRE[1 + (p[1] % 3 == 0)], True))
    (x0, y0, z0), (x1, y1, z1) = bounds_of(tail)
    tf = c.part('trail', 'glow')
    for i in range(3):
        y = y1 - round(i * 0.8 * k)
        t = top_of(tail, 0, y)
        if t is not None:
            flame(tf, 0, y, t + 1, (1.4 - i * 0.3) * k, k, w=0.4)
    return c


def phoenix_placeholder(c, H):  # pragma: no cover - Phoenix is in legends.py
    return c


# ----------------------------------------------------- Glacial (ice) set

def glacier_mammoth(c, H):
    fur, furD = P('#8A6A55'), P('#6A4E3E')
    plan('beast', c, H, {'col': '#8A6A55', 'belly': '#A88A70', 'snout': '#7A5E4A', 'horn': '#BFF4FF', 'glow': '#7FE6FF'},
         kind='heavy', tusks=True, tail='short')
    k = H / 10.0
    for name in ('body', 'head', 'legFL', 'legFR', 'legBL', 'legBR'):
        p = part_or_none(c, name)
        if p:
            speckle(p, (fur,), furD, 5)
    # shaggy fur fringe hanging under the body
    body = c.part('body')
    fringe = c.part('fringe', 'static')
    zb = min(p[2] for p in body.v)
    for (x, y, z) in list(body.v):
        if z == zb + 1 and (x + y) % 2 == 0:
            for i in range(round(0.5 * k)):
                fringe.put((x, y, z - 1 - i), furD)
    # a cap of snow on the back
    body.paint(lambda p, cc, g: (P('#F4FBFF'), False) if p[2] >= max(q[2] for q in body.v if q[0] == p[0] and q[1] == p[1]) - 1 and p[2] > 4.6 * k else None)
    # the trunk, curling down and up at the tip
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    trunk = c.part('trunk', 'static', (0, y0, z0))
    pts = []
    for i in range(20):
        s = i / 19
        pts.append((0, y0 + 0.4 * k - s * 1.0 * k - math.sin(s * math.pi) * 0.4 * k, z0 + 1.0 * k - s * 2.8 * k + s ** 4 * 1.4 * k,
                    max(0.8, 0.62 * k * (1 - 0.45 * s))))
    sweep(trunk, pts, lambda s: fur if s < 0.85 else furD)
    # ice tusks glow at the tips, and frost crystals on the snowy back
    tusks = c.part('tusks')
    tusks.anim = 'glow'
    tusks.paint(lambda p, cc, g: (P('#7FE6FF'), True) if p[1] < y0 - 1.6 * k else None)
    cr = c.part('frost', 'glow')
    for (x, y) in ((0.9, -0.8), (-1.1, 0.6), (0.6, 1.8), (-0.3, -1.6)):
        t = top_of(body, round(x * k), round(y * k))
        if t is not None:
            crystal(cr, round(x * k), round(y * k), t + 1, 1.3 * k, 0.4 * k, ICE, ICE_L)
    return c


def glacier_orca(c, H):
    plan('whale', c, H, {'col': '#3A6A9A', 'belly': '#E6FBFF', 'glow': '#9FE7FF'}, kind='orca')
    k = H / 10.0 * 1.1
    for p in c.parts:
        p.paint(lambda q, cc, g: (P('#C8F2FF'), False) if cc == WHITE else None)
        speckle(p, (P('#3A6A9A'),), P('#5A8ABA'), 6)
    # an ice spout from the blowhole: a fountain of crystals
    body = c.part('body')
    ys = [p[1] for p in body.v]
    y = round(min(ys) + (max(ys) - min(ys)) * 0.25)
    # sit the spout on the highest body voxel near the blowhole
    near = [q for q in body.v if abs(q[1] - y) <= 1 and -1 <= q[0] <= 0]
    x, y, t = max(near, key=lambda q: q[2]) if near else (0, y, round(5 * k))
    spout = c.part('spout', 'glow', (x, y, t))
    for i in range(round(1.8 * k) + 1):
        spout.box((x - 1, y - 1, t + i), (x, y, t + i), ICE_L, True)
    top = t + round(1.8 * k)
    for a in range(6):
        ang = a / 6 * math.pi * 2
        crystal(spout, x, y, top - 1, 1.1 * k, 0.4 * k, ICE, ICE_L, lean=(math.cos(ang) * 0.7, math.sin(ang) * 0.7))
    # icy fin edges
    for name in ('dorsal', 'finL', 'finR'):
        p = part_or_none(c, name)
        if p:
            (x0, y0, z0), (x1, y1, z1) = bounds_of(p)
            p.paint(lambda q, cc, g: (ICE, True) if q[2] == (z1 if name == 'dorsal' else z0) else None)
    return c


def blizzard_owl(c, H):
    snow, grey = P('#F4FBFF'), P('#C8D6E8')
    k, lift = grand_bird(c, H, snow, P('#FFFFFF'), P('#3A3A4A'), snow, (snow, P('#E6F2FF'), P('#C8E8FF')), ICE,
                         feet=P('#E6EEF8'), tuft=True, crest=None)
    for p in c.parts:
        speckle(p, (snow,), grey, 13)
    c.part('eyes').paint(lambda p, cc, g: (P('#FFC21A'), True) if cc == INK else None)
    # a swirling blizzard ring round it, with snowflakes
    sw = orbit_part(c, 'blizzard', (0, 0.6 * k, 4.6 * k + lift))
    ring(sw, 0, 0.6 * k, 3.6 * k + lift, 4.4 * k, ICE_L, True, thick=0.6, tilt=0.18)
    for a in range(6):
        ang = a / 6 * math.pi * 2
        star(sw, math.cos(ang) * 4.4 * k, 0.6 * k + math.sin(ang) * 4.4 * k, 3.6 * k + lift + math.sin(ang) * 4.4 * k * 0.18 + 1,
             max(1, round(0.3 * k)), ICE, True, plane='xy')
    return c


def frost_giant(c, H):
    plan('upright', c, H, {'col': '#E6F2FF', 'belly': '#FFFFFF', 'glow': '#7FE6FF', 'eye': '#2E5AC8'}, kind='giant')
    k = H / 10.0
    body = c.part('body')
    # ice armour: plates on the chest and shoulders
    armour = c.part('armour', 'static')
    for (x, y, z) in list(body.v):
        if y < -1.2 * k and 4.2 * k < z < 6.8 * k and (x + 100) % 3 != 0 and abs(x + .5) < 1.8 * k:
            armour.put((x, y - 1, z), ICE if z % 2 else ICE_D)
    for side in (1, -1):
        armour.ell((side * 2.2 * k - (0.5 if side < 0 else 0), 0, 7.2 * k), (1.0 * k, 1.1 * k, 0.6 * k), ICE_D)
    # the icicle beard
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    beard = c.part('beard', 'glow', (0, y0, z0))
    for x in range(round(-0.9 * k), round(0.9 * k)):
        f = head.front(x, z0 + 1)
        if f:
            n = round((1.6 - abs(x + .5) / k * 0.9) * k)
            for i in range(max(1, n)):
                beard.put((f[0], f[1] - 1, f[2] - i), ICE_L if i < n - 1 else ICE, True)
    # an ice crown of spikes
    cr = c.part('icecrown', 'glow')
    for a in range(5):
        x = (a - 2) * 0.55 * k
        crystal(cr, x, (y0 + y1) / 2, z1 + 1, (1.0 + 0.5 * (a == 2)) * k, 0.3 * k, ICE, ICE_L)
    return c


def frost_saber(c, H):
    plan('beast', c, H, {'col': '#F4FBFF', 'belly': '#FFFFFF', 'snout': '#FFFFFF', 'accent': '#7FB8E8', 'horn': '#BFF4FF',
                         'glow': '#7FE6FF', 'eye': '#2E5AC8'}, kind='cat', tail='lion', saber=True, stripes=True)
    k = H / 10.0
    fangs = c.part('fangs')
    fangs.anim = 'glow'
    fangs.paint(lambda p, cc, g: (ICE, True))
    # frost spikes along the spine
    body = c.part('body')
    sp = c.part('frost', 'glow')
    for y in range(round(-1.4 * k), round(3.2 * k), max(2, round(0.9 * k))):
        t = top_of(body, 0, y)
        if t is not None:
            crystal(sp, -0.5, y, t + 1, 0.9 * k, 0.3 * k, ICE, ICE_L, lean=(0, 0.25))
    return c


def shard(part, start, d, length, r, col, tip, glow=True):
    """A crystal shard from `start` along direction d: a fat base tapering
    to a bright point, drawn in half-voxel steps so it stays one piece."""
    n = max(2, round(length * 2))
    dl = math.sqrt(sum(q * q for q in d)) or 1.0
    ux, uy, uz = (q / dl for q in d)
    for i in range(n + 1):
        s = i / n
        rr = max(0.55, r * (1 - s ** 1.4))
        at = (start[0] + ux * length * s, start[1] + uy * length * s, start[2] + uz * length * s)
        part.ell(at, (rr, rr, rr), tip if s > 0.55 else col, glow)


def crystal_triceratops(c, H):
    plan('dino', c, H, {'col': '#7F8FD8', 'belly': '#C8D2F2', 'accent': '#4F5FB8', 'horn': '#7FD6FF', 'glow': '#9FE7FF'},
         kind='trike')
    k = H / 10.0
    # the frill: a deep-blue plate rimmed with a crown of glowing crystal shards
    frill = c.part('frill')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(frill)
    deep, mid = P('#3F4FA8'), P('#6A5FD8')
    frill.paint(lambda p, cc, g: ((mid if (p[0] * 3 + p[2] * 5) % 11 < 3 else deep), False))
    cx, cz, R = (x0 + x1 + 1) / 2.0, z0, (x1 - x0 + 1) / 2.0
    ys = sorted(p[1] for p in frill.v)
    yb = ys[len(ys) // 2]
    for i, a in enumerate((0.2, 0.55, 0.95, 1.3, 1.5708, 1.84, 2.19, 2.59, 2.94)):
        big = i % 2 == 0
        st = (cx + math.cos(a) * (R - 1.2), yb + 0.5, cz + math.sin(a) * (R - 1.2))
        shard(frill, st, (math.cos(a), 0.35, math.sin(a)), (1.5 if big else 1.0) * k,
              (0.55 if big else 0.42) * k, P('#2FA8F0') if big else P('#8A5AF0'), P('#7FE0FF'))
    # crystal horns: icy blue running to a white-hot tip
    hp = c.part('horns')
    (hx0, hy0, hz0), (hx1, hy1, hz1) = bounds_of(hp)
    hp.paint(lambda p, cc, g: ((P('#7FE0FF'), True) if p[2] >= hz1 - 1 or p[1] <= hy0 + 1 else (P('#8FD0F8'), False)))
    # crystal clusters on the back
    body = c.part('body')
    cr = c.part('crystals', 'glow')
    for (x, y, h) in ((0.6, -0.6, 1.4), (-0.9, 0.8, 1.2), (0.4, 2.0, 1.0), (-0.3, 0.2, 1.6)):
        t = top_of(body, round(x * k), round(y * k))
        if t is not None:
            crystal(cr, round(x * k), round(y * k), t, h * k, 0.38 * k, P('#8A5AF0') if x < 0 else P('#2FA8F0'), P('#7FE0FF'),
                    lean=(x * 0.15, 0.1))
    return c


def frost_wyvern(c, H):
    plan('drake', c, H, {'col': '#BFE6FF', 'belly': '#F4FBFF', 'accent': '#7FB8E8', 'glow': '#9FE7FF', 'horn': '#E6FBFF',
                         'wing': '#9FD8F8'}, kind='wyvern', wings='bat', horns='swept')
    k = H / 10.0
    # icicles hanging from the wings' lower edge
    for name in ('wingL', 'wingR'):
        w = c.part(name)
        lows = {}
        for (x, y, z) in w.v:
            if (x, y) not in lows or z < lows[(x, y)]:
                lows[(x, y)] = z
        for (x, y), z in lows.items():
            if x % 3 == 0 and y == min(yy for (xx, yy) in lows if xx == x):
                n = 1 + (abs(x) * 7) % max(2, round(0.9 * k))
                for i in range(n):
                    w.put((x, y, z - 1 - i), ICE_L, True)
    # frost breath: a glowing mouth and a puff of crystals before it
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    br = c.part('breath', 'glow', (0, y0, z0))
    mz = z0 + round(0.6 * k)
    f = head.front(0, mz) or (0, y0, mz)
    for i in range(round(1.4 * k)):
        r = 0.3 * k + i * 0.25
        br.ell((0, f[1] - i, mz + 0.5), (r, 0.8, r), ICE_L if i % 2 else ICE, True)
    return c


# ---------------------------------------------------- Nature (green) set

def verdant_wyrm(c, H):
    plan('serpent', c, H, {'col': '#4FA84A', 'belly': '#C8E8A0', 'accent': '#2E8A3E', 'glow': '#B8FF6A'}, kind='wyrm')
    k = H / 10.0
    body = c.part('body')
    speckle(body, (P('#4FA84A'),), P('#6CC85F'), 4)  # moss
    # flowers all along the spine, in place of the plain spine fins
    sp = c.part('spines')
    pts = sorted(sp.v)
    sp.v = {}
    fl = c.part('flowers', 'glow')
    seen = set()
    for (x, y, z) in pts:
        key = (x // max(2, round(0.9 * k)), y // max(2, round(0.9 * k)))
        if key in seen:
            continue
        seen.add(key)
        petal = (BLOSSOM, P('#FFE14D'), P('#C9A3FF'))[len(seen) % 3]
        flower(fl, x, y, z + 1, k * 0.9, petal=petal, heart=GOLD, glow=True)
    sp.v = {}
    # leafy horns
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    lv = c.part('leaves', 'static', ((x0 + x1) / 2, (y0 + y1) / 2, z1))
    cx = (x0 + x1 + 1) / 2
    for side in (1, -1):
        bx = cx + side * 0.6 * k
        by = (y0 + y1) / 2 + 0.3 * k
        t = top_of(head, math.floor(bx), math.floor(by)) or z1
        # a leaf: a stem rising back from the crown with a blade either side
        horn(lv, (bx, by, t - 0.5), (bx + side * 1.0 * k, by + 1.6 * k, t + 1.6 * k), 0.5 * k, LEAF, LEAF_D, both=False)
    return c


def blossom_qilin(c, H):
    plan('beast', c, H, {'col': '#F2D8B8', 'belly': '#FFF1DC', 'snout': '#FFF1DC', 'accent': '#FF9BC8', 'horn': '#FFE27A',
                         'glow': '#FFD43B'}, kind='hoof', horns='qilin', mane='crest', tail='bushy')
    k = H / 10.0
    body = c.part('body')
    # golden scales on the back
    body.paint(lambda p, cc, g: (GOLD if (p[0] + p[1] * 2 + p[2]) % 3 == 0 else P('#E8B860'), False) if cc == P('#F2D8B8') and p[2] > 4.8 * k else None)
    # the cherry-blossom mane and tail: blossoms over the pink crest
    for name in ('mane', 'tail'):
        m = part_or_none(c, name)
        if not m:
            continue
        pts = list(m.v)
        for i, (x, y, z) in enumerate(pts):
            if i % 23 == 0:
                flower(m, x, y, z + 1, k * 0.7, petal=P('#FFD6E8'), heart=GOLD, glow=False)
    # falling petals: a few drifting by its legs (on a slow orbit ring)
    pe = orbit_part(c, 'petals', (0, 0.4 * k, 4 * k))
    ring(pe, 0, 0.4 * k, 6.4 * k, 3.6 * k, P('#FFD6E8'), True, thick=0.5, tilt=0.25)
    for a in range(5):
        ang = a / 5 * math.pi * 2
        flower(pe, math.cos(ang) * 3.6 * k, 0.4 * k + math.sin(ang) * 3.6 * k, 6.4 * k + math.sin(ang) * 3.6 * k * 0.25, k * 0.6,
               petal=BLOSSOM, glow=True)
    return c


def elder_treant(c, H):
    bark, barkD = P('#7A5232'), P('#5A3A22')
    plan('upright', c, H, {'col': '#7A5232', 'belly': '#9A6E46', 'glow': '#B8FF6A', 'eye': '#2A1A10'}, kind='treant')
    k = H / 10.0
    for p in c.parts:
        if p.name != 'eyes':
            p.paint(lambda q, cc, g: (barkD, False) if cc in (bark,) and (q[0] * 3 + q[2]) % 5 == 0 else None)
    # a leafy crown with branches, and a bird's nest with a little bird
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    crown = c.part('canopy', 'static', (0, 0, z1))
    for side in (1, -1):
        rod(crown, (side * 0.6 * k, 0, z1), (side * 2.0 * k, 0.2 * k, z1 + 1.6 * k), 0.45 * k, bark)
    crown.ell((0, 0.2 * k, z1 + 2.2 * k), (2.8 * k, 2.2 * k, 1.5 * k), LEAF)
    crown.paint(lambda p, cc, g: (LEAF_D, False) if (p[0] + p[1] + p[2]) % 4 == 0 else None)
    speckle(crown, (LEAF,), BLOSSOM, 17)
    nest = c.part('nest', 'static')
    nz = z1 + 3.4 * k
    for a in range(30):
        ang = a / 30 * math.pi * 2
        nest.ell((1.2 * k + math.cos(ang) * 0.8 * k, 0.4 * k + math.sin(ang) * 0.8 * k, nz), (0.6, 0.6, 0.7), P('#B8874A'))
    nest.ell((1.2 * k, 0.4 * k, nz - 0.3 * k), (0.8 * k, 0.8 * k, 0.4 * k), P('#9A6E3A'))
    bird = c.part('nestbird', 'static')
    bird.ell((1.2 * k, 0.4 * k, nz + 0.7 * k), (0.55 * k, 0.55 * k, 0.55 * k), P('#6AB8FF'))
    bf = bird.front(math.floor(1.2 * k), math.floor(nz + 0.7 * k))
    if bf:
        bird.put((bf[0], bf[1] - 1, bf[2]), P('#FFB627'))
        bird.put((bf[0], bf[1], bf[2] + 1), INK) if (bf[0], bf[1], bf[2] + 1) in bird.v else None
    # glowing moss and mushrooms at its feet
    for name in ('legL', 'legR'):
        lp = part_or_none(c, name)
        if lp:
            lp.paint(lambda q, cc, g: (P('#B8FF6A'), True) if q[2] < 0.6 * k and (q[0] + q[1]) % 3 == 0 else None)
    return c


def mushroom_king(c, H):
    plan('upright', c, H, {'col': '#E84855', 'belly': '#FFF1DC', 'accent': '#FFFFFF', 'glow': '#FFE14D'}, kind='mushroom',
         hat='crown')
    k = H / 10.0
    cap = c.part('cap')
    cap.paint(lambda p, cc, g: (P('#FFF6B0'), True) if cc == WHITE and (p[0] + p[1]) % 5 == 0 else None)
    # the royal cape: purple velvet with an ermine trim, hanging behind
    body = c.part('body')
    cape = c.part('cape', 'static')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(body)
    back = {}
    for (x, y, z) in body.v:
        back[(x, z)] = max(back.get((x, z), y), y)
    for z in range(round(1.4 * k), z1 - 1):
        s = (z1 - z) / (z1 - 1.4 * k)
        w = round(1.3 * k + s * 0.9 * k)
        ys = [back[(x, zz)] for (x, zz) in back if zz == z]
        for x in range(-w, w):
            y = (back.get((x, z)) or (max(ys) if ys else y1)) + 1 + round(s * 0.5 * k)
            trim = z < 1.4 * k + 2 or abs(x + .5) > w - 1.5
            for dy in range(round(s * 0.5 * k) + 1):  # it hangs down from the shoulders, touching the back
                cape.put((x, y - dy, z), (WHITE if (x + z) % 4 else INK) if trim else P('#7A2EC8'))
    # spore sparkles: little glowing puffs on the cap's rim
    sp = c.part('spores', 'glow')
    (cx0, cy0, cz0), (cx1, cy1, cz1) = bounds_of(cap)
    for a in range(10):
        ang = a / 10 * math.pi * 2
        star(sp, math.cos(ang) * 2.9 * k, math.sin(ang) * 2.7 * k, cz0 - 1, 1, P('#FFF6B0'), True, plane='xy')
    return c


def sylvan_elk(c, H):
    plan('beast', c, H, {'col': '#9A6E46', 'belly': '#E8D2B0', 'snout': '#E8D2B0', 'accent': '#7A5232', 'horn': '#6A4A2A',
                         'glow': '#E8FF6A'}, kind='hoof', horns='antlers', tail='short', mane='ruff')
    k = H / 10.0
    ant = c.part('horns')
    # leaves along the antlers and fireflies glowing at their tips
    pts = list(ant.v)
    for i, (x, y, z) in enumerate(pts):
        if i % 9 == 0:
            ant.put((x + (1 if x >= 0 else -1), y, z), LEAF)
            ant.put((x, y - 1, z), LEAF_D)
    ant.paint(lambda p, cc, g: (P('#E8FF6A'), True) if g else None)
    ff = orbit_part(c, 'fireflies', (0, -3.3 * k, 9 * k))
    ring(ff, 0, -2.8 * k, 9.4 * k, 2.6 * k, P('#E8FF6A'), True, thick=0.45, tilt=0.3)
    for a in range(7):
        ang = a / 7 * math.pi * 2
        ff.ell((math.cos(ang) * 2.6 * k, -2.8 * k + math.sin(ang) * 2.6 * k, 9.4 * k + math.sin(ang) * 2.6 * k * 0.3),
               (0.4 * k, 0.4 * k, 0.4 * k), P('#F4FF9A'), True)
    # white spots on the back like a fawn's, and a mossy ruff
    body = c.part('body')
    speckle(body, (P('#9A6E46'),), P('#F4E6CC'), 21, zmin=round(5.0 * k))
    m = c.part('mane')
    speckle(m, (P('#7A5232'),), LEAF, 3)
    return c


def lotus_koi(c, H):
    plan('fish', c, H, {'col': '#FFFFFF', 'belly': '#FFF6F0', 'accent': '#FF6A3D', 'glow': '#FFB3D1'}, kind='koi')
    k = H / 10.0 * 1.4
    body = c.part('body')
    speckle(body, (WHITE,), P('#FFD6E8'), 11)
    # it floats over a lotus: a pink flower on a lily pad beneath its belly
    zb = min(p[2] for parts in c.parts for p in parts.v)
    lot = c.part('lotus', 'glow', (0, 0, 0))
    lot.ell((0, 0.2 * k, 0.5), (2.6 * k, 2.6 * k, 0.6), P('#4FA84A'))
    lot.paint(lambda p, cc, g: (P('#2E8A3E'), False) if p[0] == 0 and p[1] > 0.2 * k else None)
    for ring_i, (r, h, col) in enumerate(((1.5, 0.9, P('#FFB3D1')), (1.0, 1.3, P('#FF8FBF')), (0.5, 1.5, P('#FFE14D')))):
        for a in range(8 if ring_i < 2 else 1):
            ang = a / 8 * math.pi * 2 + ring_i * 0.4
            px, py = math.cos(ang) * r * k, 0.2 * k + math.sin(ang) * r * k
            crystal(lot, px, py, 1, h * k, 0.38 * k, col, light(col, 0.4), lean=(math.cos(ang) * 0.15, math.sin(ang) * 0.15),
                    glow=ring_i == 2)
    # a stem joins the lotus to the fish's belly so nothing floats loose
    for z in range(1, zb + 1):
        lot.put((0, round(0.2 * k), z), P('#2E8A3E'))
        lot.put((-1, round(0.2 * k), z), P('#2E8A3E'))
    return c


def mantis_queen(c, H):
    import kit_pond
    kit_pond.critter(c, H, 'mantis', P('#FFC8E0'), P('#FF8FBF'), P('#FFE6F2'))
    k = H / 10.0
    # orchid petals on the legs and a crown of petals
    for p in c.parts:
        if p.name.startswith('leg'):
            p.paint(lambda q, cc, g: (P('#FFE6F2'), False) if q[2] % 2 == 0 else None)
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    cr = c.part('crown', 'glow', ((x0 + x1) / 2, (y0 + y1) / 2, z1))
    cx, cy = (x0 + x1 + 1) / 2 - 0.5, (y0 + y1) / 2
    t = top_of(head, math.floor(cx), math.floor(cy)) or z1
    cr.ell((cx, cy, t + 0.5), (0.7 * k, 0.7 * k, 0.6), GOLD, True)
    for a in range(6):
        ang = a / 6 * math.pi * 2
        crystal(cr, cx + math.cos(ang) * 0.45 * k, cy + math.sin(ang) * 0.45 * k, t + 1, 1.1 * k, 0.3 * k, P('#FF8FBF'), P('#FFF0F8'),
                lean=(math.cos(ang) * 0.3, math.sin(ang) * 0.3))
    return c


def thorn_stego(c, H):
    plan('dino', c, H, {'col': '#5C9A4A', 'belly': '#C8E0A0', 'accent': '#3A7A3A', 'glow': '#FFB3D1', 'horn': '#E8D8B0'},
         kind='stego')
    k = H / 10.0
    # thorny vines over the plates, flowers on top
    pl = c.part('plates')
    pts = list(pl.v)
    tops = {}
    for (x, y, z) in pts:
        if (y not in tops) or z > tops[y][2]:
            tops[y] = (x, y, z)
    for i, (x, y, z) in enumerate(pts):
        if (x + y + z) % 4 == 0:
            pl.put((x + (1 if x >= 0 else -1), y, z), P('#2E6A2E'))
    fl = c.part('flowers', 'glow')
    for i, (y, p) in enumerate(sorted(tops.items())):
        if i % max(1, round(0.6 * k)) == 0:
            flower(fl, p[0], p[1], p[2] + 1, k * 0.7, petal=(BLOSSOM, P('#FFE14D'), WHITE)[i % 3], glow=True)
    speckle(c.part('body'), (P('#5C9A4A'),), P('#4A8A3A'), 5)
    return c


# ---------------------------------------------------- Storm (sky) set

def storm_ram(c, H):
    plan('beast', c, H, {'col': '#4A5070', 'belly': '#8A90A8', 'snout': '#8A90A8', 'accent': '#E8ECF8', 'horn': '#E8D8B0',
                         'glow': '#4FD8FF'}, kind='hoof', horns='ram', tail='short')
    k = H / 10.0
    # cloud fleece: puffy grey-white lumps over the body
    body = c.part('body')
    fleece = c.part('fleece', 'static')
    for (x, y, z) in ((0, -1.2, 5.0), (1.1, 0.4, 4.8), (-1.1, 0.4, 4.8), (0, 1.6, 5.0), (0, 0.2, 5.5), (1.4, -1.0, 4.2),
                      (-1.4, -1.0, 4.2), (1.3, 2.0, 4.2), (-1.3, 2.0, 4.2)):
        fleece.ell((x * k, y * k, z * k), (1.05 * k, 1.05 * k, 0.9 * k), P('#EEF2FA'))
    fleece.paint(lambda p, cc, g: (P('#C8D0E2'), False) if p[2] < 4.3 * k else None)
    for p in [p for p in fleece.v if p in body.v]:
        del body.v[p]
    # lightning crackles through the fleece
    fleece.paint(lambda p, cc, g: (BOLT, True) if (p[0] * 5 + p[1] * 3 + p[2] * 2) % 31 == 0 else None)
    return c


def tempest_eagle(c, H):
    k, lift = grand_bird(c, H, P('#5A4A8A'), P('#E8ECF8'), P('#FFC21A'), P('#4A3A7A'),
                         (P('#4A3A7A'), P('#6A5AAA'), P('#9AB8FF')), BOLT_HOT, crest=P('#E8ECF8'), feet=P('#FFC21A'),
                         big_eyes=False, edge=BOLT)
    head = c.part('head')
    head.paint(lambda p, cc, g: (WHITE, False) if cc == P('#5A4A8A') else None)  # a white eagle head
    # lightning feathers on the wings
    for name in ('wingL', 'wingR'):
        w = c.part(name)
        w.paint(lambda p, cc, g: (BOLT, True) if not g and (abs(p[0] + .5) + p[2] * 0.5) % round(2.0 * k) < 1 else None)
    # the wind ring
    wr = orbit_part(c, 'windring', (0, 0.6 * k, 4 * k + lift))
    ring(wr, 0, 0.6 * k, 2.6 * k + lift, 4.2 * k, P('#C8F4FF'), True, thick=0.6, tilt=-0.2)
    ring(wr, 0, 0.6 * k, 2.6 * k + lift + 1, 3.6 * k, P('#E8FCFF'), True, thick=0.5, tilt=-0.2)
    return c


def raiju(c, H):
    plan('beast', c, H, {'col': '#FFE14D', 'belly': '#FFF6B0', 'snout': '#FFF6B0', 'accent': '#4FD8FF', 'glow': '#4FD8FF',
                         'eye': '#2E5AC8'}, kind='canine', tail='fox', mane='ruff', stripes=True)
    k = H / 10.0
    # made of lightning: the ruff and tail crackle and bolts arc off it
    for name in ('mane', 'tail'):
        p = part_or_none(c, name)
        if p:
            p.anim = 'glow' if name == 'mane' else p.anim
            p.paint(lambda q, cc, g: ((BOLT_HOT if (q[0] + q[1] + q[2]) % 3 else BOLT), True))
    bt = c.part('bolts', 'glow')
    body = c.part('body')
    for side in (1, -1):
        x = round(side * 0.9 * k) - (1 if side < 0 else 0)
        t = top_of(body, x, round(1.0 * k))
        if t is not None:
            bolt(bt, (x + .5, 1.0 * k, t), (side * 2.4 * k, 1.8 * k, t + 1.8 * k), BOLT_HOT, zig=0.5 * k)
    return c


def thunder_tiger(c, H):
    plan('beast', c, H, {'col': '#FF8A2A', 'belly': '#FFF1DC', 'snout': '#FFF1DC', 'accent': '#2A2440', 'glow': '#7FE6FF',
                         'eye': '#2E5AC8'}, kind='cat', tail='lion', stripes=True)
    k = H / 10.0
    # the stripes are lightning: turn them into bolts that glow
    for name in ('body', 'head', 'tail'):
        p = part_or_none(c, name)
        if p:
            p.paint(lambda q, cc, g: (BOLT_HOT, True) if g and (q[2] % 2 == 0) else None)
    tail = c.part('tail')
    tail.paint(lambda q, cc, g: (BOLT, True) if cc == P('#2A2440') else None)
    bt = c.part('bolts', 'glow')
    tip = max(tail.v, key=lambda v: (v[1], v[2]))
    bolt(bt, (tip[0] + .5, tip[1] + .5, tip[2] + .5), (tip[0] + .5, tip[1] + 1.0 * k, tip[2] + 1.6 * k), BOLT_HOT, zig=0.4 * k)
    return c


def storm_narwhal(c, H):
    plan('whale', c, H, {'col': '#3A4A7A', 'belly': '#C8D6F2', 'horn': '#FFE14D', 'glow': '#FFE14D'}, kind='narwhal')
    k = H / 10.0 * 1.1
    tusk = c.part('tusk')
    tusk.anim = 'glow'
    tusk.paint(lambda p, cc, g: ((P('#FFF6B0') if (p[1] % 2) else P('#FFE14D')), True))
    speckle(c.part('body'), (P('#3A4A7A'),), P('#5A6A9A'), 6)
    # storm clouds on its fins and back, sparking
    cl = c.part('clouds', 'static')
    body = c.part('body')
    for (x, y) in ((0.8, -0.4), (-0.8, 0.6), (0.2, 1.6)):
        t = top_of(body, round(x * k), round(y * k))
        if t is not None:
            cl.ell((x * k, y * k, t + 0.4 * k), (0.9 * k, 0.9 * k, 0.6 * k), P('#C8D0E2'))
    cl.paint(lambda p, cc, g: (BOLT, True) if (p[0] + p[1] * 2 + p[2] * 3) % 17 == 0 else None)
    return c


def zephyr_fox(c, H):
    plan('beast', c, H, {'col': '#9AE6D8', 'belly': '#F4FFFC', 'snout': '#F4FFFC', 'accent': '#5AC8B8', 'glow': '#E8FFFA',
                         'eye': '#1E6A6A'}, kind='canine', tail='fox')
    k = H / 10.0
    drop(c, 'tail')
    bz = 3.8 * k
    tail = c.part('tail', 'tail', (0, 3.6 * k, bz + 0.6 * k))
    # three swirling wind tails that curl at the tips
    for j, side in enumerate((-1, 0, 1)):
        pts = []
        for i in range(24):
            s = i / 23
            ang = s * math.pi * 1.6
            pts.append((side * (0.4 + 1.4 * s) * k, 3.6 * k + s * 2.4 * k + math.sin(ang) * 0.6 * k,
                        bz + 0.6 * k + s * 2.8 * k + math.cos(ang) * 0.6 * k - 0.6 * k, (0.5 + 0.35 * math.sin(s * math.pi)) * k))
        sweep(tail, pts, lambda s: P('#9AE6D8') if s < 0.5 else (P('#C8FFF4') if s < 0.85 else P('#E8FFFA')), lambda s: s >= 0.85)
    # wind swirls on its flanks
    body = c.part('body')
    body.paint(lambda p, cc, g: (P('#E8FFFA'), True) if abs(p[0] + .5) > 1.6 * k and ((p[1] + 2 * p[2]) % round(1.6 * k) == 0) and cc == P('#9AE6D8') else None)
    return c


# --------------------------------------------- Cosmic, Crystal, Spirit

def moon_owl(c, H):
    navy = P('#3A3A7A')
    k, lift = grand_bird(c, H, navy, P('#C8C8F2'), P('#FFC21A'), P('#2A2A5A'), (P('#2A2A5A'), navy, P('#6A6AB8')), P('#FFF6B0'),
                         feet=P('#C8C8F2'), tuft=True, crest=None, length=4.6)
    for p in c.parts:
        speckle(p, (navy, P('#2A2A5A')), P('#E8E8FF'), 23, glow=True)
    c.part('eyes').paint(lambda p, cc, g: (P('#FFE14D'), True) if cc == INK else None)
    # a crescent moon behind its head
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    moon = c.part('moon', 'glow', (0, y1, (z0 + z1) / 2))
    cy = y1 + 1
    cz = (z0 + z1) / 2 + 0.6 * k
    R = 2.8 * k
    for x in range(-round(R) - 1, round(R) + 1):
        for z in range(round(cz - R) - 1, round(cz + R) + 1):
            d1 = math.hypot(x + .5, z + .5 - cz)
            d2 = math.hypot(x + .5 - 1.1 * k, z + .5 - cz - 0.6 * k)
            if d1 <= R and d2 > R * 0.82:
                moon.put((x, cy, z), P('#FFF2A8') if d1 < R - 1 else P('#FFE14D'), True)
                moon.put((x, cy + 1, z), P('#E8D88A'))
    # star-tipped feathers
    for name in ('wingL', 'wingR'):
        w = c.part(name)
        (wx0, wy0, wz0), (wx1, wy1, wz1) = bounds_of(w)
        xo = wx1 if name == 'wingR' else wx0
        star(w, xo + (1 if name == 'wingR' else -1), wy0, wz1 - 1, max(1, round(0.35 * k)), P('#FFF6B0'), True)
    return c


def prism_peacock(c, H):
    teal = P('#2EC4B6')
    k, lift = grand_bird(c, H, P('#2E6AC8'), P('#5A9AE8'), P('#3A3A4A'), teal, (teal, P('#5AD8C8'), P('#B8F4EE')), P('#FFFFFF'),
                         crest=P('#2EC4B6'), feet=P('#8A8A9A'), length=3.6, rise=1.6)
    # the fan tail of rainbow crystal eyes, standing up behind it
    tail = c.part('tail', 'tail', (0, 2.6 * k, 3.2 * k + lift))
    body = c.part('body')
    cy = max(v[1] for v in body.v if abs(v[0]) < 2 and v[2] < 3.4 * k + lift) - 1
    base_z = 2.4 * k + lift
    R = 4.6 * k
    rainbow = [P('#FF4D6D'), P('#FF9A1A'), P('#FFE14D'), P('#5CD85A'), P('#4FA8FF'), P('#9A6AFF')]
    for x in range(-round(R), round(R) + 1):
        for z in range(0, round(R) + 1):
            d = math.hypot(x + .5, z)
            if d > R or z < 0:
                continue
            a = math.atan2(z, x + .5)
            y = round(cy + d * 0.18)
            tail.put((x, y, round(base_z + z)), teal if d < R * 0.5 else P('#1E9A8A'))
            tail.put((x, y + 1, round(base_z + z)), P('#1E8A7A'))
    # crystal eyes along the fan's edge, each a gem with a ring
    for i in range(9):
        a = (i + 0.5) / 9 * math.pi
        ex, ez = math.cos(a) * R * 0.8, base_z + math.sin(a) * R * 0.8
        col = rainbow[i % len(rainbow)]
        tail.ell((ex, cy + R * 0.8 * 0.18 - 1, ez), (0.75 * k, 0.6, 0.75 * k), P('#FFE14D'), True)
        tail.ell((ex, cy + R * 0.8 * 0.18 - 2, ez), (0.45 * k, 0.6, 0.45 * k), col, True)
    for i in range(5):
        a = (i + 0.5) / 5 * math.pi
        ex, ez = math.cos(a) * R * 0.5, base_z + math.sin(a) * R * 0.5
        tail.ell((ex, cy + R * 0.5 * 0.18 - 1, ez), (0.4 * k, 0.6, 0.4 * k), rainbow[(i * 2) % 6], True)
    return c


def mirror_cat(c, H):
    plan('beast', c, H, {'col': '#C8D0DC', 'belly': '#E8EEF6', 'snout': '#F4F8FC', 'accent': '#9AA8BA', 'glow': '#7FFFE6',
                         'eye': '#2EE8C8'}, kind='cat', tail='fox')
    k = H / 10.0
    # chrome: bright highlights and dark reflections in bands
    for p in c.parts:
        if p.name in ('eyes',):
            continue
        p.paint(lambda q, cc, g: (WHITE, False) if cc == P('#C8D0DC') and (q[2] + q[1] // 2) % 6 == 0 else (
            (P('#8A96A8'), False) if cc == P('#C8D0DC') and (q[2] + q[1] // 2) % 6 == 3 else None))
    c.part('eyes').paint(lambda q, cc, g: (P('#2EE8C8'), True) if cc != WHITE else None)
    # the floating mirror, in a gold frame, circling it
    mir = orbit_part(c, 'mirror', (0, 0, 5 * k))
    mx0, my0, mz0 = 3.4 * k, -0.6 * k, 6.6 * k
    for x in range(-round(1.2 * k), round(1.2 * k) + 1):
        for z in range(-round(1.6 * k), round(1.6 * k) + 1):
            d = (x / (1.2 * k)) ** 2 + (z / (1.6 * k)) ** 2
            if d <= 1:
                frame = d > 0.7
                mir.put((round(mx0), round(my0 + x), round(mz0 + z)), GOLD if frame else P('#BFF4FF'), not frame or True)
                mir.put((round(mx0) + 1, round(my0 + x), round(mz0 + z)), GOLD_D)
    # a gem on the cat's brow
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    f = head.front(0, z1 - round(0.6 * k)) or head.front(-1, z1 - round(0.6 * k))
    if f:
        gem = c.part('gem', 'glow', head.pivot)
        gem.ell((f[0] + .5 - 0.5, f[1] - 0.5, f[2]), (0.5 * k, 0.6, 0.5 * k), P('#2EE8C8'), True)
    return c


def spectral_wolf(c, H):
    ghost = P('#BFEFFF')
    plan('beast', c, H, {'col': '#BFEFFF', 'belly': '#E6FBFF', 'snout': '#E6FBFF', 'accent': '#8AD8F2', 'glow': '#7FFFE6',
                         'eye': '#7FFFE6'}, kind='canine', tail='bushy', mane='ruff')
    k = H / 10.0
    c.part('eyes').paint(lambda q, cc, g: (P('#7FFFE6'), True) if cc != WHITE else None)
    # the glowing skeleton outline: spine and ribs on the flanks
    body = c.part('body')
    bz = 3.8 * k
    body.paint(lambda p, cc, g: (P('#7FFFE6'), True) if cc == ghost and abs(p[0] + .5) > 1.5 * k and
               -1.4 * k < p[1] < 1.6 * k and (p[1] % max(3, round(0.8 * k)) == 0) and p[2] > bz - 0.4 * k else None)
    body.paint(lambda p, cc, g: (P('#7FFFE6'), True) if cc == ghost and abs(p[0] + .5) < 0.6 and p[2] >= max(
        q[2] for q in body.v if q[0] == p[0] and q[1] == p[1]) else None)
    # wispy fading paws and tail tip
    for name in ('legFL', 'legFR', 'legBL', 'legBR'):
        lp = part_or_none(c, name)
        if lp:
            lp.paint(lambda q, cc, g: (P('#E6FBFF'), True) if q[2] < 0.5 * k else None)
    tail = c.part('tail')
    tail.paint(lambda q, cc, g: (P('#E6FBFF'), True) if (q[0] + q[1] + q[2]) % 4 == 0 else None)
    return c


def starlight_pegasus(c, H):
    plan('beast', c, H, {'col': '#F4F0FF', 'belly': '#FFFFFF', 'snout': '#FFE6F2', 'accent': '#2A2A6A', 'horn': '#FFE14D',
                         'glow': '#FFF6B0', 'wing': '#E8E0FF'}, kind='hoof', mane='crest', tail='bushy', wings='feather')
    k = H / 10.0
    for name in ('mane', 'tail'):
        p = part_or_none(c, name)
        if p:
            p.paint(lambda q, cc, g: (P('#2A2A6A'), False))
            speckle(p, (P('#2A2A6A'),), P('#FFF6B0'), 5, glow=True)
            speckle(p, (P('#2A2A6A'),), P('#9A8AFF'), 4, glow=False)
    # glowing hooves and a star on the brow
    for name in ('legFL', 'legFR', 'legBL', 'legBR'):
        lp = part_or_none(c, name)
        if lp:
            lp.paint(lambda q, cc, g: (P('#FFE14D'), True) if q[2] < 0.5 * k else None)
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    st = c.part('browstar', 'glow', head.pivot)
    f = head.front(0, z1 - round(0.4 * k))
    if f:
        star(st, f[0], f[1] - 1, f[2], max(1, round(0.3 * k)), P('#FFE14D'), True)
    return c


def comet_fox(c, H):
    plan('beast', c, H, {'col': '#3A2A7A', 'belly': '#C8B8FF', 'snout': '#C8B8FF', 'accent': '#2A1A5A', 'glow': '#FFC21A',
                         'eye': '#FFE14D'}, kind='canine', tail='fox')
    k = H / 10.0
    for p in c.parts:
        speckle(p, (P('#3A2A7A'),), P('#FFF6B0'), 29, glow=True)
    drop(c, 'tail')
    bz = 3.8 * k
    tail = c.part('tail', 'tail', (0, 3.6 * k, bz + 0.6 * k))
    # the comet tail: a blazing head of fire streaming back and up
    pts = []
    for i in range(26):
        s = i / 25
        pts.append((0, 3.6 * k + s * 4.0 * k, bz + 0.6 * k + s * 2.4 * k + math.sin(s * math.pi) * 0.6 * k, (0.5 + 1.1 * s ** 0.7) * k))
    sweep(tail, pts, lambda s: P('#3A2A7A') if s < 0.2 else (FIRE[3] if s < 0.45 else (FIRE[2] if s < 0.7 else FIRE[1])), lambda s: s >= 0.2)
    return c


def astro_axolotl(c, H):
    """A chubby pink axolotl in a space helmet: galaxy gill fronds, a finned
    tail, four stubby legs and a ring of stars circling it in zero gravity."""
    k = H / 10.0
    pink, belly, deep = P('#FF9EC6'), P('#FFD6E8'), P('#E86AA0')
    body = c.part('body')
    bz = 2.5 * k
    body.ell((0, 0.9 * k, bz), (1.5 * k, 2.5 * k, 1.25 * k), pink)
    body.paint(lambda q, cc, g: (belly, False) if q[2] < bz - 0.55 * k else None)
    # dark freckles down the back
    speckle(body, (pink,), deep, 9, zmin=round(bz + 0.6 * k))
    head = c.part('head', 'head', (0, -1.2 * k, bz + 0.2 * k))
    hy, hz = -2.4 * k, bz + 0.9 * k
    head.ell((0, hy, hz), (2.0 * k, 1.5 * k, 1.45 * k), pink)
    head.paint(lambda q, cc, g: (belly, False) if q[2] < hz - 0.75 * k else None)
    km.eye_pair(c, head, round(0.75 * k), round(hz + 0.1 * k), max(2, round(0.42 * k)))
    km.cheeks(head, round(1.25 * k), round(hz - 0.45 * k))
    # a wide happy smile
    for x in range(-round(0.6 * k), round(0.6 * k)):
        zz = round(hz - 0.6 * k + (0 if abs(x + .5) < 0.35 * k else 1))
        f = head.front(x, zz)
        if f:
            head.put(f, deep)
    # galaxy gills: three fronds a side, deep violet speckled with stars
    gills = c.part('gills', 'ears', (0, hy, hz))
    gal = (P('#5A3ACF'), P('#7A4AF0'), P('#2F7FFF'))
    for side in (1, -1):
        for j, (up, out, ln) in enumerate(((1.25, 0.5, 1.0), (0.45, 1.0, 1.15), (-0.35, 0.95, 0.95))):
            root = (side * 1.55 * k, hy + 0.5 * k, hz + up * 0.55 * k)
            tip = (side * (1.55 + out * 1.5 * ln) * k, hy + 1.1 * k, hz + up * 1.25 * k + 0.35 * k)
            pts = km.curve(root, tip, 10, (0, 0.2 * k, 0.4 * k))
            for i, (x, y, z) in enumerate(pts):
                r = 0.42 * k * (1 - 0.45 * i / 10)
                gills.ell((x, y, z), (r, r, r), gal[(i + j) % 3], True)
            km.core(gills, pts, col=gal[0], glow=True)
    def stars(q, cc, g):
        if cc not in gal:
            return None
        h = (q[0] * 73856093) ^ (q[1] * 19349663) ^ (q[2] * 83492791)
        return (P('#FFF6B0'), True) if (h >> 4) % 7 == 0 else None
    gills.paint(stars)
    # a finned tail: a tapering paddle with a frill along the top and bottom
    tail = c.part('tail', 'tail', (0, 3.0 * k, bz))
    pts = [(0, 3.0 * k + t * 3.4 * k, bz + 0.2 * k + math.sin(t * math.pi) * 0.3 * k, max(0.7, 0.95 * k * (1 - 0.75 * t)))
           for t in [i / 14 for i in range(15)]]
    km.sweep(tail, pts, lambda t: pink)
    for x0, y0, z0, r in pts[2:]:
        fin = round(0.85 * k * (1 - abs((y0 - 4.6 * k) / (2.2 * k))))
        for dz in range(1, max(1, fin) + 1):
            tail.put((0, round(y0), round(z0 + r) + dz - 1), P('#FFB8D8'))
            tail.put((-1, round(y0), round(z0 + r) + dz - 1), P('#FFB8D8'))
    # four stubby legs with little pale toes
    top = round(bz - 0.4 * k)
    for side in ('L', 'R'):
        for i, ly in enumerate((-0.6 * k, 2.3 * k)):
            km.leg(c, side, i, 2, 1.15 * k, ly, top, 0.5 * k, pink, foot=belly, foot_h=1, toes=belly, wide=0.12 * k)
    # the space helmet: a white collar and a glowing glass bubble arch
    helm = c.part('helmet', 'static', (0, hy, hz))
    R = 2.25 * k
    ring(helm, 0.5, hy + 0.9 * k, hz - 0.2 * k, 1.75 * k, WHITE, False, thick=0.9, axis='y')
    glass = P('#7FD8FF')
    arch = [(0.5 + math.cos(t / 30 * math.pi) * R, hy + 0.2 * k, hz + 0.1 * k + math.sin(t / 30 * math.pi) * R * 0.95)
            for t in range(31)]
    for (x, y, z) in arch:
        helm.ell((x, y, z), (0.6, 0.6, 0.6), glass, True)
    km.core(helm, arch, col=glass, glow=True)
    # an antenna with a glowing bead, off the arch's crown
    ax, az = round(0.5 + R * 0.35), round(hz + 0.1 * k + R * 0.92)
    for i in range(-2, round(0.9 * k)):
        helm.put((ax, round(hy + 0.2 * k), az + i), WHITE)
    helm.ell((ax + .5, hy + 0.2 * k + .5, az + 0.9 * k + .5), (0.5 * k, 0.5 * k, 0.5 * k), P('#FFE14D'), True)
    for part in c.parts:
        if part is not helm:
            for v in list(helm.v):
                if v in part.v and part.name in ('head', 'eyes'):
                    del helm.v[v]
    # zero gravity: a ring of stars circling it
    cx, cy, cz = 0, 0.6 * k, bz + 0.5 * k
    st = orbit_part(c, 'stars', (cx, cy, cz))
    Ro = 3.6 * k
    ring(st, cx + .5, cy, cz, Ro, P('#B8A0FF'), True, thick=0.95, tilt=0.25)
    for a in range(5):
        ang = a / 5 * math.pi * 2
        star(st, cx + math.cos(ang) * Ro, cy + math.sin(ang) * Ro, cz + math.sin(ang) * Ro * 0.25, 1, P('#FFF6B0'), True)
    c.gait_hint = 'hover'
    return c


# ---------------------------------------------- Fantasy, Myth and Ocean

def sky_whale(c, H):
    plan('whale', c, H, {'col': '#7AA8E8', 'belly': '#F4F8FF', 'glow': '#FFE14D'}, kind='whale')
    k = H / 10.0 * 1.1
    # cloud fins: puffy white clouds on its fins and fluke
    for name in ('finL', 'finR', 'tail'):
        p = part_or_none(c, name)
        if p:
            (x0, y0, z0), (x1, y1, z1) = bounds_of(p)
            for (x, y, z) in list(p.v)[::5]:
                if z >= z1 - 1:
                    p.ell((x, y, z + 0.5), (0.6 * k, 0.6 * k, 0.45 * k), P('#FFFFFF'))
    # the tiny lighthouse on its back
    body = c.part('body')
    y = round(0.2 * k)
    t = top_of(body, 0, y) or round(6 * k)
    lh = c.part('lighthouse', 'static', (0, y, t))
    hgt = round(2.6 * k)
    for i in range(hgt):
        r = 0.75 * k - i * 0.12
        band = (i // max(2, round(0.5 * k))) % 2
        lh.ell((0, y, t + i), (max(0.8, r), max(0.8, r), 0.6), P('#FF4D5E') if band else WHITE)
    lh.ell((0, y, t - 0.2 * k), (1.0 * k, 1.0 * k, 0.6), P('#8A8A9A'))
    lamp = c.part('lamp', 'glow', (0, y, t + hgt))
    lamp.ell((0, y, t + hgt + 0.4 * k), (0.55 * k, 0.55 * k, 0.5 * k), P('#FFE14D'), True)
    lamp.ell((0, y, t + hgt + 1.0 * k), (0.6 * k, 0.6 * k, 0.2 * k + 0.4), P('#FF4D5E'))
    lamp.put((0, y, round(t + hgt + 1.3 * k)), P('#FF4D5E'))
    lamp.put((-1, y, round(t + hgt + 1.3 * k)), P('#FF4D5E'))
    return c


def arcane_tortoise(c, H):
    import creatures as cr
    cr.blob(c, H, 'turtle', P('#8AC86A'), P('#4A5A8A'))
    k = H / 10.0
    # legs reach up into the shell (the turtle plan's legs stop short)
    body = c.part('body')
    for p in c.parts:
        if p.name.startswith('leg'):
            for (x, y, z) in list(p.v):
                for zz in range(z + 1, z + round(1.6 * k)):
                    if any((x, y, zz) in q.v for q in c.parts if q is not p):
                        break
                    p.put((x, y, zz), p.v[(x, y, z)][0])
    # rune-carved shell: glowing rune lines over the shell's plates
    for p in c.parts:
        if p.name in ('shell', 'body'):
            p.paint(lambda q, cc, g: (P('#7FE6FF'), True) if cc == P('#4A5A8A') and (
                (q[0] + q[1]) % round(1.4 * k) == 0 or (q[0] - q[1]) % round(1.4 * k) == 0) and q[2] > 2.2 * k else None)
    # the floating spellbook, open, circling above its shell
    bk = orbit_part(c, 'spellbook', (0, 0, 6 * k))
    bx, by, bz = 2.6 * k, 0, 6.6 * k
    for side in (1, -1):
        for x in range(round(1.4 * k)):
            for y in range(round(1.8 * k)):
                z = bz + x * 0.3
                bk.put((round(bx + side * x) - (1 if side < 0 else 0), round(by + y - 0.9 * k), round(z)), P('#FFF6E0'))
                bk.put((round(bx + side * x) - (1 if side < 0 else 0), round(by + y - 0.9 * k), round(z) - 1), P('#7A2EC8'))
    for y in range(round(1.8 * k)):
        bk.put((round(bx) - 1, round(by + y - 0.9 * k), round(bz) - 1), P('#5A1EA8'))
        bk.put((round(bx), round(by + y - 0.9 * k), round(bz) - 1), P('#5A1EA8'))
    # glowing letters rising from the pages
    for i in range(3):
        bk.put((round(bx + 0.4 * k), round(by - 0.4 * k + i), round(bz + 1 + i)), P('#7FE6FF'), True)
        bk.put((round(bx - 0.6 * k), round(by + i), round(bz + 1 + i)), P('#C9A3FF'), True)
    # a wizard's star on its head
    head = part_or_none(c, 'head')
    if head:
        (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
        st = c.part('headstar', 'glow', head.pivot)
        star(st, (x0 + x1) / 2, (y0 + y1) / 2, z1 + 1, max(1, round(0.3 * k)), P('#FFE14D'), True)
    return c


def basilisk(c, H):
    plan('serpent', c, H, {'col': '#1E8A4A', 'belly': '#C8F2A0', 'accent': '#0E5A2E', 'glow': '#B8FF6A', 'eye': '#FFE14D'},
         kind='wyrm', frills=True)
    k = H / 10.0
    c.part('eyes').paint(lambda q, cc, g: (P('#FFE14D'), True) if cc != WHITE else None)
    body = c.part('body')
    body.paint(lambda p, cc, g: (P('#2EAA5A'), False) if cc == P('#1E8A4A') and (p[0] + p[1] * 2 + p[2]) % 3 == 0 else None)
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    cr = c.part('crown', 'glow', ((x0 + x1) / 2, (y0 + y1) / 2, z1))
    km._crown(cr, k, (x0 + x1 + 1) / 2 - 0.5, (y0 + y1) / 2 + 0.2 * k, z1 - 0.2 * k, 1.0 * k, GOLD, True)
    return c


def manticore(c, H):
    plan('beast', c, H, {'col': '#D8763A', 'belly': '#F2C89A', 'snout': '#F2C89A', 'accent': '#7A2E1E', 'horn': '#2A1A1A',
                         'glow': '#FF4D6D', 'wing': '#5A2A3A'}, kind='cat', mane='lion', tail='spike', wings='bat')
    k = H / 10.0
    # a scorpion's tail: armoured segments and a glowing sting
    tail = c.part('tail')
    tail.paint(lambda p, cc, g: (P('#7A2E1E') if (p[1] + p[2]) % 3 == 0 else P('#9A3E2A'), False) if not g and cc != P('#2A1A1A') else None)
    st = c.part('sting', 'glow')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(tail)
    horn(st, (0, y1 - 0.4 * k, z1), (0, y1 - 1.6 * k, z1 + 0.6 * k), 0.5 * k, P('#FF4D6D'), P('#FFB3C0'), glow=True, both=False)
    return c


def pixie_dragon(c, H):
    plan('drake', c, H, {'col': '#9AE6C8', 'belly': '#F4FFF8', 'accent': '#5AC8A8', 'glow': '#FFB3F2', 'horn': '#FFE6F8',
                         'wing': '#FF9BD2'}, kind='pixie', horns='swept')
    k = H / 10.0
    # fairy dust: glittering sparkles on the wings and a trail of stars
    for name in ('wingL', 'wingR'):
        w = c.part(name)
        speckle(w, (P('#FF9BD2'), light(P('#FF9BD2'), 0.4)), P('#FFF6FF'), 6, glow=True)
    dust = orbit_part(c, 'fairydust', (0, 0, 5 * k))
    ring(dust, 0, 0.2 * k, 5.4 * k, 3.4 * k, P('#FFD6F8'), True, thick=0.45, tilt=0.35)
    for a in range(6):
        ang = a / 6 * math.pi * 2
        star(dust, math.cos(ang) * 3.4 * k, 0.2 * k + math.sin(ang) * 3.4 * k, 5.4 * k + math.sin(ang) * 3.4 * k * 0.35, 1,
             P('#FFFFFF'), True)
    return c


def treasure_dragon(c, H):
    plan('drake', c, H, {'col': '#F2B82E', 'belly': '#FFE8A0', 'accent': '#D98A10', 'glow': '#FFF6B0', 'horn': '#FFFFFF',
                         'wing': '#E8A21A'}, kind='drake', wings='bat', horns='crown')
    k = H / 10.0
    for p in c.parts:
        speckle(p, (P('#F2B82E'),), GOLD_L, 7)
    # the coin pile it sits on: gold coins heaped under its feet, a few gems
    pile = c.part('hoard', 'static', (0, 0, 0))
    for (x, y, r, h) in ((0, 0.2, 3.6, 0.9), (1.6, -1.6, 1.6, 0.8), (-1.8, 1.8, 1.8, 0.7), (-1.4, -2.4, 1.2, 0.6), (2.2, 2.0, 1.4, 0.6)):
        pile.ell((x * k, y * k, 0), (r * k, r * k, h * k), GOLD, cond=lambda xx, yy, zz: zz >= 0)
    pile.paint(lambda p, cc, g: (GOLD_D if (p[0] + p[1]) % 3 == 0 else (GOLD_L if (p[0] * 2 + p[1]) % 5 == 0 else GOLD), False))
    for (x, y, col) in ((2.4, -1.0, P('#FF3B5C')), (-2.6, 0.4, P('#3FA9FF')), (0.8, 3.0, P('#3FE08A')), (-0.8, -3.0, P('#C9A3FF'))):
        t = top_of(pile, round(x * k), round(y * k))
        if t is not None:
            pile.ell((x * k, y * k, t + 0.4 * k), (0.45 * k, 0.45 * k, 0.45 * k), col, True)
    # the dragon stands on top of the pile: raise it
    lift = round(0.5 * k)
    for p in c.parts:
        if p is not pile:
            p.v = {(x, y, z + lift): v for (x, y, z), v in p.v.items()}
            p.pivot = (p.pivot[0], p.pivot[1], p.pivot[2] + lift)
    # pile under the legs only reaches them: fill the gap so it is one piece
    for (x, y, z) in list(pile.v):
        for zz in range(z + 1, lift):
            pile.put((x, y, zz), GOLD) if (x * x + y * y) < (2.4 * k) ** 2 else None
    return c


def lollipop_lion(c, H):
    plan('beast', c, H, {'col': '#FFD6E8', 'belly': '#FFFFFF', 'snout': '#FFFFFF', 'accent': '#FF4D8A', 'glow': '#FFE14D',
                         'eye': '#7A2E8A'}, kind='cat', mane='lion', tail='lion')
    k = H / 10.0
    # the swirled lollipop mane: a pink and white spiral round its face
    m = c.part('mane')
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    hz = (z0 + z1) / 2
    m.paint(lambda p, cc, g: ((P('#FF4D8A') if int((math.atan2(p[2] + .5 - hz, p[0] + .5) / (2 * math.pi) * 6 +
                                                    math.hypot(p[0] + .5, p[2] + .5 - hz) / (0.8 * k))) % 2 else WHITE), False))
    # a candy-stick tail tuft and sprinkles
    tail = c.part('tail')
    tail.paint(lambda p, cc, g: ((P('#FF4D8A') if (p[1] + p[2]) % 3 == 0 else WHITE), False) if cc == P('#FFD6E8') else None)
    for p in c.parts:
        if p.name in ('body', 'head'):
            speckle(p, (P('#FFD6E8'),), P('#7FD8FF'), 17)
            speckle(p, (P('#FFD6E8'),), P('#FFE14D'), 19)
    # a lollipop crown-stick on top: a glowing candy
    cs = c.part('candy', 'glow', ((x0 + x1) / 2, (y0 + y1) / 2, z1))
    rod(cs, (0, (y0 + y1) / 2, z1), (0, (y0 + y1) / 2, z1 + 1.2 * k), 0.6, WHITE)
    cs.ell((0, (y0 + y1) / 2, z1 + 1.8 * k), (0.8 * k, 0.5, 0.8 * k), P('#FFE14D'), True)
    return c


def robo_rex(c, H):
    plan('dino', c, H, {'col': '#8A96A8', 'belly': '#C8D0DC', 'accent': '#4A5A70', 'horn': '#E8ECF2', 'glow': '#4FD8FF',
                         'eye': '#4FD8FF'}, kind='rex')
    k = H / 10.0
    # panels and rivets, a visor across the eyes
    for p in c.parts:
        if p.name == 'eyes':
            continue
        p.paint(lambda q, cc, g: (P('#4A5A70'), False) if cc == P('#8A96A8') and (q[1] % round(1.2 * k) == 0 or q[2] % round(1.4 * k) == 0) else None)
        speckle(p, (P('#8A96A8'),), P('#E8ECF2'), 23)
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    visor = c.part('visor', 'glow', head.pivot)
    ez = round(z1 - 0.9 * k)
    for x in range(x0, x1 + 1):
        for dz in range(max(2, round(0.45 * k))):
            f = head.front(x, ez + dz)
            if f:
                visor.put((f[0], f[1] - 1, f[2]), P('#4FD8FF'), True)
    # piston legs: shining rods down the shins and a glowing chest core
    for name in ('legL', 'legR'):
        lp = part_or_none(c, name)
        if lp:
            lp.paint(lambda q, cc, g: (P('#E8ECF2'), False) if q[1] == min(r[1] for r in lp.v if r[2] == q[2]) and q[2] % 2 == 0 else None)
            lp.paint(lambda q, cc, g: (P('#FFC21A'), False) if q[2] in (round(1.4 * k), round(1.4 * k) + 1) else None)
    body = c.part('body')
    body.paint(lambda p, cc, g: (P('#4FD8FF'), True) if p[1] < -1.6 * k and (p[0] + .5) ** 2 + (p[2] - 5.0 * k) ** 2 < (0.6 * k) ** 2 else None)
    # back fins like heat sinks
    sp = c.part('fins', 'static')
    for y in range(round(-1.0 * k), round(2.6 * k), 2):
        t = top_of(body, 0, y)
        if t is not None:
            for i in range(round(0.8 * k)):
                sp.put((0, y, t + 1 + i), P('#4A5A70'))
                sp.put((-1, y, t + 1 + i), P('#4A5A70'))
    return c


def abyss_angler(c, H):
    plan('fish', c, H, {'col': '#2A2A5A', 'belly': '#4A3A7A', 'accent': '#3A2A6A', 'glow': '#7FFFD4', 'eye': '#7FFFD4'},
         kind='angler')
    k = H / 10.0 * 1.4
    c.part('eyes').paint(lambda q, cc, g: (P('#7FFFD4'), True) if cc != WHITE else None)
    speckle(c.part('body'), (P('#2A2A5A'),), P('#7FFFD4'), 31, glow=True)
    # the lure: a stalk curving forward from its head to a glowing bulb
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    lure = c.part('lure', 'glow', (0, (y0 + y1) / 2, z1))
    my = (y0 + y1) / 2 - 0.4 * k
    t = top_of(head, 0, math.floor(my)) or z1
    pts = curve((0.2, my, t - 0.5), (0.2, y0 - 1.2 * k, t + 0.4 * k), 30, (0, 0, 2.2 * k))
    km.core(lure, pts, col=P('#4A3A7A'))
    for (x, y, z) in pts:
        lure.ell((x - 0.5, y, z), (0.7, 0.7, 0.7), P('#4A3A7A'))
    bx, by, bz = pts[-1]
    lure.ell((0, by - 0.3 * k, bz - 0.5 * k), (0.8 * k, 0.8 * k, 0.8 * k), P('#7FFFD4'), True)
    lure.ell((0, by - 0.6 * k, bz - 0.3 * k), (0.35 * k, 0.35 * k, 0.35 * k), WHITE, True)
    return c


def twin_drake(c, H):
    plan('drake', c, H, {'col': '#C83A3A', 'belly': '#FFD6A0', 'accent': '#7A1E1E', 'glow': '#FFC21A', 'horn': '#FFE8B0',
                         'wing': '#8A2A3A'}, kind='drake', heads=2, wings='bat')
    k = H / 10.0
    # one fire head (right), one ice head (left): the left half turns icy
    red, redB = P('#C83A3A'), P('#FFD6A0')
    for p in c.parts:
        if p.name in ('eyes',):
            continue
        p.paint(lambda q, cc, g: ((P('#3A8AD8') if cc == red else (P('#D6F2FF') if cc == redB else (
            ICE if g else None))), g) if q[0] < 0 and (cc in (red, redB) or g) else None)
    h2 = part_or_none(c, 'head2')
    if h2:
        (x0, y0, z0), (x1, y1, z1) = bounds_of(h2)
        br = c.part('icebreath', 'glow', h2.pivot)
        mz = z0 + round(0.6 * k)
        f = h2.front(math.floor((x0 + x1) / 2), mz) or (0, y0, mz)
        for i in range(round(1.0 * k)):
            br.ell(((x0 + x1 + 1) / 2, f[1] - i, mz + 0.5), (0.3 * k + i * 0.2, 0.8, 0.3 * k + i * 0.2), ICE_L, True)
    h1 = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(h1)
    fb = c.part('firebreath', 'glow', h1.pivot)
    mz = z0 + round(0.6 * k)
    f = h1.front(math.floor((x0 + x1) / 2), mz) or (0, y0, mz)
    for i in range(round(1.0 * k)):
        fb.ell(((x0 + x1 + 1) / 2, f[1] - i, mz + 0.5), (0.3 * k + i * 0.2, 0.8, 0.3 * k + i * 0.2), FIRE[2 - (i % 2)], True)
    return c


def coral_seahorse(c, H):
    plan('upright', c, H, {'col': '#FF8A6A', 'belly': '#FFD6B8', 'accent': '#FF6A9A', 'glow': '#7FFFE6'}, kind='seahorse')
    k = H / 10.0
    # the coral crown: branching pink and orange coral on its head
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    cr = c.part('coral', 'static', ((x0 + x1) / 2, (y0 + y1) / 2, z1))
    cx, cy = (x0 + x1 + 1) / 2 - 0.5, (y0 + y1) / 2
    for i, (dx, dy, h, col) in enumerate(((0, 0, 2.2, P('#FF6A9A')), (0.8, 0.4, 1.6, P('#FFB36A')), (-0.8, 0.4, 1.7, P('#FF8FBF')),
                                          (0.3, 0.9, 1.3, P('#FFE14D')))):
        base = (cx + dx * k * 0.5, cy + dy * k * 0.5, z1)
        tip = (cx + dx * k, cy + dy * k, z1 + h * k)
        rod(cr, base, tip, 0.35 * k, col)
        rod(cr, tip, (tip[0] + 0.5 * k * (1 if dx >= 0 else -1), tip[1], tip[2] + 0.6 * k), 0.28 * k, col)
        cr.ell(tip, (0.45 * k, 0.45 * k, 0.45 * k), light(col, 0.3), True)
    # rising bubbles, a short glowing chain from its snout
    bub = c.part('bubbles', 'glow')
    f = head.front(math.floor(cx), z1 - round(0.6 * k)) or (math.floor(cx), y0, z1 - round(0.6 * k))
    bz = f[2] + 0.3 * k
    by = f[1] - 0.2 * k
    for i in range(4):
        r = (0.32 + 0.1 * i) * k
        bub.ell((cx, by - 0.1 * k * i, bz), (r, r, r), P('#C8FFF4'), True)
        bub.paint(lambda q, cc, g: (WHITE, True) if cc == P('#C8FFF4') and (q[0] + q[2]) % 4 == 0 else None)
        bz += r + (0.32 + 0.1 * (i + 1)) * k - 1  # the next bubble just overlaps this one
    return c


def hermit_titan(c, H):
    import kit_pond
    kit_pond.shore(c, H, 'hermit', P('#FF7A4A'), P('#C84A2A'), P('#FFD6B8'))
    k = H / 10.0
    # the sunken ship it lives in, replacing the shell: a wooden hull with a
    # mast, a torn sail and a lantern
    shell = part_or_none(c, 'shell')
    if shell:
        (x0, y0, z0), (x1, y1, z1) = bounds_of(shell)
        shell.v = {}
    else:
        x0, y0, z0, x1, y1, z1 = -2 * k, 0, 1.6 * k, 2 * k, 3.4 * k, 4.6 * k
    ship = c.part('shell', 'static', ((x0 + x1) / 2, (y0 + y1) / 2, z0))
    wood, woodD = P('#9A6A3A'), P('#6A4422')
    cy = (y0 + y1) / 2 + 0.4 * k
    for y in range(round(cy - 2.6 * k), round(cy + 2.6 * k)):
        u = (y - cy) / (2.6 * k)
        w = 1.9 * k * (1 - abs(u) ** 2.2 * (0.8 if u < 0 else 0.4))
        for x in range(-round(w), round(w)):
            for z in range(round(z0), round(z0 + 2.4 * k)):
                inner = abs(x + .5) < w - 1.2 and z > z0 + 0.6 * k
                if not inner:
                    shell_col = woodD if (z - round(z0)) % 3 == 0 else wood
                    ship.put((x, y, z), shell_col)
    # portholes along the hull glow
    for y in range(round(cy - 1.6 * k), round(cy + 1.8 * k), round(1.0 * k)):
        for side in (1, -1):
            x = round(1.9 * k * (1 - abs((y - cy) / (2.6 * k)) ** 2.2 * 0.6))
            ship.put((x - 1 if side > 0 else -x, y, round(z0 + 1.4 * k)), P('#FFE14D'), True)
    # mast and sail
    rod(ship, (0, cy, z0 + 0.6 * k), (0, cy, z0 + 5.6 * k), 0.4 * k, woodD)
    for z in range(round(z0 + 2.6 * k), round(z0 + 5.2 * k)):
        w = round(1.6 * k * (1 - (z - z0 - 2.6 * k) / (3.6 * k)))
        for x in range(-w, w):
            if (x * 7 + z * 3) % 11 != 0:  # a few torn holes
                ship.put((x, round(cy - 0.6 * k), z), P('#F2E6C8'))
    ship.put((0, round(cy), round(z0 + 5.9 * k)), P('#FF4D5E'))
    lan = c.part('lantern', 'glow')
    lan.ell((0, cy - 0.6 * k, z0 + 5.6 * k), (0.45 * k, 0.45 * k, 0.55 * k), P('#FFE14D'), True)
    for p in [p for p in ship.v if p in lan.v]:
        del ship.v[p]
    return c


# ------------------------------------------------------------------ roster

ROSTER = [
    ('GlacierMammoth', 'Legendary', glacier_mammoth),
    ('VerdantWyrm', 'Legendary', verdant_wyrm),
    ('MoonOwl', 'Legendary', moon_owl),
    ('LavaDrake', 'Legendary', lava_drake),
    ('PrismPeacock', 'Legendary', prism_peacock),
    ('StormRam', 'Legendary', storm_ram),
    ('CoralSeahorse', 'Legendary', coral_seahorse),
    ('SpectralWolf', 'Legendary', spectral_wolf),
    ('SkyWhale', 'Legendary', sky_whale),
    ('BlossomQilin', 'Legendary', blossom_qilin),
    ('FrostWyvern', 'Legendary', frost_wyvern),
    ('SunScarab', 'Legendary', sun_scarab),
    ('MirrorCat', 'Legendary', mirror_cat),
    ('ArcaneTortoise', 'Legendary', arcane_tortoise),
    ('CerberusPup', 'Legendary', cerberus_pup),
    ('MagmaGolem', 'Legendary', magma_golem),
    ('BlazeRhino', 'Legendary', blaze_rhino),
    ('GoldenSphinx', 'Legendary', golden_sphinx),
    ('MeteorBeetle', 'Legendary', None),  # set below
    ('EmberManta', 'Legendary', ember_manta),
    ('GlacierOrca', 'Legendary', glacier_orca),
    ('BlizzardOwl', 'Legendary', blizzard_owl),
    ('FrostGiant', 'Legendary', frost_giant),
    ('FrostSaber', 'Legendary', frost_saber),
    ('CrystalTriceratops', 'Legendary', crystal_triceratops),
    ('ElderTreant', 'Legendary', elder_treant),
    ('MushroomKing', 'Legendary', mushroom_king),
    ('SylvanElk', 'Legendary', sylvan_elk),
    ('LotusKoi', 'Legendary', lotus_koi),
    ('MantisQueen', 'Legendary', mantis_queen),
    ('ThornStego', 'Legendary', thorn_stego),
    ('TempestEagle', 'Legendary', tempest_eagle),
    ('Raiju', 'Legendary', raiju),
    ('ThunderTiger', 'Legendary', thunder_tiger),
    ('StormNarwhal', 'Legendary', storm_narwhal),
    ('ZephyrFox', 'Legendary', zephyr_fox),
    ('StarlightPegasus', 'Legendary', starlight_pegasus),
    ('Basilisk', 'Legendary', basilisk),
    ('Manticore', 'Legendary', manticore),
    ('PixieDragon', 'Legendary', pixie_dragon),
    ('TreasureDragon', 'Legendary', treasure_dragon),
    ('LollipopLion', 'Legendary', lollipop_lion),
    ('RoboRex', 'Legendary', robo_rex),
    ('CometFox', 'Legendary', comet_fox),
    ('AstroAxolotl', 'Legendary', astro_axolotl),
    ('AbyssAngler', 'Legendary', abyss_angler),
    ('TwinDrake', 'Legendary', twin_drake),
    ('HermitTitan', 'Legendary', hermit_titan),
]


def meteor_beetle(c, H):
    import kit
    kit.bug(c, H, 'beetle', P('#4A4048'), P('#2A2228'), None)
    k = H / 10.0
    shell = part_or_none(c, 'shell')
    if shell:
        rock = (P('#4A4048'),)
        speckle(shell, rock, P('#6A5E66'), 4)
        # craters, and the shell glowing hot through cracks
        cracks(shell, (P('#4A4048'), P('#6A5E66')), FIRE[1], k, scale=0.7)
        top = max(q[2] for q in shell.v)
        shell.paint(lambda p, cc, g: (FIRE[2], True) if p[2] >= top - 1 and (p[0] + p[1]) % 4 == 0 else None)
    # a smoking trail of embers off the back
    sm = c.part('smoke', 'glow')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(shell or c.part('body'))
    for i in range(4):
        r = (0.5 + 0.18 * i) * k
        sm.ell((0, y1 + 0.2 * k + i * 0.9 * k, z1 - 0.6 * k + i * 0.7 * k), (r, r, r), (FIRE[1], FIRE[2], P('#8A8A9A'), P('#B8B8C8'))[i], i < 2)
    return c


def calm_pale_glow(c, most=60):
    """Near-white voxels that glow render as flat white blobs (and Neon in
    game does the same), so big pale glowing areas keep their colour but stop
    glowing. Small white-hot tips (at most `most` voxels a part) still glow."""
    for p in c.parts:
        pale = [q for q, (col, g) in p.v.items() if g and sum(col) / 3 > 215]
        if len(pale) > most:
            for q in pale:
                p.v[q] = (p.v[q][0], False)
    return c


def _pieces(c):
    """Face-connected pieces of the creature's non-orbit voxels, biggest
    first, and the part that owns each voxel."""
    from collections import deque
    owner = {}
    for p in c.parts:
        if p.anim != 'orbit':
            for v in p.v:
                owner.setdefault(v, p)
    left, out = set(owner), []
    while left:
        s0 = left.pop()
        comp, q = {s0}, deque([s0])
        while q:
            x, y, z = q.popleft()
            for m in ((x + 1, y, z), (x - 1, y, z), (x, y + 1, z), (x, y - 1, z), (x, y, z + 1), (x, y, z - 1)):
                if m in left:
                    left.remove(m)
                    comp.add(m)
                    q.append(m)
        out.append(comp)
    out.sort(key=len, reverse=True)
    return out, owner


def join_pieces(c, rounds=6):
    """Welds pieces that touch the rest of the creature only at an edge or
    a corner: each such contact gets the missing voxel(s) between them, in
    the smaller piece's part and colour, so the creature is one solid piece
    without changing its silhouette. Truly floating pieces are left alone
    (tidy drops the tiny ones)."""
    for _ in range(rounds):
        pieces, owner = _pieces(c)
        if len(pieces) < 2:
            return c
        main = pieces[0]
        added = False
        for comp in pieces[1:]:
            for (x, y, z) in comp:
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        for dz in (-1, 0, 1):
                            if abs(dx) + abs(dy) + abs(dz) < 2 or (x + dx, y + dy, z + dz) not in main:
                                continue
                            # step one axis at a time from the piece to main
                            part = owner[(x, y, z)]
                            col, g = part.v[(x, y, z)]
                            cur = [x, y, z]
                            steps = [(axis, d) for axis, d in ((0, dx), (1, dy), (2, dz)) if d]
                            for axis, d in steps[:-1]:
                                cur[axis] += d
                                t = tuple(cur)
                                if t not in owner:
                                    part.v[t] = (col, g)
                                    owner[t] = part
                            added = True
                            break
                        else:
                            continue
                        break
                    else:
                        continue
                    break
                else:
                    continue
                break
        if not added:
            added = _close_gaps(pieces, owner)
        if not added:
            return c
    return c


def _close_gaps(pieces, owner, reach=3, keep=8):
    """A sizeable piece that stops a voxel or two short of the rest (a head
    set just off the neck) is joined across the gap: every one of its
    voxels at the closest distance gets a straight face-connected bridge to
    its nearest main voxel, in its own part and colour."""
    main = pieces[0]
    added = False
    for comp in pieces[1:]:
        if len(comp) <= keep:
            continue
        lo = [min(v[i] for v in comp) - reach for i in range(3)]
        hi = [max(v[i] for v in comp) + reach for i in range(3)]
        near = [m for m in main if all(lo[i] <= m[i] <= hi[i] for i in range(3))]
        if not near:
            continue
        pairs = []
        for u in comp:
            d, v = min((sum((a - b) ** 2 for a, b in zip(u, m)), m) for m in near)
            pairs.append((d, u, v))
        dmin = min(p[0] for p in pairs)
        if dmin > reach * reach:
            continue
        for d, u, v in pairs:
            if d > dmin + 1:
                continue
            part = owner[u]
            col, g = part.v[u]
            cur = list(u)
            for axis in range(3):
                while cur[axis] != v[axis]:
                    cur[axis] += 1 if v[axis] > cur[axis] else -1
                    t = tuple(cur)
                    if t not in owner:
                        part.v[t] = (col, g)
                        owner[t] = part
            added = True
    return added


def _orbit_gives_way(c):
    """Where an orbiting prop passes through the creature, the creature
    keeps the voxel (the loader gives a shared voxel to the later part, which
    would punch a hole in the body)."""
    solid = set()
    for p in c.parts:
        if p.anim != 'orbit':
            solid |= set(p.v)
    for p in c.parts:
        if p.anim == 'orbit':
            for v in solid & set(p.v):
                del p.v[v]
    return c


def _finished(fn):
    def build(c, H):
        fn(c, H)
        return calm_pale_glow(tidy(join_pieces(_orbit_gives_way(c))))
    return build


def finish_existing(roster):
    """The Legendaries built before this batch (Phoenix, Thunder Griffin)
    get the same weld, so the loose-piece check passes for every Legendary."""
    return [(sid, tier, _finished(fn)) if tier == 'Legendary' and sid in ('Phoenix', 'ThunderGriffin') else (sid, tier, fn)
            for sid, tier, fn in roster]


ROSTER = [(sid, tier, _finished(fn if fn else meteor_beetle)) for sid, tier, fn in ROSTER]

ELEMENT = {
    'GlacierMammoth': 'Glacial', 'VerdantWyrm': 'Nature', 'LavaDrake': 'Ember', 'StormRam': 'Storm',
    'CoralSeahorse': 'Nature', 'SkyWhale': 'Storm', 'BlossomQilin': 'Nature', 'FrostWyvern': 'Glacial',
    'SunScarab': 'Ember', 'CerberusPup': 'Ember', 'MagmaGolem': 'Ember', 'BlazeRhino': 'Ember', 'GoldenSphinx': 'Ember',
    'MeteorBeetle': 'Ember', 'EmberManta': 'Ember', 'GlacierOrca': 'Glacial', 'BlizzardOwl': 'Glacial',
    'FrostGiant': 'Glacial', 'FrostSaber': 'Glacial', 'CrystalTriceratops': 'Glacial', 'ElderTreant': 'Nature',
    'MushroomKing': 'Nature', 'SylvanElk': 'Nature', 'LotusKoi': 'Nature', 'MantisQueen': 'Nature', 'ThornStego': 'Nature',
    'TempestEagle': 'Storm', 'Raiju': 'Storm', 'ThunderTiger': 'Storm', 'StormNarwhal': 'Storm', 'ZephyrFox': 'Storm',
}
