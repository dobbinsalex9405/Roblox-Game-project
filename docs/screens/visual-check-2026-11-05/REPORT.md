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
