# #168 at 80c7e399 (mesh swap fix): PASS (check 1 PASS per verifier ruling)

**Check 1: PASS per verifier ruling, 30 s counts from species arrival.** The 30 s is MeshArrival's arriveSeconds, which starts when the species model reaches the client, not at the give. The swaps happened as each species arrived in the server's alphabetical load order. That load rate is pre-existing and out of scope; the verifier is noting it for the backlog. Below, the first section is the original check-1 run (recorded before the ruling); checks 2 to 4 follow it.

Build: `git checkout --detach 80c7e399f6d837e28f04cff8e88ccb2aeaa7e2b0`, then `BUILD_ENVIRONMENT=staging tools/build.sh hatchery-heist` (build stamp 80c7e399f6d8). I opened the local .rbxl in Studio, not the Staging cloud place. Everything was driven through the Studio MCP (play-solo, execute_luau, screen_capture), with no screen-control clicks.

The diff from main is CreatureView.luau, CreatureAssets.luau (MeshCount attribute), the new shared/MeshArrival.luau, atmosphere.luau (creatureMeshes timing: arriveSeconds 30, retries 5/15/45/120/300 s), Schemas, a spec and CHANGELOG.

## Check (1) Mesh swap: PASS per verifier ruling (first recorded as FAIL on the literal 30 s bound)

- I gave Llama, Meerkat, Lobster and Dachshund 5.2 s after play started, 0.3 s apart. I sent the same `Test:Command("game", "creature/<id>")` request that the test panel's Give button sends, fired from the Client so it landed inside the first seconds. At that moment ReplicatedStorage.CreatureMeshes held 47 of 509 models, and none of the four species was in it yet.
- All four were drawn as boxes first: Llama 37 parts, Meerkat 28, Lobster 31, Dachshund 32.
- Each one swapped to its meshes. Times are measured from the last give, so a give was 0.3 to 1.2 s earlier:

| Species | Pad | Boxes first | Meshed at | MeshParts | MeshCount attr / children |
|---|---|---|---|---|---|
| Dachshund | Pad4 | 32 | 18.0 s | 9 | 9 / 9 |
| Lobster | Pad3 | 31 | 33.3 s | 10 | 10 / 10 |
| Llama | Pad1 | 37 | 33.3 s | 9 | 9 / 9 |
| Meerkat | Pad2 | 28 | 34.3 s | 7 | 7 / 7 |

- At 50 s, 0 creatures were still on boxes. All 17 creature visuals in the world (5 on pads plus the farm and shop animals) had MeshParts and 0 visible boxes. The remaining Parts are the invisible 0.05-stud `Root_*` joint parts.
- Then I gave one more Llama, a species that was already loaded. It was drawn as meshes 0.37 s after the give, with 9 MeshParts and 0 boxes.
- **Why FAIL:** Lobster, Llama and Meerkat took about 34 to 35 s from the give to swap, which is over the required 30 s. Dachshund took about 19 s.
- **Likely cause:** server load order, not the client wait. CreatureAssets loads the 509 species alphabetically (`table.sort(queue)`, 4 workers). The swap times follow the alphabet: D at 18 s, then L, L and M at 33 to 34 s. CreatureMeshes was 47/509 at the give and 509/509 by 50 s. So the client swapped once each species reached it; the 30 s bound is missed because the species arrived late. I did not record each model's arrival time, so this is an inference, not a measurement.
- A verifier ruling is needed: is the 30 s measured from the give (FAIL) or from the species' arrival (would pass)? I did not retry around it.

Output: 0 `CreatureView: redrawing ... failed` warnings and 0 script errors on the client or server. The only lines were the engine's ContentId fetch warnings and Studio's DataStore notices. See output-log.txt.

Screens: pr168-meshed-pads.jpg (Dachshund and Llama meshed on their pads, Feedback button visible).

## Checks (2) to (4), after the ruling: PASS

I used the same local build (stamp 80c7e399f6d8) in a fresh play-solo session. ReplicatedStorage.CreatureMeshes reached 509 of 509 models about 25 s after I started waiting.

**(2) MeshCount vs MeshPart children: PASS.** All 12 named samples match:

| Species | MeshCount | MeshPart children |
|---|---|---|
| Llama | 9 | 9 |
| Meerkat | 7 | 7 |
| Lobster | 10 | 10 |
| Dachshund | 9 | 9 |
| Koi | 8 | 8 |
| Narwhal | 8 | 8 |
| MantaRay | 7 | 7 |
| LionCub | 10 | 10 |
| DivingBeetle | 11 | 11 |
| Hummingbird | 8 | 8 |
| MoonJelly | 5 | 5 |
| Chick | 8 | 8 |

Across all 509 models there are 0 mismatches.

**(3) Sanity: PASS.**
- **Egg Market odds.** I walked to the market. The HUD card appeared, and I clicked "See every creature", then each tab. Rows were counted in OddsList.Window.Rows and their percentages summed:

| Egg | Rows | Sum | Rows by tier |
|---|---|---|---|
| Basic | 94 | 100.0000% | Common 71, Uncommon 19, Rare 1, UR 1, Epic 1, Legendary 1 (Common "1.2958% · 1 in 77.2") |
| Meadow | 261 | 100.0000% | Common 128, Uncommon 73, Rare 40, UR 13, Epic 6, Legendary 1 |
| Moonlit | 158 | 100.0000% | Uncommon 6 ("9.66675% · 1 in 10.3"), Rare 20 ("1.89999% · 1 in 52.6"), UR 58, Epic 54, Godly 19, Legendary 1 |

  The Basic HUD card is unchanged: 92.0018% / 6.9996% / 0.7986% / 0.1800% / 0.0180% / 0.0020%.
- **Book.** It reads "Found 0/509". Tabs: Common 0/199, Uncommon 0/97, Rare 0/60, UR 0/71, Epic 0/60, Legendary 0/2, Godly 0/20.
- **Scene.**
  - I added 10M coins with the test panel and bought floors 2 and 3 (HH:BuyFloor).
  - I gave all 17 batch-12 creatures through the test panel's Give action, which places each one on a free pad. 8 went to floor 3, 8 to floor 2, and OkapiCalf to floor 1.
  - Result: 17 creatures, **138 MeshParts**, 0 visible boxes and 0 stuck on boxes. That matches #166 and #167. See pr168-scene-17.jpg.
- **Move.** In 6 s: DivingBeetle 3.5 studs, Hummingbird 5.1, Koi 2.3, LionCub 3.4, MagmaSnail 2.1, MantaRay 1.9, MoonJelly 4.3, Narwhal 4.0.
- **Earn.** Income shows +964/s. Auto-collecting rose from 12.16K to 16.04K in 4 s.
  - #167 showed +978/s. Here OkapiCalf sits on floor 1 (x1) instead of a bonus floor.
- **Respawn.**
  - Before: 8 of 8 odds signs present and changing.
  - I reset with Esc, R, Enter, and a new Character spawned after 7 s.
  - After: 8 of 8 signs changed in each of three 5 s windows. See pr168-after-respawn.jpg.
- **Feedback.** PlayerGui.CoreFeedback.FeedbackButton is visible and enabled.

**(4) Output: PASS.** I checked LogService after the respawn:
- Client: 397 lines, all ContentId fetch warnings. 0 errors, 0 "CreatureView: redrawing ... failed", 0 OddsView or Hud lines.
- Server: 0 errors. Besides ContentId, Economy and Analytics lines, only the usual Studio notices: profilestore, Stores DataStores unavailable, TestPanel on, CoreServer started.
- Check 1's session was also clean (output-log.txt).

## Overall for #168 at 80c7e399: PASS

Check 1 is a PASS per the verifier's ruling, and checks 2, 3 and 4 PASS.

Screens: pr168-meshed-pads.jpg, pr168-odds-moonlit.jpg, pr168-scene-17.jpg, pr168-after-respawn.jpg.
