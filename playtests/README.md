# Headless playtests

Scripts that play a game through its own server logic under Lune, without
Roblox: the real core services and the game's Actions on an in-memory
session-locked store with a hand-moved clock. They are not part of CI; run
them by hand from the repo root when a build changes the loop or the economy.

```sh
lune run playtests/hatchery-heist/checks.luau       # system-by-system checks (PASS / BUG / NOTE)
lune run playtests/hatchery-heist/run_session.luau  # 15-minute bot sessions and a 3-hour run
lune run playtests/hatchery-heist/pacing.luau       # belt cap and first-three-minutes pacing
```

Each game gets its own folder with a `Sim.luau` (the server), a bot and the
checks. Findings go into the playtest report doc for that game.

## Depthbound (PR #4 branch)

These scripts require `games/depthbound`, so run them on a checkout that has
the Depthbound build (the PR #4 branch, or main once it merges).

```sh
lune run playtests/depthbound/checks.luau       # system checks (PASS / BUG / NOTE), incl. mine hash statistics
lune run playtests/depthbound/run_session.luau  # 15-minute bots (4 styles x 5 seeds), a 4-player server, a 2-hour run
```

`bot.luau` is the player: it falls down its own shaft, takes visible ore in
reach, digs down while the pick allows, tunnels sideways at the deepest layer,
climbs with a margin or a full pack, sells and buys upgrades. Several bots run
in lockstep on one server (`Bot.Scheduler.run`), stepping every 0.2 s and
regrowing the mine every 15 s like the real server.
