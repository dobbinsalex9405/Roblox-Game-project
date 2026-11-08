# Creature meshes: from Blender to the game

Hatchery Heist's creatures are drawn from Blender meshes once those are
uploaded to Roblox. Until then, and for any creature whose meshes fail to
load, the game draws the same creature from its VoxelArt boxes. A missing or
broken upload never breaks a hatch.

## How a creature gets its meshes

1. **Shapes.** Every creature is defined once, in `tools/art/creatures.py`
   (and `legends.py` for the Legendaries and Godlies). Adding a Common is one
   ROSTER line.
2. **In-game boxes.** `python3 tools/art/export.py` writes
   `src/shared/VoxelArt.luau`. This works at once and needs no upload.
3. **Meshes.** `tools/art/blender/build.py` turns the same voxels, rebuilt
   at one voxel size for every tier (0.1 stud, Alex's pick), into bevelled
   voxel meshes plus a flat far version (`*_lod1`) of every part. It writes
   `.fbx` and `.glb` files, the palette texture, `meta.json` and review
   renders. `--designs /mnt/project-files/designs` also copies each creature
   into the design library Alex browses in the 3D viewer
   (`Creatures/Hatchery Heist/<Tier>/<Species>/`).
4. **Upload.** Start the **Upload creature meshes** workflow by hand. It
   builds the meshes, uploads each creature's `.fbx` as a Model asset, and
   opens a draft PR that records the asset ids in
   `tools/art/blender/assets.json` and `src/shared/CreatureMeshes.luau`.
5. **In game.** `server/CreatureAssets` loads each uploaded Model with
   `InsertService:LoadAsset` into `ReplicatedStorage.CreatureMeshes`. The
   client's `CreatureView` puts the meshes on the same joints, with the same
   animation, glow and fade as the boxes.
6. **Checks.** The PR with the ids is verified like any other, including the
   visual playtest. Look at every creature in the game and in the Hatchery
   Book. Then merge.

`python3 tools/art/blender/luau.py` regenerates `CreatureMeshes.luau` from
the art and `assets.json`. CI checks that the committed file is current.

## The one step only Alex can do

The upload uses the Hatchery Heist Staging key (`ROBLOX_API_KEY_HATCHERY_HEIST`
in the `staging` environment). That key needs the **Assets API** permission
with **asset:read** and **asset:write**.

1. Open the Creator Dashboard and go to **Open Cloud → API Keys**.
2. Open the "Staging publish (GitHub Actions)" key.
3. Under **Access Permissions**, add **Assets API** and tick **Read** and
   **Write**.
4. Click **Save Changes**. Do not regenerate the key.

## Ownership

A game can only load assets that its own owner created. The upload creates
assets for the group that owns the Hatchery Heist Staging experience; it
looks the group up from `ops/environments.json`, so no id is stored here.

If Production is ever published under a different group, upload the meshes
again with that group's key. Production then needs its own ids (see
`ops/DECISIONS.md`, 2026-11-05).

## Budgets

- Meshes are at most 18,000 triangles each. Roblox allows 20,000; bigger
  parts are split.
- Close up (LOD0), a creature is at most 15,000 triangles for Common to Rare,
  20,000 for Ultra Rare, 28,000 for Epic and 40,000 for Legendary and Godly
  (`CreatureMeshes.spec`). Today: Commons 5,500 to 10,800, Godlies 32,000 to
  37,000. Undersides and glowing faces (Neon shows no bevel) are flat.
- Far away (past 30 studs) the game draws LOD1: flat, greedy-merged faces, at
  most 4,000 triangles a creature (most about 1,000). This keeps a floor of 8
  to 10 creatures light on a phone.
- The palette textures are tiny (64 × 16 to 64 × 64 pixels).

## Hatchery Book pictures

The Hatchery Book shows each creature as a still picture, not a live 3D
view: Roblox only draws a ViewportFrame while it is on screen, so a flick
or a reopen left cards empty for a moment. The pictures come from the same
meshes and colours as the game and Alex's viewer.

1. `build.py OUT --thumbs` renders each creature the game lists at rest,
   three-quarter view, on a clear background, cropped to its outline and
   centred in a 256 × 256 PNG (`OUT/<id>/<id>_thumb.png`, about 4 s each).
   `thumb.json` beside it holds the art fingerprint it was drawn from
   (`thumbs.py`: meshes, colours and the picture style).
2. Run the **Upload creature meshes** workflow with **art = thumbs** (and
   `only` for a batch). It uploads each picture as an **Image** asset and
   opens a draft PR recording the ids under `"thumbs"` in
   `tools/art/blender/assets.json` and in `src/shared/CreatureThumbs.luau`.
3. `luau.py` lists a picture only while its fingerprint matches the
   creature's art now. A reworked or recoloured creature drops out of
   `CreatureThumbs.luau` (and `luau.py` names it), so the Book draws it
   live until its new picture is uploaded. Changing the picture style
   means bumping `thumbs.STYLE`, which redraws them all.

An uploaded Image is moderated before it shows. Until then it draws
nothing, so look at a batch in game before merging its ids.

## Outdoor nature, skybox and grass

The trees, bushes, rocks, flowers, the six skybox faces and the grass tile
go the same way, from `tools/art/env` (its README says how). Run the
**Upload creature meshes** workflow with **art = nature** on a branch; it
commits `tools/art/env/assets.json`, `env.json` and `EnvArt.luau` back onto
that branch. The sky faces and grass tile are uploaded as **Image** assets,
never Decals: a Decal id on a Sky face or Texture draws nothing, and
`luau.py` writes 0 for any image not recorded as an Image. A push made by
the workflow does not start CI, so follow it with a real commit.
`server/EnvAssets` loads the models into ServerStorage and
Scenery places copies; until a tree loads the game draws its box tree.
