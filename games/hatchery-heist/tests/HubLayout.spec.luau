--!strict
-- The farm hub's layout (config/atmosphere.luau scenery.hub) must fit the
-- map: every piece is a real WorldArt prop, sits between the Egg Market and
-- the bases, keeps off the paths to the bases and the shop's plot, and
-- overlaps no other piece, lamp, signpost or market odds sign. Footprints come from each
-- prop's size, turned to face the centre as the game places them.
local Geometry = require("../src/shared/Geometry")
local WorldArt = require("../src/shared/WorldArt")
local atmosphere = require("../config/atmosphere")
local shophouse = require("../config/shophouse")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

type Rect = { name: string, corners: { { number } } }

local hub = atmosphere.scenery.hub

-- The footprint (studs) of a prop: x across, z deep.
local function footprint(id: string): (number, number)
	local prop = WorldArt.props[id]
	return prop.size[1] * prop.voxel, prop.size[3] * prop.voxel
end

-- A rectangle `width` across and `depth` deep, centred `radius` from the
-- middle at `angle` degrees (x = cos, z = sin, as Layout.plotCFrame), its
-- depth along the radius, shifted `side` studs across.
local function rect(
	name: string,
	angle: number,
	radius: number,
	width: number,
	depth: number,
	side: number?
): Rect
	local a = math.rad(angle)
	local out = { math.cos(a), math.sin(a) }
	local across = { -math.sin(a), math.cos(a) }
	local cx = out[1] * radius + across[1] * (side or 0)
	local cz = out[2] * radius + across[2] * (side or 0)
	local corners = {}
	for _, dx in { -width / 2, width / 2 } do
		for _, dy in { -depth / 2, depth / 2 } do
			table.insert(corners, { cx + out[1] * dy + across[1] * dx, cz + out[2] * dy + across[2] * dx })
		end
	end
	-- corners in order round the rectangle
	return { name = name, corners = { corners[1], corners[2], corners[4], corners[3] } }
end

local function overlaps(a: Rect, b: Rect): boolean
	for _, shape in { a, b } do
		local c = shape.corners
		for i = 1, 4 do
			local p, q = c[i], c[i % 4 + 1]
			local nx, nz = -(q[2] - p[2]), q[1] - p[1]
			local function span(r: Rect): (number, number)
				local lo, hi = math.huge, -math.huge
				for _, v in r.corners do
					local d = v[1] * nx + v[2] * nz
					lo, hi = math.min(lo, d), math.max(hi, d)
				end
				return lo, hi
			end
			local alo, ahi = span(a)
			local blo, bhi = span(b)
			if ahi <= blo or bhi <= alo then
				return false
			end
		end
	end
	return true
end

-- Smallest distance from a corner to a path centreline (the rays from the
-- middle along 0, 45, 90 ... degrees).
local function pathClearance(r: Rect): number
	local best = math.huge
	for k = 0, 7 do
		local a = math.rad(k * 45)
		local ux, uz = math.cos(a), math.sin(a)
		for _, v in r.corners do
			if v[1] * ux + v[2] * uz > 0 then
				best = math.min(best, math.abs(-v[1] * uz + v[2] * ux))
			end
		end
	end
	return best
end

local function pieces(): { Rect }
	local out = {}
	for i, piece in hub.pieces do
		local w, d = footprint(piece.id)
		if piece.yaw and math.abs(piece.yaw % 180 - 90) < 1 then
			w, d = d, w
		end
		table.insert(out, rect(`{i} {piece.id}`, piece.angle, piece.radius, w, d))
	end
	return out
end

-- Lamps and signposts beside every path.
local function streetProps(): { Rect }
	local out = {}
	local lw, ld = footprint(hub.lamps.id)
	local sw, sd = footprint(hub.signposts.id)
	for k = 0, 7 do
		for _, radius in hub.lamps.radii do
			for _, s in { -1, 1 } do
				table.insert(
					out,
					rect(`lamp {k * 45}/{radius}/{s}`, k * 45, radius, lw, ld, s * hub.lamps.side)
				)
			end
		end
		table.insert(
			out,
			rect(`signpost {k * 45}`, k * 45, hub.signposts.radius, sw, sd, -hub.signposts.side)
		)
	end
	return out
end

-- The Egg Market's odds sign beside each stop (Geometry.marketSign), with
-- its legs behind the face.
local function marketSigns(): { Rect }
	local sign = Geometry.MARKET_SIGN
	local out = {}
	for index = 1, Geometry.PLOTS do
		local cx, cz, fx, fz, ax, az = Geometry.marketSign(index)
		local w = sign.width / 2 + sign.frame
		-- 0.15 in front of the face's centre to `depth` behind it.
		local corners = {}
		for _, k in { { -1, 0.15 }, { 1, 0.15 }, { 1, 0.15 - sign.depth }, { -1, 0.15 - sign.depth } } do
			table.insert(corners, { cx + ax * k[1] * w + fx * k[2], cz + az * k[1] * w + fz * k[2] })
		end
		table.insert(out, { name = `market sign {index}`, corners = corners })
	end
	return out
end

describe("Farm hub layout", function()
	it("names real hub props", function()
		local ids = { hub.arch.id, hub.lamps.id, hub.signposts.id }
		for _, piece in hub.pieces do
			table.insert(ids, piece.id)
		end
		for _, id in ids do
			local prop = WorldArt.props[id]
			expect(prop ~= nil and id or `{id} is not in WorldArt`).toBe(id)
			if prop then
				local ok = prop.kind == "building" or prop.kind == "hubprop"
				expect(ok and id or `{id} is a {prop.kind}, not a hub prop`).toBe(id)
			end
		end
	end)

	it("keeps every piece between the market and the bases", function()
		for _, r in pieces() do
			for _, v in r.corners do
				local d = math.sqrt(v[1] * v[1] + v[2] * v[2])
				local ok = d >= hub.innerRadius and d <= hub.outerRadius
				expect(ok and r.name or `{r.name} reaches r{math.floor(d)}`).toBe(r.name)
			end
		end
	end)

	it("keeps pieces, lamps and signposts off the paths", function()
		local all = pieces()
		for _, r in streetProps() do
			table.insert(all, r)
		end
		for _, r in all do
			local clear = pathClearance(r)
			local ok = clear >= hub.pathWidth / 2
			expect(ok and r.name or `{r.name} is {clear} studs from a path's centre`).toBe(r.name)
		end
	end)

	it("keeps the shop's plot clear of paths and of everything else", function()
		-- the shop's own config is the source of truth; the hub mirrors it
		expect(hub.shop.angle).toBe(shophouse.angle)
		expect(hub.shop.radius).toBe(shophouse.radius)
		local shop = rect("shop", hub.shop.angle, hub.shop.radius, hub.shop.width, hub.shop.depth)
		expect(pathClearance(shop) >= hub.pathWidth / 2).toBe(true)
		for _, v in shop.corners do
			expect(math.sqrt(v[1] * v[1] + v[2] * v[2]) <= 77).toBe(true) -- base fronts at about r78
		end
		local others = pieces()
		for _, r in streetProps() do
			table.insert(others, r)
		end
		for _, r in marketSigns() do
			table.insert(others, r)
		end
		for _, r in others do
			expect(overlaps(shop, r) and `{r.name} is on the shop` or r.name).toBe(r.name)
		end
	end)

	it("overlaps nothing else", function()
		local all = pieces()
		for _, r in streetProps() do
			table.insert(all, r)
		end
		for _, r in marketSigns() do
			table.insert(all, r)
		end
		local arch = WorldArt.props[hub.arch.id]
		local aw, ad = arch.size[1] * arch.voxel, arch.size[3] * arch.voxel
		for k = 0, 7 do
			-- the arch spans the path, so its width runs across the radius
			table.insert(all, rect(`arch {k * 45}`, k * 45, hub.arch.radius, aw, ad))
		end
		for i = 1, #all do
			for j = i + 1, #all do
				local a, b = all[i], all[j]
				local hit = overlaps(a, b)
				expect(hit and `{a.name} overlaps {b.name}` or "clear").toBe("clear")
			end
		end
	end)

	it("stands each market odds sign low, off the belt and the path, facing the path", function()
		local sign = Geometry.MARKET_SIGN
		expect(sign.bottom + sign.height + sign.frame <= 5).toBe(true)
		local beltEdge = 27.5 + 3.2 / 2 -- Layout.MARKET_LANES[2] + MARKET_WIDTH / 2
		for index, r in marketSigns() do
			for _, v in r.corners do
				local d = math.sqrt(v[1] * v[1] + v[2] * v[2])
				expect(d >= beltEdge + 0.5 and r.name or `{r.name} reaches r{d}, onto the belt`).toBe(r.name)
			end
			local clear = pathClearance(r)
			expect(clear >= hub.pathWidth / 2 and r.name or `{r.name} is {clear} studs from a path's centre`).toBe(
				r.name
			)
			-- Its face looks out, turned toward its stop's path.
			local a = (index - 1) / Geometry.PLOTS * 2 * math.pi
			local _, _, fx, fz = Geometry.marketSign(index)
			local outward = fx * math.cos(a) + fz * math.sin(a)
			local toPath = -(fx * -math.sin(a) + fz * math.cos(a))
			expect(outward > 0.9 and toPath > 0.2).toBe(true)
		end
	end)
end)
