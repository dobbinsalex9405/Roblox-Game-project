# Metrics and the studio scoreboard

Every game counts its own daily numbers, and once a day a workflow turns them
into the **Studio scoreboard**: one GitHub issue, rewritten every morning,
that shows how much Robux each game made and whether it is keeping players.
The daily Claude run reads it (`ops/DAILY_RUN.md`), and it is the score for
the challenge.

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
| `returnedD1`, `returnedD7` | first join of the day, 1 or 7 days after their first ever join |
| `playSeconds`, `sessionsEnded` | total length of sessions that ended that day, and how many |
| `peakServerPlayers` | most players on one server at once |
| `robux`, `purchases` | per `product:<Key>` and `pass:<Key>`: Robux paid and how many purchases |
| `payers` | distinct players who paid anything that day |

- Developer products count when the receipt is granted (`Receipts`, so a
  retried receipt never counts twice) at the price the player paid.
- Passes count when a purchase finishes in game, at the pass's price. Passes
  bought on the website are not seen.
- No user ids, names or text: only counts.
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
pools the last 7 days the same way.

**Gate for the next wave of games:** 14 days after launch, 7-day D1 at
least 25%, average session 10+ minutes, players up 3 days in a row.
**Kill signal:** 7-day D1 under 15% after 7 days. Stopping a game is Alex's
call; the run only flags it.

Run it by hand from the Actions tab (`env: staging` writes a separate
"Studio scoreboard (staging)" issue, labelled `daily-metrics-staging`, useful
while testing on Staging).

## Setup

Nothing new for Alex: it uses the same `ROBLOX_READ_API_KEY` repository
secret as the feedback pull (`ops/SETUP.md`, the read-only key with DataStore
"List entry keys" and "Read entry" on every game's Staging and Production).
Until that key and the Production ids exist, the workflow skips quietly.
