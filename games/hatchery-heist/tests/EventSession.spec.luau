--!strict
-- Timed events and the Giant Egg through the real Actions and core services
-- (tests/Harness): an Egg Sale halves what a market egg costs, Speedy
-- Incubators halve its hatch, a Money Rush pays double exactly while it
-- runs, and the Giant Egg gives today's Legendary once a cycle.
local Events = require("../src/shared/Events")
local Fakes = require("../../../packages/core/tests/Fakes")
local GiantEgg = require("../src/shared/GiantEgg")
local Harness = require("./Harness")
local eventsConfig = require("../config/events")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local config = Harness.config

local function fixed(kind: string?): () -> any
	return function()
		return Events.effectsOf(kind, eventsConfig)
	end
end

local function priceOf(eggId: string): number
	for _, egg in config.eggs do
		if egg.id == eggId then
			return egg.priceCoins
		end
	end
	error(`no egg {eggId}`)
end

local function hatchOf(eggId: string): number
	for _, egg in config.eggs do
		if egg.id == eggId then
			return egg.hatchSeconds
		end
	end
	error(`no egg {eggId}`)
end

describe("Timed events in play", function()
	it("an Egg Sale halves the price, and the purchase is counted for the event", function()
		local h = Harness.new({ effects = fixed("EggSale") })
		local player = Fakes.player(41)
		h.join(player)
		local before = h.get(player).coins
		local ok = h.buy(player, "BasicEgg")
		expect(ok).toBe(true)
		expect(before - h.get(player).coins).toBe(Events.price(priceOf("BasicEgg"), fixed("EggSale")()))
		expect(before - h.get(player).coins).toBe(priceOf("BasicEgg") / 2)
		local counted = h.eventsOf("custom")
		local found = false
		for _, args in counted do
			if args[1] == "Event:EggBought" and args[3][1] == "EggSale" and args[3][2] == "BasicEgg" then
				found = true
			end
		end
		expect(found).toBe(true)
	end)

	it("without an event the price, hatch time and telemetry are unchanged", function()
		local h = Harness.new({ effects = fixed(nil) })
		local player = Fakes.player(42)
		h.join(player)
		local before = h.get(player).coins
		h.buy(player, "BasicEgg")
		expect(before - h.get(player).coins).toBe(priceOf("BasicEgg"))
		local incubator = h.get(player).incubators[1]
		expect(incubator.readyAt - incubator.startedAt).toBe(hatchOf("BasicEgg"))
		for _, args in h.eventsOf("custom") do
			expect(args[1] ~= "Event:EggBought").toBe(true)
		end
	end)

	it("Speedy Incubators halve the hatch time of eggs bought during it", function()
		local h = Harness.new({ effects = fixed("FastHatch") })
		local player = Fakes.player(43)
		h.join(player)
		h.buy(player, "BasicEgg")
		local incubator = h.get(player).incubators[1]
		expect(incubator.readyAt - incubator.startedAt).toBe(math.ceil(hatchOf("BasicEgg") / 2))
	end)

	it("a Money Rush pays double for exactly the seconds it covers", function()
		local start = 1_800_000_000
		local rushFrom, rushTo = start + 100, start + 400
		local override = { kind = "MoneyRush", startsAt = rushFrom, endsAt = rushTo }
		-- The override's extra seconds alone (the schedule's own windows
		-- are taken out), so the test holds whatever day the clock is on.
		local function seconds(from: number, to: number): number
			return Events.incomeSeconds(from, to, eventsConfig, override)
				- Events.incomeSeconds(from, to, eventsConfig)
				+ (to - from)
		end
		local plain = Harness.new({ start = start })
		local rushed = Harness.new({ start = start, incomeSeconds = seconds })
		local a, b = Fakes.player(44), Fakes.player(45)
		plain.join(a)
		rushed.join(b)
		plain.actions:grantCreature(a, "Phoenix")
		rushed.actions:grantCreature(b, "Phoenix")
		plain.wait(a, 600)
		rushed.wait(b, 600)
		local pa, pb = plain.get(a).pendingCoins, rushed.get(b).pendingCoins
		expect(pa > 0).toBe(true)
		-- 600 s of income, 300 of them doubled: 900/600 of the plain pile.
		expect(math.abs(pb / pa - 1.5) < 1e-9).toBe(true)
	end)
end)

describe("Giant Egg", function()
	it("gives today's Legendary once a cycle and says when the next arrives", function()
		local h = Harness.new()
		local player = Fakes.player(46)
		h.join(player)
		local now = h.clock.now()
		local d = h.get(player)
		local status = GiantEgg.status(d, now, eventsConfig, config.creatures.species)
		expect(status.bought).toBe(false)
		expect(config.creatures.species[status.species :: string].rarity).toBe("Legendary")
		expect(GiantEgg.refusal(d, now, eventsConfig, config.creatures.species)).toBeNil()
		local creature: any, isNew = nil, false
		h.data:update(player, function(data)
			GiantEgg.record(data, status.cycle)
			local ledger = h.economy:ledger(player, data)
			creature, isNew = h.actions:giftInside(player, data, ledger, status.species, GiantEgg.EGG_ID)
		end)
		d = h.get(player)
		expect(creature.speciesId).toBe(status.species)
		expect(creature.eggId).toBe("GiantEgg")
		expect(creature.slot ~= nil).toBe(true) -- placed on a floor like a hatch
		expect(isNew).toBe(true)
		expect(d.found[status.species]).toBe(now)
		expect(d.giantEgg.bought).toBe(1)
		local refusal = GiantEgg.refusal(d, now, eventsConfig, config.creatures.species) :: string
		expect(refusal).toContain("You have today's Giant Egg")
		expect(refusal).toContain(Events.countdown(status.endsAt - now))
		-- The next cycle it can be bought again, and holds a different Legendary.
		local tomorrow = status.endsAt + 1
		expect(GiantEgg.refusal(d, tomorrow, eventsConfig, config.creatures.species)).toBeNil()
		local next = GiantEgg.status(d, tomorrow, eventsConfig, config.creatures.species)
		expect(next.cycle).toBe(status.cycle + 1)
		expect(next.species ~= status.species).toBe(true)
	end)

	it("prices it in coins for the event: the floor, or hours of income when that is more", function()
		local egg = eventsConfig.giantEgg
		expect(GiantEgg.coinPrice(eventsConfig, 0)).toBe(egg.coinPriceMin)
		local rich = egg.coinPriceMin -- coins a second, far above the floor's rate
		expect(GiantEgg.coinPrice(eventsConfig, rich)).toBe(rich * egg.coinPriceIncomeHours * 3600)
	end)

	it("sells today's Legendary for coins during the event, once a cycle", function()
		local h = Harness.new()
		local player = Fakes.player(47)
		h.join(player)
		local now = h.clock.now()
		local price = GiantEgg.coinPrice(eventsConfig, 0)
		local function buy(): (string?, string?)
			local got: string?, why: string? = nil, nil
			h.data:update(player, function(data)
				local ledger = h.economy:ledger(player, data)
				got, why =
					GiantEgg.buyWithCoins(data, ledger, now, eventsConfig, config.creatures.species, price)
				h.economy:commit(ledger)
			end)
			return got, why
		end
		-- Short of coins: refused, nothing taken, nothing recorded.
		local poor = h.get(player).coins
		local got, why = buy()
		expect(got).toBeNil()
		expect(why :: string).toContain("coins during the event")
		expect(h.get(player).coins).toBe(poor)
		expect(h.get(player).giantEgg.bought).toBe(0)
		-- With enough: today's Legendary, the price taken, the cycle recorded.
		h.data:update(player, function(data)
			data.coins += price
		end)
		local before = h.get(player).coins
		got, why = buy()
		local status = GiantEgg.status(h.get(player), now, eventsConfig, config.creatures.species)
		expect(why).toBeNil()
		expect(got).toBe(status.species)
		expect(before - h.get(player).coins).toBe(price)
		expect(status.bought).toBe(true)
		-- A second one the same cycle is refused and costs nothing.
		h.data:update(player, function(data)
			data.coins += price
		end)
		before = h.get(player).coins
		got, why = buy()
		expect(got).toBeNil()
		expect(why :: string).toContain("You have today's Giant Egg")
		expect(h.get(player).coins).toBe(before)
	end)

	it("refuses while the save is loading and keeps old saves working", function()
		local now = 1_800_000_000
		expect(GiantEgg.refusal(nil, now, eventsConfig, config.creatures.species)).toContain("loading")
		local old: { [string]: any } = {} -- a save from before the Giant Egg
		expect(GiantEgg.status(old, now, eventsConfig, config.creatures.species).bought).toBe(false)
		GiantEgg.record(old, 5)
		GiantEgg.record(old, 4) -- a late receipt never moves the cycle back
		expect(old.giantEgg.lastCycle).toBe(5)
		expect(old.giantEgg.bought).toBe(2)
	end)
end)
