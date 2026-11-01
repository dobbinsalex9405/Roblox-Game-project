--!nocheck
local Sim = require("./Sim")
local S = require("./session")
local Fakes = require("../../packages/core/tests/Fakes")
local Log = require("@core/Log")
Log.setSink(function() end)

for _, strategy in { "greedy", "basic", "slots" } do
	for _, seed in { 7, 12345, 999 } do
		print(`\n=== 15-minute session: strategy={strategy} seed={seed} ===`)
		local h = Sim.new({ seed = seed })
		local p = Fakes.player(seed)
		h.join(p)
		S.play(h, p, 900, strategy, true)
	end
end

print(
	"\n=== Long session (3 hours, greedy, seed 7): when do pads fill / storage overflow / rebirth happen? ==="
)
local h = Sim.new({ seed = 7 })
local p = Fakes.player(1)
h.join(p)
local r = S.play(h, p, 3 * 3600, "greedy", false)
local names = {}
for name in r.milestones do
	table.insert(names, name)
end
table.sort(names, function(a, b)
	return r.milestones[a] < r.milestones[b]
end)
for _, name in names do
	print(string.format("  milestone %-24s at %s", name, S.mmss(r.milestones[name])))
end
for i = 1, #r.timeline, 15 do
	print(r.timeline[i])
end
print(r.timeline[#r.timeline])
print(string.format("  idle seconds: %d of %d (%.0f%%)", r.idle, 3 * 3600, r.idle / (3 * 3600) * 100))
local d = r.final
print(
	string.format(
		"  end: coins %s, income %s/s, creatures %d, slots %d, rebirths %d",
		S.fmt(d.coins),
		S.fmt(r.perSecond),
		#d.creatures,
		d.slots,
		d.rebirths
	)
)
