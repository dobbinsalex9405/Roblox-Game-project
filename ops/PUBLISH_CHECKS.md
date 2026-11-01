# Publish checks: before and after every Staging or Production publish

CI proves a pull request is sound. Publishing needs two more things: proof
that the exact file being uploaded starts and plays (the **pre-publish gate**),
and proof that it behaves on real Roblox once it is live (the **post-publish
checks**). This page defines both. The gate is automated in the publish
workflows; the post-publish checks are partly automated and partly a short
join on the live experience, and nothing moves to Production until they pass
on Staging.

## What runs where

| Check | What it proves | PR (CI) | Staging publish | Production publish | After publish |
|---|---|---|---|---|---|
| Format, lint, strict types | the code is well-formed | yes | (already passed on `main`) | (already passed on `main`) | |
| Unit tests `lune run tools/test/run` | pure logic, config, save data, odds | yes | yes | yes | |
| Build `tools/build.sh` | Rojo project resolves, environment stamp written | yes (dev) | yes (staging) | yes (production) | |
| **Boot check** `lune run tools/boot/run --built <game>` | the built place starts its server, a player can join, the client UI starts, a player can leave | yes, every game | yes, the uploaded file | yes, the uploaded file | |
| **Key flows** `tools/keyflows.sh <game>` | the main loop plays through headless: every system check in `playtests/<game>/checks.luau` passes | yes, every game | yes | yes | |
| Version read-back | Roblox accepted the upload and reports the new place version | | yes (run summary) | yes (summary + git tag) | |
| **Live join** (below) | the version behaves on real Roblox: loads, plays, saves, sells | | | | within 1 hour of a Staging publish; before and right after a Production publish |
| **Error-queue sweep** (below) | no server or client error from the new build | | | | 1 hour and 24 hours after a publish |

A red step in the gate stops the publish: the workflow never reaches the
upload. A red post-publish check stops promotion to Production, or triggers a
Production rollback (re-run **Publish to Production** with the previous
`<game>/production/v<n>` tag).

## Pre-publish gate (automated)

Both publish workflows run these on the commit being published, after the
build and before the upload:

1. **Tests.** `lune run tools/test/run`.
2. **Build** with `BUILD_ENVIRONMENT` set, so the place carries the right
   product and game pass ids for that environment.
3. **Boot check** on the built file: `lune run tools/boot/run --built <game>`.
   It loads `build/<game>.rbxl` under Lune with a thin Roblox shim
   (`tools/boot/shim.luau`), runs every server Script in
   `ServerScriptService`, waits for start-up to settle, joins one player
   (character, PlayerGui, Backpack, `PlayerAdded`), runs the client
   LocalScripts against the same tree, then removes the player. Any error in
   start-up, a deferred task, a signal handler or a remote handler fails the
   check. It caught the Street Food Empire start-up assert that reached `main`
   on 2026-11-01, which the unit tests and the headless playtests could not
   see because neither runs the real `init.server` entry point.
4. **Key flows** on the same commit: `tools/keyflows.sh <game>` runs
   `playtests/<game>/checks.luau`, the headless playtest that plays the main
   loop through the game's own Actions on an in-memory store (first purchase,
   core loop, selling, upgrades, passes, rejoin, exploit refusals). It exits
   non-zero on any `[BUG]`. Every game must have one; a game without it cannot
   be published.

Production adds: the ref must already be on `main`, and Alex must click
Approve on the `production` environment.

What the gate cannot do: judge how anything looks, moves or sounds, or talk to
real Roblox services. That is what the post-publish checks are for.

## Post-publish checks

### 1. Version read-back (automated, in the workflow)

The publish tool prints the place version Roblox returned and writes it to the
run summary. Production also tags the commit `<game>/production/v<version>`.
If the summary shows no version, the publish did not happen; nothing else
applies.

### 2. Live join (a person, or Claude on Alex's laptop by Remote Control)

Within an hour of a Staging publish, and again right after a Production
publish, join the experience with the studio's Roblox account and work
through the list below. Use a phone-sized window for at least the UI items
(Studio's device emulator, or resize the Player window to about 360x640).
Note anything odd in the project thread with the game, version and step.

**Every game**

- The place loads with no red error toast and the HUD, the Shop button and the
  Feedback button are all visible and not overlapping at phone size.
- The Shop opens, every item shows a price, and every paid random item shows
  its exact odds (totalling 100%). The Studio-only Test panel is **absent**.
- A purchase prompt appears and can be cancelled with no change to coins or
  inventory. (Do not complete a Robux purchase on Production unless testing a
  refund path on purpose; Staging purchases are free test prompts.)
- Send one piece of feedback through the Feedback button; it is accepted and
  the button rate-limits a second send.
- Leave and rejoin: progress is exactly as it was (coins, inventory, upgrades).
- The join and the leave each appear in the server's output with no warning
  that mentions `ProfileStore`, `DataStore`, `remote` or `drop`.

**Hatchery Heist**: buy and hatch a Basic egg; place the creature; collect
coins from a pad; ride a mount; steal from a neighbour's base and get caught
once; the belt and the raid timer both move.

**Tidecatch Cove**: buy bait; cast; hook on the bite; reel a fish in; put it
in a pool; see it grow after waiting; sell it; buy the next rod.

**Street Food Empire**: hand-serve the first customers; hire a Trainee; buy
the second stall; collect from the register; hit the queue cap on the counter
and see customers leave, not stack.

**Depthbound**: dive with the starting lamp; mine ore in reach; climb out with
a margin; sell; buy the Rucksack; see the lamp refill at camp; let the lamp
run out once and confirm the ore is lost but the save is fine.

### 3. Error-queue sweep (automated by the daily run, or by hand)

Servers write errors and feedback to the `ErrorQueue` DataStore once per
minute at most (`packages/core/src/ErrorReporter.luau`), tagged with the build
commit. One hour and 24 hours after a publish, list the entries written since
the publish and read the ones whose `build` equals the published commit:

- Any **server** error record: stop. Fix forward on Staging, or roll
  Production back.
- **Client** error records with `count` under 10 across all servers: open an
  issue, keep going. 10 or more: treat as a server error.
- Feedback records: triage in the feedback thread as usual.

Reading the queue needs the game's API key with DataStore read on that
environment (`ops/SETUP.md` step 2); the daily run does this with the keys
GitHub already holds, never from a laptop.

### 4. Production only: the first 24 hours

Alongside the sweep, look at the experience's Developer Stats the next day:
visits, average session length and the crash/error rate against the day
before. A drop of more than a third in session length, or an error rate that
doubled, is a rollback unless the cause is already known and fixed on
Staging.

## Promotion rule

A commit may go to Production only when, on Staging at the **same commit**,
the version read-back succeeded, the live join passed for that game, and the
24-hour sweep found no server error. The approver (Alex) checks these three
before clicking Approve; the production workflow records the commit and tag so
the check is reproducible.

## Not yet automated

- **Boot on real Roblox.** Open Cloud's Luau execution tasks can run a script
  on a server of a specific published place version. A task that requires the
  shared `Build` module, checks the commit stamp, loads every config module
  and touches `DataStoreService` would turn most of the live join's
  "it loads" items into a workflow step. It needs the API key to carry the
  Luau execution scope for that experience; add it when the keys are created.
- **The error-queue sweep in the publish workflows.** Today it belongs to the
  daily run (`ops/DAILY_RUN.md`), which already reads the queue. A delayed job
  in the publish workflow would need the same DataStore read scope.
