# Core framework

Pure logic lives in `src/` and runs the same in Roblox and in Lune tests:
anything that touches a Roblox service is passed in, and the Roblox wiring
lives in `server/` and `client/`. Inside `src/`, modules require each other by
relative path (`require("./Log")`); everything else requires them by instance
(`require(ReplicatedStorage.Core.Log)`).

| # | Module | What it guarantees | Tests |
|---|--------|--------------------|-------|
| 1 | `Config` | Each game config file matches its schema; a bad number fails CI and start-up, never live play. Config is frozen once loaded. | `Config.spec`, each game's `Config.spec` |
| 2 | `Net` (+ `Schema`, `RateLimiter`) | The only client/server channel. Wrong types, extra arguments, unknown names and floods are dropped and counted per player. | `Net.spec`, `Schema.spec` |
| 3 | `DataService` | Session-locked load and save (ProfileStore), versioned migrations run step by step, a migration can never drop a key (retired keys are archived), data from a newer build is refused, updates are atomic and cannot yield. | `DataService.spec` |
| 4 | `Economy` | Server-owned currencies, whole amounts only, never negative, capped, one log line and one analytics event per change. | `Economy.spec` |
| 5 | `Receipts` | Developer products: the purchase id is saved with the grant, Roblox hears "granted" only after the save lands, repeats grant nothing. | `Receipts.spec` |
| 6 | `Passes` | Pass ownership by key, checked on join, live on purchase mid-session. Id 0 means not created yet and is never owned. | `Passes.spec` |
| 7 | `Odds` | Weights out of 10,000 so shown odds total exactly 100.00%. Screen and roll read one table; boosts and one-time exclusions recompute it. Paid tables only roll through `rollPaid`. | `Odds.spec` (incl. a 1M-roll check) |
| 8 | `Policy` | PolicyService per player, read once, fails closed. | `Policy.spec` |
| – | `Timers` | Progress from a saved start time with an optional offline cap; shared restock windows. | `Timers.spec` |
| 11 | `Analytics` | One naming scheme over AnalyticsService; session length and D1/D7/D30 return markers for the launch gate. | `Analytics.spec` |
| 12 | `ErrorReporter` | Errors grouped by signature, at most one queue write per server per minute, feedback cleaned and rate-limited. | `ErrorReporter.spec` |

Still to come, per the plan: 9 Plots (with Hatchery Heist M2), 10 Events,
13 UI kit and AgeCheck (with M5), plus movement checks (M4).

## Starting the core in a game

```lua
-- server
local services = CoreServer.start({
	game = "my-game", build = Build.commit, dataStoreName = "PlayerData_v1",
	template = DataTemplate.template, migrations = DataTemplate.migrations,
	currencies = { coins = { field = "coins", max = 1e15 } },
	passes = monetization.passes, oddsTables = oddsTables, remotes = Remotes,
})
services.receipts:register("CoinPack", productId, function(player, data, ledger)
	ledger:add("coins", 1000, "IAP:CoinPack")
end)
services.net:on(Remotes["MyGame:Collect"], function(player) ... end)

-- client
CoreClient.start()
```
