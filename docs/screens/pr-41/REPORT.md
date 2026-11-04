# PR #41 visual check: partial (stopped by Alex)

Builds: before = origin/main cb4a209, after = PR #41 head 8b0da33. Studio play solo on Alex's laptop, 1920x1200 full-screen captures (Studio chrome included).

The pass was stopped after Hatchery Heist "loop": Alex paused it and asked for a better visual playtest method. Not done: HH action and hud-phone, all Tidecatch Cove, Street Food Empire and Depthbound after shots.

## Hatchery Heist

**before-hatchery-heist-spawn.png**: Player stands on a flat, empty grass field. Only the top edges of three black slabs (the belt boards) poke out of the ground on the horizon, and a white label is sliced off at ground level on the left. No belt, eggs, incubators, pads or spawn plate are visible. A new player has nothing to do. Broken.

**before-hatchery-heist-wide.png**: Zoomed out: an empty field with eight black slab tops in a ring and nothing else. Confirms the whole base ring is buried.

**after-hatchery-heist-spawn.png**: Spawn plate, belts, eggs, glowing pads and incubators now sit on top of the ground. Ground bug fixed here. Problems: "Rebirth" and "Collect" labels sit on top of each other and are hard to read; the boards over the belts read as blank black slabs from the yard; an empty dark panel fills the top centre of the HUD; the Studio "LoopLabGames" toast is Studio-only.

**after-hatchery-heist-wide.png**: The full ring of eight bases is visible and level with the grass. The labels overlap on every base ("Rebirth"/"Collect" again, plus a cut-off "...ect" at the right edge). The look is grey-box: flat brown floors, black boards and plain grey cylinders.

**after-hatchery-heist-loop.png**: Inside a base: incubators (grey cylinders), rows of pads, a "Free base" sign and glowing rebirth/collect pads. Nothing floats or is buried. First-minute clarity is poor: nothing on screen tells a new player which base is theirs, what to buy, or what to do next, and standing next to belt eggs showed no Buy prompt.

Verdict: ground bug FIXED. Playable but not clear enough to ship: overlapping labels, blank-looking boards, empty HUD panel and no "your base / buy an egg" guidance.

## Tidecatch Cove (before only)

**before-tidecatch-cove-spawn.png**: Player on endless flat sand. The dock, water and tanks are all hidden; a label is sliced at ground level in the distance. The HUD shows the bait list and the "Bucket"/"Pools" buttons. "Bucket" is partly covered by the Studio toast, which is Studio-only. Broken.

**before-tidecatch-cove-wide.png**: Zoomed out: nothing but sand and a "Roof" label clipping through the ground. Confirms the whole map is buried.

After build: NOT CHECKED.

## Street Food Empire, Depthbound

NOT CHECKED.

## Output (after-hatchery-heist)

Only Studio asset-auth errors, no script errors:
- `ContentId: rbxassetid://96037266319483 failed due to: Authentication required to access Asset.`
- `ContentId: rbxassetid://114302219876492 failed due to: Authentication required to access Asset.` (x2)
- `Failed to load animation with sanitized ID rbxassetid://114302219876492: Animation failed to load` (x2)
