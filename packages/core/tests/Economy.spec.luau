--!strict
local DataService = require("@core/DataService")
local Economy = require("@core/Economy")
local Fakes = require("./Fakes")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local function setup()
	local data =
		DataService.new({ store = Fakes.store(), template = { version = 1, coins = 0 }, migrations = {} })
	local events: { Economy.Change } = {}
	local economy = Economy.new({
		data = data,
		currencies = { coins = { field = "coins", max = 1000 } },
		onChange = function(change)
			table.insert(events, change)
		end,
	})
	local p = Fakes.player(1)
	data:load(p, 1)
	return economy, data, p, events
end

describe("Economy", function()
	it("adds and spends with one event per change", function()
		local economy, _, p, events = setup()
		expect((economy:add(p, "coins", 100, "Gameplay:Hatch"))).toBe(true)
		expect((economy:spend(p, "coins", 40, "Shop:Egg"))).toBe(true)
		expect(economy:balance(p, "coins")).toBe(60)
		expect(#events).toBe(2)
		expect(events[1].flow).toBe("Source")
		expect(events[1].transactionType).toBe("Gameplay")
		expect(events[1].sku).toBe("Hatch")
		expect(events[2].flow).toBe("Sink")
		expect(events[2].balance).toBe(60)
	end)

	it("never goes negative and emits nothing on a refused spend", function()
		local economy, _, p, events = setup()
		economy:add(p, "coins", 10, "Gameplay:Hatch")
		local ok, err = economy:spend(p, "coins", 11, "Shop:Egg")
		expect(ok).toBe(false)
		expect(err).toContain("insufficient")
		expect(economy:balance(p, "coins")).toBe(10)
		expect(#events).toBe(1)
	end)

	it("caps at the currency max and reports only what was applied", function()
		local economy, _, p, events = setup()
		economy:add(p, "coins", 990, "Gameplay:Hatch")
		economy:add(p, "coins", 50, "Gameplay:Hatch")
		expect(economy:balance(p, "coins")).toBe(1000)
		expect(events[2].amount).toBe(10)
		economy:add(p, "coins", 50, "Gameplay:Hatch")
		expect(#events).toBe(2) -- nothing applied, nothing reported
	end)

	it("rejects bad amounts, unknown currencies and bad reasons without changing data", function()
		local economy, _, p, events = setup()
		for _, amount in { 0, -5, 1.5, 0 / 0, math.huge } do
			expect((economy:add(p, "coins", amount, "Gameplay:Hatch"))).toBe(false)
		end
		expect((economy:add(p, "gems", 5, "Gameplay:Hatch"))).toBe(false)
		expect((economy:add(p, "coins", 5, "no reason"))).toBe(false)
		expect(economy:balance(p, "coins")).toBe(0)
		expect(#events).toBe(0)
	end)

	it("ledger changes inside a failed update are never committed", function()
		local economy, data, p, events = setup()
		local ok = data:update(p, function(d)
			local ledger = economy:ledger(p, d)
			ledger:add("coins", 5, "IAP:CoinPack")
			error("grant blew up")
		end)
		expect(ok).toBe(false)
		expect(economy:balance(p, "coins")).toBe(0)
		expect(#events).toBe(0)
	end)
end)
