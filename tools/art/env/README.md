# Outdoor nature (Hatchery Heist)

The world outside the bases: a family of voxel trees, bushes, rocks, flower
patches, grass tufts and mushroom rings, the skybox and the grass tile. All
modelled in plain Python (numpy), meshed in Blender, uploaded to Roblox and
placed by the game. The colours are the world props' palettes
(`tools/art/world/props.py`), so the outdoors matches the Egg Market.

| File | What it is |
| --- | --- |
| `nature.py` | Every model: Puff Oak, Amber Oak, Blossom Tree, Star Pine, Moonberry Willow, Toadstool Tree (small, medium, large), bushes, hedge, rocks, stepping stones, flowers, grass, mushrooms |
| `envkit.py` | The world thread's voxel grids (`tools/art/world/vkit.py`) at a voxel size per model, meshed one mesh per colour |
| `build.py` | Blender: `.fbx` for Roblox, `.glb` and a render for the design viewer, `env.json` |
| `sky.py` | The six skybox faces (storybook sky, voxel clouds, mountains, floating islands) |
| `grass.py` | The seamless grass tile |
| `upload.py` | Uploads the models and images through Open Cloud (`assets.json`) |
| `luau.py` | Writes `games/hatchery-heist/src/shared/EnvArt.luau` (CI checks it) |

## Why it is built this way

- **One MeshPart per colour.** A MeshPart has one Color, so a tree is a
  handful of MeshParts (bark, three leaf greens, blossom) and needs no
  texture upload, which is what failed for the creatures (#66).
- **Flat voxel faces, bigger voxels.** Trees use 0.3 to 0.45 stud voxels,
  the same voxels-per-object as a 0.1-stud creature. The creatures' bevelled
  "pillow" faces would be 0.01 studs deep here (invisible at play distance)
  and cost five times the triangles, so faces are greedy-merged flat
  squares. A large tree is about 11,000 triangles, a bush 1,900.
- **Box trees until meshes load.** The game draws the old box tree at each
  tree spot and swaps in the meshes when they arrive; the small props wait
  for theirs. Nothing breaks if an upload is missing.
- **A sky that survives any face order.** Roblox does not document which way
  each skybox face points. Above 33 degrees the sky depends only on height,
  and near the four vertical seams the mountains follow one shared shape, so
  every order and mirroring still meets at the seams.

## Changing a model, the sky or the grass

```sh
pip install --target=/tmp/bpy bpy==5.1.2          # once
PYTHONPATH=/tmp/bpy python3 tools/art/env/build.py build/env/models --only StarPineL --designs /mnt/project-files/designs
python3 tools/art/env/sky.py build/env/sky        # SkyboxBk..Up.png, net.png, panorama.png
python3 tools/art/env/grass.py build/env/grass    # Grass.png, grass-preview.png
python3 tools/art/env/luau.py
lune run tools/test/run Nature
```

Then run the **Upload creature meshes** workflow with **art = nature** on
your branch. It rebuilds everything, uploads what changed, and commits
`assets.json`, `env.json` and `EnvArt.luau` back onto that branch.

Where things go in the world, and how many, is `scenery.nature` in
`games/hatchery-heist/config/atmosphere.luau` (planned by
`src/shared/NaturePlan.luau`).
