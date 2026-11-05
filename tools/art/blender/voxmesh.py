"""Voxels to a polished voxel mesh, in plain Python (no Blender needed).

Every visible voxel face becomes a "pillow": a flat inner square raised a
little off the face, with four sloped rims running down to the face's edges.
Next to a neighbour on the same plane the two rims make a V-groove, so the
voxel grid reads clearly in any light; on an outside edge the two rims meet
like a bevel. That is the look of the concept renders (each voxel its own
soft-edged cube) at 10 triangles a face, with no hidden geometry: faces
between two voxels of the same part are never made.

Frames: the art is built in voxels with x right, y back (front is -y), z up
(tools/art). Meshes come out in the game's frame, in studs: Roblox axes (Y
up, front -Z), feet at Y = 0, X and Z centred on the creature, exactly as
export.py places VoxelArt boxes. art (x, y, z) -> Roblox (x, z, y), as in
export.py.

Colour: every face samples one cell of a small per-creature palette texture
(palette.py lays it out). Faces get one of a few tone variants picked by a
stable hash of the voxel, so a flat area of one colour shimmers slightly
like hand-placed cubes; rims use a darker shade, which deepens the grooves.
Glowing voxels go to separate glow meshes (one per glow colour) so the game
can make them Neon and pulse them."""

DIRS = [  # (normal, tangent u, tangent v) with u x v = normal (outward)
    ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
    ((-1, 0, 0), (0, 0, 1), (0, 1, 0)),
    ((0, 1, 0), (0, 0, 1), (1, 0, 0)),
    ((0, -1, 0), (1, 0, 0), (0, 0, 1)),
    ((0, 0, 1), (1, 0, 0), (0, 1, 0)),
    ((0, 0, -1), (0, 1, 0), (1, 0, 0)),
]

TONES = 4  # tone variants per colour for faces
BEVEL = 0.08  # rim width, as a share of a voxel
LIFT = 0.035  # how far the inner square stands off the face, in voxels
DOWN = 5  # DIRS index of the downward face (art -z)


def tone_of(p, d):
    """Stable 0..TONES-1 tone for voxel p's face d (no randomness, so a
    re-export never changes a mesh that did not change)."""
    x, y, z = p
    h = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (d * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    return (h >> 8) % TONES


def _add(a, b, s=1.0):
    return (a[0] + b[0] * s, a[1] + b[1] * s, a[2] + b[2] * s)


def pillow_faces(voxels, flat=()):
    """Yields (voxel, dir_index, inner_quad, rims) for every visible face of
    `voxels` (a set or dict keyed by (x, y, z)). Corners are in voxels, art
    frame. inner_quad is 4 points; rims is 4 quads (outer edge, inner edge),
    all wound counter-clockwise seen from outside.

    Faces that point straight down (bellies, chins, feet) are flat squares
    with no rims: the camera is nearly always above a creature, and it saves
    about an eighth of the triangles. So are faces against a voxel in
    `flat` (where a leg meets the body: hidden until the leg swings)."""
    for p in voxels:
        for d, (n, u, v) in enumerate(DIRS):
            q = (p[0] + n[0], p[1] + n[1], p[2] + n[2])
            if q in voxels:
                continue
            # face origin: the voxel corner where this face's u, v start
            o = (p[0] + max(n[0], 0), p[1] + max(n[1], 0), p[2] + max(n[2], 0))
            outer = [o, _add(o, u), _add(_add(o, u), v), _add(o, v)]
            if d == DOWN or q in flat:
                yield p, d, outer, []
                continue
            b = BEVEL
            lift = n
            inner = [
                _add(_add(_add(o, u, b), v, b), lift, LIFT),
                _add(_add(_add(o, u, 1 - b), v, b), lift, LIFT),
                _add(_add(_add(o, u, 1 - b), v, 1 - b), lift, LIFT),
                _add(_add(_add(o, u, b), v, 1 - b), lift, LIFT),
            ]
            rims = []
            for i in range(4):
                j = (i + 1) % 4
                rims.append((outer[i], outer[j], inner[j], inner[i]))
            yield p, d, inner, rims


def to_game(pt, centre, voxel):
    """art voxel point -> game studs: (x, z, y), centred, feet at 0."""
    cx, cy, z0 = centre
    return ((pt[0] - cx) * voxel, (pt[2] - z0) * voxel, (pt[1] - cy) * voxel)


class MeshData:
    """Triangles ready for any exporter: verts (game frame, studs), tris
    (index triples, counter-clockwise from outside in the game frame) and one
    palette cell per triangle."""

    def __init__(self, name):
        self.name, self.verts, self.tris, self.cells = name, [], [], []
        self._index = {}

    def vert(self, p):
        k = (round(p[0], 5), round(p[1], 5), round(p[2], 5))
        i = self._index.get(k)
        if i is None:
            i = len(self.verts)
            self.verts.append(k)
            self._index[k] = i
        return i

    def quad(self, pts, cell):
        # art -> game swaps two axes, a mirror, so the winding flips
        a, b, c, d = (self.vert(p) for p in pts)
        self.tris.append((a, c, b))
        self.cells.append(cell)
        self.tris.append((a, d, c))
        self.cells.append(cell)

    def bounds(self):
        lo = [min(v[i] for v in self.verts) for i in range(3)]
        hi = [max(v[i] for v in self.verts) for i in range(3)]
        return lo, hi


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def flat_mesh(vox, centre, voxel, cell_of, name, keep=None, step=1, closed=False):
    """Flat faces (no pillow) for the visible skin of `vox` ({(x, y, z):
    (rgb, glow)}), with neighbouring faces of one colour on one plane merged
    into rectangles (greedy meshing). keep(rgb, glow) picks which voxels get
    faces (all of them hide faces). step > 1 first merges step^3 blocks of
    voxels into one (the most common colour wins), for a far LOD.

    closed: also make the faces where a kept voxel meets one that is not
    kept, so the mesh is a closed shell. Glow meshes need it: Roblox's
    importer drops an open one-voxel slab (glowing paw soles at ground level
    vanished from four uploaded creatures). Those faces sit against the solid
    mesh, which leaves its own face there out, so nothing new shows."""
    if step > 1:
        blocks = {}
        for p, col in vox.items():
            blocks.setdefault((p[0] // step, p[1] // step, p[2] // step), []).append(col)
        grid = {}
        for bp, cols in blocks.items():
            if len(cols) * 4 < step ** 3:  # mostly empty: leave it out
                continue
            grid[bp] = max(set(cols), key=cols.count)
    else:
        grid = vox
    m = MeshData(name)
    for d, (n, u, v) in enumerate(DIRS):
        planes = {}
        for p, col in grid.items():
            q = (p[0] + n[0], p[1] + n[1], p[2] + n[2])
            if q in grid and not (closed and keep and not keep(*grid[q])):
                continue
            if keep and not keep(*col):
                continue
            planes.setdefault(_dot(p, n), {})[(_dot(p, u), _dot(p, v))] = col
        for layer, cells in planes.items():
            done = set()
            for (a, b) in sorted(cells, key=lambda ab: (ab[1], ab[0])):
                if (a, b) in done:
                    continue
                key = cells[(a, b)]

                def free(q):
                    return q in cells and q not in done and cells[q] == key

                w = 1
                while free((a + w, b)):
                    w += 1
                h = 1
                while all(free((a + i, b + h)) for i in range(w)):
                    h += 1
                for i in range(w):
                    for j in range(h):
                        done.add((a + i, b + j))
                p = tuple(a * u[k] + b * v[k] + layer * n[k] for k in range(3))
                o = (p[0] + max(n[0], 0), p[1] + max(n[1], 0), p[2] + max(n[2], 0))
                quad = [o, _add(o, u, w), _add(_add(o, u, w), v, h), _add(o, v, h)]
                if step > 1:
                    quad = [(q[0] * step, q[1] * step, q[2] * step) for q in quad]
                m.quad([to_game(q, centre, voxel) for q in quad], cell_of(key[0], key[1], 'face', 2))
    return m


LOD1_TRIS = 4000  # the far version's budget for a whole creature


def lod1_meshes(parts, centre, voxel, cell_of, prefix):
    """The far version of every part: flat, greedy-merged faces, built from
    2x2x2 voxel blocks when the creature would pass LOD1_TRIS otherwise.
    Returns {part name: MeshData}."""
    for step in (1, 2, 3):
        out = {}
        for part in parts:
            name = f'{prefix}_{part.name}_lod1'
            m = flat_mesh(part.v, centre, voxel, cell_of, name, step=step)
            if not m.tris:  # a small part (eyes) that blocks would lose
                m = flat_mesh(part.v, centre, voxel, cell_of, name)
            out[part.name] = m
        if sum(len(m.tris) for m in out.values()) <= LOD1_TRIS:
            break
    return out


def part_meshes(part, centre, voxel, cell_of, max_tris=18000, flat=()):
    """Meshes for one creature part: solid faces in one or more meshes (split
    so none passes max_tris; Roblox allows 20,000 per MeshPart) and glowing
    faces in one mesh per glow colour. cell_of(rgb, glow, kind, tone) gives the
    palette cell; kind is 'face' or 'rim'.

    Glowing and solid voxels of one part close against each other (a glow
    voxel hides the solid face beside it), so the part reads as one solid
    piece; only the outer skin is made."""
    solid_faces = []
    glow_faces = {}
    for p, d, inner, rims in pillow_faces(part.v, flat):
        rgb, glow = part.v[p]
        t = tone_of(p, d)
        item = (p, d, inner, rims, rgb, glow, t)
        if glow:
            glow_faces.setdefault(rgb, []).append(item)
        else:
            solid_faces.append(item)

    def build(name, items):
        m = MeshData(name)
        for p, d, inner, rims, rgb, glow, t in items:
            g = lambda q: to_game(q, centre, voxel)  # noqa: E731
            m.quad([g(q) for q in inner], cell_of(rgb, glow, 'face', t))
            rc = cell_of(rgb, glow, 'rim', t)
            for r in rims:
                m.quad([g(q) for q in r], rc)
        return m

    out = []
    per = max(1, max_tris // 10)

    def chunked(kind, rgb, base, items):
        # sorted bottom to top, so a split mesh is a few tidy slices
        items.sort(key=lambda it: (it[0][2], it[0][1], it[0][0], it[1]))
        chunks = [items[i:i + per] for i in range(0, len(items), per)]
        for i, chunk in enumerate(chunks):
            suffix = '' if len(chunks) == 1 else f'_{i + 1}'
            out.append((kind, rgb, build(f'{base}{suffix}', chunk)))

    if solid_faces:
        chunked('solid', None, part.name, solid_faces)
    # Glow meshes are drawn as Neon, which shows no shading, so their pillows
    # would be invisible: they are flat and greedy-merged instead.
    for k, rgb in enumerate(sorted(glow_faces)):
        m = flat_mesh(part.v, centre, voxel, cell_of, f'{part.name}_glow' + ('' if k == 0 else str(k + 1)),
                      keep=lambda c, g, rgb=rgb: g and c == rgb, closed=True)
        out.append(('glow', rgb, m))
    return out
