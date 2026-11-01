--!strict
-- Tidecatch Cove headless sessions: 15 minutes per style, a milestone table
-- over several seeds, 2-hour curves and a 3-hour return.
--   lune run playtests/tidecatch-cove/run_session.luau

local Harness = require("../../games/tidecatch-cove/tests/Harness")
local Fakes = require("../../packages/core/tests/Fakes")
local Bot = require("./bot")

local function session(styleName: string, seconds: number, seed: number, opts: any?)
	local options = opts or {}
	options.seed = seed
	local h = Harness.new(options)
	local p = Fakes.player(seed)
	h.join(p)
	local b = Bot.new(h, p, Bot.STYLES[styleName])
	Bot.play(b, seconds)
	return b, h
end

print("Tidecatch Cove headless sessions")

for _, name in { "keeper", "grower", "rareOnly", "seller", "flipper", "baitless" } do
	print(`\n=== {name}: 15 min (seed 2026) ===`)
	local b, h = session(name, 900, 2026)
	Bot.printMilestones(b)
	Bot.printTimeline(b)
	print("  end: " .. Bot.summary(b))
	local refusals = {}
	for why, n in b.refusals do
		table.insert(refusals, `{why} x{n}`)
	end
	table.sort(refusals)
	if #refusals > 0 then
		print("  refusals: " .. table.concat(refusals, "; "))
	end
	local notices = {}
	for _, n in h.notices do
		notices[n] = (notices[n] or 0) + 1
	end
	local list = {}
	for n, c in notices do
		table.insert(list, `{n} x{c}`)
	end
	table.sort(list)
	print("  notices: " .. table.concat(list, "; "))
end

-- Milestones across seeds, 15 minutes, keeper.
print("\n=== milestones, keeper, seeds 1-5, 15 min (m:ss; - = not reached) ===")
local names = { "FirstCatch", "FirstPlaced", "FirstSale", "FirstGrowth", "FirstUncommon", "FirstRare", "FirstEpic", "Pool3", "ReefRod", "Journal10", "Pool4", "FirstGiantSold" }
print("  seed  " .. table.concat(names, "  "))
for seed = 1, 5 do
	local b = session("keeper", 900, seed)
	local at = {}
	for _, m in b.milestones do
		at[m.name] = m.at
	end
	local cells = {}
	for _, n in names do
		local v = at[n]
		table.insert(cells, string.format("%-" .. #n .. "s", if v then Bot.clockStr(v) else "-"))
	end
	print(`  {seed}     ` .. table.concat(cells, "  "))
end

-- 2-hour curves.
for _, name in { "keeper", "seller" } do
	print(`\n=== {name}: 2 hours (seed 9), every 10 minutes ===`)
	local b = session(name, 7200, 9)
	print("  min   coins   fish$  pool$  casts catch  esc  rod slots pooled poolVal bucket journal worms")
	for _, r in b.timeline do
		if r.minute % 10 == 0 then
			print(string.format(
				"  %3d %7d %7d %6d  %5d %5d %4d  %3d  %4d  %5d  %6d  %5d  %5d  %5d",
				r.minute, r.coins, r.fish, r.pool, r.casts, r.catches, r.escapes, r.rod, r.slots, r.pooled,
				r.poolValue, r.bucket, r.journal, r.worms
			))
		end
	end
	Bot.printMilestones(b)
	print("  end: " .. Bot.summary(b))
end

-- Leave after 15 minutes, come back after 3 hours: the return hook.
print("\n=== keeper 15 min, away 3 h, back for 5 min (seed 2026) ===")
do
	local b, h = session("keeper", 900, 2026)
	local before = h.get(b.player)
	local poolsBefore = #before.pools
	local coinsBefore = before.coins
	h.leave(b.player)
	local h2 = Harness.new({ store = h.store, start = h.time + 3 * 3600, seed = 3 })
	local p = Fakes.player(2026)
	h2.join(p)
	local w = h2.welcomes[1]
	print(`  welcome: grew {if w then w.grew else "none"} restocked {if w then tostring(w.restocked) else "-"} (pools {poolsBefore})`)
	local b2 = Bot.new(h2, p, Bot.STYLES.keeper)
	Bot.play(b2, 300)
	local after = h2.get(p)
	print(`  coins {coinsBefore} -> {after.coins} after 5 min back; pool sales {b2.earned.pool}`)
	Bot.printMilestones(b2)
end

-- Sell Multiplier + Extra Pools passes, keeper, 15 min.
print("\n=== keeper with Sell Multiplier + Extra Pools, 15 min (seed 2026) ===")
do
	local b = session("keeper", 900, 2026, { perks = { autoReel = false, extraPools = true, sellMultiplier = true } })
	print("  end: " .. Bot.summary(b))
end
