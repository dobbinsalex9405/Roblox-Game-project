--!strict
-- The Giant Legendary Egg's rules, as pure functions over saved data
-- (Alex, Nov 7 2026). It stands on the Golden Nest all day; each event cycle
-- (config/events.luau) it holds one named Legendary (Events.giantSpecies),
-- and each player can buy it once a cycle. It is an event special (Alex,
-- Nov 7): while the day's event runs it costs coins (`coinPrice`), the rest
-- of the day Robux. What it hatches is shown before purchase, so nothing
-- about it is random.
--
-- The server checks `refusal` before opening Roblox's prompt
-- (src/server/GiantEgg.luau) and `record`s the purchase in the receipt's own
-- data update. A receipt always grants, even a second one in a cycle (two
-- prompts raced): money taken is never refused.

local Events = require("./Events")
local Numbers = require("./Numbers")

export type Data = { [string]: any }

export type Status = {
	cycle: number,
	species: string?, -- today's Legendary (nil if the game has none)
	endsAt: number, -- unix seconds the cycle (and today's egg) ends
	bought: boolean, -- this player has bought this cycle's egg
}

local GiantEgg = {}

GiantEgg.EGG_ID = "GiantEgg" -- the egg id its creatures record (eggId)

function GiantEgg.status(d: Data?, now: number, events: any, species: { [string]: any }): Status
	local cycle, cycleStart = Events.cycleOf(now, events)
	local mine = d and d.giantEgg
	return {
		cycle = cycle,
		species = Events.giantSpecies(cycle, events, species),
		endsAt = cycleStart + Events.DAY,
		bought = mine ~= nil and (mine.lastCycle or 0) >= cycle,
	}
end

-- Why this player cannot buy the egg now, or nil.
function GiantEgg.refusal(d: Data?, now: number, events: any, species: { [string]: any }): string?
	if d == nil then
		return "Your hatchery is still loading."
	end
	local status = GiantEgg.status(d, now, events, species)
	if status.species == nil then
		return "The Giant Egg is empty today."
	end
	if status.bought then
		return `You have today's Giant Egg. A new Legendary arrives in {Events.countdown(status.endsAt - now)}.`
	end
	return nil
end

-- Its coin price during the event for a player earning `perSecond` coins
-- a second: the larger of the floor and that many hours of their income.
function GiantEgg.coinPrice(events: any, perSecond: number): number
	local egg = events.giantEgg
	local fromIncome = math.ceil(math.max(perSecond, 0) * egg.coinPriceIncomeHours * 3600)
	return math.max(egg.coinPriceMin, fromIncome)
end

-- Buys today's egg with coins, inside a data update: checks it can be
-- bought and afforded, takes `price` coins and records it. Returns today's
-- Legendary, or nil and why not.
function GiantEgg.buyWithCoins(
	d: Data,
	ledger: any,
	now: number,
	events: any,
	species: { [string]: any },
	price: number
): (string?, string?)
	local refusal = GiantEgg.refusal(d, now, events, species)
	if refusal then
		return nil, refusal
	end
	if ledger:balance("coins") < price then
		return nil, `The Giant Egg costs {Numbers.short(price)} coins during the event.`
	end
	local status = GiantEgg.status(d, now, events, species)
	ledger:spend("coins", price, `Shop:{GiantEgg.EGG_ID}`)
	GiantEgg.record(d, status.cycle)
	return status.species, nil
end

-- Notes a purchase for cycle `cycle` (inside the receipt's data update).
function GiantEgg.record(d: Data, cycle: number)
	local mine = d.giantEgg
	if mine == nil then
		mine = { lastCycle = 0, bought = 0 }
		d.giantEgg = mine
	end
	mine.lastCycle = math.max(mine.lastCycle or 0, cycle)
	mine.bought = (mine.bought or 0) + 1
end

return GiantEgg
