# Tidecatch Cove: intended behavior

Working title; check Roblox for name collisions before launch (M7). Game 2 of
Wave 1; it replaced Coral Cove (approved Nov 1, 2026). When a bug report and
this spec disagree, the spec wins until Alex says otherwise.

Players fish sea creatures from a shared lagoon, then raise them in their own
tide pools, where they keep growing while the player is away.

## Map (grey-box)

A lagoon in the middle with an island (spawn and the Bait & Tackle shop) and
four fishing docks, and a ring of 8 coves around it, one per player. The water
is a see-through slab players wade through. Everything is built from code
(`src/server/World.luau`, positions in `src/shared/Layout.luau`).

## Core loop

1. **Cast.** Stand on a dock and use its Cast prompt. The cast uses one of the
   picked bait (or none). Spots (`config/fishing.luau`):
   Shallows (any rod), Reef (Reef Rod or better), Kelp Forest (Storm Rod), and
   Tide Flats, which opens only at low tide (the tide cycle arrives in M4, so
   it stays closed until then).
2. **Bite.** After `biteSeconds` (times the rod's `biteTime`) the server rolls
   the catch from that spot's odds table for the picked bait, with the
   player's rod applied, and rolls its size. The player sees only the rarity.
3. **Reel.** Tap "!" within `hookSeconds` to set the hook, then hold to push
   the green zone right and let go to let it drift left, keeping the fish
   inside until the bar fills (`src/shared/Reel.luau`). One big hold target,
   built for touch. Rarer fish dart faster and fill slower; better rods have a
   wider zone.
4. **Keep or sell.** A catch goes into the bucket (`bucketSlots`), and the
   catch card offers Keep or Sell. If the bucket is full, the least valuable of
   the bucket and the new catch sells at once (a tie keeps the bucket), so a
   rare catch is never thrown away for small change; a notice names what sold.
5. **Pools.** Place a bucket creature in a free pool (2 to start, more for
   coins, +2 with the Extra Pool pass). It grows Tiny, Young, Grown, Large,
   Giant, one stage every `stageSeconds` for its rarity, and sells for more at
   each (`config/pools.luau`). Feeding adds a quarter stage at once, once every
   `feed.cooldownSeconds` per pool. Sell from the pool at any stage.
6. **Away.** Pools grow by the saved clock. On rejoin, time away counts up to
   `offline.maxSeconds`; a welcome-back message says how many creatures grew
   and whether the shop restocked. A restock alone is not news after an
   absence under 2 minutes (a server hop).
7. **Shop.** Rods (3 tiers, any higher tier can be bought straight away) and
   bait (4 kinds) for coins. Bait only ever shifts a catch toward rarer fish,
   and pays back about twice its price at Tiny prices on the spot it suits
   (the Golden Lure breaks even at Tiny and pays through grown Legendaries). Each bait has a
   `stock` per restock; the shop restocks every `restockSeconds` on the server
   clock, the same moment in every server.
8. **Journal.** Every species caught is recorded with its count and biggest
   size; the HUD shows how many of the 25 species the player has. Rewards per
   page come with M4.

## Odds

Every spot and bait has one odds table (weights out of 10,000), and the rod is
applied as an odds boost, so the odds board on each dock and the odds card at
the Cast prompt show exactly what the server rolls. Free casts need no odds
screen under the policy; every spot shows its odds anyway. Species not yet in
the player's journal show as "???" on free tables; a paid table always names
every outcome.

## Safety

- The server decides every catch, and checks rod, bait, distance to the dock,
  one line at a time (no recast until the cast ends, so no bait is burned)
  and a cast cooldown.
- A reel reported faster than `Reel.minSeconds` (a human reaction plus filling
  the bar without one miss) is a script: the fish is lost and
  `Fish:ReelTooFast` is logged.
- Coins are never sold for Robux, so casts are not paid random items. Bait
  marked `robux` (bait packs, M5) makes every cast with it a paid roll:
  policy-checked through `Odds.rollPaid`, refused for restricted players
  before the bait is used. If coin packs are ever added, every bait cast
  becomes paid.

## Money (M5, prices need Alex's approval)

Passes: Auto-reel, Extra Pool, Sell Multiplier (perks already honored for
Extra Pool and Sell Multiplier). Products: Growth Boost, Restock Skip, Bait
Packs (paid random: odds screen), Mystery Bait (paid random: odds screen and
policy check). Subscription: one rare bait a day. Private servers. All ids are
0 until created; Config.spec fails if one is set before its handler exists.

## Save data

Version 1 is in `src/shared/DataTemplate.luau`. Changes go through a migration;
nothing is ever removed.

## Status

- Done (M2): cast, bite, reel minigame, keep or sell, bucket, pools with five
  growth stages, feeding, selling, offline growth with a cap and a
  welcome-back message, rods, bait and the restocking shop, journal records,
  odds boards and card, grey-box map, phone-first HUD, onboarding analytics.
- Next (M3): first Staging publish and Studio session (lagoon layout, first
  playtest). Then M4: tide cycle (low-tide spot, storm odds, glow-tide
  mutations), Journal pages and rewards, Leaderboards ("biggest catch today"),
  and the phone test of the reel. M5: the shop (passes, products, odds
  screens for bait packs and mystery bait, subscription).
