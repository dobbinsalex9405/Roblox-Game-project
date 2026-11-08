"""kit_trim.trim_boxes: a creature over its tier's box budget gets the
smallest mirrored edits that bring its in-game boxes inside it, and its
finer Blender build (the reviewed mesh) is never touched.

Run: python3 -m unittest discover -s tools/art/tests"""
import contextlib
import io
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'blender'))
sys.path.insert(0, os.path.join(HERE, '..'))

import kit_trim  # noqa: E402
from voxkit import Creature  # noqa: E402

BROWN, DARK = (150, 110, 80), (60, 40, 30)


def critter(fine=False):
    """A mirrored bug: a 4-wide body and two bent legs a side (two boxes each), 9 boxes."""
    c = Creature('TrimTest', 'Common')
    c.fine = fine
    body = c.part('body', 'static')
    for x in range(-2, 2):
        for y in range(0, 6):
            body.put((x, y, 2), BROWN)
            body.put((x, y, 3), BROWN)
    for name, y in (('leg1', 1), ('leg3', 4)):
        for side, sx in (('L', -1), ('R', 1)):
            leg = c.part(name + side, 'leg')
            x0 = -3 if sx < 0 else 2
            leg.put((x0, y, 1), DARK)
            leg.put((x0 + sx, y, 1), DARK)
            leg.put((x0 + sx, y, 0), DARK)
    return c


def boxes(c):
    return sum(kit_trim._boxes(p.v) for p in c.parts)


def run(c, **a):
    with contextlib.redirect_stderr(io.StringIO()):
        kit_trim.trim_boxes(c, 10, a={'kind': 'trim_boxes', **a})


class Trim(unittest.TestCase):
    def test_brings_the_boxes_inside_the_budget(self):
        c = critter()
        start = boxes(c)
        run(c, budget=start - 1)
        self.assertLessEqual(boxes(c), start - 1)

    def test_edits_stay_mirrored(self):
        c = critter()
        run(c, budget=boxes(c) - 1)
        xs = [v[0] for p in c.parts for v in p.v]
        s = min(xs) + max(xs)
        cells = {v for p in c.parts for v in p.v}
        self.assertEqual(cells, {(s - x, y, z) for (x, y, z) in cells})

    def test_every_leg_still_stands(self):
        c = critter()
        run(c, budget=boxes(c) - 2, parts=['leg1', 'leg3'])
        for p in c.parts:
            if p.name.startswith('leg'):
                self.assertTrue(any(v[2] == 0 for v in p.v), p.name)

    def test_inside_the_budget_nothing_changes(self):
        c = critter()
        before = {p.name: dict(p.v) for p in c.parts}
        run(c, budget=boxes(c))
        self.assertEqual(before, {p.name: dict(p.v) for p in c.parts})

    def test_the_fine_blender_build_is_never_touched(self):
        c = critter(fine=True)
        before = {p.name: dict(p.v) for p in c.parts}
        run(c, budget=1)
        self.assertEqual(before, {p.name: dict(p.v) for p in c.parts})


if __name__ == '__main__':
    unittest.main()
