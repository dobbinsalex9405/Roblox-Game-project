"""No part that moves against the body shares a face plane with it.

A leg, wing, fin, tail, head or ears turning about its hinge keeps every face
whose normal lies along the hinge axis in the same plane. Where such a face
is flush with a body face facing the same way (a bunny's hind foot beside
its flank, kicking back in a hop), the two overlap in one plane while it
swings and flicker (Alex, Nov 5, Dutch Bunny). describe.py insets every
moving part (voxmesh MeshData.inset) so the body's face always wins. This
checks every creature's meshes, every moving part, against its body.

Run: python3 -m unittest discover -s tools/art/tests"""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'blender'))
sys.path.insert(0, os.path.join(HERE, '..'))

import describe  # noqa: E402

TOL = 1e-4  # studs: closer than this is the same plane


def planes(md):
    """{(axis, sign, offset): [(lo_u, lo_v, hi_u, hi_v)]} for every triangle
    of the mesh that lies flat in an axis plane."""
    out = {}
    for (a, b, c), n in zip(md.tris, md.tri_normals):
        if n is None:
            continue  # a face inside the part (a glow against its own solid): never seen
        pa, pb, pc = md.verts[a], md.verts[b], md.verts[c]
        for axis in range(3):
            if abs(pa[axis] - pb[axis]) < TOL and abs(pa[axis] - pc[axis]) < TOL:
                # winding (a, c, b) is outward in MeshData.quad; the normal's
                # sign along `axis` from the cross product
                u, v = [i for i in range(3) if i != axis]
                e1 = (pb[u] - pa[u], pb[v] - pa[v])
                e2 = (pc[u] - pa[u], pc[v] - pa[v])
                cross = e1[0] * e2[1] - e1[1] * e2[0]
                if abs(cross) < 1e-12:
                    break
                sign = 1 if cross > 0 else -1
                us = (pa[u], pb[u], pc[u])
                vs = (pa[v], pb[v], pc[v])
                key = (axis, sign, round(pa[axis] / TOL))
                out.setdefault(key, []).append((min(us), min(vs), max(us), max(vs)))
                break
    return out


def overlap(r, s, reach):
    return r[0] < s[2] + reach and s[0] < r[2] + reach and r[1] < s[3] + reach and s[1] < r[3] + reach


class MovingPartsNeverShareABodyPlane(unittest.TestCase):
    def test_every_creature(self):
        bad = []
        for c in describe.creatures():
            meta, _, parts = describe.describe(c)
            roles = {m['name']: describe.walkpose.role(m['name'], m['anim']) for m in meta['parts']}
            body = {}
            for part, _, meshes in parts:
                if part.name == 'body':
                    for kind, _, md, _ in meshes:
                        if kind != 'lod1':
                            for k, rs in planes(md).items():
                                body.setdefault(k, []).extend(rs)
            for part, _, meshes in parts:
                if roles[part.name] in describe.STILL_ROLES:
                    continue
                for kind, _, md, _ in meshes:
                    if kind == 'lod1':
                        continue
                    # how far a swing (up to about 0.7 rad) can slide a face
                    # along its own plane: the part's size
                    lo, hi = md.bounds()
                    reach = max(h - lw for lw, h in zip(lo, hi))
                    for k, rs in planes(md).items():
                        if k in body and any(overlap(r, s, reach) for r in rs for s in body[k]):
                            bad.append(f'{c.species} {part.name}')
                            break
        self.assertEqual(sorted(set(bad)), [], 'moving parts flush with a body face (they flicker as they swing)')


if __name__ == '__main__':
    unittest.main()
