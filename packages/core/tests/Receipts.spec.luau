--!strict
local DataService = require("@core/DataService")
local Economy = require("@core/Economy")
local Fakes = require("./Fakes")
local Receipts = require("@core/Receipts")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local PRODUCT = 1111

local function setup(persistResult: () -> boolean)
	local store = Fakes.store()
	local data = DataService.new({
		store = store,
		template = { version = 1, coins = 0, receipts = {} },
		migrations = {},
	})
	local changes = 0
	local economy = Economy.new({
		data = data,
		currencies = { coins = { field = "coins", max = 1e12 } },
		onChange = function()
			changes += 1
		end,
	})
	local players: { [number]: any } = {}
	local granted = {}
	local receipts = Receipts.new({
		data = data,
		economy = economy,
		findPlayer = function(userId)
			return players[userId]
		end,
		persist = function()
			return persistResult()
		end,
		onGranted = function(_player, key, robux)
			table.insert(granted, { key, robux })
		end,
		maxStored = 3,
	})
	receipts:register("CoinPack", PRODUCT, function(_player, _d, ledger)
		ledger:add("coins", 1000, "IAP:CoinPack")
	end)
	local p = Fakes.player(7)
	players[7] = p
	data:load(p, 7)
	return receipts, data, p, players, granted, function()
		return changes
	end
end

local function receipt(id: string)
	return { PlayerId = 7, ProductId = PRODUCT, PurchaseId = id, CurrencySpent = 49 }
end

describe("Receipts", function()
	it("grants once and records the purchase id", function()
		local receipts, data, p, _, granted, changes = setup(function()
			return true
		end)
		expect(receipts:process(receipt("A"))).toBe("PurchaseGranted")
		expect((data:get(p) :: any).coins).toBe(1000)
		expect(changes()).toBe(1)
		expect(#granted).toBe(1)
		expect(granted[1][2]).toBe(49)
	end)

	it("repeat receipts for the same purchase grant only once", function()
		local receipts, data, p = setup(function()
			return true
		end)
		for _ = 1, 5 do
			expect(receipts:process(receipt("A"))).toBe("PurchaseGranted")
		end
		expect((data:get(p) :: any).coins).toBe(1000)
	end)

	it("a failed save means Roblox retries later, and the retry does not double-grant", function()
		local saveWorks = false
		local receipts, data, p = setup(function()
			return saveWorks
		end)
		expect(receipts:process(receipt("A"))).toBe("NotProcessedYet")
		saveWorks = true
		expect(receipts:process(receipt("A"))).toBe("PurchaseGranted")
		expect((data:get(p) :: any).coins).toBe(1000)
	end)

	it("waits when the player is not in this server or not loaded", function()
		local receipts, _, _, players = setup(function()
			return true
		end)
		players[7] = nil
		expect(receipts:process(receipt("A"))).toBe("NotProcessedYet")
	end)

	it("never grants an unknown product", function()
		local receipts = setup(function()
			return true
		end)
		expect(receipts:process({ PlayerId = 7, ProductId = 999, PurchaseId = "Z" })).toBe("NotProcessedYet")
	end)

	it("a grant that errors leaves data unchanged", function()
		local receipts, data, p = setup(function()
			return true
		end)
		receipts:register("Broken", 2222, function(_player, d)
			d.coins = 5
			error("bug in grant")
		end)
		expect(receipts:process({ PlayerId = 7, ProductId = 2222, PurchaseId = "B" })).toBe("NotProcessedYet")
		expect((data:get(p) :: any).coins).toBe(0)
		expect(#(data:get(p) :: any).receipts).toBe(0)
	end)

	it("keeps only the most recent purchase ids", function()
		local receipts, data, p = setup(function()
			return true
		end)
		for _, id in { "1", "2", "3", "4" } do
			receipts:process(receipt(id))
		end
		expect((data:get(p) :: any).receipts).toEqual({ "2", "3", "4" })
	end)

	it("refuses unconfigured product ids and duplicates", function()
		local receipts = setup(function()
			return true
		end)
		expect(function()
			receipts:register("Unset", 0, function() end)
		end).toThrow("real product id")
		expect(function()
			receipts:register("Again", PRODUCT, function() end)
		end).toThrow("twice")
	end)
end)
