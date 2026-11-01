--!strict
-- The ore pack: { [blockId] = count }. Saved with the player, so a crash or
-- a fair disconnect never loses a haul; a lamp-out keeps only part of it.

export type Pack = { [string]: number }

local Pack = {}

function Pack.count(pack: Pack): number
	local n = 0
	for _, count in pack do
		n += count
	end
	return n
end

function Pack.value(pack: Pack, blocks: { [string]: any }): number
	local coins = 0
	for id, count in pack do
		local block = blocks[id]
		if block then
			coins += block.value * count
		end
	end
	return coins
end

-- Adds one piece; false when the pack is full.
function Pack.add(pack: Pack, blockId: string, capacity: number): boolean
	if Pack.count(pack) >= capacity then
		return false
	end
	pack[blockId] = (pack[blockId] or 0) + 1
	return true
end

-- Splits a pack on lamp-out: keeps floor(total x keepFraction) pieces (at
-- least `minKeep`, so a small pack never comes back empty), spread
-- across stacks in proportion to their size (largest remainder first, ties to
-- the more valuable ore), so a lucky gem is as much at risk as the rest.
-- Returns the kept and dropped packs; the input is not changed.
function Pack.split(
	pack: Pack,
	keepFraction: number,
	blocks: { [string]: any },
	minKeep: number?
): (Pack, Pack)
	local total = Pack.count(pack)
	local budget = math.min(total, math.max(minKeep or 0, math.floor(total * keepFraction + 1e-9)))
	local kept: Pack = {}
	local dropped: Pack = {}
	local rows: { { id: string, count: number, remainder: number, value: number } } = {}
	local used = 0
	for id, count in pack do
		local exact = count * keepFraction
		local whole = math.floor(exact + 1e-9)
		kept[id] = whole
		used += whole
		table.insert(rows, {
			id = id,
			count = count,
			remainder = exact - whole,
			value = if blocks[id] then blocks[id].value else 0,
		})
	end
	table.sort(rows, function(a, b)
		if a.remainder ~= b.remainder then
			return a.remainder > b.remainder
		end
		if a.value ~= b.value then
			return a.value > b.value
		end
		return a.id < b.id
	end)
	for _, row in rows do
		if used >= budget then
			break
		end
		if kept[row.id] < row.count then
			kept[row.id] += 1
			used += 1
		end
	end
	for id, count in pack do
		local k = kept[id]
		if count - k > 0 then
			dropped[id] = count - k
		end
		if k == 0 then
			kept[id] = nil
		end
	end
	return kept, dropped
end

return Pack
