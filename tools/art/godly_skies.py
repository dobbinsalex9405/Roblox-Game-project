"""Godly creatures that fly, float or swim: Clockwork Leviathan, Thunder
Kraken, Eclipse Dragon, Mecha Dragon, Chrono Owl, Cosmic Whale, Crystal
Swan, Butterfly Empress and Hurricane Roc. See godly_common.py for the
standard they follow (every Godly hovers in game)."""
import math

from godly_common import (C, INK, WHITE, tilt, _ball_pts, _fbm, _hash, _mix, _shade, ball, cloud, ctx, front_at,
                          gradient, leg, limb, mirror_put, mottle, orbit_ring, proud_eyes, shard, side_eyes, sparkle, star4, tidy,
                          tube, wing)


def bez(p0, p1, p2, s):
    return tuple((1 - s) ** 2 * a + 2 * (1 - s) * s * b + s * s * c for a, b, c in zip(p0, p1, p2))


def gear(col, col2, glow=False, teeth=10):
    """A cog standing upright, facing out from the orbit's centre."""
    def draw(part, centre, r):
        cx, cy, cz = centre
        a_out = math.atan2(cy - part.pivot[1], cx - part.pivot[0])
        ux, uy = -math.sin(a_out), math.cos(a_out)
        nx, ny = math.cos(a_out), math.sin(a_out)
        R = r
        for i in range(-math.ceil(R) - 1, math.ceil(R) + 2):
            for j in range(-math.ceil(R) - 1, math.ceil(R) + 2):
                d = math.hypot(i + .5, j + .5)
                ang = math.atan2(j + .5, i + .5)
                tooth = math.cos(ang * teeth) > 0.2
                outer = R + (0.9 if tooth else 0)
                if d > outer or d < R * 0.32:
                    continue
                spoke = d < R * 0.72 and min(abs(math.sin(ang * 2)), abs(math.cos(ang * 2))) > 0.35
                if spoke:
                    continue
                for t in (0, 1):
                    q = (math.floor(cx + ux * (i + .5) + nx * t), math.floor(cy + uy * (i + .5) + ny * t), math.floor(cz + j + .5))
                    part.put(q, col2 if d > R * 0.85 or d < R * 0.45 else col, glow)
    return draw


def drake(c, k, fine, col, belly, *, wing_cols, wing_tip, wing_edge=None, membrane=True, horn=WHITE,
          body_z=3.8, head_at=(-4.3, 8.2), span=4.6, rise=3.0, chord=2.8):
    """A dragon frame: body, four legs, a long neck, a dragon head (long
    snout, jaw line with fangs, brow ridges, horns swept back) and a long
    tail; big wings raised and spread. Returns (body, head, head centre)."""
    b = c.part('body')
    b.ell((0, 0.6 * k, body_z * k), (1.55 * k, 2.6 * k, 1.45 * k), col)
    b.ell((0, -1.2 * k, (body_z + 0.3) * k), (1.5 * k, 1.4 * k, 1.5 * k), col)
    if belly is not None:
        b.paint(lambda p, cc, g: (belly, False) if p[2] < (body_z - 0.7) * k else None)
    from godly_common import four_legs
    four_legs(c, k, -1.2, 2.0, 1.15, body_z - 0.5, 0.82, 0.6, col, paw=col, claw=WHITE, splay=0.3)  # low, splayed reptile legs
    hy, hz = head_at
    # a long neck curving up and forward
    neck = [bez((0, -1.7 * k, (body_z + 0.8) * k), (0, -2.6 * k, (body_z + 3.4) * k), (0, (hy + 0.8) * k, (hz - 0.3) * k), s_)
            for s_ in (i / 23 for i in range(24))]
    for i, q in enumerate(neck):
        r = (0.95 - 0.3 * i / 23) * k
        b.ell(q, (r, r, r), col)
    c.neck_pts = neck
    h = c.part('head', 'head', (0, (hy + 0.8) * k, (hz - 0.3) * k))
    h.ell((0, hy * k, hz * k), (1.0 * k, 1.05 * k, 0.88 * k), col)  # skull
    h.ell((0, (hy - 1.35) * k, (hz - 0.1) * k), (0.62 * k, 1.15 * k, 0.5 * k), col)  # long snout
    jaw = _shade(col, 0.78)
    h.ell((0, (hy - 1.1) * k, (hz - 0.62) * k), (0.55 * k, 1.1 * k, 0.26 * k), jaw)  # lower jaw
    for p in list(h.v):  # the jaw line
        if abs(p[2] + .5 - (hz - 0.42) * k) < 0.6 and p[1] < (hy - 0.4) * k:
            x, y, z = p
            if (x, y - 1, z) not in h.v or (x + 1, y, z) not in h.v or (x - 1, y, z) not in h.v:
                h.put(p, INK)
    for sx in (1, -1):
        # fangs at the corners of the mouth, on the sides of the jaw a little
        # back from the tip, pointing down
        fz = round((hz - 0.42) * k)
        fy = round((hy - 1.75) * k)
        xs = [q[0] for q in h.v if q[1] == fy and q[2] == fz]
        if xs:
            fx = max(xs) if sx > 0 else min(xs)
            for dz in range(max(2, round(0.32 * k))):
                h.put((fx, fy, fz - dz), WHITE)
                if dz < 2:
                    h.put((fx, fy + 1, fz - dz), WHITE)
        f = front_at(h, round(sx * 0.25 * k) - (1 if sx < 0 else 0), round((hz + 0.15) * k))
        if f:
            h.put(f, INK)  # nostrils
        h.ell((sx * 0.55 * k, (hy - 0.55) * k, (hz + 0.62) * k), (0.42 * k, 0.55 * k, 0.18 * k), jaw)  # brow ridge
        pts = [(sx * (0.5 + 0.55 * s_) * k, (hy + 0.3 + 2.0 * s_) * k, (hz + 0.6 + 0.9 * s_ - 0.35 * s_ * s_) * k,
                max(0.55, (0.32 - 0.22 * s_) * k)) for s_ in (i / 15 for i in range(16))]
        tube(h, pts, lambda s_: horn)
    wing(c, k, (1.0, 0.1, body_z + 1.0), span, rise, chord, wing_cols, wing_tip, edge=wing_edge,
         thick=2, membrane=membrane, ribs=_shade(wing_cols[0], 0.7) if membrane else None, glow_tip=not membrane)
    t = c.part('tail', 'tail', (0, 3.0 * k, body_z * k))
    pts = []
    for i in range(40):
        s_ = i / 39
        q = bez((0, 3.0 * k, body_z * k), (0.2 * k, 6.4 * k, (body_z - 0.6) * k), (2.4 * k, 6.2 * k, 1.2 * k), s_)
        pts.append((*q, max(0.55, (0.9 - 0.7 * s_) * k)))
    tube(t, pts, lambda s_: col)
    c.tail_pts = pts  # for plated segments
    return b, h, (0, hy * k, hz * k)


# ------------------------------------------------------------ Eclipse Dragon

def eclipse_dragon(c, H):
    """A dragon split down the middle: its right side sunlit gold, its left
    moonlit silver, with a glowing eclipse ring on its chest; a sun and a
    moon circle it."""
    k, fine = ctx(c, H * 0.9)
    gold, goldL, goldD = C('#FFB21A'), C('#FFD45A'), C('#E0820F')
    silver, silverL, silverD = C('#D6DCE8'), C('#F4F6FB'), C('#B4BAC6')  # moonlit silver-white
    b, h, (hx, hy, hz) = drake(c, k, fine, gold, None, wing_cols=(goldD, gold, goldL), wing_tip=C('#FFF0A0'),
                               horn=C('#FFF6D8'))

    def split(p, cc, g, edge=0.0):
        if g or cc in (INK, WHITE, C('#FFF6D8')):
            return None
        left = p[0] + .5 < edge
        z = p[2] / (8.5 * k)
        if left:
            return ((silverD if z < 0.35 else (silver if z < 0.7 else silverL)), False) if fine else (silver, False)
        return ((goldD if z < 0.35 else (gold if z < 0.7 else goldL)), False) if fine else (gold, False)
    for part in c.parts:
        if part.name in ('wingL',):
            part.paint(lambda p, cc, g: ((silverD, False) if cc == goldD else ((silver, False) if cc == gold else ((silverL, False) if cc == goldL else ((C('#D8E6FF'), True) if g else None)))))
        elif part.name == 'head':
            # the split runs down the middle of the face; the silver half
            # reaches a little past the middle so it shows from the front
            # three-quarter view as well
            part.paint(lambda p, cc, g: split(p, cc, g, 0.35 * k))
        elif part.name != 'wingR':
            part.paint(split)
    # scale shimmer and stars on the moon side
    sparkle(b, (WHITE, C('#BFE3FF')), 120, 51, fine, only=lambda p, cc: p[0] < 0)
    sparkle(b, (C('#FFF6B0'),), 160, 52, fine, only=lambda p, cc: p[0] >= 0)
    proud_eyes(c, h, [(0.6 * k, hz + 0.25 * k)], 0.36 * k, 0.32 * k, C('#FF7A1A'), ring=INK, pupil=INK,
               lid=goldD, iris2=C('#FFD43B'), slit=True, behind=hy * 1.0 - 0.75 * k)
    eyes = c.part('eyes')
    eyes.paint(lambda p, cc, g: ((C('#5CC8FF'), True) if p[0] < 0 and cc == C('#FF7A1A') else ((C('#BFE3FF'), True) if p[0] < 0 and cc == C('#FFD43B') else None)))
    # the eclipse on its chest: a dark disc in a glowing corona
    ring = c.part('eclipse', 'glow', (0, -2.6 * k, 4.9 * k))
    cz, cy = 4.9 * k, None
    for x in range(-round(1.1 * k), round(1.1 * k) + 1):
        for z in range(round(cz - 1.1 * k), round(cz + 1.1 * k) + 1):
            d = math.hypot(x + .5, z + .5 - cz) / (1.0 * k)
            if d > 1:
                continue
            f = front_at(b, x, z)
            if f:
                if d < 0.5:
                    ring.put((f[0], f[1] - 1, f[2]), C('#2A2457'), False)  # the moon's disc, raised
                else:
                    ring.put((f[0], f[1] - 1, f[2]), C('#FFF0A0') if d < 0.7 else C('#FFB21A'), True)
    tidy(c)
    orbit_ring(c, k, [(0, 5.0, 0.8, ball(C('#FFB21A'), C('#FFE45C'), glow=True, bands=True, fine=fine)),
                      (180, 5.4, 0.7, ball(C('#D8DDF0'), C('#A8AECB'), speck=C('#9AA0C0'), seed=11, fine=fine))]
               + ([(90, 2.8, 0.36, star4(WHITE, C('#BFE3FF'))), (270, 7.0, 0.36, star4(C('#FFF0A0'), C('#FFB21A')))] if fine else []))
    return c


# ------------------------------------------------------------ Mecha Dragon

def mecha_dragon(c, H):
    """A robot dragon in steel and red armour, a glowing visor, a reactor
    core in its chest and angular jet wings with thrusters; little drones
    circle it."""
    k, fine = ctx(c, H * 0.9)
    steel, steelL, steelD, red, redD = C('#9AA6B8'), C('#C3CCDA'), C('#5E6878'), C('#E8304A'), C('#A81E32')
    core = C('#5CE1FF')
    b, h, (hx, hy, hz) = drake(c, k, fine, steel, steelD, wing_cols=(steelD, steel, steelL), wing_tip=red,
                               membrane=False, horn=steelL)
    # plated segments along the neck and tail: a dark seam every few
    # points, red plates on alternate segments' top
    t = c.part('tail')

    def plates(part, pts, every, red_top):
        def seg(p, cc, g):
            if g or cc not in (steel, steelD):
                return None
            i = min(range(len(pts)), key=lambda j: (pts[j][0] - p[0] - .5) ** 2 + (pts[j][1] - p[1] - .5) ** 2
                    + (pts[j][2] - p[2] - .5) ** 2)
            if i % every == 0:
                return (_shade(steelD, 0.8), False)
            if red_top(p, pts[i]) and (i // every) % 2 == 0:
                return (red, False)
            return (steel if (i // every) % 2 else steelL, False)
        part.paint(seg)
    plates(t, [q[:3] for q in c.tail_pts], 4, lambda p, q: p[2] + .5 > q[2])
    plates_n = c.neck_pts
    nk = lambda p: p[1] < -1.6 * k and p[2] > 4.6 * k  # the neck's voxels in the body part
    for p in [p for p in b.v if nk(p)]:
        cc, g = b.v[p]
        if g or cc not in (steel, steelD):
            continue
        i = min(range(len(plates_n)), key=lambda j: sum((plates_n[j][a] - p[a] - .5) ** 2 for a in range(3)))
        if i % 3 == 0:
            b.v[p] = (_shade(steelD, 0.8), False)
        elif p[1] + .5 < plates_n[i][1] - 0.2 * k:  # the throat side
            b.v[p] = (steelD, False)
        else:
            b.v[p] = ((red if (i // 3) % 2 == 0 else steel), False)
    for part in c.parts:
        if part.name == 'body' or part.name.startswith('leg'):
            # armour panels: red plates on top, steel below, panel seams
            part.paint(lambda p, cc, g: (red, False) if not g and p[2] > 5.0 * k and cc == steel else None)
            if fine:
                part.paint(lambda p, cc, g: (_shade(cc, 0.72), False) if not g and cc in (steel, red) and (p[1] % round(0.9 * k) == 0 or p[2] % round(1.1 * k) == 0) else None)
                part.paint(lambda p, cc, g: (steelL, False) if cc == steel and _hash(*p, 61) % 37 == 0 else None)  # rivets
    for name in ('wingL', 'wingR'):
        w = c.part(name)
        w.paint(lambda p, cc, g: (redD, False) if cc == steelD and p[2] % 3 == 0 else None)
    # visor across the eyes instead of eyes
    eyes = c.part('eyes', 'blink', h.pivot)
    for x in range(-round(0.95 * k), round(0.95 * k)):
        for z in range(round(hz + 0.05 * k), round(hz + 0.4 * k)):
            f = front_at(h, x, z, behind=hy - 1.0 * k)
            if f:
                h.put(f, INK)
                eyes.put((f[0], f[1] - 1, f[2]), core if (x + z) % 4 else WHITE, True)
    # armoured snout: a red stripe down the top of the snout, steel elsewhere
    h.paint(lambda p, cc, g: (red, False) if cc == steel and abs(p[0] + .5) < 0.3 * k and p[2] > hz + 0.25 * k
            and p[1] < hy - 0.6 * k else None)
    # reactor core
    rc = c.part('core', 'glow', (0, -2.5 * k, 4.6 * k))
    for x in range(-round(0.7 * k), round(0.7 * k) + 1):
        for z in range(round(4.6 * k - 0.7 * k), round(4.6 * k + 0.7 * k) + 1):
            d = math.hypot(x + .5, z + .5 - 4.6 * k) / (0.7 * k)
            f = front_at(b, x, z)
            if f and d <= 1:
                rc.put((f[0], f[1] - 1, f[2]), WHITE if d < 0.35 else (core if d < 0.75 else C('#2E86E8')), True)
    # thruster nozzles on each wing's trailing (lower, rear) edge, glowing
    # blue out of the back
    blue, blueL = C('#2E9BFF'), C('#BFF0FF')
    for name in ('wingR', 'wingL'):
        w = c.part(name)
        xs = sorted({p[0] for p in w.v}, key=abs)
        for frac in (0.3, 0.62):
            x = xs[min(len(xs) - 1, int(frac * len(xs)))]
            col_v = [p for p in w.v if p[0] == x]
            lo = min(p[2] for p in col_v)
            y = max(p[1] for p in col_v if p[2] <= lo + 1)
            cx, cy, cz = x + .5, y + 0.2 * k, lo + 0.45 * k
            w.ell((cx, cy, cz), (0.36 * k, 0.55 * k, 0.36 * k), steelD)
            w.ell((cx, cy + 0.45 * k, cz), (0.27 * k, 0.2 * k, 0.27 * k), blue, True)
            w.ell((cx, cy + 0.62 * k, cz), (0.15 * k, 0.15 * k, 0.15 * k), blueL, True)
    tidy(c)

    def drone(part, centre, r):
        cx, cy, cz = centre
        part.ell(centre, (r * 0.8, r * 0.8, r * 0.5), steel)
        part.ell((cx, cy, cz - r * 0.15), (r * 0.35, r * 0.35, r * 0.3), red, True)
        for dx, dy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
            px, py = cx + dx * r * 0.45, cy + dy * r * 0.45
            part.ell((px, py, cz + r * 0.5), (r * 0.3, r * 0.3, 0.5), steelL)
            part.put((math.floor(px), math.floor(py), math.floor(cz + r * 0.5) - 1), core, True)
    orbit_ring(c, k, [(30, 3.0, 0.5, drone), (150, 5.6, 0.5, drone), (270, 3.8, 0.5, drone)])
    return c


# ------------------------------------------------------------ Chrono Owl

def bird_body(c, k, fine, col, belly, *, body=(1.9, 1.8, 2.2), body_z=3.6, head_r=1.55, head_z=6.5, leg_col,
              talon, legs_x=0.75):
    """A round bird: body, a big head, two short legs with talons."""
    b = c.part('body')
    b.ell((0, 0.2 * k, body_z * k), (body[0] * k, body[1] * k, body[2] * k), col)
    if belly is not None:
        b.paint(lambda p, cc, g: (belly, False) if p[1] < -0.6 * k and p[2] < (body_z + 1.2) * k else None)
    for sx, sd in ((1, 'R'), (-1, 'L')):
        hip = (sx * legs_x * k, 0.0, (body_z - body[2] * 0.7) * k)
        lp = leg(c, 'leg' + sd, hip, (sx * legs_x * k, -0.1 * k, 0.4 * k), 0.38 * k, 0.3 * k, leg_col, paw=leg_col,
                 paw_r=(0.45 * k, 0.6 * k, 0.3 * k), claw=talon)
    h = c.part('head', 'head', (0, 0, (head_z - 0.9) * k))
    h.ell((0, -0.2 * k, head_z * k), (head_r * 1.05 * k, head_r * 0.95 * k, head_r * 0.92 * k), col)
    return b, h


def clock_face(c, h, k, cx, cz, r, behind):
    """A clock-face eye: a white dial with hour marks and two hands, in the
    `eyes` part, proud of the face."""
    eyes = c.part('eyes', 'blink', h.pivot)
    for x in range(math.floor(cx - r) - 1, math.ceil(cx + r) + 1):
        for z in range(math.floor(cz - r) - 1, math.ceil(cz + r) + 1):
            dx, dz = x + .5 - cx, z + .5 - cz
            d = math.hypot(dx, dz) / r
            if d > 1:
                continue
            f = front_at(h, x, z, behind)
            if not f:
                continue
            h.put(f, C('#6A4A2A'))
            ang = math.atan2(dz, dx)
            if d > 0.86:
                col, g = C('#FFC83D'), True  # brass rim
            elif d > 0.68 and abs(math.sin(ang * 6)) < 0.25:
                col, g = INK, False  # hour marks
            elif (abs(dx) < 0.6 and 0 < dz < r * 0.62) or (abs(dz) < 0.6 and 0 < dx * (1 if cx > 0 else -1) < r * 0.45):
                col, g = INK, False  # the hands
            else:
                col, g = C('#FFF6DA'), True
            eyes.put((f[0], f[1] - 1, f[2]), col, g)
    return eyes


def chrono_owl(c, H):
    """A great owl with clock-face eyes, a brass beak and wings of starlight
    (deep night blue, scattered with glowing stars, tipped with gold); an
    hourglass circles it."""
    k, fine = ctx(c, H)
    plume, plumeL, plumeD, cream = C('#4A3F8C'), C('#6A5FB8'), C('#2E2766'), C('#E8DDF5')
    night, nightL, gold = C('#1E2A6A'), C('#2E3F9A'), C('#FFC83D')
    b, h = bird_body(c, k, fine, plume, cream, body=(2.0, 1.9, 2.3), body_z=3.4, head_r=1.7, head_z=6.4,
                     leg_col=C('#C9A060'), talon=INK)
    for part in (b, h):
        gradient(part, [plumeD, plume, plume, plumeL], 1.2 * k, 8.2 * k, fine, keep=(cream,))
    # chest feather chevrons
    if fine:
        b.paint(lambda p, cc, g: (C('#C9BDE6'), False) if cc == cream and (p[2] + abs(p[0] + .5) // 2) % round(0.6 * k) == 0 else None)
    # facial disc: two pale rings round the eyes
    for sx in (1, -1):
        h.ell((sx * 0.75 * k, -1.2 * k, 6.45 * k), (0.95 * k, 0.6 * k, 0.95 * k), C('#B8AEE0'))
    for sx in (1, -1):
        clock_face(c, h, k, sx * 0.78 * k, 6.5 * k, 0.72 * k, behind=-2.2 * k)
    # brass beak
    for i in range(round(0.8 * k)):
        w = max(1, round(0.3 * k * (1 - i / (0.8 * k))))
        for x in range(-w, w):
            f = front_at(h, x, round(6.0 * k) - i)
            if f:
                h.put((f[0], f[1] - 1 - (i // 3), f[2]), gold)
    # ear tufts
    e = c.part('ears', 'ears', (0, 0, 7.7 * k))
    for i in range(round(1.0 * k)):
        mirror_put(e, (round(1.1 * k + i * 0.35), round(-0.3 * k), round(7.6 * k) + i), plumeL if i < 0.6 * k else gold)
        mirror_put(e, (round(1.1 * k + i * 0.35) - 1, round(-0.3 * k), round(7.6 * k) + i), plume)
    # starlight wings
    wing(c, k, (1.6, 0.2, 5.0), 4.2, 2.4, 2.2, (night, nightL, C('#3E52B8')), gold, edge=None, thick=2)
    for name in ('wingL', 'wingR'):
        sparkle(c.part(name), (WHITE, C('#BFE3FF'), gold), 14, 71, fine)
    # tail fan
    t = c.part('tail', 'tail', (0, 1.8 * k, 2.2 * k))
    for i in range(round(1.6 * k)):
        for x in range(-round(0.9 * k), round(0.9 * k)):
            t.put((x, round(1.9 * k) + i, round(2.0 * k) - i // 2), night if i < 1.2 * k else gold)
    tidy(c)

    def hourglass(part, centre, r):
        cx, cy, cz = centre
        H_ = r * 1.5
        for z in range(math.floor(cz - H_), math.ceil(cz + H_) + 1):
            t = abs(z + .5 - cz) / H_
            if t > 1:
                continue
            rr = max(0.6, r * (0.18 + 0.7 * t))
            cap = t > 0.86
            for x in range(math.floor(cx - rr) - 1, math.ceil(cx + rr) + 1):
                for y in range(math.floor(cy - rr) - 1, math.ceil(cy + rr) + 1):
                    d = math.hypot(x + .5 - cx, y + .5 - cy)
                    if d > (r * 1.0 if cap else rr):
                        continue
                    if cap:
                        part.put((x, y, z), C('#8A5A33'))
                    elif (z + .5 < cz and t > 0.25) or d < 0.9:
                        part.put((x, y, z), C('#FFD84A'), True)  # sand
                    elif d > rr - 1.2:
                        part.put((x, y, z), C('#BFE9FF'))  # glass
    orbit_ring(c, k, [(0, 4.2, 0.62, hourglass)]
               + ([(120, 6.8, 0.36, star4(WHITE, gold)), (240, 2.6, 0.36, star4(C('#BFE3FF'), WHITE))] if fine else []))
    return c


# ------------------------------------------------------------ Crystal Swan

def crystal_swan(c, H):
    """A swan of clear ice, its long neck curved in an S, wings raised in
    faceted crystal feathers with glowing edges, a diamond crown; icicles
    circle it."""
    k, fine = ctx(c, H * 1.1)
    ice, iceL, iceD, iceDD = C('#CFEFFF'), C('#F0FAFF'), C('#9ACCEB'), C('#6FA8D6')
    beak, gem = C('#5C7AFF'), C('#BFF4FF')
    b = c.part('body')
    b.ell((0, 0.6 * k, 3.0 * k), (1.8 * k, 2.6 * k, 1.5 * k), ice)
    b.ell((0, 2.6 * k, 3.6 * k), (1.2 * k, 1.1 * k, 1.0 * k), ice)  # raised tail
    for sx, sd in ((1, 'R'), (-1, 'L')):
        leg(c, 'leg' + sd, (sx * 0.7 * k, 0.6 * k, 1.8 * k), (sx * 0.75 * k, 0.4 * k, 0.4 * k), 0.32 * k, 0.26 * k,
            iceDD, paw=iceDD, paw_r=(0.6 * k, 0.7 * k, 0.28 * k))
    # S-shaped neck rising from the breast
    p0, p1, p2 = (0, -1.4 * k, 3.6 * k), (0, -0.2 * k, 6.4 * k), (0, -1.9 * k, 7.6 * k)
    neck_pts = [(*bez(p0, p1, p2, s), max(0.6, (0.78 - 0.25 * s) * k)) for s in (i / 29 for i in range(30))]
    tube(b, neck_pts, lambda s: ice)
    h = c.part('head', 'head', (0, -1.7 * k, 7.2 * k))
    hy, hz = -2.1 * k, 7.75 * k
    h.ell((0, hy, hz), (0.72 * k, 0.9 * k, 0.7 * k), ice)
    h.ell((0, hy - 1.0 * k, hz - 0.15 * k), (0.3 * k, 0.6 * k, 0.26 * k), beak)
    for part in (b, h):
        gradient(part, [iceDD, iceD, ice, iceL], 1.6 * k, 8.4 * k, fine, keep=(beak,))
        if fine:
            part.paint(lambda p, cc, g: (_shade(cc, 1.08 if (p[0] - p[1] + 2 * p[2]) // round(0.7 * k) % 2 else 0.93), False) if not g and cc != beak else None)
    # dark eyes with a bright shine, on the sides of the head
    side_eyes(c, h, hy - 0.15 * k, hz + 0.12 * k, 0.32 * k, C('#1A2340'), ring=C('#1A2340'), pupil=INK, glow=False,
              lid=iceD)
    # the crown: a gold band round the top of the head with five pointed,
    # faceted sapphire gems standing up from it, the middle one tallest,
    # a white sparkle on each tip
    crown = c.part('crown', 'glow', (0, hy, hz + 0.7 * k))
    gold, goldD = C('#FFC93B'), C('#D9961A')
    sapph, sapphL, sapphD = C('#3FA9FF'), C('#9AD8FF'), C('#1E6FD0')
    zb = hz + 0.5 * k
    for x in range(-round(0.62 * k), round(0.62 * k)):
        for y in range(round(hy - 0.6 * k), round(hy + 0.6 * k)):
            d = math.hypot((x + .5) / (0.62 * k), (y + .5 - hy) / (0.6 * k))
            if 0.62 < d <= 1.0:
                for dz in range(max(2, round(0.22 * k))):
                    crown.put((x, y, round(zb) + dz), gold if dz else goldD)
    for i, (gx, gy, L) in enumerate(((0, -0.55, 0.95), (-0.42, -0.36, 0.68), (0.42, -0.36, 0.68),
                                     (-0.6, 0.1, 0.5), (0.6, 0.1, 0.5))):
        cx, cy, z0 = gx * k, hy + gy * k, round(zb) + max(2, round(0.22 * k)) - 1
        Lv = round(L * k)
        for j in range(Lv):
            t = j / Lv
            w = 0.24 * k * (1 - t) if t > 0.3 else 0.24 * k * (0.6 + t / 0.3 * 0.4)  # a diamond: widens, then points
            for x in range(math.floor(cx - w) - 1, math.ceil(cx + w) + 1):
                for y in range(math.floor(cy - w) - 1, math.ceil(cy + w) + 1):
                    ddx, ddy = x + .5 - cx, y + .5 - cy
                    if abs(ddx) + abs(ddy) > w + 0.3:
                        continue
                    # facets: light on the front-left faces, dark on the back-right
                    col = sapphL if ddx < 0 and ddy < 0 else (sapph if ddx < 0 or ddy < 0 else sapphD)
                    crown.put((x, y, z0 + j), col, False)
        tip = (math.floor(cx), math.floor(cy), z0 + Lv)
        crown.put(tip, WHITE, True)
        if fine:
            for d in ((1, 0, 0), (-1, 0, 0), (0, -1, 0), (0, 1, 0)):
                crown.put((tip[0] + d[0], tip[1] + d[1], tip[2] - 1 if d[1] else tip[2]), WHITE, True)  # sparkle
    for q in [q for q in crown.v if q in h.v]:
        del crown.v[q]
    # crystal wings, raised in an arch
    wing(c, k, (1.3, 0.4, 4.0), 4.0, 2.8, 2.4, (ice, iceL, C('#DDF6FF')), gem, edge=C('#7FDBFF') if fine else None,
         thick=2)
    sparkle(b, (WHITE, gem), 160, 81, fine)
    tidy(c)
    orbit_ring(c, k, [(a, z, 0.5, shard(C('#9AD8FF'), WHITE, tall=2.0)) for a, z in ((0, 3.4), (90, 5.6), (180, 3.0), (270, 5.2))])
    return c


# ------------------------------------------------------------ Hurricane Roc

def hurricane_roc(c, H):
    """An enormous storm bird in slate and silver feathers with a crackling
    crest, riding a ring of whirling wind (its orbit)."""
    k, fine = ctx(c, H * 1.08)
    slate, slateL, slateD, silver = C('#5A6A8A'), C('#7A8CB0'), C('#3E4A66'), C('#DCE6F5')
    volt, voltL, beakc = C('#5CE1FF'), C('#D8FBFF'), C('#FFC83D')
    b, h = bird_body(c, k, fine, slate, silver, body=(1.7, 2.1, 2.0), body_z=3.6, head_r=1.3, head_z=6.3,
                     leg_col=beakc, talon=INK, legs_x=0.7)
    for part in (b, h):
        gradient(part, [slateD, slate, slate, slateL], 1.6 * k, 7.8 * k, fine, keep=(silver,))
    if fine:
        b.paint(lambda p, cc, g: (_shade(cc, 0.86), False) if cc in (slate, slateL, slateD) and (p[2] + (p[0] // 2)) % 4 == 0 else None)
    # a raptor's beak: a solid upper bill rooted in the face, arching forward
    # and hooking down to a dark tip, over a shorter lower bill
    yf = front_at(h, 0, round(6.1 * k))[1] + 0.5
    cere, beakD, beakT, tipc = C('#FFDD6B'), C('#E6A51F'), C('#D98A12'), C('#9A5E14')
    L = 1.3 * k
    n = 30
    for i in range(n):
        t = i / (n - 1)
        # forward along the top, then the last third curls down into the hook
        y = yf + 0.3 * k - L * (t if t < 0.7 else 0.7 + (t - 0.7) * 0.75)
        z = 6.1 * k + 0.16 * k * math.sin(math.pi * min(t, 0.7) / 0.7 * 0.5) - (0.5 * k * ((t - 0.6) / 0.4) ** 1.6 if t > 0.6 else 0)
        rx = 0.44 * k * (1 - t) ** 0.8 + 0.07 * k
        rz = 0.36 * k * (1 - t) ** 0.55 + 0.09 * k
        col = cere if t < 0.2 else (beakc if t < 0.62 else (beakT if t < 0.9 else tipc))
        h.ell((0, y, z), (rx, 0.16 * k, rz), col)
    for i in range(16):  # the lower bill, shorter, tucked under the hook
        t = i / 15 * 0.42
        h.ell((0, yf + 0.25 * k - L * t, 5.66 * k - 0.08 * k * t),
              (0.28 * k * (1 - t) + 0.06 * k, 0.12 * k, 0.11 * k), beakD)
    proud_eyes(c, h, [(0.6 * k, 6.55 * k)], 0.34 * k, 0.32 * k, volt, ring=INK, pupil=INK, lid=slateD,
               iris2=C('#2E86E8'), behind=-1.6 * k)
    for sx in (1, -1):
        h.ell((sx * 0.6 * k, -1.3 * k, 6.95 * k), (0.45 * k, 0.3 * k, 0.14 * k), slateD)
    # lightning crest
    crest = c.part('crest', 'glow', (0, -0.2 * k, 7.5 * k))
    for i, dx in enumerate((-0.35, 0.0, 0.35)):
        x, y, z = dx * k, -0.2 * k, 7.45 * k
        for j in range(round(1.4 * k)):
            crest.put((math.floor(x), math.floor(y), math.floor(z)), voltL if j > 0.9 * k else volt, True)
            y += 0.55
            z += 0.75
            x += (1 if (j // 3) % 2 else -1) * 0.35
    # vast wings, storm-edged
    wing(c, k, (1.4, 0.3, 4.6), 4.6, 2.8, 2.4, (slateD, slate, slateL, silver), voltL, edge=volt if fine else None,
         thick=2)
    t = c.part('tail', 'tail', (0, 2.0 * k, 2.6 * k))
    for i in range(round(2.0 * k)):
        for x in range(-round(0.8 * k) - i // 4, round(0.8 * k) + i // 4):
            t.put((x, round(2.1 * k) + i, round(2.5 * k) - i // 2), slateD if (x + i) % 5 else silver)
    tidy(c)

    def gust(col, col2):
        """A curl of wind: an arc streak, thick in the middle."""
        def draw(part, centre, r):
            cx, cy, cz = centre
            a0 = math.atan2(cy - part.pivot[1], cx - part.pivot[0])
            R = math.hypot(cx - part.pivot[0], cy - part.pivot[1])
            n = 26
            for i in range(n):
                s = i / (n - 1)
                a = a0 - 0.5 + s * 1.0
                th = 1 + round(math.sin(s * math.pi) * r * 0.5)
                for t_ in range(th):
                    q = (math.floor(part.pivot[0] + math.cos(a) * (R - t_ * 0.5)), math.floor(part.pivot[1] + math.sin(a) * (R - t_ * 0.5)),
                         math.floor(cz + math.sin(s * math.pi * 2) * r * 0.4 + t_ * 0.3))
                    part.put(q, col2 if t_ == 0 else col, True)
        return draw
    # ten wind threads, two layers turning together: five low and wide, five
    # high and between them
    winds = [(a, z) for a, z in ((0, 1.6), (72, 3.0), (144, 4.4), (216, 2.2), (288, 3.6))]
    winds += [(a + 36, z) for a, z in ((0, 3.8), (72, 2.0), (144, 3.2), (216, 4.6), (288, 1.4))]
    orbit_ring(c, k, [(a, z, 0.55, gust(C('#BFEFFF'), WHITE)) for a, z in winds], margin=0.5)
    return c


# ------------------------------------------------------------ Butterfly Empress

def butterfly_empress(c, H):
    """A giant butterfly queen: a velvet body with a little gold crown and
    curled antennae, six legs, and great wings painted as a flower garden
    (blossoms, leaves and glowing dew on a sky-blue ground); glowing pollen
    orbs circle her."""
    k, fine = ctx(c, H)
    body_c, body_d, gold = C('#4A2A6A'), C('#2E1A45'), C('#FFC83D')
    sky, skyD, rim_c = C('#7FC8FF'), C('#4A9AE8'), C('#2E1A45')
    petals = [C('#FF5C8A'), C('#FFD93B'), C('#FF9A3D'), C('#B45CFF'), WHITE]
    leafc = C('#4CC26A')
    b = c.part('body')
    for i in range(7):  # segmented abdomen and thorax
        y = (-0.6 + i * 0.6) * k
        r = (0.95 - 0.08 * abs(i - 1)) * k
        b.ell((0, y, (4.6 - 0.12 * i) * k), (r, 0.5 * k, r), body_c if i % 2 else body_d)
    if fine:
        b.paint(lambda p, cc, g: (C('#6A3F8A'), False) if p[2] > 4.9 * k and cc == body_c else None)
    # six thin legs, three a side, front to back
    for i, ly in enumerate((-0.7, 0.0, 0.7)):
        for sx, sd in ((1, 'R'), (-1, 'L')):
            hip = (sx * 0.6 * k, ly * k, 4.0 * k)
            lp = c.part(f'leg{i + 1}{sd}', f'leg{i + 1}{sd}', hip)
            knee = (sx * 1.4 * k, (ly - 0.1) * k, 3.2 * k)
            foot = (sx * 1.7 * k, (ly - 0.2 * (1 - i)) * k, 0.3 * k)
            limb(lp, hip, knee, 0.22 * k, 0.2 * k, body_d)
            limb(lp, knee, foot, 0.2 * k, 0.16 * k, body_d)
            for q in [q for q in lp.v if q[2] < 0]:
                del lp.v[q]
    h = c.part('head', 'head', (0, -1.0 * k, 4.9 * k))
    h.ell((0, -1.6 * k, 5.0 * k), (0.95 * k, 0.85 * k, 0.9 * k), body_c)
    proud_eyes(c, h, [(0.48 * k, 5.1 * k)], 0.38 * k, 0.42 * k, C('#5CE1FF'), ring=INK, pupil=INK, lid=body_d,
               iris2=C('#B45CFF'), behind=-2.6 * k)
    # curled antennae with glowing tips, and a little crown
    ant = c.part('ears', 'ears', (0, -1.6 * k, 5.8 * k))
    for sx in (1, -1):
        pts = []
        for i in range(18):
            s = i / 17
            a = s * math.pi * 1.4
            pts.append((sx * (0.35 + 0.9 * s) * k, (-1.7 - 0.6 * math.sin(a)) * k, (5.8 + 1.9 * s - 0.4 * max(0, s - 0.8) / 0.2) * k, 0.6))
        tube(ant, pts, lambda s: body_d)
        ant.ell((sx * 1.3 * k, -1.7 * k, 7.6 * k), (0.3 * k,) * 3, gold, True)
    crown = c.part('crown', 'glow', (0, -1.6 * k, 5.8 * k))
    for i in range(5):
        x = round((i - 2) * 0.22 * k)
        for j in range(round((0.5 if i % 2 == 0 else 0.3) * k)):
            crown.put((x, round(-1.6 * k), round(5.75 * k) + j), gold, True)
            crown.put((x - 1, round(-1.6 * k), round(5.75 * k) + j), gold, True)
    for q in [q for q in crown.v if q in h.v]:
        del crown.v[q]
    # great garden wings: upper and lower lobes, hinged at the shoulder
    for sx, name in ((1, 'wingR'), (-1, 'wingL')):
        w = c.part(name, name, (sx * 0.7 * k, 0.0, 4.8 * k))
        for lobe, (cx, cz, rx, rz, dy) in enumerate(((2.5, 6.6, 2.1, 2.2, -0.3), (2.0, 3.4, 1.55, 1.6, 0.6))):
            for x in range(round(0.6 * k), round((cx + rx) * k) + 1):
                for z in range(round((cz - rz) * k), round((cz + rz) * k) + 1):
                    d = ((x + .5 - cx * k) / (rx * k)) ** 2 + ((z + .5 - cz * k) / (rz * k)) ** 2
                    if d > 1:
                        continue
                    if d > 0.82:
                        col = rim_c
                    else:
                        col = sky if not fine else (skyD if _fbm(x, 0, z, 1.2 * k, 3 + lobe) < 0.42 else sky)
                    xx = x if sx > 0 else -x - 1
                    y = round(dy * k + 0.08 * (x - 0.6 * k))
                    w.put((xx, y, z), col)
                    w.put((xx, y + 1, z), col)
            # flowers painted on the wing: a ring of petals round a centre
            n_fl = 7 if fine else 3
            for f in range(n_fl):
                ang = f / n_fl * math.pi * 2 + lobe
                fx = cx * k + math.cos(ang) * rx * k * 0.48 * (0.6 + 0.4 * (f % 2))
                fz = cz * k + math.sin(ang) * rz * k * 0.48 * (0.6 + 0.4 * (f % 2))
                pc = petals[(f + lobe) % len(petals)]
                fr = (0.45 if fine else 0.6) * k
                for x in range(round(fx - fr) - 1, round(fx + fr) + 2):
                    for z in range(round(fz - fr) - 1, round(fz + fr) + 2):
                        dx, dz = x + .5 - fx, z + .5 - fz
                        d = math.hypot(dx, dz)
                        if d > fr:
                            continue
                        petal = math.cos(math.atan2(dz, dx) * 5) > -0.3 or d < fr * 0.45
                        if not petal:
                            continue
                        xx = x if sx > 0 else -x - 1
                        y = round((-0.3 if lobe == 0 else 0.6) * k + 0.08 * (x - 0.6 * k))
                        if (xx, y, z) in w.v and w.v[(xx, y, z)][0] != rim_c:
                            ctr = d < fr * 0.35
                            w.put((xx, y - 1, z), gold if ctr else pc, ctr)
                            if (xx, y + 1, z) in w.v:  # the same blossom, paler, on the back of the wing
                                w.put((xx, y + 2, z), _mix(gold, WHITE, 0.3) if ctr else _mix(pc, WHITE, 0.3), ctr)
            if fine:  # leaves and glowing dew, front and back
                for (x, y, z), (cc, g) in list(w.v.items()):
                    if cc not in (sky, skyD):
                        continue
                    for dy, seed, lc in ((-1, 9, leafc), (1, 19, _mix(leafc, WHITE, 0.25))):
                        if (x, y + dy, z) in w.v:
                            continue
                        if _hash(x, z, lobe, seed) % 23 == 0:
                            w.put((x, y + dy, z), lc)
                        elif _hash(x, z, lobe, seed + 1) % 61 == 0:
                            w.put((x, y + dy, z), WHITE, True)  # dew
    tidy(c)
    orbit_ring(c, k, [(a, z, 0.48, ball(C('#FFB21A'), C('#FFE45C'), glow=True, cap=True, fine=fine))
                      for a, z in ((20, 2.4), (100, 4.4), (180, 2.0), (260, 3.6), (330, 6.0))]
               + ([(60, 3.2, 0.3, star4(C('#FFE45C'), C('#FFB21A'))), (220, 5.0, 0.3, star4(C('#FFE45C'), C('#FFB21A')))]
                  if fine else []), margin=0.5)
    return c


# ------------------------------------------------------------ Cosmic Whale

def cosmic_whale(c, H):
    """A whale made of glass with a galaxy inside: a long tapered body
    swimming level, its shell rimmed in pale-blue glass with bright glints,
    the dark inside swirling with a glowing spiral galaxy and stars; a pale
    grooved throat under a long jaw line, bright eyes, long flippers that
    paddle and wide tail flukes; moons circle above its back."""
    c.gait_hint = 'swim'  # swims through the air: the tail sweeps and the flippers paddle
    k, fine = ctx(c, H * 1.2)  # long and low: drawn a little bigger so its voxels match the rest at 6 studs
    navy, navyL, navyD = C('#1E2A6A'), C('#2E3F9A'), C('#141C4A')
    glass, glassL, belly, groove = C('#8FC8FF'), C('#D4ECFF'), C('#B4C8F0'), C('#8098D8')
    vio, pink, cyan = C('#9A5CFF'), C('#FF5CD6'), C('#5CE1FF')
    b = c.part('body')
    # spine: blunt head at the front (-y), biggest just behind the eyes,
    # tapering to a slim tail stock that lifts a little
    spine = []
    n = 56
    for i in range(n):
        s_ = i / (n - 1)
        y = (-4.0 + 7.6 * s_) * k
        z = (3.0 + 0.35 * math.sin(s_ * math.pi) + 0.9 * max(0.0, s_ - 0.7) ** 1.5 * 4.0) * k
        r = (1.85 * math.sin(min(1.0, (s_ + 0.12) / 0.42) * math.pi / 2) ** 0.7 * (1 - 0.82 * max(0.0, s_ - 0.3) / 0.7) ** 1.1
             + 0.12) * k
        spine.append((0.0, y, z, r))
    for (x, y, z, r) in spine:
        b.ell((x, y, z), (r * 0.92, 0.5 * k, r * 0.85), navy)

    def at_y(y):
        i = min(range(n), key=lambda j: abs(spine[j][1] - y))
        return spine[i]

    def normal(p, pad=0.0):
        _, sy, sz, r = at_y(p[1] + .5)
        return (p[0] + .5) / (r * 0.92 + pad), (p[2] + .5 - sz) / (r * 0.85 + pad)

    # the glass shell: a pale-blue rim along the top of the back, glass
    # belly, and the dark galaxy inside showing through the flanks
    def shell(p, cc, g, pad=0.0):
        nx, nz = normal(p, pad)
        if nz < -0.55:
            if p[1] < 0.6 * k and fine and p[0] % 3 == 0:
                return (groove, False)  # throat grooves
            return (belly, False)
        if nz > 0.74 or abs(nx) > 0.98:
            return (glass, False)
        if nz > 0.52:
            return (_mix(navy, glass, 0.55), False)
        return (navyD if nz < -0.2 else navy), False
    b.paint(shell)

    # the galaxy inside, seen through each flank: a glowing two-armed spiral
    gy, gz = 0.1 * k, 3.1 * k

    def galaxy(p, cc, g):
        if cc in (belly, groove, glass):
            return None
        x, y, z = p[0] + .5, p[1] + .5, p[2] + .5
        if abs(x) < 0.7 * k:
            return None
        dy, dz = y - gy, z - gz
        d = math.hypot(dy / 1.5, dz)
        if d < 1.4 * k:
            ang = math.atan2(dz, dy / 1.5)
            arm = math.sin(2 * ang - d / (0.32 * k))
            if d < 0.3 * k:
                return (WHITE, True)
            if d < 0.5 * k:
                return (C('#FFE6FA'), True)
            if arm > 0.35:
                return ((pink if d > 0.85 * k else vio) if fine else vio, True)
        if fine and cc in (navy, navyD) and _fbm(*p, 1.3 * k, 33) > 0.66:
            return (_mix(cc, vio, 0.35), False)  # nebula clouds
        return None
    b.paint(galaxy)
    sparkle(b, (WHITE, cyan, WHITE, C('#FFE6FA')), 140, 91, fine, keep=(belly, groove, glass, _mix(navy, glass, 0.55)))
    # glass glints: short bright diagonal streaks high on each flank
    if fine:
        for sx in (1, -1):
            for gy0, gz0, L in ((-2.4, 3.9, 0.9), (-1.8, 4.0, 0.55), (1.4, 3.75, 0.7)):
                for j in range(round(L * k)):
                    y, z = gy0 * k + j * 0.7, gz0 * k - j * 0.7
                    xs = [q[0] for q in b.v if q[1] == round(y) and q[2] == round(z)]
                    if xs:
                        b.put((max(xs) if sx > 0 else min(xs), round(y), round(z)), glassL, True)
    # the head: a long jaw line from the snout back under the eye, bright eyes
    h = c.part('head', 'head', spine[8][:3])
    for (x, y, z, r) in spine[:14]:
        h.ell((x, y, z), (r * 0.92 + 0.6, 0.5 * k, r * 0.85 + 0.6), navy)
    for q in [q for q in h.v if q in b.v]:
        h.v[q] = b.v[q]
    for q in list(h.v):
        if q in b.v:
            del b.v[q]
    h.paint(lambda p, cc, g: None if g else shell(p, cc, g, 0.6))  # one clean glass shell over head and body
    sparkle(h, (WHITE, cyan), 160, 94, fine, keep=(belly, groove, glass, _mix(navy, glass, 0.55)))
    _, hy0, hz0, _ = spine[0]
    for q in list(h.v):  # jaw line: from the front of the snout, curving up towards the eye
        x, y, z = q
        t = (y + .5 - hy0) / (2.7 * k)
        if 0 <= t <= 1.15 and abs(z + .5 - (hz0 - 0.55 * k + 0.45 * k * t * t)) < 1.0:
            nbrs = [(x + 1, y, z), (x - 1, y, z), (x, y - 1, z)]
            if any(n_ not in h.v for n_ in nbrs):
                h.put(q, INK)
    _, ey, ez, er = spine[9]
    side_eyes(c, h, ey, ez - 0.15 * k, 0.62 * k, cyan, iris2=C('#9AE8FF'), rim_shine=True, lid=navyD)
    # long flippers that paddle, pale-edged like glass
    _, fy, fz, fr = spine[15]
    for sx, name in ((1, 'finR'), (-1, 'finL')):
        fp = c.part(name, name, (sx * fr * 0.8, fy, fz - 0.45 * fr))
        L = round(1.5 * k)
        for i in range(L):
            s_ = i / L
            fp.ell((sx * (fr * 0.8 + i), fy + s_ * 1.0 * k, fz - 0.45 * fr - s_ * 0.45 * k),
                   (0.6, (0.6 - 0.3 * s_) * k, 0.2 * k), navyL if s_ < 0.7 else glass)
        fp.paint(lambda p, cc, g: (glass, False) if cc == navyL and (p[1] + .5) > fy + 0.35 * k + 0.5 * k * abs(p[0] + .5) / (2.2 * k) else None)
    # wide flukes with a notch, rimmed in glass, a glow at each tip
    t = c.part('tail', 'tail', spine[-12][:3])
    for (x, y, z, r) in spine[-12:]:
        t.ell((x, y, z), (r * 0.92, 0.5 * k, r * 0.85), navy)
    for q in [q for q in t.v if q in b.v]:
        t.v[q] = b.v[q]
        del b.v[q]
    _, ye, ze, _ = spine[-1]
    for sx in (1, -1):
        for i in range(round(2.2 * k)):
            s_ = i / (2.2 * k)
            yy = ye + (0.1 + 0.9 * s_ * s_) * k
            ln = (1.25 - 0.75 * s_) * k
            for dy in range(round(ln)):
                col = glass if dy >= round(ln) - 2 or i >= round(2.2 * k) - 2 else navy
                for dz in (-1, 0, 1):
                    t.put((sx * i if sx > 0 else -i - 1, round(yy - ln * 0.4 + dy), round(ze - 0.1 * k) + dz), col)
        t.ell((sx * 2.05 * k, ye + 1.05 * k, ze - 0.05 * k), (0.32 * k, 0.32 * k, 0.2 * k), vio, True)
    sparkle(t, (WHITE, cyan), 120, 93, fine, keep=(glass,))
    tidy(c)
    tilt(c, 8, (0, 0, 3.0 * k))  # nose a touch up, as if swimming up through space
    orbit_ring(c, k, [(0, 6.0, 0.55, ball(C('#D8DDF0'), C('#A8AECB'), speck=C('#9AA0C0'), seed=3, fine=fine)),
                      (120, 6.2, 0.5, ball(C('#FFB4E0'), WHITE, cap=True, fine=fine)),
                      (240, 6.0, 0.5, ball(C('#9AE8FF'), WHITE, bands=True, fine=fine))]
               + ([(60, 6.6, 0.3, star4(WHITE, cyan)), (300, 6.6, 0.3, star4(WHITE, pink))] if fine else []),
               margin=0.4)
    return c


# ------------------------------------------------------------ Thunder Kraken

def thunder_kraken(c, H):
    """A storm kraken: a domed mantle of deep teal with glowing spots, big
    fierce eyes, and six curling tentacles crackling with lightning (each its
    own leg, so they sway as it drifts); a ring of storm clouds circles it."""
    k, fine = ctx(c, H)
    teal, tealL, tealD, sucker = C('#2A6A8A'), C('#3E8AAE'), C('#1A4A66'), C('#F0C9E8')
    bolt, boltL = C('#FFCC1A'), C('#FFFFFF')
    b = c.part('body')
    b.ell((0, 0.0, 4.2 * k), (1.8 * k, 1.8 * k, 1.1 * k), teal)  # where the arms join
    hd = c.part('head', 'head', (0, 0.2 * k, 4.6 * k))
    hd.ell((0, 0.4 * k, 6.2 * k), (2.0 * k, 2.2 * k, 2.6 * k), teal)  # the mantle
    for part in (b, hd):
        gradient(part, [tealD, teal, tealL], 3.2 * k, 8.8 * k, fine)
    hd.paint(lambda p, cc, g: (C('#5CE1FF'), True) if p[2] > 5.6 * k and _hash(p[0] // 3, p[1] // 3, p[2] // 3, 4) % 9 == 0 else None)
    proud_eyes(c, hd, [(1.15 * k, 5.85 * k)], 0.62 * k, 0.7 * k, bolt, ring=INK, pupil=INK, lid=tealD,
               iris2=C('#FF9A1A'), behind=-2.2 * k, pupil_r=0.08)
    for sx in (1, -1):  # fierce brows
        f = front_at(hd, round(sx * 1.15 * k), round(6.75 * k))
        if f:
            hd.ell((sx * 1.15 * k, f[1] - 0.1 * k, 6.75 * k), (0.7 * k, 0.35 * k, 0.18 * k), tealD)
    # six tentacles: leg1..leg3 each side, curling out and down
    # six tentacles: leg1..leg3 each side, curling out and down; each left
    # one is the exact mirror of its right one
    dark = C('#0E2A3A')
    for i, ang in enumerate((-55, 0, 55)):
        sx = 1
        base = (0.9 * k * abs(math.cos(math.radians(ang))) + 0.4 * k, (ang / 55) * 0.9 * k, 3.6 * k)
        lp = c.part(f'leg{i + 1}R', f'leg{i + 1}R', base)
        pts = []
        for j in range(26):
            s_ = j / 25
            out = (0.4 + 2.3 * s_) * k
            x = base[0] + out * 0.75
            y = base[1] + (ang / 55) * out * 0.65
            z = 3.6 * k - 3.0 * k * math.sin(min(1.0, s_ * 1.4) * math.pi / 2) + 1.1 * k * max(0.0, s_ - 0.7) / 0.3
            pts.append((x, y, max(0.6, z), max(0.6, (0.62 - 0.45 * s_) * k)))
        tube(lp, pts, lambda s_: teal)
        gradient(lp, [tealD, teal], 0.2 * k, 3.6 * k, fine)
        # one lightning bolt along the top of the tentacle: a bright zig-zag
        # in a dark groove, so each zig reads with a gap beside it
        verts = []
        for n_, j in enumerate(range(2, 23, 3)):
            x, y, z, r = pts[j]
            verts.append((x, y + (0.5 if n_ % 2 else -0.5) * r))
        boltv = set()
        for (x0, y0), (x1, y1) in zip(verts, verts[1:]):
            steps = max(2, round(2 * math.hypot(x1 - x0, y1 - y0)))
            for t in range(steps + 1):
                boltv.add((math.floor(x0 + (x1 - x0) * t / steps), math.floor(y0 + (y1 - y0) * t / steps)))
        tops = {}
        for (x, y, z) in lp.v:
            if (x, y) not in tops or z > tops[(x, y)]:
                tops[(x, y)] = z
        for (x, y) in boltv:
            if (x, y) in tops:
                lp.put((x, y, tops[(x, y)]), bolt, True)
                lp.put((x, y, tops[(x, y)] + 1), bolt, True)
        for (x, y) in boltv:
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + d[0], y + d[1])
                if n not in boltv and n in tops:
                    lp.put((n[0], n[1], tops[n]), dark)
        for q in [q for q in lp.v if q[2] < 0]:
            del lp.v[q]
        mirror = c.part(f'leg{i + 1}L', f'leg{i + 1}L', (-base[0], base[1], base[2]))
        for (x, y, z), (cc, g) in lp.v.items():
            mirror.put((-x - 1, y, z), cc, g)
    tidy(c)

    def storm(part, centre, r):
        cloud(C('#6A7390'), C('#4A5270'))(part, centre, r)
        cx, cy, cz = centre
        x, y, z = cx, cy, cz - 0.35 * r
        for j in range(round(r * 1.4)):
            part.put((math.floor(x), math.floor(y), math.floor(z)), bolt, True)
            z -= 1
            x += (1 if (j // 2) % 2 else -1) * 0.6
    orbit_ring(c, k, [(a, z, 0.7, storm) for a, z in ((0, 6.0), (90, 7.2), (180, 6.2), (270, 7.0))], margin=0.6)
    return c


# ------------------------------------------------------------ Clockwork Leviathan

def clockwork_leviathan(c, H):
    """A brass whale-serpent built of gear-plated segments: a long body that
    swims level with a gentle wave, a whale head with a grille mouth and lamp
    eyes, a furnace heart glowing through a grille on each side of its chest,
    gear wheels on its flanks, copper fin plates and a dorsal gear fin down
    its back, flippers and wide flukes; cogs circle above its back."""
    c.gait_hint = 'swim'  # swims through the air: the tail sweeps and the flippers paddle
    k, fine = ctx(c, H * 1.28)  # long and low: drawn bigger so its voxels match the rest at 6 studs
    brass, brassL, brassD, copper = C('#C9922E'), C('#E8B85A'), C('#8A6020'), C('#B8662E')
    steel, steelD, fire, fireL = C('#6A7080'), C('#3E4250'), C('#FF7A1A'), C('#FFD84A')
    b = c.part('body')
    # spine: head at the front (-y), a long body with a slow wave, tail rising
    spine = []
    n = 64
    for i in range(n):
        s_ = i / (n - 1)
        y = (-4.4 + 9.0 * s_) * k
        z = (2.0 + 0.35 * math.sin(s_ * math.pi * 2.0 + 0.3) + 0.5 * max(0.0, s_ - 0.75) / 0.25) * k
        r = (1.05 * (1 - s_) ** 0.9 + 0.22) * k
        spine.append((0.0, y, z, r))
    # segments: each a slightly flattened ring, with a groove between
    for i, (x, y, z, r) in enumerate(spine):
        b.ell((x, y, z), (r, 0.5 * k, r * 0.88), brass)
    # gear plating: every segment ends in a toothed rim
    for i in range(4, n - 4, 5):
        x0, y0, z0, r0 = spine[i]
        for t in range(int(2 * math.pi * r0 * 1.4) + 8):
            a_ = t / (int(2 * math.pi * r0 * 1.4) + 8) * 2 * math.pi
            if math.cos(a_ * max(6, round(r0 / k * 10))) < 0.2:
                continue
            b.put((math.floor(x0 + math.cos(a_) * (r0 + 0.7)), math.floor(y0), math.floor(z0 + math.sin(a_) * (r0 * 0.88 + 0.7))),
                  brassD)
    if fine:
        seg = 0.95 * k
        b.paint(lambda p, cc, g: (brassD, False) if cc == brass and ((p[1] + .5 + 3.2 * k) % seg) < 1.0 else None)
        b.paint(lambda p, cc, g: (brassL, False) if cc == brass and ((p[1] + .5 + 3.2 * k) % seg) < 2.0 and p[2] % 4 == 0 else None)  # rivets
    gradient(b, [brassD, brass, brassL], 1.0 * k, 3.2 * k, fine, keep=(brassD, brassL) if fine else ())
    b.paint(lambda p, cc, g: (copper, False) if p[2] < 1.55 * k and p[1] < 2.0 * k and cc != brassD else None)  # copper belly plates
    # the furnace heart: a round grille on each side of the chest, fire behind
    port = c.part('furnace', 'glow', spine[9][:3])
    _, py, pz, pr = spine[9]
    for sx in (1, -1):
        for y in range(round(py - 0.9 * k), round(py + 0.9 * k) + 1):
            for z in range(round(pz - 0.9 * k), round(pz + 0.9 * k) + 1):
                d = math.hypot(y + .5 - py, z + .5 - pz) / (0.8 * k)
                if d > 1:
                    continue
                xs = [q[0] for q in b.v if q[1] == y and q[2] == z]
                if not xs:
                    continue
                xo = max(xs) if sx > 0 else min(xs)
                if d > 0.82:
                    b.put((xo, y, z), steel)
                elif (z % 3 == 0) and d < 0.82:
                    b.put((xo, y, z), steelD)  # grille bars
                else:
                    port.put((xo + sx, y, z), fireL if d < 0.45 else fire, True)
    # gear wheels on the flanks, facing out
    for sx in (1, -1):
        for at, gr in ((24, 0.55), (36, 0.42)):
            x, y, z, r = spine[at]
            for gy in range(-math.ceil(gr * k) - 1, math.ceil(gr * k) + 2):
                for gz in range(-math.ceil(gr * k) - 1, math.ceil(gr * k) + 2):
                    d = math.hypot(gy + .5, gz + .5)
                    ang = math.atan2(gz + .5, gy + .5)
                    outer = gr * k + (0.9 if math.cos(ang * 8) > 0.2 else 0)
                    if d > outer or d < gr * k * 0.3:
                        continue
                    xs = [q[0] for q in b.v if q[1] == round(y + gy) and q[2] == round(z + gz)]
                    if not xs:
                        continue
                    xo = (max(xs) if sx > 0 else min(xs)) + sx
                    b.put((xo, round(y + gy), round(z + gz)), brassL if d > gr * k * 0.8 or d < gr * k * 0.45 else steel)
    # head: a blunt whale head with a grille mouth and lamp eyes
    x0, y0, z0, r0 = spine[0]
    h = c.part('head', 'head', spine[5][:3])
    h.ell((0, y0 - 0.2 * k, z0 + 0.1 * k), (1.25 * k, 1.4 * k, 1.1 * k), brass)
    h.ell((0, y0 - 1.1 * k, z0 - 0.25 * k), (1.0 * k, 0.9 * k, 0.75 * k), brass)
    gradient(h, [brassD, brass, brassL], z0 - 1.1 * k, z0 + 1.2 * k, fine)
    mouth = c.part('mouthfire', 'glow', (0, y0 - 1.8 * k, z0 - 0.5 * k))
    for x in range(round(-0.8 * k), round(0.8 * k)):
        for z in range(round(z0 - 0.85 * k), round(z0 - 0.3 * k)):
            f = front_at(h, x, z)
            if f:
                if x % 3 == 0:
                    h.put(f, steelD)  # the grille's bars
                else:
                    h.put(f, steelD)
                    mouth.put((f[0], f[1] - 1, f[2]), fireL if z > z0 - 0.6 * k else fire, True)  # furnace glow behind the grille
    proud_eyes(c, h, [(0.7 * k, z0 + 0.35 * k)], 0.34 * k, 0.34 * k, fireL, ring=steel, pupil=fire,
               lid=brassD, iris2=fire, behind=y0 - 1.4 * k)
    # flippers, mirrored
    for sx, name in ((1, 'finR'), (-1, 'finL')):
        _, y, z, r = spine[14]
        fp = c.part(name, name, (sx * r * 0.85, y, z - 0.4 * k))
        for i in range(round(1.3 * k)):
            s_ = i / (1.3 * k)
            fp.ell((sx * (r * 0.85 + i), y + s_ * 0.8 * k, z - 0.4 * k - s_ * 1.0 * k), (0.6, (0.6 - 0.3 * s_) * k, 0.2 * k),
                   brassL if i % 4 else brassD)
    # wide flukes
    t = c.part('tail', 'tail', spine[-8][:3])
    _, ye, ze, _ = spine[-1]
    # whale flukes: two swept-back lobes with a notch between, brass with a
    # riveted light edge, a lamp glowing at each tip
    for sx in (1, -1):
        L = round(1.5 * k)
        for i in range(L):
            s_ = i / L
            yy = ye + (0.15 + 0.75 * s_ * s_) * k
            ln = (0.95 - 0.6 * s_) * k
            for dy in range(round(ln)):
                edge = dy >= round(ln) - 2 or i >= L - 2
                col = brassL if edge else (brass if (i + dy) % 5 else brassD)
                for dz in (0, 1):
                    t.put((i if sx > 0 else -i - 1, round(yy - ln * 0.35 + dy), round(ze - 0.05 * k + 0.45 * i) + dz), col)  # tips swept up
        t.ell((sx * 1.45 * k, ye + 1.0 * k, ze - 0.05 * k + 0.45 * 1.45 * k), (0.2 * k, 0.2 * k, 0.16 * k), fire, True)
    # a toothed dorsal gear fin: half a big gear standing up from the back
    fins = c.part('crest', 'static', spine[22][:3])
    _, gy0, gz0, gr0 = spine[22]
    G = 1.15 * k
    for gy in range(-math.ceil(G) - 2, math.ceil(G) + 3):
        for gz in range(0, math.ceil(G) + 3):
            d = math.hypot(gy + .5, gz + .5)
            ang = math.atan2(gz + .5, gy + .5)
            outer = G + (1.2 if math.cos(ang * 12) > 0.1 else 0)
            if d > outer or (G * 0.32 < d < G * 0.68 and abs(math.sin(ang * 2)) > 0.5):
                continue
            col = brassL if d > G else (steel if d < G * 0.32 else brass)
            for x in (0, -1):
                fins.put((x, round(gy0 + gy), round(gz0 + gr0 * 0.8 + gz)), col)
    # a low toothed ridge running down the back, fore and aft of the gear
    for at in list(range(8, 18)) + list(range(28, 46)):
        _, y, z, r = spine[at]
        top = math.floor(z + r * 0.88)
        for x in (0, -1):
            fins.put((x, math.floor(y), top + 1), brassD)
            if at % 2 == 0:
                fins.put((x, math.floor(y), top + 2), brassL)
    for q in [q for q in fins.v if q in b.v]:
        del fins.v[q]
    tidy(c)
    orbit_ring(c, k, [(30, 4.2, 0.5, gear(brass, brassL)), (150, 4.4, 0.45, gear(copper, brassL)),
                      (270, 4.2, 0.5, gear(steel, brassL))]
               + ([(90, 4.8, 0.28, star4(fireL, fire)), (210, 4.8, 0.28, star4(fireL, fire))] if fine else []),
               margin=0.4)
    return c


BUILDERS = {
    'ClockworkLeviathan': clockwork_leviathan,
    'ThunderKraken': thunder_kraken,
    'EclipseDragon': eclipse_dragon,
    'MechaDragon': mecha_dragon,
    'ChronoOwl': chrono_owl,
    'CosmicWhale': cosmic_whale,
    'CrystalSwan': crystal_swan,
    'ButterflyEmpress': butterfly_empress,
    'HurricaneRoc': hurricane_roc,
}
