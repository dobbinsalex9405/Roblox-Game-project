"""What a creature's meshes are, without Blender: every part's meshes
(triangles, palette cells, bounds), its joint and the creature's meta.json.
build.py turns this into Blender objects and files; luau.py turns the meta
into the game's CreatureMeshes.luau. Keeping it Blender-free means CI can
check the game data is current with plain Python."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))

from creatures import build_all  # noqa: E402
import palette as pal  # noqa: E402
import voxmesh  # noqa: E402

RANK = ['Common', 'Uncommon', 'Rare', 'Ultra Rare', 'Epic', 'Legendary', 'Godly']

# More, smaller voxels for the smaller tiers, at the same size in studs: a
# 2-stud Common gets 16 voxels of height (room for eyes, cheeks, sturdy
# legs) instead of the in-game boxes' 8. The showpieces are built huge
# already, so they keep one voxel = 0.25 studs.
DETAIL = {'Common': 2, 'Uncommon': 2, 'Rare': 2, 'Ultra Rare': 1.5, 'Epic': 1.5, 'Legendary': 1, 'Godly': 1}


MOVERS = ('body', 'head', 'wingL', 'wingR', 'tail')


def parent_of(part, parts):
    """export.parent_of, the same answer, faster on the finer voxels: the
    moving part this one touches most, ties broken by the nearest voxel and
    then by the head. Distances are only measured when touching ties."""
    if part.name == 'body':
        return None
    if part.name in ('eyes', 'ears'):
        return 'head'
    scored = []
    for other in parts:
        if other is part or other.name not in MOVERS:
            continue
        touching = 0
        for (x, y, z) in part.v:
            if any((x + dx, y + dy, z + dz) in other.v
                   for dx in (-1, 0, 1) for dy in (-1, 0, 1) for dz in (-1, 0, 1)):
                touching += 1
        scored.append((touching, other))
    if not scored:
        return 'body'
    top = max(t for t, _ in scored)
    tied = [o for t, o in scored if t == top]
    if len(tied) == 1:
        return tied[0].name

    def nearest(other):
        best = None
        ov = list(other.v)
        for v in part.v:
            for w in ov:
                d = (v[0] - w[0]) ** 2 + (v[1] - w[1]) ** 2 + (v[2] - w[2]) ** 2
                if best is None or d < best:
                    best = d
                    if best == 0:
                        return 0
        return best

    return max(tied, key=lambda o: (-nearest(o), o.name == 'head')).name


def hexs(rgb):
    return '%02X%02X%02X' % rgb


def r4(v):
    return [round(x, 4) for x in v]


def creatures(tiers=None, only=None):
    cs = build_all(DETAIL)
    if tiers:
        cs = [c for c in cs if c.rarity in tiers]
    if only:
        cs = [c for c in cs if c.species in only]
    return cs


def describe(c):
    """Returns (meta, palette, parts) where parts is [(part, joint_pivot,
    [(kind, rgb, MeshData, mesh_name)])]. All positions are in the game
    frame, in studs, feet at the origin."""
    lo, hi = c.bounds()
    centre = ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2])
    V = c.voxel
    p = pal.Palette()
    parts, parts_meta, total, glows = [], [], 0, set()
    for part in c.parts:
        pivot = voxmesh.to_game(part.pivot, centre, V)
        meshes, mlist = [], []
        for kind, rgb, md in voxmesh.part_meshes(part, centre, V, p.cell_of):
            if not md.tris:
                continue
            name = f'{c.species}_{md.name}'
            lo_m, hi_m = md.bounds()
            entry = {
                'name': name,
                'kind': kind,
                'center': r4([(a + b) / 2 for a, b in zip(lo_m, hi_m)]),
                'size': r4([b - a for a, b in zip(lo_m, hi_m)]),
                'tris': len(md.tris),
            }
            if kind == 'glow':
                entry['color'] = hexs(rgb)
                glows.add(hexs(rgb))
            total += len(md.tris)
            meshes.append((kind, rgb, md, name))
            mlist.append(entry)
        parts.append((part, pivot, meshes))
        parts_meta.append({
            'name': part.name,
            'anim': 'body' if part.name == 'body' else part.anim,
            'parent': parent_of(part, c.parts),
            'pivot': r4(pivot),
            'meshes': mlist,
        })
    size = [(hi[0] - lo[0]) * V, (hi[2] - lo[2]) * V, (hi[1] - lo[1]) * V]
    meta = {
        'id': c.species,
        'rarity': c.rarity,
        'heightStuds': round(size[1], 4),
        'sizeStuds': r4(size),
        'voxelStuds': round(V, 5),
        'rig': 'voxel-parts-v1',
        'glow': bool(glows),
        'glowColors': sorted(glows),
        'tris': total,
        'parts': parts_meta,
        'clips': {'idle': {'seconds': 4.0, 'loop': True}, 'walk': {'seconds': 1.0, 'loop': True}},
        'files': {'glb': f'{c.species}.glb', 'fbx': f'{c.species}.fbx', 'texture': f'{c.species}_palette.png'},
    }
    return meta, p, parts


def manifest(cs=None):
    metas = [describe(c)[0] for c in (cs if cs is not None else creatures())]
    metas.sort(key=lambda m: (RANK.index(m['rarity']), m['id']))
    return {'version': 1, 'creatures': metas}
