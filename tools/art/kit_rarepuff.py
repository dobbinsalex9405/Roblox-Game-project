"""Rare puff kinds for kit_puff's `puff` plan (see kit_puff.add_kind): moss,
candle, snowball, spark, bramble, pompom and ghost. Each is a little round
critter with one Rare extra that glows: a moss ball's flower, a candle's
flame, a snowball's frost, a spark's lightning tuft, a bramble's berry eyes,
a pom-pom's rainbow, a ghost's soft shine.

Same art frame and scale as kit_puff (x right, y back, front is -y, z up,
k = H / 10)."""
import math

from voxkit import hexc
import kit_puff
from kit_puff import dark, light, _hash

INK, WHITE = hexc('#1B1B2F'), hexc('#FFFFFF')


def _top(body, head):
    return max(p[2] for p in list(body.v) + list(head.v))


def _surface(part):
    vs = part.v
    return [p for p in vs if any(n not in vs for n in (
        (p[0] + 1, p[1], p[2]), (p[0] - 1, p[1], p[2]), (p[0], p[1] + 1, p[2]),
        (p[0], p[1] - 1, p[2]), (p[0], p[1], p[2] + 1)))]


def _moss(c, H, k, body, head, cols, opts):
    """A moss ball: tufts of two greens all over, a tiny flower on top with a
    glowing centre, and glowing green toes (it leaves green footprints)."""
    col = cols['col']
    tone = cols.get('accent') or light(col, 0.2)
    for part in (body, head):
        part.paint(lambda p, cc, g: (tone, False) if _hash(p[0] // 2, p[1] // 2, p[2] // 2, 3) % 3 == 0 else (dark(col, 0.12), False) if _hash(*p, 4) % 5 == 0 else None)
    fl = c.part('flower', 'static')
    top = _top(body, head)
    petal = cols.get('tuft') or hexc('#FF9EC2')
    x0, y0 = round(0.8 * k), round(0.2 * k)
    for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        fl.ell((x0 + dx * 0.5 * k + .5, y0 + dy * 0.5 * k + .5, top + 0.6), (0.45 * k, 0.45 * k, 0.3 * k + .2), petal)
    fl.put((x0, y0, top + 1), hexc('#FFE27A'), True)
    fl.put((x0, y0, top + 2), hexc('#FFE27A'), True)
    return {'big_eyes': True}


def _candle(c, H, k, body, head, cols, opts):
    """A little candle: a wax body with a melted rim and wax drips running
    down its sides, a dark wick, and a teardrop flame: orange outside, a
    yellow then white-hot core, rising to a point."""
    col = cols['col']
    drip = cols.get('accent') or light(col, 0.3)
    top = _top(body, head)
    rim = max(1, round(0.5 * k))
    for part in (body, head):
        part.paint(lambda p, cc, g: (drip, False) if p[2] > top - rim else None)
    # wax drips: short runs down the outside from the rim, a voxel proud
    dr = c.part('drips', 'static')
    allv = set(body.v) | set(head.v)
    for n, ang in enumerate((25, 100, 160, 230, 300)):
        a = math.radians(ang)
        length = (2, 4, 3, 5, 3)[n] * max(1, round(0.5 * k))
        for i in range(length):
            z = top - rim - i + 1
            ring = [p for p in allv if p[2] == z]
            if not ring:
                break
            far = max(ring, key=lambda p: (p[0] + .5) * math.cos(a) + (p[1] + .5) * math.sin(a))
            q = (far[0] + (1 if math.cos(a) > 0.5 else -1 if math.cos(a) < -0.5 else 0),
                 far[1] + (1 if math.sin(a) > 0.5 else -1 if math.sin(a) < -0.5 else 0), z)
            if q not in allv:
                dr.put(q, light(drip, 0.4))
    flame = c.part('flame', 'static')
    wick = dark(col, 0.6)
    flame.put((0, 0, top + 1), wick)
    flame.put((-1, 0, top + 1), wick)
    outer = cols.get('tuft') or hexc('#FF7A1A')
    mid, core = hexc('#FFA820'), hexc('#FFF2B0')
    # the teardrop, base up: each row's width (an even number, centred) and
    # its colours, outer to core; a round belly, then narrowing to a point
    rows = [(2, mid), (4, core), (6, core), (6, mid), (4, mid), (4, outer), (2, outer), (2, outer)]
    rows = [r for r in rows for _ in range(max(1, round(k / 1.6)))]
    for i, (D, inner) in enumerate(rows):
        z = top + 2 + i
        h = D // 2
        for x in range(-h, h):
            for y in range(-h, h):
                if D >= 4 and abs(x + .5) + abs(y + .5) > h + (0.1 if D == 4 else 1.1):
                    continue  # round the corners off
                edge = abs(x + .5) > h - 1 or abs(y + .5) > h - 1
                flame.put((x, y, z), outer if (edge and D >= 4) else inner, True)
    return {'shine': True}


def _snowball(c, H, k, body, head, cols, opts):
    """A snowball: a carrot nose, pebble (coal) eyes, glinting frost on top."""
    col = cols['col']
    frost = cols.get('accent') or hexc('#BDEBFF')
    for p in _surface(head) + _surface(body):
        if p[2] > 0.55 * max(q[2] for q in body.v) and _hash(*p, 9) % 8 == 0:
            (head if p in head.v else body).v[p] = (frost, True)
    nose = c.part('nose', 'static')
    zc = sum(p[2] for p in head.v) / len(head.v)
    fy = min(p[1] for p in head.v if abs(p[2] - zc) < 1.5)
    carrot = cols.get('tuft') or hexc('#FF8A1A')
    n = round(1.4 * k)
    for i in range(n):
        r = 0.45 * k * (1 - i / (n + 1)) + .3
        nose.ell((0, fy - i + .5, zc - 0.2 * k), (r, .6, r), carrot)
    del col
    return {'face_z': 0.35}


def _spark(c, H, k, body, head, cols, opts):
    """A spark: a yellow ball with a zig-zag lightning-bolt tuft that glows,
    and little glowing static flecks."""
    col = cols['col']
    bolt = cols.get('tuft') or hexc('#FFF27A')
    top = _top(body, head)
    tuft = c.part('bolt', 'static')
    x, z = 0.0, top + 1
    for i, (dx, dz) in enumerate(((0.6, 1.0), (-0.9, 0.5), (0.8, 1.0), (-0.5, 0.6))):
        a = (x, 0.2 * k, z)
        x, z = x + dx * k, z + dz * k
        kit_puff_line(tuft, a, (x, 0.2 * k, z), bolt, r=(0.42 - 0.06 * i) * k)
    for p in list(tuft.v):
        tuft.v[p] = (bolt, True)
    flick = cols.get('accent') or hexc('#7FDBFF')
    for p in _surface(body):
        if _hash(*p, 13) % 17 == 0 and p[2] > 1.4 * k:
            body.v[p] = (flick, True)
    del col
    return {'big_eyes': True}


def kit_puff_line(part, a, b, col, r):
    n = max(1, int(math.ceil(max(abs(b[i] - a[i]) for i in range(3)) * 2)))
    for i in range(n + 1):
        t = i / n
        p = tuple(a[j] + (b[j] - a[j]) * t for j in range(3))
        part.ell(p, (max(r, .6),) * 3, col)


def _bramble(c, H, k, body, head, cols, opts):
    """A ball of brambles: tangled dark stems with thorns poking out, a leaf
    on top (its berry eyes are kit_wild's `berryeyes` accessory)."""
    col = cols['col']
    stem = cols.get('accent') or dark(col, 0.3)
    for part in (body, head):
        part.paint(lambda p, cc, g: (stem, False) if (p[0] + 2 * p[1] + p[2]) % 4 == 0 or (2 * p[0] - p[1] + p[2]) % 5 == 0 else None)
    thorns = c.part('thorns', 'static')
    for part in (body, head):
        for p in _surface(part):
            if _hash(*p, 21) % 11 == 0 and p[2] > 1.2 * k:
                d = (1 if p[0] >= 0 else -1, 0, 1 if p[2] > 3 * k else 0)
                n = (p[0] + d[0], p[1] + d[1], p[2] + d[2])
                if n not in part.v:
                    thorns.put(n, light(stem, 0.4))
    leaf = c.part('leaf', 'static')
    top = _top(body, head)
    lc = cols.get('tuft') or hexc('#4FA84A')
    leaf.ell((0.7 * k, 0.3 * k, top + 0.5), (0.9 * k, 0.45 * k, 0.3 * k + .2), lc)
    return {'big_eyes': True}


def _pompom(c, H, k, body, head, cols, opts):
    """A rainbow pom-pom: fluffy yarn in rainbow bands round the ball, tufts
    standing out, the top band glowing softly."""
    bands = [hexc('#FF5E7A'), hexc('#FF9F40'), hexc('#FFD43B'), hexc('#6CD66A'), hexc('#4AA8FF'), hexc('#A77BFF')]
    top = _top(body, head)
    step = max(1, (top + 1) / len(bands))
    fur = c.part('fur', 'static')
    ally = [p[1] for p in list(body.v) + list(head.v)]
    yfront = min(ally) + 0.45 * (max(ally) - min(ally))  # the face's half stays smooth
    for part in (body, head):
        part.paint(lambda p, cc, g: (bands[min(len(bands) - 1, int((top - p[2]) / step))], False))
        vs = set(part.v)
        for p in list(part.v):
            if _hash(*p, 33) % 100 < 20 and 1.2 * k < p[2] < top - 1 and p[1] > yfront:
                for n in ((p[0] + 1, p[1], p[2]), (p[0] - 1, p[1], p[2]), (p[0], p[1] + 1, p[2])):
                    if n not in vs:
                        fur.put(n, part.v[p][0])
                        break
    for p in list(fur.v):
        if p in body.v or p in head.v:
            del fur.v[p]
    for part in (body, head):  # the very top glows softly
        part.paint(lambda p, cc, g: (cc, True) if p[2] >= top else None)
    return {'big_eyes': True}


def _ghost(c, H, k, body, head, cols, opts):
    """A little sheet ghost: a domed sheet whose hem ripples down round its
    feet, rosy blushing cheeks, and a soft glow on the crown."""
    col = cols['col']
    sheet = c.part('sheet', 'static')
    zs = [p[2] for p in body.v]
    lo = min(zs)
    xs = [p[0] for p in body.v]
    R = (max(xs) - min(xs) + 1) / 2
    cy = sum(p[1] for p in body.v) / len(body.v)
    for z in range(0, lo + round(0.8 * k)):
        for a in range(48):
            ang = a / 48 * 2 * math.pi
            r = R * (0.92 + 0.08 * math.sin(ang * 6))
            if z < round(0.4 * k) and math.sin(ang * 6 + 1.0) < 0:
                continue  # the rippled hem
            sheet.put((math.floor(math.cos(ang) * r), math.floor(cy + math.sin(ang) * r), z), col)
    top = _top(body, head)
    glow = cols.get('accent') or hexc('#DDF3FF')
    for part in (body, head):
        part.paint(lambda p, cc, g: (glow, True) if p[2] >= top - max(1, round(0.4 * k)) else None)
    return {'big_eyes': True, 'face_z': 0.1}


for _name, _fn, _gait in (('moss', _moss, 'hop'), ('candle', _candle, 'hop'), ('snowball', _snowball, 'hop'),
                          ('spark', _spark, 'hop'), ('bramble', _bramble, 'hop'), ('pompom', _pompom, 'hop'),
                          ('ghost', _ghost, 'hover')):
    kit_puff.add_kind(_name, _fn, _gait)

kit_puff.SHAPES.update({
    'moss': (3.0, 2.9, 2.8),
    'candle': (2.3, 2.3, 3.2),
    'snowball': (3.0, 3.0, 3.0),
    'spark': (2.9, 2.8, 2.8),
    'bramble': (3.1, 3.0, 2.9),
    'pompom': (3.1, 3.0, 3.1),
    'ghost': (2.6, 2.5, 3.2),  # rule k: pillowed without its glow, it fits the 15k Rare budget
})
