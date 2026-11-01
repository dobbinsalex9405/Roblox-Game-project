--!strict
-- Street Food Empire sessions: 15 minutes for each serving and buying habit,
-- a 2-hour run, and an 8-hour run to time the rebirth. Nothing in the game is
-- random, so one run per style is the whole story.
--   lune run playtests/street-food-empire/run_session.luau

local Bot = require("./bot")
local Harness = require("../../games/street-food-empire/tests/Harness")
local Fakes = require("../../packages/core/tests/Fakes")

local function fmt(seconds: number?): string
	if seconds == nil then
		return "  -  "
	end
	local s = math.floor(seconds)
	if s >= 3600 then
		return string.format("%d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60)
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

local function run(styleName: string, seconds: number, perks: any?): (any, Bot.Bot)
	local h = Harness.new({ perks = perks })
	local p = Fakes.player(1)
	h.join(p)
	local b = Bot.new(h, p, Bot.STYLES[styleName])
	Bot.play(h, b, seconds)
	return h, b
end

local function printTimeline(b: Bot.Bot, every: number)
	print("  min     cash    hand  register  stations/levels cooks district   meal  reg/s  serves  lost")
	for _, t in b.timeline do
		if t.minute % every == 0 then
			print(
				string.format(
					"  %3d %8d %7d %9d     %2d/%-2d        %2d     %d    %7d %6.1f  %5d  %5.0f",
					t.minute,
					t.cash,
					t.hand,
					t.register,
					t.stations,
					t.levels,
					t.cooks,
					t.district,
					t.meal,
					t.registerPerSecond,
					t.serves,
					t.lost
				)
			)
		end
	end
end

print("Street Food Empire headless sessions")
local MILESTONES = {
	"FirstServe",
	"FirstStation",
	"FirstCook",
	"Built:FryStation",
	"District2",
	"Built:TacoTruck",
	"Hired:LineCook",
	"District3",
	"RebirthReady",
}
for _, name in { "attentive", "attentiveRoi", "batcher", "casual", "idle", "handOnly" } do
	local h, b = run(name, 900)
	local d = h.get(b.player)
	print(`\n=== {name}: 15 min ===`)
	for _, line in b.log do
		print("  " .. line)
	end
	printTimeline(b, 1)
	print(
		string.format(
			"  end: cash %d, hand %d + register %d, %d stations, %d cooks, district %d, %d serves, %.0f customers lost, %d purchases, %.0f s away from the counter",
			d.cash,
			b.hand,
			b.register,
			#d.stations,
			#d.cooks,
			d.districts,
			b.serves,
			b.lost,
			b.purchases,
			b.awaySeconds
		)
	)
	local notices: { [string]: number } = {}
	for _, n in h.notices do
		notices[n] = (notices[n] or 0) + 1
	end
	for text, n in notices do
		print(string.format("  notice x%d: %s", n, text))
	end
end

print("\n=== milestones (m:ss) ===")
local header = string.format("%-13s", "style")
for _, m in MILESTONES do
	header ..= string.format(" %-17s", m)
end
print(header)
local long = {}
for _, name in { "attentive", "attentiveRoi", "batcher", "casual", "idle", "handOnly" } do
	local _, b = run(name, 2 * 3600)
	long[name] = b
	local line = string.format("%-13s", name)
	for _, m in MILESTONES do
		line ..= string.format(" %-17s", fmt(b.milestones[m]))
	end
	print(line)
end

print("\n=== 2-hour curves (every 10 min) ===")
for _, name in { "attentive", "attentiveRoi", "idle" } do
	print(`-- {name}`)
	printTimeline(long[name], 10)
end

print("\n=== 8-hour runs: when is the rebirth affordable? ===")
for _, name in { "attentive", "attentiveRoi", "batcher" } do
	local h, b = run(name, 8 * 3600)
	local d = h.get(b.player)
	print(
		string.format(
			"  %-13s District3 %s  RebirthReady %s  hand %d  register %d  cooks %d  stations %d (levels %d)",
			name,
			fmt(b.milestones.District3),
			fmt(b.milestones.RebirthReady),
			b.hand,
			b.register,
			#d.cooks,
			#d.stations,
			(function()
				local n = 0
				for _, s in d.stations do
					n += s.level
				end
				return n
			end)()
		)
	)
end

print("\n=== 2x Cash + Auto-Collect, attentive, 15 min ===")
do
	local h, b = run("attentive", 900, { doubleCash = true, autoCollect = true })
	local d = h.get(b.player)
	print(
		string.format(
			"  cash %d, hand %d, register %d, district %d, stations %d",
			d.cash,
			b.hand,
			b.register,
			d.districts,
			#d.stations
		)
	)
end
