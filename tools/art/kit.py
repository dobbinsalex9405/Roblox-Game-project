"""The variant kit: new body plans (bugs, crab), patterns and accessories that
dress up a creature after its body plan has built it. A new Common is one
entry in tools/art/roster/*.json (see variants.py), made from a body plan,
colours, patterns and accessories, so many Commons can be added as data.

Everything here works in the art frame (x right, y back, front is -y, z up)
and scales with k = H / 10 like the body plans, so it looks the same in the
in-game boxes and in the finer Blender build."""
import math

from voxkit import hexc

INK, WHITE = hexc('#1B1B2F'), hexc('#FFFFFF')


def _hash(*v):
    h = 2166136261
    for x in v:
        h = ((h ^ (int(x) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    return h


def _find(c, name):
    for p in c.parts:
        if p.name == name:
            return p
    return None


def ball(part, centre, r, col):
    """An ellipsoid that always has at least its centre voxel, so a tiny
    accessory on the small in-game build never vanishes."""
    part.ell(centre, r, col)
    part.put(tuple(math.floor(v) for v in centre), col)


def head_of(c):
    return _find(c, 'head') or _find(c, 'body')


def crown(c):
    """(y, z) of the top of the head, centred: where hats and bows sit."""
    head = head_of(c)
    zt = max(p[2] for p in head.v)
    top = [p for p in head.v if p[2] >= zt - 1]
    y = sum(p[1] for p in top) / len(top)
    return y, zt


# ---------------------------------------------------------------- body plans

def bug(c, H, kind, col, accent, wing=None):
    """Small bugs: bee, butterfly, beetle, caterpillar."""
    from creatures import eyes, blush
    k = H / 10.0
    body = c.part('body')
    head = c.part('head', 'static', (0, -2.0 * k, 3.4 * k))
    wc = wing or hexc('#E8F4FF')
    if kind == 'bee':
        body.ell((0, 0.9 * k, 2.6 * k), (2.2 * k, 2.8 * k, 2.1 * k), col)
        w = max(1, round(0.7 * k))
        body.paint(lambda p, cc, g: (accent, False) if p[1] > -0.6 * k and (p[1] // w) % 2 == 0 else None)
        body.put((0, round(3.8 * k), round(2.4 * k)), accent)
        head.ell((0, -1.9 * k, 3.0 * k), (1.8 * k, 1.5 * k, 1.7 * k), col)
        eyes(c, head, max(1, round(0.6 * k)), round(3.2 * k), max(1, round(0.5 * k)))
        blush(head, round(1.2 * k), round(2.4 * k))
        for sx in (-1, 1):
            wp = c.part('wingL' if sx < 0 else 'wingR', 'wingL' if sx < 0 else 'wingR', (sx * 1.0 * k, 0.4 * k, 4.4 * k))
            wp.ell((sx * 1.9 * k, 0.6 * k, 4.9 * k), (1.4 * k, 1.1 * k, 0.4 * k + .3), wc)
            for i in range(max(2, round(1.2 * k))):
                head.put((round(sx * 0.7 * k) - (1 if sx < 0 else 0) + (sx * (i // 2)), round(-2.4 * k), round(4.4 * k) + i), accent)
        for sx in (-1, 1):
            for i, ly in enumerate((-0.4 * k, 1.6 * k)):
                x = round(sx * 1.0 * k) - (1 if sx < 0 else 0)
                leg = _leg(c, sx, i, 2, (x + .5, round(ly) + .5, round(0.9 * k) + 1))
                leg.box((x, round(ly), 0), (x, round(ly), round(0.9 * k)), accent)
    elif kind == 'butterfly':
        body.ell((0, 0.6 * k, 2.4 * k), (0.8 * k, 2.4 * k, 0.8 * k), accent)
        head.ell((0, -2.2 * k, 2.8 * k), (1.4 * k, 1.3 * k, 1.3 * k), accent)
        eyes(c, head, max(1, round(0.5 * k)), round(2.9 * k), max(1, round(0.4 * k)))
        blush(head, round(1.0 * k), round(2.2 * k))
        zb = 3.0 * k
        for sx in (-1, 1):
            name = 'wingL' if sx < 0 else 'wingR'
            wp = c.part(name, name, (sx * 0.6 * k, 0.6 * k, zb))
            # two lobes standing up in a shallow V, a voxel and a bit thick
            for (cy, cz, ry, rz) in ((-0.2, 2.6, 1.9, 2.3), (1.9, 1.2, 1.3, 1.4)):
                for y in range(math.floor((cy - ry) * k), math.ceil((cy + ry) * k) + 1):
                    for z in range(math.floor(zb + (cz - rz) * k), math.ceil(zb + (cz + rz) * k) + 1):
                        d = ((y + .5 - cy * k) / (ry * k)) ** 2 + ((z + .5 - zb - cz * k) / (rz * k)) ** 2
                        if d > 1:
                            continue
                        x = round(sx * (0.9 * k + max(0, z - zb) * 0.35))
                        x = x if sx > 0 else x - 1
                        colw = wc if d > 0.62 else col
                        wp.put((x, y, z), colw)
                        if k >= 1.5:
                            wp.put((x + sx, y, z), colw)
            # a pale spot on each upper wing
            for (x, y, z), (cc, g) in list(wp.v.items()):
                if math.dist((y, z), (-0.2 * k, zb + 3.2 * k)) < 0.55 * k:
                    wp.v[(x, y, z)] = (WHITE, False)
            for i in range(max(2, round(1.4 * k))):
                head.put((round(sx * 0.5 * k) - (1 if sx < 0 else 0) + sx * (i // 2), round(-2.8 * k), round(3.9 * k) + i), INK)
        for sx in (-1, 1):
            x = round(sx * 0.5 * k) - (1 if sx < 0 else 0)
            # (the coarse stand-in's body is all head and wings but these)
            leg = _leg(c, sx, 0, 1, (x + .5, .5, round(1.8 * k) + 1)) if getattr(c, 'fine', False) else body
            leg.box((x, 0, 0), (x, 0, round(1.8 * k)), INK)
    elif kind == 'beetle':
        shell = c.part('shell', 'static')
        shell.ell((0, 0.8 * k, 2.0 * k), (2.6 * k, 3.0 * k, 1.9 * k), col, cond=lambda x, y, z: z >= round(1.0 * k))
        shell.paint(lambda p, cc, g: (accent, False) if abs(p[0] + .5) < 0.6 and p[2] > 1.4 * k else None)
        body.ell((0, 0.8 * k, 1.2 * k), (2.2 * k, 2.6 * k, 0.8 * k), INK)
        head.ell((0, -2.4 * k, 1.8 * k), (1.4 * k, 1.1 * k, 1.1 * k), INK)
        eyes(c, head, max(1, round(0.4 * k)), round(2.0 * k), max(1, round(0.4 * k)))
        for pp in list(c.part('eyes').v):
            c.part('eyes').v[pp] = (WHITE, False)
        for i in range(max(2, round(1.8 * k))):  # a little horn
            head.put((0, round(-3.4 * k) - i // 2, round(2.2 * k) + i), accent)
            head.put((-1, round(-3.4 * k) - i // 2, round(2.2 * k) + i), accent)
        for sx in (-1, 1):
            for i, ly in enumerate((-1.0 * k, 0.8 * k, 2.6 * k)):
                # a leg out from under the shell: a thigh from just inside
                # the body's edge at this row (the middle pair sits where it
                # bulges most), then down, so every leg shows the same length
                hw = 2.2 * k * math.sqrt(max(0.0, 1 - ((ly - 0.8 * k) / (2.6 * k)) ** 2))
                x = round(sx * (hw + 0.6 * k)) - (1 if sx < 0 else 0)
                inner = round(sx * hw) - (1 if sx < 0 else 0) - sx
                leg = _leg(c, sx, i, 3, (inner + .5, round(ly) + .5, round(0.9 * k) + 1))
                leg.box((min(x, inner), round(ly), round(0.9 * k)), (max(x, inner), round(ly), round(0.9 * k)), INK)
                leg.box((x, round(ly), 0), (x, round(ly), round(0.9 * k)), INK)
    elif kind == 'caterpillar':
        n = 5
        for i in range(n):
            r = (1.5 - i * 0.12) * k
            body.ell((0, (-0.6 + i * 1.5) * k, r), (r, r * 0.9, r), col if i % 2 else accent)
        head.ell((0, -2.4 * k, 2.4 * k), (1.8 * k, 1.5 * k, 1.8 * k), col)
        eyes(c, head, max(1, round(0.6 * k)), round(2.8 * k), max(1, round(0.5 * k)))
        blush(head, round(1.1 * k), round(2.0 * k))
        for sx in (-1, 1):
            for i in range(max(2, round(1.4 * k))):
                head.put((round(sx * 0.7 * k) - (1 if sx < 0 else 0), round(-2.6 * k), round(4.0 * k) + i), INK)
    else:
        raise ValueError(f'bug: unknown kind {kind}')
    return c


def _leg(c, sx, i, n, hip):
    import rig
    return rig.leg_part(c, 'L' if sx < 0 else 'R', i, n, hip)


def crab(c, H, col, accent):
    from creatures import blush
    k = H / 10.0
    body = c.part('body')
    head = c.part('head', 'static', (0, -1.6 * k, 2.6 * k))
    body.ell((0, 0.4 * k, 2.0 * k), (3.0 * k, 2.2 * k, 1.4 * k), col)
    head.ell((0, -1.2 * k, 2.4 * k), (2.2 * k, 1.2 * k, 1.1 * k), col)
    body.paint(lambda p, cc, g: (accent, False) if p[2] < 1.4 * k else None)
    eyes_p = c.part('eyes', 'blink', head.pivot)
    for sx in (-1, 1):
        x = round(sx * 0.9 * k) - (1 if sx < 0 else 0)
        head.box((x, round(-1.8 * k), round(3.2 * k)), (x, round(-1.8 * k), round(4.0 * k)), col)
        head.box((x, round(-1.8 * k), round(4.0 * k) + 1), (x, round(-1.8 * k) + 1, round(4.0 * k) + 2), WHITE)
        eyes_p.put((x, round(-1.8 * k) - 1, round(4.0 * k) + 2), INK)
        # claws, raised in front
        cx = sx * 3.0 * k
        body.ell((cx, -1.8 * k, 2.8 * k), (0.9 * k, 0.9 * k, 1.0 * k), col)
        body.ell((cx + sx * 0.3 * k, -2.6 * k, 3.6 * k), (0.4 * k + .3, 0.5 * k, 0.7 * k), col)
        for i, ly in enumerate((-0.2 * k, 1.0 * k, 2.0 * k)):
            xx = round(sx * 3.0 * k) - (1 if sx < 0 else 0)
            inner = round(sx * 2.2 * k) - (1 if sx < 0 else 0)
            top = round(1.2 * k)
            leg = _leg(c, sx, i, 3, (inner + .5, round(ly) + .5, top + 1))
            # out from under the shell, then down to the sand
            leg.box((min(xx, inner), round(ly), top), (max(xx, inner), round(ly), top), col)
            x2 = xx + (sx if k > 1 else 0)  # two voxels wide, outward on either side
            leg.box((min(xx, x2), round(ly), 0), (max(xx, x2), round(ly), top), col)
    blush(head, round(1.4 * k), round(2.0 * k))
    return c


def lizard(c, H, kind, col, accent, belly=None):
    """Small lizards, low and long with a big round head: gecko, chameleon,
    iguana, bearded (a bearded dragon). `accent` is the crest, spines, beard
    or the gecko's spots; `belly` the underside and chin."""
    from creatures import eyes, blush
    k = H / 10.0
    fine = getattr(c, 'fine', False)
    body = c.part('body')
    head = c.part('head', 'static', (0, -2.2 * k, 3.4 * k))
    tail = c.part('tail', 'static', (0, 3.0 * k, 2.1 * k))
    body.ell((0, 0.8 * k, 2.2 * k), (1.8 * k, 2.8 * k, 1.5 * k), col)
    if belly:
        body.paint(lambda p, cc, g: (belly, False) if p[2] < 1.6 * k else None)
    # four short legs splayed out to the sides, toes forward
    lw = max(1, round(0.7 * k))
    # Drawn on the right, then mirrored (x -> -x - 1) so both sides match.
    for ly in (-0.9 * k, 2.4 * k):
        x0 = round(1.6 * k)
        xt = x0 + lw
        boxes = (((x0, round(ly), 0), (x0 + lw - 1, round(ly) + lw - 1, round(1.6 * k))),
                 ((xt, round(ly) - 1, 0), (xt + (1 if k >= 1.5 else 0), round(ly) + lw - 1, 0)))
        for a, b in boxes:
            body.box(a, b, col)
            body.box((-b[0] - 1, a[1], a[2]), (-a[0] - 1, b[1], b[2]), col)
    # a big round head, a little wider than tall, with a short flat muzzle
    head.ell((0, -2.4 * k, 3.9 * k), (max(2.0 * k, 2.1), 1.75 * k, max(1.9 * k, 1.6)), col)  # wide enough for eyes in the small build
    head.ell((0, -3.4 * k, 3.0 * k), (1.2 * k, 1.3 * k, 1.0 * k), col)
    if belly:
        head.paint(lambda p, cc, g: (belly, False) if p[2] < 2.5 * k else None)
    # the tail: a tapering line of balls, curling up at the tip for a chameleon
    n = 12
    for i in range(n):
        t = i / (n - 1)
        r = (0.95 - 0.55 * t) * k
        if kind == 'chameleon' and t > 0.5:
            a = (t - 0.5) / 0.5 * math.pi * 1.5
            y, z = 4.6 * k + 1.1 * k * math.sin(a), 1.6 * k + 1.1 * k * (1 - math.cos(a))
        else:
            y, z = 3.0 * k + 3.2 * k * t, 2.0 * k - 1.1 * k * t
        zc = max(r, z)
        tail.ell((0, y, zc), (r, 0.6 * k, r), col)
        for x in (-1, 0):  # never thinner than two voxels, in the small in-game build too
            tail.put((x, math.floor(y), math.floor(zc)), col)
    if kind == 'chameleon' and fine:
        # turret eyes: a ball of skin on each side the eyes sit in
        for sx in (-1, 1):
            head.ell((sx * 1.2 * k, -3.2 * k, 4.4 * k), (0.8 * k, 0.7 * k, 0.8 * k), col)
    es = max(1, round(0.8 * k))
    ze = min(round(3.6 * k), max(p[2] for p in head.v) - es)  # on the face in the small build too
    eyes(c, head, max(1, round(1.0 * k)), ze, es)
    blush(head, round(1.7 * k), round(2.9 * k))
    ac = hexc(accent) if isinstance(accent, str) else accent
    if kind == 'gecko':
        # round spots along the back and tail
        for part in (body, tail):
            zmid = 2.1 * k
            part.paint(lambda p, cc, g: (ac, False) if not g and p[2] >= zmid and _hash(p[0] // 2, p[1] // 2, p[2] // 2, 3) % 4 == 0 else None)
    elif kind == 'chameleon':
        # a rounded casque on the back of the head and a ridge down the back
        cq = c.part('crest', 'static')
        cq.ell((0, -1.7 * k, 5.4 * k), (0.45 * k + .3, 1.1 * k, 1.1 * k), ac)
        for p in list(body.v):
            if p[0] in (-1, 0) and p[2] == max(q[2] for q in body.v if q[0] == p[0] and q[1] == p[1]):
                body.put(p, ac)
    elif kind in ('iguana', 'bearded'):
        # a row of spines down the back and onto the tail
        sp = c.part('spines', 'static')
        step = max(2, round(0.9 * k))
        for part in (body, tail):
            # the tail's spines belong to the tail, so they stay on it when
            # shape() rescales the body and only shifts the tail
            dest = sp if part is body else tail
            tops = {}
            for (x, y, z) in part.v:
                if x == 0:
                    tops[y] = max(tops.get(y, -1), z)
            for y, z in tops.items():
                if y % step == 0 and y > -1.8 * k:
                    for dz in ((1, 2) if fine else (1,)):
                        dest.put((0, y, z + dz), ac)
                        dest.put((-1, y, z + dz), ac)
        if kind == 'iguana':
            # a dewlap under the chin
            for i in range(max(2, round(1.0 * k))):
                head.box((-1, round(-3.4 * k) + i // 2, round(1.9 * k) - i), (0, round(-3.0 * k), round(1.9 * k) - i), ac)
        else:
            # a spiky beard: the chin and jaw speckled in the accent colour,
            # with a few spikes standing proud at the sides
            head.paint(lambda p, cc, g: (ac, False) if not g and p[2] < 2.7 * k and (p[0] + p[1] + p[2]) % 2 == 0 else None)
            bd = c.part('beard', 'static')
            zj = round(2.4 * k)
            for (x, y, z) in list(head.v):
                if z == zj and (y % 2 == 0) and abs(x + .5) > 1.0 * k:
                    nx = x + (1 if x >= 0 else -1)
                    if (nx, y, z) not in head.v:
                        bd.put((nx, y, z), ac)
    else:
        raise ValueError(f'lizard: unknown kind {kind}')
    return c

# ------------------------------------------------------------------ patterns

def pattern(c, H, kind, col, parts=('body',)):
    """Paints a pattern on the named parts."""
    k = H / 10.0
    col = hexc(col) if isinstance(col, str) else col
    targets = [p for p in (_find(c, n) for n in parts) if p]
    for part in targets:
        if not part.v:
            continue
        zlo = min(p[2] for p in part.v)
        zhi = max(p[2] for p in part.v)
        if kind == 'spots':
            s = max(2, round(1.3 * k))

            def spot(p, cc, g, s=s):
                if g:
                    return None
                cell = (p[0] // s, p[1] // s, p[2] // s)
                h = _hash(*cell, 7)
                if h % 100 >= 38:
                    return None
                ox, oy, oz = ((h >> 8) % s, (h >> 12) % s, (h >> 16) % s)
                cxyz = (cell[0] * s + ox * 0.5 + s * 0.25, cell[1] * s + oy * 0.5 + s * 0.25, cell[2] * s + oz * 0.5 + s * 0.25)
                d = math.dist((p[0] + .5, p[1] + .5, p[2] + .5), cxyz)
                return (col, False) if d < s * 0.55 else None
            part.paint(spot)
        elif kind == 'stripes':
            w = max(1, round(0.6 * k))
            mid = zlo + (zhi - zlo) * 0.45
            part.paint(lambda p, cc, g: (col, False) if not g and p[2] >= mid and (p[1] // w) % 2 == 0 else None)
        elif kind == 'socks':
            part.paint(lambda p, cc, g: (col, False) if not g and p[2] <= zlo + round(0.7 * k) else None)
        elif kind == 'saddle':
            part.paint(lambda p, cc, g: (col, False) if not g and p[2] >= zhi - round(0.9 * k) else None)
        elif kind == 'tips':
            part.paint(lambda p, cc, g: (col, False) if not g and p[2] >= zhi - round(0.5 * k) else None)
        elif kind == 'back':  # the rear half
            ymid = (min(p[1] for p in part.v) + max(p[1] for p in part.v)) / 2
            part.paint(lambda p, cc, g: (col, False) if not g and p[1] >= ymid else None)
        else:
            raise ValueError(f'pattern: unknown kind {kind}')


# --------------------------------------------------------------- accessories

def accessory(c, H, kind, col, col2=None):
    """Adds an accessory as its own part (it rides on the head or body)."""
    k = H / 10.0
    col = hexc(col) if isinstance(col, str) else col
    col2 = hexc(col2) if isinstance(col2, str) else (col2 or WHITE)
    head = head_of(c)
    y, zt = crown(c)
    if kind == 'beanie':
        hat = c.part('hat', 'static')
        cut = zt - max(1, round(0.9 * k))
        for p, (cc, g) in list(head.v.items()):
            if p[2] >= cut:
                hat.put(p, col)
        for p in list(hat.v):  # a turned-up band one voxel proud
            if p[2] == cut:
                hat.put((p[0], p[1], p[2]), col2)
        ball(hat, (0, y, zt + 0.5 * k), (0.6 * k, 0.6 * k, 0.6 * k), col2)
    elif kind == 'bow':
        bow = c.part('bow', 'static')
        bx = 1.0 * k
        for sx in (-1, 1):
            ball(bow, (bx + sx * 0.6 * k, y, zt + 0.4 * k), (0.5 * k, 0.35 * k + .3, 0.45 * k), col)
        ball(bow, (bx, y, zt + 0.4 * k), (0.3 * k + .2, 0.4 * k, 0.3 * k + .2), col2)
    elif kind == 'flower':
        fl = c.part('flower', 'static')
        fx, z = round(1.0 * k), zt + 1
        r = max(1, round(0.5 * k))
        for dx, dy in ((r, 0), (-r, 0), (0, r), (0, -r)):
            ball(fl, (fx + dx, y + dy, z), (0.45 * k, 0.45 * k, 0.3 * k + .2), col)
        ball(fl, (fx, y, z + 0.2 * k), (0.35 * k, 0.35 * k, 0.3 * k + .2), col2)
    elif kind == 'sprout':
        sp = c.part('sprout', 'static')
        h = max(2, round(1.0 * k))
        for i in range(h):
            sp.put((0, round(y), zt + 1 + i), col2)
        for sx in (-1, 1):
            ball(sp, (sx * 0.6 * k, y, zt + h + 0.2 * k), (0.6 * k, 0.3 * k + .2, 0.3 * k + .2), col)
    elif kind in ('scarf', 'bell'):
        body = _find(c, 'body')
        if body is None or head is body:
            return
        r = max(1, round(0.5 * k))
        hv = set(head.v)
        sc = c.part('scarf', 'static')
        for p in list(body.v):
            if p[2] < 1.2 * k:
                continue
            near = any((p[0] + dx, p[1] + dy, p[2] + dz) in hv
                       for dx in range(-r, r + 1) for dy in range(-r, r + 1) for dz in range(-r, r + 1))
            if near:
                sc.put(p, col)
        if kind == 'bell' and sc.v:
            fy = min(p[1] for p in sc.v)
            fz = min(p[2] for p in sc.v if p[1] <= fy + 1)
            ball(sc, (0, fy - 0.2 * k, fz), (0.5 * k + .2, 0.5 * k + .2, 0.5 * k + .2), col2)
    elif kind == 'horns':
        hp = c.part('horns', 'static')
        n = max(2, round(1.2 * k))
        for sx in (-1, 1):
            x = round(sx * 0.8 * k) - (1 if sx < 0 else 0)
            for i in range(n):
                hp.put((x + (sx if i >= n - 1 and k > 1.5 else 0), round(y) + i // 2, zt + 1 + i), col)
                if i < n // 2:
                    hp.put((x + sx, round(y) + i // 2, zt + 1 + i), col)
    elif kind == 'beard':
        fz = min(p[2] for p in head.v)
        fy = min(p[1] for p in head.v if p[2] <= fz + 1)
        bd = c.part('beard', 'static')
        for i in range(max(2, round(1.0 * k))):
            bd.put((0, fy + 1, fz - 1 - i), col)
            bd.put((-1, fy + 1, fz - 1 - i), col)
    else:
        raise ValueError(f'accessory: unknown kind {kind}')


# --------------------------------------------------------------------- shape

HEAD_PARTS = ('head', 'eyes', 'ears', 'crest', 'mane', 'horn', 'antlers', 'beard')


def _rescale(parts, centre, s):
    """Resamples the parts' voxels (nearest) scaled by s = (sx, sy, sz) about
    centre, so a shape keeps its colours and stays solid."""
    for part in parts:
        if not part.v:
            continue
        src = part.v
        xs, ys, zs = zip(*src)
        lo = [math.floor(centre[i] + (m - centre[i]) * s[i]) - 1 for i, m in enumerate((min(xs), min(ys), min(zs)))]
        hi = [math.ceil(centre[i] + (m + 1 - centre[i]) * s[i]) + 1 for i, m in enumerate((max(xs), max(ys), max(zs)))]
        out = {}
        for x in range(lo[0], hi[0]):
            for y in range(lo[1], hi[1]):
                for z in range(max(0, lo[2]), hi[2]):
                    # x shrinks a hair toward the centre line so a voxel
                    # that lands exactly on a boundary picks the same side
                    # left and right (the creature stays mirrored).
                    p = tuple(math.floor(centre[i] + (q + .5 - centre[i]) / s[i] * (1 - 1e-9 if i == 0 else 1))
                              for i, q in enumerate((x, y, z)))
                    if p in src:
                        out[(x, y, z)] = src[p]
        part.v = out


def shape(c, body=(1.0, 1.0, 1.0), head=1.0):
    """Changes a creature's proportions after its plan built it: the body
    scaled by (width, length, height) about its centre and the ground, the
    head (with its eyes, ears and crest) scaled about its centre and kept
    sitting on the body's front. Applied before accessories, so they fit."""
    b = _find(c, 'body')
    if b and b.v and tuple(body) != (1.0, 1.0, 1.0):
        ys = [p[1] for p in b.v]
        cy = (min(ys) + max(ys) + 1) / 2
        front0 = min(ys)
        top0 = max(p[2] for p in b.v)
        import rig
        # legs a body plan drew as their own parts stretch with the body,
        # hips and all, so they stay on the ground and under it
        # Legs a body plan drew as their own parts move with the body (each
        # by its hip's scaled offset) but keep their shape and height:
        # resampling a one-voxel leg would thin it away.
        legs = [p for p in c.parts if p.name in rig.LEG_NAMES]
        _rescale([b] + [p for p in c.parts if p.name in ('shell', 'spines')], (0, cy, 0), body)
        for p in legs:
            dx = round(p.pivot[0] * body[0] - p.pivot[0])
            dy = round(cy + (p.pivot[1] - cy) * body[1] - p.pivot[1])
            p.v = {(x + dx, y + dy, z): v for (x, y, z), v in p.v.items()}
            p.pivot = (p.pivot[0] + dx, p.pivot[1] + dy, p.pivot[2])
        # the head and tail move with the body's front, back and top
        dy_front = min(p[1] for p in b.v) - front0
        dy_back = max(p[1] for p in b.v) - max(ys)
        dz_top = max(p[2] for p in b.v) - top0
        for p in c.parts:
            if p is b or p.name in ('shell', 'spines') or p in legs:
                continue
            dy = dy_front if p.name in HEAD_PARTS else (dy_back if p.name == 'tail' else 0)
            dz = round(dz_top * (0.5 if p.name == 'tail' else 1))
            if dy or dz:
                p.v = {(x, y + dy, z + dz): v for (x, y, z), v in p.v.items()}
                p.pivot = (p.pivot[0], p.pivot[1] + dy, p.pivot[2] + dz)
    h = _find(c, 'head')
    if h and h.v and head != 1.0:
        xs, ys, zs = zip(*h.v)
        centre = (0, (min(ys) + max(ys) + 1) / 2, min(zs))  # grows up and out from the neck
        _rescale([p for p in c.parts if p.name in HEAD_PARTS], centre, (head, head, head))
