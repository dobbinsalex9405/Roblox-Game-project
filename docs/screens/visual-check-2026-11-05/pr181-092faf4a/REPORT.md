# #181 at 092faf4a (199 creature models re-uploaded at rest): PASS

Build: `git checkout --detach 092faf4ab965167a77850677274de47d5b7b0694`, then `BUILD_ENVIRONMENT=staging tools/build.sh hatchery-heist`. Output reads "core started build=092faf4ab965".
- I opened the local .rbxl in Studio, not the cloud place.
- I drove it only through the Studio MCP, in play-solo at desktop size.

## Check 1: warnings and attributes: PASS

- I waited for all **530** species to load before reading anything.
- **"creature meshes do not sit where CreatureMeshes lists them": 0 warnings** (it was 198 at #171).
- **ImportFit:** 0 of the 530 species have ImportFit above 0.01.

| Species | ImportYaw | ImportFit (studs) |
|---|---|---|
| AuroraStag | 3.1416 (π) | 0.000075 |
| SnowHare | π | 0.000071 |
| MoonJelly | π | 0.000080 |
| Bunny | π | 0.000079 |
| Frog | π | 0.000094 |
| CrystalHydra | π | 0.000084 |
| Eaglet | π | 0.000050 |
| Jackalope | π | 0.000088 |

## Check 2: the 8 species at rest: PASS

- **One piece:** every species' visible meshes form one connected piece, with nothing floating apart.

| Species | Meshes | Pieces |
|---|---|---|
| AuroraStag | 35 | 1 |
| Bunny | 9 | 1 |
| CrystalHydra | 20 | 1 |
| Eaglet | 8 | 1 |
| Frog | 7 | 1 |
| Jackalope | 10 | 1 |
| MoonJelly | 5 | 1 |
| SnowHare | 10 | 1 |

- **Close front-left shots:** every one has its face on the front of the head, and its ears, antlers, wings, tails, tentacles and Hydra heads attached.
- AuroraStag's small floating sparkles are its aura orbs (glow accents), not detached body parts.
- Shots: pr181-aurorastag, -bunny, -snowhare, -frog, -jackalope, -eaglet, -crystalhydra, -moonjelly (.jpg).

## Check 3: walkers: PASS

Each walker was tracked 100 times over 10 s.

| Species | Head leads the motion | Worst leg outside the body's width | Worst foot gap |
|---|---|---|---|
| Bunny | 15/16 | 0.00 | 1.13 (hop) |
| Jackalope | 17/18 | 0.00 | 1.55 (hop) |
| SnowHare | 22/24 | 0.00 | 1.03 (hop) |
| Frog | 21/22 | 0.00 | 0.70 (hop) |
| Eaglet | 19/19 | 0.00 | 0.13 |

- **Legs:** no leg ever sits outside the body's width; the legs swing under the body.
- **Feet:** the larger foot gaps are the hopping species in mid-air. The walking Eaglet keeps its feet within 0.13 studs.
- **Not walkers:** AuroraStag and CrystalHydra stood still during the sample. MoonJelly drifts and has no legs.
- Side shots: pr181-walk-jackalope, -walk-bunny, -walk-frog, -walk-snowhare (.jpg).

## Check 4: hatch reveal: PASS (3/3)

Bantam, HuskyPup and LionheadBunny (one of the re-uploaded species): each had its head toward the reveal camera, 12° off.

## Check 5: panels and Output: PASS

- **Panels:** Book, Tower and Feedback each opened, then closed with their X in first person. For all 3 the cursor was freed, the panel closed and the mouse re-locked.
- **Errors:** 0 on the client (100 warnings, all engine ContentId notices) and 0 on the server.

**Output tail (server).**
- [profilestore]: Roblox API services unavailable - data will not be saved
- [Stores] DataStores unavailable … store=ErrorQueue
- [Stores] DataStores unavailable … store=Feedback
- [TestPanel] Studio test panel is on
- [CoreServer] core started build=092faf4ab965 game=hatchery-heist studio=true
- 0 "do not sit where" lines.
