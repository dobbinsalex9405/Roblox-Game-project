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

## Pacing

Tuned with a simulated attentive player (`tests/Bot.luau`, guarded by
`tests/Pacing.spec.luau`): Market Row opens after about 18 minutes, Downtown
after about 70, the rebirth is affordable after about 6 hours. These are
starting numbers for the M4 playtests.

## Money

All prices need Alex's approval (M5). Product and pass ids stay 0 in
`config/monetization.luau` until created on Roblox; id 0 is never sold.

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
