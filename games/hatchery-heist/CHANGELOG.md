# Changelog

## Unreleased

- Raids and defenses (M4): steal one creature at a time from a rival base and
  carry it home at carry speed; the owner, the guard or a snare takes it back.
  Shield pylon (free, 90 s, 5-minute recharge), Snare and Slime traps, decoy
  eggs, one guard creature that patrols and chases, 5 minutes of new-player
  protection and a 2-minute cooldown per raided owner.
- Movement check from the shared core: speed hacks and teleports are pulled
  back, and drop anything carried. One module sets walk speed (walk, mount,
  carry, stun, slow).
- Dying or resetting while carrying sends the creature home.
- HUD: carrying banner with time left, red alarm while raiders are on your
  base. Prompts: Steal on rival bases; Make guard, Raise shield, Set snare or
  slime and Place decoy egg on your own.
- Save data v1 gains `guardUid` and `shieldReadyAt`. No live data yet, so no
  migration.
- Analytics: `Raid:Entered`, `Raid:PickedUp`, `Raid:Stolen`, `Raid:Defended`
  and the FirstRaidTried and FirstRaidDefended onboarding steps.
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
