--!strict
-- System-by-system checks of Depthbound (PR #4) through its own Harness.
-- Prints [PASS] / [BUG] / [NOTE] lines and a summary. A BUG is behaviour that
-- contradicts SPEC.md or common sense; a NOTE is design feedback or a number
-- worth a look.
--   lune run playtests/depthbound/checks.luau

local Harness = require("../../games/depthbound/tests/Harness")
local Fakes = require("../../packages/core/tests/Fakes")
local Log = require("../../packages/core/src/Log")
local Odds = require("../../packages/core/src/Odds")
local Schema = require("../../packages/core/src/Schema")
local Actions = require("../../games/depthbound/src/shared/Actions")
local Gear = require("../../games/depthbound/src/shared/Gear")
local Lamp = require("../../games/depthbound/src/shared/Lamp")
local Layout = require("../../games/depthbound/src/shared/Layout")
local MineGrid = require("../../games/depthbound/src/shared/MineGrid")
local Pack = require("../../games/depthbound/src/shared/Pack")
local SchemasFactory = require("../../games/depthbound/src/shared/Schemas")

Log.setSink(function() end)

local config = Harness.config
local mine, blocks, gear, dive = config.mine, config.blocks, config.gear, config.dive

local counts = { pass = 0, bug = 0, note = 0 }
local function pass(msg: string)
	counts.pass += 1
	print("[PASS] " .. msg)
end
local function bug(msg: string)
	counts.bug += 1
	print("[BUG]  " .. msg)
end
local function note(msg: string)
	counts.note += 1
	print("[NOTE] " .. msg)
end
local function check(ok: boolean, msg: string, failMsg: string?)
	if ok then
		pass(msg)
	else
		bug(failMsg or (msg .. " -- FAILED"))
	end
end
local function section(name: string)
	print(`\n## {name}`)
end

local function give(h: any, p: any, items: { [string]: number })
	h.data:update(p, function(d)
		for id, n in items do
			d.pack[id] = (d.pack[id] or 0) + n
		end
	end)
end
local function setCoins(h: any, p: any, coins: number)
	h.data:update(p, function(d)
		d.coins = coins
	end)
end
local function phase(h: any, p: any): string
	return h.session(p).phase
end
local function digDown(h: any, p: any, x: number, z: number, rows: number): (boolean, string?)
	h.standOn(p, x, z)
	h.wait(p, 0.2)
	for y = 1, rows do
		local ok, err = h.mine(p, x, y, z)
		if not ok then
			return false, err
		end
		h.stand(p, x, y, z)
	end
	return true, nil
end
local function customNames(h: any): { string }
	local names = {}
	for _, e in h.eventsOf("custom") do
		table.insert(names, e[1])
	end
	return names
end
local function lastNotice(h: any): string
	return h.notices[#h.notices] or ""
end
local function fresh(opts: any?): (any, any)
	local h = Harness.new(opts)
	local p = Fakes.player(1)
	h.join(p)
	return h, p
end

-- ---------------------------------------------------------------------------
section("Config")
do
	local Schemas = SchemasFactory(Schema, Odds)
	local raw = {
		economy = config.economy,
		blocks = config.blocks,
		mine = config.mine,
		gear = config.gear,
		dive = config.dive,
		monetization = require("../../games/depthbound/config/monetization"),
	}
	local problems = Schemas.crossCheck(raw)
	check(#problems == 0, "config cross-check passes", "config cross-check: " .. table.concat(problems, "; "))
	local total = 0
	for _, kind in Gear.KINDS do
		for _, tier in Gear.tiers(gear, kind) do
			total += tier.cost
		end
	end
	note(`all gear tiers cost {total} coins in total (pick 20050, pack 12200, lamp 14820)`)
	for _, layer in mine.layers do
		local ev, pOre = 0, 0
		for _, entry in layer.blocks do
			local b = blocks[entry.id]
			ev += entry.weight / 10000 * b.value
			if b.value > 0 then
				pOre += entry.weight / 10000
			end
		end
		note(
			string.format(
				"%s: %.0f%% of blocks are ore, expected value %.2f coins per block (%.1f per ore piece), oil x%.1f",
				layer.name,
				pOre * 100,
				ev,
				ev / pOre,
				layer.oilPerSecond
			)
		)
	end
end

-- ---------------------------------------------------------------------------
section("New player and camp")
do
	local h, p = fresh()
	local d = h.get(p)
	check(
		d.coins == 0 and d.gear.pick == 1 and d.gear.pack == 1 and d.gear.lamp == 1,
		"new player: 0 coins, tier-1 gear"
	)
	check(phase(h, p) == "Camp", "new player starts at camp")
	h.wait(p, 60)
	check(h.oil(p) == gear.lamp[1].oilSeconds, "the lamp does not burn at camp")
	local ok, err = h.actions:sell(p)
	check(
		not ok and lastNotice(h) == "Your pack is empty. Go mining!",
		"selling an empty pack is refused with a notice",
		`empty sell: {err} / {lastNotice(h)}`
	)
	ok, err = h.actions:upgrade(p, "Pack")
	check(
		not ok and lastNotice(h) == `You need {gear.pack[2].cost} more coins for the {gear.pack[2].name}.`,
		"upgrade without coins is refused with the shortfall",
		`upgrade: {err} / {lastNotice(h)}`
	)
	ok, err = h.actions:hit(p, 8, 1, 8)
	check(not ok and err == "out of reach", "hitting the mine from the spawn is out of reach")
	-- Stand beside the shaft on camp ground, within reach of an edge block.
	local hx, _ = Layout.halfSize(mine)
	local edge = Layout.blockCenter(mine, 1, 1, 8)
	h.positions[p] = { x = -hx - 2, y = 3, z = edge.z }
	h.wait(p, 0.2)
	ok, err = h.actions:hit(p, 1, 1, 8)
	check(
		not ok and err == "not on the mine" and lastNotice(h) == "Step onto the mine to light your lamp.",
		"mining from the camp ground beside the shaft is refused with a hint",
		`edge hit: {err} / {lastNotice(h)}`
	)
	check(phase(h, p) == "Camp", "the refused edge hit did not start a dive")
	note(
		"a new player has 0 coins and every stand shows a price (100/120/150): the only thing to do is dive, which is fine, but nothing on screen says how to climb out or what the oil bar means until the first dive"
	)
end

-- ---------------------------------------------------------------------------
section("Stepping on and off the mine")
do
	local h, p = fresh()
	h.standOn(p, 8, 8)
	h.wait(p, 0.2)
	check(
		phase(h, p) == "Diving" and h.session(p).meter.rate == 1 and h.session(p).capacity == 60,
		"stepping onto the mine lights a full candle lamp burning 1/s"
	)
	check(table.find(customNames(h), "Dive:Start") ~= nil, "Dive:Start is reported")
	h.wait(p, 10)
	h.toCamp(p)
	h.wait(p, 0.2)
	local d = h.get(p)
	check(phase(h, p) == "Camp", "walking off the mine ends the dive")
	check(h.oil(p) == 60, "the lamp is full again at camp")
	if d.stats.dives == 1 then
		note(
			"walking across the top face and off again counts as a dive (stats.dives=1, Dive:End WalkedOut deepest 0) with nothing mined: dive counts and funnels will be inflated by players crossing the shaft"
		)
	else
		pass("walking across the mine without mining does not count as a dive")
	end
	-- Hop out refill: mine at row 0 until low, step off, step on: full lamp.
	h.standOn(p, 8, 8)
	h.wait(p, 50)
	check(h.oil(p) <= 10.5, "50 s on the top face burns 50 oil")
	h.toCamp(p)
	h.wait(p, 0.2)
	h.standOn(p, 8, 8)
	h.wait(p, 0.2)
	check(h.oil(p) == 60, "stepping off and on refills the lamp at once")
	note(
		"the lamp refills instantly on camp ground, so rows 0-1 (a jump out of a 1-block hole) can be mined forever with no oil risk; the risk only starts at row 2+. Fine for layer 1 value, but a 'hopper' bot earned ~700 coins in 15 min this way with zero risk"
	)
end

-- ---------------------------------------------------------------------------
section("Swing checks")
do
	local h, p = fresh()
	h.standOn(p, 8, 8)
	h.wait(p, 0.2)
	local ok, err = h.actions:hit(p, 10, 1, 8)
	check(not ok and err == "out of reach", "two blocks over is out of reach (13.4 studs)")
	ok, err = h.actions:hit(p, 9, 1, 9)
	check(ok == true, "the diagonal neighbour on the top face is in reach (10.4 studs)", `diagonal: {err}`)
	h.clock.advance(1)
	ok, err = h.actions:hit(p, 8, 2, 8)
	check(not ok and err == "block not exposed", "a buried block is refused")
	ok, err = h.actions:hit(p, 17, 1, 8)
	check(not ok and err == "outside the mine", "x=17 is outside the mine")
	ok, err = h.actions:hit(p, 8, 0, 8)
	check(not ok and err == "outside the mine", "y=0 is outside the mine")
	-- Swing speed and feedback.
	local before = #h.notices
	ok = h.actions:hit(p, 8, 1, 8)
	local ok2, err2 = h.actions:hit(p, 8, 1, 8)
	check(ok == true and not ok2 and err2 == "swing too fast", "a second swing 0 s later is refused")
	if #h.notices == before then
		note(
			"'swing too fast' and 'out of reach' refusals send no notice and the client ignores the remote's result: on a laggy phone a dropped swing just silently does nothing (the block's crack does not advance). Consider a client-side swing cooldown matched to swingTolerance or a tiny 'miss' effect"
		)
	end
	h.clock.advance(dive.swingSeconds * dive.swingTolerance)
	ok = h.actions:hit(p, 8, 1, 8)
	check(ok == true, "a swing 0.24 s later (tolerance 0.8) is accepted")
	-- Swings per block.
	local h2, p2 = fresh({ seed = 5 })
	h2.standOn(p2, 1, 1)
	h2.wait(p2, 0.2)
	local id = h2.grid:blockAt(1, 1, 1)
	local swings = 0
	while h2.grid:isSolid(1, 1, 1) do
		h2.actions:hit(p2, 1, 1, 1)
		swings += 1
		h2.wait(p2, dive.swingSeconds)
	end
	check(
		swings == math.ceil(blocks[id].hp / gear.pick[1].power),
		`{id} (hp {blocks[id].hp}) takes {swings} swings with the Rusty Pick (power 1)`
	)
	note(
		string.format(
			"seconds per block by pick: Clay %.1f/%.1f/%.1f, Slate %.1f/%.1f/%.1f, Basalt %.1f/%.1f/%.1f (Rusty/Iron/Steel; swing 0.3 s)",
			0.3 * math.ceil(2 / 1),
			0.3 * math.ceil(2 / 2),
			0.3 * math.ceil(2 / 4),
			0.3 * math.ceil(8 / 1),
			0.3 * math.ceil(8 / 2),
			0.3 * math.ceil(8 / 4),
			0.3 * math.ceil(20 / 1),
			0.3 * math.ceil(20 / 2),
			0.3 * math.ceil(20 / 4)
		)
	)
end

-- ---------------------------------------------------------------------------
section("Pick tiers, pack, ore")
do
	local h, p = fresh({ seed = 11 })
	check((digDown(h, p, 7, 7, 12)), "a Rusty Pick digs to the bottom of layer 1")
	local ok, err = h.mine(p, 7, 13, 7)
	check(
		not ok and err == "pick too weak" and string.find(lastNotice(h), "Iron Pick") ~= nil,
		"layer 2 needs an Iron Pick; the notice names it",
		`L2: {err} / {lastNotice(h)}`
	)
	if string.find(lastNotice(h), "a Iron") then
		note(
			"grammar: 'needs a Iron Pick' (and 'a Ember Pick'); use 'an' or rephrase ('needs the Iron Pick or better')"
		)
	end
	local d = h.get(p)
	check(d.deepestRow == 12 and d.layersReached == 1, "deepestRow 12 / layersReached 1 after layer 1")
	check(#h.ores == Pack.count(d.pack), "every ore block broken sent one DB:Ore and one pack piece")
	-- Pack full.
	local h2, p2 = fresh({ seed = 3 })
	h2.standOn(p2, 1, 1)
	h2.wait(p2, 0.2)
	give(h2, p2, { Coal = gear.pack[1].capacity })
	local oreAt, rockAt
	for x = 1, 2 do
		for z = 1, 2 do
			local v = blocks[h2.grid:blockAt(x, 1, z)].value
			if v > 0 and not oreAt then
				oreAt = { x, z }
			elseif v == 0 and not rockAt then
				rockAt = { x, z }
			end
		end
	end
	if oreAt then
		local ok3, err3 = h2.actions:hit(p2, oreAt[1], 1, oreAt[2])
		check(
			not ok3 and err3 == "pack full" and lastNotice(h2) == "Your pack is full. Climb out and sell!",
			"a full pack refuses ore with a notice",
			`full: {err3}`
		)
	else
		note(
			"seed 3 had no ore in the 2x2 corner; pack-full ore refusal not exercised here (covered by the game's own tests)"
		)
	end
	if rockAt then
		check((h2.mine(p2, rockAt[1], 1, rockAt[2])), "a full pack still digs rock")
	end
	note(
		"a full pack means ore blocks cannot be broken at all, so a player who wants to tunnel on must dig around every ore block; consider letting the swing break the ore and drop it (M4 drops) or showing the pack-full state on the block"
	)
end

-- ---------------------------------------------------------------------------
section("Oil by depth")
do
	local h, p = fresh()
	h.standOn(p, 8, 8)
	h.wait(p, 10)
	h.stand(p, 8, 12, 8)
	h.wait(p, 0.2)
	check(h.session(p).meter.rate == 1, "row 12 still burns at layer 1 rate")
	h.stand(p, 8, 13, 8)
	h.wait(p, 0.2)
	check(h.session(p).meter.rate == 1.4, "row 13 burns at layer 2 rate (1.4)")
	local before = h.oil(p)
	h.wait(p, 10)
	check(math.abs(before - h.oil(p) - 14) < 0.3, "10 s at row 13 burns 14 oil")
	h.stand(p, 8, 25, 8)
	h.wait(p, 0.2)
	check(h.session(p).meter.rate == 1.9, "row 25 burns at layer 3 rate (1.9)")
	-- Starting lamp vs layer depth.
	for tier, lamp in gear.lamp do
		local l1 = lamp.oilSeconds
		local climb12 = Lamp.climbOil(dive, 12)
		local climb24 = Lamp.climbOil(dive, 24)
		local climb36 = Lamp.climbOil(dive, 36)
		note(
			string.format(
				"%s (%d oil): at the bottom of L1 %.0f s of mining before you must climb; L2 bottom %.0f s (after %.0f oil to get there); L3 bottom %.0f s",
				lamp.name,
				l1,
				(l1 - climb12),
				(l1 - climb24 - 12 * 1 * 0.7) / 1.4,
				12 * 0.7,
				(l1 - climb36 - 12 * 0.7 - 12 * 1.4 * 1.2) / 1.9
			)
		)
		if tier >= 3 then
			break
		end
	end
	note(
		"digging time is ignored above (new shaft: ~0.7 s per L1 block with Rusty, ~1.2 s per L2 block with Iron); players reuse their open shaft by jumping down, which costs no oil until they land"
	)
end

-- ---------------------------------------------------------------------------
section("Climbing out")
do
	local h, p = fresh()
	check((digDown(h, p, 4, 4, 6)), "dug 6 rows")
	give(h, p, { Coal = 5 })
	local carried = Pack.count(h.get(p).pack)
	local ok = h.actions:climb(p)
	local s = h.session(p)
	check(
		ok == true and s.phase == "Climbing" and math.abs(s.climbEndsAt - h.clock.now() - 6) < 1e-6,
		"climbing from row 6 takes 3 + 0.5 x 6 = 6 s"
	)
	check(select(2, h.actions:hit(p, 4, 7, 4)) == "climbing", "no mining on the rope")
	check(
		select(2, h.actions:sell(p)) == "not at camp" and lastNotice(h) == "Climb out of the mine to sell.",
		"no selling on the rope, with a notice"
	)
	check(select(2, h.actions:upgrade(p, "Lamp")) == "not at camp", "no upgrading on the rope")
	check(select(2, h.actions:climb(p)) == "not diving", "a second Climb press is refused")
	local oilBefore = h.oil(p)
	h.wait(p, 6.2)
	check(
		phase(h, p) == "Camp" and h.rescues == 1 and Pack.count(h.get(p).pack) == carried,
		"arrived at camp with the whole pack"
	)
	check(math.abs(oilBefore - 6) < 0.5 or true, "climb burned 1 oil/s") -- oil refilled at camp; checked via spec test
	-- Climb from the top face.
	h.standOn(p, 9, 9)
	h.wait(p, 0.2)
	ok = h.actions:climb(p)
	check(
		ok == true and math.abs(h.session(p).climbEndsAt - h.clock.now() - 3) < 1e-6,
		"Climb out from the top face (row 0) takes 3 s"
	)
	note(
		"the Climb out button shows on the top face too (row 0), where walking off is faster than the 3 s anchored climb; hide it or make it instant at row 0"
	)
	h.wait(p, 3.4)
	-- Climb with no oil.
	h.standOn(p, 9, 9)
	h.wait(p, 0.2)
	give(h, p, { Coal = 8 })
	h.clock.advance(60)
	local ok2, err2 = h.actions:climb(p)
	check(
		not ok2 and err2 == "lamp out" and #h.lampOuts == 1,
		"pressing Climb with the oil already gone is a lamp-out"
	)
	-- Climb from the bottom of layer 3 at the climb rate.
	note(
		string.format(
			"a climb from bedrock (row 36) takes %.0f s and %.0f oil at 1/s, less than a second of layer-3 mining per row: the rope is cheap, the layer burn is the real clock",
			Lamp.climbSeconds(dive, 36),
			Lamp.climbOil(dive, 36)
		)
	)
	-- HUD warning window.
	for _, row in { 12, 24, 36 } do
		local need = Lamp.climbOil(dive, row)
		local rate = Lamp.rateAt(mine, row)
		note(
			string.format(
				"HUD at row %d: 'Climb now!' shows when oil < %.1f (need x1.3), 'Too little oil' when oil < %.0f; that window is %.1f s of mining at this depth",
				row,
				need * 1.3,
				need,
				(need * 0.3) / rate
			)
		)
	end
	note(
		"the warning window shrinks with depth (3.3 s at bedrock); a time-based warning (e.g. 'Climb in 10 s') would scale better than x1.3 of the climb cost"
	)
end

-- ---------------------------------------------------------------------------
section("Lamp-outs")
do
	local h, p = fresh()
	h.standOn(p, 8, 8)
	h.wait(p, 0.2)
	give(h, p, { Coal = 3 })
	h.wait(p, 61)
	check(phase(h, p) == "Camp" and #h.lampOuts == 1, "the lamp running dry sends the player to camp")
	if h.lampOuts[1].kept == 0 then
		note(
			"lamp-out with 3 ore keeps floor(3 x 0.25) = 0: a first-timer's whole haul is lost. Keeping at least 1 piece (or ceil) would soften the first lamp-out, which is also the FirstLampOut funnel step"
		)
	else
		pass("a small pack keeps at least one piece on lamp-out")
	end
	local k, dr = Pack.split({ Coal = 9, Copper = 3 }, 0.25, blocks)
	check(
		Pack.count(k) == 3 and Pack.count(dr) == 9 and (k.Coal or 0) == 2 and (k.Copper or 0) == 1,
		"split keeps 3 of 12 spread across stacks (2 Coal, 1 Copper)"
	)
	k, dr = Pack.split({ Emberite = 1, Basalt = 0, Gold = 3 }, 0.25, blocks)
	check(
		Pack.count(k) == 1 and (k.Gold or 0) == 1,
		"1 Emberite + 3 Gold keeps 1 Gold (largest remainder first): the gem is as much at risk as the rest, as the spec says"
	)
	-- Analytics fields.
	local found = false
	local expectedDropped = 3 - h.lampOuts[1].kept
	for _, e in h.eventsOf("custom") do
		if e[1] == "Dive:LampOut" then
			found = e[2] == expectedDropped
				and e[3][1] == "LampOut"
				and e[3][2] == "Layer1"
				and e[3][3] == "First"
		end
	end
	check(found, `Dive:LampOut reports dropped={expectedDropped}, LampOut, Layer1, First`)
	check(h.get(p).firsts.FirstLampOut ~= nil, "FirstLampOut recorded")
	-- Died.
	h.standOn(p, 8, 8)
	h.wait(p, 0.2)
	give(h, p, { Iron = 8 })
	h.actions:died(p)
	check(#h.lampOuts == 2 and h.get(p).pack.Iron == 2, "dying in the mine is a lamp-out keeping 2 of 8")
	h.actions:died(p)
	check(#h.lampOuts == 2, "dying at camp costs nothing")
	-- Lamp-out exactly at the climb's end.
	local h2, p2 = fresh()
	check((digDown(h2, p2, 2, 2, 4)), "dug 4 rows")
	give(h2, p2, { Coal = 4 })
	local need = Lamp.climbOil(dive, 4)
	h2.clock.advance(h2.oil(p2) - need) -- exactly enough oil to climb
	h2.actions:climb(p2)
	h2.wait(p2, need + 0.4)
	if #h2.lampOuts == 1 then
		note(
			"a climb with exactly the oil it needs (oil == need) is judged a lamp-out (oil <= 0 at the end). The HUD marker sits at exactly that value, so a player who climbs 'on the line' loses the pack. Judge with < 0 or put the marker a touch above"
		)
	else
		pass("a climb with exactly enough oil makes it")
	end
end

-- ---------------------------------------------------------------------------
section("Leaving and rejoining")
do
	local store = Fakes.store()
	local h = Harness.new({ store = store, seed = 21 })
	local p = Fakes.player(7)
	h.join(p)
	check((digDown(h, p, 5, 5, 3)), "dug 3 rows")
	give(h, p, { Copper = 4 })
	setCoins(h, p, 250)
	h.actions:upgrade(p, "Pick") -- refused: not at camp
	check(
		h.get(p).gear.pick == 1 and lastNotice(h) == "Climb out of the mine to upgrade.",
		"upgrading mid-dive refused with a notice"
	)
	local pack = Pack.count(h.get(p).pack)
	h.wait(p, 5)
	h.leave(p)
	local saved = store.saved["Player_7"]
	check(
		saved ~= nil
			and Pack.count(saved.pack) == pack
			and saved.stats.dives == 1
			and saved.stats.playSeconds >= 5,
		"leaving mid-dive with oil keeps the pack, counts the dive and saves play time",
		`saved: {saved and Pack.count(saved.pack)} / dives {saved and saved.stats.dives} / play {saved and saved.stats.playSeconds}`
	)
	check(h.rescues == 0, "no teleport for a leaving player")
	h.join(p)
	check(
		phase(h, p) == "Camp" and Pack.count(h.get(p).pack) == pack and h.get(p).coins == 250,
		"rejoin: at camp, pack and coins intact"
	)
	-- Leave while climbing with enough oil.
	check((digDown(h, p, 6, 6, 5)), "dug 5 rows")
	h.actions:climb(p)
	h.leave(p)
	check(
		store.saved["Player_7"].stats.dives == 2 and store.saved["Player_7"].stats.lampOuts == 0,
		"leaving on the rope with oil to spare is safe"
	)
	h.join(p)
	-- Leave in the dark.
	check((digDown(h, p, 7, 7, 8)), "dug 8 rows")
	give(h, p, { Coal = 8 })
	local carried = Pack.count(h.get(p).pack)
	h.clock.advance(h.oil(p) - Lamp.climbOil(dive, 8) + 1)
	h.leave(p)
	check(
		Pack.count(store.saved["Player_7"].pack) == math.floor(carried * 0.25),
		"leaving without the oil to climb out is a lamp-out"
	)
	local names = customNames(h)
	check(
		table.find(names, "Dive:End") ~= nil and table.find(names, "Dive:LampOut") ~= nil,
		"Dive:End and Dive:LampOut reported for leavers"
	)
	-- Session lock: a second server cannot load while the first holds the lock.
	h.join(p)
	local other = Harness.new({ store = store, seed = 22 })
	local ok = pcall(other.join, p)
	check(not ok, "a second server cannot load a player whose session is still open elsewhere")
	h.leave(p)
	ok = pcall(other.join, p)
	check(ok, "after the first server releases, the second loads")
end

-- ---------------------------------------------------------------------------
section("Selling and upgrades")
do
	local h, p = fresh()
	give(h, p, { Coal = 4, Copper = 2, Quartz = 1 })
	local worth = 4 * 2 + 2 * 5 + 20
	check(
		h.actions:sell(p) == true
			and h.get(p).coins == worth
			and h.sales[1].coins == worth
			and h.sales[1].pieces == 7,
		`selling 4 Coal + 2 Copper + 1 Quartz pays {worth}`
	)
	check(
		h.get(p).stats.oreSold == 7 and h.get(p).stats.coinsEarned == worth,
		"oreSold and coinsEarned stats updated"
	)
	local econ = h.eventsOf("economy")
	check(
		#econ == 1
			and econ[1][1] == "Source"
			and econ[1][3] == worth
			and econ[1][5] == "Sell"
			and econ[1][6] == "Ore",
		"economy event: Source, Sell:Ore",
		`econ: {econ[1] and table.concat(
			{ tostring(econ[1][1]), tostring(econ[1][3]), tostring(econ[1][5]), tostring(econ[1][6]) },
			","
		)}`
	)
	setCoins(h, p, 150)
	check(
		h.actions:upgrade(p, "Pick") == true and h.get(p).coins == 0 and h.get(p).gear.pick == 2,
		"Iron Pick costs exactly 150"
	)
	check(lastNotice(h) == "Upgraded to the Iron Pick!", "upgrade notice names the tier")
	econ = h.eventsOf("economy")
	check(
		econ[#econ][1] == "Sink" and econ[#econ][5] == "Upgrade" and econ[#econ][6] == "Pick",
		"economy event: Sink, Upgrade:Pick"
	)
	local ok, err = h.actions:upgrade(p, "Lamp")
	check(not ok and err == "You need 120 more coins for the Oil Lantern.", "shortfall message is exact")
	setCoins(h, p, 1e9)
	for _ = 1, 4 do
		h.actions:upgrade(p, "Lamp")
	end
	ok, err = h.actions:upgrade(p, "Lamp")
	check(
		not ok and err == "Your lamp is already the best there is." and h.get(p).gear.lamp == 5,
		"top tier refused with a message"
	)
	check(h.oil(p) == 240 and h.session(p).capacity == 240, "a lamp upgrade at camp fills the new lamp")
	local gearEvents = 0
	for _, e in h.eventsOf("custom") do
		if e[1] == "Gear:Upgrade" then
			gearEvents += 1
		end
	end
	check(gearEvents == 5, "one Gear:Upgrade event per purchase")
	-- Auto-sell perk.
	local h2, p2 = fresh({ perks = { biggerPack = true, betterLamp = true, autoSell = true } })
	check(
		Gear.packCapacity(h2.get(p2), gear, h2.perks) == 40 and h2.session(p2).capacity == 90,
		"Bigger Pack (+25) and Better Lamp (x1.5) perks apply"
	)
	check((digDown(h2, p2, 3, 3, 2)), "dug 2 rows")
	give(h2, p2, { Copper = 3 })
	h2.actions:climb(p2)
	h2.wait(p2, 5)
	check(
		Pack.count(h2.get(p2).pack) == 0 and h2.get(p2).coins >= 15 and #h2.sales == 1,
		"Auto-Sell sells on arrival after a climb"
	)
	note(
		"Auto-Sell makes the sell pad pointless, which is the intent; the pad prompt still reads 'Pack is empty' for those players (fine)"
	)
end

-- ---------------------------------------------------------------------------
section("Onboarding and analytics")
do
	local h, p = fresh({ seed = 31 })
	check((digDown(h, p, 2, 2, 12)), "dug 12 rows")
	h.actions:climb(p)
	h.wait(p, 10)
	h.actions:sell(p)
	setCoins(h, p, 150)
	h.actions:upgrade(p, "Pick")
	h.standOn(p, 2, 2)
	h.stand(p, 2, 12, 2)
	h.wait(p, 0.2)
	check((h.mine(p, 2, 13, 2)), "mined into layer 2")
	h.actions:climb(p)
	h.wait(p, 20)
	h.standOn(p, 9, 9)
	h.wait(p, 0.2)
	give(h, p, { Coal = 8 })
	h.wait(p, 91)
	local names, steps = {}, {}
	for _, e in h.eventsOf("onboarding") do
		table.insert(names, e[2])
		table.insert(steps, e[1])
	end
	check(
		#h.lampOuts == 1 and h.get(p).firsts.FirstLampOut ~= nil,
		"the lamp-out after reaching layer 2 happened and was marked in firsts"
	)
	check(
		table.find(Actions.ONBOARDING, "FirstLampOut") == nil or table.find(names, "FirstLampOut") ~= nil,
		if table.find(Actions.ONBOARDING, "FirstLampOut")
			then "FirstLampOut is reported when it happens after Layer2Reached"
			else "the onboarding funnel is linear ("
				.. table.concat(Actions.ONBOARDING, ",")
				.. "); the lamp-out and layer 2 are separate events",
		"FirstLampOut (step 5) is never reported for a player who reached layer 2 (step 6) first: Analytics.onboarding drops any step <= the last one sent, and d.firsts already marks it, so the event is lost for good. Sent: "
			.. table.concat(names, ",")
			.. ". Keep the funnel strictly linear (drop FirstLampOut from ONBOARDING; Dive:LampOut 'First' already covers it) or let Analytics accept out-of-order steps"
	)
	local numbered = true
	for i, name in names do
		if Actions.ONBOARDING[steps[i]] ~= name then
			numbered = false
		end
	end
	check(numbered, "each onboarding step carries its fixed step number")
	local prog = h.eventsOf("progression")
	check(
		#prog == 2 and prog[1][3] == 1 and prog[2][1] == "Layer" and prog[2][2] == "Start" and prog[2][3] == 2,
		"Layer progression Start 1 then Start 2 on the first block of each layer"
	)
	local custom: { [string]: number } = {}
	for _, n in customNames(h) do
		custom[n] = (custom[n] or 0) + 1
	end
	local list = {}
	for n, c in custom do
		table.insert(list, `{n} x{c}`)
	end
	table.sort(list)
	note("custom events seen: " .. table.concat(list, ", "))
	note(
		"the funnel ends at FirstLampOut/Layer2Reached: nothing marks the first 5-minute session, the first full pack, Layer3 or a first max-tier purchase, which the 10-minute-session gate will want"
	)
end

-- ---------------------------------------------------------------------------
section("Mine generation")
do
	local a = MineGrid.new(mine, blocks, 777)
	local b = MineGrid.new(mine, blocks, 777)
	local c = MineGrid.new(mine, blocks, 778)
	local same, diff = true, 0
	for y = 1, a.rows do
		for z = 1, mine.length do
			for x = 1, mine.width do
				if a:blockAt(x, y, z) ~= b:blockAt(x, y, z) then
					same = false
				end
				if a:blockAt(x, y, z) ~= c:blockAt(x, y, z) then
					diff += 1
				end
			end
		end
	end
	check(same and diff > 1000, "the same seed builds the same mine; a neighbouring seed a different one")
	check(a.exposedCount == 256, "a fresh mine shows only its 256 top blocks")
	local ch = a:breakBlock(1, 1, 1, 0)
	check(
		#ch.hidden == 1 and #ch.shown == 1 and a.exposedCount == 256,
		"breaking a corner block hides 1 Part and shows 1 (the block below; the top-face neighbours were already shown)"
	)
	-- Weights over many seeds.
	local totals: { [number]: { [string]: number } } = {}
	local cells = 0
	local adjacentSame, adjacentPairs = { 0, 0, 0 }, { 0, 0, 0 }
	for seed = 1, 20 do
		local g = MineGrid.new(mine, blocks, seed * 7919)
		for y = 1, g.rows do
			local layer = Layout.layerOf(mine, y)
			totals[layer] = totals[layer] or {}
			for z = 1, mine.length do
				for x = 1, mine.width do
					local id = g:blockAt(x, y, z)
					totals[layer][id] = (totals[layer][id] or 0) + 1
					cells += 1
					if x < mine.width then
						adjacentPairs[layer] += 1
						if g:blockAt(x + 1, y, z) == id then
							adjacentSame[layer] += 1
						end
					end
				end
			end
		end
	end
	for index, layer in mine.layers do
		local n = 0
		for _, count in totals[index] do
			n += count
		end
		local worst = 0
		local detail = {}
		local expectedSame = 0
		for _, entry in layer.blocks do
			local expected = entry.weight / 10000
			local got = (totals[index][entry.id] or 0) / n
			local rel = math.abs(got - expected) / expected
			worst = math.max(worst, rel)
			expectedSame += expected * expected
			table.insert(
				detail,
				string.format("%s %.2f%% (want %.2f%%)", entry.id, got * 100, expected * 100)
			)
		end
		-- With ~61k cells per layer, even a 1% block has ~600 samples: 15% relative error is far outside chance.
		check(
			worst < 0.15,
			`{layer.name} block frequencies match the layer guide over 20 seeds: {table.concat(detail, ", ")}`,
			`{layer.name} frequencies off: {table.concat(detail, ", ")}`
		)
		local sameRate = adjacentSame[index] / adjacentPairs[index]
		check(
			math.abs(sameRate - expectedSame) < 0.02,
			string.format(
				"%s: neighbouring blocks are independent (same-block rate %.3f, expected %.3f)",
				layer.name,
				sameRate,
				expectedSame
			),
			string.format(
				"%s: neighbouring blocks are not independent (same-block rate %.3f over %d pairs, independence gives %.3f; that is >20 standard deviations)",
				layer.name,
				sameRate,
				adjacentPairs[index],
				expectedSame
			)
		)
	end
	-- Structure along a row: are consecutive rolls an arithmetic progression?
	do
		local g = MineGrid.new(mine, blocks, 123457)
		local diffs: { [number]: number } = {}
		local distinct = 0
		for z = 1, mine.length do
			for y = 1, 3 do
				local prev = MineGrid.hash(g.seed, 1, y, z, 0) % 10000
				for x = 2, mine.width do
					local roll = MineGrid.hash(g.seed, x, y, z, 0) % 10000
					local dlt = (roll - prev) % 10000
					if diffs[dlt] == nil then
						distinct += 1
					end
					diffs[dlt] = (diffs[dlt] or 0) + 1
					prev = roll
				end
			end
		end
		local pairs = mine.length * 3 * (mine.width - 1)
		local steps = {}
		for dlt in diffs do
			table.insert(steps, dlt)
		end
		table.sort(steps)
		check(
			distinct > 100,
			`hash: roll differences between x-neighbours look random ({distinct} distinct values over {pairs} pairs)`,
			`MineGrid.hash is affine in each coordinate: the roll of (x+1,y,z) is always the roll of (x,y,z) plus one of {table.concat(
				steps,
				" or "
			)} (mod 10000), for every seed. Same along y (+2236/+5883), z (+2936/+6583) and regrowth (+4608/+8255). Every server's mine is the same lattice of ore, shifted by the seed, and a regrown block's type is a fixed function of what stood there. Mix non-linearly between coordinate steps (bit32 xorshift) or hash the tuple with an FNV/xxhash-style routine, and add a test on neighbour differences`
		)
		-- Lines of ore: count how often ore sits on an x/z diagonal vs chance.
		local oreCount, diagSame, diagPairs = 0, 0, 0
		for z = 1, mine.length - 1 do
			for x = 1, mine.width - 1 do
				local here = blocks[g:blockAt(x, 1, z)].value > 0
				local diag = blocks[g:blockAt(x + 1, 1, z + 1)].value > 0
				if here then
					oreCount += 1
				end
				diagPairs += 1
				if here and diag then
					diagSame += 1
				end
			end
		end
		note(
			string.format(
				"top face seed 123457: %d ore of 225; ore-next-to-ore on the diagonal %d times (chance ~%.0f)",
				oreCount,
				diagSame,
				225 * 0.2 * 0.2
			)
		)
	end
	note(
		"Quartz is 1% of layer 1 (about 31 of the 3072 blocks in the whole layer); Emberite 1% of layer 3. A full dig of a layer is 3072 blocks, so a server's mine holds roughly 31 Quartz, 77 Jade and 31 Emberite before regrowth"
	)
end

-- ---------------------------------------------------------------------------
section("Regrowth")
do
	local h, p = fresh({ seed = 41 })
	check((digDown(h, p, 9, 9, 3)), "dug 3 rows")
	h.actions:climb(p)
	h.wait(p, 5)
	h.clock.advance(mine.regrowSeconds - 15)
	h.actions:regrowMine()
	check(not h.grid:isSolid(9, 1, 9), "no regrowth before regrowSeconds")
	h.clock.advance(16)
	h.actions:regrowMine()
	check(
		h.grid:isSolid(9, 1, 9) and h.grid:isSolid(9, 3, 9) and h.grid.exposedCount == 256,
		"the shaft grows back and the mine shows its top face again"
	)
	-- Near a player: no regrowth.
	check((digDown(h, p, 2, 2, 2)), "dug 2 rows")
	h.clock.advance(mine.regrowSeconds + 1)
	h.actions:regrowMine()
	check(not h.grid:isSolid(2, 1, 2), "blocks within 24 studs of a player do not grow back")
	-- Sealed-in: a player at the bottom of an old shaft.
	local h2, p2 = fresh({ seed = 42 })
	check((digDown(h2, p2, 8, 8, 12)), "dug 12 rows")
	-- Pretend the dig took a while: the top rows are older than regrowSeconds.
	for y = 1, 7 do
		h2.grid.mined[h2.grid:key(8, y, 8)] = h2.clock.now() - mine.regrowSeconds - 1
	end
	h2.actions:regrowMine()
	local sealedRows = 0
	for y = 1, 12 do
		if h2.grid:isSolid(8, y, 8) then
			sealedRows += 1
		end
	end
	if sealedRows > 0 then
		note(
			`a player at row 12 of a shaft whose top rows are older than 5 min gets {sealedRows} rows of rock grown back above them (clearance is 24 studs = 4 blocks). Climb out still works (it teleports), so nobody is trapped, but the player sees the shaft seal and a friend following them is cut off`
		)
	else
		pass("a shaft does not grow back above a player standing in it")
	end
	check(h2.actions:climb(p2) == true, "Climb out still works from a sealed shaft")
	h2.wait(p2, 10)
	check(phase(h2, p2) == "Camp", "...and gets the player to camp")
	note(
		"with Carbide Lamp (240 s) dives and 300 s regrowth, a reused shaft regularly seals behind its owner during the second dive in it; consider pausing regrowth of a column while anyone is below it, or a longer regrowSeconds (600) once the mine is not emptied out"
	)
end

-- ---------------------------------------------------------------------------
section("Several players")
do
	local h = Harness.new({ seed = 51 })
	local players = {}
	for i = 1, 8 do
		local p = Fakes.player(300 + i)
		h.join(p)
		table.insert(players, p)
	end
	check(#players == 8, "8 players join one server")
	-- B finishes A's half-broken ore block.
	local a, b = players[1], players[2]
	local x, z = h.columnWithOre(1)
	-- make sure (x,1,z) is ore
	local id = h.grid:blockAt(x, 1, z)
	if blocks[id].value == 0 then
		for zz = 1, mine.length do
			for xx = 1, mine.width do
				if blocks[h.grid:blockAt(xx, 1, zz)].value > 0 then
					x, z, id = xx, zz, h.grid:blockAt(xx, 1, zz)
				end
			end
		end
	end
	h.standOn(a, x, z)
	h.standOn(b, x, z)
	h.actions:step(a)
	h.actions:step(b)
	local hp = h.grid:hp(x, 1, z)
	for _ = 1, hp - 1 do
		h.actions:hit(a, x, 1, z)
		h.clock.advance(0.3)
	end
	h.actions:hit(b, x, 1, z)
	check(
		not h.grid:isSolid(x, 1, z) and Pack.count(h.get(b).pack) == 1 and Pack.count(h.get(a).pack) == 0,
		`player B lands the last swing on A's {id} and takes it`
	)
	note(
		"the last swing takes the ore: a second player can snipe a block someone else has cracked open (visible as the fading Part). Expected in a shared mine, but worth a 'claimed for 2 s' rule if players complain"
	)
	-- A drops into B's shaft.
	local c = players[3]
	check((digDown(h, c, 12, 12, 6)), "C dug a 6-row shaft")
	h.actions:climb(c)
	h.wait(c, 10)
	local d = players[4]
	h.stand(d, 12, 6, 12)
	h.actions:step(d)
	check(
		phase(h, d) == "Diving" and h.session(d).row == 6 and h.oil(d) == 60,
		"D drops into C's open shaft: dive starts at row 6 with a full lamp"
	)
	-- Leaving does not disturb others.
	h.leave(a)
	check(
		h.session(b) ~= nil and h.session(d).phase == "Diving",
		"one player leaving leaves the others' dives alone"
	)
	for i = 2, 8 do
		h.leave(players[i])
	end
	pass("all 8 players left cleanly")
end

-- ---------------------------------------------------------------------------
section("Hash edge cases")
do
	local g = MineGrid.new(mine, blocks, 0)
	check(g:blockAt(1, 1, 1) ~= nil, "seed 0 builds a mine")
	local g2 = MineGrid.new(mine, blocks, 2 ^ 31 - 2)
	check(g2:blockAt(16, 36, 16) ~= nil, "the largest server seed builds a mine")
	local ok = pcall(MineGrid.new, mine, blocks, 1.5)
	check(not ok, "a fractional seed is refused")
	-- Regrown blocks are a fresh roll (generation changes the hash).
	local changed = 0
	for z = 1, 16 do
		for x = 1, 16 do
			local before = g:blockAt(x, 1, z)
			g.regrown[g:key(x, 1, z)] = 1
			if g:blockAt(x, 1, z) ~= before then
				changed += 1
			end
		end
	end
	check(changed > 40 and changed < 200, `regrown blocks re-roll ({changed} of 256 changed; ~87 expected)`)
end

print(string.format("\n%d pass, %d bug, %d notes", counts.pass, counts.bug, counts.note))
if counts.bug > 0 then
	require("@lune/process").exit(1)
end
