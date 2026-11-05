--!strict
-- The real-engine cloud check (tools/cloud): URLs, task states, the probe
-- script it sends, and a whole run against a fake Open Cloud on this machine.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local net = require("@lune/net")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local lib = require("../cloud/lib")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local function json(v: any): string
	return serde.encode("json", v)
end

describe("cloud check", function()
	it("saves without publishing and runs on that exact version", function()
		expect(lib.saveUrl(1, 2)).toBe(
			"https://apis.roblox.com/universes/v1/1/places/2/versions?versionType=Saved"
		)
		expect(lib.taskUrl(1, 2, 7)).toBe(
			"https://apis.roblox.com/cloud/v2/universes/1/places/2/versions/7/luau-execution-session-tasks"
		)
		expect(lib.pathUrl("universes/1/places/2/versions/7/luau-execution-sessions/a-b/tasks/c-d")).toBe(
			"https://apis.roblox.com/cloud/v2/universes/1/places/2/versions/7/luau-execution-sessions/a-b/tasks/c-d"
		)
	end)

	it("never sends the key anywhere but Roblox or this machine", function()
		expect(function()
			lib.saveUrl(1, 2, "https://evil.example.com")
		end).toThrow("only be Roblox")
		expect(function()
			lib.pathUrl("../../elsewhere")
		end).toThrow("unexpected task path")
	end)

	it("reads task states", function()
		expect(lib.outcome({ state = "PROCESSING" }).done).toBe(false)
		local done = lib.outcome({ state = "COMPLETE", output = { results = { "{}" } } })
		expect(done.ok).toBe(true)
		local failed = lib.outcome({ state = "FAILED", error = { code = "SCRIPT_ERROR", message = "boom" } })
		expect(failed.done).toBe(true)
		expect(failed.error).toBe("SCRIPT_ERROR: boom")
		expect(function()
			lib.report({}, function(s)
				return serde.decode("json", s)
			end)
		end).toThrow("no JSON report")
	end)

	it("the probe script it sends compiles, with the World checks and texts embedded", function()
		local script = lib.script(
			fs.readFile("tools/audit/World.luau"),
			fs.readFile("tools/cloud/probe.luau"),
			{ { path = "a", text = "]] ]==] tricky", font = "Gotham", size = 14, width = 10, height = 10 } },
			json
		)
		luau.compile(script) -- throws on a syntax error
		-- The embedded World module loads on its own (what loadstring does in Roblox).
		local world = luau.load(fs.readFile("tools/audit/World.luau"))()
		expect(type(world.check)).toBe("function")
	end)

	it("a probe that checked nothing fails instead of passing", function()
		local rules = {}
		for _, f in lib.coverage({ started = 0, parts = 0 }) do
			table.insert(rules, f.rule)
		end
		expect(rules).toEqual({ "engine.no-scripts", "engine.empty-world" })
		expect(#lib.coverage({ started = 3, parts = 120 })).toBe(0)
	end)

	it("runs end to end against a fake Open Cloud: save, task, poll, logs, report", function()
		local seen: { string } = {}
		local polls = 0
		local report = json({
			findings = { { severity = "WARN", rule = "engine.loose-parts", message = "1 loose" } },
			counts = { FAIL = 0, WARN = 1 },
			started = 3,
			parts = 10,
			labels = 2,
			spawns = 1,
			texts = 0,
		})
		local taskPath =
			"universes/10774144065/places/110929970966106/versions/7/luau-execution-sessions/s1/tasks/t1"
		local port = 20000 + math.random(0, 9999)
		local server = net.serve(port, function(req: any)
			table.insert(seen, `{req.method} {req.path}`)
			if req.headers["x-api-key"] ~= "test-key" then
				return { status = 401, body = "no key" }
			end
			if req.method == "POST" and string.find(req.path, "/versions$") then
				return { status = 200, body = json({ versionNumber = 7 }) }
			elseif req.method == "POST" then
				local body = serde.decode("json", req.body)
				assert(type(body.script) == "string" and #body.script > 1000, "the probe script was sent")
				return { status = 200, body = json({ path = taskPath, state = "QUEUED" }) }
			elseif string.find(req.path, "/logs$") then
				return {
					status = 200,
					body = json({ luauExecutionSessionTaskLogs = { { messages = { "probe says hi" } } } }),
				}
			end
			polls += 1
			local state = if polls < 2 then "PROCESSING" else "COMPLETE"
			return {
				status = 200,
				body = json({ path = taskPath, state = state, output = { results = { report } } }),
			}
		end)
		-- The tool reads the real Staging ids from ops/environments.json; the
		-- fake answers for any ids.
		local dir = "build/test-cloud"
		fs.writeDir(dir)
		local place = `{dir}/tiny.rbxl`
		fs.writeFile(place, roblox.serializePlace(roblox.Instance.new("DataModel")))
		local result = process.exec(
			"lune",
			{ "run", "tools/cloud/run", "hatchery-heist", "--place", place },
			{
				env = {
					ROBLOX_API_KEY = "test-key",
					OPEN_CLOUD_BASE_URL = `http://127.0.0.1:{port}`,
				},
			}
		)
		server:stop()
		expect(result.stdout).toContain("REAL-ENGINE CHECK PASSED")
		expect(result.stdout).toContain("[log] probe says hi")
		expect(result.stdout).toContain("Started 3 server script(s); 10 parts")
		expect(string.find(result.stdout, "test-key", 1, true)).toBeNil()
		expect(seen[1]).toContain("POST /universes/v1/")
		expect(seen[1]).toContain("/versions")
		fs.removeDir(dir)
	end)
end)
