"""World voxel kit: numpy voxel grids modelled in studs, a vectorised
"pillow" mesher (same look as tools/art/blender/voxmesh.py: every visible
voxel face is a slightly raised square with bevelled rims), and Blender
helpers to turn grids into meshes, render and export.

Units: 1 Blender unit = 1 stud. Voxel = 0.1 stud. Z up. Shapes are given in
studs; voxel centres are at (i + 0.5) * VOX.
"""
import math
import numpy as np

VOX = 0.1
BEVEL = 0.08   # creature v2 values
LIFT = 0.035
RIM = 0.90
FACE_TONE = np.array([0.94, 0.98, 1.0, 1.04], np.float32)

# ------------------------------------------------------------------ palette
PAL = [((0, 0, 0), 0.0)]  # index 0 = empty
_PIDX = {}
FAMILY = {}  # palette index -> the index it stands in for when speckle is dropped (Parts export)


def hexrgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def col(h, glow=0.0, of=None):
    """palette index of a colour. With `of` (another palette index) the colour
    is a speckle of that one: it gets its own index, folded into `of` when the
    Parts export drops speckle, so a colour used plainly elsewhere never folds."""
    rgb = hexrgb(h) if isinstance(h, str) else tuple(h)
    k = (rgb, float(glow)) if of is None else (rgb, float(glow), int(of))
    if k not in _PIDX:
        if of is not None and (rgb, float(glow)) != (PAL[of][0], PAL[of][1]):
            FAMILY[len(PAL)] = int(of)
        _PIDX[k] = len(PAL)
        PAL.append(k[:2])
    return _PIDX[k]


def lin(c):
    c = np.asarray(c, np.float32) / 255.0
    return np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)


def hnoise(X, Y, Z, seed=0):
    """stable 0..1 per voxel"""
    xi = np.floor(X / VOX + 0.01).astype(np.int64)
    yi = np.floor(Y / VOX + 0.01).astype(np.int64)
    zi = np.floor(Z / VOX + 0.01).astype(np.int64)
    h = (xi * 73856093) ^ (yi * 19349663) ^ (zi * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return ((h & 0xFFFFFF).astype(np.float32)) / float(0xFFFFFF)


def snoise(X, Y, Z, f=1.0, seed=0):
    """smooth-ish -1..1 field (sum of sines), for lumpy shapes and patches"""
    s = seed * 1.618
    return (np.sin(X * f * 1.7 + s) * np.sin(Y * f * 1.3 + 2 * s) * np.sin(Z * f * 2.1 + 3 * s)
            + 0.5 * np.sin(X * f * 3.1 - s) * np.sin(Y * f * 2.7 + s) + 0.5 * np.sin(Y * f * 3.3 + Z * f * 2.3 + s)) / 2.0


# --------------------------------------------------------------------- grid
class Grid:
    """Dense voxel box. lo/hi are the world bounds in studs."""

    def __init__(self, lo, hi):
        self.o = np.floor(np.array(lo, float) / VOX + 1e-6).astype(int)
        n = np.ceil(np.array(hi, float) / VOX - 1e-6).astype(int) - self.o
        self.c = np.zeros(tuple(n), np.uint16)

    def _sub(self, lo, hi):
        a = np.floor(np.array(lo, float) / VOX + 1e-6).astype(int) - self.o
        b = np.ceil(np.array(hi, float) / VOX - 1e-6).astype(int) - self.o
        a = np.maximum(a, 0)
        b = np.minimum(b, self.c.shape)
        if np.any(b <= a):
            return None
        sl = tuple(slice(int(i), int(j)) for i, j in zip(a, b))
        ax = [(np.arange(i, j) + self.o[k] + 0.5) * VOX for k, (i, j) in enumerate(zip(a, b))]
        X, Y, Z = np.meshgrid(*ax, indexing='ij')
        return sl, X, Y, Z

    def fill(self, lo, hi, mask, c, only_empty=False, only_filled=False):
        r = self._sub(lo, hi)
        if r is None:
            return
        sl, X, Y, Z = r
        m = mask(X, Y, Z) if mask is not None else np.ones(X.shape, bool)
        sub = self.c[sl]
        if only_empty:
            m &= sub == 0
        if only_filled:
            m &= sub > 0
        v = c(X, Y, Z) if callable(c) else c
        if np.ndim(v):
            sub[m] = np.asarray(v)[m]
        else:
            sub[m] = v

    def paint(self, lo, hi, mask, c):
        self.fill(lo, hi, mask, c, only_filled=True)

    def carve(self, lo, hi, mask=None):
        self.fill(lo, hi, mask, 0)

    # ---- primitives (studs)
    def box(self, lo, hi, c, **kw):
        self.fill(lo, hi, None, c, **kw)

    def ell(self, ctr, r, c, cond=None, **kw):
        cx, cy, cz = ctr
        rx, ry, rz = r

        def m(X, Y, Z):
            d = ((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2 + ((Z - cz) / rz) ** 2
            out = d <= 1.0
            if cond is not None:
                out &= cond(X, Y, Z)
            return out
        self.fill((cx - rx, cy - ry, cz - rz), (cx + rx, cy + ry, cz + rz), m, c, **kw)

    def blob(self, ctr, r, c, amp=0.15, f=1.5, seed=0, **kw):
        """lumpy ellipsoid"""
        cx, cy, cz = ctr
        rx, ry, rz = r

        def m(X, Y, Z):
            d = np.sqrt(((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2 + ((Z - cz) / rz) ** 2)
            return d <= 1.0 + amp * snoise(X, Y, Z, f, seed)
        k = 1 + amp
        self.fill((cx - rx * k, cy - ry * k, cz - rz * k), (cx + rx * k, cy + ry * k, cz + rz * k), m, c, **kw)

    def cyl(self, cx, cy, z0, z1, r, c, r1=None, cond=None, **kw):
        """vertical cylinder / cone (r at z0 -> r1 at z1)"""
        r1 = r if r1 is None else r1
        R = max(r, r1)

        def m(X, Y, Z):
            t = np.clip((Z - z0) / max(z1 - z0, 1e-6), 0, 1)
            rr = r + (r1 - r) * t
            out = (X - cx) ** 2 + (Y - cy) ** 2 <= rr ** 2
            if cond is not None:
                out &= cond(X, Y, Z)
            return out
        self.fill((cx - R, cy - R, z0), (cx + R, cy + R, z1), m, c, **kw)

    def rbox(self, lo, hi, rad, c, **kw):
        """box with rounded vertical edges (rad in studs)"""
        (x0, y0, z0), (x1, y1, z1) = lo, hi

        def m(X, Y, Z):
            dx = np.maximum(np.maximum(x0 + rad - X, X - (x1 - rad)), 0)
            dy = np.maximum(np.maximum(y0 + rad - Y, Y - (y1 - rad)), 0)
            return dx * dx + dy * dy <= rad * rad
        self.fill(lo, hi, m, c, **kw)

    def rrbox(self, lo, hi, rad, c, **kw):
        """box rounded on every edge"""
        (x0, y0, z0), (x1, y1, z1) = lo, hi

        def m(X, Y, Z):
            dx = np.maximum(np.maximum(x0 + rad - X, X - (x1 - rad)), 0)
            dy = np.maximum(np.maximum(y0 + rad - Y, Y - (y1 - rad)), 0)
            dz = np.maximum(np.maximum(z0 + rad - Z, Z - (z1 - rad)), 0)
            return dx * dx + dy * dy + dz * dz <= rad * rad
        self.fill(lo, hi, m, c, **kw)

    def seg(self, a, b, r, c, r1=None, **kw):
        """capsule from a to b (studs), radius r -> r1"""
        a = np.array(a, float)
        b = np.array(b, float)
        r1 = r if r1 is None else r1
        R = max(r, r1)
        ab = b - a
        L2 = float(ab @ ab) or 1e-9

        def m(X, Y, Z):
            px, py, pz = X - a[0], Y - a[1], Z - a[2]
            t = np.clip((px * ab[0] + py * ab[1] + pz * ab[2]) / L2, 0, 1)
            dx, dy, dz = px - t * ab[0], py - t * ab[1], pz - t * ab[2]
            rr = r + (r1 - r) * t
            return dx * dx + dy * dy + dz * dz <= rr * rr
        lo = np.minimum(a, b) - R
        hi = np.maximum(a, b) + R
        self.fill(lo, hi, m, c, **kw)

    def count(self):
        return int((self.c > 0).sum())


# ------------------------------------------------------------------- mesher
DIRS = [
    ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
    ((-1, 0, 0), (0, 0, 1), (0, 1, 0)),
    ((0, 1, 0), (0, 0, 1), (1, 0, 0)),
    ((0, -1, 0), (1, 0, 0), (0, 0, 1)),
    ((0, 0, 1), (1, 0, 0), (0, 1, 0)),
    ((0, 0, -1), (0, 1, 0), (1, 0, 0)),
]
QUADS = np.array([[4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]], np.int64)


def pillow(grid, skip_bottom=False, glow_split=True):
    """-> dict kind -> (verts (N,3) studs, loops (L,), loop colours (L,4) linear,
    face count). kind 'solid' or 'glow'."""
    C = grid.c
    filled = C > 0
    pad = np.pad(filled, 1)
    nx, ny, nz = C.shape
    pal_lin = np.array([lin(p[0]) for p in PAL], np.float32)
    pal_glow = np.array([p[1] for p in PAL], np.float32)
    acc = {'solid': [], 'glow': []}
    for d, (n, u, v) in enumerate(DIRS):
        if skip_bottom and d == 5:
            continue
        nb = pad[1 + n[0]:1 + n[0] + nx, 1 + n[1]:1 + n[1] + ny, 1 + n[2]:1 + n[2] + nz]
        vis = filled & ~nb
        idx = np.argwhere(vis)
        if not len(idx):
            continue
        ci = C[idx[:, 0], idx[:, 1], idx[:, 2]]
        n_, u_, v_ = (np.array(t, np.float32) for t in (n, u, v))
        o = idx.astype(np.float32) + np.maximum(n_, 0)
        b = BEVEL
        corners = [
            o, o + u_, o + u_ + v_, o + v_,
            o + u_ * b + v_ * b + n_ * LIFT,
            o + u_ * (1 - b) + v_ * b + n_ * LIFT,
            o + u_ * (1 - b) + v_ * (1 - b) + n_ * LIFT,
            o + u_ * b + v_ * (1 - b) + n_ * LIFT,
        ]
        V = np.stack(corners, 1)  # F,8,3
        V = (V + grid.o.astype(np.float32)) * VOX
        # tone per voxel face
        hx = idx[:, 0] + grid.o[0]
        hy = idx[:, 1] + grid.o[1]
        hz = idx[:, 2] + grid.o[2]
        h = (hx.astype(np.int64) * 73856093) ^ (hy.astype(np.int64) * 19349663) ^ (hz.astype(np.int64) * 83492791) ^ (d * 2654435761)
        h = (h ^ (h >> 13)) * 1274126177
        tone = FACE_TONE[(h >> 8) % 4]
        base = pal_lin[ci]
        g = pal_glow[ci] > 0
        face_c = base * tone[:, None]
        rim_c = base * (RIM * tone)[:, None]
        for kind, sel in (('solid', ~g), ('glow', g)):
            if not sel.any():
                continue
            Vs = V[sel]
            F = len(Vs)
            fc, rc = face_c[sel], rim_c[sel]
            cols = np.empty((F, 5, 4, 4), np.float32)
            cols[:, 0, :, :3] = fc[:, None, :]
            cols[:, 1:, :, :3] = rc[:, None, None, :]
            cols[..., 3] = 1
            acc[kind].append((Vs, cols, F))
    out = {}
    for kind, parts in acc.items():
        if not parts:
            continue
        V = np.concatenate([p[0] for p in parts]).reshape(-1, 3)
        cols = np.concatenate([p[1] for p in parts]).reshape(-1, 4)
        F = sum(p[2] for p in parts)
        loops = (np.arange(F, dtype=np.int64)[:, None, None] * 8 + QUADS[None]).reshape(-1)
        out[kind] = (V, loops, cols, F)
    return out


# ------------------------------------------------------------------ blender
def bl_mesh(name, V, loops, cols, coll, mat, loc=(0, 0, 0)):
    import bpy
    me = bpy.data.meshes.new(name)
    me.vertices.add(len(V))
    me.vertices.foreach_set('co', V.astype(np.float32).ravel())
    me.loops.add(len(loops))
    me.loops.foreach_set('vertex_index', loops.astype(np.int32))
    npoly = len(loops) // 4
    me.polygons.add(npoly)
    me.polygons.foreach_set('loop_start', (np.arange(npoly, dtype=np.int32) * 4))
    me.update(calc_edges=True)
    ca = me.color_attributes.new('col', 'FLOAT_COLOR', 'CORNER')
    ca.data.foreach_set('color', cols.astype(np.float32).ravel())
    me.color_attributes.active_color = ca
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    coll.objects.link(ob)
    return ob


def materials(rough=0.6, glow_strength=3.0, spec=0.3):
    import bpy
    out = []
    for name, glow in (('Voxel', False), ('VoxelGlow', True)):
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes['Principled BSDF']
        a = nt.nodes.new('ShaderNodeVertexColor')
        a.layer_name = 'col'
        nt.links.new(a.outputs['Color'], bsdf.inputs['Base Color'])
        bsdf.inputs['Roughness'].default_value = rough
        try:
            bsdf.inputs['Specular IOR Level'].default_value = spec
        except KeyError:
            pass
        if glow:
            nt.links.new(a.outputs['Color'], bsdf.inputs['Emission Color'])
            bsdf.inputs['Emission Strength'].default_value = glow_strength
        out.append(m)
    return out


def grid_objects(grid, name, coll, mats, skip_bottom=False):
    obs = []
    for kind, (V, loops, cols, F) in pillow(grid, skip_bottom).items():
        obs.append(bl_mesh(f'{name}_{kind}', V, loops, cols, coll, mats[0] if kind == 'solid' else mats[1]))
    return obs
