# The update loop: from numbers to the next update

Every live game gets one update a week, and the numbers choose what it is.
The loop measures each game, picks the one thing most worth fixing or adding,
builds it through the normal PR path, puts it on Staging, asks Alex to send it
to Production, and then checks whether it helped. A bad release is caught in
its first days and rolled back.

```
 measure ──> decide ──> brief ──> build ──> verify ──> Staging ──> Production ──> review
 (scoreboard,  (update   (update   (builder  (verifier  (merge,      (Alex's      (day 3: rollback?
  feedback,     plan      issue)    thread)   + CI)      checks)      click)       day 7: verdict)
  errors)       issue)        ^                                                        │
                              └────────────────────── next week ───────────────────────┘
```

The machine part is plain code and runs every day in GitHub Actions. The
judgement part (writing the brief, building, verifying) runs in Claude threads.
Alex only clicks the Production publish (and a rollback, which is also a
Production publish), and decides whether to stop a game.

## The pieces

| Piece | What it does | Where |
|---|---|---|
| **Studio scoreboard** | Every game's daily counters: players, new players, D1, session length, Robux, payers, best sellers, and the analytics fields (D7, friends, purchase prompts, onboarding steps) as they arrive | `ops/METRICS.md`, issue labelled `daily-metrics`, 06:41 UTC |
| **Player feedback** | Reports and errors become tracking issues (`bug`, `<game>`, `sevN`) and an ideas tally | `ops/FEEDBACK.md`, `ops/DAILY_RUN.md` step 2 |
| **Update plan** | Reads the scoreboard, the open bugs and the Production release tags; writes each game's focus for the week, the signals behind it, a check on the latest release, and the questions for Alex | `tools/loop/`, `.github/workflows/update-plan.yml`, issue labelled `update-plan`, after the scoreboard (07:03 UTC at the latest) |
| **Daily run** | Acts on the plan: urgent items the same day, briefs on Mondays, the Production ask on Fridays | `ops/DAILY_RUN.md` step 3 |
| **Loop owner** | The Claude thread "Run the update loop from metrics": turns the plan into update briefs, gets builders started, keeps the backlog, tunes the rules | this file |
| **Builders and fixers** | Build one update or fix per PR; Opus 5.5 at medium effort | started by the coordinator on the owner's request |
| **Verifier** | Re-verifies each PR's final head; Fable 5.1 at high effort | "Playtest the games for bugs and gaps" |

Every number the plan decides with lives in `tools/loop/config.luau` and is
printed at the bottom of the plan issue. Change it there (with a line in
`ops/DECISIONS.md`); this page explains the rules, the config holds the values.

## Deciding: the signals

Every day the plan computes, per live game, over the last 7 days (pooled, not
an average of daily rates):

| Signal | Fires when | Focus | Level |
|---|---|---|---|
| open sev1 | any open `sev1` bug for the game | fix | urgent |
| release drop | 2 to 3 days after a Production release (one day is too thin; the plan shows it as "worse so far"), against the 7 days before it: average session -33%, Robux per player -30%, players -30%, or D1 -10 points | fix, and a rollback question for Alex | urgent |
| regression | yesterday against the 7 days before, with no release in the last 3 days: players, average session or Robux down 30% | fix (open a sev1 and find the cause) | urgent |
| sev2 pile | 3 or more open `sev2` bugs | fix | high |
| release review | the latest release (4 to 13 days old) reviewed worse | fix (fix forward or revert) | high |
| few new players | live 3+ days and under 30 new players in 7 days | discovery | high |
| low D1 | D1 under 25% (high under 20%); names the onboarding step that loses most players when the analytics have it | onboarding | high / normal |
| short sessions | average session under 10 min (high under 6); with the share of sessions reaching 10 min | depth | high / normal |
| low D7 | D7 under 8% while D1 is at least 20% | return | normal |
| low spend | retention good enough (D1 20%+, sessions 8+ min) and under 1% of players paying or under 1 Robux per player a day; names items whose prompts rarely sell (under 5% of 20+ prompts) | monetization | normal |
| little friend play | under 15% of sessions with a friend on the server (and D1 not under 20%); compares minutes with and without a friend | social | normal |
| retained but flat | D1 and session length on target, but players flat or down week over week | content | normal |

**Sample sizes.** A rate needs players behind it: D1 and D7 need 30 new
players a week, session length 40 sessions, spending 60 player-days. Below
that the rule stays quiet and the plan lists what it could not judge. A
release check needs 20 players a day before the release. The analytics' exact
counts (`purchasesByItem7`, `arpdau7`) are used when the scoreboard has them.

**Picking the week's focus.** One focus per game per week, so we can tell
what worked. The most severe level wins; within a level the order is:

1. **fix**: stop the damage first.
2. **discovery**: without players nothing else can be measured.
3. **onboarding**: a player who does not come back tomorrow never sees the rest.
4. **depth**: then each session.
5. **return**: then the week.
6. **monetization**: only once players stay; spending tuned on a leaky game is wasted.
7. **social**: friends bring friends and stay longer.
8. **content**: engaged players run out of things to do.

No signal means the game is healthy: the update is the next **content** item
from the game's backlog.

**Not live yet.** A game with no Production players has the focus **launch**:
its update is getting onto Production (Staging checks, then Alex's click).

**For Alex.** The plan collects what only Alex decides: a rollback, a game
showing the **kill signal** (7-day D1 under 15% after 7 days: keep it or stop
work on it), and a game passing the **launch gate** (14 days after launch, D1
at least 25%, average session 10+ minutes, players rising 3 days in a row: the
next wave of games can start).

## The playbook: what each focus changes

An update is small and aimed: one focus, at most three changes, plus any bug
fixes already queued. Every number goes in the game's `config/`, so many
updates are config changes with tests.

| Focus | Typical changes | Judged by |
|---|---|---|
| **fix** | The failing test first, then the fix, a `CHANGELOG.md` line (`ops/FEEDBACK.md`). For a release drop: roll back, or revert the change on `main` and ship forward | the signal clears; no new error groups |
| **discovery** | Icon, thumbnails, title, description (`/mnt/project-files/store/<game>/`, "Make store art for every game"). Test one change at a time. Never spend Robux on ads or sponsors: that is Alex's money | new players a week |
| **onboarding** | The first reward within 60 seconds, an arrow or highlight on the first action, fewer steps before the core loop, cheaper first upgrade (`economy.luau`), clearer first-minute text; fix the step the funnel names | D1, the funnel step |
| **depth** | A goal always on screen (next upgrade, next zone), shorter early upgrade gaps, a mid-session milestone reward, a timed event inside the session | average session, share of 10+ min sessions |
| **return** | Daily reward or streak, timers that finish while away (growth, cooking, restock), "come back tomorrow" preview of the next unlock | D7 |
| **monetization** | Place the item where the need is felt (out of oil, pool full), a one-time starter pack, change one price **on the ladder** (`ops/PRICING.md`), bundle a weak item. Paid random items keep exact odds and the PolicyService check | payer share, Robux per player, prompt conversion |
| **social** | Friend join bonus, co-op actions worth more together, invite prompt at a high moment, visible other players' progress | share of sessions with a friend, new players |
| **content** | The next backlog item: a new zone, species, recipe, creature or tier; a limited-time event; top player ideas (3+ players asked) | players week over week, session length |

Changing a price or creating a pass or product touches the Roblox item, not
only the config: the price on Roblox must match the config. Creating items is
done on the Creator Dashboard (the laptop thread with Alex); prefer updates
that use existing items, and queue new items as `ops/SETUP.md`-style steps.

**The backlog.** Each game's `SPEC.md` keeps an **Update backlog** section:
candidate updates grouped by focus, each one line with the expected effect.
The loop owner adds to it from playtest reports, feedback ideas and what
worked in the other games; a brief takes the top item that fits the focus.

## The weekly cadence

All four games run the same week in parallel, one builder thread each.
Times are UTC.

| Day | What happens | Who |
|---|---|---|
| **Monday** | The daily run sends the plan to the loop owner. For each game the owner opens (or updates) one **update issue** and asks the coordinator for a builder thread per game that has one. Last week's release review goes on last week's issue | daily run, loop owner |
| **Mon to Wed** | Build: branch, draft PR, CI green, verifier OK on the final head, merge. **Wednesday 23:59 is the merge deadline** for this week's Production | builders, verifier |
| **Thursday** | Staging checks for the merged build (`ops/PUBLISH_CHECKS.md`): live join, 1-hour error sweep, then the 24-hour sweep | thread that merged, daily run |
| **Friday** | The daily run sends Alex **one** message listing every update that passed the promotion rule, with the Publish to Production link per game | daily run |
| **Weekend** | Peak play; the release is measured | scoreboard |
| **Monday after** | Day-3 fast check has run every day since; the full 7-day review closes the loop | update plan, loop owner |

A build that misses Wednesday waits for next Friday unless it is a fix. At
most one update PR per game is open at a time.

**Hotfix lane.** An urgent fix (sev1, regression, release drop) skips the
calendar: fix today, verifier and CI as always, merge, Staging checks, and
ask Alex for the Production click as soon as the 1-hour sweep is clean. Say
in the ask that the 24-hour sweep is still running.

## The update issue

One per game per week, opened by the loop owner. Title
`<game>: update <YYYY-MM-DD> (<focus>)` (the Monday's date), labels `update`,
`<game>`, `focus:<kind>`, then the stage labels as it moves:
`building` → `on-staging` → `ready-for-production` → `live`. Body:

```
Focus: <kind>, because <the plan's signal, with numbers>
Bet: <metric> from <now> to <target> by <review date>
Changes (at most 3):
- <change> (<file / config key>)
Bugs included: #<n> ...
Verify: <playtest checks or bot session that show it works>
Rollback: <game>/production/v<n> (the release before this one)
```

After release the owner comments the day-3 check and the day-7 verdict from
the plan (`better`, `mixed`, `flat`, `softer`, `worse`), closes the issue, and
adds a line to the game's backlog when the result says what to try next.

## Release flow

1. **PR**: draft, attribution block, CI green, the verifier's OK on the final
   head, then merge without asking Alex (standing rule). Any push after the OK
   needs a fresh OK.
2. **Staging**: the merge publishes every game to Staging. Post-publish checks
   per `ops/PUBLISH_CHECKS.md`: version read-back, live join, 1-hour and
   24-hour error sweeps. A STOP on Staging blocks promotion: fix forward.
3. **Promotion rule** (`ops/PUBLISH_CHECKS.md`): only a commit whose Staging
   build passed the read-back, the live join and the 24-hour sweep goes to
   Production. The owner then labels the update issue `ready-for-production`.
4. **Production**: Alex runs **Publish to Production** (game, `ref` = the
   commit) and approves it. The workflow tags `<game>/production/v<n>`
   (annotated, so the plan knows the publish day).
5. **After**: the live join and the sweeps again; the plan's day-3 check and
   day-7 review.

## Rollback

A rollback is **Publish to Production** with `ref` set to the previous
release tag, so it needs Alex's click. Ask Alex, with the tag and the
numbers, the same day any of these happens:

- the plan raises a **release drop** (within 3 days of a release);
- the 1-hour or 24-hour sweep on Production says **STOP** (a server error, or
  a client error seen 10+ times);
- Developer Stats the day after: session length down a third or the error
  rate doubled (`ops/PUBLISH_CHECKS.md` section 4);
- a sev1 that the release caused and that cannot be fixed within the day.

Meanwhile fix forward on Staging. If the drop is explained by something
outside the game (a Roblox outage, a holiday), say so on the update issue
and do not roll back. A release reviewed **worse** after day 3 is not rolled
back automatically: it becomes next week's fix focus (revert the change on
`main` or fix it).

A game with no earlier release cannot roll back; the fix goes forward.

## The pause switch

The switch (`CLAUDE.md`) overrides the loop:

- **paused**: nothing; the Actions keep writing the plan, no one acts on it.
- **publishHold**: decide, write briefs and build as usual, but merge no game
  code (a merge publishes to Staging) and send no Production asks, except a
  rollback question, which goes to Alex with the hold mentioned.

## Before the games are live

Until a game has Production players its focus is **launch**, and the loop's
weekly work is the launch path: playtest findings and feedback from Staging,
Alex's remaining setup steps, then the first Production ask. The plan workflow
already runs (it reports every game as not live), so the first real numbers
flow into decisions the day after launch.

## Changing the rules

The thresholds are first guesses from common Roblox benchmarks. After two
weeks of real data the owner reviews them: a rule that fired and pointed at
the wrong thing gets a better number, a rule that never fires stays. Change
`tools/loop/config.luau`, keep `tools/tests/UpdateLoop.spec.luau` green, and
add the reason to `ops/DECISIONS.md`. The launch gate itself is Alex's
target (`CLAUDE.md`); the test keeps the plan's copy equal to the scoreboard's.
