"""Renders creatures standing in a row at their in-game sizes, for review.

    PYTHONPATH=/opt/bpy python3 tools/art/blender/lineup.py out.png --tier Common
    PYTHONPATH=/opt/bpy python3 tools/art/blender/lineup.py out.png --all
    PYTHONPATH=/opt/bpy python3 tools/art/blender/lineup.py out.png --only Calf,Foal

Same meshes as build.py, in their rest pose."""
import argparse
import math
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import build  # noqa: E402
from describe import RANK, creatures  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--tier', action='append')
    ap.add_argument('--all', action='store_true')
    ap.add_argument('--only', help='comma separated ids, drawn in this order')
    ap.add_argument('--samples', type=int, default=48)
    ap.add_argument('--angle', type=float, default=0, help='turn the camera this many degrees (3/4 view: 35)')
    a = ap.parse_args()
    only = a.only.split(',') if a.only else None
    cs = creatures(None if a.all or only else a.tier, set(only) if only else None)
    if only:
        cs.sort(key=lambda c: only.index(c.species))
    if not only:
        cs.sort(key=lambda c: RANK.index(c.rarity))
    s = build.reset()
    tmp = tempfile.mkdtemp(prefix='lineup-')
    x, tallest, gap = 0.0, 0.0, 0.5 + 2.0 * math.sin(math.radians(a.angle))
    for c in cs:
        coll = bpy.data.collections.new(c.species)
        s.collection.children.link(coll)
        meta, root, _, _ = build.creature_scene(c, tmp, coll)
        w = meta['sizeStuds'][0]
        x += w / 2
        root.location = (x, 0, 0)
        x += w / 2 + gap
        tallest = max(tallest, meta['sizeStuds'][1])
    width = x - gap
    fake = {'sizeStuds': [width, tallest, 2], 'rarity': 'Common'}
    co = build.stage(s, fake, False)
    s.cycles.samples = a.samples
    cam = co.data
    cam.type = 'ORTHO'
    turn = math.radians(a.angle)
    cam.ortho_scale = width * math.cos(turn) + 1.0 + 3.0 * math.sin(turn)
    target = Vector((width / 2, 0, tallest * 0.45))
    eye = target + Vector((40 * math.sin(turn), 40 * math.cos(turn), 40 * math.tan(math.radians(14))))
    co.location = eye
    co.rotation_euler = (target - eye).to_track_quat('-Z', 'Y').to_euler()
    s.render.resolution_x = 2000
    s.render.resolution_y = max(500, int(2000 * (tallest * 1.35 + 0.8) / cam.ortho_scale))
    s.render.filepath = os.path.abspath(a.out)
    bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    main()
