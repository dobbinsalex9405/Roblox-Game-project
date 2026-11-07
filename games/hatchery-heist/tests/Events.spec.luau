--!strict
-- Timed events and the Giant Egg's daily pick (shared/Events.luau): one
-- window a cycle, the same on every server, inside the allowed hours, each
-- event once per round and never twice running, and the effects exact at the
-- window's edges.
local Events = require("../src/shared/Events")
local config = require("../config/events")
local creatures = require("../config/creatures")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local DAY = 86400
local NOV_7_2026 = 1794009600 -- 2026-11-07 00:00 UTC

local function legendaries(): { string }
	local ids = {}
	for id, s in creatures.species do
		if s.rarity == "Legendary" then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

describe("Events schedule", function()
	it("hashes deterministically and spreads the bits", function()
		expect(Events.hash(1, 2, 3)).toBe(Events.hash(1, 2, 3))
		expect(Events.hash(1, 2, 3) ~= Events.hash(1, 2, 4)).toBe(true)
		expect(Events.hash(1, 2, 3) ~= Events.hash(2, 2, 3)).toBe(true)
		-- Roughly uniform: 4,000 hashes into 4 buckets.
		local buckets = { 0, 0, 0, 0 }
		for i = 1, 4000 do
			local b = Events.hash(config.seed, 9, i) % 4 + 1
			buckets[b] += 1
			expect(Events.hash(config.seed, 9, i) < 2 ^ 32).toBe(true)
		end
		for _, n in buckets do
			expect(n > 850 and n < 1150).toBe(true)
		end
	end)

	it("turns cycles over at the configured hour", function()
		local noon = NOV_7_2026 + config.cycleStartHourUtc * 3600
		local before, beforeStart = Events.cycleOf(noon - 1, config)
		local at, atStart = Events.cycleOf(noon, config)
		expect(at).toBe(before + 1)
		expect(atStart).toBe(noon)
		expect(beforeStart).toBe(noon - DAY)
	end)

	it("puts one 30-minute window in every cycle, inside the allowed hours, on the step", function()
		local first = Events.cycleOf(NOV_7_2026, config)
		local starts: { [number]: boolean } = {}
		for cycle = first, first + 365 do
			local w = Events.window(cycle, config)
			local _, cycleStart = Events.cycleOf(w.startsAt, config)
			expect(Events.cycleOf(w.startsAt, config)).toBe(cycle)
			expect(w.endsAt - w.startsAt).toBe(config.windowMinutes * 60)
			local into = w.startsAt - cycleStart
			expect(into >= config.earliestHour * 3600).toBe(true)
			expect(into <= config.latestHour * 3600).toBe(true)
			expect(into % (config.startStepMinutes * 60)).toBe(0)
			expect(Events.cycleOf(w.endsAt - 1, config)).toBe(cycle)
			starts[into] = true
			-- Same answer every time (every server agrees).
			expect(Events.window(cycle, config).startsAt).toBe(w.startsAt)
			expect(Events.window(cycle, config).kind).toBe(w.kind)
		end
		-- The time really moves around.
		local distinct = 0
		for _ in starts do
			distinct += 1
		end
		expect(distinct > 100).toBe(true)
	end)

	it("runs every event once per round and never the same two cycles running", function()
		local n = #config.rotation
		local first = Events.cycleOf(NOV_7_2026, config)
		local counts: { [string]: number } = {}
		local last: string? = nil
		for cycle = first, first + 400 do
			local kind = Events.window(cycle, config).kind
			expect(config.kinds[kind] ~= nil).toBe(true)
			expect(kind ~= last).toBe(true)
			last = kind
			counts[kind] = (counts[kind] or 0) + 1
		end
		for _, kind in config.rotation do
			-- 401 cycles: about 100 each; a round of n holds each exactly once.
			expect(math.abs(counts[kind] - 401 / n) <= 2).toBe(true)
		end
		local round = (first // n + 1) * n
		local seen: { [string]: boolean } = {}
		for cycle = round, round + n - 1 do
			seen[Events.window(cycle, config).kind] = true
		end
		for _, kind in config.rotation do
			expect(seen[kind]).toBe(true)
		end
	end)

	it("rotates two or one entries without repeats", function()
		local prev = nil
		for cycle = 1, 20 do
			local pick = Events.rotationPick({ "A", "B" }, cycle, 5, 1)
			expect(pick ~= prev).toBe(true)
			prev = pick
			expect(Events.rotationPick({ "Solo" }, cycle, 5, 1)).toBe("Solo")
		end
	end)

	it("says what is active and what is next", function()
		local cycle = Events.cycleOf(NOV_7_2026, config)
		local w = Events.window(cycle, config)
		local before = Events.state(w.startsAt - 1, config)
		expect(before.active).toBeNil()
		expect(before.nextWindow.startsAt).toBe(w.startsAt)
		local during = Events.state(w.startsAt, config)
		expect((during.active :: any).kind).toBe(w.kind)
		expect(during.nextWindow.cycle).toBe(cycle + 1)
		local last = Events.state(w.endsAt - 1, config)
		expect(last.active ~= nil).toBe(true)
		local after = Events.state(w.endsAt, config)
		expect(after.active).toBeNil()
		expect(after.nextWindow.cycle).toBe(cycle + 1)
	end)

	it("lets a test override replace the schedule while it lasts", function()
		local cycle = Events.cycleOf(NOV_7_2026, config)
		local w = Events.window(cycle, config)
		local now = w.startsAt - 7200
		local override = { kind = "MoneyRush", startsAt = now, endsAt = now + 600 }
		local state = Events.state(now + 1, config, override)
		expect((state.active :: any).kind).toBe("MoneyRush")
		expect(state.nextWindow.startsAt).toBe(w.startsAt)
		expect(Events.state(now + 600, config, override).active).toBeNil()
		-- An override reaching into the scheduled window pushes "next" on.
		local long = { kind = "EggSale", startsAt = now, endsAt = w.startsAt + 60 }
		expect(Events.state(now + 1, config, long).nextWindow.cycle).toBe(cycle + 1)
	end)
end)

describe("Events effects", function()
	it("maps each kind to its numbers and leaves the rest at 1", function()
		local none = Events.effectsOf(nil, config)
		expect(none.priceFactor).toBe(1)
		expect(none.hatchFactor).toBe(1)
		expect(none.incomeFactor).toBe(1)
		expect(none.rarityMultipliers).toBeNil()
		expect(Events.effectsOf("EggSale", config).priceFactor).toBe(0.5)
		expect(Events.effectsOf("FastHatch", config).hatchFactor).toBe(0.5)
		expect(Events.effectsOf("MoneyRush", config).incomeFactor).toBe(2)
		local lucky = Events.effectsOf("LuckyHatch", config).rarityMultipliers :: any
		expect(lucky.Legendary).toBe(3)
		expect(lucky.Common).toBeNil()
		expect(Events.effectsOf("EggSale", config).incomeFactor).toBe(1)
	end)

	it("prices and hatch times stay whole and positive", function()
		local sale = Events.effectsOf("EggSale", config)
		expect(Events.price(50, sale)).toBe(25)
		expect(Events.price(2500, sale)).toBe(1250)
		expect(Events.price(1, sale)).toBe(1)
		expect(Events.price(15000, Events.effectsOf(nil, config))).toBe(15000)
		local fast = Events.effectsOf("FastHatch", config)
		expect(Events.hatchSeconds(10, fast)).toBe(5)
		expect(Events.hatchSeconds(1, fast)).toBe(1)
		expect(Events.hatchSeconds(15, fast)).toBe(8)
	end)

	it("pays Money Rush's double income exactly for the part of a span it covers", function()
		local cycle = Events.cycleOf(NOV_7_2026, config)
		local rush: any = nil
		for c = cycle, cycle + 10 do
			local w = Events.window(c, config)
			if w.kind == "MoneyRush" then
				rush = w
				break
			end
		end
		expect(rush ~= nil).toBe(true)
		local s = rush.startsAt
		expect(Events.incomeSeconds(s - 100, s - 10, config)).toBe(90)
		expect(Events.incomeSeconds(s - 10, s + 10, config)).toBe(30) -- 10 plain + 10 doubled
		expect(Events.incomeSeconds(s, s + 600, config)).toBe(1200)
		expect(Events.incomeSeconds(rush.endsAt - 5, rush.endsAt + 5, config)).toBe(15)
		expect(Events.incomeSeconds(s - DAY, s + DAY, config)).toBe(2 * DAY + 1800)
		expect(Events.incomeSeconds(s, s, config)).toBe(0)
		-- Another kind adds nothing.
		local other = Events.window(rush.cycle + 1, config)
		expect(Events.incomeSeconds(other.startsAt, other.endsAt, config)).toBe(1800)
	end)

	it("pays an override's income instead of the schedule's while it lasts", function()
		local cycle = Events.cycleOf(NOV_7_2026, config)
		local w = Events.window(cycle, config)
		local o = { kind = "MoneyRush", startsAt = w.startsAt - 300, endsAt = w.startsAt + 300 }
		local expected = 1200 + 600 -- 1200 s, 600 of them doubled by the override
		if w.kind == "MoneyRush" then
			expected += 900 -- the rest of the scheduled rush, after the override
		end
		expect(Events.incomeSeconds(w.startsAt - 600, w.startsAt + 600, config, o)).toBe(expected)
	end)
end)

describe("Events banner and Giant Egg", function()
	it("names a Lucky Hatch boost the way players read it on the odds card", function()
		expect(Events.boostName("LuckyHatch", config)).toBe("Lucky Hatch")
		expect(Events.boostName("Unknown", config)).toBe("Unknown")
	end)

	it("counts down in plain words", function()
		expect(Events.countdown(7)).toBe("0:07")
		expect(Events.countdown(45 * 60 + 9)).toBe("45:09")
		expect(Events.countdown(2 * 3600 + 5 * 60)).toBe("2h 05m")
		expect(Events.countdown(-5)).toBe("0:00")
	end)

	it("announces the next event, then runs it with time left", function()
		local cycle = Events.cycleOf(NOV_7_2026, config)
		local w = Events.window(cycle, config)
		local def = config.kinds[w.kind]
		local far = Events.banner(w.startsAt - 3 * 3600, config)
		expect(far.active).toBe(false)
		expect(far.title).toBe(def.title)
		expect(far.line).toBe("Next event in 3h 00m")
		local soon = Events.banner(w.startsAt - 125, config)
		expect(soon.line).toBe("Starts in 2:05!")
		local live = Events.banner(w.startsAt + 60, config)
		expect(live.active).toBe(true)
		expect(live.title).toBe(def.title)
		expect(live.line).toBe("Now! 29:00 left")
		expect(live.seconds).toBe(29 * 60)
		expect(soon.seconds).toBe(125)
		expect(live.blurb).toBe(def.blurb)
	end)

	it("puts every Legendary on the Giant Egg in turn, never twice running", function()
		local ids = legendaries()
		expect(#ids >= 1).toBe(true)
		local first = Events.cycleOf(NOV_7_2026, config)
		local seen: { [string]: number } = {}
		local last: string? = nil
		for cycle = first, first + 10 * #ids - 1 do
			local id = Events.giantSpecies(cycle, config, creatures.species) :: string
			expect(creatures.species[id].rarity).toBe("Legendary")
			if #ids > 1 then
				expect(id ~= last).toBe(true)
			end
			last = id
			seen[id] = (seen[id] or 0) + 1
		end
		for _, id in ids do
			expect(seen[id] ~= nil).toBe(true)
		end
		expect(Events.giantSpecies(first, config, {})).toBeNil()
	end)
end)

describe("Events config", function()
	local Config = require("@core/Config")
	local Odds = require("@core/Odds")
	local Schema = require("@core/Schema")
	local Eggs = require("../src/shared/Eggs")
	local Schemas = require("../src/shared/Schemas")(Schema, Odds)

	local function copy(value: any): any
		if type(value) ~= "table" then
			return value
		end
		local out = {}
		for k, v in value do
			out[k] = copy(v)
		end
		return out
	end

	local function problems(events: any): string
		return table.concat(Config.validate(Schemas.sections({ events = events })), "\n")
	end

	it("matches its schema", function()
		expect(problems(config)).toBe("")
	end)

	it("catches a window past the cycle, an unknown event and an event that does nothing", function()
		local late = copy(config)
		late.latestHour = 23.5
		late.windowMinutes = 60
		expect(problems(late)).toContain("next cycle")
		local unknown = copy(config)
		table.insert(unknown.rotation, "Fireworks")
		expect(problems(unknown)).toContain("unknown event Fireworks")
		local idle = copy(config)
		idle.kinds.EggSale.priceFactor = nil
		expect(problems(idle)).toContain("EggSale changes nothing")
	end)

	it("Lucky Hatch keeps every egg at exactly 100% and really raises the rare tiers", function()
		local eggs = Eggs.expand(require("../config/eggs"), creatures.species)
		local odds = Odds.new()
		for _, def in Eggs.oddsTables(eggs, true) do
			odds:define(def)
		end
		local boost = { rarityMultipliers = config.kinds.LuckyHatch.rarityMultipliers }
		local player = {}
		for _, egg in eggs do
			local multipliers = Eggs.boostMultipliers(egg, boost, creatures.species)
			odds:setBoosts(player, egg.id, { { id = "LuckyHatch", multipliers = multipliers } })
			local total, before, after = 0, 0, 0
			local base: { [string]: number } = {}
			for _, o in egg.outcomes do
				base[o.id] = o.weight
			end
			for _, row in odds:display(egg.id, player).rows do
				total += row.weight
				local rarity = creatures.species[row.id].rarity
				if rarity == "Legendary" or rarity == "Godly" or rarity == "Epic" then
					before += base[row.id]
					after += row.weight
				end
			end
			expect(total).toBe(egg.total or 10000)
			expect(after > before).toBe(true)
		end
	end)
end)
