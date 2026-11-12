# #185 at 4a43cdef (every egg hatches every creature): PASS on criteria 1, 2, 4, 5, 7 and 8; criterion 3 not checkable in-game; criterion 6 skipped (no toggle)

Build: `git checkout --detach 4a43cdef433d15009de2904018541e9505c2fd1e`, then `BUILD_ENVIRONMENT=staging tools/build.sh hatchery-heist`. Output reads "core started build=4a43cdef433d".
- I opened the local .rbxl in Studio, not the cloud place, and drove it only through the Studio MCP, in play-solo.
- **Screen sizes:** "Desktop" is the largest Studio viewport on this laptop, **1350×672**; a 1920×1080 viewport isn't possible on this screen. Phone is **844×392** (Studio window resized).
- **Config check:** all 4 eggs have pool "All", and the tier weights match the brief exactly, Premium included (650754 / 282722 / 64980 / 1444 / 100).

## 1. Coin egg odds cards: PASS

| Egg | Lines (percent and "1 in N" for each tier) | Sum | Godly tier | Phone fit |
|---|---|---|---|---|
| Basic | Common 92.03153% · 1 in 1.1, Uncommon 7.17024% · 1 in 13.9, Rare 0.69984% · 1 in 143, UR 0.09017% · 1 in 1,109, Epic 0.00780% · 1 in 12,821, Legendary 0.00022% · 1 in 454,545, Godly 0.00020% · **1 in 500,000** | 100.0000% | per creature **1 in 10,000,000** (list) | all 7 tiers on screen, min text 12.0 px |
| Meadow | 57.96870 / 37.03460 / 4.50036 / 0.45014 / 0.04500 / 0.00100 (1 in 100,000) / Godly 0.00020% · **1 in 500,000** | 100.0000% | per creature **1 in 10,000,000** | all on screen, min 12.8 px |
| Moonlit | 2.02980 (1 in 49.3) / 64.57484 / 29.99997 / 3.19997 / 0.19020 / 0.00422 (1 in 23,697) / Godly 0.00100% · 1 in 100,000 | 100.0000% | per creature 1 in 2,000,000 | all on screen, min 12.8 px |

- **Desktop text:** at least 16.8 px, 0 labels not fitting.
- **Phone layout:** the card is 224×158 at (16, 168), fully on screen. The 7 tiers fill it, and the "See every creature" button sits one short scroll below (row canvas 190 px in a 158 px window).
- **Images:**
  - Desktop: pr185-desk-card-basic.jpg, pr185-desk-card-meadow.jpg. My desktop Moonlit capture caught the Basic card instead (the card switches as the belt moves), so the desktop Moonlit card is checked by the readout above and the phone image.
  - Phone: pr185-phone-card-basic.jpg, pr185-phone-card-meadow.jpg, pr185-phone-card-moonlit.jpg.

## 2. The whole roster is reachable from every coin egg: PASS

- The card has no tappable tiers. The way in is "See every creature", which lists every creature with its tier.
- **Each of the Basic, Meadow and Moonlit lists has 530 rows summing to 100.0000%**, with 199 Common, 97 Uncommon, 81 Rare, 71 UR, 60 Epic, 2 Legendary and 20 Godly.
- **Spot checks (in all three lists):**
  - Chick (Common).
  - Kiwi and Petal Bunny (batch-13 Rares; Petal Bunny was Moonlit-only before).
  - Phoenix (Legendary).
  - Cosmic Whale and Nebula Serpent (Godly).
- **Images:** pr185-desk-list-meadow-godly.jpg (Godlies at 1 in 10,000,000), pr185-phone-list-basic.jpg.
- **NOTE, pre-existing (no client code in this PR):** the card is rebuilt each time a passing belt egg's prompt shows, about twice a second. So a single click on "See every creature" can land on a button that has just been replaced and do nothing. It took 2 to 4 clicks to open.

## 3. Premium Egg card: NOT CHECKABLE IN-GAME (config PASS)

- The Premium Egg product has id 0 on Staging, and it is not in the shop catalog (the Robux tab shows only the coin packs, the shield and the passes). So there is no Premium card to open.
- In config it has exactly 5 tiers: Rare, UR, Epic, Legendary and Godly, with no Common or Uncommon.
- **NOTE:** its product description still says "a chance at a Phoenix or the Godly Golden Goose"; it now rolls any Godly.

## 4. 25 hatches: PASS

| # | Egg | Creature | Tier (config) | Reveal |
|---|---|---|---|---|
| 1-10 | Basic | Cornling, Bookworm, GardenSpider, Hare, Marmoset, PineMarten, Cardinal, ZebraFinch, SeaUrchin, Kookaburra | U, C, C, C, C, C, C, C, C, U | matched all 10 |
| 11-20 | Meadow | Carrotling, PugPup, Jerboa, SpikyDuckling, Aphid, Cardinal, Kingfisher, AnteaterPup, ZebraPiglet, Lionfish | U, C, U, C, C, C, C, U, U, U | matched all 10 |
| 21-25 | Moonlit | ArcticFoxKit, SlowLoris, GiraffeCalf, DandelionPuff, MummyHamster | U, U, R, U, R | matched all 5 |

- Every hatch added exactly 1 creature. The end total is 25 (8 on pads + 17 in the inventory).
- **Output:** 0 server errors.
- The single client error line ("OddsList is not a valid member…", stack "AssistantCommand") came from one of my own Studio MCP diagnostic scripts, not the game.

## 5. Book: PASS

The egg named on each tier's cards:

| Tier | Egg named on every card | Image |
|---|---|---|
| Common | Basic Egg · 1 in 216 | pr185-book-common.jpg |
| Uncommon | Moonlit Egg · 1 in 150 | pr185-book-uncommon.jpg |
| Rare | Moonlit Egg · 1 in 270 | pr185-book-rare.jpg |
| Ultra Rare | Moonlit Egg · 1 in 2,219 | – |
| Epic | Moonlit Egg · 1 in 31,546 | pr185-book-epic.jpg |
| Legendary | Moonlit Egg · 1 in 47,393 | – |
| Godly | Moonlit Egg · 1 in 2,000,000 | pr185-book-godly.jpg |

- **0 Book labels name the Premium Egg.**
- The Book reads "Found 24/530" after the 25 hatches (Cardinal hatched twice).

## 6. Restricted (paid-random-items off) path: SKIPPED

The Studio test panel has no PolicyService or restricted toggle; it offers currency, passes, products, "Give a creature" and save reset only.

## 7. Panels: PASS

- **Desktop, first person:** Book, Creatures, Shop and Feedback each opened, then closed with their X. For all 4 the cursor was freed, the panel closed and the mouse re-locked.
- **Phone:** the "every creature" list closes with its **X**, and also with a **tap on the backdrop**, which I checked after reopening it.

## 8. Standing: PASS

- **Walkers:** a mid-stride Cardinal and a Pine Marten have their legs under their bodies (pr185-stride-cardinal-pinemarten.jpg).
- **Tower signs:** from the yard, "1. Cozy Studio x1.00" and "Floor 2: 20K coins" read whole (pr185-tower-signs-yard.jpg; desktop, with no GOAL banner after the hatches).

**Output tail (server).**
- [profilestore]: Roblox API services unavailable - data will not be saved
- [Stores] DataStores unavailable … store=ErrorQueue
- [Stores] DataStores unavailable … store=Feedback
- [TestPanel] Studio test panel is on
- [CoreServer] core started build=4a43cdef433d game=hatchery-heist studio=true
- [CoreServer] client error userId=… (my MCP script's error, forwarded)
- [ErrorReporter] error queue write failed; batch dropped errors=1 (Studio has no DataStores)
- 0 errors.
