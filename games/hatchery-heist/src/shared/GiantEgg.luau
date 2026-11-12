--!strict
-- The Giant Golden Egg's rules, as pure functions over saved data. It stands
-- in the middle of the map all day; each player can buy it once per event
-- cycle (config/events.luau). It is an event special (Alex, Nov 7): while the
-- day's event runs it costs coins (`coinPrice`), the rest of the day Robux.
--
-- What it hatches (Alex, Nov 12): no named creature, just far better odds
-- than any other egg and nothing below Epic: the egg "GiantEgg" in
-- config/eggs.luau, a paid random item like every egg. The odds card shows
-- its exact odds before purchase, and the server rolls it through the odds
-- service's policy-checked roll (players under the fixed-order rule get the
-- fixed order the card shows them instead).
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
	endsAt: number, -- unix seconds the cycle ends and the egg can be bought again
	bought: boolean, -- this player has bought this cycle's egg
}

-- Chooses what this purchase hatches: `boughtBefore` counts the player's
-- earlier Giant Eggs (the fixed order's place). Nil if nothing can hatch.
export type Pick = (boughtBefore: number) -> string?

local GiantEgg = {}

GiantEgg.EGG_ID = "GiantEgg" -- its egg in config/eggs.luau, and the eggId its creatures record

function GiantEgg.status(d: Data?, now: number, events: any): Status
	local cycle, cycleStart = Events.cycleOf(now, events)
	local mine = d and d.giantEgg
	return {
		cycle = cycle,
		endsAt = cycleStart + Events.DAY,
		bought = mine ~= nil and (mine.lastCycle or 0) >= cycle,
	}
end

-- Why this player cannot buy the egg now, or nil.
function GiantEgg.refusal(d: Data?, now: number, events: any): string?
	if d == nil then
		return "Your hatchery is still loading."
	end
	local status = GiantEgg.status(d, now, events)
	if status.bought then
		return `You have today's Giant Egg. The next one is ready in {Events.countdown(status.endsAt - now)}.`
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

-- Picks what a purchase for cycle `cycle` hatches and notes it (inside the
-- purchase's data update). Returns the species, or nil (and notes nothing)
-- if none can hatch.
function GiantEgg.open(d: Data, cycle: number, pick: Pick): string?
	d.eggsBought = d.eggsBought or {}
	local boughtBefore = d.eggsBought[GiantEgg.EGG_ID] or 0
	local speciesId = pick(boughtBefore)
	if speciesId == nil then
		return nil
	end
	local mine = d.giantEgg
	if mine == nil then
		mine = { lastCycle = 0, bought = 0 }
		d.giantEgg = mine
	end
	mine.lastCycle = math.max(mine.lastCycle or 0, cycle)
	mine.bought = (mine.bought or 0) + 1
	d.eggsBought[GiantEgg.EGG_ID] = boughtBefore + 1
	return speciesId
end

-- Buys today's egg with coins, inside a data update: checks it can be
-- bought and afforded, takes `price` coins, records it and picks what it
-- hatches. Returns the species, or nil and why not.
function GiantEgg.buyWithCoins(
	d: Data,
	ledger: any,
	now: number,
	events: any,
	price: number,
	pick: Pick
): (string?, string?)
	local refusal = GiantEgg.refusal(d, now, events)
	if refusal then
		return nil, refusal
	end
	if ledger:balance("coins") < price then
		return nil, `The Giant Egg costs {Numbers.short(price)} coins during the event.`
	end
	local status = GiantEgg.status(d, now, events)
	local speciesId = GiantEgg.open(d, status.cycle, pick)
	if speciesId == nil then
		return nil, "The Giant Egg has nothing to hatch right now."
	end
	ledger:spend("coins", price, `Shop:{GiantEgg.EGG_ID}`)
	return speciesId, nil
end

return GiantEgg
