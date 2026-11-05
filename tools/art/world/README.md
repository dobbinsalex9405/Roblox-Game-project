# World art (Hatchery Heist)

Trees, eggs, the Egg Market (pedestal, belt, Golden Nest) and farm decor
for the shared centre, in the Storybook Farm style; and the cozy apartment
towers around it: the shell of every floor, the elevator, ladder and floor
plaque, and the decor for all ten floors (magical near the top). Everything is modelled once, at 0.1-stud voxels, in
plain Python with numpy.

| File | What it is |
| --- | --- |
| `vkit.py` | Voxel grids modelled in studs, the pillow mesher, Blender helpers |
| `styles.py` | The three reference directions (colours, shapes) and eggs |
| `props.py` | Trees, eggs, pedestal, belt, Golden Nest, elevator, ladder, plaque |
| `decor.py` | Farm-centre decor, and the decor of floors 8 to 10 |
| `apartment.py` | Apartment decor of floors 1 to 7 (4 zones: cozy, toys, lighting, food) |
| `tower.py` | The apartment shell: floor, back, left, right and front of each floor, and the roof |
| `export.py` | Writes `games/hatchery-heist/src/shared/WorldArt.luau` |
| `build.py` | Draco `.glb` meshes, renders, `meta.json`, 3D viewer copies |
| `partsheet.py` | One render of every prop's Parts version |
| `refscene.py` | Renders a reference scene for direction A, B or C |
| `towerscene.py` | Review renders (map overview, ten-floor cutaway, one room) and the whole tower as one `.glb` |

## Changing a prop

1. Edit `props.py`, `decor.py`, `apartment.py` or `tower.py`. Animated pieces are their own part; the
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

Colours that are only speckle (texture) on another colour are made with
`pick([...])` or `col(hex, of=base)`: the Parts version folds them into the
base colour, so a texture never costs boxes and never leaks into a colour
used plainly somewhere else.

## The apartment tower

Every tower piece shares one anchor: the base centre at its floor's walking
height (the roof: one storey above the highest bought floor). Floor `n`
sits `12 * (n - 1)` studs above floor 1. Footprint x -24..24, base-local z
-3..23; walls are 0.8 thick (inside half wallpaper, outside half facade, so
both faces survive 0.2 and 0.4-stud Parts voxels); the back-left corner is
left open for the 7 x 7 elevator shaft at (-20.5, 20.5) and the right wall
has a doorway at z 12.5..16.5 for the ladder outside at x 25.2.

```sh
PYTHONPATH=/opt/bpy python3 tools/art/world/towerscene.py cutaway build/world/cutaway.png
PYTHONPATH=/opt/bpy python3 tools/art/world/towerscene.py room build/world/room.png --floor 4
```
