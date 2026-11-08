--!nocheck
-- Player's-eye audit: boots each built game headless (the boot shim), lets
-- one player join and start their client, then looks at the result the way
-- a new player would and fails on what a player would hit:
--
--   world   parts or labels inside the ground, no spawn, a buried or blocked
--           spawn, prompts with nothing to stand on or out of reach
--   HUD     at phone, tablet and desktop size: buttons off the screen or
--           under Roblox's top bar, overlapping buttons or text, text too
--           small to read on a phone
--   clicks  every button on the first screen, one at a time: errors, what
--           opens, whether it closes again
--
-- and renders what that player would see as PNG images (boxes, flat colours,
-- a bitmap font: an approximation, not Roblox's renderer):
--
--   spawn-view.png      the default camera behind the character at the spawn
--   wide-view.png       the same, zoomed out
--   map.png             top-down
--   side-north.png, side-east.png   cuts through the spawn, ground line in red
--   phone.png, tablet.png, desktop.png   the HUD over the spawn view
--   click-NN-<button>.png   the phone screen after each button click
--
--   lune run tools/audit/run [game|all] [--built] [--environment staging]
--                            [--out build/audit] [--no-images]
--
-- Without --built it builds each game for Staging (BUILD_OUT=build/audit-places
-- tools/build.sh), so pass and product ids are real and the Robux shop shows
-- what a player sees; GetProductInfo answers with the game's own listings
-- (config/monetization.luau: name and Robux price). --built audits
-- build/<game>.rbxl as it is (a dev build has no ids, so its shop is empty).
--
-- Writes <out>/<game>/report.md, report.json and the images. Exit code 1 when
-- any check fails. ops/VISUAL_PLAYTEST.md says how the verifier uses it.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")

local Shim = require("../boot/shim")
local Monetization = require("../../packages/core/src/Monetization")
local Canvas = require("./Canvas")
local Collect = require("./Collect")
local Gui = require("./Gui")
local Report = require("./Report")
local Scene = require("./Scene")
local World = require("./World")

local args = table.clone(process.args)
local flags: { [string]: any } = {}
local positional: { string } = {}
do
	local i = 1
	while i <= #args do
		local a = args[i]
		if a == "--out" or a == "--environment" then
			flags[string.sub(a, 3)] = args[i + 1]
			i += 2
		elseif string.sub(a, 1, 2) == "--" then
			flags[string.sub(a, 3)] = true
			i += 1
		else
			table.insert(positional, a)
			i += 1
		end
	end
end

local OUT = flags.out or "build/audit"
local IMAGES = not flags["no-images"]
local SETTLE = 0.3

local games: { string } = {}
if #positional == 0 or positional[1] == "all" then
	for _, name in fs.readDir("games") do
		if fs.isDir(`games/{name}`) and fs.isFile(`games/{name}/default.project.json`) then
			table.insert(games, name)
		end
	end
	table.sort(games)
else
	games = positional
end

local ENVIRONMENT = flags.environment or "staging"

local function placeFor(game: string): string
	if flags.built then
		local built = `build/{game}.rbxl`
		if not fs.isFile(built) then
			error(`{built} does not exist; run tools/build.sh {game} first or drop --built`)
		end
		return built
	end
	local result = process.exec("tools/build.sh", { game }, {
		env = { BUILD_ENVIRONMENT = ENVIRONMENT, BUILD_OUT = "build/audit-places" },
	})
	if not result.ok then
		error(`tools/build.sh failed for {game}:\n{result.stdout}\n{result.stderr}`)
	end
	return `build/audit-places/{game}.rbxl`
end

-- The environment a built place was stamped for (tools/build.sh).
local function environmentOf(placePath: string): string
	local place = roblox.deserializePlace(fs.readFile(placePath))
	for _, d in place:GetDescendants() do
		if d.ClassName == "ModuleScript" and d.Name == "Build" then
			local env = string.match(d.Source, 'environment = "(%a+)"')
			if env then
				return env
			end
		end
	end
	return "dev"
end

-- What GetProductInfo answers in that environment: each created pass and
-- product's listed name and Robux price (an id of 0 is not on Roblox).
local function productInfoFor(game: string, environment: string): ({ [number]: any }, number)
	local path = `games/{game}/config/monetization.luau`
	if not fs.isFile(path) then
		return {}, 0
	end
	local config = luau.load(fs.readFile(path), { debugName = path })()
	local resolved = Monetization.resolve(config, environment)
	local listings = config.listings or {}
	local info, count = {}, 0
	for _, kind in { "passes", "products" } do
		for key, id in resolved[kind] do
			local listing = listings[kind] and listings[kind][key]
			if id > 0 and listing then
				info[id] = {
					Name = listing.name,
					PriceInRobux = listing.robux,
					Description = listing.description or "",
					IsForSale = true,
				}
				count += 1
			end
		end
	end
	return info, count
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

local function runAll(game: any, scripts: { any }, where: string)
	for _, inst in scripts do
		local ok, err = pcall(Shim.runScript, game, inst, false)
		if not ok then
			table.insert(Shim.errors, { where = `{where} {inst:GetFullName()}`, message = err })
		end
	end
end

local function takeErrors(): { any }
	local errors = Shim.errors
	Shim.errors = {}
	return errors
end

-- The boot shim's remotes go nowhere (a quiet server). Here the one player's
-- client and the server talk, so the HUD shows what a joining player sees
-- (coins, plot, guide) instead of empty labels.
local bridged = false
-- Like Roblox, events sent to the client before it listens wait in a queue
-- (the server sends a joining player's data before their scripts start).
local pendingToClient: { { inst: any, args: any } } = {}

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

local function bridgeRemotes()
	if bridged then
		return
	end
	bridged = true
	local function onSide(side: string, fn: () -> ())
		local was = Shim.side
		Shim.side = side
		fn()
		Shim.side = was
	end
	for _, className in { "RemoteEvent", "UnreliableRemoteEvent" } do
		roblox.implementMethod(className, "FireServer", function(inst, ...)
			local player = Shim.players[1]
			local args = table.pack(...)
			onSide("server", function()
				Shim.signalOf(inst, "OnServerEvent"):Fire(player, table.unpack(args, 1, args.n))
			end)
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
			table.insert(
				Shim.errors,
				{ where = `server invoke {inst:GetFullName()}`, message = tostring(results[2]) }
			)
			return nil
		end
		return table.unpack(results, 2, results.n)
	end)
end

-- Sets what the client sees of the screen: the camera's viewport and the
-- top bar, and tells the game (code that places buttons listens for these).
local function setScreen(game: any, width: number, height: number, inset: number)
	local camera = game:GetService("Workspace").CurrentCamera
	if camera then
		pcall(function()
			camera.ViewportSize = roblox.Vector2.new(width, height)
		end)
		Shim.signalOf(camera, "Changed:ViewportSize"):Fire()
	end
	local guiService = game:GetService("GuiService")
	pcall(function()
		guiService.TopbarInset = roblox.Rect.new(104, 2, width - 104, inset - 2)
	end)
	Shim.signalOf(guiService, "Changed:TopbarInset"):Fire()
end

-- Boots the place like tools/boot/run.luau: server start, one player joins,
-- that player's client starts. Returns the game, the player and any errors.
local function boot(placePath: string): (any, any, { any })
	Shim.reset()
	pendingToClient = {}
	Shim.side = "server"
	Shim.quiet = true
	Shim.detachOnDestroy = true
	-- Before Shim.install, which only fills in members not yet implemented.
	bridgeRemotes()
	Shim.install()
	local game = roblox.deserializePlace(fs.readFile(placePath))
	Shim.baseEnvironment(game)
	local players = game:GetService("Players")
	runAll(game, scriptsUnder(game:GetService("ServerScriptService"), "Script"), "server start-up")
	task.wait(SETTLE)
	local player = Shim.newPlayer(game, 1, "AuditTester")
	table.insert(Shim.players, player)
	players.PlayerAdded:Fire(player)
	task.wait(SETTLE * 2)

	-- Roblox puts the character on the spawn; the shim leaves it at the origin.
	local spawn = nil
	for _, d in game:GetService("Workspace"):GetDescendants() do
		if d.ClassName == "SpawnLocation" then
			spawn = d
			break
		end
	end
	if spawn and player.Character then
		local root = player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local top = spawn.CFrame.Position + roblox.Vector3.new(0, spawn.Size.Y / 2 + 3, 0)
			root.CFrame = roblox.CFrame.new(top)
		end
	end

	local errors = takeErrors()
	Shim.resetModules()
	Shim.side = "client"
	players.LocalPlayer = player
	local camera = Shim.seed(roblox.Instance.new("Camera"))
	camera.Name = "Camera"
	camera.Parent = game:GetService("Workspace")
	game:GetService("Workspace").CurrentCamera = camera
	-- The client starts on a phone, as most players do.
	local phone = Gui.SCREENS[1]
	setScreen(game, phone.width, phone.height, phone.inset)
	local clientScripts = scriptsUnder(game:GetService("StarterPlayer"), "LocalScript")
	for _, s in scriptsUnder(game:GetService("StarterGui"), "LocalScript") do
		table.insert(clientScripts, s)
	end
	for _, s in scriptsUnder(game:GetService("ReplicatedFirst"), "LocalScript") do
		table.insert(clientScripts, s)
	end
	runAll(game, clientScripts, "client start-up")
	task.wait(SETTLE)
	flushToClient()
	task.wait(SETTLE)
	for _, e in takeErrors() do
		table.insert(errors, e)
	end
	return game, player, errors
end

local function writePng(path: string, c: Canvas.Canvas)
	fs.writeFile(path, Canvas.toPng(c))
end

local CAPTION_BG = { r = 0, g = 0, b = 0 }
local CAPTION = { r = 1, g = 1, b = 1 }
local RED = { r = 1, g = 0.15, b = 0.15 }

local function caption(c: Canvas.Canvas, text: string)
	local size = math.max(14, math.floor(c.height / 40))
	Canvas.fillRect(c, 0, 0, c.width, size + 8, CAPTION_BG, 0.6)
	Canvas.text(c, 6, 4, text, size, CAPTION)
end

-- Where the default camera would be: behind and above the character on the
-- spawn, looking the way the spawn faces.
local function spawnCamera(
	spawn: World.Box?,
	distance: number,
	pitch: number,
	fov: number
): (any, number, number, number)
	local sx, sz, top, lx, lz = 0, 0, 0, 0, -1
	if spawn then
		local _, _, _, _, t = World.bounds(spawn)
		sx, sz, top = spawn.cx, spawn.cz, t
		-- A SpawnLocation's front (look) is -ZVector.
		lx, lz = -spawn.bx, -spawn.bz
		local l = math.sqrt(lx * lx + lz * lz)
		if l < 1e-6 then
			lx, lz = 0, -1
		else
			lx, lz = lx / l, lz / l
		end
	end
	local fy = top + 4.5
	local p = math.rad(pitch)
	local ex = sx - lx * distance * math.cos(p)
	local ez = sz - lz * distance * math.cos(p)
	local ey = fy + distance * math.sin(p)
	return Scene.lookAt(ex, ey, ez, sx, fy, sz, fov), sx, top, sz, lx, lz
end

local function renderWorld(
	width: number,
	height: number,
	boxes: { World.Box },
	labels: { World.Label },
	spawn: World.Box?,
	distance: number,
	pitch: number,
	labelSize: number
): Canvas.Canvas
	local c = Canvas.new(width, height)
	Scene.sky(c)
	local cam, sx, top, sz, lx, lz = spawnCamera(spawn, distance, pitch, 70)
	local all = table.clone(boxes)
	for _, b in Scene.character(sx, top, sz, lx, lz) do
		table.insert(all, b)
	end
	Scene.drawBoxes(c, cam, all)
	Scene.drawLabels(c, cam, labels, labelSize)
	return c
end

-- Bounds of what the game built (everything but the ground), with a margin.
local function contentBounds(boxes: { World.Box }): (number, number, number, number, number, number)
	local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
	for _, b in boxes do
		if not b.isGround then
			local ax, ay, az, bx, by, bz = World.bounds(b)
			-- Ignore runaway parts far from everything (they get their own check).
			if math.abs(ax) < 4000 and math.abs(bz) < 4000 and math.abs(ay) < 4000 then
				x0, y0, z0 = math.min(x0, ax), math.min(y0, ay), math.min(z0, az)
				x1, y1, z1 = math.max(x1, bx), math.max(y1, by), math.max(z1, bz)
			end
		end
	end
	if x0 == math.huge then
		return -64, -10, -64, 64, 20, 64
	end
	local m = 16
	return x0 - m, y0 - 4, z0 - m, x1 + m, y1 + 4, z1 + m
end

local function renderMap(boxes: { World.Box }, labels: { World.Label }, spawn: World.Box?): Canvas.Canvas
	local x0, _, z0, x1, y1, z1 = contentBounds(boxes)
	local w, h = x1 - x0, z1 - z0
	local scale = math.min(1400 / w, 1000 / h)
	local cw, ch = math.max(320, math.floor(w * scale)), math.max(240, math.floor(h * scale))
	local c = Canvas.new(cw, ch, { r = 0.12, g = 0.12, b = 0.14 })
	local cam = Scene.ortho((x0 + x1) / 2, y1 + 100, (z0 + z1) / 2, { 0, -1, 0 }, { 0, 0, -1 }, scale, false)
	Scene.drawBoxes(c, cam, boxes)
	Scene.drawLabels(c, cam, labels, 12)
	if spawn then
		local sx, sy = Scene.toScreen(cam, c, spawn.cx, spawn.cy, spawn.cz)
		if sx and sy then
			Canvas.strokeRect(c, sx - 8, sy - 8, sx + 8, sy + 8, RED, 1, 3)
			Canvas.text(c, sx + 11, sy - 6, "SPAWN", 12, RED)
		end
	end
	return c
end

local function renderSide(boxes: { World.Box }, spawn: World.Box?, forward: { number }): Canvas.Canvas
	local x0, y0, z0, x1, y1, z1 = contentBounds(boxes)
	local groundTop = nil
	for _, g in World.grounds(boxes) do
		local _, _, _, _, top = World.bounds(g)
		groundTop = if groundTop then math.max(groundTop, top) else top
	end
	-- A window around the ground (or the spawn when there is no Baseplate):
	-- what is just under it and what stands on it.
	local ref = groundTop
	if ref == nil and spawn then
		local _, _, _, _, spawnTop = World.bounds(spawn)
		ref = spawnTop
	end
	ref = ref or 0
	local bottom = math.max(math.min(y0, ref - 20), ref - 40)
	local top = math.min(math.max(y1, ref + 10), ref + 120)
	local across = if math.abs(forward[1]) > 0.5 then z1 - z0 else x1 - x0
	local scale = math.min(1400 / across, 700 / (top - bottom))
	local cw = math.max(320, math.floor(across * scale))
	local ch = math.max(200, math.floor((top - bottom) * scale))
	local c = Canvas.new(cw, ch, { r = 0.55, g = 0.75, b = 0.95 })
	local cx = if spawn then spawn.cx else (x0 + x1) / 2
	local cz = if spawn then spawn.cz else (z0 + z1) / 2
	if math.abs(forward[1]) > 0.5 then
		cz = (z0 + z1) / 2
	else
		cx = (x0 + x1) / 2
	end
	-- The cut plane goes through the spawn.
	local px = if spawn and math.abs(forward[1]) > 0.5 then spawn.cx else cx
	local pz = if spawn and math.abs(forward[3]) > 0.5 then spawn.cz else cz
	local cam = Scene.ortho(px, (top + bottom) / 2, pz, forward, { 0, 1, 0 }, scale, true)
	Scene.drawBoxes(c, cam, boxes)
	if groundTop then
		local _, gy = Scene.toScreen(cam, c, px + forward[1], groundTop, pz + forward[3])
		if gy then
			for x = 0, cw - 1, 12 do
				Canvas.fillRect(c, x, gy - 1, x + 7, gy + 1, RED, 1)
			end
			Canvas.text(c, 6, gy + 4, `GROUND TOP Y={string.format("%.1f", groundTop)}`, 12, RED)
		end
	end
	if spawn then
		local sx, sy = Scene.toScreen(cam, c, spawn.cx + forward[1], spawn.cy, spawn.cz + forward[3])
		if sx and sy then
			Canvas.fillRect(c, sx - 1, sy - 30, sx + 1, sy, RED, 1)
			Canvas.text(c, sx + 4, sy - 30, "SPAWN", 12, RED)
		end
	end
	return c
end

local failedAny = false

local function auditGame(gameName: string)
	local placePath = placeFor(gameName)
	local dir = `{OUT}/{gameName}`
	fs.writeDir(dir)
	for _, name in fs.readDir(dir) do
		if string.match(name, "%.png$") then
			fs.removeFile(`{dir}/{name}`)
		end
	end
	local commit = "dev"
	pcall(function()
		local source = fs.readFile(`games/{gameName}/src/shared/Build.luau`)
		commit = string.match(source, 'commit = "([^"]*)"') or commit
	end)
	local result = process.exec("git", { "rev-parse", "--short=12", "HEAD" })
	if result.ok then
		commit = string.gsub(result.stdout, "%s+$", "")
	end

	local findings: { World.Finding } = {}
	local images: { { file: string, title: string } } = {}

	local environment = environmentOf(placePath)
	local priced
	Shim.productInfo, priced = productInfoFor(gameName, environment)
	local game, player, errors = boot(placePath)
	for _, e in errors do
		local severity, why = Gui.severityOfError(e.message)
		table.insert(findings, {
			severity = severity,
			rule = if why then "harness.destroyed" else "boot.error",
			message = if why then `{why} ({e.where})` else `{e.where}: {e.message}`,
		})
	end

	local characters = {}
	if player.Character then
		table.insert(characters, player.Character)
	end
	local boxes, labels = Collect.world(game, characters)
	for _, f in World.check(boxes, labels) do
		table.insert(findings, f)
	end
	local spawn = World.spawns(boxes)[1]

	local function save(file: string, title: string, c: Canvas.Canvas)
		if IMAGES then
			caption(c, `{gameName} @ {commit}: {title}`)
			writePng(`{dir}/{file}`, c)
			table.insert(images, { file = file, title = title })
		end
	end

	local spawnView = nil
	if IMAGES then
		spawnView = renderWorld(1280, 720, boxes, labels, spawn, 12.5, 20, 14)
		save("spawn-view.png", "spawn view (default camera behind the character)", spawnView)
		save(
			"wide-view.png",
			"zoomed out from the spawn",
			renderWorld(1280, 720, boxes, labels, spawn, 60, 35, 14)
		)
		save("map.png", "top-down map (labels and prompts in yellow/white)", renderMap(boxes, labels, spawn))
		save(
			"side-north.png",
			"side cut through the spawn, looking north",
			renderSide(boxes, spawn, { 0, 0, -1 })
		)
		save(
			"side-east.png",
			"side cut through the spawn, looking east",
			renderSide(boxes, spawn, { 1, 0, 0 })
		)
	end

	-- The HUD at each screen size, and every button on the first screen.
	local gui = Gui.audit(game, player, {
		images = IMAGES,
		background = function(width: number, height: number): Canvas.Canvas
			return renderWorld(width, height, boxes, labels, spawn, 12.5, 20, 12)
		end,
		save = save,
		takeErrors = takeErrors,
		settle = SETTLE,
		-- Each button is clicked from a fresh boot, so one open menu can't hide the next button.
		reboot = function()
			local g, p = boot(placePath)
			return g, p
		end,
		shim = Shim,
		wait = task.wait,
		setScreen = function(p: any, width: number, height: number, inset: number)
			-- The player belongs to the game it joined.
			setScreen(p.Parent.Parent, width, height, inset)
		end,
	})
	for _, f in gui.findings do
		table.insert(findings, f)
	end

	local known = {}
	if fs.isFile("tools/audit/known.json") then
		known = serde.decode("json", fs.readFile("tools/audit/known.json")).known or {}
	end
	for _, k in Report.applyKnown(gameName, findings, known) do
		table.insert(findings, {
			severity = "WARN",
			rule = "known.stale",
			message = `tools/audit/known.json lists a {k.rule} problem matching "{k.contains}" that no longer happens: remove the entry.`,
		})
	end

	local notes = table.clone(gui.notes)
	local emptyShop = if priced == 0
		then " (none is created there, so the Robux shop is empty: audit a Staging build to see it)"
		else ""
	table.insert(
		notes,
		1,
		`Built for {environment}; {priced} pass(es) and product(s) priced from config/monetization.luau listings{emptyShop}.`
	)
	table.insert(
		notes,
		"Reading the HUD images: the two dark rounded boxes at the top left stand in for Roblox's own top-bar buttons (menu and chat), not the game's; grey boxes with a cross are images (not loaded); red outlines mark elements with a FAIL. Text is a bitmap font, so its width is approximate (the cloud check measures it with Roblox's fonts)."
	)
	local report = Report.build(gameName, commit, findings, images, notes, Shim.gaps)
	fs.writeFile(`{dir}/report.md`, report.markdown)
	fs.writeFile(
		`{dir}/report.json`,
		serde.encode(
			"json",
			{ game = gameName, commit = commit, findings = findings, images = images, texts = gui.texts },
			true
		)
	)
	print(report.summary)
	if report.failed then
		failedAny = true
	end
end

for _, gameName in games do
	local ok, err = pcall(auditGame, gameName)
	if not ok then
		failedAny = true
		print(`[FAIL] {gameName}: the audit itself failed: {err}`)
	end
end

if failedAny then
	print(`\nPLAYER'S-EYE AUDIT FAILED (reports and images in {OUT}/)`)
	process.exit(1)
end
print(`\nPLAYER'S-EYE AUDIT PASSED (reports and images in {OUT}/)`)
process.exit(0)
