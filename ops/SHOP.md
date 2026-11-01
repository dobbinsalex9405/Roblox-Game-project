# Shop, Robux purchases and the Studio test panel

All four games share one shop and one test panel from `packages/core`. This
page covers how a game wires its products, where the Roblox ids go, and how
to test purchases in Studio.

## Testing purchases in Studio (the test panel)

Open the place in Studio and press **Play**. Two buttons sit in the top bar:
**Shop** and a purple **Test** button. The Test button only exists in Studio.
A live server never listens to it, and a Studio server only accepts it from
Studio's test players or the place's creator (or the owner of the group that
owns it).

| Panel section | Button | What it does |
| --- | --- | --- |
| Currency | `+1K`, `+100K`, `+10M`, `-1K` | Adds (or spends) that much of the game's currency. |
| Game passes | `Give` / `Remove` | Owns or stops owning a pass **for this session only**. Nothing is saved; the next join asks Roblox again. |
| Products | `Buy` | Runs the product through the **real receipt path** with a new fake purchase id: the same code a Robux purchase runs, saved exactly once. |
| Products | `Replay` | Sends the **same** purchase id again, as Roblox does when it retries. The panel should say "nothing was given twice. Exactly-once works." Any other answer is a bug. |
| Save | `Reset my save` (tap twice) | Wipes your save back to a brand-new player and ends the test. Press Play again to start fresh. |

What the panel cannot test: Roblox's own purchase window. That needs the
place published to an experience with the product created (see below). In
Studio, Roblox shows a test purchase window and charges nothing.

## Real purchases (Staging, then Production)

1. Create the passes and developer products on the experience in the Creator
   Hub (prices are set there, and need Alex's approval).
2. Put each id under `environments.staging` (or `.production`) in the game's
   `config/monetization.luau`. Keys you leave out stay 0 there, and an item
   with id 0 is never prompted.
3. `tools/build.sh` stamps the build with `BUILD_ENVIRONMENT` (dev, staging or
   production). The publish workflows set it, and `Monetization.resolve` picks
   the matching ids.

## Wiring a game's products (for game code)

```lua
local Monetization = require(ReplicatedStorage.Core.Monetization)
local ids = Monetization.resolve(monetization, Build.environment)

local services = CoreServer.start({ ..., passes = ids.passes, ... })

-- Register every product the game can deliver, even while its id is 0,
-- so the test panel can run it. Grants run inside a data update: change
-- `data` or use `ledger`, never yield.
services.receipts:register("CashPackSmall", ids.products.CashPackSmall, function(player, data, ledger)
	ledger:add("cash", 5000, "IAP:CashPackSmall")
end)

-- Then list what the shop shows. Items with random results must name the
-- odds table to show first, and set paidRandom (players PolicyService
-- restricts cannot buy them).
services.shop:setCatalog({
	{ key = "CashPackSmall", kind = "product", name = "5K Cash", description = "Adds 5,000 cash." },
	{ key = "DoubleCash", kind = "pass", name = "Double Cash", description = "Every sale pays double." },
	{ key = "MysteryBait", kind = "product", name = "Mystery Bait", description = "...",
		oddsTable = "MysteryBait", paidRandom = true,
		-- Optional: names to show for outcome ids (the raw id shows otherwise).
		oddsLabels = { StormLurex3 = "3 Storm Lures" } },
})
```

The server re-checks every Buy before opening Roblox's prompt. It refuses an
item with id 0, a pass already owned, and a paid random item for restricted
players. It also refuses a random item whose odds the player has not seen in
the last 10 minutes; the shop's "Show odds" button counts.
