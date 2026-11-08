"""Every Legendary's in-game stand-in fits the Legendary box budget.

The game draws a creature as voxel boxes (VoxelArt) until its mesh loads,
and tools/art/to_config.py keeps a creature out of the game's config while
those boxes are over its tier's budget (BOX_BUDGET). Legendaries are built
in legendaries.py, which fits an over-budget stand-in (fit_stand_in) on the
coarse build only. This builds the roster as the game draws it and fails
on any Legendary over the budget, and checks that the fit never touches
the fine build the Blender meshes come from.

Run: python3 -m unittest discover -s tools/art/tests"""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'blender'))
sys.path.insert(0, os.path.join(HERE, '..'))

import creatures  # noqa: E402
import describe  # noqa: E402
import legendaries  # noqa: E402
import to_config  # noqa: E402

BUDGET = to_config.BOX_BUDGET['Legendary']


class LegendaryStandInsFitTheBudget(unittest.TestCase):
    def test_every_legendary_within_budget(self):
        over = {}
        for c in creatures.build_all():
            if c.rarity == 'Legendary':
                budget = [p for p in to_config.art_problems(c) if 'budget' in p]
                if budget:
                    over[c.species] = budget
        self.assertEqual(over, {}, f'Legendary stand-ins over {BUDGET} boxes')

    def test_fit_skips_the_fine_build(self):
        fine = [c for c in creatures.build_all(describe.DETAIL) if c.rarity == 'Legendary']
        self.assertTrue(fine)
        for c in fine:
            before = {p.name: dict(p.v) for p in c.parts}
            legendaries.fit_stand_in(c)
            self.assertEqual({p.name: p.v for p in c.parts}, before, c.species)


if __name__ == '__main__':
    unittest.main()
