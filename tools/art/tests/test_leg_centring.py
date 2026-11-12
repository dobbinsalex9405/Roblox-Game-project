"""A creature's left and right legs sit the same distance either side of the
model's centre.

The export centres every model on its bounding box (describe.describe). A
piece that sticks out on one side only (GorillaBaby's banana, Nov 8) moves
that centre off the mirror line, so in the game the left leg sits further
out than the right and CreatureMeshes.spec fails ("legL: 0.2 studs off its
right leg") once the creature is live. This catches it before an upload, at
the same 0.13-stud tolerance as that spec.

Run: python3 -m unittest discover -s tools/art/tests"""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'blender'))
sys.path.insert(0, os.path.join(HERE, '..'))

import creatures  # noqa: E402
import describe  # noqa: E402

TOLERANCE = 0.13  # studs, as games/hatchery-heist/tests/CreatureMeshes.spec.luau

# Creatures allowed off-centre for now, each with a reason. A new name here
# needs one; a fixed creature comes off (test_known_list_is_current).
KNOWN = {}


def leg_offsets(c):
    """{left leg name: studs between where it is and the mirror of its right leg}."""
    lo, hi = c.bounds()
    twice_centre = lo[0] + hi[0]
    by = {p.name: p for p in c.parts}
    out = {}
    for name, part in by.items():
        twin = by.get(name[:-1] + 'R')
        if not (name.startswith('leg') and name.endswith('L') and twin and part.v and twin.v):
            continue
        l0, l1 = min(q[0] for q in part.v), max(q[0] for q in part.v) + 1
        r0, r1 = min(q[0] for q in twin.v), max(q[0] for q in twin.v) + 1
        out[name] = max(abs(l0 + r1 - twice_centre), abs(l1 + r0 - twice_centre)) / 2 * c.voxel
    return out


class LegsCentred(unittest.TestCase):
    def test_legs_mirror_about_the_centre(self):
        off = {}
        for c in creatures.build_all(describe.DETAIL):
            if c.species in KNOWN:
                continue
            worst = max(leg_offsets(c).values(), default=0)
            if worst > TOLERANCE:
                off[f'{c.species} ({c.rarity})'] = round(worst, 3)
        self.assertEqual(off, {}, 'legs off the mirror line (studs): a piece sticking out on one side '
                         'moves the bounding-box centre')

    def test_known_list_is_current(self):
        """A creature on KNOWN that has been fixed comes off the list."""
        built = {c.species: c for c in creatures.build_all(describe.DETAIL) if c.species in KNOWN}
        fixed = [n for n, c in built.items() if max(leg_offsets(c).values(), default=0) <= TOLERANCE]
        self.assertEqual(fixed, [], 'fixed: take these off KNOWN')


if __name__ == '__main__':
    unittest.main()
