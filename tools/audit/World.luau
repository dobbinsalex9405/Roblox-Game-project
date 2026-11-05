--!strict
-- What a player would find wrong with the world, from plain data (no Roblox
-- types), so the same checks run on a headless boot (tools/audit/run.luau)
-- and inside a real Roblox server (tools/cloud/probe.luau).
--
-- A box is any BasePart as an oriented box: centre, the part's right / up /
-- back axes, half sizes. Meshes, wedges, balls and cylinders count as their
-- bounding box, which is what a player bumps into closely enough for these
-- checks. A label is something drawn at a point in the world: a BillboardGui
-- or SurfaceGui text, or a ProximityPrompt.

local World = {}

export type Color = { r: number, g: number, b: number }

export type Box = {
	name: string,
	path: string,
	className: string,
	cx: number,
	cy: number,
	cz: number,
	-- Unit axes of the part (CFrame.XVector, YVector, ZVector).
	rx: number,
	ry: number,
	rz: number,
	ux: number,
	uy: number,
	uz: number,
	bx: number,
	by: number,
	bz: number,
	-- Half sizes along those axes.
	hx: number,
	hy: number,
	hz: number,
	color: Color,
	transparency: number,
	canCollide: boolean,
	isGround: boolean,
	isSpawn: boolean,
	enabled: boolean,
}

export type Label = {
	path: string,
	kind: string, -- "Billboard", "Surface" or "Prompt"
	text: string,
	x: number,
	y: number,
	z: number,
	alwaysOnTop: boolean,
	reach: number, -- a prompt's MaxActivationDistance; 0 otherwise
}

export type Finding = {
	severity: string, -- "FAIL", "WARN" or "NOTE"
	rule: string,
	message: string,
}

-- Tolerances, in studs.
World.GROUND_EPSILON = 0.05
-- An R15 character standing on the spawn: 4 wide, 5.5 tall, 2 deep, with a
-- little air above its head.
World.CHARACTER_HALF = { x = 2, y = 3, z = 1 }
-- Character root height above the floor; a prompt counts as in reach when
-- its distance from a standing player's root is within its reach.
World.ROOT_HEIGHT = 3
-- First-minute rule: the nearest thing to do should be a short walk.
World.FAR_FROM_SPAWN = 250

-- World-space axis-aligned bounds of a box.
function World.bounds(b: Box): (number, number, number, number, number, number)
	local ex = math.abs(b.rx) * b.hx + math.abs(b.ux) * b.hy + math.abs(b.bx) * b.hz
	local ey = math.abs(b.ry) * b.hx + math.abs(b.uy) * b.hy + math.abs(b.by) * b.hz
	local ez = math.abs(b.rz) * b.hx + math.abs(b.uz) * b.hy + math.abs(b.bz) * b.hz
	return b.cx - ex, b.cy - ey, b.cz - ez, b.cx + ex, b.cy + ey, b.cz + ez
end

-- Whether the box's axes line up with the world's (within a degree or so).
function World.axisAligned(b: Box): boolean
	local function unitAxis(x: number, y: number, z: number): boolean
		return math.max(math.abs(x), math.abs(y), math.abs(z)) > 0.9998
	end
	return unitAxis(b.rx, b.ry, b.rz) and unitAxis(b.ux, b.uy, b.uz) and unitAxis(b.bx, b.by, b.bz)
end

-- A point in a box's own space.
function World.toLocal(b: Box, x: number, y: number, z: number): (number, number, number)
	local dx, dy, dz = x - b.cx, y - b.cy, z - b.cz
	return dx * b.rx + dy * b.ry + dz * b.rz,
		dx * b.ux + dy * b.uy + dz * b.uz,
		dx * b.bx + dy * b.by + dz * b.bz
end

-- Is the point inside the ground's footprint and below its top surface?
-- Returns how far below the top it is.
local function underGround(ground: Box, x: number, y: number, z: number): number?
	local lx, ly, lz = World.toLocal(ground, x, y, z)
	if math.abs(lx) < ground.hx and math.abs(lz) < ground.hz and ly < ground.hy - World.GROUND_EPSILON then
		if ly > -ground.hy - 50 then
			return ground.hy - ly
		end
	end
	return nil
end

-- Top of the ground straight under/over (x, z), or nil off its edge.
local function groundTopAt(ground: Box, x: number, z: number): number?
	local lx, _, lz = World.toLocal(ground, x, ground.cy, z)
	if math.abs(lx) <= ground.hx and math.abs(lz) <= ground.hz then
		local _, _, _, _, top = World.bounds(ground)
		return top
	end
	return nil
end

local function intersects(
	ax0: number,
	ay0: number,
	az0: number,
	ax1: number,
	ay1: number,
	az1: number,
	b: Box
): boolean
	local bx0, by0, bz0, bx1, by1, bz1 = World.bounds(b)
	return ax0 < bx1 and ax1 > bx0 and ay0 < by1 and ay1 > by0 and az0 < bz1 and az1 > bz0
end

-- The highest standable top at or below `y` under (x, z): ground or any
-- solid part. nil when there is nothing under the point at all.
function World.floorUnder(boxes: { Box }, x: number, y: number, z: number): number?
	local best: number? = nil
	for _, b in boxes do
		if b.canCollide and b.transparency < 1 then
			local x0, _, z0, x1, top, z1 = World.bounds(b)
			if x >= x0 and x <= x1 and z >= z0 and z <= z1 and top <= y + 1 then
				if best == nil or top > best then
					best = top
				end
			end
		end
	end
	return best
end

local function examples(list: { string }, n: number): string
	local shown = {}
	for i = 1, math.min(#list, n) do
		table.insert(shown, "    " .. list[i])
	end
	if #list > n then
		table.insert(shown, `    ... and {#list - n} more`)
	end
	return table.concat(shown, "\n")
end

function World.spawns(boxes: { Box }): { Box }
	local out = {}
	for _, b in boxes do
		if b.isSpawn and b.enabled then
			table.insert(out, b)
		end
	end
	return out
end

function World.grounds(boxes: { Box }): { Box }
	local out = {}
	for _, b in boxes do
		if b.isGround then
			table.insert(out, b)
		end
	end
	return out
end

function World.check(boxes: { Box }, labels: { Label }): { Finding }
	local findings: { Finding } = {}
	local function add(severity: string, rule: string, message: string)
		table.insert(findings, { severity = severity, rule = rule, message = message })
	end

	local grounds = World.grounds(boxes)
	if #grounds == 0 then
		add("NOTE", "ground.none", "No Baseplate in Workspace: the ground checks were skipped.")
	end

	-- 1. Nothing the game builds may sit inside the ground.
	local buried: { { depth: number, text: string } } = {}
	for _, b in boxes do
		if not b.isGround and b.transparency < 1 then
			for _, g in grounds do
				local depth = underGround(g, b.cx, b.cy, b.cz)
				if depth then
					table.insert(buried, {
						depth = depth,
						text = `{b.path} is {string.format("%.1f", depth)} studs under the ground`,
					})
					break
				end
			end
		end
	end
	if #buried > 0 then
		table.sort(buried, function(a, b)
			return a.depth > b.depth
		end)
		local lines = {}
		for _, item in buried do
			table.insert(lines, item.text)
		end
		add(
			"FAIL",
			"ground.buried",
			`{#buried} part(s) have their centre inside the ground, so players see them sunk or not at all:\n{examples(
				lines,
				6
			)}`
		)
	end

	-- 2. Labels and prompts above the ground.
	local buriedLabels = {}
	for _, l in labels do
		for _, g in grounds do
			local depth = underGround(g, l.x, l.y, l.z)
			if depth then
				local first = string.split(l.text, "\n")[1]
				local what = if first ~= "" then ` "{first}"` else ""
				table.insert(
					buriedLabels,
					`{l.kind} {l.path}{what} is {string.format("%.1f", depth)} studs under the ground`
				)
				break
			end
		end
	end
	if #buriedLabels > 0 then
		add(
			"FAIL",
			"labels.buried",
			`{#buriedLabels} label(s) or prompt(s) are under the ground, where no player can see or use them:\n{examples(
				buriedLabels,
				6
			)}`
		)
	end

	-- 3. Spawning.
	local spawns = World.spawns(boxes)
	if #spawns == 0 then
		add("FAIL", "spawn.missing", "No enabled SpawnLocation: players appear at the world origin.")
	end
	for _, s in spawns do
		local _, _, _, _, top = World.bounds(s)
		for _, g in grounds do
			local gTop = groundTopAt(g, s.cx, s.cz)
			if gTop and top < gTop - World.GROUND_EPSILON then
				add(
					"FAIL",
					"spawn.buried",
					`{s.path}: its top is {string.format("%.1f", gTop - top)} studs under the ground; players spawn inside the Baseplate.`
				)
			end
		end
		local h = World.CHARACTER_HALF
		local x0, y0, z0 = s.cx - h.x, top + 0.2, s.cz - h.z
		local x1, y1, z1 = s.cx + h.x, top + 0.2 + 2 * h.y, s.cz + h.z
		local blockers = {}
		local soft = {}
		for _, b in boxes do
			if b ~= s and b.canCollide and intersects(x0, y0, z0, x1, y1, z1, b) then
				if World.axisAligned(b) then
					table.insert(blockers, b.path)
				else
					table.insert(soft, b.path)
				end
			end
		end
		if #blockers > 0 then
			add(
				"FAIL",
				"spawn.blocked",
				`{s.path}: a player standing on it would be inside {#blockers} solid part(s):\n{examples(
					blockers,
					5
				)}`
			)
		end
		if #soft > 0 then
			add(
				"WARN",
				"spawn.crowded",
				`{s.path}: rotated solid part(s) close over the spawn (bounding boxes overlap a standing player):\n{examples(
					soft,
					5
				)}`
			)
		end
	end

	-- 4. Every prompt can be reached by someone standing on something.
	local nearest: number? = nil
	for _, l in labels do
		if l.kind == "Prompt" then
			local floor = World.floorUnder(boxes, l.x, l.y, l.z)
			if floor == nil then
				add("FAIL", "prompt.nofloor", `Prompt {l.path} has nothing to stand on under it.`)
			else
				local height = l.y - (floor + World.ROOT_HEIGHT)
				if height > l.reach then
					add(
						"FAIL",
						"prompt.unreachable",
						`Prompt {l.path} is {string.format("%.1f", l.y - floor)} studs above the floor under it; a player can reach {l.reach}.`
					)
				end
			end
			for _, s in spawns do
				local d = math.sqrt((l.x - s.cx) ^ 2 + (l.z - s.cz) ^ 2)
				if nearest == nil or d < nearest then
					nearest = d
				end
			end
		end
	end
	if nearest and nearest > World.FAR_FROM_SPAWN then
		add(
			"WARN",
			"loop.far",
			`The nearest prompt is {math.floor(nearest)} studs from the spawn (about {math.floor(nearest / 16)} s of walking).`
		)
	end

	-- 5. Anything far under the ground has fallen out of the world.
	local fallen = {}
	for _, b in boxes do
		if not b.isGround then
			for _, g in grounds do
				local _, gy0 = World.bounds(g)
				if b.cy < gy0 - 1 then
					table.insert(fallen, b.path)
					break
				end
			end
		end
	end
	if #fallen > 0 then
		add(
			"WARN",
			"world.fallen",
			`{#fallen} part(s) are below the bottom of the ground:\n{examples(fallen, 5)}`
		)
	end

	return findings
end

return World
