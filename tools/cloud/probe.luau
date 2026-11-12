--!nocheck
-- Runs inside a real Roblox server through Open Cloud Luau Execution
-- (tools/cloud/run.luau prepends WORLD_SOURCE and TEXTS_JSON). Nothing runs
-- on its own in such a server: no players, no physics, and the place's
-- scripts stay off. So this starts the server scripts itself, waits for the
-- world to be built, then checks it with the real engine:
--
--   * the shared World checks (tools/audit/World.luau) on real part data
--   * the spawn: real collision geometry (meshes included) where a player stands
--   * prompts: a real raycast down to the floor under each one
--   * parts that are not anchored or welded (they fall once physics runs)
--   * text: Roblox's own font metrics for every label in the world and every
--     HUD text the headless audit measured, so text that is cut off or too
--     small is measured, not estimated
--
-- Returns one JSON string: { findings = { {severity, rule, message} }, counts }.

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local ServerScriptService = game:GetService("ServerScriptService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local findings = {}
local function add(severity, rule, message)
	table.insert(findings, { severity = severity, rule = rule, message = message })
end

-- Errors from the game's own scripts.
local errorLines = {}
LogService.MessageOut:Connect(function(message, kind)
	if kind == Enum.MessageType.MessageError then
		table.insert(errorLines, message)
	end
end)

-- 1. Start the server scripts the way Roblox would, each with its own `script`.
local started = 0
for _, s in ServerScriptService:GetDescendants() do
	if s:IsA("Script") and s.Enabled and s.RunContext ~= Enum.RunContext.Client then
		local fn, compileError = loadstring(s.Source, "=" .. s:GetFullName())
		if fn == nil then
			add("FAIL", "engine.compile", `{s:GetFullName()} does not compile: {compileError}`)
		else
			-- selene: allow(deprecated)
			local env = setmetatable({ script = s }, { __index = getfenv(1) })
			-- selene: allow(deprecated)
			setfenv(fn, env)
			task.spawn(function()
				local ok, err = pcall(fn)
				if not ok then
					table.insert(errorLines, `{s:GetFullName()}: {err}`)
				end
			end)
			started += 1
		end
	end
end
task.wait(5)
for _, line in errorLines do
	add("FAIL", "engine.error", `Server error while starting: {line}`)
end

-- 2. The shared checks on real part data.
-- selene: allow(undefined_variable)
local World = loadstring(WORLD_SOURCE)()

local function box(part)
	local cf, size = part.CFrame, part.Size
	local x, y, z = cf.XVector, cf.YVector, cf.ZVector
	return {
		name = part.Name,
		path = part:GetFullName(),
		className = part.ClassName,
		cx = cf.Position.X,
		cy = cf.Position.Y,
		cz = cf.Position.Z,
		rx = x.X,
		ry = x.Y,
		rz = x.Z,
		ux = y.X,
		uy = y.Y,
		uz = y.Z,
		bx = z.X,
		by = z.Y,
		bz = z.Z,
		hx = size.X / 2,
		hy = size.Y / 2,
		hz = size.Z / 2,
		color = { r = part.Color.R, g = part.Color.G, b = part.Color.B },
		transparency = part.Transparency,
		canCollide = part.CanCollide,
		isGround = part.Name == "Baseplate" and part.Parent == Workspace,
		isSpawn = part:IsA("SpawnLocation"),
		enabled = not part:IsA("SpawnLocation") or part.Enabled,
	}
end

local function anchorPosition(inst)
	if inst == nil then
		return nil
	end
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Attachment") then
		return inst.WorldPosition
	elseif inst:IsA("Model") then
		return inst:GetPivot().Position
	end
	return nil
end

local function textOf(gui)
	local parts = {}
	for _, d in gui:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and d.Visible then
			table.insert(parts, d.Text)
		end
	end
	return table.concat(parts, "\n")
end

local boxes, labels, parts = {}, {}, {}
for _, d in Workspace:GetDescendants() do
	if d:IsA("BasePart") and not d:IsA("Terrain") then
		table.insert(boxes, box(d))
		table.insert(parts, d)
	elseif d:IsA("BillboardGui") and d.Enabled then
		local pos = anchorPosition(d.Adornee or d.Parent)
		if pos then
			pos += d.StudsOffsetWorldSpace + Vector3.new(0, d.StudsOffset.Y, 0)
			table.insert(labels, {
				path = d:GetFullName(),
				kind = "Billboard",
				text = textOf(d),
				x = pos.X,
				y = pos.Y,
				z = pos.Z,
				alwaysOnTop = d.AlwaysOnTop,
				reach = 0,
			})
		end
	elseif d:IsA("ProximityPrompt") and d.Enabled then
		local pos = anchorPosition(d.Parent)
		if pos then
			table.insert(labels, {
				path = d:GetFullName(),
				kind = "Prompt",
				text = d.ActionText,
				x = pos.X,
				y = pos.Y,
				z = pos.Z,
				alwaysOnTop = true,
				reach = d.MaxActivationDistance,
			})
		end
	end
end
for _, f in World.check(boxes, labels) do
	f.rule = "engine." .. f.rule
	table.insert(findings, f)
end

-- 3. Real geometry at the spawn and under every prompt.
local spawnCount = 0
for _, s in Workspace:GetDescendants() do
	if s:IsA("SpawnLocation") and s.Enabled then
		spawnCount += 1
		local top = s.Position.Y + s.Size.Y / 2
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { s }
		params.RespectCanCollide = true
		local standing = CFrame.new(s.Position.X, top + 0.2 + 2.75, s.Position.Z)
		local inside = Workspace:GetPartBoundsInBox(standing, Vector3.new(3.5, 5.5, 1.5), params)
		local names = {}
		for _, p in inside do
			table.insert(names, p:GetFullName())
			if #names == 5 then
				break
			end
		end
		if #inside > 0 then
			add(
				"FAIL",
				"engine.spawn-blocked",
				`{s:GetFullName()}: a player standing on it overlaps {#inside} solid part(s) (real collision geometry): {table.concat(
					names,
					", "
				)}`
			)
		end
	end
end

local rayParams = RaycastParams.new()
rayParams.RespectCanCollide = true
for _, l in labels do
	if l.kind == "Prompt" then
		local hit = Workspace:Raycast(Vector3.new(l.x, l.y + 0.5, l.z), Vector3.new(0, -60, 0), rayParams)
		if hit == nil then
			add(
				"FAIL",
				"engine.prompt-nofloor",
				`Prompt {l.path}: a ray straight down hits nothing within 60 studs.`
			)
		end
	end
end

-- 4. Loose parts: not anchored and not joined to anything fall once physics runs.
local loose = {}
for _, p in parts do
	if not p.Anchored and #p:GetJoints() == 0 and p.AssemblyRootPart == p then
		table.insert(loose, p:GetFullName())
	end
end
if #loose > 0 then
	add(
		"WARN",
		"engine.loose-parts",
		`{#loose} part(s) are neither anchored nor welded and will fall when the game runs: {table.concat(
			loose,
			", ",
			1,
			math.min(#loose, 5)
		)}`
	)
end

-- 5. Text with Roblox's own font metrics.
local function fontOf(name)
	local ok, font = pcall(function()
		return Enum.Font[name]
	end)
	return if ok and font then font else Enum.Font.SourceSans
end

local function fits(text, size, font, width, wrapped)
	local bounds = TextService:GetTextSize(text, size, font, Vector2.new(if wrapped then width else 1e5, 1e5))
	return bounds
end

local measured = 0
-- selene: allow(undefined_variable)
local texts = HttpService:JSONDecode(TEXTS_JSON)
for _, t in texts do
	local font = fontOf(t.font)
	local text = string.gsub(t.text, "<[^>]*>", "")
	if t.scaled then
		-- The size Roblox's TextScaled picks: the largest that fits the box.
		local best = 0
		for size = math.min(100, math.floor(t.height)), 1, -1 do
			local b = fits(text, size, font, t.width, t.wrapped)
			if b.X <= t.width + 0.5 and b.Y <= t.height + 0.5 then
				best = size
				break
			end
		end
		if best < 9 then
			add(
				"FAIL",
				"engine.text-tiny",
				`{t.path} ("{text}"): Roblox scales it to {best} px on a phone: unreadable.`
			)
		end
	else
		local b = fits(text, t.size, font, t.width, t.wrapped)
		if not t.wrapped and b.X > t.width + 2 then
			add(
				"FAIL",
				"engine.text-cut",
				`{t.path} ("{text}"): {math.floor(b.X)} px of text in a {math.floor(t.width)} px box on a phone (Roblox font metrics).`
			)
		elseif t.wrapped and b.Y > t.height + 2 then
			add(
				"FAIL",
				"engine.text-cut",
				`{t.path} ("{text}"): needs {math.floor(b.Y)} px of height in a {math.floor(t.height)} px box on a phone (Roblox font metrics).`
			)
		end
	end
	measured += 1
end

-- 6. Creature meshes as Roblox imported them (Hatchery Heist): every
-- species' meshes must land where CreatureMeshes lists them once the
-- importer's turn is undone (shared/MeshImport), or its pieces and leg
-- pivots are drawn in the wrong places (Alex, Nov 12: displaced legs,
-- faces on the back of the head).
do
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local listModule = shared and shared:FindFirstChild("CreatureMeshes")
	local importModule = shared and shared:FindFirstChild("MeshImport")
	if listModule and importModule then
		local CreatureMeshes = require(listModule)
		local MeshImport = require(importModule)
		local uploaded = 0
		for _, entry in CreatureMeshes do
			if entry.assetId > 0 and entry.textureId > 0 then
				uploaded += 1
			end
		end
		-- server/CreatureAssets loads them a few at a time in the background
		local folder = ReplicatedStorage:WaitForChild("CreatureMeshes", 30)
		local deadline = os.clock() + 180
		local last, still = -1, 0
		while folder and os.clock() < deadline do
			local n = #folder:GetChildren()
			if n >= uploaded then
				break
			end
			still = if n == last then still + 1 else 0
			last = n
			if still >= 20 then
				break -- nothing new for 20 s: the rest failed to load
			end
			task.wait(1)
		end
		local loaded, turns, misses = 0, {}, {}
		for _, model in if folder then folder:GetChildren() else {} do
			loaded += 1
			local yaw = model:GetAttribute(MeshImport.ATTRIBUTE)
			local miss = model:GetAttribute(MeshImport.FIT_ATTRIBUTE)
			if type(yaw) ~= "number" or type(miss) ~= "number" then
				add("FAIL", "engine.creature-import", `{model.Name}: no {MeshImport.ATTRIBUTE} measured`)
			else
				local key = `{math.round(math.deg(yaw))} degrees`
				turns[key] = (turns[key] or 0) + 1
				if miss > MeshImport.TOLERANCE then
					table.insert(misses, `{model.Name} ({math.floor(miss * 1000 + 0.5) / 1000} studs)`)
				end
			end
		end
		if #misses > 0 then
			table.sort(misses)
			add(
				"FAIL",
				"engine.creature-import",
				`{#misses} species' meshes do not land where CreatureMeshes lists them, so their legs and parts would be drawn out of place: {table.concat(
					misses,
					", "
				)}`
			)
		end
		local spread = {}
		for key, n in turns do
			table.insert(spread, `{n} turned {key}`)
		end
		table.sort(spread)
		add(
			"NOTE",
			"engine.creature-import",
			`{loaded} of {uploaded} uploaded species loaded; importer turn: {table.concat(spread, ", ")}`
		)
		if loaded < uploaded then
			add("WARN", "engine.creature-import", `{uploaded - loaded} uploaded species did not load in time`)
		end
	end
end

-- 7. (diagnostic, to be removed) two species that miss.
do
	local RS = game:GetService("ReplicatedStorage")
	local CM = require(RS.Shared.CreatureMeshes)
	local InsertService = game:GetService("InsertService")
	local function r(n)
		return math.floor(n * 1000 + 0.5) / 1000
	end
	for _, id in { "Bunny", "Ant" } do
		local entry = CM[id]
		local ok, loaded = pcall(function()
			return InsertService:LoadAsset(entry.assetId)
		end)
		if ok then
			local found = {}
			for _, d in loaded:GetDescendants() do
				if d:IsA("MeshPart") then
					found[d.Name] = d
				end
			end
			for _, part in entry.parts do
				for _, m in part.meshes do
					local mp = found[m.name]
					if mp then
						local p, z = mp.Position, mp.Size
						add(
							"NOTE",
							"diag.miss",
							`{m.name} listed ({m.center[1]},{m.center[2]},{m.center[3]}) size ({m.size[1]},{m.size[2]},{m.size[3]}) landed ({r(p.X)},{r(p.Y)},{r(p.Z)}) size ({r(z.X)},{r(z.Y)},{r(z.Z)}) look ({r(mp.CFrame.LookVector.X)},{r(mp.CFrame.LookVector.Z)})`
						)
					else
						add("NOTE", "diag.miss", `{m.name} missing`)
					end
				end
			end
		end
	end
end

local counts = { FAIL = 0, WARN = 0, NOTE = 0 }
for _, f in findings do
	counts[f.severity] = (counts[f.severity] or 0) + 1
end
return HttpService:JSONEncode({
	findings = findings,
	counts = counts,
	started = started,
	parts = #parts,
	labels = #labels,
	spawns = spawnCount,
	texts = measured,
})
