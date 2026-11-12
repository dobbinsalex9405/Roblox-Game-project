# #168 at 80c7e399 (mesh swap fix): FAIL on check (1), the 30 s bound; stopped there

Build: `git checkout --detach 80c7e399f6d837e28f04cff8e88ccb2aeaa7e2b0`, then `BUILD_ENVIRONMENT=staging tools/build.sh hatchery-heist` (build stamp 80c7e399f6d8). I opened the local .rbxl in Studio, not the Staging cloud place. Everything was driven through the Studio MCP (play-solo, execute_luau, screen_capture), with no screen-control clicks.

The diff from main is CreatureView.luau, CreatureAssets.luau (MeshCount attribute), the new shared/MeshArrival.luau, atmosphere.luau (creatureMeshes timing: arriveSeconds 30, retries 5/15/45/120/300 s), Schemas, a spec and CHANGELOG.

## Check (1) Mesh swap: FAIL (literal 30 s bound); the stuck-boxes bug itself is fixed

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

## Checks (2) MeshCount for 10 species, (3) sanity, (4) Output: not run

I stopped at the first FAIL, as briefed. For the four species above, MeshCount already matches their MeshPart children.

Screens: pr168-meshed-pads.jpg (Dachshund and Llama meshed on their pads, Feedback button visible).
