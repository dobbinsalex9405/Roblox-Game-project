"""Which creatures' uploaded FBX carries a baked walk pose.

Until Nov 12 build.py wrote the FBX with the scene evaluated at the walk
clip's first frame (its NLA tracks live), and Roblox's importer baked that
pose into the meshes. A creature is dirty when any part is turned, or moved
against the body, at that frame. A lift or slide of the whole body moves
every piece together and is harmless (the game places pieces by their
listed centres). Blender-free: the same formulas as build.pose_fn('walk').

    python3 tools/art/blender/baked_pose.py [--only A,B] [--json OUT]
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))

from describe import creatures, parent_of  # noqa: E402
import rig  # noqa: E402
import walkpose  # noqa: E402

EPS = 1e-6


def frame_one(c):
    """{part: (rx, ry, rz, dx, dy)} of the parts the walk clip's first frame
    moves, as build.pose_fn('walk') at t = 0 (moving = 1)."""
    lo, hi = c.bounds()
    height = (hi[2] - lo[2]) * c.voxel
    gait = rig.gait(c) or 'trot'
    anims = {p.name: walkpose.role(p.name, 'body' if p.name == 'body' else p.anim) for p in c.parts}
    legged = any(walkpose.is_leg(a) for a in anims.values())
    moved = {}
    for name, anim in anims.items():
        if anim in ('wingL', 'wingR', 'orbit', 'ears'):
            continue  # sin(0) = 0 for their clips at t = 0
        rx, ry, rz, dx, dy = walkpose.pose(gait, anim, 0.0, 1.0, height, legged)
        if anim == 'body':
            dx = dy = 0.0  # moves every piece together: harmless
        if max(abs(rx), abs(ry), abs(rz), abs(dx), abs(dy)) > EPS:
            moved[name] = [round(v, 4) for v in (rx, ry, rz, dx, dy)]
    return gait, moved


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--only')
    ap.add_argument('--json')
    a = ap.parse_args()
    only = set(a.only.split(',')) if a.only else None
    out = {}
    for c in creatures(only=only):
        gait, moved = frame_one(c)
        out[c.species] = {'gait': gait, 'dirty': bool(moved), 'parts': moved}
    if a.json:
        with open(a.json, 'w') as f:
            json.dump(out, f, indent=1, sort_keys=True)
    dirty = sorted(s for s, v in out.items() if v['dirty'])
    print(f'{len(dirty)} of {len(out)} dirty')
    for s in dirty:
        print(s, out[s]['gait'], ','.join(out[s]['parts']))


if __name__ == '__main__':
    main()
