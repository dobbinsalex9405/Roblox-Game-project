"""Environment voxel kit: the world thread's voxel grids (tools/art/world/
vkit.py) at a voxel size chosen per model, meshed one mesh per colour.

Why one mesh per colour: Roblox MeshParts take one Color each, so a tree
arrives as a handful of MeshParts (bark, three leaf greens, blossom ...) with
no texture to upload or fail to load. Every visible voxel face is the same
bevelled "pillow" square as the creatures and the world props.

Why a bigger voxel than the creatures' 0.1 stud: a 24-stud tree at 0.1 stud
would be 240 voxels tall and several hundred thousand triangles. Trees and
rocks use the same voxels-per-object as a creature (a 3-stud Common is 30
voxels tall; a 24-stud oak at 0.4 stud is 60), so they read as the same
polished voxel style from where a player stands.

Units: studs, Z up, front -y (as vkit). `roblox()` converts to the game's
frame (Y up, front -Z) the same way the world props' .glb export does.
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'world'))

import vkit  # noqa: E402

TRI_CAP = 18000  # Roblox allows 20,000 triangles a mesh; bigger colours split


def set_voxel(v):
    vkit.VOX = float(v)


def pick(hexes, seed, glow=0.0):
    """speckle: each voxel takes one of a few close colours, stable per voxel"""
    ids = [vkit.col(h, glow) for h in hexes]
    if len(ids) == 1:
        return ids[0]
    arr = np.array(ids, np.uint16)

    def c(X, Y, Z):
        n = vkit.hnoise(X, Y, Z, seed)
        return arr[np.minimum((n * len(arr)).astype(int), len(arr) - 1)]
    return c


def tones(pal, z0, z1, seed=1, sx=0.12):
    """dark at the bottom of a canopy, light at the top, wobbly border"""
    d, m, l_ = pick(pal['dark'], seed + 50), pick(pal['mid'], seed + 51), pick(pal['light'], seed + 52)

    def c(X, Y, Z):
        t = (Z - z0) / max(z1 - z0, 1e-6) + sx * vkit.snoise(X, Y, Z, 2.0 / max(vkit.VOX * 6, 0.3), seed)
        return np.where(t < 0.28, d(X, Y, Z), np.where(t > 0.72, l_(X, Y, Z), m(X, Y, Z)))
    return c


# ------------------------------------------------------------------- mesher
def pillow_by_colour(grid, skip_bottom=True):
    """-> {palette index: (verts (F*8,3) studs, quads (F*5,4))}, the same
    bevelled face as vkit.pillow, grouped by colour (no vertex colours)."""
    C = grid.c
    filled = C > 0
    pad = np.pad(filled, 1)
    nx, ny, nz = C.shape
    acc = {}
    for d, (n, u, v) in enumerate(vkit.DIRS):
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
        b = vkit.BEVEL
        lift = vkit.LIFT
        corners = [
            o, o + u_, o + u_ + v_, o + v_,
            o + u_ * b + v_ * b + n_ * lift,
            o + u_ * (1 - b) + v_ * b + n_ * lift,
            o + u_ * (1 - b) + v_ * (1 - b) + n_ * lift,
            o + u_ * b + v_ * (1 - b) + n_ * lift,
        ]
        V = (np.stack(corners, 1) + grid.o.astype(np.float32)) * vkit.VOX
        for c in np.unique(ci):
            acc.setdefault(int(c), []).append(V[ci == c])
    out = {}
    for c, parts in acc.items():
        V = np.concatenate(parts)
        F = len(V)
        quads = (np.arange(F, dtype=np.int64)[:, None, None] * 8 + vkit.QUADS[None]).reshape(-1, 4)
        out[c] = (V.reshape(-1, 3), quads)
    return out


def flat_by_colour(grid, skip_bottom=True):
    """Far version: greedy-merged flat quads per colour (2 triangles a
    rectangle of same-colour faces). -> {palette index: (verts, quads)}"""
    C = grid.c
    nx, ny, nz = C.shape
    pad = np.pad(C > 0, 1)
    out = {}
    for d, (n, u, v) in enumerate(vkit.DIRS):
        if skip_bottom and d == 5:
            continue
        axis = int(np.argmax(np.abs(n)))
        sgn = n[axis]
        nb = pad[1 + n[0]:1 + n[0] + nx, 1 + n[1]:1 + n[1] + ny, 1 + n[2]:1 + n[2] + nz]
        vis = np.where((C > 0) & ~nb, C, 0)
        others = [a for a in range(3) if a != axis]
        for k in range(C.shape[axis]):
            sl = [slice(None)] * 3
            sl[axis] = k
            m = vis[tuple(sl)].copy()  # 2D over others[0], others[1]
            H, W = m.shape
            for i in range(H):
                j = 0
                while j < W:
                    c = m[i, j]
                    if c == 0:
                        j += 1
                        continue
                    w = 1
                    while j + w < W and m[i, j + w] == c:
                        w += 1
                    h = 1
                    while i + h < H and np.all(m[i + h, j:j + w] == c):
                        h += 1
                    m[i:i + h, j:j + w] = 0
                    p0 = [0, 0, 0]
                    p0[axis] = k + (1 if sgn > 0 else 0)
                    a0, a1 = others
                    corners = []
                    for (di, dj) in ((0, 0), (h, 0), (h, w), (0, w)):
                        p = list(p0)
                        p[a0] = i + di
                        p[a1] = j + dj
                        corners.append(p)
                    # winding so the normal points along n
                    e1 = np.subtract(corners[1], corners[0])
                    e2 = np.subtract(corners[3], corners[0])
                    if np.dot(np.cross(e1, e2), n) < 0:
                        corners = corners[::-1]
                    out.setdefault(int(c), []).append(corners)
                    j += w
    res = {}
    for c, qs in out.items():
        V = (np.array(qs, np.float32).reshape(-1, 3) + grid.o.astype(np.float32)) * vkit.VOX
        quads = np.arange(len(qs) * 4, dtype=np.int64).reshape(-1, 4)
        res[c] = (V, quads)
    return res


def split(V, quads, cap=TRI_CAP):
    """cut a colour's quads into chunks of at most `cap` triangles, by height"""
    ntri = len(quads) * 2
    if ntri <= cap:
        return [(V, quads)]
    k = math.ceil(ntri / cap)
    z = V[quads].mean(1)[:, 2]
    order = np.argsort(z, kind='stable')
    out = []
    for chunk in np.array_split(order, k):
        q = quads[chunk]
        used, inv = np.unique(q.ravel(), return_inverse=True)
        out.append((V[used], inv.reshape(-1, 4)))
    return out


def roblox(V):
    """model frame (Z up, front -y) -> Roblox (Y up, front -Z), the frame the
    .fbx/.glb files carry: turned 180 degrees about up, then Y-up"""
    V = np.asarray(V, np.float64)
    return np.stack([-V[:, 0], V[:, 2], V[:, 1]], 1)


def hexcol(ci):
    rgb, glow = vkit.PAL[ci][0], vkit.PAL[ci][1]
    return '%02X%02X%02X' % tuple(rgb), glow
