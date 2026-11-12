# #179 at afeee375 (reveal closes on B and the menu; floor plaque in front of the wall): FAIL on row 1 (plaque cut by the wall from the side); rows 2-4 PASS

Build: `git checkout --detach afeee37578b0c75c8fd0acda7c7d4faf80bf5558`, then `BUILD_ENVIRONMENT=staging tools/build.sh hatchery-heist`. Output reads "core started build=afeee37578b0".
- I opened the local .rbxl in Studio, not the cloud place.
- I drove it only through the Studio MCP, in play-solo at 1350x672.
- The brief did not say to stop at the first FAIL, so I ran every row to give the builder the full picture.

## Row 1: floor signs: FAIL (from the side)

I bought floors 2 and 3.

- **From the front: OK.** At normal play distance, "2. Book Nook x1.05" and "3. Plant Sunroom x1.30" are complete. Each sits in the band above its storey's windows and below the next deck, without clipping the deck, the windows or the flower boxes (pr179-plaques-front.jpg).
- **From the side: names cut by the wall.**
  - At about 30° off the front the labels read "…ok Nook x1.05" and "…t Sunroom x1.30" (pr179-plaques-30deg-cut.jpg).
  - At about 55° they read ": Nook x1.05" and "Sunroom x1.30" (pr179-plaques-side-55deg-cut.jpg).
  - The part of each label on the far side is hidden behind the front wall.
- **Why:** the billboard is 12 studs wide, faces the camera, and hangs 1.5 studs in front of the wall (`Geometry.FLOOR_PLAQUE.out = 1.5`, AlwaysOnTop false). Seen at an angle θ, its far edge sits 6·sin θ behind its centre. That reaches the wall once θ is more than about 14.5° off straight-on. So any player not standing nearly straight in front of the tower sees a truncated name.
- **Possible fixes:** `out` of at least about 6 for full readability up to 90°, a narrower label, or AlwaysOnTop (with a MaxDistance).
- **Inside storey 2:** no plaque floats in the room (pr179-inside-storey2.jpg).
- **Floor 1 has no plaque.** The build loop makes plaques for floors 2 and up only, the same as main. So the brief's "1. Cozy Studio x1.00" sign does not exist; that floor's name shows only in the Tower window. This is not a regression from this PR; it is a NOTE for the coordinator.

## Row 2: reveal with B, Escape, tap and auto-close, 10 hatches: PASS

I bought 10 Basic eggs into incubators 1 to 10 and hatched them one or three at a time.
- "on" means the reveal is up (its dim backdrop is visible).
- "shown" means the creature and its words are showing.

| # | View | What I did | Result |
|---|---|---|---|
| 1 | 3rd | B during the wobble (t+0.3 s), then B again | The B cracked the egg: shown at t+0.9 s, against about 1.5 to 1.9 s untouched. The second B closed the reveal. |
| 2 | 3rd | Escape once the creature was shown | The reveal closed. The Roblox menu is on top with no reveal behind it. A second Escape closed the menu. |
| 3 to 5 | 3rd | Hatched 3 together (queued), then Escape during the first wobble | All 3 skipped and the menu was on top. No reveal reappeared in the next 6 s. |
| 6 | 3rd | B on the shown creature | Closed |
| 7 | 3rd | A plain tap (click at 150,400) | Closed |
| 8 | 3rd | Left alone | Closed by itself after 3.6 s |
| 9 | **1st** | B, then B | The cursor was free during the reveal (mouse 120,658) and B closed it. Afterwards the mouse was re-locked (675,336) and the character walked 10.7 studs. |
| 10 | **1st** | Escape during the wobble | The reveal closed and the menu opened. After the menu closed, the mouse was locked at the centre again. |

- No reveal ever got stuck.
- HH:Hatched fired 10 times: Chick, TabbyKitten, BarnCat, Gosling, Goldfish, ChihuahuaPup, FrizzleChick, Chipmunk, ShetlandPony, SugarGlider.
- The Creatures window lists all 10 by name ("Earning: 10/24 slots used. In your inventory: 0.").
- The Roblox menu itself is Roblox's own overlay, which a screen capture does not include. "Menu on top" was read from `GuiService.MenuIsOpen`. pr179-after-escape-no-reveal.jpg shows no reveal left behind.

## Row 3: sanity: PASS

- **#172:** with all 24 pads full, a hatched Dutch Bunny went to the inventory (stored 0 → 1). The notice read "Your tower is full: Dutch Bunny went to your inventory. Open Creatures to place it." Coins were unchanged, and the server log has 0 Sell lines.
- **#174:** the Basic egg on incubator 1 is its model, 2.60 tall, bottom 1.30 (the incubator top).
- **#175:** the Tower window opened from the elevator with E in first person, with the cursor freed (120,658), and closed with X.
- **Odds cards:** Basic, Meadow and Moonlit each 100.0000%.
- **Feedback** button visible.
- **Output:** 0 script errors (client and server). 0 RevealInput, HatchReveal or CreatureView lines.

## Row 4: standing: PASS

A Chick caught mid-stride and a Bantam both have their legs under their bodies (pr179-stride-chick-bantam.jpg). No Dachshunds were used.

Screens: pr179-plaques-front, pr179-plaques-30deg-cut, pr179-plaques-side-55deg-cut, pr179-inside-storey2, pr179-after-escape-no-reveal, pr179-stride-chick-bantam (.jpg).
