# #179 re-gate at 6e3a9592 (floor plaques 6.5 studs out): PASS

Build: `git checkout --detach 6e3a9592a3504a165ff53375cd7a14c860a6c031`, then `BUILD_ENVIRONMENT=staging tools/build.sh hatchery-heist`. Output reads "core started build=6e3a9592a350".
- I opened the local .rbxl in Studio, not the cloud place.
- I drove it only through the Studio MCP, in play-solo at 1350x672.
- Since the last gate, the plaque is a 12×1.8 BillboardGui on an invisible anchor, 6.5 studs in front of the front wall (AlwaysOnTop false).

## Row 1: floor signs from outside: PASS

I bought floors 2 and 3. **Floor 1 has no plaque.** Only floors 2 and up get one, the same as on main and at the previous head, so "1. Cozy Studio x1.00" does not exist to read; that is a NOTE.

| Angle | Distance | Text read | Whole |
|---|---|---|---|
| 0° | 20 studs | "3. Plant Sunroom x1.30", "2. Book Nook x1.05" | yes |
| +30° | 20 | both, as above | yes |
| −30° | 20 | both | yes |
| +60° | 20 | both ("x1.30" drawn over a roof turret, every letter visible) | yes |
| −60° | 20 | both | yes |
| 0° | 45 | both (small, readable) | yes |
| steep corner view, about 70° | about 15 | "2. Book Nook x1.05" | yes |

Screens: pr179-signs-0deg-20studs, -plus30-, -minus30-, -plus60-, -minus60-20studs, -0deg-45studs, pr179-corner-steep-flicker.

## Row 2: from inside: PASS

- Looking up and out from storey 2, the label shows only faintly through a window, outside the glass (pr179-inside-storey2-up.jpg).
- Nothing floats in the room, and the label overlaps neither the next deck nor the windows from outside.

## Row 3: 10 hatch reveals in first person: PASS

- **Setup:** first person (LockFirstPerson). 10 Basic eggs, all 10 showing their patterned egg model.
- **Reveals 6 to 10:** the hatch key E and the closing input were sent in one input call, with the reveal traced every 20 ms:
  - 6: B during the wobble cracked the egg (creature shown 0.57 s later), and B again closed it.
  - 7: closed with B.
  - 8: **Escape** closed the reveal (0.23 s later) and opened the Roblox menu with nothing behind it. A second Escape closed the menu.
  - 9: B, then B.
  - 10: closed with a **tap**.
- **Reveals 1 to 5:** I sent the inputs as separate tool calls, and the round trip was slower than the reveal. Reveal 1 closed by itself before my input, and reveal 2 closed with B on the shown creature. Reveals 3 to 5 closed, but I can't tie each close to the key press. None of them stuck.
- All 10 closed, with no reveal left on screen. All 10 creatures were placed (Chinchilla, Calf, MuddyPiglet, Turkey, Calf, Wombat, Crow, LopBunny, GuineaFowl, SiameseKitten).
- **Mouse:** after each close the mouse is locked again for first person (LockCenter), as expected. The #179 gate at afeee375 already showed the cursor is freed while a reveal shows (moved to 120,658).
- 0 script errors.

## Row 4: quick checks: PASS

- **#172:** with all 24 pads full, a hatched Iguana went to the inventory (stored 0 → 1) with "Your tower is full: Iguana went to your inventory. Open Creatures to place it.". 0 Sell lines on the server.
- **#174:** all 10 incubating eggs were egg Models.
- **#175:**
  - The front wall stands with windows on every storey.
  - I walked in through the front door to (121, y, 0) and back out.
  - A steep corner view shows no z-fighting on the frames (pr179-corner-steep-flicker.jpg).
- **Logs:** Feedback button visible. 0 script errors on the client and the server. 0 RevealInput, HatchReveal or CreatureView lines.

Raw numbers and the reveal trace: output-log.txt.
