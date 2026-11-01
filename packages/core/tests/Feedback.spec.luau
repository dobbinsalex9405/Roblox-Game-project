--!strict
local CoreRemotes = require("@core/CoreRemotes")
local Feedback = require("@core/Feedback")
local Net = require("@core/Net")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

type Written = { key: string, batch: Feedback.Batch }

local function setup(overrides: { [string]: any }?)
	local writes: { Written } = {}
	local filterCalls = 0
	local options: Feedback.Options = {
		game = "test-game",
		build = "abc123",
		placeVersion = 42,
		server = "1b2c3d4e-0000-1111-2222-333344445555",
		write = function(key, batch)
			table.insert(writes, { key = key, batch = batch })
			return true
		end,
		filter = function(_userId, text)
			filterCalls += 1
			return true,
				(string.gsub(text, "%d%d%d%d+", function(digits)
					return string.rep("#", #digits)
				end))
		end,
	}
	for key, value in overrides or {} do
		(options :: any)[key] = value
	end
	return Feedback.new(options), writes, function()
		return filterCalls
	end
end

local function info(userId: number?): Feedback.PlayerInfo
	return {
		userId = userId or 1,
		accountAgeDays = 30,
		locale = "en-us",
		sessionSeconds = 754.6,
		pingMs = 81.2,
		position = "10,3,-20",
		context = { coins = 1200, area = "Mine", mounted = false },
	}
end

local function submission(text: string, category: string?, rating: number?): Feedback.Submission
	return {
		category = (category or "bug") :: any,
		text = text,
		rating = rating or 0,
		client = { platform = "touch", screen = "844x390", fps = 58.7 },
	}
end

local DAY = 86400
local T0 = 1793520000 -- 2026-11-01 08:00:00 UTC

describe("Feedback", function()
	it("stores a tagged, filtered report and writes it in one batch", function()
		local feedback, writes = setup()
		feedback:noteError(1, "deadbeef", "attempt to index nil with 'Coins'", T0 - 30)
		local ok, message = feedback:submit(info(), submission("Egg froze, call me 5551234", "bug", 2), T0)
		expect(ok).toBe(true)
		expect(message).toBe(Feedback.MESSAGES.sent)
		expect(feedback:flush(T0 + 1)).toBe(true)
		expect(#writes).toBe(1)
		local batch = writes[1].batch
		expect(batch.schema).toBe(1)
		expect(batch.game).toBe("test-game")
		local report = batch.reports[1]
		expect(report.text).toBe("Egg froze, call me #######")
		expect(report.category).toBe("bug")
		expect(report.rating).toBe(2)
		expect(report.build).toBe("abc123")
		expect(report.placeVersion).toBe(42)
		expect(report.platform).toBe("touch")
		expect(report.screen).toBe("844x390")
		expect(report.fps).toBe(58)
		expect(report.sessionSeconds).toBe(754)
		expect(report.pingMs).toBe(81)
		expect(report.position).toBe("10,3,-20")
		expect(report.context).toEqual({ coins = 1200, area = "Mine", mounted = false })
		expect(#report.recentErrors).toBe(1)
		expect(report.recentErrors[1].signature).toBe("deadbeef")
		expect(report.recentErrors[1].secondsAgo).toBe(30)
		expect(feedback:pending()).toBe(0)
	end)

	it("uses dated keys that list one day by prefix and fit the DataStore limit", function()
		local key = Feedback.batchKey(T0 + 3725, "1b2c3d4e-0000-1111-2222-333344445555", 7)
		expect(key).toBe("20261101-090205-1b2c3d4e0000111122223333-7")
		expect(#key <= 50).toBe(true)
		expect(string.sub(key, 1, 8)).toBe(Feedback.dayPrefix(T0))
		expect(Feedback.batchKey(T0, "", 1)).toBe("20261101-080000-studio-1")
		-- Two flushes in the same second never share a key.
		local feedback, writes = setup()
		feedback:submit(info(1), submission("first report"), T0)
		feedback:flush(T0, true)
		feedback:submit(info(2), submission("second report"), T0)
		feedback:flush(T0, true)
		expect(writes[1].key == writes[2].key).toBe(false)
	end)

	it("writes at most once per interval, however many reports arrive", function()
		local feedback, writes = setup()
		for userId = 1, 150 do
			feedback:submit(info(userId), submission(`report number {userId}`), T0 + userId * 0.2)
			feedback:flush(T0 + userId * 0.2)
		end
		expect(#writes).toBe(1)
		feedback:flush(T0 + 61)
		expect(#writes).toBe(2)
		expect(#writes[1].batch.reports + #writes[2].batch.reports).toBe(150)
	end)

	it("rate-limits each player: cooldown, duplicates and a daily cap", function()
		local feedback = setup({ dailyLimit = 3 })
		expect((feedback:submit(info(), submission("the shop is broken"), T0))).toBe(true)
		local ok, message = feedback:submit(info(), submission("another thing"), T0 + 10)
		expect(ok).toBe(false)
		expect(message).toBe(Feedback.MESSAGES.cooldown)
		ok, message = feedback:submit(info(), submission("The Shop is broken"), T0 + 100)
		expect(ok).toBe(false)
		expect(message).toBe(Feedback.MESSAGES.duplicate)
		expect((feedback:submit(info(), submission("second report"), T0 + 100))).toBe(true)
		expect((feedback:submit(info(), submission("third report"), T0 + 200))).toBe(true)
		ok, message = feedback:submit(info(), submission("fourth report"), T0 + 300)
		expect(ok).toBe(false)
		expect(message).toBe(Feedback.MESSAGES.daily)
		-- Another player is not affected, and the cap resets the next UTC day.
		expect((feedback:submit(info(2), submission("fourth report"), T0 + 300))).toBe(true)
		expect((feedback:submit(info(), submission("next day report"), T0 + DAY))).toBe(true)
	end)

	it("cleans text, caps it in characters and refuses empty or broken text", function()
		local feedback, writes = setup({ maxLength = 10 })
		expect((feedback:submit(info(1), submission("  a\0b\tc  \r\n\n\n\nd  "), T0))).toBe(true)
		expect((feedback:submit(info(2), submission(string.rep("é", 40)), T0))).toBe(true)
		local ok, message = feedback:submit(info(3), submission("  \n "), T0)
		expect(ok).toBe(false)
		expect(message).toBe(Feedback.MESSAGES.tooShort)
		ok, message = feedback:submit(info(4), submission("bad \255\254 bytes"), T0)
		expect(ok).toBe(false)
		expect(message).toBe(Feedback.MESSAGES.badText)
		feedback:flush(T0, true)
		local reports = writes[1].batch.reports
		expect(reports[1].text).toBe("a b c\n\nd")
		expect(reports[2].text).toBe(string.rep("é", 10))
	end)

	it("refuses bad categories, ratings and client info", function()
		local feedback = setup()
		local ok, message = feedback:submit(info(), submission("hello there", "praise"), T0)
		expect(ok).toBe(false)
		expect(message).toBe(Feedback.MESSAGES.badCategory)
		expect((feedback:submit(info(), submission("hello there", "idea", 6), T0))).toBe(false)
		expect((feedback:submit(info(), submission("hello there", "idea", 2.5), T0))).toBe(false)
		local weird = submission("hello there")
		weird.client = { platform = "toaster", screen = "1x1", fps = 60 } :: any
		expect((feedback:submit(info(), weird, T0))).toBe(false)
		expect((feedback:submit(info(), "not a table" :: any, T0))).toBe(false)
		expect((feedback:submit(info(), submission("hello there", "idea", 5), T0))).toBe(true)
	end)

	it("never stores unfiltered text: a filter failure refuses the report and does not count", function()
		local fail = true
		local feedback, writes = setup({
			filter = function(_userId: number, text: string)
				if fail then
					error("TextService is down")
				end
				return true, text
			end,
		})
		local ok, message = feedback:submit(info(), submission("the raid button does nothing"), T0)
		expect(ok).toBe(false)
		expect(message).toBe(Feedback.MESSAGES.filter)
		fail = false
		-- Not counted against the cooldown: the retry goes through at once.
		expect((feedback:submit(info(), submission("the raid button does nothing"), T0 + 1))).toBe(true)
		feedback:flush(T0 + 2, true)
		expect(#writes).toBe(1)
	end)

	it("refuses a report the filter blanked out entirely", function()
		local feedback = setup({
			filter = function(_userId: number, text: string)
				return true, (string.gsub(text, "[^%s]", "#"))
			end,
		})
		local ok, message = feedback:submit(info(), submission("something rude"), T0)
		expect(ok).toBe(false)
		expect(message).toBe(Feedback.MESSAGES.empty)
	end)

	it("a player cannot send a second report while the first is being filtered", function()
		local feedback: Feedback.Feedback
		local inner: { any }? = nil
		feedback = setup({
			filter = function(_userId: number, text: string)
				-- Simulates a second click arriving while the filter yields.
				local ok, message = feedback:submit(info(), submission("second click"), T0)
				inner = { ok, message }
				return true, text
			end,
		})
		expect((feedback:submit(info(), submission("first click"), T0))).toBe(true)
		expect((inner :: any)[1]).toBe(false)
		expect((inner :: any)[2]).toBe(Feedback.MESSAGES.busy)
		expect(feedback:pending()).toBe(1)
	end)

	it("keeps reports when a write fails and sends them with the next batch", function()
		local failWrites = true
		local writes = {}
		local feedback = setup({
			write = function(_key: string, batch: Feedback.Batch)
				if failWrites then
					error("DataStore request was rejected")
				end
				table.insert(writes, batch)
				return true
			end,
		})
		feedback:submit(info(1), submission("first report"), T0)
		expect(feedback:flush(T0 + 1, true)).toBe(false)
		expect(feedback:pending()).toBe(1)
		feedback:submit(info(2), submission("second report"), T0 + 5)
		failWrites = false
		expect(feedback:flush(T0 + 70)).toBe(true)
		expect(#writes[1].reports).toBe(2)
		expect(writes[1].reports[1].text).toBe("first report")
	end)

	it("caps what it holds between writes", function()
		local feedback = setup({ maxPending = 2 })
		feedback:submit(info(1), submission("report one"), T0)
		feedback:submit(info(2), submission("report two"), T0)
		local ok, message = feedback:submit(info(3), submission("report three"), T0)
		expect(ok).toBe(false)
		expect(message).toBe(Feedback.MESSAGES.full)
	end)

	it("attaches only recent, distinct client errors, newest first, and forgets on leave", function()
		local feedback, writes = setup({ errorsPerPlayer = 2 })
		feedback:noteError(1, "old", "from long ago", T0 - 3600)
		feedback:noteError(1, "aaaa", "first", T0 - 50)
		feedback:noteError(1, "bbbb", "second", T0 - 40)
		feedback:noteError(1, "aaaa", "first again", T0 - 10)
		feedback:submit(info(1), submission("it broke twice"), T0)
		feedback:noteError(2, "cccc", "gone", T0 - 5)
		feedback:forget(2)
		feedback:submit(info(2), submission("it broke once"), T0)
		feedback:flush(T0, true)
		local first = writes[1].batch.reports[1].recentErrors
		expect(#first).toBe(2)
		expect(first[1].signature).toBe("aaaa")
		expect(first[1].message).toBe("first again")
		expect(first[2].signature).toBe("bbbb")
		expect(#writes[1].batch.reports[2].recentErrors).toBe(0)
	end)

	it("keeps only simple, bounded values from the game's context hook", function()
		local context: { [string]: any } = {
			coins = 5,
			nan = 0 / 0,
			inf = math.huge,
			name = string.rep("x", 300),
			nested = { a = 1 },
			["bad key"] = 1,
			fn = print,
			ok = true,
		}
		for i = 1, 20 do
			context[`k{string.format("%02d", i)}`] = i
		end
		local out = Feedback.sanitizeContext(context)
		local count = 0
		for _ in out do
			count += 1
		end
		expect(count).toBe(12)
		expect(out.coins).toBe(5)
		expect(out.nan).toBeNil()
		expect(out.inf).toBeNil()
		expect(out.nested).toBeNil()
		expect(out["bad key"]).toBeNil()
		expect(Feedback.sanitizeContext(nil)).toEqual({})
		expect(#(Feedback.sanitizeContext({ name = string.rep("x", 300) }).name :: string)).toBe(100)
	end)

	it("its remote accepts what the form sends and rejects anything else", function()
		local remote = CoreRemotes["Core:Feedback"]
		local server = Net.newServer({
			now = function()
				return 0
			end,
		})
		server:register(CoreRemotes)
		local got = 0
		server:on(remote, function()
			got += 1
		end)
		local client = { platform = "keyboard", screen = "1920x1080", fps = 60 }
		expect(server:dispatch("p1", remote.name, "idea", "more pets please", 5, client)).toBe("ok")
		expect(server:dispatch("p2", remote.name, "idea", "more pets please", 0, client)).toBe("ok")
		expect(server:dispatch("p3", remote.name, "nope", "text", 0, client)).toBe("schema")
		expect(server:dispatch("p4", remote.name, "bug", "text", 9, client)).toBe("schema")
		expect(server:dispatch("p5", remote.name, "bug", "text", 0, { platform = "keyboard" })).toBe("schema")
		expect(server:dispatch("p6", remote.name, "bug", string.rep("x", 2001), 0, client)).toBe("schema")
		expect(got).toBe(2)
	end)

	it("form helpers agree with the server's rules", function()
		expect(Feedback.sendBlocker(nil, "long enough", false, 0)).toBe("Pick a type")
		expect(Feedback.sendBlocker("bug", "  a ", false, 0)).toBe("Write a little more")
		expect(Feedback.sendBlocker("bug", "abc", false, 0)).toBeNil()
		expect(Feedback.sendBlocker("bug", "abc", true, 0)).toBe("Sending...")
		expect(Feedback.sendBlocker("bug", "abc", false, 41.2)).toBe("Wait 42s")
		expect(Feedback.clip(string.rep("ü", 600), Feedback.MAX_LENGTH)).toBe(string.rep("ü", 500))
		expect(Feedback.platformFrom({ touch = true, keyboard = false, gamepad = false, vr = false })).toBe(
			"touch"
		)
		expect(Feedback.platformFrom({ touch = true, keyboard = true, gamepad = true, vr = false })).toBe(
			"keyboard"
		)
		expect(Feedback.platformFrom({ touch = false, keyboard = false, gamepad = true, vr = false })).toBe(
			"gamepad"
		)
		expect(Feedback.platformFrom({ touch = false, keyboard = true, gamepad = false, vr = true })).toBe(
			"vr"
		)
		expect(Feedback.screenString(1920.6, 1080)).toBe("1920x1080")
		for _, category in Feedback.CATEGORIES do
			expect(type(Feedback.PLACEHOLDERS[category])).toBe("string")
		end
	end)
end)
