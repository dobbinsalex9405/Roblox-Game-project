--!strict
local DataService = require("@core/DataService")
local Fakes = require("./Fakes")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

-- A three-version history used by several tests:
--   v1 { version, coins }
--   v2 adds gems
--   v3 retires `gems` and replaces it with `wallet = { gems = n }`
local migrations: { DataService.Migration } = {
	{
		from = 1,
		run = function(data)
			data.gems = 0
		end,
	},
	{
		from = 2,
		retire = { "gems" },
		run = function(data)
			local old = data._retired and data._retired["v2.gems"] or 0
			data.wallet = { gems = old }
		end,
	},
}
local template = { version = 3, coins = 10, wallet = { gems = 0 }, stats = { joins = 0 } }

local function service(store)
	return DataService.new({ store = store, template = template, migrations = migrations })
end

describe("DataService", function()
	it("gives new players a copy of the template", function()
		local store = Fakes.store()
		local data = service(store)
		local p = Fakes.player(1)
		expect((data:load(p, 1))).toBe("loaded")
		expect(data:get(p)).toEqual(template)
		expect(data:get(p) == template).toBe(false)
	end)

	it("runs every migration on a sample of each older version without losing anything", function()
		local samples = {
			Player_1 = { version = 1, coins = 500, extra = "kept" },
			Player_2 = { version = 2, coins = 7, gems = 42 },
			Player_3 = { version = 3, coins = 1, wallet = { gems = 5 }, stats = { joins = 9 } },
		}
		local store = Fakes.store(samples)
		local data = service(store)
		for id = 1, 3 do
			local p = Fakes.player(id)
			expect((data:load(p, id))).toBe("loaded")
			local d = data:get(p) :: any
			expect(d.version).toBe(3)
			expect(d.coins).toBe(samples[`Player_{id}`].coins)
			expect(type(d.wallet.gems)).toBe("number")
		end
		-- A current-version save is not changed by loading.
		expect(store.profiles.Player_3.Data).toEqual({
			version = 3,
			coins = 1,
			wallet = { gems = 5 },
			stats = { joins = 9 },
		})
	end)

	it("upgrades v1 and v2 saves step by step and archives retired keys", function()
		local store = Fakes.store({
			Player_1 = { version = 1, coins = 500, extra = "kept" },
			Player_2 = { version = 2, coins = 7, gems = 42 },
		})
		local data = service(store)
		local p1, p2 = Fakes.player(1), Fakes.player(2)
		data:load(p1, 1)
		data:load(p2, 2)
		local d1 = data:get(p1) :: any
		expect(d1.version).toBe(3)
		expect(d1.coins).toBe(500)
		expect(d1.extra).toBe("kept")
		expect(d1.wallet.gems).toBe(0)
		expect(d1.stats.joins).toBe(0) -- filled from the template
		local d2 = data:get(p2) :: any
		expect(d2.wallet.gems).toBe(42)
		expect(d2._retired["v2.gems"]).toBe(42)
		expect(d2.gems).toBeNil()
	end)

	it("refuses a migration that drops a key, and leaves the save untouched", function()
		local bad: { DataService.Migration } = {
			{
				from = 1,
				run = function(data)
					data.coins = nil
				end,
			},
		}
		local store = Fakes.store({ Player_1 = { version = 1, coins = 5 } })
		local data =
			DataService.new({ store = store, template = { version = 2, coins = 0 }, migrations = bad })
		local result, err = data:load(Fakes.player(1), 1)
		expect(result).toBe("migration-failed")
		expect(err).toContain("removed key")
		expect(store.saved.Player_1).toEqual({ version = 1, coins = 5 })
	end)

	it("refuses data from a newer build instead of downgrading it", function()
		local store = Fakes.store({ Player_1 = { version = 9, coins = 5 } })
		local data = service(store)
		local result = data:load(Fakes.player(1), 1)
		expect(result).toBe("too-new")
		expect(store.saved.Player_1.version).toBe(9)
		expect(store.locked.Player_1).toBeNil()
	end)

	it("reports a failed session lock", function()
		local store = Fakes.store()
		store.failNext = true
		expect((service(store):load(Fakes.player(1), 1))).toBe("failed")
	end)

	it("commits updates atomically: errors leave data untouched", function()
		local store = Fakes.store()
		local data = service(store)
		local p = Fakes.player(1)
		data:load(p, 1)
		local ok = data:update(p, function(d)
			d.coins += 5
		end)
		expect(ok).toBe(true)
		expect((data:get(p) :: any).coins).toBe(15)
		local failed, err = data:update(p, function(d)
			d.coins = 999
			error("nope")
		end)
		expect(failed).toBe(false)
		expect(err).toContain("nope")
		expect((data:get(p) :: any).coins).toBe(15)
	end)

	it("rejects update callbacks that yield", function()
		local store = Fakes.store()
		local data = service(store)
		local p = Fakes.player(1)
		data:load(p, 1)
		local ok, err = data:update(p, function(d)
			d.coins = 1
			coroutine.yield()
		end)
		expect(ok).toBe(false)
		expect(err).toContain("yielded")
		expect((data:get(p) :: any).coins).toBe(10)
	end)

	it("notifies listeners after a successful update", function()
		local data = service(Fakes.store())
		local p = Fakes.player(1)
		data:load(p, 1)
		local seen = 0
		data:onChanged(function(player, d)
			expect(player).toBe(p)
			seen = d.coins
		end)
		data:update(p, function(d)
			d.coins = 77
		end)
		expect(seen).toBe(77)
	end)

	it("saves on release and keeps the table identity ProfileStore holds", function()
		local store = Fakes.store()
		local data = service(store)
		local p = Fakes.player(1)
		data:load(p, 1)
		local profile = store.profiles.Player_1
		local live = profile.Data
		data:update(p, function(d)
			d.coins = 3
		end)
		expect(profile.Data == live).toBe(true)
		data:release(p)
		expect(store.saved.Player_1.coins).toBe(3)
		expect(data:get(p)).toBeNil()
	end)

	it("validates the migration chain and template version", function()
		expect(function()
			DataService.latestVersion({ { from = 2, run = function() end } })
		end).toThrow("consecutive")
		expect(function()
			DataService.new({ store = Fakes.store(), template = { version = 1 }, migrations = migrations })
		end).toThrow("template.version")
	end)
end)
