"""Voxel kit for Hatchery Heist art: build creatures as voxel grids split into
animated parts, merge them into boxes for the game, and (with Blender's bpy)
render them. Plain Python; bpy is only needed by render.py."""
import math


def hexc(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


class Part:
    """One animated piece of a creature (body, head, tail...). Voxels are
    {(x, y, z): (rgb, glow)}; x right, y back (front is -y), z up."""

    def __init__(self, name, anim='static', pivot=(0, 0, 0)):
        self.name, self.anim, self.pivot, self.v = name, anim, pivot, {}

    def put(self, p, col, glow=False):
        self.v[(int(p[0]), int(p[1]), int(p[2]))] = (col, glow)

    def ell(self, c, r, col, glow=False, cond=None):
        cx, cy, cz = c
        rx, ry, rz = (max(r[0], 0.5), max(r[1], 0.5), max(r[2], 0.5))
        for x in range(math.floor(cx - rx), math.ceil(cx + rx) + 1):
            for y in range(math.floor(cy - ry), math.ceil(cy + ry) + 1):
                for z in range(math.floor(cz - rz), math.ceil(cz + rz) + 1):
                    d = ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 + ((z + .5 - cz) / rz) ** 2
                    if d <= 1.0 and (cond is None or cond(x, y, z)):
                        self.put((x, y, z), col, glow)

    def box(self, a, b, col, glow=False):
        for x in range(int(a[0]), int(b[0]) + 1):
            for y in range(int(a[1]), int(b[1]) + 1):
                for z in range(int(a[2]), int(b[2]) + 1):
                    self.put((x, y, z), col, glow)

    def paint(self, fn):
        for p, (col, glow) in list(self.v.items()):
            r = fn(p, col, glow)
            if r:
                self.v[p] = r

    def front(self, x, z):
        ys = [p[1] for p in self.v if p[0] == x and p[2] == z]
        return (x, min(ys), z) if ys else None

    def top(self, x, y):
        zs = [p[2] for p in self.v if p[0] == x and p[1] == y]
        return (x, y, max(zs)) if zs else None


class Creature:
    def __init__(self, species, rarity):
        self.species, self.rarity, self.parts = species, rarity, []

    def part(self, name, anim='static', pivot=(0, 0, 0)):
        for p in self.parts:
            if p.name == name:
                return p
        p = Part(name, anim, pivot)
        self.parts.append(p)
        return p

    def all_voxels(self):
        out = {}
        for p in self.parts:
            out.update(p.v)
        return out

    def bounds(self):
        vs = list(self.all_voxels())
        lo = [min(v[i] for v in vs) for i in range(3)]
        hi = [max(v[i] for v in vs) + 1 for i in range(3)]
        return lo, hi


def greedy_boxes(voxels):
    """Merge voxels of the same colour and glow into boxes. Returns
    [(x, y, z, sx, sy, sz, key)] with key = (rgb, glow)."""
    left = dict(voxels)
    boxes = []
    for p in sorted(voxels, key=lambda q: (q[2], q[1], q[0])):
        if p not in left:
            continue
        key = left[p]
        x, y, z = p
        sx = 1
        while (x + sx, y, z) in left and left[(x + sx, y, z)] == key:
            sx += 1
        sy = 1
        while all((x + i, y + sy, z) in left and left[(x + i, y + sy, z)] == key for i in range(sx)):
            sy += 1
        sz = 1
        while all((x + i, y + j, z + sz) in left and left[(x + i, y + j, z + sz)] == key
                  for i in range(sx) for j in range(sy)):
            sz += 1
        for i in range(sx):
            for j in range(sy):
                for k in range(sz):
                    del left[(x + i, y + j, z + k)]
        boxes.append((x, y, z, sx, sy, sz, key))
    return boxes


def hidden(voxels):
    """Voxels with all six neighbours filled: never seen, so the game skips
    them when that does not split a box (they merge into interior boxes)."""
    out = set()
    for (x, y, z) in voxels:
        if all(n in voxels for n in ((x + 1, y, z), (x - 1, y, z), (x, y + 1, z), (x, y - 1, z),
                                     (x, y, z + 1), (x, y, z - 1))):
            out.add((x, y, z))
    return out


def merged_boxes(voxels):
    """Fewer boxes than greedy_boxes for the same look: a box may run through
    voxels nobody can see (all six neighbours filled) whatever their colour.
    Every visible voxel ends up in exactly one box, of its own colour, so no
    two boxes ever share a face on the outside (coplanar faces flicker and
    catch shadow speckles). Returns [(x, y, z, sx, sy, sz, key)]."""
    hide = hidden(voxels)
    covered = set()

    def ok(p, key):
        if p in hide:
            return True
        return p in voxels and voxels[p] == key and p not in covered

    boxes = []
    for p in sorted(voxels, key=lambda q: (q[2], q[1], q[0])):
        if p in hide or p in covered:
            continue
        key = voxels[p]
        x, y, z = p
        sx = 1
        while ok((x + sx, y, z), key):
            sx += 1
        sy = 1
        while all(ok((x + i, y + sy, z), key) for i in range(sx)):
            sy += 1
        sz = 1
        while all(ok((x + i, y + j, z + sz), key) for i in range(sx) for j in range(sy)):
            sz += 1
        for i in range(sx):
            for j in range(sy):
                for k in range(sz):
                    covered.add((x + i, y + j, z + k))
        boxes.append((x, y, z, sx, sy, sz, key))
    return boxes
