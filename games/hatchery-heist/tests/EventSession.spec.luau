--!strict
-- Timed events and the Giant Egg through the real Actions and core services
-- (tests/Harness): an Egg Sale halves what a market egg costs, Speedy
-- Incubators halve its hatch, a Money Rush pays double exactly while it
-- runs, and the Giant Egg rolls an Epic or better once a cycle.
local Events = require("../src/shared/Events")
local Fakes = require("../../../packages/core/tests/Fakes")
local GiantEgg = require("../src/shared/GiantEgg")
local Harness = require("./Harness")
local Hatchery = require("../src/shared/Hatchery")
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

-- What the server's purchase does (src/server/GiantEgg.luau `picker`): a
-- policy-checked roll on the Giant Egg's odds table, or the fixed order.
local function picker(h: any, player: any): GiantEgg.Pick
	local egg = Hatchery.eggById(config.eggs, GiantEgg.EGG_ID)
	return function(boughtBefore: number): string?
		if not h.policy:paidRandomAllowed(player) then
			return Hatchery.fixedOrderOutcome(egg, boughtBefore)
		end
		return (h.odds:rollPaid(GiantEgg.EGG_ID, player, h.policy))
	end
end

local ABOVE_EPIC = { Epic = true, Legendary = true, Godly = true }

describe("Giant Egg", function()
	it("has far better odds than any other egg and nothing below Epic, exactly 100%", function()
		local egg = Hatchery.eggById(config.eggs, GiantEgg.EGG_ID)
		local byTier: { [string]: number } = {}
		local sum = 0
		for _, o in egg.outcomes do
			local rarity = config.creatures.species[o.id].rarity
			expect(ABOVE_EPIC[rarity]).toBe(true)
			byTier[rarity] = (byTier[rarity] or 0) + o.weight
			sum += o.weight
		end
		expect(sum).toBe(egg.total)
		-- Every tier from Epic up can hatch. The split itself is
		-- tools/economy/even_eggs.py's (target Epic 79.5%, Legendary 20%,
		-- Godly 0.5%, cut while a tier is thin), checked by CI's --check.
		expect((byTier.Epic or 0) > 0).toBe(true)
		expect((byTier.Legendary or 0) > 0).toBe(true)
		expect((byTier.Godly or 0) > 0).toBe(true)
		-- Every Epic, Legendary and Godly that any egg hatches is in it.
		for _, other in config.eggs do
			for _, o in other.outcomes do
				if ABOVE_EPIC[config.creatures.species[o.id].rarity] then
					local found = false
					for _, mine in egg.outcomes do
						found = found or mine.id == o.id
					end
					expect(found).toBe(true)
				end
			end
		end
		-- Better than the Premium Egg at every tier it shares.
		local premium = Hatchery.eggById(config.eggs, "PremiumEgg")
		local premiumTier: { [string]: number } = {}
		for _, o in premium.outcomes do
			local rarity = config.creatures.species[o.id].rarity
			premiumTier[rarity] = (premiumTier[rarity] or 0) + o.weight / premium.total
		end
		for _, rarity in { "Legendary", "Godly" } do
			expect(byTier[rarity] / egg.total > premiumTier[rarity]).toBe(true)
		end
	end)

	it("rolls an Epic or better once a cycle and says when the next is ready", function()
		local h = Harness.new()
		local player = Fakes.player(46)
		h.join(player)
		local now = h.clock.now()
		local d = h.get(player)
		local status = GiantEgg.status(d, now, eventsConfig)
		expect(status.bought).toBe(false)
		expect(GiantEgg.refusal(d, now, eventsConfig)).toBeNil()
		local creature: any, isNew = nil, false
		h.data:update(player, function(data)
			local speciesId = GiantEgg.open(data, status.cycle, picker(h, player)) :: string
			local ledger = h.economy:ledger(player, data)
			creature, isNew = h.actions:giftInside(player, data, ledger, speciesId, GiantEgg.EGG_ID)
		end)
		d = h.get(player)
		expect(ABOVE_EPIC[config.creatures.species[creature.speciesId].rarity]).toBe(true)
		expect(creature.eggId).toBe("GiantEgg")
		expect(creature.slot ~= nil).toBe(true) -- placed on a floor like a hatch
		expect(isNew).toBe(true)
		expect(d.found[creature.speciesId]).toBe(now)
		expect(d.giantEgg.bought).toBe(1)
		expect(d.eggsBought.GiantEgg).toBe(1)
		local refusal = GiantEgg.refusal(d, now, eventsConfig) :: string
		expect(refusal).toContain("You have today's Giant Egg")
		expect(refusal).toContain(Events.countdown(status.endsAt - now))
		-- The next cycle it can be bought again.
		local tomorrow = status.endsAt + 1
		expect(GiantEgg.refusal(d, tomorrow, eventsConfig)).toBeNil()
		expect(GiantEgg.status(d, tomorrow, eventsConfig).cycle).toBe(status.cycle + 1)
	end)

	it("follows the fixed order for a player who may not buy paid random items", function()
		local h = Harness.new({ restricted = true })
		local player = Fakes.player(48)
		h.join(player)
		local egg = Hatchery.eggById(config.eggs, GiantEgg.EGG_ID)
		local got: { string } = {}
		for cycle = 1, 3 do
			h.data:update(player, function(data)
				table.insert(got, GiantEgg.open(data, cycle, picker(h, player)) :: string)
			end)
		end
		for i, speciesId in got do
			expect(speciesId).toBe(Hatchery.fixedOrderOutcome(egg, i - 1))
		end
	end)

	it("prices it in coins for the event: the floor, or hours of income when that is more", function()
		local egg = eventsConfig.giantEgg
		expect(GiantEgg.coinPrice(eventsConfig, 0)).toBe(egg.coinPriceMin)
		local rich = egg.coinPriceMin -- coins a second, far above the floor's rate
		expect(GiantEgg.coinPrice(eventsConfig, rich)).toBe(rich * egg.coinPriceIncomeHours * 3600)
	end)

	it("sells it for coins during the event, once a cycle", function()
		local h = Harness.new()
		local player = Fakes.player(47)
		h.join(player)
		local now = h.clock.now()
		local price = GiantEgg.coinPrice(eventsConfig, 0)
		local function buy(): (string?, string?)
			local got: string?, why: string? = nil, nil
			h.data:update(player, function(data)
				local ledger = h.economy:ledger(player, data)
				got, why = GiantEgg.buyWithCoins(data, ledger, now, eventsConfig, price, picker(h, player))
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
		-- With enough: an Epic or better, the price taken, the cycle recorded.
		h.data:update(player, function(data)
			data.coins += price
		end)
		local before = h.get(player).coins
		got, why = buy()
		expect(why).toBeNil()
		expect(ABOVE_EPIC[config.creatures.species[got :: string].rarity]).toBe(true)
		expect(before - h.get(player).coins).toBe(price)
		expect(GiantEgg.status(h.get(player), now, eventsConfig).bought).toBe(true)
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
		expect(GiantEgg.refusal(nil, now, eventsConfig)).toContain("loading")
		local old: { [string]: any } = {} -- a save from before the Giant Egg
		expect(GiantEgg.status(old, now, eventsConfig).bought).toBe(false)
		local function any(): string?
			return "Phoenix"
		end
		GiantEgg.open(old, 5, any)
		GiantEgg.open(old, 4, any) -- a late receipt never moves the cycle back
		expect(old.giantEgg.lastCycle).toBe(5)
		expect(old.giantEgg.bought).toBe(2)
		expect(old.eggsBought.GiantEgg).toBe(2)
		-- Nothing to hatch: nothing recorded.
		local empty: { [string]: any } = {}
		expect(GiantEgg.open(empty, 6, function(): string?
			return nil
		end)).toBeNil()
		expect(empty.giantEgg).toBeNil()
	end)
end)
