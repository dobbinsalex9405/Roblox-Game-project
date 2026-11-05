# Creature art

Hatchery Heist's creatures as voxel models, in plain Python.

| File | What it is |
| --- | --- |
| `voxkit.py` | Parts, voxels and merging voxels into as few boxes as possible |
| `creatures.py` | Every species: body plans, colours, sizes by rarity (`HEIGHT`) |
| `legends.py` | The two Legendaries and two Godlies, built in far more detail |
| `roster/*.json` | Creatures added as data (one line each), read by `variants.py` |
| `variants.py` | Loads and checks the roster files: body plan, shape, colours, patterns, accessories |
| `kit.py` | The variant kit: bug, crab and lizard plans, `shape`, patterns, accessories |
| `kit_pond.py` | More plans for roster entries: `critter` (garden bugs) and `shore` (pond and shore animals) |
| `kit_puff.py` | The `puff` plan: small round invented critters that hop on two stubby feet (kinds pebble, seed, puddle, tadpole, fuzz, gum, mushroom, acorn, cone, pip, ball); other kits add kinds with `kit_puff.add_kind` |
| `kit_extras.py` | More accessories for roster entries: `ridge` (back spikes), `third_eye`, `butter` (a pat on the head), `twin_tail`, `droopy_ears`, `fringe`, `shag`, `long_snout`, `streaks`, `cap`, `eye_ring`, `speckles`, `button_eye`, `knit_head`, `small_ears`, `stand_tall`, `rostrum`, `bristles`; plans `twig` (stick insect), `termite`, `wasp` and `strider` (water strider) |
| `export.py` | Writes `games/hatchery-heist/src/shared/VoxelArt.luau` |
| `render.py` | Renders creatures with Blender for review |

See `ANIMATION.md` for the rig and gait conventions every new creature follows (named leg, wing and fin parts; gaits).

## Adding a creature (as data)

1. Add one line to a file in `roster/` (a new file per batch, so batches
   never collide). The fields are in `variants.py`'s docstring:
   `{"id": "Calf", "rarity": "Common", "plan": "quadruped", "colors": {...},
   "options": {...}, "shape": {"body": [1.2, 1.15, 1.05], "head": 1.05},
   "patterns": [...], "accessories": [...]}`.
2. `python3 tools/art/variants.py` checks every entry and names the file
   and entry of any mistake.
3. Look at it:
   `PYTHONPATH=/opt/bpy python3 tools/art/blender/lineup.py out.png --only Calf,Foal --angle 35`.
4. The game picks it up once `games/hatchery-heist/config/creatures.luau`
   lists the id. Until then `export.py` and `blender/luau.py` leave it out
   of the generated files and say so, so CI stays green. After adding the
   config line, re-run both and commit the generated files.

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
square, every tier rebuilt from 0.1-stud voxels, glowing parts as their own
(flat) meshes, a flat far version (`_lod1`) of every part, one joint per
part. See `ops/ASSETS.md` for how they reach the game.

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
