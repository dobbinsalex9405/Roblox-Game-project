# Decisions

Non-obvious choices, newest first, so a later session can trust them.

## 2026-11-05: Rarer odds and voxel creatures (Hatchery Heist)

- **Odds tables may total more than 10,000.** `Odds` takes an optional
  `total` (a power of ten up to 10,000,000); left out it stays 10,000, so the
  other games are unchanged. Hatchery Heist's eggs total 100,000 (Alex asked
  for far rarer odds); percentages show as many decimals as the total needs
  and every row also shows "1 in N". The fixed order for restricted players
  is the same odds as a cycle (50,000 to 100,000 eggs), computed once per egg,
  and the wait for a creature is a binary search.
- **Creatures are client-built voxel models, not uploaded meshes.** Art is
  Python (`tools/art`), merged into boxes and exported as Luau data; the
  client builds Parts. This needs no Open Cloud asset key, diffs in review,
  and lets parts move (Motor6Ds) and glow (Neon) per tier. A box may run
  through voxels nobody can see, but never overlaps another on the outside
  (coplanar faces flickered and caught shadow speckles in the render
  check), and a voxel belongs to one part only. Budgets per tier are tested;
  a Godly is at most 800 parts, fine for a 1 in 50,000 creature.
- **The server's creature parts are invisible stand-ins.** The client
  draws the model on them rather than hiding them locally, because the
  camera rewrites `LocalTransparencyModifier` on character parts and a
  hidden mount would reappear. `LookFade` carries ghost (ridden, guarding)
  and gone (carried).
- **Income roughly doubles per tier and tops out at 1,000/s** (Common 1 to
  Godly 1,000), on the scale the economy was built for (the old Phoenix was
  600/s), not 40,000/s. Rarity pays in looks and bragging more than coins,
  so coin packs, slots and rebirth stay meaningful: the 80K pack is at least
  five minutes of an Epic's income (tested). The Moonlit Egg is 15,000 coins
  (about 12 minutes of its average hatch's income to pay back, against
  about 8 for a Meadow Egg).
- **`VoxelArt.luau` is generated and skipped by StyLua** (it would put each
  number on its own line); CI re-runs the exporter and fails if it differs.
## 2026-11-05: Games start without DataStores (Studio)

- A built `.rbxl` opened in Studio is an unpublished place, where
  `GetDataStore` throws. The error queue, feedback and metrics sinks opened
  their stores unguarded while CoreServer started, so every game's server
  died at start-up in Studio. They now open stores through
  `Core.Stores.open`, which returns nil with one warning per store, and
  their writers then report failure without touching a store. Live servers
  always get their store, so nothing changes there.
- CI boots every built game a second time with `--studio --unpublished`
  (GetDataStore throws the Studio message), so this cannot come back. Player
  saves are ProfileStore's own concern: it switches to its mock store.

## 2026-11-04: Shop tabs, first-session guide and atmosphere (Hatchery Heist)

- **The shared shop takes game tabs.** `CoreClient.addShopTab(name, render)`
  puts a game's own-currency tab in front of the Robux tab and the shop
  opens on it. Opening straight onto Robux prices read as a cash grab on a
  first look. Games without a tab keep the old single Robux list.
- **The guide is pure and tested** (`src/shared/Guide.luau`), like Street
  Food Empire's, and stops after the 4th incubator, the point where the
  playtest numbers say the loop has clicked.
- **The welcome screen shows on a fresh save only** (no egg bought, first
  session), so no data field or migration was needed.
- **Scenery is decoration only.** Fences and flowers don't collide, so raid
  routes and the movement check are unchanged. Hills and tree trunks
  collide, but they are outside the play area.
- **Music is licensed library audio only.** Track ids live in
  `config/atmosphere.luau`. The cloud sandbox can't reach Roblox's
  catalogue, so ids are picked in Studio's Creator Store (by Roblox) on the
  laptop. With no ids, there is no music and no Music button.

## 2026-11-04: Place parts in project files with CFrame, and check the ground

- `rojo build` does not write a part's `Position` into the place file, so the
  Baseplates of Hatchery Heist, Tidecatch Cove and Street Food Empire were
  built centred on Y = 0 (top at Y = 10) and buried each map. Project files
  now use `CFrame`; `tools/tests/ProjectFiles.spec.luau` rejects `Position`,
  `Orientation` and `Rotation`.
- The boot check now fails when a part sits inside a Baseplate after the
  server builds its world and a player joins. It is still no substitute for
  looking: every visible change gets a Studio play-solo screenshot before it
  is called done.

## 2026-11-03: The daily run starts the morning workflows itself

- GitHub's `schedule` trigger ran the feedback pull and the scoreboard about
  10 hours late on Nov 2 and had not started them by 07:13 UTC on Nov 3. The
  daily Claude run now dispatches Player feedback and both scoreboards when
  today's runs are missing (`ops/DAILY_RUN.md` step 1). The cron lines stay
  as a fallback. A late scoreboard or plan run only rewrites the same issue;
  a late feedback run can open a second digest for the same day, which the
  next run closes as a duplicate (step 2.1).
- A Staging publish that fails with a Roblox 5xx gets one re-run of the
  failed job before it counts as a failure (Nov 2: Depthbound got HTTP 500,
  the re-run published).

## 2026-11-02: Screen control on the laptop

- **A local MCP server, not a skill.** `tools/screen-control/` gives Claude
  Code on the laptop screenshots, mouse, keyboard and window focus, for the
  clicks the browser tools cannot do (thumbnail uploads, Studio play tests).
  Registered in Claude Code's user config so every laptop session gets it.
- **Alex starts it, nothing else does.** It is an HTTP server on 127.0.0.1
  behind a token, run in a visible window by `start.ps1`; no stdio server
  that Claude Code could launch by itself.
- **Keys go through a guard, fail closed.** No typing or key presses in
  password, code, CAPTCHA or payment fields or on sign-in and checkout
  pages; an unreadable focused field is a refusal too.
- **Token in `%USERPROFILE%`, not AppData**, because the Store-installed
  Claude app gets a private AppData copy that other programs cannot see.

## 2026-11-02: Player analytics in the scoreboard

- **One pipeline, not two.** Analytics (time played, returning players,
  friends, where Robux is spent, onboarding, game events) are extra counters
  in the same `Metrics` DataStore days and extra sections in the same Studio
  scoreboard issue. No new store, key, workflow or secret.
- **No third-party analytics service.** Roblox's own analytics need a
  signed-in session and outside services need an API key in game servers;
  DataStore counters are readable with the read-only key Alex already made.
- **Counts only.** No user ids, names or player text leave the game; the
  "brought a friend" and "first payment" markers live in each player's own
  save.
- **The JSON stays `version: 1`.** New numbers are optional fields, so the
  daily run and the update loop thread keep working; a breaking change would
  bump the version.
- **Where Robux is spent is named by the client.** `Shop:Buy` carries a
  PascalCase place name (schema-checked, at most 100 per day kept), because
  only the client knows which button was pressed. A lying client can only
  mislabel its own purchase; Robux totals still come from Roblox's receipts.
- **Schema 2 reads schema 1.** A server running older code during a rollout
  leaves schema 2 values alone (its write is skipped), so a few minutes of
  counts from old servers can be lost on the day of the first rollout. Nothing
  is live yet, so this costs nothing now.
- **"With a friend" is checked against Roblox**, at most 50 lookups per join,
  in the background; a failed lookup counts as solo.

## 2026-11-02: The update loop

- **Ages 16+ is the starting audience.** Every game is shown to 16+ only
  until Alex completes ID verification, 2-step verification and, per game,
  250 highly engaged players or a refundable 1,000 Robux fee. The plan
  carries it as one studio-wide For Alex line, repeated in the Friday ask,
  and early metrics are read against the 16+ pool. Which games are open lives
  in `tools/loop/config.luau` (`audience`).

- **Plain code decides the signals; Claude decides the update.** The plan
  (`tools/loop/`) is a tested rules engine over the scoreboard JSON, the open
  bugs and the release tags. It never writes game code; it names a focus and
  the numbers behind it, and the loop owner thread writes the brief.
- **One focus per game per week**, so a release's effect can be read. Ties
  go fix → discovery → onboarding → depth → return → monetization → social →
  content: fix the leak before pouring players or prices into it.
- **Rates need a sample.** D1/D7 need 30 new players a week, session length 40
  sessions, spending 60 player-days; below that a rule stays quiet and the
  plan says what it could not judge. With too few new players the focus is
  the store page (discovery), the only thing that can change that.
- **Weekly cadence with a Wednesday merge deadline and a Friday Production
  ask**, so the Staging 24-hour sweep fits before the ask and releases land
  before the weekend peak. Alex gets one batched ask a week, plus hotfixes.
- **Release checks compare days, not weekdays.** Day 3 (rollback question)
  and day 7 (verdict) compare the days after a release with up to 7 days
  before, skipping the release day itself. Weekday mix can blur day 3; the
  thresholds (a third off session length, 30% off players or Robux per
  player, 10 points off D1) are set wide for that reason.
- **A rollback question needs 2 days after a release.** With 20 players a
  day, one day can swing 30% on noise (verifier's review of #30); day 1 shows
  as "worse so far" in the plan and asks no one.
- **Production tags are now annotated**, so a tag carries its publish date
  (a lightweight tag only has its commit's date, which can be days older).
- **The loop reads the scoreboard issue, not the metrics run's files**, and a
  separate workflow writes the plan. The analytics work can change
  `metrics.yml` and `tools/metrics/` freely; the contract is the
  `loop-lab-metrics v1` block, where new fields are optional.
- **Thresholds are first guesses** from common Roblox benchmarks (D1 25%, D7
  8%, about 1% of daily players paying). Review them after two weeks of real
  data.

## 2026-11-01: Feedback prefilter and the error sweep

- **A plain-code prefilter, not a model, sits between players and the Claude
  run.** It dedupes, tags keywords, caps per player and per game, and leans
  towards escalating; the Claude run decides. Its output is a hidden JSON
  block with no player text, so nothing a player typed reaches the run as
  structure.
- **One read-only key and one workflow read both feedback and errors.** The
  `ErrorQueue` sweep reuses `ROBLOX_READ_API_KEY` and the Player feedback
  workflow, so Alex makes one key, not two, and errors land next to the
  reports that mention them.
- **`ErrorQueue` keys are now dated** (`YYYYMMDD-HHMMSS-<server>-<n>`, as
  `Feedback`), so a day or an hour lists by prefix instead of reading the
  whole store. Keys in the old `<minute>-<job>` form (Staging test sessions
  at most) are simply never listed; nothing reads or migrates them.
- **The 1-hour sweep is started by the thread that published, not by a
  sleeping job**, which would spend an hour of Actions minutes per publish.
  The daily digest is the 24-hour sweep, and the daily run catches a missed
  one.
- **Sweeps open an issue even when clean** (`error-sweep`), so the promotion
  rule ("24-hour sweep found no server error") has a record to point at.
  Daily digests still open only when there is something in them.

## 2026-11-01: In-game feedback in every game

- **The core owns it, so every game gets it.** `CoreClient.start` mounts the
  Feedback button and form, `CoreServer.start` runs the server side; a game
  only adds a `feedbackContext` hook (`src/shared/FeedbackContext.luau`) with
  a few numbers that help reproduce a bug. A game could opt out with
  `CoreClient.start({ feedback = false })`; none should.
- **The button lives in the Roblox top bar**, right-aligned in
  `GuiService.TopbarInset`, so it never covers a game's HUD on any screen.
  The left end of the free top-bar area is kept for the shop button.
- **Bug / Idea / Other, up to 500 characters, optional 1-5 fun rating.** Text
  is required (a bare rating says too little to act on). The rating also
  becomes a `Feedback:Rating` analytics event, a cheap weekly fun score.
- **Only filtered text is stored.** Reports are not shown to other players,
  but players type names and numbers; Roblox's filter (non-chat broadcast
  mode) removes personal information. If the filter fails, the report is
  refused with "try again", never stored raw. A report the filter blanks out
  entirely is refused too.
- **Limits:** one report per player per minute, ten per UTC day per server,
  repeats refused, at most 200 held per server between writes (a failed write
  keeps them for the next try). The remote itself allows 3 calls a minute.
- **Its own DataStore (`Feedback`), not the error queue.** Feedback moved out
  of ErrorReporter: different readers, different retention, and reports carry
  much more context. Each report still links to the error queue through the
  signatures of the player's last client errors (up to 5, from the last 10
  minutes).
- **Dated keys, one write per server per minute.** Keys start with the UTC
  date (`YYYYMMDD-HHMMSS-<server>-<n>`), so the reader lists one day with a
  prefix and the daily run reads each batch exactly once. Writes stay far
  under the DataStore budget.
- **Read outside the game through Open Cloud, from GitHub Actions.** The
  cloud sandbox cannot reach apis.roblox.com, so the daily workflow pulls with
  a read-only repository secret and opens one `player-feedback` issue per day
  with reports. The issue escapes player text (no mentions, links or
  formatting) and shows reporter tags, not user ids; full reports stay in a
  90-day run artifact. The repo is private.
- **Triage process in `ops/FEEDBACK.md`:** severity 1-3, fix with a failing
  test first, verified by the playtest thread, auto-merged, production by
  Alex's click.
## 2026-11-01: Boot check and key flows gate every merge and publish

- **Why.** PR #5 merged with a start-up assert in Street Food Empire's
  `init.server` (`queueMax <= 20`, while the config said 30). CI was green: the
  unit tests and the headless playtests exercise pure modules, and nothing ran
  the real server entry point. The game would not have started on Staging.
- **Boot check** (`tools/boot/`): the built `.rbxl` is loaded under Lune with a
  thin Roblox shim and its server Scripts, a player join, the client
  LocalScripts and the leave all run for real. Errors anywhere fail the check.
  The shim answers only what the games use; an unknown member raises Roblox's
  own error and the fix is to teach the shim, never to loosen the game.
- **Key flows** (`tools/keyflows.sh`): `playtests/<game>/checks.luau` now exits
  non-zero on a bug and runs in CI. A new game cannot be published without one.
- **Where they run.** CI on every PR (every game, `--built` on the CI build);
  both publish workflows on the exact file about to be uploaded, after the
  build and before the upload. `ops/PUBLISH_CHECKS.md` defines the whole
  pre-publish gate and the post-publish checks (version read-back, live join,
  error-queue sweep, first-24-hours rule) and the promotion rule to Production.
- `playtests/` is now formatted and linted like the rest of the repo.

## 2026-11-01: One Robux price ladder for every game

- **Six prices: 25, 49, 99, 149, 199, 399.** Small packs, skips and refills
  at 25; 15-minute boosts, protection and one paid random roll at 49; medium
  packs and convenience passes at 99; capacity passes (and Auto-reel, which
  plays the core action) at 149; earnings multipliers at 199; large packs at
  399, the ceiling while the games are new. Full table and reasons:
  `ops/PRICING.md`.
- **Low end of the usual simulator ranges on purpose.** New games have no
  reviews or social proof, so conversion matters more than price per sale;
  passes can rise a rung later without hurting early buyers. Prices are
  revisited after each game's first 7 live days.
- **Prices live in the game configs** (`listings`: name, Robux, description),
  not only on Roblox, so the laptop creates exactly what the repo says and a
  test (`tools/tests/Pricing.spec.luau`) holds every game to the ladder, the
  shop's names and `ops/PRICING.md`.
- **Tidecatch's draft (Mystery 39, packs 49, Extra Pools 199, Sell 299) was
  folded in**, keeping its rule that the paid random item is never the worse
  deal: Mystery Bait and the Storm Lure Pack are both 25, with the pack cut
  from 5 lures to 4.
- **No Starter Pack yet.** It is usually the best first purchase in a
  simulator, but each game needs a grant and a once-only check, so it is a
  separate change.

## 2026-11-01: Tidecatch Cove keeps the HUD Pools panel

- **Feed, Sell and Unlock work from anywhere** through the HUD Pools panel,
  as Place already did from the Bucket. In the playtest a bot spent about a
  quarter of its time walking between dock and cove (about 13 s a round
  trip), which is dead time on a phone. The cove still matters: it is where
  the creatures are seen growing, and the welcome-back message points there.
  Decided by Claude under the standing rule that design calls do not go to
  Alex; revisit if session data shows players never visit their cove.

## 2026-11-01: Depthbound's daily return reward

- **The first real haul sold each UTC day pays double** (at least 5 ore, so
  a stray coal does not use it up). It stacks with an Ore Boost and works at
  the sell pad and with Auto-Sell. The day it was last paid is saved
  (`dailyHaulDay`), so it is once a day across servers. This is the Wave 1
  plan's "reward the first dive of each day" lever for day-1 retention, with
  numbers in `config/dive.luau` (`dailyHaul`).
- **Picked without waiting for Alex** (AI-managed project rule): of the
  playtest tuning card, the lamp-out floor and doubled tier-5 costs shipped
  in PR #4, the first-dive guide in PR #12, and this is the last of the four.
  The late-game gear cliff and zero-risk top-row mining stay as they are
  until real play data: both matter after the first session, and the launch
  gate measures day-1 return and session length first.
- **The goal line advertises it** after the first upgrade, until it is taken.
  An event `Daily:FirstHaul` (coins paid) shows whether it brings players back.

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

## 2026-11-01: Tidecatch Cove Robux shop (milestone M5 code, prices pending)

- **Robux bait is its own bait.** Bait Pack and Mystery Bait give Storm Lures
  and Pearl Lures, which coins never buy. A cast is a paid random roll exactly
  when its bait came from Robux, so the policy check and the "paid" odds
  label follow the bait id alone, with no per-unit bookkeeping. Coin bait
  stays a free roll (coins are never sold here).
- **Auto-reel is decided on the server.** With the pass, the server lands the
  fish at a fixed per-rarity rate a little slower than the fastest human reel,
  and ignores the client's report, so the pass cannot be used to claim a
  perfect reel.
- **Mystery Bait never grants nothing.** The shop refuses restricted players
  before Roblox's prompt; if the policy flips after paying, the grant gives
  the smallest bundle rather than keep the Robux for nothing.

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
  DataStore: one write per server per minute at most. *Superseded
  2026-11-01: keys are dated, `YYYYMMDD-HHMMSS-<server>-<n>`, and the
  feedback workflow reads them by day or hour prefix (see the top entry).* Consider MemoryStore with expiry at M5 if
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
