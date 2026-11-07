# Hatchery Heist: intended behavior

Working title; check Roblox for name collisions before launch (M7).

Players run an egg-hatching base that pays coins every second, while rivals
sneak in to steal creatures. When a bug report and this spec disagree, the
spec wins until Alex says otherwise.

## Core loop

Eight bases sit in a ring around a shared yard; each player gets one.

1. **Egg Market.** One round belt in the middle of the map, around the
   Golden Nest, shared by everyone (`economy.conveyor`, `server/Market`,
   `client/ConveyorView`): two lanes turning opposite ways, a new egg every
   `spawnSeconds` taking turns between them, once round in `travelSeconds`,
   the kind picked by `weights`. Each egg rides its own pedestal, bobbing and
   turning. Walk up to an egg and buy it with coins; it goes straight into
   the first free incubator. Whoever buys an egg first gets it: the server
   refuses the rest ("Someone else got that egg first.") and every player
   sees it leave its pedestal. The server sells only within `buyReach` of
   the egg. The odds card for that egg is on screen while the Buy prompt is,
   and a raised sign beside each of the eight stops shows a belt egg's
   name, price and its two rarest tiers as "1 in N", one egg at a time
   (`conveyor.signSeconds`; `Geometry.MARKET_SIGN`; the Golden Nest stays
   clear). The card's "See every creature" button lists each creature's
   exact chance. Buy stays off until the odds are known.
2. **Incubators.** 3 to start, more for coins (`economy.incubators.slotCosts`),
   +2 with the Extra Incubators pass. An egg hatches `hatchSeconds` after it
   was bought, by the saved clock, so it keeps going while the player is away.
3. **Hatch.** What an egg hatches is decided and paid for at purchase (a paid
   roll from the odds table, or the fixed order below) and revealed at hatch.
   The creature goes to the highest owned floor of the tower with room for
   it, otherwise to the inventory (150 slots, `storage.slots`). When the
   inventory overflows, the weakest stored creature sells for
   `storage.sellSeconds` of its income. Only creatures on a floor earn.
4. **Coins.** Placed creatures earn `coinsPerSecond` × mutation × rebirth bonus
   (× Double Coins pass) into an uncollected pile. Step on the collect pad to
   bank it, or own Auto-Collect to bank it every `autoCollectSeconds`.
5. **Rebirth.** At the rebirth stand: costs `rebirth.baseCost`, each rebirth
   `costGrowth` times the last; resets coins, the pile and creatures (kept in
   the save's `rebirthArchive`) for +25% income per rebirth. Eggs in
   incubators, bought slots, tower floors and floor upgrades stay.
6. **Offline.** On rejoin, the pile gains `offline.rate` of normal income for
   at most `offline.maxSeconds`; a welcome-back message says how much and how
   many eggs finished hatching.

## The tower (Alex, Nov 5 2026)

Each base is a cozy apartment-style tower of 10 floors (`economy.tower`,
`Geometry`, `Tower`); the farm is only the centrepiece in the middle of the
map (Alex, Nov 5). Floors: 1 Cozy Studio, 2 Book Nook, 3 Plant Sunroom,
4 Bakery Kitchen, 5 Games Lounge, 6 Winter Cabin, 7 Art Studio, 8 Rooftop
Garden, 9 Starlit Observatory, 10 Golden Sky Penthouse.
Floor 1 is free; each next floor costs `floorPrices` (25K, 75K, 225K, 675K,
2M, 6M, 18M, 55M, 165M) and must be built in order. A floor has 8 spots in a
4 by 2 grid. A creature takes 1 spot up to Ultra Rare, 2 for Epic and 3 for
Legendary and Godly (`slotsByRarity`), side by side in one row.

- **Multiplier.** Creatures on floor 1 earn x1. Floor f from 2 earns
  1 + `floorBonus` × (f − 2) + `startBonus`, plus `upgradeBonus` per upgrade,
  so a new floor starts just above the floor below at full upgrades. Fully
  upgraded, floor f earns 1 + 0.25 × (f − 1): x1.25 on floor 2 up to x3.25
  on floor 10.
- **Upgrades.** 4 per floor from floor 2, bought in order: Cozy spots, Toys,
  Lighting, Food and water, at 20/35/50/75% of that floor's price
  (`upgradeShares`). Each shows a prop on the floor.
- **Placing.** A new creature goes to the highest floor with room, otherwise
  to the inventory; nothing is swapped out. "Your Creatures" (🐾 Pets) moves
  any creature to a floor or back to the inventory; Place best fills the
  tower from the top floor down by income per spot, leaving the ridden
  creature and the guard where they are.
- **Getting up.** An elevator in one corner (stand at a stop, pick an owned
  floor; the server checks you are at the elevator and own the floor) and a
  ladder on the opposite side. Raiders climb the ladder: a steal is refused
  unless the raider stands on that creature's floor.
- **Wandering** (`shared/Walk`, `atmosphere.wander`): each placed creature
  walks around its own spots on a schedule from its uid and the server
  clock, so every player sees the same thing and creatures never collide.
  Gaits per species (CreatureMeshes `gait`): trot, waddle, hop, scuttle,
  slither, hover. Only the client moves them; the server, raids and income
  use the pad. Every floor of a nearby tower shows: your own tower's
  creatures within `cullStuds` (180), other players' within `cullOtherStuds`
  (100), which only move within `animateOtherStuds` (60).
- **Old saves** (before the tower) are placed best first once on join, with
  the mount and the guard cleared; every join then tidies the save so no two
  creatures overlap and none sits on a floor the player doesn't own.

## Creatures and rarity (Alex, Nov 5 2026)

33 species in seven tiers: **Common** (10), **Uncommon** (7), **Rare** (5),
**Ultra Rare** (4), **Epic** (3), **Legendary** (2) and **Godly** (2). The
lower the tier, the bigger the selection and the smaller the creature; the
higher, the bigger, more detailed, more animated and more glowing
(`src/shared/CreatureLooks.luau`):

- Common: 2 studs; bobs and blinks.
- Uncommon: turns its head, wags its tail.
- Rare: flicks its ears, flaps its wings.
- Ultra Rare: glowing (Neon) markings, a soft light and sparkles.
- Epic: 3 studs, standing in a glowing rarity ring.
- Legendary: 3.4 studs, hovering in a soft aura, the most detailed
  models in the game (Phoenix, Thunder Griffin).
- Godly: 3.8 studs, glowing cubes orbit it and its ring cycles through
  the rainbow (Golden Goose, Nebula Serpent).

Sizes (`Layout.raritySize`, Uncommon 2.2, Rare 2.4, Ultra Rare 2.7) rise only
a little with rarity (Alex, Nov 5): rarer creatures will take more room on a
floor instead. The client draws a creature's whole art exactly as tall as the
server's stand-in.

Every creature is a voxel model made in `tools/art` (Python, rendered for
review with Blender) and exported to `src/shared/VoxelArt.luau`. The server
places an invisible stand-in part for each creature it shows (on a pad,
ridden, guarding, carried, decoy) with a `CreatureLook` attribute; the
client's `CreatureView` builds and animates the model on it. A ridden
creature is drawn one stud taller than on its pad, at most `Layout.MOUNT_MAX`
studs, a carried one at most `Layout.CARRY_MAX`.

**Eggs roll a tier, then a creature** (Alex, Nov 5). Each egg in
`config/eggs.luau` has a pool and a whole weight per tier, out of 100,000
(1 = 0.001%). Each creature lists the pools it hatches from
(`config/creatures.luau`) and may set an in-tier `weight` (1 by default).
`Eggs.expand` splits each tier's weight between its creatures, largest
remainder first, so every tier's chance is exact and adding a creature only
splits its own tier. The odds card shows one line per tier; the
"See every creature" list shows each creature as a percentage and as
"1 in N". The rarest belt hatch is a Godly at 1 in 50,000 from the Moonlit
Egg. Each creature also has an optional `element`, unused until elements
roll out with a much larger roster.

| Egg | Price | Market share | Best odds |
| --- | ---: | ---: | --- |
| Basic | 50 coins | 55% | Phoenix 1 in 50,000 |
| Meadow | 2,500 coins | 30% | Thunder Griffin 1 in 33,333 |
| Moonlit | 15,000 coins | 15% | Nebula Serpent 1 in 50,000 |
| Premium | Robux (not on sale yet) | | Golden Goose 1 in 10,000 |

## Mounts (approved Nov 1, 2026)

Ride any creature you own from its floor. Its species' `mountSpeed` sets your
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
- **One guard**: any creature on a floor can guard (not while ridden). It chases
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
  Each base's floor is a low 0.3-stud deck above the grass (`Layout.PLOT_Y`
  lowers the whole base; the server refuses to start if a floor is higher).
  Background music from Roblox's licensed library, with a Music on/off button
  in the side menu. It never starts or stops abruptly: it rises from silence
  over 4 s once the player has spawned, each track crossfades into the next,
  and the button fades it (`atmosphere.music`).
- **Hatch reveal** (`src/client/HatchReveal.luau`): every hatch plays on
  screen. The egg wobbles, cracks, and the creature turns under its rarity,
  name, income and the player's exact chance (same numbers as the odds card).
  It grows with rarity (`CreatureLooks`: wobble, rays, confetti, shake,
  hold). Tap skips ahead; holding skips every waiting reveal (a notice lists
  them); waiting Commons and Uncommons already in the book share one reveal.
- **Hatchery Book** (side menu): one tab per tier ("Common 3/30"), every
  species on a card; owned ones in colour, the rest as "???" silhouettes,
  each with its best egg and exact chance. Only cards on screen hold a 3D
  model, so a tab of hundreds stays light. The income bonus is capped: a full
  book is `economy.book.maxBonus` (+25%) whatever the roster, each tier owns
  `tierShare` of it, split evenly across its creatures. Cards found since the
  book was last opened say NEW (red dot on their tab, a count on the menu
  button). Kept in `data.found` and `data.bookSeenAt`.
- **Daily Rewards** (side menu, "!" when one is waiting; opens by itself
  once a session for returning players): Day 1 to 7 once a UTC day, then
  round again; a missed day starts over. Each is so many seconds of income
  between a floor and a cap (`economy.daily`), Day 7 the biggest (45
  minutes, at least 3,500 and at most 20,000 coins, a quarter of the 80K
  Coins pack). Kept in `data.daily`.
- **Farmyard** (`src/server/Farm.luau`, `atmosphere.scenery.farm`): outside
  the ring of bases, a red barn and silo, a windmill whose sails turn on each
  client, a duck pond, an animal pen and crop fields, among voxel trees and
  terraced hills. Farm animals are voxel creatures drawn by CreatureView
  (Ducklings, Chicks, Lambs, Piglets). Decoration only.
- **Sound effects** (`config/atmosphere.luau` `sounds`): named hooks; an id
  of 0 is silent until one is picked by ear.

## Timed events and the Giant Egg (Alex, Nov 7 2026)

Rules in `src/shared/Events.luau` and `src/shared/GiantEgg.luau`, numbers in
`config/events.luau`, the reasons in `ops/DECISIONS.md` (2026-11-07).

- **One event a day.** Days run 12:00 to 12:00 UTC; each has one 30-minute
  event starting at a seeded random time between 15:00 and 03:00 UTC. Every
  server and client computes the same schedule from the seed. Kinds: Egg
  Sale (market eggs cost half), Speedy Incubators (eggs bought during it
  hatch in half the time), Money Rush (income x2 while it runs, the offline
  pile counting only the seconds it covered), Lucky Hatch (Rare x1.5 up to
  Legendary and Godly x3; odds still total exactly 100% and show live).
- **Banner** in the middle of the top bar: the next event and when it
  starts (a live countdown in its last hour), or the running event and the
  time left. Tapping opens a card with what it does and today's Giant Egg.
  Notices go to everyone shortly before it starts, at the start and at the
  end. The HUD's income line turns gold and shows x2 during a Money Rush;
  egg prompts and the coin shop show sale prices and faster hatch times.
- **Giant Legendary Egg** (`src/server/GiantEgg.luau`, art from
  `tools/art/world/giantegg.py`): a big gold egg on a plinth in the middle
  of the map with today's Legendary standing on top. A sign shows the
  Legendary, its income, the price and the time to the next one. Its Buy
  prompt (G / DPadUp) sells product `GiantEgg` once per player per day;
  the buyer gets that Legendary, placed like a hatch, with the hatch
  reveal. After buying, the sign says "Yours today" and the prompt turns
  off until the next day. Saves keep `giantEgg = { lastCycle, bought }`.
- **Studio:** the Test panel's `event` action starts any event now, the
  next one in 2 minutes, or stops it; `giantegg` forgets today's purchase.

## Money

All prices need Alex's approval (M5). Product and pass ids stay 0 in
`config/monetization.luau` until created on Roblox; id 0 is never sold.

- The shop opens on its **Coins** tab (next incubator, free shield, traps,
  decoy egg, belt eggs); Robux items are the second tab.
- **Golden Egg Shop** (`src/server/ShopHouse.luau`, `config/shophouse.luau`,
  art and room layout in `src/shared/ShopArt.luau` from
  `tools/art/world/shop.py`): a walk-in storybook shop in the yard (angle
  22.5, radius 62, door toward the Golden Nest) where every Robux item in the
  Shop window stands on its own display: the four coin packs from a pouch to
  a treasure hoard on one wall, Auto-Collect, Extra Incubators, Double Coins
  and Shield Refill on the other, a counter with a Hamster shopkeeper at the
  back. Each plinth's tag shows the name, a line on what it does and the
  price from Roblox ("Owned" for a pass the player has, "Coming soon" for an
  item not on Roblox yet). Its Buy prompt sends the same `Shop:Buy` as the
  Shop window (source `GoldenEggShop`), so the server re-checks everything.
  An item with random results never goes on a display (`ShopPlan`): it stays
  in the Shop window behind its odds screen.
- Passes: Double Coins, Extra Incubators (+2 slots), Auto-Collect.
- Products: four coin packs, each giving its fixed coins or
  `incomeMinutes` of the buyer's income right now, whichever is more (5, 20,
  45 and 100 minutes; `Products.packCoins`). The shop shows each player
  their own exact amount and a purchase never gives less than was shown.
  Shield Refill (adds `shieldSeconds`), Instant
  Hatch, Premium Egg, Luck Boost (15 minutes, multiplies Rare and better
  weights on the listed eggs; the boosted table still totals exactly 100%).
- Private servers.

**Every egg is a paid random item** (coins can be bought with Robux): odds
screen before purchase, odds update live during a Luck Boost, PolicyService
check on every purchase. Players for whom PolicyService restricts paid random
items get the fixed order instead: each egg hatches a fixed repeating cycle
in which every outcome comes exactly as often as its odds (a Basic Egg cycle
is 100,000 eggs, with two Phoenixes in it). The odds card
shows the next creature and how many eggs until each other one, so nothing
they buy is random and they get no more and no fewer rare creatures than
anyone else.

## Save data

Version 1 is in `src/shared/DataTemplate.luau`. Changes go through a migration;
nothing is ever removed. `found` (Hatchery Book) was added to version 1
without a migration: the core's reconcile fills it in as `{}`, and join
back-fills it from the creatures the player owns. `bookSeenAt` was added the
same way (reconcile fills in 0, so a returning player's first look marks
their whole book NEW once).

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
- **depth**: batch the "Inventory is full" notices (14 in 5 minutes) into one.
- **return**: show the offline earnings as a reward moment with the number,
  not a passing notice.
- **monetization**: list the Premium Egg with its odds (M5, paid random:
  odds screen and PolicyService check); Instant Hatch and Luck Boost.
- **social**: raids and visits already exist (M4); add a raid leaderboard and
  a reward for visiting a friend's base.
- **content**: new egg tier and creatures; a timed event egg.
