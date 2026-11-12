"""even_eggs.solve on made-up pools: weights are whole multiples of each
tier's member count, add up to the total, and stay close to the targets."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import even_eggs  # noqa: E402

CHANCES = {'Common': 0.67, 'Uncommon': 0.31, 'Rare': 0.017, 'Ultra Rare': 0.0028, 'Epic': 0.00017,
           'Legendary': 0.00003}


class Solve(unittest.TestCase):
    def check(self, total, chances, counts):
        weights = even_eggs.solve(total, chances, counts)
        self.assertEqual(sum(weights.values()), total)
        for tier, weight in weights.items():
            self.assertEqual(weight % counts[tier], 0, tier)
            self.assertGreaterEqual(weight // counts[tier], 1, tier)
        return weights

    def test_even_split_close_to_targets(self):
        counts = {'Common': 129, 'Uncommon': 101, 'Rare': 62, 'Ultra Rare': 13, 'Epic': 6, 'Legendary': 6}
        weights = self.check(1_000_000, CHANCES, counts)
        for tier, chance in CHANCES.items():
            self.assertLess(abs(weights[tier] / 1_000_000 - chance) / chance, 0.03, tier)

    def test_awkward_counts_still_add_up(self):
        for counts in ({'Common': 97, 'Uncommon': 89, 'Rare': 83, 'Ultra Rare': 79, 'Epic': 71, 'Legendary': 67},
                       {'Common': 2, 'Uncommon': 4, 'Rare': 6, 'Ultra Rare': 8, 'Epic': 10, 'Legendary': 12}):
            self.check(1_000_000, CHANCES, counts)

    def test_per_creature_chance_is_exact(self):
        chances = {'Uncommon': 0.58, 'Rare': 0.38, 'Ultra Rare': 0.037, 'Epic': 0.0029, 'Legendary': 0.00008,
                   'Godly': ('each', 0.000001)}
        for godlies in (1, 19, 20, 37):
            counts = {'Uncommon': 18, 'Rare': 38, 'Ultra Rare': 62, 'Epic': 54, 'Legendary': 44, 'Godly': godlies}
            weights = self.check(10_000_000, chances, counts)
            self.assertEqual(weights['Godly'], godlies * 10)

    def test_thin_tier_is_cut_below_the_tier_under_it(self):
        # Two Legendaries with a tier target meant for 48 would each be far
        # likelier than each Epic: the tier is cut, and the points go to the
        # common tiers.
        chances = {'Common': 0.02, 'Uncommon': 0.646, 'Rare': 0.30, 'Ultra Rare': 0.032, 'Epic': 0.0019,
                   'Legendary': 0.0001, 'Godly': ('each', 0.000001)}
        counts = {'Common': 199, 'Uncommon': 97, 'Rare': 60, 'Ultra Rare': 71, 'Epic': 60, 'Legendary': 2,
                  'Godly': 20}
        weights = self.check(10_000_000, chances, counts)
        each = {t: weights[t] // counts[t] for t in weights}
        self.assertLess(each['Legendary'], each['Epic'])
        self.assertLessEqual(each['Legendary'] * even_eggs.EVEN_STEP, each['Epic'])
        self.assertEqual(each['Godly'], 10)
        self.assertTrue(even_eggs.rarer_is_rarer(list(weights), each))
        # With the full 48 the target fits, and nothing is cut.
        weights = self.check(10_000_000, chances, {**counts, 'Legendary': 48})
        self.assertLess(abs(weights['Legendary'] / 10_000_000 - 0.0001) / 0.0001, 0.03)

    def test_a_dearer_egg_may_favour_uncommon_but_never_a_rarer_tier(self):
        each = {'Common': 1005, 'Uncommon': 66598, 'Rare': 50006, 'Ultra Rare': 4507}
        self.assertTrue(even_eggs.rarer_is_rarer(list(each), each))
        self.assertFalse(even_eggs.rarer_is_rarer(list(each), {**each, 'Ultra Rare': 50006}))

    def test_thin_tier_cannot_become_the_likeliest(self):
        # The Giant Golden Egg (Epic and up) with only 2 Legendaries live:
        # each Legendary would be 1 in 10, each Epic 1 in 75.
        chances = {'Epic': 0.795, 'Legendary': 0.20, 'Godly': 0.005}
        for legendaries in (2, 15, 48):
            counts = {'Epic': 60, 'Legendary': legendaries, 'Godly': 20}
            weights = self.check(1_000_000, chances, counts)
            each = {t: weights[t] // counts[t] for t in weights}
            self.assertLess(each['Legendary'], each['Epic'])
            self.assertLess(each['Godly'], each['Legendary'])

    def test_per_creature_tier_that_breaks_the_order_is_refused(self):
        chances = {'Common': 0.9999, 'Epic': 0.0001, 'Godly': ('each', 0.001)}
        with self.assertRaises(SystemExit):
            even_eggs.solve(1_000_000, chances, {'Common': 10, 'Epic': 10, 'Godly': 2})

    def test_ladder_flags_a_cheaper_egg_with_better_rare_odds(self):
        n = {'Rare': 10}
        solved = {'BasicEgg': (1000, {'Rare': 100}, n), 'MeadowEgg': (1000, {'Rare': 50}, n),
                  'MoonlitEgg': (1000, {'Rare': 200}, n)}
        self.assertEqual(len(even_eggs.ladder_problems(solved)), 1)

    def test_live_targets_solve_on_the_full_roster(self):
        # The roster once batches 15-17 land: 48 Legendaries.
        counts = {'Common': 199, 'Uncommon': 97, 'Rare': 60, 'Ultra Rare': 71, 'Epic': 60, 'Legendary': 48,
                  'Godly': 20}
        solved = {}
        for egg, (total, chances) in even_eggs.TARGETS.items():
            c = {t: counts[t] for t in chances}
            solved[egg] = (total, self.check(total, chances, c), c)
        self.assertEqual(even_eggs.ladder_problems(solved), [])

    def test_empty_tier_is_refused(self):
        with self.assertRaises(SystemExit):
            even_eggs.solve(1_000_000, CHANCES, {**{t: 5 for t in CHANCES}, 'Legendary': 0})


if __name__ == '__main__':
    unittest.main()
