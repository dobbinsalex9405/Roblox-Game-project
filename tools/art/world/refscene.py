"""Render one reference vignette per style direction.
PYTHONPATH=/opt/bpy python3 scene.py A out.png [--fast]"""
import sys
import os
import math
import time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa
from mathutils import Vector  # noqa
import vkit  # noqa
from vkit import Grid, materials, grid_objects  # noqa
import styles as A  # noqa

DESIGNS = '/mnt/project-files/designs/Creatures/Hatchery Heist/Common'


def setup_render(s, st, res, samples):
    w = bpy.data.worlds.new('Sky')
    s.world = w
    w.use_nodes = True
    nt = w.node_tree
    bg = nt.nodes['Background']
    tc = nt.nodes.new('ShaderNodeTexCoord')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    nt.links.new(tc.outputs['Generated'], sep.inputs[0])
    nt.links.new(sep.outputs['Z'], ramp.inputs['Fac'])
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (*st['sky_hor'], 1)
    ramp.color_ramp.elements[1].position = 0.12
    ramp.color_ramp.elements[1].color = (*st['sky_top'], 1)
    nt.links.new(ramp.outputs['Color'], bg.inputs['Color'])
    bg.inputs['Strength'].default_value = st['amb']
    sun = bpy.data.lights.new('Sun', 'SUN')
    sun.energy = st['sun']
    sun.color = st['sun_col']
    sun.angle = math.radians(6)
    so = bpy.data.objects.new('Sun', sun)
    so.rotation_euler = tuple(math.radians(a) for a in st['sun_rot'])
    s.collection.objects.link(so)
    s.render.engine = 'CYCLES'
    s.cycles.device = 'CPU'
    s.cycles.samples = samples
    s.cycles.use_denoising = True
    s.cycles.max_bounces = 4
    try:
        s.view_settings.view_transform = st.get('vt', 'Standard')
        if s.view_settings.view_transform == 'AgX':
            s.view_settings.look = st['look']
    except Exception as e:  # noqa
        print('colour mgmt', e)
        s.view_settings.view_transform = 'Standard'
    s.view_settings.exposure = st['exposure']
    s.render.resolution_x, s.render.resolution_y = res


def camera(s, eye, target, lens=32):
    cam = bpy.data.cameras.new('Cam')
    cam.lens = lens
    co = bpy.data.objects.new('Cam', cam)
    s.collection.objects.link(co)
    s.camera = co
    co.location = eye
    co.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat('-Z', 'Y').to_euler()
    return co


def creature(s, name, loc, yaw):
    p = os.path.join(DESIGNS, name, f'{name}.glb')
    if not os.path.exists(p):
        return
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=p)
    new = [o for o in bpy.data.objects if o not in before]
    roots = [o for o in new if o.parent is None]
    for r in roots:
        r.location = loc
        r.rotation_euler = (math.radians(90), 0, math.radians(yaw))
    for o in new:
        if o.animation_data:
            o.animation_data_clear()


def build(key):
    st = A.STYLES[key]
    g = Grid((-30, -16, -1), (30, 40, 12))
    t = time.time()
    A.ground(g, st, -30, -16, 30, 40)
    # path from the front up to the belt
    A.path(g, st, -1.6, -16, 1.6, 10.5)
    cx, cy, R = -13.0, 21.0, 11.0
    A.hub(g, st, cx, cy, R - 3.0)
    A.conveyor(g, st, cx, cy, R)
    # room corner, back right
    fz = A.room(g, st, 5, 11, 20, 26)
    A.cozy(g, st, 10.5, 20.5, fz)
    A.fence(g, st, 4, 20, 7.5)
    A.tree(g, st, -9.5, 3.5, seed=3)
    A.bush(g, st, -4.5, 9.0, r=1.1, seed=7)
    A.bush(g, st, 15.5, 4.0, r=1.0, seed=8)
    A.pedestal(g, st, 4.2, -0.5, egg_kind='moonlit')

    def avoid(x, y):
        if -2.2 < x < 2.2:
            return True
        if (x - cx) ** 2 + (y - cy) ** 2 < (R + 2.2) ** 2:
            return True
        if x > 4.5 and y > 10.5:
            return True
        if 2.8 < x < 5.8 and -2 < y < 1:
            return True
        return False
    A.tufts(g, st, -30, -16, 30, 40, 420, avoid=avoid)
    if st['key'] == 'C':
        A.glowshrooms(g, st, -26, -14, 26, 14, 30, avoid=avoid)
        A.flowers(g, st, -30, -16, 30, 40, 110, avoid=avoid)
    else:
        A.flowers(g, st, -30, -16, 30, 40, 230, avoid=avoid)
    print(key, 'voxels', g.count(), round(time.time() - t, 1), 's', flush=True)
    return st, g, fz


def main():
    key, out = sys.argv[1], sys.argv[2]
    fast = '--fast' in sys.argv
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    st, g, fz = build(key)
    mats = materials(rough=st['rough'], glow_strength=st['glow'])
    obs = grid_objects(g, 'scene', s.collection, mats)
    print('faces', sum(len(o.data.polygons) for o in obs) // 5, flush=True)
    creature(s, 'Chick', (6.3, -1.4, 0), 200)
    creature(s, 'Piglet', (14.0, 15.5, fz), 215)
    creature(s, 'Piglet', (-2.8, 2.5, 0), 160)
    setup_render(s, st, (960, 600) if fast else (1920, 1200), 16 if fast else 64)
    camera(s, (17.5, -17.0, 13.0), (-1.5, 9.0, 1.2), lens=30)
    s.render.filepath = out
    t = time.time()
    bpy.ops.render.render(write_still=True)
    print('render', round(time.time() - t, 1), 's')


if __name__ == '__main__':
    main()
