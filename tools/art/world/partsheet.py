"""One render of every prop's Parts version (what the game builds today), laid
out on a grid, for a quick look. Run export.py first.

    PYTHONPATH=/opt/bpy python3 tools/art/world/partsheet.py OUT.png [--only-floor 1] [--kind decor]
"""
import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
import build  # noqa: E402

ROOT = build.ROOT


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--kind')
    ap.add_argument('--floor', type=int)
    ap.add_argument('--samples', type=int, default=16)
    a = ap.parse_args()
    wa = json.load(open(os.path.join(ROOT, 'build', 'world', 'worldart.json')))
    import props  # noqa
    ids = []
    for pid in sorted(wa):
        p = props.REGISTRY[pid]
        kind, kw = p[1], p[4]
        if a.kind and kind != a.kind:
            continue
        if a.floor is not None and kw.get('floor') != a.floor:
            continue
        ids.append(pid)
    s = build.reset()
    cache = {}
    cols = max(1, math.ceil(math.sqrt(len(ids) * 1.6)))
    cell = 9.0
    for i, pid in enumerate(ids):
        ob = build.parts_prop(dict(wa[pid], id=pid), s.collection, cache)
        lo, hi = build.bounds([ob])
        cx, cy = (i % cols) * cell, -(i // cols) * cell
        ob.location = (cx - (lo.x + hi.x) / 2, cy - (lo.y + hi.y) / 2, -lo.z)
        cu = bpy.data.curves.new(pid, 'FONT')
        cu.body = pid
        cu.size = 0.6
        t = bpy.data.objects.new(pid + '_label', cu)
        t.location = (cx - 3.5, cy - 4.2, 0.02)
        mat = bpy.data.materials.new('label')
        mat.use_nodes = True
        mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.02, 0.02, 0.02, 1)
        cu.materials.append(mat)
        s.collection.objects.link(t)
    rows = math.ceil(len(ids) / cols)
    W, H = cols * cell, rows * cell
    co = build.stage(s, (W, H, 6), True)
    s.cycles.samples = a.samples
    co.data.type = 'ORTHO'
    co.data.ortho_scale = max(W, H * 1.25) * 1.05
    cx, cy = (cols - 1) * cell / 2, -(rows - 1) * cell / 2
    co.location = (cx, cy - 40, 45)
    from mathutils import Vector
    co.rotation_euler = (Vector((cx, cy, 0)) - co.location).to_track_quat('-Z', 'Y').to_euler()
    s.render.resolution_x = 2400
    s.render.resolution_y = int(2400 * min(1.6, (H * 0.8 + 6) / W))
    s.render.filepath = os.path.abspath(a.out)
    bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    main()
