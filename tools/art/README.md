# Creature art

Hatchery Heist's 33 creatures as voxel models, in plain Python.

| File | What it is |
| --- | --- |
| `voxkit.py` | Parts, voxels and merging voxels into as few boxes as possible |
| `creatures.py` | Every species: body plans, colours, sizes by rarity (`HEIGHT`) |
| `legends.py` | The two Legendaries and two Godlies, built in far more detail |
| `export.py` | Writes `games/hatchery-heist/src/shared/VoxelArt.luau` |
| `render.py` | Renders creatures with Blender for review |

## Changing a creature

1. Edit `creatures.py` (or `legends.py`).
2. `python3 tools/art/export.py`, and commit the regenerated `VoxelArt.luau`
   with it. CI re-runs the export and fails if the two differ.
3. `lune run tools/test/run VoxelArt` checks every species has art, the art
   is well formed, each tier stays within its part budget, and creatures
   grow with rarity.
4. Look at it: `render.py` (below), then the player's-eye check.

## Rendering

Blender runs headless from pip, no install:

```sh
pip install --target=/tmp/bpy bpy==5.1.2      # once, about 1 GB, Python 3.13
PYTHONPATH=/tmp/bpy python3 tools/art/render.py lineup.png --all
PYTHONPATH=/tmp/bpy python3 tools/art/render.py phoenix.png Phoenix
```

## How the game draws them

Each part of a creature (body, head, ears, tail, wings, eyes, glow pieces)
becomes boxes welded to a root that a Motor6D moves, so the client animates
a few joints per creature, not every box. `src/shared/CreatureLooks.luau`
says what each tier does: bob, head turn, ear flick, wing flap, blink, glow
pulse, light, sparkles, rarity ring, hover, orbiting lights. See
`src/client/CreatureView.luau`.

## Blender meshes (`blender/`)

The same creatures as polished voxel meshes: each voxel face a bevelled
square, twice the voxels for the small tiers, glowing parts as their own
meshes, one joint per part. See `ops/ASSETS.md` for how they reach the game.

| File | What it is |
| --- | --- |
| `blender/voxmesh.py` | Voxels to bevelled meshes (plain Python) |
| `blender/palette.py` | The tiny per-creature colour texture |
| `blender/describe.py` | Every creature's meshes, joints and `meta.json` (plain Python) |
| `blender/build.py` | Blender: `.glb`, `.fbx`, idle and walk clips, renders |
| `blender/lineup.py` | Blender: a row of creatures at in-game size |
| `blender/luau.py` | Writes `src/shared/CreatureMeshes.luau` (CI checks it) |
| `blender/upload.py` | Uploads the `.fbx` files as Model assets (the workflow runs it) |

```sh
PYTHONPATH=/opt/bpy python3 tools/art/blender/build.py out --tier Common     # files + renders
PYTHONPATH=/opt/bpy python3 tools/art/blender/build.py out --no-render       # files only
PYTHONPATH=/opt/bpy python3 tools/art/blender/lineup.py commons.png --tier Common
python3 tools/art/blender/luau.py                                            # after any art change
```
