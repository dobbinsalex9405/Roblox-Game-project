--!strict
local Prefilter = require("../feedback/prefilter")
local lib = require("../feedback/lib")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local nextId = 0
local function report(fields: { [string]: any }): { [string]: any }
	nextId += 1
	local r: { [string]: any } = {
		id = `r{nextId}`,
		at = nextId,
		game = "hatchery-heist",
		category = "other",
		rating = 0,
		text = "",
		userId = nextId,
		recentErrors = {},
	}
	for k, v in fields do
		r[k] = v
	end
	return r
end

describe("feedback prefilter", function()
	it("normalizes text into lower-case words", function()
		expect(Prefilter.normalize("  I CAN'T jump!!  The egg… is GONE?? ")).toBe(
			"i cant jump the egg is gone"
		)
		expect(Prefilter.normalize("won\u{2019}t load")).toBe("wont load")
		expect(Prefilter.normalize("Café — très bien 🙂")).toBe("café très bien")
		expect(Prefilter.normalize("bad \255 bytes")).toBe("bad bytes")
	end)

	it("matches whole words and phrases only", function()
		local tags = Prefilter.tags("It doesn't work and I lost my robux")
		expect(tags.sev1).toEqual({ "lost", "robux" })
		expect(tags.sev2).toEqual({ "doesnt work" })
		expect(Prefilter.tags("payday is a great update").sev1).toBeNil()
		expect(Prefilter.tags("so laggy today").perf).toEqual({ "laggy" })
	end)

	it("over-escalates: warning words beat the category the player picked", function()
		expect((Prefilter.priority(report({ category = "idea", text = "the shop wont let me buy pets" })))).toBe(
			"sev1"
		)
		expect((Prefilter.priority(report({ category = "other", text = "my egg disappeared" })))).toBe("sev1")
		expect((Prefilter.priority(report({ category = "idea", text = "I got stuck in a wall" })))).toBe(
			"sev2"
		)
		expect((Prefilter.priority(report({ category = "bug", text = "the colours look odd" })))).toBe("sev2")
		local withError =
			report({ category = "idea", text = "more maps", recentErrors = { { signature = "ab" } } })
		expect((Prefilter.priority(withError))).toBe("sev2")
		expect((Prefilter.priority(report({ category = "other", text = "kinda laggy" })))).toBe("perf")
		expect((Prefilter.priority(report({ category = "other", text = "meh", rating = 2 })))).toBe("check")
		expect((Prefilter.priority(report({ category = "idea", text = "add dragons please", rating = 5 })))).toBeNil()
		expect((Prefilter.priority(report({ category = "other", text = "love this game", rating = 1 })))).toBe(
			"check"
		)
	end)

	it("dedupes the same text and the same client error into one group", function()
		local reports = {
			report({ category = "bug", text = "Egg is stuck!" }),
			report({ category = "bug", text = "egg is STUCK" }),
			report({ category = "bug", text = "shop broke", recentErrors = { { signature = "e1" } } }),
			report({ category = "bug", text = "can't open shop", recentErrors = { { signature = "e1" } } }),
			report({ category = "idea", text = "more mounts" }),
		}
		local result = Prefilter.run(reports)
		expect(#result.items).toBe(2)
		expect(result.quiet).toBe(1)
		for _, item in result.items do
			expect(item.reports).toBe(2)
			expect(item.players).toBe(2)
		end
		local errorGroup = if result.items[1].errors[1] == "e1" then result.items[1] else result.items[2]
		expect(errorGroup.errors).toEqual({ "e1" })
		expect(errorGroup.tags).toEqual({ "broke", "cant", "client-error" })
	end)

	it("ranks sev1 first, then by how many players hit it", function()
		local reports = {
			report({ category = "bug", text = "stuck in wall" }),
			report({ category = "bug", text = "stuck under map" }),
			report({ category = "bug", text = "stuck under map" }),
			report({ category = "other", text = "lag" }),
			report({ category = "other", text = "lost my robux purchase" }),
		}
		local items = Prefilter.run(reports).items
		expect(items[1].priority).toBe("sev1")
		expect(items[2].sample).toBe("stuck under map")
		expect(items[3].sample).toBe("stuck in wall")
		expect(items[4].priority).toBe("perf")
	end)

	it("caps reports per player and groups per game, without losing the overflow", function()
		local reports = {}
		for i = 1, 8 do
			table.insert(reports, report({ userId = 99, category = "bug", text = `spam bug {i}` }))
		end
		for i = 1, 5 do
			table.insert(reports, report({ game = "depthbound", category = "bug", text = `bug number {i}` }))
		end
		local result = Prefilter.run(reports, { maxPerReporter = 3, maxPerGame = 4 })
		expect(result.cappedReporters).toBe(5)
		local hh, db = 0, 0
		for _, item in result.items do
			if item.game == "hatchery-heist" then
				hh += 1
			else
				db += 1
			end
		end
		expect(hh).toBe(3)
		expect(db).toBe(4)
		expect(result.cappedGroups.depthbound).toBe(1)
		expect(#result.overflow).toBe(1)
	end)

	it("gives each group a stable fingerprint, shown on its line", function()
		local a = Prefilter.run({ report({ category = "bug", text = "Egg is stuck!" }) }).items[1]
		local b = Prefilter.run({ report({ category = "bug", text = "egg is STUCK", userId = 5 }) }).items[1]
		expect(a.fingerprint).toBe(b.fingerprint) -- same words, another day and player
		expect(#a.fingerprint).toBe(8)
		local other =
			Prefilter.run({ report({ game = "depthbound", category = "bug", text = "egg is stuck" }) })
		expect(other.items[1].fingerprint == a.fingerprint).toBe(false)
		local e1 = Prefilter.run({
			report({ category = "bug", text = "x", recentErrors = { { signature = "s1" } } }),
		})
		local e2 = Prefilter.run({
			report({ category = "bug", text = "y", recentErrors = { { signature = "s1" } } }),
		})
		expect(e1.items[1].fingerprint).toBe(e2.items[1].fingerprint) -- same error, different words
		expect(Prefilter.fingerprint("")).toBe("811c9dc5") -- FNV-1a offset basis
		expect(Prefilter.fingerprint("a")).toBe("e40c292c") -- FNV-1a reference value
		expect(Prefilter.markdown(e1, lib.escape)).toContain(`fp:{e1.items[1].fingerprint}`)
	end)

	it("keeps at most 20 report ids per group", function()
		local reports = {}
		for _ = 1, 30 do
			table.insert(reports, report({ category = "bug", text = "same bug" }))
		end
		local item = Prefilter.run(reports).items[1]
		expect(item.reports).toBe(30)
		expect(#item.reportIds).toBe(20)
	end)

	it("writes an escaped Needs triage section that sits at the top of the digest", function()
		local reports = {
			report({ category = "bug", text = "@alex lost <b>everything</b> #1" }),
			report({ category = "idea", text = "dragons" }),
		}
		local result = Prefilter.run(reports)
		local section = Prefilter.markdown(result, lib.escape)
		expect(section).toContain("## Needs triage")
		expect(section).toContain(
			`1. **sev1** hatchery-heist · fp:{result.items[1].fingerprint} · 1 player, 1 report · bug · lost`
		)
		expect(string.find(section, "@alex", 1, true)).toBeNil()
		expect(section).toContain("\\<b\\>")
		expect(section).toContain("1 reports needed no triage")
		local empty = Prefilter.markdown(Prefilter.run({}), lib.escape)
		expect(empty).toContain("Nothing escalated")

		for _, r in reports do
			r.build, r.placeVersion, r.platform, r.screen, r.fps = "abc", 1, "touch", "1x1", 60
			r.pingMs, r.sessionSeconds, r.position, r.context = 50, 60, "", {}
		end
		local md = lib.digest(reports :: any, "Player feedback", nil, section).markdown
		local top = string.find(md, "## Needs triage", 1, true) :: number
		local gameHeading = string.find(md, "## hatchery-heist", 1, true) :: number
		expect(top < gameHeading).toBe(true)
		expect(md).toContain(`id {reports[1].id}`)
	end)
end)
