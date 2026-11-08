"""kit_trim: a creature over its tier's box budget gets the
smallest mirrored edits that bring its in-game boxes inside it (trim_boxes),
or a plainer stand-in for a part that costs too many (pad_legs, jaw_band),
and its finer Blender build (the reviewed mesh) is never touched.

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


RIPPLE, SAND, BEARD, INK = (207, 239, 255), (226, 182, 119), (176, 122, 62), (27, 27, 47)


def strider(fine=False):
    """A body and one stepped leg a side that stands on a 3x3 ripple ring."""
    c = Creature('PadTest', 'Common')
    c.fine = fine
    body = c.part('body', 'static')
    for x in range(-1, 1):
        for y in range(0, 4):
            body.put((x, y, 2), BROWN)
    for side, sx in (('L', -1), ('R', 1)):
        leg = c.part('leg2' + side, 'leg', pivot=(-1.0 if sx < 0 else 0.0, 1, 2.1))
        x0 = -2 if sx < 0 else 1
        for dx, z in ((0, 2), (1, 2), (1, 1), (2, 1)):
            leg.put((x0 + sx * dx, 1, z), DARK)
        cx = x0 + sx * 3
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                leg.put((cx + dx, 1 + dy, 0), DARK if dx == dy == 0 else RIPPLE)
    return c


class PadLegs(unittest.TestCase):
    def test_a_ringed_leg_is_a_disc_and_a_bar(self):
        c = strider()
        before = boxes(c)
        kit_trim.pad_legs(c, 10, a={'parts': ['leg2']})
        self.assertLess(boxes(c), before)
        for p in c.parts:
            if p.name.startswith('leg2'):
                pad = [v for v in p.v if v[2] == 0]
                self.assertEqual(len(pad), 9, p.name)
                self.assertTrue(all(p.v[v][0] == RIPPLE for v in pad), p.name)
                self.assertLessEqual(kit_trim._boxes(p.v), 3, p.name)
                # the knee stays at the hip's height
                self.assertEqual(max(v[2] for v in p.v), 2, p.name)

    def test_the_fine_build_keeps_its_legs(self):
        c = strider(fine=True)
        before = {p.name: dict(p.v) for p in c.parts}
        kit_trim.pad_legs(c, 10, a={'parts': ['leg2']})
        self.assertEqual(before, {p.name: dict(p.v) for p in c.parts})


class JawBand(unittest.TestCase):
    def head(self, fine=False):
        c = Creature('JawTest', 'Common')
        c.fine = fine
        h = c.part('head', 'static')
        for x in range(-2, 2):
            for y in range(-2, 0):
                h.put((x, y, 2), SAND if (x + y) % 2 else BEARD)
                h.put((x, y, 3), SAND)
        h.put((-2, -2, 2), INK, True)
        return c, h

    def test_the_lowest_layer_takes_its_darkest_colour(self):
        c, h = self.head()
        kit_trim.jaw_band(c, 10)
        jaw = {v: h.v[v] for v in h.v if v[2] == 2}
        self.assertEqual(jaw.pop((-2, -2, 2)), (INK, True))  # a glowing voxel is kept
        self.assertEqual(set(jaw.values()), {(BEARD, False)})
        self.assertTrue(all(h.v[v] == (SAND, False) for v in h.v if v[2] == 3))

    def test_the_fine_build_keeps_its_head(self):
        c, h = self.head(fine=True)
        before = dict(h.v)
        kit_trim.jaw_band(c, 10)
        self.assertEqual(before, h.v)


if __name__ == '__main__':
    unittest.main()
