"""Builds the Golden Egg Shop's props in Blender, like build.py does for the
world props: a polished voxel mesh (.glb, Draco), a review render, a render
of the Parts version the game builds (from build/world/shopart.json, so run
shopexport.py first), meta.json and a copy in the 3D design viewer, under
World/Hatchery Heist/Golden Egg Shop. --whole also writes the whole shop,
put together from shop.LAYOUT, as one model ("Golden Egg Shop (whole)").

The big shell pieces (walls, floor, ceiling, roof, shelves) and the whole
shop go to the viewer as their Parts version (what the game builds; a few
thousand boxes), because their 0.1-stud voxel meshes run to 30-140 MB. The
other props keep the voxel mesh, Draco-compressed with gltf-transform (npx).

    python3 tools/art/world/shopbuild.py OUT [--only ShopCounter] [--designs /mnt/project-files/designs] [--fast] [--whole]
"""
import argparse
import json
import math
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402

import build  # noqa: E402
import props  # noqa: E402
import shop  # noqa: E402
import shopscene  # noqa: E402

FOLDER = 'World/Hatchery Heist/Golden Egg Shop'
BIG = {'ShopFloor', 'ShopWallFront', 'ShopWallBack', 'ShopWallSide', 'ShopRoof', 'ShopGable', 'ShopCeiling', 'ShopShelf'}


def parts_glb(path, place):
    """exports the Parts version: `place(coll)` adds the objects"""
    build.reset()
    s = bpy.context.scene
    coll = bpy.data.collections.new('Parts')
    s.collection.children.link(coll)
    root = bpy.data.objects.new('root', None)
    coll.objects.link(root)
    for ob in place(coll):
        ob.parent = root
    root.rotation_euler = (0, 0, math.pi)
    bpy.context.view_layer.update()
    build.export_glb(path, coll)


def draco(path):
    tmp = path + '.tmp.glb'
    r = subprocess.run(['npx', '-y', '@gltf-transform/cli@4.1.1', 'draco', path, tmp], capture_output=True, text=True)
    if r.returncode == 0 and os.path.exists(tmp):
        os.replace(tmp, path)
    else:
        print('draco failed for', path, r.stderr[-400:], flush=True)
build.folder_of = lambda p: FOLDER + ('/Displays' if p.kind == 'shopdisplay' else '')


def whole(out, designs, fast):
    name = 'Golden Egg Shop (whole)'
    d = os.path.join(out, 'GoldenEggShop')
    os.makedirs(d, exist_ok=True)

    def place(coll):
        kit = shopscene.Kit(coll, parts=True)
        placed = shopscene.assemble(kit)
        for ob in list(coll.objects):
            if ob.hide_render:
                bpy.data.objects.remove(ob)
        for ob in placed:
            if ob.name not in coll.objects:
                coll.objects.link(ob)
        return [ob for ob in placed if ob.type == 'MESH']
    parts_glb(os.path.join(d, 'GoldenEggShop.glb'), place)
    draco(os.path.join(d, 'GoldenEggShop.glb'))
    s, coll, co = shopscene.scene(fast)
    shopscene.assemble(shopscene.Kit(coll, parts=False))
    s.render.resolution_x = s.render.resolution_y = 720 if fast else 1024
    shopscene.look(co, (16, -46, 14), (0, 0, 7.5), 30)
    s.render.filepath = os.path.join(d, 'hero.png')
    bpy.ops.render.render(write_still=True)
    meta = dict(id='GoldenEggShop', game='Hatchery Heist', kind='shop', direction='Storybook Farm centre',
                note='The whole walk-in Robux shop as the game builds it (Parts version; 30 x 24 studs, door toward the Golden Nest).',
                sizeStuds=[shop.W, shop.RIDGE + 2.5, shop.D], voxelStuds=0.1)
    with open(os.path.join(d, 'meta.json'), 'w') as fh:
        json.dump(meta, fh, indent=1)
    if designs:
        dd = os.path.join(designs, FOLDER, name)
        os.makedirs(dd, exist_ok=True)
        for fn in ('GoldenEggShop.glb', 'hero.png', 'meta.json'):
            shutil.copyfile(os.path.join(d, fn), os.path.join(dd, fn))
    print('whole shop ->', d, flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--only')
    ap.add_argument('--designs')
    ap.add_argument('--fast', action='store_true')
    ap.add_argument('--whole', action='store_true')
    a = ap.parse_args()
    out = os.path.abspath(a.out)
    os.makedirs(out, exist_ok=True)
    data = json.load(open(os.path.join(build.ROOT, 'build', 'world', 'shopart.json')))
    ids = sorted(pid for pid, v in props.REGISTRY.items() if v[1] in ('shop', 'shopdisplay'))
    if a.only:
        want = set(a.only.split(','))
        ids = [i for i in ids if i in want]
    for pid in ids:
        m = build.build_one(pid, out, None, a.fast, data)
        glb = os.path.join(out, pid, f'{pid}.glb')
        if pid in BIG:
            parts_glb(glb, lambda coll, pid=pid: [build.parts_prop(dict(data[pid], id=pid), coll, {})])
            m['meshNote'] = 'glb is the Parts version (what the game builds)'
        draco(glb)
        with open(os.path.join(out, pid, 'meta.json'), 'w') as fh:
            json.dump(m, fh, indent=1)
        if a.designs:
            dd = os.path.join(a.designs, build.folder_of(props.make(pid)), pid)
            os.makedirs(dd, exist_ok=True)
            for fn in (f'{pid}.glb', 'hero.png', 'parts.png', 'meta.json'):
                if os.path.exists(os.path.join(out, pid, fn)):
                    shutil.copyfile(os.path.join(out, pid, fn), os.path.join(dd, fn))
        print(f"{pid:24s} {m['meshTris']:8d} tris  parts {m['partsBoxes']:4d} boxes", flush=True)
    if a.whole:
        whole(out, a.designs, a.fast)


if __name__ == '__main__':
    main()
