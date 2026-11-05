"""Accessories and patterns for the Uncommon batch (master creature sheet,
Nov 5), loaded by variants.py like every kit_*.py. Each one dresses a
creature after its body plan built it, in the art frame (x right, y back,
front is -y, z up) and the plan's scale (k = H / 10), so it reads the same in
the in-game boxes and the finer Blender build.

Accessories (roster `accessories`, each `{"kind", "color", "color2"?, ...}`;
extra keys are listed with each):

- **cup**: the creature sits in a container worn round its middle, legs out
  underneath. `style`: teacup (polka dots in color2, a handle), pumpkin
  (ribbed, a stem), cauldron (iron pot on the ground, bubbling brew in
  color2), thimble (dimpled metal).
- **mitten**: a knitted mitten round the body, the head out of its cuff
  (color2 ribbing), a thumb on one side.
- **shell**: a snail shell on the back, spiral stripes in color2.
- **ball**: `style` beach (balanced on the nose, color/color2/white
  panels), coconut (on the ground in front), dung (a big ball in front),
  berry (held under the chin).
- **pot**: a honey pot hugged to the chest, honey (color2) over the rim.
- **bubble**: a bubblegum bubble blown from the mouth.
- **unc_tusks**: two small tusks beside the snout.
- **snout**: a long snout or trunk from the face. `length` (in k, default
  2), `droop` (0 straight on, 1 hangs down), `r` (thickness in k), the tip
  in color2.
- **hornset**: `style` swept, curled (ram curls), wide (buffalo),
  pair (two short horns back over the head), tri (pair and a third),
  ibex (thick ridged arcs from the brow back over the neck, color2 ridges),
  rhino (one big horn up from the nose).
- **earset**: new ears in place of the plan's. `style` roo, fold, huge,
  pointy, tufted (color2 tufts), round (`size`), tiny, none (no ears);
  color2 the inside.
- **tailset**: a new tail in place of the plan's. `style` curl, upright,
  tuft, roo, long, bushy, brush (a fox's huge brush, color2 tip, `size`),
  train, plume, pinwheel, drip; `rings: true` bands
  it in color2.
- **wingset**: wings that flap, as wingL/wingR. `style` feather or bat.
- **wingfold**: folded wings sweep forward round the body, their tips
  `forward` voxels further forward per voxel down (default 0.5).
- **boots**: on every foot. `style` feather (fluffy) or rain (a boot with a
  color2 rim).
- **stilts**: longer legs: lifts the creature `length` (in k) and stretches
  its legs to the ground.
- **carapace**: armour over the back. `style` bands (armadillo), scales
  (the tail too) or plates (pangolin: stepped overlapping plates over the
  back, head top and tail); color2 the seams.
- **skirt**: long shaggy fur hanging from the body's sides (a yak's),
  `length` its bottom's height in k, `from` where it starts (0 belly to
  1 back, default 0.45), `sides: true` down the flanks only, `strands`
  a list of colours for darker and lighter hanging strands, `solid: true`
  a filled coat (holes where the legs swing).
- **fluff**: `style` fur (a fuzzy coat taking the colours under it, or
  color with `solid: true`; `head: true` too, `layers` thick) or popcorn
  (puffs in color and color2; one on every `every`th spot, default 6;
  `head: true` adds a few on the crown).
- **frizz**: curly feathers sticking out everywhere.
- **unc_mushrooms**: little caps on the back, spots in color2.
- **unc_spikes**: soft spikes over the back, tips in color2. `head: true` too,
  `size` (in k).
- **feelers**: whiskers, two each side of the muzzle.
- **bigeyes**: bigger eyes (`size` in k), white shine.
- **mouth**: `style` smile (a wide smile, color2 tongue) or underbite.
- **sweater**: a knitted sweater over the body, color2 ribbing.
- **snowcap**: a cap of snow on the head.
- **mane_strip**: a bristly strip down the head and back.
- **crest**: `style` fan (a fan of feathers, color2 tips) or plumes (a
  bunch of bright feathers).
- **beak**: a bigger beak over the plan's. `style` big, curved, long.
- **fan**: a peacock spider's fan raised at the back.
- **leaf**: the body is a flat leaf with a color2 midrib and veins.
- **goatee**: a goat's beard under the chin, below a long snout (`length` in k).
- **jellybean**: a beetle's shell remade as one smooth glossy jellybean, arched
  like a kidney bean, with a long gloss streak (color2).
- **eyedisc**: a color disc round each eye (`disc` in k) with a big color2
  eye (`size` in k) and a glint: eyes that read on dark or busy faces;
  `lift` and `back` (in k) move the eye up and back.
- **cicada**: turns the dragonfly critter into a cicada: wide head, big
  bulging eyes at the sides (`eye`), a stout banded body and clear roof
  wings (color) with color2 veins.

Patterns (roster `patterns`, `{"kind", "color", "parts"?, ...}`):

- **face** the front of the head (`depth`, 0 to 1); **cap** the top of the
  head (`depth`; `nape` runs it further down the back of the head, `soft:
  true` blends its edge in a half-tone band); **mask** a band across the eyes; **zebrastripe** wavy stripes
  over body, head and legs; **streak** a band along each side (`z`, 0
  bottom to 1 top); **rosettes** ring spots; **flecks** small speckles
  (`density` %); **sash** a diagonal band; **rainbow** bands of colour
  front to back, starting from color; **sprinkles** candy sprinkles;
  **swirl** a helix stripe (`phase` 0 to 1, run it twice for two
  colours); **ribs** a skeleton's ribs and spine; **stitches** sewn seams;
  **facets** folded-paper planes; **drips** a coat poured over the top,
  dripping down; **sheen** glints on the top surfaces; **half** the left
  half; **ends** the far end of a part (`frac`, e.g. wing tips); **rim** the
  bottom edge; **trim** shaves a small nub off the top of a dome (`max`
  voxels a layer); **strands** long hair in vertical runs of one tone
  (`density` %, `seed`; run twice for darker and lighter strands)."""
import math
from collections import Counter

import kit
import rig
from kit import INK, WHITE, _find, _hash, ball, crown, head_of
from voxkit import hexc

PINK = hexc('#FF9BB5')


# ------------------------------------------------------------------ helpers

def _k(H):
    return H / 10.0


def mix(a, b, t):
    return tuple(max(0, min(255, round(a[i] + (b[i] - a[i]) * t))) for i in range(3))


def dark(col, t=0.3):
    return mix(col, INK, t)


def light(col, t=0.35):
    return mix(col, WHITE, t)


def bounds(vs):
    vs = list(vs)
    return ([min(v[i] for v in vs) for i in range(3)], [max(v[i] for v in vs) for i in range(3)])


def mput(part, x, y, z, col, glow=False):
    """Put (x, y, z) on the right (x >= 0) and its mirror on the left."""
    part.put((x, y, z), col, glow)
    part.put((-x - 1, y, z), col, glow)


def tube(part, pts, r0, r1, col, colfn=None, closed_min=0.5):
    """A rod along the polyline pts, its radius going from r0 to r1; colfn(t)
    (t 0 at the start, 1 at the end) colours it along its length."""
    segs = [(pts[i], pts[i + 1]) for i in range(len(pts) - 1)]
    lens = [math.dist(a, b) for a, b in segs]
    total = sum(lens) or 1
    done = 0
    for (a, b), L in zip(segs, lens):
        n = max(1, int(math.ceil(L * 2.5)))
        for i in range(n + 1):
            t = i / n
            p = tuple(a[j] + (b[j] - a[j]) * t for j in range(3))
            tt = (done + L * t) / total
            r = r0 + (r1 - r0) * tt
            cc = colfn(tt) if colfn else col
            if r >= closed_min:
                part.ell(p, (r, r, r), cc)
            part.put(tuple(math.floor(v) for v in p), cc)
        done += L


class _Into:
    """Draws into an existing part, replacing what is there: an accessory
    that rides a part is cheaper as part of it (no faces between them)."""

    def __init__(self, part):
        self.target, self.v = part, {}

    def put(self, p, col, glow=False):
        p = (int(p[0]), int(p[1]), int(p[2]))
        self.v[p] = (col, glow)
        self.target.v[p] = (col, glow)

    def ell(self, *a, **kw):
        from voxkit import Part
        tmp = Part('tmp')
        tmp.ell(*a, **kw)
        for p, (cc, g) in tmp.v.items():
            self.put(p, cc, g)

    def box(self, *a, **kw):
        from voxkit import Part
        tmp = Part('tmp')
        tmp.box(*a, **kw)
        for p, (cc, g) in tmp.v.items():
            self.put(p, cc, g)

    def front(self, x, z):
        ys = [p[1] for p in self.v if p[0] == x and p[2] == z]
        return (x, min(ys), z) if ys else None


def legs_of(c):
    return [p for p in c.parts if p.name in rig.LEG_NAMES]


def torso(c):
    """(lo, hi, belly z) of the body's trunk: the body's voxels above where the
    legs end (the belly's lowest point on the middle line)."""
    body = _find(c, 'body')
    lo, hi = bounds(body.v)
    mid = [p[2] for p in body.v if p[0] in (-1, 0)]
    belly = min(mid) if mid else lo[2]
    trunk = [p for p in body.v if p[2] >= belly]
    tlo, thi = bounds(trunk)
    return tlo, thi, belly


def rump(c):
    """The back of the body, at the middle of its height there: (y, z)."""
    body = _find(c, 'body')
    tlo, thi, belly = torso(c)
    zc = (belly + thi[2]) / 2
    ys = [p[1] for p in body.v if abs(p[2] - zc) <= 1 and p[0] in (-1, 0)]
    return (max(ys) if ys else thi[1]), zc


def snout_tip(c):
    """The middle of the front of the face (x, y, z): the frontmost head
    voxels on the middle line, centred."""
    head = head_of(c)
    mids = [p for p in head.v if p[0] in (-1, 0)]
    yf = min(p[1] for p in mids)
    front = [p for p in mids if p[1] <= yf]
    z = sum(p[2] for p in front) / len(front)
    return 0, yf, z


def eye_spots(c):
    """[(x, y, z)] centre of each eye (left, right), or [] if none."""
    e = _find(c, 'eyes')
    if not e or not e.v:
        return []
    out = []
    for side in (lambda x: x < 0, lambda x: x >= 0):
        vs = [p for p in e.v if side(p[0])]
        if vs:
            out.append(tuple(sum(p[i] for p in vs) / len(vs) for i in range(3)))
    return out


def surface_up(part):
    """Voxels of the part with nothing above them."""
    return [p for p in part.v if (p[0], p[1], p[2] + 1) not in part.v]


def outside(c, p):
    return all(p not in q.v for q in c.parts)


# -------------------------------------------------------------- accessories

def cup(c, H, col, col2, a):
    k = _k(H)
    style = a.get('style', 'teacup')
    col2 = col2 or WHITE
    tlo, thi, belly = torso(c)
    cy = (tlo[1] + thi[1]) / 2
    rx = (thi[0] - tlo[0] + 1) / 2 + max(1, round(0.25 * k))
    ry = (thi[1] - tlo[1] + 1) / 2 + max(1, round(0.25 * k))
    # the cup is drawn into the body (it rides it anyway), so the faces
    # between cup and body are never made; a cauldron on the ground is its
    # own part so the legs are not mistaken for it
    part = c.part('cup', 'static') if style == 'cauldron' else _Into(_find(c, 'body'))
    if style == 'cauldron':
        # on the ground, round-bellied, up to the creature's middle
        z0, z1 = 0, round(belly + (thi[2] - belly) * 0.6)
        R = max(rx, ry * 0.85)
        rx = ry = R
        prof = lambda t: 0.82 + 0.3 * math.sin(min(1, t * 1.15) * math.pi) - 0.08 * t  # noqa: E731
    elif style == 'pumpkin':
        z0, z1 = max(0, belly - round(0.5 * k)), round(belly + (thi[2] - belly) * 0.62)
        prof = lambda t: 0.8 + 0.32 * math.sin(t * math.pi * 0.95)  # noqa: E731
    elif style == 'thimble':
        z0, z1 = belly, round(belly + (thi[2] - belly) * 0.6)
        prof = lambda t: 1.0 - 0.06 * t  # noqa: E731
    else:  # teacup: a little foot, then a bowl flaring to the rim
        z0, z1 = belly - 1, round(belly + (thi[2] - belly) * 0.6)
        prof = lambda t: 0.62 if t < 0.12 else 0.8 + 0.28 * math.sqrt((t - 0.12) / 0.88)  # noqa: E731
    h = max(1, z1 - z0)
    inner = set()
    for z in range(z0, z1 + 1):
        t = (z - z0) / h
        s = prof(t)
        ax, ay = rx * s, ry * s
        for x in range(math.floor(-ax) - 1, math.ceil(ax) + 1):
            for y in range(math.floor(cy - ay) - 1, math.ceil(cy + ay) + 1):
                d = ((x + .5) / ax) ** 2 + ((y + .5 - cy) / ay) ** 2
                if d > 1:
                    continue
                # one voxel thick: outside the inner ellipse one voxel in
                din = ((x + .5) / max(0.5, ax - 1)) ** 2 + ((y + .5 - cy) / max(0.5, ay - 1)) ** 2
                wall = din > 1
                # a cauldron is solid up to its brew (z1 - 1): inner walls
                # under the brew are never seen
                if z == z0 or wall or style != 'cauldron' or z < z1:
                    part.put((x, y, z), col)  # (solid: the creature's middle is inside it)
                if not (z == z0 or wall):
                    inner.add((x, y, z))
    ang = lambda x, y: math.atan2(y + .5 - cy, x + .5)  # noqa: E731
    if style == 'teacup':
        # polka dots in rows round the wall, a gold rim, a handle on the right
        s = max(3, round(1.4 * k))
        R = (rx + ry) / 2
        n = max(6, round(2 * math.pi * R / (1.7 * s)))
        for (x, y, z) in list(part.v):
            if (x, y, z) in inner:
                if z == z1:
                    part.put((x, y, z), dark(col, 0.12))  # the inside of the cup
                continue
            if z == z1 or z == z1 - 1:
                part.put((x, y, z), hexc('#F2C14E') if z == z1 else col)
                continue
            if z <= z0 + 1:
                continue
            zi = (z - z0 - 1) / s
            row = math.floor(zi)
            th = (ang(x, y) / (2 * math.pi)) * n + (0.5 if row % 2 else 0)
            du = (th - math.floor(th) - 0.5) * (2 * math.pi * R / n)
            dz = (zi - row - 0.5) * s
            if math.hypot(du, dz) < s * 0.42 and z < z1 - 1:
                part.put((x, y, z), col2)
        # the handle: an open loop standing out from the wall, its hole
        # clear, two voxels thick front to back
        zc = (z0 + z1) / 2
        xr = max(p[0] for p in part.v if abs(p[2] - zc) <= 1)
        hr = max(1.5, (z1 - z0) * 0.36)
        hx = xr + hr * 0.45
        for i in range(96):
            th = i / 96 * 2 * math.pi
            x = round(hx + hr * math.cos(th))
            if x <= xr:
                continue
            for d in (0,):
                part.put((x, round(cy) + d, round(zc + hr * 1.1 * math.sin(th))), col)
    elif style == 'pumpkin':
        rib = dark(col, 0.18)
        for (x, y, z) in list(part.v):
            if (x, y, z) in inner:
                if z == z1:
                    part.put((x, y, z), light(col, 0.35))
                continue
            # the ribs only on the Blender build: the in-game boxes stay in
            # budget with a plain pumpkin
            if getattr(c, 'fine', False) and math.cos(ang(x, y) * 8) > 0.55:
                part.put((x, y, z), rib)
        # a curly stem and a leaf on the rim at the back
        st = c.part('stem', 'static')
        sy = round(thi[1] - 0.2 * k)
        for i in range(max(2, round(0.8 * k))):
            st.put((0, sy + i // 2, z1 + 1 + i), hexc('#6B8E23'))
            st.put((-1, sy + i // 2, z1 + 1 + i), hexc('#6B8E23'))
        ball(st, (1.2 * k, sy, z1 + 0.6 * k), (0.8 * k, 0.5 * k, 0.25 * k + .3), hexc('#5DBB63'))
    elif style == 'cauldron':
        iron = col
        rim = light(col, 0.18)
        for (x, y, z) in list(part.v):
            if z >= z1 - max(0, round(0.25 * k)):
                part.put((x, y, z), rim)
        # three stubby feet and a glowing brew round the creature
        for i in range(3):
            th = math.pi / 2 + i * 2 * math.pi / 3
            fx, fy = math.cos(th) * rx * 0.6, cy + math.sin(th) * ry * 0.6
            part.box((round(fx) - 1, round(fy) - 1, 0), (round(fx), round(fy), 0), dark(iron, 0.3))
        brew = col2 or hexc('#7CFF6B')
        zb = z1 - 1
        for (x, y, z) in list(inner):
            if z == zb:
                part.put((x, y, z), brew, True)
        bub = c.part('bubbles', 'glow')
        for i in range(2):
            th = i * 2.6 + 0.4
            bx, by = math.cos(th) * rx * 0.55, cy + math.sin(th) * ry * 0.55
            ball(bub, (bx, by, z1 + 0.5 + (i % 2) * 0.5 * k), (0.35 * k + .2,) * 3, light(brew, 0.3))
        for p in list(bub.v):
            bub.v[p] = (bub.v[p][0], True)
        # whatever of the creature sits under the brew is never seen: drop it
        # (its faces would only cost triangles)
        sunk = {q for q in inner if q[2] <= zb}
        for p in c.parts:
            if p is not part:
                for q in [q for q in p.v if q in sunk or (q[2] <= zb and q in part.v)]:
                    del p.v[q]
        # legs poking out through the iron are tucked in: it sits in its pot
        for p in legs_of(c):
            for q in [q for q in p.v if q[2] <= z1 and
                      ((q[0] + .5) / (rx + 1.5)) ** 2 + ((q[1] + .5 - cy) / (ry + 1.5)) ** 2 <= 1]:
                del p.v[q]
    elif style == 'thimble':
        dim = dark(col, 0.2)
        for (x, y, z) in list(part.v):
            if (x, y, z) in inner:
                if z == z1:
                    part.put((x, y, z), dark(col, 0.3))
                continue
            if z0 < z < z1 - 1 and (x + z) % 2 == 0 and (y + z) % 2 == 0:
                part.put((x, y, z), dim)
            if z == z1:
                part.put((x, y, z), light(col, 0.25))


def mitten(c, H, col, col2, a):
    k = _k(H)
    col2 = col2 or WHITE
    body = _find(c, 'body')
    tlo, thi, belly = torso(c)
    front = tlo[1] + (thi[1] - tlo[1]) * 0.28
    m = _Into(body)  # drawn into the body: no hidden faces under the knit
    rib = dark(col, 0.15)
    for (x, y, z) in list(body.v):
        if z < belly or y < front:
            continue
        for dx in (-1, 0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    q = (x + dx, y + dy, z + dz)
                    if q not in body.v and q[2] >= belly:
                        m.put(q, col)
    # knit: little v rows; the cuff at the front opening
    for (x, y, z) in list(m.v):
        if y <= front + max(1, round(0.5 * k)):
            m.put((x, y, z), col2 if (x + z) % 2 == 0 else light(col2, 0.2) if col2 != WHITE else hexc('#F1EDE6'))
        elif (z + (abs(x) % 2)) % 3 == 0:
            m.put((x, y, z), rib)
    # a thumb on the right side
    xr = max(p[0] for p in m.v)
    zc = (belly + thi[2]) / 2
    yc = (front + thi[1]) / 2
    ball(m, (xr + 0.3 * k, yc - 0.3 * k, zc), (0.8 * k, 1.0 * k, 0.9 * k), col)


def shell(c, H, col, col2, a):
    k = _k(H)
    col2 = col2 or dark(col, 0.3)
    tlo, thi, belly = torso(c)
    cy = (tlo[1] + thi[1]) / 2 + 0.3 * k
    r = (thi[2] - belly) * 0.54 + 0.45 * k
    cz = thi[2] + r * 0.35
    from voxkit import Part
    s = Part('shell')  # drawn into the body below: no faces between them
    w = (thi[0] - tlo[0] + 1) / 2 * 0.95
    s.ell((0, cy, cz), (w, r, r), col)
    band = max(1.0, 0.75 * k)
    for p in list(s.v):
        dy, dz = p[1] + .5 - cy, p[2] + .5 - cz
        rr = math.hypot(dy, dz)
        th = math.atan2(dz, dy) / (2 * math.pi)
        if int((rr / band + th * 1.0) % 2) == 0 and rr > band * 0.6:
            s.v[p] = (col2, False)
    # a pale lip where it sits on the back
    for p in list(s.v):
        if p[2] <= belly + (thi[2] - belly) * 0.55:
            del s.v[p]
    body = _find(c, 'body')
    body.v.update(s.v)


def ball_acc(c, H, col, col2, a):
    k = _k(H)
    style = a.get('style', 'beach')
    b = c.part('ball', 'static')
    if style == 'beach':
        head = head_of(c)
        _, yf, _ = snout_tip(c)
        nose = [p for p in head.v if p[1] <= yf + 1]
        zt = max(p[2] for p in nose)
        r = 1.15 * k
        cen = (0, yf + r * 0.4, zt + r + 0.4)
        b.ell(cen, (r, r, r), col)
        cols = [col, col2 or hexc('#4D9DE0'), WHITE, hexc('#FFD43B')]
        for p in list(b.v):
            th = math.atan2(p[1] + .5 - cen[1], p[0] + .5)
            b.v[p] = (cols[int((th / (2 * math.pi) + 0.5) * 6) % 4], False)
        for x in (-1, 0):
            b.put((x, round(cen[1]) - (0 if k < 1.5 else 0), round(cen[2] + r) - 0), WHITE)
    elif style in ('coconut', 'dung'):
        body_parts = [p for p in c.parts]
        ymin = min(p[1] for q in body_parts for p in q.v)
        r = (1.0 if style == 'coconut' else 1.5) * k
        cen = (0, ymin - r * 0.85, r)
        b.ell(cen, (r, r, r * 0.95), col)
        if style == 'coconut':
            for p in list(b.v):
                if _hash(*p, 11) % 4 == 0:
                    b.v[p] = (dark(col, 0.25), False)
            for i, (ex, ez) in enumerate(((-0.35, 0.3), (0.35, 0.3), (0, -0.1))):
                f = b.front(math.floor(ex * r), math.floor(cen[2] + ez * r))
                if f:
                    b.put(f, col2 or INK)
        else:
            for p in list(b.v):
                if _hash(*p, 5) % 5 == 0:
                    b.v[p] = (dark(col, 0.2), False)
                elif _hash(*p, 6) % 7 == 0:
                    b.v[p] = (light(col, 0.15), False)
    elif style == 'berry':
        _, yf, z = snout_tip(c)
        r = 0.6 * k
        cen = (0, yf + 0.2 * k, z - 1.1 * k)
        ball(b, cen, (r, r, r), col)
        b.put((0, math.floor(cen[1] - r * 0.5), math.floor(cen[2] + r * 0.5)), light(col, 0.5))
        b.put((0, math.floor(cen[1]), math.floor(cen[2] + r) + 1), col2 or hexc('#5DBB63'))
        b.put((-1, math.floor(cen[1]), math.floor(cen[2] + r) + 1), col2 or hexc('#5DBB63'))


def pot(c, H, col, col2, a):
    k = _k(H)
    col2 = col2 or hexc('#FFC93C')
    tlo, thi, belly = torso(c)
    p = c.part('pot', 'static')
    r = 1.15 * k
    cen = (0, tlo[1] - r * 0.55, belly + r * 0.9)
    p.ell(cen, (r, r * 0.9, r), col)
    top = math.floor(cen[2] + r * 0.75)
    for q in list(p.v):
        if q[2] > top:
            del p.v[q]
    for x in range(math.floor(-r * 0.75), math.ceil(r * 0.75)):
        for y in range(math.floor(cen[1] - r * 0.7), math.ceil(cen[1] + r * 0.7)):
            if ((x + .5) / (r * 0.75)) ** 2 + ((y + .5 - cen[1]) / (r * 0.7)) ** 2 <= 1:
                p.put((x, y, top + 1), col2)
    # honey dripping over the rim, a band round the neck
    for x in (-1, 0, 1, -2):
        f = p.front(x, top)
        if f:
            for d in range(1 + (_hash(x, 2) % max(1, round(0.9 * k)))):
                p.put((f[0], f[1], f[2] - d), col2)
    for q in list(p.v):
        if q[2] == top - max(1, round(0.3 * k)) and p.v[q][0] == col:
            p.v[q] = (dark(col, 0.25), False)


def bubble(c, H, col, col2, a):
    k = _k(H)
    _, yf, z = snout_tip(c)
    b = c.part('bubble', 'static')
    r = a.get('size', 1.1) * k
    cen = (0, yf - r + 1, z - 0.2 * k)
    b.ell(cen, (r, r, r), col)
    b.put((math.floor(-r * 0.4), math.floor(cen[1] - r * 0.8), math.floor(cen[2] + r * 0.45)), WHITE)
    b.put((math.floor(-r * 0.4) - 1, math.floor(cen[1] - r * 0.75), math.floor(cen[2] + r * 0.45)), WHITE)


def tusks(c, H, col, col2, a):
    k = _k(H)
    head = head_of(c)
    _, yf, z = snout_tip(c)
    t = c.part('tusks', 'static')
    zb = min(p[2] for p in head.v if p[1] <= yf + 1)
    x = max(1, round(0.75 * k))
    n = max(2, round(1.0 * k))
    for i in range(n):
        mput(t, x + (1 if i == n - 1 else 0), yf + 1 - (i // 2), zb + i, col)


def snout(c, H, col, col2, a):
    k = _k(H)
    L, droop, r = a.get('length', 2.0) * k, a.get('droop', 0.3), a.get('r', 0.5) * k
    head = head_of(c)
    _, yf, z = snout_tip(c)
    s = c.part('snout', 'static')
    start = (0, yf + 1.2 * k, z)
    mid = (0, yf - L * 0.5, z - droop * L * 0.25)
    end = (0, yf - L, z - droop * L * 0.75)
    tube(s, [start, mid, end], r, r * 0.75, col, colfn=lambda t: (col2 or dark(col, 0.4)) if t > 0.93 else col)
    del head  # (the snout rides the head)


def _horn(part, pts, r0, r1, col, col2=None):
    tube(part, pts, r0, r1, col, colfn=(lambda t: col2 if col2 and t > 0.8 else col))


def hornset(c, H, col, col2, a):
    k = _k(H)
    style = a.get('style', 'swept')
    head = head_of(c)
    y, zt = crown(c)
    h = c.part('horns', 'static')
    bx = 0.75 * k
    for sx in (-1, 1):
        def P(x, yy, z, sx=sx):
            return (sx * x if sx > 0 else -x, yy, z)
        if style == 'ibex':
            # thick ridged arcs from the brow, up and back over the neck
            _, yf, _ = snout_tip(c)
            yb = y - 0.9 * k
            pts = [(bx * 1.0, yb, zt - 0.5 * k), (bx * 1.1, yb + 0.3 * k, zt + 0.6 * k),
                   (bx * 1.3, yb + 1.4 * k, zt + 1.4 * k), (bx * 1.45, yb + 2.8 * k, zt + 1.5 * k),
                   (bx * 1.55, yb + 4.0 * k, zt + 0.8 * k), (bx * 1.55, yb + 4.6 * k, zt - 0.3 * k)]
            pts = [((p[0] if sx > 0 else -p[0]), p[1], p[2]) for p in pts]
            ridge = col2 or dark(col, 0.25)
            tube(h, pts, 0.62 * k, 0.26 * k, col, colfn=lambda t: ridge if int(t * 14) % 2 else col)
            continue
        if style == 'swept':
            pts = [(bx, y - 0.3 * k, zt - 0.2 * k), (bx + 0.2 * k, y + 0.4 * k, zt + 1.4 * k),
                   (bx + 0.35 * k, y + 1.6 * k, zt + 2.3 * k), (bx + 0.45 * k, y + 2.8 * k, zt + 2.2 * k),
                   (bx + 0.5 * k, y + 3.5 * k, zt + 1.5 * k)]
            r0, r1 = 0.55 * k, 0.25 * k
        elif style == 'curled':
            cx, cz, R = bx + 0.6 * k, zt - 0.3 * k, 0.75 * k
            pts = [(bx, y, zt - 0.1 * k)]
            for i in range(9):
                th = math.pi * 0.6 - i * (math.pi * 1.5 / 8)
                pts.append((cx + R * math.cos(th) * (1 - i * 0.04), y + 0.15 * k * i, cz + R * math.sin(th) * (1 - i * 0.04)))
            r0, r1 = 0.4 * k, 0.22 * k
        elif style == 'wide':
            pts = [(bx - 0.2 * k, y, zt - 0.4 * k), (bx + 1.2 * k, y + 0.3 * k, zt - 0.1 * k),
                   (bx + 2.0 * k, y + 0.9 * k, zt + 0.3 * k), (bx + 2.3 * k, y + 1.6 * k, zt + 1.0 * k)]
            r0, r1 = 0.75 * k, 0.32 * k
        else:  # tri / pair: a pair, back over the head
            pts = [(bx, y, zt - 0.2 * k), (bx + 0.15 * k, y + 0.6 * k, zt + 1.2 * k),
                   (bx + 0.2 * k, y + 1.4 * k, zt + 1.7 * k)]
            r0, r1 = 0.38 * k, 0.2 * k
        if style == 'rhino':
            break
        pts = [((p[0] if sx > 0 else -p[0]), p[1], p[2]) for p in pts]
        _horn(h, pts, r0, r1, col, col2)
    if style == 'tri':  # and a third in the middle of the forehead
        _, yf, z = snout_tip(c)
        ey = eye_spots(c)
        zb = (max(e[2] for e in ey) + 1.2 * k) if ey else zt - 0.6 * k
        _horn(h, [(0, yf + 0.9 * k, zb), (0, yf + 0.5 * k, zb + 1.0 * k), (0, yf + 0.8 * k, zb + 1.8 * k)],
              0.4 * k, 0.18 * k, col, col2)
    if style == 'rhino':
        _, yf, z = snout_tip(c)
        _horn(h, [(0, yf + 0.6 * k, z + 0.2 * k), (0, yf - 0.4 * k, z + 1.2 * k), (0, yf - 0.6 * k, z + 2.4 * k),
                  (0, yf + 0.0 * k, z + 3.3 * k)], 0.75 * k, 0.3 * k, col, col2)
    # left and right exactly mirrored
    right = {p: v for p, v in h.v.items() if p[0] >= 0}
    if style != 'rhino':
        h.v = dict(right)
        for (x, yy, z), v in right.items():
            h.v[(-x - 1, yy, z)] = v
    del head


def _ear_base(c, bx):
    """(y, z) where an ear at x = bx sits on the top of the head."""
    head = head_of(c)
    xs = [p for p in head.v if p[0] == round(bx)]
    if not xs:
        xs = list(head.v)
    yc = sum(p[1] for p in xs) / len(xs)
    top = [p[2] for p in xs if abs(p[1] - yc) <= 1]
    return yc, (max(top) if top else max(p[2] for p in xs))


def earset(c, H, col, col2, a):
    k = _k(H)
    style = a.get('style', 'roo')
    head = head_of(c)
    ears = _find(c, 'ears') or c.part('ears', 'static', (0, crown(c)[0], crown(c)[1]))
    ears.v = {}
    if style == 'none':  # no ears to see (a pangolin's are tucked in)
        return
    inner = col2 or PINK
    hlo, hhi = bounds(head.v)
    half = (hhi[0] - hlo[0] + 1) / 2
    if style in ('roo', 'huge', 'tufted', 'pointy', 'tiny', 'round'):
        if style == 'round' or style == 'tiny':
            size = a.get('size', 0.75 if style == 'round' else 0.35) * k
            bx = half * 0.62
            yc, zb = _ear_base(c, bx)
            for sx in (1,):
                cen = (bx + 0.1 * k, yc, zb + size * 0.6)
                ears.ell(cen, (size, max(0.6, 0.32 * k), size), col)
                if style == 'round' and size >= 1.2:
                    ears.ell((cen[0], cen[1] - 0.25 * k, cen[2]), (size * 0.6, 0.2 * k + .2, size * 0.6), inner)
        else:
            Hh = {'roo': 2.2, 'huge': 2.6, 'tufted': 2.2, 'pointy': 1.8}[style] * k
            Wb = {'roo': 0.85, 'huge': 1.35, 'tufted': 0.9, 'pointy': 1.0}[style] * k
            tilt = {'roo': 0.25, 'huge': 0.55, 'tufted': 0.12, 'pointy': 0.15}[style]
            bx = half * (0.5 if style != 'huge' else 0.55)
            yc, zb = _ear_base(c, bx)
            th = max(1, round(0.35 * k))
            n = max(3, round(Hh))
            for i in range(n + 1):
                t = i / n
                w = Wb * (1 - t) ** (0.8 if style == 'roo' else 1.0) + 0.3
                for u10 in range(-int(w * 10), int(w * 10) + 1, 5):
                    u = u10 / 10
                    x = bx + u * math.cos(tilt) + i * math.sin(tilt)
                    z = zb - 1 + i * math.cos(tilt) - u * math.sin(tilt) * 0.5
                    for d in range(th):
                        is_in = abs(u) < w - 0.8 and 0.12 < t < 0.8 and d == 0
                        ears.put((math.floor(x), round(yc) - d, math.floor(z)), inner if is_in else col)
            if style == 'tufted':
                # a straight tuft from the tip, one voxel wide
                tip = max((p for p in ears.v if p[0] >= 0), key=lambda p: (p[2], -p[1]))
                for j in range(max(2, round(1.0 * k))):
                    ears.put((tip[0], tip[1], tip[2] + 1 + j), col2 or INK)
        right = {p: v for p, v in ears.v.items() if p[0] >= 0}
        ears.v = dict(right)
        for (x, y, z), v in right.items():
            ears.v[(-x - 1, y, z)] = v
    elif style == 'fold':
        # small ears folded flat forward over the crown
        bx = half * 0.5
        yc, zb = _ear_base(c, bx)
        w = max(2, round(0.8 * k))
        for i in range(max(2, round(0.8 * k))):
            for x in range(round(bx - w / 2) + i // 2, round(bx + w / 2) - i // 2 + 1):
                mput(ears, x, round(yc) - i - 1, zb + 1 - (i // 2), col)


def _tail_part(c):
    t = _find(c, 'tail')
    ry, rz = rump(c)
    if t is None:
        t = c.part('tail', 'tail', (0, ry, rz))
    t.v = {}
    return t, ry, rz


def tailset(c, H, col, col2, a):
    k = _k(H)
    style = a.get('style', 'long')
    t, ry, rz = _tail_part(c)
    t.pivot = (0, ry, rz)
    rings = a.get('rings')
    c2 = col2 or dark(col, 0.4)
    ringfn = (lambda tt: c2 if int(tt * 7) % 2 == 1 else col) if rings else None
    y0 = ry - 0.6 * k
    if style == 'curl':
        pts = [(0, y0, rz), (0, ry + 1.4 * k, rz + 0.4 * k), (0, ry + 2.4 * k, rz + 1.6 * k)]
        cy, cz, R = ry + 2.0 * k, rz + 2.6 * k, 0.9 * k
        for i in range(10):
            th = -0.2 - i * 0.62
            pts.append((0, cy + R * math.cos(th) * (1 - i * 0.05), cz + R * math.sin(-th) * (1 - i * 0.05)))
        tube(t, pts, 0.55 * k, 0.3 * k, col, ringfn)
    elif style == 'upright':
        pts = [(0, y0, rz), (0, ry + 0.6 * k, rz + 1.2 * k), (0, ry + 0.9 * k, rz + 3.2 * k)]
        tube(t, pts, a.get('r', 0.45) * k, a.get('r', 0.45) * k * 0.8, col, ringfn)
        if a.get('tuft'):
            ball(t, (0, ry + 0.95 * k, rz + 3.4 * k), (0.45 * k, 0.4 * k, 0.6 * k), c2)
    elif style == 'tuft':
        pts = [(0, y0, rz), (0, ry + 1.5 * k, rz + 0.5 * k), (0, ry + 3.0 * k, rz + 0.3 * k),
               (0, ry + 4.0 * k, rz - 0.5 * k)]
        tube(t, pts, 0.22 * k, 0.18 * k, col)
        ball(t, (0, ry + 4.4 * k, rz - 0.8 * k), (0.55 * k, 0.75 * k, 0.6 * k), c2)
    elif style == 'roo':
        pts = [(0, y0, rz), (0, ry + 1.3 * k, rz - 0.9 * k), (0, ry + 2.8 * k, 0.45 * k), (0, ry + 3.8 * k, 0.4 * k)]
        tube(t, pts, 0.85 * k, 0.4 * k, col, ringfn)
    elif style == 'long':
        pts = [(0, y0, rz), (0, ry + 1.4 * k, rz - 0.6 * k), (0, ry + 2.4 * k, rz - 1.6 * k),
               (0, ry + 3.0 * k, max(0.5 * k, rz - 2.6 * k)), (0, ry + 3.5 * k, max(0.5 * k, rz - 2.4 * k) + 0.6 * k)]
        tube(t, pts, a.get('r', 0.4) * k, a.get('r', 0.4) * k * 0.7, col, ringfn)
    elif style == 'bushy':
        pts = [(0, y0, rz), (0, ry + 1.5 * k, rz - 0.5 * k), (0, ry + 3.0 * k, rz - 0.3 * k),
               (0, ry + 3.8 * k, rz + 0.6 * k)]
        tube(t, pts, 0.6 * k, 1.0 * k, col, ringfn)
        if col2 and not rings:
            ball(t, (0, ry + 4.0 * k, rz + 1.0 * k), (0.8 * k, 0.6 * k, 0.6 * k), col2)
    elif style == 'brush':  # a fox's huge brush: as big as the body, sweeping up and round
        sz = a.get('size', 1.0)
        pts = [(0, y0, rz), (0, ry + 1.2 * k * sz, rz + 0.2 * k), (0, ry + 2.4 * k * sz, rz + 1.0 * k * sz),
               (0, ry + 3.0 * k * sz, rz + 2.4 * k * sz), (0, ry + 2.6 * k * sz, rz + 3.6 * k * sz),
               (0, ry + 1.7 * k * sz, rz + 4.1 * k * sz)]
        lift = a.get('lift', 0) * k  # raise it up the back (a squirrel's tail stands tall)
        pts = [(p[0], p[1] - lift * 0.35 * i / 5, p[2] + lift * i / 5) for i, p in enumerate(pts)]
        prof = lambda tt: (0.5 + 1.1 * math.sin(min(1, tt * 1.25) * math.pi * 0.85)) * k * sz  # noqa: E731
        for i in range(len(pts) - 1):
            a0, a1 = pts[i], pts[i + 1]
            n = 8
            for j in range(n + 1):
                tt = (i + j / n) / (len(pts) - 1)
                cen = tuple(a0[q] + (a1[q] - a0[q]) * j / n for q in range(3))
                r = prof(tt)
                cc = (col2 or WHITE) if tt > 0.8 else col
                ball(t, cen, (r * 0.95, r, r), cc)
    elif style == 'train':  # a long trailing bird tail: two ribbons
        for sx in (-1, 1):
            x = sx * 0.35 * k
            pts = [(x, y0, rz), (x * 1.5, ry + 1.8 * k, rz - 0.6 * k), (x * 2, ry + 3.4 * k, rz - 1.0 * k),
                   (x * 2.5, ry + 4.6 * k, rz - 0.6 * k)]
            tube(t, pts, 0.35 * k, 0.25 * k, col, (lambda tt: c2 if tt > 0.85 else col) if col2 else None)
    elif style == 'plume':  # bird of paradise: a fountain of plumes
        for i, sx in enumerate((-1.0, -0.5, 0, 0.5, 1.0)):
            pts = [(0, y0, rz), (sx * 0.6 * k, ry + 1.2 * k, rz + 1.0 * k + abs(sx) * -0.5 * k),
                   (sx * 1.4 * k, ry + 2.4 * k, rz + 1.2 * k - abs(sx) * 0.8 * k),
                   (sx * 1.9 * k, ry + 3.2 * k, rz + 0.2 * k - abs(sx) * 0.6 * k)]
            tube(t, pts, 0.3 * k, 0.32 * k, col, (lambda tt: c2 if tt > 0.7 else col) if col2 else None)
    elif style == 'pinwheel':
        tube(t, [(0, y0, rz), (0, ry + 1.6 * k, rz + 0.8 * k)], 0.2 * k, 0.2 * k, hexc('#C9A26B'))
        cy, cz = ry + 1.7 * k, rz + 1.6 * k
        R = 1.6 * k
        for q in range(4):
            cc = col if q % 2 == 0 else (col2 or WHITE)
            for i in range(int(R * 3)):
                for j in range(int(R * 3)):
                    u, v = i / 3, j / 3
                    if v > u:  # a triangle blade
                        continue
                    th = q * math.pi / 2
                    x = u * math.cos(th) - v * math.sin(th)
                    z = u * math.sin(th) + v * math.cos(th)
                    t.put((math.floor(x), round(cy), math.floor(cz + z)), cc)
        t.put((0, round(cy) - 1, round(cz)), hexc('#FFD43B'))
        t.put((-1, round(cy) - 1, round(cz)), hexc('#FFD43B'))
    elif style == 'drip':
        pts = [(0, y0, rz), (0, ry + 1.2 * k, rz + 0.6 * k), (0, ry + 2.2 * k, rz + 1.6 * k)]
        tube(t, pts, 0.55 * k, 0.45 * k, col)
        for p in list(t.v):
            if (p[1], p[2] - 1) and (p[0], p[1], p[2] - 1) not in t.v and _hash(p[0], p[1], 4) % 3 == 0:
                for d in range(1, 1 + _hash(*p, 9) % max(2, round(0.9 * k))):
                    t.put((p[0], p[1], p[2] - d), col2 or light(col, 0.3))
    if not t.v:
        t.put((0, round(ry), round(rz)), col)


def wingfold(c, H, col, col2, a):
    """Folded wings sweep forward: each wing's lower voxels move forward
    (`forward` voxels per voxel down from the shoulder, default 0.5), so the
    tips wrap round the body's side."""
    f = a.get('forward', 0.5)
    taken = set()
    for p in c.parts:
        if p.name not in ('wingL', 'wingR'):
            taken |= set(p.v)
    for name in ('wingL', 'wingR'):
        w = _find(c, name)
        if not w:
            continue
        top = max(q[2] for q in w.v)
        moved = {}
        for (x, y, z), v in w.v.items():
            q = (x, y - round((top - z) * f), z)
            if q not in taken:
                moved[q] = v
        w.v = moved


def wingset(c, H, col, col2, a):
    k = _k(H)
    style = a.get('style', 'feather')
    tlo, thi, belly = torso(c)
    if _find(c, 'wingL'):
        return
    sy = tlo[1] + (thi[1] - tlo[1]) * 0.4
    sz = belly + (thi[2] - belly) * 0.8
    sxr = thi[0] * 0.7
    span = a.get('span', 2.6) * k
    occupied = set()
    for p in c.parts:
        occupied |= set(p.v)
    for sx, name in ((-1, 'wingL'), (1, 'wingR')):
        w = c.part(name, name, (sx * sxr, sy, sz))
        nu = max(3, round(span))
        for i in range(nu + 1):
            u = i / nu
            x = sxr + i
            if style == 'bat':
                lift = 0.9 * k * math.sin(u * math.pi * 0.7)
                yf = sy - 0.5 * k - 0.4 * k * u
                yb = sy + (1.6 - 0.4 * u) * k
                scallop = 0.5 * k * abs(math.sin(u * math.pi * 3))
                yb -= scallop
            else:
                lift = 1.0 * k * u
                yf = sy - 0.5 * k + 0.2 * k * u
                yb = sy + (1.8 + 0.6 * u) * k - (0.6 * k * u * u)
                if i % 2 == 1:
                    yb -= 0.4 * k
            for y in range(math.floor(yf), math.ceil(yb) + 1):
                for d in range(1 if k < 1.6 else 2):
                    z = round(sz + lift) - d
                    xx = x if sx > 0 else -x - 1
                    edge = y >= yb - 0.6 * k
                    if style == 'bat':
                        bone = any(abs((y - yf) - f * (yb - yf)) < 0.6 for f in (0.0,)) or (i % max(2, nu // 3) == 0)
                        cc = dark(col, 0.25) if bone else (col2 or col)
                    else:
                        cc = (col2 if (col2 and edge) else col)
                    w.put((math.floor(xx), y, z), cc)
        for p in [p for p in w.v if p in occupied]:
            del w.v[p]


def boots(c, H, col, col2, a):
    k = _k(H)
    style = a.get('style', 'rain')
    targets = legs_of(c) or [_find(c, 'body')]
    hgt = (0.5 if style == 'feather' else 0.9) * k
    for part in targets:
        if not part.v:
            continue
        z0 = min(p[2] for p in part.v)
        low = [p for p in part.v if p[2] <= z0 + hgt]
        top = max(p[2] for p in low) if low else z0
        add = {}
        for (x, y, z) in low:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    if style == 'feather' and _hash(x + dx, y + dy, z, 3) % 3 == 0:
                        continue
                    q = (x + dx, y + dy, z)
                    if q not in part.v:
                        add[q] = col
            part.v[(x, y, z)] = ((col2 if (style == 'rain' and z == top and col2) else col), False)
        for q, cc in add.items():
            part.put(q, (col2 if (style == 'rain' and q[2] == top and col2) else cc))


def stilts(c, H, col, col2, a):
    k = _k(H)
    n = max(1, round(a.get('length', 0.8) * k))
    legs = legs_of(c)
    if legs:
        stand = legs
    else:
        stand = [_find(c, 'body')]
    for part in c.parts:
        old = part.v
        bottom = {(x, y): v for (x, y, z), v in old.items() if z == 0} if part in stand else {}
        second = {(x, y): v for (x, y, z), v in old.items() if z == 1} if part in stand else {}
        part.v = {(x, y, z + n): v for (x, y, z), v in old.items()}
        part.pivot = (part.pivot[0], part.pivot[1], part.pivot[2] + n)
        for (x, y), v in bottom.items():
            part.v[(x, y, 0)] = v
            src = second.get((x, y))
            if src is None:
                # a toe or splayed foot: rise from its nearest shin column
                near = min(second, key=lambda q: (q[0] - x) ** 2 + (q[1] - y) ** 2) if second else None
                if near and (near[0] - x) ** 2 + (near[1] - y) ** 2 > 2:
                    continue
                src = v
            for z in range(1, n + 1):
                part.v[(x, y, z)] = src


def carapace(c, H, col, col2, a):
    k = _k(H)
    style = a.get('style', 'bands')
    body = _find(c, 'body')
    tlo, thi, belly = torso(c)
    zcut = belly + (thi[2] - belly) * (0.35 if style == 'bands' else 0.3)
    head = head_of(c)
    hy = max(p[1] for p in head.v) if head is not body else tlo[1]
    if style == 'plates':
        return _plates(c, k, body, head, col, col2, belly, thi, a)
    srcs = [body] + ([_find(c, 'tail')] if style == 'scales' and _find(c, 'tail') else [])
    seam = col2 or dark(col, 0.3)
    bw = max(2, round(0.7 * k))
    for src in srcs:
        # the armour is drawn into the part it covers: one surface, no
        # hidden faces underneath
        add = {}
        for (x, y, z) in list(src.v):
            if z < zcut or (src is body and y < hy - 1.0 * k):
                continue
            for d in ((1, 0, 0), (-1, 0, 0), (0, 0, 1), (0, 1, 0)):
                q = (x + d[0], y + d[1], z + d[2])
                if q not in src.v:
                    add[q] = col
        if not add:
            continue
        ylo = min(p[1] for p in add)
        for p in add:
            cc = col
            if style == 'bands':
                if (p[1] - ylo) % bw == 0:
                    cc = seam
            else:
                row = (p[1] - ylo) // bw
                off = (p[0] + (bw // 2 if row % 2 else 0)) % bw
                if (p[1] - ylo) % bw == 0 or off == 0:
                    cc = seam
                elif (p[1] - ylo) % bw == bw - 1:
                    cc = light(col, 0.15)
            src.put(p, cc)


def skirt(c, H, col, col2, a):
    k = _k(H)
    body = _find(c, 'body')
    tlo, thi, belly = torso(c)
    zm = round(belly + (thi[2] - belly) * a.get('from', 0.45))
    sil = {(x, y) for (x, y, z) in body.v if z == zm}
    ring = set()
    for (x, y) in sil:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in sil:
                ring.add(q)
    # its own (still) part: drawn into the body, the leg split would take
    # its long fringe for legs
    s = c.part('skirt', 'static')
    if a.get('sides'):  # only down the flanks, front and back left open
        xs = [x for (x, y) in sil]
        half = (max(xs) - min(xs) + 1) / 2
        ring = {(x, y) for (x, y) in ring if abs(x + .5) >= half * 0.6}
    cols = [col] + ([hexc(c2) if isinstance(c2, str) else c2 for c2 in a.get('strands', [])] if a.get('strands') else [])
    cells = ring
    bodyv = set(body.v)
    if a.get('solid'):  # a filled coat down to the hem, holes where the legs swing
        legxy = {(x, y) for p in c.parts if p.name.startswith('leg') for (x, y, z) in p.v}
        cells = (ring | sil) - legxy
    for (x, y) in cells:
        j = a.get('jag', 2)
        zs = round(a.get('length', 0.9) * k) + _hash(x // j, y // j, 31) % (a.get('shag', 1) + 1)
        cc = cols[_hash(x, y, 37) % len(cols)] if (x, y) in ring else col
        for z in range(zs, zm + 1):
            if (x, y, z) not in bodyv:
                s.put((x, y, z), cc)


def fluff(c, H, col, col2, a):
    k = _k(H)
    style = a.get('style', 'fur')
    parts = [_find(c, 'body')] + ([_find(c, 'head')] if a.get('head') and _find(c, 'head') else [])
    ey = eye_spots(c)
    yface = min(e[1] for e in ey) + 1.6 * k if ey else -1e9
    f = c.part('fluff', 'static') if style == 'popcorn' else None
    occupied = set()
    for p in c.parts:
        occupied |= set(p.v)
    if style == 'popcorn':
        body = parts[0]
        tlo, thi, belly = torso(c)
        every = max(1, int(a.get('every', 6)))
        spots = [p for p in surface_up(body) if p[2] >= belly + (thi[2] - belly) * 0.3]
        if len(parts) > 1:
            # a few kernels on the crown too: the top of the head only, off the face
            head = parts[1]
            htop = max(p[2] for p in head.v)
            spots += [p for p in surface_up(head) if p[2] >= htop - 0.6 * k and p[1] >= yface - 1.6 * k]
        for (x, y, z) in spots:
            h = _hash(x, y, z, 21)
            if h % every == 0:
                cc = col if (h >> 4) % 3 else (col2 or hexc('#FFE08A'))
                ball(f, (x + .5, y + .5, z + 0.5 + 0.2 * k), (0.45 * k + .2,) * 3, cc)
        return
    layers = a.get('layers', 1)
    tlo, thi, belly = torso(c)
    for part in parts:
        shell = set(part.v)
        coat = {}
        for layer in range(layers):
            add = set()
            for (x, y, z) in shell:
                if part.name == 'head' and y < yface:
                    continue
                for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1)):
                    q = (x + d[0], y + d[1], z + d[2])
                    if q in shell or q in occupied or q[2] < belly:
                        continue
                    add.add((q, (x, y, z)))
            for q, src in add:
                # the coat takes the colour under it, so patterns show through
                under = part.v.get(src, (coat.get(src, col),))[0]
                coat[q] = col if a.get('solid') or under in (INK, WHITE) else under
            shell |= {q for q, _ in add}
        # a few tufts standing up from the top of the coat
        for (x, y, z) in list(coat):
            if (x, y, z + 1) not in coat and (x, y, z + 1) not in part.v and x % 2 == 0 and y % 2 == 0 \
                    and _hash(x // 2, y // 2, 13) % 5 == 0:
                coat[(x, y, z + 1)] = light(col, 0.1)
        for q, cc in coat.items():  # into the part itself: no faces between coat and body
            part.put(q, cc)
    return


def frizz(c, H, col, col2, a):
    k = _k(H)
    body = _find(c, 'body')
    head = _find(c, 'head')
    f = _Into(body)  # the curls are part of the body
    ey = eye_spots(c)
    yface = min(e[1] for e in ey) + 1.2 * k if ey else -1e9
    tlo, thi, belly = torso(c)
    cy = (tlo[1] + thi[1]) / 2
    for part in [p for p in (body, head) if p]:
        cz = sum(p[2] for p in part.v) / len(part.v)
        pcy = sum(p[1] for p in part.v) / len(part.v)
        for (x, y, z) in list(part.v):
            if z < belly or (part is head and y < yface):
                continue
            if _hash(x // 2, y // 2, z // 2, 41) % 7 != 0 or (x % 2, y % 2, z % 2) != (0, 0, 0):
                continue
            if (x, y, z) not in [q for q in surface_up(part) if q == (x, y, z)] and _hash(x, y, z, 3) % 2:
                continue
            n = (x + .5, y + .5 - pcy, z + .5 - cz)
            L = math.hypot(*n) or 1
            n = (n[0] / L, n[1] / L, n[2] / L)
            p0 = (x + .5, y + .5, z + .5)
            curl = 1 if _hash(x, y, 2) % 2 else -1
            pts = [p0, (p0[0] + n[0] * 0.9 * k, p0[1] + n[1] * 0.9 * k, p0[2] + n[2] * 0.9 * k + 0.2 * k),
                   (p0[0] + n[0] * 1.2 * k + curl * 0.3 * k, p0[1] + n[1] * 1.3 * k, p0[2] + n[2] * 1.2 * k + 0.6 * k)]
            tube(f, pts, 0.2 * k, 0.15 * k, col if _hash(x, z, 5) % 3 else light(col, 0.15))
    del cy


def _plates(c, k, body, head, col, col2, belly, thi, a):
    """Pangolin armour: rows of overlapping plates over the back, the top
    of the head and the whole tail. Each plate is a stepped shingle: it
    stands one voxel proud at its back edge (dark seam under the lip), so
    the rows read as overlapping from any side."""
    seam = col2 or dark(col, 0.35)
    hi_col = light(col, 0.18)
    pw = max(4, round(1.3 * k))  # plate size
    tail = _find(c, 'tail')
    zcut = belly + (thi[2] - belly) * 0.25
    hlo, hhi = bounds(head.v) if head is not body else (None, None)
    for src in [p for p in (body, head if head is not body else None, tail) if p]:
        if src is head:
            ztop = hhi[2] - (hhi[2] - hlo[2]) * 0.45
            yfront = hlo[1] + (hhi[1] - hlo[1]) * 0.35  # leave the face and snout bare
            keep = lambda q: q[2] >= ztop and q[1] >= yfront  # noqa: E731
        elif src is tail:
            keep = lambda q: True  # noqa: E731
        else:
            keep = lambda q: q[2] >= zcut  # noqa: E731
        shell = {}
        for (x, y, z) in list(src.v):
            if not keep((x, y, z)):
                continue
            for d in ((1, 0, 0), (-1, 0, 0), (0, 0, 1), (0, 1, 0), (0, -1, 0)):
                q = (x + d[0], y + d[1], z + d[2])
                if q not in src.v and keep(q) and (src is tail or d != (0, -1, 0)):
                    shell[q] = (x, y, z)
        if not shell:
            continue
        ylo = min(p[1] for p in shell)
        for p in shell:
            row = (p[1] - ylo) // pw
            u = (p[1] - ylo) % pw
            col_i = (p[0] + p[2] + (pw // 2 if row % 2 else 0)) // pw
            cc = hi_col if u == 0 else col
            if (p[0] + p[2] + (pw // 2 if row % 2 else 0)) % pw == 0:
                cc = seam
            src.put(p, cc)
            if u == pw - 1 and src is not tail:
                # the back lip of the plate stands proud; its underside is the seam
                base = shell[p]
                out = (p[0] + (p[0] - base[0]), p[1] + (p[1] - base[1]), p[2] + (p[2] - base[2]))
                if out not in src.v and out[2] >= 0:
                    src.put(out, dark(col, 0.12) if col_i % 2 else col)
                src.put(p, seam)


def mushrooms(c, H, col, col2, a):
    """Four toadstools of different sizes down the back, clear of the head: a
    pale
    stem two or more voxels tall and a domed cap in color with color2 dots."""
    k = _k(H)
    m = c.part('mushrooms', 'static')
    body = _find(c, 'body')
    tlo, thi, belly = torso(c)
    top = {}
    for (x, y, z) in body.v:
        top[(x, y)] = max(top.get((x, y), -1), z)
    stem_col = col2 or hexc('#FFF6E8')
    dot = col2 or WHITE
    hy = max(p[1] for p in head_of(c).v) if head_of(c) is not body else tlo[1]
    r0 = 0.75 * k + 0.3
    # four of different sizes in two rows down the back, behind the head and
    # apart from each other, their stems of different heights
    back = [q for q in top if q[1] > hy + 1]
    ya = min(q[1] for q in back) if back else tlo[1]
    yz = max(q[1] for q in back) if back else thi[1]
    yf = ya + r0 * 0.8
    yb = max(yf + r0 * 2.0, yz - r0 * 0.6)
    spots = ((-(r0 + 0.6), yf, 0.9), (r0 + 0.6, yf + 0.5, 0.75), (-(r0 * 0.7), yb, 1.05), (r0 + 0.8, yb - 0.5, 0.65))
    for i, (x, y, s) in enumerate(spots):
        cols = [(xx, yy) for (xx, yy) in top if abs(xx + .5 - x) < 1 and abs(yy + .5 - y) < 1]
        zt = max((top[q] for q in cols), default=thi[2]) + 1
        stem = max(2, round(1.1 * k * s)) + (1 if i in (1, 2) else 0)
        sw = 2 if k >= 1.5 else 1
        x0, y0 = math.floor(x - sw / 2 + .5), math.floor(y - sw / 2 + .5)
        for zz in range(zt - 1, zt + stem):
            for dx in range(sw):
                for dy in range(sw):
                    m.put((x0 + dx, y0 + dy, zz), stem_col)
        r = r0 * s
        cen = (x0 + sw / 2, y0 + sw / 2, zt + stem - 0.5)
        m.ell(cen, (r, r, r * 0.9), col, cond=lambda xx, yy, zz, c0=cen: zz + .5 >= c0[2])
        # a pale gill ring under the cap rim
        for q in list(m.v):
            if m.v[q][0] == col and q[2] == math.floor(cen[2]) and math.hypot(q[0] + .5 - cen[0], q[1] + .5 - cen[1]) < r - 1.2:
                m.v[q] = (light(stem_col, 0.1), False)
        # round white dots, spaced out over the dome
        caps = [q for q in m.v if m.v[q][0] == col and any(
            (q[0] + d[0], q[1] + d[1], q[2] + d[2]) not in m.v
            for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1)))]
        for q in caps:
            if q[2] > cen[2] + 0.3 * r and (q[0] // 2 + q[1] // 2 * 3 + q[2]) % 4 == 0 and (q[0] + q[1]) % 2 == 0:
                m.v[q] = (dot, False)


def spikes(c, H, col, col2, a):
    k = _k(H)
    sz = a.get('size', 0.7) * k
    parts = [_find(c, 'body')] + ([_find(c, 'head')] if a.get('head') and _find(c, 'head') else [])
    s = c.part('spikes', 'static')
    tlo, thi, belly = torso(c)
    zmin = belly + (thi[2] - belly) * a.get('from', 0.45)
    ey = eye_spots(c)
    yface = min(e[1] for e in ey) + 1.0 * k if ey else -1e9
    every = a.get('every', 5)
    for part in [p for p in parts if p]:
        cz = sum(p[2] for p in part.v) / len(part.v)
        pcy = sum(p[1] for p in part.v) / len(part.v)
        for (x, y, z) in surface_up(part):
            if z < zmin or (part.name == 'head' and y < yface):
                continue
            if _hash(x, y, 7) % every:
                continue
            n = (x + .5, (y + .5 - pcy) * 0.5, z + .5 - cz + 1.5 * k)
            L = math.hypot(*n) or 1
            p0 = (x + .5, y + .5, z + .5)
            p1 = (p0[0] + n[0] / L * sz, p0[1] + n[1] / L * sz, p0[2] + n[2] / L * sz)
            tube(s, [p0, p1], max(0.3, 0.3 * k), 0.1, col, (lambda t: col2 if col2 and t > 0.6 else col))


def whiskers(c, H, col, col2, a):
    k = _k(H)
    _, yf, z = snout_tip(c)
    w = c.part('whiskers', 'static')
    L = max(2, round(1.6 * k))
    x0 = max(1, round(0.9 * k))
    for dz in (-1, 1):  # two thin whiskers a side, fanning apart
        for i in range(L):
            mput(w, x0 + i, yf + 1 + i // 3, round(z - 0.4 * k + dz * (0.5 + i * 0.4)), col)


def bigeyes(c, H, col, col2, a):
    k = _k(H)
    R = a.get('size', 0.9) * k
    head = head_of(c)
    e = _find(c, 'eyes')
    centres = eye_spots(c)
    if not centres:
        return
    for cen in centres:
        for p in list(head.v):
            if (p[1], p[0]) and math.hypot(p[0] + .5 - cen[0], p[2] + .5 - cen[2]) <= R:
                f = head.front(p[0], p[2])
                if f and f == p:
                    del head.v[p]
                    hi = (p[0] + .5 - cen[0]) * (1 if cen[0] >= 0 else -1) < -0.15 * R and p[2] + .5 - cen[2] > 0.25 * R
                    e.put(p, WHITE if hi else (col or INK))
    # mirror so both eyes match
    right = {p: v for p, v in e.v.items() if p[0] >= 0}
    e.v = dict(right)
    for (x, y, z), v in right.items():
        e.v[(-x - 1, y, z)] = v
        head.v.pop((-x - 1, y, z), None)


def goatee(c, H, col, col2, a):
    """A little goat beard under the chin, `length` in k."""
    k = _k(H)
    head = head_of(c)
    _, yf, z = snout_tip(c)
    sn = _find(c, 'snout')
    chin = [p for p in head.v if p[1] <= yf + 1.2 * k] + (list(sn.v) if sn else [])
    zb = min(p[2] for p in chin)
    yf = min(yf, min(p[1] for p in sn.v) + 0.6 * k) if sn else yf
    L = a.get('length', 1.0) * k
    b = c.part('beard', 'static')
    tube(b, [(0, yf + 0.7 * k, zb + 0.3 * k), (0, yf + 0.6 * k, zb - L * 0.5), (0, yf + 0.8 * k, zb - L)],
         0.42 * k, 0.2 * k, col)


def eyedisc(c, H, col, col2, a):
    """A pale disc round each eye with a big dark eye in it (a puffin's
    face): `size` (in k) the eye, `disc` (in k) the disc; color the disc,
    color2 the eye."""
    k = _k(H)
    head = head_of(c)
    e = _find(c, 'eyes')
    spots = [p for p in eye_spots(c) if p[0] >= 0]
    if not spots or not e:
        return
    ex, ey, ez = spots[0]
    # `lift` / `back` (in k) move the eye up / back from where the plan put it
    ez += a.get('lift', 0) * k
    ey += a.get('back', 0) * k
    ex += a.get('back', 0) * k * 0.5
    R = a.get('disc', 1.0) * k
    r = a.get('size', 0.45) * k + 0.3
    eye = col2 or INK
    N = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
    surf = [p for p in head.v if p[0] >= 0 and any((p[0] + d[0], p[1] + d[1], p[2] + d[2]) not in head.v
                                                   and (p[0] + d[0], p[1] + d[1], p[2] + d[2]) not in e.v
                                                   for d in N)]
    new_eye = {}
    for p in surf:
        d = math.dist((p[0] + .5, p[1] + .5, p[2] + .5), (ex + .5, ey + .5, ez + .5))
        if d <= r:
            new_eye[p] = eye
        elif d <= R and head.v[p][0] != WHITE and p[2] + .5 <= ez + .5 + R * 0.55 and p[1] + .5 <= ey + .5 + R * 0.6:
            head.v[p] = (col, False)  # a disc on the face, not up over the crown
    if new_eye:
        # a white glint at the top front of the eye
        g = min(new_eye, key=lambda q: (q[1] - q[2], -q[0]))
        new_eye[g] = WHITE
    e.v = {}
    for p, cc in new_eye.items():
        del head.v[p]
        e.put(p, cc)
        m = (-p[0] - 1, p[1], p[2])
        head.v.pop(m, None)
        e.put(m, cc)
    for p in [q for q in head.v if q[0] >= 0]:
        m = (-p[0] - 1, p[1], p[2])
        if m in head.v:
            head.v[m] = head.v[p]


def cicada(c, H, col, col2, a):
    """Turns the dragonfly plan into a cicada: a wide head with two big
    bulging eyes out at the sides, and clear folded wings held like a roof
    over the back, with dark veins, running past the tail. color the wing,
    color2 the veins; `eye` the eye colour."""
    k = _k(H)
    head = head_of(c)
    body = _find(c, 'body')
    hlo, hhi = bounds(head.v)
    hc = ((hlo[0] + hhi[0] + 1) / 2, (hlo[1] + hhi[1] + 1) / 2, (hlo[2] + hhi[2] + 1) / 2)
    hcol = Counter(v[0] for v in head.v.values()).most_common(1)[0][0]
    # wider, blunter head
    head.ell((0, hc[1] + 0.1 * k, hc[2]), (1.45 * k, 0.85 * k, 0.95 * k), hcol)
    e = c.part('eyes', 'blink', head.pivot)
    e.v = {}
    eye = hexc(a.get('eye', '#B8322A'))
    er = 0.72 * k
    for sx in (1, -1):
        cen = (sx * 1.6 * k, hc[1] - 0.05 * k, hc[2] + 0.3 * k)
        tmp = {}
        for x in range(math.floor(cen[0] - er) - 1, math.ceil(cen[0] + er) + 1):
            for y in range(math.floor(cen[1] - er) - 1, math.ceil(cen[1] + er) + 1):
                for z in range(math.floor(cen[2] - er) - 1, math.ceil(cen[2] + er) + 1):
                    if math.dist((x + .5, y + .5, z + .5), cen) <= er:
                        tmp[(x, y, z)] = eye
        g = min(tmp, key=lambda q: (q[1] - q[2] - sx * q[0]))
        tmp[g] = WHITE
        for p, cc in tmp.items():
            head.v.pop(p, None)
            e.put(p, cc)
    # mirror the eyes exactly
    right = {p: v for p, v in e.v.items() if p[0] >= 0}
    e.v = dict(right)
    for (x, y, z), v in right.items():
        e.v[(-x - 1, y, z)] = v
        head.v.pop((-x - 1, y, z), None)
    # a stout cicada body in place of the dragonfly's long tail: a round
    # thorax and a short thick abdomen with darker segment bands
    bcol = Counter(v[0] for v in body.v.values()).most_common(1)[0][0]
    band = dark(bcol, 0.3)
    old_lo, _ = bounds(body.v)
    body.v = {}
    body.ell((0, -0.3 * k, 2.0 * k), (1.25 * k, 1.1 * k, 1.05 * k), bcol)
    body.ell((0, 1.5 * k, 1.85 * k), (1.15 * k, 1.75 * k, 0.95 * k), bcol)
    for p in list(body.v):
        if p[1] > 0.6 * k and (p[1] - round(0.6 * k)) % max(2, round(0.7 * k)) == 0 and p[2] < 2.4 * k:
            body.v[p] = (band, False)
    for p in [p for p in body.v if p in head.v]:
        del body.v[p]
    # wings: a long clear teardrop each side, sloping down like a roof
    lo, hi = bounds(body.v)
    wc = col or hexc('#CFEFE6')
    vein = col2 or hexc('#2F4A3A')
    ztop = hi[2] + 1
    y0 = hlo[1] + (hhi[1] - hlo[1]) * 0.8
    y1 = hi[1] + 1.6 * k
    L = y1 - y0
    for sx, name in ((1, 'wingR'), (-1, 'wingL')):
        old = _find(c, name)
        pivot = (sx * 0.3 * k, y0 + 0.5 * k, ztop)
        w = old if old else c.part(name, name, pivot)
        w.v = {}
        w.pivot = pivot
        W = 2.2 * k
        for yi in range(math.floor(y0), math.ceil(y1) + 1):
            u = (yi + .5 - y0) / L
            if u < 0 or u > 1:
                continue
            half = W * math.sin(min(1.0, u * 1.25) * math.pi / 2) * (1 - max(0, u - 0.75) * 2.2)
            for xi in range(0, math.ceil(half + 0.6 * k) + 1):
                xo = xi - 0.0
                if xo > half + 0.4 * k:
                    continue
                v = xo / max(1, half + 0.4 * k)
                z = round(ztop - v * 0.9 * k - u * 0.5 * k)
                # veins: the leading edge, two running back, a few cross veins
                # veins: the outer rim, one running down the middle, and a
                # cross vein or two near the tip; the rest stays clear
                rim = xo >= half + 0.4 * k - 0.9 or u > 0.97
                mid = abs(xo - (half + 0.4 * k) * 0.5) < 0.5 and u < 0.85
                ve = rim or mid
                x = xi if sx > 0 else -xi - 1
                w.put((x, yi, z), vein if ve else wc)
        for p in [p for p in w.v if any(p in q.v for q in c.parts if q is not w)]:
            del w.v[p]


def mouth(c, H, col, col2, a):
    k = _k(H)
    style = a.get('style', 'smile')
    head = head_of(c)
    _, yf, z = snout_tip(c)
    zm = round(z - 0.55 * k)
    w = max(2, round(0.8 * k))
    m = c.part('mouth', 'static')
    if style == 'smile':
        for x in range(-w, w):
            up = 1 if x in (-w, w - 1) else 0
            f = head.front(x, zm + up)
            if f:
                m.put(f, col or INK)
        for x in (-1, 0):
            f = head.front(x, zm - 1)
            if f:
                m.put(f, col2 or hexc('#FF7A90'))
    else:  # underbite: two little teeth up over the lip
        for x in (-w + 1, w - 2):
            f = head.front(x, zm)
            if f:
                m.put((f[0], f[1] - 1, f[2]), col or WHITE)
                m.put((f[0], f[1] - 1, f[2] + 1), col or WHITE)


def sweater(c, H, col, col2, a):
    k = _k(H)
    body = _find(c, 'body')
    tlo, thi, belly = torso(c)
    zlo = belly - round(0.3 * k)
    yback = tlo[1] + (thi[1] - tlo[1]) * a.get('length', 0.75)
    rib = col2 or dark(col, 0.2)
    for p, (cc, g) in list(body.v.items()):
        if p[2] >= zlo and p[1] <= yback:
            edge = p[1] >= yback - max(1, round(0.3 * k)) or p[2] <= zlo + max(0, round(0.25 * k))
            knit = (p[2] + (p[0] % 2)) % 3 == 0
            body.v[p] = (rib if edge else (dark(col, 0.1) if knit else col), False)


def snowcap(c, H, col, col2, a):
    k = _k(H)
    head = head_of(c)
    s = c.part('snow', 'static')
    zt = max(p[2] for p in head.v)
    for (x, y, z) in surface_up(head):
        if z >= zt - 0.8 * k:
            s.put((x, y, z + 1), col)
            if _hash(x, y, 3) % 3 == 0:
                s.put((x, y, z + 2), col)


def mohawk(c, H, col, col2, a):
    k = _k(H)
    m = c.part('mohawk', 'static')
    head = head_of(c)
    body = _find(c, 'body')
    tlo, thi, belly = torso(c)
    yend = tlo[1] + (thi[1] - tlo[1]) * a.get('length', 0.6)
    for part in (head, body):
        for x in (-1, 0):
            for (xx, y, z) in surface_up(part):
                if xx != x or y > yend:
                    continue
                if part is head and y < snout_tip(c)[1] + 1.4 * k:
                    continue
                h = 1 + (_hash(y, 5) % max(2, round(0.7 * k)))
                for d in range(1, h + 1):
                    m.put((x, y, z + d), col2 if (col2 and d == h) else col)


def crest(c, H, col, col2, a):
    k = _k(H)
    style = a.get('style', 'fan')
    head = head_of(c)
    y, zt = crown(c)
    cr = c.part('crest', 'static')
    if style == 'fan':
        n = 7
        for i in range(n):
            th = math.pi * (0.15 + 0.7 * i / (n - 1))  # from forward to back
            L = 2.0 * k
            p0 = (0, y - 0.4 * k, zt - 0.2 * k)
            p1 = (0, p0[1] - math.cos(th) * L, p0[2] + math.sin(th) * L)
            tube(cr, [p0, p1], 0.3 * k, 0.32 * k, col,
                 (lambda t: (INK if t > 0.88 else (col2 or WHITE) if t > 0.72 else col)))
    else:  # plumes
        cols = [col, col2 or hexc('#4D9DE0'), hexc('#FFD43B'), hexc('#FF5DA2'), hexc('#7CDB5E')]
        for i, dx in enumerate((-0.6, -0.3, 0, 0.3, 0.6)):
            p0 = (dx * k, y, zt - 0.2 * k)
            p1 = (dx * 2.2 * k, y + 0.3 * k, zt + 1.4 * k - abs(dx) * 0.5 * k)
            p2 = (dx * 2.8 * k, y + 0.9 * k, zt + 2.0 * k - abs(dx) * 0.8 * k)
            tube(cr, [p0, p1, p2], 0.3 * k, 0.28 * k, cols[i % len(cols)])
        right = {p: v for p, v in cr.v.items() if p[0] >= 0}
        cr.v = dict(right)
        for (x, yy, z), v in right.items():
            cr.v.setdefault((-x - 1, yy, z), v)
    del head


def beak(c, H, col, col2, a):
    k = _k(H)
    style = a.get('style', 'big')
    _, yf, z = snout_tip(c)
    b = c.part('beak', 'static')
    y0 = yf + 1.0 * k
    if style == 'big':
        L, w, h = 1.9 * k, 0.75 * k, 0.65 * k
        n = max(3, round(L))
        for i in range(n + 1):
            t = i / n
            ww, hh = w * (1 - t * 0.6), h * (1 - t * 0.7)
            for x in range(math.floor(-ww), math.ceil(ww)):
                for dz in range(math.floor(-hh), math.ceil(hh) + 1):
                    b.put((x, round(y0 - L * t - 0.2 * k), round(z + dz - t * 0.3 * k)),
                          (col2 if (col2 and dz <= -hh + 1) else col))
    elif style == 'curved':
        pts = [(0, y0, z), (0, yf - 0.8 * k, z - 0.1 * k), (0, yf - 1.8 * k, z - 0.5 * k), (0, yf - 2.4 * k, z - 1.2 * k)]
        tube(b, pts, 0.38 * k, 0.15 * k, col)
    else:  # long and pointed
        pts = [(0, y0, z), (0, yf - 1.0 * k, z - 0.05 * k), (0, yf - 1.9 * k, z - 0.2 * k)]
        tube(b, pts, 0.4 * k, 0.12 * k, col)
    right = {p: v for p, v in b.v.items() if p[0] >= 0}
    b.v = dict(right)
    for (x, y, zz), v in right.items():
        b.v[(-x - 1, y, zz)] = v


def fan(c, H, col, col2, a):
    k = _k(H)
    tlo, thi, belly = torso(c)
    f = c.part('fan', 'static')
    y = thi[1] - 0.4 * k
    cz = thi[2] - 0.2 * k
    R = 2.3 * k
    bands = [col, col2 or hexc('#4D9DE0'), hexc('#FFD43B'), hexc('#FF5D5D'), hexc('#2EC4B6')]
    for x10 in range(-int(R * 10), int(R * 10) + 1, 4):
        for z10 in range(0, int(R * 10) + 1, 4):
            x, z = x10 / 10, z10 / 10
            r = math.hypot(x, z)
            if r > R or z < 0.15 * R:
                continue
            band = bands[int(r / R * len(bands)) % len(bands)]
            f.put((math.floor(x), round(y), math.floor(cz + z)), band)
            f.put((math.floor(x), round(y) + 1, math.floor(cz + z)), dark(band, 0.15))


def leaf(c, H, col, col2, a):
    k = _k(H)
    tlo, thi, belly = torso(c)
    lf = c.part('leaf', 'static')
    cy = (tlo[1] + thi[1]) / 2 + 0.4 * k
    L, W = (thi[1] - tlo[1]) / 2 + 1.2 * k, (thi[0] - tlo[0]) / 2 + 1.4 * k
    z = thi[2]
    vein = col2 or dark(col, 0.25)
    for x in range(math.floor(-W), math.ceil(W)):
        for y in range(math.floor(cy - L), math.ceil(cy + L) + 1):
            t = (y + .5 - (cy - L)) / (2 * L)
            half = W * math.sin(math.pi * min(1, max(0, t))) ** 0.8
            if abs(x + .5) > half:
                continue
            mid = x in (-1, 0)
            v = (round(abs(x + .5) * 1.2) + y) % max(3, round(1.4 * k)) == 0
            lf.put((x, y, z + (1 if abs(x + .5) < half * 0.4 else 0)), vein if (mid or v) else col)


def jellybean(c, H, col, col2, a):
    """A beetle's shell remade as one smooth jellybean: long, rounded at both
    ends and arched like a kidney bean seen from the side, all one glossy
    colour (no seam, no spots) with a long gloss streak (color2, default
    white) down the upper left and a small dot of shine ahead of it."""
    k = _k(H)
    shell = _find(c, 'shell')
    if shell is None or not shell.v:
        return
    gloss = col2 or WHITE
    xs = [p[0] for p in shell.v]
    ys = [p[1] for p in shell.v]
    zs = [p[2] for p in shell.v]
    cy = (min(ys) + max(ys) + 1) / 2
    zlo = min(zs)
    rx = (max(xs) - min(xs) + 1) / 2 * a.get('width', 0.92)
    ry = (max(ys) - min(ys) + 1) / 2 * a.get('length', 1.08)
    rz = (max(zs) - zlo + 1) * 0.95
    arch = a.get('arch', 0.3) * k
    shell.v = {}
    for x in range(-math.ceil(rx), math.ceil(rx)):
        for y in range(math.floor(cy - ry), math.ceil(cy + ry) + 1):
            t = (y + .5 - cy) / ry
            if abs(t) > 1:
                continue
            zc = zlo - 0.15 * rz + arch * (1 - t * t)
            for z in range(zlo, math.ceil(zc + rz) + 1):
                if ((x + .5) / rx) ** 2 + t * t + ((z + .5 - zc) / rz) ** 2 <= 1:
                    shell.put((x, y, z), col)
    # one gloss streak: the top voxel just left of the ridge, along most of
    # its length, then a gap and a dot
    gx = -max(1, round(0.22 * rx)) - 1
    for y in range(math.floor(cy - 0.6 * ry), math.ceil(cy + 0.3 * ry)):
        top = shell.top(gx, y)
        if top:
            shell.v[top] = (gloss, False)
    top = shell.top(gx, math.ceil(cy + 0.48 * ry))
    if top:
        shell.v[top] = (gloss, False)
    # no horn on a jellybean: the head keeps only its own dark voxels
    head = _find(c, 'head')
    if head is not None:
        dark_head = Counter(v[0] for v in head.v.values()).most_common(1)[0][0]
        for p in [p for p, v in head.v.items() if v[0] != dark_head]:
            del head.v[p]
        # a rounder, bigger head (room for eyes that read): the same centre,
        # a third bigger, its back tucked under the shell
        hx = [p[0] for p in head.v]
        hy = [p[1] for p in head.v]
        hz = [p[2] for p in head.v]
        hc = (0, (min(hy) + max(hy) + 1) / 2, (min(hz) + max(hz) + 1) / 2 + 0.15 * k)
        hr = ((max(hx) - min(hx) + 1) / 2 * 1.3, (max(hy) - min(hy) + 1) / 2 * 1.15, (max(hz) - min(hz) + 1) / 2 * 1.4)
        head.v = {}
        head.ell(hc, hr, dark_head)
        for p in [p for p in head.v if p in shell.v]:
            del head.v[p]
        # big eyes that read on the dark head: 2x2 white, a dark pupil low
        # and inward, set into the head's front where the plan put the eyes
        e = _find(c, 'eyes')
        if e is not None and e.v:
            ex = max(1, round(0.25 * hr[0]))
            ez = round(hc[2] - 0.2 * hr[2])
            e.v = {}
            block = [(x, z) for x in (ex, ex + 1) for z in (ez, ez + 1)]
            fronts = [head.front(x, z) for x, z in block]
            yf = min(f[1] for f in fronts if f) if any(fronts) else None
            for (x, z), f in zip(block, fronts):
                if yf is None or f is None:
                    continue
                # every eye voxel on one flat plane, the head filled in behind
                for y in range(yf + 1, f[1]):
                    mput(head, x, y, z, dark_head)
                for q in ((x, yf, z), (-x - 1, yf, z)):
                    head.v.pop(q, None)
                pupil = x == ex and z == ez
                mput(e, x, yf, z, INK if pupil else WHITE)


ACCESSORIES = {
    'cup': cup, 'mitten': mitten, 'shell': shell, 'ball': ball_acc, 'pot': pot, 'bubble': bubble,
    'unc_tusks': tusks, 'snout': snout, 'hornset': hornset, 'earset': earset, 'tailset': tailset,
    'wingset': wingset, 'wingfold': wingfold, 'boots': boots, 'stilts': stilts, 'carapace': carapace, 'skirt': skirt,
    'fluff': fluff, 'frizz': frizz, 'unc_mushrooms': mushrooms, 'unc_spikes': spikes, 'feelers': whiskers,
    'bigeyes': bigeyes, 'mouth': mouth, 'sweater': sweater, 'snowcap': snowcap, 'mane_strip': mohawk,
    'crest': crest, 'beak': beak, 'fan': fan, 'leaf': leaf, 'eyedisc': eyedisc, 'cicada': cicada, 'goatee': goatee,
    'jellybean': jellybean,
}


# ----------------------------------------------------------------- patterns

def _targets(c, parts):
    return [p for p in (_find(c, n) for n in parts) if p and p.v]


def _paint(part, test, col):
    for p, (cc, g) in list(part.v.items()):
        if not g and cc not in (INK, WHITE) and test(p):
            part.v[p] = (col, False)


def _paint_any(part, test, col):
    for p, (cc, g) in list(part.v.items()):
        if not g and test(p):
            part.v[p] = (col, False)


def p_face(c, H, col, parts, p):
    head = head_of(c)
    lo, hi = bounds(head.v)
    depth = p.get('depth', 0.35)
    zt = hi[2] - (hi[2] - lo[2]) * p.get('top', 0.2)
    _paint(head, lambda q: q[1] <= lo[1] + (hi[1] - lo[1]) * depth and q[2] <= zt, col)


def p_cap(c, H, col, parts, p):
    head = head_of(c)
    lo, hi = bounds(head.v)
    depth, nape = p.get('depth', 0.3), p.get('nape', 0)
    ym = (lo[1] + hi[1]) / 2

    def edge(q):
        # the cap's lower edge, lower behind (down the nape) when nape > 0
        back = max(0.0, (q[1] - ym) / max(1, hi[1] - ym))
        return hi[2] - (hi[2] - lo[2]) * (depth + nape * back)

    if p.get('soft'):
        # a soft wash: a half-tone band under the cap's edge
        band = max(1, round(_k(H) * 0.35))
        for q, (cc, g) in list(head.v.items()):
            if not g and cc not in (INK, WHITE) and edge(q) - band <= q[2] < edge(q):
                head.v[q] = (mix(cc, col, 0.5), False)
    _paint(head, lambda q: q[2] >= edge(q), col)


def p_mask(c, H, col, parts, p):
    k = _k(H)
    head = head_of(c)
    ey = eye_spots(c)
    if not ey:
        return
    z = sum(e[2] for e in ey) / len(ey)
    lo, hi = bounds(head.v)
    _paint(head, lambda q: abs(q[2] + .5 - z) <= p.get('width', 0.55) * k and q[1] <= lo[1] + (hi[1] - lo[1]) * 0.6, col)


def p_zebra(c, H, col, parts, p):
    """Bold wavy stripes: round the body front to back, across the face and
    round the legs and tail."""
    k = _k(H)
    w = max(2, round(p.get('width', 0.6) * k))
    names = parts if parts != ('body',) else ('body', 'head', 'tail') + tuple(rig.LEG_NAMES)
    for part in _targets(c, names):
        if part.name == 'body':
            test = lambda q: ((q[1] + round(0.9 * math.sin(q[2] * 0.45))) // w) % 2 == 0  # noqa: E731
        else:
            test = lambda q: ((q[2] + round(0.6 * math.sin(q[0] * 0.5))) // w) % 2 == 0  # noqa: E731
        if part.name == 'head' and eye_spots(c):
            ring = max(1.5, 0.8 * k)
            ey = eye_spots(c)
            test = (lambda q, t=test: t(q) and all(math.dist((q[0] + .5, q[1] + .5, q[2] + .5),
                                                             (e[0] + .5, e[1] + .5, e[2] + .5)) > ring for e in ey))
        _paint(part, test, col)


def p_streak(c, H, col, parts, p):
    k = _k(H)
    for part in _targets(c, parts):
        lo, hi = bounds(part.v)
        zc = lo[2] + (hi[2] - lo[2]) * p.get('z', 0.5)
        half = (hi[0] - lo[0] + 1) / 2
        _paint(part, lambda q: abs(q[2] + .5 - zc) <= p.get('width', 0.4) * k and abs(q[0] + .5) >= half * 0.55, col)


def _cells(part, s, salt, keep):
    out = {}
    for q in part.v:
        cell = (q[0] // s, q[1] // s, q[2] // s)
        if cell in out:
            continue
        h = _hash(*cell, salt)
        if h % 100 < keep:
            ox, oy, oz = ((h >> 8) % s, (h >> 12) % s, (h >> 16) % s)
            out[cell] = (cell[0] * s + ox * 0.5 + s * 0.25, cell[1] * s + oy * 0.5 + s * 0.25, cell[2] * s + oz * 0.5 + s * 0.25)
        else:
            out[cell] = None
    return out


def p_rosettes(c, H, col, parts, p):
    k = _k(H)
    s = max(3, round(1.5 * k))
    for part in _targets(c, parts):
        cells = _cells(part, s, 19, 55)

        def ring(q, cells=cells):
            cen = cells.get((q[0] // s, q[1] // s, q[2] // s))
            if not cen:
                return False
            d = math.dist((q[0] + .5, q[1] + .5, q[2] + .5), cen)
            return s * 0.28 < d < s * 0.52
        _paint(part, ring, col)


def p_flecks(c, H, col, parts, p):
    dens = p.get('density', 12)
    for part in _targets(c, parts):
        _paint(part, lambda q: _hash(*q, 23) % 100 < dens, col)


def p_strands(c, H, col, parts, p):
    # long hair: whole vertical runs of one tone (the hash skips z), so a
    # shaggy coat reads as strands, not as speckle
    dens = p.get('density', 18)
    for part in _targets(c, parts):
        _paint(part, lambda q: _hash(q[0], q[1] // 2, p.get('seed', 41)) % 100 < dens, col)


def p_sash(c, H, col, parts, p):
    k = _k(H)
    for part in _targets(c, parts):
        lo, hi = bounds(part.v)
        mid = (lo[1] + hi[1]) / 2 + (lo[2] + hi[2]) / 2 * 0.9
        _paint(part, lambda q: abs(q[1] + q[2] * 0.9 - mid) <= p.get('width', 0.55) * k, col)
        if p.get('edge'):
            _paint(part, lambda q: p.get('width', 0.55) * k < abs(q[1] + q[2] * 0.9 - mid) <= p.get('width', 0.55) * k + 1, hexc(p['edge']))


RAINBOW = ['#FF5D5D', '#FF9F43', '#FFD43B', '#7CDB5E', '#2EC4B6', '#4D9DE0', '#9B6BDF']


def p_rainbow(c, H, col, parts, p):
    k = _k(H)
    w = max(1, round(p.get('width', 0.7) * k))
    cols = [hexc(h) for h in RAINBOW]
    start = min(range(len(cols)), key=lambda i: sum((cols[i][j] - col[j]) ** 2 for j in range(3)))
    for part in _targets(c, parts):
        lo, hi = bounds(part.v)
        for q, (cc, g) in list(part.v.items()):
            if g or cc in (INK, WHITE):
                continue
            idx = (start + (q[1] - lo[1]) // w) % len(cols)
            part.v[q] = (cols[idx], False)


SPRINKLES = ['#FF5D8F', '#FFD43B', '#4D9DE0', '#7CDB5E', '#FF9F43', '#B07CFF']


def p_sprinkles(c, H, col, parts, p):
    for part in _targets(c, parts):
        lo, hi = bounds(part.v)
        zc = (lo[2] + hi[2]) / 2
        for q in surface_up(part):
            h = _hash(*q, 29)
            if q[2] >= zc and h % 7 == 0:
                cc = hexc(SPRINKLES[(h >> 5) % len(SPRINKLES)])
                part.v[q] = (cc, False)
                nb = (q[0] + (1 if h & 1 else 0), q[1] + (0 if h & 1 else 1), q[2])
                if nb in part.v and part.v[nb][0] not in (INK, WHITE):
                    part.v[nb] = (cc, False)


def p_swirl(c, H, col, parts, p):
    k = _k(H)
    n = p.get('turns', 1.0)
    w = max(2.0, p.get('width', 2.2) * k)
    ph = p.get('phase', 0.0)
    for part in _targets(c, parts):
        lo, hi = bounds(part.v)
        cz = (lo[2] + hi[2]) / 2

        def on(q):
            th = math.atan2(q[2] + .5 - cz, q[0] + .5) / (2 * math.pi)
            v = (q[1] / w + th * n + ph) % 1.0
            return v < p.get('share', 0.34)
        _paint(part, on, col)


def p_ribs(c, H, col, parts, p):
    k = _k(H)
    body = _find(c, 'body')
    tlo, thi, belly = torso(c)
    y0, y1 = tlo[1] + (thi[1] - tlo[1]) * 0.25, tlo[1] + (thi[1] - tlo[1]) * 0.7
    gap = max(2, round(0.7 * k))
    zc = belly + (thi[2] - belly) * 0.35
    _paint(body, lambda q: y0 <= q[1] <= y1 and q[2] >= zc and (q[1] - round(y0)) % gap == 0, col)
    _paint(body, lambda q: q[0] in (-1, 0) and q[2] >= thi[2] - 1 and q[1] <= thi[1] - 0.6 * k, col)


def p_stitches(c, H, col, parts, p):
    k = _k(H)
    body = _find(c, 'body')
    head = _find(c, 'head')
    tlo, thi, belly = torso(c)
    yc = round((tlo[1] + thi[1]) / 2)
    for part, test in ((body, lambda q: q[1] == yc and q[0] >= 0),
                       (head, lambda q: q[0] == max(x for (x, y, z) in head.v) - 1 if head else False)):
        if not part:
            continue
        for q in list(part.v):
            if test(q):
                part.v[q] = (col, False)
                if q[2] % 2 == 0:
                    for d in (-1, 1):
                        r = (q[0], q[1] + d, q[2]) if part is body else (q[0], q[1] + d, q[2])
                        if r in part.v:
                            part.v[r] = (col, False)
    del k


def p_facets(c, H, col, parts, p):
    k = _k(H)
    s = max(2, round(1.2 * k))
    names = parts if parts != ('body',) else ('body', 'head') + tuple(rig.LEG_NAMES)
    for part in _targets(c, names):
        _paint_any(part, lambda q: (part.v[q][0] not in (INK, WHITE)) and ((q[0] + q[1] + q[2]) // s) % 2 == 0 and
                   ((q[0] - q[1] + 2 * q[2]) // s) % 2 == 0, col)


def p_drips(c, H, col, parts, p):
    k = _k(H)
    for part in _targets(c, parts):
        lo, hi = bounds(part.v)
        zc = hi[2] - (hi[2] - lo[2]) * p.get('depth', 0.3)
        for q in list(part.v):
            if part.v[q][0] in (INK, WHITE):
                continue
            drip = _hash(q[0], q[1], 37) % 4 == 0
            reach = zc - (1 + _hash(q[0], q[1], 38) % max(2, round(1.0 * k))) if drip else zc
            if q[2] >= reach:
                part.v[q] = (col, False)


def p_sheen(c, H, col, parts, p):
    for part in _targets(c, parts):
        for q in surface_up(part):
            if part.v[q][0] not in (INK, WHITE) and _hash(*q, 43) % 3 == 0:
                part.v[q] = (col, False)


def p_half(c, H, col, parts, p):
    """The left half of the parts in col, crinkled like foil. Ears are kept
    symmetric by the finer build, so their half becomes its own part."""
    for part in _targets(c, parts):
        if part.name == 'ears':
            foil = c.part('foil', 'static', part.pivot)
            for q, (cc, g) in list(part.v.items()):
                if q[0] < 0:
                    foil.put(q, light(col, 0.3) if _hash(*q, 3) % 3 == 0 else col)
            continue
        _paint(part, lambda q: q[0] < 0, col)
        if p.get('crinkle', True):
            _paint(part, lambda q: q[0] < 0 and _hash(*q, 3) % 3 == 0, light(col, 0.3))


def p_ends(c, H, col, parts, p):
    for part in _targets(c, parts):
        lo, hi = bounds(part.v)
        frac = p.get('frac', 0.3)
        axis = p.get('axis', 'y')
        if axis == 'x':
            _paint(part, lambda q: abs(q[0] + .5) >= max(abs(lo[0]), abs(hi[0] + 1)) * (1 - frac), col)
        else:
            _paint(part, lambda q: q[1] >= hi[1] - (hi[1] - lo[1]) * frac, col)


def p_trim(c, H, col, parts, p):
    """Shaves a little nub off the top of a dome: the top layers of the
    parts while a layer has `max` voxels or fewer (default 4)."""
    for part in _targets(c, parts):
        while part.v:
            zt = max(q[2] for q in part.v)
            layer = [q for q in part.v if q[2] == zt]
            if len(layer) > p.get('max', 4):
                break
            for q in layer:
                del part.v[q]


def p_rim(c, H, col, parts, p):
    k = _k(H)
    for part in _targets(c, parts):
        lo, hi = bounds(part.v)
        _paint(part, lambda q: q[2] <= lo[2] + max(0, round(0.35 * k)), col)


PATTERNS = {
    'face': p_face, 'cap': p_cap, 'mask': p_mask, 'zebrastripe': p_zebra, 'streak': p_streak, 'rosettes': p_rosettes,
    'flecks': p_flecks, 'sash': p_sash, 'rainbow': p_rainbow, 'sprinkles': p_sprinkles, 'swirl': p_swirl,
    'ribs': p_ribs, 'stitches': p_stitches, 'facets': p_facets, 'drips': p_drips, 'sheen': p_sheen,
    'half': p_half, 'ends': p_ends, 'rim': p_rim, 'trim': p_trim, 'strands': p_strands,
}
