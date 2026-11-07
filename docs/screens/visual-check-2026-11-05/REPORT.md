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

## Gate: #66 at ddfd832

FAIL.
- **Spoiler:** unfound Book cards keep each creature's real TextureID and only set Color dark.
  A MeshPart's texture covers its Color, so once a texture loads the unfound card shows the
  creature in full colour (`66-hh-book-spoiler`: all 20 unfound cards in colour). Before the
  textures load the cards are grey, not dark (`66-hh-book-before-textures`).
- **Missing names:** the Species label is blank on found cards (Chick, Calf...) and on most
  unfound cards ("???" only on 6 of 30).
- **Textures:** 5 creature textures fail to load: Mouse 125942249841390, Fawn 123184545739625,
  Toad 110360095487934, Koala 138011394882264, Crab 112487715406458. About 18 more report "Asset
  content representation is being generated" (still processing on Roblox's side), so the first
  hatch showed a grey, untextured Lop Bunny that got its colours a few seconds later.
- **Output:** 21 MessageErrors "Failed to upload TexturePack ... Referenced Asset N is NOT found ...
  PBR textures may not be visible".
- PASS: all 53 meshes load (MeshParts with MeshIds, none blank). Sizes match the tier steps (Common
  2.0, Uncommon 2.2, Rare 2.4, Ultra Rare 2.7, Epic 3.0, Legendary 3.4, Godly 3.8). Feet sit on the
  pad (Legendary and Godly hover 0.3-0.45 by design). Voxel style is the same across tiers with no
  z-fighting seen. Phoenix ride 4.4 studs, 17 MeshParts, no glow, rider seated. Hatch reveal
  shows the mesh. The creature is on its pad 0.23 s after the hatch press.

## Re-gate: #66 at 1d4efbd

FAIL. Every mesh loads (all 12 sampled creatures have MeshParts with MeshIds, no SurfaceAppearance,
no "Failed to upload TexturePack" errors), sizes follow the tiers and feet sit on the pads. But
no creature has colour: every one is plain grey (`66b-hh-grey-meshes`). Each creature's TextureID
fails to load with "Asset type does not match requested type" (24 warnings; ContentProvider
Failure for all 12 sampled, e.g. Mouse 134268190690554, Fawn 123371316878080, Toad
98361995289835, Koala 76631192769813, Crab 104822474090359). These ids look like Decal asset ids,
not the Image ids that a MeshPart.TextureID needs.

## Gate: #68 at 98d9930 (tower)

PASS with three findings.
- Tower menu: floors 2-4 built with coins from the Test panel (25K, 75K, 225K) and an upgrade
  bought on floor 2. Each floor has a deck, railings, 4 pillars and a plaque ("2. Book Nook
  x1.10" ...). Floor 5 shows as a see-through ghost deck with "Floor 5: 675.00K coins (Tower menu)".
- Elevator: the Ride prompt opens the menu with Go on each built floor. Go to floor 3 lands the
  player on the floor 3 elevator pad.
- Pets: Move offers floors 1-4 and To inventory; To inventory works (Chick showed "Inventory");
  Place best put the best creatures on the highest floor (Serpent, Unicorn, Dragonling,
  Ember Fox on floor 4; Fox Kit, Chick, Bunny on floor 3). Income went up to +4.57K/s.
- **Ladder:** climbing from inside the tower, the player hits the underside of the floor 2 deck
  at y 10 and stays stuck there (`68-hh-ladder-blocked-inside`). From outside, the player climbs
  to the top and steps onto the highest built floor, but there is no way off at floors 2 or 3.
- **Ghost label:** the "(Tower menu)" text wraps onto a second line. It looks like a leftover
  hint.
- Phone 844x392: the Tower and Pets windows fit and no text is clipped, but Upgrade, Build,
  Move and Place best buttons are 34 px tall (under 40). The windows' X closes with a real
  click (checked with a real mouse; the Studio test tool's click didn't reach it near the top
  of the screen).
- Book: "???" now shows on all unfound cards, top rows included.
- Output: no errors.

## Gate: #75 at 22eb9ca (nature)

PASS with two layout findings.
- Trees: 204 scenery props, all meshes (1,560 MeshParts, no box-only trees). On the client the
  meshes were already in place from the first frame after spawn, so no pop was visible in Studio.
  Kinds: oaks, blossoms, willows, Star Pines, berry and hydrangea bushes, rocks, three flower
  patches, grass tufts, 8 mushroom rings, toadstools. 39 trees in the 166-245 ring.
- **Gap trees:** no tree stands in any of the 8 gaps between bases; the barn, windmill, pond, pen
  and four fields fill the gaps at about r 186.
- **Star Pines:** 6 of 15 stand on hills (the large ones at r 316-343); the other 9 are in the wood
  ring on flat grass.
- Sky: the Up face looks right (plain blue gradient with the sun), and clouds and floating islands
  cross the corner seams with no break (looked at the 45° and 225° corners).
- Grass: the Baseplate is Grass with a top Texture, and all 66 hill parts have grass.
- Phone 844x392 looking into the wood: 60 fps in all four directions.
- Output: no "nature meshes did not load" and no texture-type errors. One warning: grass texture
  95042477743332 "Asset content representation is being generated" (still processing on Roblox).

## Gate: #76 at 5dc6ed9 (Golden Egg Shop)

FAIL on readability (lighting); everything else passes.
- Placement PASS: GoldenEggShop at angle 22.5°, radius 61.6, 32x21x28. Its front (LookVector) faces
  the nest. Nothing else overlaps its box (`76-hh-shop-outside`).
- Layout PASS: 8 displays. Coin packs on one wall (5K, 30K, 80K, 200K), Auto-Collect, Extra
  Incubators, Double Coins and Shield Refill on the other. A Hamster shopkeeper stands behind the
  counter. "Coins" and "Passes & Shield" wall signs.
- Buy PASS: the prompt reads "80K Coins / Buy for R$ 199" (E, no hold). Pressing it opened the
  Roblox "Buy item 80K Coins 199 / test purchase" window, which I closed with its X. Output logged
  "[Shop] purchase prompted key=CoinPackBig ... source=GoldenEggShop".
- Walking in and out: no getting stuck.
- **FAIL, overexposed inside:** 78 Neon parts, 10 PointLights and bloom (Intensity 0.35, Threshold
  1.6) on pale wood wash the room out to white and yellow. The price-tag cards (2.5x1.5 studs with
  4 text lines) and the wall signs show as blank white with faint text, so you can't read them
  (`76-hh-shop-coin-wall`, `76-hh-shop-counter`). From outside, the shop looks good.
- Output: no game errors.

## Gate 3: #66 at c904a7b

PASS. 8 creatures given (Mouse, Fawn, Koala, Crab, Chick, Ember Fox, Dragonling, Nebula Serpent),
all coloured (`66c-hh-coloured-meshes`); every texture loads (7/7 Success). A frame-by-frame log
from the moment each creature appeared shows meshes within 0.12 s and never an untextured grey
mesh. No "Asset type does not match" or TexturePack errors. Book: 17 unfound cards on screen, all
dark with no TextureID and labelled "???"; Chick shows in colour with NEW
(`66c-hh-book-silhouettes`). Output still has 7 one-time "Asset content representation is being
generated" warnings while Roblox finishes processing the new images.

## Re-look: #75 at 2de293d (sky and grass ids)

PASS. The grass Texture (106077023630198) renders on the Baseplate (pixel-grass pattern,
`75b-hh-grass`) and all 66 hills keep their textures. The sky shows clouds, floating islands and
the blue Up face at the corners (`75b-hh-sky-corner`). No asset-type errors. Two notes: Output
still prints one "Asset content representation is being generated" warning for the grass id even
though it renders, and ContentProvider:PreloadAsync reports "Failure" for all 6 skybox ids even
though the sky draws.

## Gate 2: #76 at b024d1a (shop lighting)

PASS. 0 Neon parts; lights at brightness 0.30 (0.45 for the chandelier) with ranges 8-18. The
inside is warm and no longer washed out. Price tags are dark cards with a gold edge, unlit
(LightInfluence 0), 3x1.5 studs, readable from the middle of the shop ("80K Coins / Adds 80000
coins right away. / R$ 199", passes show "Owned"). The "Coins" wall sign is readable
(`76b-hh-coin-wall`, `76b-hh-pass-wall`). At 844x392 the tags can be read up close
(`76b-hh-tags-phone-close`) but are small from the doorway (`76b-hh-shop-phone`). The Buy prompt
"80K Coins / Buy for R$ 199" opened the test-purchase window, which I closed with its X. Output: no
errors.

## Gate: #89 at 417eb6b (farm framing, pines)

PASS with one note. There are 11 Star Pines, each on its own hill and none on flat grass. Every
farm piece has small trees on both sides about 39 studs from its centre (Puff Oak S for the barn,
windmill, pond and pen; Blossom S for the fields) with a bush beside them (`89-hh-barn-framed`).
Note: wood stands behind the windmill, pond, pen and two fields, but there are no trees within
12° behind the barn or the fields at 67° and 338°. Output: no errors.

## Gate: #84 at 73a8c4e (tower fixes)

PASS. Ladder: climbing from the ground inside the tower passes cleanly through the deck openings
(no snag under a deck) and grows with the built floors (top at y 28.3 with floors 2-3). Stepping
off works at floor 2 (landed on the floor 2 deck) and floor 3 (`84-hh-floor3-off-ladder`) by
jumping back off the ladder level with the deck. Walking from a deck into the opening grabs the
ladder, and holding back climbs all the way down to the ground with no damage. Phone 844x392:
the X and every Upgrade/Build button are 40 px tall, no clipped text (`84-hh-tower-menu-phone`).
Coin amounts read "5K", "15K", "225K", "675K", "2M" and the ghost deck reads "Floor 4: 225K
coins" on one line. Output: no errors.

Note for players: getting off at a middle floor means jumping back at the right height. Holding W
alone climbs past the last built floor and off the top of the ladder.

## Gate: #83 at ac7d480 (walking, Godly size, LOD)

FAIL on three items; sizes and frame rate pass.
- Sizes PASS: Commons 2.00, Fox Kit 2.20, Raccoon 2.41, Ember Fox 2.70, Dragonling 3.01, Phoenix
  3.38, Nebula Serpent 6.02, Golden Goose 6.00 (3x a Common). On floor 4 no two creatures'
  bounding boxes overlapped in 8 s of wandering.
- **Walking:** creatures wander (Ember Fox 3.7, Raccoon 3.1, Golden Goose 1.7 studs per 6 s) with
  a 0.2-0.3 stud bob, but the meshes have no separate leg parts (body, head, ears, tail, eyes), so
  nothing swings: they glide. Feet stay within 0.1 of the pad; Legendary/Godly hover 0.36-0.65.
- **Upper floors hidden from below:** standing on the ground 20-45 studs from the tower, every
  creature on floors 3 and 4 is hidden, even at 21 studs, while floor 2 shows. From floor 3, all
  15 show. From outside, the upper floors look empty (`83-hh-upper-floors-hidden`).
- **Meshes failing:** Output says "creature meshes did not load; drawing voxel boxes" for Ember
  Fox, Frost Wolf and Crystal Stag. Ember Fox drew as 61 voxel boxes. Plus about 12 "Asset content
  representation is being generated" notes for new image ids.
- Phone 844x392 with 15 creatures on floor 3: 58 fps. No game errors.

## Gate: #91 at a327f2f (apartment interior)

PASS with one finding and one gap. Floors 2-4 were built and fully furnished. The furnished
floors are cozy, not washed out (`91-hh-book-nook`): 0 Neon and 12 lamps at brightness 0.40.
Each furnishing step grows in over about 0.3 s with an UpgradeSparkle particle burst. **No sound:**
Sfx.play("reward") is called, but `sounds.reward.id` is 0 in atmosphere.luau, so it's silent. A
Chick moved to Pad9 on floor 2 sits on the reading cushion and shows (`91-hh-chick-on-cushion`).
Ladder opening clear of furniture on floors 1-4 (scripted check). **Gap:** floors 5-10 were built
but my clicks on their Upgrade buttons didn't register, so they have no furniture and weren't
checked. Phone 844x392 inside the tower with 3 furnished floors: 60 fps. No game errors. Output
also shows "creature meshes did not load; drawing voxel boxes" for FrostWolf, CrystalStag,
EmberFox and MoonUnicorn (the #94 issue).

## Gate: #94 at 9c94b08 (glow meshes)

FAIL. After 20 s all four still draw as voxel boxes (Crystal Stag 108 boxes, Frost Wolf 66,
Ember Fox 61, Moon Unicorn 104; no MeshParts). Output gives the reason each time: "mesh
<Species>_body_glow missing from asset <id>" — CrystalStag 76176813759498, EmberFox
115947540552349, FrostWolf 118793263738444, MoonUnicorn 110066245966043.

## Re-gate: #83 at 74a596c

Mixed. From the yard and from a neighbour's base, all 15 creatures on floors 2-4 are drawn (PASS).
Phone 844x392: 59.8 fps. No game errors (voxel-box notes for the 4 glow species are the #94
issue). **Walking:** the whole creature rocks side to side (10-17° on the walkers), nods (8° pitch)
and bobs (0.13) at about 1.3-1.8 studs/s, but heads, ears and tails never move against the body
(0° on every part), so there's no ear or tail swing. **Own-tower rule:** standing on your own
ground floor inside the tower, floor 2 and all of floor 4 show while half of floor 3 is hidden
(pads 21-24 hidden, 17-20 shown). That doesn't match "your floor ±1".

## Gate: #93 at ca84265

PASS. Trees stand behind every farm piece within ±12° (Barn 3, Field 67° 3, Field 338° 1 plus
more just outside that cone; `93-hh-field338` shows wood behind the field). No scenery prop sits
inside any farm piece's footprint. No parts are named "path", so the check against paths was
done by eye: nothing stands on the walkways.

## Gate: #97 at 48dbaf4 (Egg Market)

PASS except kiosk readability. 258 slats all moving; 66-82 eggs (Basic, Meadow, Moonlit) on crates
in two lanes going opposite ways around the nest. On walking up, the Buy prompt and the egg's odds
card appear (`97-hh-market-walkup`). Pressing E bought a Basic egg: coins went down by 50, an
incubator started and the goal changed to "Your egg hatches in 8s"; the bought egg's crate and
shell go fully transparent (`97-hh-market-bought`). A fresh spawn lands at the player's own base
(134, 3, 0). Phone 844x392 at the market: 60 fps. **FAIL:** the kiosk's odds boards over the nest
can't be read from the paths: about 34 studs away the rows are a few pixels tall
(`97-hh-kiosk-from-path`). No game errors. A Studio "Lighting Technology Migration" notice
popped up once and was closed with its X; it's Studio-only.

## Re-gate: #94 at f8f36be

PASS. Ember Fox, Frost Wolf, Crystal Stag and Moon Unicorn draw as coloured MeshParts (6-7 each,
texture loads), not voxel boxes (`94b-hh-glow-species-meshes`). Output has "creature glow meshes
missing; drawing the creature without them meshes=<Species>_body_glow" for all four and no
"drawing voxel boxes" line.

## Re-gate: #91 at 1a77df3 (scope: floors 5-10)

PASS. Every Build tap on floors 2-10 registered, as did all 4 Upgrade taps on each of floors 5-10
(coins kept changing over 1,000-coin boundaries while I clicked). The menu shows floors 5-10 "Fully
furnished" (`91b-hh-floors5-10-furnished`); floor 10 used real mouse clicks. Standing on each of
floors 5-10, all 4 decor groups load, and no furniture part sits in the ladder opening
(`91b-hh-penthouse`).

## Re-gate 3: #83 at 7746760

Mixed. **Walking PASS:** parts now move against the body while walking: Bunny ears 18°, tail 27°,
head 8°; Calf ears 17°, tail 26°, head 8°; Chick and Duckling head 8°. **Own tower FAIL:** standing
on my own ground floor inside the tower, floor 2 (4 creatures) shows but ALL of floors 3 and 4 are
hidden (11 creatures). That's worse than gate 2. From the yard all 15 show. **Hover:** the Godlies
float with their lowest point 0.94 (Golden Goose) and 0.98 (Nebula Serpent) above the pad,
including the bob; no Legendary was placed this run. Phone fps 60. No game errors (the 4
voxel-box notes are from #94, which this branch doesn't contain).

## #97 kiosk-only re-gate @ 2d65cab

- **Board readability: PASS (desktop), PASS with a layout note (phone).** One egg per board. Each row is 1.28 studs tall: 20 px per stud, text bounds 25.6 px. From 34 studs at eye height, a row is about 17 px tall on desktop (1350x672) and about 8 px on phone (844x392). Every row is readable in `97c-hh-kiosk-34studs-desktop.jpg`.
  - **Phone note:** the board is 14.5 studs up. Walking in from the path, the coin HUD and the GOAL banner sit right over it and hide the title and the first 3 to 4 rows (`97c-hh-kiosk-34studs-phone-eye.jpg`, `97c-hh-kiosk-46studs-phone-3rdperson.jpg`). Lowering the board or the camera's target would fix it.
- **First spawn: PASS.** The player joins at their own base (plot-local 0, 3.2, 24). The SpawnLocation is now at (52, 0.1, 0), off the belt, Transparency 1, with no decals. Nothing shows in the lane (`97c-hh-spawn-plate-area-phone.jpg`).
- **Respawn: FINDING.** After the character died (killed from the server), it stayed at the plaza SpawnLocation (53, 3, 1) for 6 s and was not sent home. `CharacterAdded -> World.sendHome` is the same code as on main f82fdd9, so this is probably an existing ordering race (the teleport runs before Roblox places the character) and not caused by #97. Because the plate is now off the belt, a respawned player lands next to the Golden Egg Shop, not on the belt.
- Output: nothing new. It shows the usual unpublished-place DataStore notes, the 203785492 notice, and voxel-box fallbacks.

## #98 coin packs @ fce2140

**PASS.**
- **Zero income:** the Robux tab shows 5K / 30K / 80K / 200K Coins, each labelled "N coins right away" (`98-hh-robux-tab-zero-income.jpg`). A Test-panel buy of CoinPackSmall logged `amount=5000 balance=5200 reason=IAP:CoinPackSmall`.
- **Income +876/s** (CrystalStag, EmberFox, FrostWolf and Dragonling given): the tab shows 263K / 1.05M / 2.36M / 5.26M Coins, each labelled "...: N minutes of what you earn now" (`98-hh-robux-tab-876ps.jpg`). The exact values would be 262,800 / 1,051,200 / 2,365,200 / 5,256,000; the shop rounds them to 3 significant figures.
- **Grants match what the shop shows exactly:** Small `amount=263000` and Medium `amount=1050000`. The grant is the rounded amount that was displayed, not the unrounded one.
- Output: nothing new.

## #83 gate 4 @ 1d9eae7 (distance-only cull)

Setup: floors 2-4 built, 15 creatures given through the Test panel (2 on floor 2, 5 on floor 3, 8 on floor 4; mix of commons and rares, incl. CrystalStag, EmberFox, FrostWolf, Dragonling, MoonUnicorn, GoldenGoose).

- **From the ground floor inside the tower: PASS.** 15/15 creature models drawn (floor 2 2/2, floor 3 5/5, floor 4 8/8). The decks block the view upward, as expected (`83d-hh-inside-ground-floor.jpg`).
- **Walking: PASS.** 5 of 15 moved more than 0.3 studs in a 3 s window. The rest were idle on their schedule.
- **Yard: PASS.** 15/15 drawn, 59.5 fps on desktop (`83d-hh-yard-side-view.jpg`).
- **Ladder climb: PASS.** The character was stepped up the ladder line (plot-local 22.5, 14.5) from y 3 to 42, sampling every 1.5 studs. The count stayed at 15 drawn the whole way, with 0 changes, so nothing popped in or out.
- **Several full towers, phone 844x392, Studio in the foreground: FINDING.**
  - Setup: server-side clones of the 15 creature balls (same CreatureLook, Uid set, parented as `Creature` under each free `PadN`, so they wander like real ones) filled every pad of the four neighbouring towers: Plot2 and Plot8 at 84 studs, Plot3 and Plot7 at 155. Plot1's extra clones were removed by its own resync. That made 335 creatures in total.
  - Standing in the yard of my base, 273 are drawn: own 15, Plot2 80, Plot8 80, Plot7 79, Plot3 19 (the rest of Plot3 is beyond 180 studs).
  - Measured **36-39 fps** (default camera 39.3; looking at own tower, Plot2, Plot8 and the market: 36.8 / 38.6 / 37.0 / 36.1).
  - Baseline at the same spot with only the own 15: **59.3 fps**.
  - Client memory was 2.8 GB with the clones present.
  - This is the laptop GPU in Studio, so a real phone will likely be slower.

## #97 re-gate @ 3b75f13 (phone board view, respawn)

- **(1) Phone 844x392 from 34 studs: FAIL.** The board is now 16x11 studs, centred 11.5 studs up, with text bounds 0.88 studs per line.
  - With the character standing 34 studs out on the path (0, 3, -42.2), facing the market, and a follow camera 12 studs behind and 4 up, the board sits right behind the coin HUD. Only a strip of the coin column shows between the HUD's two lines, and the GOAL banner covers the lower rows (`97d-hh-kiosk-34studs-phone-player.jpg`). The same happens from 46 studs (`97d-hh-kiosk-46studs-phone-3rdperson.jpg`).
  - On phone, the HUD and banner fill roughly screen y 85-220 of 392. At this distance that band is where anything 8-15 studs up lands.
  - The rows are readable once they are uncovered, which happens on desktop or when the camera is pitched up.
- **(2) Respawn: PASS.** After a server kill, the new character was at its own base (plot-local 0, 3, 24) at the first 0.5 s sample and stayed there for 4 s. The plaza SpawnLocation (52, 0.1, 0) is transparent and nothing shows there or by the Golden Egg Shop (`97d-hh-plaza-spawn-empty-phone.jpg`).

## #83 gate 5 @ 4f58308 (neighbour LOD)

Setup was the same as gate 4: floors 2-4 built, 15 creatures given, then 320 server-side clones filled every free pad of Plot2/Plot8 (84 studs) and Plot3/Plot7 (155 studs). Phone 844x392, Studio window in the foreground, standing in my own yard at (100, 3.7, -30).

- **Drawn:** 76 creatures in total (gate 4 drew 273).
  - Plot1: 15, all animating.
  - Plot8: 59 drawn, 40-100 studs away, 11 of them animating (the nearest ones).
  - Plot2: 2 drawn at 97 studs, frozen.
  - Plot3 and Plot7: none.
- **fps with neighbours full: BORDERLINE, median about 54, range 50-58.**
  - First run: default camera 55.5; looking at own tower / Plot2 / Plot8 / market 53.7 / 52.0 / 57.3 / 59.6.
  - Two repeats: 53.8, 55.3, 50.2, 50.7, 58.2 and 52.6, 53.0, 56.7, 54.3, 51.9.
  - **Baseline** at the same spot with the clones parked: 56.1, 59.3, 59.7, 59.5, 57.2 / 57.5, 59.0, 55.4, 57.1, 58.8 (median about 58). The neighbours now cost about 4 fps; in gate 4 they cost about 21.
- **Client memory:** 2865 MB with clones, 2846 MB without.
- **Neighbour animation resumes up close: PASS.** Standing at (95, 3.3, -61) next to Plot8: all 39 of 39 creatures within 60 studs animate. Beyond 60 studs, 7 of 30 animate; these are probably within 60 of the camera, which sits about 12 studs behind the character.
- **Own tower, all floors, from the ground floor: PASS.** 15/15 drawn (floor 2 1/1, floor 3 6/6, floor 4 8/8).
- Output: nothing new. It shows the usual unpublished-place notes, the "being generated" notices for new mesh ids, and voxel-box fallbacks.

## #101 sound ids @ 41001a7

**PASS.** I can't hear audio, so this check reads Sound properties instead. A client watcher on SoundService logged every `Sfx_*` Sound once it was created and 0.25 s after each `Played`.

| Slot | Triggered by | SoundId | Loaded | Length | Volume | Playing / TimePosition |
|---|---|---|---|---|---|---|
| click | Daily, Book, Daily close buttons | 73629124033518 | yes | 0.17 | 0.40 | playing, 0.15 at first play; finished by +0.25 s later (shorter than the sample) |
| reward | Daily Claim (+250 coins) | 100288208393628 | yes | 1.35 | 0.60 | playing, 0.15 |
| eggShake | Hatch (Basic Egg) | 9120784504 | yes | 0.30 | 0.50 | playing, 0.15 |
| eggCrack | Hatch | 9113959343 | yes | 1.02 | 0.60 | playing, 0.17 |
| reveal | Hatch (Chick, Common) | 90618709727045 | yes | 2.54 | 0.50 | playing, 0.04 |
| newEntry | First Chick in the Book | 73774648241042 | yes | 4.20 | 0.40 | playing, 0.04 |
| revealBig | not hatched (needs Ultra Rare/Epic); loaded and played directly | 85188102085028 | yes | 2.43 | - | playing, 0.30 |
| revealLegend | not hatched; loaded and played directly | 1840076509 | yes | 2.25 | - | playing, 0.32 |

Output has no "failed to load" line for any of the eight ids.

**Side finding (not #101):** The trap pads (R "Set slime" 2K, E "Set snare" 5K) sit right beside Incubator 1. Standing at the incubator's front, E went to "Set snare" instead of "Hatch" (`101-hh-snare-prompt-beside-incubator.jpg`). The snare purchase was refused only because I had 400 coins. A richer player trying to hatch could spend 5K on a snare by mistake.

## #97 polish @ e6a8671 (three eye-level boards round the Golden Nest)

Each board is 26x7 studs, centred 4.5 studs up and 15 studs from the nest, facing outward. There are 14 labels per board, each about 1.0 stud tall.

- **(1) Readability, phone 844x392, 34 studs out along Board3's normal, follow camera: FAIL.**
  - With the follow camera (12 studs behind the character, 4 up), the board projects to viewport y 135-178. That is right behind the coin HUD (y 66-130) and the GOAL banner (y 138-176), so none of it shows (`97e-hh-board-34studs-phone-follow.jpg`).
  - Even with the camera aimed straight at the board, it lands at y 164-206. The banner covers the top, and the eggs riding the belt ring (radius about 30, between the path and the board) cover the lower rows. Only a strip of the title and first rows shows (`97e-hh-board-34studs-phone-aimed.jpg`, `97e-hh-nest-facing-board.jpg`).
  - At this distance one stud is about 6 px on phone, so a 1-stud line is about 6 px tall, too small to read even when uncovered.
- **(2) Nest as the centrepiece: it reads as walled off when you face a board, and fine through the gaps.**
  - Head-on, a board fills the middle of the ring and hides the whole nest (`97e-hh-nest-facing-board.jpg`).
  - Looking through a gap between boards, the Golden Egg and the coloured eggs show clearly, framed by two dark boards (`97e-hh-nest-from-gap.jpg`).
  - The boards sit inside the belt ring, so belt eggs pass in front of them all the time. From the path you see eggs, then a dark slab, then the nest only through the gaps.
  - **Suggestion:** take the odds off the centre. Either put a small low sign at each of the 8 stops, outside the ring at eye level facing the path (1-2 tiers per line, bigger type), or rely on the existing tap-to-open odds card and keep one small "Odds" sign. Either way the ring and nest stay the clear centrepiece. If the boards stay: make them narrower (about 12 studs) with wide gaps, put the top at 5 studs or lower, and place them outside the belt so eggs don't pass in front.

## #106 trap prompts @ be70e4a

**PASS.**
- **Hatch beats traps:** in front of Incubator 1 (91, 3.3, 18), the same spot where E set a snare on 41001a7, only the Hatch prompt shows (`106-hh-hatch-only-prompt-phone.jpg`). The trap prompts there are 9.0 studs away and out of their 5-stud range. Pressing E hatched the egg: the onboarding step and new creature appeared, coins were unchanged, and no trap event fired.
- **Trap prompts:** Snare is F and Slime is R, each with HoldDuration 0.6 and MaxActivationDistance 5.
  - At 6.2 studs from Trap1 neither shows. At 3.5 studs both show (PromptShown logged).
  - A tap of F gave HoldBegan with no trigger. Holding R for 0.9 s triggered Slime; the server refused it for coins (174 < 2K).
- **Phone 844x392:** Hatch and the two trap prompts are separate cards, each about 150x60 px. Slime and Snare stack in two rows with distinct key badges (`106-hh-trap-prompts-close-phone.jpg`).
- **Stray prompts:** the only other enabled prompts in reach around the incubators are the belt Buy prompts (E, range 10), which appear and disappear as eggs pass. At the incubator front Hatch is nearer (4.7 against 7.5 or more) and is the one shown. Decoy "Place" prompts (E) are out of range there.

## Fresh-player run, main @ f82fdd9, phone 844x392

Screenshots `fp-*` are the whole Studio window. The game viewport is the left part. The Roblox player list (top right, "LoopLabGames") and the chat hint are Studio/desktop only; phones hide them. Run order: spawn, welcome, belt, buy, hatch, Book, Daily, Tower floor 2 (coins topped up with Test +100K, since 25K takes a fresh player far longer than 15 min), Golden Egg Shop, Robux tab.

Ranked by how much each would bother a first-time player:

1. **Pressing Buy on the belt often hits an expensive egg.** The belt keeps moving, so the prompt in front of you is whichever egg is nearest. My first E press hit a Meadow Egg (2.5K) and only said "Not enough coins." (`fp-04`). The toast doesn't say which egg or that Basic Eggs (white, 50) are the affordable ones. Suggestion: "That's a Meadow Egg (2.5K). Basic Eggs are 50" in the toast, and/or show Buy only on eggs you can afford while you have under 2.5K.
2. **The belt area is crowded on phone** (`fp-03`). The auto-opening odds card covers the left third. The GOAL banner and its yellow arrow marker sit on top of the egg's Buy prompt, and "Basic Egg: 50 coins" is half covered. Suggestion: don't auto-open the odds card on phone (keep the "Egg odds" button), and hide the arrow marker once the player is at the belt.
3. **Golden Egg Shop interior on phone:** the camera clips into the counter and walls, so you see a grey block and a floating Buy prompt, not the displays (`fp-12`). Suggestion: push the walls out or open the front, or zoom the camera in inside the shop.
4. **"Auto-collecting N" shows from the start** (`fp-07`). The shop also lists Auto-Collect, Double Coins and Extra Incubators as **Owned** for this account. This is probably because the Studio test account is the experience's owner. Needs a check with a non-owner account in the Staging Player. If real players also see "Auto-collecting", it contradicts the goal text "Collect them at the green pad".
5. **Tower: the Build button turns into Upgrade under your finger** (`fp-11`). After "Build 25K", the same button becomes "Upgrade 5K", so a double-tap spends 5K straight away. There's also no "Book Nook built!" moment beyond the row changing. Suggestion: about 1 s of cooldown or a "Built!" state before Upgrade appears, plus a toast or sound.
6. **The base sign shows through the HUD at spawn** (`fp-02`). "LoopLabGames's Hatchery" sits right behind the coin panel and reads as "LoopLabGames's Ha+0/s y". A more opaque HUD panel, or moving the sign, fixes it.
7. **Daily claim has no reward feedback** (`fp-09`). The Claim button just turns into a timer. The window covers the coin counter, so you never see +601 land. A "+601 coins" pop would help. The odd amounts (601, 901, 5.41K) also look like bugs rather than designed numbers.
8. **The reveal creature looks grey and untextured** (Chipmunk, `fp-06`). Probably its mesh was still processing (Output: "Asset content representation is being generated"). Recheck on Staging. Also "Tap to continue" is low contrast, and the GOAL banner shows through the reveal dimmer.
9. **The side menu draws over modal windows** (Tower, Book, Daily: `fp-08`, `fp-10`). The right edge of each window sits under the Guide/Book/Tower buttons. Raise the modals' DisplayOrder or hide the side menu while a window is open.
10. **Tower, can't afford:** the greyed "Build 25K coins" gives no message when tapped (`fp-10`). "You need 24.2K more coins" would help.
11. **Robux tab on phone:** about 1.5 products are visible at a time, and the window stops short of the screen bottom. A world Buy prompt shows below it (`fp-13`).
12. **Welcome card on phone:** only 2 of its 4 tips show without scrolling (`fp-01`). "Earn coins" and "Raid and defend" are below the fold, with only a thin scrollbar hinting at them.

Worked without trouble: welcome "Let's go", goal banner steps, buying a Basic Egg, 5 s incubation with "Ready!", Hatch prompt, auto-placement on a pad, income ticking, Book (Found 1/53, NEW tag), Daily claim, floor 2 build and the wall sign "2. Book Nook".

## #97 per-stop signs @ f37d1b0

- **Sign legibility, phone 844x392: FAIL.** Each sign is 8.6x4.2 studs at 40 px/stud. It has 13 labels (egg name plus 6 tiers as "1 in N"), each about 0.46 studs tall.
  - 10 studs from Sign1 (beside Stop1), follow camera: a line is about 5 px. The character stands in front of the sign and covers its middle (`97f-hh-stop1-10studs-phone.jpg`).
  - 5 studs out, straight in front of the sign: a line is about 7 px (`97f-hh-sign-5studs-phone.jpg`, real-pixel zoom `97f-hh-sign-5studs-zoom.jpg`). The tier names can just be made out at 1:1 on the laptop. On a phone, 7 logical px is below anything readable. The egg name row sits under the GOAL banner, and the character covers the centre of the sign.
  - The rotation every 4 s works (cheapest first).
- **Nest from the path: PASS.** With the centre boards gone, the Golden Egg and the coloured eggs show clearly above the ring. The 8 signs are small, low and outside the belt, and don't hide the nest (`97f-hh-nest-from-path.jpg`).
- **Moved hub stands: not checkable in the world.** BookStand, ThemeStand, Mailbox and NoticeBoard exist only in the layout data and WorldArt; no instance with those names is built in this place. Only `HubLayout.spec` covers their spacing.
- **Suggestions for the signs:** use fewer, bigger lines at about 1 stud or more of text, for example egg name and price on line 1, then "Rare 1 in 125 · Epic 1 in 5.6K · Legendary 1 in 50K" on two lines. Put the sign where the follow camera sees it past the character: on the left post, or raised so its face sits at about 5-7 studs, above the character's head and below the banner band. Alternatively keep the tiers in the tap-to-open odds card and have the sign show just the egg name, price and the rarest odds.

## Roster to game: 61 new Commons, 4 patches on main f82fdd9

The four patches from `art/hatchery-heist/roster-to-game/` applied cleanly with `git am` on a detached f82fdd9. The local head is bcbaf74: same patches, different committer, so the hash differs from ad38a11. The build reports `build=bcbaf74e6004`, and creatures.luau has 91 Commons, up from 30. Phone 844x392.

**PASS.**
- **Hatches:** 5 eggs (4 Meadow, 1 Basic). They gave Piglet (existing, Basic), **Skunk (new)**, **Dragonfly (new)**, Toad (existing) and **Lobster (new)**.
  - Each new Common got the "NEW! Added to your Hatchery Book" reveal with "1 in 77.6", was placed on a pad, and earns.
  - All three new Commons draw with their **meshes**, not voxel boxes: MeshParts Skunk 5, Dragonfly 5, Lobster 4. No "drawing voxel boxes" line for any new species.
  - Their texture ids (Skunk 135003881643824, Dragonfly 98674226874925, Lobster 88648848823375) log "Asset content representation is being generated" in Studio. Expect them to look plain until Roblox finishes processing (`roster-hh-reveal-skunk.jpg`, `roster-hh-reveal-dragonfly.jpg`, `roster-hh-yard-new-commons.jpg`).
- **Book:**
  - Header "Found 3/114", Common tab "3/91".
  - The grid holds 91 cards, each at least 104x150 px.
  - It scrolls on phone to the last card (canvas 2532 px in a 198 px window) (`roster-hh-book-common-91-top.jpg`, `-end.jpg`).
- **Odds unchanged from main:**
  - Basic: 92 / 7 / 0.8 / 0.18 / 0.018 / 0.002 %.
  - Meadow: 67 / 31 / 1.7 / 0.28 / 0.017 / 0.003 %.
  - Moonlit: 58 / 38 / 3.7 / 0.29 / 0.008 / 0.002 %.
  - The per-creature "1 in N" for a new Meadow Common is 77.6.
- **Output:** nothing new beyond the texture-processing notices.

## #97 @ e94c6b4 (3-line signs, affordable-only Buy, refusal toast)

**PASS, with three small notes.** Phone 844x392.

1. **Sign at 10 studs, follow camera behind the character walking in to Stop1: PASS.**
   - The sign is on the left. All three lines read clearly at about 14 px, e.g. "Moonlit Egg · 15K" / "Legendary 1 in 12,500" / "Godly 1 in 50,000".
   - The character doesn't cover it, and its top sits just under the GOAL banner (`97g-hh-sign-10studs-walkin-phone.jpg`).
   - Text bounds are 0.90 studs per line, and `TextFits` is true for every line, including the longest ("Legendary 1 in 33,333").
   - At 14 studs the top line touches the banner's lower edge (`97g-hh-sign-14studs-walkin-phone.jpg`).
   - *Note:* standing at the stop itself, the GOAL banner and then the odds card cover the sign's right half (`97g-hh-at-stop-live-camera.jpg`, `97g-hh-at-stop-buy-oddscard.jpg`). That's fine, because the odds card shows the same information there.
2. **Fresh player at the stop: PASS.**
   - With 200 coins, only Basic Egg Buy prompts are enabled; every Meadow and Moonlit Buy prompt is disabled, and only Basic ones fire PromptShown.
   - At 0 coins, all of them enable.
   - The odds card is 280x214 px (75% scale) at the top left.
   - The Stop1 GuideArrow is disabled and no Beam is on within 4 studs of the stop.
3. **Coins refusal: PASS.**
   - At 0 coins, Buy on a Meadow Egg shows "Not enough coins: a Meadow Egg costs 2.5K. Basic Eggs cost 50."
   - The egg stays on the market (`MarketEggs.MeadowEgg`, transparency 0.00 at +0.6 s and +3.6 s).
   - *Note:* the toast sits between the banner and the Buy prompt, and its first word runs under the odds card (`97g-hh-refusal-toast.jpg`).
4. **Nest view: PASS.** The Golden Egg and coloured eggs read clearly over the ring (`97g-hh-nest-from-path.jpg`).
   - *Note:* the sign backs are plain dark slabs. From the far side of the ring you see blank boards; a wood back or a small egg icon would look nicer.

## #112 @ 2df231c (fresh-player fixes, stacked on #97 e94c6b4)

**FAIL: stopped at the first failure.** Phone size (viewport about 858x418; the window was not in front, because Alex was using the laptop).

- **Welcome card: PASS.** All four tips fit without scrolling (`112-hh-welcome-four-tips-phone.jpg`).
- **Coin panel: PASS.** Bar BackgroundTransparency is 0.05, and the base sign no longer shows through.
- **Side menu: FAIL. It never appears.** After "Let's go!", `HatcheryGuide.SideMenu.Visible` stays false for good, with no window open (`112-hh-spawn-no-side-menu-phone.jpg`). Guide, Book, Tower, Pets, Daily and Music can't be reached.
  - Cause: GuideView's new loop hides the menu while *any* enabled ScreenGui has DisplayOrder 20-49. CoreFeedback (20), CoreShop (30) and CoreTestPanel (35) are always enabled because they hold the top-bar buttons.
  - CoreFeedback and CoreShop exist on live servers too, so this would ship.
  - Fix: test each window's own `Window.Visible` (or keep an explicit list of the HH windows), not `ScreenGui.Enabled`.

## #111 @ 37850b9 (tower shells, ladder stop)

**PASS.** Phone 844x392. The visual half was done with Studio in front.

- **Own tower shell:**
  - With floor 1 only, it reads as a brick apartment with a roof (`111-hh-own-shell-floor1.jpg`).
  - After building floors 2-4 it shows four storeys plus the roof. Parts per storey: 452 / 437 / 525 / 365, roof 217 (`111-hh-own-shell-4floors.jpg`).
  - The insides read as rooms on the ground floor and floor 4 (`111-hh-ground-floor-inside.jpg`, `111-hh-floor4-inside.jpg`).
- **No ground-floor flicker.** Sampled 30 times over 3 s: 452 storey-1 shell parts visible every time, grey-box count steady at 8, shell count steady.
- **Ladder:**
  - With 1 floor, the ladder top is 2.2 and the landing is non-colliding.
  - With 2 floors: ladder 0.2 to 14.2, landing at 12.2 solid.
  - With 4 floors: ladder top 38.2, landing at 36.2. It stops at the top built floor and moves up after each build.
- **Deck creatures:** 8 given creatures sit on floor 4 and stand still for 15 s at 60 fps. That's expected: walking (#83) isn't on this branch (no Walk.luau on f82fdd9, 37850b9 or main). The leg/body hop check has to wait for a build with #83.
- **Neighbour shells:**
  - Neighbour towers were set server-side to TowerFloors 10, plus 320 creature clones.
  - Shells are drawn for own (1,996 parts) plus the 3 nearest: Plot2 and Plot8 at 84 studs, and Plot7, each 4,728 parts. Plot3 stays without a shell (`111-hh-neighbour-plot2-shell.jpg`).
  - Plot3's floors 2-10 aren't really built, because the plot is unowned, so its clone creatures float. That comes from my setup, not the PR.
- **Phone fps, standing in the yard with 4 full neighbours:**
  - Neighbours as 10-storey shells: 55.6 / 56.2 / 59.0 / 58.9 / 56.5 (median 56.5).
  - Neighbour shells dropped back to 1 storey: 57.1 / 58.6 / 58.9 / 58.9 / 55.8 (median 58.6).
  - So full neighbour shells cost about 2 fps. Client memory: 1,263 MB.

## #114 + #115 @ 82ccd64 (Book viewports near screen, virtualization)

**PASS, with one note.**
- **Phone 844x392:** Common tab, 6 columns, 0/30. Silhouettes are dark, "???", egg name and "1 in N" are correct (`115-hh-book-common-phone.jpg`).
- **Scrolling:** a scripted scroll top-to-bottom in 60 px steps and back up in 90 px steps, one frame each, found every visible card with its text and a ViewportFrame holding its model. No blank or stale cards.
- **Tabs:** Godly → Rare → Common and back gives the same canvas and 12/12 cards complete.
- **Desktop maximised (1350x684):** still 6 columns, no blanks, and it re-flowed after the resize.
- **Note:**
  - Right after a very fast scroll (4 jumps of 140 px in about 0.1 s), the row that just came into view **draws empty for well under 1 s** before the silhouettes appear (`115-hh-book-blank-row-right-after-fast-scroll.jpg`). They're filled by +1 s (`115-hh-book-filled-1s-after-scroll.jpg`).
  - The data side is complete during that moment (models and camera already in the ViewportFrame), so this is the first render of a ViewportFrame that has just become visible. A player flicking the list will see a brief blank flash on the new row.
- I couldn't test a 200-card tab: on this build the largest tab is Common at 30 cards.

## #116 @ 36b2f56 (floor label slack)

**PASS, with one note.**
- "Floor 2: 25K coins" over the ghost floor uses TextScaled and fits. The text takes 528 of the 1034 px label width, leaving clear space at both ends (`116-hh-floor2-label-close.jpg`).
- The label is a BillboardGui at (120, 13.8, 1.5). There's no floor plaque on an unbuilt floor, so it can't overlap one.
- **Note:** from the yard at spawn, it sits right beside the "⭐ YOUR HATCHERY ⭐" billboard (offset 10 above the sign at 140, 4.3, 0), and the two read as one line: "★ YOUR HATCHERY ★ Floor 2: 25K coins" (`116-hh-floor2-label-spawn.jpg`). Not an overlap, but crowded.

## #112 re-gate @ 1abc90f

**PASS.** Phone size (viewport about 858x418).

- **Side menu:**
  - Present after "Let's go!".
  - Hidden while Book, Daily, Tower, the Core Shop or the Test panel is open; back on close (Book checked both ways).
- **Daily:**
  - Amounts are round: 250 / 400 / 600 / 900 / 1.3K / 1.8K / 3.5K.
  - Claim shows gold "+250 coins!" in the footer under the day cards, nothing floating over them. Coins went 200 → 450 (`112c-hh-daily-claim-pop.jpg`).
  - The window still covers the HUD coin counter, but the footer pop is the feedback.
- **Tower:**
  - The greyed Build, tapped with 450 coins, shows "Need 24.55K more" (`112c-hh-tower-need-more.jpg`).
  - With 100.45K coins, a triple-tap 60 ms apart charged once (one `Shop:TowerFloor` sink, 100,450 → 75,450).
  - The button showed "Built!", then "Upgrade 5K coins" after about 0.8 s. "Building..." was too brief to sample.
- **Golden Egg Shop:** CameraMaxZoomDistance is 8 inside. No clipping, and the displays and counter are visible (`112c-hh-golden-shop-inside.jpg`).
- **Core Shop:**
  - 600x362 on phone, price on the button row.
  - The Robux tab shows about 2.3 products (`112c-hh-shop-robux-phone.jpg`).
  - Nothing cut off in Tidecatch, Street Food Empire or Depthbound (`112c-tc-shop.jpg`, `112c-sfe-shop.jpg`, `112c-db-shop.jpg`).
- **Market (from #97):**
  - Sign backs are light wood with "🥚 EGG MARKET". **The emoji renders as an egg** in Studio, not a box (`112c-hh-sign-back-egg-market.jpg`).
  - At 14 studs with the follow camera, the sign clears the GOAL banner (`112c-hh-sign-14studs.jpg`).
  - The refusal toast (y 128-156) now sits above the odds card (y 168+), no overlap (`112c-hh-refusal-toast.jpg`).
- Earlier items still PASS: welcome card shows 4 tips, coin panel is solid.
- Side note: the Test panel's "Reset my save" kicks the client, by design. Restarting play recovers.

## Hop leg/body look, main @ fca8d30 (includes #83 walking, before #74)

**Nothing for hop to break in the game yet.**
- No creature on main has `gait = "hop"`: CreatureMeshes carries no gait field. So Bunny, Lop Bunny, Calf and Lamb all walk with the default gait.
- Their in-game rigs have **no leg joints**. Motors are body, head, eyes, ears and tail (plus flower or scarf). The legs are part of the single body mesh, so legs can't cross the body in game. The 4-legged swing and hop poses in Walk.luau only drive parts named leg*.
- Watched up close for 4 s: the Bunny moved up to 5.5 studs, with the body bobbing and the head, ears and tail separate. No part passes through another (`hop-main-bunny-walking.jpg`).
- The checkered black/white look in the shot is the mesh texture mid-rewrite: Output says "being generated" during the upload run, which is expected. It isn't geometry overlap.
- So the overlap Alex saw is probably in the 3D viewer's separate-leg animation. It will matter in game only once creatures ship with leg parts and a hop gait (e.g. after #74 and the animation work).

## Staging player's-eye pass, published place 110929970966106 @ fca8d30

**How:** the desktop Roblox Player opened but ignores synthetic mouse input (the "Ready to playtest?" Continue click never registered). So I opened the **published Staging place** in Studio (File > open from Roblox, place 110929970966106, build=fca8d30e4238) and played it at phone size (858x418). It's the same published content and the same remote assets; the difference is the Studio Test panel and no DataStores.

**No blocking problems found.**
- **Fresh join:** the welcome card appears; "Let's go!" goes to the base with the GOAL "Walk to the Egg Market…" (`stg-welcome-phone.jpg`, `stg-spawn-phone.jpg`).
- **Egg Market:** bought Meadow (2.5K), Moonlit (15K) and Basic (50) eggs, and each went to an incubator.
- **Hatches:**
  - Fox Kit (Uncommon), Chipmunk (Common) and Kitten (Uncommon) all got the NEW reveal and were placed and earning (`stg-reveal-*.jpg`).
  - All three render as voxel/checker in the reveal: their textures are mid-rewrite ("Asset content representation is being generated" for each new texture id). That's expected during the upload run.
  - I didn't get a #117-new Common from a hatch. Through the Test panel I gave Bullfrog, CalicoKitten, Chinchilla, Cockatoo, CorgiPup, Ant and BearCub. All drew with MeshParts (3-5 each, 0 boxes).
- **Book:**
  - "Found 0/114", Common 0/91.
  - Scrolling the full 2532 px canvas in 100 px steps found no card without a model.
  - The last card (WalrusPup) shows a silhouette a moment after it scrolls into view (#114 behaviour, as on its gate) (`stg-book-114-end.jpg`).
- **Tower:** built floor 2. 7 creatures walk on floors 1 and 2: in 5 s they moved 0.2 to 2.4 studs, with meshes (`stg-floor2-walkers.jpg`).
- **Daily:** claimed Day 1.
  - Staging amounts are 2K / 3K / 4.5K / 6.5K / 9K / 13K / 20K. They are round, but much larger than the 250-3.5K on the #112 branch. Check which config is intended.
  - The side menu stays visible over the Daily window. Expected, because #112's hide fix isn't on main.
- **Output (real findings, not the in-place rewrite):**
  - `creature meshes did not load; drawing voxel boxes reason=mesh Hedgehog_ears missing from asset 83813792125695` and `NebulaSerpent_head missing from asset 133734762072662`: those two assets are missing a named part.
  - Glow meshes are missing for CrystalStag, EmberFox, FrostWolf, MoonUnicorn and ThunderGriffin (wing glow2). Those creatures draw without glow.

## #112 remerged head @ 5fa4ac7 (side menu re-check)

**PASS for #112, plus one finding that comes from the layout, not from #112.** Local build, phone size.
- **Side menu hides and comes back cleanly** on every window, over five open/close cycles: Daily, Tower, Pets, Core Shop and Book. Each open logged `side=false`; each close logged `side=true`. It was present after "Let's go!" and at the end.
- **Finding: the Roblox player list (CoreGui, top right) covers the Guide button.** With the player list open (the desktop default), the "LoopLabGames" panel sits right on top of 📖 Guide. Tapping Guide hits the player list instead and opens its "Examine Avatar" card (`112d-guide-under-playerlist.jpg`). The Guide button never received Activated in three tries.
  - Phones hide the player list by default, so this mainly affects desktop players.
  - Fix: start the side menu below the player list (for example under y 110 px), or hide the PlayerList CoreGui. HH has a single score, so the list adds little.

## #74 @ 1ef9dd3 (full creature meshes, legs and gaits), local build

**PASS.** Local build only; the cloud place was never opened. Desktop maximised. Set-up: floors 2-4 built, then given via the Test panel: Beetle, Bluebird, Bunny, CrystalStag, Duckling, Earthworm, EmberFox, Frog, FrostWolf, Grasshopper, Hedgehog, MoonUnicorn, NebulaSerpent, Snail, ThunderGriffin.

1. **Gaits on the tower floors, sampled 8 s at 10 Hz while walking:**
   - Every legged creature's leg joints swing:
     - Quadrupeds about 0.5 rad: EmberFox, FrostWolf, Hedgehog, CrystalStag, MoonUnicorn.
     - Grasshopper's six legs 0.69 rad; Beetle's six legs 0.28-0.30 rad (scuttle).
     - Bluebird and Duckling (two legs) waddle.
   - Hoppers lift the body about 0.7 studs per hop: Bunny, Frog, Grasshopper.
   - ThunderGriffin hovers with its body bobbing up to 0.68, legs moving.
   - Snail and Earthworm creep (body offset ≤0.08, no legs) with no spinning.
   - NebulaSerpent's body wave goes up to 1.2.
   - Close-ups of Bunny, Beetle, Bluebird, FrostWolf, ThunderGriffin and NebulaSerpent show no flicker at the leg joints and no legs passing through bodies (`74-hh-bunny-beetle-bluebird.jpg`, `74-hh-frostwolf-trot.jpg`, `74-hh-thundergriffin.jpg`, `74-hh-nebulaserpent.jpg`).
2. **The seven named creatures:**
   - All draw with meshes, and Output has **no** "drawing voxel boxes" or "glow meshes missing" line (unlike Staging at fca8d30).
   - Hedgehog: 8 MeshParts, no ears, no boxes.
   - EmberFox, FrostWolf, CrystalStag: one neon `legXX_glow` paw block per leg (0.29x0.10x0.29), plus a mane/body glow.
   - MoonUnicorn: 6 glow parts. ThunderGriffin: 6 glow parts including the tail. NebulaSerpent: head present, 10 glow parts.
   - *Note:* FrostWolf's `mane_glow` is a thin neon bar (0.21x1.25x0.42) standing behind the head. From the side it reads like a stray white stick (`74-hh-frostwolf-trot.jpg`). It's by design, but polish may want it wider or shorter.
3. **Reveal and Book:**
   - The Tabby Kitten reveal shows a whole, textured creature (`74-hh-reveal-tabby.jpg`).
   - In the Common tab, all 91 cards have mesh models (4-10 MeshParts) and no boxes.
   - In the Uncommon tab, all 7 silhouettes and the found Hedgehog are whole (`74-hh-book-uncommon.jpg`). As on #115, newly shown cards take a moment before their first render.
4. **First screen:** welcome card, HUD, side menu and shield look as before. Nothing regressed (`74-hh-first-screen.jpg`).

## Post-#74 main @ 126dd4a (local build)

**PASS, with one finding.**
- Walking with legs: EmberFox, FrostWolf, CrystalStag, MoonUnicorn and Hedgehog each swing their legs 0.51-0.62 rad. Bunny hops (lift 0.62). NebulaSerpent waves (lift 1.2).
- Paw glows: 5 glow parts on EmberFox, FrostWolf and CrystalStag; 6 on MoonUnicorn.
- Hedgehog: 8 meshes, no boxes, no ears by design. NebulaSerpent's head is present.
- **Finding:** Output says `creature glow meshes missing ... ThunderGriffin_wingR_glow2, ThunderGriffin_wingL_glow2`. This didn't appear on the PR head 1ef9dd3, so the live ThunderGriffin asset seems to be missing the wing glow2 parts.

## #119 @ b93446a (polish)

**FAIL on the Book flick; the other checks PASS.** Desktop maximised.
- **Guide on desktop: PASS.** The PlayerList CoreGui is off. The side menu starts at y 124, and tapping Guide opens the welcome card (`119-hh-guide-desktop.jpg`).
- **Floor-2 label vs YOUR HATCHERY: PASS.** The banner moved up to offset 14.5. From the yard the two no longer share a line (`119-hh-hatchery-banner.jpg`). The floor label isn't AlwaysOnTop (MaxDistance 80), so it hides behind the house from most angles.
- **Book fast flick: FAIL.** Scrolling 4 jumps of 350 px in about 0.12 s leaves **two whole rows blank** right after (`119-hh-book-flick-blank.jpg`).
  - About 0.5 s later most of them are filled, but not all (`-partial.jpg`). By about 1 s all are filled (`-filled.jpg`).
  - The data side reports all 24 visible cards have models, so the first-render blank from #115 is still there.
  - A player flicking fast will see blank rows for up to about 1 s.
- **First screen:** apart from the moves above, nothing else changed.

## #92 @ 7783949 (Legendaries, Phoenix and Thunder Griffin welds), local build

**PASS, with notes.** Desktop.
- **Scope:** in-game config at this head has only **2 Legendaries** (Phoenix, ThunderGriffin). The other "48 Legendaries" are art-tool sources (`tools/art/legendaries.py`, `kit_myth.py`) and aren't playable creatures yet, so the "six other Legendaries" spot-check isn't possible. The Book Legendary tab shows 2/2 (`92-hh-book-legendary.jpg`).
- **Welds:** I computed the gap between every non-glow mesh part and its nearest neighbour (oriented boxes): **0.00 for every part** on both creatures.
  - Phoenix: 9 parts. Wings, legs and tail touch the body; crest and eyes touch the head.
  - ThunderGriffin: 12 parts. Wings touch the ruff, legs touch the body.
  - No floating pieces (`92-hh-phoenix-pad.jpg`, `92-hh-griffin-pad.jpg`).
- **Glow:**
  - Phoenix has 10 glow parts, including wing glow2.
  - ThunderGriffin has 5: wingR/L_glow plus tail_glow/glow2/glow3. This PR *removes* the wing glow2 meshes from CreatureMeshes and adds tail glow2/3.
  - Output has **no** "glow meshes missing" line, so the main-126dd4a warning is fixed by this PR.
  - Note for the verifier: there are no wing glow2 pieces, by design here.
- **Size on the pad:** Phoenix bounding box 4.0x3.9x4.0 and ThunderGriffin 5.3x4.0x4.7, each on a 3.8-4.4 stud ring, hovering. Bloom is heavy at desktop size, as noted before for big tiers.
- **Hatch reveal:** not checked. The Test panel can't trigger a Premium-egg reveal, and Phoenix/Griffin come only from Premium eggs. The Book card shows both whole.
- **Kittens:** Calico, Persian, Siamese, Tabby, Tuxedo and Kitten all draw with meshes (9-10 MeshParts, 0 boxes) in world and Book. This was **before** the kitten re-upload.
- **First screen:** unchanged (`92-hh-first-screen.jpg`).

## #119 Book re-check @ 2c2042d

**Mostly fixed. One case left.** Desktop, Common tab, four 350 px jumps.
- **First flick after opening the Book (0.5 s wait): still blank.** Right after opening, the first fast flick down lands on two blank rows (`119b-hh-first-flick-blank.jpg`). At that point the data side reports all 91 cards built (ViewportFrames hold models), and fps is 60. So the warm range is built, but those frames haven't rendered once yet.
- **Every later flick (down again after 0.8 s; up after 0.5 s): PASS.** Every row is drawn the moment it lands (`119b-hh-second-flick-down.jpg`, `119b-hh-flick-up.jpg`).
- **Read:** building is fine. The blank comes from a ViewportFrame's first render, which only happens once it has been on screen. A first fast flick within about a second of opening still shows it.
- **Possible fix:** on open, briefly cycle the canvas through the warm range off-screen, or keep ViewportFrames Visible with the cards at ImageTransparency 1 for one frame, so each one renders once before the player scrolls.

## #119 Book @ b044b4c (warm cards hidden behind on-screen cards)

**FAIL.** Desktop, Common tab.
- **Warm cards show through.** During the first second after opening, the hidden warm-up cards stacked behind the on-screen cards are visible:
  - their labels bleed through the cards in front, e.g. "MBasic Egg g" and doubled "Meadow Egg" (`119c-hh-open-text-bleed.jpg`, `119c-hh-immediate-flick.jpg`);
  - many on-screen cards are still blank.
  The front cards' background doesn't fully cover the cards behind. Text renders on top of, or through, the semi-transparent card.
- **Flick right after opening (≈50 ms):** lands at 1400 with most cards blank, plus the same text bleed (`119c-hh-immediate-flick.jpg`).
- **At ≈0.3 s, even unscrolled:** the top two rows still have blank cards (`119c-hh-03s-top.jpg`).
- **At ≈1 s:** the flick lands fully drawn, and every card sits in the right slot (`119c-hh-1s-flick.jpg`).
- **Read:** this is worse than 2c2042d in the first second, because of the visible bleed. It's the same after 1 s.
- **Suggestions:** park warm cards off-screen inside a ClipsDescendants frame that still counts as on screen; or set the front cards' BackgroundTransparency to 0 and put warm cards at a lower ZIndex/LayoutOrder; or warm with a GroupTransparency of 1 inside a CanvasGroup.

## Main @ 0d49cd0 after #92 (local build of the published commit)

**PASS.** I couldn't drive the published Staging game: the desktop Player ignores synthetic input and screen-control is down. So I checked a local build of the exact published commit, which loads the same live mesh assets.
- No "glow meshes missing" line in Output; the ThunderGriffin wing glow2 warning is gone.
- Phoenix: 19 MeshParts, 10 glows, 0 boxes. ThunderGriffin: 17 MeshParts, 5 glows, 0 boxes.
- All five kitten Book cards have meshes (9-10 MeshParts, 0 boxes). Calico and Persian on pads are the same.

## #119 Book @ d9dc0ff

**FAIL.** Desktop, Common tab.
- **Fixed:** nothing peeks through the front cards any more (no text bleed). Layering is right: dark well under the picture, name and odds over it. After about 2 s every card is in its slot with its silhouette (`119d-hh-settled.jpg`).
- **Still blank:**
  - A flick right after opening lands on 18 visible cards with empty wells (`119d-hh-immediate.jpg`).
  - At 0.3 s it's the same (`119d-hh-03s.jpg`).
  - At 1 s, 5 of 12 fully visible cards are still empty (`119d-hh-1s.jpg`).
- So this is **worse than 2c2042d**, where the 1 s flick was fully drawn. The new 0.3 s start delay plus 4 per frame isn't fast enough to warm the rows a flick reaches.
- Not run: the tab-switch repeat and the NEW badge (no found cards in a fresh save), since the flick check already fails.

## #71 @ f5b766b (Godly rework: Nebula Serpent, Golden Goose)

**PASS, with two notes.** Local build, desktop, both given through the Test panel onto ground-floor pads.
- **Meshes:** NebulaSerpent 42 MeshParts (33 glow), GoldenGoose 20 (10 glow). No placeholder boxes. The only non-mesh parts are the Godly Ring and the Goose's eight 0.3-stud orbiting Orbs (the tier effect).
- **Hover:** bottom above the pad was sampled over 6 s.
  - Serpent: 0.84-1.29 studs (0.18-0.27 of its 4.7 height).
  - Goose: 0.84-1.02 (0.16-0.19 of 5.3).
  - The minimum is above 0.14 of height, as expected with the bob on top of the 0.14 base.
- **Welded:** gaps between nearest parts (oriented boxes) are 0.00 for every Serpent part (body_1-4, head_1-2, eyes, orbit_1-2).
  - Goose: all 0.00 except the **nest, 0.15 studs** from its nearest part. That's a small but real gap under the body.
- **Orbiting worlds:** orbit_1 is one 7.5-stud mesh (the ring of worlds) around the body, and orbit_2 is a small world. Close-ups show the worlds circling outside the coil (`71-hh-serpent-pad.jpg`). A box-overlap test can't separate "passes through" from "circles around" for a ring mesh, so this is judged by eye only: nothing seen passing through.
- **Walk.lie:** on a ground-floor pad the Serpent is coiled upright (about 3.7x5.5 studs) and wanders, turning through 10 headings. It does **not** lie along the row. `Walk.lie` only fires when the creature is too long for the spot's depth, and this coil isn't, so I couldn't observe lie behaviour here.
- **Book:** both Godly cards draw whole with NEW badges (`71-hh-book-godly.jpg`).

## #119 Book @ 3978bac

**FAIL.** Desktop, fresh join, Common tab. Each flick is four or more 350 px jumps.
- **First open, flick at about 0 s:** at the first capture (about 1-2 s later, because the capture tool is slow), 3 of 18 visible cards were drawn and 15 were empty (`119e-hh-first-open-flick.jpg`). They were all filled by the next capture, about 5 s later.
- **Reopen (all 91 cards reported built; built cards persist while closed), flick 0→2100→700:** 10 of 18 drawn, 8 empty (`119e-hh-reopen-flick.jpg`).
- **Tab switch (Uncommon, then back to Common), flick to 1400:** 0 of 12 fully visible cards drawn (`119e-hh-tabswitch-flick.jpg`).
- **Fixed:** no bleed-through, and layering is correct.
- **Read:** the cards are built, and the data side counts 91/91 with models. But a ViewportFrame that has been off screen, or whose tab was hidden, still has to render again when it comes back. Reopening and switching tabs don't land on drawn cards, so the acceptance bar isn't met. Persisting the built cards doesn't help, because Roblox drops a ViewportFrame's render once the frame is hidden or its parent isn't visible.
- **Suggestion:** consider a static image instead. Render each silhouette once into an EditableImage/capture or a pre-baked thumbnail per species, so the Book shows ImageLabels. That removes ViewportFrame first-render latency entirely.
- **Not run:** the NEW badge check, since the flick checks fail.

## #79 @ 55b612f (Crayfish, Ladybug re-uploads)

**PASS, plus one cross-PR warning.** Local build, desktop.
- **Crayfish:** 10 MeshParts, 0 boxes. Every part touches its neighbour (gap 0.00), including leg2L/R and leg3L/R onto the body.
- **Ladybug:** 9 MeshParts, 0 boxes, all gaps 0.00 (head↔body, legs→body).
  - In-game mesh height is 1.98 studs; both creatures are scaled to the 2-stud creature ball, as every Common is. The "1.1-stud height" in the brief must be the art-space height before scaling. I can't see a separate 1.1 in game.
- **Book:** both cards draw. The found Ladybug card shows the red-and-black textured model with its NEW badge (`79-hh-book-ladybug.jpg`).
- **Warning (not #79's fault):** on this branch Output logs `creature meshes did not load; drawing voxel boxes reason=mesh NebulaSerpent_head missing from asset 133734762072662`.
  - #71 re-uploaded the Serpent asset **in place** with new part names (head_1/head_2).
  - So any build without #71's CreatureMeshes now draws the Serpent as voxel boxes. That likely includes **main and Staging until #71 merges**.

## #120 events @ ae7e48f

**PASS, with three small findings.** Local build, desktop (1350x672) and phone (844x392).
- **Banner and card:** the top-bar banner shows "Speedy Incubators · Next event in 8h 37m". Tapping it opens a card with the next event, its blurb, the start time, today's Giant Egg (Thunder Griffin, Legendary) and "One 30-minute event every day" (`120-hh-event-card.jpg`). On phone the banner (x 332-572) doesn't overlap the HUD, Shop, Test or Feedback (x 724+) (`120-hh-phone.jpg`).
- **Egg Sale:** prompts show "SALE! Basic Egg: 25 coins", Meadow 1.25K, Moonlit 7.5K. Buying a Basic egg charged **25** (log `amount=25 reason=Shop:BasicEgg`). A toast "Egg Sale! Every market egg is half price! For 30:00." appears.
  - *Finding:* 1 of 29 enabled Buy prompts still showed the old full price ("Moonlit Egg: 15K coins") 6 s after the start. Each egg refreshes its label only on its own update, so one stale label can sit on the belt briefly.
- **Speedy Incubators:** a Meadow egg bought during it showed 0:29 on its incubator, against 0:58-1:00 normally, so halved.
- **Money Rush:** income +141/s → **+282/s** during the event, back to 141 after.
- **Lucky Hatch:** odds card boosted rows sum to 100.000% (Meadow 66.229/30.644/2.522/0.554/0.042/0.009; Basic 91.440/6.958/1.193/0.358/0.045/0.006).
  - *Finding:* the card header reads **"Boosted: LuckyHatch"**, which is the internal id; it should say "Lucky Hatch".
- **Giant Egg:**
  - An 11-stud egg sits on the Golden Nest with Thunder Griffin (TodaysLegendary) standing on top.
  - The sign reads "GIANT LEGENDARY EGG · Today: Thunder Griffin +500/s · Coming soon · one a day · new in 3h 13m".
  - The shell rocks in occasional short wobbles (about ±3°).
  - Market eggs are moved out: the nearest is on the 30-stud ring. The decorative Golden Egg is gone; the nest's small pink, blue and green decorative eggs remain.
  - The Buy prompt reads "**Coming soon** / Giant Legendary Egg". There's no Giant Egg entry in the Core Shop.
  - *Finding:* the sign faces one way, and from the main path it's partly behind the egg (`120-hh-giantegg-phone.jpg`).
- **Test panel:** "event" buttons start each kind, and Stop works. "giantegg → Forget" replies "Today's Giant Egg can be bought again."
- **Output:** nothing new from #120. The voxel NebulaSerpent line comes from the branch base, before #71.

## #119 trimmed @ 454a645 vs main 00ac01c

**PASS: no regression, and better on reopen.** Desktop, fresh join, Common tab. Same procedure on both builds; captures land about 1-2 s after each flick.

| Moment | main 00ac01c | #119 454a645 |
|---|---|---|
| First open, flick to 1400 at once | 2 of 12 visible cards drawn | 1 of 12 drawn (same) |
| Close, reopen, flick 0→2100→700 | about 1 of 12 full cards drawn | **9 of 12** full cards drawn, plus the top partial row drawn |

- **Dark well** visible under every card on #119 (main has none), so an unfilled card reads as "loading", not "missing".
- **NEW badge:** after giving a Chick, its card shows the NEW badge with a coloured model. After closing and reopening the Book, NEW is gone and the side-menu badge has cleared (`119f-pr-new-badge.jpg`, `119f-pr-new-cleared.jpg`).
- **No bleed-through:** layering is right (well, then picture, then name/odds, then NEW).
- **Non-Book fixes hold:** PlayerList CoreGui off; side menu starts at y 124; YOUR HATCHERY banner offset 14.5, clear of "Floor 2: 25K coins".

## #120 re-check @ 33ede02 (three findings, plus the phone sign fit)

**(1) and (2) PASS; (3) FAIL on phone.** Local build.
1. **Belt prices refresh:** when Egg Sale starts, every enabled Buy label shows SALE within **0.41 s**. When it stops, every label is back to full price within **0.35 s**.
2. **Odds header:** reads "**Boosted: Lucky Hatch**" (`120b-hh-lucky-hatch-header.jpg`).
3. **Giant Egg sign:** it's now a BillboardGui on the Hitbox, so it faces the camera from every side. Its centre is at y 20.6 (`SignBottom` 18.30). Today's Thunder Griffin top is at y 18.38, so the sign's bottom edge sits at the creature's head (about 0.1 overlap), **not 0.8 above**.
   - **Phone fit (844x392), projected through a follow camera 12 behind and 4 up, facing the egg from the path:**

     | Player distance from egg | Sign on screen |
     |---|---|
     | 25 studs | y 26-66 |
     | 36 studs | y 57-87 |
     | 50 studs | y 80-103 |
     | 70 studs | y 99-116 |

   - The coin HUD and GOAL banner fill x 242-602, y 8-118, right where the sign's centre (x 422) lands. **On a phone the raised sign sits behind the HUD and GOAL banner from every distance on the path.**
   - Studio's capture tool renders BillboardGuis from its own camera, so screenshots of the sign's height aren't reliable. These numbers are projected from the actual follow-camera geometry instead.
   - Suggestion: put the sign back at about egg height, beside or in front of the egg, or attach it lower with the creature drawn above. Keep its centre below about 13 studs so it lands under y 120 on a phone.

## #120 @ 576526e (phone sign fix, Giant Egg event special)

**PASS.** Local build.
1. **Giant Egg sign placement:**
   - The sign is an 11 x 4.2-stud BillboardGui with its centre at y 7.45, offset 9.88 studs to the camera's right of the egg.
   - Projected through the follow camera (12 behind, 4 up) from the path at 20, 25, 36, 50, 70 and 90 studs.
   - **Phone 844x392:** sign at x 434-557, y 135-172. That's always below the HUD/GOAL band (bottom y 118), clear of the side menu (x ≥ 750), and right of the character (x 394-448).
   - Raycasts to 9 points on the sign hit neither the Giant Egg nor the Legendary at any distance (0/9 occluded).
   - **Tablet 1024x698:** y 240-306. **Desktop 1350x672:** y 231-295. Also 0/9 occluded.
   - On phone, the sign shrinks to about 38x15 px at 70 studs and 31x11 px at 90, so the text is only readable from about 36 studs or closer (64x25 px there).
2. **Event special:**
   - With Money Rush started, the sign reads "EVENT SPECIAL: 250M coins · one a day". The prompt (key G, range 16) reads "Buy for 250M coins / Event special: costs coins now".
   - With 250M coins, pressing G charged exactly **250,000,000** (log `reason=Shop:GiantEgg`, balance 200). The Thunder Griffin reveal played ("NEW! … LEGENDARY … +500 coins/s") and a Thunder Griffin was placed.
   - After that the prompt reads "Yours today" and is disabled, and the sign says "Yours today! New Legendary in 2h 36m". A second G press bought nothing (still one Griffin).
   - After Forget and Stop, the sign is back to "Coming soon · one a day · new in …" and the prompt to "Coming soon / Giant Legendary Egg".
3. **Belt reprice:**
   - All enabled labels showed SALE 0.07 s after Egg Sale started.
   - All were back to full price immediately when switching to Lucky Hatch.
   - The odds card reads "Boosted: Lucky Hatch".

## #109 @ 5674076 (Common B legacy refits)

**PASS.** Local build, desktop and phone.
- **Scope:** compared with current main, the only in-game creature change in this head is **Bumblebee**: new textureId 82434895412728, raised 0.2 (height 1.1 → 1.3), tris 7076. Meerkat and the other refit commits are already on main or only touch the art-tool sources, so there's nothing else live to check.
- **Bumblebee on a pad:**
  - 9 MeshParts, 0 boxes, all using texture **82434895412728** (the new one).
  - Every part touches its neighbour (gap 0.00): wings and legs on the body, head on the body, eyes on the head.
  - Its lowest point stays 0.01-0.15 studs above the pad over 3 s of hover bob, so there's no clipping into the floor (`109-hh-bumblebee-pad.jpg`).
- **Ladybug (control):** 9 meshes, 0 boxes, sits 0.01-0.09 above the pad.
- **Book (phone 844x392):** the Bumblebee card shows the textured model (9 MeshParts, texture 82434895412728) with its NEW badge (`109-hh-book-bumblebee-phone.jpg`).
- **Output:** only "content representation is being generated" for the fresh texture, plus my own script error from a lookup by the wrong card name. No asset failures.

## #126 @ b1abd44 (lazy hatch order in restricted mode)

**Logic PASS. Layout FAIL (the odds card overflows the screen).** Local builds. Restricted mode came from the fallback: the policy fetch at CoreServer.luau:309 was patched locally to return `{ ArePaidRandomItemsRestricted = true, IsPaidItemTradingAllowed = false }`. That patch was not committed.
- **Restricted, Basic Egg odds card:**
  - Header: "Fixed order, no chance involved:".
  - 47 rows, one per outcome, each "Name (Tier): N in every 100000" with a wait. Commons 2359 each (Silkie 2358), Uncommons 3500 each, Raccoon 800, Ember Fox 180, Dragonling 18, Phoenix 2. These match main's tier odds 92 / 7 / 0.8 / 0.18 / 0.018 / 0.002 %, split across the tier.
  - Gosling = **NEXT**, Turtle "in 2 eggs", Bunny "in 3 eggs", … Phoenix "in 25011 eggs".
- **Buy and hatch one Basic Egg:**
  - The hatch was **Gosling** (Uncommon), the one marked NEXT.
  - The reveal shows no "1 in N" line (`126-hh-restricted-reveal-gosling.jpg`).
  - Afterwards every wait dropped by 1 (Bunny 3→2, Silkie 41→40, Raccoon 44→43, Phoenix 25011→25010). **Turtle became NEXT**, and Gosling moved to "in 41 eggs".
- **Book in restricted mode:** the found Gosling card and the ??? cards have **blank odds lines**, with no egg name and no "1 in N" (`126-hh-restricted-book.jpg`).
- **FAIL, layout:** the restricted odds card is **280x1142 px on a 672 px tall desktop viewport**, placed at y −264. It runs off the top and bottom of the screen and covers the Shop/Test buttons and the chat. There's no scroll, so most rows, including NEXT (near the bottom), can't be seen (`126-hh-restricted-oddscard-overflow.jpg`). On a phone it would be worse. Fix: make the list a ScrollingFrame capped to the viewport, or show only NEXT plus the next few rows and the rarest outcomes, grouping Commons as one line.
- **Unrestricted pass:** the odds card is unchanged from main (Basic: 92.000% · 1 in 1.1 / 7.000% · 1 in 14.3 / 0.800% · 1 in 125 / 0.180% · 1 in 556 / 0.018% · 1 in 5,556 / 0.002% · 1 in 50,000; size 280x214).

## #126 fixed head @ 952e6f8

**Desktop and logic PASS. Phone FAIL (the card overflows the bottom). One truncation finding.** Local builds; restricted mode uses the local policy-fetch patch, not committed.
- **Desktop 1350x672, restricted:** the card is 280x310 at y 152-462, so it fits (`126b-hh-restricted-card-desktop.jpg`). Contents:
  - "Fixed order, no chance involved:", then the next three: Gosling NEXT · Turtle in 2 eggs · Bunny in 3 eggs.
  - Then one line per tier: Common 92000 in 100000 · in 3 eggs; Uncommon 7000 · NEXT; Rare 800 · in 44; Ultra Rare 180 · in 296; Epic 18 · in 2796; Legendary 2 · in 25011.
  - The tier counts sum to **100000**, the cycle length.
  - Rows are small text at desktop size, but readable.
- **"See the whole order":** opens "Basic Egg: fixed order", 340x460, soonest first with "count in 100000 · wait" per creature (45 creatures). It **scrolls**: canvas 1168 px, CanvasPosition reached 708 (`126b-hh-whole-order-list.jpg`).
  - *Finding:* the right column truncates: "3500 in 100000 · in 2…" (`TextFits=false`, needs 141.6 px in a 161.5 px label at this size, `TextTruncate=AtEnd`). The wait value is the part being cut off.
- **Buy one egg:** hatched **Gosling** (the old NEXT). After the hatch the card shows Turtle NEXT · Bunny in 2 eggs · Chick in 3 eggs, and the tier waits each dropped by 1 (Rare 44→43, Ultra Rare 296→295, Epic 2796→2795, Legendary 25011→25010).
- **Phone 844x392, restricted: FAIL.** The card is 280x**310** placed at y 168, so its bottom is at y **478**, 86 px off the bottom of a 392 px screen. No UIScale was applied, so it didn't shrink as specified.
- **Unrestricted:** the card matches main: 280x214, Basic 92.000% · 1 in 1.1 … 0.002% · 1 in 50,000. Desktop y 152; phone y 168-382 (fits).

## #125 Book thumbnails @ 2f2f05f

**PASS, with two notes.** Local build. Each card is now an ImageLabel "Picture" (91 in Common); there are no ViewportFrames.
- **First open in a fresh session (cold image cache):** a flick right after opening showed **empty wells for about 1-3 s** while the images downloaded (`125-hh-first-open-cold.jpg`). They were filled by the next capture (`125-hh-first-open-3s.jpg`).
  - At about 3 s, 72 of 91 images had loaded. The last 19 (Lamb, Lorikeet, MacawChick, Mole, Moth, Opossum, OtterPup, PacmanFrog, Parakeet, Platypus, SealPup, ShibaPup, SiameseKitten, Silkie, Skunk, Snail, SunConure, TreeFrog, WalrusPup) took longer, but **all had loaded by about 10 s. None stayed blank.**
  - The first open of each other tab behaves the same way (Uncommon and Rare blank for about 1-3 s, then drawn).
- **Reopen and fast flick (0→2100→700):** every visible card was drawn at once (`125-hh-reopen-flick.jpg`). The tab switch back was also instant once the tab had loaded. This is the big improvement over ViewportFrames.
- **Silhouettes and pictures:** unfound creatures are solid black silhouettes (ImageColor3 0,0,0). After giving Ant, Bumblebee, Bunny, Chick and Crayfish, their cards show the coloured picture with a NEW badge. Spot-checked Bunny (white rabbit) and Chick (yellow chick): right species, well framed (`125-hh-found-colour.jpg`).
- **Odds lines:** unchanged ("Meadow Egg · 1 in 77.6", "Basic Egg · 1 in 42.4", Rare "1 in 125 / 118 / 7.9 / 3.1").
- **Phone 844x392 (fresh session):** the window is 760x352 at y −9, so it fits, and the pictures show at once (`125-hh-phone-fresh.jpg`).
  - *Note:* if the viewport shrinks while the session is running (desktop → phone), the Book keeps its desktop height (760x560) and sits at y −113, cutting off the title. It doesn't refit on resize. That matters for a device rotation, not for a normal join.

## #126 @ 5341bf8 (compact restricted odds card)

**FAIL by 4 px. Everything else passes.** On a phone in restricted mode, the compact card's bottom edge is at screen y 388. The target is ≤384. The whole card still shows on the 392 px screen. Local builds. Restricted mode comes from the local policy-fetch patch, which was not committed.
- **Phone 844x392, restricted:**
  - The card is 211x163 after the UIScale, at screen y 226-388 (**4 px over the ≤384 target**) (`126c-phone-restricted-card.jpg`).
  - The tier rows scroll (canvas 233 in a 163 frame).
  - The smallest text is 5.6 px tall. That's small but readable in the capture.
  - "See the whole order" can be reached by scrolling inside the rows.
- **Whole order (phone):**
  - The window covers screen y 138-382 and is titled "Basic Egg: fixed order".
  - The header reads "How many of every 100000 eggs:".
  - Rows read like "Gosling (3500) | NEXT" and "Turtle (3500) | in 2 eggs".
  - **0 truncated labels**, so the right-hand column is complete.
  - It scrolls (canvas 1194; I reached 1014) (`126c-phone-restricted-whole-order.jpg`).
- **Desktop 1350x672, restricted:** 280x310 at y 152-462, the same as 952e6f8.
  - Rows: Gosling NEXT / Turtle in 2 eggs / Bunny in 3 eggs, then the six tiers as "N in 100000 · in N eggs", then "See the whole order".
  - 0 labels fail TextFits (`126c-desktop-restricted-card.jpg`).
- **Desktop, unrestricted:** matches main. The card is 280x214, and Basic reads 92.000% · 1 in 1.1 / 7.000% · 1 in 14.3 / 0.800% · 1 in 125 / 0.180% · 1 in 556 / 0.018% · 1 in 5,556 / 0.002% · 1 in 50,000 (`126c-desktop-unrestricted-card.jpg`).
- **Bumblebee Book card:** while unfound it's a drawn silhouette. After a test-panel give it shows the full-colour bee with a NEW badge, "Bumblebee", and "Meadow Egg 1 in 77.6". It's a live ViewportFrame with 9 parts and none of them dark, so it isn't a black card (`126c-book-bumblebee.jpg`).

## #87 @ e7332eb (Owlet re-texture), merged onto main as b478729

**PASS.** Local Staging build. I gave an Owlet from the test panel and watched it in the plot.
- **Textured:** all 8 MeshParts (16 parts in total) use TextureID 139903809045735, the new id from the PR. None are untextured. It shows as a brown feathered owl with yellow feet (`87-hh-owlet-plot.jpg`).
- **No gaps:** the largest OBB gap between visible parts is 0.000 studs.
- **Feet on ground:** the plot floor is at y 0.70. While walking, the leg boxes' lowest corner reaches 0.67, a 0.03 stud corner dip from the leg swing, and no other part goes below 0.75. At rest the bottom of the bounding box is at 0.71.
- **Walks:** it moved along a 2.40 stud path in 12 s with the waddle gait. Head and body stay together.
- **Book card:** the Rare tab shows "Owlet / Moonlit Egg 1 in 7.9" with a NEW badge and the coloured model (8 viewport parts) (`87-hh-book-rare.jpg`).
- **Rare odds unchanged:** Raccoon Basic 1 in 125, Penguin Meadow 1 in 118, Owlet Moonlit 1 in 7.9, Fennec and PandaCub Premium 1 in 3.1.

## #127 @ 6e04cfe (Charms and the Charm Claw), merged onto main as 130c142

**FAIL, phone layout.** On an 844x390 phone, the 10-pull reveal's footer runs about 14 px past the bottom of the screen. The Open Charms and Done buttons are cut off: only about 30 of their 44 px show (`127-hh-phone-pull10-FAIL.jpg`). The Lua numbers are stage y −13..346, heading −13..22, tray 30..290 and footer 302..346. The real pixels sit 58 px lower than those numbers say, even though IgnoreGuiInset is true, so on screen the heading is at about 45 and the footer at about 360..404. Likely cause: `screenSize()` takes off TOP_BAR, but the stage is centred at Position (0.5, 0.5)+29 in a gui that still renders under the top bar. Fix: anchor the stage to the safe area, or size it from (viewport − 58 − footer). I stopped at this FAIL, so the small phone was not checked.

Everything checked before the FAIL (desktop 1350x672 unless noted):
1. **Claw cabinet:**
   - It sits at angle 15.0°, r 42.6 (pivot; spec r43) and faces the middle (look·centre = 1.000).
   - It's in front of the Golden Egg Shop and off the door's line.
   - The "Charm Claw" marquee is present. ClawPrompt reads "Play / Charm Claw" and reaches 9 studs (`127-hh-claw-hub.jpg`).
2. **Claw window, 760x500:**
   - Odds per tier with % and 1 in N (Common 55.000% · 1 in 1.8 … Godly 0.100% · 1 in 1,000).
   - The split line, the 10-pull Rare+ and 100-pull Epic+ promise lines, and the pity line (Legendary+ within 200).
   - "See every charm" opens 4 tables: Every pull (21 rows), 10-pull promise (15), 100-pull promise (9) and pity (6). Each sums to 100.000%. 0 labels fail TextFits (`127-hh-claw-window.jpg`, `127-hh-claw-every-charm.jpg`).
   - Coin prices are x1 5K, x10 45K and x100 400K. Coins went down by exactly 5K + 45K.
   - The Robux rows read "10 pulls: coming soon" and "100 pulls: coming soon". AutoButtonColor is off, and clicking both brought up no purchase prompt.
3. **Bag and walking away:** "Bag 0 / 300" closes the claw and opens Charms. Walking away closed the window at 19.5 studs (reach 16, checked every 0.5 s).
4. **Pulls:**
   - x1 shows the "You got" card (Rabbit's Foot) (`127-hh-pull1.jpg`).
   - x10 shows a 5x2 grid of "?" cards with Skip. Skip jumps to the full result, which stays up until Done. It held Rare+ (Lucky Horseshoe, Sunstone) (`127-hh-pull10-cards.jpg`, `127-hh-pull10-result.jpg`).
   - x100 shows the haul grouped with counts, including a Godly and two Legendaries. The gold burst fired (Burst colour 1,0.82,0.25, 1.17 s after the pull) (`127-hh-pull100.jpg`).
   - Minor: the top border of the haul's first row is clipped.
   - Done takes you back to the claw window while you're in reach.
5. **Charms window:**
   - 3 slots plus locked Floor 3/6/9.
   - Equipping Royal Banquet, Rabbit's Foot and Dragon's Hearth shows "Equipped: +8% coins, x1.08 luck, eggs 20% faster" and an "Equipped" ribbon on each card (`127-hh-charms-equipped.jpg`).
   - Unequipping Dragon's Hearth drops the totals to "+8% coins, x1.08 luck".
   - Fuse on Feed Bag x25 left 20 (bag 121→117, 500 coins).
   - Fuse all showed a 10-line plan with a 11.5K fee. I checked it by hand: 23 fuses × 500 = 11.5K. After it, the bag went 117→25, the counts match the plan, and the equipped charms were kept (`127-hh-fuseall-confirm.jpg`).
   - Minor: the ribbon covers the card's icon, and the "Others': On" button is clipped at the right edge of the controls row (the row scrolls sideways).
6. **Worn ring:**
   - Two worn charms circle behind the shoulders (`127-hh-worn-ring.jpg`).
   - "My charms: Off" clears the character's Charms attribute, so others stop seeing them. The ring disappears and the stats stay. Turning it On brings the ring back.
   - "Others': Off" toggles without touching your own ring. *Not covered:* I couldn't see another player's ring, because Studio solo has one client.
7. **Luck:**
   - Rabbit's Foot shows "Boosted: Rabbit's Foot" on the Basic card: Rare 0.864%, UR 0.195%, Epic 0.020%, Legendary 0.003% · 1 in 33,333. The total is 100.000% (`127-hh-odds-clover.jpg`).
   - **The x3 cap with Luck Boost wasn't testable.** Luck Boost has no grant path in this build (product id 0, no test action, no luck event), so only Odds.spec covers it.
   - *Note:* rounding the weights to whole numbers makes the small tiers jump: Legendary 2→3 weight is x1.5, Epic 18→20 is x1.11, against the advertised x1.08. The card shows what's rolled, but it overstates the charm on rare tiers.
8. **Test panel "charm":** "Cornucopia added to your charm bag." Bag 25→26 and the card appears.
9. **Phone 844x390:**
   - All 7 side-menu buttons fit, with Charms at y 341-384.
   - The claw window is 760x308 at y 70-378, both panes scroll, 0 TextFits failures, and the smallest text is 13.6 px (`127-hh-phone-claw.jpg`).
   - **The 10-pull reveal footer is cut off: FAIL (above).**

## #103 @ 9784504 (32 new Uncommons), merged onto main as 45d414b

**PASS, with one gap noted.** Local builds, desktop.
1. **Book:** the Uncommon tab reads 0/39 (7 old + 32 new). I scrolled every card: all 39 have a live ViewportFrame with parts (4-43), so none are blank or black. Unfound cards show proper silhouettes (`103-hh-book-uncommon.jpg`).
   - **TeacupPiglet** (a still copy, side and rear): a pink piglet in a white cup with pink hearts and a yellow rim. From the side the white loop handle is at the cup's back. From the rear it shows end-on as a white ring with a pink heart. It reads as a teacup (`103-hh-teacup-side.jpg`, `103-hh-teacup-rear.jpg`, in the plot `103-hh-teacup-plot.jpg`).
2. **Odds cards:**
   - Basic 92 / 7 / 0.8 / 0.18 / 0.018 / 0.002 sums to 100.000%. Its "See every creature" list sums to 100.000% with 7 Uncommon rows at 1.000% each: Gosling, Turtle, Radishling, Turnipling, Peapod, Carrotling, Cornling.
   - Meadow 67 / 31 / 1.7 / 0.28 / 0.017 / 0.003 sums to 100.000%. Its list has 29 Uncommon rows (25 new + Fox Kit, Hedgehog, Squirrel, Puppy) at 1.069% each (Yak Calf 1.068%), totalling 31%.
   - Moonlit card sums to 100.000%. *Gap:* I couldn't open the Moonlit per-creature list. A Moonlit egg stays at the stop only 0.98 s, too short to click "See every creature".
3. **Restricted** (local policy patch): the Basic fixed order lists all 7 Uncommons in turn: Gosling in 40 … Cornling in 46. Then Raccoon in 47, Ember Fox in 87, Dragonling in 299 and Phoenix in 2,503. The waits only go up (NEXT, 2, 3 … 46).
   - On this main-based build the restricted card is still the old full-length card. #126 replaces it.
4. **World**, TeacupPiglet, Carrotling, YakCalf and Pangolin:
   - Every MeshPart is textured, and the largest gap is 0.000.
   - While walking, the median bottom of the part boxes is 0.72-0.76 on a 0.70 floor. Box corners dip to 0.49-0.66 during leg swing; Pangolin's tail box is the lowest.
   - In 4 s they walked 3.5 / 0.6 (Carrotling hops, peak 1.46) / 3.4 / 3.6 studs.

## #126 @ effcae6 (11 px text floor), merged onto main locally as 3c45913

**FAIL by 0.6 px on the unrestricted phone card. Restricted passes.**

*Merge note:* effcae6 conflicts with current main in `ops/DECISIONS.md` (docs only). To build, I took the PR's side of that file locally. The PR needs a main merge before it can land.

Text is measured as TextBounds.Y, the same measure as 5341bf8's 5.6 px and main's 14.4 px.
- **Phone 844x392, restricted:**
  - The card is 224x157 at UIScale 0.80, screen y 225-383, so it's within ≤384.
  - The smallest text is 12.0 px (TextSize 15 × 0.8). 0 labels fail TextFits.
  - The rows scroll (canvas 267 in a 157 frame). Scrolled to the end, "See the whole order" sits at y 353-377 inside the rows (`126d-phone-restricted-card.jpg`).
  - Whole order: the window covers y 138-382, titled "Basic Egg: fixed order" with the header "How many of every 100000 eggs:". Rows: Gosling (3500) | NEXT, Turtle (3500) | in 2 eggs, Bunny (2359) | in 3 eggs … The right column is complete, 0 labels fail TextFits, the smallest text is 14.4 px and it scrolls (canvas 1194) (`126d-phone-restricted-whole-order.jpg`).
- **Desktop 1350x672, restricted:** 280x334 at y 198-532, against 280x310 at 5341bf8; it's taller only because the text is bigger. Smallest text 14.4 px, 0 TextFits failures, same contents (`126d-desktop-restricted-card.jpg`).
- **Phone 844x392, unrestricted: FAIL.**
  - The card is 224x157 at UIScale 0.80, screen y 225-383 (bottom passes). The rows scroll (canvas 171 in a 157 frame, so the last rows and "See every creature" scroll into view).
  - Every row label is **TextSize 14 → 10.4 px tall on screen**, below the 11 px floor (`126d-phone-unrestricted-card-FAIL.jpg`). "See every creature" is TextSize 15 → 12.0 px.
  - 14 × 0.8 = 11.2 nominal, but the rendered glyph box comes out at 10.4. Fix: TextSize 15 for the rows, as the restricted card already uses, or keep the scale at 0.85 or more.
- Stopped at this FAIL, so the unrestricted desktop card was not rechecked.

## #129 @ b0bb378 (12 new Epics), merged onto main as caf29b1

**PASS.** Local builds, desktop 1350x672.
1. **Book:** the Epic tab reads 0/15 (3 old + 12 new). All 12 new Epics (Kappa, Star Jelly, Crystal Golem, Gem Drake, Baby Kraken, Sea Serpent, Sand Serpent, Star Whale Calf, Hippocampus, Cloud Serpent, Hydra Hatchling, Abyss Jelly) are live draws with 6-17 parts. None are blank or black (`129-hh-book-epic.jpg`).
   - Odds lines: Abyss Jelly "Meadow Egg 1 in 11,111". The Moonlit ones read 1 in 4,348 or 1 in 4,545.
2. **Odds cards:**
   - Basic, Meadow and Moonlit each sum to 100.000%. Tier shares are unchanged; the new creatures split the existing tier share.
   - Meadow list: Abyss Jelly 0.009% · 1 in 11,111 next to Crystal Stag 0.008%, which adds up to the 0.017% Epic tier.
   - Moonlit list: 13 Epic rows (11 new + Dragonling + Moon Unicorn) at 0.022-0.023% each, totalling 0.290%. The list sums to 100.000%.
   - (I caught the Moonlit card on the belt this time; see the #103 note.)
3. **Restricted** (local policy patch): Meadow's fixed order has "Abyss Jelly (Epic): 9 in every 100000 → in 703 eggs". Moonlit's has all 11 new Epics, from Hydra Hatchling "23 in every 100000 → in 490 eggs" to Baby Kraken "22 … in 2839 eggs", with the waits only going up.
   - Note: Meadow and Moonlit Buy prompts stay disabled until the player can afford the egg. With 200 coins only the Basic card appears, so I added test coins first.
4. **World**, Star Jelly (hover), Crystal Golem (waddle) and Cloud Serpent (slither):
   - The colour meshes are textured.
   - The only untextured parts are the intended Neon `_glow` overlays: StarJelly heart and tail; Golem body, body2, eyes and crystals; Serpent body, tail and whiskers.
   - The "Ring" part is the Epic floor disc.
   - With the ring excluded, the largest gap is 0.000.
   - Star Jelly hovers at 0.71-0.84, with its tentacle tips on the ring (`129-hh-starjelly.jpg`).
   - Cloud Serpent sits at 0.71-0.81.
   - Crystal Golem's leg boxes dip to 0.47 mid-step, but at floor level the foot is planted on the ring, not sunk (`129-hh-golem-feet.jpg`).
   - All three move: 1.3 / 14.0 / 4.8 studs in 4 s.

## #127 @ 4c9ea8b (claw gate fixes), merged onto main locally as 7238772

**FAIL again on the 10-pull reveal at 844x390.** The footer is still cut off by the same 14 px (`127b-phone-pull10-FAIL.jpg`).

*Merge note:* 4c9ea8b conflicts with current main (c8b281b, after #104) in `ops/DECISIONS.md` (docs only). I took the PR's side locally to build.

The new ScreenInsets layout is in the build: the ClawReveal gui is CoreUISafeInsets, 844x332. But the stage is 359 px tall (y −13..346 inside the 332 px gui), so it spills 13 px above and 14 px below.
- On screen, Open Charms (160x44) and Done (120x44) sit at y 360-404 on a 390 px screen. Only 30 of their 44 px show.
- Likely cause: the tray is 260 px tall, i.e. cellH = 126, the maximum. That means `screenSize()` read about 390 px of height, not 332. `revealGui.AbsoluteSize` still holds the full-screen size in the same frame that `playNext` sets `Enabled = true` and calls `showFew`, before the safe-area insets apply.
- Expected with the insets: s.Y = 332 − 24 = 308 → cellH = (308 − 100 − 8) / 2 = 100 → stage 308. That fits, with 12 px clearance.
- Fix: wait a frame after enabling before measuring, re-layout on `AbsoluteSize` change, or compute from `ViewportSize − GuiService.TopbarInset`.

Stopped at this FAIL. The luckboost cap, small phone, badge, controls row and x100 border were not rechecked on this head.

## #130 @ 91fc317 (10 new Epics), merged onto main c8b281b as 14903d2

**PASS.** Local builds, desktop 1350x672. This main doesn't have #129 yet, so the Epic tab counts 3 + 10.
1. **Book:** Epic 0/13. All 10 new Epics (MushroomGnome, TrollCub, SaplingEnt, GingerbreadGolem, PetalSprite, FrostSprite, EmberImp, YetiCub, RimeDrakeling, BonsaiDragon) are live draws with 8-16 parts. None are black (`130-hh-book-epic.jpg`).
   - Odds lines: Moonlit 1 in 3,448; Yeti Cub Meadow 1 in 16,667; Gingerbread Golem Meadow 1 in 20,000.
2. **Odds cards:**
   - Basic, Meadow and Moonlit each sum to 100.000%.
   - Moonlit list: 10 Epic rows (8 new + Dragonling + Moon Unicorn) at 0.029% each. The list sums to 100.000%.
   - Meadow list: Crystal Stag 0.006%, Yeti Cub 0.006%, Gingerbread Golem 0.005%, which adds up to the 0.017% tier.
3. **Restricted:**
   - Meadow: Yeti Cub "6 in every 100000 → in 1402 eggs", Gingerbread Golem "5 … in 1869 eggs".
   - Moonlit: all 8 listed, from Troll Cub "29 … in 490 eggs" to Sapling Ent "in 1867 eggs".
   - The waits only go up.
4. **World**, PetalSprite (hover), YetiCub (waddle) and RimeDrakeling (trot):
   - Textured. The only untextured parts are the Neon `_glow` overlays: PetalSprite's flower and wings, YetiCub's snowball, RimeDrakeling's wings and spines.
   - The largest gap is 0.000.
   - PetalSprite's stem rests on its ring, bottom 0.71-0.81 (`130-hh-petalsprite.jpg`). YetiCub sits at 0.71-0.81.
   - RimeDrakeling's leg boxes dip to 0.45 mid-trot, but its feet are planted on the ring at floor level (`130-hh-rime-feet.jpg`).
   - They moved 5.6 / 0.1 / 7.7 studs in 4 s. YetiCub was idling in that window.

## #131 @ 673c56f (Book preload and refit, odds-list egg tabs), merged onto main c8b281b as 1f110f4

**PASS.** Local builds.
- **Book, fresh session (desktop):** the first open shows the Common tab, with all 18 visible card pictures (ImageLabels) already loaded at 0.00 s (`131-hh-book-first-open.jpg`).
- **Book refit:**
  - Resizing desktop → phone 844x392 with the Book open refits it to 760x352 at screen y 49-401. The title is fully visible at y 57-93.
  - The window's bottom 9 px sit under the screen edge. That's the same geometry as the fresh-phone open in #125, and the pages scroll (`131-hh-book-resized-phone.jpg`).
  - Resizing back to 1350x672 refits to 760x560 at y 85-645.
  - Studio can't rotate, so I used the resize as the stand-in.
- **Odds-list egg tabs, new 200-coin player at the belt (Meadow and Moonlit Buy prompts hidden):**
  - The Basic card's "See every creature" opens the list with tabs Basic / Meadow / Moonlit, cheapest first, each 109x40.
  - Each tab switches the title and the full list: Basic 45 rows, Meadow 62, Moonlit 11. Each sums to 100.000% (`131-hh-oddslist-tabs-desktop.jpg`, `131-hh-oddslist-moonlit-desktop.jpg`).
  - Same on phone 844x392: the window covers y 138-382, the tabs are 109x40, and all three sum to 100.000% (`131-hh-oddslist-moonlit-phone.jpg`).
  - *Note:* switching tabs keeps the previous scroll position. The Moonlit list opened scrolled to the bottom.
- **Restricted, per tab:** main's restricted card (before #126) has no list button, so I checked this on main + #131 + #126 @ 434b2bf merged locally (11c79db; CHANGELOG conflict only, local patch).
  - Each tab shows "<Egg>: fixed order" with "How many of every 100000 eggs:". Rows: Basic 45, Meadow 62, Moonlit 11. Each sums to exactly 100000.
  - The waits go NEXT, in 2 eggs, … and only increase (`131-hh-restricted-moonlit-tab.jpg`).
- *Left over from main, not introduced here:* "Dalmatian Pup (Common)" and "Siamese Kitten (Common)" are cut off with "…" in the Basic list's left column (161 px wide), and one Meadow name likewise. The row widths are unchanged by this PR (`131-hh-oddslist-truncated-names.jpg`).

## #126 @ 434b2bf (row TextSize 15), merged onto main ad8133f as 8156f82

**FAIL: the Legendary odds are cut off on the unrestricted phone card.**
- **Phone 844x392, unrestricted:**
  - The card is 224x157 at UIScale 0.80, screen y 225-383, so it's within ≤384. The rows scroll (canvas 171 in a 157 frame).
  - The smallest text is now 12.0 px (TextSize 15), which meets the 11 px floor.
  - **But the Legendary value label "0.002% · 1 in 50,000" no longer fits its 104x17 box.** It renders as **"0.002% · 1 in…"** (TextFits false), so the player can't read the rarest odds (`126e-phone-unrestricted-legendary-truncated-FAIL.jpg`).
  - Every other row fits. The longest values are 22 characters ("0.018% · 1 in 5,556" fits; "0.002% · 1 in 50,000" doesn't).
  - Fix: widen the value column (the name column has room: "Legendary" is short), drop the "· " separator on phones, or let the value wrap.
- Stopped at this FAIL. The unrestricted desktop card and the restricted phone glance were not done on this head. (Restricted 12.0 px at y 225-383 passed on effcae6, and the #131+#126 combined build showed restricted tabs working.)

## #127 @ fe40382 (reveal safe-area refit), merged onto main ad8133f as 6cd33fe

**PASS.** Local build.
- **Phone 844x390, 10-pull reveal:**
  - ClawReveal is CoreUISafeInsets, 844x332.
  - The stage is 308 px, screen y 70-378.
  - Open Charms 160x44 and Done 120x44 sit at y 334-378, **12 px above the edge** (`127c-phone-pull10.jpg`).
- **Refit on resize** (the stand-in for rotation; Studio can't rotate):
  - I resized 844x390 → small phone 702x378 with the reveal open.
  - The stage refit at UIScale 0.962 to y 70-366, and Done sits at y 324-366, 12 px clear. All 10 cards fit inside x 51-650 (`127c-smallphone-refit.jpg`).
- **Small phone 702x378, fresh 10-pull:** the stage is 308 at scale 1.0. **Skip** 120x44 at y 322-366 is 12 px clear, and Done / Open Charms are at the same spot after Skip (`127c-smallphone-skip.jpg`).
- **x100 haul (small phone):** the grid has 4 px top padding. The first card is 4 px below the scroll top with a 3 px stroke, so the first-row borders are fully visible (`127c-smallphone-x100.jpg`).
- **Charms window (small phone):**
  - The controls row is 646 px wide in a 646 px frame. "Show mine: On" and "See others: On" both fit (TextFits) and aren't clipped.
  - The "On" badge (30x18 at the top-left corner) sits clear of the 🍀 glyph (`127c-smallphone-charms-badge.jpg`).
  - Equipping Wishbone shows "Equipped: +8% coins, x1.11 luck".
- **Luck Boost cap:** test panel "luckboost" On ("Luck Boost odds on.") + Wishbone (x1.11). Every egg card reads "Boosted: Wishbone, Luck Boost" and sums to exactly 100.000%.
  - Basic: Rare 0.800→1.322 (x1.65), UR 0.180→0.347 (x1.93), Epic 0.018→0.039 (x2.17), Legendary 0.002→0.004 (x2.0). Each is ≤ base × boost × 1.11 (1.665 / 1.94 / 2.22 / 2.22) and ≤ x3.
  - Moonlit list (per creature): Owlet 12.667→16.333 (x1.29 after normalising), Axolotl 1.85→2.783 (x1.50), Epics 0.022→0.037-0.039 (≤x1.77), Phoenix 0.008→0.013, Nebula 0.002→0.003. All are ≤ the uncapped product.
  - *Note:* the x3 cap can't actually be reached with today's sources. The largest product is Luck Boost x2 × Star of Fortune x1.2 = x2.4, so on screen the cap shows only as "never above". Spec tests cover the cap itself.
- *Note (main, not this PR):* at 702x378 the main-branch odds card (without #126) runs below the screen, so "See every creature" can't be reached on a small phone. #126 fixes that.

## #126 @ 8dca9a9 (value box sized to its text), merged onto main ad8133f as 675ec02

**PASS.**
- **Phone 844x392, unrestricted:**
  - The card is 224x157 at UIScale 0.80, screen y 225-383, within ≤384.
  - **TextFits is true on every row.** The Legendary row reads "0.002% · 1 in 50,000" in full.
  - The smallest text is 12.0 px, and the rows scroll (canvas 171 in a 157 frame) (`126f-phone-unrestricted.jpg`).
- **Desktop 1350x672, unrestricted, fresh session:** 280x214 at y 258-472 at scale 1.0. Smallest text 14.4 px, nothing truncated, and the same six rows as main (92.000% · 1 in 1.1 … 0.002% · 1 in 50,000). Unchanged from main.
- **Phone, restricted (glance):** 224x157 at y 225-383, smallest text 12.0 px, nothing truncated, and the rows scroll (267 in a 157 frame).
- *Note, not a FAIL:* the card doesn't refit when the viewport grows mid-session. After a phone → desktop resize it stayed 224x157 at scale 0.8 on a 1350x672 screen. It's still readable and fits (`126f-desktop-after-resize-no-refit.jpg`). A fresh desktop session is correct. This matters for rotation; the Book got a refit in #131 and this card could use the same.

## #90 @ 0ffc7ce (thumbs for the live four), merged onto main ad8133f as 6a9acf4

**PASS.** Local build, desktop.
- **CreatureThumbs:** 114 entries, and FrostWolf, StormHawk, CrystalStag and MoonUnicorn are all present.
- **Book:** after a test-panel give, each of the four shows its coloured picture with a NEW badge.
  - Frost Wolf `rbxassetid://117071203284379` and Storm Hawk `…71546280985932` are on the Ultra Rare tab.
  - Crystal Stag `…84692928531479` and Moon Unicorn `…93137043299342` are on the Epic tab.
  - All four images report IsLoaded (`90-hh-book-ultrarare.jpg`, `90-hh-book-epic.jpg`).
  - *Note:* on the first open of the Epic tab, some of #129's live-draw silhouettes were briefly blank or partial while their meshes streamed in (`90-hh-book-epic-loading.jpg`). About 4 s later every card was fully drawn, and their ViewportFrames were fully populated (6-17 parts each).
- **World:**
  - All four have one texture on every colour MeshPart. The only untextured parts are the intended Neon `_glow` overlays: FrostWolf's legs and crest; StormHawk's tail and crest ×2; CrystalStag's body, legs, head, antlers and crystals; MoonUnicorn's body, legs and mane.
  - The largest gap is 0.000 on all four.
  - Bottom medians are 0.74-0.75 on a 0.70 floor. Leg-swing corners dip to 0.54-0.55 on StormHawk and MoonUnicorn.
  - They move: FrostWolf 5.4 studs in 12 s, StormHawk 4.2 in 4 s, CrystalStag 12.5 in 12 s, MoonUnicorn 3.1 in 4 s.
  - **FrostWolf crest glow:** a Neon 0.8x0.8x0.6 part, colour (0.81, 0.93, 1), shows as a white glow on its head (`90-hh-frostwolf.jpg`).
