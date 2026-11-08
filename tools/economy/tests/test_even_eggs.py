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

    def test_empty_tier_is_refused(self):
        with self.assertRaises(SystemExit):
            even_eggs.solve(1_000_000, CHANCES, {**{t: 5 for t in CHANCES}, 'Legendary': 0})


if __name__ == '__main__':
    unittest.main()
