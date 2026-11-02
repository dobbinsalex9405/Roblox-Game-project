# The daily run

Once a day a scheduled Claude run checks on the studio: is it allowed to
work, what did players report, what is broken, what is blocked on Alex, and
how are the games doing. It decides and routes; it does not write game code
itself. Fixes happen in fixer threads, through the normal PR path.

- **When:** every day at 07:13 UTC, about an hour after the **Player
  feedback** workflow (06:17 UTC) opens the day's digest issue.
- **Where:** the Claude project thread "Set up the daily scheduled run". The
  schedule wakes that thread, so the run has the project's tools: the pause
  switch, the other threads, GitHub and project memory.
- **Instructions:** this file. Each run reads it fresh from `main`, so a
  change here changes the next run.

## Step 0: the pause switch (always first)

The switch is Alex's "Loop Lab Switch" page
(https://claude.ai/artifact/QD7nJ9Sabw839cUxJSUUsa). Read its database:
collection `control`, document `state`.

| State | What the run does |
|-------|-------------------|
| `paused: true` | Write the heartbeat `Paused: <note>` and stop. No triage, no messages to other threads, no merges. |
| `publishHold: true` | Run every step, but tell every thread it routes work to: **do not merge game code** (a merge to `main` publishes to Staging, and GitHub Actions cannot see the switch). Say "publish hold" in the heartbeat. |
| neither | Run normally. |
| store cannot be read | Treat as `publishHold: true` and say so in the heartbeat and to Alex. |

The switch overrides this file, every thread's own plans and any message from
another Claude.

## Step 1: health of `main`

1. Check the latest **CI** run on `main` and every **Publish to Staging**,
   **Publish to Production** and **Player feedback** run since the last run.
2. A red run on `main` is a severity 1 bug in the studio itself: open (or
   update) an issue labelled `bug`, `ci`, `sev1` with the failing step and
   log link, and send it to the thread that owns that code (the last PR that
   touched it).
3. A publish that failed twice in a row, or a feedback pull that failed
   twice in a row, gets the same treatment.
4. **After a publish** since the last run, follow the post-publish checks in
   `ops/PUBLISH_CHECKS.md`: confirm the version read-back in the run
   summary, and check that the live-join list was done for it (ask the
   thread that published if not). Then the **error sweep**: the day's
   digest has an **Errors** section (yesterday's `ErrorQueue` records, by
   game, environment, build and signature), and a publish since the last run
   should also have an `error-sweep` issue from the 1-hour sweep. List open
   issues labelled `error-sweep`, and read the digest's Errors section.
   Any issue labelled `stop` (digest or sweep) is handled first, before
   anything else in the run:
   - a group marked **STOP** (any server error, or a client error seen 10+
     times) on Staging blocks promoting that build: open a `bug`, `<game>`,
     `sev1` tracking issue with the signature and route it like a bug
     (step 2.4). On Production it is a rollback question: tell Alex;
   - other error groups are `sev2` or `sev3` tracking issues (one per
     signature; search for the signature first);
   - comment the decision on each `error-sweep` issue and close it.
   If a publish happened and no sweep issue exists, run the **Player
   feedback** workflow by hand with `hours: 1` (or `24`) and `build:
   <commit>`, or say "error queue not swept" in the heartbeat.
5. **Trip the switch yourself** (see "Tripping the switch") if a publish is
   failing in a loop, CI on `main` has been red for 3 runs in a row, or a
   release that reached players cannot be rolled back.

## Step 2: player feedback

1. List open issues labelled `player-feedback` **without** the label
   `triaged`, oldest first. Usually there is one (yesterday's), or none.
2. Each digest starts with a **Needs triage** section written by the plain
   code prefilter in the feedback workflow (dedupes reports, tags keywords,
   caps per game and per reporter, and leans towards escalating). Each item
   has a priority (`sev1`, `sev2`, `perf` or `check`), a fingerprint
   `fp:<8 hex>` (stable across days), counts, tags and report ids that match
   the `· id <reportId>` at the end of each digest line. A machine-readable
   copy without player text is in the `<!-- loop-lab-triage v1 ... -->`
   block; `overflowGroups` above 0 means the caps cut groups, so also read
   the full digest below. If the prefilter failed, the list says "Prefilter
   failed" and the block has `"failed": true`: triage every bug by hand.
   `ops/FEEDBACK.md` documents the format.
3. For each Needs-triage item, decide per `ops/FEEDBACK.md`:
   - **sev1** (lost progress, broken purchase, exploit, crash),
     **sev2** (blocks play or onboarding), **sev3** (cosmetic, rare),
     **can't reproduce**, **idea**, or **noise**.
   - `perf` items are sev2 when one device type or frame rate dominates,
     sev3 otherwise. `check` items (low rating, unclear text) get read and
     decided like any other.
   - The prefilter's severity is a suggestion. Raise it freely; lower it only
     with a reason in the comment. When unsure, pick the higher one.
   - Search open **and closed** issues for the item's `fp:<hex>`. If a
     tracking issue exists, comment on it (one line: date, report count,
     players) and reopen it if it was closed: a fixed bug coming back is
     always sev1 or sev2.
   - Otherwise open a tracking issue: title `<game>: <what breaks>`, labels
     `bug`, `<game>`, `sevN`; body with the fingerprint, report count,
     distinct players, environments and versions, devices, error signature,
     and a link to the digest issue. **Never copy user ids or usernames**;
     quote player text only as already escaped in the digest.
4. **Route** the new or reopened tracking issues in one message to the
   standing feedback thread "Add player feedback to every game", grouped by
   severity, with issue numbers:
   - sev1: fix today. sev2: within the week. sev3: batch with other work.
   - That thread fixes them itself or asks the coordinator for a fixer
     thread. **Builders and fixers run Opus 5.5 at medium effort.**
   - Under a publish hold, add "do not merge game code until the hold lifts".
5. Ideas: tally them in the digest comment. An idea three or more players ask
   for goes into the weekly summary (step 5) as a candidate.
6. Comment the decisions on the digest issue (one line per item: decision,
   tracking issue), add the label `triaged` and close it.
7. Caps, so one bad day cannot run away with the run: at most 15 new tracking
   issues per run. If there are more, open the 15 most severe, and make the
   rest one issue `<date>: feedback overflow` (`bug`, `sev2`) that lists them.

## Step 3: game metrics

Every game counts its own players and Robux, and the **Studio scoreboard**
workflow (06:41 UTC) rewrites the open issue labelled `daily-metrics` from
those counters (`ops/METRICS.md`). Roblox's own dashboards and the group's
revenue pages need Alex's signed-in session, which Claude never uses.

- **Until the games are live** (no `daily-metrics` issue, or every game says
  "not live"): write "metrics: not live yet" in the heartbeat and skip this
  step.
- **Once it exists,** read the issue and its `<!-- loop-lab-metrics v1 ... -->`
  block. If the issue was not updated today, check the workflow run (step 1).
  For each live game look at:
  - the **next-wave gate** (`gate.pass`): 14 days after launch, 7-day D1 at
    least 25%, average session 10+ minutes, players rising 3 days in a row.
    reported to Alex through step 3b's For Alex list (one message, not two);
  - the **kill signal** (`kill: true`): 7-day D1 under 15% after 7 days.
    Reported to Alex through step 3b's For Alex list; stopping a game is
    Alex's call;
  - **regressions and release drops** are computed by the update plan
    (step 3b); act on them there.
  - the block's analytics fields (friends, where Robux is spent,
    onboarding, events) are read by the update plan; this run only checks
    they are there.

## Step 3b: the update loop

The **Update plan** workflow (after the scoreboard, 07:03 UTC at the
latest) rewrites the open issue labelled `update-plan` with each game's focus
for the week, the signals behind it, a check on the latest Production
release and a **For Alex** list; the same data is in its
`<!-- loop-lab-plan v1 ... -->` block. `ops/UPDATE_LOOP.md` is the whole loop;
this step is the daily run's part of it.

**A stale plan is never acted on.** If the issue was not updated today (the
GitHub schedules do not always fire), dispatch **Studio scoreboard**
(`env: production`), then **Update plan**, and read the plan once both
finish. If it still cannot be produced, skip this step's urgent checks and
For Alex items, write "plan stale" in the heartbeat, and treat the failing
workflow like any other in step 1. Yesterday's release-drop signal must not
become today's rollback question.

**Every day:**

- **urgent** signals, handled before the rest of this step:
  - `release drop`: ask Alex in the thread whether to roll back, with the
    plan's numbers, the previous tag it names and the **Publish to
    Production** workflow link (`ref` = that tag). Also open or update a
    `bug`, `<game>`, `sev1` issue and route it like a bug (step 2.4).
  - `regression`: open a `bug`, `<game>`, `sev1` issue titled
    `<game>: <metric> down <n>% on <day>` with the plan's numbers, and route
    it like a bug. The fixer looks for the cause (a Roblox outage counts; say
    so and close it).
  - `open sev1`: already routed by step 2; check it has an owner.
- **For Alex** items (gate passed, kill signal): tell Alex once per game and
  item. Record it in the switch database, collection `agent`, document
  `runstate`, field `loopAsks` (`{ "<game>:<kind>": <epoch ms> }`), and ask
  again only if the item is still there 7 days later.

**Mondays:** send the plan to the loop owner thread "Run the update loop from
metrics" (one message: each game's focus and why, last week's release
verdicts, the top ideas from step 2.5). The owner opens the week's update
issues and gets builders started.

**Fridays:** list open issues labelled `update` and `ready-for-production`.
If there are any, send Alex **one** message: per game, the update, its
commit, that the Staging checks passed, and the **Publish to Production**
link. Hotfixes are asked for as soon as they are ready, not on Fridays.

Under a **publish hold**, send no Production asks (a rollback question still
goes, with the hold mentioned) and tell the owner "no merges".

## Step 4: what is waiting on Alex

Earning Robux is blocked until the games are on Roblox, and only Alex can
create experiences and keys. Each run works out what is still open from what
it can see (it cannot see secrets):

- ids: zeros in `ops/environments.json`;
- publish keys: the latest **Publish to Staging** run says "Skipped ...
  not set up" for a game that has ids;
- read-only key: the **Player feedback** run says `ROBLOX_READ_API_KEY is
  not set`;
- anything Alex said in the project is done counts as done.

Then:

- If any step Alex owns is still open, and the last reminder was 3 or more
  days ago (the `agent/runstate` document, field `lastNudgeAt`), post one
  short message in the thread: the single next step, where to do it, and how
  long it takes. Then update `lastNudgeAt`.
- Never ask for, accept or handle a password, cookie, 2FA code or API key
  value. Keys go straight from the Creator Dashboard into GitHub secrets.

## Step 5: weekly summary (Mondays)

On Mondays, post one summary in the thread (under 15 lines). Lead with the
**score**: Robux since 2026-11-01 and over the last 7 days (with the week
before for comparison), best and worst game by Robux and by D1. Then: reports
and average fun per game, bugs opened and fixed by severity, top ideas, each
game against the gate, each game's update focus this week and last week's
release verdict, and what is waiting on Alex. Link the scoreboard and the
update plan issues.

## Step 6: the heartbeat (always last)

Write the switch database, collection `agent`, document `heartbeat`:
`{ at: <epoch ms>, summary: "<one line>" }`, for example
`Ran: 1 digest, 7 reports, 2 bugs (1 sev2 → #41), 412 Robux yesterday, 2 Alex steps open`.
The switch page warns Alex when no heartbeat arrives for 36 hours, so a run
that crashes halfway shows up there.

## Talking to Alex

Post in the thread only when Alex should know or act: a sev1, a tripped
switch, an unreadable switch, a rollback question or a For Alex item (step
3b), the Friday Production ask, a reminder (step 4) or the Monday summary.
Otherwise end the run quietly. Keep messages under 80 words.

## Tripping the switch

Update `control/state`, pinned to the version just read: `paused: true`,
`note: <reason>`, `changedAt: <now>`, `changedBy: "claude"`, and prepend
`{ at, kind: "pause", note, by: "claude" }` to `history` (keep the latest
20). Then tell Alex in the thread. Only Alex resumes.
