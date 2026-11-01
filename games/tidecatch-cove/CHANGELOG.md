# Changelog

## Unreleased

- First playable (M2): cast from four docks, a server-rolled bite, a
  touch-first reel minigame, keep or sell into a 12-slot bucket, 2 to 8 tide
  pools where creatures grow through five stages by the saved clock, feeding,
  selling at any stage, offline growth capped at 3 hours per absence with a
  welcome-back message, three rods, four baits and a bait shop that restocks
  every 10 minutes on the server clock, and journal records of every species
  caught.
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
