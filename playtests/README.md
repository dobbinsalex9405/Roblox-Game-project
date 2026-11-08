# Headless playtests

Scripts that play a game through its own server logic under Lune, without
Roblox: the real core services and the game's Actions on an in-memory
session-locked store with a hand-moved clock. Each game's `checks.luau` is the
**key-flow check**: CI and both publish workflows run it through
`tools/keyflows.sh`, and it exits non-zero on any `[BUG]`, so every game needs
one. The bot sessions and pacing runs are longer; run them by hand from the
repo root when a build changes the loop or the economy.

```sh
lune run playtests/hatchery-heist/checks.luau       # system-by-system checks (PASS / BUG / NOTE)
lune run playtests/hatchery-heist/run_session.luau  # 15-minute bot sessions and a 3-hour run
lune run playtests/hatchery-heist/pacing.luau       # belt cap and first-three-minutes pacing
```

Each game gets its own folder with a `Sim.luau` (the server), a bot and the
checks. Findings go into the playtest report doc for that game.

These scripts test the rules, not what a player sees. Every game change also
gets the player's-eye check in `ops/VISUAL_PLAYTEST.md` (rendered audit,
real-engine check, Studio play-solo).

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

## Street Food Empire (PR #5 branch)

These scripts require `games/street-food-empire` (the PR #5 branch, or main
once it merges). The game's own `tests/Harness.luau` is the server.

```sh
lune run playtests/street-food-empire/checks.luau       # system checks (PASS / BUG / NOTE), incl. hand-vs-register numbers
lune run playtests/street-food-empire/run_session.luau  # 15-minute bots (6 styles), 2-hour curves, 8-hour rebirth runs
```

`bot.luau` is the player: it stands at the counter and serves every customer,
collects the register, and leaves for six seconds per purchase. Styles differ
in how often they come back to the counter (`attentive`, `batcher` 60 s,
`casual` 180 s, `idle` 600 s), in what they buy (`attentiveRoi` picks by
payback time) and whether they hire at all (`handOnly`). Customers who find
the line full are counted as lost.

## Tidecatch Cove (PR #7 branch)

These scripts require `games/tidecatch-cove` (the PR #7 branch, or main once
it merges). The game's own `tests/Harness.luau` is the server.

```sh
lune run playtests/tidecatch-cove/checks.luau       # system checks (PASS / BUG / NOTE), incl. odds, reel and pool numbers
lune run playtests/tidecatch-cove/run_session.luau  # 15-minute bots (6 styles), seeds 1-5, 2-hour curves, a 3-hour return
```

`bot.luau` is the player: it casts at the best dock its rod allows, plays the
reel with 0.2 s of reaction lag, keeps or sells from the catch card, tends its
pools (feed, sell at a target stage, swap a weak pool for a better catch) and
shops, with walking time charged for every trip between the dock, the cove
and the island shop. Styles differ in what they keep (`keeper`, `grower`,
`rareOnly`, `seller`), how soon they sell a pool (`flipper`) and whether they
buy bait (`baitless`; the others buy only bait whose expected value beats its
price).
