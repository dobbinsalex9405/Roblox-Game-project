"""Refits for the first roster's Commons: accessories that change a part the
shared body plans draw the same for everyone (a bird's beak, a mammal's
ears and muzzle, a tail, the eyes), so a pug, a capybara and a quokka stop
reading as the same kitten. Each replaces or reshapes what the plan built,
after the plan, shape and patterns (see variants.py), so creatures without
it are untouched.

Accessories (fn(c, H, color, color2, a); `a` is the roster's accessory
dict, its extra keys are the settings named below):

- **ears**: new ears in color, inner or rim color2. `style`: round (size),
  tiny, rimmed (a red panda's: white rim, dark inside), folded (a pug's
  small flaps folding forward).
- **muzzle**: a muzzle out from the face below the eyes, in color, with a
  nose in color2 (default ink). `w` half width, `h` height, `d` depth,
  `taper` (all in k), `nose` [width, height] in voxels, `smile`,
  `wrinkle` (a darker fold across the top), `up` (moves it up, in k),
  `coarse`: false leaves it off the in-game boxes.
- **ruff**: a fluffy ring of fur around the face (a lionhead's mane);
  color2 paints the face inside it (a golden tamarin's dark face).
- **big_eyes**: bigger round eyes with a glint (`size` in k, `up`, `out`);
  `small_pair` adds two small eyes outside them (a jumping spider's).
- **stripe**: a stripe down the middle of the back, nose to tail tip.
- **membrane**: a gliding skin along each side between the legs, edged in
  color2 (a sugar glider's).
- **tear_marks**: a dark line down from the inside of each eye.
- **claw_arms**: the front legs become long arms reaching down to the
  ground with hooked claws in color2 (a sloth's).
- **ring_tail**: the tail replaced by a long ringed tail held up in a
  question mark, rings of color and color2 (a ringtail lemur's).
- **poms**: pom-poms on the crown, ear tips, tail and ankles (a poodle's).
- **beak**: the beak redrawn. `style`: pointed, cone (a finch's), hooked
  (a parrot's), small_hook (a cockatiel's), long (a wader's), dagger (a heron's), pouch (a pelican's,
  color2 the pouch). `len` (in k) for long, dagger and pouch.
- **cheeks**: a round patch on each cheek (a cockatiel's).
- **face**: the face and throat painted color (a lovebird's).
- **hood**: the head painted color above a ring of color2 (a drake
  mallard's green head and white collar).
- **throat_bars**: thin bars across the throat (a zebra finch's).
- **plume**: one or two thin feathers trailing back from the crown.
- **lift_legs**: the creature stands taller on longer legs (`by` in k); feet
  stay on the ground; `toes` keeps a bird's toes flat.
- **fold_wings**: the wings folded shut over the back (a damselfly's), tip
  spot color2.
- **leaf**: a big cut leaf held in the jaws, over the back (a leafcutter
  ant's), vein color2.
- **mandibles**: big antler jaws (a stag beetle's), the little horn removed.
- **feelers**: the head's ink antennae replaced by two short thin ones in
  color; color2 paints a stripe over the head.
- **chameleon**: a tall casque, turret eyes on the sides and a tail rolled
  in a spiral (colour: casque; color2: eye turrets).

And two plans: **sentinel**, a meerkat standing up on its hind legs on
watch, tail behind as a prop (colours col, belly, patches, ear_col,
tail_col); **fiddler**, a crab with one huge claw (colours col, accent,
claw).

Same art frame as kit.py (x right, y back, front is -y, z up), k = H / 10.
Left and right halves are drawn once and mirrored (x -> -x - 1)."""

import math
from collections import Counter

from voxkit import hexc

INK, WHITE = hexc('#1B1B2F'), hexc('#FFFFFF')
BLUSH = hexc('#FF8FB1')


def _rgb(col, default=None):
    if col is None:
        return default
    return hexc(col) if isinstance(col, str) else col


def _find(c, name):
    return next((p for p in c.parts if p.name == name), None)


def _dark(col, t=0.3):
    return tuple(max(0, round(v * (1 - t))) for v in col)


def _main(part):
    """The part's most common colour."""
    return Counter(cc for cc, g in part.v.values()).most_common(1)[0][0]


def _mx(x):
    return -x - 1


def _fine(c):
    return getattr(c, 'fine', False)


def _bb(vs):
    vs = list(vs)
    return [min(v[i] for v in vs) for i in range(3)], [max(v[i] for v in vs) for i in range(3)]


def _sym(part, x, y, z, col, glow=False):
    """A voxel at x (x >= 0 side) and its mirror."""
    part.put((x, y, z), col, glow)
    part.put((_mx(x), y, z), col, glow)


def _rod(cells, a, b, col):
    """Voxels from a to b (voxel units), each step face to face with the last."""
    n = max(2, int(math.ceil(max(abs(b[j] - a[j]) for j in range(3)))) * 2)
    last = None
    for s in range(n + 1):
        t = s / n
        v = tuple(math.floor(a[j] + (b[j] - a[j]) * t) for j in range(3))
        if last is not None:
            cur = list(last)
            for j in range(3):
                if cur[j] != v[j]:
                    cur[j] = v[j]
                    cells[tuple(cur)] = col
        cells[v] = col
        last = v


def _eye_info(c):
    """(left eye voxels, right eye voxels, eyes part) from the eyes part."""
    e = _find(c, 'eyes')
    if e is None or not e.v:
        return [], [], e
    return [p for p in e.v if p[0] < 0], [p for p in e.v if p[0] >= 0], e


def _clear_eyes(c, head):
    """Fills the holes the eyes were cut into with the head's colour, and
    empties the eyes part. Returns the old eye voxels."""
    e = _find(c, 'eyes')
    if e is None:
        return []
    old = list(e.v)
    hc = _main(head)
    for p in old:
        head.put(p, hc)
    e.v = {}
    return old


def _head_frame(head):
    lo, hi = _bb(head.v)
    cz = (lo[2] + hi[2]) / 2
    yc = sum(p[1] for p in head.v) / len(head.v)
    top = hi[2]
    xs = [p[0] for p in head.v if p[2] >= top - 2]
    half = (max(xs) - min(xs) + 1) / 2
    return lo, hi, cz, yc, top, half


# ------------------------------------------------------------ mammals

def ears(c, H, color, color2=None, a=None):
    """New ears in color: style round, tiny, rimmed or folded (see above)."""
    k = H / 10.0
    a = a or {}
    col = _rgb(color)
    second = _rgb(color2)
    head = _find(c, 'head')
    if head is None or not head.v:
        return
    old = _find(c, 'ears')
    ep = old if old is not None else c.part('ears', 'static', head.pivot)
    ep.v = {}
    lo, hi, cz, yc, top, half = _head_frame(head)
    style = a.get('style', 'round')
    # never over the eyes or any other part
    taken = set().union(*[set(p.v) for p in c.parts if p is not ep])
    back = [p for p in head.v if p[2] >= top - 1]
    yb = sum(p[1] for p in back) / len(back)
    if style in ('round', 'tiny'):
        r = (0.35 if style == 'tiny' else float(a.get('size', 0.6))) * k
        r = max(1.0, r)
        cx = max(1.0, half - (0.1 if style == 'tiny' else 0.25) * k)
        cy = yb + (0.4 * k if style == 'tiny' else 0.1 * k)
        cz_e = top + (0.0 if style == 'tiny' else 0.15 * k)
        if a.get('top'):  # set up on top of the head, not at its sides
            cx = max(1.0, half * 0.55)
            cz_e = top + 0.4 * k
        cells = {}
        for x in range(0, math.ceil(cx + r) + 1):
            for y in range(math.floor(cy - r), math.ceil(cy + r) + 1):
                for z in range(top - 1, math.ceil(cz_e + r) + 1):
                    d = ((x + .5 - cx) / r) ** 2 + ((y + .5 - cy) / max(0.6, 0.35 * k)) ** 2 + ((z + .5 - cz_e) / r) ** 2
                    if d <= 1 and (x, y, z) not in taken and (_mx(x), y, z) not in taken:
                        cells[(x, y, z)] = col
        if second:
            fy = {}
            for (x, y, z) in cells:
                fy[(x, z)] = min(fy.get((x, z), y), y)
            for (x, z), y in fy.items():
                if z <= cz_e + r * 0.4 and abs(x + .5 - cx) < r * 0.6:
                    cells[(x, y, z)] = second
        for (x, y, z), cc in cells.items():
            _sym(ep, x, y, z, cc)
    elif style == 'rimmed':
        # a red panda's: big rounded triangles, rust behind, a white rim
        # and a dark middle on the front
        rim = second or WHITE
        inner = _dark(col, 0.55)
        cx = max(1.0, half - 0.45 * k)
        h = max(3, round(1.3 * k))
        w0 = max(2, round(0.75 * k))
        yf = math.floor(yb - 0.2 * k)
        depth = max(1, round(0.35 * k))
        cells = {}
        for i in range(h):
            w = max(1, round(w0 * (1 - i / h) + 0.4))
            for dx in range(-w, w):
                x = round(cx) + dx
                if x < 0:
                    continue
                for dy in range(depth):
                    edge = dx in (-w, w - 1) or i == h - 1
                    face = dy == 0
                    cells[(x, yf + dy, top + 1 + i)] = (rim if edge else inner) if face else col
        for (x, y, z), cc in cells.items():
            _sym(ep, x, y, z, cc)
    elif style == 'folded':
        # a pug's: a small flap lying on the head's top corner, its tip
        # folded down over the side, every voxel on the head's surface
        w = max(2, round(0.8 * k))
        yf = math.floor(min(p[1] for p in back)) + max(0, round(0.2 * k))
        x0 = max(1, round(half - 0.9 * k))
        cells = {}
        for y in range(yf, yf + w):
            outer = None
            for x in range(x0, x0 + w + 1):
                zs = [p[2] for p in head.v if p[0] == x and p[1] == y]
                if not zs:
                    break
                cells[(x, y, max(zs) + 1)] = col
                outer = (x, max(zs))
            if outer:
                x, zt_ = outer
                for z in range(zt_ - max(1, round(0.6 * k)), zt_ + 1):
                    xs = [p[0] for p in head.v if p[1] == y and p[2] == z and p[0] >= 0]
                    if xs:
                        cells[(max(xs) + 1, y, z)] = col
        for (x, y, z), cc in cells.items():
            _sym(ep, x, y, z, cc)
    for p in [p for p in ep.v if p in taken]:
        del ep.v[p]


def muzzle(c, H, color, color2=None, a=None):
    """A muzzle out from the face, below the eyes (see the module doc)."""
    k = H / 10.0
    a = a or {}
    if not _fine(c) and a.get('coarse') is False:
        return  # left off the in-game boxes, to keep them in budget
    col = _rgb(color)
    nose = _rgb(color2, INK)
    head = _find(c, 'head')
    if head is None or not head.v:
        return
    le, re_, e = _eye_info(c)
    lo, hi, cz, yc, top, half = _head_frame(head)
    ez = min(p[2] for p in le + re_) if le or re_ else round(cz)
    zt = ez - 1 + round(float(a.get('up', 0)) * k)
    hh = max(2, round(float(a.get('h', 0.9)) * k))
    z0 = max(lo[2], zt - hh + 1)
    hw = max(1, round(float(a.get('w', 0.9)) * k))
    dd = max(1, round(float(a.get('d', 0.8)) * k))
    taper = float(a.get('taper', 0.2)) * k
    fronts = {(x, z): head.front(x, z) for x in range(0, hw) for z in range(z0, zt + 1)}
    known = [f[1] for f in fronts.values() if f]
    fmin = min(known) if known else lo[1]
    tip_y = fmin - dd
    for (x, z), f in fronts.items():
        back = f[1] if f else fmin + 1
        for y in range(tip_y, back + 1):
            t = (fmin - y) / max(1, dd)  # 0 at the face, 1 at the tip
            w = hw - round(taper * max(0.0, t))
            if x >= w:
                continue
            # round the outer front corners
            if y == tip_y and x == w - 1 and z in (z0, zt) and w >= 2:
                continue
            _sym(head, x, y, z, col)
    # the nose: on top of the front, ink or color2
    nw, nh = a.get('nose', [max(1, round(0.4 * k)), max(1, round(0.35 * k))])
    for x in range(nw):
        for dz in range(nh):
            ys = [p[1] for p in head.v if p[0] == x and p[2] == zt - dz]
            if ys:
                _sym(head, x, min(ys), zt - dz, nose)
    if a.get('wrinkle') and _fine(c):
        fold = _dark(_main(head), 0.25)
        for x in range(0, hw):
            f = head.front(x, zt)
            if f and head.v[f][0] == col:
                _sym(head, x, f[1] + 1, zt + 1, fold) if (x, f[1] + 1, zt + 1) in head.v else None
            g = head.front(x, zt + 1)
            if g and x < max(1, hw - 1):
                _sym(head, x, g[1], zt + 1, fold)
    if a.get('smile') and _fine(c):
        zm = z0
        for x in range(0, max(1, hw - 1)):
            f = head.front(x, zm)
            if f:
                _sym(head, x, f[1], zm, INK)
        x = max(1, hw - 1)
        f = head.front(x, zm + 1)
        if f:
            _sym(head, x, f[1], zm + 1, INK)


def ruff(c, H, color, color2=None, a=None):
    """A ring of fluffy fur around the face; color2 paints the face inside."""
    k = H / 10.0
    a = a or {}
    col = _rgb(color)
    face = _rgb(color2)
    head = _find(c, 'head')
    if head is None or not head.v:
        return
    lo, hi, cz, yc, top, half = _head_frame(head)
    rx = (hi[0] - lo[0] + 1) / 2 * float(a.get('size', 1.0))
    rz = (hi[2] - lo[2] + 1) / 2 * float(a.get('size', 1.0))
    fy = lo[1]
    ry = fy + max(1, round(0.7 * k))
    r = max(1.5, float(a.get('thick', 0.85)) * k)
    mane = _find(c, 'mane')
    if mane is not None:
        mane.v = {}  # the ruff replaces the plan's mane strip
    rp = c.part('ruff', 'static', head.pivot)
    cells = set()
    n = 36 if _fine(c) else 0  # the in-game boxes keep to their budget: no ruff there
    for i in range(n):
        ang = i / n * 2 * math.pi
        px, pz = math.cos(ang) * rx, cz + .5 + math.sin(ang) * rz
        if px < -0.5:
            continue
        for x in range(0, math.ceil(px + r) + 1):
            for y in range(math.floor(ry - r), math.ceil(ry + r * 1.6) + 1):
                for z in range(math.floor(pz - r), math.ceil(pz + r) + 1):
                    if ((x + .5 - px) / r) ** 2 + ((y + .5 - ry) / (r * 1.3)) ** 2 + ((z + .5 - pz) / r) ** 2 <= 1 \
                            and y >= fy + 1 and z >= 0:
                        cells.add((x, y, z))
    shade = _dark(col, 0.12)
    for (x, y, z) in cells:
        if (x, y, z) in head.v:
            continue
        tuft = (x * 3 + z * 5 + y) % 4 == 0
        _sym(rp, x, y, z, shade if tuft and _fine(c) else col)
    if face:
        le, re_, e = _eye_info(c)
        for p, (cc, g) in list(head.v.items()):
            if p[1] <= fy + max(1, round(0.6 * k)) and ((p[0] + .5) / rx) ** 2 + ((p[2] + .5 - cz) / rz) ** 2 < 0.62:
                head.v[p] = (face, g)


def big_eyes(c, H, color=None, color2=None, a=None):
    """Bigger round eyes with a glint; color, when given, rings them."""
    k = H / 10.0
    a = a or {}
    ring = _rgb(color) if a.get('ring') else None
    head = _find(c, 'head')
    if head is None or not head.v:
        return
    le, re_, e = _eye_info(c)
    if not le:
        return
    lx = sum(p[0] for p in le) / len(le)
    lz = sum(p[2] for p in le) / len(le)
    _clear_eyes(c, head)
    e = c.part('eyes', 'blink', head.pivot)
    s = max(2, round(float(a.get('size', 0.9)) * k)) if _fine(c) else max(1, round(float(a.get('size', 0.9)) * k))
    cx = -lx - 1 + float(a.get('out', 0)) * k  # the right eye's centre (x >= 0)
    cz = lz + float(a.get('up', 0)) * k
    x0 = max(0, round(cx - s / 2 + .5))
    z0 = round(cz - s / 2 + .5)

    def cut(x, z, col):
        f = head.front(x, z)
        if f:
            del head.v[f]
            e.put(f, col)
            g = head.front(_mx(x), z)
            if g:
                del head.v[g]
                e.put(g, col)

    for dx in range(s):
        for dz in range(s):
            corner = s >= 3 and dx in (0, s - 1) and dz in (0, s - 1)
            if corner:
                continue
            glint = s >= 2 and dz == s - 1 and dx == (1 if s >= 3 else 0)
            cut(x0 + dx, z0 + dz, WHITE if glint else INK)
    if ring and _fine(c):
        for dx in range(-1, s + 1):
            for dz in range(-1, s + 1):
                if 0 <= dx < s and 0 <= dz < s:
                    continue
                if dx in (-1, s) and dz in (-1, s):
                    continue
                x = x0 + dx
                if x < 0:
                    continue
                f = head.front(x, z0 + dz)
                if f:
                    _sym(head, x, f[1], z0 + dz, ring)
    if a.get('small_pair'):
        # two small eyes beside and above the big pair
        ss = max(1, round(0.4 * k))
        for dx in range(ss):
            for dz in range(ss):
                cut(x0 + s + 1 + dx, z0 + s - ss + 1 + dz, INK)


def stripe(c, H, color, color2=None, a=None):
    """A stripe along the top midline of head, body and tail."""
    k = H / 10.0
    if not _fine(c):
        return  # detail for the meshes; the in-game boxes keep to their budget
    col = _rgb(color)
    head = _find(c, 'head')
    fy = min(p[1] for p in head.v) if head is not None and head.v else -999
    eyes_top = max((p[2] for p in _find(c, 'eyes').v), default=0) if _find(c, 'eyes') else 0
    for name in ('head', 'body', 'tail'):
        part = _find(c, name)
        if part is None or not part.v:
            continue
        tops = {}
        for (x, y, z) in part.v:
            if x in (-1, 0):
                tops[(x, y)] = max(tops.get((x, y), -1), z)
        for (x, y), z in tops.items():
            if name == 'head' and (y < fy + round(0.5 * k) or z <= eyes_top):
                continue
            part.v[(x, y, z)] = (col, False)


def membrane(c, H, color, color2=None, a=None):
    """A gliding skin along each side between front and back legs."""
    k = H / 10.0
    if not _fine(c):
        return  # detail for the meshes; the in-game boxes keep to their budget
    col = _rgb(color)
    edge = _rgb(color2, col)
    body = _find(c, 'body')
    if body is None or not body.v:
        return
    zs = [p[2] for p in body.v]
    feet = [p for p in body.v if p[2] == 0]
    if not feet:
        return
    fy0, fy1 = min(p[1] for p in feet), max(p[1] for p in feet)
    leg_top = max(p[2] for p in body.v if p[2] <= round(1.7 * k) and abs(p[0] + .5) > 0) if zs else 0
    z_lo = max(leg_top + 1, round(1.8 * k))
    z_hi = z_lo + max(1, round(0.7 * k))
    w = max(1, round(0.5 * k))
    mp = c.part('membrane', 'static')
    for y in range(fy0, fy1 + 1):
        for z in range(z_lo, z_hi + 1):
            xs = [p[0] for p in body.v if p[1] == y and p[2] == z and p[0] >= 0]
            if not xs:
                continue
            xo = max(xs)
            for i in range(1, w + 1):
                last = i == w
                _sym(mp, xo + i, y, z, edge if last else col)


def tear_marks(c, H, color, color2=None, a=None):
    """A line down from the inside corner of each eye."""
    k = H / 10.0
    col = _rgb(color)
    head = _find(c, 'head')
    le, re_, e = _eye_info(c)
    if head is None or not re_:
        return
    xin = min(p[0] for p in re_)
    zb = min(p[2] for p in re_)
    n = max(2, round(1.0 * k))
    for i in range(1, n + 1):
        f = head.front(xin, zb - i)
        if f:
            _sym(head, xin, f[1], zb - i, col)


def claw_arms(c, H, color, color2=None, a=None):
    """The front legs become long arms reaching to the ground ahead, with
    hooked claws (color2)."""
    k = H / 10.0
    if not _fine(c):
        return  # detail for the meshes; the in-game boxes keep to their budget
    col = _rgb(color)
    claw = _rgb(color2, hexc('#F2E6C8'))
    body = _find(c, 'body')
    if body is None or not body.v:
        return
    feet = [p for p in body.v if p[2] == 0 and p[0] >= 0]
    if not feet:
        return
    ymid = (min(p[1] for p in feet) + max(p[1] for p in feet)) / 2
    front = [p for p in feet if p[1] < ymid]
    cols_ = {(p[0], p[1]) for p in front}
    belly = round(float((a or {}).get('cut', 2.0)) * k)
    for (x, y) in cols_:
        for z in range(0, belly):
            body.v.pop((x, y, z), None)
            body.v.pop((_mx(x), y, z), None)
    fx = sum(x for x, _ in cols_) / len(cols_)
    fyy = sum(y for _, y in cols_) / len(cols_)
    sh = (fx - 0.2 * k, fyy + 0.2 * k, belly + 0.8 * k)
    hand = (fx + 0.5 * k, fyy - 1.8 * k, 0.3 * k)
    w = max(1, round(0.5 * k))
    cells = {}
    path = {}
    _rod(path, sh, hand, col)
    for (x, y, z) in path:
        for dx in range(w + 1):
            for dz in range(w):
                cells[(x + dx, y, z + dz)] = col
    hx, hy = math.floor(hand[0]), math.floor(hand[1])
    # hooked claws: two long claws reaching forward along the ground
    n = max(2, round(1.0 * k))
    for cx in (hx, hx + w):
        for i in range(1, n + 1):
            cells[(cx, hy - i, 0)] = claw
        cells[(cx, hy - n - 1, 0)] = claw
        cells[(cx, hy - n - 1, 1)] = claw  # the hook
    for (x, y, z), cc in cells.items():
        if z >= 0:
            _sym(body, x, y, z, cc)


def ring_tail(c, H, color, color2=None, a=None):
    """A long tail held up in a question mark, ringed in color and color2."""
    k = H / 10.0
    a = a or {}
    c1 = _rgb(color)
    c2 = _rgb(color2, INK)
    body = _find(c, 'body')
    if body is None or not body.v:
        return
    old = _find(c, 'tail')
    tl = old if old is not None else c.part('tail', 'static')
    tl.v = {}
    lo, hi = _bb(body.v)
    yb = hi[1] - 0.6 * k
    zb = lo[2] + (hi[2] - lo[2]) * 0.62
    tl.pivot = (0, yb, zb)
    pts = [(0.0, 0.0), (1.1, 0.5), (1.7, 1.8), (1.8, 3.4), (1.5, 4.7), (0.8, 5.4), (0.2, 5.2)]
    sc = float(a.get('length', 1.0))
    r = max(0.6, float(a.get('thick', 0.5)) * k)
    band = max(1, round(0.45 * k)) if _fine(c) else 3
    dist = 0.0
    prev = None
    for i in range(len(pts) - 1):
        (y0, z0), (y1, z1) = pts[i], pts[i + 1]
        seg = math.hypot(y1 - y0, z1 - z0) * k * sc
        steps = max(2, round(seg * 2))
        for s in range(steps):
            t = s / steps
            y = yb + (y0 + (y1 - y0) * t) * k * sc
            z = zb + (z0 + (z1 - z0) * t) * k * sc
            if prev is not None:
                dist += math.hypot(y - prev[0], z - prev[1])
            prev = (y, z)
            cc = c1 if int(dist / band) % 2 == 0 else c2
            for x in range(0, math.ceil(r)):
                for yy in range(math.floor(y - r), math.ceil(y + r) + 1):
                    for zz in range(math.floor(z - r), math.ceil(z + r) + 1):
                        if ((x + .5) / r) ** 2 + ((yy + .5 - y) / r) ** 2 + ((zz + .5 - z) / r) ** 2 <= 1.0:
                            if (x, yy, zz) not in tl.v:
                                _sym(tl, x, yy, zz, cc)
    # a thick ink tip
    if prev:
        for x in range(0, max(1, math.ceil(r))):
            _sym(tl, x, math.floor(prev[0]), math.floor(prev[1]), c2)


def poms(c, H, color, color2=None, a=None):
    """Pom-poms: a topknot, on each ear tip, the tail tip and each ankle."""
    k = H / 10.0
    col = _rgb(color)
    r = max(1.5, 0.95 * k)
    head = _find(c, 'head')
    body = _find(c, 'body')
    pp = c.part('poms', 'static', head.pivot if head is not None else (0, 0, 0))

    def ball(part, cx, cy, cz, rr):
        for x in range(0, math.ceil(cx + rr) + 1):
            for y in range(math.floor(cy - rr), math.ceil(cy + rr) + 1):
                for z in range(max(0, math.floor(cz - rr)), math.ceil(cz + rr) + 1):
                    if ((x + .5 - cx) / rr) ** 2 + ((y + .5 - cy) / rr) ** 2 + ((z + .5 - cz) / rr) ** 2 <= 1:
                        _sym(part, x, y, z, col)

    if head is not None and head.v:
        lo, hi, cz, yc, top, half = _head_frame(head)
        ball(pp, -0.5, yc, top + 0.4 * k, r * 1.2)
    ears_p = _find(c, 'ears')
    if ears_p is not None and ears_p.v:
        right = [p for p in ears_p.v if p[0] >= 0]
        zl = min(p[2] for p in right)
        low = [p for p in right if p[2] <= zl + 1]
        ball(ears_p, sum(p[0] for p in low) / len(low) + .5, sum(p[1] for p in low) / len(low) + .5, zl + 0.2 * k, r * 0.9)
    tail = _find(c, 'tail')
    if tail is not None and tail.v:
        far = max(tail.v, key=lambda p: (p[1], p[2]))
        ball(tail, -0.5, far[1] + .5, far[2] + .5, r)
        # keep the pom on the centre line (ball() mirrors from x = 0)
    if body is not None and body.v and _fine(c):
        zk = max(1, round(0.5 * k))
        foot = [p for p in body.v if p[2] == 0 and p[0] >= 0]
        if foot:
            ymid = (min(p[1] for p in foot) + max(p[1] for p in foot)) / 2
            for half_ in (lambda p: p[1] < ymid, lambda p: p[1] >= ymid):
                f = [p for p in foot if half_(p)]
                if f:
                    fx = sum(p[0] for p in f) / len(f) + .5
                    fy_ = sum(p[1] for p in f) / len(f) + .5
                    ball(body, fx, fy_, zk + 0.3, r * 0.85)


def symmetry(c, H, color=None, color2=None, a=None):
    """Mirrors the right side onto the left where a plan's rounding left
    them a voxel apart: `parts` lists "wings" (wingL from wingR) and/or
    "legs" (the body's low leg voxels, up to `z` in k, default 1.7), or "all"
    (every part)."""
    k = H / 10.0
    a = a or {}
    which = a.get('parts', ['wings', 'legs'])
    if 'all' in which:
        # every part's left half from its right; a left part from its right twin
        byname = {p.name: p for p in c.parts}
        for p in c.parts:
            if p.name.endswith('L') and p.name[:-1] + 'R' in byname:
                r = byname[p.name[:-1] + 'R']
                p.v = {(_mx(x), y, z): v for (x, y, z), v in r.v.items()}
                p.pivot = (-r.pivot[0], r.pivot[1], r.pivot[2])
            elif not p.name.endswith('R'):
                right = {q: v for q, v in p.v.items() if q[0] >= 0}
                p.v = dict(right)
                for (x, y, z), v in right.items():
                    p.v[(_mx(x), y, z)] = v
        return
    if 'wings' in which:
        wl, wr = _find(c, 'wingL'), _find(c, 'wingR')
        if wl is not None and wr is not None and wr.v:
            wl.v = {(_mx(x), y, z): v for (x, y, z), v in wr.v.items()}
            wl.pivot = (-wr.pivot[0], wr.pivot[1], wr.pivot[2])
    if 'legs' in which:
        body = _find(c, 'body')
        if body is not None and body.v:
            zt = round(float(a.get('z', 1.7)) * k)
            low = {p: v for p, v in body.v.items() if p[2] <= zt}
            for p in [p for p in low if p[0] < 0]:
                del body.v[p]
            for (x, y, z), v in low.items():
                if x >= 0:
                    body.v[(_mx(x), y, z)] = v


# --------------------------------------------------------------- birds

BEAKS = {
    # per layer outward from the face: (half width, z low, z high) about
    # the beak's centre row
    'pointed': [(1, -1, 0), (1, 0, 0)],
    'cone': [(1, -1, 0), (1, -1, 0), (1, 0, 0)],
    'hooked': [(1, -1, 1), (1, -1, 1), (1, -2, 0), (1, -2, -1)],
    # a parrot's small hook: short, curling down at the tip
    'small_hook': [(1, -1, 1), (1, -2, 0)],
}


def beak(c, H, color, color2=None, a=None):
    """The beak redrawn in color: pointed, cone, hooked, long, dagger or
    pouch (see the module doc)."""
    k = H / 10.0
    a = a or {}
    col = _rgb(color)
    head = _find(c, 'head')
    if head is None or not head.v:
        return
    tip = min(head.v, key=lambda p: (p[1], -abs(p[0] + .5)))
    bcol = head.v[tip][0]
    yc = sum(p[1] for p in head.v) / len(head.v)
    old = [p for p, (cc, g) in head.v.items() if cc == bcol and p[1] < yc]
    if bcol == _main(head) or not old:
        return
    zc = round(sum(p[2] for p in old) / len(old) + (0.5 if len({p[2] for p in old}) % 2 == 0 else 0))
    for p in old:
        del head.v[p]
    # fill the holes the old beak leaves in the face: a removed voxel with
    # head behind it and head (or old beak) on all four sides was face
    hc = _main(head)
    gone = set(old)
    for _ in range(2):
        for (x, y, z) in list(gone):
            near = head.v.keys() | gone
            if (x, y + 1, z) in head.v and all(q in near for q in ((x - 1, y, z), (x + 1, y, z), (x, y, z - 1), (x, y, z + 1))):
                head.put((x, y, z), hc)
                gone.discard((x, y, z))
    f = head.front(0, zc) or head.front(0, zc - 1)
    if not f:
        return
    fy = f[1]
    style = a.get('style', 'pointed')
    fine = _fine(c)
    if style in BEAKS:
        layers = BEAKS[style]
    else:
        n = max(3, round(float(a.get('len', {'long': 1.8, 'dagger': 2.4, 'pouch': 2.4}.get(style, 1.8))) * k))
        if style == 'long':
            layers = [(1, -1, 0)] + [(1, 0, 0)] * (n - 1)
        elif style == 'dagger':
            layers = [(1, -1, 0), (1, -1, 0)] + [(1, -1, 0) if i < n // 2 else (1, 0, 0) for i in range(n - 2)]
        else:  # pouch
            layers = [(1, 0, 0)] * n
    if not fine:
        layers = [(lw, 0, 0) for (lw, zl, zh) in layers[:max(1, len(layers) // 2)]]
    for i, (lw, zl, zh) in enumerate(layers):
        y = fy - 1 - i
        for x in range(lw):
            for z in range(zc + zl, zc + zh + 1):
                _sym(head, x, y, z, col)
        # fill behind, back into the face, so the beak is attached
        if i == 0:
            for x in range(lw):
                for z in range(zc + zl, zc + zh + 1):
                    yy = y + 1
                    while (x, yy, z) not in head.v and yy < fy + 3:
                        _sym(head, x, yy, z, col)
                        yy += 1
    if style == 'pouch':
        pouch = _rgb(color2, _dark(col, 0.1))
        n = len(layers)
        for i in range(1, n - 1):
            depth = max(1, round(min(i, n - 1 - i) * (0.9 if fine else 0.3)))
            for dz in range(1, depth + 1):
                _sym(head, 0, fy - 1 - i, zc - dz, pouch)


def cheeks(c, H, color, color2=None, a=None):
    """A round patch on each cheek: on the side of the head, just behind
    and below the eye, clear of the beak (`size`, `down`, `back` in k)."""
    k = H / 10.0
    a = a or {}
    col = _rgb(color)
    head = _find(c, 'head')
    le, re_, e = _eye_info(c)
    if head is None or not re_:
        return
    ex = max(p[0] for p in re_)
    ey = min(p[1] for p in re_)
    ez = min(p[2] for p in re_)
    cy = ey + float(a.get('back', 0.9)) * k
    cz = ez - float(a.get('down', 0.4)) * k
    r = max(1.2, float(a.get('size', 0.65)) * k)
    hc = _main(head)
    # the side surface: the outermost voxel of each (y, z) row, and the
    # one just inside it
    side = {}
    for (x, y, z) in head.v:
        if x >= 0:
            side[(y, z)] = max(side.get((y, z), x), x)
    for (y, z), xo in side.items():
        if ((y + .5 - cy) / r) ** 2 + ((z + .5 - cz) / r) ** 2 > 1:
            continue
        for x in (xo, xo - 1):
            if x <= ex:
                continue
            for q in ((x, y, z), (_mx(x), y, z)):
                if q in head.v and head.v[q][0] in (hc, BLUSH):
                    head.v[q] = (col, head.v[q][1])


def face(c, H, color, color2=None, a=None):
    """The face and throat painted color, from the eyes down."""
    k = H / 10.0
    a = a or {}
    col = _rgb(color)
    head = _find(c, 'head')
    if head is None or not head.v:
        return
    hc = _main(head)
    lo, hi, cz, yc, top, half = _head_frame(head)
    cut = yc - float(a.get('back', 0.3)) * k
    zt = top - float(a.get('below', 0.5)) * k
    for p, (cc, g) in list(head.v.items()):
        if cc == hc and p[1] < cut and p[2] < zt:
            head.v[p] = (col, g)


def hood(c, H, color, color2=None, a=None):
    """The head painted color above a ring of color2 (a drake's collar)."""
    k = H / 10.0
    a = a or {}
    col = _rgb(color)
    ring = _rgb(color2, WHITE)
    head = _find(c, 'head')
    body = _find(c, 'body')
    le, re_, e = _eye_info(c)
    if head is None or not head.v:
        return
    ez = min(p[2] for p in le + re_) if le or re_ else round(sum(p[2] for p in head.v) / len(head.v))
    zn = ez - round(float(a.get('depth', 1.2)) * k)
    w = max(1, round(0.3 * k))
    hc = _main(head)
    for part in (head, body):
        if part is None:
            continue
        for p, (cc, g) in list(part.v.items()):
            if part is head and p[2] >= zn + w and cc == hc:
                part.v[p] = (col, g)
            elif zn <= p[2] < zn + w and (part is head or p[1] < 0):
                if cc in (hc, _main(body) if body is not None else None) or part is head:
                    if part is head and cc != hc:
                        continue
                    part.v[p] = (ring, g)


def throat_bars(c, H, color, color2=None, a=None):
    """Bars across the throat and upper breast: rows of color and color2
    (default white), on the front below the beak."""
    k = H / 10.0
    col = _rgb(color)
    pale = _rgb(color2, WHITE)
    head = _find(c, 'head')
    body = _find(c, 'body')
    le, re_, e = _eye_info(c)
    if head is None or not re_:
        return
    ez = min(p[2] for p in re_)
    z1 = ez - max(3, round(1.9 * k))
    z0 = z1 - max(3, round(1.6 * k))
    for part in (head, body):
        if part is None or not part.v:
            continue
        front = {}
        ey = min(p[1] for p in re_)
        for (x, y, z) in part.v:
            if part is head and y < ey:
                continue  # the beak, not the throat
            if abs(x + .5) <= float((a or {}).get('w', 1.0)) * k and z0 <= z <= z1:
                front[(x, z)] = min(front.get((x, z), y), y)
        for (x, z), y in front.items():
            for dy in (0, 1):
                q = (x, y + dy, z)
                if q in part.v and part.v[q][0] != INK:
                    part.v[q] = (col if (z1 - z) % 2 == 1 else pale, False)


def plume(c, H, color, color2=None, a=None):
    """One or two thin feathers trailing back from the crown."""
    k = H / 10.0
    col = _rgb(color)
    head = _find(c, 'head')
    if head is None or not head.v:
        return
    lo, hi, cz, yc, top, half = _head_frame(head)
    crown = [p for p in head.v if p[2] == top]
    yb = max(p[1] for p in crown)
    pp = c.part('plume', 'static', head.pivot)
    n = max(3, round(1.6 * k))
    for i in range(n):
        y = yb + i
        z = top + 1 + (1 if i >= n // 2 else 0) - (1 if i == n - 1 else 0)
        pp.put((-1, y, z), col)
        pp.put((0, y, z), col)
        if i < n // 2:
            pp.put((-1, y, z - 1), col) if z - 1 > top else None
            pp.put((0, y, z - 1), col) if z - 1 > top else None


# ------------------------------------------------------------ legs

def lift(c, d, toes=False):
    """Stands the creature d voxels taller: every part goes up, and every
    leg part grows down to the ground again. A cell on a leg's bottom layer
    with leg above it becomes a column to the ground; with `toes`, a cell
    with nothing above it (a bird's toe) stays flat on the ground."""
    if d <= 0:
        return
    for p in c.parts:
        p.v = {(x, y, z + d): v for (x, y, z), v in p.v.items()}
        p.pivot = (p.pivot[0], p.pivot[1], p.pivot[2] + d)
    for p in c.parts:
        if not p.name.startswith('leg') or not p.v:
            continue
        zb = min(q[2] for q in p.v)
        bottom = [q for q in p.v if q[2] == zb]
        for (x, y, z) in bottom:
            v = p.v[(x, y, z)]
            above = (x, y, z + 1) in p.v
            if toes and not above:
                del p.v[(x, y, z)]
                p.v[(x, y, z - d)] = v
                continue
            for zz in range(z - d, z):
                p.v[(x, y, zz)] = v


def lift_legs(c, H, color=None, color2=None, a=None):
    """Taller on longer legs: `by` (in k, default 0.8), `toes` for birds."""
    k = H / 10.0
    a = a or {}
    if not any(p.name.startswith('leg') for p in c.parts):
        return
    lift(c, max(1, round(float(a.get('by', 0.8)) * k)), bool(a.get('toes')))


# --------------------------------------------------------------- bugs

def fold_wings(c, H, color, color2=None, a=None):
    """The wings folded shut, standing together over the back."""
    k = H / 10.0
    col = _rgb(color)
    spot = _rgb(color2, _dark(col, 0.6))
    body = _find(c, 'body')
    if body is None or not body.v:
        return
    lo, hi = _bb(body.v)
    head = _find(c, 'head')
    yf = (max(p[1] for p in head.v) if head is not None and head.v else lo[1]) + 1
    thorax = [p for p in body.v if p[1] <= yf + round(1.2 * k)]
    zt = max(p[2] for p in thorax) + 1
    length = max(4, round(float((a or {}).get('length', 3.6)) * k))
    tall = max(2, round(0.7 * k))
    for sx, name in ((-1, 'wingL'), (1, 'wingR')):
        old = _find(c, name)
        wp = old if old is not None else c.part(name, name, (sx * 0.5 * k, yf, zt))
        wp.v = {}
        wp.pivot = (sx * 0.5, yf + 0.5, zt)
        x = 0 if sx > 0 else -1
        for i in range(length):
            y = yf + i
            rise = i * 0.25
            h = tall if i < length - 1 else max(1, tall - 1)
            for dz in range(h):
                z = round(zt + rise) + dz
                tipspot = i >= length - max(2, round(0.5 * k)) and dz == h - 1
                wp.put((x, y, z), spot if tipspot else col)
            # keep each step touching the last
            if i and round(zt + rise) > round(zt + (i - 1) * 0.25):
                wp.put((x, y, round(zt + rise) - 1), col)


def leaf(c, H, color, color2=None, a=None):
    """A big cut leaf held in the jaws, standing up over the back."""
    k = H / 10.0
    col = _rgb(color)
    vein = _rgb(color2, _dark(col, 0.3))
    head = _find(c, 'head')
    body = _find(c, 'body')
    if head is None or body is None or not head.v:
        return
    lo, hi = _bb(list(body.v) + list(head.v))
    hf = min(p[1] for p in head.v)
    htop = max(p[2] for p in head.v)
    lp = c.part('leaf', 'static', head.pivot)
    # the stem from the jaws, up
    stem_y = hf + max(1, round(0.4 * k))
    cy = (hf + hi[1]) / 2
    cz = hi[2] + 1.8 * k
    ry, rz = (hi[1] - hf) / 2 + 0.4 * k, 1.6 * k
    base_z = htop
    for z in range(base_z, round(cz - rz) + 2):
        for x in (-1, 0):
            lp.put((x, stem_y, z), vein)
    for y in range(math.floor(cy - ry), math.ceil(cy + ry) + 1):
        for z in range(math.floor(cz - rz), math.ceil(cz + rz) + 1):
            d = ((y + .5 - cy) / ry) ** 2 + ((z + .5 - cz) / rz) ** 2
            # a bite taken out of the top back edge (a cut leaf)
            bite = ((y + .5 - (cy + ry * 0.55)) / (ry * 0.35)) ** 2 + ((z + .5 - (cz + rz * 0.8)) / (rz * 0.45)) ** 2 < 1
            if d <= 1 and not bite:
                on_vein = abs(z + .5 - (cz - (y + .5 - cy) * 0.15)) < 0.6
                for x in (-1, 0):
                    lp.put((x, y, z), vein if on_vein and _fine(c) else col)
    # join the leaf to the stem
    zb = min(z for (x, y, z) in lp.v if y == stem_y and z > base_z + 1) if any(
        y == stem_y and z > base_z + 1 for (x, y, z) in lp.v) else base_z
    for z in range(base_z, zb + 1):
        for x in (-1, 0):
            lp.v.setdefault((x, stem_y, z), (vein, False))


def mandibles(c, H, color, color2=None, a=None):
    """Big antler jaws reaching forward from the head, each with a tine."""
    k = H / 10.0
    col = _rgb(color)
    head = _find(c, 'head')
    if head is None or not head.v:
        return
    lo, hi, cz, yc, top, half = _head_frame(head)
    # drop the little horn: anything in this colour standing above the head
    for p, (cc, g) in list(head.v.items()):
        if cc == col and p[1] < yc and p[2] > cz:
            del head.v[p]
    lo, hi, cz, yc, top, half = _head_frame(head)
    fy = lo[1]
    z0 = cz + 0.2 * k
    cells = {}
    # each jaw (drawn on the right, mirrored): out and forward, then curving
    # in to a tip, with a tine pointing inward; the tips stay apart
    base = (0.9 * k, fy + 0.8 * k, z0)
    out = (1.8 * k, fy - 1.0 * k, z0 + 0.3 * k)
    tip = (1.05 * k, fy - 2.4 * k, z0 + 0.6 * k)
    _rod(cells, base, out, col)
    _rod(cells, out, tip, col)
    _rod(cells, (1.75 * k, fy - 0.7 * k, z0 + 0.3 * k), (1.15 * k, fy - 0.9 * k, z0 + 0.3 * k), col)
    mp = c.part('mandibles', 'static', head.pivot)
    xmin = max(1, math.floor(0.95 * k))
    for (x, y, z), cc in cells.items():
        x = max(x, xmin)
        _sym(mp, x, y, z, cc)
        if _fine(c):
            _sym(mp, x, y, z + 1, cc)


def feelers(c, H, color, color2=None, a=None):
    """Short thin antennae instead of the head's tall ink ones; color2, when
    given, paints a stripe over the head."""
    k = H / 10.0
    col = _rgb(color)
    head = _find(c, 'head')
    if head is None or not head.v:
        return
    lo, hi, cz, yc, top, half = _head_frame(head)
    for p, (cc, g) in list(head.v.items()):
        if cc == INK and p[2] > cz:
            del head.v[p]
    lo, hi, cz, yc, top, half = _head_frame(head)
    fy = min(p[1] for p in head.v if p[2] >= top - 1)
    x = max(1, round(0.5 * k))
    n = max(1, round(0.7 * k))
    for i in range(n):
        _sym(head, x, fy + 1 - i, top + 1 + i, col)
        if i:
            _sym(head, x, fy + 2 - i, top + 1 + i, col)
    if color2:
        st = _rgb(color2)
        tops = {}
        for (xx, y, z) in head.v:
            if xx in (-1, 0):
                tops[(xx, y)] = max(tops.get((xx, y), -1), z)
        for (xx, y), z in tops.items():
            if head.v[(xx, y, z)][0] != col:
                head.v[(xx, y, z)] = (st, False)


def chameleon(c, H, color, color2=None, a=None):
    """A tall casque, turret eyes on the sides, a tail rolled in a spiral."""
    k = H / 10.0
    cq_col = _rgb(color)
    head = _find(c, 'head')
    if head is None or not head.v:
        return
    hc = _main(head)
    turret = _rgb(color2, hc)
    fine = _fine(c)
    lo, hi, cz, yc, top, half = _head_frame(head)
    # the casque: a tall rounded blade rising from the back of the head
    cq = c.part('crest', 'static')
    cq.v = {}
    yb = hi[1]
    h = max(2, round(2.0 * k))
    for i in range(h):
        z = top - 1 + i
        ylen = max(1, round((1.0 - i / h) * 2.4 * k))
        for y in range(yb - ylen, yb + 1):
            cq.put((-1, y, z), cq_col)
            cq.put((0, y, z), cq_col)
    # turret eyes: cones on each side, the pupil at the tip
    le, re_, e = _eye_info(c)
    if re_:
        ez = sum(p[2] for p in re_) / len(re_)
        ey = min(p[1] for p in re_) + 0.6 * k
        _clear_eyes(c, head)
        e = c.part('eyes', 'blink', head.pivot)
        xs = max(p[0] for p in head.v if abs(p[2] - ez) <= 1)
        r = max(1.0, 0.75 * k)
        cx = xs + 0.1 * k
        for x in range(0, math.ceil(cx + r) + 1):
            for y in range(math.floor(ey - r), math.ceil(ey + r) + 1):
                for z in range(math.floor(ez - r), math.ceil(ez + r) + 1):
                    if ((x + .5 - cx) / r) ** 2 + ((y + .5 - ey) / r) ** 2 + ((z + .5 - ez) / r) ** 2 <= 1:
                        if (x, y, z) not in head.v:
                            _sym(head, x, y, z, turret)
        # the pupil: the outermost voxels of the turret, toward the front
        xo = max(p[0] for p in head.v if abs(p[1] - ey) <= r and abs(p[2] - ez) <= r)
        pz = round(ez - .5)
        py = math.floor(ey - (0.3 * k if fine else 0))
        for dz in ((0, 1) if fine else (0,)):
            for dy in ((0, -1) if fine else (0,)):
                p = (xo, py + dy, pz + dz)
                head.v.pop(p, None)
                head.v.pop((_mx(p[0]), p[1], p[2]), None)
                col_ = WHITE if (fine and dz == 1 and dy == -1) else INK
                e.put(p, col_)
                e.put((_mx(p[0]), p[1], p[2]), col_)
    # the tail: out behind, then rolled down in a tight spiral
    tail = _find(c, 'tail')
    if tail is not None and tail.v:
        tc = _main(tail)
        y0 = min(p[1] for p in tail.v)
        z0 = sum(p[2] for p in tail.v if p[1] <= y0 + 1) / max(1, len([p for p in tail.v if p[1] <= y0 + 1]))
        tail.v = {}
        R0 = 1.3 * k
        cy, czz = y0 + 2.4 * k, max(R0 + 0.6, z0 - 0.2 * k)
        pts = []
        for i in range(10):  # straight out to the top of the roll
            t = i / 9
            pts.append((y0 + (cy - y0) * t, z0 + (czz + R0 - z0) * t, 0.8 - 0.2 * t))
        n = 30
        for i in range(1, n + 1):
            t = i / n
            ang = math.pi / 2 - t * 1.6 * 2 * math.pi
            R = R0 * (1 - 0.65 * t)
            pts.append((cy + math.cos(ang) * R * -1 + 0, czz + math.sin(ang) * R, 0.6 - 0.3 * t))
        for (y, z, rr) in pts:
            r = max(0.6, rr * k)
            for x in range(0, math.ceil(r)):
                for yy in range(math.floor(y - r), math.ceil(y + r) + 1):
                    for zz in range(max(0, math.floor(z - r)), math.ceil(z + r) + 1):
                        if ((x + .5) / r) ** 2 + ((yy + .5 - y) / r) ** 2 + ((zz + .5 - z) / r) ** 2 <= 1:
                            _sym(tail, x, yy, zz, tc)
            _sym(tail, 0, math.floor(y), math.floor(z), tc)


# --------------------------------------------------------------- plans

def sentinel(c, H, cols, opts):
    """Plan "sentinel": a meerkat up on its hind legs on watch, slim and
    tall, front paws held at the chest, dark eye patches, small dark ears,
    the tail behind on the ground as a prop."""
    import rig
    from creatures import eyes
    k = H / 10.0
    col = cols['col']
    belly = cols.get('belly', col)
    patch = cols.get('patches', _dark(col, 0.5))
    ear = cols.get('ear_col', patch)
    tcol = cols.get('tail_col', col)
    c.gait_hint = 'waddle'
    body = c.part('body')
    head = c.part('head', 'static', (0, -0.3 * k, 6.8 * k))
    hip = round(1.4 * k)
    # hind legs: a shin up to the hip and a long foot flat on the ground
    fw = max(1, round(0.5 * k))
    xl = max(1, round(0.55 * k))
    leg = rig.leg_part(c, 'L', 0, 1, (-(xl + fw / 2), 0.3 * k, hip + 1))
    cells = {}
    for x in range(xl, xl + fw):
        for z in range(0, hip + 1):
            for y in range(round(0.0 * k), round(0.0 * k) + fw):
                cells[(x, y, z)] = col
        for y in range(round(-0.9 * k), round(0.0 * k)):
            cells[(x, y, 0)] = col
    for (x, y, z), cc in cells.items():
        leg.put((_mx(x), y, z), cc)
    legr = rig.leg_part(c, 'R', 0, 1, (xl + fw / 2, 0.3 * k, hip + 1))
    for (x, y, z), cc in cells.items():
        legr.put((x, y, z), cc)
    # the body: slim and upright, haunches at the bottom
    body.ell((0, 0.2 * k, hip + 1.2 * k), (1.3 * k, 1.2 * k, 1.3 * k), col)
    body.ell((0, 0.0, hip + 2.9 * k), (1.0 * k, 0.95 * k, 1.9 * k), col)
    body.paint(lambda p, cc, g: (belly, False) if p[1] + .5 < -0.35 * k and p[2] > hip else None)
    # front paws held together at the chest
    for x in range(0, max(1, round(0.45 * k))):
        for z in range(round(hip + 2.6 * k), round(hip + 3.1 * k) + 1):
            for y in (round(-1.05 * k), round(-1.05 * k) - (1 if k > 1.5 else 0)):
                _sym(body, x + max(0, round(0.15 * k)), y, z, col)
    # the head: small and round with a tapered snout
    hz = hip + 5.4 * k
    head.ell((0, -0.3 * k, hz), (1.4 * k, 1.15 * k, 1.05 * k), col)
    head.ell((0, -1.2 * k, hz - 0.35 * k), (0.55 * k, 0.75 * k, 0.5 * k), belly)
    f = head.front(0, round(hz - 0.2 * k))
    if f:
        _sym(head, 0, f[1], f[2], INK)
    es = max(1, round(0.4 * k))
    ez = round(hz + 0.05 * k)
    # eyes one column out from the middle (on the face, whatever the
    # detail), so the two middle columns stay light between the patches
    xs = [p[0] for p in head.v if p[2] == ez and p[0] >= 0]
    eyes(c, head, max(0, min(1, max(xs) - es + 1)), ez, es)
    # a dark patch around each eye, never towards the middle, and a glint
    e = _find(c, 'eyes')
    ring = {(p[0], p[2]) for p in e.v}
    for p, (cc, g) in list(head.v.items()):
        near = [(x, z) for (x, z) in ring if 0 <= abs(p[0] + .5) - abs(x + .5) <= 1 and abs(p[2] - z) <= 1 and (p[0] >= 0) == (x >= 0)]
        if near and p[1] < -0.6 * k and cc != INK:
            head.v[p] = (patch, g)
    if _fine(c):
        # the glint: a white voxel just outside each eye, on the face
        for p in e.v:
            x = p[0] + (1 if p[0] >= 0 else -1)
            f = head.front(x, p[2])
            if f and abs(f[1] - p[1]) <= 1:
                head.v[f] = (WHITE, False)
    # small dark ears low on the sides
    ep = c.part('ears', 'static', head.pivot)
    r = max(1.0, 0.35 * k)
    for x in range(0, math.ceil(1.6 * k) + 1):
        for y in range(math.floor(-0.3 * k - r), math.ceil(-0.3 * k + r) + 1):
            for z in range(math.floor(hz + 0.4 * k - r), math.ceil(hz + 0.4 * k + r) + 1):
                if ((x + .5 - 1.3 * k) / r) ** 2 + ((y + .5 + 0.3 * k) / (r * 0.7)) ** 2 + ((z + .5 - hz - 0.4 * k) / r) ** 2 <= 1:
                    if (x, y, z) not in head.v:
                        _sym(ep, x, y, z, ear)
    # the tail: from the rump down behind, along the ground, a dark tip
    tl = c.part('tail', 'static', (0, 1.2 * k, hip + 0.6 * k))
    path = [(1.1, hip / k + 0.7), (1.9, 0.8), (2.6, 0.35), (3.4, 0.35)]
    prev = None
    for (y, z) in path:
        if prev:
            cells = {}
            _rod(cells, (0, prev[0] * k, prev[1] * k), (0, y * k, z * k), tcol)
            for (x, yy, zz) in cells:
                tl.put((-1, yy, zz), tcol)
                tl.put((0, yy, zz), tcol)
                if k > 1.5 and yy < 2.6 * k:
                    tl.put((-1, yy, zz + 1), tcol)
                    tl.put((0, yy, zz + 1), tcol)
        prev = (y, z)
    tip = max(tl.v, key=lambda p: p[1])
    for p in list(tl.v):
        if p[1] >= tip[1] - max(0, round(0.4 * k)):
            tl.v[p] = (patch, False)
    return c


def fiddler(c, H, cols, opts):
    """Plan "fiddler": a fiddler crab, one claw about three times the other,
    eyes on tall stalks, three legs a side out from under the shell."""
    import rig
    from creatures import blush
    k = H / 10.0
    col = cols['col']
    acc = cols.get('accent', col)
    claw = cols.get('claw', acc)
    c.gait_hint = 'scuttle'
    body = c.part('body')
    head = c.part('head', 'static', (0, -1.6 * k, 2.6 * k))
    top = round(1.4 * k)
    body.ell((0, 0.4 * k, 2.3 * k), (2.6 * k, 1.9 * k, 1.1 * k), col)
    body.paint(lambda p, cc, g: (acc, False) if p[2] < 1.8 * k else None)
    head.ell((0, -1.2 * k, 2.5 * k), (1.8 * k, 1.0 * k, 0.9 * k), col)
    # eyes up on stalks
    e = c.part('eyes', 'blink', head.pivot)
    xs = max(1, round(0.75 * k))
    sy = round(-1.6 * k)
    ztop = round(3.2 * k)
    for z in range(round(2.6 * k), ztop + max(1, round(0.8 * k))):
        _sym(head, xs, sy, z, col)
    zb = ztop + max(1, round(0.8 * k))
    for dx in range(max(1, round(0.4 * k))):
        for dz in range(max(1, round(0.5 * k))):
            _sym(head, xs + dx, sy, zb + dz, WHITE)
    _sym(e, xs, sy - 1, zb, INK)
    blush(head, round(1.1 * k), round(2.2 * k))
    # the small claw (left) and the huge one (right)
    sc = {}
    _rod(sc, (1.9 * k, -0.9 * k, 2.0 * k), (2.3 * k, -1.9 * k, 2.2 * k), col)
    for (x, y, z) in sc:
        body.put((_mx(x), y, z), col)
    body.ell((-2.4 * k - .5, -2.3 * k, 2.2 * k), (0.4 * k + .2, 0.5 * k, 0.4 * k + .2), claw)
    arm = {}
    _rod(arm, (2.0 * k, -0.6 * k, 2.0 * k), (2.6 * k, -1.7 * k, 2.4 * k), col)
    for (x, y, z) in arm:
        body.put((x, y, z), col)
        body.put((x, y, z + 1), col)
    cp = c.part('claw', 'static')
    cx, cy, cz = 2.9 * k, -2.5 * k, 2.6 * k
    cp.ell((cx, cy, cz), (0.95 * k, 1.1 * k, 0.9 * k), claw)
    # two fingers forward with a gap between them
    fl = max(2, round(1.3 * k))
    th = max(1, round(0.35 * k))
    for i in range(fl):
        y = math.floor(cy - 1.0 * k) - i
        for x in range(math.floor(cx - 0.45 * k), math.ceil(cx + 0.35 * k)):
            for dz in range(th):
                cp.put((x, y, math.floor(cz + 0.35 * k) + dz), claw)
                if i == fl - 1:  # the tip hooks down, joined face to face
                    cp.put((x, y, math.floor(cz + 0.35 * k) + dz - 1), claw)
                if i < fl - 1:
                    cp.put((x, y, math.floor(cz - 0.75 * k) + dz), _dark(claw, 0.15))
    # three legs a side, out from under the shell and down
    for i, ly in enumerate((-0.3 * k, 0.6 * k, 1.5 * k)):
        inner = round(1.9 * k)
        outer = round(2.9 * k)
        y = round(ly)
        cells = {}
        for x in range(inner, outer + 1):
            cells[(x, y, top)] = col
        for z in range(0, top + 1):
            cells[(outer, y, z)] = col
        hip = (inner + .5, y + .5, top + 1)
        left = rig.leg_part(c, 'L', i, 3, (-hip[0], hip[1], hip[2]))
        right = rig.leg_part(c, 'R', i, 3, hip)
        for (x, yy, z), cc in cells.items():
            right.put((x, yy, z), cc)
            left.put((_mx(x), yy, z), cc)
    return c


PLANS = {'sentinel': ({'col', 'belly', 'patches', 'ear_col', 'tail_col'}, {}),
         'fiddler': ({'col', 'accent', 'claw'}, {})}
BUILDERS = {'sentinel': sentinel, 'fiddler': fiddler}
ACCESSORIES = {
    'ears': ears, 'muzzle': muzzle, 'ruff': ruff, 'big_eyes': big_eyes, 'stripe': stripe,
    'membrane': membrane, 'tear_marks': tear_marks, 'claw_arms': claw_arms, 'ring_tail': ring_tail,
    'poms': poms, 'beak': beak, 'cheeks': cheeks, 'face': face, 'hood': hood, 'throat_bars': throat_bars,
    'plume': plume, 'lift_legs': lift_legs, 'fold_wings': fold_wings, 'leaf': leaf, 'mandibles': mandibles,
    'feelers': feelers, 'chameleon': chameleon, 'symmetry': symmetry,
}
