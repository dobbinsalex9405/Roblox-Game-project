# Decisions

Non-obvious choices, newest first, so a later session can trust them.

## 2026-11-01: Tidecatch Cove first playable (milestone M2)

- **One odds table per spot and bait; the rod is a boost.** Bait multiplies
  the spot's weights by rarity and is rescaled to 10,000 at start-up, so each
  table is exact. The rod is applied with the core's `setBoosts`, so the dock
  boards, the odds card and the bite all read one table and update the moment
  a rod is bought.
- **The catch is rolled at the bite, on the server.** The client learns only
  the rarity (to set the minigame's difficulty) until the fish is landed.
- **The reel is checked by time, not watched.** The minigame runs on the
  client (`src/shared/Reel.luau`, the same code the tests play), and the
  server rejects a catch reported sooner than a human reaction plus a perfect
  fill (`Reel.minSeconds`). The client never starts the bar before the
  reaction time, so honest players are never rejected. One line at a time, a
  1 s cast cooldown and a distance check cover the rest.
- **Free casts are not paid random items.** Tidecatch sells no coins for
  Robux, so casts with no bait or coin-bought bait are free rolls. A bait
  marked `robux` (M5 bait packs) turns every cast with that bait type into a
  paid roll through `Odds.rollPaid`, refused for restricted players before
  the bait is used. If coin packs are ever added, every bait cast becomes
  paid. Verify this reading on the Creator Hub before M5, as the Wave 1 plan asks.
- **Offline growth uses the saved clock and is folded in on join.** Time away
  counts up to `pools.offline.maxSeconds` (3 hours, more than any creature
  needs to reach Giant today), then each pool's timer is moved forward so the
  rest of the absence can never count later. Feeding adds growth seconds on
  top (`fed`), so growth is pure arithmetic over saved numbers.
- **Starting bait is given in code, not the template.** The core refills
  missing template keys on load, so a template `bait = { Worm = 10 }` would
  hand back worms every time a player used them up.
- **A full bucket sells the new catch at once** rather than refusing it, so a
  reeled fish is never wasted. The catch card says so.
- **Onboarding steps are only the moments that must happen in order** (Joined,
  FirstCast, FirstCatch, FirstPlaced, FirstGrowth); the core drops
  out-of-order steps, and a first sale can come before or after a first
  placement, so it is the custom event `Onboarding:FirstSale`.
- **Leaderboards ("biggest catch today") wait for M4** with the tide and the
  journal pages; the save already records each player's biggest catch.
- **Pacing (first tuning, for the closed test).** A simulated player catches
  about 6 fish a minute, earns about 1,000 coins in the first 10 minutes and
  reaches the Reef Rod (1,500) in 25 to 40 minutes. A simulated human (0.2 s
  reaction) lands almost every Common and Rare with the starting rod, and
  Legendaries need a better rod.

## 2026-11-01: Hatchery Heist first playable (milestone M2)

- **The conveyor is a schedule, not physics.** Egg n appears at
  n × `spawnSeconds` and its kind is a fixed hash of n and the base. Clients
  draw every belt from the server clock and the server checks a purchase
  against the same schedule (1.5 s latency allowance), so the belt costs no
  network traffic and cannot be spoofed.
- **The hatch result is decided at purchase.** Payment and the paid roll (or
  the fixed order) happen in the same atomic save, and the incubator stores
  the outcome. Waiting for a better roll or re-rolling is impossible.
- **Fixed order for restricted players.** Where PolicyService restricts paid
  random items, eggs hatch their outcomes in listed order and the odds card
  shows that order with the next one marked. Verify this reading against the
  Creator Hub policy before M5, as the Wave 1 plan asks.
- **Buy stays off until the odds arrive** from the server, so no egg can be
  bought without its odds on screen.
- **Income is a pile, collected in batches.** Online income accrues every
  10 s and before any change to what earns; banking happens at the collect
  pad or every 30 s with Auto-Collect, so there is one economy event per
  collect, not one per second.
- **Storage is capped (30)** and the weakest stored creature sells for 60 s of
  its income when it overflows. Without a cap a 30-minute simulated session
  stored nearly 200 creatures, and saves would grow without limit.
- **Rebirth keeps eggs in incubators and bought slots.** The plan says it
  resets coins and creatures; eggs were paid for, so they stay.
- **Game rules run in Lune.** `src/shared/Actions.luau` is the server's whole
  action layer with Roblox effects passed in, so the tests drive the real code
  through the real core services. It lives in Shared to load the same way in
  Roblox and Lune; it holds no secrets and does nothing without server services.
- **Mounts are basic in M2.** A welded shape and walk speed from the
  species; the Movement check that rejects speed hacks comes with raids (M4).

## 2026-11-01: Framework scaffold (milestone M1)

- **Repo name.** The plan suggested `roblox-studio`; Alex created
  `roblox-game-project`. Same layout either way.
- **Pure core, injected Roblox.** Everything in `packages/core/src` runs in
  Lune with no Roblox services, so every money and data rule is unit-tested on
  each push. Roblox wiring is a thin layer in `packages/core/server` and
  `packages/core/client`, checked by the strict type check and exercised in
  Studio sessions.
- **String requires inside the core.** `src/` modules use
  `require("./Module")`, which Roblox and Lune both resolve. Everything outside
  `src/` requires by instance. Verify at the first Studio session (M3); the
  fallback is instance requires in `src/` plus a Lune shim.
- **Game modules that need the core take it as an argument** (for example
  `Schemas(Schema, Odds)`), because a game's shared folder and the core sit in
  different places in Roblox and on disk.
- **Every Hatchery Heist egg is a paid random item.** Coin packs sell coins for
  Robux, so eggs bought with coins fall under the paid random items policy too
  (brief, Part 7). All egg tables are marked paid: odds screen before purchase,
  PolicyService check on every hatch. For restricted players the M5 shop must
  offer a policy-approved alternative (for example direct purchase of a
  specific creature, or eggs from a free earnable currency).
- **Odds as integers out of 10,000.** Shown percentages are exact to 0.01% and
  always total 100.00%; boosts renormalize with the largest-remainder method and
  never drop a possible outcome below 0.01%.
- **Receipts trust only saved data.** Roblox is told "granted" only after a
  save containing the purchase id lands (ProfileStore `OnAfterSave`), with a
  15 second timeout.
- **Data from a newer build is refused, not downgraded,** so a rollback can
  never overwrite progress made on the newer build.
- **Error queue keys** are `<unix minute>-<JobId>` in the `ErrorQueue`
  DataStore: one write per server per minute at most. The nightly reader (M5)
  lists keys newer than its cursor. Consider MemoryStore with expiry at M5 if
  DataStore storage grows.
- **Packages.** ProfileStore pinned at exactly `1.0.3` (MadStudio, by loleris;
  source reviewed 2026-11-01). React-Lua is deferred to the UI kit (module 13,
  M5) so no unused code ships before then.
- **Publishing.** GitHub Actions with group-owned keys in environment secrets
  named `ROBLOX_API_KEY_<GAME>`. Staging publishes on merge and skips games
  whose ids or key are not set yet. Production is manual, only from commits on
  `main`, waits for Alex's approval, and tags `<game>/production/v<version>`;
  rollback is a re-run with the previous tag. The publish tool only sends the
  key to `apis.roblox.com` (or 127.0.0.1 for its own smoke test).
- **Third-party action.** `CompeyDev/setup-rokit@v0.2.1` installs Rokit on CI.
  Pinned by tag; pin to a commit SHA if supply-chain rules tighten.
- **Wave 1 build plans:** Alex approved mounts on 2026-11-01; the Mounts
  module and the `mountUid`/`decoys` save fields arrived in M2. Adding
  top-level save fields needs no migration (new keys are filled from the
  template on load).
