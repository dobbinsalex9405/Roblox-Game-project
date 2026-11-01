# Changelog

## Unreleased

- Feedback button in the top bar (shared core): players send a Bug, Idea or
  Other report with an optional fun rating. Reports carry this game's
  progress snapshot (rod, bait, bucket, pools, species caught and casts) to help reproduce bugs.
- First playable (M2): cast from four docks, a server-rolled bite, a
  touch-first reel minigame, keep or sell into a 12-slot bucket, 2 to 8 tide
  pools where creatures grow through five stages by the saved clock, feeding,
  selling at any stage, offline growth capped at 3 hours per absence with a
  welcome-back message, three rods, four baits and a bait shop that restocks
  every 10 minutes on the server clock, and journal records of every species
  caught.
- Playtest fixes: notices name rods, bait and creatures as players read them;
  a full bucket sells its least valuable catch instead of the new one; no
  recast while a line waits for a bite; a lost Rare or rarer fish says a
  better rod helps; the welcome-back message ignores a restock after a server
  hop; bait retuned so it always pays (Worm 6c, Krill 30c, Glow Bait 150c,
  Golden Lure 600c, with stronger rare multipliers).
- Pools panel: feed, sell and unlock pools from anywhere, like placing from
  the bucket, so tending pools no longer means walking back to the cove.
- 25 sea creatures in 5 rarities with sizes; value grows with size and stage.
- Exact odds on every dock's board and on the Cast prompt's card, from the
  same table the server rolls (bait and rod included).
- Anti-macro: one line at a time, a cast cooldown, distance to the dock, and a
  minimum human reel time checked on the server.
- Grey-box map built from code: a lagoon with an island shop, four docks with
  floats and odds boards, 8 coves with 10 pool spots each.
- Save data v1: coins, rod tier, bait, bucket, pools, journal, shop window,
  receipts, stats, firsts. New game, so no migration.
- Analytics: onboarding steps Joined, FirstCast, FirstCatch, FirstPlaced,
  FirstGrowth (once per player, ever), `Onboarding:FirstSale`, `Fish:Caught`,
  `Fish:Escaped`, `Fish:ReelTooFast`, `Pool:Sold`, Rod progression, and every
  coin change through the economy ledger.
