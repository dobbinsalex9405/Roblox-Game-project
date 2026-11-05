"""Renders the farm hub as the game lays it out: every piece in
config/atmosphere.luau `scenery.hub`, in its Parts version (what the game
builds today, from build/world/worldart.json, so run export.py first),
around the Golden Nest and the two-lane belt, with the paths, the base
fronts and a stand-in for the shop's plot.

    PYTHONPATH=/opt/bpy python3 tools/art/world/hubscene.py OUT_DIR [--fast]

Writes OUT_DIR/hub-overview.png (from above) and hub-walk-*.png (eye level,
from the market's edge). Roblox frame -> Blender: (x, y, z) -> (x, -z, y).
"""
import argparse
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import vkit  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
CONFIG = os.path.join(ROOT, 'games', 'hatchery-heist', 'config', 'atmosphere.luau')


def read_layout():
    """the hub block of atmosphere.luau, read with a few patterns (it is
    plain data: numbers, strings and short tables)"""
    src = open(CONFIG).read()
    hub = src[src.index('\t\thub = {'):]
    hub = hub[:hub.index('\n\t\t},\n')]

    def num(key, block):
        return float(re.search(key + r'\s*=\s*([-\d.]+)', block).group(1))

    def block(key):
        m = re.search(r'\b' + key + r'\s*=\s*\{([^\n]*)\}', hub)
        return m.group(1)
    out = dict(pathWidth=num('pathWidth', hub))
    shop = block('shop')
    out['shop'] = {k: num(k, shop) for k in ('angle', 'radius', 'width', 'depth')}
    arch = block('arch')
    out['arch'] = dict(id=re.search(r'id = "(\w+)"', arch).group(1), radius=num('radius', arch))
    lamps = re.search(r'lamps = \{ id = "(\w+)", radii = \{([^}]*)\}, side = ([-\d.]+)', hub)
    out['lamps'] = dict(id=lamps.group(1), radii=[float(v) for v in lamps.group(2).split(',') if v.strip()], side=float(lamps.group(3)))
    sp = block('signposts')
    out['signposts'] = dict(id=re.search(r'id = "(\w+)"', sp).group(1), radius=num('radius', sp), side=num('side', sp))
    out['pieces'] = []
    for m in re.finditer(r'\{ id = "(\w+)", angle = ([-\d.]+), radius = ([-\d.]+)(?:, yaw = ([-\d.]+))? \}', hub):
        out['pieces'].append(dict(id=m.group(1), angle=float(m.group(2)), radius=float(m.group(3)), yaw=float(m.group(4) or 0)))
    return out


class Scene:
    """boxes in Roblox world coordinates, gathered per colour, one mesh"""

    def __init__(self):
        self.verts, self.faces, self.mats = [], [], []
        self.mat_index = {}

    def mat(self, hexs):
        if hexs not in self.mat_index:
            self.mat_index[hexs] = len(self.mat_index)
        return self.mat_index[hexs]

    def box(self, corners, hexs):
        """corners: 8 Roblox-frame points in the order x0y0z0, x0y0z1,
        x0y1z0, x0y1z1, x1y0z0, ... (x outer, z inner)"""
        n = len(self.verts)
        for (x, y, z) in corners:
            self.verts.append((x, -z, y))
        for f in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            self.faces.append(tuple(n + q for q in f))
            self.mats.append(self.mat(hexs))

    def prop(self, data, pos, angle_deg, yaw_deg=0.0, face_centre=True):
        """place a worldart prop at pos (Roblox x, y, z), its front (-Z)
        facing the map centre, then turned yaw_deg"""
        vs = data['voxel']
        a = math.radians(angle_deg)
        if face_centre:
            right = (math.sin(a), 0, -math.cos(a))
            back = (math.cos(a), 0, math.sin(a))
        else:
            right, back = (1, 0, 0), (0, 0, 1)
        if yaw_deg:
            t = math.radians(yaw_deg)
            r2 = tuple(right[i] * math.cos(t) - back[i] * math.sin(t) for i in range(3))
            b2 = tuple(right[i] * math.sin(t) + back[i] * math.cos(t) for i in range(3))
            right, back = r2, b2

        def w(x, y, z):
            return (pos[0] + x * right[0] + z * back[0], pos[1] + y, pos[2] + x * right[2] + z * back[2])
        for part in data['parts']:
            b = part['boxes']
            for i in range(0, len(b), 7):
                x, y, z, sx, sy, sz, ci = b[i:i + 7]
                x0, y0, z0 = x * vs, y * vs, z * vs
                x1, y1, z1 = (x + sx) * vs, (y + sy) * vs, (z + sz) * vs
                cs = [w(xx, yy, zz) for xx in (x0, x1) for yy in (y0, y1) for zz in (z0, z1)]
                self.box(cs, data['palette'][int(ci) - 1])

    def slab(self, cx, cz, angle_deg, w, d, y0, y1, hexs):
        a = math.radians(angle_deg)
        right = (math.sin(a), -math.cos(a))
        back = (math.cos(a), math.sin(a))
        cs = []
        for xx in (-w / 2, w / 2):
            for yy in (y0, y1):
                for zz in (-d / 2, d / 2):
                    cs.append((cx + xx * right[0] + zz * back[0], yy, cz + xx * right[1] + zz * back[1]))
        self.box(cs, hexs)

    def build(self, coll):
        me = bpy.data.meshes.new('hub')
        me.from_pydata(self.verts, [], self.faces)
        for hexs in sorted(self.mat_index, key=self.mat_index.get):
            m = bpy.data.materials.new(hexs)
            m.use_nodes = True
            bs = m.node_tree.nodes['Principled BSDF']
            rgb = vkit.lin(vkit.hexrgb(hexs.rstrip('*')))
            bs.inputs['Base Color'].default_value = (*rgb, 1)
            bs.inputs['Roughness'].default_value = 0.6
            if hexs.endswith('*'):
                bs.inputs['Emission Color'].default_value = (*rgb, 1)
                bs.inputs['Emission Strength'].default_value = 2.5
            me.materials.append(m)
        for poly, mi in zip(me.polygons, self.mats):
            poly.material_index = mi
        me.update()
        import bmesh
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new('hub', me)
        coll.objects.link(ob)
        return ob


def polar(angle_deg, radius, side=0.0):
    a = math.radians(angle_deg)
    return (math.cos(a) * radius - math.sin(a) * side, math.sin(a) * radius + math.cos(a) * side)


def compose(layout, art):
    s = Scene()
    # ground, paths, plaza and the base fronts
    s.slab(0, 0, 0, 260, 260, -1.0, 0.0, '6CC64B')
    for k in range(8):
        ang = k * 45
        cx, cz = polar(ang, (29 + 78) / 2)
        s.slab(cx, cz, ang, layout['pathWidth'], 78 - 29, 0.0, 0.15, 'D8B07A')
        bx, bz = polar(ang, 78 + 32)
        s.slab(bx, bz, ang, 64, 64, 0.0, 0.3, '9A8F7C')
    # the market: nest and the two belt lanes
    s.prop(art['GoldenNest'], (0, 0, 0), 0, face_centre=False)
    for r in (22.0, 27.5):
        for i in range(48):
            ang = i * 7.5
            cx, cz = polar(ang, r)
            s.slab(cx, cz, ang, 0.9 * 2 * math.pi * r / 48, 3.2, 1.0, 1.35, 'C98E52')
            s.slab(cx, cz, ang, 0.5 * 2 * math.pi * r / 48, 2.4, 0.0, 1.0, '8B5A33')
    # the shop's plot (built by its own thread): a plain stand-in
    sh = layout['shop']
    cx, cz = polar(sh['angle'], sh['radius'])
    s.slab(cx, cz, sh['angle'], sh['width'], sh['depth'], 0.0, 12.0, 'F2E3C8')
    s.slab(cx, cz, sh['angle'], sh['width'] + 1.6, sh['depth'] + 2.8, 12.0, 14.0, 'D2483D')
    # arches, lamps, signposts, pieces
    for k in range(8):
        ang = k * 45
        ax, az = polar(ang, layout['arch']['radius'])
        # the arch spans the path: its width runs across the radius
        s.prop(art[layout['arch']['id']], (ax, 0, az), ang)
        for r in layout['lamps']['radii']:
            for sd in (-1, 1):
                lx, lz = polar(ang, r, sd * layout['lamps']['side'])
                s.prop(art[layout['lamps']['id']], (lx, 0, lz), ang)
        sx, sz = polar(ang, layout['signposts']['radius'], -layout['signposts']['side'])
        s.prop(art[layout['signposts']['id']], (sx, 0, sz), ang)
    for p in layout['pieces']:
        x, z = polar(p['angle'], p['radius'])
        s.prop(art[p['id']], (x, 0, z), p['angle'], p['yaw'])
    return s


def camera(scene, eye, target, lens=35):
    cam = bpy.data.cameras.new('Cam')
    cam.lens = lens
    cam.clip_end = 2000
    co = bpy.data.objects.new('Cam', cam)
    scene.collection.objects.link(co)
    scene.camera = co
    e, t = Vector(eye), Vector(target)
    co.location = e
    co.rotation_euler = (t - e).to_track_quat('-Z', 'Y').to_euler()
    return co


def bl(x, y, z):
    """Roblox point -> Blender"""
    return (x, -z, y)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--fast', action='store_true')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    art = json.load(open(os.path.join(ROOT, 'build', 'world', 'worldart.json')))
    layout = read_layout()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    coll = bpy.data.collections.new('hub')
    sc.collection.children.link(coll)
    compose(layout, art).build(coll)
    w = bpy.data.worlds.new('Sky')
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.42, 0.62, 1.0, 1)
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.9
    li = bpy.data.lights.new('Sun', 'SUN')
    li.energy = 3.4
    li.angle = math.radians(6)
    so = bpy.data.objects.new('Sun', li)
    so.rotation_euler = (math.radians(42), 0, math.radians(150))
    sc.collection.objects.link(so)
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 16 if a.fast else 48
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 4
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.exposure = -0.1
    shots = [
        ('hub-overview', bl(-30, 125, 105), bl(0, -4, 10), 30, (1600, 1100)),
        # eye level from the market's edge (a player is 5 tall; camera just behind and above)
        ('hub-walk-barn', bl(polar(45, 33)[0], 6.5, polar(45, 33)[1]), bl(polar(67.5, 56)[0], 8, polar(67.5, 56)[1]), 20, (1280, 800)),
        ('hub-walk-stalls', bl(polar(90, 33)[0], 6.5, polar(90, 33)[1]), bl(polar(112.5, 48)[0], 5, polar(112.5, 48)[1]), 20, (1280, 800)),
        ('hub-walk-windmill', bl(polar(180, 33)[0], 6.5, polar(180, 33)[1]), bl(polar(160, 50)[0], 8, polar(160, 50)[1]), 20, (1280, 800)),
        ('hub-walk-silo', bl(polar(225, 33)[0], 6.5, polar(225, 33)[1]), bl(polar(205, 50)[0], 7, polar(205, 50)[1]), 20, (1280, 800)),
        ('hub-walk-pond', bl(polar(315, 33)[0], 6.5, polar(315, 33)[1]), bl(polar(300, 54)[0], 2, polar(300, 54)[1]), 20, (1280, 800)),
    ]
    for name, eye, target, lens, res in shots:
        camera(sc, eye, target, lens)
        sc.render.resolution_x, sc.render.resolution_y = res
        if a.fast:
            sc.render.resolution_x //= 2
            sc.render.resolution_y //= 2
        sc.render.filepath = os.path.join(a.out, name + '.png')
        bpy.ops.render.render(write_still=True)
        print('wrote', sc.render.filepath, flush=True)


if __name__ == '__main__':
    main()
