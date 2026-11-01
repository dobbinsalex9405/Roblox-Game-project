# Hatchery Heist: intended behavior

Working title; check Roblox for name collisions before launch (M7).

Players run an egg-hatching base that pays coins every second, while rivals
sneak in to steal creatures. When a bug report and this spec disagree, the
spec wins until Alex says otherwise.

## Core loop

1. Buy an egg from the conveyor (coins, or Robux for the Premium Egg).
2. Place it in an incubator slot; it hatches after `hatchSeconds`
   (`config/eggs.luau`), counted from a saved start time, so it keeps going
   while the player is offline.
3. The hatched creature earns `coinsPerSecond` × mutation × rebirth bonus
   (× Double Coins pass) while placed on the base (`config/creatures.luau`,
   `config/economy.luau`).
4. Buy more incubator slots (`economy.incubators.slotCosts`).
5. Rebirth: reset coins and creatures for a permanent +25% income per rebirth;
   each rebirth costs `costGrowth` times the last.
6. Offline: earn `offline.rate` of normal income for at most `offline.maxSeconds`.

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
check on every hatch. Restricted players get a policy-approved alternative.

## Save data

Version 1 is in `src/shared/DataTemplate.luau`. Changes go through a migration;
nothing is ever removed.

## Status

- Done (M1): config with schemas and cross-file checks, save data v1, income
  and rebirth math, coin pack and shield refill grants, core wiring.
- Next (M2): conveyor, incubators and hatching, collecting, rebirth, first UI.
