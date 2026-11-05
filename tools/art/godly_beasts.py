"""Godly creatures that stand on legs: Solar Lion, Aurora Stag, Void Kitsune,
Prism Alicorn, Omega Chimera, Magma Behemoth, World Turtle, Candy Colossus and
Crystal Hydra. See kit_godly.py for the standard they follow."""
import math

from godly_common import (C, INK, WHITE, front_at, _ball_pts, _vnoise, _fbm, _hash, _mix, _shade, ball, cloud, ctx, flake, four_legs,
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
    k, fine = ctx(c, H * 0.95)  # a long, wide body: drawn a little smaller to stay in the triangle budget
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



def rainbow(s):
    cols = (C('#FF4D6D'), C('#FF9A3D'), C('#FFD93B'), C('#4CD964'), C('#3FA9FF'), C('#9A5CFF'))
    return cols[min(len(cols) - 1, int(s * len(cols)))]


def hair_locks(part, k, roots, length, droop, r, col_at, glow=False, n=14, wave=0.2):
    """Flowing locks of hair (mane, tail): each from a root (x, y, z) in
    voxels, sweeping back by `length` and down by `droop` (k units)."""
    for m, (x0, y0, z0) in enumerate(roots):
        pts = []
        for j in range(n):
            s = j / (n - 1)
            pts.append((x0 + math.sin(s * math.pi * 1.3 + m) * wave * k, y0 + s * length * k,
                        z0 - s * s * droop * k, max(0.55, r * (1 - 0.45 * s) * k)))
        tube(part, pts, lambda s, m=m: col_at(s, m), lambda s: glow)


# ------------------------------------------------------------ Prism Alicorn

def prism_alicorn(c, H):
    """A white winged unicorn with a flowing rainbow mane and tail, a golden
    spiral horn and pearly feathered wings; a halo of rainbow gems circles
    it."""
    k, fine = ctx(c, H)
    white, whiteD, whiteDD, pearl = C('#FBF8FF'), C('#E4DDF5'), C('#C9BFE6'), C('#F3E9FF')
    hoof, gold, goldL = C('#D9A520'), C('#FFC83D'), C('#FFF0A0')
    b, h, (hx, hy, hz) = beast(c, k, fine, white, None, paw=hoof, body=(1.35, 2.5, 1.35), body_z=5.0, hip_z=4.6,
                               leg_x=0.88, front_y=-1.6, back_y=2.1, leg_r=(0.52, 0.36), head=(1.05, 1.3, 1.0),
                               head_at=(-3.55, 7.9), snout=(0.66, 1.05, 0.58), snout_col=pearl, nose=C('#C9A3D9'),
                               paw_r=(0.5, 0.55, 0.42))
    for part in (b, h):
        gradient(part, [whiteDD, whiteD, white, white], 3.4 * k, 9.0 * k, fine, keep=(pearl, C('#C9A3D9')))
    for name in ('legFL', 'legFR', 'legBL', 'legBR'):
        gradient(c.part(name), [whiteDD, whiteD, white], 0, 4.6 * k, fine, keep=(hoof,))
    proud_eyes(c, h, [(0.55 * k, hz + 0.18 * k)], 0.42 * k, 0.42 * k, C('#B45CFF'), ring=C('#3A1F5A'),
               pupil=C('#3A1F5A'), lid=whiteD, iris2=C('#5CC8FF'), behind=hy - 0.9 * k)
    e = c.part('ears', 'ears', (0, hy + 0.2 * k, hz + 0.9 * k))
    for sx in (1, -1):
        for i in range(round(0.8 * k)):
            t = i / (0.8 * k)
            e.ell((sx * (0.62 * k), hy + 0.25 * k, hz + 0.85 * k + i), (0.26 * k * (1 - t) + 0.5, 0.18 * k, 0.5), white)
    for q in [q for q in e.v if q in h.v]:
        del e.v[q]
    # golden spiral horn
    horn = c.part('horn', 'glow', (0, hy - 0.4 * k, hz + 1.0 * k))
    L = round(2.0 * k)
    for i in range(L):
        t = i / L
        r = max(0.6, 0.38 * k * (1 - t))
        cz = hz + 0.85 * k + i
        cy = hy - 0.5 * k - t * 0.9 * k
        horn.ell((0, cy, cz), (r, r, 0.6), gold if (i + int(t * 6)) % 4 else C('#FFD93B'), True)
    # rainbow mane down the neck and a long rainbow tail
    mane = c.part('mane', 'glow', (0, hy, hz))
    roots = [(sx * 0.3 * k, hy + (0.3 + 0.45 * i) * k, hz + (1.1 - 0.42 * i) * k) for i in range(6 if fine else 4) for sx in (1, -1)]
    hair_locks(mane, k, roots, 1.5, 1.4, 0.5, lambda s, m: rainbow((m // 2) / 6 if fine else s), glow=True)
    for q in [q for q in mane.v if q in h.v or q in b.v or q in horn.v]:
        del mane.v[q]
    tail = c.part('tail', 'tail', (0, 3.5 * k, 5.6 * k))
    hair_locks(tail, k, [(dx * k, 3.5 * k, 5.6 * k) for dx in ((-0.3, 0.0, 0.3) if fine else (0.0,))], 2.4, 3.6, 0.6,
               lambda s, m: rainbow(s), glow=True, n=18, wave=0.25)
    # pearly feathered wings, gold leading edge
    wing(c, k, (0.9, -0.6, 6.0), 4.2, 2.4, 2.0, (pearl, white, C('#E8D9FF'), C('#D4C2FF')), C('#FFB8F0'),
         edge=gold if fine else None, thick=2, glow_tip=False)
    sparkle(b, (C('#FFD93B'), C('#3FA9FF')), 300, 41, fine)
    tidy(c)
    gems = [C('#FF4D6D'), C('#FF9A3D'), C('#FFD93B'), C('#4CD964'), C('#3FA9FF'), C('#9A5CFF')]
    orbit_ring(c, k, [(i * 60, 2.4 + (i % 2) * 0.5, 0.4, shard(g, g, tall=1.4))
                      for i, g in enumerate(gems)])
    return c


# ------------------------------------------------------------ Omega Chimera

def omega_chimera(c, H):
    """Lion, eagle and serpent fused under cosmic armour: a lion's maned
    head and body plated in midnight armour with gold trim and glowing
    runes, eagle wings, eagle talons at the front, and a serpent for a
    tail with its own head; rings of runes circle it."""
    k, fine = ctx(c, H * 0.86)  # a long, wide body: drawn a little smaller to stay in the triangle budget
    tan, tanD, mane_c, mane_d = C('#D9A35A'), C('#B07A35'), C('#7A3FB8'), C('#4E2585')
    arm, armD, armL, trim = C('#2A2457'), C('#1A163A'), C('#3D3680'), C('#FFC83D')
    rune, runeL, feather, featherD = C('#5CE1FF'), C('#C8F7FF'), C('#5A3A2A'), C('#3A2418')
    snake, snakeD, beak = C('#3FBF6A'), C('#287A45'), C('#FFB627')
    b, h, (hx, hy, hz) = beast(c, k, fine, tan, None, paw=tanD, body=(1.8, 2.7, 1.7), body_z=4.4, hip_z=3.8,
                               leg_x=1.15, front_y=-1.5, back_y=2.2, leg_r=(0.74, 0.55), head=(1.45, 1.4, 1.3),
                               head_at=(-3.1, 7.2), snout=(0.85, 0.85, 0.65), snout_col=C('#F0CF95'),
                               nose=C('#5A2A1A'))
    # eagle talons on the front legs
    for name in ('legFL', 'legFR'):
        lp = c.part(name)
        lp.paint(lambda p, cc, g: (beak, False) if p[2] < 1.6 * k else None)
    # armour: plates over the back and shoulders, gold trim, glowing runes
    def armour(p, cc, g):
        if g or p[2] < 4.4 * k:
            return None
        if abs(p[2] + .5 - 4.4 * k) < 0.6:
            return (trim, False)
        return (arm, False)
    b.paint(armour)
    if fine:
        b.paint(lambda p, cc, g: (armL, False) if cc == arm and (p[1] // max(1, round(0.7 * k))) % 2 == 0 and p[2] > 5.6 * k else None)
        b.paint(lambda p, cc, g: (trim, False) if cc in (arm, armL) and p[1] % round(1.4 * k) == 0 else None)
        b.paint(lambda p, cc, g: (rune, True) if cc in (arm, armL) and _hash(p[0] // 2, p[1] // 2, p[2] // 2, 5) % 23 == 0 else None)
    for name in ('legBL', 'legBR'):
        c.part(name).paint(lambda p, cc, g: (armD, False) if 2.0 * k < p[2] else None)
    gradient(h, [tanD, tan, tan], 6.0 * k, 8.5 * k, fine, keep=(C('#F0CF95'), C('#5A2A1A')))
    proud_eyes(c, h, [(0.62 * k, hz + 0.2 * k)], 0.46 * k, 0.4 * k, rune, ring=armD, pupil=armD, lid=tanD,
               iris2=C('#2E86E8'), behind=hy - 1.0 * k)
    for sx in (1, -1):
        h.ell((sx * 0.62 * k, hy - 1.0 * k, hz + 0.75 * k), (0.52 * k, 0.3 * k, 0.15 * k), tanD)
    # an armoured helm with a glowing rune
    helm = c.part('helm', 'glow', (0, hy, hz + 1.2 * k))
    helm.ell((0, hy + 0.1 * k, hz + 0.95 * k), (1.15 * k, 1.1 * k, 0.45 * k), trim, True)
    helm.ell((0, hy - 0.2 * k, hz + 1.25 * k), (0.32 * k, 0.32 * k, 0.32 * k), rune, True)
    for q in [q for q in helm.v if q in h.v]:
        del helm.v[q]
    # big violet mane
    mane = c.part('crest', 'static', (0, hy + 0.6 * k, hz))
    mane.ell((0, hy + 0.85 * k, hz - 0.2 * k), (1.85 * k, 0.9 * k, 1.85 * k), mane_c)
    mane.ell((0, hy + 1.35 * k, hz - 0.5 * k), (1.55 * k, 0.6 * k, 1.55 * k), mane_d)
    if fine:
        for i in range(12):
            a = i / 12 * math.pi * 2
            pts = [(math.cos(a) * (1.7 + 0.6 * s) * k, hy + (0.9 + 0.5 * s) * k, hz - 0.2 * k + math.sin(a) * (1.7 + 0.6 * s) * k,
                    max(0.55, 0.38 * (1 - s) * k)) for s in (j / 7 for j in range(8))]
            tube(mane, pts, lambda s: mane_c if s < 0.6 else C('#B45CFF'))
    for q in [q for q in mane.v if q in h.v or q in helm.v]:
        del mane.v[q]
    ears_pair(c, k, (1.15, hy / k + 0.2, hz / k + 1.1), 0.7, 0.32, tan, inner=tanD, lean=0.15)
    # eagle wings, raised
    wing(c, k, (1.3, 0.2, 5.8), 3.6, 2.4, 1.8, (feather, C('#7A5236'), C('#A8743F')), C('#FFFFFF'),
         edge=rune if fine else None, thick=2, glow_tip=False)
    # serpent tail ending in a snake's head
    t = tail_tube(c, k, (0, 3.6, 4.4), (0, 6.4, 3.2), (0, 5.4, 6.9), 0.55, 0.42, lambda s: snake if s > 0.15 else tan, n=34)
    gradient(t, [snakeD, snake], 2.5 * k, 6.5 * k, fine, keep=(tan,))
    if fine:
        t.paint(lambda p, cc, g: (C('#C8F27A'), False) if cc in (snake, snakeD) and (p[1] + p[2]) % 5 == 0 else None)
    t.ell((0, 5.0 * k, 7.35 * k), (0.62 * k, 0.85 * k, 0.55 * k), snake)
    for sx in (1, -1):
        t.put((round(sx * 0.45 * k) - (1 if sx < 0 else 0), round(4.6 * k), round(7.55 * k)), C('#FFD43B'), True)
    for j in range(round(0.6 * k)):  # forked tongue
        t.put((0, round(4.2 * k) - j, round(7.1 * k)), C('#FF3B5C'))
    tidy(c)

    def rune_ring(col, col2):
        def draw(part, centre, r):
            cx, cy, cz = centre
            a_out = math.atan2(cy - part.pivot[1], cx - part.pivot[0])
            ux, uy = -math.sin(a_out), math.cos(a_out)
            for i in range(48):
                a = i / 48 * math.pi * 2
                for rr in (r, r - 1):
                    q = (math.floor(cx + ux * math.cos(a) * rr), math.floor(cy + uy * math.cos(a) * rr), math.floor(cz + math.sin(a) * rr))
                    part.put(q, col2 if (i % 6 == 0 and rr == r) else col, True)
        return draw
    orbit_ring(c, k, [(30, 3.0, 0.62, rune_ring(rune, runeL)), (150, 5.6, 0.55, rune_ring(C('#B45CFF'), runeL)),
                      (270, 3.6, 0.6, rune_ring(trim, C('#FFF0A0')))])
    return c


# ------------------------------------------------------------ Magma Behemoth

def magma_behemoth(c, H):
    """A giant salamander of cooling basalt, lava glowing through the cracks
    of its hide, a smoking volcano rising from its back with a lava pool
    in its crater; meteors circle it."""
    k, fine = ctx(c, H * 0.92)  # a long, wide body: drawn a little smaller to stay in the triangle budget
    rock, rockL, rockD, rockDD = C('#4A3A3E'), C('#5E4A4C'), C('#33282C'), C('#241C20')
    lava, lavaL, lavaH, belly = C('#FF5A1A'), C('#FF9A1A'), C('#FFD84A'), C('#E0702A')
    b = c.part('body')
    # long low body, thick tail-root
    b.ell((0, 0.6 * k, 2.9 * k), (2.05 * k, 3.2 * k, 1.5 * k), rock)
    b.ell((0, -2.0 * k, 3.1 * k), (1.85 * k, 1.4 * k, 1.45 * k), rock)
    b.paint(lambda p, cc, g: (belly, False) if p[2] < 1.9 * k else None)
    # sprawled legs: hips out at the sides, elbows out, feet wide
    for fb, ly in (('F', -1.7), ('B', 2.3)):
        for sx, sd in ((1, 'R'), (-1, 'L')):
            hip = (sx * 1.5 * k, ly * k, 2.5 * k)
            knee = (sx * 2.25 * k, ly * k, 1.75 * k)
            foot = (sx * 2.35 * k, (ly - 0.2) * k, 0.55 * k)
            lp = c.part('leg' + fb + sd, 'leg' + fb + sd, hip)
            limb(lp, hip, knee, 0.85 * k, 0.75 * k, rock)
            limb(lp, knee, foot, 0.75 * k, 0.62 * k, rock)
            lp.ell((foot[0], foot[1] - 0.35 * k, 0.4 * k), (0.8 * k, 0.9 * k, 0.4 * k), rockD)
            for i in range(3):
                lp.put((math.floor(foot[0] + (i - 1) * 0.45 * k), math.floor(foot[1] - 1.25 * k), 0), lavaL, True)
            for q in [q for q in lp.v if q[2] < 0]:
                del lp.v[q]
            gradient(lp, [rockD, rock], 0, 3.0 * k, fine)
    # head: broad flat salamander head
    h = c.part('head', 'head', (0, -3.0 * k, 3.4 * k))
    hy, hz = -4.3 * k, 3.4 * k
    h.ell((0, hy, hz), (1.9 * k, 1.6 * k, 1.05 * k), rock)
    h.ell((0, hy - 0.9 * k, hz - 0.35 * k), (1.6 * k, 1.0 * k, 0.7 * k), rock)
    h.paint(lambda p, cc, g: (belly, False) if p[2] < hz - 0.6 * k else None)
    # glowing mouth line
    for p in list(h.v):
        if abs(p[2] + .5 - (hz - 0.45 * k)) < 0.6 and p[1] < hy - 0.3 * k:
            x, y, z = p
            if (x, y - 1, z) not in h.v or abs(x) > 1.4 * k:
                h.put(p, lava, True)
    proud_eyes(c, h, [(0.95 * k, hz + 0.45 * k)], 0.45 * k, 0.42 * k, lavaH, ring=rockDD, pupil=rockDD, lid=rockD,
               iris2=lavaL, slit=True, behind=hy - 1.2 * k)
    # lava cracks through the hide (fine), lava speckles (coarse)
    for part in [b, h]:
        gradient(part, [rockD, rock, rockL], 1.5 * k, 5.0 * k, fine, keep=(belly,))
        if fine:
            part.paint(lambda p, cc, g: (lava, True) if not g and cc != belly and abs(_fbm(p[0], p[1], p[2], 0.9 * k, 17) - 0.5) < 0.035 else None)
            part.paint(lambda p, cc, g: (lavaL, True) if cc == lava and _hash(*p, 2) % 4 == 0 else None)
        else:
            part.paint(lambda p, cc, g: (lava, True) if not g and cc != belly and _hash(p[0] // 2, p[1] // 2, p[2] // 2, 3) % 19 == 0 else None)
    # glowing spines along the back
    spines = c.part('crest', 'glow', (0, 1.0 * k, 4.4 * k))
    for i in range(7):
        y = (-2.4 + i * 0.8) * k
        if -0.6 * k < y < 2.2 * k:
            continue  # the volcano sits here
        top = max(p[2] for p in b.v if p[1] == round(y) and abs(p[0]) <= 1)
        for j in range(round(0.7 * k)):
            r = max(0.5, 0.35 * k * (1 - j / (0.7 * k)))
            spines.ell((0, y, top + j), (r, r, 0.5), lavaL if j < 0.4 * k else lavaH, True)
    # the volcano on its back
    vol = c.part('volcano', 'static', (0, 0.8 * k, 4.4 * k))
    vy, base = 0.8 * k, 3.9 * k
    for z in range(round(base), round(base + 3.2 * k)):
        t = (z - base) / (3.2 * k)
        r_out = (1.55 - 0.95 * t) * k
        r_in = (0.15 + 0.45 * t) * k if t > 0.6 else 0
        for x in range(-round(r_out) - 1, round(r_out) + 1):
            for y in range(round(vy - r_out) - 1, round(vy + r_out) + 1):
                d = math.hypot(x + .5, y + .5 - vy)
                if d <= r_out and d >= r_in:
                    vol.put((x, y, z), rockD if (_hash(x, y, z, 8) % 3 or not fine) else rockDD)
    # lava streams down the cone
    for a in (0.4, 2.2, 4.1) if fine else (0.4, 3.0):
        for z in range(round(base + 0.3 * k), round(base + 3.2 * k)):
            t = (z - base) / (3.2 * k)
            r_out = (1.55 - 0.95 * t) * k
            x = round(math.cos(a + t * 0.6) * r_out)
            y = round(vy + math.sin(a + t * 0.6) * r_out)
            vol.put((x, y, z), lava, True)
            vol.put((x - 1, y, z), lavaL, True)
    lava_top = round(base + 2.9 * k)
    pool = c.part('lava', 'glow', (0, vy, lava_top))
    pool.ell((0, vy, lava_top), (0.5 * k, 0.5 * k, 0.35 * k), lavaH, True)
    for q in [q for q in pool.v if q in vol.v]:
        del pool.v[q]
    # smoke puffs
    if fine:
        smoke = c.part('smoke', 'glow', (0, vy, lava_top + 1.0 * k))
        for i, (dx, dz, r) in enumerate(((0.0, 0.9, 0.55), (0.35, 1.6, 0.45), (-0.2, 2.2, 0.35))):
            for p in _ball_pts((dx * k, vy + 0.2 * k * i, lava_top + dz * k), r * k):
                smoke.put(p, C('#8E8494'))
        smoke.anim = 'static'
    # tail: thick, tapering, curling to one side
    tail = c.part('tail', 'tail', (0, 3.6 * k, 2.8 * k))
    pts = []
    for i in range(28):
        s = i / 27
        pts.append((math.sin(s * math.pi * 0.7) * 1.4 * k, 3.6 * k + s * 3.0 * k, 2.8 * k - s * 1.9 * k, max(0.6, (0.95 - 0.7 * s) * k)))
    tube(tail, pts, lambda s: rock)
    gradient(tail, [rockD, rock], 0.5 * k, 3.5 * k, fine)
    if fine:
        tail.paint(lambda p, cc, g: (lava, True) if abs(_fbm(p[0], p[1], p[2], 0.9 * k, 17) - 0.5) < 0.035 else None)
    tail.paint(lambda p, cc, g: (lavaL, True) if p[1] > 6.2 * k else None)
    tidy(c)

    def meteor(part, centre, r):
        cx, cy, cz = centre
        for p in _ball_pts(centre, r):
            part.put(p, rockD if _hash(*p, 4) % 3 else rockL)
            if fine and abs(_fbm(p[0], p[1], p[2], 0.35 * k, 9) - 0.5) < 0.05:
                part.put(p, lavaL, True)
        # a short glowing trail behind it (it travels counter-clockwise)
        a = math.atan2(cy - part.pivot[1], cx - part.pivot[0])
        tx, ty = math.sin(a), -math.cos(a)
        for j in range(1, round(1.4 * r) + 1):
            rr = max(0.5, r * 0.55 * (1 - j / (1.6 * r)))
            part.ell((cx + tx * (r + j), cy + ty * (r + j), cz + 0.15 * j), (rr, rr, rr), lava if j < r * 0.7 else lavaH, True)
    orbit_ring(c, k, [(20, 5.6, 0.62, meteor), (140, 3.6, 0.5, meteor), (250, 6.4, 0.55, meteor)])
    return c



# ------------------------------------------------------------ World Turtle

def world_turtle(c, H):
    """An old sea turtle carrying a little world: a grassy island on its
    shell with a blossoming tree, a pond and a waterfall spilling over the
    shell's rim; clouds circle it."""
    k, fine = ctx(c, H * 0.9)  # a wide shell: drawn a little smaller to stay in the triangle budget
    skin, skinL, skinD = C('#7FB86A'), C('#A2D488'), C('#5A8C4A')
    shell, shellD, shellL, rimc = C('#8A5A33'), C('#6A4224'), C('#A8743F'), C('#C99A55')
    grass, grassL, grassD, dirt = C('#5DC75A'), C('#8FE07A'), C('#3FA048'), C('#8A6230')
    water, waterL, foam = C('#3FA9FF'), C('#7FD3FF'), C('#E8F8FF')
    bark, leaf, leafL, blossom = C('#7A4E2A'), C('#4CC26A'), C('#7FE08A'), C('#FF8FC8')
    b = c.part('body')
    # shell: a low dome with plates
    sz = 2.3 * k
    b.ell((0, 0.5 * k, sz), (2.6 * k, 3.0 * k, 2.0 * k), shell, cond=lambda x, y, z: z + .5 >= sz - 0.35 * k)
    b.ell((0, 0.5 * k, sz - 0.3 * k), (2.75 * k, 3.15 * k, 0.45 * k), rimc)  # the rim
    b.ell((0, 0.5 * k, sz - 0.5 * k), (2.2 * k, 2.6 * k, 0.9 * k), skinL)  # plastron underneath

    def plates(p, cc, g):
        if cc != shell:
            return None
        u, v = (p[0] + .5) / (1.05 * k), (p[1] + .5 - 0.5 * k) / (1.05 * k)
        fu, fv = u - math.floor(u + (0.5 if math.floor(v) % 2 else 0)), v - math.floor(v)
        if min(fu, 1 - fu) < 0.08 or min(fv, 1 - fv) < 0.08:
            return (shellD, False)
        return (shellL if fine and (_hash(math.floor(u), math.floor(v), 0, 3) % 2) else shell, False)
    b.paint(plates)
    # four stubby legs out of the shell
    for fb, ly in (('F', -1.4), ('B', 2.4)):
        for sx, sd in ((1, 'R'), (-1, 'L')):
            hip = (sx * 1.7 * k, ly * k, 1.7 * k)
            foot = (sx * 2.35 * k, (ly - 0.15) * k, 0.55 * k)
            lp = c.part('leg' + fb + sd, 'leg' + fb + sd, hip)
            limb(lp, hip, foot, 0.72 * k, 0.62 * k, skin)
            lp.ell((foot[0], foot[1] - 0.25 * k, 0.4 * k), (0.72 * k, 0.85 * k, 0.4 * k), skinD)
            for i in range(3):
                lp.put((math.floor(foot[0] + (i - 1) * 0.4 * k), math.floor(foot[1] - 1.1 * k), 0), C('#E8DCC0'))
            for q in [q for q in lp.v if q[2] < 0]:
                del lp.v[q]
            if fine:
                lp.paint(lambda p, cc, g: (skinD, False) if cc == skin and _hash(*p, 5) % 5 == 0 else None)
    # head on a short neck
    h = c.part('head', 'head', (0, -2.4 * k, 2.4 * k))
    limb(b, (0, -1.8 * k, 2.0 * k), (0, -3.0 * k, 2.6 * k), 0.85 * k, 0.75 * k, skin)
    hy, hz = -3.7 * k, 2.95 * k
    h.ell((0, hy, hz), (1.05 * k, 1.15 * k, 0.9 * k), skin)
    h.ell((0, hy - 0.75 * k, hz - 0.2 * k), (0.75 * k, 0.6 * k, 0.6 * k), skin)
    gradient(h, [skinD, skin, skinL], hz - 0.9 * k, hz + 0.9 * k, fine)
    for x in range(-round(0.45 * k), round(0.45 * k)):  # a gentle smile
        f = front_at(h, x, round(hz - 0.38 * k - 0.15 * k * math.cos((x + .5) / (0.45 * k) * 1.4)))
        if f:
            h.put(f, skinD)
    proud_eyes(c, h, [(0.5 * k, hz + 0.3 * k)], 0.38 * k, 0.38 * k, C('#2E5A2A'), ring=INK, pupil=INK, lid=skinD,
               glow=False, behind=hy - 0.7 * k)
    # the little world on top: an island of grass and earth
    top = max(p[2] for p in b.v) + 1
    isl = c.part('island', 'static', (0, 0.5 * k, top))
    icx, icy = 0.0, 0.6 * k
    for x in range(-round(2.2 * k), round(2.2 * k) + 1):
        for y in range(round(icy - 2.4 * k), round(icy + 2.4 * k) + 1):
            d = math.hypot((x + .5) / (2.0 * k), (y + .5 - icy) / (2.3 * k))
            if fine:
                d += (_vnoise(x, y, 0, 0.6 * k, 7) - 0.5) * 0.18
            if d > 1.0:
                continue
            # seat the island on the shell's curve
            col_top = max([p[2] for p in b.v if p[0] == x and p[1] == y] or [top - 1])
            z0 = col_top + 1
            h_ = round((1.0 - d) * 0.8 * k) + 1
            for z in range(z0 - 1, z0 + h_):
                isl.put((x, y, z), grass if z == z0 + h_ - 1 else dirt)
    gradient(isl, [grassD, grass, grassL], top, top + 0.8 * k, fine, keep=(dirt,), only=lambda p, cc: cc != dirt)
    isl_top = {(x, y): z for (x, y, z) in isl.v}
    for (x, y, z) in list(isl.v):
        if isl_top.get((x, y), z) < z:
            isl_top[(x, y)] = z
    for (x, y), z in list(isl_top.items()):
        if isl.v[(x, y, z)][0] in (grass, grassD, grassL):
            isl_top[(x, y)] = z
    # flowers in the grass
    if fine:
        for (x, y), z in isl_top.items():
            hh = _hash(x, y, 0, 19) % 40
            if hh < 2:
                isl.put((x, y, z + 1), (C('#FFFFFF'), C('#FFD93B'))[hh])
    # a pond with a waterfall pouring off the shell's back-left edge
    pond_c = (-0.9 * k, 1.4 * k)
    for (x, y), z in isl_top.items():
        if math.hypot(x + .5 - pond_c[0], y + .5 - pond_c[1]) < 0.7 * k:
            isl.put((x, y, z), water)
    fall = c.part('waterfall', 'glow', (-1.9 * k, 2.4 * k, top))
    wx = -round(1.6 * k)
    for y in range(round(1.2 * k), round(1.6 * k)):
        col_top = isl_top.get((wx, y))
        if col_top is None:
            continue
        for x in range(wx - round(0.9 * k), wx + 1):
            if (x, y) in isl_top:
                isl.put((x, y, isl_top[(x, y)]), water)
        zx = col_top
        x = wx - round(0.9 * k)
        while zx > 0:
            # find the outer surface below and fall just outside it
            outside = min([q[0] for q in list(b.v) + list(isl.v) if q[1] == y and q[2] == zx] or [x + 1])
            xx = min(x, outside - 1)
            fall.put((xx, y, zx), foam if (zx + y) % 5 == 0 else (waterL if fine and (zx + y) % 3 == 0 else water), True)
            fall.put((xx - 1, y, zx), water, False)
            zx -= 1
    for q in [q for q in fall.v if q in b.v or q in isl.v]:
        del fall.v[q]
    # a blossoming tree near the front right
    tx, ty = round(0.7 * k), round(-0.2 * k)
    tz = isl_top.get((tx, ty), top + 2) + 1
    tree = c.part('tree', 'static', (tx, ty, tz))
    limb(tree, (tx, ty, tz), (tx + 0.2 * k, ty + 0.1 * k, tz + 2.1 * k), 0.38 * k, 0.26 * k, bark)
    for dx, dy, dz, r in ((0.2, 0.1, 2.6, 1.05), (-0.55, 0.3, 2.2, 0.75), (0.85, -0.2, 2.25, 0.7), (0.2, 0.6, 3.15, 0.65)):
        tree.ell((tx + dx * k, ty + dy * k, tz + dz * k), (r * k, r * k, r * 0.85 * k), leaf)
    gradient(tree, [C('#3FA048'), leaf, leafL], tz + 1.5 * k, tz + 3.6 * k, fine, keep=(bark,))
    tree.paint(lambda p, cc, g: (blossom, False) if cc != bark and _hash(*p, 23) % (9 if fine else 99) == 0 else None)
    # little tail
    tail_tube(c, k, (0, 3.3, 1.6), (0, 4.0, 1.4), (0, 4.3, 1.0), 0.42, 0.25, lambda s: skin)
    tidy(c)
    orbit_ring(c, k, [(0, 4.6, 0.75, cloud(WHITE, C('#DDEBFA'))), (120, 3.2, 0.62, cloud(WHITE, C('#DDEBFA'))),
                      (240, 5.2, 0.68, cloud(WHITE, C('#DDEBFA')))]
               + ([(60, 6.2, 0.3, star4(C('#FFE45C'), WHITE)), (300, 2.4, 0.42, ball(C('#FFD93B'), C('#FFF6B0'), glow=True, cap=True, fine=fine))] if fine else []))
    return c


# ------------------------------------------------------------ Candy Colossus

def candy_colossus(c, H):
    """A big friendly gummy golem standing on two chocolate-dipped feet, its
    body a strawberry gummy with sprinkles, candy-cane arms, a gumdrop face
    and a crown of gumballs; sweets circle it."""
    k, fine = ctx(c, H)
    gum, gumL, gumD, gumDD = C('#FF5C8A'), C('#FF8FB1'), C('#E83E6E'), C('#C02A55')
    choc, chocL, cane, caneR = C('#6A3A22'), C('#8A5232'), C('#FFFFFF'), C('#FF3B5C')
    sprinkles = [C('#FFD93B'), C('#4CD9FF'), C('#7CE07A'), C('#FFFFFF'), C('#B45CFF')]
    b = c.part('body')
    b.ell((0, 0.2 * k, 4.3 * k), (2.3 * k, 1.9 * k, 2.2 * k), gum)
    b.ell((0, 0.2 * k, 2.8 * k), (2.0 * k, 1.7 * k, 1.3 * k), gum)  # belly
    gradient(b, [gumDD, gumD, gum, gumL], 1.6 * k, 6.5 * k, fine)
    # gummy shine: a pale sheen on the upper front
    b.paint(lambda p, cc, g: (C('#FFC2D6'), False) if p[1] < -0.9 * k and ((p[0] + .5 + 0.8 * k) / (0.55 * k)) ** 2 + ((p[2] + .5 - 5.3 * k) / (0.8 * k)) ** 2 <= 1 else None)
    # sprinkles
    if fine:
        for p in list(b.v):
            x, y, z = p
            if (x, y - 1, z) not in b.v or (x, y, z + 1) not in b.v:
                hh = _hash(x, y, z, 77) % 26
                if hh < len(sprinkles) and b.v[p][0] != C('#FFC2D6'):
                    b.put(p, sprinkles[hh])
    # legs: thick gummy legs with chocolate-dipped feet
    for sx, sd in ((1, 'R'), (-1, 'L')):
        hip = (sx * 1.15 * k, 0.3 * k, 2.2 * k)
        lp = leg(c, 'leg' + sd, hip, (sx * 1.25 * k, 0.2 * k, 0.6 * k), 0.85 * k, 0.8 * k, gum, paw=choc,
                 paw_r=(0.95 * k, 1.15 * k, 0.6 * k))
        lp.paint(lambda p, cc, g: (chocL, False) if cc == choc and p[2] > 0.6 * k else None)
        gradient(lp, [gumDD, gumD], 0.8 * k, 2.2 * k, fine, keep=(choc, chocL))
    # candy-cane arms hanging at the sides (part of the body; they sway with it)
    for sx in (1, -1):
        sh = (sx * 2.2 * k, 0.1 * k, 5.2 * k)
        el = (sx * 2.85 * k, -0.2 * k, 3.6 * k)
        hand = (sx * 2.8 * k, -0.6 * k, 2.4 * k)
        pts = []
        for i in range(16):
            s = i / 15
            a, bq = (sh, el) if s < 0.5 else (el, hand)
            u = s * 2 if s < 0.5 else (s - 0.5) * 2
            pts.append((*(a[j] + (bq[j] - a[j]) * u for j in range(3)), 0.62 * k))
        arm = c.part('arms', 'static', sh)
        tube(arm, pts, lambda s: cane)
        arm.paint(lambda p, cc, g: (caneR, False) if (p[2] + round(abs(p[0]) * 0.6)) % round(0.7 * k) < round(0.3 * k) else None)
        arm.ell(hand, (0.7 * k, 0.7 * k, 0.7 * k), gumL)
    # head: a big gumdrop
    h = c.part('head', 'head', (0, 0.0, 6.3 * k))
    hz = 7.4 * k
    for z in range(round(6.2 * k), round(8.9 * k)):
        t = (z - 6.2 * k) / (2.7 * k)
        r = (1.55 - 0.4 * t * t) * k * (1 - 0.55 * max(0, t - 0.7) / 0.3)
        for x in range(-math.ceil(r), math.ceil(r) + 1):
            for y in range(-math.ceil(r), math.ceil(r) + 1):
                if ((x + .5) / r) ** 2 + ((y + .5) / (r * 0.92)) ** 2 <= 1:
                    h.put((x, y, z), C('#FFB627'))
    gradient(h, [C('#E8901A'), C('#FFB627'), C('#FFD45A')], 6.2 * k, 8.8 * k, fine)
    if fine:  # sugar crystals
        h.paint(lambda p, cc, g: (C('#FFF3C9'), False) if _hash(*p, 41) % 9 == 0 else None)
    proud_eyes(c, h, [(0.55 * k, hz + 0.05 * k)], 0.42 * k, 0.48 * k, C('#3A2A1A'), ring=INK, pupil=INK,
               lid=C('#E8901A'), glow=False)
    for x in range(-round(0.5 * k), round(0.5 * k)):  # a big smile
        z = round(hz - 0.75 * k + 0.25 * k * ((x + .5) / (0.5 * k)) ** 2)
        f = front_at(h, x, z)
        if f:
            h.put(f, C('#7A2A1A'))
    for sx in (1, -1):
        f = front_at(h, round(sx * 1.0 * k) - (1 if sx < 0 else 0), round(hz - 0.35 * k))
        if f:
            h.put(f, gumL)
    # crown of gumballs
    crown = c.part('crown', 'glow', (0, 0, 8.4 * k))
    cols = [C('#FF3B5C'), C('#3FA9FF'), C('#FFD93B'), C('#4CD964'), C('#B45CFF'), C('#FF9A3D')]
    n = 8
    for i in range(n):
        a = i / n * math.pi * 2
        crown.ell((math.cos(a) * 1.05 * k, math.sin(a) * 1.0 * k, 8.3 * k), (0.42 * k,) * 3, cols[i % len(cols)], True)
    crown.ell((0, 0, 9.0 * k), (0.5 * k,) * 3, C('#FFD93B'), True)
    for q in [q for q in crown.v if q in h.v]:
        del crown.v[q]
    tidy(c)

    def wrapped(col, col2):
        def draw(part, centre, r):
            cx, cy, cz = centre
            a_out = math.atan2(cy - part.pivot[1], cx - part.pivot[0])
            ux, uy = -math.sin(a_out), math.cos(a_out)
            for p in _ball_pts(centre, r * 0.7):
                part.put(p, col2 if (p[0] + p[2]) % 3 == 0 else col)
            for sd in (-1, 1):
                for j in range(1, round(r * 0.8) + 1):
                    w = round(j * 0.6)
                    for dz in range(-w, w + 1):
                        part.put((math.floor(cx + ux * sd * (r * 0.6 + j)), math.floor(cy + uy * sd * (r * 0.6 + j)), math.floor(cz + dz)), col)
        return draw

    def lolly(col, col2):
        def draw(part, centre, r):
            cx, cy, cz = centre
            a_out = math.atan2(cy - part.pivot[1], cx - part.pivot[0])
            ux, uy = -math.sin(a_out), math.cos(a_out)
            for i in range(-round(r), round(r) + 1):
                for j in range(-round(r), round(r) + 1):
                    d = math.hypot(i, j)
                    if d <= r:
                        ang = math.atan2(j, i)
                        sw = (ang + d / r * 4.0) % (math.pi * 2 / 3) < math.pi / 3
                        part.put((math.floor(cx + ux * i), math.floor(cy + uy * i), math.floor(cz + j)), col if sw else col2)
            for j in range(round(r), round(r * 2.3)):
                part.put((math.floor(cx), math.floor(cy), math.floor(cz - j)), WHITE)
        return draw
    orbit_ring(c, k, [(0, 4.6, 0.6, wrapped(C('#4CD9FF'), WHITE)), (90, 6.2, 0.62, lolly(C('#FF3B5C'), WHITE)),
                      (180, 3.4, 0.55, wrapped(C('#FFD93B'), C('#FF9A3D'))), (270, 5.6, 0.62, lolly(C('#7CE07A'), C('#FFF6B0')))]
               + ([(45, 2.4, 0.42, ball(C('#B45CFF'), C('#D9B8FF'), cap=True, fine=fine)),
                   (225, 7.2, 0.4, ball(C('#FF9A3D'), C('#FFD45A'), cap=True, fine=fine))] if fine else []))
    return c


# ------------------------------------------------------------ Crystal Hydra

def crystal_hydra(c, H):
    """A drake of living ice crystal with three necks: a ruby head, a
    sapphire head (in the middle, highest) and an emerald head; crystal
    spikes down its back and shards circling it."""
    k, fine = ctx(c, H * 0.92)
    ice, iceL, iceD, iceDD = C('#BFE3F5'), C('#E6F6FF'), C('#8EC2E0'), C('#6A9AC4')
    gems = {'ruby': (C('#E8304A'), C('#FF7A8A'), C('#A01830')), 'sapphire': (C('#2E6BE8'), C('#6FA4FF'), C('#1A3FA0')),
            'emerald': (C('#22B85A'), C('#6FE89A'), C('#127A3A'))}
    b, _h0, _ = beast(c, k, fine, ice, iceL, paw=iceD, body=(1.8, 2.6, 1.6), body_z=4.0, hip_z=3.5, leg_x=1.15,
                      front_y=-1.3, back_y=2.1, leg_r=(0.72, 0.52), neck=False, head=(0.5, 0.5, 0.5), head_at=(0, 4.0),
                      snout=(0.3, 0.3, 0.3), claw=C('#FFFFFF'))
    c.parts.remove(_h0)  # the frame's head: this one has three of its own
    gradient(b, [iceDD, iceD, ice, iceL], 2.4 * k, 6.0 * k, fine, keep=(iceL,))
    for name in ('legFL', 'legFR', 'legBL', 'legBR'):
        gradient(c.part(name), [iceDD, iceD, ice], 0, 3.5 * k, fine, keep=(C('#FFFFFF'),))
    # facets: lighter and darker planes across the crystal hide
    if fine:
        b.paint(lambda p, cc, g: (_shade(cc, 1.1 if (p[0] + 2 * p[1] - p[2]) // round(0.8 * k) % 2 else 0.92), False) if not g else None)
    # three necks, one 'head' part so they turn together
    h = c.part('head', 'head', (0, -1.8 * k, 5.2 * k))
    eyes_at = []
    for name, sx, top, fwd in (('ruby', -1, 7.6, -2.9), ('sapphire', 0, 9.0, -3.6), ('emerald', 1, 7.6, -2.9)):
        col, colL, colD = gems[name]
        nb = (sx * 0.8 * k, -1.5 * k, 4.6 * k)
        hx_, hy_, hz_ = sx * 2.5 * k, fwd * k, top * k
        ctrl = (sx * 2.1 * k, -1.6 * k, (top - 1.6) * k)
        for i in range(24):
            s = i / 23
            q = tuple((1 - s) ** 2 * a + 2 * (1 - s) * s * cc + s * s * e for a, cc, e in zip(nb, ctrl, (hx_, hy_ + 0.8 * k, hz_ - 0.5 * k)))
            b.ell(q, ((0.75 - 0.25 * s) * k,) * 3, ice) if s < 0.2 else h.ell(q, ((0.75 - 0.25 * s) * k,) * 3, _mix(ice, col, 0.3 + 0.5 * s))
        h.ell((hx_, hy_, hz_), (0.9 * k, 1.05 * k, 0.8 * k), col)
        h.ell((hx_, hy_ - 1.05 * k, hz_ - 0.25 * k), (0.56 * k, 0.8 * k, 0.45 * k), col)
        gradient(h, [colD, col, colL], hz_ - 0.8 * k, hz_ + 0.8 * k, fine,
                 only=lambda p, cc, hx_=hx_, hy_=hy_, hz_=hz_: math.dist((p[0], p[1], p[2]), (hx_, hy_, hz_)) < 1.9 * k)
        # crystal horns
        for hs in (1, -1):
            for j in range(round(0.9 * k)):
                r_ = max(0.5, 0.22 * k * (1 - j / (0.9 * k)))
                h.ell((hx_ + hs * 0.5 * k, hy_ + 0.45 * k + j * 0.7, hz_ + 0.6 * k + j), (r_, r_, 0.5), colL)
        eyes_at.append((hx_, hy_, hz_))
    # eyes for each head, one blink part
    eyes = c.part('eyes', 'blink', h.pivot)
    for hx_, hy_, hz_ in eyes_at:
        for hs in (1, -1):
            ex, ez = hx_ + hs * 0.45 * k, hz_ + 0.2 * k
            for x in range(math.floor(ex - 0.3 * k), math.ceil(ex + 0.3 * k)):
                for z in range(math.floor(ez - 0.25 * k), math.ceil(ez + 0.25 * k)):
                    if ((x + .5 - ex) / (0.3 * k)) ** 2 + ((z + .5 - ez) / (0.25 * k)) ** 2 > 1:
                        continue
                    f = front_at(h, x, z, behind=hy_ - 1.0 * k)
                    if f:
                        shn = z + .5 > ez + 0.05 * k and (x + .5 - ex) * hs < 0
                        eyes.put((f[0], f[1] - 1, f[2]), WHITE if shn else C('#FFF3A0'), True)
    for q in [q for q in h.v if q in b.v]:
        del h.v[q]
    # crystal spikes down the back
    spikes = c.part('crest', 'glow', (0, 0, 5.6 * k))
    for i in range(6):
        y = (-0.6 + i * 0.75) * k
        col_ = (gems['ruby'][1], gems['sapphire'][1], gems['emerald'][1])[i % 3]
        tops = [p[2] for p in b.v if p[1] == round(y) and abs(p[0] + .5) <= 1]
        if not tops:
            continue
        top = max(tops)
        L = round((1.1 - 0.08 * i) * k)
        for j in range(L):
            r = max(0.5, 0.42 * k * (1 - j / L))
            spikes.ell((0, y, top + j), (r, r * 0.7, 0.5), col_ if j < L * 0.7 else WHITE, True)
    # tail with a crystal tip
    t = tail_tube(c, k, (0, 3.4, 4.0), (0, 5.8, 3.0), (0, 6.6, 4.4), 0.62, 0.3, lambda s: ice)
    gradient(t, [iceDD, iceD, ice], 2.5 * k, 5.0 * k, fine)
    t.ell((0, 6.7 * k, 4.8 * k), (0.4 * k, 0.4 * k, 0.75 * k), gems['sapphire'][1], True)
    tidy(c)
    orbit_ring(c, k, [(0, 3.4, 0.55, shard(gems['ruby'][0], gems['ruby'][1])),
                      (120, 5.4, 0.55, shard(gems['sapphire'][0], gems['sapphire'][1])),
                      (240, 3.8, 0.55, shard(gems['emerald'][0], gems['emerald'][1]))]
               + ([(60, 6.6, 0.4, shard(iceD, iceL)), (180, 2.4, 0.4, shard(iceD, iceL)), (300, 6.0, 0.4, shard(iceD, iceL))] if fine else []))
    return c


BUILDERS = {
    'SolarLion': solar_lion,
    'AuroraStag': aurora_stag,
    'VoidKitsune': void_kitsune,
    'PrismAlicorn': prism_alicorn,
    'OmegaChimera': omega_chimera,
    'MagmaBehemoth': magma_behemoth,
    'WorldTurtle': world_turtle,
    'CandyColossus': candy_colossus,
    'CrystalHydra': crystal_hydra,
}
