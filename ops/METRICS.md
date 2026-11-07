# Metrics and the studio scoreboard

Every game counts its own daily numbers, and once a day a workflow turns them
into the **Studio scoreboard**: one GitHub issue, rewritten every morning,
that shows how much Robux each game made, whether it is keeping players, how
long they play, who brings friends, and where in the game Robux is spent.
The daily Claude run reads it (`ops/DAILY_RUN.md`), the update loop reads its
analytics to choose what to change next, and it is the score for the
challenge. The project thread "Track player analytics for all games" owns
this pipeline.

Why our own counters: Roblox's Creator Dashboard and the group's revenue
pages have the same kind of numbers, but nothing outside Roblox can read them
without a signed-in account, and Claude never signs in. A DataStore can be
read with a read-only Open Cloud key.

## What each game counts

`packages/core/src/Metrics.luau` (pure, tested) with
`packages/core/server/MetricsStore.luau` (the DataStore writer), wired in
`CoreServer.start`, so every game gets it with no code of its own. Per UTC day:

| Field | Meaning |
|-------|---------|
| `sessions` | joins |
| `players` | distinct players (their first join of the day) |
| `newPlayers` | first join ever |
| `returnedD1`, `returnedD7`, `returnedD30` | first join of the day, 1, 7 or 30 days after their first ever join |
| `playSeconds`, `sessionsEnded` | total length of sessions that ended that day, and how many |
| `sessionLengths` | ended sessions by length: `m0` under 1 min, `m1` 1-5, `m5` 5-10, `m10` 10-20, `m20` 20-40, `m40` 40+ |
| `peakServerPlayers` | most players on one server at once |
| `friendJoins`, `friendNewPlayers` | joins that followed someone in or came from an invite, and how many of those were first joins |
| `friendSessions`, `friendPlaySeconds` | ended sessions that had a friend on the same server, and their total length |
| `friendsBrought`, `bringers` | friend joins whose friend was already on the server, and distinct players who brought someone that day |
| `robux`, `purchases` | per `product:<Key>` and `pass:<Key>`: Robux paid and how many purchases |
| `robuxBySource`, `purchasesBySource` | the same by **where in the game** the prompt was opened (`Shop`, `HudRefill`, ...) |
| `prompts`, `promptsBySource` | purchase prompts opened, per item and per place |
| `payers`, `newPayers` | distinct players who paid anything that day, and players whose first payment ever it was |
| `events` | game events by name (below) |

- Developer products count when the receipt is granted (`Receipts`, so a
  retried receipt never counts twice) at the price the player paid.
- Passes count when a purchase finishes in game, at the pass's price. Passes
  bought on the website are not seen.
- No user ids, names or text: only counts.
- **Friends.** A friend join is a join with `Player.FollowUserId` or the join
  data's `ReferredByPlayerId` set (they followed someone in, or accepted an
  invite). If that person is on the same server, they "brought" a friend,
  remembered once a day in their save (`meta.lastBroughtDay`), and both
  sessions count as "with a friend". At each join the server also asks Roblox
  (`IsFriendsWithAsync`, at most 50 lookups) whether anyone already there is a
  friend.
- **Where Robux is spent.** `Shop:Buy` takes an optional third argument, the
  place the player pressed Buy: the shared shop sends `Shop`, a game's own
  button sends its own PascalCase name (Depthbound's oil button sends
  `HudRefill`). The server remembers it for 15 minutes; the purchase that
  follows counts there. Anything else (bought on the website, a receipt
  retried in a later session, no name given) counts as `Other`. A game adding
  a new buy button should name it, so it shows up on its own row.
- **First-time payers** are remembered in the save (`meta.firstPaidAt`).
- **Game events.** Everything a game sends through `services.analytics` is
  also counted by name: custom events (`Raid:Stolen`), onboarding steps
  (`Onboarding:03:HatchEgg`, at most once per player session),
  `Progression:<Path>:<Status>` and `Funnel:<Name>:<Step>:<StepName>`. Session,
  retention and purchase events are counted by the fields above instead. At
  most 200 names a day per shard. A game gets more detail in the report by
  sending more events; no other code is needed. Hatchery Heist's timed
  events count `Event:Seen` (each player once per event they saw, with
  its kind), `Event:EggBought` (eggs bought during an event) and `GiantEgg:Prompted` /
  `GiantEgg:Bought` (the Giant Egg's buy prompts and sales).
- **Schema.** Days carry `schema = 2`. Schema 1 values (written before
  2026-11-02) are read and upgraded with the new fields at zero; a server
  never rewrites a value from a newer schema than its own.
- Studio never writes (so the test panel's fake purchases never reach it).
- Each server merges its counts into the `Metrics` DataStore about once a
  minute with `UpdateAsync`, and once more when the server closes. Keys are
  `<YYYYMMDD>-s<0-7>`: a server always writes the same one of 8 shard keys,
  so a busy day spreads writes instead of queueing on one key. That is one
  DataStore request per server per minute, far under the budget.
- If a write fails, the counts are kept and go out with the next one (up to 3
  unsent days).

## The scoreboard

`.github/workflows/metrics.yml` runs at 06:41 UTC, `lune run
tools/metrics/pull`, which lists every key in each live game's Production
experience, reads the ones from 2026-10-31 on (at most 62 days back), adds
the shards up and writes the issue labelled `daily-metrics`, "Studio
scoreboard":

- the **challenge total** since 2026-11-01: Robux paid, and about 70% of it
  as earnings (Roblox's cut on in-experience sales; Premium payouts not
  included);
- one row per game for yesterday: players, new players, D1, average session,
  Robux, Robux over 7 days, payers, and where it stands on the next-wave gate;
- per live game, the last 14 days and the best sellers of the last 7;
- a hidden `<!-- loop-lab-metrics v1 ... -->` block with the same numbers as
  JSON (no player data) for the daily run.

D1 for a day is the players who came back on it for the first time since
their first day, divided by the new players of the day before. The 7-day D1
pools the last 7 days the same way; D7 and D30 use the new players 7 and 30
days before.

### Analytics, last 7 days

Under each live game's table, the scoreboard adds:

- **Players**: player-days (a player counts once per day played), the share
  that were returning players, new players, D1, D7 and D30.
- **Time played**: sessions, average length, the share that ran 10+ minutes
  (the gate's bar), and the length buckets.
- **Friends**: the share of new players who came with a friend, the share of
  sessions with a friend on the server, average session with a friend and
  solo, and friends brought in and by how many players.
- **Spending**: the share of player-days that paid, first-time payers,
  Robux per player-day; a table per item (Robux, purchases, prompts, bought
  per prompt) and per place in the game.
- **First minutes**: how many times each onboarding step was reached, as a
  share of step 1, which shows where new players drop off.
- **Game events**: the 12 most frequent.

### The JSON block

`<!-- loop-lab-metrics v1 ... -->` stays `version: 1`: every field that was
there keeps its meaning, and new numbers are extra fields. A field that is
missing means "no data" (a rate with nothing to divide by, or an empty map).
Per game, besides the v1 fields:

| Field | Meaning (last 7 days) |
|-------|------------------------|
| `d7Week`, `d30Week` | pooled D7 and D30 return |
| `returningShare7`, `playerDays7` | returning player-days / player-days, and player-days |
| `longSessionShare7`, `sessionLengths7` | share of sessions of 10+ minutes, and the buckets |
| `friendJoinShare` | new players who came with a friend / new players |
| `friendShare` | sessions with a friend on the server / sessions ended |
| `friendAvgMinWeek`, `soloAvgMinWeek` | average session with a friend, and without |
| `friendsBrought7`, `bringers7` | friends brought in; daily distinct bringers, summed |
| `payerRate7`, `newPayers7`, `arpdau7` | payers / player-days, first-time payers, Robux / player-day |
| `robuxByItem7`, `purchasesByItem7`, `prompts7` | per `product:<Key>` / `pass:<Key>` |
| `robuxBySource7`, `purchasesBySource7`, `promptsBySource7` | per place in the game |
| `onboarding7` | `"01:StepName"` -> times reached |
| `events7` | other game events -> count |

Maps keep their 25 largest entries (40 for onboarding). Each `days[]` row
also gains `returning`, `d7`, `newPayers`, `friendJoins` and `friendSessions`.
The full numbers for every day are in the run's `scoreboard-<run id>`
artifact (`scoreboard.json`), kept 90 days.

**Gate for the next wave of games:** 14 days after launch, 7-day D1 at
least 25%, average session 10+ minutes, players up 3 days in a row.
**Kill signal:** 7-day D1 under 15% after 7 days. Stopping a game is Alex's
call; the run only flags it.

The **Update plan** workflow runs when this one finishes and turns the same
block into each game's next update (`ops/UPDATE_LOOP.md`). Fields added to
the block later (D7, friends, purchase prompts, onboarding steps) are
optional: version 1 keeps every existing field and meaning, and the plan uses
a new field only when it is there.

Run it by hand from the Actions tab (`env: staging` writes a separate
"Studio scoreboard (staging)" issue, labelled `daily-metrics-staging`, useful
while testing on Staging).

## Setup

Nothing new for Alex: it uses the same `ROBLOX_READ_API_KEY` repository
secret as the feedback pull (`ops/SETUP.md`, the read-only key with DataStore
"List entry keys" and "Read entry" on every game's Staging and Production).
Until that key and the Production ids exist, the workflow skips quietly.
