"""Godly creatures that stand on legs: Solar Lion, Aurora Stag, Void Kitsune,
Prism Alicorn, Omega Chimera, Magma Behemoth, World Turtle, Candy Colossus and
Crystal Hydra. See kit_godly.py for the standard they follow."""
import math

from godly_common import (C, INK, WHITE, front_at, _ball_pts, _fbm, _hash, _mix, _shade, ball, cloud, ctx, flake, four_legs,
                       gradient, leg, limb, mirror_put, mottle, orbit_ring, tidy, proud_eyes, shard, sparkle, star4, tube,
                       wing)


# ------------------------------------------------------------ a beast frame

def beast(c, k, fine, col, belly, *, body=(1.8, 2.9, 1.65), body_z=4.6, hip_z=4.0, leg_x=1.15, front_y=-1.55,
          back_y=2.4, leg_r=(0.66, 0.46), paw=None, claw=None, neck=True, head=(1.3, 1.35, 1.2), head_at=(-3.25, 7.3),
          snout=(0.78, 0.82, 0.62), snout_col=None, nose=INK, col_back=None, paw_r=None):
    """A four-legged body: barrel, chest and haunches, four leg parts, a neck
    and a head with a muzzle. Returns (body part, head part, head centre)."""
    b = c.part('body')
    by = (front_y + back_y) / 2 + 0.2
    b.ell((0, by * k, body_z * k), (body[0] * k, body[1] * k, body[2] * k), col)
    b.ell((0, (front_y + 0.2) * k, (body_z + 0.25) * k), (body[0] * 1.02 * k, 1.45 * k, body[2] * 1.05 * k), col)  # chest
    b.ell((0, (back_y - 0.1) * k, (body_z + 0.1) * k), (body[0] * 1.0 * k, 1.35 * k, body[2] * 0.98 * k), col)  # haunch
    if belly is not None:
        b.paint(lambda p, cc, g: (belly, False) if p[2] < (body_z - body[2] * 0.62) * k and cc == col else None)
    four_legs(c, k, front_y, back_y, leg_x, hip_z, leg_r[0], leg_r[1], col, col_back=col_back, paw=paw or col,
              claw=claw, paw_r=paw_r)
    hy, hz = head_at
    if neck:
        limb(b, (0, (front_y - 0.2) * k, (body_z + 0.6) * k), (0, (hy + 0.5) * k, (hz - 0.5) * k), 1.05 * k, 0.9 * k, col)
    h = c.part('head', 'head', (0, (hy + 0.6) * k, (hz - 0.7) * k))
    h.ell((0, hy * k, hz * k), (head[0] * k, head[1] * k, head[2] * k), col)
    for sx in (1, -1):  # cheeks
        h.ell((sx * head[0] * 0.55 * k, (hy - 0.35) * k, (hz - 0.35) * k), (0.62 * k, 0.75 * k, 0.6 * k), col)
    sc = snout_col or col
    h.ell((0, (hy - head[1] * 0.95) * k, (hz - 0.42) * k), (snout[0] * k, snout[1] * k, snout[2] * k), sc)
    # nose pad
    nz = (hz - 0.42 + snout[2] * 0.55) * k
    ny = (hy - head[1] * 0.95 - snout[1] * 0.9) * k
    h.ell((0, ny, nz), (0.32 * k, 0.22 * k, 0.18 * k), nose)
    # mouth line under the muzzle
    for x in range(-round(0.35 * k), round(0.35 * k)):
        f = None
        for y in range(round(ny), round(ny + 1.2 * k)):
            if (x, y, round(nz - 0.45 * k)) in h.v:
                f = (x, y, round(nz - 0.45 * k))
                break
        if f and abs(x + .5) > 0.12 * k:
            h.put(f, _shade(sc, 0.55))
    return b, h, (0, hy * k, hz * k)


def tail_tube(c, k, start, ctrl, end, r0, r1, col_at, glow_at=lambda s: False, n=28, name='tail'):
    """A tail in its own `tail` part, a quadratic curve from start (the root,
    its pivot) through ctrl to end, in k units."""
    t = c.part(name, 'tail', tuple(v * k for v in start))
    pts = []
    for i in range(n):
        s = i / (n - 1)
        q = tuple(((1 - s) ** 2 * a + 2 * (1 - s) * s * b + s * s * e) * k for a, b, e in zip(start, ctrl, end))
        pts.append((*q, max(0.55, (r0 + (r1 - r0) * s) * k)))
    tube(t, pts, col_at, glow_at)
    return t


def ears_pair(c, k, base, h, w, col, inner=None, lean=0.25, back=0.2, name='ears'):
    """Upright triangular ears (in k units: base = right ear's (x, y, z))."""
    e = c.part(name, 'ears', (0, base[1] * k, base[2] * k))
    L = max(3, round(h * k))
    for i in range(L):
        t = i / (L - 1)
        ww = w * k * (1 - t)
        for dx in range(-round(ww), round(ww) + 1):
            for dy in range(max(1, round(0.35 * k * (1 - t)))):
                x = round(base[0] * k + lean * k * t + dx)
                p = (x, round(base[1] * k + back * k * t + dy), round(base[2] * k + i))
                inside = inner is not None and abs(dx) < ww * 0.5 and dy == 0 and t < 0.75
                mirror_put(e, p, inner if inside else col)
    return e


# ------------------------------------------------------------ Solar Lion

def solar_lion(c, H):
    """A golden lion whose mane is a ring of sun flares, eyes like suns, a
    flame tuft on its tail; a small sun and three moons circle it."""
    k, fine = ctx(c, H)
    gold, goldL, goldD, goldDD = C('#F2B33D'), C('#FFD36B'), C('#D48A1F'), C('#A8641A')
    cream = C('#FFE9B8')
    flare, flareL, flareH, red = C('#FF7A1A'), C('#FFB21A'), C('#FFE45C'), C('#F0441C')
    b, h, (hx, hy, hz) = beast(c, k, fine, gold, cream, paw=goldL, claw=C('#FFF3D0'), snout_col=cream,
                               nose=C('#7A3A1A'), body=(1.95, 2.6, 1.8), body_z=4.0, hip_z=3.4, leg_x=1.2,
                               front_y=-1.45, back_y=2.15, leg_r=(0.8, 0.6), head=(1.58, 1.5, 1.42),
                               head_at=(-3.05, 6.85), snout=(0.92, 0.85, 0.7))
    for part in (b, h):
        gradient(part, [goldD, gold, gold, goldL], 2.0 * k, 9.0 * k, fine, keep=(cream, C('#7A3A1A'), C('#FFF3D0')))
    for name in ('legFL', 'legFR', 'legBL', 'legBR'):
        lp = c.part(name)
        gradient(lp, [goldDD, goldD, gold], 0, 4.0 * k, fine, keep=(goldL, C('#FFF3D0')))
    # a darker saddle down the back
    mottle(b, goldD, 1.4 * k, 0.62, 5, fine, keep=(cream,))
    proud_eyes(c, h, [(0.66 * k, hz + 0.22 * k)], 0.5 * k, 0.46 * k, flareH, ring=C('#7A3A1A'),
               pupil=C('#B4400F'), lid=goldD, iris2=flareL, behind=hy - 1.1 * k)
    # brows
    for sx in (1, -1):
        h.ell((sx * 0.66 * k, hy - 1.0 * k, hz + 0.86 * k), (0.5 * k, 0.3 * k, 0.14 * k), goldD)
    # the sun-flare mane: rays fanning out round the head, layered
    mane = c.part('crest', 'glow', (0, hy + 0.6 * k, hz))
    my, mz = hy + 0.65 * k, hz - 0.05 * k
    rays = 22 if fine else 10
    for i in range(rays):
        a = i / rays * math.pi * 2
        long_ = 1.0 if i % 2 == 0 else 0.72
        L = (2.25 if fine else 2.0) * k * long_
        pts = []
        for j in range(14):
            s = j / 13
            wob = math.sin(s * math.pi * 1.4 + i) * 0.18 * k * s
            r = 1.3 * k + s * L
            x = math.cos(a) * r * 1.05 + wob * math.sin(a)
            z = mz + math.sin(a) * r
            y = my + 0.1 * k + s * (1.1 + 0.5 * (i % 3 == 1)) * k
            pts.append((x, y, z, max(0.55, (0.62 - 0.5 * s) * k)))
        if fine:
            tube(mane, pts, lambda s: red if s < 0.18 else (flare if s < 0.5 else (flareL if s < 0.8 else flareH)),
                 lambda s: True)
        else:
            tube(mane, pts, lambda s: flare if s < 0.55 else flareH, lambda s: True)
    # a solid mane disc behind the head so no ray shows a gap
    mane.ell((0, my + 0.9 * k, mz), (2.05 * k, 1.25 * k, 2.1 * k), flare, True)
    mane.ell((0, my + 1.6 * k, mz - 0.4 * k), (1.7 * k, 1.1 * k, 1.7 * k), red if fine else flare, True)
    for q in [q for q in mane.v if q in h.v or q in b.v]:
        del mane.v[q]
    # ears poking through the mane
    ears_pair(c, k, (1.05, hy / k + 0.2, hz / k + 1.05), 0.8, 0.36, gold, inner=goldD, lean=0.1)
    # tail with a flame tuft
    t = tail_tube(c, k, (0, 3.8, 4.6), (0, 6.0, 4.2), (0, 5.6, 6.8), 0.36, 0.3, lambda s: gold)
    tuft = c.part('tail')
    for p in _ball_pts((0, 5.55 * k, 7.1 * k), 0.68 * k):
        tuft.put(p, flareL, True)
    for j in range(round(1.1 * k)):
        tuft.put((0, round(5.5 * k), round(7.6 * k) + j), flareH if j > 0.5 * k else flare, True)
        tuft.put((-1, round(5.5 * k), round(7.6 * k) + j), flareH if j > 0.5 * k else flare, True)
    sparkle(b, (flareH,), 220, 9, fine, keep=(cream,))

    tidy(c)
    # a small sun and three moons
    sun = ball(flareL, flareH, glow=True, bands=True, fine=fine)
    moon_a = ball(C('#DCD6EE'), C('#B7AFD3'), cap=False, speck=C('#A49BC4'), seed=3, fine=fine)
    moon_b = ball(C('#C7D9F2'), C('#FFFFFF'), cap=True, fine=fine)
    moon_c = ball(C('#E8D2C0'), speck=C('#C4A58E'), seed=4, fine=fine)
    orbit_ring(c, k, [
        (-30, 6.8, 0.78, sun),
        (75, 4.0, 0.58, moon_a),
        (165, 7.2, 0.52, moon_b),
        (250, 3.2, 0.55, moon_c),
    ] + ([(30, 2.6, 0.38, star4(flareH, flareL)), (205, 5.6, 0.36, star4(WHITE, flareH))] if fine else []))
    return c



def antler(part, k, base, sx, beam_len, rise, tines, col_at, glow=True, r0=0.3, r1=0.14):
    """One branching antler (right side for sx = 1): a beam sweeping up and
    back with `tines` (fraction along, up, out) branching off it."""
    bx, by, bz = base
    beam = []
    for i in range(22):
        s = i / 21
        beam.append((bx + sx * s * beam_len * 0.75 * k, by + s * beam_len * 0.55 * k,
                     bz + s * rise * k - s * s * 0.5 * k, max(0.55, (r0 - (r0 - r1) * s) * k)))
    tube(part, beam, col_at, lambda s: glow)
    tips = [beam[-1][:3]]
    for at, up, out in tines:
        x, y, z, _ = beam[int(at * 21)]
        pts = []
        for i in range(10):
            s = i / 9
            pts.append((x + sx * s * out * k, y - s * 0.25 * k, z + s * up * k, max(0.55, (r1 * 1.1 - 0.05 * s) * k)))
        tube(part, pts, lambda s, at=at: col_at(min(1.0, at + 0.4 * s)), lambda s: glow)
        tips.append(pts[-1][:3])
    return tips


# ------------------------------------------------------------ Aurora Stag

def aurora_stag(c, H):
    """A frost-white stag whose great antlers glow through the colours of an
    aurora, with ribbons of aurora light hanging between their tines;
    snowflakes and ice shards circle it."""
    k, fine = ctx(c, H)
    frost, frostL, frostD, frostDD = C('#DDEBFA'), C('#F4F9FF'), C('#B8CCEA'), C('#8EA6D0')
    hoof, nose = C('#3B4A7A'), C('#4A5A8A')
    teal, green, violet, pink, cyan = C('#2EE6C8'), C('#4CF08A'), C('#9A5CFF'), C('#FF5CD6'), C('#5CE1FF')
    b, h, (hx, hy, hz) = beast(c, k, fine, frost, frostL, paw=hoof, body=(1.3, 2.65, 1.35), body_z=5.3, hip_z=4.9,
                               leg_x=0.85, front_y=-1.7, back_y=2.2, leg_r=(0.5, 0.33), head=(0.98, 1.2, 0.95),
                               head_at=(-3.75, 8.2), snout=(0.58, 1.15, 0.5), snout_col=frostL, nose=nose,
                               paw_r=(0.5, 0.55, 0.45))
    for part in (b, h):
        gradient(part, [frostDD, frostD, frost, frostL], 3.6 * k, 9.4 * k, fine, keep=(nose, frostL))
    for name in ('legFL', 'legFR', 'legBL', 'legBR'):
        gradient(c.part(name), [frostDD, frostD, frost], 0, 4.9 * k, fine, keep=(hoof,))
    # pale rump and chest blaze, frost speckles
    b.paint(lambda p, cc, g: (frostL, False) if p[1] > 3.3 * k and p[2] > 4.9 * k else None)
    sparkle(b, (cyan, WHITE), 260, 21, fine)
    proud_eyes(c, h, [(0.55 * k, hz + 0.15 * k)], 0.4 * k, 0.38 * k, cyan, ring=C('#1E2A55'), pupil=C('#1E2A55'),
               lid=frostD, iris2=teal, behind=hy - 0.9 * k)
    # ears
    e = c.part('ears', 'ears', (0, hy + 0.3 * k, hz + 0.6 * k))
    for sx in (1, -1):
        e.ell((sx * 1.2 * k, hy + 0.35 * k, hz + 0.55 * k), (0.62 * k, 0.2 * k, 0.26 * k), frost)
        e.ell((sx * 1.2 * k, hy + 0.25 * k, hz + 0.55 * k), (0.42 * k, 0.12 * k, 0.15 * k), C('#FFC9E8'))
    for q in [q for q in e.v if q in h.v]:
        del e.v[q]
    # aurora antlers
    horns = c.part('horns', 'glow', (0, hy + 0.3 * k, hz + 1.0 * k))
    stops = (teal, green, cyan, violet, pink)

    def col_at(s):
        return stops[min(len(stops) - 1, int(s * len(stops)))] if fine else (teal if s < 0.5 else violet)
    curtains = []
    for sx in (1, -1):
        tips = antler(horns, k, (sx * 0.5 * k, hy + 0.3 * k, hz + 0.8 * k), sx, 3.2, 2.2,
                      ((0.25, 1.3, 0.1), (0.5, 1.2, 0.45), (0.75, 1.0, 0.2)) if fine else ((0.35, 1.2, 0.2), (0.7, 1.0, 0.2)),
                      col_at)
        curtains.append(tips)
    # ribbons of aurora light hanging from tine to tine (fine build)
    if fine:
        rib = c.part('aurora', 'glow', (0, hy + 0.3 * k, hz + 1.0 * k))
        for tips in curtains:
            tips = sorted(tips, key=lambda q: q[1])
            for a, bq in zip(tips, tips[1:]):
                steps = max(2, round(math.dist(a, bq)))
                for i in range(steps + 1):
                    s = i / steps
                    x, y, z = (a[j] + (bq[j] - a[j]) * s for j in range(3))
                    drop = round((0.9 + 0.35 * math.sin(s * math.pi * 2 + x)) * k)
                    for d in range(drop):
                        if d % 3 == 2 and i % 2:
                            continue
                        f = d / max(1, drop - 1)
                        rib.put((math.floor(x), math.floor(y), math.floor(z) - d), green if f < 0.4 else (teal if f < 0.75 else violet), True)
        for q in [q for q in rib.v if q in horns.v or q in h.v]:
            del rib.v[q]
    # short tail, white flag
    tail_tube(c, k, (0, 3.8, 5.9), (0, 4.3, 6.1), (0, 4.5, 5.5), 0.38, 0.28, lambda s: frostL)
    tidy(c)
    orbit_ring(c, k, [
        (0, 5.0, 0.62, flake(C('#BFF4FF'), WHITE)),
        (90, 3.0, 0.55, shard(C('#7FDBFF'), C('#D8FBFF'))),
        (180, 6.0, 0.62, flake(C('#BFF4FF'), WHITE)),
        (270, 3.4, 0.55, shard(C('#9A8CFF'), C('#E3DCFF'))),
    ] + ([(45, 7.4, 0.42, flake(cyan, WHITE)), (225, 7.4, 0.42, flake(green, WHITE))] if fine else []))
    return c


# ------------------------------------------------------------ Void Kitsune

def void_kitsune(c, H):
    """A fox of deep night with a starry coat, glowing violet markings and
    nine star-filled tails fanned behind it; spirit flames circle it."""
    k, fine = ctx(c, H)
    night, nightL, nightD, inkv = C('#2B2560'), C('#3E3684'), C('#1C1842'), C('#120F2E')
    chest, mark, markL, cyan = C('#C9C2FF'), C('#B45CFF'), C('#E3B8FF'), C('#5CE1FF')
    b, h, (hx, hy, hz) = beast(c, k, fine, night, chest, paw=nightD, body=(1.5, 2.4, 1.4), body_z=3.9, hip_z=3.4,
                               leg_x=0.95, front_y=-1.35, back_y=1.9, leg_r=(0.58, 0.44), head=(1.45, 1.35, 1.25),
                               head_at=(-2.85, 6.6), snout=(0.62, 1.0, 0.5), snout_col=chest, nose=inkv)
    for part in (b, h):
        gradient(part, [nightD, night, night, nightL], 2.0 * k, 8.0 * k, fine, keep=(chest, inkv))
    for name in ('legFL', 'legFR', 'legBL', 'legBR'):
        lp = c.part(name)
        gradient(lp, [inkv, nightD, night], 0, 3.4 * k, fine)
        lp.paint(lambda p, cc, g: (mark, True) if 1.0 * k < p[2] < 1.25 * k else None)  # glowing anklets
    sparkle(b, (WHITE, cyan, markL), 70, 31, fine, keep=(chest,))
    sparkle(h, (WHITE,), 140, 32, fine, keep=(chest, inkv))
    # cheek and brow markings
    for sx in (1, -1):
        for i in range(round(0.9 * k)):
            f = front_at(h, round(sx * (0.9 * k + i * 0.3)) - (1 if sx < 0 else 0), round(hz - 0.1 * k + i * 0.35))
            if f:
                h.put(f, mark, True)
    proud_eyes(c, h, [(0.62 * k, hz + 0.2 * k)], 0.48 * k, 0.4 * k, C('#FFD45A'), ring=inkv, pupil=inkv, lid=nightD,
               iris2=C('#FF9A3D'), slit=True, behind=hy - 0.9 * k)
    ears_pair(c, k, (0.85, hy / k + 0.35, hz / k + 0.8), 1.5, 0.48, night, inner=mark, lean=0.3)
    ear = c.part('ears')
    ear.paint(lambda p, cc, g: (markL, True) if p[2] > hz + 2.0 * k and cc == night else None)
    # nine tails fanned behind, each a soft tube of night sky with a glowing tip
    tail = c.part('tail', 'tail', (0, 2.9 * k, 4.4 * k))
    n = 9
    root = (0, 2.9 * k, 4.4 * k)
    for i in range(n):
        th = math.radians(-78 + 156 * i / (n - 1))  # fanned like a peacock's, seen from behind
        L = (3.0 - 0.35 * abs(i - 4) / 4) * k
        end = (math.sin(th) * L, root[1] + 1.9 * k, root[2] + math.cos(th) * L * 0.85 + 0.6 * k)
        ctrl = (math.sin(th) * L * 0.35, root[1] + 1.6 * k, root[2] + 0.2 * k)
        pts = []
        m = 22 if fine else 12
        for j in range(m):
            s_ = j / (m - 1)
            q = tuple((1 - s_) ** 2 * a + 2 * (1 - s_) * s_ * cc + s_ * s_ * e for a, cc, e in zip(root, ctrl, end))
            r = (0.28 + 0.34 * math.sin(min(1.0, s_ * 1.15) * math.pi * 0.8)) * k
            pts.append((*q, max(0.6, r)))
        tube(tail, pts, lambda s_: night if s_ < 0.72 else (mark if s_ < 0.9 else markL), lambda s_: s_ >= 0.72)
    tail.paint(lambda p, cc, g: (nightD, False) if cc == night and p[2] < 4.6 * k else None)
    sparkle(tail, (WHITE, cyan, WHITE, markL), 26 if fine else 9999, 33, fine)
    tidy(c)
    orb = ball(C('#7FD8FF'), WHITE, glow=True, cap=True, fine=fine)
    orb2 = ball(C('#C58CFF'), WHITE, glow=True, cap=True, fine=fine)
    orbit_ring(c, k, [
        (-20, 4.8, 0.48, orb), (60, 2.4, 0.42, orb2), (130, 5.8, 0.45, orb),
        (200, 3.0, 0.48, orb2), (280, 6.2, 0.42, orb),
    ])
    return c


BUILDERS = {
    'SolarLion': solar_lion,
    'AuroraStag': aurora_stag,
    'VoidKitsune': void_kitsune,
}
