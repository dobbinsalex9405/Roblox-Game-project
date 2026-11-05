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
