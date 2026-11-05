"""Review renders of the Golden Egg Shop, put together from shop.LAYOUT the way
the game places it.

    python3 tools/art/world/shopscene.py OUT_DIR [--mesh] [--fast]

Writes outside.png (from the yard, door side), inside.png (roof, ceiling and
front wall left off, looking in from above the door), left.png and right.png
(each display wall from the middle of the room) and glb/ShopInterior.glb
(the whole shop as one model, for the 3D viewer).

By default it uses the Parts version (what the game builds; run
shopexport.py first); --mesh uses the full voxel meshes instead.
"""
import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import build  # noqa: E402
import props  # noqa: E402
import shop  # noqa: E402
import vkit  # noqa: E402

ROOT = build.ROOT
KEEPER = '#C98E52'


class Kit:
    def __init__(self, coll, parts):
        self.coll, self.parts = coll, parts
        self.data = json.load(open(os.path.join(ROOT, 'build', 'world', 'shopart.json'))) if parts else {}
        self.cache, self.mats = {}, ({} if parts else vkit.materials())

    def source(self, pid):
        if pid in self.cache:
            return self.cache[pid]
        if self.parts:
            d = self.data[pid]
            ob = build.parts_prop(dict(d, id=pid), self.coll, self.mats)
            vs = d['voxel']
            ax, ay, az = d['anchor']
            ob.data.transform(Matrix.Translation(-Vector((ax * vs, az * vs, ay * vs))))
            obs = [ob]
        else:
            p = props.make(pid)
            ax, ay, az = p.anchor or (0, 0, 0)
            obs = []
            for name, anim, parent, pivot, g in p.parts:
                for ob in vkit.grid_objects(g, f'{pid}_{name}', self.coll, self.mats):
                    ob.data.transform(Matrix.Translation(-Vector((ax, ay, az))))
                    obs.append(ob)
        for ob in obs:
            ob.hide_render = True
            ob.hide_viewport = True
        self.cache[pid] = obs
        return obs

    def place(self, pid, at, turn, tag=''):
        out = []
        for src in self.source(pid):
            ob = bpy.data.objects.new(f'{pid}{tag}', src.data)
            ob.location = at
            ob.rotation_euler = (0, 0, math.radians(-turn))  # Roblox turn -> art frame (mirrored axes)
            self.coll.objects.link(ob)
            out.append(ob)
        return out


def assemble(kit, skip=()):
    placed = []
    for i, e in enumerate(shop.LAYOUT):
        t = e['type']
        if t == 'piece' and e['prop'] not in skip:
            placed += kit.place(e['prop'], e['at'], e['turn'], f'_{i}')
        elif t == 'display':
            placed += kit.place(e['plinth'], e['at'], e['turn'], f'_{i}')
            x, y, z = e['at']
            placed += kit.place(e['item'], (x, y, z + shop.PLINTH_TOP[e['plinth']]), e['turn'], f'_{i}i')
        elif t == 'keeper':
            # a stand-in block where the client draws the shopkeeper creature
            x, y, z = e['at']
            s = e['size']
            bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z + s / 2))
            ob = bpy.context.object
            ob.scale = (s * 0.8, s * 0.7, s)
            m = bpy.data.materials.new('keeper')
            m.use_nodes = True
            m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (*vkit.lin(vkit.hexrgb(KEEPER)), 1)
            ob.data.materials.append(m)
            placed.append(ob)
        elif t == 'light':
            li = bpy.data.lights.new(f'L{i}', 'POINT')
            li.energy = 60 * e['brightness'] * (e['range'] / 12)
            li.color = (1.0, 0.82, 0.55)
            li.shadow_soft_size = 0.4
            o = bpy.data.objects.new(f'L{i}', li)
            o.location = e['at']
            kit.coll.objects.link(o)
    return placed


def scene(fast):
    s = build.reset()
    coll = bpy.data.collections.new('Shop')
    s.collection.children.link(coll)
    co = build.stage(s, (40, 40, 20), fast)
    for o in list(s.collection.objects):
        if o.type == 'MESH':  # build.stage's ground plane: sandy yard colour instead
            m = o.data.materials[0]
            m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (*vkit.lin((222, 200, 150)), 1)
    return s, coll, co


def look(co, eye, at, lens=28):
    co.data.lens = lens
    co.location = Vector(eye)
    co.rotation_euler = (Vector(at) - Vector(eye)).to_track_quat('-Z', 'Y').to_euler()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--mesh', action='store_true')
    ap.add_argument('--fast', action='store_true')
    ap.add_argument('--only')
    a = ap.parse_args()
    out = os.path.abspath(a.out)
    os.makedirs(out, exist_ok=True)
    res = 720 if a.fast else 1280
    shots = {
        'outside': (dict(), (16, -46, 14), (0, 0, 7.5), 30),
        'inside': (dict(skip=('ShopRoof', 'ShopCeiling', 'ShopWallFront', 'ShopAwning', 'ShopSign', 'ShopChandelier')),
                   (0, -27, 21), (0, 1.5, 2.5), 26),
        'left': (dict(skip=('ShopRoof', 'ShopCeiling', 'ShopChandelier')), (7.5, -0.5, 5.6), (-14, 0.5, 4.2), 18),
        'right': (dict(skip=('ShopRoof', 'ShopCeiling', 'ShopChandelier')), (-7.5, -0.5, 5.6), (14, 0.5, 4.2), 18),
        'counter': (dict(skip=('ShopRoof', 'ShopChandelier')), (0, -8, 5.2), (0, 9, 4.0), 24),
        'door': (dict(skip=('ShopRoof',)), (0, -20, 5.5), (0, 0, 5), 26),
    }
    want = set(a.only.split(',')) if a.only else set(shots)
    for name, (kw, eye, at, lens) in shots.items():
        if name not in want:
            continue
        s, coll, co = scene(a.fast)
        kit = Kit(coll, not a.mesh)
        assemble(kit, **kw)
        if name != 'outside' and name != 'door':
            s.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.5
        s.render.resolution_x, s.render.resolution_y = res, res * 9 // 16
        look(co, eye, at, lens)
        s.render.filepath = os.path.join(out, f'{name}.png')
        bpy.ops.render.render(write_still=True)
        print('wrote', s.render.filepath, flush=True)


if __name__ == '__main__':
    main()
