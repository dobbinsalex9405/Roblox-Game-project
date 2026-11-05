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
3. **Meshes.** `tools/art/blender/build.py` turns the same voxels, at twice
   the detail for the small tiers, into bevelled voxel meshes. It writes
   `.fbx` and `.glb` files, the palette texture, `meta.json` and review
   renders. Renders for Alex go in project files under
   `art/hatchery-heist/blender/<id>/`.
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
- A Common is about 6,000 to 8,000 triangles in all. Legendaries and Godlies
  are 40,000 to 65,000. Mesh render fidelity stays Automatic, so distant
  creatures use fewer triangles.
- The palette textures are tiny (64 × 16 to 64 × 64 pixels).
