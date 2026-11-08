"""to_config.art_problems: every rule a creature breaks is reported, not only
the first, and the Blender build (the reviewed mesh) may not glow below
Ultra Rare either, since the game draws a mesh's glowing voxels as neon.

Run: python3 -m unittest discover -s tools/art/tests"""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'blender'))
sys.path.insert(0, os.path.join(HERE, '..'))

import to_config  # noqa: E402
from voxkit import Creature  # noqa: E402

BROWN, PINK = (150, 110, 80), (255, 227, 238)


def stripes(rarity, n, glow=False):
    """A creature whose in-game build is exactly n boxes: n one-voxel posts in
    alternating colours, a voxel apart. With glow, the first post glows."""
    c = Creature('ConfigTest', rarity)
    body = c.part('body', 'static')
    for i in range(n):
        body.put((2 * i, 0, 0), BROWN if i % 2 else (90, 60, 40), glow and i == 0)
    return c


def fine(rarity, lit=0):
    """A Blender build with `lit` glowing voxels."""
    c = Creature('ConfigTest', rarity)
    c.fine = True
    body = c.part('body', 'static')
    for i in range(10):
        body.put((i, 0, 0), PINK if i < lit else BROWN, i < lit)
    return c


class Problems(unittest.TestCase):
    def test_a_creature_inside_every_rule_passes(self):
        self.assertEqual(to_config.art_problems(stripes('Rare', 40), fine('Rare')), [])

    def test_floor_is_sixty_percent_of_the_tier_below_budget(self):
        self.assertEqual(to_config.floor_of('Common'), 0)
        self.assertEqual(to_config.floor_of('Uncommon'), 18)
        self.assertEqual(to_config.floor_of('Rare'), 26)

    def test_over_budget_and_glowing_reports_both(self):
        why = to_config.art_problems(stripes('Rare', 61, glow=True), fine('Rare', lit=3))
        self.assertEqual(len(why), 3, why)
        self.assertIn('61 voxel boxes, Rare budget is 60', why[0])
        self.assertIn('glows', why[1])
        self.assertIn('its mesh glows (3 voxels)', why[2])

    def test_under_the_detail_floor_is_held(self):
        why = to_config.art_problems(stripes('Rare', 25))
        self.assertEqual(why, ['25 voxel boxes, Rare detail floor is 26'])

    def test_a_glowing_mesh_is_held_even_when_the_stand_in_is_plain(self):
        why = to_config.art_problems(stripes('Uncommon', 30), fine('Uncommon', lit=4))
        self.assertEqual(why, ['its mesh glows (4 voxels), but only Ultra Rare and up may'])

    def test_ultra_rare_and_up_may_glow(self):
        self.assertEqual(to_config.art_problems(stripes('Ultra Rare', 60, glow=True), fine('Ultra Rare', 5)), [])


if __name__ == '__main__':
    unittest.main()
