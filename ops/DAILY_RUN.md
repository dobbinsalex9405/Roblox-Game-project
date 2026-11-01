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
4. **Trip the switch yourself** (see "Tripping the switch") if a publish is
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

Roblox's revenue and engagement numbers live in the Creator Dashboard, and
the group's revenue pages need Alex's signed-in session, which Claude never
uses. So the run reads only what the studio's own code reports:

- **Until the games are live** (`ops/environments.json` production ids are 0,
  or there is no `daily-metrics` issue yet): write "metrics: not set up" in
  the heartbeat and skip this step.
- **Once a `daily-metrics` issue exists** (the planned workflow reads each
  game's own daily counters from a DataStore with the read-only key), read
  the latest one and check each live game against:
  - the **Wave 2 gate**, 14 days after launch: D1 retention at least 25%,
    average session 10+ minutes, players rising 3 days in a row;
  - **kill signals**: D1 under 15% after 7 days, or Robux per 1,000 sessions
    falling for 7 days. Flag them; deciding to stop a game is Alex's call.
  - **regressions**: a drop of 30% or more day over day in sessions, average
    session, or Robux right after a release points at that release. Open a
    `sev1` issue and route it like a bug.

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

On Mondays, post one summary in the thread (under 15 lines): reports and
average fun per game, bugs opened and fixed by severity, top ideas, metrics
against the gate, and what is waiting on Alex.

## Step 6: the heartbeat (always last)

Write the switch database, collection `agent`, document `heartbeat`:
`{ at: <epoch ms>, summary: "<one line>" }`, for example
`Ran: 1 digest, 7 reports, 2 bugs (1 sev2 → #41), metrics not set up, 2 Alex steps open`.
The switch page warns Alex when no heartbeat arrives for 36 hours, so a run
that crashes halfway shows up there.

## Talking to Alex

Post in the thread only when Alex should know or act: a sev1, a tripped
switch, an unreadable switch, a reminder (step 4) or the Monday summary.
Otherwise end the run quietly. Keep messages under 80 words.

## Tripping the switch

Update `control/state`, pinned to the version just read: `paused: true`,
`note: <reason>`, `changedAt: <now>`, `changedBy: "claude"`, and prepend
`{ at, kind: "pause", note, by: "claude" }` to `history` (keep the latest
20). Then tell Alex in the thread. Only Alex resumes.
