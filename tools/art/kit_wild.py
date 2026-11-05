"""Plans and accessories for the Rare batch (see variants.py for how kit
modules plug in):

- **octopus** (kinds octopus, sock, duck): a round mantle with a face, eight
  arms that are its legs (leg1L..leg4R, hinged under the mantle, so they
  sway as it drifts). A sock octopus has knitted stripy arms; a duck one
  has a duck's head on top. Colours: col, accent, belly.
- **jelly** (kind moon): a domed bell with four glowing rings, a frilled rim
  and four trailing tentacles that are its legs. Colours: col, accent.
- critter kind **scorpion** (added to kit_pond's critter): a low segmented
  body on eight legs, two pincers and a tail curled over its back with a
  glowing stinger.

Accessories here are the Rare batch's look pieces (ruff, neck, nose horn,
hump, antlers, witch hat, wind-up key, crystals, ...). Each is fn(c, H, col,
col2) like kit.accessory, in the same art frame (x right, y back, front is
-y, z up) and scale (k = H / 10), so it fits the in-game boxes and the finer
Blender build alike. Rares should read a step more special than Commons, so
most of them carry a small glowing (emissive) piece of their own."""
import math

from voxkit import hexc
import kit
import kit_pond
import rig

INK, WHITE = hexc('#1B1B2F'), hexc('#FFFFFF')
_dark, _mix, line, face = kit_pond._dark, kit_pond._mix, kit_pond.line, kit_pond.face


def _light(col, t=0.35):
    return _mix(col, WHITE, t)


def _leg(c, sx, i, n, hip):
    return rig.leg_part(c, 'L' if sx < 0 else 'R', i, n, hip)


def _mirror(part, pred=None):
    """Copies the right half (x >= 0) onto the left, so a part drawn with
    rounding stays exactly symmetric."""
    right = {p: v for p, v in part.v.items() if p[0] >= 0 and (pred is None or pred(p))}
    for (x, y, z), v in right.items():
        part.v[(-x - 1, y, z)] = v


# ------------------------------------------------------------------ octopus

def octopus(c, H, kind, col, accent=None, belly=None):
    k = H / 10.0
    accent = accent or _light(col, 0.45)
    belly = belly or _light(col, 0.3)
    fine = getattr(c, 'fine', False)
    body = c.part('body')
    duck = kind == 'duck'
    # the mantle: a round dome, a little taller than wide, on a skirt the
    # arms grow from; a duck octopus has a small round core instead
    if duck:
        body.ell((0, 0.4 * k, 3.4 * k), (2.0 * k, 2.0 * k, 1.7 * k), col)
    else:
        # the mantle is the head (it carries the face); the body is the
        # skirt the arms hang from
        mantle = c.part('head', 'static', (0, 0.6 * k, 4.0 * k))
        mantle.ell((0, 0.6 * k, 5.2 * k), (2.3 * k, 2.3 * k, 2.6 * k), col)
        body.ell((0, 0.4 * k, 3.0 * k), (2.2 * k, 2.2 * k, 1.2 * k), col)
        # freckles on top of the mantle, glowing a little at Rare and up
        glowing = c.rarity not in ('Common', 'Uncommon')
        mantle.paint(lambda p, cc, g: (accent, glowing) if p[2] > 6.0 * k and kit._hash(p[0] // 2, p[1] // 2, p[2] // 2, 3) % 9 == 0 else None)
    # eight arms, four a side, from the skirt out and down to the ground,
    # the tips curling up; each is a leg part hinged at the skirt
    sock = kind == 'sock'
    for sx in (-1, 1):
        for i, ang in enumerate((25, 65, 110, 150)):
            a = math.radians(ang)
            ox, oy = math.sin(a) * sx, -math.cos(a)  # out from the centre, front is -y
            r0 = 1.4 * k
            hip = (ox * r0, 0.4 * k + oy * r0, 2.6 * k)
            leg = _leg(c, sx, i, 4, (round(hip[0]) + .5, round(hip[1]) + .5, round(hip[2]) + 1))
            pts = []
            n = 12
            for j in range(n + 1):
                t = j / n
                reach = r0 + 3.0 * k * t
                z = 2.6 * k * (1 - t) ** 1.6 + 0.4 * k
                if t > 0.8:  # the tip curls up and back in
                    reach -= (t - 0.8) * 2.0 * k
                    z += (t - 0.8) * 4.0 * k
                pts.append((ox * reach, 0.4 * k + oy * reach, z, (0.62 - 0.38 * t) * k))
            for j, (x, y, z, r) in enumerate(pts):
                if sock:
                    # knitted bands along the arm, a contrasting toe
                    stripe = (j // 3) % 2 == 1 or j >= n - 1
                    leg.ell((x, y, z), (max(r, .7), max(r, .7), max(r, .7)), accent if stripe else col)
                else:
                    leg.ell((x, y, z), (max(r, .7), max(r, .7), max(r, .7)), col)
            if not sock and fine:
                # pale suckers along the underside
                for (x, y, z, r) in pts[2:-2:2]:
                    leg.put((math.floor(x), math.floor(y), max(0, math.floor(z - r))), belly)
    if sock:
        # knitted stripes: rows around each arm in the accent colour, a
        # ribbed cuff where the arms meet the mantle
        body.paint(lambda p, cc, g: (accent, False) if (p[0] + p[1]) % 2 == 0 else None)
        c.part('head').paint(lambda p, cc, g: (_dark(col, 0.08), False) if (p[0] // 2 + p[2]) % 2 == 0 else None)
    if duck:
        head = c.part('head', 'head', (0, -0.6 * k, 5.0 * k))
        hc = belly
        head.ell((0, -0.6 * k, 6.4 * k), (2.0 * k, 1.9 * k, 1.9 * k), hc)
        bw = max(2, round(0.9 * k))
        bill = hexc('#FF9418')
        head.box((-bw, round(-3.4 * k), round(5.5 * k)), (bw - 1, round(-2.0 * k), round(5.5 * k) + max(1, round(0.5 * k))), bill)
        face(c, head, k, 6.6, x_off=0.7, size=0.55)
        # a curly glowing tuft on top
        for i in range(max(3, round(1.4 * k))):
            head.put((0 if i % 2 else -1, round(-0.6 * k) + i // 3, round(8.3 * k) + i), accent, True)
    else:
        # the face on the front of the mantle
        mantle = c.part('head')
        face(c, mantle, k, 4.6, x_off=0.75, size=0.6, cheek_z=3.9)
        # a little 'o' mouth
        m = mantle.front(0, round(3.6 * k)) or mantle.front(-1, round(3.6 * k))
        if m:
            mantle.put(m, _dark(col, 0.5))
    return c


# --------------------------------------------------------------------- jelly

def jelly(c, H, kind, col, accent=None):
    k = H / 10.0
    accent = accent or hexc('#FF8FC8')
    rim = 4.6 * k
    # the body is the bell's scalloped rim (the tentacles hang from it); the
    # domed bell above is the head, which carries the face
    body = c.part('body')
    bell = c.part('head', 'static', (0, 0, rim + 1.0 * k))
    bell.ell((0, 0, rim), (3.0 * k, 3.0 * k, 3.2 * k), col, cond=lambda x, y, z: z >= round(rim))
    for a in range(16):
        ang = a / 16 * 2 * math.pi
        body.ell((math.cos(ang) * 2.8 * k, math.sin(ang) * 2.8 * k, rim - 0.2 * k), (0.55 * k, 0.55 * k, 0.45 * k), _light(col, 0.3))
    # four glowing rings on top, the moon jelly's mark
    for q in range(4):
        ang = q * math.pi / 2 + math.pi / 4
        cx, cy = math.cos(ang) * 1.25 * k, math.sin(ang) * 1.25 * k
        bell.paint(lambda p, cc, g, cx=cx, cy=cy: (accent, True) if p[2] > rim + 0.9 * k and 0.42 * k < math.hypot(p[0] + .5 - cx, p[1] + .5 - cy) < 0.8 * k else None)
    # a soft glow round the rim
    body.paint(lambda p, cc, g: (_light(accent, 0.5), True) if p[2] <= round(rim) and (p[0] + p[1]) % 3 == 0 else None)
    # the face on the front of the bell
    face(c, bell, k, (rim / k) + 1.0, x_off=0.8, size=0.6, cheek_z=(rim / k) + 0.4)
    # frilly oral arms under the bell (static) and four long tentacles, one
    # `tail` part hinged under the bell so they sweep as it swims
    frills = c.part('frills', 'static')
    for sx in (-1, 1):
        for sy in (-1, 1):
            for i in range(round(2.6 * k)):
                z = rim - 1 - i
                wob = math.sin(i / max(1, k) * 1.6) * 0.5 * k
                frills.ell((sx * (0.6 * k + wob), sy * 0.6 * k, z), (0.45 * k, 0.45 * k, 0.6), _light(accent, 0.35))
    tent = c.part('tail', 'tail', (0, 0, round(rim)))
    for sx in (-1, 1):
        for i, sy in enumerate((-1, 1)):
            hip = (sx * 2.0 * k, sy * 1.4 * k, rim)
            leg = tent
            n = max(4, round(rim))
            for j in range(n):
                z = rim - 1 - j
                if z < round(0.3 * k):
                    break
                wob = math.sin(j / max(1, k) * 1.3 + i) * 0.5 * k
                leg.ell((hip[0] + sx * wob, hip[1], z), (0.3 * k + .2, 0.3 * k + .2, 0.6), _light(col, 0.15))
    return c


# ------------------------------------------------------------ scorpion

def scorpion(c, H, k, col, accent, wing, body, head):
    """A low segmented scorpion on eight legs, pincers forward, its tail
    curled over its back to a glowing stinger."""
    dark = _dark(col, 0.3)
    # the body: a flat oval of plates, darker seams between them
    body.ell((0, 0.4 * k, 1.8 * k), (1.7 * k, 2.4 * k, 0.9 * k), col, cond=lambda x, y, z: z >= round(1.0 * k))
    band = max(1, round(0.7 * k))
    body.paint(lambda p, cc, g: (dark, False) if (p[1] // band) % 2 == 0 and p[2] >= round(2.2 * k) else None)
    head.pivot = (0, -1.8 * k, 1.9 * k)
    head.ell((0, -2.0 * k, 1.9 * k), (1.3 * k, 1.0 * k, 0.8 * k), col)
    face(c, head, k, 2.0, x_off=0.35, size=0.4, cheek_z=1.5)
    # eight legs, four a side, bent like a spider's
    kit_pond.bent_legs(body, k, (-1.0, -0.2, 0.6, 1.4), dark, hip=(1.2, 1.6), knee=(2.3, 2.6), foot=2.8, r=0.22, splay=0.8, c=c)
    # pincers: an arm forward from each side, a big claw at the end
    claws = c.part('claws', 'static')
    for sx in (-1, 1):
        sh = (sx * 1.2 * k, -1.6 * k, 1.8 * k)
        el = (sx * 2.2 * k, -2.6 * k, 1.9 * k)
        hand = (sx * 1.6 * k, -3.8 * k, 1.9 * k)
        line(claws, sh, el, col, r=0.32 * k)
        line(claws, el, hand, col, r=0.4 * k)
        claws.ell((hand[0], hand[1] - 0.4 * k, hand[2]), (0.75 * k, 0.9 * k, 0.6 * k), col)
        for d in (-1, 1):  # the two fingers, open a little
            line(claws, (hand[0] + d * 0.3 * k, hand[1] - 1.0 * k, hand[2]), (hand[0] + d * 0.45 * k, hand[1] - 1.9 * k, hand[2]), accent, r=0.25 * k)
    # the tail: segments up from the rear and curling forward over the back
    tail = c.part('tail', 'tail', (0, 2.6 * k, 2.0 * k))
    pts = []
    n = 9
    for i in range(n):
        t = i / (n - 1)
        ang = math.pi * 0.05 + t * math.pi * 1.05
        pts.append((0, 2.6 * k + math.sin(ang) * 1.8 * k * (1.0 - 0.15 * t) + 0.3 * k, 2.0 * k + (1 - math.cos(ang)) * 2.0 * k, (0.7 - 0.25 * t) * k))
    for i, (x, y, z, r) in enumerate(pts):
        tail.ell((x, y, z), (r, r, r), col if i % 2 == 0 else dark)
    x, y, z, r = pts[-1]
    tail.ell((0, y - 0.6 * k, z - 0.2 * k), (0.5 * k, 0.6 * k, 0.5 * k), accent, True)
    tail.put((0, round(y - 1.3 * k), round(z - 0.7 * k)), accent, True)
    tail.put((-1, round(y - 1.3 * k), round(z - 0.7 * k)), accent, True)


kit_pond.add_critter_kind('scorpion', scorpion)


# --------------------------------------------------------------- helpers

def _head(c):
    return kit.head_of(c)


def _front_y(part, z=None):
    ys = [p[1] for p in part.v if z is None or p[2] == z]
    return min(ys) if ys else 0


def _bounds(part):
    vs = list(part.v)
    return ([min(v[i] for v in vs) for i in range(3)], [max(v[i] for v in vs) for i in range(3)])


def _top_at(c, x, y, names=('body',)):
    zs = [p[2] for n in names for p in (kit._find(c, n).v if kit._find(c, n) else {}) if p[0] == x and p[1] == y]
    return max(zs) if zs else None


def _shift(part, dx=0, dy=0, dz=0):
    part.v = {(x + dx, y + dy, z + dz): v for (x, y, z), v in part.v.items()}
    px, py, pz = part.pivot
    part.pivot = (px + dx, py + dy, pz + dz)


# ------------------------------------------------------------ accessories

def ruff(c, H, col, col2=None):
    """A lion's mane: a thick fluffy ring round the back of the head and the
    neck, its outer tufts tipped in col2."""
    k = H / 10.0
    head = _head(c)
    (lo, hi) = _bounds(head)
    cx, cy, cz = 0, (lo[1] + hi[1] + 1) / 2, (lo[2] + hi[2] + 1) / 2
    rx, rz = (hi[0] - lo[0] + 1) / 2, (hi[2] - lo[2] + 1) / 2
    mane = c.part('mane', 'static', (0, cy, cz))
    tip = col2 or _light(col, 0.3)
    hv = set(head.v) | set(c.part('eyes').v) | set(c.part('ears').v if kit._find(c, 'ears') else {})
    for a in range(32):
        ang = a / 32 * 2 * math.pi
        px, pz = cx + math.cos(ang) * rx * 1.05, cz + math.sin(ang) * rz * 1.0
        mane.ell((px, cy + 0.5 * k, pz), (0.55 * k, 0.6 * k, 0.55 * k), col,
                 cond=lambda x, y, z: (x, y, z) not in hv and z >= 1)
    # the outer tufts a lighter shade
    far = {}
    for (x, y, z) in mane.v:
        d = math.hypot(x + .5 - cx, (z + .5 - cz) * rx / max(rz, 1))
        far[(x, y, z)] = d
    edge = max(far.values()) - 0.35 * k if far else 0
    mane.paint(lambda p, cc, g: (tip, False) if far.get(p, 0) >= edge and kit._hash(*p, 37) % 2 == 0 else None)
    _mirror(mane)


def neck(c, H, col, col2=None):
    """A long neck: lifts the head (and everything on it) and fills a neck
    from the shoulders up to it, patched in col2 if given (a giraffe)."""
    k = H / 10.0
    lift = round(3.6 * k)
    fwd = round(1.0 * k)
    head = _head(c)
    hp = set(kit.HEAD_PARTS)
    for p in c.parts:
        if p.name in hp or p.name == 'eyes':
            _shift(p, dy=-fwd, dz=lift)
    body = kit._find(c, 'body')
    (blo, bhi) = _bounds(body)
    (hlo, hhi) = _bounds(head)
    base = (0, blo[1] + 1.4 * k, bhi[2] - 0.8 * k)
    top = (0, (hlo[1] + hhi[1]) / 2 + 0.6 * k, hlo[2] + 1.2 * k)
    before = set(body.v)
    line(body, base, top, col, r=0.95 * k)
    if col2:  # patches on the new neck
        s = max(2, round(1.1 * k))
        for p in set(body.v) - before:
            h = kit._hash(p[0] // s, p[1] // s, p[2] // s, 29)
            if h % 3 == 0:
                body.v[p] = (col2, False)


def giraffepatches(c, H, col, col2=None):
    """A giraffe's coat: big brown patches (col) split by thin cream lines,
    over the body, neck, head and upper legs (only the coat colour; the
    belly and snout stay). Patches are cells round jittered seed points."""
    k = H / 10.0
    s = max(3.0, 1.25 * k)

    def seed(i, j, l):
        h = kit._hash(i, j, l, 51)
        return ((i + 0.25 + (h % 50) / 100) * s, (j + 0.25 + (h // 50 % 50) / 100) * s, (l + 0.25 + (h // 2500 % 50) / 100) * s)

    def patch(p):
        ci, cj, cl = int(math.floor(p[0] / s)), int(math.floor(p[1] / s)), int(math.floor(p[2] / s))
        ds = sorted(math.dist((p[0] + .5, p[1] + .5, p[2] + .5), seed(i, j, l))
                    for i in (ci - 1, ci, ci + 1) for j in (cj - 1, cj, cj + 1) for l in (cl - 1, cl, cl + 1))
        return ds[1] - ds[0] > 0.15 * s

    coat = None
    body = kit._find(c, 'body')
    if body and body.v:
        from collections import Counter
        coat = Counter(v[0] for v in body.v.values()).most_common(1)[0][0]
    for part in c.parts:
        if part.name in ('body', 'head') or part.name.startswith('leg'):
            zmin = min(q[2] for q in part.v) if part.v else 0
            part.paint(lambda p, cc, g, zmin=zmin, part=part: (col, False) if cc == coat and patch(p) and
                       (not part.name.startswith('leg') or p[2] > zmin + 1.2 * k) else None)


def banana(c, H, col, col2=None):
    """A banana held up in one hand (a baby gorilla's snack), glowing softly,
    brown (col2) at the ends."""
    k = H / 10.0
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    side = [p for p in body.v if p[0] >= hi[0] - 1]
    hz = min(p[2] for p in side) if side else lo[2]
    hy = min(p[1] for p in side) if side else lo[1]
    hx = hi[0] - round(0.4 * k)
    part = c.part('banana', 'static')
    n = max(8, round(4.0 * k))
    end = col2 or hexc('#6A4A22')
    for i in range(n):
        t = i / (n - 1)
        # a crescent: up from the fist, bowing forward, the tip curling back
        y = hy - 0.2 * k - math.sin(t * math.pi) * 0.9 * k
        z = hz + 0.3 * k + t * 2.4 * k
        r = 0.22 * k + .35
        tip = t < 0.08 or t > 0.92
        part.ell((hx + .5, y, z), (r, r, r), end if tip else col, not tip)


def ossicones(c, H, col, col2=None):
    """Two giraffe horn nubs on the crown, with dark (or glowing) knobs."""
    k = H / 10.0
    y, zt = kit.crown(c)
    part = c.part('horns', 'static')
    knob = col2 or _dark(col, 0.4)
    n = max(2, round(1.0 * k))
    for sx in (-1, 1):
        x = round(sx * 0.7 * k) - (1 if sx < 0 else 0)
        for i in range(n):
            part.put((x, round(y), zt + 1 + i), col)
        kit.ball(part, (x + .5, round(y) + .5, zt + n + 0.6 * k), (0.4 * k, 0.4 * k, 0.4 * k), knob)
    _mirror(part)


def nosehorn(c, H, col, col2=None):
    """A rhino's horn: a cone up from the end of the snout, a smaller one
    behind it, the tip in col2."""
    k = H / 10.0
    head = _head(c)
    (lo, hi) = _bounds(head)
    zn = round(lo[2] + (hi[2] - lo[2]) * 0.55)  # just above the nose
    f = head.front(0, zn) or head.front(-1, zn)
    fy = f[1] if f else _front_y(head)
    zt = zn
    part = c.part('horn', 'static')
    for (dy, h, r0) in ((0.6, 2.0, 0.65), (2.0, 1.0, 0.45)):
        n = max(2, round(h * k))
        for i in range(n):
            r = r0 * k * (1 - i / (n + 0.5))
            tipc = col2 if (col2 and i >= n - max(1, round(0.4 * k))) else col
            part.ell((0, fy + dy * k - 0.4 * k - i * 0.6, zt + 0.5 + i), (max(r, .5), max(r, .5), .5), tipc)
    _mirror(part)


def hump(c, H, col, col2=None):
    """A camel's single hump on the back."""
    k = H / 10.0
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    body.ell((0, (lo[1] + hi[1]) / 2 + 0.5 * k, hi[2] + 0.2 * k), (1.4 * k, 1.6 * k, 1.6 * k), col,
             cond=lambda x, y, z: z >= hi[2] - 0.6 * k)


def antlers(c, H, col, col2=None):
    """Small branching antlers (a reindeer calf's), tips glowing col2."""
    k = H / 10.0
    y, zt = kit.crown(c)
    part = c.part('antlers', 'static')
    tip = col2 or _light(col, 0.4)
    for sx in (1,):
        base = (sx * 0.9 * k, y + 0.3 * k, zt)
        top = (sx * 1.9 * k, y + 0.9 * k, zt + 2.6 * k)
        line(part, base, top, col, r=0.3 * k)
        for (t, ox, oy, oz) in ((0.35, 0.2, -0.9, 0.8), (0.7, 0.9, -0.5, 0.7)):
            b = tuple(base[i] + (top[i] - base[i]) * t for i in range(3))
            e = (b[0] + ox * k, b[1] + oy * k, b[2] + oz * k)
            line(part, b, e, col, r=0.22 * k)
            part.put(tuple(math.floor(v) for v in e), tip, bool(col2))
        part.put(tuple(math.floor(v) for v in top), tip, bool(col2))
        part.put((math.floor(top[0]), math.floor(top[1]), math.floor(top[2]) + 1), tip, bool(col2))
    _mirror(part)


def witchhat(c, H, col, col2=None):
    """A pointed witch hat with a wide brim, a bent tip and a glowing buckle."""
    k = H / 10.0
    y, zt = kit.crown(c)
    hat = c.part('hat', 'static')
    band = col2 or hexc('#B983FF')
    hat.ell((0, y, zt + 0.3 * k), (2.3 * k, 2.1 * k, 0.35 * k + .2), col)
    n = round(3.6 * k)
    for i in range(n):
        t = i / n
        r = 1.3 * k * (1 - t) + 0.25
        bend = max(0.0, t - 0.6) ** 2 * 4.0 * k
        hat.ell((0, y + bend, zt + 0.6 * k + i), (r, r, .6), col)
    hat.paint(lambda p, cc, g: (band, True) if abs(p[2] - (zt + 0.8 * k)) <= max(0, round(0.25 * k)) and cc == col and abs(p[0] + .5) <= 1.3 * k else None)
    _mirror(hat)


def windkey(c, H, col, col2=None):
    """A wind-up key in the back that turns (anim orbit: about its shaft)."""
    k = H / 10.0
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    yb = (lo[1] + hi[1]) / 2 + 0.4 * k
    ztop = _top_at(c, 0, round(yb)) or hi[2]
    key = c.part('key', 'orbit', (0, round(yb) + .5, ztop + 1))
    sh = max(1, round(0.25 * k))
    key.box((-sh, round(yb) - sh + 1, ztop - 1), (sh - 1, round(yb) + sh - 1 + 1, ztop + round(1.2 * k)), col)
    zb = ztop + round(1.6 * k)
    for sx in (-1, 1):  # the two loops of the bow, in the y = yb plane
        kit.ball(key, (sx * 0.9 * k, round(yb) + .5, zb), (0.8 * k, 0.3 * k + .3, 0.65 * k), col)
    key.ell((0, round(yb) + .5, zb), (0.4 * k, 0.4 * k, 0.4 * k), col2 or col, bool(col2))


def crystals(c, H, col, col2=None):
    """A cluster of crystal spikes along the back, glowing cores in col2."""
    k = H / 10.0
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    part = c.part('crystals', 'static')
    core = col2 or _light(col, 0.5)
    spots = ((0.0, 0.2, 1.9, 0), (0.9, -0.6, 1.3, 15), (0.8, 1.0, 1.5, 10), (0.0, 1.8, 1.1, -10), (0.5, -1.4, 1.0, 20))
    yc = (lo[1] + hi[1]) / 2
    for (ox, oy, h, lean) in spots:
        for sx in ((1,) if ox == 0 else (-1, 1)):
            x, y = sx * ox * k, yc + oy * k
            z0 = _top_at(c, math.floor(x), math.floor(y)) or hi[2]
            n = max(3, round(h * 1.5 * k))
            for i in range(n):
                r = 0.65 * k * (1 - i / (n + 1)) + 0.3
                lx = sx * math.sin(math.radians(lean)) * i
                part.ell((x + lx, y, z0 + i), (r, r, .6), core if r < 0.4 * k else col, r < 0.4 * k)


def raincloud(c, H, col, col2=None):
    """A little raincloud above the creature, glowing raindrops falling."""
    k = H / 10.0
    (lo, hi) = c.bounds()
    yc = (lo[1] + hi[1]) / 2 + 0.6 * k
    zc = hi[2] + 1.6 * k
    cloud = c.part('cloud', 'static')
    for (x, y, r) in ((0, 0, 1.0), (-1.0, 0.2, 0.75), (1.0, -0.1, 0.8), (0.4, 0.7, 0.7), (-0.5, -0.6, 0.7)):
        cloud.ell((x * k, yc + y * k, zc), (r * k, r * k, r * 0.8 * k), col)
    drop = col2 or hexc('#7FD4FF')
    for (x, y) in ((-0.6, 0.0), (0.5, 0.3), (0.0, -0.5)):
        for i in range(max(2, round(0.9 * k))):
            if i % 2 == 0:
                cloud.put((math.floor(x * k), math.floor(yc + y * k), math.floor(zc - 0.8 * k) - 1 - i), drop, True)
    # a thin wisp down to the shell so the cloud is part of the creature
    top = _top_at(c, 0, math.floor(yc), names=[p.name for p in c.parts if p.name != 'cloud']) or hi[2]
    for z in range(top + 1, math.floor(zc - 0.6 * k)):
        cloud.put((0, math.floor(yc + 0.9 * k), z), _light(col, 0.2))
        cloud.put((-1, math.floor(yc + 0.9 * k), z), _light(col, 0.2))


def lavacracks(c, H, col, col2=None):
    """Glowing lava cracks across the shell (or body)."""
    k = H / 10.0
    part = kit._find(c, 'shell') or kit._find(c, 'body')
    w = max(1, round(0.35 * k))
    part.paint(lambda p, cc, g: (col, True) if (abs((p[1] * 3 + p[2] * 2) % max(4, round(2.6 * k))) < w
                                                 or abs((p[1] * 2 - p[2] * 3 + p[0]) % max(5, round(3.4 * k))) < w) else None)


def glowstripe(c, H, col, col2=None):
    """One bright glowing stripe down the middle of the head and back
    (a badger's white stripe, smouldering)."""
    k = H / 10.0
    w = max(1, round(0.45 * k))
    for name in ('body', 'head'):
        part = kit._find(c, name)
        if not part:
            continue
        tops = {}
        for (x, y, z) in part.v:
            tops[(x, y)] = max(tops.get((x, y), -1), z)
        part.paint(lambda p, cc, g: (col, True) if abs(p[0] + .5) <= w and p[2] >= tops[(p[0], p[1])] - max(1, round(0.5 * k)) else None)


def glowspots(c, H, col, col2=None):
    """Round glowing spots scattered over the body and head."""
    k = H / 10.0
    s = max(2, round(1.2 * k))
    for name in ('body', 'head'):
        part = kit._find(c, name)
        if not part:
            continue

        def spot(p, cc, g, s=s, name=name):
            cell = (p[0] // s, p[1] // s, p[2] // s)
            h = kit._hash(*cell, 11 if name == 'body' else 13)
            if h % 100 >= 30 or p[2] < 1.0 * k:
                return None
            cxyz = (cell[0] * s + s * 0.5, cell[1] * s + s * 0.5, cell[2] * s + s * 0.5)
            return (col, True) if math.dist((p[0] + .5, p[1] + .5, p[2] + .5), cxyz) < s * 0.45 else None
        part.paint(spot)


def sparks(c, H, col, col2=None):
    """Zig-zag sparks standing up along the spine, glowing."""
    k = H / 10.0
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    part = c.part('sparks', 'static')
    step = max(2, round(0.9 * k))
    for i, y in enumerate(range(lo[1] + round(0.8 * k), hi[1] - round(0.4 * k), step)):
        z0 = _top_at(c, 0, y)
        if z0 is None:
            continue
        n = max(2, round((0.9 if i % 2 else 1.3) * k))
        for j in range(n):
            x = 0 if (j // max(1, round(0.4 * k))) % 2 == 0 else (1 if i % 2 else -1)
            part.put((x, y, z0 + 1 + j), col, True)
            part.put((x - 1, y, z0 + 1 + j), col, True)


def whiskers(c, H, col, col2=None):
    """Three whiskers a side from the muzzle, frosty and glowing."""
    k = H / 10.0
    head = _head(c)
    fy = _front_y(head)
    (lo, hi) = _bounds(head)
    z0 = lo[2] + (hi[2] - lo[2]) * 0.3
    part = c.part('whiskers', 'static')
    for sx in (1,):
        for j, dz in enumerate((-0.35, 0.0, 0.35)):
            a = (sx * 0.9 * k, fy + 0.6 * k, z0 + dz * k)
            b = (sx * 2.9 * k, fy + 0.9 * k, z0 + dz * k * 2.2)
            line(part, a, b, col, glow=True)
    _mirror(part)


def barbels(c, H, col, col2=None):
    """A koi's two barbels: thin feelers (one voxel) from the corners of the
    mouth, out and drooping, about four voxels long, glowing softly."""
    k = H / 10.0
    head = _head(c)
    (lo, hi) = _bounds(head)
    zm = round(lo[2] + (hi[2] - lo[2]) * 0.35)
    row = [p for p in head.v if p[2] == zm]
    fy = min(p[1] for p in row) if row else lo[1]
    part = c.part('barbels', 'static')
    n = max(4, round(1.4 * k))
    x0 = max(1, round(0.5 * k))
    for i in range(n):
        part.put((x0 + i // 2, fy + 1 - (i + 1) // 2 - (1 if i == 0 else 0), zm - i // 2), col, True)
    _mirror(part)


def tailtip(c, H, col, col2=None):
    """Colours the end third of the tail (an ermine's black tip)."""
    tl = kit._find(c, 'tail')
    if not tl or not tl.v:
        return
    ys = [p[1] for p in tl.v]
    cut = min(ys) + (max(ys) - min(ys)) * 0.6
    tl.paint(lambda p, cc, g: (col, False) if p[1] >= cut else None)


def mohawk(c, H, col, col2=None):
    """An upright brush mane from the forehead down the neck (a zebra's),
    striped col and col2."""
    k = H / 10.0
    head = _head(c)
    body = kit._find(c, 'body')
    part = c.part('mane', 'static')
    (hlo, hhi) = _bounds(head)
    ys = range(hlo[1] + round(1.0 * k), round(1.0 * k))
    for y in ys:
        z0 = _top_at(c, 0, y, names=('head', 'body'))
        if z0 is None:
            continue
        cc = col if (y // max(1, round(0.5 * k))) % 2 == 0 else (col2 or col)
        for j in range(max(2, round(0.9 * k))):
            part.put((0, y, z0 + 1 + j), cc)
            part.put((-1, y, z0 + 1 + j), cc)
    del body


def zebra(c, H, col, col2=None):
    """Bold stripes all round the body, legs and head (a zebra's)."""
    k = H / 10.0
    w = max(1, round(0.55 * k))
    for name in ('body', 'head', 'tail'):
        part = kit._find(c, name)
        if part and name == 'head':
            # forehead and cheeks in bands across, the muzzle left dark
            (lo, hi) = _bounds(part)
            part.paint(lambda p, cc, g, lo=lo, hi=hi: (col, False) if not g and (p[2] // w) % 2 == 0 and p[2] > lo[2] + (hi[2] - lo[2]) * 0.45 else None)
        elif part:
            part.paint(lambda p, cc, g: (col, False) if not g and ((p[1] + p[2] // 2) // w) % 2 == 0 and abs(p[0] + .5) > 0.35 * k else None)


def tigerstripes(c, H, col, col2=None):
    """Thin tiger stripes: bands down the sides of the body and legs,
    three short ones on the forehead, rings on the tail. The belly keeps its
    colour (col2, if given, is left unpainted)."""
    k = H / 10.0
    period = max(3, round(1.3 * k))
    w = max(1, round(0.35 * k))
    body = kit._find(c, 'body')
    if body:
        body.paint(lambda p, cc, g: (col, False) if not g and cc != col2 and (p[1] + p[2] // 2) % period < w and abs(p[0] + .5) > 0.5 * k else None)
    head = kit._find(c, 'head')
    if head:
        (lo, hi) = _bounds(head)
        zf = lo[2] + (hi[2] - lo[2]) * 0.62
        head.paint(lambda p, cc, g: (col, False) if not g and p[2] >= zf and abs(p[0] + .5) in (0.5, 1.5 + round(0.6 * k), ) and p[1] < (lo[1] + hi[1]) / 2 else None)
        head.paint(lambda p, cc, g: (col, False) if not g and p[2] >= zf and p[1] < (lo[1] + hi[1]) / 2 and (abs(p[0] + .5) < 0.6 or abs(abs(p[0] + .5) - 1.2 * k) < 0.6) and (p[2] - round(zf)) % 2 == 0 else None)
        head.paint(lambda p, cc, g: (col, False) if not g and abs(p[0] + .5) > (hi[0] - lo[0]) / 2 - 0.4 * k and p[2] % period < w else None)
    tl = kit._find(c, 'tail')
    if tl:
        tl.paint(lambda p, cc, g: (col, False) if p[1] % period < w + 1 else None)


def leggings(c, H, col, col2=None):
    """Stripes across the lower legs (an okapi's, a sand cat's)."""
    k = H / 10.0
    body = kit._find(c, 'body')
    w = max(1, round(0.4 * k))
    body.paint(lambda p, cc, g: (col, False) if p[2] < 1.6 * k and (p[2] // w) % 2 == 0 else None)


def tearlines(c, H, col, col2=None):
    """A cheetah's dark tear lines from the eyes down past the muzzle."""
    k = H / 10.0
    head = _head(c)
    eyes = kit._find(c, 'eyes')
    if not eyes or not eyes.v:
        return
    for sx in (1,):
        ex = [p for p in eyes.v if (p[0] >= 0)]
        if not ex:
            continue
        x0 = min(p[0] for p in ex)
        z0 = min(p[2] for p in ex)
        for i in range(max(2, round(1.6 * k))):
            x = x0 + i // 3
            f = head.front(x, z0 - 1 - i)
            if f:
                head.put(f, col)
                head.put((-f[0] - 1, f[1], f[2]), col)


def twinkle(c, H, col, col2=None):
    """A glowing star-shine in each eye: the Rare sparkle."""
    eyes = kit._find(c, 'eyes')
    if not eyes or not eyes.v:
        return
    for sx in (-1, 1):
        side = [p for p in eyes.v if (p[0] >= 0) == (sx > 0)]
        if not side:
            continue
        zt = max(p[2] for p in side)
        top = [p for p in side if p[2] == zt]
        p = max(top, key=lambda q: q[0]) if sx > 0 else min(top, key=lambda q: q[0])
        eyes.v[p] = (col, True)


def eartips(c, H, col, col2=None):
    """The tips of the ears glow softly in col: a Rare's shine."""
    k = H / 10.0
    ears = kit._find(c, 'ears')
    if not ears or not ears.v:
        return
    top = max(p[2] for p in ears.v)
    lo = min(p[2] for p in ears.v)
    cut = top - max(1, round(min(0.5 * k, (top - lo) * 0.3)))
    ears.paint(lambda p, cc, g: (col, True) if p[2] > cut else None)


def tailglow(c, H, col, col2=None):
    """The end of the tail glows softly in col."""
    tl = kit._find(c, 'tail')
    if not tl or not tl.v:
        return
    ys = [p[1] for p in tl.v]
    cut = min(ys) + (max(ys) - min(ys)) * 0.75
    tl.paint(lambda p, cc, g: (col, True) if p[1] >= cut else None)


def berryeyes(c, H, col, col2=None):
    """Big glossy berry eyes in col, each with a glinting highlight."""
    eyes = kit._find(c, 'eyes')
    head = _head(c)
    if not eyes or not eyes.v:
        return
    for (x, y, z) in list(eyes.v):
        eyes.v[(x, y, z)] = (col, False)
        for n in ((x, y, z + 1), (x + (1 if x >= 0 else -1), y, z), (x, y, z - 1)):
            if n in head.v:
                head.v[n] = (_dark(col, 0.15), False)
    for sx in (-1, 1):
        side = [p for p in eyes.v if (p[0] >= 0) == (sx > 0)]
        if side:
            top = max(side, key=lambda p: (p[2], -p[0] * sx))
            eyes.v[top] = (_light(col, 0.6), True)


def screenface(c, H, col, col2=None):
    """A robot's screen face: a dark panel over the front of the head, the
    eyes and a smile glowing on it in col2."""
    k = H / 10.0
    head = _head(c)
    eyes = kit._find(c, 'eyes')
    lit = col2 or hexc('#5CF2FF')
    (lo, hi) = _bounds(head)
    fy = _front_y(head)
    zc = (lo[2] + hi[2]) / 2
    head.paint(lambda p, cc, g: (col, False) if p[1] <= fy + max(1, round(0.5 * k)) and abs(p[2] + .5 - zc) < 1.3 * k and abs(p[0] + .5) < 1.7 * k else None)
    if eyes:
        for p in eyes.v:
            eyes.v[p] = (lit, True)
    for x in range(-round(0.7 * k), round(0.7 * k)):
        dz = 1 if x in (-round(0.7 * k), round(0.7 * k) - 1) else 0
        f = head.front(x, round(zc - 0.7 * k) + dz)
        if f:
            head.put(f, lit, True)


def antenna(c, H, col, col2=None):
    """A short antenna on the crown with a glowing bulb."""
    k = H / 10.0
    y, zt = kit.crown(c)
    part = c.part('antenna', 'static')
    n = max(2, round(1.2 * k))
    for i in range(n):
        part.put((0, round(y), zt + 1 + i), col)
    kit.ball(part, (0.5, round(y) + .5, zt + n + 0.5 * k), (0.45 * k, 0.45 * k, 0.45 * k), col2 or hexc('#FF4D5E'))
    for p in list(part.v):
        if p[2] > zt + n:
            part.v[p] = (col2 or hexc('#FF4D5E'), True)


def wraps(c, H, col, col2=None):
    """Mummy bandages: diagonal wraps over the body and head in col, with
    darker gaps, leaving one eye peeking out."""
    k = H / 10.0
    w = max(2, round(0.7 * k))
    gap = col2 or _dark(col, 0.25)
    for name in ('body', 'head', 'tail'):
        part = kit._find(c, name)
        if not part:
            continue
        part.paint(lambda p, cc, g: ((gap if ((p[2] + p[1] // 2 + (p[0] if name == 'head' else 0) // 3) % w) == 0 else col), False))
    eyes = kit._find(c, 'eyes')
    if eyes:  # wrap over the left eye
        for p in [p for p in eyes.v if p[0] < 0]:
            del eyes.v[p]
            _head(c).put(p, col)
    # a loose bandage end trailing from the back
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    loose = c.part('bandage', 'static')
    for i in range(max(3, round(1.8 * k))):
        loose.put((round(0.8 * k), hi[1] + 1 + i // 2, hi[2] - round(1.0 * k) - i), col)
        loose.put((round(0.8 * k) + 1, hi[1] + 1 + i // 2, hi[2] - round(1.0 * k) - i), col)


def beetleshell(c, H, col, col2=None):
    """A shiny beetle's shell over the back, split down the middle (col2)."""
    k = H / 10.0
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    shell = c.part('shell', 'static')
    yc = (lo[1] + hi[1]) / 2 + 0.3 * k
    ztop = hi[2]
    shell.ell((0, yc, ztop - 1.0 * k), ((hi[0] - lo[0] + 1) / 2 + 0.3 * k, (hi[1] - lo[1]) / 2 * 0.8, 1.7 * k), col,
              cond=lambda x, y, z: z >= ztop - 1.2 * k)
    seam = col2 or _dark(col, 0.5)
    shell.paint(lambda p, cc, g: (seam, False) if abs(p[0] + .5) < 0.6 else None)
    shell.paint(lambda p, cc, g: (_light(col, 0.5), False) if p[0] > 0.6 * k and p[1] < yc and p[2] > ztop + 0.2 * k else None)


def teapot(c, H, col, col2=None):
    """Makes the shell a china teapot: a lid with a knob on top, a spout at
    the front side, a handle at the back, blue flowers (col2) on the china,
    and a glowing puff of steam from the spout."""
    k = H / 10.0
    shell = kit._find(c, 'shell') or kit._find(c, 'body')
    (lo, hi) = _bounds(shell)
    yc = (lo[1] + hi[1]) / 2
    flower = col2 or hexc('#4A78D8')
    shell.paint(lambda p, cc, g: (col, False))
    shell.paint(lambda p, cc, g: (flower, False) if kit._hash(p[0] // 2, p[1] // 2, p[2] // 2, 5) % 11 == 0 and p[2] > lo[2] + 1 else None)
    pot = c.part('teapot', 'static')
    # a lid and knob
    pot.ell((0, yc, hi[2] + 0.2 * k), (1.0 * k, 1.0 * k, 0.35 * k + .2), col)
    kit.ball(pot, (0, yc, hi[2] + 0.8 * k), (0.4 * k, 0.4 * k, 0.4 * k), flower)
    # the spout from the right side, rising forward
    zs = (lo[2] + hi[2]) / 2
    line(pot, (hi[0] - 0.3 * k, yc - 0.6 * k, zs), (hi[0] + 1.3 * k, yc - 1.6 * k, zs + 1.4 * k), col, r=0.4 * k)
    tip = (hi[0] + 1.4 * k, yc - 1.7 * k, zs + 1.6 * k)
    for i in range(3):
        pot.ell((tip[0] + 0.2 * k * i, tip[1] - 0.1 * k * i, tip[2] + 0.5 * k + i * 0.55 * k), (0.35 * k + .2, 0.35 * k + .2, 0.3 * k + .2), WHITE, True)
    # a handle on the left side
    for a in range(10):
        ang = a / 9 * math.pi
        pot.ell((lo[0] - 0.3 * k - math.sin(ang) * 0.9 * k, yc + 0.4 * k, zs - 0.3 * k + math.cos(ang) * 0.9 * k), (0.3 * k + .2, 0.3 * k + .2, 0.3 * k + .2), col)


def donut(c, H, col, col2=None):
    """A sprinkle donut ring round the middle (a float), sprinkles in col2."""
    k = H / 10.0
    body = kit._find(c, 'body')
    # (the shore seal's flippers round unevenly at some heights: keep the
    # body mirror-exact so its legs pair up)
    for p in [p for p in body.v if p[0] < 0]:
        del body.v[p]
    _mirror(body)
    # its belly rests on the float, just off the ground, so only the
    # flippers touch down (and step)
    z0 = min(p[2] for p in body.v)
    for piece in rig._plan_pieces({(x, y) for (x, y, z) in body.v if z == z0}):
        if min(x for x, _ in piece) < 0 <= max(x for x, _ in piece):
            for (x, y) in piece:
                body.v.pop((x, y, z0), None)
    (lo, hi) = _bounds(body)
    ring = c.part('donut', 'static')
    yc = (lo[1] + hi[1]) / 2 - 0.4 * k
    zc = max(lo[2] + (hi[2] - lo[2]) * 0.5, 1.6 * k)
    R = (hi[0] - lo[0] + 1) / 2 + 0.2 * k
    r = 0.75 * k
    dough = hexc('#E8B06A')
    for a in range(48):
        ang = a / 48 * 2 * math.pi
        ring.ell((math.cos(ang) * R, yc + math.sin(ang) * R * 0.95, zc), (r, r, r * 0.9), dough)
    # pink icing over the top half, glowing rainbow sprinkles
    ring.paint(lambda p, cc, g: (col, False) if p[2] + .5 >= zc - 0.1 * k else None)
    _mirror(ring)
    for p in [p for p in ring.v if p in body.v]:
        del ring.v[p]  # the ring sits round the body, never cuts into it
    sprinkles = [hexc('#FF4D5E'), hexc('#FFD43B'), hexc('#5CF2FF'), hexc('#7BE36A'), WHITE]
    ring.paint(lambda p, cc, g: (sprinkles[kit._hash(*p, 9) % 5], True) if cc == col and kit._hash(*p, 21) % 13 == 0 else None)
    del col2


def wrapper(c, H, col, col2=None):
    """A cupcake's pleated paper wrapper: the lower body painted in ribs (col2
    every other pleat) and a rolled rim standing out round the top edge."""
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    rib = col2 or _dark(col, 0.2)
    zt = lo[2] + (hi[2] - lo[2]) * 0.42
    yc = (lo[1] + hi[1]) / 2

    def pleat(p, cc, g):
        if p[2] > zt:
            return None
        a = math.atan2(p[1] + .5 - yc, p[0] + .5) / (2 * math.pi) * 32
        return (rib if int(math.floor(a)) % 2 == 0 else col, False)

    body.paint(pleat)
    cup = c.part('wrapper', 'static')
    for a in range(64):
        ang = a / 64 * 2 * math.pi
        R = (hi[0] - lo[0] + 1) / 2 * 1.0 + 0.6
        cup.put((math.floor(math.cos(ang) * R), math.floor(yc + math.sin(ang) * R), math.floor(zt) + 1), col)
    for p in list(cup.v):
        if p in body.v:
            del cup.v[p]
    _mirror(cup)


def cherry(c, H, col, col2=None):
    """A glossy cherry on top of the head, a green stem."""
    k = H / 10.0
    y, zt = kit.crown(c)
    part = c.part('cherry', 'static')
    kit.ball(part, (0.5, y, zt + 0.6 * k), (0.6 * k, 0.6 * k, 0.6 * k), col)
    part.put((0, round(y) - max(1, round(0.2 * k)), round(zt + 0.9 * k)), _light(col, 0.6), True)
    for i in range(max(2, round(0.8 * k))):
        part.put((i // 2, round(y) + i // 2, round(zt + 1.1 * k) + i), col2 or hexc('#3E9A3E'))


def frosting(c, H, col, col2=None):
    """A swirl of frosting on top of the head, tipped with sprinkles."""
    k = H / 10.0
    y, zt = kit.crown(c)
    part = c.part('frosting', 'static')
    for i in range(3):
        r = (1.05 - 0.3 * i) * k
        part.ell((0, y, zt + 0.2 * k + i * 0.55 * k), (r, r, 0.4 * k + .2), col)
    part.put((0, round(y), round(zt + 1.8 * k)), col)
    if col2:
        part.paint(lambda p, cc, g: (col2, True) if kit._hash(*p, 4) % 9 == 0 else None)
    _mirror(part)


def pancakes(c, H, col, col2=None):
    """The body as a stack of pancakes: browned edges in col every layer, a
    butter pat (col2) on top with a glowing syrup drip."""
    k = H / 10.0
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    layer = max(2, round(0.9 * k))
    body.paint(lambda p, cc, g: (col, False) if (p[2] - lo[2]) % layer == 0 and p[2] > lo[2] else None)
    pat = c.part('butter', 'static')
    y, zt = kit.crown(c)
    top = max(p[2] for p in body.v)
    yc = (lo[1] + hi[1]) / 2 + 0.6 * k
    zb = _top_at(c, 0, round(yc)) or top
    pat.box((-round(0.7 * k), round(yc - 0.7 * k), zb + 1), (round(0.7 * k) - 1, round(yc + 0.7 * k) - 1, zb + max(1, round(0.5 * k))), col2 or hexc('#FFE27A'))
    syrup = hexc('#C8721C')
    for i in range(max(2, round(1.6 * k))):
        x = round(1.6 * k)
        pt = (x, round(yc) + (i // 3), zb - i)
        body.put(pt, syrup, True)
    del y, zt


def icing(c, H, col, col2=None):
    """A cinnamon-roll shell: a spiral of dark cinnamon with white icing
    (col) drizzled over the top."""
    k = H / 10.0
    shell = kit._find(c, 'shell') or kit._find(c, 'body')
    (lo, hi) = _bounds(shell)
    cy, cz = (lo[1] + hi[1] + 1) / 2, (lo[2] + hi[2] + 1) / 2
    cinnamon = col2 or hexc('#8A4A1E')
    shell.paint(lambda p, cc, g: (cinnamon, False) if int((math.hypot(p[1] + .5 - cy, p[2] + .5 - cz) + math.atan2(p[2] + .5 - cz, p[1] + .5 - cy) * 0.35 * k) / max(1, 0.6 * k)) % 2 == 0 else None)
    shell.paint(lambda p, cc, g: (col, False) if p[2] > cz + 0.4 * k and (p[1] + p[0] // 2) % max(2, round(1.1 * k)) == 0 else None)


def facedisc(c, H, col, col2=None):
    """An owl's face: pale discs round each eye and feathered ear tufts."""
    k = H / 10.0
    head = _head(c)
    eyes = kit._find(c, 'eyes')
    if eyes and eyes.v:
        for sx in (-1, 1):
            side = [p for p in eyes.v if (p[0] >= 0) == (sx > 0)]
            if not side:
                continue
            ex = sum(p[0] for p in side) / len(side) + .5
            ez = sum(p[2] for p in side) / len(side) + .5
            fy = min(p[1] for p in side)
            head.paint(lambda p, cc, g, ex=ex, ez=ez, fy=fy: (col, False) if p[1] <= fy + 1.0 * k and math.hypot(p[0] + .5 - ex, p[2] + .5 - ez) < 1.05 * k else None)
    ears = kit._find(c, 'ears')
    if ears and col2:
        ears.paint(lambda p, cc, g: (col2, False))


def twohead(c, H, col, col2=None):
    """A second head beside the first (a two-headed turtle): the head moves
    left, a copy of it (with its own blinking eyes) sits on the right,
    turned out a little the other way."""
    k = H / 10.0
    head = kit._find(c, 'head')
    eyes = kit._find(c, 'eyes')
    if not head:
        return
    off = round(1.0 * k)
    hv = dict(head.v)
    ev = dict(eyes.v) if eyes else {}
    head.v = {(x - off, y, z): v for (x, y, z), v in hv.items()}
    head.pivot = (head.pivot[0] - off, head.pivot[1], head.pivot[2])
    if eyes:
        eyes.v = {(x - off, y, z): v for (x, y, z), v in ev.items()}
    h2 = c.part('head2', 'static', (off, head.pivot[1], head.pivot[2]))
    for (x, y, z), v in hv.items():
        h2.put((x + off, y + (1 if x >= 0 else 0), z), *v)
    if eyes:
        e2 = c.part('eyes2', 'blink', h2.pivot)
        for (x, y, z), v in ev.items():
            e2.put((x + off, y + (1 if x >= 0 else 0), z), *v)
    # the two necks join the body: fill between
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(head)
    for sx in (-1, 1):
        line(body, (sx * off, lo[1] + 1.2 * k, (lo[2] + hi[2]) / 2), (sx * off * 0.4, lo[1] + 2.4 * k, (lo[2] + hi[2]) / 2 - 0.2 * k), col, r=0.7 * k)


def crocsnout(c, H, col, col2=None):
    """A crocodile's long toothy snout in place of a beak, and a ridged
    crocodile tail."""
    k = H / 10.0
    head = _head(c)
    (lo, hi) = _bounds(head)
    fy = _front_y(head)
    # take the beak away (the voxels in front of the face)
    face_y = fy + max(1, round(0.5 * k))
    for p in [p for p, (cc, g) in head.v.items() if p[1] < face_y and p[2] < lo[2] + (hi[2] - lo[2]) * 0.55]:
        del head.v[p]
    zb = round(lo[2] + (hi[2] - lo[2]) * 0.32)
    L = round(2.4 * k)
    w = round(0.95 * k)
    snout = c.part('snout', 'static')
    snout.box((-w, face_y - L, zb), (w - 1, face_y + 1, zb + max(2, round(0.8 * k))), col)
    teeth = col2 or WHITE
    for y in range(face_y - L + 1, face_y, 2):
        snout.put((w, y, zb), teeth)
        snout.put((-w - 1, y, zb), teeth)
    for sx in (-1, 1):  # nostril bumps
        snout.put((round(sx * 0.4 * k) - (1 if sx < 0 else 0), face_y - L + 1, zb + max(2, round(0.8 * k)) + 1), _dark(col, 0.4))
    # a ridged tail
    body = kit._find(c, 'body')
    (blo, bhi) = _bounds(body)
    tl = c.part('tail', 'tail', (0, bhi[1], blo[2] + (bhi[2] - blo[2]) * 0.35))
    n = round(3.0 * k)
    for i in range(n):
        r = 0.8 * k * (1 - i / (n + 1)) + .4
        y = bhi[1] - 0.6 * k + i
        z = blo[2] + (bhi[2] - blo[2]) * 0.35 - i * 0.18
        tl.ell((0, y, z), (r, .7, r), col)
        if i % 2 == 0:
            tl.put((0, round(y), round(z + r)), _dark(col, 0.3))
            tl.put((-1, round(y), round(z + r)), _dark(col, 0.3))


def _wings(c, k, col, edge, shape, glow_edge=False):
    """Two thin wings on the back (wingL / wingR), each drawn on the right
    as a list of (dx, dz) cells by `shape`, mirrored to the left."""
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    yc = (lo[1] + hi[1]) / 2 - 0.2 * k
    zt = max(p[2] for p in body.v if abs(p[1] - yc) <= 1)
    x0 = round(0.4 * k)
    for sx, name in ((-1, 'wingL'), (1, 'wingR')):
        w = c.part(name, name, (sx * x0, round(yc), zt))
        for (dx, dz, e) in shape:
            x = x0 + dx
            w.put((x if sx > 0 else -x - 1, round(yc), zt + dz), edge if e else col, glow_edge and e)
            w.put((x if sx > 0 else -x - 1, round(yc) + 1, zt + dz), edge if e else col, glow_edge and e)


def bflywings(c, H, col, col2=None):
    """Butterfly wings on the back: two lobes a side, edged in glowing col2."""
    k = H / 10.0
    cells = []
    R1, R2 = 2.3 * k, 1.6 * k
    for dx in range(0, round(3.6 * k)):
        for dz in range(-round(1.6 * k), round(3.6 * k)):
            up = ((dx - 1.6 * k) / R1) ** 2 + ((dz - 1.6 * k) / R1) ** 2 <= 1
            dn = ((dx - 1.2 * k) / R2) ** 2 + ((dz + 0.3 * k) / R2) ** 2 <= 1
            if up or dn:
                cells.append((dx, dz))
    cs = set(cells)
    shape = [(dx, dz, any((dx + a, dz + b) not in cs for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))) and dx > 0)
             for (dx, dz) in cells]
    _wings(c, k, col, col2 or _light(col, 0.5), shape, glow_edge=True)


def glideflaps(c, H, col, col2=None):
    """A flying squirrel's gliding flaps: thin skin from the sides out past
    the legs, edged in col2; they are its wings, so they flap."""
    k = H / 10.0
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    zc = round(lo[2] + (hi[2] - lo[2]) * 0.55)
    y0, y1 = lo[1] + round(0.6 * k), hi[1] - round(0.6 * k)
    edge = col2 or _light(col, 0.4)
    x0 = round(1.3 * k)
    for sx, name in ((-1, 'wingL'), (1, 'wingR')):
        w = c.part(name, name, (sx * x0, (y0 + y1) / 2, zc))
        for y in range(y0, y1 + 1):
            reach = round(1.4 * k * math.sin(math.pi * (y - y0) / max(1, y1 - y0)) + 0.4 * k)
            xb = max(p[0] for p in body.v if p[1] == y and p[2] == zc) if any(p[1] == y and p[2] == zc for p in body.v) else x0
            for i in range(reach + 1):
                x = xb + 1 + i
                w.put((x if sx > 0 else -x - 1, y, zc), edge if i == reach else col)


def bigbeak(c, H, col, col2=None):
    """A toucan's huge beak: banana-shaped, col with a black tip and a
    col2 (red) stripe along the top."""
    k = H / 10.0
    head = _head(c)
    (lo, hi) = _bounds(head)
    fy = _front_y(head)
    face_y = fy + max(1, round(0.4 * k))
    # drop the small beak
    for p in [p for p in head.v if p[1] < face_y and p[2] < lo[2] + (hi[2] - lo[2]) * 0.6]:
        del head.v[p]
    beak = c.part('beak', 'static')
    zc = lo[2] + (hi[2] - lo[2]) * 0.42
    L = 3.2 * k
    n = 14
    for i in range(n):
        t = i / (n - 1)
        r = 0.95 * k * (1 - 0.6 * t) + .3
        y = face_y - t * L
        z = zc + math.sin(t * math.pi) * 0.35 * k - t * 0.4 * k
        beak.ell((0, y, z), (r * 0.85, .8, r), col)
    beak.paint(lambda p, cc, g: (INK, False) if p[1] < face_y - 0.82 * L else None)
    if col2:
        beak.paint(lambda p, cc, g: (col2, False) if cc == col and p[2] > zc + 0.45 * k else None)
    _mirror(beak)


def longbeak(c, H, col, col2=None):
    """A long thin beak (a hummingbird's, a kiwi's), slightly down-curved,
    the tip in col2."""
    k = H / 10.0
    head = _head(c)
    (lo, hi) = _bounds(head)
    fy = _front_y(head)
    face_y = fy + max(1, round(0.4 * k))
    for p in [p for p in head.v if p[1] < face_y and p[2] < lo[2] + (hi[2] - lo[2]) * 0.6]:
        del head.v[p]
    beak = c.part('beak', 'static')
    zc = lo[2] + (hi[2] - lo[2]) * 0.42
    L = round(2.8 * k)
    w = max(1, round(0.25 * k))
    for i in range(L):
        t = i / L
        z = round(zc - t * t * 0.8 * k)
        tip = col2 if (col2 and t > 0.75) else col
        beak.box((-w, face_y - i, z), (w - 1, face_y - i, z + (1 if t < 0.5 else 0)), tip)


def hookbeak(c, H, col, col2=None):
    """A raptor's hooked beak: short and deep, curving down at the tip."""
    k = H / 10.0
    head = _head(c)
    (lo, hi) = _bounds(head)
    fy = _front_y(head)
    face_y = fy + max(1, round(0.4 * k))
    for p in [p for p in head.v if p[1] < face_y and p[2] < lo[2] + (hi[2] - lo[2]) * 0.6]:
        del head.v[p]
    beak = c.part('beak', 'static')
    zc = lo[2] + (hi[2] - lo[2]) * 0.45
    w = max(1, round(0.5 * k))
    L = round(1.3 * k)
    for i in range(L):
        h = round((0.9 - 0.4 * i / L) * k)
        beak.box((-w, face_y - i, round(zc) - h // 2), (w - 1, face_y - i, round(zc) + h // 2), col)
    beak.box((-max(1, w - 1), face_y - L, round(zc) - round(0.8 * k)), (max(1, w - 1) - 1, face_y - L, round(zc) + 1), col2 or _dark(col, 0.3))


def casque(c, H, col, col2=None):
    """A hornbill's helmet: a long curved beak with a tall casque on top."""
    bigbeak(c, H, hexc('#FFE27A') if col2 is None else col2, None)
    k = H / 10.0
    beak = kit._find(c, 'beak')
    (lo, hi) = _bounds(beak)
    part = c.part('casque', 'static')
    for y in range(lo[1] + round(0.9 * k), hi[1] + 1):
        t = (y - lo[1]) / max(1, hi[1] - lo[1])
        zt = max((p[2] for p in beak.v if p[1] == y), default=hi[2])
        h = round(0.9 * k * math.sin(math.pi * min(1, t * 1.2)))
        for z in range(zt + 1, zt + 1 + h):
            for x in (-1, 0):
                part.put((x, y, z), col)
    part.paint(lambda p, cc, g: (_light(col, 0.4), True) if p[2] == max(q[2] for q in part.v if q[1] == p[1]) else None)


def wingless(c, H, col, col2=None):
    """Takes the wings away (a kiwi): its round body is all there is."""
    for name in ('wingL', 'wingR'):
        p = kit._find(c, name)
        if p:
            c.parts.remove(p)
    del col, col2


def crowncrest(c, H, col, col2=None):
    """A peachick's crown: a little fan of thin stalks, each tipped with a
    glowing bead in col2."""
    k = H / 10.0
    y, zt = kit.crown(c)
    part = c.part('crest', 'static')
    for i, ang in enumerate((-30, -10, 10, 30)):
        a = math.radians(ang)
        n = max(2, round(1.3 * k))
        x = 0
        for j in range(n):
            x = round(math.sin(a) * j)
            part.put((x if x >= 0 else x - 1, round(y), zt + 1 + j), col)
        bead = (x if x >= 0 else x - 1, round(y), zt + 1 + n)
        part.put(bead, col2 or hexc('#3FE0D0'), True)
        part.put((bead[0], bead[1] - 1, bead[2]), col2 or hexc('#3FE0D0'), True)


def shellheld(c, H, col, col2=None):
    """A clam shell held against the chest (a sea otter's), ridged in col2."""
    k = H / 10.0
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    shell = c.part('clam', 'static')
    zc = lo[2] + (hi[2] - lo[2]) * 0.62
    yc = _front_y(body, round(zc)) - 0.2 * k
    shell.ell((0, yc - 0.3 * k, zc), (1.4 * k, 0.5 * k + .3, 1.1 * k), col, cond=lambda x, y, z: z >= zc - 0.8 * k)
    shell.paint(lambda p, cc, g: (col2 or _dark(col, 0.25), False) if p[0] % 2 == 0 else None)
    kit.ball(shell, (0, yc - 0.2 * k, zc - 0.5 * k), (0.25 * k + .2, 0.25 * k + .2, 0.25 * k + .2), hexc('#FFF4F8'))
    for p in list(shell.v):
        if shell.v[p][0] == hexc('#FFF4F8'):
            shell.v[p] = (hexc('#FFF4F8'), True)  # a glowing pearl


def bolttail(c, H, col, col2=None):
    """A zig-zag lightning-bolt tail, glowing."""
    k = H / 10.0
    old = kit._find(c, 'tail')
    pivot = old.pivot if old else (0, 3.4 * k, 3.4 * k)
    if old:
        c.parts.remove(old)
    tl = c.part('tail', 'tail', pivot)
    x, y, z = 0, pivot[1], pivot[2]
    segs = ((0, 1.2, 0.9), (0, -0.2, 0.9), (0, 1.2, 1.1), (0, -0.4, 0.8))
    for i, (dx, dy, dz) in enumerate(segs):
        a = (x, y, z)
        x, y, z = x + dx * k, y + abs(dy) * k * (1 if dy > 0 else 0.3), z + dz * k
        line(tl, a, (x, y, z), col, r=(0.45 - 0.07 * i) * k, glow=True)


def throat(c, H, col, col2=None):
    """A glowing patch on the throat (a hummingbird's ruby gorget): the
    front of the body just under the head."""
    k = H / 10.0
    body = kit._find(c, 'body')
    head = _head(c)
    (hlo, hhi) = _bounds(head)
    zt = hlo[2] + 1
    body.paint(lambda p, cc, g: (col, True) if zt - 1.4 * k <= p[2] <= zt + 1 and p[1] <= _front_y(body, p[2]) + 0.6 * k and abs(p[0] + .5) < 1.4 * k else None)
    head.paint(lambda p, cc, g: (col, True) if p[2] <= hlo[2] + 0.6 * k and p[1] < (hlo[1] + hhi[1]) / 2 and abs(p[0] + .5) < 1.4 * k else None)


def eyering(c, H, col, col2=None):
    """A pale ring round each eye, so an eye set in a dark band still reads
    (an angelfish's): head and body voxels next to the eyes take col."""
    k = H / 10.0
    eyes = kit._find(c, 'eyes')
    if not eyes:
        return
    ev = list(eyes.v)
    r = max(1.5, 0.45 * k)
    near = lambda p: any((p[0] - e[0]) ** 2 + (p[1] - e[1]) ** 2 + (p[2] - e[2]) ** 2 <= r * r for e in ev)
    for part in (_head(c), kit._find(c, 'body')):
        if part is not None:
            part.paint(lambda p, cc, g: (col, False) if p not in eyes.v and near(p) else None)


def narwhaltusk(c, H, col, col2=None):
    """A narwhal's tusk: replaces the plan's tusk with a long, thin, straight
    one (about the body's length, two voxels thick) from the upper lip,
    banded cream (col) and tan (col2) for the spiral, the tip glowing."""
    k = H / 10.0
    old = kit._find(c, 'tusk')
    if old:
        c.parts.remove(old)
    head = _head(c)
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    (hlo, hhi) = _bounds(head)
    fy = hlo[1]
    z0 = round((hlo[2] + hhi[2]) / 2 + 0.35 * k)
    zrow = [p for p in head.v if p[2] == z0 and p[0] in (-1, 0)]
    if zrow:
        fy = min(p[1] for p in zrow)
    n = max(8, round((hi[1] - hlo[1] + 1) * 0.9))  # about the whole body's length
    tan = col2 or _dark(col, 0.25)
    tusk = c.part('tusk', 'static', (0, fy, z0))
    band = max(2, round(0.5 * k))
    for i in range(n):
        y = fy - 1 - i
        z = z0 + i // max(4, round(2.0 * k))  # tilts up a little
        glow = i >= n - max(2, round(0.6 * k))
        cc = col if (i // band) % 2 == 0 else tan
        thick = 2 if i < n - 2 else 1
        for x in ((-1, 0) if thick == 2 else (0,)):
            for dz in range(thick):
                tusk.put((x, y, z + dz - (thick - 1) // 2), cc, glow)
    # the root sits in the lip
    for x in (-1, 0):
        tusk.put((x, fy, z0), col)


def speckles(c, H, col, col2=None):
    """Light single-voxel speckles over the back and head (a narwhal's)."""
    for name in ('body', 'head'):
        part = kit._find(c, name)
        if not part:
            continue
        (lo, hi) = _bounds(part)
        mid = (lo[2] + hi[2]) / 2
        part.paint(lambda p, cc, g, mid=mid: (col, False) if p[2] > mid - 1 and kit._hash(*p, 41) % 11 == 0 else None)


def cheekglow(c, H, col, col2=None):
    """Round cheeks glowing frosty col."""
    k = H / 10.0
    head = _head(c)
    (lo, hi) = _bounds(head)
    fy = _front_y(head)
    zc = lo[2] + (hi[2] - lo[2]) * 0.35
    head.paint(lambda p, cc, g: (col, True) if p[1] <= fy + 1.2 * k and 0.9 * k < abs(p[0] + .5) < 2.2 * k and abs(p[2] + .5 - zc) < 0.7 * k else None)


def gust(c, H, col, col2=None):
    """A little glowing swirl of wind under the creature."""
    k = H / 10.0
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    yc = (lo[1] + hi[1]) / 2
    part = c.part('gust', 'static')
    for a in range(60):
        t = a / 60
        ang = t * 2 * math.pi * 1.6
        R = (1.2 + 1.2 * t) * k
        z = 0.3 * k + t * 1.4 * k
        if a % 4 < 3:
            part.put((math.floor(math.cos(ang) * R), math.floor(yc + math.sin(ang) * R), math.floor(z)), col, True)


def embers(c, H, col, col2=None):
    """Glowing ember flecks scattered over the feathers (or fur)."""
    for name in ('body', 'wingL', 'wingR', 'tail', 'crest'):
        part = kit._find(c, name)
        if part:
            part.paint(lambda p, cc, g: (col, True) if kit._hash(*p, 17) % 11 == 0 else None)


def flakes(c, H, col, col2=None):
    """Glowing snowflakes scattered in the fleece."""
    for name in ('body', 'head'):
        part = kit._find(c, name)
        if part:
            surf = {p for p in part.v if any(n not in part.v for n in ((p[0] + 1, p[1], p[2]), (p[0] - 1, p[1], p[2]), (p[0], p[1], p[2] + 1), (p[0], p[1] + 1, p[2]), (p[0], p[1] - 1, p[2])))}
            part.paint(lambda p, cc, g: (col, True) if p in surf and kit._hash(*p, 23) % 9 == 0 else None)


def clover(c, H, col, col2=None):
    """A four-leaf clover on the head, a glowing dewdrop in the middle."""
    k = H / 10.0
    y, zt = kit.crown(c)
    part = c.part('clover', 'static')
    stem = max(1, round(0.6 * k))
    for i in range(stem):
        part.put((0, round(y), zt + 1 + i), _dark(col, 0.2))
    z = zt + stem + 1
    for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        kit.ball(part, (0.5 + dx * 0.55 * k, y + .5 + dy * 0.55 * k, z), (0.5 * k, 0.5 * k, 0.25 * k + .2), col)
    part.put((0, round(y), z + 1), col2 or hexc('#CFFFF0'), True)


def petalcrown(c, H, col, col2=None):
    """A ring of petals round the crown, a glowing centre (col2)."""
    k = H / 10.0
    y, zt = kit.crown(c)
    part = c.part('petals', 'static')
    for a in range(6):
        ang = a / 6 * 2 * math.pi
        kit.ball(part, (math.cos(ang) * 0.8 * k + .5, y + math.sin(ang) * 0.8 * k, zt + 0.5), (0.5 * k, 0.5 * k, 0.3 * k + .2), col)
    kit.ball(part, (0.5, y, zt + 0.8), (0.4 * k, 0.4 * k, 0.3 * k + .2), col2 or hexc('#FFE27A'))
    if col2:
        part.paint(lambda p, cc, g: (col2, True) if cc == col2 else None)


def cobweb(c, H, col, col2=None):
    """Strands of cobweb trailing from the back, glinting."""
    k = H / 10.0
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    part = c.part('web', 'static')
    for i, (x, dz) in enumerate(((-0.6, 0.0), (0.6, 0.4), (0.0, 0.8))):
        a = (x * k, hi[1] - 0.6 * k, hi[2] - 0.6 * k - dz * k)
        b = (x * 1.6 * k, hi[1] + 2.2 * k, 0.3 * k)
        line(part, a, b, col, glow=(i == 2))
    for t in (0.35, 0.7):
        pa = (-0.6 * k + (-0.6 * 1.6 * k + 0.6 * k) * t, hi[1] - 0.6 * k + 2.8 * k * t, (hi[2] - 0.6 * k) * (1 - t))
        pb = (0.6 * k + (0.6 * 1.6 * k - 0.6 * k) * t, hi[1] - 0.6 * k + 2.8 * k * t, (hi[2] - k) * (1 - t))
        line(part, pa, pb, col)


def knees(c, H, col, col2=None):
    """Paints a band round the middle (the knee) of each leg."""
    k = H / 10.0
    for p in c.parts:
        if p.name in rig.LEG_NAMES and p.v:
            zs = [q[2] for q in p.v]
            top = max(zs)
            p.paint(lambda q, cc, g, top=top: (col, False) if top - 1.2 * k <= q[2] <= top - 0.3 * k else None)


def fuzz(c, H, col, col2=None):
    """Short hairs standing out all over a body (a tarantula's)."""
    for name in ['body', 'head'] + list(rig.LEG_NAMES):
        part = kit._find(c, name)
        if not part:
            continue
        for p in list(part.v):
            if kit._hash(*p, 31) % 7 == 0 and p[2] > 0:
                n = (p[0] + (1 if p[0] >= 0 else -1), p[1], p[2] + 1)
                if n not in part.v:
                    part.put(n, col)


def wingspots(c, H, col, col2=None):
    """An eye spot on each wing (col with a glowing col2 centre), and the
    wing tips curled darker (an atlas moth's snake-head tips)."""
    k = H / 10.0
    for name in ('wingL', 'wingR'):
        w = kit._find(c, name)
        if not w or not w.v:
            continue
        xs = [p[0] for p in w.v]
        zs = [p[2] for p in w.v]
        cx = (min(xs) + max(xs)) / 2 + .5
        cz = (min(zs) + max(zs)) / 2 + .5
        w.paint(lambda p, cc, g, cx=cx, cz=cz: ((col2 or WHITE), True) if math.hypot(p[0] + .5 - cx, p[2] + .5 - cz) < 0.35 * k + .4 else (
            (col, False) if math.hypot(p[0] + .5 - cx, p[2] + .5 - cz) < 0.75 * k + .4 else None))
        far = max(xs) if name == 'wingR' else min(xs)
        w.paint(lambda p, cc, g, far=far: (_dark(cc, 0.35), False) if abs(p[0] - far) <= max(1, round(0.5 * k)) and p[2] >= max(zs) - round(1.4 * k) else None)


def bigwings(c, H, col, col2=None):
    """Makes the wings a third bigger (the biggest wings in the tier)."""
    for name in ('wingL', 'wingR'):
        w = kit._find(c, name)
        if w and w.v:
            kit._rescale([w], w.pivot, (1.3, 1.0, 1.3))
    del col, col2


def wingtails(c, H, col, col2=None):
    """Long trailing tails off the hind wings (a luna moth's), glowing at
    the ends."""
    k = H / 10.0
    for sx, name in ((-1, 'wingL'), (1, 'wingR')):
        w = kit._find(c, name)
        if not w or not w.v:
            continue
        zs = [p[2] for p in w.v]
        low = [p for p in w.v if p[2] == min(zs)]
        p0 = max(low, key=lambda p: p[0] * sx)
        n = round(2.2 * k)
        for i in range(n):
            pt = (p0[0] + sx * (i // 3), p0[1] + i // 2, p0[2] - 1 - i // 2)
            w.put(pt, col2 if i >= n - max(1, round(0.5 * k)) and col2 else col, bool(col2) and i >= n - max(1, round(0.5 * k)))


def clearwings(c, H, col, col2=None):
    """See-through looking wings: pale glassy panes (col) with dark veins
    and glowing orange edges (col2)."""
    k = H / 10.0
    for name in ('wingL', 'wingR'):
        w = kit._find(c, name)
        if not w or not w.v:
            continue
        # the wing is a thin sheet: find its two long axes
        span = [max(p[i] for p in w.v) - min(p[i] for p in w.v) for i in range(3)]
        thin = span.index(min(span))
        a, b = [i for i in range(3) if i != thin]
        flat = {(p[a], p[b]) for p in w.v}
        edge = {q for q in flat if any((q[0] + d0, q[1] + d1) not in flat for d0, d1 in ((1, 0), (-1, 0), (0, 1), (0, -1)))}
        vein = max(4, round(2.2 * k))
        w.paint(lambda p, cc, g: ((col2 or hexc('#FF9418')), True) if (p[a], p[b]) in edge else (
            (_dark(col, 0.45), False) if (p[a] + p[b]) % vein == 0 else (col, False)))


def honeybelly(c, H, col, col2=None):
    """A round, swollen honey belly at the rear, golden and glowing inside."""
    k = H / 10.0
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    zc = lo[2] + (hi[2] - lo[2]) * 0.6
    belly = c.part('honey', 'static')
    belly.ell((0, hi[1] + 0.4 * k, zc + 0.3 * k), (1.7 * k, 1.8 * k, 1.6 * k), col)
    belly.paint(lambda p, cc, g: (col2 or _light(col, 0.45), True) if p[0] > 0.2 * k and p[1] < hi[1] + 0.2 * k and p[2] > zc + 0.6 * k else None)
    belly.paint(lambda p, cc, g: (_dark(col, 0.3), False) if (p[1] - hi[1]) % max(2, round(0.9 * k)) == 0 and cc == col else None)


def bighorn(c, H, col, col2=None):
    """A hercules beetle's giant horn: a long one forward and up from the
    head, a curved one down from the shell to meet it, glossy tips."""
    k = H / 10.0
    head = _head(c)
    (lo, hi) = _bounds(head)
    part = c.part('horn', 'static')
    base = (0, lo[1] + 0.6 * k, (lo[2] + hi[2]) / 2)
    pts = [(0, base[1] - t * 2.2 * k, base[2] - 0.2 * k + math.sin(t * 1.9) * 1.6 * k) for t in (i / 10 for i in range(11))]
    for i, (x, y, z) in enumerate(pts):
        part.ell((x, y, z), (0.5 * k * (1 - i / 14) + .5,) * 3, col)
    shell = kit._find(c, 'shell') or kit._find(c, 'body')
    (slo, shi) = _bounds(shell)
    top = (0, slo[1] + 0.8 * k, shi[2])
    # the great thorax horn: up off the shell, then long and forward over
    # the head, hooking down at the end to meet the head horn
    pts2 = [(0, top[1] + 0.4 * k - t * 5.0 * k, top[2] + 0.4 * k + math.sin(t * math.pi * 0.8) * 1.3 * k - t * t * 1.4 * k) for t in (i / 16 for i in range(17))]
    for i, (x, y, z) in enumerate(pts2):
        part.ell((x, y, z), (0.55 * k * (1 - i / 22) + .4,) * 3, col)
    # the hairy gold underside of the thorax horn
    hair = _light(col, 0.45)
    for (x, y, z) in pts2[5:14]:
        part.put((0, math.floor(y), math.floor(z - 0.55 * k)), hair)
        part.put((-1, math.floor(y), math.floor(z - 0.55 * k)), hair)
    tip = col2 or _light(col, 0.5)
    part.paint(lambda p, cc, g: (tip, bool(col2)) if p[1] < min(q[1] for q in part.v) + 0.7 * k else None)
    _mirror(part)


def gear(c, H, col, col2=None):
    """A brass wind-up gear standing upright on a post on the back, side-on
    so its teeth read; it turns like a wind-up key (anim orbit, about the
    vertical axis). Its hub glows col2; the shell gets riveted seams."""
    k = H / 10.0
    shell = kit._find(c, 'shell') or kit._find(c, 'body')
    (lo, hi) = _bounds(shell)
    yc = (lo[1] + hi[1]) / 2 + 0.6 * k
    zt = (_top_at(c, 0, round(yc), names=(shell.name,)) or hi[2])
    R = 1.3 * k
    post = max(1, round(0.5 * k))
    zc = zt + post + R + 0.4 * k
    g = c.part('gear', 'orbit', (0, round(yc) + .5, zt + 1))
    for z in range(zt + 1, zt + post + 2):
        for x in (-1, 0):
            g.put((x, round(yc), z), _dark(col, 0.3))
    for a in range(96):
        ang = a / 96 * 2 * math.pi
        tooth = (a // 6) % 2 == 0
        for r10 in range(round(0.45 * k * 10), round((R + (0.45 * k if tooth else 0)) * 10) + 1, 5):
            r = r10 / 10
            for x in (-1, 0):
                g.put((x, math.floor(yc + math.cos(ang) * r), math.floor(zc + math.sin(ang) * r)), col)
    # spokes' gaps: four round windows between the hub and the rim
    for q in range(4):
        ang = q * math.pi / 2 + math.pi / 4
        wy, wz = yc + math.cos(ang) * 0.85 * k, zc + math.sin(ang) * 0.85 * k
        for p in [p for p in g.v if p[2] > zt + post + 1 and math.hypot(p[1] + .5 - wy, p[2] + .5 - wz) < 0.28 * k + .3]:
            del g.v[p]
    hub = col2 or hexc('#5CF2FF')
    for p in [p for p in g.v if math.hypot(p[1] + .5 - yc, p[2] + .5 - zc) < 0.45 * k + .5]:
        g.v[p] = (hub, True)
    for x in (-2, 1):
        for p in [(x, y, z) for (_, y, z) in list(g.v) if math.hypot(y + .5 - yc, z + .5 - zc) < 0.3 * k + .5]:
            g.put(p, hub, True)
    shell.paint(lambda p, cc, g2: (_dark(cc, 0.3), False) if abs(p[0] + .5) < 0.6 or (p[1] % max(3, round(1.5 * k)) == 0 and p[2] > lo[2] + k) else None)


def geode(c, H, col, col2=None):
    """A cracked-open geode for a shell: the top of the body opened up and
    filled with glowing crystal points (col), a pale rim of rock."""
    k = H / 10.0
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    yc = (lo[1] + hi[1]) / 2
    zcut = hi[2] - round(0.9 * k)
    rim = col2 or hexc('#D8D2E0')
    R = (hi[0] - lo[0] + 1) / 2 * 0.62
    for p in [p for p in body.v if p[2] > zcut and math.hypot(p[0] + .5, p[1] + .5 - yc) < R]:
        del body.v[p]
    body.paint(lambda p, cc, g: (rim, False) if p[2] >= zcut - 1 and math.hypot(p[0] + .5, p[1] + .5 - yc) < R + 1.2 else None)
    part = c.part('crystals', 'static')
    for (x, y, h) in ((0, 0, 1.6), (0.7, -0.5, 1.0), (-0.6, 0.6, 1.2), (0.5, 0.7, 0.8), (-0.6, -0.6, 0.9)):
        n = max(2, round(h * k))
        for i in range(n):
            r = 0.5 * k * (1 - i / (n + 1)) + .3
            part.ell((x * k, yc + y * k, zcut - 0.6 * k + i), (r, r, .6), col, True)
    part.paint(lambda p, cc, g: (_light(col, 0.4), True) if (p[0] + p[1] + p[2]) % 3 == 0 else None)


def yarn(c, H, col, col2=None):
    """Knitted yarn: strands wound round the body and head in col (a
    darker shade of the coat), and a loose thread from the tail tip."""
    k = H / 10.0
    for name in ('body', 'head', 'tail'):
        part = kit._find(c, name)
        if part:
            part.paint(lambda p, cc, g: (col, False) if (p[2] * 2 + p[1] + (p[0] // 2)) % max(3, round(1.4 * k)) == 0 else None)
    tl = kit._find(c, 'tail')
    if tl and tl.v:
        end = max(tl.v, key=lambda p: (p[1], -p[2]))
        for i in range(max(3, round(2.2 * k))):
            tl.put((end[0] + (i // 3), end[1] + 1 + i // 2, max(0, end[2] - i)), col2 or col)


def teddy(c, H, col, col2=None):
    """A stitched teddy: dashed seams (col) down the middle of the body and
    head, a patch on one side, and button eyes (col2) with glinting holes."""
    k = H / 10.0
    for name in ('body', 'head'):
        part = kit._find(c, name)
        if part:
            part.paint(lambda p, cc, g: (col, False) if p[0] in (-1, 0) and p[1] % 2 == 0 else None)
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    patch = _light(col2 or hexc('#7FB3FF'), 0.3)
    body.paint(lambda p, cc, g: (patch, False) if p[0] > 0 and abs(p[1] + .5 - (lo[1] + hi[1]) / 2) < 0.9 * k and abs(p[2] + .5 - (lo[2] + hi[2]) / 2) < 0.8 * k else None)
    eyes = kit._find(c, 'eyes')
    if eyes and col2:
        for p in eyes.v:
            eyes.v[p] = (col2, False)
        for sx in (-1, 1):
            side = sorted(p for p in eyes.v if (p[0] >= 0) == (sx > 0))
            if side:
                eyes.v[side[len(side) // 2]] = (WHITE, True)


def cactus(c, H, col, col2=None):
    """Soft white cactus spines dotted over the body and head, in rows."""
    k = H / 10.0
    for name in ('body', 'head', 'tail'):
        part = kit._find(c, name)
        if not part:
            continue
        w = max(2, round(0.8 * k))
        surf = [p for p in part.v if (p[0] + 1 if p[0] >= 0 else p[0] - 1, p[1], p[2]) not in part.v]
        for p in surf:
            if p[1] % w == 0 and p[2] % w == 0 and p[2] > 1.4 * k:
                part.put((p[0] + (1 if p[0] >= 0 else -1), p[1], p[2]), col)
        part.paint(lambda p, cc, g: (_dark(cc, 0.12), False) if (p[0] // max(2, round(0.9 * k))) % 2 == 0 and cc != col else None)


def bubble(c, H, col, col2=None):
    """A soap bubble round the whole creature, drawn as glowing rainbow
    rings (the bubble's shine) so the creature inside stays in view."""
    k = H / 10.0
    (lo, hi) = c.bounds()
    cx = (lo[0] + hi[0]) / 2
    cy = (lo[1] + hi[1]) / 2
    cz = (lo[2] + hi[2]) / 2 + 0.4 * k
    R = max(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]) / 2 + 0.9 * k
    part = c.part('bubble', 'static')
    shades = [col, col2 or hexc('#FFB3F0'), hexc('#B3FFF0'), hexc('#FFF6B3')]
    n = 160
    for i in range(n):
        a = i / n * 2 * math.pi
        for (u, v, w) in ((math.cos(a), math.sin(a), 0.0), (math.cos(a), 0.0, math.sin(a)), (0.0, math.cos(a), math.sin(a))):
            z = cz + w * R
            if z < 0.3 * k:
                continue
            part.put((math.floor(cx + u * R), math.floor(cy + v * R), math.floor(z)), shades[(i // 10) % 4], True)
    # a shine highlight high on the front
    part.ell((cx + 0.45 * R, cy - 0.7 * R, cz + 0.45 * R), (0.35 * k, 0.35 * k, 0.35 * k), WHITE, True)


def trunk(c, H, col, col2=None):
    """An elephant's trunk hanging from the face, curling up at the tip,
    the tip in col2 (pale pink)."""
    k = H / 10.0
    head = _head(c)
    (lo, hi) = _bounds(head)
    fy = _front_y(head)
    zc = lo[2] + (hi[2] - lo[2]) * 0.42
    part = c.part('trunk', 'static')
    n = 12
    for i in range(n + 1):
        t = i / n
        y = fy + 0.3 * k - t * 1.6 * k - max(0, t - 0.6) * 2.4 * k
        z = zc - t * 2.4 * k + max(0, t - 0.65) ** 2 * 14 * k
        r = (0.75 - 0.3 * t) * k
        crease = i % 2 == 1 and t < 0.85
        part.ell((0, y, z), (r, r, r), (col2 if (col2 and t > 0.88) else (_dark(col, 0.12) if crease else col)))
    _mirror(part)


def fanears(c, H, col, col2=None):
    """Big round fan ears out at the sides of the head (an elephant's),
    pink inside (col2); they are the ears part, so they flap."""
    k = H / 10.0
    head = _head(c)
    (lo, hi) = _bounds(head)
    old = kit._find(c, 'ears')
    if old:
        c.parts.remove(old)
    ears = c.part('ears', 'ears', (0, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2 + 0.6 * k))
    inner = col2 or hexc('#FFB3C7')
    yc = (lo[1] + hi[1]) / 2 + 0.3 * k
    zc = (lo[2] + hi[2]) / 2 + 0.3 * k
    for sx in (1,):
        xc = hi[0] + 0.6 * k
        ears.ell((xc, yc, zc), (0.4 * k + .3, 1.3 * k, 1.6 * k), col)
        ears.paint(lambda p, cc, g: (inner, False) if p[1] <= yc - 0.2 * k and abs(p[2] + .5 - zc) < 1.2 * k and abs(p[1] + .5 - yc) < 1.0 * k and p[0] >= xc - 0.4 * k else None)
    _mirror(ears)


def curlhorns(c, H, col, col2=None):
    """A musk ox's horns: from a broad boss on the crown, sweeping down past
    the cheeks and curling up at the tips (col2)."""
    k = H / 10.0
    y, zt = kit.crown(c)
    head = _head(c)
    (lo, hi) = _bounds(head)
    part = c.part('horns', 'static')
    part.ell((0, y, zt - 0.1 * k), ((hi[0] - lo[0] + 1) / 2 * 0.75, 0.7 * k, 0.4 * k + .2), col)
    for i in range(14):
        t = i / 13
        ang = t * math.pi * 1.1
        x = (hi[0] - lo[0] + 1) / 2 * 0.75 + math.sin(ang) * 1.0 * k
        z = zt - 0.4 * k - (1 - math.cos(ang)) * 1.4 * k + max(0, t - 0.7) * 2.5 * k
        r = (0.42 - 0.2 * t) * k + .3
        part.ell((x, y - 0.3 * k - t * 0.6 * k, z), (r, r, r), col2 if (col2 and t > 0.8) else col)
    _mirror(part)


def longfur(c, H, col, col2=None):
    """A shaggy skirt of long fur hanging from the body, most of the way to
    the ground (the legs still show below)."""
    k = H / 10.0
    body = kit._find(c, 'body')
    (lo, hi) = _bounds(body)
    zmid = lo[2] + (hi[2] - lo[2]) * 0.55
    skirt = [p for p in body.v if p[2] >= zmid - 0.5 and p[2] <= zmid + 0.5]
    floor = round(1.0 * k)
    for (x, y, z) in skirt:
        if abs(x + .5) < (hi[0] - lo[0]) / 2 - 1.2 and lo[1] + 1 < y < hi[1] - 1:
            continue  # only the outer edge hangs
        drop = max(floor, z - round(1.6 * k)) + (kit._hash(x, y, 41) % max(1, round(0.5 * k)))
        for zz in range(drop, z):
            body.put((x, y, zz), col if (x + y + zz) % 5 else _dark(col, 0.15))


def flamehair(c, H, col, col2=None):
    """A flickering flame of hair on top of the head, glowing col into a
    col2 core."""
    k = H / 10.0
    y, zt = kit.crown(c)
    part = c.part('flame', 'static')
    core = col2 or hexc('#FFF27A')
    for i in range(round(2.2 * k)):
        t = i / (2.2 * k)
        r = 1.0 * k * (1 - t) + .3
        sway = math.sin(t * 3.0) * 0.4 * k
        part.ell((sway, y, zt + 0.5 + i), (r, r * 0.8, .6), col, True)
    part.paint(lambda p, cc, g: (core, True) if abs(p[0] + .5) < 0.35 * k + .5 and p[2] < zt + 1.3 * k else None)


ACCESSORIES = {
    'ruff': ruff, 'neck': neck, 'ossicones': ossicones, 'giraffepatches': giraffepatches, 'banana': banana, 'nosehorn': nosehorn, 'hump': hump, 'antlers': antlers,
    'witchhat': witchhat, 'windkey': windkey, 'crystals': crystals, 'raincloud': raincloud, 'lavacracks': lavacracks,
    'glowstripe': glowstripe, 'glowspots': glowspots, 'sparks': sparks, 'whiskers': whiskers, 'barbels': barbels, 'tailtip': tailtip,
    'mohawk': mohawk, 'zebra': zebra, 'tigerstripes': tigerstripes, 'leggings': leggings, 'tearlines': tearlines, 'twinkle': twinkle, 'eartips': eartips, 'tailglow': tailglow,
    'screenface': screenface, 'berryeyes': berryeyes, 'antenna': antenna, 'wraps': wraps, 'beetleshell': beetleshell, 'teapot': teapot,
    'donut': donut, 'wrapper': wrapper, 'cherry': cherry, 'frosting': frosting, 'pancakes': pancakes,
    'icing': icing, 'facedisc': facedisc, 'twohead': twohead, 'crocsnout': crocsnout, 'bflywings': bflywings,
    'glideflaps': glideflaps, 'bigbeak': bigbeak, 'longbeak': longbeak, 'hookbeak': hookbeak, 'casque': casque,
    'wingless': wingless, 'crowncrest': crowncrest, 'shellheld': shellheld, 'bolttail': bolttail,
    'cheekglow': cheekglow, 'eyering': eyering, 'narwhaltusk': narwhaltusk, 'speckles': speckles, 'throat': throat, 'gust': gust, 'embers': embers, 'flakes': flakes, 'clover': clover,
    'petalcrown': petalcrown, 'cobweb': cobweb, 'knees': knees, 'fuzz': fuzz, 'wingspots': wingspots,
    'bigwings': bigwings, 'wingtails': wingtails, 'clearwings': clearwings, 'honeybelly': honeybelly,
    'bighorn': bighorn, 'gear': gear, 'geode': geode, 'yarn': yarn, 'teddy': teddy, 'cactus': cactus,
    'wildbubble': bubble, 'wildtrunk': trunk, 'fanears': fanears, 'curlhorns': curlhorns, 'longfur': longfur,
    'flamehair': flamehair,
}

PLANS = {
    'octopus': ({'col', 'accent', 'belly'}, {'kind': {'octopus', 'sock', 'duck'}}),
    'jelly': ({'col', 'accent'}, {'kind': {'moon'}}),
}

BUILDERS = {
    'octopus': lambda c, H, cols, opts: octopus(c, H, opts.get('kind', 'octopus'), cols['col'], cols.get('accent'), cols.get('belly')),
    'jelly': lambda c, H, cols, opts: jelly(c, H, opts.get('kind', 'moon'), cols['col'], cols.get('accent')),
}
