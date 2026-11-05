"""The **mammal** plan (see variants.py for how kit modules plug in): Rare
four-legged animals whose shape the cat-like `quadruped` cannot give them.
Each kind draws its own body, head, ears and tail, and its legs straight
into leg parts (`legFL`..`legBR`, hinged at the top of each leg, the left
legs an exact mirror of the right):

- **camel**: long legs with knobbly knees and wide pads, one clear hump, a
  long curved neck, a long droopy muzzle, small round ears, a glowing bell.
- **ermine**: long, low and slender (about twice as long as tall), short
  legs, small round ears, a long tail with a black tip.
- **muskox**: shaggy fur hanging to the floor over its legs, a dark face
  with a lighter muzzle and eye patches, horns that sweep out and curl down
  past small tucked ears, glowing horn tips.
- **sandcat**: a wide flat head with wide, low-set ears (glowing inside),
  big eyes, striped legs, a ringed tail with a black tip.
- **ferret**: the ermine's shape in its own colours (accent tips the tail).
- **hamster**: a round chubby ball with puffed cheek pouches, tiny pink
  nose, small round ears and stubby pink-toed legs.
- **mouse**: a slim body, a pointed snout, big round disc ears with pink
  fronts, a long thin tail curving up.
- **badger**: low and wide on short thick legs, a white stripe from nose
  over the crown, white cheeks, small pale ears.
- **lamb**: a curly woolly body on thin dark legs, a dark face with a
  woolly cap and pale eyes, ears sticking out sideways.
- **foal** / **giraffe**: long legs, a long horse-like head on an upright
  neck with a short mane, small upright ears, a tufted tail (zebra, okapi,
  reindeer calves); the giraffe's neck is about twice as long.
- **bear**: chunky shoulders on thick legs, a round head with a short
  lighter snout and a big black nose, small round ears.
- **mole**: a long low velvet body, a long pointed pink nose, tiny eyes,
  big pink digging paws held out at the shoulders.
- **squirrel**: a small body, tufted ears and a big bushy tail curling up
  over its back.
- **cheetah** / **snowleopard**: big-cat cubs with small round ears: the
  cheetah slim and leggy with solid spots and tear lines, the snow leopard
  stocky with rosettes and a very thick, long tail.
- **hippo**: a barrel body on short legs, a very wide flat-fronted muzzle
  with nostrils on top, tiny round ears.
- **rhino**: a heavy body, a long low head sloping to the nose with the big
  horn at its tip (a small one behind), small tube ears.
- **otter**: floats on its back (gait `swim`): pale face, paws on its chest
  holding a shell with a glowing pearl, webbed hind feet up as `finL`/`finR`,
  a flat `tail`.

Colours: col, belly, snout, accent (horns, bell, shell), glow, tail_col.
Same art frame (x right, y back, front is -y, z up) and scale (k = H / 10)
as the other kits."""
import math

from voxkit import hexc
import kit_pond
import rig

INK, WHITE = hexc('#1B1B2F'), hexc('#FFFFFF')
_dark, _mix, line, face = kit_pond._dark, kit_pond._mix, kit_pond.line, kit_pond.face


def _light(col, t=0.35):
    return _mix(col, WHITE, t)


def _h(*a):
    v = 2166136261
    for x in a:
        v = ((v ^ (int(x) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    return v


def _hm(*a):
    """A well-mixed hash of small integers (neighbouring voxels differ)."""
    v = 0x9E3779B9
    for x in a:
        v ^= (int(x) * 0x85EBCA6B) & 0xFFFFFFFF
        v = ((v << 13) | (v >> 19)) & 0xFFFFFFFF
        v = (v * 0xC2B2AE35 + 0x27D4EB2F) & 0xFFFFFFFF
    v ^= v >> 16
    v = (v * 0x7FEB352D) & 0xFFFFFFFF
    return v ^ (v >> 15)


def _mirror(part):
    """The left half becomes an exact mirror of the right (x >= 0)."""
    right = {p: v for p, v in part.v.items() if p[0] >= 0}
    part.v = dict(right)
    for (x, y, z), v in right.items():
        part.v[(-x - 1, y, z)] = v


def _legs(c, k, spots, hz, w, col, foot=None, foot_h=0.3, paint=None):
    """Four legs, `spots` the right legs' (x, y) front to back. Each leg is a
    w x w column from the ground to z = hz (inside the body, which keeps the
    shared voxels), hinged at its top; the left legs mirror the right."""
    top = round(hz)
    for i, (x, y) in enumerate(spots):
        x0, y0 = round(x * k), round(y * k)
        right = rig.leg_part(c, 'R', i, len(spots), (x0 + w / 2, y0 + w / 2, top))
        left = rig.leg_part(c, 'L', i, len(spots), (-x0 - w / 2, y0 + w / 2, top))
        for z in range(top):
            for dx in range(w):
                for dy in range(w):
                    q = (x0 + dx, y0 + dy, z)
                    cc = foot if foot is not None and z < max(1, round(foot_h * k)) else col
                    if paint:
                        cc = paint(q, cc, (x0, y0, w)) or cc
                    right.put(q, cc)
        for (qx, qy, qz), v in right.v.items():
            left.v[(-qx - 1, qy, qz)] = v


def _side_eyes(c, head, y, z, brow=None):
    """Eyes on the sides of the head (a camel's): the outermost head voxel at
    depth y, row z, is the eye; the one just in front of it is a white
    glint, and the two above are a lighter brow."""
    e = c.part('eyes', 'blink', head.pivot)
    row = [p for p in head.v if p[1] == y and p[2] == z and p[0] >= 0]
    if row:
        q = max(row)
        del head.v[q]
        e.put(q, INK)
        g = (q[0], q[1] - 1, q[2])
        if g in head.v:
            del head.v[g]
            e.put(g, WHITE)
        if brow is not None:
            for b in ((q[0], q[1], q[2] + 1), (q[0], q[1] - 1, q[2] + 1)):
                if b in head.v:
                    head.v[b] = (brow, False)
    for (x, yy, zz), v in list(e.v.items()):
        head.v.pop((-x - 1, yy, zz), None)
        e.v[(-x - 1, yy, zz)] = v
    for (x, yy, zz), v in list(head.v.items()):
        if x >= 0 and brow is not None and v == (brow, False):
            head.v[(-x - 1, yy, zz)] = v


def _ears_round(c, k, x, y, z, r, col, pivot):
    ears = c.part('ears', 'ears', pivot)
    ears.ell((x * k, y * k, z * k), r, col)
    _mirror(ears)
    return ears


# ------------------------------------------------------------------ camel

def _camel(c, k, cols):
    col = cols['col']
    belly = cols.get('belly') or _light(col, 0.3)
    snout = cols.get('snout') or _light(col, 0.3)
    pad = _dark(col, 0.35)
    gold = cols.get('accent') or hexc('#FFD24A')
    w = max(2, round(0.6 * k))
    # long legs: a knobbly knee halfway up and a wide pad at the foot
    knee = round(1.8 * k)

    def knees(q, cc, base):
        return _dark(col, 0.12) if knee <= q[2] < knee + max(1, round(0.25 * k)) else None
    _legs(c, k, ((0.85, -0.9), (0.85, 2.2)), 3.7 * k, w, col, foot=pad, foot_h=0.25, paint=knees)
    for p in [p for p in c.parts if p.name in rig.LEG_NAMES]:
        sx = 1 if p.name.endswith('R') else -1
        xs = [q[0] for q in p.v]
        ys = [q[1] for q in p.v]
        # the knee bulges a voxel out at the front and outside; the pad spreads
        for q in list(p.v):
            if knee <= q[2] < knee + max(1, round(0.25 * k)) and q[1] == min(ys):
                p.put((q[0], q[1] - 1, q[2]), _dark(col, 0.12))
            if q[2] == 0 and q[1] == min(ys):
                p.put((q[0], q[1] - 1, 0), pad)
        for q in list(p.v):
            if q[2] == 0 and q[0] == (max(xs) if sx > 0 else min(xs)):
                p.put((q[0] + sx, q[1], 0), pad)
    body = c.part('body')
    body.ell((0, 0.7 * k, 4.6 * k), (1.35 * k, 2.3 * k, 1.2 * k), col)
    # one clear hump
    body.ell((0, 0.8 * k, 5.8 * k), (0.95 * k, 1.15 * k, 1.0 * k), col)
    body.paint(lambda p, cc, g: (belly, False) if p[2] < 4.0 * k else None)
    # the neck curves forward and down out of the chest, then up to the head
    head = c.part('head', 'head', (0, -1.3 * k, 4.9 * k))
    line(head, (0, -1.3 * k, 4.9 * k), (0, -2.5 * k, 5.6 * k), col, r=0.62 * k)
    line(head, (0, -2.5 * k, 5.6 * k), (0, -2.9 * k, 7.4 * k), col, r=0.52 * k)
    head.ell((0, -3.0 * k, 8.0 * k), (0.8 * k, 0.9 * k, 0.75 * k), col)
    # a long muzzle with a droopy lower lip
    head.ell((0, -4.1 * k, 7.75 * k), (0.58 * k, 1.0 * k, 0.5 * k), snout)
    head.ell((0, -4.15 * k, 7.15 * k), (0.48 * k, 0.75 * k, 0.32 * k), _dark(snout, 0.12))
    fy = min(p[1] for p in head.v)
    zt = max(p[2] for p in head.v if p[1] == fy)
    for x in (round(0.25 * k), -round(0.25 * k) - 1):
        head.put((x, fy, zt), INK)
    _side_eyes(c, head, round(-3.1 * k), round(7.9 * k), brow=_light(col, 0.35))
    # a glowing bell on a collar where the neck leaves the chest
    red = hexc('#C8463A')
    head.paint(lambda p, cc, g: (red, False) if abs(p[1] + .5 + 2.15 * k) < 0.25 * k + .5 and 5.0 * k < p[2] < 6.4 * k else None)
    bell = c.part('bell', 'static')
    # a little bell under the throat: a dome flaring to a rim, a dark clapper
    by, bz = -2.75 * k, 4.75 * k
    bell.ell((0, by, bz), (0.6 * k, 0.6 * k, 0.6 * k), gold, True)
    bell.v = {p: v for p, v in bell.v.items() if p[2] <= bz}
    bell.ell((0, by, bz + 0.3 * k), (0.3 * k + .3, 0.3 * k + .3, 0.35 * k), gold, True)
    lo = min(p[2] for p in bell.v)
    bell.put((0, math.floor(by), lo - 1), INK)
    _mirror(bell)
    _ears_round(c, k, 0.62, -2.75, 8.7, (0.3 * k, 0.24 * k, 0.36 * k), col, (0, -2.8 * k, 8.6 * k))
    tail = c.part('tail', 'tail', (0, 3.0 * k, 5.0 * k))
    tc = cols.get('tail_col') or _dark(col, 0.2)
    line(tail, (0, 3.0 * k, 5.0 * k), (0, 3.35 * k, 3.6 * k), tc, r=0.3 * k)
    tail.ell((0, 3.4 * k, 3.2 * k), (0.35 * k, 0.3 * k, 0.55 * k), _dark(tc, 0.3))
    _mirror(tail)


# ------------------------------------------------------------------ ermine

def _ermine(c, k, cols):
    col = cols['col']
    w = max(2, round(0.55 * k))
    _legs(c, k, ((0.5, -1.5), (0.5, 2.5)), 1.6 * k, w, col, foot=_dark(col, 0.06))
    body = c.part('body')
    body.ell((0, 0.6 * k, 2.15 * k), (0.92 * k, 2.95 * k, 0.85 * k), col)
    body.ell((0, -1.4 * k, 2.4 * k), (0.88 * k, 1.05 * k, 0.9 * k), col)
    body.paint(lambda p, cc, g: (_dark(col, 0.04), False) if p[2] > 2.6 * k and _h(*p) % 7 == 0 else None)
    # the head held up on a slim neck, alert
    head = c.part('head', 'head', (0, -1.7 * k, 2.7 * k))
    line(head, (0, -1.7 * k, 2.6 * k), (0, -2.35 * k, 3.7 * k), col, r=0.6 * k)
    head.ell((0, -2.75 * k, 4.3 * k), (1.15 * k, 0.95 * k, 0.95 * k), col)
    head.ell((0, -3.6 * k, 3.75 * k), (0.5 * k, 0.5 * k, 0.38 * k), cols.get('snout') or col)
    fy = min(p[1] for p in head.v)
    zt = max(p[2] for p in head.v if p[1] == fy)
    head.put((0, fy, zt), INK)
    head.put((-1, fy, zt), INK)
    face(c, head, k, 4.3, x_off=0.75, size=0.3, cheeks=False)
    _ears_round(c, k, 0.75, -2.45, 5.2, (0.32 * k, 0.2 * k, 0.3 * k), col, (0, -2.45 * k, 5.0 * k))
    tail = c.part('tail', 'tail', (0, 3.4 * k, 2.4 * k))
    line(tail, (0, 3.4 * k, 2.4 * k), (0, 5.0 * k, 3.0 * k), cols.get('tail_col') or col, r=0.34 * k)
    line(tail, (0, 5.0 * k, 3.0 * k), (0, 5.9 * k, 3.6 * k), cols.get('tail_col') or col, r=0.3 * k)
    tip = cols.get('accent') or hexc('#1F1F2A')
    tail.paint(lambda p, cc, g: (tip, False) if p[1] > 5.0 * k else None)
    _mirror(tail)


# ------------------------------------------------------------------ musk ox

def _muskox(c, k, cols):
    col = cols['col']
    face_col = _dark(col, 0.25)
    snout = cols.get('snout') or hexc('#B8A890')
    horn = cols.get('accent') or hexc('#D8CCB0')
    glow = cols.get('glow') or hexc('#FFF4D6')
    w = max(2, round(0.7 * k))
    _legs(c, k, ((0.95, -0.9), (0.95, 2.0)), 2.2 * k, w, _dark(col, 0.15), foot=hexc('#2A2420'), foot_h=0.4)
    body = c.part('body')
    body.ell((0, 0.6 * k, 3.4 * k), (1.7 * k, 2.4 * k, 1.6 * k), col)
    body.ell((0, -0.2 * k, 4.4 * k), (1.35 * k, 1.3 * k, 1.05 * k), col)  # the shoulder hump
    # a lighter saddle on the back
    body.paint(lambda p, cc, g: (_light(col, 0.22), False) if p[2] > 4.4 * k and -0.3 * k < p[1] < 1.6 * k else None)
    # the shaggy skirt: the body's outline at its widest hangs down nearly
    # to the floor in uneven streaks, over the legs
    zc = round(3.4 * k)
    ring = {(x, y) for (x, y, z) in body.v if z == zc}
    rim = {q for q in ring if any((q[0] + d0, q[1] + d1) not in ring for d0, d1 in ((1, 0), (-1, 0), (0, 1), (0, -1)))}
    rim2 = {q for q in ring if q not in rim and any((q[0] + d0, q[1] + d1) in rim for d0, d1 in ((1, 0), (-1, 0), (0, 1), (0, -1)))}
    for (x, y) in rim | rim2:
        hx = x if x >= 0 else -x - 1
        end = max(1, round(0.4 * k)) + _h(hx, y) % 3
        shade = (col, _dark(col, 0.14), _light(col, 0.1))[_h(hx, y, 5) % 3]
        for z in range(end, zc):
            body.put((x, y, z), shade)
        if (x, y) in rim:  # the hem flares out a little over the lower third
            ox = (1 if x >= 0 else -1) if (x + 1, y) not in ring or (x - 1, y) not in ring else 0
            oy = (1 if y > 0.6 * k else -1) if (x, y + 1) not in ring or (x, y - 1) not in ring else 0
            for z in range(end, round(1.5 * k)):
                body.put((x + ox, y + oy, z), shade)
    head = c.part('head', 'head', (0, -1.5 * k, 3.8 * k))
    head.ell((0, -2.45 * k, 3.5 * k), (1.1 * k, 1.05 * k, 1.1 * k), face_col)
    head.ell((0, -3.4 * k, 2.85 * k), (0.72 * k, 0.55 * k, 0.55 * k), snout)
    # a shaggy beard hanging under the chin
    head.ell((0, -2.4 * k, 2.15 * k), (0.85 * k, 0.75 * k, 0.75 * k), col)
    fy = min(p[1] for p in head.v)
    zt = max(p[2] for p in head.v if p[1] == fy)
    for x in (round(0.3 * k), -round(0.3 * k) - 1):
        head.put((x, fy, zt), INK)
    face(c, head, k, 3.55, x_off=0.42, size=0.42, cheeks=False)
    # lighter patches round the eyes so they read on the dark face
    eyes = next(p for p in c.parts if p.name == 'eyes')
    ev = list(eyes.v)
    head.paint(lambda p, cc, g: (_light(face_col, 0.35), False) if p not in eyes.v and cc == face_col and any(
        abs(p[0] - e[0]) <= 1 and abs(p[2] - e[2]) <= 1 and abs(p[1] - e[1]) <= 1 for e in ev) else None)
    _mirror(head)
    # small ears tucked out sideways under the horns
    _ears_round(c, k, 1.15, -2.2, 3.55, (0.32 * k, 0.2 * k, 0.2 * k), face_col, (0, -2.2 * k, 3.6 * k))
    # horns: a boss across the crown, sweeping out and curling down past the ears
    horns = c.part('horns', 'static')
    horns.ell((0, -2.4 * k, 4.45 * k), (1.0 * k, 0.45 * k, 0.32 * k), horn)
    pts = ((0.6, -2.4, 4.5), (1.35, -2.35, 4.35), (1.75, -2.45, 3.7), (1.8, -2.75, 2.95), (1.55, -3.15, 2.75), (1.5, -3.35, 3.15))
    for i in range(len(pts) - 1):
        r = (0.4 - 0.05 * i) * k
        line(horns, tuple(v * k for v in pts[i]), tuple(v * k for v in pts[i + 1]), horn, r=max(r, 0.65))
    tipz = 3.0 * k
    horns.paint(lambda p, cc, g: (glow, True) if p[1] < -3.0 * k and p[2] > tipz and abs(p[0]) > 1.2 * k else None)
    _mirror(horns)
    tail = c.part('tail', 'tail', (0, 2.9 * k, 3.6 * k))
    tail.ell((0, 3.0 * k, 3.4 * k), (0.4 * k, 0.4 * k, 0.6 * k), col)
    _mirror(tail)


# ------------------------------------------------------------------ sand cat

def _sandcat(c, k, cols):
    col = cols['col']
    belly = cols.get('belly') or _light(col, 0.4)
    stripe = cols.get('accent') or hexc('#8A6A44')
    glow = cols.get('glow') or hexc('#FFB24A')
    w = max(2, round(0.6 * k))
    bands = (round(0.55 * k), round(1.2 * k))

    def striped(q, cc, base):
        x0, y0, ww = base
        outer = q[0] == x0 + ww - 1 or q[1] == y0
        return stripe if outer and q[2] in bands else None
    _legs(c, k, ((0.7, -0.8), (0.7, 2.0)), 2.0 * k, w, col, foot=belly, foot_h=0.2, paint=striped)
    body = c.part('body')
    body.ell((0, 0.6 * k, 2.6 * k), (1.2 * k, 2.0 * k, 1.1 * k), col)
    body.paint(lambda p, cc, g: (belly, False) if p[2] < 2.1 * k and abs(p[0] + .5) < 0.9 * k else None)
    head = c.part('head', 'head', (0, -1.4 * k, 3.6 * k))
    # a wide, flat head with fluffy cheeks
    head.ell((0, -2.2 * k, 4.4 * k), (1.55 * k, 1.2 * k, 1.0 * k), col)
    head.ell((1.2 * k, -2.5 * k, 3.95 * k), (0.5 * k, 0.6 * k, 0.48 * k), belly)
    head.ell((0, -3.25 * k, 4.0 * k), (0.6 * k, 0.4 * k, 0.4 * k), belly)
    fy = min(p[1] for p in head.v)
    zt = max(p[2] for p in head.v if p[1] == fy)
    head.put((0, fy, zt), hexc('#E8909A'))
    _mirror(head)
    face(c, head, k, 4.55, x_off=0.5, size=0.5, cheeks=False)
    # a dark line running back from each eye's outer corner
    eyes = next(p for p in c.parts if p.name == 'eyes')
    ez = min(p[2] for p in eyes.v)
    ex = max(p[0] for p in eyes.v)
    for (x, y, z) in list(head.v):
        if z == ez and x in (ex + 1, ex + 2) and (x, y - 1, z) not in head.v:
            head.put((x, y, z), stripe)
    _mirror(head)
    # wide ears set low on the sides of the head, leaning outward, dark tips
    # and glowing insides
    ears = c.part('ears', 'ears', (0, -2.2 * k, 5.1 * k))
    n = max(3, round(1.05 * k))
    y0 = round(-2.25 * k)
    for i in range(n):
        t = i / (n - 1)
        wd = (1.0 - t) * 0.72 * k
        cx = 1.25 * k + t * 0.5 * k
        z = round(4.95 * k) + i
        for x in range(math.floor(cx - wd), math.ceil(cx + wd) + 1):
            for y in (y0, y0 + 1):
                inner = y == y0 and abs(x + .5 - cx) < wd - 1 and i < n - 1
                ears.put((x, y, z), (glow if inner else (INK if t > 0.75 else col)), inner)
    _mirror(ears)
    tail = c.part('tail', 'tail', (0, 2.5 * k, 2.9 * k))
    line(tail, (0, 2.5 * k, 2.9 * k), (0, 3.9 * k, 2.5 * k), col, r=0.4 * k)
    line(tail, (0, 3.9 * k, 2.5 * k), (0, 4.8 * k, 3.1 * k), col, r=0.37 * k)
    ring = max(1, round(0.3 * k))
    tail.paint(lambda p, cc, g: (INK, False) if p[1] > 4.5 * k else (stripe, False) if any(
        abs(p[1] - r * k) < ring / 2 + .01 for r in (3.4, 4.0)) else None)
    _mirror(tail)


# ------------------------------------------------------------------ sea otter

def _otter(c, k, cols):
    col = cols['col']
    belly = cols.get('belly') or _light(col, 0.3)
    pale = cols.get('snout') or _light(col, 0.6)
    shell = cols.get('accent') or hexc('#FFC8B0')
    glow = cols.get('glow') or hexc('#F4FBFF')
    body = c.part('body')
    # lying on its back: a long body low on the water, chest and belly up
    body.ell((0, 0.7 * k, 1.8 * k), (1.35 * k, 2.8 * k, 1.0 * k), col)
    body.ell((0, -0.6 * k, 2.3 * k), (1.2 * k, 1.3 * k, 1.0 * k), col)  # the chest, raised
    body.paint(lambda p, cc, g: (belly, False) if p[2] > 2.2 * k and abs(p[0] + .5) < 1.0 * k and p[1] < 2.6 * k else None)
    # front paws resting on the chest holding a shell with a glowing pearl
    for x in (0.62,):
        body.ell((x * k, -0.9 * k, 3.3 * k), (0.32 * k, 0.4 * k, 0.32 * k), _dark(col, 0.2))
    _mirror(body)
    sh = c.part('shell', 'static')
    sh.ell((0, -0.5 * k, 3.55 * k), (0.75 * k, 0.6 * k, 0.3 * k), shell)
    sh.paint(lambda p, cc, g: (_dark(shell, 0.18), False) if p[0] % 2 == 0 else None)
    sh.ell((0, -0.55 * k, 3.95 * k), (0.25 * k + .3, 0.25 * k + .3, 0.25 * k + .3), glow, True)
    _mirror(sh)
    head = c.part('head', 'head', (0, -2.0 * k, 2.3 * k))
    head.ell((0, -2.75 * k, 3.0 * k), (1.1 * k, 1.0 * k, 1.0 * k), pale)
    head.paint(lambda p, cc, g: (_mix(pale, col, 0.4), False) if p[1] > -2.3 * k else None)
    head.ell((0, -3.6 * k, 2.75 * k), (0.52 * k, 0.4 * k, 0.38 * k), _light(pale, 0.4))
    fy = min(p[1] for p in head.v)
    zt = max(p[2] for p in head.v if p[1] == fy)
    head.put((0, fy, zt), INK)
    _mirror(head)
    face(c, head, k, 3.3, x_off=0.45, size=0.4, cheeks=True, cheek_z=2.85, cheek_x=0.85)
    _ears_round(c, k, 0.98, -2.5, 3.75, (0.28 * k, 0.2 * k, 0.25 * k), _dark(col, 0.1), (0, -2.45 * k, 3.6 * k))
    # webbed hind feet held up out of the water: they paddle as it swims
    for name, sx in (('finR', 1), ('finL', -1)):
        fin = c.part(name, name, (sx * 0.75 * k, 2.9 * k, 2.2 * k))
        line(fin, (0.75 * k, 2.9 * k, 2.2 * k), (0.95 * k, 3.3 * k, 3.4 * k), _dark(col, 0.1), r=0.32 * k)
        fin.ell((1.0 * k, 3.4 * k, 3.75 * k), (0.48 * k, 0.24 * k, 0.55 * k), _dark(col, 0.25))
        if sx < 0:
            fin.v = {(-x - 1, y, z): v for (x, y, z), v in fin.v.items()}
    tail = c.part('tail', 'tail', (0, 3.3 * k, 1.7 * k))
    tail.ell((0, 4.4 * k, 1.75 * k), (0.5 * k, 1.1 * k, 0.26 * k), cols.get('tail_col') or _dark(col, 0.1))
    _mirror(tail)


# ------------------------------------------------------------------ hamster

def _hamster(c, k, cols):
    col = cols['col']
    belly = cols.get('belly') or _light(col, 0.5)
    pink = hexc('#FFB3C7')
    _legs(c, k, ((0.7, -0.9), (0.7, 1.3)), 1.6 * k, max(2, round(0.5 * k)), _dark(col, 0.08), foot=pink, foot_h=0.25)
    body = c.part('body')
    # a round, chubby ball of a body
    body.ell((0, 0.4 * k, 2.75 * k), (1.65 * k, 1.8 * k, 1.55 * k), col)
    body.paint(lambda p, cc, g: (belly, False) if p[2] < 2.6 * k and abs(p[0] + .5) < 1.1 * k and p[1] < 0.8 * k else None)
    head = c.part('head', 'head', (0, -1.0 * k, 3.4 * k))
    head.ell((0, -1.55 * k, 3.4 * k), (1.35 * k, 1.15 * k, 1.15 * k), col)
    # puffed-out cheek pouches and a tiny pink nose
    head.ell((1.0 * k, -2.05 * k, 2.85 * k), (0.62 * k, 0.55 * k, 0.55 * k), belly)
    head.ell((0, -2.6 * k, 3.05 * k), (0.38 * k, 0.28 * k, 0.32 * k), belly)
    _mirror(head)
    fy = min(p[1] for p in head.v)
    zt = max(p[2] for p in head.v if p[1] == fy)
    head.put((0, fy, zt), pink)
    head.put((-1, fy, zt), pink)
    face(c, head, k, 3.55, x_off=0.55, size=0.4, cheeks=False)
    ears = c.part('ears', 'ears', (0, -1.4 * k, 4.4 * k))
    ears.ell((0.85 * k, -1.45 * k, 4.45 * k), (0.36 * k, 0.18 * k + .3, 0.36 * k), col)
    ears.paint(lambda p, cc, g: (pink, False) if p[1] == min(q[1] for q in ears.v) and abs(p[0] + .5 - 0.85 * k) < 0.2 * k + .5 and p[2] < 4.6 * k else None)
    _mirror(ears)
    tail = c.part('tail', 'tail', (0, 2.0 * k, 2.2 * k))
    tail.ell((0, 2.25 * k, 2.1 * k), (0.25 * k + .3, 0.3 * k, 0.25 * k + .3), col)
    _mirror(tail)


# ------------------------------------------------------------------ mouse

def _mouse(c, k, cols):
    col = cols['col']
    belly = cols.get('belly') or _light(col, 0.4)
    pink = cols.get('accent') or hexc('#FFB3C7')
    _legs(c, k, ((0.6, -0.8), (0.6, 1.6)), 1.6 * k, 2, _dark(col, 0.1), foot=pink, foot_h=0.25)
    body = c.part('body')
    body.ell((0, 0.5 * k, 2.3 * k), (1.15 * k, 1.85 * k, 1.1 * k), col)
    body.paint(lambda p, cc, g: (belly, False) if p[2] < 2.0 * k and abs(p[0] + .5) < 0.8 * k else None)
    head = c.part('head', 'head', (0, -1.2 * k, 2.9 * k))
    head.ell((0, -1.8 * k, 3.15 * k), (1.0 * k, 1.0 * k, 0.95 * k), col)
    # a pointed snout with a pink nose at the tip
    head.ell((0, -2.85 * k, 2.85 * k), (0.48 * k, 0.65 * k, 0.42 * k), belly)
    fy = min(p[1] for p in head.v)
    zt = max(p[2] for p in head.v if p[1] == fy)
    head.put((0, fy, zt), pink)
    head.put((-1, fy, zt), pink)
    _mirror(head)
    face(c, head, k, 3.45, x_off=0.5, size=0.36, cheeks=False)
    # big round ears, thin discs with pink fronts
    ears = c.part('ears', 'ears', (0, -1.6 * k, 4.0 * k))
    ears.ell((0.95 * k, -1.55 * k, 4.35 * k), (0.72 * k, 0.15 * k + .35, 0.72 * k), col)
    fr = min(q[1] for q in ears.v)
    ears.paint(lambda p, cc, g: (pink, False) if p[1] == fr and math.hypot(p[0] + .5 - 0.95 * k, p[2] + .5 - 4.35 * k) < 0.5 * k else None)
    _mirror(ears)
    # a long thin tail curving back and up
    tail = c.part('tail', 'tail', (0, 2.3 * k, 1.9 * k))
    tc = cols.get('tail_col') or pink
    line(tail, (0, 2.3 * k, 1.9 * k), (0, 3.8 * k, 1.1 * k), tc, r=0.3 * k)
    line(tail, (0, 3.8 * k, 1.1 * k), (0, 5.0 * k, 2.0 * k), tc, r=0.25 * k)
    _mirror(tail)


# ------------------------------------------------------------------ badger

def _badger(c, k, cols):
    col = cols['col']
    stripe = cols.get('snout') or hexc('#F4F1EA')
    claw = cols.get('belly') or _dark(col, 0.4)
    w = max(2, round(0.75 * k))
    _legs(c, k, ((1.0, -1.2), (1.0, 1.9)), 1.5 * k, w, _dark(col, 0.25), foot=claw, foot_h=0.25)
    body = c.part('body')
    # low and wide, broad in the shoulders
    body.ell((0, 0.6 * k, 2.3 * k), (1.65 * k, 2.3 * k, 1.05 * k), col)
    body.ell((0, -0.6 * k, 2.5 * k), (1.55 * k, 1.2 * k, 1.05 * k), col)
    body.paint(lambda p, cc, g: (_light(col, 0.18), False) if p[2] > 3.0 * k and _h(*p) % 4 == 0 else None)
    head = c.part('head', 'head', (0, -1.6 * k, 2.6 * k))
    head.ell((0, -2.2 * k, 2.6 * k), (1.15 * k, 1.05 * k, 0.9 * k), col)
    head.ell((0, -3.2 * k, 2.3 * k), (0.55 * k, 0.65 * k, 0.45 * k), col)
    head.ell((0, -3.9 * k, 2.2 * k), (0.35 * k, 0.5 * k, 0.3 * k), col)  # a pointed snout
    # the badger's white stripe from the nose over the crown, and white cheeks
    head.paint(lambda p, cc, g: (stripe, False) if abs(p[0] + .5) < 0.35 * k + .5 and p[2] > 2.3 * k else None)
    head.paint(lambda p, cc, g: (stripe, False) if abs(p[0] + .5) > 0.75 * k and p[2] < 2.6 * k and p[1] < -2.2 * k else None)
    fy = min(p[1] for p in head.v)
    zt = max(p[2] for p in head.v if p[1] == fy)
    head.put((0, fy, zt), INK)
    head.put((-1, fy, zt), INK)
    _mirror(head)
    face(c, head, k, 2.8, x_off=0.55, size=0.36, cheeks=False)
    _ears_round(c, k, 1.0, -1.9, 3.35, (0.3 * k, 0.2 * k, 0.26 * k), stripe, (0, -1.9 * k, 3.2 * k))
    tail = c.part('tail', 'tail', (0, 2.8 * k, 2.6 * k))
    tail.ell((0, 3.1 * k, 2.5 * k), (0.4 * k, 0.5 * k, 0.32 * k), _light(col, 0.15))
    _mirror(tail)


# ------------------------------------------------------------------ lamb

def _lamb(c, k, cols):
    col = cols['col']
    face_col = cols.get('snout') or hexc('#3A3438')
    _legs(c, k, ((0.75, -0.8), (0.75, 1.9)), 2.6 * k, 2, face_col, foot=_dark(face_col, 0.35), foot_h=0.3)
    body = c.part('body')
    body.ell((0, 0.55 * k, 3.25 * k), (1.4 * k, 2.0 * k, 1.2 * k), col)
    # curly wool: little puffs all over, a shade darker in the hollows
    for i in range(26):
        a = _h(i, 1) % 360 / 180 * math.pi
        b = (_h(i, 2) % 140 - 50) / 180 * math.pi
        x = math.cos(b) * math.cos(a) * 1.3 * k
        y = 0.55 * k + math.cos(b) * math.sin(a) * 1.9 * k
        z = 3.25 * k + math.sin(b) * 1.1 * k
        body.ell((x, y, z), (0.5 * k, 0.5 * k, 0.5 * k), col if i % 3 else _dark(col, 0.06))
    _mirror(body)
    head = c.part('head', 'head', (0, -1.3 * k, 4.0 * k))
    head.ell((0, -2.1 * k, 4.15 * k), (0.8 * k, 0.85 * k, 0.95 * k), face_col)
    head.ell((0, -2.65 * k, 3.75 * k), (0.55 * k, 0.5 * k, 0.5 * k), _light(face_col, 0.15))
    # a woolly cap on the crown
    head.ell((0, -1.95 * k, 4.95 * k), (0.85 * k, 0.75 * k, 0.5 * k), col)
    _mirror(head)
    face(c, head, k, 4.3, x_off=0.42, size=0.36, cheeks=False)
    eyes = next(p for p in c.parts if p.name == 'eyes')
    if face_col == hexc('#3A3438') or sum(face_col) < 300:  # dark face: pale eyes with dark pupils
        for q in list(eyes.v):
            if eyes.v[q][0] == INK:
                eyes.v[q] = (WHITE, False)
    ears = c.part('ears', 'ears', (0, -2.0 * k, 4.5 * k))
    line(ears, (0.75 * k, -2.0 * k, 4.45 * k), (1.6 * k, -2.0 * k, 4.35 * k), face_col, r=0.3 * k)  # out to the sides
    _mirror(ears)
    tail = c.part('tail', 'tail', (0, 2.5 * k, 3.6 * k))
    tail.ell((0, 2.7 * k, 3.5 * k), (0.45 * k, 0.4 * k, 0.45 * k), col)
    _mirror(tail)


# ------------------------------------------------------------------ foal

def _foal(c, k, cols, neck=1.0):
    """A foal or calf on long legs: a long horse-like head on an upright
    neck with a short mane, small upright pointed ears, side eyes with a
    glint, a slim body, a thin tail with a tuft. `neck` stretches the neck
    (a giraffe's is about 2)."""
    col = cols['col']
    belly = cols.get('belly') or col
    snout = cols.get('snout') or _light(col, 0.3)
    mane = cols.get('accent') or _dark(col, 0.35)
    hoof = _dark(cols.get('tail_col') or col, 0.45)
    w = max(2, round(0.55 * k))
    _legs(c, k, ((0.75, -0.9), (0.75, 2.0)), 3.3 * k, w, col, foot=hoof, foot_h=0.3)
    body = c.part('body')
    body.ell((0, 0.6 * k, 4.0 * k), (1.15 * k, 2.1 * k, 1.05 * k), col)
    body.paint(lambda p, cc, g: (belly, False) if p[2] < 3.5 * k and abs(p[0] + .5) < 0.8 * k else None)
    nz = 4.6 * k + 2.0 * k * neck  # where the neck meets the head
    head = c.part('head', 'head', (0, -1.1 * k, 4.6 * k))
    line(head, (0, -1.1 * k, 4.4 * k), (0, -1.9 * k, nz), col, r=0.55 * k)
    # a short upright mane along the back of the neck
    for i in range(int(2.0 * k * neck) + 1):
        t = i / max(1, 2.0 * k * neck)
        y = -1.1 * k - t * 0.8 * k + 0.55 * k
        z = 4.6 * k + t * 2.0 * k * neck
        for x in (-1, 0):
            head.put((x, math.floor(y), math.floor(z)), mane)
            head.put((x, math.floor(y) + 1, math.floor(z)), mane)
    head.ell((0, -2.2 * k, nz + 0.4 * k), (0.72 * k, 0.8 * k, 0.68 * k), col)
    head.ell((0, -3.2 * k, nz), (0.55 * k, 0.8 * k, 0.5 * k), snout)
    fy = min(p[1] for p in head.v)
    zt = max(p[2] for p in head.v if p[1] == fy)
    for x in (round(0.25 * k), -round(0.25 * k) - 1):
        head.put((x, fy, zt), INK)
    _side_eyes(c, head, round(-2.45 * k), round(nz + 0.45 * k), brow=_light(col, 0.3))
    ears = c.part('ears', 'ears', (0, -2.0 * k, nz + 1.0 * k))
    n = max(3, round(0.8 * k))
    for i in range(n):
        x = round(0.5 * k) + i // 3
        ears.put((x, round(-2.0 * k), round(nz + 0.9 * k) + i), col)
        if i < n - 1:
            ears.put((x + 1, round(-2.0 * k), round(nz + 0.9 * k) + i), col)
    _mirror(ears)
    tail = c.part('tail', 'tail', (0, 2.6 * k, 4.4 * k))
    tc = cols.get('tail_col') or mane
    line(tail, (0, 2.6 * k, 4.4 * k), (0, 3.1 * k, 3.0 * k), col, r=0.25 * k)
    tail.ell((0, 3.15 * k, 2.6 * k), (0.32 * k, 0.3 * k, 0.55 * k), tc)
    _mirror(tail)


def _giraffe(c, k, cols):
    _foal(c, k, cols, neck=1.9)


# ------------------------------------------------------------------ bear

def _bear(c, k, cols):
    col = cols['col']
    snout = cols.get('snout') or _light(col, 0.25)
    pad = cols.get('accent') or _dark(col, 0.45)
    w = max(2, round(0.85 * k))
    _legs(c, k, ((0.95, -1.1), (0.95, 1.7)), 1.9 * k, w, col, foot=_dark(col, 0.08), foot_h=0.25)
    body = c.part('body')
    body.ell((0, 0.4 * k, 3.0 * k), (1.6 * k, 2.3 * k, 1.45 * k), col)
    body.ell((0, -0.6 * k, 3.4 * k), (1.45 * k, 1.3 * k, 1.3 * k), col)  # chunky shoulders
    head = c.part('head', 'head', (0, -1.6 * k, 3.9 * k))
    head.ell((0, -2.2 * k, 4.2 * k), (1.15 * k, 1.05 * k, 1.0 * k), col)
    head.ell((0, -3.25 * k, 3.8 * k), (0.62 * k, 0.6 * k, 0.48 * k), snout)
    fy = min(p[1] for p in head.v)
    zt = max(p[2] for p in head.v if p[1] == fy)
    for x in (0, -1):
        head.put((x, fy, zt), INK)
        head.put((x, fy, zt - 1), INK)
    _mirror(head)
    face(c, head, k, 4.45, x_off=0.45, size=0.35, cheeks=True, cheek_z=4.0, cheek_x=0.95)
    _ears_round(c, k, 0.85, -2.0, 5.1, (0.36 * k, 0.24 * k, 0.32 * k), col, (0, -2.0 * k, 5.0 * k))
    tail = c.part('tail', 'tail', (0, 2.6 * k, 3.4 * k))
    tail.ell((0, 2.75 * k, 3.4 * k), (0.32 * k, 0.3 * k, 0.32 * k), col)
    _mirror(tail)
    del pad


# ------------------------------------------------------------------ mole

def _mole(c, k, cols):
    col = cols['col']
    pink = cols.get('snout') or hexc('#FF9EB8')
    _legs(c, k, ((0.75, -0.6), (0.75, 1.9)), 1.2 * k, 2, _dark(col, 0.1), foot=pink, foot_h=0.25)
    body = c.part('body')
    # a long, low velvet sausage
    body.ell((0, 0.6 * k, 2.0 * k), (1.35 * k, 2.4 * k, 1.15 * k), col)
    head = c.part('head', 'head', (0, -1.5 * k, 2.2 * k))
    head.ell((0, -1.9 * k, 2.2 * k), (1.05 * k, 1.0 * k, 0.95 * k), col)
    # a long pointed pink nose
    line(head, (0, -2.6 * k, 2.1 * k), (0, -3.6 * k, 1.9 * k), pink, r=0.38 * k)
    head.ell((0, -3.75 * k, 1.9 * k), (0.45 * k, 0.3 * k, 0.4 * k), pink)
    _mirror(head)
    # tiny eyes, squinting
    face(c, head, k, 2.75, x_off=0.55, size=0.25, cheeks=False)
    # big pink digging paws held out at the shoulders
    paws = c.part('paws', 'static')
    for i in range(3):
        paws.ell((1.35 * k, -1.2 * k + i * 0.35 * k, 1.5 * k), (0.5 * k, 0.22 * k + .3, 0.55 * k), pink)
    for q in list(paws.v):
        if q[2] <= round(1.0 * k) and q[1] < -1.2 * k:
            paws.v[q] = (_dark(pink, 0.25), False)  # claws
    _mirror(paws)
    tail = c.part('tail', 'tail', (0, 2.9 * k, 2.0 * k))
    line(tail, (0, 2.9 * k, 2.0 * k), (0, 3.6 * k, 2.3 * k), pink, r=0.22 * k)
    _mirror(tail)


# ------------------------------------------------------------------ squirrel

def _squirrel(c, k, cols):
    col = cols['col']
    belly = cols.get('belly') or _light(col, 0.4)
    _legs(c, k, ((0.6, -0.8), (0.6, 1.4)), 1.5 * k, 2, col, foot=_dark(col, 0.15), foot_h=0.25)
    body = c.part('body')
    body.ell((0, 0.4 * k, 2.4 * k), (1.15 * k, 1.75 * k, 1.15 * k), col)
    body.paint(lambda p, cc, g: (belly, False) if p[2] < 2.4 * k and abs(p[0] + .5) < 0.75 * k and p[1] < 0.6 * k else None)
    head = c.part('head', 'head', (0, -1.2 * k, 3.1 * k))
    head.ell((0, -1.8 * k, 3.5 * k), (1.0 * k, 0.95 * k, 0.9 * k), col)
    head.ell((0, -2.7 * k, 3.15 * k), (0.45 * k, 0.4 * k, 0.38 * k), belly)
    fy = min(p[1] for p in head.v)
    zt = max(p[2] for p in head.v if p[1] == fy)
    head.put((0, fy, zt), INK)
    head.put((-1, fy, zt), INK)
    _mirror(head)
    face(c, head, k, 3.7, x_off=0.5, size=0.36, cheeks=True, cheek_z=3.3, cheek_x=0.85)
    # ears with tufts
    ears = c.part('ears', 'ears', (0, -1.7 * k, 4.3 * k))
    for i in range(max(3, round(0.9 * k))):
        ears.put((round(0.55 * k), round(-1.7 * k), round(4.2 * k) + i), col if i < 2 else _dark(col, 0.2))
        ears.put((round(0.55 * k) + 1, round(-1.7 * k), round(4.2 * k) + i), col if i < 1 else _dark(col, 0.2))
    _mirror(ears)
    # a big bushy tail curling up over the back
    tail = c.part('tail', 'tail', (0, 2.0 * k, 2.4 * k))
    tc = cols.get('tail_col') or col
    for i in range(9):
        t = i / 8
        ang = t * math.pi * 1.1
        y = 2.2 * k + math.sin(ang) * 1.4 * k
        z = 2.0 * k + (1 - math.cos(ang)) * 1.9 * k
        r = (0.55 + 0.35 * math.sin(t * math.pi)) * k
        tail.ell((0, y, z), (r * 0.9, r, r), tc)
    tail.paint(lambda p, cc, g: (_light(tc, 0.2), False) if _h(*p) % 5 == 0 else None)
    _mirror(tail)


# ------------------------------------------------------------------ big cats

def _spots(part, k, col, rosette=False):
    """Spots over a part's surface, sized to the voxels: a cheetah's are
    scattered single dark voxels; a snow leopard's rosettes are small broken
    rings (two or three dark voxels round a lighter centre)."""
    vs = part.v
    surf = [p for p in vs if any(n not in vs for n in (
        (p[0] + 1, p[1], p[2]), (p[0] - 1, p[1], p[2]), (p[0], p[1] + 1, p[2]),
        (p[0], p[1] - 1, p[2]), (p[0], p[1], p[2] + 1)))]
    if not rosette:
        for p in surf:
            if not vs[p][1] and _hm(*p) % 5 == 0:
                vs[p] = (col, False)
        return
    ring = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
    for p in surf:
        if vs[p][1] or _hm(*p, 7) % 7:
            continue
        h = _hm(*p, 9)
        for j, d in enumerate(ring):
            q = (p[0] + d[0], p[1] + d[1], p[2] + d[2])
            if q in vs and (h >> j) % 3 and q in set(surf):
                vs[q] = (col, False)


def _bigcat(c, k, cols, snow=False):
    col = cols['col']
    belly = cols.get('belly') or _light(col, 0.5)
    spot = cols.get('accent') or hexc('#2A2020')
    w = max(2, round((0.62 if snow else 0.5) * k))
    hz = (2.0 if snow else 2.7) * k
    _legs(c, k, ((0.7, -0.9), (0.7, 2.0)), hz, w, col, foot=belly, foot_h=0.2)
    body = c.part('body')
    bz = hz + (0.5 if snow else 0.45) * k
    body.ell((0, 0.6 * k, bz), ((1.2 if snow else 1.0) * k, 2.0 * k, (1.1 if snow else 0.9) * k), col)
    body.paint(lambda p, cc, g: (belly, False) if p[2] < bz - 0.4 * k and abs(p[0] + .5) < 0.75 * k else None)
    head = c.part('head', 'head', (0, -1.3 * k, bz + 0.6 * k))
    hzc = bz + 1.0 * k
    head.ell((0, -2.0 * k, hzc), ((1.1 if snow else 0.95) * k, 0.95 * k, 0.88 * k), col)
    head.ell((0, -2.85 * k, hzc - 0.35 * k), (0.48 * k, 0.4 * k, 0.38 * k), belly)
    fy = min(p[1] for p in head.v)
    zt = max(p[2] for p in head.v if p[1] == fy)
    head.put((0, fy, zt), hexc('#E8909A') if snow else INK)
    head.put((-1, fy, zt), hexc('#E8909A') if snow else INK)
    _mirror(head)
    face(c, head, k, hzc / k + 0.15, x_off=0.42, size=0.36, cheeks=False)
    if not snow:  # a cheetah's dark tear lines from the eyes to the mouth
        eyes = next(p for p in c.parts if p.name == 'eyes')
        for (x, y, z) in list(eyes.v):
            if x >= 0 and eyes.v[(x, y, z)][0] == INK:
                for dz in range(1, max(2, round(0.7 * k))):
                    q = head.front(x, z - dz)
                    if q:
                        head.v[q] = (_mix(spot, col, 0.35), False)
        _mirror(head)
    _ears_round(c, k, 0.72, -1.8, hzc / k + 0.85, (0.3 * k, 0.18 * k, 0.26 * k), col, (0, -1.8 * k, hzc + 0.8 * k))
    for part in [body] + [p for p in c.parts if p.name.startswith('leg')]:
        _spots(part, k, spot, rosette=snow)
    tail = c.part('tail', 'tail', (0, 2.5 * k, bz))
    if snow:  # very thick and long, curling up at the end
        line(tail, (0, 2.5 * k, bz), (0, 5.0 * k, bz - 1.2 * k), col, r=0.6 * k)
        line(tail, (0, 5.0 * k, bz - 1.2 * k), (0, 6.3 * k, bz - 0.2 * k), col, r=0.6 * k)
        _spots(tail, k, spot, rosette=True)
    else:  # long and thin, ringed dark at the end, a white tip
        line(tail, (0, 2.5 * k, bz), (0, 4.4 * k, bz - 1.1 * k), col, r=0.3 * k)
        line(tail, (0, 4.4 * k, bz - 1.1 * k), (0, 5.1 * k, bz - 0.5 * k), col, r=0.3 * k)
        tail.paint(lambda p, cc, g: (WHITE, False) if p[1] > 4.85 * k else (spot, False) if p[1] > 3.6 * k and (p[1] // 2) % 2 == 0 else None)
        _spots(tail, k, spot)
    _mirror(tail)


def _cheetah(c, k, cols):
    _bigcat(c, k, cols, snow=False)


def _snowleopard(c, k, cols):
    _bigcat(c, k, cols, snow=True)


# ------------------------------------------------------------------ hippo

def _hippo(c, k, cols):
    col = cols['col']
    snout = cols.get('snout') or _light(col, 0.3)
    w = max(2, round(0.85 * k))
    _legs(c, k, ((1.0, -1.0), (1.0, 1.9)), 1.3 * k, w, _dark(col, 0.08), foot=_dark(col, 0.3), foot_h=0.25)
    body = c.part('body')
    body.ell((0, 0.5 * k, 2.6 * k), (1.75 * k, 2.4 * k, 1.5 * k), col)
    body.paint(lambda p, cc, g: (_light(col, 0.15), False) if p[2] < 1.9 * k else None)
    head = c.part('head', 'head', (0, -1.5 * k, 3.0 * k))
    head.ell((0, -2.2 * k, 3.2 * k), (1.25 * k, 1.1 * k, 1.0 * k), col)
    # a very wide, flat-fronted muzzle
    head.ell((0, -3.1 * k, 2.7 * k), (1.35 * k, 0.75 * k, 0.8 * k), snout)
    cut = round(-3.55 * k)
    for q in [q for q in head.v if q[1] < cut]:
        del head.v[q]
    fy = min(p[1] for p in head.v)
    zt = max(p[2] for p in head.v if p[1] <= fy + 1)
    # nostrils on top of the muzzle, near the front
    for x in (round(0.5 * k), -round(0.5 * k) - 1):
        q = (x, fy + 1, zt)
        if q in head.v:
            head.v[q] = (_dark(snout, 0.5), False)
    _mirror(head)
    face(c, head, k, 3.75, x_off=0.55, size=0.36, cheeks=False)
    _ears_round(c, k, 0.85, -1.8, 4.2, (0.24 * k, 0.16 * k, 0.22 * k), col, (0, -1.8 * k, 4.1 * k))
    tail = c.part('tail', 'tail', (0, 2.8 * k, 2.8 * k))
    line(tail, (0, 2.8 * k, 2.8 * k), (0, 3.2 * k, 2.2 * k), col, r=0.24 * k)
    _mirror(tail)


# ------------------------------------------------------------------ rhino

def _rhino(c, k, cols):
    col = cols['col']
    horn = cols.get('accent') or hexc('#E8E0D0')
    glow = cols.get('glow')
    w = max(2, round(0.8 * k))
    _legs(c, k, ((1.0, -1.0), (1.0, 2.0)), 1.7 * k, w, col, foot=_dark(col, 0.25), foot_h=0.25)
    body = c.part('body')
    body.ell((0, 0.6 * k, 2.9 * k), (1.6 * k, 2.4 * k, 1.4 * k), col)
    body.paint(lambda p, cc, g: (_dark(col, 0.08), False) if (p[1] - round(0.2 * k)) % max(3, round(1.4 * k)) == 0 and p[2] > 2.2 * k else None)
    # a long, low, heavy head sloping down to the nose
    head = c.part('head', 'head', (0, -1.3 * k, 3.0 * k))
    line(head, (0, -1.6 * k, 3.1 * k), (0, -3.4 * k, 2.3 * k), col, r=0.85 * k)
    head.ell((0, -1.9 * k, 3.2 * k), (1.0 * k, 0.9 * k, 0.9 * k), col)
    fy = min(p[1] for p in head.v)
    zt = max(p[2] for p in head.v if p[1] == fy)
    # the big horn at the nose tip, tapering to a point and curving up and
    # back; a small second horn behind it. Horn coloured, only the very tip
    # glows.
    hp = c.part('horns', 'static')
    # side profile, base up: (front, back) offsets from the nose tip and the
    # half width; the front edge sweeps back so the point curves up
    prof = [(0, 3, 2), (0, 2, 1), (1, 2, 1), (1, 2, 1), (2, 2, 1), (3, 3, 1)]
    for i, (f0, b0, wide) in enumerate(prof):
        for x in range(wide):
            for y in range(fy + f0, fy + b0 + 1):
                hp.put((x, y, zt + 1 + i), horn)
    # the small second horn, on the head's top behind the big one
    y2 = fy + 1 + round(1.9 * k)
    z2 = max((p[2] for p in head.v if p[1] == y2 and p[0] in (-1, 0)), default=zt)
    hp.put((0, y2, z2 + 1), _dark(horn, 0.06))
    hp.put((0, y2 + 1, z2 + 1), _dark(horn, 0.06))
    hp.put((0, y2, z2 + 2), _dark(horn, 0.06))
    _mirror(hp)
    _side_eyes(c, head, round(-2.3 * k), round(3.0 * k), brow=_light(col, 0.2))
    # small round ears
    _ears_round(c, k, 0.75, -1.6, 4.0, (0.3 * k + .2, 0.22 * k + .2, 0.28 * k + .2), col, (0, -1.6 * k, 3.9 * k))
    tail = c.part('tail', 'tail', (0, 2.9 * k, 3.2 * k))
    line(tail, (0, 2.9 * k, 3.2 * k), (0, 3.3 * k, 2.4 * k), col, r=0.22 * k)
    if glow:  # the Rare's glow: a little lit tuft at the tail's tip
        tail.ell((0, 3.3 * k, 2.1 * k), (0.2 * k + .2, 0.2 * k + .2, 0.35 * k + .2), glow, True)
    _mirror(tail)


KINDS = {'camel': _camel, 'ermine': _ermine, 'ferret': _ermine, 'muskox': _muskox, 'sandcat': _sandcat, 'otter': _otter,
         'hamster': _hamster, 'mouse': _mouse, 'badger': _badger, 'lamb': _lamb, 'foal': _foal, 'giraffe': _giraffe,
         'bear': _bear, 'mole': _mole, 'squirrel': _squirrel, 'cheetah': _cheetah, 'snowleopard': _snowleopard,
         'hippo': _hippo, 'rhino': _rhino}
GAITS = {'otter': 'swim'}


def beast(c, H, kind, cols):
    k = H / 10.0
    KINDS[kind](c, k, cols)
    eyes = next((p for p in c.parts if p.name == 'eyes'), None)
    if eyes is None or len(eyes.v) < 2:
        # the coarse in-game boxes: too few voxels for the face as drawn, so
        # one ink voxel a side on the head's front, a row above its middle
        head = next(p for p in c.parts if p.name == 'head')
        zs = sorted(p[2] for p in head.v)
        zm = zs[len(zs) // 2]
        e = eyes or c.part('eyes', 'blink', head.pivot)
        for z in (zm + 1, zm, zm + 2, zm - 1):
            for x in (1, 0, 2):
                f, g = head.front(x, z), head.front(-x - 1, z)
                if f and g:
                    for q in (f, g):
                        del head.v[q]
                        e.put(q, INK)
                    break
            if len(e.v) >= 2:
                break
        if len(e.v) < 2:
            raise ValueError(f'{c.species}: the {kind} face has no eyes')
    c.gait_hint = GAITS.get(kind, 'trot')
    return c


PLANS = {
    'mammal': ({'col', 'belly', 'snout', 'accent', 'glow', 'tail_col'}, {'kind': set(KINDS)}),
}

BUILDERS = {
    'mammal': lambda c, H, cols, opts: beast(c, H, opts['kind'], cols),
}
