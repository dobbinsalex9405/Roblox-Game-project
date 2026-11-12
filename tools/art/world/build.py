"""Builds Hatchery Heist's world props in Blender: a polished voxel mesh
(.glb, Draco compressed), a review render of the mesh, a render of the
Parts version the game builds today (from build/world/worldart.json, so run
export.py and giantexport.py first), meta.json, and a copy in the 3D design viewer's folders.

    PYTHONPATH=/opt/bpy python3 tools/art/world/build.py OUT [--only OakTree,Bush] [--designs /mnt/project-files/designs] [--fast] [--full]

Meshes are flat greedy quads (vkit.flat): light enough for the viewer and
under Roblox's 20k-triangle MeshPart cap. --full gives the heavy bevelled
pillow voxels instead.

OUT/<id>/ gets <id>.glb, hero.png, parts.png and meta.json; OUT/lineup.png
shows every prop's Parts version side by side.

Frames: props are modelled with the front at -y (art frame). The .glb faces
-Z like Roblox and the creature files: the mesh is turned 180 degrees about
the up axis before export, and glTF's Y-up conversion does the rest.
"""
import argparse
import json
import math
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
import numpy as np  # noqa: E402

import vkit  # noqa: E402
import props  # noqa: E402
import decor  # noqa: E402,F401
import apartment  # noqa: E402,F401
import tower  # noqa: E402,F401
import rooms  # noqa: E402,F401
import hub  # noqa: E402,F401
import giantegg  # noqa: E402,F401  (kind "event": the Giant Golden Egg)

ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))

FOLDER = {
    'tree': 'Nature/Hatchery Heist/Trees', 'bush': 'Nature/Hatchery Heist/Trees', 'stump': 'Nature/Hatchery Heist/Trees',
    'egg': 'Eggs/Hatchery Heist', 'event': 'Eggs/Hatchery Heist',
    'pedestal': 'World/Hatchery Heist/Egg Market', 'belt': 'World/Hatchery Heist/Egg Market', 'hub': 'World/Hatchery Heist/Egg Market',
    'elevator': 'World/Hatchery Heist/Elevator and ladder', 'ladder': 'World/Hatchery Heist/Elevator and ladder',
    'plaque': 'World/Hatchery Heist/Elevator and ladder',
    'building': 'World/Hatchery Heist/Farm hub/Buildings', 'hubprop': 'World/Hatchery Heist/Farm hub/Street props',
}
from tower import THEMES  # noqa: E402


def folder_of(p):
    if p.kind == 'decor':
        if not p.floor:
            return 'World/Hatchery Heist/Farm centre'
        return f'Decor and props/Hatchery Heist/{p.floor:02d} {THEMES[p.floor - 1]}'
    if p.kind == 'room':
        return f'Decor and props/Hatchery Heist/Tower interiors/{p.floor:02d} {THEMES[p.floor - 1]}'
    if p.kind == 'tower':
        if not p.floor:
            return 'World/Hatchery Heist/Apartment tower/Roof'
        return f'World/Hatchery Heist/Apartment tower/Floor {p.floor:02d} {THEMES[p.floor - 1]}'
    return FOLDER.get(p.kind, 'World/Hatchery Heist/Other')


HEAVY_TRIS = 600_000


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


def stage(s, size, fast):
    w = bpy.data.worlds.new('Sky')
    s.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = (0.42, 0.62, 1.0, 1)
    bg.inputs['Strength'].default_value = 0.85
    for name, energy, rot in (('Sun', 3.2, (48, 0, 150)), ('Fill', 0.6, (65, 0, -40))):
        li = bpy.data.lights.new(name, 'SUN')
        li.energy = energy
        li.angle = math.radians(8)
        o = bpy.data.objects.new(name, li)
        o.rotation_euler = tuple(math.radians(a) for a in rot)
        s.collection.objects.link(o)
    big = max(size)
    bpy.ops.mesh.primitive_plane_add(size=big * 30, location=(0, 0, 0))
    gm = bpy.data.materials.new('Ground')
    gm.use_nodes = True
    gm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (*vkit.lin((112, 190, 98)), 1)
    gm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.9
    bpy.context.object.data.materials.append(gm)
    cam = bpy.data.cameras.new('Cam')
    cam.lens = 50
    co = bpy.data.objects.new('Cam', cam)
    s.collection.objects.link(co)
    s.camera = co
    s.render.engine = 'CYCLES'
    s.cycles.device = 'CPU'
    s.cycles.samples = 12 if fast else 32
    s.cycles.use_denoising = True
    s.cycles.max_bounces = 4
    s.view_settings.view_transform = 'Standard'
    s.view_settings.exposure = -0.15
    return co


def aim(co, lo, hi, yaw=-35, pitch=22, k=1.0):
    lo, hi = Vector(lo), Vector(hi)
    c = (lo + hi) / 2
    r = max((hi - lo).length * 0.5, 0.5) * 2.9 * k
    a, pt = math.radians(yaw), math.radians(pitch)
    # front is -y: yaw 0 looks at the front
    eye = c + Vector((math.sin(a) * math.cos(pt), -math.cos(a) * math.cos(pt), math.sin(pt))) * r
    co.location = eye
    co.rotation_euler = (c - eye).to_track_quat('-Z', 'Y').to_euler()


def mesh_prop(p, coll, mats, light=False):
    """Pillow meshes (flat greedy quads when `light`), one object per part
    (and glow), parented to an empty."""
    root = bpy.data.objects.new(p.id, None)
    coll.objects.link(root)
    obs = []
    for name, anim, parent, pivot, g in p.parts:
        for ob in vkit.grid_objects(g, f'{p.id}_{name}', coll, mats, light=light):
            ob.parent = root
            obs.append(ob)
    return root, obs


def parts_prop(data, coll, mats_cache):
    """The Parts version, from worldart.json: one cube per box, Roblox frame
    (x, y up, z) -> Blender (x, z, y), the inverse of export.py's swap, so
    the front (-Z) faces -y like the mesh renders."""
    vs = data['voxel']
    verts, faces, mids = [], [], []
    for part in data['parts']:
        b = part['boxes']
        for i in range(0, len(b), 7):
            x, y, z, sx, sy, sz, ci = b[i:i + 7]
            x0, y0, z0 = x * vs, y * vs, z * vs
            x1, y1, z1 = (x + sx) * vs, (y + sy) * vs, (z + sz) * vs
            # Roblox -> Blender: (X, Y, Z) -> (X, Z, Y)
            cs = [(xx, zz, yy) for xx in (x0, x1) for yy in (y0, y1) for zz in (z0, z1)]
            n = len(verts)
            verts += cs
            for f in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
                faces.append(tuple(n + q for q in f))
                mids.append(int(ci) - 1)
    me = bpy.data.meshes.new(data.get('id', 'parts'))
    me.from_pydata(verts, [], faces)
    for i, hexs in enumerate(data['palette']):
        key = hexs
        if key not in mats_cache:
            m = bpy.data.materials.new(key)
            m.use_nodes = True
            bs = m.node_tree.nodes['Principled BSDF']
            rgb = vkit.lin(vkit.hexrgb(hexs.rstrip('*')))
            bs.inputs['Base Color'].default_value = (*rgb, 1)
            bs.inputs['Roughness'].default_value = 0.55
            if hexs.endswith('*'):
                bs.inputs['Emission Color'].default_value = (*rgb, 1)
                bs.inputs['Emission Strength'].default_value = 2.5
            mats_cache[key] = m
        me.materials.append(mats_cache[key])
    for poly, mi in zip(me.polygons, mids):
        poly.material_index = mi
    me.update()
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new('parts', me)
    coll.objects.link(ob)
    bev = ob.modifiers.new('bev', 'BEVEL')
    bev.width = min(0.04, vs * 0.15)
    bev.segments = 1
    return ob


def bounds(obs):
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for ob in obs:
        for c in ob.bound_box:
            w = ob.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def render(s, path, res):
    s.render.resolution_x = s.render.resolution_y = res
    s.render.filepath = path
    bpy.ops.render.render(write_still=True)


def export_glb(path, coll):
    for ob in bpy.context.scene.objects:
        ob.select_set(ob.name in coll.objects)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format='GLB', use_selection=True, export_yup=True, export_apply=True,
        export_draco_mesh_compression_enable=True, export_draco_mesh_compression_level=6,
        export_draco_position_quantization=14, export_draco_color_quantization=8,
        export_vertex_color='ACTIVE', export_animations=False, export_extras=False,
    )


def build_one(pid, out, designs, fast, worldart, full=False):
    p = props.make(pid)
    d = os.path.join(out, pid)
    os.makedirs(d, exist_ok=True)
    s = reset()
    coll = bpy.data.collections.new(pid)
    s.collection.children.link(coll)
    mats = vkit.materials()
    # flat greedy quads by default: a 0.1-stud pillow mesh runs to hundreds of
    # thousands of triangles for a building, far too heavy for the viewer and
    # for Roblox's 20k-triangle MeshPart cap. --full keeps the pillow look.
    root, obs = mesh_prop(p, coll, mats, light=not full)
    lo, hi = bounds(obs)
    size = hi - lo
    tris = sum(len(o.data.polygons) for o in obs) * 2
    # glb: turned to face -Z. A big flat prop (a 40-stud rug) makes a pillow
    # mesh of millions of triangles, too heavy for the 3D viewer: those ship
    # their Parts version instead, which is what the game shows anyway.
    glb_from = 'mesh'
    if tris > HEAVY_TRIS and pid in worldart:
        glb_from = 'parts'
        light = bpy.data.collections.new(pid + '_light')
        s.collection.children.link(light)
        pob = parts_prop(dict(worldart[pid], id=pid), light, {})
        pob.rotation_euler = (0, 0, math.pi)
        bpy.context.view_layer.update()
        export_glb(os.path.join(d, f'{pid}.glb'), light)
        for ob in list(light.objects):
            bpy.data.objects.remove(ob)
    else:
        root.rotation_euler = (0, 0, math.pi)
        bpy.context.view_layer.update()
        export_glb(os.path.join(d, f'{pid}.glb'), coll)
        root.rotation_euler = (0, 0, 0)
        bpy.context.view_layer.update()
    co = stage(s, size, fast)
    aim(co, lo, hi)
    render(s, os.path.join(d, 'hero.png'), 360 if fast else 640)
    # Parts version next to nothing else: hide the mesh, show the boxes
    if pid in worldart:
        for ob in obs:
            ob.hide_render = True
        pob = parts_prop(dict(worldart[pid], id=pid + '_parts'), s.collection, {})
        plo, phi = bounds([pob])
        aim(co, plo, phi)
        render(s, os.path.join(d, 'parts.png'), 360 if fast else 640)
    meta = dict(id=pid, game='Hatchery Heist', kind=p.kind, direction='Storybook Farm centre, cozy apartment towers', note=p.note,
                sizeStuds=[round(size.x, 2), round(size.z, 2), round(size.y, 2)], voxelStuds=vkit.VOX, meshTris=tris,
                partsVoxelStuds=worldart.get(pid, {}).get('voxel'), glbFrom=glb_from,
                partsBoxes=sum(len(pp['boxes']) // 7 for pp in worldart.get(pid, {}).get('parts', [])),
                parts=[x[0] for x in p.parts])
    if p.floor:
        meta['floor'] = p.floor
    if p.zone:
        meta['zone'] = p.zone
    with open(os.path.join(d, 'meta.json'), 'w') as fh:
        json.dump(meta, fh, indent=1)
    if designs:
        dd = os.path.join(designs, folder_of(p), pid)
        os.makedirs(dd, exist_ok=True)
        for fn in (f'{pid}.glb', 'hero.png', 'parts.png', 'meta.json'):
            if os.path.exists(os.path.join(d, fn)):
                shutil.copyfile(os.path.join(d, fn), os.path.join(dd, fn))
    return meta


def lineup(out, ids, cols=6):
    from PIL import Image, ImageDraw
    tiles = []
    for pid in ids:
        f = os.path.join(out, pid, 'parts.png')
        if os.path.exists(f):
            im = Image.open(f).convert('RGB').resize((320, 320))
            ImageDraw.Draw(im).text((8, 6), pid, fill=(20, 20, 20))
            tiles.append(im)
    if not tiles:
        return
    rows = -(-len(tiles) // cols)
    sh = Image.new('RGB', (320 * cols, 320 * rows), (255, 255, 255))
    for i, im in enumerate(tiles):
        sh.paste(im, ((i % cols) * 320, (i // cols) * 320))
    sh.save(os.path.join(out, 'lineup.png'), optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--only')
    ap.add_argument('--designs')
    ap.add_argument('--fast', action='store_true')
    ap.add_argument('--full', action='store_true', help='bevelled pillow voxels instead of flat quads (heavy)')
    a = ap.parse_args()
    out = os.path.abspath(a.out)
    os.makedirs(out, exist_ok=True)
    wa_path = os.path.join(ROOT, 'build', 'world', 'worldart.json')
    worldart = json.load(open(wa_path)) if os.path.exists(wa_path) else {}
    ga_path = os.path.join(ROOT, 'build', 'world', 'giantart.json')  # giantexport.py
    if os.path.exists(ga_path):
        worldart.update(json.load(open(ga_path)))
    ids = sorted(props.REGISTRY)
    if a.only:
        want = set(a.only.split(','))
        ids = [i for i in ids if i in want]
    for pid in ids:
        m = build_one(pid, out, a.designs, a.fast, worldart, a.full)
        print(f"{pid:24s} {m['meshTris']:8d} tris  parts {m['partsBoxes']:4d} boxes", flush=True)
    lineup(out, sorted(props.REGISTRY))


if __name__ == '__main__':
    main()
