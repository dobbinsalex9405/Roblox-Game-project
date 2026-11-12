"""Checks every built creature's FBX is at rest before it goes to Roblox.

Opens each OUT/<id>/<id>.fbx the way an importer would and compares every
mesh's centre with the centre meta.json lists for it (the rest pose, which
CreatureMeshes is generated from). A mesh more than TOLERANCE away means
the FBX carries a pose: Roblox would bake it into the meshes and the game
would draw that part out of place (Nov 12: 199 creatures went up mid-step;
muting the clips alone still left the joints at their last pose).

    PYTHONPATH=/opt/bpy python3 tools/art/blender/fbx_check.py OUT [--only Ant,Bunny]

Exits 1 and names each creature and mesh that misses. The upload workflow
runs it between the build and the upload."""
import argparse
import json
import os
import sys

import bpy
from mathutils import Vector

TOLERANCE = 0.01  # studs; meta.json rounds centres to 0.0001


def listed(meta):
    """{mesh name: game-frame centre} for every mesh meta.json lists."""
    out = {}
    for p in meta['parts']:
        for m in p['meshes']:
            out[m['name']] = m['center']
        if p.get('lod1'):
            out[p['lod1']['name']] = p['lod1']['center']
    return out


def landed(fbx):
    """{mesh name: game-frame centre} of every mesh in the FBX, imported
    with the axes build.py writes it with (front -Z, Y up)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=fbx, axis_forward='-Z', axis_up='Y')
    out = {}
    for ob in bpy.context.scene.objects:
        if ob.type != 'MESH':
            continue
        cs = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
        mid = [(min(c[k] for c in cs) + max(c[k] for c in cs)) / 2 for k in range(3)]
        # Blender (x, y, z) = game (x, -z, y)
        out[ob.name] = (mid[0], mid[2], -mid[1])
    return out


def check(out_dir, species):
    """Problems with one creature's FBX, as strings (empty when at rest)."""
    d = os.path.join(out_dir, species)
    meta = json.load(open(os.path.join(d, 'meta.json')))
    want = listed(meta)
    got = landed(os.path.join(d, f'{species}.fbx'))
    bad = []
    for name, c in sorted(want.items()):
        if name not in got:
            bad.append(f'{species}: {name} is missing from the FBX')
            continue
        miss = sum((got[name][k] - c[k]) ** 2 for k in range(3)) ** 0.5
        if miss > TOLERANCE:
            bad.append(f'{species}: {name} sits {miss:.3f} studs from its rest centre')
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--only')
    a = ap.parse_args()
    only = set(a.only.split(',')) if a.only else None
    names = sorted(
        n for n in os.listdir(a.out)
        if os.path.exists(os.path.join(a.out, n, f'{n}.fbx')) and (only is None or n in only)
    )
    bad = []
    for n in names:
        bad += check(a.out, n)
    for b in bad:
        print(b)
    print(f'{len(names)} FBX checked, {len({b.split(":")[0] for b in bad})} not at rest')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
