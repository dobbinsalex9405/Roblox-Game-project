"""Rule k: no creature below Ultra Rare glows.

A glowing voxel becomes a Neon piece in the meshes and a lit box in the
game, and glow is kept for Ultra Rare and up. This builds every creature in
the roster twice, at the detail the Blender meshes use and as the coarse
in-game stand-in, and fails on any Common, Uncommon or Rare that still has
a glowing voxel. The fix for a creature that glows is `"glow": false` in its
roster entry (variants.py), which keeps the colours and drops the glow. It
also keeps every one of them inside its tier's triangle budget.

Run: python3 -m unittest discover -s tools/art/tests"""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'blender'))
sys.path.insert(0, os.path.join(HERE, '..'))

import creatures  # noqa: E402
import describe  # noqa: E402
import variants  # noqa: E402

BELOW_ULTRA_RARE = ('Common', 'Uncommon', 'Rare')


def glowing(c):
    """{part name: glowing voxel count} for the parts that glow."""
    out = {}
    for p in c.parts:
        n = sum(1 for _, g in p.v.values() if g)
        if n:
            out[p.name] = n
    return out


class NoGlowBelowUltraRare(unittest.TestCase):
    def check(self, built, label):
        bad = {}
        for c in built:
            if c.rarity in BELOW_ULTRA_RARE:
                g = glowing(c)
                if g:
                    bad[f'{c.species} ({c.rarity})'] = g
        self.assertEqual(bad, {}, f'{label}: creatures below Ultra Rare that glow (rule k); '
                         'set "glow": false on their roster entries')

    def test_meshes(self):
        self.check(creatures.build_all(describe.DETAIL), 'Blender meshes')

    def test_stand_ins(self):
        self.check(creatures.build_all(), 'in-game stand-ins')

    def test_meshes_in_triangle_budget(self):
        """Every creature below Ultra Rare meshes inside its tier's triangle
        budget. Voxels that lost their glow are pillowed like the rest and
        fall back to flat faces only when pillowing would pass the budget
        (describe.describe), so a de-glowed creature can't pass it either."""
        over = {}
        for c in describe.creatures(BELOW_ULTRA_RARE):
            tris = describe.describe(c)[0]['tris']
            if tris > describe.PLAIN_BUDGET[c.rarity]:
                over[f'{c.species} ({c.rarity})'] = tris
        self.assertEqual(over, {}, 'over the triangle budget')

    def test_switch_keeps_colours(self):
        """`"glow": false` turns every glow off but keeps every colour and
        every voxel where it was, and a part that pulsed only to glow stands
        still."""
        entry = {'id': 'GlowSwitchProbe', 'rarity': 'Rare', 'plan': 'quadruped',
                 'colors': {'col': '#D8A86A', 'belly': '#F2D6A8'},
                 'patterns': [{'kind': 'spots', 'color': '#FFD24A', 'glow': True}]}
        lit = variants.builder(entry)
        dark = variants.builder(dict(entry, glow=False))
        a = lit(creatures.Creature('GlowSwitchProbe', 'Rare'), 20)
        b = dark(creatures.Creature('GlowSwitchProbe', 'Rare'), 20)
        self.assertTrue(glowing(a), 'the probe should glow without the switch')
        self.assertEqual(glowing(b), {})
        self.assertEqual([p.name for p in a.parts], [p.name for p in b.parts])
        for pa, pb in zip(a.parts, b.parts):
            self.assertEqual({q: col for q, (col, _) in pa.v.items()}, {q: col for q, (col, _) in pb.v.items()})
            self.assertNotEqual(pb.anim, 'glow')

    def test_switch_only_false(self):
        with self.assertRaises(variants.RosterError):
            variants.check({'id': 'GlowSwitchProbe', 'rarity': 'Rare', 'plan': 'quadruped',
                            'colors': {'col': '#D8A86A'}, 'glow': True}, 'test')


if __name__ == '__main__':
    unittest.main()
