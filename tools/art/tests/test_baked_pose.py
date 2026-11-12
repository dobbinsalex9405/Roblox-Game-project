"""baked_pose.py names the creatures whose old FBX carried a walk pose.

Roblox's importer baked the walk clip's first frame into the meshes of 198
of 509 uploaded creatures (real-engine probe, Nov 12). The detector must
agree with what the real engine saw, so the re-upload list is right:
Ant's left legs and Bunny's hop pitch were baked in; AlleyCat (trot) and
Chick landed clean. build.py now writes the FBX at rest without clips.

Run: python3 -m unittest discover -s tools/art/tests"""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'blender'))
sys.path.insert(0, os.path.join(HERE, '..'))

import baked_pose  # noqa: E402
from describe import creatures  # noqa: E402


class BakedPose(unittest.TestCase):
    def test_matches_the_real_engine(self):
        cs = {c.species: c for c in creatures(only={'Ant', 'Bunny', 'AlleyCat', 'Chick'})}
        _, ant = baked_pose.frame_one(cs['Ant'])
        self.assertEqual(sorted(ant), ['leg1L', 'leg2R', 'leg3L'])  # rolled 0.3 rad
        _, bunny = baked_pose.frame_one(cs['Bunny'])
        self.assertIn('body', bunny)  # pitched for the hop
        self.assertEqual(baked_pose.frame_one(cs['AlleyCat'])[1], {})
        self.assertEqual(baked_pose.frame_one(cs['Chick'])[1], {})

    def test_fbx_is_written_without_clips(self):
        src = open(os.path.join(HERE, '..', 'blender', 'build.py')).read()
        fbx = src[src.index('def export_fbx'):]
        fbx = fbx[:fbx.index('\n\n\n')]
        self.assertIn('bake_anim=False', fbx)
        self.assertIn('tr.mute = True', src)


if __name__ == '__main__':
    unittest.main()
