"""Body plans for pond, shore and garden-bug Commons, used by roster entries
like the plans in kit.py (see variants.py):

- **critter**: garden bugs: dragonfly, ant, grasshopper, spider, firefly,
  pillbug, worm, slug, mantis. Colours: col, accent, wing.
- **shore**: pond and shore animals: starfish, urchin, hermit, lobster,
  seal, walrus, newt, beaver, platypus. Colours: col, accent, belly.

Same art frame as kit.py (x right, y back, front is -y, z up) and the same
scale (k = H / 10), so a plan looks alike in the in-game boxes and in the
finer Blender build. Each plan keeps to the parts the game animates (body,
head, eyes, tail, wingL/wingR) plus static extras."""
import math

from voxkit import hexc

INK, WHITE = hexc('#1B1B2F'), hexc('#FFFFFF')
GLOW_TAIL = hexc('#FFF27A')

PLANS = {
    'critter': (
        {'col', 'accent', 'wing'},
        {'kind': {'dragonfly', 'ant', 'grasshopper', 'spider', 'firefly', 'pillbug', 'worm', 'slug', 'mantis'}},
    ),
    'shore': (
        {'col', 'accent', 'belly'},
        {'kind': {'starfish', 'urchin', 'hermit', 'lobster', 'seal', 'walrus', 'newt', 'beaver', 'platypus'}},
    ),
}


def _mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _dark(col, t=0.35):
    return _mix(col, INK, t)


def line(part, a, b, col, r=0.0, glow=False):
    """A voxel line from a to b; r > 0 makes it a round rod that thick."""
    n = max(1, int(math.ceil(max(abs(b[i] - a[i]) for i in range(3)) * 2)))
    for i in range(n + 1):
        t = i / n
        p = tuple(a[j] + (b[j] - a[j]) * t for j in range(3))
        if r > 0.6:
            part.ell(p, (r, r, r), col, glow)
        else:
            part.put(tuple(math.floor(v) for v in p), col, glow)


def _mx(x):
    """x mirrored for the left side (voxel cells are [x, x+1))."""
    return -x - 1


def face(c, head, k, z, x_off=0.7, size=0.55, cheeks=True, cheek_z=None, cheek_x=None):
    """Eyes (that blink) and blushing cheeks, the same as the body plans'."""
    from creatures import eyes, blush
    eyes(c, head, max(1, round(x_off * k)), round(z * k), max(1, round(size * k)))
    if cheeks and k >= 1:
        cx = cheek_x if cheek_x is not None else x_off + 0.8
        blush(head, round(cx * k), round((cheek_z if cheek_z is not None else z - 0.8) * k))


def antennae(head, k, x, y, z, length, col, back=0.0, spread=0.35):
    """Two antennae from (±x, y, z), leaning out by `spread` and back by
    `back` per voxel up, `length` voxels long (at least two)."""
    n = max(2, round(length * k))
    for sx in (-1, 1):
        for i in range(n):
            xx = round(x * k + i * spread)
            head.put((xx if sx > 0 else _mx(xx), round(y * k + i * back), round(z * k) + i), col)


def legs(body, k, spots, col, out=0.9, height=1.0, w=None):
    """Six (or more) thin legs: for each (x, y) on the body's side a rod down
    and out to the ground."""
    w = w if w is not None else max(0, round(0.18 * k))
    for (x, y) in spots:
        for sx in (-1, 1):
            top = (sx * x * k, y * k, height * k)
            foot = (sx * (x + out) * k, y * k, 0)
            n = max(2, round(max(out, height) * k * 1.5))
            for i in range(n + 1):
                t = i / n
                px = top[0] + (foot[0] - top[0]) * t
                pz = top[2] + (foot[2] - top[2]) * t
                bx = math.floor(px)
                for dx in range(w + 1):
                    for dy in range(w + 1):
                        body.put((bx + (dx if sx > 0 else -dx), math.floor(top[1]) + dy, max(0, math.floor(pz))), col)


def bent_legs(body, k, ys, col, hip=(0.8, 2.0), knee=(1.8, 3.4), foot=2.6, r=0.3, splay=0.5):
    """Pairs of legs that arch up to a knee and down to the ground, like a
    spider's or an ant's: for each y on the body a hip at (x, z), a knee
    further out and higher, a foot further out still. Legs splay forward at
    the front and back at the rear by `splay`."""
    mid = (ys[0] + ys[-1]) / 2
    for y in ys:
        dy = (y - mid) * splay
        for sx in (-1, 1):
            a = (sx * hip[0] * k, y * k, hip[1] * k)
            b = (sx * knee[0] * k, (y + dy * 0.5) * k, knee[1] * k)
            c = (sx * foot * k, (y + dy) * k, 0)
            line(body, a, b, col, r=r * k)
            line(body, b, c, col, r=r * k * 0.85)


# --------------------------------------------------------------- critters

def critter(c, H, kind, col, accent=None, wing=None):
    k = H / 10.0
    accent = accent or _dark(col)
    wc = wing or hexc('#DDF3FF')
    body = c.part('body')
    head = c.part('head', 'static', (0, -2.0 * k, 3.0 * k))
    if kind == 'dragonfly':
        # a long striped tail held level and lifted at the tip, a round
        # thorax, a big head that is mostly eyes, four long clear wings
        body.ell((0, -0.3 * k, 2.0 * k), (1.0 * k, 1.2 * k, 1.0 * k), col)
        for i in range(7):
            r = (0.62 - i * 0.04) * k
            body.ell((0, (0.9 + i * 0.75) * k, (2.0 + i * 0.1) * k), (r, 0.5 * k + .3, r), col if i % 2 == 0 else accent)
        head.ell((0, -1.9 * k, 2.4 * k), (1.2 * k, 1.0 * k, 1.1 * k), col)
        for sx in (-1, 1):
            head.ell((sx * 0.9 * k, -2.0 * k, 2.9 * k), (0.8 * k, 0.8 * k, 0.8 * k), accent)
        face(c, head, k, 2.1, x_off=0.35, size=0.45, cheek_z=1.6)
        bent_legs(body, k, (-0.9, -0.3, 0.3), INK, hip=(0.5, 1.4), knee=(1.0, 1.4), foot=1.3, r=0.2)
        for sx in (-1, 1):
            name = 'wingL' if sx < 0 else 'wingR'
            wz = round(3.6 * k)
            wp = c.part(name, name, (sx * 0.5 * k, -0.3 * k, wz))
            for (cy, ry, rx) in ((-0.7, 0.7, 4.2), (0.7, 0.62, 3.8)):
                for x in range(1, math.ceil(rx * k) + 1):
                    for y in range(math.floor((cy - ry) * k), math.ceil((cy + ry) * k) + 1):
                        d = ((x - 0.5) / (rx * k)) ** 2 + ((y + .5 - cy * k) / (ry * k)) ** 2
                        if d > 1:
                            continue
                        xx = round(0.5 * k) + x - 1
                        # a clear wing with a thin coloured rim and a spot at the tip
                        edge = d > 0.8
                        spot = x > rx * k * 0.8 and abs(y + .5 - cy * k) < ry * k * 0.45
                        wp.put((xx if sx > 0 else _mx(xx), y, wz + (1 if x > 2.6 * k else 0)), accent if (edge or spot) else wc)
    elif kind == 'ant':
        # a round head, a slim chest, a pinched waist and a big round rear
        # tipped up, on six arched legs
        head.ell((0, -2.6 * k, 3.4 * k), (1.5 * k, 1.3 * k, 1.4 * k), col)
        body.ell((0, -0.7 * k, 2.8 * k), (0.8 * k, 1.1 * k, 0.75 * k), col)
        body.ell((0, 0.6 * k, 2.6 * k), (0.45 * k + .2, 0.45 * k + .2, 0.45 * k + .2), col)
        body.ell((0, 2.2 * k, 3.0 * k), (1.5 * k, 1.8 * k, 1.4 * k), col)
        body.paint(lambda p, cc, g: (accent, False) if p[1] > 1.4 * k and p[2] > 3.8 * k else None)
        face(c, head, k, 3.4, x_off=0.5, size=0.5, cheek_z=2.7)
        # elbowed antennae: up, then forward
        for sx in (-1, 1):
            x = round(0.5 * k)
            up = max(2, round(1.3 * k))
            for i in range(up):
                head.put((x if sx > 0 else _mx(x), round(-2.9 * k), round(4.6 * k) + i), INK)
            for i in range(max(2, round(1.0 * k))):
                xx = x + i // 2
                head.put((xx if sx > 0 else _mx(xx), round(-2.9 * k) - 1 - i, round(4.6 * k) + up - 1), INK)
        bent_legs(body, k, (-1.3, -0.7, -0.1), _dark(col, 0.45), hip=(0.6, 2.6), knee=(1.7, 3.2), foot=2.3, r=0.25, splay=1.2)
    elif kind == 'grasshopper':
        # a long body, a tall head, folded wings and big jumping legs
        body.ell((0, 0.8 * k, 2.6 * k), (1.2 * k, 3.0 * k, 1.2 * k), col)
        body.paint(lambda p, cc, g: (accent, False) if p[2] < 2.0 * k else None)
        for y in range(round(-0.4 * k), round(3.8 * k)):  # folded wings along the back
            for x in (-1, 0):
                body.put((x, y, round(3.7 * k)), wc)
        head.ell((0, -2.2 * k, 3.6 * k), (1.3 * k, 1.2 * k, 1.6 * k), col)
        face(c, head, k, 3.8, x_off=0.5, size=0.5)
        antennae(head, k, 0.4, -2.6, 5.0, 2.2, accent, back=0.6, spread=0.2)
        legs(body, k, [(0.7, -1.0), (0.7, 0.2)], accent, out=0.6, height=1.8)
        for sx in (-1, 1):
            # thigh up and back, shin down to the ground behind
            knee = (sx * 1.5 * k, 2.6 * k, 4.6 * k)
            hip = (sx * 1.0 * k, 0.6 * k, 2.8 * k)
            foot = (sx * 1.6 * k, 4.2 * k, 0)
            line(body, hip, knee, col, r=0.45 * k)
            line(body, knee, foot, accent, r=0.33 * k)
    elif kind == 'spider':
        # a round rear with a mark on it, a round front, eight bent legs
        body.ell((0, 1.6 * k, 3.0 * k), (2.0 * k, 2.1 * k, 1.9 * k), col)
        body.paint(lambda p, cc, g: (accent, False) if p[2] > 3.4 * k and (abs(p[0] + .5) < 0.45 * k or abs(p[1] - 1.6 * k) < 0.45 * k) else None)
        head.ell((0, -1.0 * k, 2.4 * k), (1.6 * k, 1.5 * k, 1.4 * k), col)
        face(c, head, k, 2.5, x_off=0.45, size=0.75)
        bent_legs(body, k, (-1.5, -0.9, -0.3, 0.3), _dark(col, 0.15), hip=(1.0, 2.2), knee=(2.3, 3.9), foot=3.4, r=0.28, splay=1.0)
    elif kind == 'firefly':
        # a soft beetle with a coloured cap and a glowing tail
        body.ell((0, 0.6 * k, 2.2 * k), (1.6 * k, 2.6 * k, 1.4 * k), col)
        shell = c.part('shell', 'static')
        shell.ell((0, 0.6 * k, 2.6 * k), (1.8 * k, 2.4 * k, 1.4 * k), col, cond=lambda x, y, z: z >= round(2.4 * k) and y < round(2.2 * k))
        shell.paint(lambda p, cc, g: (_dark(col, 0.25), False) if abs(p[0] + .5) < 0.5 else None)
        lamp = c.part('lamp', 'glow')
        lamp.ell((0, 3.0 * k, 1.9 * k), (1.2 * k, 1.0 * k, 1.0 * k), wing or GLOW_TAIL, True)
        head.ell((0, -2.0 * k, 2.4 * k), (1.4 * k, 1.2 * k, 1.3 * k), accent)
        face(c, head, k, 2.4, x_off=0.45, size=0.5)
        antennae(head, k, 0.4, -2.6, 3.4, 1.6, INK, back=-0.2, spread=0.4)
        legs(body, k, [(0.8, -0.8), (0.9, 0.4), (0.8, 1.6)], INK, out=0.6, height=1.0)
    elif kind == 'pillbug':
        # a domed back of overlapping plates
        body.ell((0, 0.6 * k, 1.6 * k), (2.2 * k, 3.0 * k, 1.9 * k), col, cond=lambda x, y, z: z >= 0)
        band = max(1, round(0.75 * k))
        body.paint(lambda p, cc, g: (accent, False) if ((p[1] - round(-2.4 * k)) // band) % 2 == 1 and p[2] >= 1 else None)
        head.ell((0, -2.4 * k, 1.5 * k), (1.5 * k, 1.0 * k, 1.2 * k), _dark(col, 0.15))
        face(c, head, k, 1.6, x_off=0.4, size=0.5, cheek_z=1.0)
        antennae(head, k, 0.6, -3.0, 2.0, 1.4, _dark(col, 0.4), back=-0.3, spread=0.5)
    elif kind in ('worm', 'slug'):
        if kind == 'worm':
            # segments along the ground, the front one rearing up as a head
            for i in range(5):
                r = (1.05 - i * 0.06) * k
                body.ell((0, (0.6 + i * 1.2) * k, r), (r, 0.8 * k, r), col if i != 1 else accent)
            body.ell((0, -0.4 * k, 1.8 * k), (1.0 * k, 0.9 * k, 1.1 * k), col)
            head.ell((0, -1.0 * k, 3.6 * k), (1.5 * k, 1.3 * k, 1.5 * k), col)
            face(c, head, k, 3.6, x_off=0.5, size=0.5)
        else:
            # a soft slug: a long foot, a mantle on its back, eye stalks
            body.ell((0, 0.8 * k, 1.0 * k), (1.5 * k, 4.0 * k, 1.0 * k), col)
            body.ell((0, 0.4 * k, 1.8 * k), (1.5 * k, 2.0 * k, 1.1 * k), accent)
            body.ell((0, 3.6 * k, 0.8 * k), (0.8 * k, 1.4 * k, 0.8 * k), col)
            head.ell((0, -2.6 * k, 2.2 * k), (1.3 * k, 1.1 * k, 1.5 * k), col)
            face(c, head, k, 2.2, x_off=0.4, size=0.5, cheek_z=1.6)
            for sx in (-1, 1):
                x = round(0.6 * k)
                x = x if sx > 0 else _mx(x)
                line(head, (x + .5, -2.8 * k, 3.2 * k), (x + .5 + sx * 0.3 * k, -3.0 * k, 4.8 * k), col)
                head.ell((x + .5 + sx * 0.3 * k, -3.0 * k, 5.0 * k), (0.4 * k + .2, 0.4 * k + .2, 0.4 * k + .2), _dark(col, 0.2))
    elif kind == 'mantis':
        # an upright mantis: long rear on the ground, tall neck, folded arms
        body.ell((0, 2.0 * k, 2.2 * k), (1.2 * k, 2.6 * k, 1.0 * k), col)
        line(body, (0, 0.2 * k, 2.4 * k), (0, -1.2 * k, 5.0 * k), col, r=0.6 * k)
        body.paint(lambda p, cc, g: (accent, False) if p[2] < 1.8 * k else None)
        for y in range(round(0.6 * k), round(4.2 * k)):
            for x in (-1, 0):
                body.put((x, y, round(3.1 * k)), wc)
        head = c.part('head', 'static', (0, -1.6 * k, 6.0 * k))
        head.ell((0, -1.6 * k, 6.2 * k), (1.7 * k, 1.0 * k, 1.1 * k), col)
        head.ell((0, -1.8 * k, 5.4 * k), (0.8 * k, 0.8 * k, 0.8 * k), col)
        face(c, head, k, 6.2, x_off=0.7, size=0.6, cheek_z=5.6)
        antennae(head, k, 0.4, -1.8, 7.2, 1.8, accent, back=-0.3, spread=0.5)
        for sx in (-1, 1):
            # the folded front arms, held up under the chin
            sh = (sx * 0.6 * k, -1.2 * k, 4.6 * k)
            el = (sx * 0.9 * k, -2.4 * k, 3.4 * k)
            hand = (sx * 0.8 * k, -2.8 * k, 4.6 * k)
            line(body, sh, el, col, r=0.4 * k)
            line(body, el, hand, accent, r=0.35 * k)
        legs(body, k, [(0.6, 0.6), (0.6, 1.8)], accent, out=1.2, height=2.0)
    else:
        raise ValueError(f'critter: unknown kind {kind}')
    return c


# ------------------------------------------------------------------ shore

def _star(R, cz):
    """(x, z) of the five star points: one up, two out, two on the ground."""
    pts = []
    for i in range(5):
        t = math.radians(90 + 72 * i)
        pts.append((R * math.cos(t), cz + R * math.sin(t)))
    return pts


def shore(c, H, kind, col, accent=None, belly=None):
    k = H / 10.0
    accent = accent or _dark(col)
    body = c.part('body')
    head = c.part('head', 'static', (0, -2.0 * k, 3.6 * k))
    if kind == 'starfish':
        # standing up on two points, waving the other three, face in front
        R, cz, th = 4.2 * k, 3.6 * k, 0.8 * k
        pts = _star(R, cz)
        lo = min(z for _, z in pts)
        cz -= lo - 0.4 * k
        pts = _star(R, cz)
        for (px, pz) in pts:
            n = max(4, round(R * 1.5))
            for i in range(n + 1):
                t = i / n
                r = (1.5 - 1.1 * t) * k
                body.ell((px * t, 0, cz + (pz - cz) * t), (r, th + (0.5 - 0.4 * t) * k * 0.5, r), col)
        head.ell((0, 0, cz), (1.9 * k, th + 0.3 * k, 1.9 * k), col)
        # bumps down each arm and paler tips
        for (px, pz) in pts:
            for t in (0.45, 0.7):
                x, z = px * t, cz + (pz - cz) * t
                f = body.front(math.floor(x), math.floor(z))
                if f:
                    body.put(f, accent)
        body.paint(lambda p, cc, g: (belly, False) if belly and math.hypot(p[0] + .5, p[2] + .5 - cz) > R * 0.82 else None)
        face(c, head, k, cz / k + 0.2, x_off=0.5, size=0.55, cheek_z=cz / k - 0.5, cheek_x=1.0)
        mouth = head.front(0, round(cz - 0.9 * k))
        if mouth:
            head.put(mouth, INK)
            head.put((-1, mouth[1], mouth[2]), INK)
    elif kind == 'urchin':
        # a round urchin with soft spikes, standing on little tube feet
        cz, r = 2.8 * k, 2.4 * k
        head.ell((0, 0, cz), (r, r, r), col)
        for sx in (-1, 1):
            for y in (-0.8, 0.8):
                x = round(sx * 1.0 * k)
                body.box((x if sx > 0 else _mx(x), round(y * k), 0), (x if sx > 0 else _mx(x), round(y * k), round(0.6 * k)), belly or col)
        sp = c.part('spines', 'static')
        n = 46
        for i in range(n):
            # a Fibonacci sphere of spikes, none on the face or underneath
            zz = 1 - 2 * (i + .5) / n
            rr = math.sqrt(1 - zz * zz)
            a = i * 2.39996
            d = (rr * math.cos(a), rr * math.sin(a), zz)
            if zz < -0.35 or (d[1] < -0.45 and abs(d[0]) < 0.75 and zz < 0.6):
                continue
            a0 = (d[0] * r * 0.9, d[1] * r * 0.9, cz + d[2] * r * 0.9)
            a1 = (d[0] * r * 1.55, d[1] * r * 1.55, cz + d[2] * r * 1.55)
            line(sp, a0, a1, accent, r=0.22 * k)
        face(c, head, k, cz / k + 0.1, x_off=0.6, size=0.6, cheek_z=cz / k - 0.7)
    elif kind in ('hermit', 'lobster'):
        if kind == 'hermit':
            # a little crab peeking out of a big spiral shell
            shell = c.part('shell', 'static')
            shell.ell((0, 1.4 * k, 3.2 * k), (2.3 * k, 2.4 * k, 2.6 * k), accent)
            shell.ell((0, 2.2 * k, 5.4 * k), (1.3 * k, 1.4 * k, 1.4 * k), accent)
            shell.ell((0, 2.6 * k, 6.6 * k), (0.6 * k + .3, 0.6 * k + .3, 0.7 * k + .3), accent)
            band = belly or WHITE
            shell.paint(lambda p, cc, g: (band, False) if int((p[2] - p[1] * 0.6) / max(1, 0.8 * k)) % 2 == 0 else None)
            body.ell((0, -1.2 * k, 1.6 * k), (1.8 * k, 1.4 * k, 1.3 * k), col)
            head.ell((0, -2.0 * k, 2.2 * k), (1.3 * k, 0.8 * k, 0.8 * k), col)
            ez, ey = 3.6, -2.2
            claws = ((1, 1.0), (-1, 0.75))  # one big claw, one small
        else:
            # a lobster: a long body that ends in a fan, big claws up front
            body.ell((0, 0.0 * k, 2.2 * k), (1.6 * k, 2.2 * k, 1.4 * k), col)
            for i in range(4):
                r = (1.2 - i * 0.15) * k
                body.ell((0, (2.2 + i * 0.9) * k, (1.8 - i * 0.15) * k), (r, 0.6 * k + .3, r * 0.85), col)
            tail = c.part('tail', 'static', (0, 5.6 * k, 1.2 * k))
            for sx in (-1, 0, 1):
                tail.ell((sx * 0.8 * k, 6.4 * k, 1.0 * k), (0.6 * k + .2, 0.9 * k, 0.4 * k + .2), accent)
            body.paint(lambda p, cc, g: (belly, False) if belly and p[2] < 1.2 * k else None)
            head.ell((0, -2.2 * k, 2.6 * k), (1.3 * k, 0.9 * k, 1.0 * k), col)
            antennae(head, k, 0.4, -2.8, 3.2, 3.0, accent, back=-0.5, spread=0.25)
            ez, ey = 3.8, -2.4
            claws = ((1, 1.0), (-1, 1.0))
        eyes_p = c.part('eyes', 'blink', head.pivot)
        for sx in (-1, 1):
            x = round(0.7 * k)
            x = x if sx > 0 else _mx(x)
            head.box((x, round(ey * k), round((ez - 0.8) * k)), (x, round(ey * k), round(ez * k)), col)
            s = max(1, round(0.35 * k))
            head.box((x - (s - 1 if sx < 0 else 0), round(ey * k) - s + 1, round(ez * k) + 1), (x + (s - 1 if sx > 0 else 0), round(ey * k), round(ez * k) + s), WHITE)
            eyes_p.put((x, round(ey * k) - s, round(ez * k) + s), INK)
        from creatures import blush
        blush(head, round(1.0 * k), round((ez - 1.6) * k))
        for sx, big in claws:
            cx = sx * (2.4 if kind == 'lobster' else 2.0) * k
            arm0 = (sx * 1.2 * k, -1.6 * k, 1.8 * k)
            arm1 = (cx, -2.6 * k, 2.6 * k)
            line(body, arm0, arm1, col, r=0.4 * k)
            body.ell((cx, -3.4 * k, 3.0 * k), (0.9 * big * k, 1.1 * big * k, 0.8 * big * k), col)
            body.ell((cx + sx * 0.25 * k, -4.4 * k * (0.85 + 0.15 * big), 3.4 * k), (0.4 * big * k + .3, 0.6 * big * k, 0.3 * big * k + .3), accent)
        legs(body, k, [(1.0, -0.6), (1.1, 0.2), (1.0, 1.0)], col, out=0.9, height=1.4)
    elif kind in ('seal', 'walrus'):
        # a plump seal sitting up: big round chest, head raised, flippers
        tusks = kind == 'walrus'
        body.ell((0, 0.4 * k, 2.3 * k), (2.2 * k, 2.6 * k, 2.3 * k), col)
        body.ell((0, 2.6 * k, 1.2 * k), (1.5 * k, 1.8 * k, 1.2 * k), col)
        if belly:
            body.paint(lambda p, cc, g: (belly, False) if p[1] < -0.8 * k and p[2] < 3.4 * k else None)
        tail = c.part('tail', 'static', (0, 4.0 * k, 0.6 * k))
        for sx in (-1, 1):
            tail.ell((sx * 0.9 * k, 4.6 * k, 0.5 * k), (0.9 * k, 1.0 * k, 0.4 * k + .3), accent)
            body.ell((sx * 2.2 * k, -0.6 * k, 0.7 * k), (0.8 * k, 1.1 * k, 0.4 * k + .3), accent)
        head.ell((0, -1.4 * k, 4.8 * k), (2.0 * k, 1.8 * k, 1.8 * k), col)
        muzzle = belly or _mix(col, WHITE, 0.4)
        if tusks:
            muzzle = _mix(col, hexc('#E8C9A0'), 0.6)
        head.ell((0, -3.0 * k, 4.2 * k), (1.2 * k, 0.6 * k + .2, 0.7 * k), muzzle)
        nose = head.front(0, round(4.7 * k)) or head.front(-1, round(4.7 * k))
        if nose:
            head.put(nose, INK)
            head.put((-1, nose[1], nose[2]), INK)
        # whisker dots
        for sx in (-1, 1):
            for dz in (0, 1):
                x = round(0.7 * k) + dz
                f = head.front(x if sx > 0 else _mx(x), round(4.2 * k) - dz)
                if f:
                    head.put(f, _dark(muzzle, 0.45))
        if tusks:
            for sx in (-1, 1):
                x = round(0.5 * k)
                x = x if sx > 0 else _mx(x)
                f = head.front(x, round(3.8 * k))
                y = (f[1] if f else round(-3.4 * k)) + 1
                head.box((x, y - 1, round(2.2 * k)), (x, y - 1, round(3.8 * k)), WHITE)
        face(c, head, k, 5.2, x_off=0.7, size=0.65, cheek_z=4.4)
    elif kind == 'newt':
        # a plump little newt: a wide round head with eyes on top, a soft
        # body, splayed legs and a tail that curls up at the end
        body.ell((0, 0.4 * k, 1.5 * k), (1.5 * k, 2.4 * k, 1.2 * k), col)
        head.ell((0, -2.2 * k, 2.0 * k), (1.9 * k, 1.6 * k, 1.5 * k), col)
        for sx in (-1, 1):
            head.ell((sx * 0.9 * k, -2.4 * k, 3.2 * k), (0.7 * k, 0.7 * k, 0.6 * k), col)
        tail = c.part('tail', 'static', (0, 2.6 * k, 1.2 * k))
        for i in range(7):
            r = (0.95 - i * 0.1) * k
            tail.ell((0, (2.8 + i * 0.65) * k, (1.4 + i * i * 0.05) * k), (r * 0.75 + .3, 0.5 * k + .3, r + .3), col)
        if belly:
            body.paint(lambda p, cc, g: (belly, False) if p[2] < 1.0 * k else None)
            head.paint(lambda p, cc, g: (belly, False) if p[2] < 1.1 * k else None)
        for sx in (-1, 1):
            for ly in (-1.1, 1.8):
                hip = (sx * 1.1 * k, ly * k, 1.2 * k)
                foot = (sx * 2.1 * k, (ly - 0.3) * k, 0.4 * k)
                line(body, hip, foot, col, r=0.45 * k)
                body.ell((sx * 2.2 * k, (ly - 0.5) * k, 0.3 * k), (0.55 * k, 0.55 * k, 0.3 * k + .2), col)
        face(c, head, k, 2.9, x_off=0.6, size=0.55, cheek_z=2.0)
        mouth = head.front(0, round(1.6 * k))
        if mouth and k >= 1:
            for x in range(-round(0.6 * k), round(0.6 * k)):
                g = head.front(x, round(1.6 * k) + (1 if x in (-round(0.6 * k), round(0.6 * k) - 1) else 0))
                if g:
                    head.put(g, INK)
    elif kind in ('beaver', 'platypus'):
        from creatures import quadruped
        quadruped(c, H, col, belly=belly, snout=None if kind == 'platypus' else (belly or col),
                  ears='round', tail='nothing')
        head = c.part('head')
        tail = c.part('tail', 'static', (0, 3.4 * k, 1.0 * k))
        # a flat paddle tail with a cross-hatched top
        tail.ell((0, 5.0 * k, 1.0 * k), (1.3 * k, 1.9 * k, 0.4 * k + .3), accent)
        tail.paint(lambda p, cc, g: (_dark(accent, 0.25), False) if (p[0] + p[1]) % 3 == 0 and p[2] >= round(1.0 * k) else None)
        if kind == 'beaver':
            f = head.front(0, round(4.4 * k))
            if f:
                for x in (-1, 0):
                    head.box((x, f[1], round(3.9 * k)), (x, f[1], round(4.3 * k)), WHITE)
        else:
            # a wide flat duck bill and no ears showing
            ears = c.part('ears')
            ears.v.clear()
            bw = max(1, round(1.2 * k))
            z0 = round(4.8 * k)
            y0 = min(p[1] for p in head.v) + 1
            head.box((-bw, y0 - max(2, round(1.3 * k)), z0), (bw - 1, y0, z0 + max(1, round(0.5 * k))), accent)
            for x in (-1, 0):
                head.put((x, y0 - max(2, round(1.3 * k)) + 1, z0 + max(1, round(0.5 * k))), _dark(accent, 0.4))
    else:
        raise ValueError(f'shore: unknown kind {kind}')
    return c


BUILDERS = {
    'critter': lambda c, H, cols, opts: critter(c, H, opts['kind'], cols['col'], cols.get('accent'), cols.get('wing')),
    'shore': lambda c, H, cols, opts: shore(c, H, opts['kind'], cols['col'], cols.get('accent'), cols.get('belly')),
}
