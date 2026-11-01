--!strict
-- Every game's Robux listings: on the studio ladder, one per pass and product,
-- named as the shop names them, quoting the config's real numbers, and
-- written out in ops/PRICING.md exactly as the configs say.
local fs = require("@lune/fs")
local lib = require("../pricing/lib")
local loadGames = require("../pricing/games")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local games = loadGames()

local function byId(id: string): lib.Game
	for _, g in games do
		if g.id == id then
			return g
		end
	end
	error(`no game {id}`)
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	return (string.gsub(out, "^,", ""))
end

local function fakeGame(): lib.Game
	return {
		id = "fake",
		title = "Fake",
		packField = "coins",
		monetization = {
			passes = { DoubleCoins = 0 },
			products = { PackSmall = { id = 0, coins = 100 }, PackLarge = { id = 0, coins = 1000 } },
			listings = {
				passes = { DoubleCoins = { name = "Double Coins", robux = 199, description = "x2" } },
				products = {
					PackSmall = { name = "100 Coins", robux = 25, description = "100 coins" },
					PackLarge = { name = "1K Coins", robux = 99, description = "1,000 coins" },
				},
			},
		},
		catalog = { { key = "DoubleCoins", kind = "pass", name = "Double Coins" } },
	}
end

describe("pricing", function()
	it("every game's listings pass every pricing rule", function()
		expect(#games).toBe(4)
		for _, g in games do
			expect(table.concat(lib.problems(g), "\n")).toBe("")
		end
	end)

	it("ops/PRICING.md's table is what the configs say", function()
		local doc = fs.readFile("ops/PRICING.md")
		expect(lib.render(doc, lib.markdown(games)) == doc).toBe(true)
	end)

	it("lists every item the shops sell today", function()
		for _, g in games do
			local live = 0
			for _, row in lib.rows(g) do
				if row.live then
					live += 1
				end
			end
			expect(live).toBe(#g.catalog)
		end
	end)

	it("the ladder is cheapest first and tops out at 399", function()
		for i = 2, #lib.LADDER do
			expect(lib.LADDER[i].robux > lib.LADDER[i - 1].robux).toBe(true)
		end
		expect(lib.LADDER[#lib.LADDER].robux).toBe(399)
	end)

	it("catches a price off the ladder, a missing listing and a stray one", function()
		local g = fakeGame()
		g.monetization.listings.passes.DoubleCoins.robux = 250
		g.monetization.passes.AutoCollect = 0
		g.monetization.listings.products.Ghost = { name = "Ghost", robux = 25, description = "boo" }
		local text = table.concat(lib.problems(g), "\n")
		expect(text).toContain("DoubleCoins costs 250 Robux, which is not on the studio ladder")
		expect(text).toContain("passes.AutoCollect has no listing")
		expect(text).toContain("listings.products.Ghost is not one of the game's products")
	end)

	it("catches a shop name that differs from the listing", function()
		local g = fakeGame()
		g.catalog[1].name = "2x Coins"
		expect(table.concat(lib.problems(g), "\n")).toContain(
			`the shop calls it "2x Coins" but its listing says "Double Coins"`
		)
	end)

	it("catches a bigger pack that is worse value", function()
		local g = fakeGame()
		g.monetization.products.PackLarge.coins = 300 -- 3 per Robux, under the small pack's 4
		expect(table.concat(lib.problems(g), "\n")).toContain(
			"PackLarge gives less coins per Robux than PackSmall"
		)
	end)

	it("catches a name or description too long for Roblox", function()
		local g = fakeGame()
		g.monetization.listings.products.PackSmall.name = string.rep("a", 51)
		g.monetization.listings.products.PackLarge.description = string.rep("a", 1001)
		local text = table.concat(lib.problems(g), "\n")
		expect(text).toContain("PackSmall: name must be 1 to 50 characters")
		expect(text).toContain("PackLarge: description must be 1 to 1000 characters")
	end)

	it("descriptions quote the configs' real numbers", function()
		local function says(g: lib.Game, section: string, key: string, fragment: string)
			local description = g.monetization.listings[section][key].description
			assert(
				string.find(description, fragment, 1, true),
				`{g.title} {key}: description "{description}" should say "{fragment}"`
			)
		end
		local function minutes(seconds: number): string
			return `{seconds // 60} minutes`
		end

		local hh = byId("hatchery-heist")
		local raids = require("../../games/hatchery-heist/config/raids")
		local hhEconomy = require("../../games/hatchery-heist/config/economy")
		for _, key in { "CoinPackSmall", "CoinPackMedium", "CoinPackLarge" } do
			says(hh, "products", key, `{commas(hh.monetization.products[key].coins)} coins`)
		end
		says(hh, "products", "ShieldRefill", `{raids.shieldSeconds // 60} more minutes`)
		says(hh, "products", "LuckBoost", minutes(hh.monetization.boosts.LuckBoost.durationSeconds))
		expect(hhEconomy.incubators.passBonusSlots).toBe(2) -- "Two more incubators"
		says(hh, "passes", "ExtraIncubators", "Two more")

		local tc = byId("tidecatch-cove")
		local pack = tc.monetization.products.BaitPack
		expect(pack.bait).toBe("StormLure")
		says(tc, "products", "BaitPack", `{pack.count} Storm Lures`)
		expect(tc.monetization.products.GrowthBoost.stages).toBe(1) -- "grows one stage"
		says(tc, "products", "GrowthBoost", "one stage")
		expect(tc.monetization.sellMultiplier).toBe(2) -- "pays double"
		says(tc, "passes", "SellMultiplier", "double")

		local sfe = byId("street-food-empire")
		local sfeEconomy = require("../../games/street-food-empire/config/economy")
		for _, key in { "CashPackSmall", "CashPackMedium", "CashPackLarge" } do
			says(sfe, "products", key, `{commas(sfe.monetization.products[key].cash)} cash`)
		end
		local speed = sfe.monetization.boosts.SpeedBoost
		expect(speed.customerMultiplier).toBe(2) -- "twice as fast"
		says(sfe, "products", "SpeedBoost", minutes(speed.durationSeconds))
		expect(sfeEconomy.doubleCashMultiplier).toBe(2) -- "pays double"
		says(sfe, "passes", "DoubleCash", "double")

		local db = byId("depthbound")
		local ore = db.monetization.boosts.OreBoost
		expect(ore.sellMultiplier).toBe(2) -- "sells for double"
		says(db, "products", "OreBoost", minutes(ore.durationSeconds))
	end)

	it("Mystery Bait is never the worse deal than the Storm Lure Pack", function()
		-- What a Pearl Lure is worth in Storm Lures: its Epic and Legendary
		-- multipliers are about 2.5x a Storm Lure's (config/fishing.luau).
		local PEARL_IN_STORM = 2.5
		local m = byId("tidecatch-cove").monetization
		local total, average, least = 0, 0, math.huge
		for _, outcome in m.mysteryBait do
			total += outcome.weight
		end
		for _, outcome in m.mysteryBait do
			local worth = outcome.count * (if outcome.bait == "PearlLure" then PEARL_IN_STORM else 1)
			average += worth * outcome.weight / total
			least = math.min(least, worth)
		end
		local pack = m.products.BaitPack
		local mysteryPerRobux = average / m.listings.products.MysteryBait.robux
		local packPerRobux = pack.count / m.listings.products.BaitPack.robux
		expect(mysteryPerRobux >= packPerRobux).toBe(true)
		expect(least > 0).toBe(true)
	end)
end)
