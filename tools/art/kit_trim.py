"""Trim: brings a creature's in-game boxes (VoxelArt, the stand-in drawn
before its mesh loads) down to its tier's box budget with the smallest edits
there are, where fit_boxes would redraw whole parts on a coarser grid and
lose the antennae or legs that make a small creature itself.

    {"kind": "trim_boxes", "color": "#000000", "parts": ["leg3", "leg1"]}

Put it last. It only touches the coarse in-game build: the Blender meshes,
and so the reviewed models and their thumbnails, are never changed. Each
step makes one mirrored edit (a voxel and its twin on the other side): first
filling a notch, so the outline only gains a corner, then taking away a
voxel. It tries the named parts in order ("leg3" means leg3L and leg3R), never
a face part or a glowing voxel, and takes the first edit that saves a box,
until the creature is inside its budget ("budget", or its tier's in
tools/art/to_config.py BOX_BUDGET). Each edit is printed when the art builds.
"""
import sys

FACE = ('head', 'eyes', 'ears', 'crest', 'mane', 'horn', 'antlers', 'beard', 'antennae', 'antenna')
STEPS = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))


def _boxes(v):
    from voxkit import greedy_boxes, merged_boxes
    return min(len(greedy_boxes(v)), len(merged_boxes(v))) if v else 0


def _own(c):
    # as creatures.build_all does next: a voxel belongs to one part only (legs
    # and wings give way to the body), so the boxes counted are the ones drawn
    import rig
    for i, part in enumerate(c.parts):
        for later in c.parts[i + 1:]:
            for v in set(part.v) & set(later.v):
                if part.name == 'body' and (later.name in rig.LEG_NAMES or later.name in ('wingL', 'wingR')):
                    del later.v[v]
                else:
                    del part.v[v]


def _drawn(c):
    """The boxes the game will draw for `c` as it stands: build_all next
    gives each voxel to one part, then carves walking legs out of the body
    (rig.split_legs), which can split a box in two."""
    import copy

    import rig
    from voxkit import Part
    d = copy.deepcopy(c)
    _own(d)
    d.parts = [p for p in d.parts if p.v]
    rig.split_legs(d, Part)
    return sum(_boxes(p.v) for p in d.parts), _legs(d)


def _legs(c):
    """The walking legs as the game rigs them, by name."""
    import rig
    return tuple(sorted(p.name for p in c.parts if p.name in rig.LEG_NAMES))


def _try(c, new, legs):
    """The boxes drawn with some parts' voxels swapped for `new` ({name:
    voxels}); None when the walking legs would change (a foot cut off the
    body they are carved from, two legs run together)."""
    old = {p.name: p.v for p in c.parts if p.name in new}
    for p in c.parts:
        if p.name in new:
            p.v = new[p.name]
    try:
        n, after = _drawn(c)
        return n if after == legs else None
    finally:
        for p in c.parts:
            if p.name in old:
                p.v = old[p.name]


def _twin_name(name):
    if name[-1:] in ('L', 'R') and len(name) > 1:
        return name[:-1] + ('R' if name[-1] == 'L' else 'L')
    return name


def _edits(c, part, mirror):
    """Mirrored edits on `part`, fills first: [(kind, {part name: new voxels})]."""
    parts = {p.name: p for p in c.parts}
    taken = {v for p in c.parts for v in p.v}
    twin = parts.get(_twin_name(part.name), part)
    out = []
    # fills: an empty cell with at least two neighbours in this part (an
    # inside corner), all one colour, in that colour; its twin the same way
    seen = set()
    for (x, y, z) in sorted(part.v):
        for d in STEPS:
            w = (x + d[0], y + d[1], z + d[2])
            if w in taken or w in seen:
                continue
            seen.add(w)
            near = [part.v[n] for n in ((w[0] + e[0], w[1] + e[1], w[2] + e[2]) for e in STEPS) if n in part.v]
            # every neighbour one colour, so a fill never covers a pattern
            if len(near) < 2 or len(set(near)) > 1 or near[0][1]:
                continue
            col = near[0]
            new = {part.name: dict(part.v), twin.name: dict(twin.v)}
            new[part.name][w] = col
            if mirror(w) not in taken:
                new[twin.name][mirror(w)] = col
            out.append(('fill', w, new))
    # cuts: a voxel and its twin, never a glowing one, nor the last voxel a
    # leg stands on
    import rig
    floor = min(v[2] for v in part.v)
    for v in sorted(part.v):
        if part.v[v][1]:
            continue
        if part.name in rig.LEG_NAMES and v[2] == floor and sum(1 for u in part.v if u[2] == floor) < 2:
            continue
        new = {part.name: dict(part.v), twin.name: dict(twin.v)}
        new[part.name].pop(v)
        new[twin.name].pop(mirror(v), None)
        out.append(('cut', v, new))
    return out


def trim_boxes(c, H, col=None, col2=None, a=None):
    if getattr(c, 'fine', False):
        return
    a = a or {}
    budget = a.get('budget')
    if not budget:
        sys.path.insert(0, __import__('os').path.dirname(__file__))
        from to_config import BOX_BUDGET
        budget = BOX_BUDGET.get(c.rarity)
    if not budget:
        return
    _own(c)
    xs = [v[0] for p in c.parts for v in p.v]
    s = min(xs) + max(xs)

    def mirror(v):
        return (s - v[0], v[1], v[2])

    total, legs = _drawn(c)
    names = a.get('parts') or [p.name for p in c.parts]
    while total > budget:
        best = None
        for want in names:
            for part in [p for p in c.parts if p.name in (want, want + 'L', want + 'R')]:
                if part.name in FACE or not part.v:
                    continue
                for kind, v, new in _edits(c, part, mirror):
                    # a quick look at the parts it changes, then the whole
                    # creature as the game draws it
                    parts = {p.name: p for p in c.parts}
                    if sum(_boxes(nv) for nv in new.values()) >= sum(_boxes(parts[n].v) for n in new):
                        continue
                    after = _try(c, new, legs)
                    if after is not None and after < total:
                        best = (kind, part.name, v, new, after)
                        break
                if best:
                    break
            if best:
                break
        if not best:
            print(f'trim_boxes: {c.species} stays at {total} boxes (budget {budget})', file=sys.stderr)
            return
        kind, name, v, new, total = best
        for p in c.parts:
            if p.name in new:
                p.v = new[p.name]
        print(f'trim_boxes: {c.species}: {kind} {name} {v} and its twin, now {total} boxes', file=sys.stderr)


def _darkness(col):
    r, g, b = col
    return 0.299 * r + 0.587 * g + 0.114 * b


def pad_legs(c, H, col=None, col2=None, a=None):
    """In-game stand-in only: legs that end in a ripple ring on the water (a
    water strider's) are drawn as one flat disc in the ripple colour with the
    leg a straight bar to it (out from the hip at its height, then down onto
    the disc's middle), where the fine build's stepped strut and ring cost eight
    boxes a leg. "parts": the legs, e.g. ["leg2", "leg3"]."""
    if getattr(c, 'fine', False):
        return
    names = (a or {}).get('parts') or []
    for p in c.parts:
        if not p.v or not any(p.name in (n, n + 'L', n + 'R') for n in names):
            continue
        floor = min(v[2] for v in p.v)
        low = [v for v in p.v if v[2] == floor]
        count = {}
        for v in low:
            count[p.v[v]] = count.get(p.v[v], 0) + 1
        ring = max(count, key=count.get)
        rest = [p.v[v] for v in p.v if p.v[v] != ring]
        if count[ring] < 6 or not rest:
            continue
        leg = max(set(rest), key=rest.count)
        xs, ys = [v[0] for v in low], [v[1] for v in low]
        cx, cy = (min(xs) + max(xs)) // 2, (min(ys) + max(ys)) // 2
        strut = [v for v in p.v if v[2] > floor]
        px, py, pz = p.pivot
        # the hip: the strut voxel nearest the joint, the higher one on a tie
        hip = min(strut or low, key=lambda v: (abs(v[0] - px) + abs(v[1] - py) + abs(v[2] - pz), -v[2]))
        new = {(x, y, floor): ring for x in range(min(xs), max(xs) + 1) for y in range(min(ys), max(ys) + 1)}
        # out from the hip at its height, then down onto the disc: the knee
        # stays high, as a strider's does
        top = max(hip[2], floor + 1)
        x, y = hip[0], hip[1]
        while x != cx:
            new[(x, y, top)] = leg
            x += 1 if cx > x else -1
        while y != cy:
            new[(x, y, top)] = leg
            y += 1 if cy > y else -1
        for z in range(floor + 1, top + 1):
            new[(x, y, z)] = leg
        p.v = new


def jaw_band(c, H, col=None, col2=None, a=None):
    """In-game stand-in only: the head's lowest layer, a checkered jaw and
    beard in the fine build, drawn as one band in its darkest colour (eyes and
    glowing voxels kept), so the head is a few boxes, not a dozen."""
    if getattr(c, 'fine', False):
        return
    head = next((p for p in c.parts if p.name == (a or {}).get('part', 'head')), None)
    if not head or not head.v:
        return
    floor = min(v[2] for v in head.v)
    band = [v for v in head.v if v[2] == floor and not head.v[v][1]]
    if not band:
        return
    dark = min({head.v[v][0] for v in band}, key=_darkness)
    for v in band:
        head.v[v] = (dark, False)


def _unify(v, near=32):
    """Colours within `near` on every channel of a commoner one take it."""
    count = {}
    for val in v.values():
        count[val] = count.get(val, 0) + 1
    keep, to = [], {}
    for val in sorted(count, key=lambda k: (-count[k], k)):
        same = next((k for k in keep if k[1] == val[1] and max(abs(a - b) for a, b in zip(k[0], val[0])) <= near), None)
        if same:
            to[val] = same
        else:
            keep.append(val)
            to[val] = val
    return {k: to[val] for k, val in v.items()}


def _close(v, need, taken):
    """Fills every empty cell with at least `need` neighbours in the part (an
    inside corner or a notch), in the colour most of them have, until none is
    left. Only where every neighbour is one colour (a fill never covers a
    spot or a stripe), never a cell another part has, nor next to a glow."""
    v = dict(v)
    while True:
        add = {}
        cells = {(x + d[0], y + d[1], z + d[2]) for (x, y, z) in v for d in STEPS} - set(v) - taken
        for w in sorted(cells):
            near = [v[n] for n in ((w[0] + d[0], w[1] + d[1], w[2] + d[2]) for d in STEPS) if n in v]
            if len(near) >= need and len(set(near)) == 1 and not near[0][1]:
                add[w] = near[0]
        if not add:
            return v
        v.update(add)


def _thin(c, parts, budget, legs):
    """Recolours a dark pattern's voxels (darker than the part's own colour)
    to that colour, a mirrored pair at a time, the pair that saves most boxes
    first, until the creature is inside its budget or half the pattern is
    gone. True when it got inside."""
    xs = [v[0] for p in c.parts for v in p.v]
    s = min(xs) + max(xs)
    for p in parts:
        count = {}
        for val in p.v.values():
            count[val] = count.get(val, 0) + 1
        base = max(count, key=lambda k: (count[k], k))
        dark = [v for v, val in p.v.items() if not val[1] and _darkness(val[0]) < _darkness(base[0]) - 40]
        while sum(1 for v in dark if p.v[v] == base) < len(dark) // 2:
            total = _drawn(c)[0]
            if total <= budget:
                return True
            best = None
            for v in sorted(dark):
                if p.v[v] == base:
                    continue
                new = dict(p.v)
                new[v] = base
                tw = (s - v[0], v[1], v[2])
                if tw in new and tw in dark:
                    new[tw] = base
                after = _try(c, {p.name: new}, legs)
                if after is not None and after < total and (best is None or after < best[0]):
                    best = (after, v, new)
            if not best:
                break
            p.v = best[2]
            print(f'plain_boxes: {c.species}: thinned the pattern on {p.name} at {best[1]}, now {best[0]} boxes',
                  file=sys.stderr)
    return _drawn(c)[0] <= budget


def plain_boxes(c, H, col=None, col2=None, a=None):
    """In-game stand-in only: brings a creature with a busy coat or a ragged
    outline inside its tier's box budget, a step at a time and only as far as
    it needs, on the named parts in order ("parts", e.g. ["body", "head"]):
      1. near-identical colours (a fluff a shade off its coat) become one,
      2. notches with four neighbours or more are filled,
         (with "thin": true, a dense dark pattern, rosettes, loses up to half
         its voxels, the ones that cost most boxes first, in mirrored pairs),
      3. trim_boxes' mirrored one-voxel edits on the same parts,
      4. notches with three neighbours are filled, then step 3 again.
    Patterns that differ more than a shade (spots, drips, a sash) are kept."""
    if getattr(c, 'fine', False):
        return
    a = a or {}
    budget = a.get('budget')
    if not budget:
        sys.path.insert(0, __import__('os').path.dirname(__file__))
        from to_config import BOX_BUDGET
        budget = BOX_BUDGET.get(c.rarity)
    if not budget:
        return
    _own(c)
    names = a.get('parts') or ['body']
    parts = [p for n in names for p in c.parts if p.name in (n, n + 'L', n + 'R') and p.v]

    legs = _drawn(c)[1]

    def total():
        return _drawn(c)[0]

    def step(name, fn):
        for p in parts:
            if total() <= budget:
                return True
            new = fn(p)
            after = _try(c, {p.name: new}, legs)
            if after is not None and after < total():
                p.v = new
                print(f'plain_boxes: {c.species}: {name} {p.name}, now {total()} boxes', file=sys.stderr)
        return total() <= budget

    def others(p):
        return {v for q in c.parts if q is not p for v in q.v}

    if step('one colour for near shades on', lambda p: _unify(p.v)):
        return
    if step('notches filled on', lambda p: _close(p.v, 4, others(p))):
        return
    if a.get('thin') and _thin(c, parts, budget, legs):
        return
    trim_boxes(c, H, a={'budget': budget, 'parts': names})
    if total() <= budget:
        return
    if step('corners filled on', lambda p: _close(p.v, 3, others(p))):
        return
    trim_boxes(c, H, a={'budget': budget, 'parts': names})


def kitten_face(c, H, col=None, col2=None, a=None):
    """In-game stand-in only: a small cat's face that reads at a glance.
    At this size the coarse build's eye row can run into one dark band
    (a spot or a dark voxel between the eyes, read as sunglasses), and its
    ears into one ridge of 3-4 spikes (read as a flame). So:
      - every head voxel between the two eyes, on the eyes' row, and any
        darker one touching an eye, takes the head's own colour, so the eyes
        stand apart and no stripe runs into one (an eye patch);
      - the ears become two, one on each top corner of the head: a nub one
        voxel high, or with "ears": "step" a two-wide base and a tip on its
        outer column."""
    if getattr(c, 'fine', False):
        return
    parts = {p.name: p for p in c.parts}
    head, eyes, ears = parts.get('head'), parts.get('eyes'), parts.get('ears')
    if not head or not head.v:
        return
    count = {}
    for val in head.v.values():
        count[val] = count.get(val, 0) + 1
    base = max(count, key=lambda k: (count[k], k))
    if eyes and len(eyes.v) >= 2:
        z = min(v[2] for v in eyes.v)
        ex = sorted({v[0] for v in eyes.v if v[2] == z})
        lo, hi = ex[0], ex[-1]
        for v in list(head.v):
            if v[2] == z and lo < v[0] < hi and v not in eyes.v:
                head.v[v] = base
        # nothing darker than the head touches an eye, even corner to corner:
        # a stripe or spot running into an eye reads as an eye patch
        ring = {(x + dx, y + dy, zz + dz) for (x, y, zz) in eyes.v
                for dx in (-1, 0, 1) for dy in (-1, 0, 1) for dz in (-1, 0, 1)}
        for v in ring & set(head.v):
            if head.v[v] != base and _darkness(head.v[v][0]) < _darkness(base[0]) and not head.v[v][1]:
                head.v[v] = base
    if ears and ears.v:
        hx = [v[0] for v in head.v]
        left, right = min(hx), max(hx)
        ys = [v[1] for v in ears.v]
        zs = [v[2] for v in ears.v]
        y = max(set(ys), key=lambda k: (ys.count(k), -k))
        tone = max(set(ears.v.values()), key=lambda k: (list(ears.v.values()).count(k), k))
        top = max(v[2] for v in head.v if v[0] in (left, right))
        z0 = max(min(zs), top + 1)
        new = {}
        if (a or {}).get('ears') == 'step':
            # a two-wide base on each top corner and a tip on its outer column
            for x, inner in ((left, left + 1), (right, right - 1)):
                new[(x, y, z0)] = tone
                new[(inner, y, z0)] = tone
                new[(x, y, z0 + 1)] = tone
        else:
            # a nub on each top corner, one voxel high and two deep, so the
            # top centre stays flat on a head only four voxels wide
            for x in (left, right):
                new[(x, y, z0)] = tone
                new[(x, y + 1, z0)] = tone
        ears.v = new


ACCESSORIES = {'trim_boxes': trim_boxes, 'pad_legs': pad_legs, 'jaw_band': jaw_band, 'plain_boxes': plain_boxes,
               'kitten_face': kitten_face}
