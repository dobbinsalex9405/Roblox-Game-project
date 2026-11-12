# #174 at 261c6eec (incubator eggs show their patterned egg models): PASS, with 2 NOTES

Build: `git checkout --detach 261c6eec5412dda85984cc16f765b8d47d5cf680`, then `BUILD_ENVIRONMENT=staging tools/build.sh hatchery-heist`. The stamp reads 261c6eec5412, and Output confirms it: "core started build=261c6eec5412".
- I opened the local .rbxl in Studio (which had auto-updated to version-63eb6055af4e4688), not the cloud place.
- I drove it only through the Studio MCP, in play-solo.
- The diff from main is World.luau (incubatorEgg, syncIncubators), atmosphere.incubatorEggs, Schemas, a spec and CHANGELOG.

## Row 1: three egg types at once: PASS

I bought a Basic, a Meadow and a Moonlit egg off the belt with their Buy prompts. They went to incubators 1, 2 and 3. The incubator's top is at y 1.30 (centre 0.8, a 1-stud disc 4 studs across).

| Incubator | Egg | Instance | Parts | Height | Bottom y | Centre offset | Width |
|---|---|---|---|---|---|---|---|
| 1 | Basic | Model | 22 | 2.60 | 1.30 | 0.00, 0.00 | 2.08 |
| 2 | Meadow | Model | 23 | 2.60 | 1.30 | 0.00, 0.00 | 2.08 |
| 3 | Moonlit | Model | 68 | 2.60 | 1.30 | 0.00, 0.00 | 1.89 |

- Each egg is exactly 2.6 studs tall, centred, and resting on the top: not floating, not sunk.
- At about 2 studs wide on a 4-stud disc, they clear the rim.
- The patterns match the belt art:
  - Basic: cream with speckles;
  - Meadow: green with a darker green band;
  - Moonlit: dark blue with glowing stars.
- The belt versions have 2 more parts each (the crate trim).
- Screens:
  - pr174-three-eggs-player-eye.jpg (Moonlit and Basic, with Meadow behind the character);
  - pr174-three-eggs-side.jpg;
  - pr174-meadow-closeup.jpg (Moonlit and Basic at the edges).

## Row 2: hatch, then rebuy on the same incubator, 10 times: PASS

Each cycle on incubator 1 went: Basic egg ready, hatch (`HH:Hatch`, what the Hatch prompt sends), then buy again off the belt.
- **10/10 cycles:**
  - the egg model is gone right after the hatch (0 Egg instances);
  - the hatch reveal showed;
  - the rebuy put exactly 1 new BasicEgg model on incubator 1.
- **Hatched:** Pomeranian, Llama, BengalKitten, Canary, Dachshund, Cockatoo, SiameseKitten, Hen, AlleyCat, MuddyPiglet.
- **No doubles:** sampled every 0.03 s through all 10 cycles, incubator 1 never held more than **1** Egg at once.
- **No leftovers:** afterwards the world held exactly 3 Egg models outside the market, one per occupied incubator, matching the server's 3 incubators.

## Row 3: respawn or rejoin: PASS (respawn); rejoin not testable locally

- **Respawn:** with 3 eggs incubating I reset with Esc, R, Enter. After the new Character spawned, all three are still patterned Models (22, 23 and 68 parts), not balls.
- **Rejoin:** a play-solo stop and start in Studio starts a fresh save, because DataStores are unavailable. So incubating eggs can't survive a rejoin here, and that path was not exercised.
  - The models are made server-side by `syncIncubators` from the save, the same call for a join as for a buy.
  - The Real-engine/Staging pass is the place for a true rejoin.

## Row 4: sanity from #175: PASS

- **Tower window:** opened from the elevator with E in first person; the cursor was freed (mouse 120,658). It closed with X and the mouse re-locked (675,336).
- **Front door:** I walked from the elevator into the storey and out through the front door to (103, y, 0).
- **Odds cards:** Basic, Meadow and Moonlit tiers each sum to 100.0000%.
- **Feedback** button present.
- **Output:** 0 script errors on the client and the server. 0 lines mentioning incubatorEgg, VoxelProp or CreatureView. All 8 pad creatures were drawn with meshes (see output-log.txt).

## Row 5: standing: NOTE

- Siamese Kitten caught mid-stride, with Hen behind it: legs under their bodies (pr174-stride-kitten-hen.jpg).
- **NOTE:** a Dachshund caught on its pad lies flat with its legs stretched out front and back, not under the body (pr174-stride-dachshund.jpg). From one frame I can't tell a rest pose from the #171 leg displacement. It is pre-existing and not touched by #174.

## NOTES

1. The Dachshund pose above.
2. Studio MCP tool artifact (as in #175): `screen_capture` with a camera position sets the camera to Scriptable, and two of those calls timed out here.
   - I held the camera on Custom with a test-only guard during gameplay steps.
   - It does not affect the game.

Screens: pr174-three-eggs-player-eye, pr174-three-eggs-side, pr174-meadow-closeup, pr174-stride-kitten-hen, pr174-stride-dachshund (.jpg).
