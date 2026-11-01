--!strict
local Analytics = require("@core/Analytics")
local DataService = require("@core/DataService")
local Economy = require("@core/Economy")
local Fakes = require("./Fakes")
local Receipts = require("@core/Receipts")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local DAY = 86400

local function recordingSink()
	local events: { { any } } = {}
	local sink: Analytics.Sink = {
		economy = function(_p, flow, currency, amount, balance, transactionType, sku)
			table.insert(events, { "economy", flow, currency, amount, balance, transactionType, sku })
		end,
		onboarding = function(_p, step, name)
			table.insert(events, { "onboarding", step, name })
		end,
		funnel = function(_p, funnel, session, step, name)
			table.insert(events, { "funnel", funnel, session, step, name })
		end,
		progression = function(_p, path, status, level)
			table.insert(events, { "progression", path, status, level })
		end,
		custom = function(_p, name, value, fields)
			table.insert(events, { "custom", name, value, fields })
		end,
	}
	return sink, events
end

describe("Analytics", function()
	it("every purchase and currency change emits exactly one event", function()
		local sink, events = recordingSink()
		local analytics = Analytics.new(sink)
		local data = DataService.new({
			store = Fakes.store(),
			template = { version = 1, coins = 0, receipts = {} },
			migrations = {},
		})
		local economy = Economy.new({
			data = data,
			currencies = { coins = { field = "coins", max = 1e12 } },
			onChange = function(change)
				analytics:economy(change)
			end,
		})
		local p = Fakes.player(1)
		data:load(p, 1)
		local receipts = Receipts.new({
			data = data,
			economy = economy,
			findPlayer = function()
				return p
			end,
			persist = function()
				return true
			end,
			onGranted = function(player, key, robux)
				analytics:purchase(player, key, robux)
			end,
		})
		receipts:register("CoinPack", 5, function(_player, _d, ledger)
			ledger:add("coins", 100, "IAP:CoinPack")
		end)

		economy:add(p, "coins", 10, "Gameplay:Hatch")
		economy:spend(p, "coins", 5, "Shop:Egg")
		economy:spend(p, "coins", 500, "Shop:Egg") -- refused: no event
		receipts:process({ PlayerId = 1, ProductId = 5, PurchaseId = "x", CurrencySpent = 25 })
		receipts:process({ PlayerId = 1, ProductId = 5, PurchaseId = "x", CurrencySpent = 25 }) -- repeat: no event

		local economyEvents, purchaseEvents = 0, 0
		for _, e in events do
			if e[1] == "economy" then
				economyEvents += 1
			elseif e[1] == "custom" and e[2] == "Purchase:Product" then
				purchaseEvents += 1
				expect(e[3]).toBe(25)
				expect(e[4]).toEqual({ "CoinPack" })
			end
		end
		expect(economyEvents).toBe(3)
		expect(purchaseEvents).toBe(1)
	end)

	it("enforces the naming scheme", function()
		local analytics = Analytics.new((recordingSink()))
		local p = Fakes.player(1)
		expect(function()
			analytics:custom(p, "raid started", 1)
		end).toThrow("Area:Event")
		expect(function()
			analytics:custom(p, "Raid:Started", 1, { "a", "b", "c", "d" })
		end).toThrow("at most 3")
		analytics:custom(p, "Raid:Started", 1)
	end)

	it("sends each onboarding step once per session, in order", function()
		local sink, events = recordingSink()
		local analytics = Analytics.new(sink)
		local p = Fakes.player(1)
		analytics:onboarding(p, 1, "Joined")
		analytics:onboarding(p, 1, "Joined")
		analytics:onboarding(p, 2, "BoughtEgg")
		analytics:onboarding(p, 1, "Joined")
		expect(#events).toBe(2)
	end)

	it("emits retention markers on day 1, 7 and 30 only on the first join that day", function()
		local first = 100 * DAY + 3600
		expect(Analytics.retentionMarkers(0, 0, first)).toEqual({})
		expect(Analytics.retentionMarkers(first, first, first + 600)).toEqual({})
		expect(Analytics.retentionMarkers(first, first, first + DAY)).toEqual({ "Retention:D1" })
		expect(Analytics.retentionMarkers(first, first + DAY, first + DAY + 60)).toEqual({})
		expect(Analytics.retentionMarkers(first, first + DAY, first + 7 * DAY)).toEqual({ "Retention:D7" })
		expect(Analytics.retentionMarkers(first, first, first + 2 * DAY)).toEqual({})
		expect(Analytics.retentionMarkers(first, first + 29 * DAY, first + 30 * DAY)).toEqual({
			"Retention:D30",
		})
	end)

	it("reports session length in seconds", function()
		local sink, events = recordingSink()
		local analytics = Analytics.new(sink)
		local p = Fakes.player(1)
		local now = 50 * DAY
		analytics:sessionStart(p, { firstJoinAt = now - DAY, lastJoinAt = now - DAY }, now)
		expect(analytics:sessionEnd(p, now + 725.6)).toBe(725)
		local last = events[#events]
		expect(last[2]).toBe("Session:Length")
		expect(last[3]).toBe(725)
		local sawD1 = false
		for _, e in events do
			if e[2] == "Retention:D1" then
				sawD1 = true
			end
		end
		expect(sawD1).toBe(true)
		expect(analytics:sessionEnd(p, now + 900)).toBeNil()
	end)

	it("never lets a failing sink break gameplay", function()
		local sink = recordingSink()
		sink.custom = function()
			error("AnalyticsService throttled")
		end
		local analytics = Analytics.new(sink)
		analytics:custom(Fakes.player(1), "Raid:Started", 1)
	end)
end)
