--!nocheck
-- Exports every model the games build, as plain data for the design viewer
-- (tools/designs/build.mjs). Run from the repo root after `tools/build.sh all`:
--
--   lune run tools/designs/export [game ...] [--out build/designs/game-models.json]
--
-- Each game boots headless like the player's-eye audit (server start, one
-- player joins, their client starts and runs a few seconds), then every Model
-- in the Workspace becomes one design: its parts as boxes, balls, cylinders
-- and wedges with their colours. Folders are walked into; loose parts in a
-- folder become one design named after the folder. Copies of the same model
-- (eight plots, the same tree twice) are listed once with how many the game
-- has. Hatchery Heist's creatures come straight from VoxelArt.luau, so every
-- species is in the viewer even before anyone hatches it.

local datetime = require("@lune/datetime")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")

local Shim = require("../boot/shim")
local Collect = require("../audit/Collect")

local args = table.clone(process.args)
local OUT = "build/designs/game-models.json"
local games: { string } = {}
do
	local i = 1
	while i <= #args do
		if args[i] == "--out" then
			OUT = args[i + 1]
			i += 2
		else
			table.insert(games, args[i])
			i += 1
		end
	end
end
if #games == 0 or games[1] == "all" then
	games = {}
	for _, name in fs.readDir("games") do
		if fs.isFile(`games/{name}/default.project.json`) then
			table.insert(games, name)
		end
	end
	table.sort(games)
end

-- How long the client runs before the snapshot, so things that appear over
-- time (eggs riding the belt, customers walking in) are there.
local RUN_SECONDS = 4
local FRAMES = 120

-------------------------------------------------------------------------------
-- Boot (the audit's boot, without the screens and images)
-------------------------------------------------------------------------------

local pendingToClient: { any } = {}

local function deliverToClient(inst: any, args: any)
	local s = Shim.signalOf(inst, "OnClientEvent")
	local listening = false
	for _, h in s.handlers do
		if h.Connected then
			listening = true
		end
	end
	if not listening then
		table.insert(pendingToClient, { inst = inst, args = args })
		return
	end
	local was = Shim.side
	Shim.side = "client"
	s:Fire(table.unpack(args, 1, args.n))
	Shim.side = was
end

local function flushToClient()
	local queue = pendingToClient
	pendingToClient = {}
	for _, item in queue do
		deliverToClient(item.inst, item.args)
	end
end

local bridged = false
local function bridgeRemotes()
	if bridged then
		return
	end
	bridged = true
	for _, className in { "RemoteEvent", "UnreliableRemoteEvent" } do
		roblox.implementMethod(className, "FireServer", function(inst, ...)
			local player = Shim.players[1]
			local packed = table.pack(...)
			local was = Shim.side
			Shim.side = "server"
			Shim.signalOf(inst, "OnServerEvent"):Fire(player, table.unpack(packed, 1, packed.n))
			Shim.side = was
		end)
		roblox.implementMethod(className, "FireClient", function(inst, _player, ...)
			deliverToClient(inst, table.pack(...))
		end)
		roblox.implementMethod(className, "FireAllClients", function(inst, ...)
			deliverToClient(inst, table.pack(...))
		end)
	end
	roblox.implementMethod("RemoteFunction", "InvokeServer", function(inst, ...)
		local handler = inst.OnServerInvoke
		if handler == nil then
			return nil
		end
		local was = Shim.side
		Shim.side = "server"
		local results = table.pack(pcall(handler, Shim.players[1], ...))
		Shim.side = was
		if not results[1] then
			return nil
		end
		return table.unpack(results, 2, results.n)
	end)
end

local function scriptsUnder(root: any, className: string): { any }
	local out = {}
	for _, d in root:GetDescendants() do
		if d.ClassName == className then
			table.insert(out, d)
		end
	end
	table.sort(out, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
	return out
end

local function runAll(game: any, scripts: { any })
	for _, inst in scripts do
		pcall(Shim.runScript, game, inst, false)
	end
end

local function boot(placePath: string): any
	Shim.reset()
	pendingToClient = {}
	Shim.side = "server"
	Shim.quiet = true
	Shim.detachOnDestroy = true
	bridgeRemotes()
	Shim.install()
	local game = roblox.deserializePlace(fs.readFile(placePath))
	Shim.baseEnvironment(game)
	local players = game:GetService("Players")
	runAll(game, scriptsUnder(game:GetService("ServerScriptService"), "Script"))
	task.wait(0.3)
	local player = Shim.newPlayer(game, 1, "DesignExport")
	table.insert(Shim.players, player)
	players.PlayerAdded:Fire(player)
	task.wait(0.6)

	Shim.resetModules()
	Shim.side = "client"
	players.LocalPlayer = player
	local camera = Shim.seed(roblox.Instance.new("Camera"))
	camera.Name = "Camera"
	camera.Parent = game:GetService("Workspace")
	game:GetService("Workspace").CurrentCamera = camera
	pcall(function()
		camera.ViewportSize = roblox.Vector2.new(1280, 720)
	end)
	local clientScripts = scriptsUnder(game:GetService("StarterPlayer"), "LocalScript")
	for _, root in { "StarterGui", "ReplicatedFirst" } do
		for _, s in scriptsUnder(game:GetService(root), "LocalScript") do
			table.insert(clientScripts, s)
		end
	end
	runAll(game, clientScripts)
	task.wait(0.3)
	flushToClient()
	for _ = 1, FRAMES do
		pcall(Shim.stepFrames, 1, true)
	end
	task.wait(RUN_SECONDS)
	return game
end

-------------------------------------------------------------------------------
-- Parts to data
-------------------------------------------------------------------------------

-- One part: { shape, x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22,
-- sx, sy, sz, "RRGGBB", transparency, material }. The rotation is the part's
-- right, up and back axes as columns (Roblox CFrame components).
local function r3(n: number): number
	return math.round(n * 1000) / 1000
end

local function hex(c: any): string
	if c == nil then
		return "A3A2A5"
	end
	return string.format(
		"%02X%02X%02X",
		math.clamp(math.round(c.R * 255), 0, 255),
		math.clamp(math.round(c.G * 255), 0, 255),
		math.clamp(math.round(c.B * 255), 0, 255)
	)
end

local function prop(inst: any, name: string, default: any): any
	local ok, value = pcall(function()
		return inst[name]
	end)
	if ok and value ~= nil then
		return value
	end
	return default
end

local function enumName(v: any): string?
	if v == nil then
		return nil
	end
	local s = tostring(v)
	return string.match(s, "%.([%w_]+)$") or s
end

local function shapeOf(part: any): (string, any)
	local size = part.Size
	local mesh = part:FindFirstChildWhichIsA("SpecialMesh")
	if mesh then
		local kind = enumName(prop(mesh, "MeshType", nil))
		local scale = prop(mesh, "Scale", roblox.Vector3.new(1, 1, 1))
		local scaled = roblox.Vector3.new(size.X * scale.X, size.Y * scale.Y, size.Z * scale.Z)
		if kind == "Sphere" then
			return "ball", scaled
		elseif kind == "Cylinder" then
			return "cylinder", scaled
		elseif kind == "Wedge" then
			return "wedge", scaled
		elseif kind == "Brick" then
			return "block", scaled
		end
		return "mesh", size
	end
	local class = part.ClassName
	if class == "WedgePart" then
		return "wedge", size
	elseif class == "CornerWedgePart" then
		return "cornerwedge", size
	elseif class == "MeshPart" or class == "UnionOperation" then
		return "mesh", size
	end
	local shape = enumName(prop(part, "Shape", nil))
	if shape == "Ball" then
		return "ball", size
	elseif shape == "Cylinder" then
		return "cylinder", size
	elseif shape == "Wedge" then
		return "wedge", size
	elseif shape == "CornerWedge" then
		return "cornerwedge", size
	end
	return "block", size
end

local function partData(part: any): { any }?
	local transparency = prop(part, "Transparency", 0)
	if transparency >= 0.98 then
		return nil
	end
	local shape, size = shapeOf(part)
	local cf = Collect.cframe(part)
	local x, y, z = cf.XVector, cf.YVector, cf.ZVector
	local p = cf.Position
	return {
		shape,
		r3(p.X),
		r3(p.Y),
		r3(p.Z),
		r3(x.X),
		r3(y.X),
		r3(z.X),
		r3(x.Y),
		r3(y.Y),
		r3(z.Y),
		r3(x.Z),
		r3(y.Z),
		r3(z.Z),
		r3(size.X),
		r3(size.Y),
		r3(size.Z),
		hex(prop(part, "Color", nil)),
		r3(transparency),
		enumName(prop(part, "Material", nil)) or "Plastic",
	}
end

local function partsOf(root: any): { any }
	local out = {}
	local list = if root:IsA("BasePart") then { root } else {}
	for _, d in root:GetDescendants() do
		table.insert(list, d)
	end
	for _, d in list do
		if d:IsA("BasePart") and d.ClassName ~= "Terrain" then
			local data = partData(d)
			if data then
				table.insert(out, data)
			end
		end
	end
	return out
end

-- Moves parts so the design sits on the ground at the origin: centred on X
-- and Z, lowest point at Y = 0 (by part centres and half sizes, good enough
-- for framing).
local function centre(parts: { any }): ({ any }, { number })
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	for _, p in parts do
		-- Extent of an oriented box along each world axis.
		local hx, hy, hz = p[14] / 2, p[15] / 2, p[16] / 2
		local ex = math.abs(p[5]) * hx + math.abs(p[6]) * hy + math.abs(p[7]) * hz
		local ey = math.abs(p[8]) * hx + math.abs(p[9]) * hy + math.abs(p[10]) * hz
		local ez = math.abs(p[11]) * hx + math.abs(p[12]) * hy + math.abs(p[13]) * hz
		minX, maxX = math.min(minX, p[2] - ex), math.max(maxX, p[2] + ex)
		minY, maxY = math.min(minY, p[3] - ey), math.max(maxY, p[3] + ey)
		minZ, maxZ = math.min(minZ, p[4] - ez), math.max(maxZ, p[4] + ez)
	end
	if minX == math.huge then
		return parts, { 0, 0, 0 }
	end
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local out = {}
	for _, p in parts do
		local q = table.clone(p)
		q[2], q[3], q[4] = r3(p[2] - cx), r3(p[3] - minY), r3(p[4] - cz)
		table.insert(out, q)
	end
	return out, { r3(maxX - minX), r3(maxY - minY), r3(maxZ - minZ) }
end

-- Turns parts about the vertical axis through the origin.
local function yaw(parts: { any }, angle: number): { any }
	local c, s = math.cos(angle), math.sin(angle)
	local out = {}
	for _, p in parts do
		local q = table.clone(p)
		-- Position.
		q[2], q[4] = p[2] * c + p[4] * s, -p[2] * s + p[4] * c
		-- Each column of the rotation (rows 1 and 3 change).
		for col = 0, 2 do
			local a, b = p[5 + col], p[11 + col]
			q[5 + col], q[11 + col] = a * c + b * s, -a * s + b * c
		end
		for i = 2, 13 do
			q[i] = r3(q[i])
		end
		table.insert(out, q)
	end
	return out
end

-- Same shapes, sizes, places and colours: the same model.
local function num1(n: number): string
	local text = string.format("%.1f", n)
	if text == "-0.0" then
		return "0.0"
	end
	return text
end

local function signature(parts: { any }): string
	local rows = {}
	for _, p in parts do
		local row = { p[1] }
		for i = 2, 16 do
			-- A ball looks the same however it is turned.
			if p[1] == "ball" and i >= 5 and i <= 13 then
				continue
			end
			table.insert(row, num1(p[i]))
		end
		table.insert(row, p[17])
		table.insert(rows, table.concat(row, ","))
	end
	table.sort(rows)
	return table.concat(rows, ";")
end

-- What a model is made of: how many pieces of each shape and which colours,
-- ignoring where each piece sits, how big it is and which piece has which
-- colour. Copies the game scatters with random sizes, turns and colours
-- (trees, flower beds) count as one design. Small things scattered loose in
-- a folder (flower patches) also ignore colours: each patch picks its own.
local function makeup(parts: { any }, withColours: boolean): string
	local seen, rows = {}, {}
	for _, p in parts do
		seen[p[1]] = (seen[p[1]] or 0) + 1
		if withColours then
			seen[p[17]] = true
		end
	end
	for k, v in seen do
		table.insert(rows, k .. "=" .. tostring(v))
	end
	table.sort(rows)
	return table.concat(rows, ";")
end

-------------------------------------------------------------------------------
-- Walking the world
-------------------------------------------------------------------------------

local SKIP = { Camera = true, Terrain = true, Baseplate = true }

-- Folders whose loose parts are separate things (each egg on the belt), not
-- pieces of one thing; each part is named by its attribute when it has one.
local SPLIT: { [string]: string } = { ConveyorEggs = "EggId" }

local function isCharacter(inst: any): boolean
	return inst:IsA("Model") and inst:FindFirstChildWhichIsA("Humanoid") ~= nil
end

local function hasParts(inst: any): boolean
	if inst:IsA("BasePart") then
		return true
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			return true
		end
	end
	return false
end

-- The world box around a part, grown by `pad` studs on every side.
local function aabb(p: { any }, pad: number): { number }
	local hx, hy, hz = p[14] / 2, p[15] / 2, p[16] / 2
	local ex = math.abs(p[5]) * hx + math.abs(p[6]) * hy + math.abs(p[7]) * hz + pad
	local ey = math.abs(p[8]) * hx + math.abs(p[9]) * hy + math.abs(p[10]) * hz + pad
	local ez = math.abs(p[11]) * hx + math.abs(p[12]) * hy + math.abs(p[13]) * hz + pad
	return { p[2] - ex, p[3] - ey, p[4] - ez, p[2] + ex, p[3] + ey, p[4] + ez }
end

-- Loose parts that touch (or nearly: within two studs) belong together, and
-- so do a part and the parts inside it (a dock and its float).
local CLUSTER_GAP = 1
local function clustersOf(loose: { any }): { any }
	local boxes = {}
	local parent = {}
	for i, l in loose do
		boxes[i] = aabb(l.data, CLUSTER_GAP)
		parent[i] = i
	end
	local function find(i: number): number
		while parent[i] ~= i do
			parent[i] = parent[parent[i]]
			i = parent[i]
		end
		return i
	end
	local firstOf = {}
	for i, l in loose do
		local first = firstOf[l.owner]
		if first then
			parent[find(i)] = find(first)
		else
			firstOf[l.owner] = i
		end
	end
	for i = 1, #loose do
		local a = boxes[i]
		for j = i + 1, #loose do
			local b = boxes[j]
			if
				a[1] <= b[4]
				and b[1] <= a[4]
				and a[2] <= b[5]
				and b[2] <= a[5]
				and a[3] <= b[6]
				and b[3] <= a[6]
			then
				local ri, rj = find(i), find(j)
				if ri ~= rj then
					parent[ri] = rj
				end
			end
		end
	end
	local byRoot = {}
	local out = {}
	for i, l in loose do
		local r = find(i)
		local c = byRoot[r]
		if not c then
			c = { parts = {}, name = l.name, volume = -1 }
			byRoot[r] = c
			table.insert(out, c)
		end
		table.insert(c.parts, l.data)
		local v = l.data[14] * l.data[15] * l.data[16]
		if v > c.volume then
			c.name, c.volume = l.name, v
		end
	end
	return out
end

-- Groups: { name, path (Workspace-relative folder names), parts }
local function collectGroups(workspace: any): { any }
	local groups = {}
	local function walk(folder: any, path: { string })
		local loose = {}
		for _, child in folder:GetChildren() do
			if SKIP[child.Name] and folder == workspace then
				continue
			end
			if isCharacter(child) or not hasParts(child) then
				continue
			end
			if child:IsA("Model") then
				table.insert(groups, { name = child.Name, path = path, parts = partsOf(child) })
			elseif child:IsA("BasePart") then
				if folder == workspace then
					table.insert(groups, { name = child.Name, path = path, parts = partsOf(child) })
				elseif SPLIT[folder.Name] then
					local label = child:GetAttribute(SPLIT[folder.Name])
					table.insert(groups, {
						name = child.Name,
						label = if label then tostring(label) else nil,
						path = path,
						parts = partsOf(child),
					})
				else
					for _, p in partsOf(child) do
						table.insert(loose, { data = p, name = child.Name, owner = child })
					end
				end
			else
				local sub = table.clone(path)
				table.insert(sub, child.Name)
				walk(child, sub)
			end
		end
		if #loose > 0 then
			local clusters = clustersOf(loose)
			if #clusters == 1 then
				-- One connected thing (the hills, the mine floor): named after its folder.
				local name = path[#path] or "Parts"
				local parent = table.move(path, 1, #path - 1, 1, {})
				table.insert(groups, { name = name, path = parent, parts = clusters[1].parts })
			else
				-- Separate things scattered in one folder (flower patches among
				-- the trees): each is its own design, named after its biggest part.
				for _, c in clusters do
					table.insert(groups, { name = c.name, path = path, parts = c.parts, scattered = true })
				end
			end
		end
	end
	walk(workspace, {})
	return groups
end

-- "Plot3" and "Plot7" are copies of "Plot".
local function baseName(name: string): string
	local base = string.gsub(name, "%d+$", "")
	if base == "" then
		return name
	end
	return base
end

local function exportGame(name: string): { any }
	local placePath = `build/{name}.rbxl`
	if not fs.isFile(placePath) then
		error(`{placePath} does not exist; run tools/build.sh {name} first`)
	end
	local game = boot(placePath)
	local workspace = game:GetService("Workspace")
	local groups = collectGroups(workspace)

	local designs = {}
	local byKey: { [string]: any } = {}
	local variants: { [string]: number } = {}
	for _, g in groups do
		if #g.parts == 0 then
			continue
		end
		-- Copies stand at different angles around the map (plots in a ring):
		-- turn each so its biggest part lines up with the axes, then pick the
		-- quarter turn whose description sorts first, so copies match.
		local biggest, volume = g.parts[1], -1
		for _, p in g.parts do
			local v = p[14] * p[15] * p[16]
			if v > volume then
				biggest, volume = p, v
			end
		end
		local base0 = math.atan2(biggest[11], biggest[5])
		local parts, size, sig
		for k = 0, 3 do
			local turned, turnedSize = centre(yaw(g.parts, base0 + k * math.pi / 2))
			local s = signature(turned)
			if sig == nil or s < sig then
				parts, size, sig = turned, turnedSize, s
			end
		end
		local base = g.label or baseName(g.name)
		local folderKey = table.concat(g.path, "/") .. "/" .. base
		local key = folderKey .. "#" .. makeup(parts, not g.scattered)
		local existing = byKey[key]
		if existing then
			existing.copies += 1
		else
			variants[folderKey] = (variants[folderKey] or 0) + 1
			local design = {
				game = name,
				name = base,
				variant = variants[folderKey],
				where = table.concat(g.path, " > "),
				path = g.path,
				copies = 1,
				size = size,
				parts = parts,
			}
			byKey[key] = design
			table.insert(designs, design)
		end
	end

	-- The whole map, as a player would see it from the sky.
	local everything = {}
	for _, g in groups do
		for _, p in g.parts do
			table.insert(everything, p)
		end
	end
	for _, child in workspace:GetChildren() do
		if child.Name == "Baseplate" and child:IsA("BasePart") then
			local ground = partData(child)
			if ground then
				table.insert(everything, ground)
			end
		end
	end
	local mapParts, mapSize = centre(everything)
	table.insert(designs, {
		game = name,
		name = "Whole map",
		variant = 1,
		where = "",
		path = {},
		copies = 1,
		size = mapSize,
		parts = mapParts,
		map = true,
	})
	print(`{name}: {#designs} designs from {#groups} groups`)
	return designs
end

-------------------------------------------------------------------------------
-- Hatchery Heist creatures from VoxelArt
-------------------------------------------------------------------------------

local function voxelCreatures(): { any }
	local path = "games/hatchery-heist/src/shared/VoxelArt.luau"
	if not fs.isFile(path) then
		return {}
	end
	local art = luau.load(fs.readFile(path), { debugName = path })()
	local v = art.voxel
	local out = {}
	for species, a in art.species do
		local parts = {}
		for _, part in a.parts do
			local b = part.boxes
			for i = 1, #b, 7 do
				local colour = a.palette[b[i + 6]] or "CCCCCC"
				local neon = string.sub(colour, -1) == "*"
				colour = string.gsub(colour, "%*$", "")
				table.insert(parts, {
					"block",
					r3((b[i] + b[i + 3] / 2) * v),
					r3((b[i + 1] + b[i + 4] / 2) * v),
					r3((b[i + 2] + b[i + 5] / 2) * v),
					1,
					0,
					0,
					0,
					1,
					0,
					0,
					0,
					1,
					r3(b[i + 3] * v),
					r3(b[i + 4] * v),
					r3(b[i + 5] * v),
					string.upper(colour),
					0,
					if neon then "Neon" else "SmoothPlastic",
					part.name,
				})
			end
		end
		local centred, size = centre(parts)
		table.insert(out, {
			game = "hatchery-heist",
			name = species,
			creature = true,
			rarity = a.rarity,
			variant = 1,
			where = "",
			path = {},
			copies = 1,
			size = size,
			parts = centred,
		})
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	print(`hatchery-heist: {#out} creatures from VoxelArt`)
	return out
end

-------------------------------------------------------------------------------
-- Hatchery Heist charms from ClawArt (one model per charm, its trim in the
-- tier colour, as the game draws it)
-------------------------------------------------------------------------------

local function loadModule(path: string): any
	local source = fs.readFile(path)
	-- Type-only requires (WorldArt.Prop) have nothing to load here.
	source = string.gsub(source, 'local %w+ = require%("[^"]+"%)\n', "")
	return luau.load(source, { debugName = path })()
end

local function tierHexes(): { [string]: string }
	local source = fs.readFile("games/hatchery-heist/src/shared/Layout.luau")
	local block = string.match(source, "local RARITY_COLORS[^=]*= {(.-)\n}") or ""
	local out = {}
	for line in string.gmatch(block, "[^\n]+") do
		local tier, r, g, b =
			string.match(line, '%[?"?([%a ]+)"?%]?%s*=%s*Color3%.fromRGB%((%d+),%s*(%d+),%s*(%d+)%)')
		if tier then
			out[tier] = string.format(
				"%02X%02X%02X",
				tonumber(r) :: number,
				tonumber(g) :: number,
				tonumber(b) :: number
			)
		end
	end
	return out
end

local function clawCharms(): { any }
	local artPath = "games/hatchery-heist/src/shared/ClawArt.luau"
	if not fs.isFile(artPath) then
		return {}
	end
	local art = loadModule(artPath)
	local config = loadModule("games/hatchery-heist/config/charms.luau")
	local tiers = tierHexes()
	local out = {}
	for _, c in config.charms do
		local prop = art[`Charm{c.kind}`]
		if prop then
			local v = prop.voxel
			local parts = {}
			for _, part in prop.parts do
				local b = part.boxes
				for i = 1, #b, 7 do
					local colour = prop.palette[b[i + 6]] or "CCCCCC"
					if part.name == "trim" then
						colour = tiers[c.tier] or colour
					end
					table.insert(parts, {
						"block",
						r3((b[i] + b[i + 3] / 2) * v),
						r3((b[i + 1] + b[i + 4] / 2) * v),
						r3((b[i + 2] + b[i + 5] / 2) * v),
						1,
						0,
						0,
						0,
						1,
						0,
						0,
						0,
						1,
						r3(b[i + 3] * v),
						r3(b[i + 4] * v),
						r3(b[i + 5] * v),
						string.upper(colour),
						0,
						"SmoothPlastic",
						part.name,
					})
				end
			end
			local centred, size = centre(parts)
			table.insert(out, {
				game = "hatchery-heist",
				name = c.name,
				rarity = c.tier,
				variant = 1,
				where = `Charms > {c.kind}`,
				path = { "Charms", c.kind },
				copies = 1,
				size = size,
				parts = centred,
			})
		end
	end
	print(`hatchery-heist: {#out} charms from ClawArt`)
	return out
end

-------------------------------------------------------------------------------

local all = {}
for _, name in games do
	local ok, result = pcall(exportGame, name)
	if ok then
		for _, d in result do
			table.insert(all, d)
		end
	else
		print(`{name}: export failed: {result}`)
		process.exit(1)
	end
end
if table.find(games, "hatchery-heist") then
	for _, d in voxelCreatures() do
		table.insert(all, d)
	end
	for _, d in clawCharms() do
		table.insert(all, d)
	end
end

local dir = string.match(OUT, "^(.*)/[^/]+$")
if dir then
	fs.writeDir(dir)
end
fs.writeFile(
	OUT,
	serde.encode("json", { version = 1, exportedAt = datetime.now():toIsoDate(), designs = all }, false)
)
print(`wrote {#all} designs to {OUT}`)
process.exit(0)
