# Changelog

## Unreleased

- First playable (M2): an egg conveyor per base on a shared server-time
  schedule, incubators with saved hatch times, hatching onto 20 creature pads
  with storage, coins per second into an uncollected pile, the collect pad,
  incubator slots for coins, rebirth, offline earnings with a welcome-back
  message, Auto-Collect pass support and basic riding.
- Grey-box map built from code: 8 bases around a shared yard, each with a
  belt, 14 incubators, 20 pads, a collect pad, a rebirth stand, an odds board
  and the owner's name.
- Minimal HUD: coins, income, the uncollected pile, rebirths, Get off button,
  notices, hatch reveals and the odds card shown before every egg purchase.
- Save data v1 gains `pendingCoins`, `lastIncomeAt`, `eggsBought`, `nextUid`,
  `mountUid`, `decoys`, `rebirthArchive` and `firsts`; incubators record
  `readyAt` and the outcome paid for. No live data yet, so no migration.
- Analytics: onboarding steps Joined, FirstEggBought, FirstHatch, FirstRide
  (once per player, ever), `Egg:Hatched`, Rebirth progression, and every coin
  change through the economy ledger.
- Project scaffold on the shared core: config files with schemas, save data v1,
  creature income and rebirth math, coin pack and shield refill products
  (not yet created on Roblox), server and client start-up.
