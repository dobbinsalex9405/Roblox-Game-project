"""Twelve Epics from the master sheet (Nov 7): Kappa, Star Jelly, Crystal
Golem, Gem Drake, Baby Kraken, Sea Serpent, Sand Serpent, Star Whale Calf,
Hippocampus, Cloud Serpent, Hydra Hatchling and Abyss Jelly.

Most start from a kit_myth plan and are finished here with the sheet's
feature (the kappa's water dish, the gem drake's gems, the calf's star
spout), added as kinds with kit_myth.add_kind. The jellyfish and the
octopus are new plans. Every name here starts with `em_` (the kit prefix),
so no other batch's kinds or plans can clash with them.

Epics may glow. The in-game box art (the coarse build, c.fine False) keeps
to the Epic box budget (120), so small details are drawn in the finer
Blender build only. Same art frame as the other kits: x right, y back
(front is -y), z up, feet at z = 0; k = H / 10."""
import math

from voxkit import hexc
import kit_myth as km
from kit_myth import mix, dark, light, mx, curve, sweep, top_of, eye_pair, cheeks, core

P = hexc
INK, WHITE = P('#1B1B2F'), P('#FFFFFF')
GEMS = (P('#FF2E63'), P('#2E8BFF'), P('#22D67A'), P('#FFB81A'), P('#B04BFF'))


def _fine(c):
    return getattr(c, 'fine', False)


def _part(c, name):
    return next((p for p in c.parts if p.name == name), None)


def _bounds(part):
    xs, ys, zs = zip(*part.v)
    return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def _surface(part):
    """Voxels of `part` with an open face (not buried)."""
    v = part.v
    out = []
    for (x, y, z) in v:
        for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
            if (x + d[0], y + d[1], z + d[2]) not in v:
                out.append((x, y, z))
                break
    return out


def _star(part, x, y, z, s, col, glow=True, plane='xz'):
    """A small five-point-ish star (a plus with a filled centre) of size s."""
    s = max(1, int(s))
    for i in range(-s, s + 1):
        for j in range(-s, s + 1):
            if abs(i) + abs(j) <= s and (i == 0 or j == 0 or abs(i) + abs(j) <= max(1, s - 1)):
                if plane == 'xz':
                    part.put((x + i, y, z + j), col, glow)
                elif plane == 'xy':
                    part.put((x + i, y + j, z), col, glow)
                else:
                    part.put((x, y + i, z + j), col, glow)


def _flatten(c, pairs, parts=None):
    """The in-game boxes only (c.fine False): paint shade colours back to the
    colour they shade (belly plates, speckles, bands), so the box art keeps
    to the Epic box budget. pairs: [(shade, base)]."""
    if _fine(c):
        return
    table = dict(pairs)
    for part in c.parts:
        if parts is None or part.name in parts:
            part.paint(lambda p, cc, g: (table[cc], False) if not g and cc in table else None)


def _coarsen(c, keep=('eyes',), frac=0.375):
    """The in-game boxes only (c.fine False): redraw every part on a grid of
    2 x 2 x 2 voxel cells (a cell is filled when at least `frac` of it is,
    in its most common colour), so a big Epic's stand-in box art keeps to
    the tier's box budget. Parts named in `keep` (the eyes) stay as drawn."""
    if _fine(c):
        return c
    for part in c.parts:
        if part.name in keep or not part.v:
            continue
        _coarsen_part(part, frac)
    return c


def _coarsen_part(part, frac=0.375, cell=2):
    from collections import Counter
    if True:
        cells = {}
        for (x, y, z), v in part.v.items():
            cells.setdefault((x // cell, y // cell, z // cell), []).append(v)
        out = {}
        for (cx, cy, cz), vs in cells.items():
            if len(vs) < frac * cell ** 3:
                continue
            col, glow = Counter(vs).most_common(1)[0][0]
            if any(g for _, g in vs):
                col, glow = Counter(v for v in vs if v[1]).most_common(1)[0][0]
            for dx in range(cell):
                for dy in range(cell):
                    for dz in range(cell):
                        out[(cell * cx + dx, cell * cy + dy, cell * cz + dz)] = (col, glow)
        part.v = out


def _boxes(part):
    from voxkit import greedy_boxes, merged_boxes
    return min(len(greedy_boxes(part.v)), len(merged_boxes(part.v))) if part.v else 0


FIXED = ('head', 'eyes', 'ears', 'gems', 'heart', 'spout', 'dish')


def _fit_budget(c, budget=120):
    """The in-game boxes only: while the creature is over the Epic box
    budget, redraw its heaviest part (never the face: head, eyes, ears, nor
    the legs or the small glowing features) on a 2-voxel grid, and when
    every part has had that, on a 3-voxel grid. The fine Blender build is
    never touched."""
    if _fine(c):
        return c
    import rig

    def own():
        # as creatures.build_all does next: a voxel belongs to one part only
        # (legs and wings give way to the body), so count what will be drawn
        for i, part in enumerate(c.parts):
            for later in c.parts[i + 1:]:
                for v in set(part.v) & set(later.v):
                    if part.name == 'body' and (later.name in rig.LEG_NAMES or later.name in ('wingL', 'wingR')):
                        del later.v[v]
                    else:
                        del part.v[v]
        return sum(_boxes(p) for p in c.parts)

    done = {}
    while own() > budget:
        # each part at most twice: a 2-voxel grid, then a 3-voxel grid
        cands = [p for p in c.parts if p.name not in FIXED and done.get(p.name, 0) < 2 and p.name not in rig.LEG_NAMES]
        if not cands:
            break
        part = max(cands, key=lambda p: (-done.get(p.name, 0), _boxes(p)))
        done[part.name] = done.get(part.name, 0) + 1
        before = dict(part.v)
        _coarsen_part(part, cell=1 + done[part.name])
        if not part.v:
            part.v = before
    return c


def _mirror_leg(c, src='legR', dst='legL'):
    """Redraws leg `dst` as the exact mirror of `src` (voxel x -> -1 - x,
    hinge x -> -x), so a pair of legs match to the voxel."""
    a = _part(c, src)
    if a is None:
        return
    import rig
    px, py, pz = a.pivot
    b = rig.leg_part(c, dst[-1], 0, 1, (-px, py, pz))
    b.pivot = (-px, py, pz)
    b.v = {(-1 - x, y, z): v for (x, y, z), v in a.v.items()}


def _with(plan, kind, cols, opts, c, H):
    o = dict(opts)
    o['kind'] = kind
    return km.BUILDERS_BY_PLAN[plan](c, H, cols, o)


# ------------------------------------------------------------------ Kappa

def kappa(c, k, cols, opts):
    """A river imp: a green frog-ish child on two webbed feet, a turtle shell
    on its back, a yellow beak, and the dish of water on its head that holds
    its strength (glowing blue water in a pale rim, a fringe of hair)."""
    col = cols['col']
    belly = cols.get('belly', light(col, 0.5))
    shell = cols.get('accent', P('#6B4F2A'))
    beak = cols.get('snout', P('#FFC93C'))
    water = cols.get('glow', P('#2EC8FF'))
    iris = cols.get('eye', INK)
    fine = _fine(c)
    body = c.part('body')
    top = 1.5 * k
    import rig
    x = 0.85 * k
    lp = rig.leg_part(c, 'R', 0, 1, (x, 0.2 * k, top + 1))
    for z in range(0, int(top) + 1):
        lp.ell((x, 0.2 * k, z + .5), (0.55 * k, 0.55 * k, 0.5), dark(col, 0.1))
    # wide webbed feet, toes forward
    lp.ell((x, -0.35 * k, 0.5), (0.75 * k, 0.95 * k, 0.5), dark(col, 0.2))
    _mirror_leg(c)
    bz = top + 1.5 * k
    body.ell((0, 0, bz), (1.5 * k, 1.25 * k, 1.65 * k), col)
    body.paint(lambda p, cc, g: (belly, False) if p[1] < -0.55 * k and abs(p[0] + .5) < 0.95 * k and cc == col else None)
    if fine:  # belly plates, like a turtle's plastron
        body.paint(lambda p, cc, g: (dark(belly, 0.12), False) if cc == belly and (p[2] % max(2, round(0.6 * k)) == 0) else None)
    # the shell: a domed oval on the back, plates outlined in a darker brown
    sh = c.part('shell', 'static')
    sh.ell((0, 1.05 * k, bz + 0.1 * k), (1.65 * k, 0.75 * k, 1.75 * k), shell, cond=lambda x, y, z: y >= round(0.6 * k))
    rim = light(shell, 0.3)
    sh.paint(lambda p, cc, g: (rim, False) if abs((p[0] + .5)) > 1.35 * k or abs(p[2] - bz) > 1.45 * k else None)
    if fine:
        seam = dark(shell, 0.35)
        sh.paint(lambda p, cc, g: (seam, False) if cc == shell and (
            abs(p[0] + .5) < 0.6 or abs(p[0] + .5 - 0.75 * k) < 0.6 or abs(p[0] + .5 + 0.75 * k) < 0.6
            or abs(p[2] - (bz + 0.55 * k)) < 0.6 or abs(p[2] - (bz - 0.45 * k)) < 0.6) else None)
    # arms with webbed hands
    for side in (1, -1):
        pts = curve((side * 1.35 * k, -0.2 * k, bz + 0.8 * k), (side * 1.85 * k, -0.6 * k, bz - 0.9 * k), 8,
                    (side * 0.4 * k, 0, 0))
        for i, (x, y, z) in enumerate(pts):
            r = 0.45 * k if i < 7 else 0.6 * k
            body.ell((x - (0.5 if side < 0 else 0), y, z), (r, r, r), col if i < 7 else dark(col, 0.2))
    # head: round, a short yellow beak
    hz = bz + 1.65 * k + 1.2 * k
    head = c.part('head', 'head', (0, 0, bz + 1.4 * k))
    head.ell((0, -0.1 * k, hz), (1.45 * k, 1.3 * k, 1.25 * k), col)
    head.ell((0, -1.35 * k, hz - 0.45 * k), (0.75 * k, 0.55 * k, 0.4 * k), beak)
    if fine:
        head.ell((0, -1.75 * k, hz - 0.6 * k), (0.45 * k, 0.35 * k, 0.25 * k), beak)
        for x in range(-round(0.55 * k), round(0.55 * k)):
            f = head.front(x, round(hz - 0.5 * k))
            if f and head.v[f][0] == beak:
                head.put(f, dark(beak, 0.35))
    # a flat, light face across the eyes: on a small round head the eyes sit
    # where the front curves away, and the shaded rim round them read as
    # sunglasses; a flat oval plate keeps every voxel round the eyes in one
    # plane and one light green
    face = light(col, 0.15)
    yf = min(p[1] for p in head.v if abs(p[0] + .5) < 1 and abs(p[2] - hz) < 1)
    fw, fh = 1.2 * k, 0.75 * k
    for x in range(-math.ceil(fw), math.ceil(fw)):
        for z in range(round(hz - fh), round(hz + fh) + 1):
            if ((x + .5) / fw) ** 2 + ((z - hz) / fh) ** 2 <= 1.0:
                for y in range(yf, yf + round(0.8 * k)):
                    if (x, y, z) not in head.v or head.v[(x, y, z)][0] == col:
                        head.put((x, y, z), face)
    eye_pair(c, head, max(1, round(0.45 * k)), round(hz - 0.05 * k), max(2, round(0.4 * k)), iris=iris)
    if fine:
        cheeks(head, round(1.05 * k), round(hz - 0.55 * k))
    # the dish: a shallow pale rim on top of the head holding glowing water,
    # with a ragged fringe of hair round it
    dz = round(hz + 1.05 * k)
    dish = c.part('dish', 'glow', (0, -0.1 * k, dz))
    R = 0.95 * k
    rimc = cols.get('horn', P('#EDE6D6'))
    for x in range(-round(R) - 1, round(R) + 1):
        for y in range(-round(R) - 1, round(R) + 1):
            d = math.hypot(x + .5, y + .5 + 0.1 * k)
            if d <= R + 0.5:
                dish.put((x, y, dz), rimc)
                if d > R - 0.8:
                    dish.put((x, y, dz + 1), rimc)
                else:
                    dish.put((x, y, dz + 1), water, True)
    hair = cols.get('wing', dark(col, 0.45))
    for a in range(28 if fine else 12):
        ang = a / (28 if fine else 12) * math.pi * 2
        if math.sin(ang) < -0.35:  # never over the face: the eyes stay clear
            continue
        x = math.floor(math.cos(ang) * (R + 1.0))
        y = math.floor(math.sin(ang) * (R + 1.0) - 0.1 * k)
        drop = 1 + (a % 3 == 0)
        for z in range(dz - drop, dz + 1):
            head.put((x, y, z), hair)
    c.gait_hint = 'waddle'
    return c


# ------------------------------------------------------------- Crystal Golem

def _shard(part, base, d, length, r, col, tip, glow=False, tip_glow=False):
    n = max(3, round(length))
    dx, dy, dz = d
    norm = math.sqrt(dx * dx + dy * dy + dz * dz) or 1
    dx, dy, dz = dx / norm, dy / norm, dz / norm
    pts = []
    for i in range(n + 1):
        s = i / n
        p = (base[0] + dx * length * s, base[1] + dy * length * s, base[2] + dz * length * s)
        rr = max(0.5, r * (1 - s) ** 0.8)
        top = s > 0.6
        part.ell(p, (rr, rr, rr), tip if top else col, tip_glow if top else glow)
        pts.append(p)
    core(part, pts, lambda s: tip if s > 0.6 else col, lambda s: tip_glow if s > 0.6 else glow)


def _facet(part, cx, cy, cz, a, b, h, col, top_taper=0.35, bot_taper=0.25):
    """A chunky cut crystal block: a box a x b (half widths) by h tall from
    cz, with chamfered vertical edges and its top and bottom tapered."""
    for z in range(round(cz), round(cz + h)):
        t = (z - cz) / max(1.0, h)
        sh = 1.0 - top_taper * max(0.0, (t - 0.7) / 0.3) - bot_taper * max(0.0, (0.25 - t) / 0.25)
        aa, bb = a * sh, b * sh
        for x in range(math.floor(cx - aa), math.ceil(cx + aa)):
            for y in range(math.floor(cy - bb), math.ceil(cy + bb)):
                dx, dy = abs(x + .5 - cx) / max(0.5, aa), abs(y + .5 - cy) / max(0.5, bb)
                if dx <= 1 and dy <= 1 and dx + dy <= 1.55:
                    part.put((x, y, z), col)


def crystal_golem(c, k, cols, opts):
    """A chunky golem of blue crystal: cut-crystal blocks for torso, head
    and fists, short faceted legs, crystal clusters bursting from the
    shoulders and back, and a glowing core in the chest."""
    import rig
    col = cols['col']
    pale = cols.get('belly', light(col, 0.4))
    deep = cols.get('accent', dark(col, 0.3))
    glow = cols.get('glow', P('#2EE6FF'))
    tip = cols.get('horn', P('#BFF4FF'))
    iris = cols.get('eye', INK)
    fine = _fine(c)
    body = c.part('body')
    top = 2.1 * k
    for side in ('L', 'R'):
        x = 0.95 * k if side == 'R' else -0.95 * k
        lp = rig.leg_part(c, side, 0, 1, (x, 0.1 * k, top + 1))
        _facet(lp, x, 0.1 * k, 0, 0.7 * k, 0.75 * k, top + 1, deep, top_taper=0.0, bot_taper=0.0)
        _facet(lp, x, -0.05 * k, 0, 0.8 * k, 0.9 * k, max(2, round(0.45 * k)), dark(deep, 0.2), top_taper=0.0, bot_taper=0.0)
    # torso: a cut crystal, broad at the chest
    t0 = top - 0.3 * k
    _facet(body, 0, 0, t0, 1.75 * k, 1.25 * k, 4.1 * k, col, top_taper=0.2, bot_taper=0.35)
    # shoulders and arms: a boulder each side, a crystal forearm and fist
    joints = []
    for sx in (1, -1):
        xs = sx * 2.25 * k
        _facet(body, xs, 0, t0 + 2.6 * k, 0.75 * k, 0.8 * k, 1.5 * k, col)
        _facet(body, sx * 2.35 * k, -0.1 * k, t0 + 0.8 * k, 0.55 * k, 0.6 * k, 1.9 * k, deep, top_taper=0.0)
        _facet(body, sx * 2.4 * k, -0.2 * k, t0 - 0.3 * k, 0.75 * k, 0.75 * k, 1.1 * k, pale, top_taper=0.15, bot_taper=0.3)
        joints += [(xs, -0.8 * k, t0 + 3.3 * k), (sx * 2.35 * k, -0.6 * k, t0 + 1.6 * k)]
    # facets: lighter and darker cuts across the crystal (finer build only)
    if fine:
        body.paint(lambda p, cc, g: (light(cc, 0.3), False) if not g and cc in (col, deep) and (p[0] + p[2] + 2 * p[1]) % 7 == 0 else None)
        body.paint(lambda p, cc, g: (dark(cc, 0.2), False) if not g and cc in (col, deep) and (p[0] - p[2] + p[1]) % 9 == 0 else None)
    # the core: a glowing diamond on the chest
    zc = round(t0 + 2.5 * k)
    ys = [p[1] for p in body.v if abs(p[0] + .5) < 1 and p[2] == zc]
    yf = min(ys) - 1
    r = max(2, round(0.75 * k))
    for dx in range(-r, r):
        for dz in range(-r, r + 1):
            if abs(dx + .5) + abs(dz) <= r:
                body.put((dx, yf, zc + dz), glow if abs(dx + .5) + abs(dz) < r - 0.5 else light(glow, 0.5), True)
    # head: a small cut gem jutting forward between the shoulders
    hz0 = t0 + 3.8 * k
    head = c.part('head', 'head', (0, -0.3 * k, hz0))
    _facet(head, 0, -0.45 * k, hz0, 0.95 * k, 0.85 * k, 2.0 * k, pale, top_taper=0.45, bot_taper=0.1)
    head.paint(lambda p, cc, g: (deep, False) if p[2] == round(hz0 + 1.35 * k) and p[1] < -0.6 * k else None)  # brow
    eye_pair(c, head, max(1, round(0.25 * k)), round(hz0 + 0.6 * k), max(2, round(0.3 * k)), iris=glow, glow=True, tall=0)
    # crystal clusters on the shoulders and back
    cl = c.part('crystals', 'static')
    shards = [((0.5, 0.0, 1.0), (2.2, 0.0, 3.9), 1.6, 0.45), ((0.2, 0.5, 1.0), (1.7, 0.4, 3.8), 1.2, 0.38),
              ((0.0, 0.8, 1.0), (0.6, 1.0, 3.3), 1.4, 0.42)]
    if fine:
        shards += [((0.8, 0.2, 0.7), (2.6, 0.3, 3.6), 0.9, 0.3), ((0.1, 1.0, 0.5), (0.9, 1.1, 2.2), 0.9, 0.3)]
    for d, (bx, by, bz), length, rr in shards:
        for side in (1, -1):
            _shard(cl, (side * bx * k, by * k, t0 + bz * k), (d[0] * side, d[1], d[2]), length * k, rr * k, P('#7FD0FF'), tip,
                   tip_glow=True)
    c.joints = joints
    c.gait_hint = 'waddle'
    return c


# ---------------------------------------------------------------- Gem Drake

def gem_drake(c, k, cols, opts):
    """A small drake studded with gems: kit_myth's drake in slate violet,
    a row of big glowing gems down the spine, gems on the brow and the
    wing tips, and a gem at the end of the tail."""
    o = dict(opts)
    km.drake(c, k * 10.0, cols, dict(o, kind='drake', wings=o.get('wings', 'bat'), horns=o.get('horns', 'swept')))
    fine = _fine(c)
    col = cols['col']
    belly = cols.get('belly', col)
    _flatten(c, [(dark(belly, 0.12), belly)])
    body = _part(c, 'body')
    head = _part(c, 'head')
    tail = _part(c, 'tail')
    gem = c.part('gems', 'glow')
    s = max(1, round(0.5 * k))

    def stud(part_on, x, y, z, col, size=s):
        # a faceted gem: a small diamond standing proud of the surface
        for dx in range(-size, size):
            for dy in range(-size, size):
                for dz in range(0, size + 1):
                    if abs(dx + .5) + abs(dy + .5) + dz <= size + 0.5:
                        q = (x + dx, y + dy, z + dz)
                        if q not in part_on.v:
                            gem.put(q, col if dz < size else light(col, 0.55), True)

    # spine gems
    (bx0, by0, bz0), (bx1, by1, bz1) = _bounds(body)
    ys = [by0 + (by1 - by0) * t for t in ((0.25, 0.45, 0.65, 0.85) if fine else (0.3, 0.6))]
    for i, y in enumerate(ys):
        z = top_of(body, 0, round(y))
        if z is not None:
            stud(body, 0, round(y), z + 1, GEMS[i % len(GEMS)])
    # flank gems (fine only)
    if fine:
        for i, (fy, fz) in enumerate(((0.35, 0.55), (0.6, 0.45))):
            y = round(by0 + (by1 - by0) * fy)
            z = round(bz0 + (bz1 - bz0) * fz)
            for side in (1, -1):
                xs = [p[0] for p in body.v if p[1] == y and p[2] == z]
                if xs:
                    x = max(xs) + 1 if side > 0 else min(xs) - 1
                    for dz in range(-s + 1, s):
                        for dy in range(-s + 1, s):
                            if abs(dz) + abs(dy) < s:
                                gem.put((x, y + dy, z + dz), GEMS[(i + 2) % len(GEMS)], True)
    # crown gem: on top of the head, between the horns
    if head:
        (hx0, hy0, hz0), (hx1, hy1, hz1) = _bounds(head)
        yc = round(hy0 + (hy1 - hy0) * 0.45)
        z = top_of(head, 0, yc)
        if z is not None:
            stud(head, 0, yc, z + 1, GEMS[0])
    # tail-tip gem
    if tail:
        tip = max(tail.v, key=lambda p: p[1])
        for dx in range(-s, s):
            for dz in range(-s, s + 1):
                for dy in range(0, s + 1):
                    if abs(dx + .5) + abs(dz) + dy <= s + 0.5:
                        tail.put((dx, tip[1] + 1 + dy, tip[2] + dz), GEMS[1], True)
    c.gait_hint = 'trot'
    return c


# --------------------------------------------------------------- Serpents

def sea_serpent(c, k, cols, opts):
    """A teal sea serpent: kit_myth's wyrm with fin frills down the back and
    fanned fins behind the head, edged in glowing aqua."""
    o = dict(opts, kind='wyrm', frills=False)
    km.serpent(c, k * 10.0, cols, o)
    fine = _fine(c)
    _flatten(c, [(dark(cols['col'], 0.18), cols['col'])])
    fin = cols.get('accent', P('#0E6E8A'))
    glow = cols.get('glow', P('#22D3EE'))
    head = _part(c, 'head')
    sp = _part(c, 'spines')
    if sp:  # the spine row becomes a continuous sail-like frill
        frill = {}
        for (x, y, z), (cc, g) in sp.v.items():
            frill[(x, y)] = max(frill.get((x, y), z), z)
        h = max(2, round(0.7 * k))
        for (x, y), z in frill.items():
            for i in range(h):
                sp.put((x, y, z - h + 1 + i), glow if i == h - 1 else fin, i == h - 1)
            if fine:
                sp.put((x, y + 1, z - 1), fin)
    # fin ears: fanned fins on each side of the head
    if head:
        (hx0, hy0, hz0), (hx1, hy1, hz1) = _bounds(head)
        ears = c.part('ears', 'ears', ((hx0 + hx1) / 2, (hy0 + hy1) / 2, hz1))
        n = round(1.5 * k)
        for side in (1, -1):
            xb = hx1 + 1 if side > 0 else hx0 - 1
            yb = round(hy0 + (hy1 - hy0) * 0.55)
            zb = round(hz0 + (hz1 - hz0) * 0.55)
            for i in range(n):
                for j in range(-i // 2, i // 2 + 1):
                    x = xb + side * i
                    y = yb + i // 2
                    z = zb + j + i // 3
                    last = i == n - 1 or abs(j) == i // 2
                    ears.put((x, y, z), glow if last else fin, last)
    c.gait_hint = 'slither'
    return c


def sand_serpent(c, k, cols, opts):
    """A golden desert serpent: kit_myth's wyrm reared up with a broad cobra
    hood behind its head (copper in front with pale scutes, gold behind
    with a dark diamond chain and two glowing ember eye-spots), and banded
    scales along the coil."""
    o = dict(opts, kind='wyrm', frills=False)
    km.serpent(c, k * 10.0, cols, o)
    fine = _fine(c)
    col = cols['col']
    belly = cols.get('belly', light(col, 0.5))
    accent = cols.get('accent', dark(col, 0.2))
    band = cols.get('horn', dark(col, 0.35))
    glow = cols.get('glow', P('#FF7A10'))
    body = _part(c, 'body')
    tail = _part(c, 'tail')
    _flatten(c, [(dark(col, 0.18), col)])
    for part in (body, tail) if fine else ():
        if part:
            part.paint(lambda p, cc, g: (band, False) if cc == col and (p[1] * 2 + p[2] + abs(p[0])) % max(5, round(1.6 * k)) == 0 else None)
    # the hood: a flat oval behind the neck, widest a little below the head
    hood = c.part('hood', 'static')
    z0, z1 = 3.3 * k, 6.5 * k
    mark = dark(col, 0.5)
    for z in range(round(z0), round(z1)):
        u = (z - 1.5 * k) / (5.0 * k)
        xn = 0.4 * k * math.sin(u * math.pi)
        yn = -1.4 * k - u * 1.0 * k + math.sin(u * math.pi) * 0.9 * k
        t = (z - z0) / (z1 - z0)
        w = 0.9 * k + 1.25 * k * max(0.0, math.sin(min(1.0, t * 1.15) * math.pi)) ** 0.8
        yb = round(yn + 0.55 * k)
        for x in range(math.floor(xn - w), math.ceil(xn + w)):
            edge = abs(x + .5 - xn) > w - 1.2 or z in (round(z0), round(z1) - 1)
            for dy in range(2):
                front = dy == 0
                if edge:
                    cc = dark(accent, 0.3)
                elif front:
                    cc = belly if abs(x + .5 - xn) < 0.75 * k and fine and z % 2 == 0 else accent
                else:
                    cc = col
                hood.put((x, yb + dy, z), cc)
    # the hood's back: a diamond chain down the middle, two ember eye-spots
    (hx0, hy0, hz0), (hx1, hy1, hz1) = _bounds(hood)
    back = {}
    for (x, y, z) in hood.v:
        back[(x, z)] = max(back.get((x, z), y), y)
    step = max(3, round(0.9 * k))
    for (x, z), y in back.items():
        if abs(x + .5) + abs((z - hz0) % step - step / 2) < 1.3 and hz0 + 1 < z < hz1 - 1:
            hood.put((x, y, z), mark)
    for side in (1, -1):
        ex = round(side * 1.15 * k) - (1 if side < 0 else 0)
        ez = round(hz0 + (hz1 - hz0) * 0.55)
        r = max(1, round(0.42 * k))
        for dx in range(-r, r + 1):
            for dz in range(-r, r + 1):
                d2 = dx * dx + dz * dz
                y = back.get((ex + dx, ez + dz))
                if y is not None and d2 <= r * r + 0.5:
                    hood.put((ex + dx, y + 1, ez + dz), glow if d2 < (r - 0.6) ** 2 + 0.5 else mark, d2 < (r - 0.6) ** 2 + 0.5)
                    if fine:  # seen through the hood too: a soft glow on the front
                        f = min((q[1] for q in hood.v if q[0] == ex + dx and q[2] == ez + dz), default=None)
                        if f is not None and d2 < (r - 0.6) ** 2 + 0.5:
                            hood.put((ex + dx, f, ez + dz), dark(glow, 0.15), True)
    c.gait_hint = 'slither'
    return c


def hydra_hatchling(c, k, cols, opts):
    """A green hydra hatchling: kit_myth's three-headed wyrm, still wearing
    a cap of cracked eggshell on its middle head, with pale spots down its
    back and little horn nubs."""
    km.serpent(c, k * 10.0, cols, dict(opts, kind='wyrm', heads=3, frills=False))
    fine = _fine(c)
    col = cols['col']
    _flatten(c, [(dark(col, 0.18), col)])
    shell, crack = cols.get('horn', P('#FFF6E0')), cols.get('wing', P('#E8D9B0'))
    spot = cols.get('accent', light(col, 0.35))
    body = _part(c, 'body')
    if fine and body:
        body.paint(lambda p, cc, g: (spot, False) if cc == col and p[2] > 1.6 * k and (p[0] * 7 + p[1] * 5 + p[2] * 3) % 23 == 0 else None)
    head = _part(c, 'head')
    if head:
        (hx0, hy0, hz0), (hx1, hy1, hz1) = _bounds(head)
        cx, cy = (hx0 + hx1 + 1) / 2, (hy0 + hy1 + 1) / 2 + 0.2 * k
        cap = c.part('shell', 'static')
        R = 1.05 * k
        zb = hz1 - round(0.35 * k)
        for x in range(math.floor(cx - R) - 1, math.ceil(cx + R) + 1):
            for y in range(math.floor(cy - R) - 1, math.ceil(cy + R) + 1):
                for z in range(zb, zb + round(1.3 * k)):
                    d = ((x + .5 - cx) / R) ** 2 + ((y + .5 - cy) / R) ** 2 + ((z - zb) / (1.25 * k)) ** 2
                    if 0.55 <= d <= 1.0 or (d < 0.55 and z == zb + round(1.3 * k) - 1):
                        # a zig-zag cracked lower edge
                        ang = math.atan2(y + .5 - cy, x + .5 - cx)
                        if z - zb < (1 if math.sin(ang * 5) > 0 else 0) * max(1, round(0.3 * k)):
                            continue
                        cap.put((x, y, z), crack if z - zb <= max(1, round(0.3 * k)) else shell)
    for name in ('headL', 'headR', 'head'):
        h = _part(c, name)
        if not h or not fine:
            continue
        (hx0, hy0, hz0), (hx1, hy1, hz1) = _bounds(h)
        for sx in (0.3, -0.3):
            x = math.floor((hx0 + hx1) / 2 + sx * k)
            y = math.floor((hy0 + hy1) / 2 + 0.3 * k)
            zt = top_of(h, x, y)
            if zt is not None and name != 'head':
                h.put((x, y, zt + 1), cols.get('snout', P('#FFE27A')))
    c.gait_hint = 'slither'
    return c


def cloud_serpent(c, k, cols, opts):
    """A small eastern dragon made of cloud: a long body waving through the
    air in an S, built of soft cloud puffs, a storm-blue mane, gold antlers,
    long whiskers, and lightning flickering in the tuft at its tail."""
    col = cols['col']
    belly = cols.get('belly', dark(col, 0.12))
    mane = cols.get('accent', P('#5B78C8'))
    horn = cols.get('horn', P('#FFC94A'))
    glow = cols.get('glow', P('#FFE14D'))
    iris = cols.get('eye', INK)
    fine = _fine(c)
    body = c.part('body')
    n = 72
    pts = []
    for i in range(n + 1):
        t = i / n
        y = 3.6 * k - t * 5.4 * k
        x = 0.7 * k * math.sin(t * math.pi * 1.5)
        r = (0.34 + 0.6 * min(1.0, t / 0.5) ** 0.7) * k
        if t < 0.72:  # two arching humps, dipping to the ground between them
            z = r + 0.1 * k + 2.0 * k * math.sin(t / 0.72 * math.pi * 2) ** 2
        else:  # the neck rearing up to the head
            u = (t - 0.72) / 0.28
            z = r + 0.1 * k + 4.6 * k * math.sin(u * math.pi / 2)
        pts.append((x, y, z, r))
    cut = round(n * 0.3)
    tail = c.part('tail', 'tail', pts[cut][:3])
    for i, (x, y, z, r) in enumerate(pts):
        (tail if i < cut else body).ell((x, y, z), (r, r, r), col)
    core(body, [q[:3] for q in pts[cut:]], col=col)
    core(tail, [q[:3] for q in pts[:cut + 1]], col=col)
    for part in (body, tail):
        part.paint(lambda p, cc, g: (belly, False) if cc == col and p[2] < _zat(pts, p[1]) - 0.3 * k else None)
    # cloud puffs billowing along the back and sides
    step = 3 if fine else 7
    for i in range(4, n - 6, step):
        x, y, z, r = pts[i]
        part = tail if i < cut else body
        part.ell((x, y, z + r * 0.8), (r * 0.85, r * 0.8, r * 0.7), light(col, 0.5) if fine else col)
        if fine and i % (2 * step) < step:
            for sx in (1, -1):
                part.ell((x + sx * r * 0.85, y + 0.15 * k, z + r * 0.2), (r * 0.6, r * 0.6, r * 0.55), col)
    # a storm-blue mane running down the neck, tufts flicking back
    for i in range(n - 22, n - 1, 2 if fine else 4):
        x, y, z, r = pts[i]
        body.ell((x, y + 0.55 * r, z + r * 0.75), (r * 0.5, r * 0.6, r * 0.65), mane)
        if fine and i % 4 == 0:
            body.put((math.floor(x), math.floor(y + 1.3 * r), math.floor(z + r * 1.3)), glow, True)
    # the tail tuft: cloud with lightning in it
    x, y, z, r = pts[0]
    tail.ell((x, y + 0.6 * k, z + 0.3 * k), (0.8 * k, 0.8 * k, 0.75 * k), light(col, 0.3))
    km.rod(tail, (x - 0.2 * k, y + 0.9 * k, z + 1.0 * k), (x + 0.3 * k, y + 1.2 * k, z + 0.1 * k), 0.5, glow, True)
    km.rod(tail, (x + 0.3 * k, y + 1.2 * k, z + 0.1 * k), (x - 0.1 * k, y + 1.6 * k, z - 0.6 * k), 0.5, glow, True)
    # head: a dragon's head with a long snout, at the top of the neck
    hx, hy, hz = pts[-1][0], pts[-1][1] - 0.7 * k, pts[-1][2] + 0.45 * k
    head = c.part('head', 'head', (hx, hy + 0.7 * k, hz - 0.4 * k))
    head.ell((hx, hy, hz), (1.1 * k, 1.15 * k, 0.95 * k), col)
    head.ell((hx, hy - 1.15 * k, hz - 0.3 * k), (0.75 * k, 0.9 * k, 0.55 * k), col)
    head.paint(lambda p, cc, g: (belly, False) if p[2] < hz - 0.55 * k else None)
    eye_pair(c, head, max(1, round(0.35 * k)), round(hz + 0.05 * k), max(2, round(0.36 * k)), iris=iris)
    for x in (round(hx + 0.3 * k), round(hx - 0.3 * k) - 1):
        f = head.front(x, round(hz - 0.2 * k))
        if f:
            head.put(f, dark(col, 0.5))
    # gold antlers, branched, sweeping back
    ant = c.part('horns', 'static')
    for sx in (1, -1):
        base = (hx + sx * 0.55 * k, hy + 0.4 * k, hz + 0.7 * k)
        tip = (hx + sx * 1.0 * k, hy + 1.5 * k, hz + 2.0 * k)
        km.rod(ant, base, tip, 0.6, horn)
        mid = tuple(base[j] + (tip[j] - base[j]) * 0.55 for j in range(3))
        km.rod(ant, mid, (mid[0] + sx * 0.45 * k, mid[1] - 0.2 * k, mid[2] + 0.6 * k), 0.5, horn)
    # long whiskers from the snout, drooping out to the sides
    wh = c.part('whiskers', 'static')
    for sx in (1, -1):
        a = (hx + sx * 0.5 * k, hy - 1.7 * k, hz - 0.35 * k)
        pts_w = curve(a, (hx + sx * 2.0 * k, hy - 1.3 * k, hz - 1.0 * k), 10, (0, 0, 0.35 * k))
        core(wh, pts_w, lambda s: mane if s < 0.8 else glow, lambda s: s >= 0.8)
    c.gait_hint = 'slither'
    return c


def _zat(pts, y):
    """The body path's height where it passes y (nearest point)."""
    return min(pts, key=lambda q: abs(q[1] - y))[2]


# ------------------------------------------------------------ Star Whale Calf

def star_whale_calf(c, k, cols, opts):
    """A navy whale calf: kit_myth's whale speckled with glowing stars, and a
    star spout rising from its blowhole."""
    km.whale(c, k * 10.0, cols, dict(opts, kind='whale'))
    fine = _fine(c)
    _flatten(c, [(dark(cols.get('belly', P('#F4F7FF')), 0.15), cols.get('belly', P('#F4F7FF')))])
    kk = k * 1.1
    star = cols.get('glow', P('#FFD84A'))
    star2 = cols.get('horn', P('#7FD8FF'))
    body = _part(c, 'body')
    head = _part(c, 'head')
    # speckles on the back and flanks (not the belly)
    for part in (body, head):
        if not part:
            continue
        surf = _surface(part)
        (x0, y0, z0), (x1, y1, z1) = _bounds(part)
        zmid = z0 + (z1 - z0) * 0.45
        n = 0
        sset = set(surf)
        for (x, y, z) in surf:
            h = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
            if z > zmid and h % (29 if fine else 41) == 0:
                cc = star if h % 3 else star2
                part.put((x, y, z), cc, True)
                if fine:  # a little four-point star painted round it
                    for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
                        q = (x + d[0], y + d[1], z + d[2])
                        if q in sset and not part.v[q][1]:
                            part.put(q, cc, True)
                n += 1
    # the fins' and fluke's glowing edges in the pale star blue
    for name in ('finL', 'finR', 'tail'):
        f = _part(c, name)
        if f:
            f.paint(lambda p, cc, g: (star2, True) if g and cc == star else None)
    # the star spout: a short glowing fountain of stars above the blowhole
    if body:
        (x0, y0, z0), (x1, y1, z1) = _bounds(body)
        by = round(y0 + (y1 - y0) * 0.28)
        bz = top_of(body, 0, by)
        if bz is None:
            bz = z1
        sp = c.part('spout', 'glow', (0, by, bz + 1))
        h = round(1.4 * kk)
        for i in range(h):
            sp.put((0, by, bz + 1 + i), star2, True)
            sp.put((-1, by, bz + 1 + i), star2, True)
        top = bz + 1 + h
        _star(sp, 0, by, top + round(0.5 * kk), max(1, round(0.5 * kk)), star, True)
        if fine:
            for side in (1, -1):
                sx = side * round(0.9 * kk)
                for i in range(round(0.8 * kk)):
                    sp.put((sx // 2 * 1 + (side if i > 1 else 0) * i // 2, by, top - i // 2 + 1), star2, True)
                _star(sp, side * round(1.2 * kk), by, top - round(0.2 * kk), max(1, round(0.3 * kk)), star, True)
    c.gait_hint = 'hover'
    return c


# -------------------------------------------------------------- Hippocampus

def _horse_head(c, head, k, hy, hz, col, muzzle, nostril, iris):
    """A horse's head at (0, hy, hz): a skull with a long muzzle running down
    and forward, nostrils at its end, big eyes on the sides of the skull
    and pointed ears standing up (as the Legendary Starlight Pegasus)."""
    head.ell((0, hy + 0.3 * k, hz + 0.25 * k), (1.15 * k, 1.2 * k, 1.1 * k), col)
    for i in range(11):
        s2 = i / 10
        y = hy - 0.4 * k - s2 * 1.9 * k
        z = hz - 0.05 * k - s2 * 0.75 * k
        head.ell((0, y, z), ((0.95 - 0.15 * s2) * k, 0.6 * k, (0.85 - 0.12 * s2) * k), col if s2 < 0.55 else muzzle)
    nz = round(hz - 0.6 * k)
    for x in (round(0.35 * k), -round(0.35 * k) - 1):
        f = head.front(x, nz)
        if f:
            head.put(f, nostril)
    mz = round(hz - 1.15 * k)
    for x in range(-round(0.4 * k), round(0.4 * k)):
        f = head.front(x, mz)
        if f:
            head.put(f, nostril)
    eyes = c.part('eyes', 'blink', head.pivot)
    ey, ez = round(hy - 0.55 * k), round(hz + 0.05 * k)
    es = max(2, round(0.45 * k))
    for side in (1, -1):
        for dy in range(es):
            for dz in range(es + 1):
                y, z = ey + dy, ez + dz
                xs = [q[0] for q in head.v if q[1] == y and q[2] == z]
                if not xs:
                    continue
                x = max(xs) if side > 0 else min(xs)
                del head.v[(x, y, z)]
                shine = dz == es and dy == 0
                eyes.put((x, y, z), WHITE if shine else iris)
    top = max(q[2] for q in head.v)
    ears = c.part('ears', 'ears', (0, hy + 0.3 * k, top))
    for i in range(round(1.4 * k)):
        w = max(1, round(0.5 * k * (1 - i / (1.4 * k))))
        for dx in range(w):
            for dy in range(max(1, w - 1)):
                x = round(0.55 * k) + dx
                ears.put((x, round(hy + 0.3 * k) + dy, top - 1 + i), col if dx else muzzle)
                ears.put((-1 - x, round(hy + 0.3 * k) + dy, top - 1 + i), col if dx else muzzle)


def hippocampus(c, k, cols, opts):
    """The sea horse of myth: a horse's head, neck and chest with two front
    legs pawing the water, and behind them a long fish tail curling up into
    a fan fin. A sea-foam mane down the neck; fins at the elbows."""
    col = cols['col']
    belly = cols.get('belly', light(col, 0.5))
    scale = cols.get('accent', P('#2E7DB0'))
    fin = cols.get('wing', P('#7FE0F0'))
    glow = cols.get('glow', P('#22C8E8'))
    iris = cols.get('eye', INK)
    fine = _fine(c)
    body = c.part('body')
    import rig
    # chest and barrel, raised (it floats); the front legs hang and paddle
    cz = 4.0 * k
    body.ell((0, -0.6 * k, cz), (1.35 * k, 1.6 * k, 1.45 * k), col)
    body.ell((0, 0.9 * k, cz - 0.3 * k), (1.15 * k, 1.4 * k, 1.15 * k), col)
    body.paint(lambda p, cc, g: (belly, False) if p[2] < cz - 0.75 * k and cc == col else None)
    for i, side in enumerate(('L', 'R')):
        x = 0.75 * k if side == 'R' else -0.75 * k
        hip = (x, -1.1 * k, cz - 0.6 * k)
        lp = rig.leg_part(c, side, 0, 1, hip)
        top = cz - 0.6 * k
        foot_z = 1.4 * k
        n = int(top - foot_z)
        for j in range(n + 1):
            z = top - j
            y = -1.1 * k - 0.35 * k * math.sin(j / max(1, n) * math.pi)
            r = 0.5 * k * (1 - 0.25 * j / max(1, n))
            lp.ell((x, y, z), (r, r, 0.6), col)
        # hoof
        lp.ell((x, -1.25 * k, foot_z - 0.2 * k), (0.48 * k, 0.5 * k, 0.35 * k), dark(scale, 0.3))
        # elbow fin
        if fine:
            for a in range(round(0.9 * k)):
                for b in range(a // 2 + 1):
                    xx = math.floor(x + (0.4 * k + a * 0.4) * (1 if side == 'R' else -1))
                    lp.put((xx, round(-0.6 * k + a), round(cz - 1.2 * k - b)), fin if a < round(0.9 * k) - 1 else glow,
                           a == round(0.9 * k) - 1)
    # neck rising forward to the head
    neck = c.part('neck', 'static')
    for i in range(12):
        s = i / 11
        neck.ell((0, -1.3 * k - s * 0.9 * k, cz + 0.6 * k + s * 2.0 * k), (0.8 * k, 0.75 * k, 0.8 * k), col)
    for p in list(neck.v):
        body.v[p] = neck.v.pop(p)
    c.parts.remove(neck)
    hy, hz = -2.5 * k, cz + 3.1 * k
    head = c.part('head', 'head', (0, hy + 0.6 * k, hz - 0.8 * k))
    _horse_head(c, head, k * 0.92, hy, hz, col, light(col, 0.25), dark(scale, 0.2), iris)
    # the fish tail: from the barrel's back, down and round, ending in a fan
    tail = c.part('tail', 'tail', (0, 1.8 * k, cz - 0.4 * k))
    ctrl = [(1.6, cz / k - 0.3), (3.0, cz / k - 1.3), (4.1, 1.9), (5.1, 1.5), (5.8, 2.3), (5.9, 3.4)]
    pts = []
    m = 8
    for j in range(len(ctrl) - 1):
        (ya, za), (yb, zb) = ctrl[j], ctrl[j + 1]
        for i in range(m):
            t = i / m
            # smoothstep blend between the control points
            u = t * t * (3 - 2 * t)
            pts.append((ya + (yb - ya) * t, za + (zb - za) * u))
    pts.append(ctrl[-1])
    n = len(pts) - 1
    sp = []
    for i, (y, z) in enumerate(pts):
        s2 = i / n
        r = max(0.6, (1.1 - 0.75 * s2) * k)
        sp.append((0, y * k, max(z * k, r + 0.5), r))
    sweep(tail, sp, lambda s: col if s < 0.18 else scale)
    if fine:
        tail.paint(lambda p, cc, g: (dark(scale, 0.18), False) if cc == scale and (p[1] + p[2] * 2) % 4 == 0 else None)
        tail.paint(lambda p, cc, g: (light(scale, 0.3), False) if cc == scale and p[1] < 3.6 * k and (p[0], p[1] - 1, p[2]) not in tail.v and p[2] < 2.4 * k else None)
    # the fan fin at the tip: two lobes spreading up and back
    tx, ty, tz, tr = sp[-1]
    fan = round(1.6 * k)
    for i in range(fan):
        w = round(0.3 * k + i * 0.55)
        last = i >= fan - 1
        for x in range(-w, w):
            edge = last or abs(x + .5) > w - 1
            tail.put((x, round(ty + i * 0.5), round(tz + i)), glow if edge else fin, edge)
    # a frilled fin halfway along the tail
    if fine:
        y0, z0 = sp[n // 2][1], sp[n // 2][2]
        for i in range(round(1.2 * k)):
            for j in range(round(0.8 * k) - i // 2):
                tail.put((0, round(y0 - 0.4 * k + i), round(z0 + 0.6 * k + j)), fin if j < round(0.8 * k) - i // 2 - 1 else glow,
                         j == round(0.8 * k) - i // 2 - 1)
                tail.put((-1, round(y0 - 0.4 * k + i), round(z0 + 0.6 * k + j)), fin)
    # sea-foam mane down the neck and over the brow
    mane = c.part('mane', 'static')
    foam, foam2 = cols.get('horn', P('#E9FBFF')), P('#9FEAF6')
    for i in range(10 if fine else 6):
        s = i / (9 if fine else 5)
        y = -1.0 * k - s * 1.6 * k
        z = cz + 1.4 * k + s * 2.3 * k
        r = (0.7 - 0.2 * s) * k
        mane.ell((0, y + 0.75 * k, z + 0.45 * k), (0.55 * k, r, r), foam if i % 2 == 0 else foam2)
        if fine and i % 2 == 0:
            # a curling wave crest blowing back off the mane, a glowing tip
            for j in range(round(0.9 * k)):
                for x in (0, -1):
                    mane.put((x, round(y + 1.2 * k + j * 0.8), round(z + 0.9 * k + j * 0.5)), foam if j < round(0.9 * k) - 1 else glow,
                             j == round(0.9 * k) - 1)
    c.gait_hint = 'hover'
    return c


# ------------------------------------------------------------------ new plans

def em_jelly(c, H, cols, opts):
    """A floating jellyfish: a domed bell with a frilled rim, a glowing
    heart inside, and tendrils trailing below (star-tipped for the star
    jelly). It floats; the tendrils are its tail and sway."""
    k = H / 10.0
    col = cols['col']
    inner = cols.get('belly', light(col, 0.45))
    tend = cols.get('accent', light(col, 0.2))
    glow = cols.get('glow', P('#FFD84A'))
    iris = cols.get('eye', INK)
    fine = _fine(c)
    abyss = opts.get('kind') == 'abyss'
    body = c.part('body')
    bz = 6.2 * k
    R = 2.6 * k
    body.ell((0, 0, bz), (R, R, 2.4 * k), col, cond=lambda x, y, z: z >= round(bz - 0.6 * k))
    # rim frills: scallops hanging from the bell's edge
    n = 16 if fine else 8
    for a in range(n):
        ang = a / n * math.pi * 2
        x, y = math.cos(ang) * (R - 0.4 * k), math.sin(ang) * (R - 0.4 * k)
        body.ell((x, y, bz - 0.9 * k), (0.45 * k, 0.45 * k, 0.45 * k), light(col, 0.15))
        if abyss and (fine or a % 2 == 0):  # a glowing light on every scallop
            body.put((math.floor(x * 1.12), math.floor(y * 1.12), math.floor(bz - 0.9 * k)), glow, True)
    # spots on the bell
    if fine:
        body.paint(lambda p, cc, g: (inner, abyss) if cc == col and p[2] > bz + 0.6 * k and (p[0] * 5 + p[1] * 3) % 11 == 0 else None)
    # face on the front of the bell
    head = c.part('head', 'head', (0, -R * 0.6, bz))
    for p in [p for p in body.v if p[1] < -R * 0.55 and p[2] >= round(bz - 0.6 * k)]:
        head.v[p] = body.v.pop(p)
    eye_pair(c, head, max(1, round(0.55 * k)), round(bz - 0.1 * k), max(2, round(0.42 * k)), iris=iris)
    cheeks(head, round(1.25 * k), round(bz - 0.6 * k))
    # glowing heart: a small star-ish core visible under the bell (the
    # bell is open below)
    heart = c.part('heart', 'glow')
    heart.ell((0, 0.2 * k, bz - 0.4 * k), (0.9 * k, 0.9 * k, 0.6 * k), glow, True)
    # tendrils: 8 wavy tubes hanging below, star tips
    tail = c.part('tail', 'tail', (0, 0, bz - 0.8 * k))
    m = 8 if fine else 5
    for a in range(m):
        ang = (a + 0.5) / m * math.pi * 2
        r0 = (1.6 if a % 2 == 0 else 1.0) * k
        x0, y0 = math.cos(ang) * r0, math.sin(ang) * r0
        L = (4.4 if a % 2 == 0 else 3.6) * k
        steps = max(6, round(L))
        pts = []
        for i in range(steps + 1):
            s = i / steps
            wob = 0.5 * k * math.sin(s * math.pi * 2.2 + a)
            if abyss:  # electric: a sharp zig-zag instead of a soft wave
                wob = 0.55 * k * (1 if (i // max(2, round(0.6 * k))) % 2 else -1) * min(1.0, s * 3)
            pts.append((x0 + math.cos(ang + 1.3) * wob, y0 + math.sin(ang + 1.3) * wob, bz - 0.8 * k - s * L))
        if abyss:
            core(tail, pts, lambda s: glow if s > 0.25 else tend, lambda s: s > 0.25)
        else:
            core(tail, pts, col=tend)
        if fine and not abyss:
            core(tail, [(x + 1, y, z) for (x, y, z) in pts[: steps // 2]], col=tend)
        ex, ey, ez = pts[-1]
        if opts.get('kind') == 'star':
            _star(tail, math.floor(ex), math.floor(ey), math.floor(ez), max(1, round(0.4 * k)), glow, True)
        else:
            tail.put((math.floor(ex), math.floor(ey), math.floor(ez) - 1), glow, True)
    # two frilly oral arms in the middle
    if fine:
        for side in (1, -1):
            pts = [(side * 0.4 * k + 0.4 * k * math.sin(s * 5), 0.3 * k, bz - 1.0 * k - s * 2.6 * k) for s in [i / 12 for i in range(13)]]
            for (x, y, z) in pts:
                tail.ell((x, y, z), (0.5 * k * 0.7, 0.4 * k, 0.5), inner)
    c.gait_hint = 'hover'
    return c


def em_octopus(c, H, cols, opts):
    """A baby kraken: a big round mantle with huge eyes, eight curling
    tentacles spread under it (glowing suckers underneath), floating a
    little off the ground. The two front tentacles are its legs (they
    paddle); the rest curl and sway as the tail."""
    k = H / 10.0
    col = cols['col']
    belly = cols.get('belly', light(col, 0.35))
    glow = cols.get('glow', P('#3FE0FF'))
    iris = cols.get('eye', INK)
    fine = _fine(c)
    body = c.part('body')
    mz = 5.4 * k
    # mantle: a big round head-body, its crown swelling up and back
    body.ell((0, 0.3 * k, mz), (2.25 * k, 2.15 * k, 2.3 * k), col)
    body.ell((0, 0.95 * k, mz + 1.5 * k), (1.75 * k, 1.75 * k, 1.6 * k), col)
    body.paint(lambda p, cc, g: (dark(col, 0.18), False) if cc == col and (p[0] * 3 + p[1] * 7 + p[2] * 5) % 17 == 0 and p[2] > mz else None)
    if fine:  # glowing freckles on the crown
        body.paint(lambda p, cc, g: (glow, True) if cc == col and p[2] > mz + 1.0 * k and (p[0] * 11 + p[1] * 7 + p[2] * 13) % 41 == 0 else None)
    # the face is the mantle's front: big eyes, a little smile
    head = c.part('head', 'head', (0, -1.0 * k, mz))
    for p in [p for p in body.v if p[1] < -1.15 * k and p[2] < mz + 1.2 * k]:
        head.v[p] = body.v.pop(p)
    eye_pair(c, head, max(1, round(0.4 * k)), round(mz - 0.45 * k), max(3, round(0.62 * k)), iris=iris, tall=0)
    for x in range(-max(1, round(0.35 * k)), max(1, round(0.35 * k))):
        f = head.front(x, round(mz - 1.0 * k) - (1 if abs(x + .5) > 0.25 * k else 0))
        if f:
            head.put(f, dark(col, 0.55))
    if fine:
        cheeks(head, round(1.3 * k), round(mz - 0.95 * k))
    # tentacles
    tail = c.part('tail', 'tail', (0, 0.2 * k, mz - 2.0 * k))
    import rig
    for a in range(8):
        ang = (a + 0.5) / 8 * math.pi * 2 - math.pi / 2  # a=... front tentacles near -y
        dx, dy = math.cos(ang), math.sin(ang)
        front = dy < -0.6
        x0, y0, z0 = dx * 1.2 * k, dy * 1.2 * k + 0.1 * k, mz - 1.9 * k
        L = 3.9 * k
        steps = max(10, round(L * 1.1))
        pts = []
        for i in range(steps + 1):
            s = i / steps
            out = 1.2 * k + s * 3.0 * k
            z = z0 - 2.2 * k * math.sin(min(1, s * 1.6) * math.pi / 2) + 1.6 * k * max(0, s - 0.7) / 0.3 * (1 if not front else 0.4)
            curl = 0.8 * k * max(0, s - 0.65) / 0.35
            pts.append((dx * out - dy * curl, dy * out + dx * curl + 0.1 * k, max(z, 0.9 * k), max(0.75, (0.56 - 0.36 * s) * k)))
        if front:
            side = 'R' if dx > 0 else 'L'
            part = rig.leg_part(c, side, 0, 1, (x0, y0, z0))
        else:
            part = tail
        if not fine:  # the in-game boxes: a plain tube (box budget)
            pts = [(x, y, z, 0.5) for (x, y, z, r) in pts]
            core(part, [q[:3] for q in pts], col=col)
            if a % 2 == 0:
                x, y, z, r = pts[len(pts) // 2]
                part.put((math.floor(x), math.floor(y), math.floor(z) - 1), glow, True)
            continue
        sweep(part, pts, lambda s: col)
        # suckers: glowing dots under each tentacle
        for i, (x, y, z, r) in enumerate(pts):
            if i % 2 == 1 and r > 0.7:
                part.put((math.floor(x), math.floor(y), math.floor(z - r)), glow, True)
        part.paint(lambda p, cc, g, part=part: (belly, False) if cc == col and (p[0], p[1], p[2] - 1) not in part.v and p[2] < z0 - 0.8 * k else None)
    _mirror_leg(c)  # the two paddling front tentacles match exactly
    c.gait_hint = 'hover'
    return c


# ------------------------------------------------------------------ register

def _kind(fn, grow=1.0):
    """Registers fn drawn `grow` times bigger than the plan's own size (the
    plans draw some bodies short of the Epic's 3 studs), then fitted to the
    box budget."""
    def build(c, k, cols, opts):
        return _fit_budget(fn(c, k * grow, cols, opts))
    return build


def _plan(fn, grow=1.0):
    def build(c, H, cols, opts):
        return _fit_budget(fn(c, H * grow, cols, opts))
    return build


km.add_kind('upright', 'em_kappa', _kind(kappa, 1.22))
km.add_kind('upright', 'em_crystal', _kind(crystal_golem, 1.22))
km.add_kind('upright', 'em_hippocampus', _kind(hippocampus, 1.18))
km.add_kind('drake', 'em_gem', _kind(gem_drake, 1.04))
km.add_kind('serpent', 'em_sea', _kind(sea_serpent, 1.18))
km.add_kind('serpent', 'em_sand', _kind(sand_serpent, 1.1))
km.add_kind('serpent', 'em_hydra', _kind(hydra_hatchling, 0.98))
km.add_kind('serpent', 'em_cloud', _kind(cloud_serpent, 1.25))
km.add_kind('whale', 'em_starcalf', _kind(star_whale_calf, 1.12))

PLANS = {
    'em_jelly': (set(km.COLOURS), {'kind': {'star', 'abyss'}}),
    'em_octopus': (set(km.COLOURS), {'kind': {'kraken'}}),
}
BUILDERS = {'em_jelly': _plan(em_jelly, 1.18), 'em_octopus': _plan(em_octopus, 1.1)}
