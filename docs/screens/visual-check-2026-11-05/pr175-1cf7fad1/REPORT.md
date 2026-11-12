# #175 at 1cf7fad1 (Modal guard on every window; tower front wall, door and fade; no z-fighting): PASS, with 4 NOTES

Build: `git checkout --detach 1cf7fad10393c73f3400f5db4240c2a588e58ca8`, then `BUILD_ENVIRONMENT=staging tools/build.sh hatchery-heist` (stamp 1cf7fad10393). The diff from main is the two PR commits.
- I opened the local .rbxl in Studio, not the cloud place.
- I drove it only through the Studio MCP, in one play-solo session of about 38 minutes, at 1350x672.
- I could not read the PR body: the laptop has no `gh`, and I did not use a token. I followed the verifier's checklist and the CHANGELOG / DECISIONS entries in the diff.

**How "first person" was tested.**
- `Player.CameraMode = LockFirstPerson` (zoom 0.5, `MouseBehavior = LockCenter`).
- With the mouse locked, a click on a HUD button (Book, Shop, ...) does nothing, because the cursor is held at the centre. That is ordinary Roblox first-person behaviour and not this PR.
- So each HUD window was opened in third person and the camera was locked back into first person while it was open. Every close test then ran in first person.
- The elevator and the hatch reveal were opened in first person with their own E prompts. The elevator is the case Alex hit.

**What each column means.** The output log has the exact method and raw lines.
- **Freed:** with the window open, a mouse move to (120,600) moves the cursor there, where locked it stays at (675,336).
- **Re-locked:** after closing, the same move leaves the cursor at the centre again.
- **Moves:** holding W or S then walks the character.

## Row 1: first person, every window: PASS

| Window | Freed | X closes | Escape closes | Tap outside closes | B closes | Re-locked + moves |
|---|---|---|---|---|---|---|
| Elevator -> Tower (E prompt) | yes | yes | yes | yes | yes | yes, 9.6 studs |
| Shop | yes | yes | yes | yes | yes | yes, 12.7 |
| Book | yes | yes | yes | yes | yes | yes, 15.9 |
| Tower (side menu) | yes | yes | yes | yes | yes | yes, 12.7 |
| Pets (Creatures) | yes | yes | yes | yes | yes | yes, 12.8 |
| Daily | yes | yes | yes | yes | yes | yes, 12.8 |
| Guide (Welcome) | yes | "Let's go!" (no X) | yes | yes | yes | yes, 12.8 |
| Music | n/a: a mute toggle, no window | | | | | |
| Odds list ("See every creature") | yes | yes | yes | yes | yes | yes, 10.1 |
| Hatch reveal | yes | n/a: "Tap to continue" | **no** (see NOTE 1) | yes | **no** (see NOTE 1) | yes, 9.7 |
| Feedback | yes | yes | yes | yes | yes | yes, 12.8; also after a respawn, 11.7 |

- Escape closes the window **and** opens the Roblox menu, as DECISIONS.md describes: the menu opening is the close signal. A second Escape closes the menu.
- B is the gamepad `ButtonB` sent through the Studio MCP.
- Screens:
  - pr175-fp-book-open.jpg
  - pr175-fp-elevator-tower-open.jpg (opened from the elevator in first person; the dim backdrop is behind it)
  - pr175-fp-feedback-open.jpg
  - pr175-fp-hatch-reveal.jpg

## Row 2: third person: PASS

- Book, Tower, Pets, Daily, Guide, Shop and Feedback each opened from their button and closed with their X in one run. All 7 were seen open and none was left open.
- The elevator opened with E, and Escape and tap outside closed it.
- The odds list opened and closed with its X.

## Row 3: tower front wall: PASS

I bought floors 2 and 3, so the tower has 3 storeys.

- **The wall exists.** My shell has 1,802 parts, including 32 window panes, against 788 for a 1-storey tower. Every storey has a full-width front wall:
  - storeys 2 and 3 have 4 windows each;
  - storey 1 has 2 windows and the door with its awning.
  - See pr175-tower-front-outside.jpg.
- **The door is passable both ways.** I walked from (103,y,0) to (122,y,0) through the door and reached the inside, then walked back out the same way.
- **The fade works.** Front parts with LocalTransparencyModifier above 0.5:

| Where I stood | Storey 1 front | Storey 2 front | Storey 3 front |
|---|---|---|---|
| Inside storey 1, camera out front | 128/137 | 74/81 | 0/76 |
| Inside storey 2 (by the elevator's GoFloor) | 0 | 74/81 | 74/76 |
| Inside storey 3, the top | 0 | 0 | 74/76 |
| Back outside | 0 | 0 | 0 |

  So the fade covers the player's storey and the one above, as specified. The unfaded few on each storey are the planters and awning in front of the wall, which are not TowerFront parts. See pr175-inside-storey1-fade.jpg and pr175-inside-storey2-fade.jpg.
- **No gap at the corners.** The front-left corner is closed from outside, and the storey trim runs round the corner unbroken (pr175-corner-front-left.jpg). From inside, the front wall meets the side walls (pr175-stride-gecko-bunny.jpg shows the door from inside).

## Row 4: flicker: PASS (visual)

- I looked at the front corner, a floor-to-frame join and the back wall at a window box, nudging the camera a little between captures.
- None of them shows z-fighting stripes. See pr175-corner-front-left.jpg, pr175-flicker-corner-floor-join.jpg and pr175-flicker-back-wall.jpg.
- I also ran a raw geometric count on the live shell: overlapping faces in the same plane, facing the same way, with different colours. It found 949 pairs.
  - That count ignores whether a face is hidden behind a third part, and pairs within one piece. It is not the PR's "visible coplanar faces from two pieces" measure, for which TowerShell.spec reports 0.
  - The most-flagged spot (back wall, z 22.8, y 3.8 to 4.6) looks clean on screen.
  - So this is information only, not a finding.

## Row 5: sanity: PASS

- **Odds:**

| Egg | Rows | Sum |
|---|---|---|
| Basic | 94 | 100.0000% |
| Meadow | 261 | 100.0000% |
| Moonlit | 158 | 100.0000% |

- **Book:** "Found 0/509" at the start (pr175-fp-book-open.jpg). It read 3/509 after I hatched Quail, Gecko and AngoraBunny, which is expected.
- **Place and earn:** the hatched and given creatures went onto pads 1, 2, 3 and 17. Income was +25/s, and auto-collect rose 609 -> 711 in 4 s.
- **Respawn:** Esc, R, Enter gave a new character after 7.9 s, with 0 errors.
- **Feedback:** the button is visible, and its window opens and closes in first person after the respawn.
- **Output:** 0 script errors and 0 CreatureView lines on the client and the server (output-log.txt).

## Row 6: standing: NOTE only, no displacement seen

- A walking Quail and the walking Gecko and AngoraBunny all have their legs under their bodies.
- See pr175-stride-quail.jpg and pr175-stride-gecko-bunny.jpg.

## NOTES (not FAILs; for the verifier)

1. **The hatch reveal is not closed by Escape or B.**
   - It only got `dim.Modal = true` in this PR, which frees the mouse; it is not on `Modal.attach`.
   - The mouse is freed, a tap anywhere closes it, and it closes by itself within about 10 s. So the player is never stuck.
   - Escape opens the Roblox menu with the reveal still behind it, and B does nothing.
   - I judged this a NOTE because the PR describes the reveal as tap-to-continue. If the rule is that every overlay closes on Escape and B, this is the one gap.
2. **Quail drawn as boxes (CreatureView, pre-existing; not touched by #175).**
   - Quail hatched and was then also given, 13 to 20 minutes into the session, with CreatureMeshes at 509/509 and the Quail model complete (MeshCount 9 = 9). Both Quails stayed voxel boxes (0 MeshParts, 16 boxes) even with the camera 12 studs away.
   - There were no CreatureView warnings and no fetch failure for any Quail asset id. Gecko and AngoraBunny meshed normally.
   - As a diagnostic I ran `ContentProvider:PreloadAsync` on the Quail model myself. All 18 assets came back Success, and within about 1 s both Quails showed 9 MeshParts.
   - This looks like CreatureView's own preload for that species never returning (#168's MeshArrival path), not a failure. It is worth a follow-up issue. My diagnostic call may have unblocked it.
3. **Floor-name signs are cut by the new front wall.**
   - Seen from outside, "2. Book Nook x1.05" and "3. Plant Sunroom x1.30" show only in fragments where the wall covers them (pr175-tower-front-outside.jpg).
   - This is cosmetic; the signs read fully from inside.
4. **A Studio MCP tool artifact, not the game.**
   - Two `screen_capture` calls with a camera position timed out. After that, Studio's MCP reset the camera to Scriptable after every tool call (Output: "The execute_luau changed camera type. Resetting from ...").
   - The game has no `Scriptable` anywhere.
   - Rows 1 and 2 were finished before this started. For the final post-respawn check I held the camera on Custom with a test-only guard.

Screens: pr175-fp-book-open, pr175-fp-feedback-open, pr175-fp-elevator-tower-open, pr175-fp-hatch-reveal, pr175-tower-front-outside, pr175-inside-storey1-fade, pr175-inside-storey2-fade, pr175-corner-front-left, pr175-flicker-corner-floor-join, pr175-flicker-back-wall, pr175-stride-quail, pr175-stride-gecko-bunny (.jpg).
