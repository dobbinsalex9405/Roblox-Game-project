"""Review renders of the apartment upgrade path: one floor of the tower as the
game builds it (Parts versions from build/world/worldart.json, so run
export.py first), with its decor at every upgrade level from
config/towerDecor.luau's source (rooms_layout.py), creatures on the pads.

    PYTHONPATH=/opt/bpy python3 tools/art/world/roomscene.py OUT_DIR --floor 2 [--levels 0,1,2,3,4] [--fast]

Writes OUT_DIR/floor-NN-upgrade-K.png and OUT_DIR/floor-NN-path.png (the
levels side by side).
"""
import argparse
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
import build  # noqa: E402
import refscene  # noqa: E402
import towerscene as ts  # noqa: E402
import rooms_layout as rl  # noqa: E402
from styles import STYLES  # noqa: E402
from tower import THEMES  # noqa: E402

CREATURES = ['Chick', 'Piglet', 'Bunny', 'Duckling', 'Lamb', 'Hamster', 'Frog', 'Ladybug']


def put(kit, it):
    """one placed item: base-local X, Z -> art x, y; Roblox yaw -> Blender"""
    obs = kit.put(it['prop'], Vector((it['x'], it['z'], it['y'])), math.radians(-it['yaw']))
    for o in obs:
        o.scale = (it['scale'],) * 3
    return obs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--floor', type=int, default=2)
    ap.add_argument('--levels', default='0,1,2,3,4')
    ap.add_argument('--fast', action='store_true')
    ap.add_argument('--res', default='1200x750')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    s = build.reset()
    st = STYLES['A']
    W, H = (int(v) for v in a.res.split('x'))
    refscene.setup_render(s, st, (W, H), 16 if a.fast else 40)
    s.view_settings.exposure = st['exposure']
    kit = ts.Kit(s.collection, parts=True)
    ts.ground(300)
    n = a.floor
    for piece in ts.PIECES:
        kit.put(f'Tower{piece}{n}', Vector((0, 0, 0)))
    # the next floor's slab is this room's ceiling
    kit.put(f'TowerFloor{min(n + 1, 10)}' if n < 10 else 'TowerRoof', Vector((0, 0, ts.STOREY)))
    for k in range(12):
        kit.put('ElevatorShaft', Vector((*ts.SHAFT_AT, k)))
    kit.put('ElevatorCab', Vector((*ts.SHAFT_AT, 0)))
    for k in range(12):
        kit.put('LadderSection', Vector((*ts.LADDER_AT, k - 1)), -math.pi / 2)
    for i, (x, z) in enumerate(rl.PADS):
        refscene.creature(s, CREATURES[i], (x, z, 0.45), 180 + (i * 37) % 60 - 30)
    # the grey pads, as the game draws them until the beds come
    pad_mat = ts.mat('Pad', '#968C78')
    pads = []
    for x, z in rl.PADS:
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, z, 0.2))
        o = bpy.context.object
        o.scale = (6, 6, 0.4)
        o.data.materials.append(pad_mat)
        pads.append(o)
    sets = rl.room_set(n)
    by_level = {k: [o for it in items for o in put(kit, it)] for k, items in sets.items()}
    # Roblox lights a room from the sky ambient as well: a soft area light
    # under the ceiling stands in for that; bought lights add warm points.
    amb = bpy.data.lights.new('Ambient', 'AREA')
    amb.energy, amb.size, amb.color = 2600, 40, (1.0, 0.97, 0.92)
    ao = bpy.data.objects.new('Ambient', amb)
    ao.location = (0, 10, 10.8)
    s.collection.objects.link(ao)
    warm = []
    if n > 1:
        for x, z in rl.LIGHTS:
            li = bpy.data.lights.new('Warm', 'POINT')
            li.energy, li.color, li.shadow_soft_size = 260, (1.0, 0.82, 0.55), 1.0
            o = bpy.data.objects.new('Warm', li)
            o.location = (x, z, 8.2)
            s.collection.objects.link(o)
            warm.append(o)
    # a player's view: standing inside by the balcony, under the ceiling
    refscene.camera(s, (17, -2.2, 7.5), (-6, 14, 1.8), lens=16)
    levels = [int(v) for v in a.levels.split(',')]
    if n == 1:
        levels = [0]
    shots = []
    for lv in levels:
        for k, obs in by_level.items():
            for o in obs:
                o.hide_render = k > lv
        for o in pads:
            o.hide_render = lv >= 1 and n > 1
        for o in warm:
            o.hide_render = lv < 3
        path = os.path.join(a.out, f'floor-{n:02d}-upgrade-{lv}.png')
        ts.render(s, path, (W, H), 16 if a.fast else 40)
        shots.append((lv, path))
    from PIL import Image, ImageDraw
    names = rl.UPGRADES[n]['names'] if n > 1 else ()
    tw, th = W // 2, H // 2
    sheet = Image.new('RGB', (tw * min(len(shots), 3), (th + 28) * math.ceil(len(shots) / 3)), 'white')
    for i, (lv, pth) in enumerate(shots):
        im = Image.open(pth).convert('RGB').resize((tw, th))
        x, y = (i % 3) * tw, (i // 3) * (th + 28)
        sheet.paste(im, (x, y + 28))
        label = f'Floor {n} {THEMES[n - 1]}: ' + ('bare room' if lv == 0 and n > 1 else 'starter room' if n == 1 else f'upgrade {lv}, {names[lv - 1]}')
        ImageDraw.Draw(sheet).text((x + 8, y + 8), label, fill=(20, 20, 20))
    sheet.save(os.path.join(a.out, f'floor-{n:02d}-path.png'))


if __name__ == '__main__':
    main()
