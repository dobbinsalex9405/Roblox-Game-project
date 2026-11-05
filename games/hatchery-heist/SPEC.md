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

## Creatures and rarity (Alex, Nov 5 2026)

33 species in seven tiers: **Common** (10), **Uncommon** (7), **Rare** (5),
**Ultra Rare** (4), **Epic** (3), **Legendary** (2) and **Godly** (2). The
lower the tier, the bigger the selection and the smaller the creature; the
higher, the bigger, more detailed, more animated and more glowing
(`src/shared/CreatureLooks.luau`):

- Common: about 2 studs; bobs and blinks.
- Uncommon: turns its head, wags its tail.
- Rare: flicks its ears, flaps its wings.
- Ultra Rare: glowing (Neon) markings, a soft light and sparkles.
- Epic: about 5 studs, standing in a glowing rarity ring.
- Legendary: about 9 studs, hovering in a bright aura, the most detailed
  models in the game (Phoenix, Thunder Griffin).
- Godly: about 11 studs, glowing cubes orbit it and its ring cycles through
  the rainbow (Golden Goose, Nebula Serpent).

Every creature is a voxel model made in `tools/art` (Python, rendered for
review with Blender) and exported to `src/shared/VoxelArt.luau`. The server
places an invisible stand-in part for each creature it shows (on a pad,
ridden, guarding, carried, decoy) with a `CreatureLook` attribute; the
client's `CreatureView` builds and animates the model on it. A ridden
creature is drawn at most `Layout.MOUNT_MAX` studs tall, a carried one at
most `Layout.CARRY_MAX`.

Odds tables may total more than 10,000 (`total` in `config/eggs.luau`): the
eggs total 100,000, so 1 = 0.001% (1 in 100,000). The odds card shows each
row as a percentage and as "1 in N". The rarest belt hatch is a Godly at
1 in 50,000 from the Moonlit Egg.

| Egg | Price | Belt share | Best odds |
| --- | ---: | ---: | --- |
| Basic | 50 coins | 70% | Phoenix 1 in 50,000 |
| Meadow | 2,500 coins | 25% | Thunder Griffin 1 in 33,333 |
| Moonlit | 40,000 coins | 5% | Nebula Serpent 1 in 50,000 |
| Premium | Robux (not on sale yet) | | Golden Goose 1 in 10,000 |

## Mounts (approved Nov 1, 2026)

Ride any creature you own from its pad. Its species' `mountSpeed` sets your
walk speed (16 on foot; rarer is faster). The ridden creature keeps earning,
is saved (`mountUid`) and comes back after a respawn or rejoin. The server
checks ride speed with the movement check (see Raids).

## Raids and defenses (M4)

Server-checked at every step; limits in `config/raids.luau`. The server
measures every distance from the characters' positions; the client only asks.

1. **Entering a rival base** is refused (the raider is pushed back out) while
   the base has a shield, during the owner's first 5 minutes of play
   (new-player protection, once ever), or for 2 minutes after the raider last
   raided that owner. The owner gets a notice and a red alarm banner while
   raiders are on their base.
2. **Picking up** one creature at a time from a pad within `pickupReach`. The
   ridden creature and the guard cannot be taken. The creature stays in the
   owner's save while carried; only a delivery moves it.
3. **Carrying** caps speed at `carryWalkSpeed` on foot, or the mount's speed ×
   `carryMountFactor`, so the owner on a fast mount can catch up. The raider
   sees a banner with the time left (`maxCarrySeconds`).
4. **The creature goes home** if the owner or the guard reaches the raider, a
   snare fires, the raider takes too long, moves impossibly fast, dies or resets,
   leaves the game, or the owner leaves. **Reaching their own base** gives the
   raider the creature (raids won / lost are counted).
5. **Movement check** (core `Movement`): every player's position is sampled 4
   times a second against the speed the server allows (walk, mount, carry,
   trap effects) with 35% tolerance and a 2-second burst budget for lag. A
   speed hack or teleport is pulled back to the last good spot and drops a
   carried creature.

Defenses, bought and placed on the owner's own base:

- **Shield**: free at the base pylon, 90 s, recharges 5 minutes after it ends.
  Raiders already carrying may leave; everyone else is pushed out. A Shield
  Refill (Robux, M5) adds `shieldSeconds`. Never permanent.
- **Traps** on 4 trap spots, for coins: Snare (stuns and returns the creature)
  and Slime (slows to half). Each fires once on a raider, then re-arms. Every
  trap spot looks the same to raiders; only the owner sees which is which.
- **Decoy eggs** on 3 spots, for coins: look like a creature to raiders;
  picking one up stuns the raider, alerts the owner and uses it up.
- **One guard**: any creature on a pad can guard (not while ridden). It chases
  raiders it can see on the base at a share of its mount speed and takes the
  creature back on contact.

Only players online in the server can be raided. Permanent raid immunity is
never sold.

## First session and look

- **Welcome screen** on a brand-new save's first join: what the game is and
  four steps (buy eggs, hatch, earn and collect, raid and defend). The
  **Guide** button in the side menu (right edge) reopens it any time.
- **Goal line** under the coin bar, with a beam and a bouncing arrow to the
  target: buy an egg, wait for it and hatch it, collect, then save up for and
  unlock the 4th incubator. It goes away after that (`src/shared/Guide.luau`).
- **Look and sound** from `config/atmosphere.luau`: sunny afternoon light,
  haze, clouds, bloom and sun rays; a sandy yard with the Golden Nest in the
  middle; low fences and flower beds on each base; trees and a ring of hills.
  Background music from Roblox's licensed library, with a Music on/off button
  in the side menu.

## Money

All prices need Alex's approval (M5). Product and pass ids stay 0 in
`config/monetization.luau` until created on Roblox; id 0 is never sold.

- The shop opens on its **Coins** tab (next incubator, free shield, traps,
  decoy egg, belt eggs); Robux items are the second tab.
- Passes: Double Coins, Extra Incubators (+2 slots), Auto-Collect.
- Products: three coin packs, Shield Refill (adds `shieldSeconds`), Instant
  Hatch, Premium Egg, Luck Boost (15 minutes, multiplies Rare and better
  weights on the listed eggs; the boosted table still totals exactly 100%).
- Private servers.

**Every egg is a paid random item** (coins can be bought with Robux): odds
screen before purchase, odds update live during a Luck Boost, PolicyService
check on every purchase. Players for whom PolicyService restricts paid random
items get the fixed order instead: each egg hatches a fixed repeating cycle
in which every outcome comes exactly as often as its odds (a Basic Egg cycle
is 50,000 eggs, with one Phoenix in it). The odds card
shows the next creature and how many eggs until each other one, so nothing
they buy is random and they get no more and no fewer rare creatures than
anyone else.

## Save data

Version 1 is in `src/shared/DataTemplate.luau`. Changes go through a migration;
nothing is ever removed.

## Status

- Done (M1): config with schemas and cross-file checks, save data v1, income
  and rebirth math, coin pack and shield refill grants, core wiring.
- Done (M2): conveyor, incubators, hatching, collecting, slots, rebirth,
  offline earnings, Auto-Collect, basic riding, grey-box bases built from code,
  minimal HUD, odds card and board, onboarding analytics.
- Done (M4): raids, carrying, delivery, the movement check, shield, traps,
  decoy eggs, the guard, new-player protection, raid banners and prompts.
- Next (M3, waiting on Alex's setup): first Staging publish and the first
  Studio session (lay out the map, first playtest, tune raid numbers). Then M5
  the shop (Premium Egg, Instant Hatch, Luck Boost, prices).

## Update backlog

Candidate updates for the weekly loop (`ops/UPDATE_LOOP.md`), grouped by
focus. A brief takes the top item that fits the week's focus; the loop owner
adds new ones from playtests, feedback ideas and what worked elsewhere.

- **fix**: the conveyor marks an egg bought before the server answers, so a
  refused buy leaves it invisible for that player; show it again on refusal.
- **onboarding**: funnel events for FirstCollect, FirstSlot and FirstRebirth
  (the funnel ends at FirstRide, about 15 s in), so D1 problems can be placed.
- **onboarding**: say "eggs are ready: press Hatch" on the welcome-back
  message; eggs finished while away earn nothing until hatched.
- **depth**: rebirth takes all leftover coins; keep the surplus or warn first.
  Slots 10 to 12 cost more than the first rebirths: re-space the slot curve.
- **depth**: batch the "Storage is full" notices (14 in 5 minutes) into one.
- **return**: show the offline earnings as a reward moment with the number,
  not a passing notice.
- **monetization**: list the Premium Egg with its odds (M5, paid random:
  odds screen and PolicyService check); Instant Hatch and Luck Boost.
- **social**: raids and visits already exist (M4); add a raid leaderboard and
  a reward for visiting a friend's base.
- **content**: new egg tier and creatures; a timed event egg.
