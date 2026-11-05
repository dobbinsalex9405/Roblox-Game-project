"""Review renders of the apartment towers, put together the way the game
places them (8 bases on a ring of radius 110, each facing the farm in the
middle; every tower piece on its floor's anchor).

    PYTHONPATH=/opt/bpy python3 tools/art/world/towerscene.py overview OUT.png
    PYTHONPATH=/opt/bpy python3 tools/art/world/towerscene.py cutaway OUT.png
    PYTHONPATH=/opt/bpy python3 tools/art/world/towerscene.py room OUT.png [--floor 4]

overview and cutaway use the Parts version (what the game builds), so run
export.py first; room uses the full voxel meshes of one floor. glb writes
the whole ten-floor tower with its decor, Parts version, as one light .glb
for the 3D viewer.
"""
import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Vector, Matrix  # noqa: E402
import build  # noqa: E402
import vkit  # noqa: E402
import props  # noqa: E402
import refscene  # noqa: E402
from styles import STYLES  # noqa: E402

ROOT = build.ROOT
RING, PLOTS, STOREY = 110.0, 8, 12.0
PIECES = ('Floor', 'Back', 'Left', 'Right', 'Front')
SHAFT_AT, LADDER_AT = (-20.5, 20.5), (25.2, 14.5)
CREATURES = ['Chick', 'Piglet', 'Bunny', 'Duckling', 'Lamb', 'CorgiPup', 'Hamster', 'RedPanda', 'Koala', 'Frog', 'Foal', 'Capybara',
             'Quokka', 'Fawn', 'GoatKid', 'Ladybug']


class Kit:
    """one mesh per prop (Parts or voxel), placed many times as linked copies"""

    def __init__(self, coll, parts=True):
        self.coll, self.parts = coll, parts
        self.wa = json.load(open(os.path.join(ROOT, 'build', 'world', 'worldart.json')))
        self.cache, self.mats = {}, ({} if parts else vkit.materials())

    def source(self, pid):
        if pid in self.cache:
            return self.cache[pid]
        if self.parts:
            d = self.wa[pid]
            ob = build.parts_prop(dict(d, id=pid), self.coll, self.mats)
            vs = d['voxel']
            if 'anchor' in d:
                ax, ay, az = d['anchor']
                off = Vector((ax * vs, az * vs, ay * vs))
            else:
                lo, hi = build.bounds([ob])
                off = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
            ob.data.transform(Matrix.Translation(-off))
            obs = [ob]
        else:
            p = props.make(pid)
            obs = []
            for name, anim, parent, pivot, g in p.parts:
                obs += vkit.grid_objects(g, f'{pid}_{name}', self.coll, self.mats)
            if p.anchor is None:
                lo, hi = build.bounds(obs)
                off = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
                for o in obs:
                    o.data.transform(Matrix.Translation(-off))
        for o in obs:
            o.hide_render = True
            o.hide_viewport = True
        self.cache[pid] = obs
        return obs

    def put(self, pid, loc, yaw=0.0):
        out = []
        for src in self.source(pid):
            o = src.copy()
            o.hide_render = o.hide_viewport = False
            o.location = loc
            o.rotation_euler = (0, 0, yaw)
            self.coll.objects.link(o)
            out.append(o)
        return out


def plot_frame(i):
    a = i / PLOTS * 2 * math.pi
    c = Vector((math.cos(a), math.sin(a), 0)) * RING
    return c, a - math.pi / 2


def local(c, th, x, y, z=0.0):
    return c + Vector((x * math.cos(th) - y * math.sin(th), x * math.sin(th) + y * math.cos(th), z))


def decor_layout(floor):
    """where the review renders put each floor's decor: beds on the left
    strip, food on the right, lights along the back, toys at the front;
    anything too big for a strip goes into a cell."""
    by = {'cozy': [], 'toys': [], 'lighting': [], 'food': []}
    for pid, (fn, kind, lo, hi, kw) in sorted(props.REGISTRY.items()):
        if kind == 'decor' and kw.get('floor') == floor and kw.get('zone') in by:
            by[kw['zone']].append((pid, hi[0] - lo[0], hi[1] - lo[1]))
    out, cells = [], [(-15, 15), (15, 15), (-5, 5), (5, 5), (15, 5), (-15, 5), (5, 15), (-5, 15)]
    slots = {
        'cozy': [((-21.4, 4.5), math.pi / 2), ((-21.4, 12.0), math.pi / 2)],
        'food': [((21.4, 3.0), -math.pi / 2), ((21.4, 8.0), -math.pi / 2), ((21.4, 19.5), -math.pi / 2)],
        'lighting': [((-11.0, 20.9), 0.0), ((-1.0, 20.9), 0.0), ((9.0, 20.9), 0.0)],
        'toys': [((-12.0, -1.3), 0.0), ((0.0, -1.3), 0.0), ((12.0, -1.3), 0.0)],
    }
    for zone, items in by.items():
        free = list(slots[zone])
        for pid, w, d in items:
            fits = d <= (2.8 if zone in ('toys', 'lighting') else 3.6) and w <= 7.5
            if free and fits:
                (x, y), yaw = free.pop(0)
                out.append((pid, x, y, yaw))
            elif cells:
                x, y = cells.pop(0)
                out.append((pid, x, y, 0.0))
    return out


def tower(kit, c, th, floors, decor=True, roof=True, creatures=0, seed=0):
    for n in range(1, floors + 1):
        z = (n - 1) * STOREY
        for piece in PIECES:
            kit.put(f'Tower{piece}{n}', local(c, th, 0, 0, z), th)
        if decor:
            for pid, x, y, yaw in decor_layout(n):
                kit.put(pid, local(c, th, x, y, z), th + yaw)
    top = floors * STOREY
    if roof:
        kit.put('TowerRoof', local(c, th, 0, 0, top), th)
    # elevator shaft from the ground to the roof, cab parked on floor 1, ladder up the right wall
    for k in range(int(top)):
        kit.put('ElevatorShaft', local(c, th, *SHAFT_AT, k), th)
    kit.put('ElevatorShaftTop', local(c, th, *SHAFT_AT, top), th)
    kit.put('ElevatorCab', local(c, th, SHAFT_AT[0], SHAFT_AT[1], 0.0), th)
    for k in range(int(top) - 1):
        kit.put("LadderSection", local(c, th, *LADDER_AT, k), th - math.pi / 2)
    kit.put("LadderTop", local(c, th, LADDER_AT[0], LADDER_AT[1], top - 1), th - math.pi / 2)


def creatures_in(c, th, floors, n_each, seed):
    import random
    rng = random.Random(seed)
    for n in range(1, floors + 1):
        cells = [(cx, cy) for cx in (-15, -5, 5, 15) for cy in (5, 15)]
        rng.shuffle(cells)
        for k in range(min(n_each, 8)):
            name = rng.choice(CREATURES)
            x, y = cells[k][0] + rng.uniform(-2.5, 2.5), cells[k][1] + rng.uniform(-2.5, 2.5)
            refscene.creature(bpy.context.scene, name, tuple(local(c, th, x, y, (n - 1) * STOREY)), math.degrees(th) + rng.uniform(-60, 60))


def base_plate(c, th, coll, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(c.x, c.y, -0.75))
    o = bpy.context.object
    o.scale = (64, 64, 0.3)
    o.rotation_euler = (0, 0, th)
    o.data.materials.append(mat)
    return o


def mat(name, hexs, rough=0.85):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = m.node_tree.nodes['Principled BSDF']
    bs.inputs['Base Color'].default_value = (*vkit.lin(vkit.hexrgb(hexs)), 1)
    bs.inputs['Roughness'].default_value = rough
    return m


def ground(size=900):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, -0.02))
    bpy.context.object.data.materials.append(mat('Grass', '#6DBE57', 0.95))


def farm_centre(kit):
    kit.put('GoldenNest', Vector((0, 0, 0)))
    for k in range(24):
        a = k * math.pi / 12
        kit.put('BeltRail', Vector((math.cos(a) * 22, math.sin(a) * 22, 0)), a + math.pi / 2)
    for k, egg in enumerate(['BasicEgg', 'MeadowEgg', 'MoonlitEgg', 'PremiumEgg'] * 2):
        a = k * math.pi / 4 + math.pi / 8
        p = Vector((math.cos(a) * 31, math.sin(a) * 31, 0))
        kit.put('EggPedestal', p, a + math.pi / 2)
        kit.put(egg, p + Vector((0, 0, 1.15)), a + math.pi / 2)
    farm = ['HayBaleBed', 'NestBox', 'TyreSwing', 'Seesaw', 'HangingLantern', 'FeedTrough', 'WaterBucket', 'GrainSack']
    trees = ['OakTree', 'AppleTree', 'BlossomTree', 'OakTreeAutumn', 'PineTree']
    for k in range(16):
        a = k * math.pi / 8 + math.pi / 16
        r = 50 + 6 * (k % 2)
        kit.put(trees[k % len(trees)], Vector((math.cos(a) * r, math.sin(a) * r, 0)), a)
        a2 = a + math.pi / 16
        kit.put(farm[k % len(farm)], Vector((math.cos(a2) * 40, math.sin(a2) * 40, 0)), a2 + math.pi / 2)
        kit.put('Bush', Vector((math.cos(a2) * 58, math.sin(a2) * 58, 0)), a2)


def render(s, out, res, samples):
    s.render.resolution_x, s.render.resolution_y = res
    s.cycles.samples = samples
    s.render.filepath = os.path.abspath(out)
    bpy.ops.render.render(write_still=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('mode', choices=['overview', 'cutaway', 'room', 'glb'])
    ap.add_argument('out')
    ap.add_argument('--floor', type=int, default=4)
    ap.add_argument('--samples', type=int, default=48)
    ap.add_argument('--fast', action='store_true')
    a = ap.parse_args()
    s = build.reset()
    st = STYLES['A']
    refscene.setup_render(s, st, (1600, 1000), a.samples)
    s.view_settings.exposure = st['exposure']
    coll = s.collection
    samples = 12 if a.fast else a.samples
    if a.mode == 'overview':
        kit = Kit(coll, parts=True)
        ground()
        plate = mat('Plate', '#E9DFC9')
        farm_centre(kit)
        heights = [10, 4, 6, 3, 8, 5, 2, 7]
        for i in range(PLOTS):
            c, th = plot_frame(i)
            base_plate(c, th, coll, plate)
            tower(kit, c, th, heights[i], decor=heights[i] <= 4)
        cam_target = Vector((0, 0, 20))
        refscene.camera(s, (-150, -265, 175), cam_target, lens=30)
        render(s, a.out, (1600, 1000), samples)
    elif a.mode == 'cutaway':
        kit = Kit(coll, parts=True)
        ground(400)
        c, th = Vector((0, 0, 0)), 0.0
        base_plate(c, th, coll, mat('Plate', '#E9DFC9'))
        tower(kit, c, th, 10)
        creatures_in(c, th, 10, 3, 5)
        refscene.camera(s, (-60, -150, 95), (0, 8, 62), lens=34)
        render(s, a.out, (1100, 1600), samples)
    elif a.mode == 'glb':
        out = bpy.data.collections.new('Tower')
        s.collection.children.link(out)
        kit = Kit(out, parts=True)
        tower(kit, Vector((0, 0, 0)), 0.0, 10)
        for obs in kit.cache.values():
            for o in obs:
                bpy.data.objects.remove(o)
        root = bpy.data.objects.new('ApartmentTower', None)
        out.objects.link(root)
        for o in list(out.objects):
            if o is not root:
                o.parent = root
        root.rotation_euler = (0, 0, math.pi)
        bpy.context.view_layer.update()
        build.export_glb(os.path.abspath(a.out), out)
    else:
        kit = Kit(coll, parts=False)
        ground(300)
        c, th, n = Vector((0, 0, 0)), 0.0, a.floor
        for piece in PIECES:
            kit.put(f'Tower{piece}{n}', Vector((0, 0, 0)))
        for pid, x, y, yaw in decor_layout(n):
            kit.put(pid, Vector((x, y, 0)), yaw)
        for k in range(12):
            kit.put('ElevatorShaft', Vector((*SHAFT_AT, k)))
        kit.put('ElevatorCab', Vector((*SHAFT_AT, 0)))
        for k in range(12):
            kit.put('LadderSection', Vector((*LADDER_AT, k - 1)), -math.pi / 2)
        creatures_in(c, th, 1, 8, 11)
        refscene.camera(s, (16, -24, 13), (-7, 11, 1.5), lens=24)
        render(s, a.out, (1600, 1000), samples)


if __name__ == '__main__':
    main()
