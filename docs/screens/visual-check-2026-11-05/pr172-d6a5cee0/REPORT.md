# #172 at d6a5cee0 (hatch with no open slot: never auto-sell): PASS (row 4 skipped), with 1 NOTE

This replaces the FAIL at 2fe4fc15.

Build: `git checkout --detach d6a5cee07fba27e5927daad52c2d38d7503678a9`, then `BUILD_ENVIRONMENT=staging tools/build.sh hatchery-heist`. Output reads "core started build=d6a5cee07fba".
- I opened the local .rbxl in Studio, not the cloud place.
- I drove it only through the Studio MCP, in play-solo.
- Counts come from the player data the server pushes (Core:Data). Sales come from the server's `[Economy]` log.
- Hatches were real: eggs bought off the belt through their Buy prompts, then `HH:Hatch` per incubator.

## Row 1: full tower, inventory below cap, 10 hatches in a row: PASS

Floor 1 pads were 8/8. I bought 10 Basic eggs and hatched them 0.35 s apart.

| | Placed | Inventory | Incubating | Coins |
|---|---|---|---|---|
| Before | 8 | 0 | 10 | 7,297,576 |
| After | 8 | **10** | 0 | 7,299,016 |

- **Hatched:** HuskyPup, Bantam, Rooster, BarnCat, TuxedoKitten, Rooster, BarnCat, LionheadBunny, AngoraBunny, Goldfish. All 10 went to the inventory, and inventory rose by exactly 10.
- **Notices:** 10 of "Your tower is full: <Name> went to your inventory. Open Creatures to place it.", one per hatch, each with the right name.
- **Creatures window:** "Earning: 8/8 slots used. In your inventory: 10." All 10 are listed by name as "Inventory" rows (pr172-row1-inventory-list.jpg).
- **Coins:**
  - The coin change during each hatch was 0 except one +1440. That is `reason=Gameplay:Collect`, the auto-collect tick (8 × 6/s × 30 s), not a sale.
  - The server log has **0** Sell lines.

## Row 2: full inventory: PASS

1. **Setup:** I gave 280 OkapiCalf (inventory 290), bought one Basic egg, then gave 10 more. Now: inventory **300**, pads 8/8, 1 egg incubating.
2. **Buying at the cap is refused.** I tried 3 more Basic eggs.
   - Each was refused with exactly "Your tower and inventory are full (300). Unlock a new floor to make room."
   - Incubating stayed at 1, and the server's `Shop:BasicEgg` count stayed at 11, so no coins were spent.
3. **A ready egg waits.** I pressed Hatch on the ready egg.
   - Inventory stayed 300, pads 8, incubating 1. The egg is still on incubator 1 as its BasicEgg model.
   - No HH:Hatched event, no reveal, nothing sold.
   - The notice read exactly "Your tower and inventory are full (300). Make room in your inventory, then hatch: your egg waits here." (pr172-row2-egg-waits.jpg)
4. **Making room works.** There is no sell action, so I freed a pad the intended way: I unlocked floor 2 (`Shop:TowerFloor`).
   - Hatch then succeeded: a BengalKitten on pad 9.
   - Pads 8 → 9, inventory 300, incubating 0, and the egg model is gone.

## Row 3: a creature received past the cap: PASS

- I filled floor 2's pads (16/16), then gave a Meerkat at inventory 300.
- It arrived: inventory **301**, 317 creatures in all. The panel said "Meerkat added to your inventory (the tower is full)."
- Coins were unchanged (7,282,679), and nothing was sold.
- Through all of rows 1 to 3 the server `[Economy]` log was: Shop:BasicEgg 11, IncubatorSlot 7, TowerFloor 1, Gameplay:Collect 8, Admin:StudioTest 1, and **0 Sell**.

## Row 4: older save shape: SKIPPED

The Studio test panel offers only "Give a creature". It has no way to load an older save shape, so this row was not run.

## Row 5: sanity: PASS

- **#174 egg models:** after unlocking floor 3, a Moonlit egg sits on incubator 1 as its model (68 parts, 2.60 tall, bottom 1.30 = the incubator top).
- **#175 Tower window:** opened from the elevator with E in first person; the cursor was freed (mouse 120,658). It closed with X and the mouse re-locked (675,336).
- **Front door:** I walked in and out through it.
- **Odds cards:** Basic, Meadow and Moonlit each 100.0000%.
- **Feedback** button visible.
- **Output:** 0 script errors (client and server). 0 CreatureView, incubatorEgg or VoxelProp lines. 0 pad creatures without meshes.

## Row 6: standing: NOTE

- The Bengal Kitten on floor 2 has its legs under its body (pr172-stride-bengal-kitten.jpg).
- **NOTE:** every Dachshund on floor 1 (8 of them, the only species there) lies flat with its legs stretched out front and back, not under its body (pr172-stride-dachshunds.jpg).
  - This is the same pose noted in the #174 gate, so it is consistent for the species.
  - It is pre-existing (#171 area or the Dachshund's rest pose) and not touched by #172.
  - The brief's "two walking creatures" could not be met with a second species here, because the pads were filled with Dachshunds for the test.

Screens: pr172-row1-inventory-list, pr172-row2-egg-waits, pr172-stride-bengal-kitten, pr172-stride-dachshunds (.jpg).
