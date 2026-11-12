"""No creature in the game has a detached stand-in piece.

to_config holds back a new creature whose in-game stand-in has a voxel group
that touches nothing else, not even at an edge or corner (to_config.detached;
parts in LOOSE_PARTS float on purpose). Creatures that were already live when
that rule came in are only reported ("live, kept") and never dropped, so this
test is what keeps them fixed: it builds the stand-in of every creature in
the generated block of config/creatures.luau and fails on any detached piece.

Run: python3 -m unittest discover -s tools/art/tests"""
import contextlib
import io
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'blender'))
sys.path.insert(0, os.path.join(HERE, '..'))

import creatures  # noqa: E402
import to_config  # noqa: E402


def live():
    """Ids in the generated block of config/creatures.luau."""
    with open(to_config.CONFIG) as f:
        return to_config.hand_ids(to_config.split(f.read())[1])


class NoDetachedStandIn(unittest.TestCase):
    def test_every_live_stand_in_is_one_piece(self):
        ids = live()
        self.assertTrue(ids)
        with contextlib.redirect_stdout(io.StringIO()):
            built = creatures.build_all(only=ids)
        bad = {c.species: to_config.detached(c) for c in built}
        bad = {k: v for k, v in bad.items() if v}
        self.assertEqual(bad, {}, 'live stand-ins with detached pieces')


if __name__ == '__main__':
    unittest.main()
