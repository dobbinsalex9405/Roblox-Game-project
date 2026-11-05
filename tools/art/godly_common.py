"""The `godly` body plan: Hatchery Heist's hand-built Godly showpieces, added
as roster data (tools/art/roster/godlies-01.json) like any other plan, with
`options.kind` naming the creature. Each one is drawn by its own function in
godly_beasts.py (creatures that stand on legs) or godly_skies.py (fliers,
floaters and swimmers); this module holds what they share.

The standard they follow (ops/DECISIONS.md, "Nebula Serpent v4" and "New
Godly creatures"):

- Drawn at the Godly height (creatures.HEIGHT) with 1.6x finer voxels in the
  Blender build (creatures.FINER), about 61 voxels tall. Fine surface detail
  (dithered shading, scales, sparkles, extra trims) is only drawn when
  `c.fine` is set, so the in-game boxes (VoxelArt) stay inside the Godly
  budget of 800.
- Legs, wings and fins are their own parts (rig.LEG_NAMES, wingL/wingR,
  finL/finR), hinged at the hip or shoulder, so the game's walk swings them.
- Eyes are their own `blink` part one voxel proud of the face, so a blink
  shows a lid, not a hole.
- Everything that circles the creature is ONE `orbit` part pivoting on the
  body's centre (the game turns it once every 9 s). orbit_ring() keeps each
  piece clear of everything else at its height (with room for the head and
  wings to move) and keeps the sweep within 0.8x the creature's height, so a
  Godly fits its 3-spot area on the tower (Godly thread, Nov 5).

Same frame as the rest of tools/art: x right, y back (front is -y), z up,
in voxels; k = H / 10, so every size below reads as tenths of the height."""
import math

from voxkit import hexc
from legends import _ball_pts, _fbm, _hash, _mix, _shade, _vnoise, tube  # noqa: F401

INK = hexc('#1B1B2F')
WHITE = hexc('#FFFFFF')
ORBIT_SWEEP = 0.8  # the orbit's sweep radius, at most this share of the height


def ctx(c, H):
    """(k, fine) for a build."""
    return H / 10.0, bool(getattr(c, 'fine', False))


def C(h):
    return hexc(h)


# ------------------------------------------------------------ colour

def gradient(part, stops, z0, z1, fine, keep=(), only=None):
    """Shade a part from bottom to top through `stops` (colours, lowest
    first). The fine build blends between neighbouring stops with an ordered
    dither, so the colour drifts over many voxels; the in-game boxes take the
    nearest stop (few colours, few boxes). Glowing voxels, colours in `keep`
    and voxels `only` rejects stay as they are."""
    n = len(stops)

    def f(p, cc, g):
        if g or cc in keep or (only is not None and not only(p, cc)):
            return None
        t = max(0.0, min(0.9999, (p[2] + .5 - z0) / max(1.0, z1 - z0)))
        if not fine:
            return (stops[min(n - 1, int(t * n))], False)
        x = t * (n - 1)
        lo = int(x)
        hi = min(n - 1, lo + 1)
        return (stops[hi] if (_hash(*p, 13) % 100) / 100.0 < x - lo else stops[lo], False)
    part.paint(f)


def mottle(part, col, scale, threshold, seed, fine, keep=(), glow=False, only=None):
    """Soft patches of `col` (value noise above `threshold`), fine build only."""
    if not fine:
        return

    def f(p, cc, g):
        if g or cc in keep or (only is not None and not only(p, cc)):
            return None
        if _fbm(p[0], p[1], p[2], scale, seed) > threshold:
            return (col, glow)
        return None
    part.paint(f)


def sparkle(part, cols, every, seed, fine, keep=(), only=None):
    """Glowing points scattered over a part's surface: one voxel in `every`."""
    if not fine:
        return
    vox = part.v
    for p in list(vox):
        cc, g = vox[p]
        if g or cc in keep or (only is not None and not only(p, cc)):
            continue
        x, y, z = p
        if all(n in vox for n in ((x + 1, y, z), (x - 1, y, z), (x, y + 1, z), (x, y - 1, z), (x, y, z + 1))):
            continue
        h = _hash(x, y, z, seed) % every
        if h < len(cols):
            vox[p] = (cols[h], True)


def rim(part, col, fine, below=None, keep=()):
    """Darken the voxels on a part's lower outline (a soft contact shadow),
    fine build only."""
    if not fine:
        return
    vox = part.v
    for p in list(vox):
        cc, g = vox[p]
        if g or cc in keep or (below is not None and p[2] > below):
            continue
        x, y, z = p
        if (x, y, z - 1) not in vox:
            vox[p] = (_shade(cc, col), False)


# ------------------------------------------------------------ anatomy

def front_at(part, x, z, behind=None):
    """The front-most voxel of `part` in column (x, z), optionally only at
    or behind y = `behind`."""
    ys = [p[1] for p in part.v if p[0] == x and p[2] == z and (behind is None or p[1] >= behind)]
    return (x, min(ys), z) if ys else None


def proud_eyes(c, head, centres, rx, rz, iris, ring=INK, pupil=INK, lid=None, glow=True, shine=WHITE,
               behind=None, slit=False, iris2=None):
    """Big eyes that stand one voxel proud of the face, in their own `blink`
    part: the face under each eye turns `lid` colour, so a blink shows a
    closed lid. `centres` are (x, z) of the right eye's centre; the left
    mirrors it. An outline ring (open at the top), a pupil (round or `slit`)
    and a shine in the top outer corner."""
    eyes = c.part('eyes', 'blink', head.pivot)
    lid = lid if lid is not None else _shade(head.v[next(iter(head.v))][0], 0.8)
    for ex, ez in centres:
        for sx in (1, -1):
            cx = ex if sx > 0 else -ex
            for x in range(math.floor(cx - rx) - 1, math.ceil(cx + rx) + 1):
                for z in range(math.floor(ez - rz) - 1, math.ceil(ez + rz) + 1):
                    dx, dz = (x + .5 - cx) / rx, (z + .5 - ez) / rz
                    d2 = dx * dx + dz * dz
                    if d2 > 1.0:
                        continue
                    f = front_at(head, x, z, behind)
                    if not f:
                        continue
                    head.put(f, lid)
                    out = d2 > 0.6 and dz < 0.3
                    if slit:
                        pup = abs(dx) < 0.2 and abs(dz) < 0.8
                    else:
                        pup = dx * dx + (dz + 0.1) ** 2 < 0.2
                    shn = 0.2 < dz < 0.75 and -0.65 < dx * sx < -0.15
                    if shn:
                        col, g = shine, True
                    elif out:
                        col, g = ring, False
                    elif pup:
                        col, g = pupil, False
                    else:
                        col, g = (iris2 if iris2 is not None and dz < -0.1 else iris), glow
                    eyes.put((f[0], f[1] - 1, f[2]), col, g)
    return eyes


def limb(part, a, b, r0, r1, col, n=None, glow=False):
    """A tapered tube from a (radius r0) to b (radius r1)."""
    L = math.dist(a, b)
    n = n or max(3, int(L * 1.5) + 2)
    for i in range(n):
        s = i / (n - 1)
        p = tuple(a[j] + (b[j] - a[j]) * s for j in range(3))
        r = r0 + (r1 - r0) * s
        part.ell(p, (r, r, r), col, glow)


def leg(c, name, hip, foot, r0, r1, col, paw=None, paw_r=None, claw=None, claws=3):
    """One walking leg in its own part (rig.LEG_NAMES), hinged at the hip:
    a tapered tube to the foot, a paw that sits on the ground and claws
    poking out of its front."""
    lp = c.part(name, name, hip)
    limb(lp, hip, foot, r0, r1, col)
    if paw is not None:
        pr = paw_r or (r1 * 1.15, r1 * 1.4, r1 * 0.8)
        lp.ell((foot[0], foot[1] - pr[1] * 0.25, pr[2]), pr, paw)
    if claw is not None:
        pr = paw_r or (r1 * 1.15, r1 * 1.4, r1 * 0.8)
        fy = foot[1] - pr[1] * 0.25 - pr[1] + 1
        for i in range(claws):
            x = foot[0] + (i - (claws - 1) / 2) * pr[0] * 0.65
            lp.put((math.floor(x), math.floor(fy), 0), claw)
            lp.put((math.floor(x), math.floor(fy), 1), claw)
    # nothing below the ground
    for p in [p for p in lp.v if p[2] < 0]:
        del lp.v[p]
    return lp


def four_legs(c, k, front_y, back_y, x, hip_z, r0, r1, col, col_back=None, paw=None, claw=None, foot_dy=0.15,
              paw_r=None, splay=0.0):
    """legFL/FR/BL/BR. Hips at (+-x, front_y | back_y, hip_z), in k units."""
    out = []
    for ly, fb, cc in ((front_y, 'F', col), (back_y, 'B', col_back or col)):
        for sx, s in ((1, 'R'), (-1, 'L')):
            hip = (sx * x * k - (0.5 if sx < 0 else -0.5) * 0, ly * k, hip_z * k)
            foot = (sx * (x + splay) * k, (ly - foot_dy) * k, 0.45 * r1 * k + 0.5)
            out.append(leg(c, 'leg' + fb + s, hip, foot, r0 * k, r1 * k, cc, paw=paw,
                           paw_r=tuple(v * k for v in paw_r) if paw_r else None, claw=claw))
    return out


def mirror_put(part, p, col, glow=False):
    """Put a voxel at p and its mirror across x = 0 (x -> -x - 1)."""
    part.put(p, col, glow)
    part.put((-p[0] - 1, p[1], p[2]), col, glow)


def wing(c, k, root, span, rise, chord, cols, tip, edge=None, thick=2, membrane=False, ribs=None,
         sweep=0.6, glow_tip=True, feather_rows=3):
    """A raised wing pair, wingR (+x) and wingL (mirror), hinged at the
    shoulder `root` (x, y, z in k units, right side). Feathered (rows of
    toothed feathers, colours shoulder to tip) or a bat-like `membrane`
    between `ribs`."""
    rx, ry, rz = root
    L = max(4, round(span * k))
    parts = []
    for sx, name in ((1, 'wingR'), (-1, 'wingL')):
        w = c.part(name, name, (sx * rx * k, ry * k, rz * k))
        for i in range(L):
            t = i / max(1, L - 1)
            x = round(rx * k) + i
            top = rz * k + rise * k * math.sin(t * math.pi * 0.75) + 0.25 * k * t
            back = ry * k + sweep * k * t * t * 2.2
            if membrane:
                ln = chord * k * (1 - 0.55 * t) * (0.75 + 0.25 * math.cos(t * math.pi * 6))
            else:
                ln = chord * k * (0.55 + 0.6 * math.sin(min(1.0, t * 1.1) * math.pi * 0.85))
                if i % 3 == 0:
                    ln -= 0.25 * k
            ln = max(2, round(ln))
            for dz in range(ln):
                d = dz / max(1, ln - 1)
                if membrane:
                    col, g = (cols[0] if d < 0.4 else (cols[1] if d < 0.8 else cols[2])), False
                    if ribs is not None and dz == 0:
                        col, g = ribs, False
                else:
                    band_i = min(len(cols) - 1, int((t * 0.6 + d * 0.6) * len(cols)))
                    col, g = cols[band_i], False
                    if t > 0.86 or (d > 0.85 and t > 0.45):
                        col, g = tip, glow_tip
                if edge is not None and dz == 0:
                    col, g = edge, True
                xx = x if sx > 0 else -x - 1
                for dy in range(thick):
                    w.put((xx, round(back + dz * 0.35) + dy, round(top - dz)), col, g)
        parts.append(w)
    return parts


# ------------------------------------------------------------ the orbit

def solid_voxels(c, skip=('orbit',)):
    out = {}
    for p in c.parts:
        if p.name not in skip:
            out.update(p.v)
    return out


def orbit_ring(c, k, items, margin=0.9):
    """Everything that circles the creature, as one `orbit` part turning about
    the body's centre. `items` are (angle in degrees, height in k units,
    radius in k units, draw), where draw(part, centre, r) paints one piece.

    Each piece sits just outside everything else at its height (plus
    `margin` k for the head turning and wings flapping), so it never passes
    through the body as it turns. If that would push it past the sweep limit
    (0.8x the height), the piece moves to the nearest height where it fits;
    a piece that fits nowhere is an error, not a silent overlap."""
    taken = solid_voxels(c)
    xs = [p[0] + .5 for p in taken]
    ys = [p[1] + .5 for p in taken]
    top = max(p[2] for p in taken) + 1
    mx, my = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    limit = ORBIT_SWEEP * top
    orbit = c.part('orbit', 'orbit', (mx, my, 0))
    reach_at = {}
    for (x, y, z) in taken:
        d = math.hypot(x + .5 - mx, y + .5 - my) + 0.71
        if d > reach_at.get(z, 0):
            reach_at[z] = d

    def reach(z0, z1):
        return max([reach_at.get(z, 0.0) for z in range(math.floor(z0), math.ceil(z1) + 1)] or [0.0])

    placed = []
    for ang, zk, rk, draw in items:
        r = rk * k
        want = zk * k
        best = None
        for dz in sorted(range(-round(top), round(top) + 1), key=abs):
            z = want + dz
            if z - r < 0.4 * r or z + r > top - 1:
                continue
            dist = reach(z - r - 1, z + r + 1) + r + margin * k
            if dist + r <= limit:
                best = (z, dist)
                break
        if best is None:
            raise ValueError(f'{c.species}: orbit piece at {ang} deg, r {rk} does not fit within {ORBIT_SWEEP}x height')
        z, dist = best
        a = math.radians(ang)
        centre = (mx + math.cos(a) * dist, my + math.sin(a) * dist, z)
        draw(orbit, centre, r)
        placed.append(centre)
    for p in [p for p in orbit.v if p in taken]:
        del orbit.v[p]
    return orbit


def sweep_ratio(c):
    """The orbit's sweep radius over the creature's height (<= 0.8)."""
    orbit = next((p for p in c.parts if p.name == 'orbit'), None)
    if orbit is None or not orbit.v:
        return 0.0
    allv = solid_voxels(c, skip=())
    top = max(p[2] for p in allv) + 1
    mx, my = orbit.pivot[0], orbit.pivot[1]
    far = max(math.hypot(x + .5 - mx, y + .5 - my) + 0.71 for (x, y, z) in orbit.v)
    return far / top


# ------------------------------------------------------------ orbit pieces

def ball(col, col2=None, glow=False, glow2=None, bands=False, cap=False, speck=None, seed=1, fine=True):
    """A small planet or orb: one colour, with optional swirl bands, a light
    cap on top or specks."""
    def draw(part, centre, r):
        cx, cy, cz = centre
        for p in _ball_pts(centre, r):
            col_, g = col, glow
            dz = (p[2] + .5 - cz) / max(r, 1)
            if col2 is not None:
                if bands and math.sin(dz * 6.5 + (p[0] + .5 - cx) * 0.4) > 0.4:
                    col_, g = col2, (glow if glow2 is None else glow2)
                elif cap and dz > 0.35:
                    col_, g = col2, (glow if glow2 is None else glow2)
            if speck is not None and fine and _hash(*p, seed) % 6 == 0:
                col_ = speck
            part.put(p, col_, g)
    return draw


def star4(col, col2, glow=True):
    """A four-point star."""
    def draw(part, centre, r):
        bx, by, bz = (math.floor(v) for v in centre)
        L = max(2, round(r))
        part.put((bx, by, bz), col, glow)
        for j in range(1, L + 1):
            cc = col2 if j > L // 2 else col
            for q in ((bx + j, by, bz), (bx - j, by, bz), (bx, by, bz + j), (bx, by, bz - j)):
                part.put(q, cc, glow)
    return draw


def flake(col, col2, glow=True):
    """A six-armed snowflake standing upright, facing out."""
    def draw(part, centre, r):
        cx, cy, cz = centre
        ang_out = math.atan2(cy - part.pivot[1], cx - part.pivot[0])
        ux, uy = -math.sin(ang_out), math.cos(ang_out)  # along the ring
        L = max(3, round(r))
        for arm in range(6):
            a = arm * math.pi / 3
            for j in range(L + 1):
                h = j * math.cos(a)
                v = j * math.sin(a)
                q = (math.floor(cx + ux * h), math.floor(cy + uy * h), math.floor(cz + v))
                part.put(q, col2 if j == L else col, glow)
                if j == round(L * 0.6):
                    for side in (-1, 1):
                        a2 = a + side * 0.9
                        for m in range(1, max(2, L // 3) + 1):
                            hh, vv = h + m * math.cos(a2), v + m * math.sin(a2)
                            part.put((math.floor(cx + ux * hh), math.floor(cy + uy * hh), math.floor(cz + vv)), col, glow)
    return draw


def shard(col, col2, glow=True, tall=1.6):
    """A double-ended crystal shard, upright."""
    def draw(part, centre, r):
        cx, cy, cz = centre
        H = r * tall
        for z in range(math.floor(cz - H), math.ceil(cz + H) + 1):
            t = 1 - abs(z + .5 - cz) / H
            if t <= 0:
                continue
            rr = max(0.5, r * 0.55 * t)
            for x in range(math.floor(cx - rr), math.ceil(cx + rr) + 1):
                for y in range(math.floor(cy - rr), math.ceil(cy + rr) + 1):
                    if abs(x + .5 - cx) + abs(y + .5 - cy) <= rr:
                        part.put((x, y, z), col2 if (z + .5 > cz + H * 0.45 or x + .5 > cx) else col, glow)
    return draw


def cloud(col, col2, fine=True):
    """A puffy cloud of three balls, flat underneath."""
    def draw(part, centre, r):
        cx, cy, cz = centre
        ang_out = math.atan2(cy - part.pivot[1], cx - part.pivot[0])
        ux, uy = -math.sin(ang_out), math.cos(ang_out)
        for off, rr, up in ((-0.7, 0.62, 0.0), (0.0, 0.85, 0.2), (0.75, 0.6, 0.0)):
            c_ = (cx + ux * off * r, cy + uy * off * r, cz + up * r)
            for p in _ball_pts(c_, rr * r):
                if p[2] + .5 < cz - 0.35 * r:
                    continue
                shade = p[2] + .5 < cz - 0.05 * r
                part.put(p, col2 if shade else col)
    return draw


# ------------------------------------------------------------ tidying

LIMBS = ('leg', 'wing', 'fin')


def tidy(c, depth=2):
    """Drop the voxels of legs, wings and fins that sit deep inside the body
    (more than `depth` voxels in): nobody sees them, they only cost
    triangles. The layer next to the body's skin stays, so a swinging limb
    never opens a gap at the hip."""
    body = next((p for p in c.parts if p.name == 'body'), None)
    if body is None:
        return
    bv = body.v
    r = range(-depth, depth + 1)
    for part in c.parts:
        if not part.name.startswith(LIMBS):
            continue
        for p in [p for p in part.v if p in bv]:
            x, y, z = p
            if all((x + dx, y + dy, z + dz) in bv for dx in r for dy in r for dz in r
                   if abs(dx) + abs(dy) + abs(dz) == depth):
                del part.v[p]
