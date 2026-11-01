--!strict
local ErrorReporter = require("@core/ErrorReporter")
local Feedback = require("@core/Feedback")
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local lib = require("../feedback/lib")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local T0 = 1793520000 -- 2026-11-01 08:00:00 UTC

-- Real batches, made by the same core module the games run.
local function makeBatches(): { { key: string, batch: Feedback.Batch } }
	local out = {}
	local feedback = Feedback.new({
		game = "hatchery-heist",
		build = "abc1234def",
		placeVersion = 7,
		server = "job-1",
		write = function(key, batch)
			table.insert(out, { key = key, batch = batch })
			return true
		end,
		filter = function(_userId, text)
			return true, text
		end,
	})
	local function info(userId: number): Feedback.PlayerInfo
		return {
			userId = userId,
			accountAgeDays = 3,
			locale = "en-us",
			sessionSeconds = 600,
			pingMs = 90,
			position = "1,2,3",
			context = { coins = 50, mounted = true },
		}
	end
	local client = { platform = "touch", screen = "844x390", fps = 55 }
	feedback:noteError(1, "c0ffee00", "attempt to index nil with 'Egg'", T0 - 5)
	feedback:submit(
		info(1),
		{ category = "bug", text = "egg vanished @alex #3 <b>", rating = 2, client = client },
		T0
	)
	feedback:noteError(2, "c0ffee00", "attempt to index nil with 'Egg'", T0 - 9)
	feedback:submit(
		info(2),
		{ category = "bug", text = "my egg is gone", rating = 0, client = client },
		T0 + 1
	)
	feedback:submit(
		info(3),
		{ category = "bug", text = "can't jump on the conveyor", rating = 0, client = client },
		T0 + 2
	)
	feedback:flush(T0 + 3, true)
	feedback:submit(
		info(4),
		{ category = "idea", text = "more mounts\nplease", rating = 5, client = client },
		T0 + 10
	)
	feedback:submit(info(5), { category = "other", text = "love it", rating = 4, client = client }, T0 + 11)
	feedback:flush(T0 + 12, true)
	return out
end

-- One ErrorQueue batch as a server writes it.
local function errorBatch(build: string, source: string, message: string, count: number, at: number): string
	local written: any = nil
	local reporter = ErrorReporter.new({
		game = "hatchery-heist",
		build = build,
		write = function(batch)
			written = batch
			return true
		end,
	})
	for _ = 1, count do
		reporter:record(source :: any, message, "Script 'Server', Line 1", at)
	end
	reporter:flush(at, true)
	return serde.encode("json", written)
end

-- A fake Open Cloud: `stores[name] = { [key] = body }`, listed two keys a page.
local function fakeOpenCloud(stores: { [string]: { [string]: string } }, state: { sawKey: boolean })
	local port = 18000 + math.random(1, 1999)
	local server = net.serve(port, function(request)
		if request.headers["x-api-key"] ~= "test-key" then
			state.sawKey = false
			return { status = 401, body = "no key" }
		end
		local query = request.query
		local store = stores[query.datastoreName]
		if store == nil then
			return { status = 404, body = "wrong store" }
		end
		if string.find(request.path, "/entries/entry", 1, true) then
			local body = store[query.entryKey]
			return if body then { status = 200, body = body } else { status = 404, body = "missing" }
		end
		local keys = {}
		for k in store do
			if string.sub(k, 1, #query.prefix) == query.prefix then
				table.insert(keys, k)
			end
		end
		table.sort(keys)
		local startAt = tonumber(query.cursor) or 1
		local page = {}
		for i = startAt, math.min(startAt + 1, #keys) do
			table.insert(page, { scope = "global", key = keys[i] })
		end
		return {
			status = 200,
			body = serde.encode("json", {
				keys = page,
				nextPageCursor = if startAt + 2 <= #keys then tostring(startAt + 2) else nil,
			}),
		}
	end)
	return port, server
end

describe("feedback tool", function()
	it("lists only configured games and environments", function()
		local targets = lib.targets({
			["$comment"] = "ignored",
			["hatchery-heist"] = {
				dev = { universeId = 5, placeId = 6 },
				staging = { universeId = 11, placeId = 12 },
				production = { universeId = 0, placeId = 0 },
			},
			depthbound = { production = { universeId = 21, placeId = 22 } },
		})
		expect(targets).toEqual({
			{ game = "depthbound", environment = "production", universeId = 21 },
			{ game = "hatchery-heist", environment = "staging", universeId = 11 },
		})
		expect(#lib.targets({ depthbound = { production = { universeId = 21 } } }, "staging")).toBe(0)
	end)

	it("builds Open Cloud URLs and never sends the key elsewhere", function()
		expect(lib.listUrl(9, "20261101", nil)).toBe(
			"https://apis.roblox.com/datastores/v1/universes/9/standard-datastores/datastore/entries"
				.. "?datastoreName=Feedback&prefix=20261101&limit=100"
		)
		expect(lib.listUrl(9, "20261101", "a b/c")).toContain("&cursor=a%20b%2Fc")
		expect(lib.entryUrl(9, "20261101-080003-job1-1")).toContain("entryKey=20261101-080003-job1-1")
		expect(lib.entryUrl(9, "k", "http://127.0.0.1:9000")).toContain("http://127.0.0.1:9000/datastores/")
		expect(function()
			lib.listUrl(9, "x", nil, "https://evil.example.com")
		end).toThrow("only be Roblox")
	end)

	it("turns UTC dates into the day prefixes the game writes", function()
		expect(lib.parseDate("2026-11-01")).toBe(T0 - 8 * 3600)
		expect(lib.parseDate("2024-02-29")).toBe(1709164800)
		expect(lib.dayPrefixes("2026-10-30", "2026-11-01")).toEqual({ "20261030", "20261031", "20261101" })
		expect(lib.dayPrefixes("2026-11-01", "2026-11-01")[1]).toBe(Feedback.dayPrefix(T0))
		expect(function()
			lib.dayPrefixes("2026-11-02", "2026-11-01")
		end).toThrow("before")
		expect(function()
			lib.parseDate("11/01/2026")
		end).toThrow("2026-11-01")
	end)

	it("reads stored batches and skips anything malformed", function()
		local batches = makeBatches()
		local decoded = serde.decode("json", serde.encode("json", batches[1].batch))
		local reports, reason = lib.reportsFrom(decoded)
		expect(reason).toBeNil()
		expect(#reports).toBe(3)
		expect(reports[1].text).toBe("egg vanished @alex #3 <b>")
		local none, why = lib.reportsFrom({ schema = 99, reports = {} })
		expect(#none).toBe(0)
		expect(why).toContain("schema 99")
		expect((lib.reportsFrom("garbage"))).toEqual({})
		local partial = lib.reportsFrom({ schema = 1, reports = { { id = "x" }, decoded.reports[1] } })
		expect(#partial).toBe(1)
	end)

	it("escapes player text so it cannot ping, link or format", function()
		local escaped = lib.escape("hi @alex see #12 **bold** <img> `x`\nline")
		expect(string.find(escaped, "@alex", 1, true)).toBeNil()
		expect(escaped).toContain("\\#12")
		expect(escaped).toContain("\\*\\*bold\\*\\*")
		expect(escaped).toContain("\\<img\\>")
		expect(string.find(escaped, "\n", 1, true)).toBeNil()
		expect(lib.reporterTag(12345)).toBe(lib.reporterTag(12345))
		expect(lib.reporterTag(12345) == lib.reporterTag(12346)).toBe(false)
	end)

	it("writes a digest grouped by game, category and client error", function()
		local reports = {}
		for _, written in makeBatches() do
			for _, report in lib.reportsFrom(written.batch) do
				report.environment = "production"
				table.insert(reports, report)
			end
		end
		local digest = lib.digest(reports, "Player feedback 2026-11-01")
		expect(digest.total).toBe(5)
		expect(digest.bugs).toBe(3)
		expect(digest.ideas).toBe(1)
		expect(digest.other).toBe(1)
		local md = digest.markdown
		expect(md).toContain("# Player feedback 2026-11-01")
		expect(md).toContain("## hatchery-heist")
		expect(md).toContain("5 reports from 5 players, average fun 3.7/5 from 3 ratings.")
		expect(md).toContain("### Bugs (3)")
		expect(md).toContain("**Error `c0ffee00`** (2 reports)")
		expect(md).toContain("**No client error attached**")
		expect(md).toContain("### Ideas (1)")
		expect(md).toContain("more mounts / please")
		expect(md).toContain("state: coins=50, mounted=true · at 1,2,3")
		expect(md).toContain("v7 · abc1234 · touch 844x390 · 55 fps · 90 ms · 10m in")
		-- No user ids in the issue text.
		expect(string.find(md, "userId", 1, true)).toBeNil()
		expect(lib.digest({}, "Empty").markdown).toContain("No feedback in this window.")
	end)

	it("cuts a huge digest to fit a GitHub issue", function()
		local report = lib.reportsFrom(makeBatches()[1].batch)[1]
		local many = {}
		for i = 1, 400 do
			local copy = table.clone(report)
			copy.text = string.rep("ü", 400)
			copy.at = T0 + i
			table.insert(many, copy)
		end
		local digest = lib.digest(many, "Big", 20000)
		expect(#digest.markdown <= 20000).toBe(true)
		expect(utf8.len(digest.markdown) ~= nil).toBe(true)
		expect(digest.markdown).toContain("full list is in the run's feedback artifact")
	end)

	it("pulls from Open Cloud end to end (against a local fake)", function()
		local batches = makeBatches()
		local state = { sawKey = true }
		local port, server = fakeOpenCloud({
			Feedback = {
				[batches[1].key] = serde.encode("json", batches[1].batch),
				[batches[2].key] = serde.encode("json", batches[2].batch),
				["20261101-120000-other-1"] = "{not json",
			},
			ErrorQueue = {
				["20261101-090000-srv1-1"] = errorBatch("abc1234def", "client", "UI nil", 3, T0 + 3600),
				["20261031-230000-srv1-1"] = errorBatch("abc1234def", "server", "old day", 1, T0 - 9 * 3600),
			},
		}, state)
		local sawKey = state.sawKey

		local dir = "build/feedback-test"
		fs.writeDir(dir)
		fs.writeFile(
			`{dir}/environments.json`,
			serde.encode("json", {
				["hatchery-heist"] = {
					staging = { universeId = 0, placeId = 0 },
					production = { universeId = 4242, placeId = 1 },
				},
			})
		)
		local result = process.exec("lune", {
			"run",
			"tools/feedback/pull",
			"--from",
			"2026-11-01",
			"--environments",
			`{dir}/environments.json`,
			"--out",
			`{dir}/out`,
		}, {
			env = {
				ROBLOX_READ_API_KEY = "test-key",
				OPEN_CLOUD_BASE_URL = `http://127.0.0.1:{port}`,
				GITHUB_OUTPUT = `{dir}/github-output`,
			},
		})
		server:stop()
		sawKey = state.sawKey

		expect(result.ok).toBe(true)
		expect(sawKey).toBe(true)
		expect(string.find(result.stdout, "test-key", 1, true)).toBeNil()
		local summary = serde.decode("json", fs.readFile(`{dir}/out/summary.json`))
		expect(summary.total).toBe(5)
		expect(summary.bugs).toBe(3)
		expect(#summary.problems).toBe(1)
		expect(summary.problems[1]).toContain("20261101-120000-other-1")
		local digest = fs.readFile(`{dir}/out/digest.md`)
		expect(digest).toContain("# Player feedback 2026-11-01")
		expect(digest).toContain("## Problems reading feedback")
		expect(digest).toContain("## Needs triage")
		local block = string.match(digest, "<!%-%- loop%-lab%-triage v1\n(.-)\n%-%->")
		expect(block ~= nil).toBe(true)
		local parsed = serde.decode("json", block :: string)
		expect(parsed.version).toBe(1)
		expect(#parsed.items).toBe(2)
		expect(parsed.items[1].priority).toBe("sev1")
		expect(string.find(block :: string, "egg", 1, true)).toBeNil() -- no player text, only keyword tags
		expect(summary.escalated).toBe(2)
		local triage = serde.decode("json", fs.readFile(`{dir}/out/triage.json`))
		expect(#triage.items).toBe(2)
		expect(triage.items[1].priority).toBe("sev1") -- "egg vanished", grouped by its client error
		expect(triage.items[1].reports).toBe(2)
		local lines = 0
		for _ in string.gmatch(fs.readFile(`{dir}/out/reports.jsonl`), "[^\n]+") do
			lines += 1
		end
		expect(lines).toBe(5)
		local outputs = fs.readFile(`{dir}/github-output`)
		expect(outputs).toContain("configured=true")
		expect(outputs).toContain("total=5")
		expect(outputs).toContain("escalated=2")
		-- The error queue for the same day: one client error, under the STOP count.
		expect(outputs).toContain("errors=1")
		expect(outputs).toContain("stop=false")
		expect(digest).toContain("## Errors")
		expect(digest).toContain("issue hatchery-heist production · build abc1234 · client")
		expect(string.find(digest, "old day", 1, true)).toBeNil() -- another day's key is not read
		expect(parsed.stop).toBe(false)
		expect(#parsed.errors).toBe(1)
		-- Errors sit between the triage list and the per-game feedback.
		local errorsAt = string.find(digest, "## Errors", 1, true) :: number
		expect(errorsAt < (string.find(digest, "## hatchery-heist", 1, true) :: number)).toBe(true)
		expect(errorsAt > (string.find(digest, "## Needs triage", 1, true) :: number)).toBe(true)
		fs.removeDir(dir)
	end)

	it("sweeps the last hours for one build after a publish", function()
		local now = T0 + 2 * 3600
		local state = { sawKey = true }
		local port, server = fakeOpenCloud({
			Feedback = {},
			ErrorQueue = {
				-- Inside the last hour, the published build: a server error = STOP.
				["20261101-093000-srv1-1"] = errorBatch(
					"feedbee1234",
					"server",
					"DataStore failed",
					1,
					now - 1800
				),
				-- Inside the hour, an older build: ignored by --build.
				["20261101-093100-srv2-1"] = errorBatch("0ld0ld0", "server", "old build", 5, now - 1700),
				-- The new build, but before the window.
				["20261101-080500-srv1-1"] = errorBatch("feedbee1234", "client", "too early", 50, now - 6900),
			},
		}, state)
		local dir = "build/feedback-test-sweep"
		fs.writeDir(dir)
		fs.writeFile(
			`{dir}/environments.json`,
			serde.encode("json", { ["hatchery-heist"] = { staging = { universeId = 7, placeId = 1 } } })
		)
		local result = process.exec("lune", {
			"run",
			"tools/feedback/pull",
			"--hours",
			"1",
			"--build",
			"feedbee",
			"--environments",
			`{dir}/environments.json`,
			"--out",
			`{dir}/out`,
		}, {
			env = {
				ROBLOX_READ_API_KEY = "test-key",
				OPEN_CLOUD_BASE_URL = `http://127.0.0.1:{port}`,
				GITHUB_OUTPUT = `{dir}/github-output`,
				FEEDBACK_NOW = tostring(now),
			},
		})
		server:stop()
		expect(result.ok).toBe(true)
		expect(result.stdout).toContain("STOP")
		local outputs = fs.readFile(`{dir}/github-output`)
		expect(outputs).toContain("title=Error sweep: last 1 h (build feedbee)")
		expect(outputs).toContain("errors=1")
		expect(outputs).toContain("stop=true")
		local digest = fs.readFile(`{dir}/out/digest.md`)
		expect(digest).toContain("**STOP: 1 error group(s)")
		expect(digest).toContain("DataStore failed")
		expect(string.find(digest, "old build", 1, true)).toBeNil()
		expect(string.find(digest, "too early", 1, true)).toBeNil()
		fs.removeDir(dir)
	end)

	it("still writes the digest, flagged for hand triage, when the prefilter fails", function()
		local batches = makeBatches()
		local port = 19000 + math.random(1, 999)
		local server = net.serve(port, function(request)
			if string.find(request.path, "/entries/entry", 1, true) then
				return { status = 200, body = serde.encode("json", batches[1].batch) }
			end
			return { status = 200, body = serde.encode("json", { keys = { { key = batches[1].key } } }) }
		end)
		local dir = "build/feedback-test-broken"
		fs.writeDir(dir)
		fs.writeFile(
			`{dir}/environments.json`,
			serde.encode("json", { ["hatchery-heist"] = { production = { universeId = 1, placeId = 1 } } })
		)
		local result = process.exec("lune", {
			"run",
			"tools/feedback/pull",
			"--from",
			"2026-11-01",
			"--environments",
			`{dir}/environments.json`,
			"--out",
			`{dir}/out`,
		}, {
			env = {
				ROBLOX_READ_API_KEY = "test-key",
				OPEN_CLOUD_BASE_URL = `http://127.0.0.1:{port}`,
				FEEDBACK_TEST_BREAK_PREFILTER = "1",
			},
		})
		server:stop()
		expect(result.ok).toBe(true)
		local digest = fs.readFile(`{dir}/out/digest.md`)
		expect(digest).toContain("Prefilter failed: triage every bug by hand.")
		expect(digest).toContain('"failed":true')
		expect(digest).toContain("### Bugs (3)") -- the reports are all still there
		fs.removeDir(dir)
	end)

	it("does nothing, successfully, before anything is set up", function()
		local result = process.exec(
			"lune",
			{ "run", "tools/feedback/pull" },
			{ env = { ROBLOX_READ_API_KEY = "" } }
		)
		expect(result.ok).toBe(true)
		expect(result.stdout).toContain("nothing to pull")
	end)
end)
