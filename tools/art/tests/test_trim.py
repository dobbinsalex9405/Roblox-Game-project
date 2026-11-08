"""kit_trim: a creature over its tier's box budget gets the
smallest mirrored edits that bring its in-game boxes inside it (trim_boxes),
or a plainer stand-in for a part that costs too many (pad_legs, jaw_band,
plain_boxes),
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


SHADE, FLUFF, SPOT = (239, 233, 224), (255, 255, 255), (90, 58, 36)


def pup(fine=False):
    """A four-legged body the game carves its legs out of (rig.split_legs):
    a ragged two-shade coat, one dark spot on each flank, four 1x1 feet."""
    c = Creature('PupTest', 'Uncommon')
    c.fine = fine
    body = c.part('body', 'static')
    for x in range(-2, 2):
        for y in range(0, 6):
            for z in range(1, 4):
                body.put((x, y, z), FLUFF if (x * 7 + y * 3 + z) % 4 == 0 else SHADE)
    for x in (-3, 2):
        for y in (1, 3):
            body.put((x, y, 2), SHADE)  # tufts
        body.put((x, 4, 3), SPOT)
    for x, y in ((-2, 0), (1, 0), (-2, 5), (1, 5)):
        body.put((x, y, 0), SHADE)
    return c


def drawn(c):
    import copy

    import rig
    from voxkit import Part
    d = copy.deepcopy(c)
    rig.split_legs(d, Part)
    return sum(kit_trim._boxes(p.v) for p in d.parts), sorted(p.name for p in d.parts if p.name.startswith('leg'))


class PlainBoxes(unittest.TestCase):
    def test_a_busy_coat_comes_inside_the_budget(self):
        c = pup()
        start, legs = drawn(c)
        with contextlib.redirect_stderr(io.StringIO()):
            kit_trim.plain_boxes(c, 10, a={'budget': start - 4, 'parts': ['body']})
        after, legs_after = drawn(c)
        self.assertLessEqual(after, start - 4)
        self.assertEqual(legs, legs_after)  # four legs still walk
        cols = {v[0] for v in c.parts[0].v.values()}
        self.assertIn(SPOT, cols)  # a pattern more than a shade off is kept
        self.assertNotIn(FLUFF, cols)  # a shade off the coat is merged

    def test_no_edit_cuts_a_foot_off(self):
        c = pup()
        start, legs = drawn(c)
        with contextlib.redirect_stderr(io.StringIO()):
            kit_trim.trim_boxes(c, 10, a={'budget': 1, 'parts': ['body']})
        self.assertEqual(legs, drawn(c)[1])

    def test_the_fine_build_keeps_its_coat(self):
        c = pup(fine=True)
        before = dict(c.parts[0].v)
        kit_trim.plain_boxes(c, 10, a={'budget': 1, 'parts': ['body']})
        self.assertEqual(before, c.parts[0].v)


class KittenFace(unittest.TestCase):
    def kitten(self, fine=False):
        c = Creature('KitTest', 'Uncommon')
        c.fine = fine
        h = c.part('head', 'static')
        for x in range(-2, 2):
            for y in range(-4, -1):
                for z in range(4, 8):
                    h.put((x, y, z), SAND)
        h.put((-1, -4, 6), SPOT)  # a spot between the eyes
        h.put((0, -4, 6), INK)  # a dark voxel between them
        e = c.part('eyes', 'static')
        e.put((-2, -4, 6), INK)
        e.put((1, -4, 6), INK)
        ears = c.part('ears', 'static')
        for x in range(-2, 3):
            ears.put((x, -2, 8), SAND)
        ears.put((-1, -2, 9), SAND)
        ears.put((1, -2, 9), SAND)
        return c, h, ears

    def test_two_eyes_with_the_head_colour_between(self):
        c, h, _ = self.kitten()
        kit_trim.kitten_face(c, 10)
        self.assertEqual(h.v[(-1, -4, 6)], (SAND, False))
        self.assertEqual(h.v[(0, -4, 6)], (SAND, False))

    def test_two_nub_ears_at_the_corners_and_a_flat_top(self):
        c, _, ears = self.kitten()
        kit_trim.kitten_face(c, 10)
        self.assertEqual({v[0] for v in ears.v}, {-2, 1})
        self.assertEqual({v[2] for v in ears.v}, {8})  # one voxel above the head

    def test_stepped_ears_tip_on_the_outer_column(self):
        c, _, ears = self.kitten()
        kit_trim.kitten_face(c, 10, a={'ears': 'step'})
        self.assertEqual({v[0] for v in ears.v if v[2] == 9}, {-2, 1})
        self.assertEqual({v[0] for v in ears.v if v[2] == 8}, {-2, -1, 0, 1})

    def test_no_stripe_touches_an_eye(self):
        c, h, _ = self.kitten()
        h.put((-2, -4, 5), SPOT)  # a cheek stripe under the eye
        h.put((-2, -4, 4), SPOT)
        kit_trim.kitten_face(c, 10)
        self.assertEqual(h.v[(-2, -4, 5)], (SAND, False))
        self.assertEqual(h.v[(-2, -4, 4)], (SPOT, False))  # the rest of it stays

    def test_the_fine_build_keeps_its_face(self):
        c, h, ears = self.kitten(fine=True)
        before = (dict(h.v), dict(ears.v))
        kit_trim.kitten_face(c, 10)
        self.assertEqual(before, (h.v, ears.v))


if __name__ == '__main__':
    unittest.main()
