--!strict
-- The shared mine as pure data: which blocks are solid, which are mined out,
-- how damaged each is and which ones are exposed (touching open air, so they
-- exist as Parts in the world and can be hit). Nothing here touches Roblox:
-- the server's MineView draws the changes each call returns.
--
-- What a block is made of is a fixed hash of the server's seed, the block's
-- position and how many times it has grown back, picked through its layer's
-- weights out of 10,000. So the grid never stores the whole mine, only what
-- players have changed, and the chance of each block is exactly the weight
-- the layer guide shows.
--
-- Only exposed blocks become Parts. A fresh mine shows just its top face
-- (width x length Parts); digging reveals the neighbours of each block broken.

local Layout = require("./Layout")

export type Changes = {
	shown: { number }, -- keys of blocks that became exposed (draw them)
	hidden: { number }, -- keys of blocks that are no longer exposed or are gone
}

export type Grid = {
	mine: any,
	seed: number,
	width: number,
	length: number,
	rows: number,
	mined: { [number]: number }, -- key -> time it was mined
	damage: { [number]: number }, -- key -> pick power taken so far
	regrown: { [number]: number }, -- key -> times it has grown back
	exposed: { [number]: true },
	exposedCount: number,

	key: (self: Grid, x: number, y: number, z: number) -> number,
	position: (self: Grid, key: number) -> (number, number, number),
	inBounds: (self: Grid, x: number, y: number, z: number) -> boolean,
	isSolid: (self: Grid, x: number, y: number, z: number) -> boolean,
	isExposed: (self: Grid, x: number, y: number, z: number) -> boolean,
	blockAt: (self: Grid, x: number, y: number, z: number) -> string,
	hp: (self: Grid, x: number, y: number, z: number) -> number,
	hpLeft: (self: Grid, x: number, y: number, z: number) -> number,
	hit: (self: Grid, x: number, y: number, z: number, power: number) -> number,
	breakBlock: (self: Grid, x: number, y: number, z: number, now: number) -> Changes,
	regrow: (self: Grid, now: number, occupied: (x: number, y: number, z: number) -> boolean) -> Changes,
	exposedKeys: (self: Grid) -> { number },
}

local MineGrid = {}

local MODULUS = 2147483647 -- 2^31 - 1: Park-Miller steps stay exact in a double
local MULTIPLIER = 48271
local NEIGHBOURS = {
	{ 1, 0, 0 },
	{ -1, 0, 0 },
	{ 0, 1, 0 },
	{ 0, -1, 0 },
	{ 0, 0, 1 },
	{ 0, 0, -1 },
}

-- A well-mixed whole number in [1, 2^31 - 2] from the seed and a few small
-- whole numbers. Every intermediate value stays below 2^53, so Roblox and
-- Lune compute the same mine from the same seed.
function MineGrid.hash(seed: number, a: number, b: number, c: number, d: number): number
	local h = seed % (MODULUS - 1) + 1
	for _, v in { a, b, c, d } do
		h = (h + v * 7919 + 104729) % (MODULUS - 1) + 1
		h = (h * MULTIPLIER) % MODULUS
		h = (h * MULTIPLIER) % MODULUS
	end
	return h
end

-- The block a roll in [1, 10000] picks from a layer's weights.
function MineGrid.pick(blocks: { { id: string, weight: number } }, roll: number): string
	local total = 0
	for _, entry in blocks do
		total += entry.weight
		if roll <= total then
			return entry.id
		end
	end
	return blocks[#blocks].id
end

function MineGrid.new(mine: any, blockConfig: { [string]: any }, seed: number): Grid
	assert(seed == seed // 1 and seed >= 0, "seed must be a whole number")
	local width, length = mine.width, mine.length
	local rows = Layout.totalRows(mine)
	local layerOfRow: { number } = {}
	for row = 1, rows do
		layerOfRow[row] = Layout.layerOf(mine, row)
	end

	local grid: any = {
		mine = mine,
		seed = seed,
		width = width,
		length = length,
		rows = rows,
		mined = {},
		damage = {},
		regrown = {},
		exposed = {},
		exposedCount = 0,
	}

	function grid.key(_self: Grid, x: number, y: number, z: number): number
		return x + (z - 1) * width + (y - 1) * width * length
	end

	function grid.position(_self: Grid, key: number): (number, number, number)
		local i = key - 1
		local x = i % width + 1
		local z = (i // width) % length + 1
		local y = i // (width * length) + 1
		return x, y, z
	end

	function grid.inBounds(_self: Grid, x: number, y: number, z: number): boolean
		return x >= 1 and x <= width and z >= 1 and z <= length and y >= 1 and y <= rows
	end

	function grid.isSolid(self: Grid, x: number, y: number, z: number): boolean
		return self:inBounds(x, y, z) and self.mined[self:key(x, y, z)] == nil
	end

	-- Solid and touching air: the top row always is; others once a neighbour
	-- inside the shaft is mined. The shaft walls and floor are not air.
	local function touchesAir(self: Grid, x: number, y: number, z: number): boolean
		if y == 1 then
			return true
		end
		for _, n in NEIGHBOURS do
			local nx, ny, nz = x + n[1], y + n[2], z + n[3]
			if self:inBounds(nx, ny, nz) and self.mined[self:key(nx, ny, nz)] ~= nil then
				return true
			end
		end
		return false
	end

	function grid.isExposed(self: Grid, x: number, y: number, z: number): boolean
		return self:isSolid(x, y, z) and self.exposed[self:key(x, y, z)] == true
	end

	function grid.blockAt(self: Grid, x: number, y: number, z: number): string
		local layer = mine.layers[layerOfRow[y]]
		local generation = self.regrown[self:key(x, y, z)] or 0
		local roll = MineGrid.hash(self.seed, x, y, z, generation) % 10000 + 1
		return MineGrid.pick(layer.blocks, roll)
	end

	function grid.hp(self: Grid, x: number, y: number, z: number): number
		return blockConfig[self:blockAt(x, y, z)].hp
	end

	function grid.hpLeft(self: Grid, x: number, y: number, z: number): number
		return math.max(0, self:hp(x, y, z) - (self.damage[self:key(x, y, z)] or 0))
	end

	-- Applies one swing; returns the hp left (0 = ready to break). Does not
	-- break the block: the caller breaks it once the player's side of the
	-- change (the pack) has landed.
	function grid.hit(self: Grid, x: number, y: number, z: number, power: number): number
		local key = self:key(x, y, z)
		self.damage[key] = (self.damage[key] or 0) + power
		return self:hpLeft(x, y, z)
	end

	local function show(self: Grid, key: number, changes: Changes)
		if not self.exposed[key] then
			self.exposed[key] = true
			self.exposedCount += 1
			table.insert(changes.shown, key)
		end
	end

	local function hide(self: Grid, key: number, changes: Changes)
		if self.exposed[key] then
			self.exposed[key] = nil
			self.exposedCount -= 1
			table.insert(changes.hidden, key)
		end
	end

	function grid.breakBlock(self: Grid, x: number, y: number, z: number, now: number): Changes
		local changes: Changes = { shown = {}, hidden = {} }
		local key = self:key(x, y, z)
		assert(self:isSolid(x, y, z), "block is already mined")
		self.mined[key] = now
		self.damage[key] = nil
		hide(self, key, changes)
		for _, n in NEIGHBOURS do
			local nx, ny, nz = x + n[1], y + n[2], z + n[3]
			if self:isSolid(nx, ny, nz) then
				show(self, self:key(nx, ny, nz), changes)
			end
		end
		return changes
	end

	-- Grows back blocks mined at least `regrowSeconds` ago where `occupied`
	-- says no player is near. A grown block is a fresh roll of its layer.
	-- Neighbours that no longer touch air are hidden.
	function grid.regrow(
		self: Grid,
		now: number,
		occupied: (x: number, y: number, z: number) -> boolean
	): Changes
		local changes: Changes = { shown = {}, hidden = {} }
		local due: { number } = {}
		for key, minedAt in self.mined do
			if now - minedAt >= mine.regrowSeconds then
				table.insert(due, key)
			end
		end
		table.sort(due) -- same result whatever order the table iterates in
		local grown: { number } = {}
		for _, key in due do
			local x, y, z = self:position(key)
			if not occupied(x, y, z) then
				self.mined[key] = nil
				self.damage[key] = nil
				self.regrown[key] = (self.regrown[key] or 0) + 1
				table.insert(grown, key)
			end
		end
		-- Recheck the grown blocks and their neighbours once everything has grown.
		local check: { [number]: true } = {}
		for _, key in grown do
			check[key] = true
			local x, y, z = self:position(key)
			for _, n in NEIGHBOURS do
				local nx, ny, nz = x + n[1], y + n[2], z + n[3]
				if self:isSolid(nx, ny, nz) then
					check[self:key(nx, ny, nz)] = true
				end
			end
		end
		local keys: { number } = {}
		for key in check do
			table.insert(keys, key)
		end
		table.sort(keys)
		for _, key in keys do
			local x, y, z = self:position(key)
			if touchesAir(self, x, y, z) then
				show(self, key, changes)
			else
				hide(self, key, changes)
			end
		end
		return changes
	end

	function grid.exposedKeys(self: Grid): { number }
		local keys = {}
		for key in self.exposed do
			table.insert(keys, key)
		end
		table.sort(keys)
		return keys
	end

	local g = (grid :: any) :: Grid
	-- A fresh mine: only the top face is exposed.
	for z = 1, length do
		for x = 1, width do
			g.exposed[g:key(x, 1, z)] = true
			g.exposedCount += 1
		end
	end
	return g
end

return MineGrid
