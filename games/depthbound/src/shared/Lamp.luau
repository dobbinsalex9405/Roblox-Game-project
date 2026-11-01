--!strict
-- The oil meter as pure math. The server keeps one Meter per diving player
-- (never saved: a dive never outlives the session) and settles it whenever
-- the burn rate changes; the client draws the same numbers from the last
-- Meter the server sent.

local Layout = require("./Layout")

export type Meter = {
	oil: number, -- oil left at `at`
	rate: number, -- oil burned per second from `at`
	at: number, -- server time
}

local Lamp = {}

function Lamp.oilAt(meter: Meter, now: number): number
	return math.max(0, meter.oil - meter.rate * math.max(0, now - meter.at))
end

-- Settles the meter at `now` and switches to a new burn rate.
function Lamp.settle(meter: Meter, now: number, rate: number): Meter
	return { oil = Lamp.oilAt(meter, now), rate = rate, at = now }
end

-- When the lamp runs dry at the current rate (math.huge if it never will).
function Lamp.emptyAt(meter: Meter): number
	if meter.rate <= 0 then
		return math.huge
	end
	return meter.at + meter.oil / meter.rate
end

-- Oil burned per second at a depth row (row 0, the top face, burns like layer 1).
function Lamp.rateAt(mine: any, row: number): number
	return mine.layers[Layout.layerOf(mine, math.max(1, row))].oilPerSecond
end

-- How long climbing out from a row takes, and the oil it burns.
function Lamp.climbSeconds(dive: any, row: number): number
	return dive.climb.baseSeconds + dive.climb.secondsPerRow * math.max(0, row)
end

function Lamp.climbOil(dive: any, row: number): number
	return Lamp.climbSeconds(dive, row) * dive.climb.oilPerSecond
end

return Lamp
