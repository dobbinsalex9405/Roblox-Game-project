# #172 at 2fe4fc15 (hatch into a full tower): FAIL on check (2) multi-hatch; stopped there

Build: `git checkout --detach 2fe4fc15290ebc029114c57f88d11b9cdaedc988`, then `BUILD_ENVIRONMENT=staging tools/build.sh hatchery-heist` (stamp 2fe4fc15290e). I opened the local .rbxl in Studio, not the cloud place, and drove it only through the Studio MCP in play-solo.

The server data was read from the full `Core:Data` table the server pushes to the client after every change. Hatches were the real flow: Basic eggs bought off the belt through their Buy prompt, then `HH:Hatch` per incubator (what the Hatch prompt sends).

**Setup.**
- 10M coins from the test panel. Incubators bought up from 3 to 10.
- The test panel gave 8 Dachshund, filling floor 1 (8/8).
- Then 5 Llama (1/s) and 145 OkapiCalf went to the inventory, which reached its cap: `economy.storage.slots` = 150.
- Total 158 creatures: 8 placed, 150 stored.

## Check (1) Three single hatches at cap: PASS

| Hatch | Newcomer | Where | Sold | Count | Notices |
|---|---|---|---|---|---|
| 1 | #159 Goldfish | inventory | #9 Llama (+20 coins) | 158 → 158 | "Your tower is full: Goldfish went to your inventory. Open Creatures to place it." and "Inventory is full: sold Llama for 20 coins." |
| 2 | #160 Foal | inventory | #10 Llama (+20) | 158 → 158 | "Your tower is full: Foal went to your inventory. …" |
| 3 | #161 Cockatiel (1/s) | inventory | #11 Llama (1/s, +20) | 158 → 158 | "Your tower is full: Cockatiel went to your inventory. …" |

- Each hatch adds 1 and the trim sells 1 older creature. The data push only shows the result after the trim, so the transient 159 is not visible.
- The newcomer was never the one sold. On hatch 3, Cockatiel ties with the Llamas at 1/s and was still kept.
- Hatches 2 and 3 showed no sold notice. That is the existing 20 s `SOLD_NOTICE_SECONDS` throttle in Actions.luau, not this PR; the coins were still paid.
- All three newcomers appear in the Creatures list ("Inventory · … when placed"). The header reads "Earning: 8/8 slots used. In your inventory: 150." See pr172-check1-inventory.jpg.

## Check (2) Multi-hatch, 10 eggs at cap: FAIL

I bought 10 Basic eggs into the 10 incubators and hatched all 10 together, 0.2 s apart.

- Hatched, in order: #162 ZebraFinch, #163 Crow, #164 Duckling, #165 Goldfish, #166 Raccoon, #167 Mouse, #168 GuineaPig, #169 DalmatianPup, #170 Canary, #171 Hen.
- Count went 158 → 158 (stored 150 → 150). Coins rose by 240.
- **6 of the 10 just-hatched creatures were sold during the batch:** ZebraFinch, Crow, Duckling, Mouse, GuineaPig and Canary.
- Only 4 survived: Goldfish, Raccoon, DalmatianPup and Hen.
- The older creatures sold were #12 and #13 Llama, plus #160 Foal and #161 Cockatiel from check 1.
- The brief expects count = before + N minus older ones. That would be 4 older sold and all 10 newcomers kept. Instead, 6 newcomers were sold.
- **Cause, from the diff:** `trimStorage(..., keep = creature.uid)` protects only the creature from the hatch that is running. A creature hatched earlier in the batch is an ordinary stored creature by the next hatch. If it is the weakest, the next hatch sells it. Each player still saw all 10 "Your tower is full: <Name> went to your inventory" notices, so 6 of the creatures it reported as in the inventory were already gone.
- See pr172-check2-after-batch.jpg: the list ends with Hen, and ZebraFinch, Crow, Duckling, Mouse, GuineaPig and Canary are absent.

Output in both checks: 0 script errors, 0 CreatureView lines. The server log has only the usual Studio DataStore and TestPanel notices. See output-log.txt.

## Checks (3) mount and guard, (4) sanity, (5) standing checks: not run

I stopped at the first FAIL, as briefed.

Screens: pr172-check1-inventory.jpg, pr172-check2-after-batch.jpg.
