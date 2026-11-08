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


def cracks(part, cols_from, col, k, glow=True, scale=1.0, width=0.65):
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
        return (col, glow) if ds[1] ** 0.5 - ds[0] ** 0.5 < width else None
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


def rest_behind(part):
    """Turns an orbiting prop a quarter turn about the vertical axis, from
    resting beside the creature (+x) to resting behind it (+y). It circles
    the creature in the game anyway; at rest on one side it widened the
    model on that side only, and the export centres a model on its bounding
    box, which set the legs off the mirror line (CreatureMeshes.spec)."""
    part.v = {(-y - 1, x, z): v for (x, y, z), v in part.v.items()}


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
    """Cracked obsidian drake: glossy black scales split by thin glowing
    lava seams, a long dragon snout with a molten mouth, big bat wings."""
    obs, obs_l = P('#1E1A24'), P('#3A3442')
    plan('drake', c, H, {'col': '#1E1A24', 'belly': '#2C2632', 'accent': '#2C2632', 'glow': '#FF7A1A', 'horn': '#5A4A55',
                         'wing': '#2A2230', 'eye': '#FFB01A'}, kind='drake', wings='none', horns='swept')
    k = H / 10.0
    body = c.part('body')
    (bx0, by0, bz0), (bx1, by1, bz1) = bounds_of(body)
    # big membrane wings, so it reads as a drake from the front too
    km.wing_bat(c, k, (1.4 * k, 0.4 * k, round(bz1 - 0.9 * k)), 5.6, dark(P('#1E1A24'), 0.1), P('#3A1E1E'), glow=P('#FF7A1A'),
                rise=1.8)
    # ember eyes that glow (dark eyes vanish on obsidian), with a hot glint
    eyes = part_or_none(c, 'eyes')
    if eyes:
        top = max(q[2] for q in eyes.v)
        for q, (cc, g) in list(eyes.v.items()):
            eyes.v[q] = (FIRE[3] if cc == WHITE else FIRE[1], True)
    # a longer dragon snout with a glowing mouth line
    head = c.part('head')
    (hx0, hy0, hz0), (hx1, hy1, hz1) = bounds_of(head)
    front = [q for q in head.v if q[1] <= hy0 + 1]
    sz = sum(q[2] for q in front) / max(1, len(front))
    head.ell((0, hy0 - 0.3 * k, sz + 0.1 * k), (0.75 * k, 1.1 * k, 0.6 * k), obs)
    nz = round(sz - 0.35 * k)
    for x in range(-round(0.7 * k), round(0.7 * k)):
        f = head.front(x, nz)
        if f:
            head.put(f, FIRE[1], True)
    for sx in (1, -1):  # nostrils
        f = head.front(round(sx * 0.35 * k) - (1 if sx < 0 else 0), round(sz + 0.25 * k))
        if f:
            head.put(f, FIRE[2], True)
    # glossy obsidian with a lighter sheen on top
    for p in c.parts:
        if p.anim in ('glow', 'blink', 'orbit'):
            continue
        p.paint(lambda q, cc, g: (obs_l, False) if cc == obs and (q[0] * 7 + q[1] * 3 + q[2] * 5) % 13 == 0 else None)
    # thin lava seams between the plates
    for name in ('body', 'tail', 'head', 'wingL', 'wingR', 'legFL', 'legFR', 'legBL', 'legBR'):
        p = part_or_none(c, name)
        if p:
            cracks(p, (obs, obs_l, P('#2C2632'), dark(obs, 0.1)), FIRE[1], k, scale=1.3, width=0.32)
    # a molten tail tip
    tail = c.part('tail')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(tail)
    tip = c.part('tailflame', 'glow')
    for dx in (-0.6 * k, 0, 0.6 * k):
        flame(tip, dx, y1 - 0.5 * k, z1 - 0.6 * k, 1.8 * k, k, w=0.35)
    return c


def sun_scarab(c, H):
    import kit
    LAPIS, LAPIS_L = P('#2A55C8'), P('#4F86F0')
    kit.bug(c, H, 'beetle', LAPIS, GOLD, None)
    k = H / 10.0
    shell = part_or_none(c, 'shell')
    if shell:
        top = max(q[2] for q in shell.v)
        low = min(q[2] for q in shell.v)
        # a lapis shell: a sheen on top, gold flecks and a gold rim
        shell.paint(lambda p, cc, g: (LAPIS_L, False) if cc == LAPIS and p[2] > top - 0.5 * k else None)
        speckle(shell, (LAPIS,), GOLD_L, 11)
        shell.paint(lambda p, cc, g: (GOLD_D, False) if p[2] <= low + 1 else None)
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    hn = c.part('beetlehorn', 'static', head.pivot)
    f = head.front(0, z1 - round(0.3 * k)) or (0, y0, z1)
    horn(hn, (0.0, f[1] + 0.5, f[2]), (0.0, f[1] - 1.0 * k, f[2] + 1.2 * k), 0.4 * k, GOLD_D, GOLD_L, bend=(0, -0.2 * k, 0.3 * k), both=False)
    # the sun it rolls, held between its back legs: an orange orb with a
    # white-hot core and short rays, far brighter than the gold beetle
    body = part_or_none(c, 'shell') or c.part('body')
    (bx0, by0, bz0), (bx1, by1, bz1) = bounds_of(body)
    R = 1.9 * k
    cy, cz = by1 + 0.5 * R, R + 0.15 * k
    sun = c.part('sun', 'glow', (0, cy, cz))
    ORANGE, HOT, CORE = P('#FF7A10'), P('#FFB020'), P('#FFF3C0')
    sun.ell((0, cy, cz), (R, R, R), ORANGE, True)
    sun.paint(lambda p, cc, g: (HOT, True) if (p[0] + .5) ** 2 + (p[1] + .5 - cy - 0.35 * R) ** 2 + (p[2] + .5 - cz - 0.25 * R) ** 2 < (0.75 * R) ** 2 else None)
    sun.paint(lambda p, cc, g: (CORE, True) if (p[0] + .5) ** 2 + (p[1] + .5 - cy - 0.5 * R) ** 2 + (p[2] + .5 - cz - 0.4 * R) ** 2 < (0.45 * R) ** 2 else None)
    for a in range(8):
        ang = a / 8 * math.pi * 2 + math.pi / 8
        dx, dz = math.cos(ang), math.sin(ang)
        if cz + dz * (R + 0.6 * k) < 0.4 * k:
            continue
        shard(sun, (dx * (R - 1), cy, cz + dz * (R - 1)), (dx, 0, dz), 0.6 * k + 1, 0.42 * k, P('#FF5A0A'), P('#FF9A1A'))
    return c


def _split_heads(c, k, col, snout, light_c, turn=25.0):
    """Three heads that read as three: the side heads turn out by `turn`
    degrees about their own pivots, a one-voxel gap parts them from the
    middle head, every muzzle is lighter and each side head gets ears."""
    head, eyes, ears = c.part('head'), c.part('eyes'), part_or_none(c, 'ears')
    # every muzzle a lighter grey so each face reads on its own
    for name in ('head', 'headL', 'headR'):
        hp = part_or_none(c, name)
        if hp:
            hp.paint(lambda p, cc, g: (light_c, False) if cc == snout else None)
    thr = 1.3 * k
    for name, side in (('headR', 1), ('headL', -1)):
        hp = part_or_none(c, name)
        if hp is None:
            continue
        hp.pivot = (hp.pivot[0] + side * round(0.9 * k), hp.pivot[1] - round(0.9 * k), hp.pivot[2])
        # the side head's eyes and a copy of the middle head's ears move with it
        mine = {q: v for q, v in eyes.v.items() if (q[0] + 0.5) * side > thr}
        for q in mine:
            del eyes.v[q]
        extra = {}
        if ears:
            for (x, y, z), v in ears.v.items():
                if x * side >= 0:
                    nx = x * 0.8 + side * 2.3 * k
                    extra[(round(nx), round(y * 0.85 + 0.7 * k + abs(x) * 0.15), round(z - 0.9 * k))] = v
        src = dict(hp.v)
        src.update({q: v for q, v in extra.items() if q not in src})
        src.update(mine)
        px, py = hp.pivot[0], hp.pivot[1]
        a = math.radians(turn * side)
        ca, sa = math.cos(a), math.sin(a)
        xs = [q[0] for q in src]
        ys = [q[1] for q in src]
        zs = sorted({q[2] for q in src})
        pad = round(1.0 * k)
        shift = round(0.9 * k)
        fwd = -round(0.9 * k)
        out = {}
        for x in range(min(xs) - pad, max(xs) + pad + 1):
            for y in range(min(ys) - pad, max(ys) + pad + 1):
                # inverse rotation of the cell centre back into the source
                dx, dy = x + 0.5 - px, y + 0.5 - py
                sx = px + dx * ca + dy * sa - 0.5
                sy = py - dx * sa + dy * ca - 0.5
                q0 = (round(sx), round(sy))
                for z in zs:
                    v = src.get((q0[0], q0[1], z))
                    if v is not None:
                        out[(x + shift * side, y + fwd, z)] = v
        eye_set = {q for q in mine}
        hp.v, new_eyes = {}, {}
        rot_eyes = set()
        for (x, y, z), v in out.items():
            dx, dy = x - shift * side + 0.5 - px, y - fwd + 0.5 - py
            sx = round(px + dx * ca + dy * sa - 0.5)
            sy = round(py - dx * sa + dy * ca - 0.5)
            if (sx, sy, z) in eye_set:
                new_eyes[(x, y, z)] = v
            else:
                hp.v[(x, y, z)] = v
        # the gap: nothing of a side head within one voxel of the middle head
        mid = set(head.v) | {q for q in eyes.v}
        for q in list(hp.v):
            if any((q[0] + dx, q[1] + dy, q[2] + dz) in mid for dx in (-1, 0, 1) for dy in (-1, 0, 1) for dz in (-1, 0, 1)):
                del hp.v[q]
        for q in list(new_eyes):
            if any((q[0] + dx, q[1] + dy, q[2]) in mid for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                del new_eyes[q]
        eyes.v.update(new_eyes)
    # the middle head leads: a touch bigger, three voxels forward and one up,
    # so all three faces show from the front and the hero view; its neck
    # stretches to meet it
    dy, dz = -3, 1
    mid_eyes = {q: v for q, v in eyes.v.items() if abs(q[0] + 0.5) <= thr}
    hx = [q[0] for q in head.v]
    hz = [q[2] for q in head.v]
    hyv = [q[1] for q in head.v]
    cx = (min(hx) + max(hx) + 1) / 2
    cyc = (min(hyv) + max(hyv) + 1) / 2
    czc = (min(hz) + max(hz) + 1) / 2
    sc = 1.1

    def grow(vox):
        out = {}
        xs = [q[0] for q in vox]
        ys = [q[1] for q in vox]
        zs = [q[2] for q in vox]
        for x in range(min(xs) - 2, max(xs) + 3):
            for y in range(min(ys) - 2, max(ys) + 3):
                for z in range(min(zs) - 2, max(zs) + 3):
                    sx = math.floor(cx + (x + 0.5 - cx) / sc)
                    sy = math.floor(cyc + (y + 0.5 - cyc) / sc)
                    sz = math.floor(czc + (z + 0.5 - czc) / sc)
                    v = vox.get((sx, sy, sz))
                    if v is not None:
                        out[(x, y + dy, z + dz)] = v
        return out
    both = dict(head.v)
    both.update(mid_eyes)
    grown = grow(both)
    head.v = {q: v for q, v in grown.items() if v not in mid_eyes.values() or q not in grow(mid_eyes)}
    ge = grow(mid_eyes)
    for q in ge:
        head.v.pop(q, None)
    for q in mid_eyes:
        del eyes.v[q]
    eyes.v.update(ge)
    if ears:
        ears.v = {(x, y + dy, z + dz + 1): v for (x, y, z), v in ears.v.items()}
        ears.pivot = (ears.pivot[0], ears.pivot[1] + dy, ears.pivot[2] + dz)
    head.pivot = (head.pivot[0], head.pivot[1] + dy, head.pivot[2] + dz)
    eyes.pivot = head.pivot
    # the stretched neck under the moved head
    body = c.part('body')
    for t in range(4):
        body.ell((0, -2.6 * k + dy * t / 3, 3.8 * k + 1.3 * k + dz * t / 3), (1.0 * k, 0.9 * k, 1.2 * k), col)
    # side heads must still clear the middle one
    mid = set(head.v) | set(eyes.v)
    for name in ('headL', 'headR'):
        hp = part_or_none(c, name)
        if hp:
            for q in list(hp.v):
                if any((q[0] + a, q[1] + b, q[2] + d) in head.v for a in (-1, 0, 1) for b in (-1, 0, 1) for d in (-1, 0, 1)):
                    del hp.v[q]


def cerberus_pup(c, H):
    plan('beast', c, H, {'col': '#3A3340', 'belly': '#5A5060', 'snout': '#5A5060', 'accent': '#2A2430', 'glow': '#FF7A1A',
                         'eye': '#FF5A1A'}, kind='canine', heads=3, tail='whip')
    k = H / 10.0
    _split_heads(c, k, P('#3A3340'), P('#5A5060'), P('#9A8CA4'))
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
    """A hulking rock golem split by thin lava seams, a molten core in its
    chest and lava pouring from its shoulders, elbows and knees."""
    plan('upright', c, H, {'col': '#3A3438', 'belly': '#4A4248', 'glow': '#FF7A1A', 'eye': '#FFB627'}, kind='golem')
    k = H / 10.0
    rock = (P('#3A3438'), P('#4A4248'), dark(P('#3A3438'), 0.12), dark(P('#3A3438'), 0.2), dark(P('#3A3438'), 0.25),
            dark(P('#3A3438'), 0.3))
    for p in c.parts:
        if p.name not in ('eyes',):
            cracks(p, rock, FIRE[1], k, scale=1.1, width=0.3)
    body = c.part('body')
    # a molten core glowing through the chest plate
    chest = [q for q, (cc, g) in body.v.items() if cc == P('#4A4248')]
    if chest:
        cx = sum(q[0] for q in chest) / len(chest)
        cz = sum(q[2] for q in chest) / len(chest)
        y0 = min(q[1] for q in chest)
        body.paint(lambda q, cc, g: ((FIRE[2] if (q[0] + .5 - cx) ** 2 + (q[2] - cz) ** 2 < (0.45 * k) ** 2 else FIRE[1]), True)
                   if q[1] <= y0 + 1 and (q[0] + .5 - cx) ** 2 + (q[2] - cz) ** 2 < (0.85 * k) ** 2 else None)
    # lava pouring from every joint: a glowing stream down the rock face
    # below it, and fat drips hanging 2-3 voxels under the nearest ledge,
    # orange fading to dark red
    owner = {}
    for p in [body] + [q for q in c.parts if q.name.startswith('leg')]:
        for q in p.v:
            owner[q] = p
    solid = set()
    for p in c.parts:
        solid |= set(p.v)
    drips = c.part('drips', 'glow')
    for (jx, jy, jz) in getattr(c, 'joints', []):
        x = round(jx) - (1 if jx < 0 else 0)
        for z in range(round(jz), max(0, round(jz - 1.0 * k)), -1):
            for xx in (x, x + (1 if jx >= 0 else -1)):
                col_ys = [q[1] for q in owner if q[0] == xx and q[2] == z]
                if col_ys:
                    f = (xx, min(col_ys), z)
                    owner[f].v[f] = (FIRE[1] if z > jz - 0.6 * k else FIRE[2], True)
        # the nearest underside (a rock voxel with air below it) near the joint
        cands = [q for q in owner if abs(q[0] - jx) <= 2 and abs(q[1] - jy) <= 3 and q[2] <= jz + 2 and q[2] >= 4
                 and (q[0], q[1], q[2] - 1) not in solid]
        cands.sort(key=lambda q: (abs(q[2] - jz) + abs(q[1] - jy), q[1]))
        used = set()
        for q in cands:
            if len(used) >= 2 or any(abs(q[0] - u[0]) < 2 and abs(q[1] - u[1]) < 2 for u in used):
                continue
            used.add(q)
            owner[q].v[q] = (FIRE[1], True)
            n = 3 if len(used) == 1 else 2
            for i in range(1, n + 1):
                t = (q[0], q[1], q[2] - i)
                if t in solid or t[2] < 1:
                    break
                drips.put(t, (FIRE[1], FIRE[0], P('#8A1010'))[min(2, i - 1)], True)
    return c


def blaze_rhino(c, H):
    plan('beast', c, H, {'col': '#6E6268', 'belly': '#8A7E84', 'snout': '#8A7E84', 'horn': '#E8D8C8', 'glow': '#FF8A1A',
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
    # ember veins glowing through the hide (legs and flanks, below the plates)
    for name in ('body', 'legFL', 'legFR', 'legBL', 'legBR', 'head'):
        p = part_or_none(c, name)
        if p:
            cracks(p, (P('#6E6268'),), FIRE[1], k, scale=1.4, width=0.28)
    # the horn itself glows molten, darkest at the root and white-hot near the tip
    hp.paint(lambda q, cc, g: (FIRE[min(3, int((q[2] - z0) / max(1, z1 - z0 + 1) * 3.2))], True))
    fl = c.part('hornflame', 'glow')
    flame(fl, 0, y0 + 0.4 * k, z1 + 1, 3.0 * k, k, w=0.75)
    for sx in (1, -1):  # smaller tongues licking up either side
        flame(fl, sx * 0.5 * k, y0 + 0.9 * k, z1 - 0.2 * k, 1.6 * k, k, w=0.4)
    return c


def golden_sphinx(c, H):
    plan('beast', c, H, {'col': '#F2C14E', 'belly': '#FFE3A0', 'snout': '#FFE3A0', 'accent': '#E8A21A', 'glow': '#4FD8FF',
                         'wing': '#FFC21A'}, kind='cat', tail='lion', wings='feather')
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
    if f:  # a ruby set in gold on the headdress band, above the brow
        jz = z1 + 1
        jy = min(q[1] for q in nemes.v if q[2] == jz) - 1 if any(q[2] == jz for q in nemes.v) else f[1]
        for (dx, dz) in ((0, 0), (-1, 0), (0, -1), (-1, -1), (0, 1), (-1, 1), (1, 0), (-2, 0)):
            rim = dx in (1, -2) or dz != 0 and False
            nemes.put((dx, jy, jz + dz), GOLD if dx in (1, -2) else P('#E8102E'), dx not in (1, -2))
        nemes.put((0, jy - 1, jz + 1), WHITE, True)
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
        if z == zb + 1:
            for i in range(round(0.5 * k) - (1 if (x * 3 + y * 7) % 4 == 0 else 0)):
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
    # big ice tusks sweeping forward, down and up again, glowing from the
    # middle out to the tips
    drop(c, 'tusks')
    tusks = c.part('tusks', 'glow', (0, y0, z0))
    for side in (1, -1):
        pts = []
        for i in range(26):
            s = i / 25
            a = s * math.pi * 0.95
            pts.append((side * (0.85 * k + 0.9 * k * s), y0 + 0.4 * k - math.sin(a) * 1.7 * k - s * 0.6 * k,
                        z0 + 0.6 * k - math.sin(a) * 1.0 * k + s * s * 2.2 * k, max(0.7, 0.44 * k * (1 - 0.6 * s))))
        if side < 0:
            pts = [(x - 0.5, y, z, r) for (x, y, z, r) in pts]
        sweep(tusks, pts, lambda s: ICE_L if s < 0.3 else (ICE if s < 0.7 else P('#4FD0FF')), lambda s: s > 0.45)
    # a thick snow drift over the back with lumps, and glowing frost crystals
    body.paint(lambda p, cc, g: (P('#F4FBFF'), False) if p[2] >= max(q[2] for q in body.v if q[0] == p[0] and q[1] == p[1]) - 2 and p[2] > 4.2 * k else None)
    cr = c.part('frost', 'glow')
    for (x, y, h, lx, ly) in ((0.9, -0.8, 1.6, 0.15, -0.1), (-1.1, 0.6, 1.9, -0.18, 0.05), (0.6, 1.8, 1.4, 0.12, 0.15),
                              (0.1, 0.4, 2.2, 0.0, 0.0)):
        t = top_of(body, round(x * k), round(y * k))
        if t is not None:
            crystal(cr, round(x * k), round(y * k), t, h * k, 0.45 * k, P('#4FC8FF'), ICE_L, lean=(lx, ly))
    return c


def glacier_orca(c, H):
    """An orca carved from glacier ice: a deep navy back, a pale ice belly and
    eye patches, faceted tones, and a fanning plume of frost from the
    blowhole."""
    navy, ice_w = P('#18264A'), P('#D8F4FF')
    plan('whale', c, H, {'col': '#18264A', 'belly': '#CDEFFF', 'glow': '#7FE0FF'}, kind='orca')
    k = H / 10.0 * 1.1
    for p in c.parts:
        p.paint(lambda q, cc, g: (ice_w, False) if cc == WHITE else None)
        p.paint(lambda q, cc, g: (P('#9FB4D0'), False) if cc == P('#C8D0E0') else None)
        # ice facets: a scatter of lighter and darker tones
        speckle(p, (navy,), P('#26385E'), 5)
        speckle(p, (navy,), P('#33507E'), 11)
        speckle(p, (P('#CDEFFF'), ice_w), P('#B0E4FA'), 6)
    # the frost plume: a fan of ice shards and frost bursting from the blowhole
    body = c.part('body')
    ys = [p[1] for p in body.v]
    y = round(min(ys) + (max(ys) - min(ys)) * 0.25)
    near = [q for q in body.v if abs(q[1] - y) <= 1 and -1 <= q[0] <= 0]
    x, y, t = max(near, key=lambda q: q[2]) if near else (0, y, round(5 * k))
    spout = c.part('spout', 'glow', (x, y, t))
    for i in range(round(0.6 * k)):
        spout.box((x - 1, y - 1, t + i), (x, y, t + i), P('#BFF4FF'), True)
    top = t + round(0.6 * k)
    for j, (dx, dy, ln) in enumerate(((0, 0, 2.0), (0.8, 0.2, 1.6), (-0.8, 0.2, 1.6), (0.45, -0.6, 1.5), (-0.45, -0.6, 1.5),
                                      (0.5, 0.8, 1.3), (-0.5, 0.8, 1.3))):
        start = (x + .5 - 0.5, y + .5 - 0.5, top)
        col = P('#5FE0FF') if j % 2 == 0 else P('#E6FBFF')
        ln *= 1.5
        shard(spout, start, (dx, dy, 1.0), ln * k, 0.36 * k, col, P('#9FEFFF'), glow=j % 2 == 0)
        dl = math.sqrt(dx * dx + dy * dy + 1)
        tip = (start[0] + dx / dl * ln * k, start[1] + dy / dl * ln * k, start[2] + ln * k / dl)
        spout.ell(tip, (0.3 * k, 0.3 * k, 0.3 * k), P('#BFF4FF'), True)
    # icy fin edges
    for name in ('dorsal', 'finL', 'finR'):
        p = part_or_none(c, name)
        if p:
            (x0, y0, z0), (x1, y1, z1) = bounds_of(p)
            p.paint(lambda q, cc, g: (P('#7FE0FF'), True) if q[2] == (z1 if name == 'dorsal' else z0) else None)
    return c


def blizzard_owl(c, H):
    snow, grey = P('#F4FBFF'), P('#C8D6E8')
    k, lift = grand_bird(c, H, snow, P('#FFFFFF'), P('#3A3A4A'), snow, (snow, P('#B8DCFF'), P('#6AB8F0')), P('#2EA8FF'),
                         feet=P('#E6EEF8'), tuft=True, crest=None)
    for p in c.parts:  # a snowy owl's dark bars
        speckle(p, (snow,), P('#7A8AA8'), 7)
    c.part('eyes').paint(lambda p, cc, g: (P('#FFC21A'), True) if cc == INK else None)
    # a swirling blizzard ring round it, with snowflakes
    sw = orbit_part(c, 'blizzard', (0, 0.6 * k, 4.6 * k + lift))
    ring(sw, 0, 0.6 * k, 3.6 * k + lift, 4.4 * k, P('#2EA8FF'), True, thick=0.95, tilt=0.18)
    for a in range(6):
        ang = a / 6 * math.pi * 2
        star(sw, math.cos(ang) * 4.4 * k, 0.6 * k + math.sin(ang) * 4.4 * k, 3.6 * k + lift + math.sin(ang) * 4.4 * k * 0.18 + 1,
             max(1, round(0.3 * k)), ICE, True, plane='xy')
    return c


def frost_giant(c, H):
    plan('upright', c, H, {'col': '#DCEBFA', 'belly': '#FFFFFF', 'glow': '#2EA8FF', 'eye': '#2E5AC8'}, kind='giant')
    k = H / 10.0
    body = c.part('body')
    # ice armour: plates on the chest and shoulders
    armour = c.part('armour', 'static')
    for (x, y, z) in list(body.v):
        if y < -1.2 * k and 3.6 * k < z < 5.0 * k and (x + 100) % 3 != 0 and abs(x + .5) < 1.8 * k:
            armour.put((x, y - 1, z), (P('#4FC8FF'), True) [0] if z % 4 == 0 else P('#3A7AD8'), z % 4 == 0)
    # ice pauldrons capping the shoulders (down at shoulder height, clear
    # of the head)
    for side in (1, -1):
        cx = side * 2.5 * k - (0.5 if side < 0 else 0)
        armour.ell((cx, 0, 6.0 * k), (1.0 * k, 1.05 * k, 0.55 * k), P('#3A7AD8'), cond=lambda x, y, z: z >= round(5.7 * k))
        armour.ell((cx, 0, 6.15 * k), (0.55 * k, 0.6 * k, 0.6), P('#4FC8FF'), True)
    # the icicle beard: five icicles hanging from the chin, in front of the chest
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    beard = c.part('beard', 'glow', (0, y0, z0))
    # start at the lowest face row that stands in front of the chest
    cz = round(z0 + 0.35 * k)
    for z in range(z0, z1):
        hf, bf = head.front(0, z), body.front(0, z)
        if hf and (bf is None or hf[1] < bf[1]):
            cz = z + 1
            break
    icicles = [((-1, 0), 1.9)]  # (cells across, length in k): the middle one, then mirrored pairs
    for xi, ln in ((2, 1.6), (5, 1.2)):
        icicles += [((xi, xi + 1), ln), ((-xi - 2, -xi - 1), ln)]
    for cells, ln in icicles:
        f = head.front(cells[0], cz) or head.front(cells[1], cz)
        if not f:
            continue
        n = round(ln * k)
        for j in range(n):
            s2 = j / max(1, n - 1)
            col = P('#2EA8FF') if s2 > 0.7 else P('#6FC8F4')
            inner = cells[0] if cells[0] >= 0 else cells[1]
            for xx in (cells if s2 < 0.5 or cells == (-1, 0) else (inner,)):
                beard.put((xx, f[1] - 1, cz - j), col, s2 > 0.7)
    # an ice crown of spikes
    cr = c.part('icecrown', 'glow')
    for a in range(5):
        x = (a - 2) * 0.55 * k
        crystal(cr, x, (y0 + y1) / 2, z1 + 1, (1.0 + 0.5 * (a == 2)) * k, 0.3 * k, P('#2EA8FF'), P('#BFF0FF'))
    return c


def frost_saber(c, H):
    plan('beast', c, H, {'col': '#C8DDF0', 'belly': '#F4FBFF', 'snout': '#9CC0E8', 'accent': '#2E5A9A', 'horn': '#BFF4FF',
                         'glow': '#2EA8FF', 'eye': '#2E5AC8'}, kind='cat', tail='lion', saber=True, stripes=True)
    k = H / 10.0
    # two long ice fangs from the mouth corners, well past the jaw line:
    # two voxels wide at the root, a glowing point at the tip
    fangs = c.part('fangs')
    fangs.anim = 'static'
    fangs.v = {}
    head = c.part('head')
    # a clean face (the stripes stay on the body and tail), so the fangs read
    head.paint(lambda p, cc, g: (P('#C8DDF0'), False) if g and cc == P('#2EA8FF') else None)
    # two white fangs, two voxels wide, rooted in the upper lip and hanging
    # five voxels below it, one voxel in front of the chin, glowing cyan tips
    xi = round(0.3 * k)
    for cells in ((xi, xi + 1), (-xi - 2, -xi - 1)):
        inner = cells[0] if cells[0] >= 0 else cells[1]
        col_v = [q for q in head.v if q[0] == inner]
        if not col_v:
            continue
        # the jaw line at this column: the lowest voxel among the front ones
        yf = min(q[1] for q in col_v)
        front = [q for q in col_v if q[1] <= yf + 1]
        zb = min(q[2] for q in front)
        yb = min(q[1] for q in front if q[2] == zb)
        # one voxel forward of the whole chin front, so the fangs stand clear
        # of the face and chest: a root at the lip, then five voxels below it
        chin = [q[1] for q in head.v if q[0] in cells and zb - 5 <= q[2] <= zb + 1]
        yfw = (min(chin) if chin else yb) - 1
        for xx in cells:  # the root, set into the lip so the fang hangs from it
            for yy in range(yfw + 1, yb + 1):
                head.v.pop((xx, yy, zb + 1), None)
                fangs.put((xx, yy, zb + 1), P('#F4FAFF'))
        for i, z in enumerate(range(zb + 1, zb - 5, -1)):
            tip = i >= 4
            for xx in cells:
                fangs.put((xx, yfw, z), P('#2EA8FF') if tip else P('#F4FAFF'), tip)
        mouth_z, mouth_y = zb + 1, yb
    # a dark mouth line between the fangs, so they read as coming from the jaw
    for x in range(-xi, xi):
        col_v = [q for q in head.v if q[0] == x and q[2] == mouth_z]
        if col_v:
            f = min(col_v, key=lambda q: q[1])
            head.v[f] = (P('#2E3A5A'), False)
    # no glowing stripes on the neck and chest front: the fangs hang there
    body = c.part('body')
    body.paint(lambda p, cc, g: (P('#C8DDF0'), False) if g and p[1] < -1.6 * k else None)
    # frost spikes along the spine
    sp = c.part('frost', 'glow')
    for y in range(round(-1.4 * k), round(3.2 * k), max(2, round(0.9 * k))):
        t = top_of(body, 0, y)
        if t is not None:
            crystal(sp, -0.5, y, t + 1, 1.1 * k, 0.35 * k, P('#2EA8FF'), P('#BFF0FF'), lean=(0, 0.25))
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
    plan('drake', c, H, {'col': '#4A8FE0', 'belly': '#DFF4FF', 'accent': '#2A5FB0', 'glow': '#4FD0FF', 'horn': '#E6FBFF',
                         'wing': '#2A5FB0'}, kind='wyvern', wings='bat', horns='swept')
    k = H / 10.0
    # icicles hanging from the right wing's lower edge, then the left wing
    # rebuilt as its exact mirror (the rig check wants matching wings)
    w = c.part('wingR')
    lows = {}
    for (x, y, z) in w.v:
        if (x, y) not in lows or z < lows[(x, y)]:
            lows[(x, y)] = z
    for (x, y), z in lows.items():
        if x % 2 == 0 and y == min(yy for (xx, yy) in lows if xx == x):
            n = round(0.5 * k) + (abs(x) * 7) % max(2, round(0.9 * k))
            for i in range(n):
                w.put((x, y, z - 1 - i), ICE_L if i >= n - 2 else P('#4FC8FF'), True)
    wl = c.part('wingL')
    wl.v = {(-1 - x, y, z): v for (x, y, z), v in w.v.items()}
    wl.pivot = (-w.pivot[0], w.pivot[1], w.pivot[2])
    # ice shards along the spine
    body = c.part('body')
    (bx0, by0, bz0), (bx1, by1, bz1) = bounds_of(body)
    sh = c.part('shards', 'glow')
    for i in range(5):
        y = by0 + (by1 - by0) * (0.15 + 0.17 * i)
        t = top_of(body, 0, round(y))
        if t is not None:
            crystal(sh, 0, round(y), t, (1.4 - 0.15 * i) * k, 0.4 * k, P('#4FC8FF'), ICE_L, lean=(0, 0.15))
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
        key = (x // max(2, round(1.4 * k)), y // max(2, round(1.4 * k)))
        if key in seen:
            continue
        seen.add(key)
        petal = (P('#FF5FA0'), P('#FFD400'), P('#A86AFF'))[len(seen) % 3]
        flower(fl, x, y, z + 1, k * 1.3, petal=petal, heart=GOLD, glow=True)
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
    """Jade qilin with gold scales, golden antlers and a big flowing
    cherry-blossom mane; its hooves burn with soft pink flame."""
    jade, jade_d = P('#5CC8A0'), P('#3A9A7A')
    pink, pink_d, pink_g = P('#FFB3D1'), P('#FF8AB8'), P('#FF4FA0')
    plan('beast', c, H, {'col': '#5CC8A0', 'belly': '#DFF7EA', 'snout': '#DFF7EA', 'accent': '#FF8AB8', 'horn': '#FFC21A',
                         'glow': '#FFE27A'}, kind='hoof', horns='antlers', mane='crest', tail='bushy')
    k = H / 10.0
    body = c.part('body')
    # gold-edged scales over the back and flanks
    body.paint(lambda p, cc, g: ((GOLD if (p[0] + 2 * p[1] + 3 * p[2]) % 5 == 0 else jade_d), False)
               if cc == jade and p[2] > 3.9 * k and (p[0] + p[1] + p[2]) % 2 == 0 else None)
    head = c.part('head')
    (hx0, hy0, hz0), (hx1, hy1, hz1) = bounds_of(head)
    (bx0, by0, bz0), (bx1, by1, bz1) = bounds_of(body)
    # the cherry-blossom mane: big pink locks from the crown, down the neck
    # and along the spine, studded with blossoms whose hearts glow
    drop(c, 'mane')
    m = c.part('mane', 'static')
    for i in range(18):
        s = i / 17
        y = hy0 + (hy1 - hy0) * 0.55 + s * (by1 - hy0 - 1.2 * k)
        z = hz1 - 0.1 * k - s * (hz1 - bz1 + 0.4 * k)
        r = 0.95 * k * (1 - 0.35 * s)
        m.ell((0, y, z), (r * 0.9, r * 0.75, r * 0.85), pink if i % 3 else pink_d)
        for sx in (1, -1):  # locks falling to either side
            m.ell((sx * r * 0.75, y + 0.2 * k, z - 0.55 * k), (0.45 * k, 0.45 * k, 0.75 * k), pink_d)
    tops = {}
    for (x, y, z) in m.v:
        if z > tops.get((x, y), -99):
            tops[(x, y)] = z
    for n, ((x, y), z) in enumerate(sorted(tops.items(), key=lambda t: (t[0][1], t[0][0]))):
        if n % 19 == 0:
            flower(m, x, y, z + 1, k * 0.6, petal=P('#FFE3EF'), heart=pink_g, glow=False)
    m.paint(lambda q, cc, g: (pink_g, True) if cc == pink_g else None)
    # a blossom-tufted tail
    tail = part_or_none(c, 'tail')
    if tail:
        tail.paint(lambda q, cc, g: (pink, False) if not g else None)
        (tx0, ty0, tz0), (tx1, ty1, tz1) = bounds_of(tail)
        flower(tail, 0, ty1 - 0.4 * k, tz1, k * 0.7, petal=P('#FFE3EF'), heart=pink_g, glow=True)
    # pink flame curling round each hoof
    for name in ('legFL', 'legFR', 'legBL', 'legBR'):
        leg = part_or_none(c, name)
        if not leg:
            continue
        (lx0, ly0, lz0), (lx1, ly1, lz1) = bounds_of(leg)
        cx, cy = (lx0 + lx1) / 2 + 0.5, (ly0 + ly1) / 2 + 0.5
        for dz, r in ((0, 0.75), (1, 0.7), (2, 0.55)):
            leg.ell((cx, cy, lz0 + 0.4 * k + dz), (r * k, r * k, 0.6), pink_g if dz < 2 else pink, True)
    return c


def elder_treant(c, H):
    """A walking tree: a bark trunk for a body with grooves running up it,
    a face carved into the upper trunk (deep-set glowing eyes under a heavy
    brow, a knot for a mouth), branch arms ending in twigs and leaves, and
    root feet; the canopy and its nest on top."""
    import rig
    from voxkit import Part
    bark, barkD, barkL, groove = P('#7A5232'), P('#5A3A22'), P('#9A6E46'), P('#3E2614')
    MOSS = P('#5CC83A')
    k = H / 10.0 * 0.87  # the canopy adds height: keep it level with the other tall Legendaries
    top = 1.8 * k  # hip height
    # root feet: a stump each, with three roots spreading over the ground
    for side in ('R', 'L'):
        sx = 1 if side == 'R' else -1
        hipx = 1.05 * k
        tmp = Part('tmp')
        for z in range(0, round(top) + 1):
            r = 0.8 * k + max(0.0, 0.35 * k * (1 - z / (0.5 * top)))
            tmp.ell((hipx, 0.2 * k, z + .5), (r, r * 0.9, 0.5), barkD if z < 0.25 * k else bark)
        for (dx, dy) in ((0.15, -1.0), (0.8, -0.55), (0.8, 0.6)):
            rod(tmp, (hipx + dx * 0.5 * k, 0.2 * k + dy * 0.5 * k, 0.7 * k), (hipx + dx * 1.35 * k, 0.2 * k + dy * 1.35 * k, 0.5),
                0.38 * k, barkD)
        leg = rig.leg_part(c, side, 0, 1, (sx * hipx, 0.2 * k, top + 1))
        for (x, y, z), v in tmp.v.items():
            leg.v[(x if sx > 0 else -1 - x, y, z)] = v
    # the trunk
    body = c.part('body')
    neck = 5.7 * k
    for z in range(round(top - 0.4 * k), round(neck) + 1):
        t = (z - top) / (neck - top)
        r = 1.75 * k - 0.25 * k * t + max(0.0, 0.3 * k * (1 - t * 4))
        body.ell((0, 0, z + .5), (r, r * 0.86, 0.5), bark)
    # branch arms from the shoulders, forking into twigs with leaf tufts
    arm = Part('arm')
    sh = (1.4 * k, 0.0, neck - 0.6 * k)
    elbow = (2.55 * k, -0.35 * k, neck - 1.9 * k)
    rod(arm, sh, elbow, 0.55 * k, bark)
    for (end, r) in (((3.25 * k, -0.6 * k, neck - 0.7 * k), 0.38 * k), ((3.05 * k, -0.7 * k, neck - 3.2 * k), 0.36 * k),
                     ((2.3 * k, -1.2 * k, neck - 3.0 * k), 0.3 * k)):
        rod(arm, elbow, end, r, barkD)
        arm.ell((end[0], end[1], end[2] + 0.25 * k), (0.55 * k, 0.55 * k, 0.45 * k), LEAF)
        arm.put((math.floor(end[0]), math.floor(end[1]) - 1, math.floor(end[2] + 0.25 * k)), BLOSSOM)
    for (x, y, z), v in arm.v.items():
        body.v[(x, y, z)] = v
        body.v[(-1 - x, y, z)] = v
    # the head: the upper trunk, a little broader, with the face carved in
    head = c.part('head', 'head', (0, 0, neck))
    htop = neck + 2.6 * k
    for z in range(round(neck) - 1, round(htop) + 1):
        t = (z - neck) / (htop - neck)
        r = 1.6 * k - 0.15 * k * t
        if t > 0.85:
            r -= (t - 0.85) * 2.5 * k
        head.ell((0, 0, z + .5), (r, r * 0.86, 0.5), bark)
    # bark grooves: wavy vertical seams round trunk and head, and a few knots
    def grooves(p, cc, g):
        if cc != bark:
            return None
        ang = math.atan2(p[1] + .5, p[0] + .5)
        u = ang / (2 * math.pi) * 14 + math.sin(p[2] / (0.9 * k)) * 0.35
        f = u - math.floor(u)
        if f < 0.13:
            return (groove, False)
        if f < 0.24:
            return (barkD, False)
        return None
    body.paint(grooves)
    head.paint(grooves)
    ez = round(neck + 1.35 * k)
    es = max(2, round(0.45 * k))
    ex = max(2, round(0.42 * k))
    eyes = c.part('eyes', 'blink', head.pivot)
    for sx in (1, -1):
        for dx in range(es):
            x = ex + dx if sx > 0 else -(ex + dx) - 1
            for dz in range(es):
                f = head.front(x, ez + dz)
                if not f:
                    continue
                # carve two voxels deep: the eye sits at the back of the socket
                del head.v[f]
                back = (f[0], f[1] + 1, f[2])
                head.v.pop(back, None)
                glint = dz == es - 1 and dx == (0 if sx > 0 else es - 1)
                eyes.put((f[0], f[1] + 2, f[2]), P('#B8FF6A') if glint else P('#4FD02A'), True)
                head.put((f[0], f[1] + 3, f[2]), groove)
        # the heavy brow: a ledge of dark bark over the socket, higher outside
        for dx in range(-1, es + 1):
            x = ex + dx if sx > 0 else -(ex + dx) - 1
            zz = ez + es + (1 if dx >= es - 1 else 0)
            f = head.front(x, zz)
            if f:
                head.put((f[0], f[1] - 1, f[2]), barkD)
                head.put(f, barkD)
    # the mouth: a dark knot hole ringed by a raised lip of pale bark
    mz = round(neck + 0.45 * k)
    mw = max(2, round(0.45 * k))
    for x in range(-mw - 1, mw + 1):
        for dz in (-1, 0, 1, 2):
            f = head.front(x, mz + dz)
            if not f:
                continue
            inner = -mw <= x < mw and dz in (0, 1)
            if inner:
                del head.v[f]
                head.put((f[0], f[1] + 1, f[2]), groove)
            elif not ((x in (-mw - 1, mw)) and dz in (-1, 2)):
                head.put((f[0], f[1] - 1, f[2]), barkL)
    # moss on the root tips, glowing
    for name in ('legL', 'legR'):
        lp = part_or_none(c, name)
        if lp:
            lp.paint(lambda q, cc, g: (MOSS, True) if q[2] <= 1 and cc == barkD and (q[0] * 3 + q[1]) % 5 == 0 else None)
    c.gait_hint = 'waddle'
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
    return c


def mushroom_king(c, H):
    plan('upright', c, H, {'col': '#E84855', 'belly': '#FFF1DC', 'accent': '#FFFFFF', 'glow': '#FFE14D'}, kind='mushroom',
         hat='crown')
    k = H / 10.0
    cap = c.part('cap')
    # lift the rim two voxels outside the face, so the face shows from the
    # hero angle
    head = c.part('head')
    foot = {(x, y) for (x, y, z) in head.v}
    zmin = min(q[2] for q in cap.v)
    for q in [q for q in cap.v if q[2] <= zmin + 1 and (q[0], q[1]) not in foot]:
        del cap.v[q]
    zmin = min(q[2] for q in cap.v if (q[0], q[1]) not in foot)
    cap.paint(lambda p, cc, g: (dark(P('#E84855'), 0.25), False) if p[2] == zmin and not g else None)
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
    # an open lotus: broad petals lying outward round the stem, glowing pink
    for ring_i, (r, ln, col) in enumerate(((1.0, 1.5, P('#FF6FAE')), (0.6, 1.1, P('#FFB3D1')))):
        for a in range(8 if ring_i == 0 else 6):
            ang = a / (8 if ring_i == 0 else 6) * math.pi * 2 + ring_i * 0.4
            for st in range(round(ln * k)):
                d = r * k + st
                w = 0.5 * k * math.sin((st + 1) / (ln * k + 1) * math.pi)
                px, py = math.cos(ang) * d, 0.2 * k + math.sin(ang) * d
                lot.ell((px, py, 1.5 + st * (0.45 if ring_i else 0.3)), (max(0.6, w), max(0.6, w), 0.6),
                        col if st < ln * k - 2 else P('#FFE3EF'), True)
    # a stem joins the lotus to the fish's belly so nothing floats loose
    for z in range(1, zb + 1):
        lot.put((0, round(0.2 * k), z), P('#2E8A3E'))
        lot.put((-1, round(0.2 * k), z), P('#2E8A3E'))
    return c


def mantis_queen(c, H):
    """An orchid mantis queen: a wide petal-pink abdomen low behind, a slim
    thorax rising to a triangular head with big bulging side eyes, the two
    raptorial forelegs folded up in front (the praying pose), four walking
    legs with petal lobes, and the crown of crystal petals."""
    import rig
    from voxkit import Part
    k = H / 10.0
    pink, petal, rim, deep = P('#FFC8E0'), P('#FFE6F2'), P('#FF8FBF'), P('#E86AA8')
    body = c.part('body')
    # abdomen: wide and low, tipped up at the back, banded
    for i in range(13):
        s2 = i / 12
        y = 0.4 * k + s2 * 3.4 * k
        z = 2.6 * k + s2 * 0.9 * k
        r = (0.75 + 0.75 * math.sin(min(1.0, s2 * 1.25) * math.pi * 0.9)) * k
        body.ell((0, y, z), (r * 1.05, 0.7 * k, r * 0.62), pink)
    body.paint(lambda q, cc, g: (rim, False) if cc == pink and q[1] > 0.9 * k and (q[1] % max(2, round(0.7 * k))) == 0 else None)
    # petal lobes on the abdomen's sides, as the orchid mantis has
    for side in (1, -1):
        for (y, z) in ((1.6 * k, 3.0 * k), (2.8 * k, 3.4 * k)):
            body.ell((side * 1.35 * k - (0.5 if side < 0 else 0), y, z), (0.55 * k, 0.75 * k, 0.28 * k), petal)
    # the slim thorax rising up and forward
    rod(body, (0, 0.6 * k, 2.8 * k), (0, -0.9 * k, 5.7 * k), 0.55 * k, pink)
    body.ell((0, 0.3 * k, 3.0 * k), (0.8 * k, 0.9 * k, 0.75 * k), pink)
    # the raptorial forelegs, folded up in front of the chest: coxa down,
    # femur back up with spines, tibia folded down against it
    arms = Part('arms')
    sh = (0.55 * k, -1.0 * k, 5.0 * k)
    knee = (0.75 * k, -2.1 * k, 4.1 * k)
    wrist = (0.75 * k, -2.7 * k, 5.9 * k)
    claw = (0.7 * k, -2.25 * k, 4.6 * k)
    rod(arms, sh, knee, 0.24 * k, pink)
    rod(arms, knee, wrist, 0.3 * k, deep)  # the big raptorial femur
    rod(arms, wrist, claw, 0.7, rim)
    for t in (0.3, 0.55, 0.8):  # spines along the femur
        p0 = tuple(knee[j] + (wrist[j] - knee[j]) * t for j in range(3))
        arms.put((math.floor(p0[0]), math.floor(p0[1]) + 2, math.floor(p0[2])), petal)
    for (x, y, z), v in arms.v.items():
        body.v[(x, y, z)] = v
        body.v[(-1 - x, y, z)] = v
    # four thin walking legs splayed wide, knees high, a petal lobe on each thigh
    for i, ly in enumerate((0.1 * k, 1.4 * k)):
        tmp = Part('tmp')
        hip = (0.6 * k, ly, 2.7 * k)
        knee2 = (2.1 * k, ly + (-0.5 if i == 0 else 0.6) * k, 3.9 * k)
        foot = (3.3 * k, ly + (-1.4 if i == 0 else 1.6) * k, 0.4)
        rod(tmp, hip, knee2, 0.75, pink)
        rod(tmp, knee2, foot, 0.7, rim)
        tmp.ell(tuple(hip[j] + (knee2[j] - hip[j]) * 0.55 for j in range(3)), (0.5 * k, 0.4 * k, 0.6), petal)
        for side in ('R', 'L'):
            sx = 1 if side == 'R' else -1
            lp = rig.leg_part(c, side, i, 2, (sx * hip[0], hip[1], hip[2] + 1))
            for (x, y, z), v in tmp.v.items():
                lp.v[(x if sx > 0 else -1 - x, y, z)] = v
    # hinge each leg at its inner end, outside the body (after the body is
    # drawn, voxels inside it belong to the body)
    for name in ('legFL', 'legFR', 'legBL', 'legBR'):
        lp = part_or_none(c, name)
        if lp:
            for q in [q for q in lp.v if q in body.v]:
                del lp.v[q]
            sx = 1 if name.endswith('R') else -1
            inner = min(lp.v, key=lambda q: abs(q[0] + 0.5))
            lp.pivot = (inner[0] + (0 if sx > 0 else 1), inner[1] + 0.5, inner[2] + 1)
    # the triangular head: wide at the top, coming to a point at the mouth
    head = c.part('head', 'head', (0, -1.0 * k, 5.7 * k))
    hz0, hz1 = 5.6 * k, 7.3 * k
    for z in range(round(hz0), round(hz1) + 1):
        t = (z - hz0) / (hz1 - hz0)
        w = 0.35 * k + 1.0 * k * t
        head.ell((0, -1.3 * k, z + .5), (w, 0.55 * k, 0.5), pink)
    f = head.front(0, round(hz0) + 1)
    if f:
        head.put((f[0], f[1] - 1, f[2]), deep)
        head.put((-1 - f[0], f[1] - 1, f[2]), deep)
    # big bulging eyes on the head's top corners, each with a glint
    eyes = c.part('eyes', 'blink', head.pivot)
    er = 0.58 * k
    for side in (1, -1):
        ex = side * 1.3 * k - (0.5 if side < 0 else 0)
        tmp = Part('e')
        tmp.ell((1.3 * k, -1.35 * k, hz1 - 0.2 * k), (er, er, er), P('#B0207A'))
        for (x, y, z), v in tmp.v.items():
            xx = x if side > 0 else -1 - x
            eyes.put((xx, y, z), v[0])
        gx = math.floor(1.3 * k) if side > 0 else -1 - math.floor(1.3 * k)
        gf = min((q for q in eyes.v if q[0] == gx and q[2] == math.floor(hz1)), key=lambda q: q[1], default=None)
        if gf:
            eyes.put(gf, WHITE)
    # antennae
    for side in (1, -1):
        pts = curve((0.3 * k, -1.6 * k, hz1), (1.1 * k, -2.6 * k, hz1 + 1.6 * k), 8, (0, 0, 0.4 * k))
        for (x, y, z) in pts:
            xx = math.floor(x) if side > 0 else -1 - math.floor(x)
            head.put((xx, math.floor(y), math.floor(z)), rim)
    # the crown of crystal petals
    cr = c.part('crown', 'glow', (0, -1.3 * k, hz1))
    cx, cy = 0.0, -1.3 * k
    t = top_of(head, 0, math.floor(cy)) or round(hz1)
    cr.ell((cx, cy, t + 0.5), (0.85 * k, 0.6 * k, 0.6), GOLD, True)
    cr.ell((cx, cy, t + 1.5), (0.75 * k, 0.5 * k, 0.6), GOLD_D, False)
    for a in range(6):
        ang = a / 6 * math.pi * 2
        crystal(cr, cx + math.cos(ang) * 0.6 * k, cy + math.sin(ang) * 0.4 * k, t + 2, 1.1 * k, 0.36 * k, P('#FF3D9A'), P('#FF7AC8'),
                lean=(math.cos(ang) * 0.35, math.sin(ang) * 0.25))
    c.gait_hint = 'trot'
    return c


def thorn_stego(c, H):
    plan('dino', c, H, {'col': '#5C9A4A', 'belly': '#C8E0A0', 'accent': '#3A7A3A', 'glow': '#FFB3D1', 'horn': '#E8D8B0'},
         kind='stego')
    k = H / 10.0
    # tall plates of woven vine down the back, in two staggered rows, edged
    # with thorns, each crowned by a glowing blossom; thorns on the tail
    drop(c, 'plates')
    body = c.part('body')
    (bx0, by0, bz0), (bx1, by1, bz1) = bounds_of(body)
    pl = c.part('plates', 'static')
    fl = c.part('flowers', 'glow')
    vine, vine_d, thorn = P('#3A7A3A'), P('#2A5A2A'), P('#8A2E3A')
    n = 6
    for i in range(n):
        s = i / (n - 1)
        yc = by0 + (by1 - by0) * (0.12 + 0.72 * s)
        h = (1.3 + 1.1 * math.sin(s * math.pi)) * k
        L = (0.55 + 0.35 * math.sin(s * math.pi)) * k
        side = 1 if i % 2 else -1
        xp = side * 0.35 * k - (1 if side < 0 else 0)
        X = round(xp)
        t = top_of(body, X, round(yc))
        if t is None:
            continue
        tip = None
        for dz in range(round(h) + 1):
            w = L * max(0.0, 1 - dz / max(1, h)) ** 0.8
            X2 = round(xp + side * dz * 0.18)
            for y in range(round(yc - w), round(yc + w) + 1):
                edge = abs(y - yc) > w - 1
                pl.put((X2, y, t + dz), vine_d if edge else (vine if (y + dz) % 3 else LEAF))
                if edge and (dz + y) % 3 == 0:
                    pl.put((X2, y + (1 if y > yc else -1), t + dz), thorn)
            tip = (X2, round(yc), t + round(h))
        if tip:
            flower(fl, tip[0], tip[1], tip[2] + 1, k * 0.75, petal=(P('#FF5FA0'), P('#FFD400'), P('#FF8A3D'))[i % 3],
                   heart=GOLD, glow=True)
    tail = part_or_none(c, 'tail')
    if tail:
        (tx0, ty0, tz0), (tx1, ty1, tz1) = bounds_of(tail)
        for (sx, dy) in ((1, -0.4), (-1, -0.4), (1, 0.5), (-1, 0.5)):
            yy = round(ty1 - 0.6 * k + dy * k)
            t = top_of(tail, 0, yy) or tz1
            horn(tail, (0, yy, t - 0.5), (sx * 1.0 * k, yy + 0.3 * k, t + 1.1 * k), 0.3 * k, thorn, P('#FF5FA0'), glow=True,
                 both=False)
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
    for (x, y, z) in ((0, -1.0, 5.0), (1.1, 0.6, 4.7), (-1.1, 0.6, 4.7), (0, 1.8, 5.0), (0, 0.4, 5.5)):
        fleece.ell((x * k, y * k, z * k), (1.25 * k, 1.25 * k, 1.0 * k), P('#EEF2FA'))
    fleece.paint(lambda p, cc, g: (P('#C8D0E2'), False) if p[2] < 4.3 * k else None)
    for p in [p for p in fleece.v if p in body.v]:
        del body.v[p]
    # lightning crackles through the fleece
    fleece.paint(lambda p, cc, g: (BOLT, True) if (p[0] * 5 + p[1] * 3 + p[2] * 2) % 31 == 0 else None)
    # the showpiece: big curled storm horns, dark slate banded with glowing
    # lightning, white-hot at the tips, with sparks jumping off them
    drop(c, 'horns')
    head = c.part('head')
    (hx0, hy0, hz0), (hx1, hy1, hz1) = bounds_of(head)
    hp = c.part('horns', 'glow', (0, (hy0 + hy1) / 2, hz1))
    slate, slate_l = P('#D8C8A0'), P('#F0E4C4')  # pale ivory, so the horns stand out on the dark head
    tips = []
    for side in (1, -1):
        cx, cy, cz = side * (hx1 + 0.2 * k), hy0 + (hy1 - hy0) * 0.62, hz1 - 1.35 * k
        pts = []
        for i in range(34):
            s = i / 33
            a = math.pi * 0.5 + s * math.pi * 1.45   # up, back, down, curling forward
            R = 1.85 * k * (1 - 0.55 * s)
            pts.append((cx + side * s * 1.0 * k, cy + math.cos(a) * R * -1.0, cz + math.sin(a) * R,
                        max(0.7, 0.7 * k * (1 - 0.6 * s))))
        if side < 0:
            pts = [(x - 0.5, y, z, r) for (x, y, z, r) in pts]
        sweep(hp, pts, lambda s: BOLT if s > 0.9 else (slate if int(s * 9) % 2 == 0 else slate_l),
              lambda s: s > 0.9)
        # glowing lightning bands spiralling round the horn
        for i, (x, y, z, r) in enumerate(pts[:-3]):
            if i % 4 == 1:
                hp.ell((x, y, z), (r + 0.4, r + 0.4, 0.6), BOLT, True)
        tips.append(pts[-1][:3])
    sp = c.part('sparks', 'glow')
    for (x, y, z) in tips:
        out = 1 if x > 0 else -1
        bolt(sp, (x, y, z), (x + out * 0.6 * k, y - 0.2 * k, z - 0.8 * k), BOLT, True, zig=0.25 * k, r=0.6)
    return c


def raptor_wing(c, k, root, length, cols, tip, edge, fingers=5):
    """A broad raptor wing pair held half-spread: the leading edge runs out
    and a little back, rising then levelling; long feathers hang from it,
    and the primaries at the end split into fingers with jagged glowing
    tips. Right wing drawn, left wing its mirror (so the rig sees a pair)."""
    rx, ry, rz = root
    L = round(length * k)
    w = c.part('wingR', 'wingR', (rx, ry, rz))
    for i in range(L):
        t = i / max(1, L - 1)
        x = round(rx) + i
        y = round(ry + t * 1.0 * k)
        top = rz + round(1.3 * k * math.sin(min(1.0, t * 1.6) * math.pi * 0.5) - max(0.0, t - 0.6) * 0.8 * k)
        prim = t > 0.62
        if prim:  # fingered primaries: long feather, a gap, long feather
            slot = (i - round(0.62 * (L - 1))) % 3
            flen = round((2.7 - 0.5 * (t - 0.62) / 0.38) * k) if slot != 2 else round(0.5 * k)
        else:
            flen = round((1.4 + 1.2 * math.sin(t / 0.62 * math.pi * 0.5)) * k)
            if i % 2:
                flen -= max(1, round(0.3 * k))  # toothed feather ends
        for dz in range(max(2, flen)):
            d = dz / max(1, flen - 1)
            if dz == 0:
                col, g = edge, False
            elif prim and d > 0.72 and flen > round(1.0 * k):
                col, g = tip, True
            elif i % 3 == 0 and dz > 1:
                col, g = cols[0], False  # a darker line between feathers
            elif d > 0.78:
                col, g = cols[2], False
            elif d > 0.4 or t > 0.45:
                col, g = cols[1], False
            else:
                col, g = cols[0], False
            for dy in range(2):
                w.put((x, y + dy, top - dz), col, g)
        if prim and flen > round(1.5 * k):  # a jagged notch in each lightning tip
            w.put((x, y, top - flen), tip, True)
    wl = c.part('wingL', 'wingL', (-rx, ry, rz))
    wl.v = {(-1 - x, y, z): v for (x, y, z), v in w.v.items()}


def tempest_eagle(c, H):
    """A storm eagle in a raptor's pose: the body angled forward over
    yellow taloned legs, a white head with a heavy brow and a hooked gold
    beak, broad half-spread wings (each longer than the body) whose
    primaries end in jagged lightning-yellow tips, a fanned tail, and the
    wind ring about it."""
    import rig
    from voxkit import Part
    k = H / 10.0
    plum, plumD, plumL, chest = P('#4A3A7A'), P('#33275A'), P('#7A6AB8'), P('#E8ECF8')
    BOLTY = P('#FFD400')
    lift = 0
    # legs: feathered thighs, yellow shanks, dark talons
    for side in ('R', 'L'):
        sx = 1 if side == 'R' else -1
        tmp = Part('tmp')
        hx, hy, hz = 0.75 * k, 0.4 * k, 2.6 * k
        tmp.ell((hx, hy, hz - 0.2 * k), (0.55 * k, 0.6 * k, 0.6 * k), plum)
        rod(tmp, (hx, hy - 0.1 * k, hz - 0.6 * k), (hx, hy - 0.2 * k, 0.6 * k), 0.26 * k, P('#FFC21A'))
        for dx, dy in ((0, -1), (0.6, -0.8), (-0.6, -0.8), (0, 0.7)):
            rod(tmp, (hx, hy - 0.2 * k, 0.5), (hx + dx * 0.55 * k, hy - 0.2 * k + dy * 0.6 * k, 0.5), 0.6, P('#2A2238'))
        lp = rig.leg_part(c, side, 0, 1, (sx * hx, hy, hz + 1))
        for (x, y, z), v in tmp.v.items():
            lp.v[(x if sx > 0 else -1 - x, y, z)] = v
    # the body: angled forward, deep chest in front, tapering to the tail
    body = c.part('body')
    for i in range(15):
        s2 = i / 14
        y = -1.2 * k + s2 * 3.2 * k
        z = 5.0 * k - s2 * 1.5 * k
        r = (1.45 - 0.75 * s2 ** 1.4) * k
        body.ell((0, y, z), (r, r * 0.95, r * 0.9), plum)
    body.paint(lambda q, cc, g: (chest, False) if q[1] < -0.9 * k and abs(q[0] + .5) < 1.0 * k and q[2] < 5.4 * k else None)
    body.paint(lambda q, cc, g: (plumL, False) if cc == chest and q[2] % 3 == 0 else None)
    body.paint(lambda q, cc, g: (plumD, False) if cc == plum and q[2] < 3.6 * k else None)
    # the tail fan: white with a storm-blue bar and a glowing yellow edge
    tail = c.part('tail', 'tail', (0, 1.8 * k, 3.4 * k))
    for i in range(round(1.9 * k)):
        s2 = i / max(1, round(1.9 * k) - 1)
        half = 0.45 * k + s2 * 0.8 * k
        for x in range(-math.ceil(half), math.ceil(half)):
            if abs(x + .5) > half:
                continue
            col, g = (chest, False) if s2 < 0.6 else (plumL, False) if s2 < 0.8 else (BOLTY, True)
            for dz in range(2):
                tail.put((x, round(1.8 * k + i), round(3.3 * k - s2 * 1.2 * k) + dz), col, g)
    # the head: white, a heavy brow, a hooked gold beak, fierce amber eyes
    head = c.part('head', 'head', (0, -1.7 * k, 5.7 * k))
    hy, hz = -2.35 * k, 6.4 * k
    head.ell((0, hy, hz), (1.05 * k, 1.15 * k, 1.0 * k), WHITE)
    head.ell((0, hy + 0.6 * k, hz - 0.7 * k), (1.0 * k, 0.9 * k, 0.8 * k), WHITE)
    f = head.front(0, round(hz - 0.1 * k))
    bk = Part('bk')
    by0 = f[1] if f else round(hy - 1.0 * k)
    for i in range(round(1.0 * k)):  # out from the face, then hooking down
        w2 = max(1, round(0.4 * k * (1 - i / (1.4 * k))))
        for x in range(-w2, w2):
            for dz in range(-1, 1 if i < 0.6 * k else 0):
                bk.put((x, by0 - 1 - i, round(hz - 0.1 * k) + dz), GOLD)
    tipy = by0 - round(1.0 * k)
    for dz in range(round(0.6 * k)):
        bk.put((-1, tipy, round(hz - 0.1 * k) - 1 - dz), GOLD_D)
        bk.put((0, tipy, round(hz - 0.1 * k) - 1 - dz), GOLD_D)
    for q, v in bk.v.items():
        head.v[q] = v
    eyes = c.part('eyes', 'blink', head.pivot)
    ez = round(hz + 0.1 * k)
    for side in (1, -1):
        for dx in range(2):
            x = round(0.45 * k) + dx if side > 0 else -(round(0.45 * k) + dx) - 1
            for dz in range(2):
                f2 = head.front(x, ez + dz)
                if f2:
                    del head.v[f2]
                    pupil = dx == 0 and dz == 0
                    eyes.put(f2, INK if pupil else P('#FFA010'), not pupil)
        # the brow: a dark ledge over the eye, lower toward the beak (the glare)
        for dx in range(-1, 3):
            x = round(0.45 * k) + dx if side > 0 else -(round(0.45 * k) + dx) - 1
            zz = ez + 2 + (1 if dx >= 2 else 0)
            f3 = head.front(x, zz)
            if f3:
                head.put((f3[0], f3[1] - 1, f3[2]), plumD)
                head.put(f3, plumD)
    # a lightning crest swept back from the crown
    cr = c.part('crest', 'glow', head.pivot)
    t0 = top_of(head, 0, round(hy)) or round(hz + 1.0 * k)
    bolt(cr, (-0.5, hy + 0.1 * k, t0), (-0.5, hy + 1.7 * k, t0 + 1.2 * k), BOLTY, zig=0.9, r=0.6)
    # broad half-spread wings, each longer than the body
    raptor_wing(c, k, (1.1 * k, -0.4 * k, round(5.6 * k)), 4.6, (plumD, plum, plumL), BOLTY, plumL)
    # the wind ring
    wr = orbit_part(c, 'windring', (0, 0.6 * k, 4 * k + lift))
    ring(wr, 0, 0.6 * k, 2.6 * k + lift, 4.2 * k, P('#C8F4FF'), True, thick=0.6, tilt=-0.2)
    ring(wr, 0, 0.6 * k, 2.6 * k + lift + 1, 3.6 * k, P('#E8FCFF'), True, thick=0.5, tilt=-0.2)
    c.gait_hint = 'waddle'
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
            p.paint(lambda q, cc, g: ((P('#1E9BFF') if (q[0] + q[2]) % 5 else P('#BFF0FF')), True) if g else None)
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
    # a longer lightning tusk: spiralled gold and white-hot, crackling at the tip
    (tx0, ty0, tz0), (tx1, ty1, tz1) = bounds_of(tusk)
    front = [q for q in tusk.v if q[1] == ty0]
    fx = sum(q[0] for q in front) / len(front) + 0.5
    fz = sum(q[2] for q in front) / len(front) + 0.5
    n = round(1.6 * k)
    for i in range(1, n + 1):
        r = max(0.55, 0.4 * k * (1 - i / (n + 2)))
        tusk.ell((fx, ty0 - i + 0.5, fz + i * 0.12), (r, 0.6, r), P('#FFE14D'))
    tusk.paint(lambda p, cc, g: ((P('#FFF6B0') if ((p[1] + p[2]) % 3 == 0) else P('#FFD400')), True))
    tip = (fx, ty0 - n, fz + n * 0.12)
    sp = c.part('sparks', 'glow')
    for (dx, dz) in ((0.7, 0.6), (-0.7, -0.3)):
        bolt(sp, tip, (tip[0] + dx * k, tip[1] - 0.5 * k, tip[2] + dz * k), BOLT, True, zig=0.25 * k, r=0.6)
    speckle(c.part('body'), (P('#3A4A7A'),), P('#5A6A9A'), 6)
    # storm clouds on its fins and back, sparking
    cl = c.part('clouds', 'static')
    body = c.part('body')
    for (x, y) in ((0.8, -0.4), (-0.8, 0.6), (0.2, 1.6)):
        t = top_of(body, round(x * k), round(y * k))
        if t is not None:
            cl.ell((x * k, y * k, t + 0.5 * k), (1.15 * k, 1.1 * k, 0.75 * k), P('#E8ECF8'))
            cl.ell((x * k + 0.5 * k, y * k + 0.3 * k, t + 0.9 * k), (0.7 * k, 0.7 * k, 0.55 * k), P('#FFFFFF'))
    zl = min(q[2] for q in cl.v) if cl.v else 0
    cl.paint(lambda p, cc, g: (P('#8A94B8'), False) if p[2] <= zl + 1 else None)  # dark storm undersides
    cl.paint(lambda p, cc, g: (BOLT, True) if (p[0] + p[1] * 2 + p[2] * 3) % 17 == 0 else None)
    return c


def zephyr_fox(c, H):
    plan('beast', c, H, {'col': '#9AE6D8', 'belly': '#F4FFFC', 'snout': '#F4FFFC', 'accent': '#5AC8B8', 'glow': '#E8FFFA',
                         'eye': '#1E6A6A'}, kind='canine', tail='fox')
    k = H / 10.0
    drop(c, 'tail')
    bz = 3.8 * k
    tail = c.part('tail', 'tail', (0, 3.6 * k, bz + 0.6 * k))
    # three wind tails: each sweeps back and up, then curls into a spiral,
    # fur at the root, paling to mint and a glowing teal curl at the tip.
    # The side tails lean out (so the curls face the hero camera) and are
    # mirrored exactly.
    fur, mint, curl = P('#9AE6D8'), P('#C8FFF4'), P('#3FE0C8')

    def wind_tail(phi, size):
        out = []
        cu, cv = 1.7 * k * size, 1.7 * k * size
        r0 = math.hypot(cu, cv)
        th0 = math.atan2(-cv, -cu)
        n = 40
        for i in range(n + 1):
            s2 = i / n
            th = th0 + s2 * 2 * math.pi * 1.45
            r = r0 * (1 - 0.86 * s2)
            u, v = cu + r * math.cos(th), cv + r * math.sin(th)
            x = math.sin(phi) * u
            y = 3.6 * k + math.cos(phi) * u
            z = bz + 0.6 * k + v
            out.append((x, y, z, max(0.6, (0.4 - 0.24 * s2) * k * size), s2))
        return out
    for phi, size in ((0.0, 1.0), (0.95, 0.75)):
        pts = wind_tail(phi, size)
        tmp = {}
        from voxkit import Part
        tp = Part('t')
        sweep(tp, [(x, y, z, r) for (x, y, z, r, _) in pts],
              lambda s2: fur if s2 < 0.3 else (mint if s2 < 0.72 else curl), lambda s2: s2 >= 0.72)
        for (x, y, z), v in tp.v.items():
            if phi == 0.0:
                tail.v[(x, y, z)] = v
            else:
                tail.v[(x, y, z)] = v
                tail.v[(-1 - x, y, z)] = v
    # the middle tail must be symmetric too
    for (x, y, z), v in list(tail.v.items()):
        tail.v.setdefault((-1 - x, y, z), v)
    # wind swirls on its flanks
    body = c.part('body')
    body.paint(lambda p, cc, g: (P('#3FE0C8'), True) if abs(p[0] + .5) > 1.6 * k and ((p[1] + 2 * p[2]) % round(1.6 * k) == 0) and cc == P('#9AE6D8') else None)
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
    # a peacock keeps its wings folded so the fan is the show: small wings
    # folded at its sides instead of the raised grand wings
    drop(c, 'wingL', 'wingR')
    body0 = c.part('body')
    (bx0, by0, bz0), (bx1, by1, bz1) = bounds_of(body0)
    # folded wings, the left an exact mirror of the right (x -> -1 - x)
    wr = c.part('wingR', 'wingR', (bx1 * 0.8, (by0 + by1) / 2, (bz0 + bz1) / 2 + 0.6 * k))
    wr.ell((bx1 + 0.05 * k, (by0 + by1) / 2 + 0.5 * k, (bz0 + bz1) / 2 + 0.2 * k), (0.4 * k, 1.2 * k, 0.8 * k), teal)
    wr.paint(lambda q, cc, g: (P('#1E9A8A'), False) if q[1] > (by0 + by1) / 2 + 1.4 * k else None)
    for q in [q for q in wr.v if q[0] < 0]:
        del wr.v[q]
    wl = c.part('wingL', 'wingL', (-wr.pivot[0], wr.pivot[1], wr.pivot[2]))
    for (x, y, z), val in wr.v.items():
        wl.v[(-1 - x, y, z)] = val
    # the fan tail of rainbow crystal eyes: about one and a half times the
    # bird's height and wider than it on both sides, so it frames the bird
    # from the front
    tail = c.part('tail', 'tail', (0, 2.6 * k, 3.2 * k + lift))
    body = c.part('body')
    cy = max(v[1] for v in body.v if abs(v[0]) < 2 and v[2] < 3.4 * k + lift) - 1
    base_z = 3.0 * k + lift
    Rx, Rz = 5.6 * k, 6.3 * k
    rainbow = [P('#FF2D5A'), P('#FF8A00'), P('#FFD400'), P('#2ED83A'), P('#1E90FF'), P('#8A3AFF')]
    for x in range(-round(Rx), round(Rx)):
        for z in range(0, round(Rz) + 1):
            d = math.hypot((x + .5) / Rx, z / Rz)
            if d > 1:
                continue
            col = P('#1E9A8A') if d < 0.93 else P('#5AD8C8')
            tail.put((x, round(cy), round(base_z + z)), col)
    # big faceted crystal eyes in two rings: a gold rim, a saturated gem with
    # a darker facet, and a white glint, standing proud of the fan's front
    for ring_r, n, size in ((0.78, 7, 1.0), (0.45, 3, 0.8)):
        for i in range(n):
            a = (i + 0.5) / n * math.pi
            ex, ez = round(math.cos(a) * Rx * ring_r - 0.5), round(base_z + math.sin(a) * Rz * ring_r)
            col = rainbow[(i + (0 if ring_r > 0.6 else 3)) % len(rainbow)]
            R = max(2, round(size * k * 0.75))
            for dx in range(-R, R + 1):
                for dz in range(-R, R + 1):
                    if abs(dx) + abs(dz) > R + 1:
                        continue
                    if abs(dx) + abs(dz) >= R:  # a gold rim, not glowing, so the gems stand apart
                        tail.put((ex + dx, round(cy), ez + dz), GOLD_D, False)
                    else:  # the gem, cut in two facets
                        tail.put((ex + dx, round(cy), ez + dz), col, True)
            tail.put((ex - 1, round(cy) - 1, ez + 1), WHITE, True)  # glint
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
    # gem eyes: emerald, cut by a dark cat's slit, with the white glint kept
    eyes = c.part('eyes')
    eyes.paint(lambda q, cc, g: (P('#12D69A'), True) if cc != WHITE else None)
    for side in (1, -1):
        xs = sorted({q[0] for q in eyes.v if (q[0] >= 0) == (side > 0)})
        if xs:
            mid = xs[len(xs) // 2]
            eyes.paint(lambda q, cc, g: (P('#0A3A2E'), False) if q[0] == mid and cc != WHITE else None)
    # the floating mirror, in a gold frame, circling it
    mir = orbit_part(c, 'mirror', (0, 0, 5 * k))
    mx0, my0, mz0 = 3.4 * k, -0.6 * k, 6.6 * k
    glass, glass_d = P('#DCE8F8'), P('#AFC4E0')
    for x in range(-round(1.2 * k), round(1.2 * k) + 1):
        for z in range(-round(1.6 * k), round(1.6 * k) + 1):
            d = (x / (1.2 * k)) ** 2 + (z / (1.6 * k)) ** 2
            if d > 1:
                continue
            frame = d > 0.68
            for dx in (0, 1, 2):  # silver glass both faces, so it reads as a mirror from any side
                if frame:
                    col, g = (GOLD if dx != 1 else GOLD_D), dx != 1
                elif dx == 1:
                    col, g = GOLD_D, False
                else:
                    streak = abs((x - z * 0.6) - 0.3 * k) < 0.35 * k
                    col, g = (WHITE, True) if streak else (glass if (x + z) % 4 else glass_d, False)
                mir.put((round(mx0) + dx, round(my0 + x), round(mz0 + z)), col, g)
    rest_behind(mir)
    # a gem on the cat's brow
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    f = head.front(0, z1 - round(0.25 * k)) or head.front(-1, z1 - round(0.25 * k))
    if f:
        gem = c.part('gem', 'glow', head.pivot)
        for (dx, dz) in ((0, 0), (-1, 0), (0, 1), (-1, 1), (0, -1), (-1, -1)):
            gem.put((f[0] + dx, f[1] - 1, f[2] + dz), P('#12D69A') if dz < 1 else P('#7FFFD8'), True)
    return c


def spectral_wolf(c, H):
    # a deep spectral blue so the bright skeleton lines stand out on it
    ghost = P('#6F7FD0')
    plan('beast', c, H, {'col': '#6F7FD0', 'belly': '#9AA8E8', 'snout': '#9AA8E8', 'accent': '#4F5FB0', 'glow': '#7FFFE6',
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
    # leg bones glowing down the front of each leg, and wispy fading paws
    for name in ('legFL', 'legFR', 'legBL', 'legBR'):
        lp = part_or_none(c, name)
        if lp:
            xs = sorted({q[0] for q in lp.v})
            mid = xs[len(xs) // 2]
            fronts = {}
            for q in lp.v:
                if q[0] in (mid, mid - 1) and q[1] < fronts.get((q[0], q[2]), 10 ** 6):
                    fronts[(q[0], q[2])] = q[1]
            for (x, z), y in fronts.items():
                if z >= 0.5 * k:
                    lp.v[(x, y, z)] = (P('#7FFFE6'), True)
            lp.paint(lambda q, cc, g: (P('#E6FBFF'), True) if q[2] < 0.5 * k else None)
    tail = c.part('tail')
    tail.paint(lambda q, cc, g: (P('#E6FBFF'), True) if (q[0] + q[1] + q[2]) % 4 == 0 else None)
    return c


def _horse_head(c, k, col, muzzle, nostril, iris):
    """Swaps the hoof plan's round head for a horse's: a skull with a long
    muzzle running down and forward, nostrils at its end, big eyes on the
    sides of the skull and pointed ears standing up."""
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    hy, hz = (y0 + y1 + 1) / 2, (z0 + z1 + 1) / 2
    head.v = {}
    head.ell((0, hy + 0.3 * k, hz + 0.25 * k), (1.15 * k, 1.2 * k, 1.1 * k), col)
    for i in range(11):
        s2 = i / 10
        y = hy - 0.4 * k - s2 * 1.9 * k
        z = hz - 0.05 * k - s2 * 0.75 * k
        head.ell((0, y, z), ((0.95 - 0.15 * s2) * k, 0.6 * k, (0.85 - 0.12 * s2) * k), col if s2 < 0.55 else muzzle)
    f0 = min(q[1] for q in head.v)
    nz = round(hz - 0.6 * k)
    for x in (round(0.35 * k), -round(0.35 * k) - 1):
        f = head.front(x, nz)
        if f:
            head.put(f, nostril)
    mz = round(hz - 1.15 * k)
    for x in range(-round(0.4 * k), round(0.4 * k)):
        f = head.front(x, mz)
        if f:
            head.put(f, nostril)
    # big eyes on the sides of the skull, a shine in each
    eyes = c.part('eyes')
    eyes.v = {}
    ey, ez = round(hy - 0.55 * k), round(hz + 0.05 * k)
    es = max(2, round(0.45 * k))
    for side in (1, -1):
        for dy in range(es):
            for dz in range(es + 1):
                y, z = ey + dy, ez + dz
                xs = [q[0] for q in head.v if q[1] == y and q[2] == z]
                if not xs:
                    continue
                x = max(xs) if side > 0 else min(xs)
                del head.v[(x, y, z)]
                shine = dz == es and dy == 0
                eyes.put((x, y, z), WHITE if shine else iris)
    # pointed ears standing up from the crown
    ears = c.part('ears')
    ears.v = {}
    top = max(q[2] for q in head.v)
    for i in range(round(1.4 * k)):
        w = max(1, round(0.5 * k * (1 - i / (1.4 * k))))
        for dx in range(w):
            for dy in range(max(1, w - 1)):
                x = round(0.55 * k) + dx
                ears.put((x, round(hy + 0.3 * k) + dy, top - 1 + i), col if dx else muzzle)
                ears.put((-1 - x, round(hy + 0.3 * k) + dy, top - 1 + i), col if dx else muzzle)


def starlight_pegasus(c, H):
    plan('beast', c, H, {'col': '#F4F0FF', 'belly': '#FFFFFF', 'snout': '#FFE6F2', 'accent': '#2A2A6A', 'horn': '#FFE14D',
                         'glow': '#FFF6B0', 'wing': '#E8E0FF'}, kind='hoof', mane='crest', tail='bushy', wings='feather')
    k = H / 10.0
    _horse_head(c, k, P('#F4F0FF'), P('#FFE6F2'), P('#C86A9A'), INK)
    for name in ('mane', 'tail'):
        p = part_or_none(c, name)
        if p:
            p.paint(lambda q, cc, g: (P('#2A2A6A'), False))
            speckle(p, (P('#2A2A6A'),), P('#FFF6B0'), 5, glow=True)
            speckle(p, (P('#2A2A6A'),), P('#9A8AFF'), 4, glow=False)
    # glowing wings: pearl at the root, deepening to violet and sky blue
    # light at the tips, strewn with star glints
    for name in ('wingL', 'wingR'):
        w = part_or_none(c, name)
        if not w:
            continue
        xs = [abs(q[0] + 0.5) for q in w.v]
        a, b = min(xs), max(xs)
        def wcol(q, cc, g, a=a, b=b):
            t = (abs(q[0] + 0.5) - a) / max(1, b - a)
            if t < 0.35:
                return None
            if (q[0] * 7 + q[1] * 3 + q[2] * 5) % 23 == 0:
                return (P('#FFF6B0'), True)
            return (P('#6A3AE0') if t < 0.7 else P('#1E7AE8'), True)
        w.paint(wcol)
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
    # the floating spellbook: a thick purple tome lying open in a shallow V,
    # cream pages ruled with purple script and a glowing sigil hovering
    # over it, circling above its shell
    bk = orbit_part(c, 'spellbook', (0, 0, 6 * k))
    bx, by, bz = 2.4 * k, 0, 6.6 * k
    pw, pd = round(1.5 * k), round(2.0 * k)
    cover, cover_d, page = P('#7A2EC8'), P('#4A1A88'), P('#FFF3D6')
    for side in (1, -1):
        for x in range(pw + 1):
            X = round(bx + side * x) - (1 if side < 0 else 0)
            z = round(bz + x * 0.35)
            for y in range(-1, pd + 1):
                Y = round(by) + y - pd // 2
                edge = x == pw or y in (-1, pd)
                bk.put((X, Y, z - 1), cover_d if edge else cover)
                bk.put((X, Y, z - 2), cover_d)
                if not edge:
                    bk.put((X, Y, z), P('#6A3AA8') if (y % 3 == 1 and 1 <= x < pw - 1) else page)
    for y in range(-1, pd + 1):  # the spine
        for dz in (1, 2, 3):
            bk.put((round(bx) - 1, round(by) + y - pd // 2, round(bz) - dz), cover_d)
            bk.put((round(bx), round(by) + y - pd // 2, round(bz) - dz), cover_d)
    # a glowing rune on each page, and a twist of glowing letters rising
    # off the right-hand page
    for side in (1, -1):
        x = round(pw * 0.5)
        X = round(bx + side * x) - (1 if side < 0 else 0)
        z = round(bz + x * 0.35)
        col = P('#2EE8FF') if side > 0 else P('#C96AFF')
        for (dx, dy) in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            bk.put((X + dx, round(by) + dy, z), col, True)
    x = round(pw * 0.5)
    X = round(bx + x)
    z = round(bz + x * 0.35)
    for i in range(1, 5):
        bk.put((X + (i // 2) % 2, round(by), z + i), P('#2EE8FF') if i % 2 else P('#C96AFF'), True)
        bk.put((X + (i // 2) % 2 - 1 + 1, round(by), z + i - 1 if i > 1 else z + i), P('#2EE8FF'), True)
    rest_behind(bk)
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
    c.gait_hint = 'swim'  # it snakes through the air (animate thread)
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
    plan('drake', c, H, {'col': '#9AE6C8', 'belly': '#F4FFF8', 'accent': '#5AC8A8', 'glow': '#FF5FD2', 'horn': '#FFE6F8',
                         'wing': '#FF6FC8'}, kind='pixie', horns='swept')
    k = H / 10.0
    # butterfly wings: hot pink shading to violet at the edges, with glowing
    # eye-spots and a glitter of fairy dust
    for name in ('wingL', 'wingR'):
        w = c.part(name)
        xs = [abs(q[0] + 0.5) for q in w.v]
        a, b = min(xs), max(xs)
        cx = sum(q[0] for q in w.v) / len(w.v)
        cz = sum(q[2] for q in w.v) / len(w.v)
        def wc(q, cc, g, a=a, b=b, cx=cx, cz=cz):
            t = (abs(q[0] + 0.5) - a) / max(1, b - a)
            if math.hypot(q[0] - cx, q[2] - cz) < 0.45 * k:
                return (P('#FFD400'), True) if math.hypot(q[0] - cx, q[2] - cz) < 0.25 * k else (P('#7A2EE8'), True)
            return (P('#FF4FB8') if t < 0.55 else P('#B04AF0'), t > 0.55)
        w.paint(wc)
        speckle(w, (P('#FF4FB8'), P('#B04AF0')), P('#FFF0FF'), 9, glow=True)
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
    c.part('eyes').paint(lambda q, cc, g: (P('#0FD6A8'), True) if cc != WHITE else None)
    speckle(c.part('body'), (P('#2A2A5A'),), P('#0FD6A8'), 31, glow=True)
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
    lure.ell((0, by - 0.3 * k, bz - 0.5 * k), (0.8 * k, 0.8 * k, 0.8 * k), P('#0FD6A8'), True)
    lure.ell((0, by - 0.75 * k, bz - 0.3 * k), (0.3 * k, 0.3 * k, 0.3 * k), P('#BFFFEA'), True)
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
    """A coral-pink seahorse: a curled tail, a crown of three branching coral
    prongs and glowing bubbles rising round it."""
    plan('upright', c, H, {'col': '#FF8A6A', 'belly': '#FFD6B8', 'accent': '#FF6A9A', 'glow': '#7FFFE6'}, kind='seahorse')
    k = H / 10.0
    head = c.part('head')
    (x0, y0, z0), (x1, y1, z1) = bounds_of(head)
    cx, cy = (x0 + x1 + 1) / 2 - 0.5, (y0 + y1) / 2
    # the coral crown: three clear branching prongs, coral pink with pale tips
    cr = c.part('coral', 'static', (cx, cy, z1))
    coral, tipc = P('#FF5F8A'), P('#FFC2D4')
    for dx, dy, h in ((0.0, 0.3, 2.6), (1.1, 0.5, 2.0), (-1.1, 0.5, 2.0)):
        base = (cx + dx * 0.4 * k, cy + dy * k, z1 - 0.4 * k)
        tip = (cx + dx * k, cy + dy * k + 0.2 * k, z1 + h * k)
        rod(cr, base, tip, 0.24 * k, coral)
        cr.ell(tip, (0.28 * k, 0.28 * k, 0.28 * k), tipc)
        # two side branches off each prong
        for f, side in ((0.45, 1), (0.7, -1)):
            mid = tuple(base[j] + (tip[j] - base[j]) * f for j in range(3))
            out = 1 if dx > 0 else -1 if dx < 0 else side
            end = (mid[0] + out * 0.8 * k, mid[1] + 0.1 * k, mid[2] + 0.7 * k)
            rod(cr, mid, end, 0.19 * k, coral)
            cr.ell(end, (0.24 * k, 0.24 * k, 0.24 * k), tipc)
    # a chain of bubbles from its snout
    bub = c.part('bubbles', 'glow')
    bcol = P('#5FE8FF')
    f = head.front(math.floor(cx), z1 - round(0.6 * k)) or (math.floor(cx), y0, z1 - round(0.6 * k))
    bz, by = f[2] + 0.3 * k, f[1] - 0.2 * k
    for i in range(3):
        r = (0.32 + 0.1 * i) * k
        bub.ell((cx, by - 0.1 * k * i, bz), (r, r, r), bcol, True)
        bz += r + (0.32 + 0.1 * (i + 1)) * k - 1
    bub.paint(lambda q, cc, g: (WHITE, True) if cc == bcol and (q[0] + q[2]) % 5 == 0 and q[1] == min(
        p[1] for p in bub.v if p[0] == q[0] and p[2] == q[2]) else None)
    # bubbles rising round it in a slow spiral
    body = c.part('body')
    (bx0, by0, bz0), (bx1, by1, bz1) = bounds_of(body)
    ring_c = ((bx0 + bx1 + 1) / 2, (by0 + by1) / 2, bz0)
    orb = orbit_part(c, 'risingbubbles', ring_c)
    Rr = 2.3 * k
    for i in range(6):
        a = i / 6 * math.pi * 2
        r = (0.28 + 0.06 * (i % 3)) * k
        z = bz0 + (0.6 + i * 0.9) * k
        x, y = ring_c[0] + math.cos(a) * Rr, ring_c[1] + math.sin(a) * Rr
        orb.ell((x, y, z), (r, r, r), bcol, True)
        orb.put((round(x - r * 0.4), round(y - r * 0.6), round(z + r * 0.4)), WHITE, True)
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
    # sunken treasure heaped in the hold, glowing gold, and seaweed trailing
    # down the hull
    hold = c.part('treasure', 'glow')
    hold.ell((0, cy + 0.9 * k, z0 + 2.2 * k), (1.1 * k, 1.2 * k, 0.6 * k), GOLD, True)
    hold.paint(lambda q, cc, g: (GOLD_L, True) if (q[0] * 3 + q[1] * 5 + q[2]) % 7 == 0 else None)
    for q in [q for q in hold.v if q in ship.v]:
        del hold.v[q]
    weed = P('#2E9A5A')
    for (sx, yy) in ((1, -1.2), (-1, 0.4), (1, 1.6), (-1, -0.2)):
        y = round(cy + yy * k)
        xs = [q[0] for q in ship.v if q[1] == y and q[2] == round(z0 + 2.2 * k)]
        if not xs:
            continue
        x = max(xs) + 1 if sx > 0 else min(xs) - 1
        for i in range(round(1.4 * k)):
            ship.put((x + (sx if (i // 3) % 2 else 0), y, round(z0 + 2.2 * k) - i), weed)
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
        # thin, irregular glowing lava cracks over dark rock (not bands)
        cracks(shell, (P('#4A4048'), P('#6A5E66')), FIRE[1], k, scale=1.15, width=0.3)
    # bright ember eyes (black eyes vanish on the dark rock face), each
    # with a white-hot glint in its top corner
    eyes = part_or_none(c, 'eyes')
    if eyes:
        head = part_or_none(c, 'head')
        # redraw the eyes as two 2x2 ember eyes set apart on the face front
        # (the bug plan's single-voxel eyes ran together on this head)
        zc = min(q[2] for q in eyes.v)
        for q in list(eyes.v):
            head.v[q] = (P('#2A2228'), False)
        eyes.v = {}
        for sx in (1, -1):
            for dx in (1, 2):
                x = dx if sx > 0 else -dx - 1
                for z in (zc, zc + 1):
                    f = head.front(x, z)
                    if f:
                        del head.v[f]
                        glint = z == zc + 1 and dx == 2
                        eyes.v[f] = (FIRE[3] if glint else FIRE[1], True)
    # smoke curling up from the hot shell itself: two soft grey wisps that
    # sit on the cracks, each two puffs, no stalk
    sm = c.part('smoke', 'glow')
    sh = shell or c.part('body')
    for (fx, fy) in ((-0.9, 1.4), (0.8, 2.3)):
        x, y = round(fx * k), round(fy * k)
        t = top_of(sh, x, y)
        if t is None:
            continue
        # small round wisps that lean well back as they rise off the crack
        sm.ell((x + 0.5, y + 0.5, t + 0.1 * k), (0.4 * k, 0.4 * k, 0.35 * k), P('#8E8A96'))
        sm.ell((x + 0.5, y + 0.5 + 0.6 * k, t + 0.5 * k), (0.45 * k, 0.45 * k, 0.38 * k), P('#B4B0BC'))
        sm.ell((x + 0.5, y + 0.5 + 1.2 * k, t + 0.75 * k), (0.32 * k, 0.32 * k, 0.3 * k), P('#D4D0DA'))
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


def fit_stand_in(c):
    """The in-game boxes only (the stand-in drawn before the mesh loads; the
    Blender meshes, and so the reviewed models and thumbnails, are never
    changed): a Legendary over its box budget (to_config.BOX_BUDGET) first
    has near-identical shades on each part made one colour (kit_trim._unify,
    never the eyes), which keeps its outline, and if it is still over, its
    heaviest parts other than the face and legs are redrawn on a coarser grid
    (kit_epicmyth._fit_budget), aiming 10 boxes under the budget because the
    walking legs are carved out of the body afterwards."""
    if getattr(c, 'fine', False):
        return c
    import kit_epicmyth
    import kit_trim
    from to_config import BOX_BUDGET
    budget = BOX_BUDGET[c.rarity]
    if kit_trim._drawn(c)[0] <= budget:
        return c
    for p in c.parts:
        if p.name != 'eyes':
            p.v = kit_trim._unify(p.v)
    if kit_trim._drawn(c)[0] > budget:
        kit_epicmyth._fit_budget(c, budget - 10)
    return c


def _finished(fn):
    def build(c, H):
        fn(c, H)
        return fit_stand_in(calm_pale_glow(tidy(join_pieces(_orbit_gives_way(c)))))
    return build


def storm_griffin(base):
    """Thunder Griffin with the sheet's storm-cloud wings: dark storm-grey
    and indigo feathers with pale cloud puffs along the top, glowing yellow
    zig-zag bolts across each wing and lightning crackling off the tail."""
    def build(c, H):
        base(c, H)
        k = H / 10.0
        storm = {P('#7A4E2A'): P('#2C3150'), P('#A8743F'): P('#3E4670'), P('#FFFFFF'): P('#6A7298')}
        cloud, cloud_l = P('#8E97BC'), P('#B8C0DE')
        volt, gold = P('#4FD8FF'), P('#FFE14D')
        for name in ('wingL', 'wingR'):
            w = part_or_none(c, name)
            if not w:
                continue
            w.paint(lambda q, cc, g: (storm[cc], g) if cc in storm and not g else None)
            (x0, y0, z0), (x1, y1, z1) = bounds_of(w)
            # cloud puffs rolling along the top edge
            tops = {}
            for (x, y, z) in w.v:
                if z > tops.get(x, (None, -1))[1]:
                    tops[x] = (y, z)
            xs = sorted(tops)
            # chunky box puffs (cheap for the in-game box art)
            step = max(2, round(1.6 * k))
            for x in xs[step // 2::step]:
                y, z = tops[x]
                hw, hd = round(0.6 * k), round(0.45 * k)
                w.box((x - hw, y - hd, z - round(0.3 * k)), (x + hw, y + hd, z + round(0.25 * k)), cloud)
                w.box((x - hw + 1, y - hd + 1, z + round(0.25 * k) + 1), (x + hw - 1, y + hd - 1, z + round(0.5 * k)), cloud)
            # the raised wing faces front: zig-zag bolts painted across its
            # front face (and mirrored on the back), root to tip
            # the old cyan stripes and white-hot tips become dark storm feathers;
            # only the bolts glow
            w.paint(lambda q, cc, g: (P('#3E4670'), False) if g and cc in (P('#D8FBFF'), volt) else None)
            out = 1 if x1 > 0 else -1
            root_x, tip_x = (x0, x1) if out > 0 else (x1, x0)
            face = {}
            back = {}
            for (x, y, z) in w.v:
                if y < face.get((x, z), 10 ** 6):
                    face[(x, z)] = y
                if y > back.get((x, z), -10 ** 6):
                    back[(x, z)] = y
            # one classic lightning bolt down the raised wing's front: tall
            # straight drops with short jogs (vertical runs stay a few boxes
            # in the in-game box art)
            xm = root_x + (tip_x - root_x) * 0.55
            zt, zb = z0 + (z1 - z0) * 0.85, z0 + (z1 - z0) * 0.12
            jog = 0.7 * k * out
            pts = [(xm - jog, zt), (xm - jog, zt - (zt - zb) * 0.4), (xm + jog, zt - (zt - zb) * 0.4),
                   (xm + jog, zt - (zt - zb) * 0.7), (xm, zt - (zt - zb) * 0.7), (xm, zb)]
            cells = set()
            for (ax, az), (bx, bz) in zip(pts, pts[1:]):
                ax, az, bx, bz = round(ax), round(az), round(bx), round(bz)
                for x in range(min(ax, bx), max(ax, bx) + 1):
                    for z in range(min(az, bz), max(az, bz) + 1):
                        cells |= {(x, z), (x + 1, z)}
            for q in cells:
                if q in face:
                    w.v[(q[0], face[q] - 1, q[1])] = (gold, True)
        # lightning crackling off the tail tip
        tail = part_or_none(c, 'tail')
        if tail:
            glows = [q for q, (cc, g) in tail.v.items() if g]
            if glows:
                cx = sum(q[0] for q in glows) / len(glows)
                cy = sum(q[1] for q in glows) / len(glows)
                cz = sum(q[2] for q in glows) / len(glows)
                for a, (ux, uy, uz) in enumerate(((0.9, 0.5, 0.6), (-0.9, 0.5, 0.6))):
                    end = (cx + ux * 1.6 * k, cy + uy * 1.6 * k, cz + uz * 1.6 * k)
                    bolt(tail, (cx, cy, cz), end, gold if a % 2 == 0 else volt, True, zig=0.35 * k, r=0.6)
        return c
    return build


def finish_existing(roster):
    """The Legendaries built before this batch (Phoenix, Thunder Griffin)
    get the same weld, so the loose-piece check passes for every Legendary;
    Thunder Griffin also gets the sheet's storm-cloud wings and lightning."""
    out = []
    for sid, tier, fn in roster:
        if tier == 'Legendary' and sid == 'ThunderGriffin':
            fn = _finished(storm_griffin(fn))
        elif tier == 'Legendary' and sid == 'Phoenix':
            fn = _finished(fn)
        out.append((sid, tier, fn))
    return out


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
