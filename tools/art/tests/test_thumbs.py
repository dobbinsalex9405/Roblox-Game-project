"""The Hatchery Book pictures: an uploaded picture is used only while it was
drawn from the creature's art as it is now (thumbs.fingerprint), so a
reworked creature never shows its old look in the Book.

Run: python3 -m unittest discover -s tools/art/tests"""
import copy
import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'blender'))
sys.path.insert(0, os.path.join(HERE, '..'))

import describe  # noqa: E402
import luau  # noqa: E402
import thumbs  # noqa: E402


ALL = {}


def one(species):
    """A fresh copy of a creature (building them all once is the slow part)."""
    if not ALL:
        ALL.update((c.species, c) for c in describe.creatures())
    return copy.deepcopy(ALL[species])


class Fingerprint(unittest.TestCase):
    def test_same_art_same_print(self):
        self.assertEqual(thumbs.fingerprint(one('Chick')), thumbs.fingerprint(one('Chick')))

    def test_each_creature_its_own(self):
        self.assertNotEqual(thumbs.fingerprint(one('Chick')), thumbs.fingerprint(one('Duckling')))

    def test_new_style_redraws_every_picture(self):
        before = thumbs.fingerprint(one('Chick'))
        thumbs.STYLE += 1
        try:
            self.assertNotEqual(thumbs.fingerprint(one('Chick')), before)
        finally:
            thumbs.STYLE -= 1

    def test_a_recolour_redraws_it(self):
        c = one('Chick')
        before = thumbs.fingerprint(c)
        part = c.parts[0]
        part.paint(lambda p, col, glow: ((255 - col[0], col[1], col[2]), glow))
        self.assertNotEqual(thumbs.fingerprint(c), before)


class Map(unittest.TestCase):
    def test_lists_only_pictures_of_the_art_as_it_is(self):
        tmp = tempfile.mkdtemp()
        assets, out = os.path.join(tmp, 'assets.json'), os.path.join(tmp, 'CreatureThumbs.luau')
        with open(assets, 'w') as f:
            json.dump({'models': {}, 'thumbs': {
                'Chick': {'imageId': 111, 'source': thumbs.fingerprint(one('Chick'))},
                'Duckling': {'imageId': 222, 'source': 'drawn-from-old-art'},
            }}, f)
        old = luau.ASSETS, luau.THUMBS_OUT
        luau.ASSETS, luau.THUMBS_OUT = assets, out
        try:
            self.assertEqual(luau.write_thumbs(), 1)
        finally:
            luau.ASSETS, luau.THUMBS_OUT = old
        with open(out) as f:
            text = f.read()
        self.assertIn('\tChick = 111,', text)
        self.assertNotIn('Duckling', text)


if __name__ == '__main__':
    unittest.main()
