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
| `shop.py` | The Golden Egg Shop (walk-in Robux shop): its props and `LAYOUT`, where the game puts each one |
| `shopexport.py` | Writes `games/hatchery-heist/src/shared/ShopArt.luau` (props + layout) and `build/world/shopart.json` |
| `shopbuild.py` | The shop's `.glb` files, renders, `meta.json` and viewer copies (World/Hatchery Heist/Golden Egg Shop) |
| `shopscene.py` | Review renders of the whole shop: outside, inside, each display wall, the counter, the door |

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
