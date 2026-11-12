"""The viewer's blink closes every creature's eyes where they are.

build.py squashes each `blink` part (the eyes) to a sliver and back in its
clips. The squash is about the eyes' joint, which sits at the head's hinge,
so without a matching lift it dragged the eyes down or up to the hinge's
height, out of the face and often outside the body (Alex, Nov 12). This
checks every creature: at every key of the blink the squashed eyes stay
inside the space the open eyes fill, centred on the same point.

Run: python3 -m unittest discover -s tools/art/tests"""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'blender'))
sys.path.insert(0, os.path.join(HERE, '..'))

import blink  # noqa: E402
import describe  # noqa: E402

TOL = 1e-6  # studs
FPS = 30  # build.py


def eye_spans():
    """{(species, part): [(low, high)]}: each blink part's close-up meshes'
    heights above its joint (game y is the height the squash acts on)."""
    out = {}
    for c in describe.creatures():
        meta, _, parts = describe.describe(c)
        roles = {m['name']: describe.walkpose.role(m['name'], m['anim']) for m in meta['parts']}
        for part, pivot, meshes in parts:
            if roles[part.name] != 'blink':
                continue
            spans = []
            for kind, _, md, _ in meshes:
                if kind != 'lod1':
                    lo, hi = md.bounds()
                    spans.append((lo[1] - pivot[1], hi[1] - pivot[1]))
            if spans:
                out[(c.species, part.name)] = spans
    return out


def leaves(lo, hi, key):
    """How far the eyes squashed by `key` stick out of their open span."""
    _, sc, lift = key
    a, b = lift + sc * lo, lift + sc * hi
    return max(0.0, lo - a, b - hi)


class Keys(unittest.TestCase):
    def test_closes_about_the_middle(self):
        # eyes 0.1 tall, 0.6 above the hinge (a typical head)
        for f, sc, lift in blink.keys(FPS, 0.65):
            self.assertAlmostEqual(lift + sc * 0.65, 0.65)
            self.assertLessEqual(leaves(0.6, 0.7, (f, sc, lift)), TOL)

    def test_a_squash_about_the_hinge_would_leave(self):
        # the old blink: no lift; the shut eyes sat 0.6 studs lower
        self.assertGreater(leaves(0.6, 0.7, (0, min(blink.SHAPE), 0.0)), 0.5)

    def test_shuts_and_opens(self):
        scales = [sc for _, sc, _ in blink.keys(FPS, 0)]
        self.assertEqual(scales[0], 1.0)
        self.assertEqual(scales[-1], 1.0)
        self.assertLess(min(scales), 0.2)
        frames = [f for f, _, _ in blink.keys(FPS, 0)]
        self.assertEqual(frames, list(range(frames[0], frames[0] + len(frames))))
        # inside the shorter (walk) clip
        self.assertLess(frames[-1], 2.0 * FPS)


class EveryCreature(unittest.TestCase):
    def test_eyes_stay_where_they_are(self):
        spans = eye_spans()
        self.assertGreater(len(spans), 400)
        bad = []
        for (species, part), ss in sorted(spans.items()):
            lo = min(a for a, _ in ss)
            hi = max(b for _, b in ss)
            keys = blink.keys(FPS, blink.middle(ss))
            worst = max(leaves(lo, hi, k) for k in keys)
            if worst > TOL:
                bad.append(f'{species}.{part}: {worst:.3f} studs')
        self.assertEqual(bad, [], 'eyes leave their place while blinking')


if __name__ == '__main__':
    unittest.main()
