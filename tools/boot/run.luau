--!nocheck
-- Boot smoke check: builds each game's place and starts its server (and
-- client) scripts under Lune with a thin Roblox shim (tools/boot/shim.luau).
--
--   lune run tools/boot/run [game|all] [--built] [--no-build] [--studio]
--                           [--no-client] [--no-join] [--settle 2] [--verbose]
--
-- By default each game is built fresh into build/boot-<game>.rbxl. `--built`
-- boots build/<game>.rbxl as tools/build.sh left it instead, so CI and the
-- publish workflows check the exact file that gets uploaded (environment
-- stamp included). `--no-build` reuses an earlier build/boot-<game>.rbxl.
--
-- What it catches: a config assert that fails at start-up, a require that
-- points nowhere, a nil index while the world is built or remotes are
-- registered, a start-up error on the client, a part built inside the
-- ground (the Baseplate). It cannot judge how anything
-- looks or plays; Studio still does that.
--
-- Exit code 1 when any game's server or client raised an error.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local Shim = require("./shim")

local args = table.clone(process.args)
local flags: { [string]: any } = {}
local positional: { string } = {}
do
	local i = 1
	while i <= #args do
		local a = args[i]
		if a == "--settle" then
			flags.settle = tonumber(args[i + 1])
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

local settle = flags.settle or 2
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

local function build(game: string): string
	if flags.built then
		local built = `build/{game}.rbxl`
		if not fs.isFile(built) then
			error(`{built} does not exist; run tools/build.sh {game} first or drop --built`)
		end
		return built
	end
	local path = `build/boot-{game}.rbxl`
	if not flags["no-build"] then
		fs.writeDir("build")
		local result = (process.exec or process.spawn)("rojo", { "build", `games/{game}`, "--output", path })
		if not result.ok then
			error(`rojo build failed for {game}:\n{result.stderr}`)
		end
	end
	return path
end

local failed = false

local function report(game: string, side: string, scripts: { string })
	local bugs = #Shim.errors
	local warns = 0
	for _, line in Shim.output do
		if string.sub(line, 1, 7) == "[warn] " then
			warns += 1
		end
	end
	print(`== {game} {side}: {#scripts} script(s), {bugs} error(s), {warns} warning(s)`)
	for _, name in scripts do
		print(`   ran {name}`)
	end
	for _, err in Shim.errors do
		failed = true
		print(`[BUG] {game} {side} ({err.where}): {err.message}`)
	end
	-- Identical lines (a warning from a loop) are shown once with a count;
	-- tracebacks are cut to their first lines.
	local seen: { [string]: number } = {}
	local order: { string } = {}
	for _, line in Shim.output do
		local show = flags.verbose
			or string.sub(line, 1, 7) == "[warn] "
			or string.sub(line, 1, 8) == "[prompt]"
			or string.sub(line, 1, 6) == "[kick]"
		if show then
			local short = {}
			for i, part in string.split(line, "\n") do
				if i > 4 then
					table.insert(short, "      ...")
					break
				end
				table.insert(short, part)
			end
			local text = table.concat(short, "\n")
			if seen[text] == nil then
				seen[text] = 0
				table.insert(order, text)
			end
			seen[text] += 1
		end
	end
	for _, text in order do
		print(`      {text}{if seen[text] > 1 then ` (x{seen[text]})` else ""}`)
	end
	local gaps = {}
	for name, count in Shim.gaps do
		table.insert(gaps, `{name} x{count}`)
	end
	table.sort(gaps)
	if #gaps > 0 then
		print(`      shim guessed at: {table.concat(gaps, ", ")}`)
	end
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

local function runAll(game: any, scripts: { any }, where: string): { string }
	local ran = {}
	for _, inst in scripts do
		local ok, err = pcall(Shim.runScript, game, inst, false)
		if not ok then
			table.insert(Shim.errors, { where = `{where} {inst:GetFullName()}`, message = err })
		end
		table.insert(ran, inst:GetFullName())
	end
	return ran
end

local function takeErrors(): { any }
	local errors = Shim.errors
	Shim.errors = {}
	return errors
end

local function takeOutput(): { string }
	local output = Shim.output
	Shim.output = {}
	return output
end

-- Nothing the server builds may sit inside the ground. Rojo silently drops a
-- part's `Position` from a project file when it builds a place, which once
-- left every Baseplate centred on Y = 0: its top at Y = 10, ten studs above
-- the floors the games build at ground level, so in Roblox the whole map was
-- buried. A part whose centre is inside a Baseplate is that bug.
local GROUND_EPSILON = 0.05

local function buriedParts(game: any): { string }
	local workspace = game:GetService("Workspace")
	local grounds = {}
	for _, child in workspace:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Baseplate" then
			table.insert(grounds, child)
		end
	end
	local buried: { string } = {}
	for _, ground in grounds do
		local half = ground.Size / 2
		for _, d in workspace:GetDescendants() do
			if d ~= ground and d:IsA("BasePart") and not d:IsA("Terrain") then
				local p = ground.CFrame:PointToObjectSpace(d.CFrame.Position)
				local inside = math.abs(p.X) < half.X
					and math.abs(p.Z) < half.Z
					and p.Y < half.Y - GROUND_EPSILON
					and p.Y > -half.Y
				if inside then
					table.insert(
						buried,
						`{d:GetFullName()} is {string.format("%.1f", half.Y - p.Y)} studs under the ground`
					)
				end
			end
		end
	end
	return buried
end

local function checkGround(game: any)
	local buried = buriedParts(game)
	if #buried > 0 then
		local shown = table.move(buried, 1, math.min(#buried, 5), 1, {})
		table.insert(Shim.errors, {
			where = "world",
			message = `{#buried} part(s) inside the Baseplate, for example:\n      {table.concat(
				shown,
				"\n      "
			)}`,
		})
	end
end

-- One game: start the server, let a player join, start that player's client
-- against the same tree (as a real client would see it), then let them leave.
local function bootGame(gameName: string, placePath: string)
	Shim.reset()
	Shim.side = "server"
	Shim.studio = flags.studio == true
	Shim.quiet = true
	Shim.install()
	local game = roblox.deserializePlace(fs.readFile(placePath))
	Shim.baseEnvironment(game)
	local players = game:GetService("Players")

	local serverScripts = scriptsUnder(game:GetService("ServerScriptService"), "Script")
	local ran = runAll(game, serverScripts, "start-up")
	task.wait(settle)

	local player
	if not flags["no-join"] then
		player = Shim.newPlayer(game, 1, "BootTester")
		table.insert(Shim.players, player)
		players.PlayerAdded:Fire(player)
		task.wait(settle * 2)
		table.insert(ran, "join of one player")
	end
	checkGround(game)
	table.insert(ran, "ground check (nothing built inside the Baseplate)")

	local clientRan, clientErrors, clientOutput = nil, nil, nil
	local serverStarted = #Shim.errors == 0
	if not flags["no-client"] and player and not serverStarted then
		print(`== {gameName} client: skipped, the server did not start`)
	end
	if not flags["no-client"] and player and serverStarted then
		local serverErrors, serverOutput = takeErrors(), takeOutput()
		Shim.resetModules()
		Shim.side = "client"
		players.LocalPlayer = player
		local camera = Shim.seed(roblox.Instance.new("Camera"))
		camera.Name = "Camera"
		camera.Parent = game:GetService("Workspace")
		game:GetService("Workspace").CurrentCamera = camera
		local clientScripts = scriptsUnder(game:GetService("StarterPlayer"), "LocalScript")
		for _, s in scriptsUnder(game:GetService("StarterGui"), "LocalScript") do
			table.insert(clientScripts, s)
		end
		for _, s in scriptsUnder(game:GetService("ReplicatedFirst"), "LocalScript") do
			table.insert(clientScripts, s)
		end
		clientRan = runAll(game, clientScripts, "client start-up")
		task.wait(settle)
		clientErrors, clientOutput = takeErrors(), takeOutput()
		-- Back to the server for the leave.
		Shim.side = "server"
		Shim.errors, Shim.output = serverErrors, serverOutput
	end

	if player then
		players.PlayerRemoving:Fire(player)
		table.remove(Shim.players, 1)
		player.Parent = nil
		task.wait(settle)
		table.insert(ran, "leave of that player")
	end
	report(gameName, "server", ran)
	if clientRan then
		Shim.errors, Shim.output = clientErrors, clientOutput
		report(gameName, "client", clientRan)
	end
end

for _, gameName in games do
	local placePath = build(gameName)
	local ok, err = pcall(bootGame, gameName, placePath)
	if not ok then
		failed = true
		print(`[BUG] {gameName}: the boot check itself failed: {err}`)
	end
end

if failed then
	print("\nBOOT CHECK FAILED")
	process.exit(1)
end
print("\nBOOT CHECK PASSED")
process.exit(0)
