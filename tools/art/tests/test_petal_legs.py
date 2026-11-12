"""An orchid mantis's petal legs are mirror twins, voxel for voxel.

kit_wild.petallegs used to draw each leg's petal from that leg's own pivot,
rounding outward with floor/ceil, so the left and right petals landed on
different voxels around the x -> -1 - x mirror line (OrchidMantis, gate on
#166, Nov 8: 6 one-sided leg voxels in the stand-in, 7 in the mesh). It now
draws the left petal and mirrors it onto the right leg; this keeps it so in
both builds.

Run: python3 -m unittest discover -s tools/art/tests"""
import json
import glob
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'blender'))
sys.path.insert(0, os.path.join(HERE, '..'))

import creatures  # noqa: E402
import describe  # noqa: E402


def petal_species():
    """Roster creatures with a petallegs accessory."""
    out = set()
    for f in glob.glob(os.path.join(HERE, '..', 'roster', '*.json')):
        d = json.load(open(f))
        for c in (d if isinstance(d, list) else d.get('creatures', [])):
            if any(a.get('kind') == 'petallegs' for a in c.get('accessories', [])):
                out.add(c['id'])
    return out


def unmirrored(c):
    """Leg voxels whose twin across the middle is missing or differs."""
    legs = {p.name: p for p in c.parts if p.name.startswith('leg')}
    bad = []
    for name, part in legs.items():
        twin = legs.get(name[:-1] + ('R' if name.endswith('L') else 'L'))
        if twin is None:
            continue
        for (x, y, z), v in part.v.items():
            if twin.v.get((-1 - x, y, z)) != v:
                bad.append((name, (x, y, z)))
    return bad


class PetalLegs(unittest.TestCase):
    def test_petal_legs_are_mirror_twins(self):
        names = petal_species()
        self.assertIn('OrchidMantis', names)
        for label, detail in (('stand-in', None), ('mesh', describe.DETAIL)):
            for c in creatures.build_all(detail):
                if c.species in names:
                    self.assertEqual(unmirrored(c), [], f'{c.species} {label}: legs not mirrored')


if __name__ == '__main__':
    unittest.main()
