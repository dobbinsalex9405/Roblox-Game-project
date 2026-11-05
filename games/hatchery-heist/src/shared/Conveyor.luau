--!strict
-- The Egg Market's conveyor in the middle of the map, as a pure schedule
-- over server time. Everyone shares it: whoever buys an egg first gets it.
--
-- Egg number n appears at the start of the belt at n * spawnSeconds and rides
-- once round over travelSeconds, on lane n % lanes + 1 (two rings, so each
-- lane gets an egg every spawnSeconds * lanes). Which egg it is comes from a
-- fixed hash of n, so the server and every client agree on the whole belt
-- without sending a single message, and the server can check any purchase
-- ("egg 591") against the clock.
--
-- The egg kind is shown before purchase (it is the egg you click), so this
-- choice is not a paid random item; the hatch result is, and is handled by
-- the odds tables.

export type ConveyorConfig = {
	spawnSeconds: number,
	travelSeconds: number,
	lanes: number,
	buyReach: number,
	signSeconds: number,
	weights: { [string]: number },
}

export type BeltEgg = {
	index: number,
	eggId: string,
	progress: number, -- 0 at the start of the belt, 1 at the end
}

local Conveyor = {}

-- How much clock difference and latency a purchase may have, in seconds.
Conveyor.TOLERANCE = 1.5

-- (a * b) mod 2^32 without losing precision: a double holds 53 bits exactly,
-- so multiply by the low and high 16 bits of `a` separately.
local function mul32(a: number, b: number): number
	local lo = bit32.band(a, 0xffff)
	local hi = bit32.rshift(a, 16)
	return (lo * b + ((hi * b) % 65536) * 65536) % 4294967296
end

-- A 32-bit integer hash ("lowbias32"): nearby n give unrelated results.
local function mix(n: number): number
	local x = n % 4294967296
	x = bit32.bxor(x, bit32.rshift(x, 16))
	x = mul32(x, 0x7feb352d)
	x = bit32.bxor(x, bit32.rshift(x, 15))
	x = mul32(x, 0x846ca68b)
	x = bit32.bxor(x, bit32.rshift(x, 16))
	return x
end
Conveyor.mix = mix

-- Egg ids with their weights, in a fixed order (map order is not stable).
local function sortedWeights(weights: { [string]: number }): ({ string }, number)
	local ids = {}
	local total = 0
	for id, weight in weights do
		table.insert(ids, id)
		total += weight
	end
	table.sort(ids)
	return ids, total
end

-- The egg kind of egg number `index`.
function Conveyor.eggAt(index: number, config: ConveyorConfig): string
	local ids, total = sortedWeights(config.weights)
	local pick = mix(index * 31) % total
	for _, id in ids do
		pick -= config.weights[id]
		if pick < 0 then
			return id
		end
	end
	return ids[#ids]
end

function Conveyor.spawnTime(index: number, config: ConveyorConfig): number
	return index * config.spawnSeconds
end

-- Which lane (1 to config.lanes) egg number `index` rides.
function Conveyor.laneOf(index: number, config: ConveyorConfig): number
	return index % config.lanes + 1
end

-- Every egg on the belt at `now`, oldest (furthest along) first.
function Conveyor.onBelt(now: number, config: ConveyorConfig): { BeltEgg }
	local first = math.ceil((now - config.travelSeconds) / config.spawnSeconds)
	local last = math.floor(now / config.spawnSeconds)
	local eggs = {}
	for index = first, last do
		local progress = (now - Conveyor.spawnTime(index, config)) / config.travelSeconds
		if progress >= 0 and progress <= 1 then
			table.insert(eggs, {
				index = index,
				eggId = Conveyor.eggAt(index, config),
				progress = progress,
			})
		end
	end
	return eggs
end

-- Whether egg number `index` can be bought at `now`, allowing for latency.
function Conveyor.canBuy(index: number, now: number, config: ConveyorConfig): boolean
	local appears = Conveyor.spawnTime(index, config)
	return now >= appears - Conveyor.TOLERANCE and now <= appears + config.travelSeconds + Conveyor.TOLERANCE
end

-- Whether an egg costing `price` shows its Buy prompt to a player holding
-- `coins`, when the cheapest egg on sale costs `cheapest`. The belt keeps
-- moving, so the nearest prompt is often a dearer egg (Studio gate, Nov 5):
-- a player sees Buy only on eggs they can afford, unless they can afford
-- none, so pressing Buy still tells them what eggs cost.
function Conveyor.offered(price: number, coins: number, cheapest: number): boolean
	return coins >= price or coins < cheapest
end

return Conveyor
