--!strict
-- Remotes for the shared shop (server/Purchases.luau) and the Studio-only test
-- panel (server/TestPanel.luau). The test remotes exist in every build but
-- only a Studio server listens to them.

local Net = require("./Net")
local Schema = require("./Schema")

local key = Schema.string({ maxLength = 50, pattern = "^[%a][%w_]*$" })
local source = Schema.string({ maxLength = 24, pattern = "^%u%w*$" })

local ShopRemotes = {
	-- Client -> server: what the shop sells here (answered with Shop:Catalog).
	["Shop:RequestCatalog"] = Net.toServer("Shop:RequestCatalog", {}, { count = 3, window = 5 }),
	-- Server -> client: the catalog (see Purchases.CatalogEntry).
	["Shop:Catalog"] = Net.toClient("Shop:Catalog", { Schema.any() }),
	-- Client -> server: buy a product or pass by key. The server checks
	-- everything and opens Roblox's purchase prompt. The optional third
	-- argument names where in the game the player pressed Buy ("Shop", or a
	-- game's own button such as "HudRefill"), so the scoreboard can show where
	-- Robux is spent (ops/METRICS.md).
	["Shop:Buy"] = Net.toServer(
		"Shop:Buy",
		{ Schema.oneOf({ "product", "pass" }), key, Schema.optional(source) },
		{ count = 3, window = 2 }
	),
	-- Server -> client: a short shop message (a refusal, "not on Roblox yet").
	["Shop:Notice"] = Net.toClient("Shop:Notice", { Schema.string({ maxLength = 200 }) }),

	-- Studio test panel. Client -> server: one command; see TestPanel.ACTIONS.
	["Test:Command"] = Net.toServer("Test:Command", {
		Schema.oneOf({ "info", "currency", "pass", "product", "replay", "reset", "game" }),
		Schema.string({ maxLength = 80 }),
		Schema.number({ min = -1e12, max = 1e12 }),
	}, { count = 10, window = 1 }),
	-- Server -> client: what the panel can do (currencies, passes, products).
	["Test:Info"] = Net.toClient("Test:Info", { Schema.any() }),
	-- Server -> client: the result of the last command, in words.
	["Test:Result"] = Net.toClient("Test:Result", { Schema.string({ maxLength = 300 }) }),
}

return ShopRemotes
