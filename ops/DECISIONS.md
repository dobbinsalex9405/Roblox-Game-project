# Decisions

Non-obvious choices, newest first, so a later session can trust them.

## 2026-11-01: Our own metrics and the studio scoreboard

- **Games count their own players and Robux** (`Metrics` in the core,
  `ops/METRICS.md`) because Roblox's dashboards and group revenue pages need
  a signed-in account and a DataStore only needs the read-only key.
- **8 shard keys per day,** fixed per server by a hash of its JobId, merged
  with `UpdateAsync` once a minute. One key per day would queue writes on
  busy days; one key per server would make the reader list thousands of keys.
- **Products count at grant, passes at in-game purchase.** Receipts already
  grant exactly once, so a retried receipt is never counted twice. Website
  pass sales and Premium payouts are invisible to the game and left out; the
  scoreboard says so.
- **Payers are counted once per player per day across servers** by saving
  the day of their last payment in their data (`meta.lastPaidDay`).
- **Studio never writes,** so test-panel purchases cannot inflate the score.
- **Earnings are shown as 70% of Robux paid,** labelled an estimate.
- **The scoreboard is one issue rewritten daily,** not one per day, so the
  daily run and Alex always find it in the same place; the raw numbers stay in
  the DataStore and in a 90-day run artifact.

## 2026-11-01: The daily run and CLAUDE.md

- **One daily Claude run, not several jobs** (`ops/DAILY_RUN.md`), at 07:13
  UTC, an hour after the feedback workflow opens its digest. It wakes the
  project thread "Set up the daily scheduled run" rather than a fresh
  session, so it can read the pause switch and message the other threads.
- **It decides and routes; it never writes game code or merges.** Fixes go
  through the feedback thread and fixer threads, so every change still gets
  the verifier and CI. This keeps the run cheap and its blast radius small.
- **A publish hold also holds merges of game code.** A merge to `main`
  publishes to Staging and GitHub Actions cannot read the switch, so the only
  way to honour "publish nothing" is to not merge.
- **An unreadable switch counts as a publish hold,** not as "running".
- **Severity leans high.** The prefilter's suggestion can be raised freely
  and lowered only with a reason; a fixed bug that comes back is sev1 or sev2.
  Missing a broken purchase costs far more than an extra fix.
- **Revenue is read only from the studio's own counters.** The group revenue
  pages need Alex's signed-in session, which Claude never uses, so metrics
  wait for a `daily-metrics` issue from the games' own DataStore counters.
- **Alex gets a reminder at most every 3 days** about setup steps only Alex can
  do, because nothing earns Robux until the experiences and keys exist.
- **`CLAUDE.md` holds the standing rules** (switch, never-touch-credentials,
  merge and thread rules) so every session in this repo starts with them.

## 2026-11-01: Depthbound's first minute

- **The pickaxe is put in the player's hand on every spawn.** Before, a new
  player had to find the hotbar before their first swing, and a pickaxe that
  arrived in the backpack after the character could be missed entirely.
- **A goal line under the top bar** walks a new player through dig, climb out
  and sell, then the cheapest upgrade with coins / cost, and disappears after
  the first upgrade (Shared/Guide.luau, from the saved `firsts`).
- **The Rucksack costs 40, not 100,** so one full first dive (about 30-60
  coins) buys the first upgrade. A test bot on 12 mines now sells within
  30 s and upgrades within 60 s (it took 55-107 s at 100); the test holds
  45 s and 75 s as the bars.

## 2026-11-01: Depthbound in the shared shop

- **Two products and three passes are listed; the Geode Crate is not.** It is
  a paid random item and geodes do not exist yet, so it stays out of the
  catalog (and unregistered) until M5 brings geodes, its odds table, the odds
  screen and the policy check. A Geode Crate id set before then is logged as
  an error, since Roblox would charge for a product nobody can deliver.
- **An Oil Refill is a saved item, poured at most once per dive** (the plan's
  recommendation; Alex approves the limit with prices at M5). A grant cannot
  refuse a purchase, so a refill bought at camp, after this dive's refill, or
  with the lamp over 90% full is kept for a later dive instead of wasted.
  Bought mid-dive it pours straight away; the HUD's refill button pours one
  from stock or opens the purchase. A lamp already dry is a lamp-out first.
- **An Ore Boost doubles sale prices for 15 minutes** (a config number), and
  buying more adds time. Its end is saved as a server Unix time, so it runs
  across servers and rejoins. Auto-Sell gets the boosted price too. Prices
  and the multiplier are Alex's call at M5.
- **Grants live in Shared/Products**, so the Lune tests run them through the
  core's real receipt path (Buy, then Replay grants nothing twice). Anything
  that touches the live dive runs right after the save, never inside it.
- **The config checks resolve every experience's ids** (dev, staging,
  production): an override for an unknown key, or one id used twice in one
  experience, fails CI.

## 2026-11-01: Shared shop and Studio test panel

- **One shop and one test panel in core** (`ops/SHOP.md`), so purchase rules
  (odds before random items, PolicyService, exactly-once grants) live in one
  place for all four games.
- **The test panel is Studio-only twice over.** Its server half starts only
  when `RunService:IsStudio()`, and in Studio it accepts only Studio test
  players (user id <= 0), the place's creator or the owning group's owner.
- **Test purchases go through the real receipt path.** `receipts:grant` runs
  the same code as `ProcessReceipt`, including the saved purchase id, and
  "Replay" re-sends an id to prove a retried receipt grants nothing.
- **Products register even with id 0** (known by key only, never by a
  receipt) so they can be tested before they exist on Roblox. The shop never
  prompts an id-0 item.
- **Ids per experience.** Staging and Production have separate products, so
  ids live under `environments` in each `monetization.luau`, and
  `tools/build.sh` stamps `BUILD_ENVIRONMENT` into `Build.luau`.
- **Random items need fresh odds.** The server refuses to prompt a paid random
  item unless that player was sent its odds in the last 10 minutes.

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

## 2026-11-01: Windows checkouts and Hatchery Heist balance

- **Wally lives in `deps/`.** `wally install` clears its `Packages/` folder;
  on case-insensitive disks (Windows, macOS) that is our `packages/` and it
  deleted the shared core. Moving `wally.toml` to `deps/` (packages install
  to `deps/ServerPackages`) fixes it with one path per game, where renaming
  `packages/` would have touched every require in every game.
- **`.gitattributes` forces LF** so Windows checkouts pass StyLua.
- **Hatchery Heist economy set from the playtest** (Alex chose "apply the
  playtest set"): startingCoins 200, Basic hatch 10 s, storage sellSeconds
  20, rebirth baseCost 120K with costGrowth 3. Bots: first rebirth at 36 min
  (was 106), idle time in 15-minute sessions 9-48% (was ~56%), and the
  storage-overflow loop now loses coins.

## 2026-11-01: Hatchery Heist raids and defenses (milestone M4)

- **The movement check is a leaky budget, in the shared core.** Each sample
  earns allowed speed × 1.35 × time, capped at 2 s worth, and spends the
  distance moved; going 4 studs over is a violation. The cap forgives lag
  bursts, and leftover budget makes slowing down (picking up, slime) never a
  violation. All three games can use it (`packages/core/src/Movement.luau`).
- **A violation pulls the player back and drops what they carry,** for every
  player, not only raiders, since mounts already change speed. No kicks or
  bans: a false positive costs a short rubber-band, not a player.
- **The carried creature never leaves the owner's save until delivery.**
  Raid state is in memory; delivery takes it from the owner and gives it to
  the raider in two saves, giving it back if the second fails. A crash,
  leave, death or reset mid-carry therefore loses and duplicates nothing.
- **Dying or resetting while carrying drops the creature,** because respawn
  puts the raider at home and would otherwise count as a delivery.
- **Shield values:** free 90 s with a 5-minute recharge after it ends, so a
  base can never be kept shielded for free. The Robux Shield Refill (M5) adds
  10 minutes. These and every raid number need tuning in the first playtest.
- **Traps are hidden from raiders.** Every trap spot looks the same to other
  players; only the owner's client colors and labels them. (A cheater could
  read the attribute; that only spoils a surprise, not the rules.)
- **One guard, chosen from the pads.** It patrols the owner's base only, at
  85% of its mount speed: every guard outruns a raider carrying on foot
  (speed 10), and a raider on a fast mount can still escape a slow guard.
- **New-player protection is the first 5 minutes ever,** counted from the
  saved Joined step, not from each session.

## 2026-11-01: Depthbound first playable (milestone M2)

- **Only blocks that touch air are Parts.** The grid stores just what players
  changed (mined, damage, regrowth); what a block is made of is a hash of the
  seed, its position and its regrowth count, picked through the layer weights.
  A fresh 16 x 16 x 36 mine is 256 Parts, and StreamingEnabled sends each
  client only the Parts near it. This replaces the plan's "chunks": the part
  count tracks tunnels dug, not mine size. The phone test (M2 session) checks it.
- **Old tunnels grow back** after 5 minutes when nobody is within 24 studs
  (or anywhere above a player still in the mine), as a fresh roll, so a
  long-running server's mine never empties and no one is sealed in.
- **The block hash is MurmurHash3's finalizer per coordinate**, done in exact
  32-bit arithmetic. The first version mixed affinely, which gave every server
  the same ore lattice shifted (found by the playtest thread, PR #6); a test
  now checks neighbouring rolls are unrelated.
- **The onboarding funnel holds only steps every player meets in order**
  (Joined, FirstBlockMined, FirstSale, FirstUpgrade). Roblox drops a step
  reported after a later one, so the first lamp-out and reaching layer 2 are
  saved in `firsts` and reported as `Dive:LampOut` (First) and Layer progression.
- **Arriving with exactly enough oil is safe,** and the HUD marker sits one
  second of climbing above the bare need to cover the tap reaching the server.
- **The server owns the oil meter** as a settled value plus a burn rate, re-settled
  when the layer changes; the client draws the same numbers. Lamp-outs during a
  climb are judged at the moment the climb finished, so a late server step can
  never turn a safe climb into a lamp-out.
- **Climbing out is a timed rope, not a walk.** The push-or-cash-out choice
  needs a clear cost: the meter marks the oil a climb from here needs. Walking
  out by hand works too.
- **Nothing beats the lamp.** Dying in the mine is a lamp-out (a reset would
  otherwise rescue a full pack); leaving mid-dive keeps the pack only if the
  oil left could have climbed out from there. The pack is saved, so a crash
  never loses a haul.
- **Lamp-outs keep 25% in proportion across stacks** (largest remainder, ties
  to the more valuable ore), so a rare gem is at the same risk as coal. The
  plan's retention watch ("quit right after the first lamp-out") is reported
  as `Dive:LampOut` with First/Repeat.
- **Hits are re-checked on the server:** in bounds, touching air, within reach
  (13 studs), swing interval x 0.8, pick tier for the layer. Selling and
  upgrading are server-side ProximityPrompts, so they need no remotes.
- **No coin packs, no paid randomness in M2.** Finding ore is free; its exact
  chances are shown at camp anyway (layers are registered as free odds tables).
  The Geode Crate (M5) gets the odds screen and policy check.

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
  random items, eggs hatch a fixed cycle that matches the odds exactly
  (smooth weighted round robin) and the odds card shows the next outcome and
  the wait for each other one. (First version cycled the listed outcomes in
  turn, which gave a Turtle every 4th egg and about twice the early income;
  the playtest caught it.) Verify this reading against the
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
  species; the movement check that rejects speed hacks came with raids (M4).

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
