# Hatchery Heist: intended behavior

Working title; check Roblox for name collisions before launch (M7).

Players run an egg-hatching base that pays coins every second, while rivals
sneak in to steal creatures. When a bug report and this spec disagree, the
spec wins until Alex says otherwise.

## Core loop

Eight bases sit in a ring around a shared yard; each player gets one.

1. **Conveyor.** Eggs ride along the front of the base on a fixed server-time
   schedule (`economy.conveyor`): one every `spawnSeconds`, crossing in
   `travelSeconds`, the kind picked by `weights`. Walk up to an egg and buy it
   with coins; it goes straight into the first free incubator. The odds card
   for that egg is on screen while the Buy prompt is, and the board above the
   belt lists every belt egg's odds. Buy stays off until the odds are known.
2. **Incubators.** 3 to start, more for coins (`economy.incubators.slotCosts`),
   +2 with the Extra Incubators pass. An egg hatches `hatchSeconds` after it
   was bought, by the saved clock, so it keeps going while the player is away.
3. **Hatch.** What an egg hatches is decided and paid for at purchase (a paid
   roll from the odds table, or the fixed order below) and revealed at hatch.
   The creature takes the first free pad (20 pads); when all are full, a
   better creature takes the weakest one's pad and the weaker one goes to
   storage (30 slots). When storage overflows, the weakest stored creature
   sells for `storage.sellSeconds` of its income.
4. **Coins.** Placed creatures earn `coinsPerSecond` × mutation × rebirth bonus
   (× Double Coins pass) into an uncollected pile. Step on the collect pad to
   bank it, or own Auto-Collect to bank it every `autoCollectSeconds`.
5. **Rebirth.** At the rebirth stand: costs `rebirth.baseCost`, each rebirth
   `costGrowth` times the last; resets coins, the pile and creatures (kept in
   the save's `rebirthArchive`) for +25% income per rebirth. Eggs in
   incubators and bought slots stay.
6. **Offline.** On rejoin, the pile gains `offline.rate` of normal income for
   at most `offline.maxSeconds`; a welcome-back message says how much and how
   many eggs finished hatching.

## Mounts (approved Nov 1, 2026)

Ride any creature you own from its pad. Its species' `mountSpeed` sets your
walk speed (16 on foot; rarer is faster). The ridden creature keeps earning,
is saved (`mountUid`) and comes back after a respawn or rejoin. The server
checks ride speed from M4 (Movement check).

## Raids (M4)

Server-checked at every step; limits in `config/raids.luau`.

1. Raider enters a rival base: refused while the base has a shield, during the
   owner's new-player protection, or while the raider is on cooldown for that owner.
2. The owner's alarm sounds and guard creatures patrol.
3. Raider picks up one creature: must be within `pickupReach` and carrying nothing.
4. While carrying, speed is capped at `carryWalkSpeed`; moving faster than
   `carrySpeedTolerance` × that drops the creature back home.
5. Touched by a guard, trap or the owner: the creature goes home. Reaches own
   base: the creature changes owner.

Only players online in the server can be raided. Permanent raid immunity is
never sold.

## Money

All prices need Alex's approval (M5). Product and pass ids stay 0 in
`config/monetization.luau` until created on Roblox; id 0 is never sold.

- Passes: Double Coins, Extra Incubators (+2 slots), Auto-Collect.
- Products: three coin packs, Shield Refill (adds `shieldSeconds`), Instant
  Hatch, Premium Egg, Luck Boost (15 minutes, multiplies Rare/Epic/Legendary
  weights on the listed eggs).
- Private servers.

**Every egg is a paid random item** (coins can be bought with Robux): odds
screen before purchase, odds update live during a Luck Boost, PolicyService
check on every purchase. Players for whom PolicyService restricts paid random
items get the fixed order instead: each egg hatches its outcomes in listed
order, and the odds card shows that list with the next creature marked, so
nothing they buy is random.

## Save data

Version 1 is in `src/shared/DataTemplate.luau`. Changes go through a migration;
nothing is ever removed.

## Status

- Done (M1): config with schemas and cross-file checks, save data v1, income
  and rebirth math, coin pack and shield refill grants, core wiring.
- Done (M2): conveyor, incubators, hatching, collecting, slots, rebirth,
  offline earnings, Auto-Collect, basic riding, grey-box bases built from code,
  minimal HUD, odds card and board, onboarding analytics.
- Next (M3): first Staging publish and the first Studio session (lay out the
  map, first playtest). Then M4 raids and defenses; M5 the shop (Premium Egg,
  Instant Hatch, Luck Boost, prices).
