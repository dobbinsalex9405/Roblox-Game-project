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
