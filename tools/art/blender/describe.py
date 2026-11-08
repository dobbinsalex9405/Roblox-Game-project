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

from creatures import FINER, HEIGHT, build_all  # noqa: E402
import palette as pal  # noqa: E402
import voxmesh  # noqa: E402
import rig  # noqa: E402
import walkpose  # noqa: E402

RANK = ['Common', 'Uncommon', 'Rare', 'Ultra Rare', 'Epic', 'Legendary', 'Godly']

# Every tier is built from the same small voxel, VOXEL_STUDS, at its own
# size in studs on a pad (TIER_STUDS, from the plan Alex reviews; Epic and up
# are only a little bigger than Commons and take extra slots instead). The art
# in creatures.py is drawn HEIGHT voxels tall, so each tier is built at
# DETAIL times that: more voxels, same shape. The game scales a creature's
# meshes to its stand-in, so a change here needs no game code.
VOXEL_STUDS = 0.1
TIER_STUDS = {'Common': 2, 'Uncommon': 2.2, 'Rare': 2.4, 'Ultra Rare': 2.7, 'Epic': 3, 'Legendary': 3.4, 'Godly': 3.8}
DETAIL = {r: TIER_STUDS[r] / (HEIGHT[r] * VOXEL_STUDS) for r in TIER_STUDS}


ROBLOX_MESH_TRIS = 20000

MOVERS = ('body', 'head', 'wingL', 'wingR', 'tail')


def check_parents(species, parents):
    """Every part's chain of parents must end at the body: a loop (head on a
    wing, the wing on the head) draws the creature as one stray cube."""
    for name in parents:
        seen, at = {name}, parents[name]
        while at is not None:
            if at in seen or at not in parents:
                raise ValueError(f'{species}: part {name} has a parent loop or a missing parent ({at})')
            seen.add(at)
            at = parents[at]


def parent_of(part, parts):
    """export.parent_of, the same answer, faster on the finer voxels: the
    moving part this one touches most, ties broken by the nearest voxel and
    then by the head. Distances are only measured when touching ties."""
    if part.name == 'body':
        return None
    if part.name in ('eyes', 'ears'):
        return 'head'
    if part.name in ('head', 'wingL', 'wingR', 'tail') or part.name.startswith('leg'):
        return 'body'  # a moving part rides the body, never another mover (no parent loops)
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
    for c in cs:
        c.voxel = VOXEL_STUDS / FINER.get(c.species, 1)  # a showpiece's finer voxels
    if tiers:
        cs = [c for c in cs if c.rarity in tiers]
    if only:
        cs = [c for c in cs if c.species in only]
    return cs


# Parts that never move against the body (it, or what rides it rigidly).
STILL_ROLES = ('body', 'static', 'blink', 'glow')
# How far a moving part's skin sits inside its voxels, in voxels: more than
# the pillow lift (voxmesh.LIFT), so even a leg's raised face squares stay
# behind a body face in the same plane.
INSET = 0.08


# The triangle budget below Ultra Rare (tools/art/check.py BUDGET): the
# tiers whose creatures can carry voxels that lost their glow (rule k).
PLAIN_BUDGET = {'Common': 15000, 'Uncommon': 15000, 'Rare': 15000}


def describe(c):
    """Returns (meta, palette, parts) where parts is [(part, joint_pivot,
    [(kind, rgb, MeshData, mesh_name)])]. All positions are in the game
    frame, in studs, feet at the origin.

    Voxels that lost their glow to rule k (part.unglowed, variants "glow":
    false) are pillowed like every other voxel. Only when that puts the
    creature over its triangle budget do they keep the flat, greedy-merged
    faces they had as glow (voxmesh.part_meshes), which costs what the glow
    cost."""
    unglowed = {p.name: p.unglowed for p in c.parts if getattr(p, 'unglowed', None)}
    if not unglowed:
        return _describe(c)
    for p in c.parts:
        p.unglowed = ()
    out = _describe(c)
    if out[0]['tris'] <= PLAIN_BUDGET.get(c.rarity, 0):
        return out
    for p in c.parts:
        p.unglowed = unglowed.get(p.name, ())
    return _describe(c)


def _describe(c):
    lo, hi = c.bounds()
    centre = ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2])
    V = c.voxel
    p = pal.Palette()
    parts, parts_meta, total, total_lod, glows = [], [], 0, 0, set()
    lods = voxmesh.lod1_meshes(c.parts, centre, V, p.cell_of, c.species)
    for part in c.parts:
        pivot = voxmesh.to_game(part.pivot, centre, V)
        meshes, mlist = [], []
        # where a leg meets the body, both sides are flat (hidden at rest)
        if part.name == 'body':
            flat = {v for o in c.parts if o.name.startswith('leg') for v in o.v}
        elif part.name.startswith('leg'):
            flat = set(next((o.v for o in c.parts if o.name == 'body'), ()))
        else:
            flat = ()
        # A part that moves against the body is inset a hair (voxmesh
        # MeshData.inset) so no face of it is ever the same plane as the
        # body's: legs, wings, fins, tails, heads and ears.
        moves = walkpose.role(part.name, part.anim) not in STILL_ROLES
        # Its faces against what it rests on (the body and the parts riding
        # it rigidly) stay put: inset, a leg's top would open a slit through
        # the hip that shows the sky.
        contact = {v for o in c.parts if o is not part and walkpose.role(o.name, o.anim) in STILL_ROLES
                   for v in o.v} if moves else ()
        for kind, rgb, md in voxmesh.part_meshes(part, centre, V, p.cell_of, flat=flat, contact=contact):
            if not md.tris:
                continue
            if moves:
                md.inset(INSET * V)
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
        lod = lods[part.name]
        lod_entry = None
        if lod.tris:
            lo_m, hi_m = lod.bounds()
            lod_entry = {
                'name': lod.name,
                'center': r4([(a + b) / 2 for a, b in zip(lo_m, hi_m)]),
                'size': r4([b - a for a, b in zip(lo_m, hi_m)]),
                'tris': len(lod.tris),
            }
            total_lod += len(lod.tris)
            meshes.append(('lod1', None, lod, lod.name))
        parts.append((part, pivot, meshes))
        parts_meta.append({
            'name': part.name,
            'anim': 'body' if part.name == 'body' else part.anim,
            'parent': parent_of(part, c.parts),
            'pivot': r4(pivot),
            'meshes': mlist,
            'lod1': lod_entry,
        })
    check_parents(c.species, {m['name']: m['parent'] for m in parts_meta})
    # Roblox refuses a mesh over 20,000 triangles at upload; solid meshes are
    # split below that, but a glow mesh (one per colour) is not
    for pm in parts_meta:
        for mm in pm['meshes']:
            if mm['tris'] > ROBLOX_MESH_TRIS:
                raise ValueError(f"{c.species}: mesh {mm['name']} has {mm['tris']} triangles, over Roblox's {ROBLOX_MESH_TRIS}")
    size = [(hi[0] - lo[0]) * V, (hi[2] - lo[2]) * V, (hi[1] - lo[1]) * V]
    meta = {
        'id': c.species,
        'rarity': c.rarity,
        'element': getattr(c, 'element', 'plain'),
        'gait': rig.gait(c),
        'heightStuds': round(size[1], 4),
        'sizeStuds': r4(size),
        'voxelStuds': round(V, 5),
        'rig': 'voxel-parts-v1',
        'glow': bool(glows),
        'glowColors': sorted(glows),
        'tris': total,
        'trisLod1': total_lod,
        'parts': parts_meta,
        'clips': {'idle': {'seconds': 4.0, 'loop': True}, 'walk': {'seconds': 2.0, 'loop': True}},
        'files': {'glb': f'{c.species}.glb', 'fbx': f'{c.species}.fbx', 'texture': f'{c.species}_palette.png'},
    }
    return meta, p, parts


def manifest(cs=None):
    metas = [describe(c)[0] for c in (cs if cs is not None else creatures())]
    metas.sort(key=lambda m: (RANK.index(m['rarity']), m['id']))
    return {'version': 1, 'creatures': metas}
