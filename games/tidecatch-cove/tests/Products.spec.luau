--!strict
-- The Robux products' grants and the shop's catalog, run through the core's
-- real receipt handler (exactly once, saved with the receipt).
local Receipts = require("@core/Receipts")
local Catch = require("../src/shared/Catch")
local Cove = require("../src/shared/Cove")
local Creatures = require("../src/shared/Creatures")
local Products = require("../src/shared/Products")
local Fakes = require("../../../packages/core/tests/Fakes")
local Harness = require("./Harness")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local config = Harness.config
local NO_PERKS = { autoReel = false, extraPools = false, sellMultiplier = false }

-- A Tidecatch server with every product registered, the way Shop.luau does.
local function setup(options: { restricted: boolean?, mystery: string? }?)
	local opts = options or {}
	local h = Harness.new({ restricted = opts.restricted })
	h.odds:define(Catch.mysteryTable(config.monetization))
	local notices: { string } = {}
	local grants = Products.grants({
		config = config,
		now = function()
			return math.floor(h.time)
		end,
		rollMystery = function(player: any): string?
			if opts.mystery then
				return opts.mystery
			end
			return (h.odds:rollPaid(Catch.MYSTERY_TABLE, player, h.policy))
		end,
		notify = function(_player: any, text: string)
			table.insert(notices, text)
		end,
	})
	local receipts = Receipts.new({
		data = h.data,
		economy = h.economy,
		findPlayer = function()
			return h.player
		end,
		persist = function()
			return true -- the fake store saves at once
		end,
	})
	for key in config.monetization.products do
		receipts:register(key, 0, grants[key])
	end
	local player = Fakes.player(40)
	h.join(player)
	return h, receipts, player, notices
end

describe("Tidecatch Cove products", function()
	it("every product has a grant, and the catalog lists every product and pass", function()
		local grants = Products.grants({
			config = config,
			now = os.time,
			rollMystery = function()
				return nil
			end,
			notify = function() end,
		})
		local listed: { [string]: string } = {}
		for _, item in Products.catalog(config) do
			listed[item.key] = item.kind
		end
		for key in config.monetization.products do
			expect(type(grants[key])).toBe("function")
			expect(listed[key]).toBe("product")
		end
		for key in config.monetization.passes do
			expect(listed[key]).toBe("pass")
		end
	end)

	it("lists Mystery Bait as a paid random item with readable odds labels", function()
		for _, item in Products.catalog(config) do
			local random = item.key == "MysteryBait"
			expect(item.paidRandom == true).toBe(random)
			expect(item.oddsTable ~= nil).toBe(random)
			if random then
				expect(item.oddsTable).toBe(Catch.MYSTERY_TABLE)
				local labels = item.oddsLabels :: { [string]: string }
				for _, o in config.monetization.mysteryBait do
					expect(labels[o.id]).toBe(`{o.count} {Catch.displayName(o.bait)}s`)
				end
			end
		end
	end)

	it("a Bait Pack gives its Robux-only bait exactly once, even when Roblox retries", function()
		local h, receipts, player, notices = setup()
		local pack = config.monetization.products.BaitPack
		local decision, fresh = receipts:grant(player, "BaitPack", "p-1")
		expect(decision).toBe("PurchaseGranted")
		expect(fresh).toBe(true)
		expect(h.get(player).bait[pack.bait]).toBe(pack.count)
		local again, freshAgain = receipts:grant(player, "BaitPack", "p-1")
		expect(again).toBe("PurchaseGranted")
		expect(freshAgain).toBe(false)
		expect(h.get(player).bait[pack.bait]).toBe(pack.count)
		expect(notices[1]).toBe(`You got {pack.count} Storm Lures!`)
		-- Casting with it is a paid roll for an unrestricted player.
		expect(h.odds:display(Catch.tableId("Shallows", pack.bait), player).paid).toBe(true)
		expect(h.actions:cast(player, "Shallows", pack.bait)).toBe(true)
		expect(h.get(player).bait[pack.bait]).toBe(pack.count - 1)
	end)

	it("Mystery Bait rolls its paid table and gives that bundle", function()
		local h, receipts, player, notices = setup()
		receipts:grant(player, "MysteryBait", "m-1")
		local d = h.get(player)
		local given = 0
		for _, o in config.monetization.mysteryBait do
			given += (d.bait[o.bait] or 0)
		end
		expect(given > 0).toBe(true)
		expect(string.find(notices[1], "^Mystery Bait: ") ~= nil).toBe(true)
	end)

	it("Mystery Bait gives exactly the outcome rolled", function()
		local h, receipts, player = setup({ mystery = "PearlLureX5" })
		receipts:grant(player, "MysteryBait", "m-2")
		expect(h.get(player).bait.PearlLure).toBe(5)
		expect(h.get(player).bait.StormLure or 0).toBe(0)
	end)

	it("Mystery Bait falls back to the smallest bundle if the policy says no after paying", function()
		local h, receipts, player = setup({ restricted = true })
		receipts:grant(player, "MysteryBait", "m-3")
		local first = config.monetization.mysteryBait[1]
		expect(h.get(player).bait[first.bait]).toBe(first.count)
	end)

	it("Growth Boost grows every pooled creature, and keeps grown ones grown", function()
		local h, receipts, player, notices = setup()
		h.economy:add(player, "coins", 1e6, "Admin:Test")
		h.data:update(player, function(d)
			Cove.land(d, h.economy:ledger(player, d), {
				speciesId = "SandShrimp",
				kg = 0.2,
				mutation = "None",
				spotId = "Shallows",
			}, math.floor(h.time), config, NO_PERKS)
		end)
		local uid = h.get(player).bucket[1].uid
		expect(h.actions:place(player, uid)).toBe(true)
		local now = math.floor(h.time)
		local before = Creatures.stage(h.get(player).pools[1], now, config.species, config.pools)
		receipts:grant(player, "GrowthBoost", "g-1")
		local after = Creatures.stage(h.get(player).pools[1], now, config.species, config.pools)
		expect(after).toBe(before + config.monetization.products.GrowthBoost.stages)
		expect(notices[#notices]).toBe("Growth Boost! 1 creature grew.")
		for i = 2, 10 do
			receipts:grant(player, "GrowthBoost", `g-{i}`)
		end
		local pooled = h.get(player).pools[1]
		expect(Creatures.stage(pooled, now, config.species, config.pools)).toBe(#config.pools.stages)
		expect(Creatures.grown(pooled, now, "Common", config.pools)).toBe(
			Creatures.growthSeconds("Common", config.pools)
		)
		expect(notices[#notices]).toBe("Growth Boost saved: your pools were empty or fully grown.")
	end)

	it("Restock Skip puts the bait shop back in stock for this player", function()
		local h, receipts, player = setup()
		h.economy:add(player, "coins", 1e6, "Admin:Test")
		local worm = Catch.bait(config.fishing, "Worm") :: any
		expect(h.actions:buyBait(player, "Worm", worm.stock)).toBe(true)
		expect(h.actions:buyBait(player, "Worm", 1)).toBeFalsy()
		receipts:grant(player, "RestockSkip", "r-1")
		expect(h.actions:buyBait(player, "Worm", worm.stock)).toBe(true)
	end)

	it("Robux-only bait is never sold for coins", function()
		local h, _receipts, player = setup()
		h.economy:add(player, "coins", 1e6, "Admin:Test")
		expect(h.actions:buyBait(player, "StormLure", 1)).toBeFalsy()
		expect(h.notices[#h.notices]).toBe("That bait comes only from Bait Packs and Mystery Bait.")
	end)
end)
