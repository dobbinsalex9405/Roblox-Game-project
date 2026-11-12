# #180 at d9da3ad6 (fix for #178: creatures stuck on voxel blocks): PASS

Build: `git checkout --detach d9da3ad6b15559276ec336e4909a6405cbe966ce`, then `BUILD_ENVIRONMENT=staging tools/build.sh hatchery-heist`. Output reads "core started build=d9da3ad6b155".
- I opened the local .rbxl in Studio, not the cloud place, and drove it only through the Studio MCP, in play-solo.
- There were two sessions: one of about 20.5 minutes for rows 1, 2, 4 and 5, and a fresh join for row 3.
- Times are seconds from the start of play:
  - **Arrival:** the species' model in CreatureMeshes holds all of its MeshParts.
  - **First mesh:** the first MeshPart on the creature, sampled every 0.5 s.
  - **Fallback:** a creature that had meshes and was later seen without them.

## Row 1: the #178 case, 20 minutes: PASS

I gave 2 Quail and 2 Peachick in the first second of play, when only 3 of 530 species models were loaded.

| Creature | Give | Species arrival | First mesh | After arrival | Fallbacks | Meshed at 20 min |
|---|---|---|---|---|---|---|
| Peachick (Pad1) | 0.2 | 26.0 | 31.7 | 5.7 s | 0 | yes (T=1221) |
| Peachick (Pad2) | 0.5 | 26.0 | 31.7 | 5.7 s | 0 | yes |
| Quail (Pad3) | 0.0 | 29.9 | 32.4 | 2.5 s | 0 | yes |
| Quail (Pad4) | 0.0 | 29.9 | 32.4 | 2.5 s | 0 | yes |

- **During the 20 minutes I:**
  - walked a loop between the market, the base and the spawn;
  - opened the Book (Rare tab) and looked at the floor signs;
  - bought floors 1 to 10 and added 8 Chicks;
  - bought and hatched an egg.
- At T=661 and at T=1221, all 80 creatures in the tower were meshed, with 0 fallbacks.
- Screens: pr180-row1-quail-peachick-1min.jpg and pr180-row1-quail-peachick-20min.jpg. The two Chicks added later stand in front in the 20 min shot.

## Row 2: 10 different species in a row: PASS

| Species | Give | Arrival | First mesh | After arrival |
|---|---|---|---|---|
| AlleyCat | 16.3 | 0.5 | 16.6 | 0.3 after the give |
| Gecko | 16.5 | 11.7 | 17.2 | 0.7 after the give |
| Kiwi (batch 13) | 16.6 | 16.2 | 21.1 | 4.9 |
| Llama | 16.9 | 18.2 | 23.5 | 5.3 |
| MantaRay | 17.2 | 20.1 | 22.3 | 2.2 |
| Narwhal | 17.5 | 22.9 | 29.1 | 6.2 |
| OkapiCalf | 17.7 | 24.0 | 29.8 | 5.8 |
| SnowLamb (batch 13) | 17.9 | 35.3 | 39.3 | 4.0 |
| Wombat | 18.2 | 40.1 | 41.4 | 1.3 |
| ZebraFinch | 132.9 | 40.8 | 133.4 | 0.5 after the give |

- All 10 meshed within **6.2 s** of their species arriving, well under 60 s.
- There is no species called "Zebra", so ZebraFinch covers Z.
- Across all 75 creatures given in the first 20 s, the worst lag was 6.2 s (Narwhal).
- **0** CreatureView or CreatureAssets warnings on the client or the server.
- Screen: pr180-row2-floor10.jpg.

## Row 3: a full tower right after joining: PASS (with one limit)

**Limit:** Studio has no DataStores, so the #123 test save can't be loaded on join. As the closest equivalent, I started a fresh session, bought floors 2 to 10 and gave **80** creatures in the first 28 s. I spread them in reverse alphabetical order, so they are the species that load last. Only 4 of 530 models had loaded at the join.

| When | Creatures drawn | On blocks |
|---|---|---|
| Right after the gives (T≈28) | 78 | 47 |
| T=60 | 80 | **0** |
| T=120 | 80 | **0** |

Screen: pr180-row3-full-tower-floor10-120s.jpg, floor 10 at 120 s, all meshed.

## Row 4: standing: PASS

- **#172:** with all 80 pad spots full, a hatched Dachshund went to the inventory (4 → 5) with "Your tower is full: Dachshund went to your inventory. Open Creatures to place it."
- **#179:** at −60°, "2. Book Nook x1.05" and "3. Plant Sunroom x1.30" read whole (pr180-signs-60deg.jpg).
- **#177:** the Book's Rare tab reads **21/81** (pr180-book-rare.jpg). In this test save those 21 are whichever Rares I gave, not specifically the batch-13 set. The batch-13 21/21 was confirmed at 3de4e2a4.

## Row 5: PASS

- Feedback button visible in both sessions.
- 0 script errors on the client and the server in both sessions.
- 0 CreatureView or CreatureAssets lines.

Raw numbers: output-log.txt.
