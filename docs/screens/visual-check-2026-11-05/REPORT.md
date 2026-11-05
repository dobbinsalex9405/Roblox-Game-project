# Studio visual check, 2026-11-05

Real-engine playtests in Roblox Studio on the laptop, driven with the Roblox Studio MCP tools
(play/stop, keyboard and mouse input into the game, character navigation, Luau inspection, Output).
Every build was made with `BUILD_ENVIRONMENT=staging tools/build.sh <game>` from the commit named
below and opened as its own `.rbxl`. Screenshots are the Studio play viewport (`.jpg` from the
Studio capture tool) or the Studio window (`.png`). The only account name visible anywhere is the
studio's own test account; no personal names.

Sizes: desktop = Studio maximised (viewport about 1690x840). Phone = Studio window sized until the
game viewport read 844x392; small phone = 668x375.

## Environment note

An unpublished place cannot use DataStores, and before PR #51 Hatchery Heist's server stopped at
start (`GetDataStore` threw inside `RobloxSinks.errorQueue`), leaving an empty HUD and no prompts.
Builds for #41 used a local, uncommitted `pcall` shim; #50, #43, #46 and #47 @ 146964a were built
with PR #51's three core files overlaid; later heads already contain #51.

## Results

| PR | Commit | Verdict | Notes |
|----|--------|---------|-------|
| #41 floor fix | ed99ae8 | PASS | All four games stand on visible ground. Tidecatch panels fit a phone. Output only had the pre-existing HH `'rarity'` flood (#49). |
| #50 raid guard error | 4f145ea | PASS | No `'rarity'` lines. Base buried as expected (based on main without #41). |
| #51 DataStore start | 1340cac | PASS | HH starts unpublished; two "DataStores unavailable" warnings (one per store). |
| #43 first look | f4b3055 | PASS | Welcome card (desktop and phone), HUD, own-base marking, goal line and beam, belt buy, odds boards, shop, Robux test prompt closed with X, Guide, Music. Output only the #49 flood. |
| #46 creatures and odds | ebbc51d | PASS (partial) | Belt kinds and rarity, commons as voxel animals, odds board, odds card, ride + Get off, FPS 52. Rarer tiers finished on #47 below. |
| #47 reveal, Book, Daily, farm | 146964a, 62ae0d9, 16b5245 | PASS with 2 findings | Daily claim and badge; Book (33 cards, scrolls on phone, FPS 57 open); reveal at three sizes with tap-to-skip and hold-to-skip-all; farm visible, windmill 9 s per turn, animals animate within 160 studs; FPS 59 at the farm; "Ready!" label and odds row size fixes confirmed. **Findings:** no NEW badge on found Book cards (not implemented); Phoenix mount is 6.5 studs tall (limit 6). |
| #47 rarer tiers | 16b5245 | PASS | Ultra Rare glow + light + particles; Epic adds ring; Legendary/Godly heavy neon, ring, aura. FPS 52.9 with 16 creatures incl. 5 Legendary/Godly. Prompts never need line of sight. Note: big-tier bloom washes out the base. |
| #44 phone usability | d5bab29 | PASS except one | Shop tabs and buttons 40 px tall, single tap, card order right; TC bait 38 px with ✓ and press tint; Pools help readable. **FAIL:** shared window close X is 36x32 (UiKit). |
| #52 floor and music | 6599f1b | PASS | Floor top 0.30, 0.4 thick, nothing buried or floating; music ~4 s ease-in and crossfade between tracks; gold GOAL tag, no missing glyph; guide beam drawn (belt billboard arrow present but not seen clearly). |

Other things seen (not on the checklists): Studio-only asset notice `rbxassetid://203785492` in
every game; Tidecatch goal banner draws over open panels at phone size; overlapping world labels
on HH (Rebirth/Shield) and SFE (Register/Counter) on #41; Depthbound HUD covers the layer-guide
title.

Music candidates for Hatchery Heist (chosen from library metadata, not by ear):
1840017271 "Magical Surprise", 1846499154 "Magic Castle", 9048460919 "Wildflower Meadows".

## Screenshots

Named `<pr>-<game>-<step>`; `47b` = 62ae0d9, `47c` = 16b5245. `50-hh-output.txt` is the Output
text for #50.

## Follow-up: #52 at e26fc1c

PASS on all items. Phoenix mount is 6.0 studs tall (visible parts y 0.3 to 6.3), with no neon, ring,
orbs, light or particles on your own mount; the rider stays in view and Get off works. With two
Phoenixes, Thunder Griffin, Nebula Serpent, Golden Goose and Crystal Stag on the base, the glow is
much dimmer than at 16b5245 and every creature reads clearly (compare `52b-hh-big-tiers-dimmer`
with `47c-hh-rare-tiers`); FPS 54. The new tracks 1840017271, 1846499154, 9048460919 all load
(2:46, 2:55, 3:11) and crossfade 1 to 2 and 2 to 3 over about 2 s. Output: no errors.

## Gate: #57 at d20ae77 (compared with main eecbc3e)

FAIL. Chick, Ember Fox and Phoenix render the same as main on pads (same part counts 14/61/415,
no MeshParts or blank meshes, same widths and heights within animation). But the ridden Phoenix is
10.1 studs tall with its ring and glow, against 6.0 studs and no glow on main: d20ae77 is not based
on eecbc3e, so #52's mount fixes (ArtScale ridden scale, CreatureLooks, Layout, init.server) are
undone by this branch. Output: no errors.

## Re-gate: #57 at af5e559

PASS. Contains main eecbc3e. Chick, Ember Fox and Phoenix match main exactly on pads (parts
14/61/415, total part volume 1.219/10.406/188.729, no MeshParts or blank meshes, same heights
within animation). Ridden Phoenix 6.0 studs with no neon, ring, light or particles; rider in view.
Output: no errors.

## Gate: #59 at 220b513

FAIL on one item (phone clipping), everything else PASS.
- Odds card shows tier chances only (Basic: Common 92% ... Legendary 0.002%), one text size, "See every
  creature" opens "Basic Egg: every creature" grouped by tier with per-creature chances (six Commons
  at 15.33% add up to the 92% tier). Desktop clean.
- FAIL: at 844x392 the list's right column is cut off by the scroll bar ("1 in 6." / "1 in 28.") on
  every row (`59-hh-every-creature-phone`). The list also covers the HUD bar at that size.
- Hatching 4 Basic eggs: Turtle (Uncommon), Mouse, Piglet, plus one still to hatch; the reveal names
  the creature with "1 in N" matching the list. Plausible, small sample.
- Sizes on pads: Common 2.0, Uncommon 2.2, Rare 2.4, Ultra Rare 2.7, Epic 3.0, Legendary 3.4,
  Godly 3.8 studs. Phoenix ride 4.4 studs, no glow.
- Daily Rewards at 844x392: Day 5/6 labels 16 px, amounts 18 px, "coins" 13 px, intro 14 px,
  nothing clipped.
- Output: no errors.

## Re-gate: #59 at 5f170e4

PASS on the gate items, with one spec note. At 844x392 the every-creature list opens below the HUD
coin bar (window top y 80, bar bottom 72) and no row text is clipped (24 labels checked); the
right-aligned numbers end 1 px before the scroll bar rather than the intended 10 px, so they sit
tight against it (`59b-hh-every-creature-phone`). All creature `assetId`s are still 0, so no
uploaded-mesh creature exists to check; the voxel Chick (2.0 studs) and Phoenix (3.4 studs) render
with the new height maths, and the Phoenix ride is 4.4 studs with the rider seated on top, no glow.
Output: no errors.

## Gate: #65 at 17f7cfe

FAIL on two items.
- Book at 844x392: tier tabs (Common 0/30 ... Godly 0/2; the tab strip scrolls sideways, Godly
  partly off the edge), header "Found 0/53 · Income +0% (max +25%)". Common grid scrolls fully, only
  cards on screen get models, no clipped text. **FAIL: spoiler flash.** When the book opens or a
  row scrolls into view, unfound "???" cards draw the creature in full colour for about a second
  before turning into the dark silhouette (`65-hh-book-spoiler-flash-reopen`,
  `65-hh-book-spoiler-flash-scroll`).
- NEW flow PASS: two hatches give the Book button a "2" badge and "NEW" on the cards; closing the
  book clears the badge, and NEW is gone on reopen.
- Every-creature list PASS: 11 px between the numbers and the scroll bar, no clipping, opens below
  the HUD bar.
- New Commons: Calf, Goat Kid, Beetle, Bluebird, Bumblebee, Caterpillar, Crab, Fawn are 2.0 studs
  in the same voxel style. **FAIL: Butterfly** renders as a single dark 0.7-stud cube. In
  VoxelArt.luau, head's parent is wingL and wingL's parent is head (a loop), so only the body is
  drawn. A script check of all 53 entries finds no other parent loops.
- Output: no errors.

## Re-gate: #65 at fd0a591

PASS. A per-frame monitor (RenderStepped) over 653 frames of opening, closing and scrolling the
Book at 844x392 and desktop found no frame where an unfound card's model had colour; screenshots
taken right after opening also show only silhouettes. Butterfly: body, head and two wings
(20 parts), 2.0 studs. At 844x392 the tab strip now fits with no scrolling (Godly ends at x 704,
strip ends at 790). Output: no errors.

Small note: unfound cards in the top three rows show only egg and odds, with no "???" name line;
"???" appears from row 4 down (and on desktop). Not a spoiler, just inconsistent.
