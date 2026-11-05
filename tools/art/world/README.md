# World art (Hatchery Heist)

Trees, eggs, the Egg Market (pedestal, belt, Golden Nest), the elevator,
ladder and floor plaque, and the decor for all ten tower floors, in the
Storybook Farm style. Everything is modelled once, at 0.1-stud voxels, in
plain Python with numpy.

| File | What it is |
| --- | --- |
| `vkit.py` | Voxel grids modelled in studs, the pillow mesher, Blender helpers |
| `styles.py` | The three reference directions (colours, shapes) and eggs |
| `props.py` | Trees, eggs, pedestal, belt, Golden Nest, elevator, ladder, plaque |
| `decor.py` | Floor decor, 10 floors x 4 zones (cozy, toys, lighting, food) |
| `export.py` | Writes `games/hatchery-heist/src/shared/WorldArt.luau` |
| `build.py` | Draco `.glb` meshes, renders, `meta.json`, 3D viewer copies |
| `partsheet.py` | One render of every prop's Parts version |
| `refscene.py` | Renders a reference scene for direction A, B or C |

## Changing a prop

1. Edit `props.py` or `decor.py`. Animated pieces are their own part; the
   part's `anim` says how the game moves it (`slide`, `spin`, `sway`, `bob`,
   `flicker`, `pulse`, `roll`, `rock`, `turn`, `drip`, `glint`).
2. `python3 tools/art/world/export.py` and commit `WorldArt.luau` with it.
   `lune run tools/test/run WorldArt` checks it is well formed and within
   each kind's box budget.
3. Look at it:

```sh
PYTHONPATH=/opt/bpy python3 tools/art/world/partsheet.py build/world/sheet.png --floor 1
PYTHONPATH=/opt/bpy python3 tools/art/world/build.py build/world/props --only HayBaleBed --designs /mnt/project-files/designs
```

Thin bits under about 0.2 studs disappear in the Parts version: draw them
at least 0.2 thick.
