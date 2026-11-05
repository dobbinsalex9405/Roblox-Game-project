"""Renders creatures standing in a row at their in-game sizes, for review.

    PYTHONPATH=/opt/bpy python3 tools/art/blender/lineup.py out.png --tier Common
    PYTHONPATH=/opt/bpy python3 tools/art/blender/lineup.py out.png --all

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
    ap.add_argument('--samples', type=int, default=48)
    a = ap.parse_args()
    cs = creatures(None if a.all else a.tier)
    cs.sort(key=lambda c: RANK.index(c.rarity))
    s = build.reset()
    tmp = tempfile.mkdtemp(prefix='lineup-')
    x, tallest, gap = 0.0, 0.0, 0.5
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
    cam.ortho_scale = width + 1.0
    target = Vector((width / 2, 0, tallest * 0.45))
    eye = target + Vector((0, 40, 40 * math.tan(math.radians(14))))
    co.location = eye
    co.rotation_euler = (target - eye).to_track_quat('-Z', 'Y').to_euler()
    s.render.resolution_x = 2000
    s.render.resolution_y = max(500, int(2000 * (tallest * 1.35 + 0.8) / (width + 1.0)))
    s.render.filepath = os.path.abspath(a.out)
    bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    main()
