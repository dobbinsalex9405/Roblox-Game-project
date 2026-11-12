# #123 at 2d78545a (economy retune): PASS on the numbers; 2 pre-existing visibility findings and 2 wording notes for the verifier

Build: `git checkout --detach 2d78545a56ad25faf4f4dacfae85e391c30796e3`, then `BUILD_ENVIRONMENT=staging tools/build.sh hatchery-heist`. Output reads "core started build=2d78545a56ad".
- I opened the local .rbxl in Studio, not the cloud place.
- I drove it only through the Studio MCP, in play-solo.
- This PR changes config only (creatures, economy, eggs), plus docs, tests and tools. It changes no game code.

## Row 1: floor prices on a fresh save: PASS on values; FINDING on visibility (pre-existing)

| Floor | Sign text read in-world | Tower window | Coins paid | Config |
|---|---|---|---|---|
| 2 | "Floor 2: 20K coins" | Build 20K coins | 20,000 | 20,000 |
| 3 | "Floor 3: 100K coins" | 100K coins | 100,000 | 100,000 |
| 4 | "Floor 4: 500K coins" | 500K coins | 500,000 | 500,000 |
| 5 | "Floor 5: 2M coins" | 2M coins | 2,000,000 | 2,000,000 |
| 6 | "Floor 6: 8M coins" | 8M coins | 8,000,000 | 8,000,000 |
| 7 | "Floor 7: 25M coins" | 25M coins | 25,000,000 | 25,000,000 |
| 8 | "Floor 8: 75M coins" | 75M coins | 75,000,000 | 75,000,000 |
| 9 | "Floor 9: 190M coins" | 190M coins | 190,000,000 | 190,000,000 |
| 10 | "Floor 10: 475M coins" | 475M coins | 475,000,000 | 475,000,000 |

- Every price matches config, and every Tower-window label fits (pr123-tower-window-prices.jpg).
- **FINDING (pre-existing, not from #123):** a player cannot see the in-world locked-floor sign.
  - It is a billboard 2 studs above the next floor's ghost deck (y about 13.8 for floor 2), which is inside the roof shell that #175 added.
  - It is hidden from outside, even from high up, and from inside the storey below (pr123-floor2-sign-hidden-outside.jpg, -inside.jpg).
  - So I read its text from the instance. #123 does not touch World.luau. The Tower window is where players see the prices.

## Row 2: egg belt: PASS on values; NOTE on wording

- **Signs:** the belt Buy prompts read "Meadow Egg: 1.5K coins" and "Moonlit Egg: 20K coins", and the odds cards read "1.5K coins" and "20K coins".
  - These are the game's short number format, not "1,500" / "20,000". NOTE on the brief's wording.
- **Meadow egg:** bought for exactly **1,500** coins. Its Hatch prompt became ready **30 s** after purchase (readyAt − startedAt = 30, wall clock 30 s), and it hatched a GibbonBaby.
- **Moonlit egg:** bought for exactly **20,000** coins, with a 120 s hatch.

## Row 3: odds: PASS; NOTE on the brief's wording

- **Cards:** each totals 100.0000%.
  - Basic: 91.9947 / 7.2048 / 0.7005 / 0.0900 / 0.0080 / 0.0020.
  - Meadow: 58.0224 / 36.9818 / 4.4960 / 0.4498 / 0.0450 / 0.0050.
  - Moonlit: 66.60012 / 30.00000 / 3.19986 / 0.19008 / 0.00899 / Godly "0.00095% · 1 in 105,263".
- **Moonlit "See every creature":** 158 rows summing to 100.0000%. All **19 Godly rows read "0.00005% · 1 in 2,000,000"**, whole, with 0 labels not fitting.
  - Desktop 1350×672: pr123-moonlit-godly-desktop.jpg.
  - Phone 844×392 (Studio viewport resized): Godly text 14.4 px, pr123-moonlit-godly-phone.jpg.
- **The Moonlit card at phone size:** all 14 labels fit at 13.6 px (pr123-card-moonlit-phone.jpg).
- **NOTE:** Godly creatures exist only in the Moonlit Egg (and the Robux Premium Egg). Basic and Meadow have no Godly tier in config, so "1 in 2,000,000 on every egg" applies to every Godly in the Moonlit list, not to every egg. The Meadow list has 261 rows, 100.0000%, and 0 Godly rows.

## Row 4: rebirth: PASS; FINDING (pre-existing)

- The rebirth stand reads **"Rebirth: 50M coins"** (pr123-rebirth-front.jpg).
- **FINDING (pre-existing):** from the side the tower wall cuts it to "Rebirth: 50M coi" (pr123-rebirth-side-cut.jpg). The label sits beside the #175 front/side wall; the same kind of fix as the #179 plaques would apply.

## Row 5: income: PASS

| Creature | Pad label | Was on main | HUD change on floor 10 |
|---|---|---|---|
| Moon Unicorn (Epic) | "260/s" | 200 | +1,589/s |
| Phoenix (Legendary) | "575/s" | 400 | +3,570/s |

Each change equals base × 3.05 (floor 10 when built) × 2 (the Studio test player owns Double Coins), plus a small Book bonus. The HUD went +61/s → +1.65K/s → +5.22K/s.

## Row 6: sanity: PASS

- **10 hatches with the tower full:** all 80 pad spots were full. 10 Basic eggs hatched 0.35 s apart, and **all 10 went to the inventory** (126 → 136).
  - Hatched: AlleyCat, PygmyGoat, Foal, SphynxKitten, Gerbil, Dove, HighlandCalf, Cockatoo, CorgiPup, GreyhoundPup.
  - There were 10 "Your tower is full: <name> went to your inventory. Open Creatures to place it." notices, and 0 Sell lines on the server.
- Feedback button visible.
- 0 script errors on the client and the server.

Raw numbers: output-log.txt.
