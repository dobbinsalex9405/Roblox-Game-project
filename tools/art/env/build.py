"""Builds Hatchery Heist's outdoor nature models (nature.py) in Blender:
one mesh per colour, an .fbx for Roblox, a .glb for the 3D design viewer, a
review render, meta.json, and build/env/env.json (what luau.py turns into
EnvArt.luau).

    PYTHONPATH=/tmp/bpy python3 tools/art/env/build.py OUT [--only PuffOakL,RockM] [--designs /mnt/project-files/designs] [--no-render] [--fast]

OUT/<id>/ gets <id>.fbx, <id>.glb, hero.png and meta.json; OUT/lineup.png
shows every model at its real size.

Meshes are flat greedy-merged voxel faces, one MeshPart per colour (see
envkit.py for why). The files face -Z with Y up, like the creature meshes.
"""
import argparse
import json
import math
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402

import envkit  # noqa: E402
import nature  # noqa: E402
import vkit  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
MANIFEST = os.path.join(HERE, 'env.json')  # committed: what the uploaded files hold

FOLDER = {
    'tree': 'Nature/Hatchery Heist/Outdoor trees',
    'bush': 'Nature/Hatchery Heist/Bushes and hedges',
    'rock': 'Nature/Hatchery Heist/Rocks and stones',
    'flowers': 'Nature/Hatchery Heist/Flowers and grass',
    'grass': 'Nature/Hatchery Heist/Flowers and grass',
    'shrooms': 'Nature/Hatchery Heist/Flowers and grass',
}
SPECIES = {
    'PuffOak': 'Puff Oak', 'AmberOak': 'Amber Oak', 'Blossom': 'Blossom Tree', 'StarPine': 'Star Pine',
    'Willow': 'Moonberry Willow', 'Toadstool': 'Toadstool Tree',
}
SIZE = {'S': 'small', 'M': 'medium', 'L': 'large'}


def design_path(m):
    """Trees group by species, each size a design: Outdoor trees/Star Pine/Star Pine (large)."""
    mid = m['id']
    base = FOLDER[m['kind']]
    for k, name in SPECIES.items():
        if mid.startswith(k) and mid[len(k):] in SIZE:
            return os.path.join(base, name, f'{name} ({SIZE[mid[len(k):]]})')
    return os.path.join(base, mid)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


_MATS = {}


def material(hexs, glow):
    key = (hexs, glow)
    if key in _MATS and _MATS[key].name in bpy.data.materials:
        return _MATS[key]
    m = bpy.data.materials.new(f'c{hexs}' + ('_glow' if glow else ''))
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    rgb = vkit.lin(vkit.hexrgb(hexs))
    b.inputs['Base Color'].default_value = (*rgb, 1)
    b.inputs['Roughness'].default_value = 0.75
    if glow:
        b.inputs['Emission Color'].default_value = (*rgb, 1)
        b.inputs['Emission Strength'].default_value = glow
    _MATS[key] = m
    return m


def mesh_object(name, V, quads, mat, coll):
    me = bpy.data.meshes.new(name)
    me.from_pydata(V.tolist(), [], quads.tolist())
    me.materials.append(mat)
    me.update()
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    return ob


def build_meshes(mid, coll):
    """-> (objects, manifest meshes, triangle count)"""
    g = nature.build(mid)
    flat = envkit.flat_by_colour(g)
    obs, meshes, tris = [], [], 0
    # biggest colour first, so names are stable and readable
    order = sorted(flat, key=lambda c: -len(flat[c][1]))
    k = 0
    for c in order:
        V, quads = flat[c]
        hexs, glow = envkit.hexcol(c)
        for Vc, qc in envkit.split(V, quads):
            k += 1
            name = f'{mid}_{k}'
            # turned 180 degrees about up: the files face -Z like Roblox
            Vb = np.stack([-Vc[:, 0], -Vc[:, 1], Vc[:, 2]], 1)
            obs.append(mesh_object(name, Vb, qc, material(hexs, glow), coll))
            R = envkit.roblox(Vc)
            lo, hi = R.min(0), R.max(0)
            mesh = dict(name=name, center=[round(float(x), 4) for x in (lo + hi) / 2],
                        size=[round(float(x), 4) for x in hi - lo], color=hexs)
            if glow:
                mesh['glow'] = True
            meshes.append(mesh)
            tris += len(qc) * 2
    return obs, meshes, tris


def export(d, mid, coll):
    for ob in bpy.context.scene.objects:
        ob.select_set(ob.name in coll.objects)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(d, f'{mid}.fbx'), use_selection=True, object_types={'MESH'},
        apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS', axis_forward='-Z', axis_up='Y',
        bake_anim=False, path_mode='STRIP', mesh_smooth_type='FACE',
    )
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(d, f'{mid}.glb'), export_format='GLB', use_selection=True, export_yup=True,
        export_apply=True, export_animations=False, export_extras=False,
        export_draco_mesh_compression_enable=True, export_draco_mesh_compression_level=6,
    )


def stage(s, fast):
    w = bpy.data.worlds.new('Sky')
    s.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = (0.45, 0.66, 1.0, 1)
    bg.inputs['Strength'].default_value = 0.9
    for name, energy, rot in (('Sun', 3.4, (50, 0, 140)), ('Fill', 0.6, (65, 0, -40))):
        li = bpy.data.lights.new(name, 'SUN')
        li.energy = energy
        li.angle = math.radians(6)
        o = bpy.data.objects.new(name, li)
        o.rotation_euler = tuple(math.radians(a) for a in rot)
        s.collection.objects.link(o)
    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0))
    gm = bpy.data.materials.new('Ground')
    gm.use_nodes = True
    gm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (*vkit.lin((104, 186, 84)), 1)
    gm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.95
    bpy.context.object.data.materials.append(gm)
    cam = bpy.data.cameras.new('Cam')
    cam.lens = 50
    co = bpy.data.objects.new('Cam', cam)
    s.collection.objects.link(co)
    s.camera = co
    s.render.engine = 'CYCLES'
    s.cycles.device = 'CPU'
    s.cycles.samples = 10 if fast else 28
    s.cycles.use_denoising = True
    s.cycles.max_bounces = 3
    s.view_settings.view_transform = 'Standard'
    s.view_settings.exposure = -0.1
    return co


def bounds(obs):
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for ob in obs:
        for c in ob.bound_box:
            w = ob.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def aim(co, lo, hi, yaw=-35, pitch=16, k=1.0):
    c = (lo + hi) / 2
    r = max((hi - lo).length * 0.5, 0.5) * 2.7 * k
    a, pt = math.radians(yaw), math.radians(pitch)
    eye = c + Vector((math.sin(a) * math.cos(pt), -math.cos(a) * math.cos(pt), math.sin(pt))) * r
    co.location = eye
    co.rotation_euler = (c - eye).to_track_quat('-Z', 'Y').to_euler()


def render(s, path, res):
    s.render.resolution_x = s.render.resolution_y = res
    s.render.filepath = path
    bpy.ops.render.render(write_still=True)


def build_one(mid, out, designs, no_render, fast):
    m = nature.MODELS[mid]
    d = os.path.join(out, mid)
    os.makedirs(d, exist_ok=True)
    s = reset()
    _MATS.clear()
    coll = bpy.data.collections.new(mid)
    s.collection.children.link(coll)
    obs, meshes, tris = build_meshes(mid, coll)
    export(d, mid, coll)
    lo, hi = bounds(obs)
    size = hi - lo
    if not no_render:
        co = stage(s, fast)
        aim(co, lo, hi)
        render(s, os.path.join(d, 'hero.png'), 400 if fast else 720)
    meta = dict(id=mid, game='Hatchery Heist', kind=m['kind'], note=m['note'], voxelStuds=m['voxel'],
                sizeStuds=[round(size.x, 2), round(size.z, 2), round(size.y, 2)], tris=tris,
                meshes=len(meshes), colours=sorted({x['color'] for x in meshes}))
    with open(os.path.join(d, 'meta.json'), 'w') as fh:
        json.dump(meta, fh, indent=1)
    if designs:
        dd = os.path.join(designs, design_path(m))
        os.makedirs(dd, exist_ok=True)
        for fn in (f'{mid}.glb', 'hero.png', 'meta.json'):
            if os.path.exists(os.path.join(d, fn)):
                shutil.copyfile(os.path.join(d, fn), os.path.join(dd, fn))
    R = np.array([x['center'] for x in meshes]), np.array([x['size'] for x in meshes])
    rlo = (R[0] - R[1] / 2).min(0)
    rhi = (R[0] + R[1] / 2).max(0)
    return dict(kind=m['kind'], voxel=m['voxel'], note=m['note'], tris=tris,
                size=[round(float(x), 3) for x in rhi - rlo], meshes=meshes)


def lineup(out, ids):
    """every model's hero render in a sheet, labelled"""
    from PIL import Image, ImageDraw
    tiles = []
    for mid in ids:
        f = os.path.join(out, mid, 'hero.png')
        if os.path.exists(f):
            im = Image.open(f).convert('RGB').resize((300, 300))
            ImageDraw.Draw(im).text((8, 6), mid, fill=(20, 20, 20))
            tiles.append(im)
    if not tiles:
        return
    cols = 6
    rows = -(-len(tiles) // cols)
    sh = Image.new('RGB', (300 * cols, 300 * rows), (255, 255, 255))
    for i, im in enumerate(tiles):
        sh.paste(im, ((i % cols) * 300, (i // cols) * 300))
    sh.save(os.path.join(out, 'lineup.png'), optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--only')
    ap.add_argument('--designs')
    ap.add_argument('--no-render', action='store_true')
    ap.add_argument('--fast', action='store_true')
    a = ap.parse_args()
    out = os.path.abspath(a.out)
    os.makedirs(out, exist_ok=True)
    ids = list(nature.MODELS)
    if a.only:
        want = a.only.split(',')
        bad = [w for w in want if w not in nature.MODELS]
        if bad:
            raise SystemExit(f'unknown models: {", ".join(bad)}')
        ids = [i for i in ids if i in want]
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    manifest = json.load(open(MANIFEST)) if os.path.exists(MANIFEST) else {}
    for mid in ids:
        entry = build_one(mid, out, a.designs, a.no_render, a.fast)
        manifest[mid] = entry
        print(f"{mid:20s} {entry['tris']:7d} tris  {len(entry['meshes']):2d} meshes  size {entry['size']}", flush=True)
    manifest = {k: manifest[k] for k in nature.MODELS if k in manifest}
    with open(MANIFEST, 'w') as fh:
        json.dump(manifest, fh, indent=1)
    if not a.no_render:
        lineup(out, ids)


if __name__ == '__main__':
    main()
