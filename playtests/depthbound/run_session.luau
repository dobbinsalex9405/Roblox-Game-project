--!strict
-- 15-minute Depthbound sessions for several player styles and seeds, a 4-player
-- server, and a 2-hour run to see when the gear maxes out. Prints milestone
-- times, per-minute timelines and a summary table.
--   lune run playtests/depthbound/run_session.luau

local Bot = require("./bot")
local Harness = require("../../games/depthbound/tests/Harness")
local Fakes = require("../../packages/core/tests/Fakes")
local Pack = require("../../games/depthbound/src/shared/Pack")

local config = Harness.config
local gear = config.gear

local function fmt(seconds: number?): string
	if seconds == nil then
		return "  -  "
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local MILESTONES = {
	"FirstOre",
	"FirstSale",
	"FirstUpgrade",
	"Upgrade:Pick2",
	"Layer2",
	"Upgrade:Pick3",
	"Layer3",
	"Upgrade:Lamp3",
	"Upgrade:Pack3",
	"Bedrock",
	"FirstLampOut",
	"AllGearMaxed",
}

local function summary(h: any, b: Bot.Bot, seconds: number): { [string]: any }
	local d = h.get(b.player)
	return {
		coins = d.coins,
		earned = d.stats.coinsEarned,
		gear = `{d.gear.pick}/{d.gear.pack}/{d.gear.lamp}`,
		deepest = d.deepestRow,
		layer = d.layersReached,
		dives = d.stats.dives,
		lampOuts = d.stats.lampOuts,
		blocks = d.stats.blocksMined,
		ore = b.orePieces,
		idle = b.idle.camp + b.idle.climb + b.idle.walk,
		idlePct = 100 * (b.idle.camp + b.idle.climb + b.idle.walk) / seconds,
		perMin = d.stats.coinsEarned / (seconds / 60),
	}
end

local function printTimeline(b: Bot.Bot)
	print("  min  coins  earned  gear   deepest layer dives lampOuts blocks ore  exposed")
	for _, t in b.timeline do
		print(
			string.format(
				"  %3d %6d %7d  %d/%d/%d  %5d    %d    %3d    %3d    %5d %4d  %5d",
				t.minute,
				t.coins,
				t.earned,
				t.pick,
				t.pack,
				t.lamp,
				t.deepest,
				t.layer,
				t.dives,
				t.lampOuts,
				t.blocks,
				t.ore,
				t.exposed
			)
		)
	end
end

local function single(strategyName: string, seed: number, seconds: number, verbose: boolean)
	local h = Harness.new({ seed = seed })
	local p = Fakes.player(100 + seed)
	h.join(p)
	local b = Bot.new(h, p, Bot.STRATEGIES[strategyName], { x = 4, z = 4 })
	Bot.Scheduler.run(h, { b }, seconds)
	local s = summary(h, b, seconds)
	if verbose then
		print(`\n=== {strategyName} seed {seed}: {seconds // 60} min ===`)
		for _, line in b.log do
			print("  " .. line)
		end
		printTimeline(b)
		print(
			string.format(
				"  end: coins %d, earned %d, gear %s, deepest row %d (layer %d), %d dives, %d lamp-outs, %d blocks, %d ore, idle %.0f%% (%.0fs camp, %.0fs climbing, %.0fs walking)",
				s.coins,
				s.earned,
				s.gear,
				s.deepest,
				s.layer,
				s.dives,
				s.lampOuts,
				s.blocks,
				s.ore,
				s.idlePct,
				b.idle.camp,
				b.idle.climb,
				b.idle.walk
			)
		)
		for err, n in b.refusals do
			print(string.format("  refused x%d: %s", n, err))
		end
		print(`  exhausted rows: {b.exhausted or 0}; open-cell walks: {b.walkedOpen or 0}`)
		print(`  climbed because: oil low {b.climbs.oil}, pack full {b.climbs.full}, nothing left {b.climbs.done} (hops out {b.climbs.hop})`)
		local notices: { [string]: number } = {}
		for _, n in h.notices do
			notices[n] = (notices[n] or 0) + 1
		end
		for text, n in notices do
			print(string.format("  notice x%d: %s", n, text))
		end
	end
	return h, b, s
end

print("Depthbound headless sessions")
print(string.format("Config: lamp tiers %s s; pack tiers %s; pick cost %s", table.concat((function()
	local t = {}
	for _, l in gear.lamp do
		table.insert(t, tostring(l.oilSeconds))
	end
	return t
end)(), "/"), table.concat((function()
	local t = {}
	for _, l in gear.pack do
		table.insert(t, tostring(l.capacity))
	end
	return t
end)(), "/"), table.concat((function()
	local t = {}
	for _, l in gear.pick do
		table.insert(t, tostring(l.cost))
	end
	return t
end)(), "/")))

-- One verbose run per strategy.
local verboseSeeds = { greedy = 2026, cautious = 2026, fresh = 2026, hopper = 2026 }
for _, name in { "greedy", "cautious", "fresh", "hopper" } do
	single(name, verboseSeeds[name], 900, true)
end

-- Milestone table across seeds.
print("\n=== 15-minute milestones across seeds (m:ss) ===")
local header = "strategy  seed "
for _, m in MILESTONES do
	header ..= string.format(" %-13s", m)
end
print(header)
local totals: { [string]: { n: number, earned: number, lampOuts: number, deepest: number, layer3: number, idle: number } } = {}
for _, name in { "greedy", "cautious", "fresh", "hopper" } do
	totals[name] = { n = 0, earned = 0, lampOuts = 0, deepest = 0, layer3 = 0, idle = 0 }
	for _, seed in { 1, 2, 3, 4, 5 } do
		local _, b, s = single(name, seed, 900, false)
		local line = string.format("%-9s %4d ", name, seed)
		for _, m in MILESTONES do
			line ..= string.format(" %-13s", fmt(b.milestones[m]))
		end
		print(line)
		local t = totals[name]
		t.n += 1
		t.earned += s.earned
		t.lampOuts += s.lampOuts
		t.deepest += s.deepest
		t.layer3 += if s.layer >= 3 then 1 else 0
		t.idle += s.idlePct
	end
end
print("\nstrategy   avg earned/15min  avg deepest  reached L3  avg lamp-outs  avg idle%")
for _, name in { "greedy", "cautious", "fresh", "hopper" } do
	local t = totals[name]
	print(
		string.format(
			"%-9s  %14.0f  %11.1f  %5d/%d  %13.1f  %9.0f",
			name,
			t.earned / t.n,
			t.deepest / t.n,
			t.layer3,
			t.n,
			t.lampOuts / t.n,
			t.idle / t.n
		)
	)
end

-- A 4-player server for 15 minutes: do they get in each other's way?
print("\n=== 4 players, one server, 15 min (seed 77) ===")
do
	local h = Harness.new({ seed = 77 })
	local bots = {}
	local styles = { "greedy", "greedy", "cautious", "fresh" }
	local columns = { { x = 3, z = 3 }, { x = 13, z = 3 }, { x = 3, z = 13 }, { x = 13, z = 13 } }
	for i = 1, 4 do
		local p = Fakes.player(200 + i)
		h.join(p)
		table.insert(bots, Bot.new(h, p, Bot.STRATEGIES[styles[i]], columns[i]))
	end
	Bot.Scheduler.run(h, bots, 900)
	for i, b in bots do
		local s = summary(h, b, 900)
		print(
			string.format(
				"  P%d %-8s earned %6d gear %s deepest %2d dives %2d lampOuts %d blocks %4d",
				i,
				styles[i],
				s.earned,
				s.gear,
				s.deepest,
				s.dives,
				s.lampOuts,
				s.blocks
			)
		)
	end
	print(`  exposed Parts at end: {h.grid.exposedCount}; mined cells: {(function()
		local n = 0
		for _ in h.grid.mined do
			n += 1
		end
		return n
	end)()}`)
	-- Hit refusals seen by anyone.
	local refusals: { [string]: number } = {}
	for _, n in h.notices do
		refusals[n] = (refusals[n] or 0) + 1
	end
	for text, n in refusals do
		print(string.format("  notice x%d: %s", n, text))
	end
end

-- Two hours, greedy: when does the gear max out, and what is left to do?
print("\n=== 2-hour greedy run (seed 9) ===")
do
	local h = Harness.new({ seed = 9 })
	local p = Fakes.player(900)
	h.join(p)
	local b = Bot.new(h, p, Bot.STRATEGIES.greedy, { x = 8, z = 8 })
	Bot.Scheduler.run(h, { b }, 7200)
	for _, line in b.log do
		print("  " .. line)
	end
	print("  min  earned   gear  deepest dives lampOuts blocks  coins/min(last 10)")
	local last = 0
	for _, t in b.timeline do
		if t.minute % 10 == 0 then
			print(
				string.format(
					"  %3d %7d  %d/%d/%d  %5d   %3d    %3d   %6d   %6.0f",
					t.minute,
					t.earned,
					t.pick,
					t.pack,
					t.lamp,
					t.deepest,
					t.dives,
					t.lampOuts,
					t.blocks,
					(t.earned - last) / 10
				)
			)
			last = t.earned
		end
	end
	local d = h.get(p)
	print(`  pack now: {Pack.count(d.pack)} pieces; sealed-shaft events: {b.sealed}`)
end
