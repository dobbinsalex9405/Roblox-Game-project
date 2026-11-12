# #177 re-check at 3de4e2a4 (batch 13 remerged on main 4c4198f): PASS

Build: `git checkout --detach 3de4e2a442b994832930b7d7c9736c7e0db20c0b`, then `BUILD_ENVIRONMENT=staging tools/build.sh hatchery-heist`. Output reads "core started build=3de4e2a442b9".
- The head contains #172, #174, #175, #179 and #123.
- I opened the local .rbxl in Studio, not the cloud place, and drove it only through the Studio MCP, in play-solo.

## Row 1: four new Rares: PASS

| Species | Meshed (s after give) | Textures | Boxes | One piece | Glow | Legs |
|---|---|---|---|---|---|---|
| Kiwi | 19.0 | 5/5 | 0 | yes | none | under |
| RexHatchling | 27.3 | 6/6 | 0 | yes | none | under |
| SeaOtter | 28.6 | 7/7 | 0 | yes | none | floats on its back (by design) |
| SnowLamb | 31.0 | 9/9 | 0 | yes | none | under |

- SnowLamb's 31.0 s counts from the give. Species load alphabetically, so S arrives late. Under the #168 ruling, 30 s counts from the species' arrival.
- Screenshot: pr177-four-creatures.jpg shows Kiwi, SnowLamb and RexHatchling. SeaOtter is on the neighbouring pad, just out of frame; its numbers are in the table.

## Row 2: odds: PASS

- **Meadow list:** 273 rows, 100.0000%. **52 Rare rows, all "0.0865% · 1 in 1,156"** (pr177-meadow-list-rare.jpg).
- **Moonlit list:** 167 rows, 100.0000%. **29 Rare rows, all "1.03447% · 1 in 96.7"** (pr177-moonlit-list-rare.jpg).
- **Cards:**
  - Meadow 100.0000%: 57.9328 / 37.0694 / 4.4980 / 0.4498 / 0.0450 / 0.0050.
  - Moonlit 100.0000%: 66.60048 / 29.99963 / 3.19986 / 0.19008 / 0.00900 / 0.00095.
  - Basic 100.0000%: 91.9947 / 7.2048 / 0.7005 / 0.0900 / 0.0080 / 0.0020, unchanged from main after #123.

## Row 3: Book: PASS

- The Rare tab shows **21/81**, with all 21 new species by name, each with a NEW badge and a loaded picture.
- Peachick and Polar Bear Cub load once they are scrolled into view, as at e46f6021.
- Screens: pr177-book-rare-top.jpg, pr177-book-rare-bottom.jpg.

## Row 4: standing: PASS

- **#172:** with the pads full (24/24), a hatched Quail went to the inventory with "Your tower is full: Quail went to your inventory. Open Creatures to place it."
- **#174:** the Basic egg on the incubator is its patterned model, 2.60 tall.
- **#175:** I walked in through the front door and back out. The corner shows no frame flicker (pr177-corner.jpg). The rebirth sign is cut from the side, which is pre-existing and was reported in #123.
- **#179:** at ±60°, "2. Book Nook x1.05" and "3. Plant Sunroom x1.30" read whole (pr177-signs-minus60.jpg). In the +60° shot the "Floor 3 built" toast covers sign 3.
- **#123:** the Tower window reads "Build 20K coins" for floor 2. The belt reads "Meadow Egg: 1.5K coins" and "Moonlit Egg: 20K coins".

## Row 5: PASS

- Feedback button visible.
- 0 script errors on the client and the server.
- **0** CreatureView or CreatureAssets warnings.

Raw numbers: output-log.txt.
