--!nocheck
local Sim = require("./Sim")
local Fakes = require("../../packages/core/tests/Fakes")
local Hatchery = require("../../games/hatchery-heist/src/shared/Hatchery")
local Log = require("@core/Log")
Log.setSink(function() end)
local config = Sim.config

-- (c) belt cap: unlimited coins, 12 slots, buy every Basic egg possible for 60s
do
	local h = Sim.new()
	local p = Fakes.player(1)
	h.join(p)
	h.economy:add(p, "coins", 1e9, "Admin:Test")
	h.data:update(p, function(d) d.slots = 12 end)
	local bought = 0
	for _ = 1, 60 do
		local d = h.get(p)
		for _, inc in table.clone(d.incubators) do if inc.readyAt <= h.clock.now() then h.actions:hatch(p, inc.slot) end end
		d = h.get(p)
		while Hatchery.freeSlot(d, d.slots) do
			local idx = h.findOnBelt(p, "BasicEgg", 1.0) or h.findOnBelt(p, "MeadowEgg", 1.0)
			if idx == nil then break end
			if h.actions:buyEgg(p, idx) then h.taken[p][idx] = true; bought += 1 end
			d = h.get(p)
		end
		h.wait(1)
	end
	print(`belt cap: with 12 slots and unlimited coins a player bought {bought} eggs in 60s (belt spawns one egg every {config.economy.conveyor.spawnSeconds}s = {60 / config.economy.conveyor.spawnSeconds}/min)`)
end

-- time to 2nd egg and actions in the first 3 minutes for a brand-new player
for _, seed in { 7, 12345, 999, 31337, 2024 } do
	local h = Sim.new({ seed = seed })
	local p = Fakes.player(seed)
	h.join(p)
	local secondAt, actions, firstMeadowAt = nil, 0, nil
	local eggs = 0
	for t = 0, 179 do
		local d = h.get(p)
		for _, inc in table.clone(d.incubators) do if inc.readyAt <= h.clock.now() then if h.actions:hatch(p, inc.slot) then actions += 1 end end end
		d = h.get(p)
		if Hatchery.pendingAt(d, h.clock.now(), Hatchery.incomePerSecond(d, config, { doubleCoins = false, extraIncubators = false })) >= 1 and t % 10 == 0 then
			h.actions:collect(p); actions += 1
		end
		d = h.get(p)
		while Hatchery.freeSlot(d, d.slots) and d.coins >= 50 do
			local idx = h.findOnBelt(p, if d.coins >= 2500 then "MeadowEgg" else "BasicEgg")
			if idx == nil then break end
			if h.actions:buyEgg(p, idx) then
				h.taken[p][idx] = true; eggs += 1; actions += 1
				if eggs == 2 and secondAt == nil then secondAt = t end
			end
			d = h.get(p)
		end
		h.wait(1)
	end
	local d = h.get(p)
	print(string.format("seed %-6d: 2nd egg at %ds; %d eggs and %d actions in the first 3 min; income at 3:00 = %d/s, coins %d", seed, secondAt or -1, eggs, actions, Hatchery.incomePerSecond(d, config, { doubleCoins = false, extraIncubators = false }), d.coins))
end
