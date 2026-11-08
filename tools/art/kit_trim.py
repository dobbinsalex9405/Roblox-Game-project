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
    # inside corner), in the colour most of them have; its twin the same way
    seen = set()
    for (x, y, z) in sorted(part.v):
        for d in STEPS:
            w = (x + d[0], y + d[1], z + d[2])
            if w in taken or w in seen:
                continue
            seen.add(w)
            near = [part.v[n] for n in ((w[0] + e[0], w[1] + e[1], w[2] + e[2]) for e in STEPS) if n in part.v]
            if len(near) < 2 or any(g for _, g in near):
                continue
            col = max(set(near), key=near.count)
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

    total = sum(_boxes(p.v) for p in c.parts)
    names = a.get('parts') or [p.name for p in c.parts]
    while total > budget:
        best = None
        for want in names:
            for part in [p for p in c.parts if p.name in (want, want + 'L', want + 'R')]:
                if part.name in FACE or not part.v:
                    continue
                for kind, v, new in _edits(c, part, mirror):
                    parts = {p.name: p for p in c.parts}
                    after = total - sum(_boxes(parts[n].v) for n in new) + sum(_boxes(nv) for nv in new.values())
                    if after < total:
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


ACCESSORIES = {'trim_boxes': trim_boxes, 'pad_legs': pad_legs, 'jaw_band': jaw_band}
