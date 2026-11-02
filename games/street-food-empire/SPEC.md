# Street Food Empire: intended behavior

Working title; check Roblox for name collisions before launch (M7).

A tycoon: grow a food cart into a city block. Players serve a queue of
customers by hand, build and upgrade food stations, hire cooks who sell for
them, and open new districts. When a bug report and this spec disagree, the
spec wins until Alex says otherwise. Plan: "Wave 1 Build Plans", tab
"3. Street Food Empire".

## Core loop

Eight plots line one street, four on each side; each player gets one. A plot
has three zones, one per district, from the street back: Cart Corner, Market
Row, Downtown. Each zone has 4 station spots.

1. **Counter.** Customers walk up at the foot traffic of every open district
   (`districts.customersPerMinute`, added up) and queue at the counter, up to
   `economy.customers.queueMax`; past that they walk on by. Each one orders
   the whole menu, so a meal is worth the sum of the dish prices of every
   finished station. Press Serve to serve the front customer: the meal plus
   `handServeBonus`, straight into cash. An empty lot with no finished station
   gets no customers.
2. **Stations.** 12 stations, 4 per district (`config/stations.luau`), each
   with 3 levels. Build one on any free open spot; it serves nothing until its
   build time is up. An upgrade keeps it serving at the old level until the
   upgrade is done. Every new restaurant starts with a built Hot Dog Cart on
   spot 1. Stations can be moved to any open spot (swapping), with their cook.
3. **Cooks.** One per station, in 3 tiers (`config/cooks.luau`). A cook sells
   their station's dish to walk-up customers at `servesPerMinute`, into the
   register, whether or not the player is serving. Each hire of a tier costs
   `costGrowth` times more than the last one still working; a better tier
   replaces the cook at that station. A cook at a station still being built
   waits for it.
4. **Register.** Cook sales pile up in the register; step on it to collect,
   or own Auto-Collect to bank it every `autoCollectSeconds`.
5. **Districts.** Opening the next district (`districts.cost`) adds its 4 spots,
   its stations and its foot traffic.
6. **Rebirth.** Needs every district open and `rebirth.cost` cash. Resets cash,
   the register, the queue, districts, stations and cooks (kept in the save's
   `rebirthArchive`) for +50% cash from every sale. Launch scope has one
   rebirth (`maxRebirths = 1`).
7. **Offline.** On rejoin, cooks pay `offline.rate` of their sales for at most
   `offline.maxSeconds`; the counter queue fills for the whole absence, so a
   full line is waiting. A welcome-back message says both.

Income is exact, not sampled: rates only change when a station finishes or a
boost ends, so the server computes each stretch between those moments
(`Restaurant.advance`). A 10-second tick, a rejoin and an offline absence agree
to the coin.

## Customers are numbers

The server keeps customers as counts (queue length, cook sales per second);
each client draws them: the counter queue on every plot and one walk-up
customer at each station with a working cook. This keeps the server light with
8 busy restaurants.

## First session

`src/shared/Guide.luau` gives a new player one goal at a time, shown as a
line under the cash bar with a gold arrow and beam to the place to go: serve
the first customer, build a second station, upgrade, hire a cook, then the
cheapest next station, upgrade or cook until Market Row opens. It points at
the register when the register holds enough to matter. See `STORE.md` for the
first-minute timeline.

## Pacing

Tuned to lean idle: cooks earn a real share, so a player who only looks in
now and then still progresses. Simulated players (`tests/Bot.luau`, guarded
by `tests/Pacing.spec.luau`):

| Player | Market Row | Downtown | Rebirth affordable | Cash from hand serving |
| --- | --- | --- | --- | --- |
| Attentive (acts every second) | ~15 min | ~57 min | ~4.5 h | ~44% |
| Looks in every minute | ~15 min | ~58 min | ~4.5 h | ~44% |
| Looks in every 5 minutes | ~30 min | ~100 min | ~7.5 h | ~14% |

The counter line (30) is long enough that checking in once a minute loses no
customers. These are starting numbers for the M4 playtests.

## Money

All prices need Alex's approval (M5). Product and pass ids stay 0 in
`config/monetization.luau` until created on Roblox; id 0 is never prompted.
Staging and Production ids go under `environments` there (ops/SHOP.md).

The core's shop lists what `src/shared/Products.luau` registers: the three
cash packs, Speed Boost, 2x Cash and Auto-Collect. Every one of them runs
through the real receipt path in the Studio test panel, even with id 0, and
`tests/Products.spec.luau` runs Buy and Replay for each product. A Speed Boost
only speeds up what comes after the purchase; buying another adds time.

- Passes: 2x Cash, Auto-Collect, Festival cosmetics bundle (M4).
- Products: three cash packs, Instant Build (finishes every build and upgrade
  in progress), Speed Boost (customers come twice as fast for 15 minutes).
- Subscription: monthly daily cash bonus (M5). Private servers.

**Nothing in this game is random**, paid or not: every meal's value and every
purchase's result is shown before buying, so no odds screen is needed. A test
fails if game code starts using randomness; if that ever changes it needs an
odds screen and a PolicyService check first (see Hatchery Heist).

## Save data

Version 1 is in `src/shared/DataTemplate.luau`. Changes go through a migration;
nothing is ever removed.

## Status

- Done (M2): counter queue and hand serving, 12 stations with 3 levels, build
  and upgrade timers, moving stations, 3 cook tiers, the register, 3
  districts, one rebirth, offline earnings with a welcome-back message,
  Auto-Collect and 2x Cash support, grey-box street of 8 plots built from code,
  client-drawn customers, minimal HUD and menus, onboarding analytics.
- Next (M3): first Staging publish and the first Studio session (street
  layout, first playtest). Then M4 customer moods, the daily order board, the
  weekly food festival and helper co-op; M5 the shop (Instant Build, Speed
  Boost, subscription, prices).

## Update backlog

Candidate updates for the weekly loop (`ops/UPDATE_LOOP.md`), grouped by
focus. A brief takes the top item that fits the week's focus; the loop owner
adds new ones from playtests, feedback ideas and what worked elsewhere.

- **onboarding**: the first minute is 11 taps and 49 s of standing still;
  every bot was still on "Unlock" after 15 minutes. Shorten the first unlock
  and point at the next build.
- **onboarding**: funnel steps for the first upgrade, the first full line,
  District 3 and the first Line Cook.
- **depth**: show how many customers walked away (half are lost at 3
  districts if the player is gone 2 minutes); a serve-all or queue upgrade.
- **depth**: rebirth burns everything above its cost; keep the surplus or
  warn. After the one rebirth there is no further goal: add rebirth 2+.
- **depth**: the hire menu should say "replaces your Trainee (no refund)".
- **return**: offline pay is worth about 15 minutes of play; the daily order
  board (M4) as the reason to return.
- **monetization**: 2x Cash halves the 6-hour climb, so price it as the big
  pass; Instant Build and Speed Boost on the long timers (M5).
- **social**: helper co-op (M4).
- **content**: customer moods, the weekly food festival (M4), a 4th district.
