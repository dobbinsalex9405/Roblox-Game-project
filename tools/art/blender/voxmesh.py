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


def tone_of(p, d):
    """Stable 0..TONES-1 tone for voxel p's face d (no randomness, so a
    re-export never changes a mesh that did not change)."""
    x, y, z = p
    h = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (d * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    return (h >> 8) % TONES


def _add(a, b, s=1.0):
    return (a[0] + b[0] * s, a[1] + b[1] * s, a[2] + b[2] * s)


def pillow_faces(voxels):
    """Yields (voxel, dir_index, inner_quad, rims) for every visible face of
    `voxels` (a set or dict keyed by (x, y, z)). Corners are in voxels, art
    frame. inner_quad is 4 points; rims is 4 quads (outer edge, inner edge),
    all wound counter-clockwise seen from outside."""
    for p in voxels:
        for d, (n, u, v) in enumerate(DIRS):
            q = (p[0] + n[0], p[1] + n[1], p[2] + n[2])
            if q in voxels:
                continue
            # face origin: the voxel corner where this face's u, v start
            o = (p[0] + max(n[0], 0), p[1] + max(n[1], 0), p[2] + max(n[2], 0))
            outer = [o, _add(o, u), _add(_add(o, u), v), _add(o, v)]
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


def part_meshes(part, centre, voxel, cell_of, max_tris=18000):
    """Meshes for one creature part: solid faces in one or more meshes (split
    so none passes max_tris; Roblox allows 20,000 per MeshPart) and glowing
    faces in one mesh per glow colour. cell_of(rgb, glow, kind, tone) gives the
    palette cell; kind is 'face' or 'rim'.

    Glowing and solid voxels of one part close against each other (a glow
    voxel hides the solid face beside it), so the part reads as one solid
    piece; only the outer skin is made."""
    solid_faces = []
    glow_faces = {}
    for p, d, inner, rims in pillow_faces(part.v):
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
    for k, (rgb, items) in enumerate(sorted(glow_faces.items())):
        chunked('glow', rgb, f'{part.name}_glow' + ('' if k == 0 else str(k + 1)), items)
    return out
