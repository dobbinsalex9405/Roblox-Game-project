--!strict
-- A queue of things to preload (the Book's pictures), handed out a batch at
-- a time, each once. `prioritize` moves items still waiting to the front:
-- the Book does it for the tab a player opens, so that tab's pictures load
-- before the rest (Studio gate, #134: a cold Uncommon tab waited 3 s+
-- behind the Common tab's pictures). Pure, for tests.

local PreloadQueue = {}

export type Queue = { waiting: { string } }

function PreloadQueue.new(items: { string }): Queue
	return { waiting = table.clone(items) }
end

-- Up to `n` items from the front, removed from the queue.
function PreloadQueue.take(q: Queue, n: number): { string }
	local out = {}
	while #out < n and #q.waiting > 0 do
		table.insert(out, table.remove(q.waiting, 1) :: string)
	end
	return out
end

-- Moves the listed items that are still waiting to the front, in the
-- listed order; the rest keep theirs.
function PreloadQueue.prioritize(q: Queue, first: { string })
	local wanted: { [string]: boolean } = {}
	for _, item in first do
		wanted[item] = true
	end
	local front, rest = {}, {}
	local waiting: { [string]: boolean } = {}
	for _, item in q.waiting do
		waiting[item] = true
		if not wanted[item] then
			table.insert(rest, item)
		end
	end
	for _, item in first do
		if waiting[item] then
			table.insert(front, item)
			waiting[item] = nil -- once, even if listed twice
		end
	end
	table.move(rest, 1, #rest, #front + 1, front)
	q.waiting = front
end

return PreloadQueue
