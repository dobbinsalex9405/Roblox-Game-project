"""Walking legs: after a creature is built, each leg that stands on the
ground is lifted out of the body into its own part, so the game can swing
it from the hip. Body plans keep drawing legs as part of the body; this
finds them afterwards, so every plan, roster entry and legend gets legs
with no changes of its own.

Names (and each part's anim, the same string), seen from the creature,
which faces -y, with L at negative x like the wings:
- four legs: legFL, legFR, legBL, legBR
- two legs (birds, upright creatures): legL, legR
- more than four (bugs, crabs): leg1L, leg2L, leg3L... front to back, and
  the same on the right
A leg's pivot is its hip: the middle of its top, where it meets the body."""
from collections import deque

LEG_NAMES = ('legFL', 'legFR', 'legBL', 'legBR', 'legL', 'legR') + tuple(f'leg{i}{s}' for i in range(1, 7) for s in 'LR')
MAX_HIP = 0.45  # legs end at most this far up the body's height


def _slab_pieces(vox, z):
    """Pieces of the body at height z, touching edge or corner, in plan view."""
    cells = {(x, y) for (x, y, zz) in vox if zz == z}
    pieces = 0
    while cells:
        pieces += 1
        todo = [cells.pop()]
        while todo:
            x, y = todo.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (x + dx, y + dy)
                    if n in cells:
                        cells.remove(n)
                        todo.append(n)
    return pieces


def _plan_pieces(cells):
    """Pieces of a set of (x, y) cells, touching edge or corner."""
    cells, out = set(cells), []
    while cells:
        start = cells.pop()
        piece, todo = {start}, [start]
        while todo:
            x, y = todo.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (x + dx, y + dy)
                    if n in cells:
                        cells.remove(n)
                        piece.add(n)
                        todo.append(n)
        out.append(piece)
    return out


def _pieces(vox):
    """Pieces of a set of voxels touching face to face (not edge or corner,
    so two legs that only graze each other stay two legs)."""
    left, out = set(vox), []
    while left:
        start = left.pop()
        piece, todo = {start}, deque([start])
        while todo:
            x, y, z = todo.popleft()
            for n in ((x + 1, y, z), (x - 1, y, z), (x, y + 1, z), (x, y - 1, z), (x, y, z + 1), (x, y, z - 1)):
                if n in left:
                    left.remove(n)
                    piece.add(n)
                    todo.append(n)
        out.append(piece)
    return out


def split_legs(c, Part):
    """Moves the body's legs into leg parts. Returns the leg part names."""
    body = next((p for p in c.parts if p.name == 'body'), None)
    if body is None or not body.v:
        return []
    if gait_hint(c) == 'slither':
        return []  # arms or a foot it glides on, not legs (a starfish, a slug)
    zs = [p[2] for p in body.v]
    z0, top = min(zs), max(zs)
    if z0 > 0 or _slab_pieces(body.v, z0) < 2:
        return []  # nothing stands on separate legs (a blob, a serpent)
    hip = z0
    limit = z0 + max(1, int((top - z0 + 1) * MAX_HIP))
    while hip + 1 < limit and _slab_pieces(body.v, hip + 1) >= 2:
        hip += 1
    # Feet: the separate pieces of the bottom slab, or of the slab above it
    # when that one has more (a cricket's hind legs dip a voxel lower than
    # its other four). Every low voxel goes to the foot below it, or the
    # nearest one, so legs that touch higher up (a front and a back leg side
    # by side) still come apart.
    base = z0
    if hip > z0 and _slab_pieces(body.v, z0 + 1) > _slab_pieces(body.v, z0):
        base = z0 + 1
    feet = _plan_pieces({(x, y) for (x, y, z) in body.v if z == base})
    # a belly on (or just off) the ground spans the middle: not a leg (a
    # seal's, or a bug's resting on its feet)
    side_feet = [f for f in feet if not (min(x for x, _ in f) < 0 <= max(x for x, _ in f))]
    if base > z0 or len(side_feet) >= 2:
        feet = side_feet
    if base > z0:  # the lower tips belong to the feet above them
        tips = _plan_pieces({(x, y) for (x, y, z) in body.v if z == z0})
        feet = [f for f in feet if not any(f & t for t in tips)] + [
            set().union(t, *[f for f in feet if f & t]) for t in tips]
    # Toes are one foot: pieces close together that also join within a short
    # ankle above the ground (webbed feet). Separate thin legs that stand
    # close (a spider's, an ant's) only meet at the body, so they stay apart.
    ankle = {}
    for i, piece in enumerate(_pieces({p for p in body.v if p[2] <= min(base + 2, hip)})):
        for (x, y, z) in piece:
            ankle.setdefault((x, y), i)
    merged = True
    while merged:
        merged = False
        for i in range(len(feet)):
            for j in range(i + 1, len(feet)):
                same = {ankle.get(cell) for cell in feet[i]} & {ankle.get(cell) for cell in feet[j]} - {None}
                if same and min((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 for a in feet[i] for b in feet[j]) <= 6.25:
                    feet[i] = feet[i] | feet.pop(j)
                    merged = True
                    break
            if merged:
                break
    # A bird's toes lying flat in front of its leg (nothing above them)
    # belong to that leg: a goose's webbed foot, not a leg of its own.
    # Only winged creatures: a lobster's or cricket's short legs stay legs.
    winged = any(p.name in ('wingL', 'wingR') for p in c.parts)
    above = {(x, y) for (x, y, z) in body.v if z == base + 1}
    flat = [f for f in feet if not (f & above)]
    standing = [f for f in feet if f & above]
    if winged and flat and len(standing) >= 2:
        for f in flat:
            fx = sum(x for x, _ in f) / len(f)
            side = [g for g in standing if (sum(x for x, _ in g) / len(g) < -0.5) == (fx < -0.5)] or standing
            near = min(side, key=lambda g: min((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 for a in f for b in g))
            near |= f
        feet = standing
    if len(feet) < 2:
        return []
    owner = {}
    for i, f in enumerate(feet):
        for cell in f:
            owner[cell] = i
    legs = [set() for _ in feet]
    for (x, y, z) in body.v:
        if z > hip:
            continue
        i = owner.get((x, y))
        if i is None:
            i = min(range(len(feet)), key=lambda j: min((x - a) ** 2 + (y - b) ** 2 for a, b in feet[j]))
            near = min((x - a) ** 2 + (y - b) ** 2 for a, b in feet[i])
            if near > 4:  # well clear of every foot: belly, not leg
                continue
        legs[i].add((x, y, z))
    legs = [leg for leg in legs if leg]
    if len(legs) < 2:
        return []
    ys = [p[1] for p in body.v]
    mid_y = (min(ys) + max(ys)) / 2

    def centre(piece):
        n = len(piece)
        return (sum(p[0] for p in piece) / n, sum(p[1] for p in piece) / n)

    groups = {}
    if len(legs) == 4:
        for piece in legs:
            x, y = centre(piece)
            name = 'leg' + ('F' if y < mid_y else 'B') + ('L' if x < 0 else 'R')
            groups.setdefault(name, []).append(piece)
        if len(groups) != 4:  # not one per corner: fall back to sides
            groups = {}
    if not groups:
        sides = {}
        for piece in legs:
            x, _ = centre(piece)
            sides.setdefault('L' if x < 0 else 'R', []).append(piece)
        if len(sides) < 2:
            return []
        for side, pieces in sides.items():
            if len(legs) <= 3 or len(pieces) == 1:  # two legs, or a side with one: the whole side
                groups['leg' + side] = pieces
            else:
                for i, piece in enumerate(sorted(pieces, key=lambda q: centre(q)[1])[:6]):
                    groups[f'leg{i + 1}{side}'] = [piece]
    left = sum(1 for name in groups if name.endswith('L'))
    if left * 2 != len(groups):
        # The meshes (the finer build) are symmetric, so unpaired legs there
        # are a bug. The coarse in-game boxes can lose a thin leg to rounding:
        # there each side swings as one leg.
        if getattr(c, 'fine', False):
            raise ValueError(f'{c.species}: legs {sorted(groups)} are not in left/right pairs')
        sides = {}
        for name, pieces in groups.items():
            sides.setdefault('leg' + name[-1], []).extend(pieces)
        groups = sides
    names = []
    for name in sorted(groups):
        vox = set().union(*groups[name])
        n = len(vox)
        px = sum(p[0] for p in vox) / n + 0.5
        py = sum(p[1] for p in vox) / n + 0.5
        leg = Part(name, name, (px, py, hip + 1))
        for p in vox:
            leg.v[p] = body.v.pop(p)
        c.parts.insert(c.parts.index(body) + 1, leg)
        names.append(name)
    return names


GAITS = ('trot', 'waddle', 'hop', 'scuttle', 'slither', 'hover')
# How a creature moves when its legs alone don't say: hand-made creatures by
# species, roster creatures by plan and kind (variants.py sets c.gait_hint).
SPECIES_GAIT = {
    'Phoenix': 'hover',
    'Frog': 'hop', 'Toad': 'hop', 'Snail': 'slither', 'Ladybug': 'scuttle', 'Turtle': 'scuttle',
    'Axolotl': 'scuttle', 'NebulaSerpent': 'hover',
}
KIND_GAIT = {
    'frog': 'hop', 'snail': 'slither', 'ladybug': 'scuttle', 'axolotl': 'scuttle', 'turtle': 'scuttle',
    'bee': 'hover', 'butterfly': 'hover', 'beetle': 'scuttle', 'caterpillar': 'slither', 'crab': 'scuttle',
    'gecko': 'trot', 'chameleon': 'trot', 'iguana': 'trot', 'bearded': 'trot',
    # kit_pond critters and shore animals
    'dragonfly': 'hover', 'firefly': 'hover', 'ant': 'scuttle', 'grasshopper': 'scuttle', 'spider': 'scuttle',
    'mantis': 'scuttle', 'pillbug': 'scuttle', 'worm': 'slither', 'slug': 'slither', 'starfish': 'slither',
    'urchin': 'scuttle', 'hermit': 'scuttle', 'lobster': 'scuttle', 'newt': 'trot', 'platypus': 'trot',
    'seal': 'waddle', 'walrus': 'waddle',
}


def gait_hint(c):
    """The gait named for this species or its kind, if any."""
    return SPECIES_GAIT.get(c.species) or getattr(c, 'gait_hint', None)


def gait(c):
    """trot, waddle, hop, scuttle, slither or hover."""
    g = gait_hint(c)
    if g:
        return g
    legs = [p for p in c.parts if p.name.startswith('leg')]
    return {4: 'trot', 2: 'waddle'}.get(len(legs), 'scuttle')
