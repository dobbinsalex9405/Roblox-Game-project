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
| `rooms.py` | The upgrade path inside every floor: beds, rugs, ceiling lights, corner plants and crests (kind `room`) |
| `rooms_layout.py` | Where every upgrade's pieces go on each floor, with the space checks; writes `config/towerDecor.luau` |
| `roomscene.py` | Renders one floor at each upgrade level, and the five side by side |
| `tower.py` | The apartment shell: floor, back, left, right and front of each floor, and the roof |
| `export.py` | Writes `games/hatchery-heist/src/shared/WorldArt.luau` |
| `build.py` | Draco `.glb` meshes, renders, `meta.json`, 3D viewer copies |
| `partsheet.py` | One render of every prop's Parts version |
| `refscene.py` | Renders a reference scene for direction A, B or C |
| `shop.py` | The Golden Egg Shop (walk-in Robux shop): its props and `LAYOUT`, where the game puts each one |
| `shopexport.py` | Writes `games/hatchery-heist/src/shared/ShopArt.luau` (props + layout) and `build/world/shopart.json` |
| `shopbuild.py` | The shop's `.glb` files, renders, `meta.json` and viewer copies (World/Hatchery Heist/Golden Egg Shop) |
| `shopscene.py` | Review renders of the whole shop: outside, inside, each display wall, the counter, the door |
| `towerscene.py` | Review renders (map overview, ten-floor cutaway, one room) and the whole tower as one `.glb` |

## Changing a prop

1. Edit `props.py`, `decor.py`, `apartment.py`, `rooms.py` or `tower.py`. Animated pieces are their own part; the
   part's `anim` says how the game moves it (`slide`, `spin`, `sway`, `bob`,
   `flicker`, `pulse`, `roll`, `rock`, `turn`, `drip`, `glint`).
2. `python3 tools/art/world/export.py` and commit `WorldArt.luau` with it.
   `--only` writes just those props (handy for a quick look), so always end
   with a full export before committing or rendering a scene.
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

## The upgrade path inside the tower

Each of a floor's four upgrades adds one room-wide layer and the zone props
from `apartment.py` / `decor.py`: 1 beds on all eight pads (the grey pads
hide), 2 a 40 x 20 rug under the pad grid, 3 four ceiling lights with real
lights, 4 four corner plants and a crest on the back wall. Floor 1 is a
fixed starter room. The names players see ("Next: Reading lamps") are in
`rooms_layout.py`, and the game furnishes the floors near the camera on the
client (`src/client/TowerDecorView.luau`). Plan:
`/mnt/project-files/plans/hatchery-heist/apartment-upgrade-path.md`.

Space rules, checked by `rooms_layout.py` and `tests/TowerDecor.spec.luau`:
creatures wander their pad cells (x -20..20, z 0..20), so only flat beds and
the rug go there and lights hang above 8.5; nothing in the elevator shaft or
in front of its door; nothing standing within 2 studs of the ladder opening
(x 21..24, z 12.5..16.5) and flat pieces half a stud from it; nothing in
front of the windows or over the pictures.

```sh
python3 tools/art/world/rooms_layout.py          # check and write config/towerDecor.luau
stylua games/hatchery-heist/config/towerDecor.luau
PYTHONPATH=/opt/bpy python3 tools/art/world/roomscene.py build/world/path --floor 4 --fast
```

## The Golden Egg Shop

The shop's props are in `shop.py` (kind `shop` or `shopdisplay`) and go to
their own module, `ShopArt.luau`, not `WorldArt.luau`, so the two never
conflict. Change the art or `LAYOUT`, then:

```sh
python3 tools/art/world/shopexport.py
lune run tools/test/run ShopArt
python3 tools/art/world/shopscene.py build/world/shopscenes --fast        # look at it
python3 tools/art/world/shopbuild.py build/world/shop --whole --designs /mnt/project-files/designs
```

Every display stands for one Robux item of the Shop window (`ShopPlan`
checks both ways). No letters or numbers in the art: the game shows props
mirrored left to right, so text goes on the signs as SurfaceGui text.
