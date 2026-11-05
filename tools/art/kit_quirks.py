"""Quirks: one-off touches that make a roster creature itself, used like the
accessories in kit.py (`"accessories": [{"kind": "torn_ear", "color": ...}]`;
variants.py loads every kit_*.py).
Each runs after the body plan, `shape` and patterns have built the creature,
so it can reshape what is there (a second head, a long neck, giant ears) as
well as add to it (glasses, a book, straw in the fur).

Every quirk is fn(c, H, col, col2, a) with colours as (r, g, b), in the art
frame (x right, y back, front is -y, z up) and the k = H / 10 scale, so it
looks alike in the in-game boxes and the finer Blender build. Legs a quirk
adds are rig leg parts, so the creature walks on them."""
import math

from voxkit import hexc

INK, WHITE = hexc('#1B1B2F'), hexc('#FFFFFF')
HEAD_PARTS = ('head', 'eyes', 'ears', 'crest', 'mane', 'horn', 'antlers', 'beard')


def _find(c, name):
    for p in c.parts:
        if p.name == name:
            return p
    return None


def _hash(*v):
    h = 2166136261
    for x in v:
        h = ((h ^ (int(x) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    return h


def _mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _shift(part, dx=0, dy=0, dz=0):
    part.v = {(x + dx, y + dy, z + dz): v for (x, y, z), v in part.v.items()}
    part.pivot = (part.pivot[0] + dx, part.pivot[1] + dy, part.pivot[2] + dz)


def _line(part, a, b, col, glow=False):
    """A line of voxels from a to b that touch face to face (a diagonal of
    voxels touching only at their edges reads as loose beads once bevelled)."""
    n = max(1, int(math.ceil(max(abs(b[i] - a[i]) for i in range(3)) * 2)))
    prev = None
    for i in range(n + 1):
        t = i / n
        p = [math.floor(a[j] + (b[j] - a[j]) * t) for j in range(3)]
        if prev:
            q = list(prev)
            for j in range(3):  # step one axis at a time
                if q[j] != p[j]:
                    q[j] = p[j]
                    part.put(tuple(q), col, glow)
        part.put(tuple(p), col, glow)
        prev = p


def _rod(part, a, b, col, w=2):
    """A solid w x w rod from a to b, face connected end to end."""
    for dx in range(w):
        for dy in range(w):
            o = (dx - (w - 1) / 2, dy - (w - 1) / 2, 0)
            _line(part, tuple(a[i] + o[i] for i in range(3)), tuple(b[i] + o[i] for i in range(3)), col)


def _surface_top(vox):
    """{(x, y): top z} of a voxel set."""
    out = {}
    for (x, y, z) in vox:
        if z > out.get((x, y), -1):
            out[(x, y)] = z
    return out


def _sides(vox):
    """The voxel sets on the left (x < 0) and right (x >= 0)."""
    return {p for p in vox if p[0] < 0}, {p for p in vox if p[0] >= 0}


# ------------------------------------------------------------------ heads

def second_head(c, H, col, col2, a=None):
    """Two heads side by side (a mutant chick): the head, its eyes and crest
    once to each side. The right one sits a voxel higher,
    so the pair looks like two birds, not one wide one."""
    k = H / 10.0
    parts = [p for p in c.parts if p.name in HEAD_PARTS and p.v]
    head = _find(c, 'head')
    if not head or not head.v:
        return
    xs, ys, zs = zip(*head.v)
    centre = (0, (min(ys) + max(ys) + 1) / 2, min(zs))
    # (no shrinking: resampling a one-voxel-thick eye layer can lose it)
    d = max(2, round(1.9 * k))
    for p in parts:
        left = {(x - d, y, z): v for (x, y, z), v in p.v.items()}
        right = {(x + d, y, z + max(1, round(0.4 * k))): v for (x, y, z), v in p.v.items()}
        # the right head's eyes stay in front of the left head's cheek
        p.v = {**left, **right}
    # the necks: fill the gap under each head down into the body
    body = _find(c, 'body')
    if body:
        hz = min(p[2] for p in head.v)
        for sx in (-1, 1):
            for z in range(hz - round(1.0 * k), hz + 1):
                body.ell((sx * d + .5 * sx, centre[1], z), (0.9 * k, 0.9 * k, 0.6), col)


def long_neck(c, H, col, col2, a=None):
    """A neck like a giraffe's: the head (and its eyes and crest) raised and
    pushed a little forward, joined to the body by a round neck."""
    k = H / 10.0
    body = _find(c, 'body')
    head = _find(c, 'head')
    if not body or not head or not head.v:
        return
    lift, fwd = round(3.4 * k), -round(0.5 * k)
    hz0 = min(p[2] for p in head.v)
    hy = sum(p[1] for p in head.v) / len(head.v)
    for p in c.parts:
        if p.name in HEAD_PARTS:
            _shift(p, 0, fwd, lift)
    r = 0.95 * k
    top = hz0 + lift + round(0.8 * k)
    base = hz0 - round(1.4 * k)
    steps = max(4, top - base)
    for i in range(steps + 1):
        t = i / steps
        z = base + (top - base) * t
        y = hy + 0.6 * k + (fwd - 0.6 * k) * t  # leans forward as it rises
        body.ell((0, y, z), (r, r, 0.8), col)


# ------------------------------------------------------------------- ears

def jumbo_ears(c, H, col, col2, a=None):
    """Round ears bigger than the creature's body (a mutant mouse), pink
    inside, standing out from the top of the head. They flap (anim ears)."""
    k = H / 10.0
    head = _find(c, 'head')
    ears = _find(c, 'ears')
    if not head or not head.v:
        return
    hy = sum(p[1] for p in head.v) / len(head.v)
    ztop = max(p[2] for p in head.v)
    if ears is None:
        ears = c.part('ears', 'ears', (0, hy, ztop))
    ears.v = {}
    ears.anim = 'ears'
    ears.pivot = (0, hy, ztop - 1.0 * k)
    inner = col2 or hexc('#FFB3C7')
    R = 2.5 * k
    cz = ztop + 1.3 * k
    for sx in (-1, 1):
        cx = sx * 2.6 * k
        y0 = round(hy)
        for x in range(math.floor(cx - R), math.ceil(cx + R) + 1):
            for z in range(math.floor(cz - R), math.ceil(cz + R) + 1):
                d = math.hypot((x + .5 - cx) / R, (z + .5 - cz) / R)
                if d > 1:
                    continue
                # a dish: thicker at the rim, pink in the middle at the front
                ears.put((x, y0, z), col)
                ears.put((x, y0 + 1, z), col)
                if d > 0.78:
                    ears.put((x, y0 - 1, z), col)
                elif d < 0.7:
                    ears.put((x, y0 - 1, z), inner)
                    ears.v.pop((x, y0 - 2, z), None)
        # a short stalk into the head so the ear never floats
        for z in range(ztop - 1, round(cz - R) + 2):
            for dx in (-1, 0):
                ears.put((round(sx * 1.4 * k) + dx, y0, z), col)


def torn_ear(c, H, col, col2, a=None):
    """A notch bitten out of the right ear (a scruffy alley cat). The ears
    move to their own part, `torn_ears`, since the finer build otherwise
    mirrors the right ear onto the left and would tear both."""
    k = H / 10.0
    ears = _find(c, 'ears')
    if not ears or not ears.v:
        return
    torn = c.part('torn_ears', 'static', ears.pivot)
    torn.v = dict(ears.v)
    ears.v = {}
    right = [p for p in torn.v if p[0] >= 0]
    if not right:
        return
    zt = max(p[2] for p in right)
    xo = max(p[0] for p in right)
    # a nick out of the tip's outer corner (cat ears are only a few voxels
    # tall, so one corner column goes), and a pink scar beside it
    for (x, y, z) in list(right):
        if z == zt and x == xo:
            torn.v.pop((x, y, z), None)
    if col2:
        for (x, y, z) in list(torn.v):
            if x == xo and z == zt - 1:
                torn.v[(x, y, z)] = (col2, False)


# ------------------------------------------------------------------- tails

def fork_tail(c, H, col, col2, a=None):
    """A swallow's long forked tail: two streamers from the rump, swinging
    with the tail anim. col2 tips them."""
    k = H / 10.0
    body = _find(c, 'body')
    old = _find(c, 'tail')
    if old:
        old.v = {}
    ys = [p[1] for p in body.v]
    zs = [p[2] for p in body.v]
    yb = max(ys) - round(0.6 * k)
    zb = min(zs) + (max(zs) - min(zs)) * 0.45
    tail = c.part('tail', 'tail', (0, yb, zb))
    w = max(1, round(0.8 * k))
    # a wedge at the root
    tail.ell((0, yb + 0.6 * k, zb), (0.9 * k, 1.0 * k, 0.45 * k + .3), col)
    L = 4.4 * k
    for sx in (-1, 1):
        n = max(4, round(L))
        for i in range(n + 1):
            t = i / n
            x = sx * (0.3 * k + 1.3 * k * t)
            y = yb + 0.8 * k + L * t
            z = zb - 0.2 * k * t
            ww = max(1, round(w * (1 - 0.6 * t)))
            cc = col2 if (col2 and t > 0.8) else col
            for dx in range(ww):
                xx = math.floor(x) + (dx if sx > 0 else -dx)
                for dz in range(max(1, round(0.3 * k))):
                    tail.put((xx, math.floor(y), math.floor(z) + dz), cc)
                    tail.put((xx, math.floor(y) - 1, math.floor(z) + dz), cc)  # no edge-only joins


def tail_threads(c, H, col, col2, a=None):
    """Two long, fine tail threads from the tip of the abdomen (a mayfly),
    curving up and apart."""
    k = H / 10.0
    body = _find(c, 'body')
    tip = max(body.v, key=lambda p: p[1])
    th = c.part('threads', 'static')
    n = max(6, round(4.6 * k))
    for sx in (-1, 1):
        prev = None
        for i in range(n + 1):
            t = i / n
            x = tip[0] + .5 + sx * (0.4 + 1.6 * k * t)
            y = tip[1] + 1 + 4.2 * k * t
            z = tip[2] + 0.5 + 2.2 * k * t * t
            p = (math.floor(x), math.floor(y), math.floor(z))
            if prev:
                _line(th, prev, p, col2 if (col2 and t > 0.85) else col)
            prev = p


def glow_tail(c, H, col, col2, a=None):
    """The rear of the body glows (a glowworm): the back third lights up,
    brightest at the tip."""
    body = _find(c, 'body')
    if not body or not body.v:
        return
    ys = [p[1] for p in body.v]
    y0, y1 = min(ys), max(ys)
    cut = y0 + (y1 - y0) * 0.62
    tip = col2 or col
    for p, (cc, g) in list(body.v.items()):
        if p[1] >= cut:
            t = (p[1] - cut) / max(1, y1 - cut)
            body.v[p] = (_mix(col, tip, t), True)


# ------------------------------------------------------------ face and coat

def glasses(c, H, col, col2, a=None):
    """Round glasses (a bookworm): a frame one voxel in front of each eye,
    a bridge between them and arms back along the head."""
    k = H / 10.0
    eyes = _find(c, 'eyes')
    if not eyes or not eyes.v:
        return
    g = c.part('glasses', 'static')
    for side in _sides(eyes.v):
        if not side:
            continue
        xs, ys, zs = zip(*side)
        x0, x1, z0, z1 = min(xs) - 1, max(xs) + 1, min(zs) - 1, max(zs) + 1
        y = min(ys) - 1
        for x in range(x0, x1 + 1):
            for z in range(z0, z1 + 1):
                corner = x in (x0, x1) and z in (z0, z1)
                if (x in (x0, x1) or z in (z0, z1)) and not corner:
                    g.put((x, y, z), col)
        outer = x0 if x0 < 0 else x1
        for i in range(max(2, round(1.2 * k))):
            g.put((outer, y + 1 + i, z1 - 1), col)
    # the bridge
    zs = [p[2] for p in g.v]
    ztop = max(zs) - 1
    y = min(p[1] for p in g.v)
    lo = max(p[0] for p in g.v if p[0] < 0 and p[1] == y)
    hi = min(p[0] for p in g.v if p[0] >= 0 and p[1] == y)
    for x in range(lo, hi + 1):
        g.put((x, y, ztop), col)
    if col2:  # a glint on each lens frame
        for p in [p for p in g.v if p[2] == max(zs) and p[1] == y][:2]:
            g.v[p] = (col2, False)


def eye_stripe(c, H, col, col2, a=None):
    """A dark stripe through the eye from beak to nape (a nuthatch), and
    with col2 a pale face and throat below it."""
    k = H / 10.0
    head = _find(c, 'head')
    eyes = _find(c, 'eyes')
    if not head or not eyes or not eyes.v:
        return
    ez = sum(p[2] for p in eyes.v) / len(eyes.v)
    half = max(1, round(0.3 * k))
    xs = [abs(p[0] + .5) for p in head.v]
    wide = max(xs)

    def paint(p, cc, g):
        if g:
            return None
        if abs(p[2] - ez) <= half and abs(p[0] + .5) >= 0.35 * wide:
            return (col, False)
        if col2 and p[2] < ez - half:
            return (col2, False)
        return None
    head.paint(paint)


def fly_eyes(c, H, col, col2, a=None):
    """Big round compound eyes on the sides of the head (a hoverfly), each
    with a glint; the creature's own eyes stay on the face between them."""
    k = H / 10.0
    head = _find(c, 'head')
    if not head or not head.v:
        return
    xs = [p[0] for p in head.v]
    ys = [p[1] for p in head.v]
    zs = [p[2] for p in head.v]
    cy = (min(ys) + max(ys)) / 2
    cz = (min(zs) + max(zs)) / 2 + 0.3 * k
    w = (max(xs) - min(xs) + 1) / 2
    fe = c.part('fly_eyes', 'static')
    r = 0.95 * k
    for sx in (-1, 1):
        cx = sx * (w - 0.2 * k)
        fe.ell((cx, cy - 0.1 * k, cz), (r * 0.8, r, r), col)
        g = (math.floor(cx + sx * 0.2 * k), math.floor(cy - 0.8 * k), math.floor(cz + 0.5 * k))
        fe.put(g, col2 or WHITE, True)
    # facets: every other voxel a shade darker
    dark = _mix(col, INK, 0.25)
    fe.paint(lambda p, cc, gl: (dark, False) if not gl and (p[0] + p[1] + p[2]) % 3 == 0 else None)


def bib(c, H, col, col2, a=None):
    """A coloured throat (a swallow's rust bib): the lower front of the head
    and the top of the chest."""
    k = H / 10.0
    head = _find(c, 'head')
    body = _find(c, 'body')
    eyes = _find(c, 'eyes')
    ez = (sum(p[2] for p in eyes.v) / len(eyes.v)) if eyes and eyes.v else max(p[2] for p in head.v) - 2 * k
    hy = sum(p[1] for p in head.v) / len(head.v)
    head.paint(lambda p, cc, g: (col, False) if not g and p[2] < ez - 0.6 * k and p[1] < hy else None)
    hz = min(p[2] for p in head.v)
    if body:
        by = min(p[1] for p in body.v)
        body.paint(lambda p, cc, g: (col, False) if not g and p[2] >= hz - 1.0 * k and p[1] < by + 1.2 * k else None)


def straw(c, H, col, col2, a=None):
    """Bits of straw stuck in the fur (a barn cat): short golden stalks
    poking out of the back at a slant."""
    k = H / 10.0
    s = c.part('straw', 'static')
    n = max(3, round(2.0 * k))
    for name, count in (('body', 5),):
        part = _find(c, name)
        if not part or not part.v:
            continue
        top = _surface_top(part.v)
        zt = max(top.values())
        spots = sorted((xy for xy, z in top.items() if z >= zt - round(0.8 * k)), key=lambda xy: _hash(xy[0], xy[1], len(name)))
        used = []
        for (x, y) in spots:
            if len(used) >= count:
                break
            if any(abs(x - u[0]) + abs(y - u[1]) < 2.2 * k for u in used):
                continue
            used.append((x, y))
            h = _hash(x, y)
            dx = 1 if h & 1 else -1
            dy = 1 if h & 2 else -1
            z = top[(x, y)]
            # a slanted stalk from the fur, every voxel touching the last face to face
            _line(s, (x + .5, y + .5, z + 1.5), (x + .5 + dx * n * 0.45, y + .5 + dy * n * 0.3, z + 1.5 + n * 0.7), col)
            tip = max(p for p in s.v if abs(p[0] - x) <= n and abs(p[1] - y) <= n)
            if col2:
                s.put(tip, col2)


def mud(c, H, col, col2, a=None):
    """Mud splashed on the coat (a muddy piglet): a few round splats on the
    back, sides and one cheek, and with col2 darker muddy feet."""
    k = H / 10.0
    for name, count in (('body', 6), ('head', 1)):
        part = _find(c, name)
        if not part or not part.v:
            continue
        surface = [p for p in part.v if any(n not in part.v for n in (
            (p[0] + 1, p[1], p[2]), (p[0] - 1, p[1], p[2]), (p[0], p[1] + 1, p[2]),
            (p[0], p[1] - 1, p[2]), (p[0], p[1], p[2] + 1)))]
        zlo = min(p[2] for p in part.v)
        surface = [p for p in surface if p[2] > zlo + 1.2 * k]
        surface.sort(key=lambda p: _hash(p[0], p[1], p[2], 5))
        spots = []
        for p in surface:
            if len(spots) >= count:
                break
            if all(math.dist(p, q) > 2.4 * k for q in spots):
                spots.append(p)
        for i, q in enumerate(spots):
            r = (0.75 + 0.35 * ((_hash(i, 9) % 100) / 100)) * k
            shade = col if i % 2 else _mix(col, INK, 0.15)
            part.paint(lambda p, cc, g, q=q, r=r, shade=shade: (shade, False) if not g and math.dist(p, q) <= r else None)
    if col2:
        body = _find(c, 'body')
        zlo = min(p[2] for p in body.v)
        body.paint(lambda p, cc, g: (col2, False) if not g and p[2] <= zlo + round(0.5 * k) else None)


def sugar(c, H, col, col2, a=None):
    """Sugar crystals on the surface (a gumdrop slug): little white grains
    on top of the body and head, some of them glinting."""
    k = H / 10.0
    sp = c.part('sugar', 'static')
    for name in ('body', 'head'):
        part = _find(c, name)
        if not part or not part.v:
            continue
        for (x, y), z in _surface_top(part.v).items():
            h = _hash(x, y, 31)
            if h % 9 == 0:
                glint = (h >> 8) % 3 == 0
                sp.put((x, y, z + 1), col2 if (glint and col2) else col, glint)


def air_bubble(c, H, col, col2, a=None):
    """A silvery air bubble held at the tail end of the back (a diving
    beetle), with a bright glint."""
    k = H / 10.0
    shell = _find(c, 'shell') or _find(c, 'body')
    ys = [p[1] for p in shell.v]
    y = max(ys) - 0.2 * k
    top = max(p[2] for p in shell.v if p[1] >= y - 1)
    b = c.part('bubble', 'static')
    r = 1.35 * k
    b.ell((0, y - 0.3 * k, top + 0.5 * k), (r, r, r), col)
    # a bright glint on the upper front of the bubble
    for dx in range(max(1, round(0.4 * k))):
        for dz in range(max(1, round(0.4 * k))):
            b.put((round(0.3 * k) + dx, math.floor(y - 1.5 * k), math.floor(top + 1.0 * k) + dz), col2 or WHITE, True)


def book(c, H, col, col2, a=None):
    """A little closed book the creature crawls out of (a bookworm): it lies
    flat over the back of the body, red covers top and bottom, a block of
    cream pages, a darker spine at the back and a gold ribbon hanging out.
    The body inside the book is hidden; the rest pokes out of the pages."""
    k = H / 10.0
    body = _find(c, 'body')
    ys = [p[1] for p in body.v]
    y1 = max(ys) + round(0.3 * k)
    y0 = y1 - round(3.4 * k)
    hw = round(1.9 * k)  # half width
    th = max(3, round(1.7 * k))  # thickness, covers included
    cover = max(1, round(0.25 * k))
    pages = col2 or hexc('#FFF6E0')
    spine = _mix(col, INK, 0.3)
    bk = c.part('book', 'static')
    for x in range(-hw, hw):
        for y in range(y0, y1 + 1):
            for z in range(0, th):
                lid = z < cover or z >= th - cover
                back = y >= y1 - cover + 1
                edge = x in (-hw, hw - 1) or y == y0
                if lid or back:
                    bk.put((x, y, z), spine if (back and not lid) else col)
                elif edge:
                    # page edges: thin lines of shade every other voxel
                    bk.put((x, y, z), pages if z % 2 else _mix(pages, INK, 0.12))
    # a cover that overhangs the pages by a voxel at the front and sides
    for x in range(-hw - 1, hw + 1):
        for y in range(y0 - 1, y1 + 1):
            for z in (0, th - 1):
                bk.put((x, y, z), col)
    # a gold title band on the top cover
    for x in range(-hw + 1, hw - 1):
        bk.put((x, y0 + round(1.0 * k), th - 1), hexc('#FFD43B'))
    # a ribbon bookmark hanging over the front edge
    for i in range(max(2, round(1.0 * k))):
        bk.put((hw - 2, y0 - 1, th - 2 - i), hexc('#4C7BD9'))
    # the body inside the book is hidden, and the worm lies low enough to
    # come out of the pages, not the cover
    for p in [p for p in body.v if y0 <= p[1] <= y1 and -hw <= p[0] < hw and p[2] < th]:
        del body.v[p]
    for p in [p for p in body.v if y0 <= p[1] and p[2] >= th - 1]:
        del body.v[p]


# ---------------------------------------------------------------- bodies

def many_legs(c, H, col, col2, a=None):
    """Lifts a long low body onto six pairs of short legs (a centipede), each
    its own rig leg part so it scuttles with a ripple down the body."""
    import rig
    k = H / 10.0
    lift = max(2, round(0.9 * k))
    for p in c.parts:
        _shift(p, 0, 0, lift)
    body = _find(c, 'body')
    ys = sorted({p[1] for p in body.v})
    y0, y1 = ys[0] + 0.6 * k, ys[-1] - 0.8 * k
    n = 6
    for i in range(n):
        y = y0 + (y1 - y0) * i / (n - 1)
        # the body's half width at this segment, at hip height
        hz = lift + round(0.6 * k)
        row = [p for p in body.v if abs(p[1] + .5 - y) < 1 and abs(p[2] - hz) <= 1]
        half = max((abs(p[0] + .5) for p in row), default=1.0 * k)
        # the hip sits inside the body, the knee out and up, the foot out on the ground:
        # every leg the same size, front to back, so all six pairs visibly step.
        # The right leg is drawn and the left is its exact mirror.
        # (never past the middle line, where the head end of the body is
        # narrow, so the left and right legs never overlap)
        x0 = max(1, math.floor(half - 0.6 * k))   # inside the body
        x1 = x0 + max(2, round(1.1 * k))          # the knee, out at the side
        yi = math.floor(y)
        hip = (x0 + .5, yi + 1, hz + 1)
        right = rig.leg_part(c, 'R', i, n, hip)
        # a thigh out from under the body, then a shin down to the ground,
        # two voxels square; the foot a shade darker
        right.box((x0, yi, hz - 1), (x1 + 1, yi + 1, hz), col)
        right.box((x1, yi, 0), (x1 + 1, yi + 1, hz - 2), col)
        if col2:
            right.box((x1, yi, 0), (x1 + 1, yi + 1, 0), col2)
        left = rig.leg_part(c, 'L', i, n, (-hip[0], hip[1], hip[2]))
        left.v = {(-x - 1, yy, z): v for (x, yy, z), v in right.v.items()}


def aphid(c, H, col, col2, a=None):
    """Redraws a ladybug-shaped blob as an aphid: a soft pear-shaped body
    (narrow at the front, round at the back), a small darker head with long
    thin antennae swept back over the body, the two little tubes an aphid has
    on its back end, and six thin legs bent outwards at the knee that hold the
    body up off the ground so they are seen stepping."""
    import rig
    import creatures
    k = H / 10.0
    body = _find(c, 'body')
    head = _find(c, 'head')
    dark = col2 or _mix(col, INK, 0.3)
    body.v = {}
    head.v = {}
    eyes_p = _find(c, 'eyes')
    if eyes_p:
        eyes_p.v = {}
    # pear: a big round back end, higher than the narrower front
    zc = 2.7 * k
    body.ell((0, 1.0 * k, zc + 0.2 * k), (1.9 * k, 2.0 * k, 1.6 * k), col)
    body.ell((0, -1.1 * k, zc - 0.2 * k), (1.25 * k, 1.4 * k, 1.05 * k), col)
    shade = _mix(col, dark, 0.45)
    body.paint(lambda p, cc, g: (shade, False) if p[2] + .5 < zc - 1.0 * k else None)
    # head: small, darker, tucked under the front of the body
    head.pivot = (0, -2.4 * k, zc)
    head.ell((0, -2.7 * k, zc - 0.3 * k), (1.05 * k, 0.95 * k, 0.9 * k), dark)
    creatures.eyes(c, head, max(1, round(0.35 * k)), round(zc), max(1, round(0.4 * k)))
    # antennae: one voxel thick, a step up from the brow, then swept back
    # and out past the sides of the body, drooping at the tips
    zt = max(p[2] for p in head.v)
    for sx in (-1, 1):
        def X(x):
            return x if sx > 0 else -x - 1
        x0 = round(0.4 * k)
        y0 = round(-3.0 * k)
        z1 = zt + 1
        head.put((X(x0), y0, zt + 1), dark)
        head.put((X(x0), y0, zt + 2), dark)
        z1 = zt + 2
        _line(head, (X(x0) + .5, y0 + .5, z1 + .5), (X(round(2.4 * k)) + .5, round(0.6 * k) + .5, z1 + .5), dark)
        xe, ye = X(round(2.4 * k)), round(0.6 * k)
        head.put((xe, ye + 1, z1), dark)
        head.put((xe, ye + 1, z1 - 1), dark)
        # the two tubes on the back end: short, up and back
        bx = X(round(0.8 * k))
        top = _surface_top(body.v)
        yb = round(2.0 * k)
        zb = top.get((bx, yb), round(zc + 1.2 * k))
        for z in range(zb + 1, zb + 1 + max(2, round(0.7 * k))):
            body.put((bx, yb, z), dark)
        body.put((bx, yb + 1, zb + max(2, round(0.7 * k))), dark)
    # legs: thin, straight out from under the body to a knee, then straight
    # down to the foot (bent outwards at the knee, like an insect's); front
    # legs step forward, back legs back
    legs = sorted([p for p in c.parts if p.name in rig.LEG_NAMES], key=lambda p: (p.pivot[1], p.pivot[0]))
    ys = sorted({round(l.pivot[1], 3) for l in legs})
    spots = [(-1.3, -1), (0.3, 0), (1.8, 1)]
    zk = round(zc - 0.6 * k)
    for leg in legs:
        sx = 1 if leg.pivot[0] >= 0 else -1
        i = min(2, ys.index(round(leg.pivot[1], 3)))
        hy, reach = spots[i]
        y = round(hy * k)

        def X(x):
            return x if sx > 0 else -x - 1
        xh, xk = round(0.9 * k), round(2.3 * k)
        leg.v = {}
        leg.pivot = (sx * (xh + .5), y + .5, zk - 0.5)
        for x in range(xh, xk + 1):
            leg.put((X(x), y, zk), dark)
        yf = y + reach * max(1, round(0.5 * k))
        for yy in range(min(y, yf), max(y, yf) + 1):
            leg.put((X(xk), yy, zk), dark)
        for z in range(0, zk + 1):
            leg.put((X(xk), yf, z), dark)
        leg.put((X(xk + 1), yf, 0), dark)  # a little foot pointing out


def drop_ears(c, H, col, col2, a=None):
    """Long floppy hound ears: from the top corners of the head each ear
    folds over and hangs flat against the side of the head, down past the
    jaw, with a rounded tip that flares out a little (a beagle). col is the
    ear colour (col2, if given, the tip)."""
    k = H / 10.0
    head = _find(c, 'head')
    ears = _find(c, 'ears')
    if not head or not head.v:
        return
    if ears is None:
        ears = c.part('ears', 'static', head.pivot)
    ec = col
    if ears.v:  # keep the plan's ear colour
        from collections import Counter
        ec = Counter(v[0] for v in ears.v.values()).most_common(1)[0][0]
    ears.v = {}
    tip = col2 or ec
    hv = head.v
    zs = [p[2] for p in hv]
    ys = [p[1] for p in hv]
    ztop, zbot = max(zs), min(zs)
    yc = (min(ys) + max(ys)) / 2
    w = max(2, round(1.3 * k))
    y0 = round(yc + 0.1 * k)  # a little behind the eyes
    zt = ztop - max(1, round(0.5 * k))
    zb = zbot - max(2, round(1.2 * k))
    for sx in (-1, 1):
        last = None
        for z in range(zt, zb - 1, -1):
            row = [p[0] for p in hv if p[2] == z and y0 <= p[1] < y0 + w]
            if sx < 0:
                row = [-x - 1 for x in row]
            side = (max(row) + 1) if row else None
            if last is None:
                x = side if side is not None else 0
                first = x
            else:  # never curls in under the jaw; flares out at the tip
                x = max(last, side if side is not None else last)
            if z == zb and last is not None:  # the tip turns out a little
                x = last + 1
            last = x
            n = w
            if z == zb:
                n = w - 2  # rounded tip
            for t in range(2):
                for dy in range(n):
                    xx = x + t
                    yy = y0 + dy + (1 if z == zb else 0)
                    if sx < 0:
                        xx = -xx - 1
                    ears.put((xx, yy, z), tip if z <= zb + 1 else ec)
        # the fold: a short flap lying on the top corner of the head, so the
        # ear grows out of the head instead of standing beside it
        row = [p[0] for p in hv if p[2] == zt and y0 <= p[1] < y0 + w]
        xs = [x if sx > 0 else -x - 1 for x in row] or [first]
        for xx in range(max(xs) - max(1, round(0.6 * k)), first + 2):
            for dy in range(w):
                ears.put((xx if sx > 0 else -xx - 1, y0 + dy, zt + 1), ec)


def tidy(c, H, col, col2, a=None):
    """Joins every loose piece of the creature to the main one: for each
    piece that touches the rest only at an edge or corner, or not at all (a
    wing tip, a diagonal tail, a back leg below a round belly), a short path
    of voxels in that piece's own part and colour, so nothing floats once
    bevelled. Put it last in the accessories."""
    from collections import deque
    import rig
    # legs one voxel thin are thickened to two, outwards and backwards, so
    # a leg reads as a leg at in-game size and stays whole as it swings
    for leg in [p for p in c.parts if p.name in rig.LEG_NAMES and p.v]:
        xs = {v[0] for v in leg.v}
        ys = {v[1] for v in leg.v}
        out = 1 if leg.pivot[0] >= 0 else -1
        if len(xs) == 1:
            leg.v.update({(x + out, y, z): cv for (x, y, z), cv in list(leg.v.items())})
        if len(ys) == 1:
            leg.v.update({(x, y + 1, z): cv for (x, y, z), cv in list(leg.v.items())})
    owner = {}
    for p in c.parts:
        for v in p.v:
            owner[v] = p
    for _ in range(64):
        left, comps = set(owner), []
        while left:
            st = left.pop()
            comp, q = {st}, deque([st])
            while q:
                x, y, z = q.popleft()
                for nb in ((x + 1, y, z), (x - 1, y, z), (x, y + 1, z), (x, y - 1, z), (x, y, z + 1), (x, y, z - 1)):
                    if nb in left:
                        left.remove(nb)
                        comp.add(nb)
                        q.append(nb)
            comps.append(comp)
        if len(comps) < 2:
            return
        comps.sort(key=len, reverse=True)
        main, piece = comps[0], comps[-1]
        # the closest pair of voxels between the piece and the main body
        best = None
        for v in piece:
            for m in main:
                d = abs(v[0] - m[0]) + abs(v[1] - m[1]) + abs(v[2] - m[2])
                if best is None or d < best[0]:
                    best = (d, v, m)
        _, v, m = best
        part = owner[v]
        colour = part.v[v]
        q = list(v)
        for i in (2, 0, 1):  # up or down first, then across
            while q[i] != m[i]:
                q[i] += 1 if m[i] > q[i] else -1
                t = tuple(q)
                if t in owner:
                    break
                part.v[t] = colour
                owner[t] = part
            else:
                continue
            break


ACCESSORIES = {
    'second_head': second_head,
    'long_neck': long_neck,
    'jumbo_ears': jumbo_ears,
    'torn_ear': torn_ear,
    'fork_tail': fork_tail,
    'tail_threads': tail_threads,
    'glow_tail': glow_tail,
    'glasses': glasses,
    'eye_stripe': eye_stripe,
    'bib': bib,
    'fly_eyes': fly_eyes,
    'straw': straw,
    'mud': mud,
    'sugar': sugar,
    'air_bubble': air_bubble,
    'book': book,
    'many_legs': many_legs,
    'aphid': aphid,
    'drop_ears': drop_ears,
    'tidy': tidy,
}
