# Changelog

## Unreleased

- Phones (shared core): the close button (X) on the shop, test panel and
  feedback windows is 40 by 40 px.
- Fixed (shared core): the game now starts in Studio from a built place
  file. The error queue, feedback and metrics stores no longer stop the
  server when DataStores are unavailable (an unpublished place); they warn
  once and save nothing. Live servers are unchanged.
- Fix: the map was buried in the ground. The Baseplate was placed with a
  property Rojo drops when it builds the place, so it sat ten studs too high
  and covered every floor, pad and label. It is now placed with CFrame, and
  the boot check fails when anything is built inside the ground.

- Player analytics (shared core): the daily scoreboard now shows time played
  and session lengths, D7 and D30 returns, players who come with or bring
  friends, Robux by item and by where in the game it was bought, purchase
  prompts, onboarding drop-off and game event counts.

- Error reports (shared core) are stored under dated keys, so the daily
  feedback digest and the post-publish error sweep can read them by day.
- Feedback button in the top bar (shared core): players send a Bug, Idea or
  Other report with an optional fun rating. Reports carry this game's
  progress snapshot (cash, register, queue, districts, stations and cooks) to help reproduce bugs.
- Robux prices and Roblox listings (name, price, description) for every
  pass and product, on the studio price ladder (ops/PRICING.md).

- First-session guide: a goal line under the cash bar, plus a gold arrow and
  beam to the place to go, from the first customer to opening Market Row.
  It follows the onboarding funnel, then offers the cheapest next station,
  upgrade or cook, so the save for Market Row is a run of small goals.
- Store page: title, description and art brief in `STORE.md`.

- Shop: the shared Robux shop lists the three cash packs, Speed Boost, 2x
  Cash and Auto-Collect, and the Studio test panel can buy and replay each
  product. Per-experience ids go in `config/monetization.luau` under
  `environments`. Instant Build waits for the M5 shop, which can offer it
  only while something is being built.
- Fixed: the server refused to start with a counter line longer than 20
  (the line is 30 since the idle rebalance). The client draws 12 at most.

- First playable (M2): a counter queue fed by each district's foot traffic,
  serving customers by hand for the whole menu, 12 stations (4 per district)
  with 3 levels each, build and upgrade timers, moving stations, 3 cook tiers
  who sell their station's dish into the register, collecting, 3 districts,
  one rebirth, offline earnings with a welcome-back message, Auto-Collect and
  2x Cash pass support.
- Exact income: the restaurant is computed piece by piece between the moments
  a rate changes, so ticks, rejoins and offline time agree to the coin.
- Grey-box map built from code: one street with 8 plots, each with a counter,
  a register, 12 station spots in three district zones, district gates, a
  rebirth stand and the owner's name. Customers are drawn on each client.
- Minimal HUD: cash, cook income, the register, customers waiting, rebirths,
  notices, the welcome-back message, and build and hire menus.
- Save data v1: cash, register, queue, rebirths, districts, stations (type,
  spot, level, build finish time), cooks (tier, station), boosts, order board
  and festival placeholders (M4), rebirth archive, receipts, onboarding
  moments and stats.
- Balance leans idle: cooks sell twice as fast (12/24/48 a minute), the
  counter line holds 30, and Market Row opens around minute 15. A player who
  looks in every 5 minutes reaches the rebirth in about 7.5 hours.
- Analytics: onboarding steps Joined, FirstCustomerServed, FirstStationBought,
  FirstUpgrade, FirstCookHired, SecondDistrictUnlocked (once per player, ever, reported
  in order even when played out of order),
  `Station:Built`, `Station:Upgraded`, `Cook:Hired`, District and Rebirth
  progression, and every cash change through the economy ledger.
- Config with schemas and cross-file checks; cash packs (not yet created on
  Roblox); tests for the rules, whole sessions, rejoins, offline time and
  pacing.
