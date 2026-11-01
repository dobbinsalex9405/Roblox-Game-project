--!strict
-- System-by-system checks of Street Food Empire (PR #5) through its own
-- Harness. Prints [PASS] / [BUG] / [NOTE] lines and a summary. A BUG is
-- behaviour that contradicts SPEC.md or common sense; a NOTE is design
-- feedback or a number worth a look.
--   lune run playtests/street-food-empire/checks.luau

local Harness = require("../../games/street-food-empire/tests/Harness")
local Fakes = require("../../packages/core/tests/Fakes")
local Log = require("../../packages/core/src/Log")
local Schema = require("../../packages/core/src/Schema")
local Restaurant = require("../../games/street-food-empire/src/shared/Restaurant")
-- Layout needs Roblox's Vector3, so its formatting helpers are copied here.
local Layout = {}
function Layout.displayName(id: string): string
	return (string.gsub(id, "(%l)(%u)", "%1 %2"))
end
function Layout.shortNumber(n: number): string
	for _, unit in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if math.abs(n) >= unit[1] then
			return string.format("%.2f%s", n / unit[1], unit[2])
		end
	end
	return tostring(math.floor(n))
end
function Layout.duration(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end
local SchemasFactory = require("../../games/street-food-empire/src/shared/Schemas")

Log.setSink(function() end)

local config = Harness.config
local economy = config.economy
local QMAX = economy.customers.queueMax
local function cookPerMinute(tier: string): number
	for _, c in config.cooks.tiers do
		if c.id == tier then
			return c.servesPerMinute
		end
	end
	error("unknown cook " .. tier)
end
local TR = cookPerMinute("Trainee") -- Trainee serves a minute
local LC = cookPerMinute("LineCook")
local TR_CART = TR * 5 / 60 -- Trainee on the level-1 cart, cash a second
local TR_LEMON = TR * 4 / 60

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
local function lastNotice(h: any): string
	return h.notices[#h.notices] or ""
end
local function fresh(opts: any?): (any, any)
	local h = Harness.new(opts)
	local p = Fakes.player(1)
	h.join(p)
	return h, p
end
local function rates(h: any, p: any)
	return Restaurant.rates(h.get(p), config, { doubleCash = h.perks.doubleCash }, h.clock.now())
end
local function stationCfg(id: string)
	return Restaurant.stationConfig(config, id)
end

-- ---------------------------------------------------------------------------
section("Config")
do
	local Schemas = SchemasFactory(Schema)
	local problems = Schemas.crossCheck(config)
	check(#problems == 0, "config cross-check passes", "config: " .. table.concat(problems, "; "))
	local menu = 0
	local allCosts = 0
	for _, s in config.stations do
		menu += s.levels[3].price
		for _, l in s.levels do
			allCosts += l.cost
		end
	end
	note(
		`the full menu at level 3 is worth {menu} a meal; a hand serve pays {math.floor(menu * 1.25)}; all 36 station levels cost {Layout.shortNumber(
			allCosts
		)}`
	)
	local traffic = 0
	for _, d in config.districts do
		traffic += d.customersPerMinute
	end
	note(
		`foot traffic 12 / 20 / 30 a minute with 1 / 2 / 3 districts; the queue (max {QMAX}) holds {QMAX * 5} s / {QMAX * 3} s / {QMAX * 2} s of arrivals`
	)
	local chefs = 0
	for n = 0, 11 do
		chefs += math.floor(500000 * 1.5 ^ n)
	end
	note(
		`twelve Chefs cost {Layout.shortNumber(chefs)} in total (500K growing x1.5), more than the 100M rebirth`
	)
	note(
		string.format(
			"hand serve at the start: 12 customers a minute x %d cash = %d a minute; a Trainee on the Hot Dog Cart earns %d a minute into the register",
			math.floor(5 * 1.25),
			12 * math.floor(5 * 1.25),
			6 * 5
		)
	)
end

-- ---------------------------------------------------------------------------
section("New player and the counter")
do
	local h, p = fresh()
	local d = h.get(p)
	check(
		d.cash == 50
			and #d.stations == 1
			and d.stations[1].stationId == "HotDogCart"
			and d.stations[1].readyAt == 0,
		"new player: 50 cash and a built Hot Dog Cart"
	)
	local ok, err = h.actions:serve(p)
	check(
		not ok and lastNotice(h) == "Nobody is waiting. Customers are on their way!",
		"serving an empty counter is refused with a notice",
		`serve: {err}`
	)
	h.wait(p, 5)
	check(
		Restaurant.waiting(h.get(p).queue) == 1,
		"one customer arrives every 5 s at the start (12 a minute)"
	)
	ok = h.actions:serve(p)
	check(ok == true and h.get(p).cash == 56 and h.served[1] == 6, "a hand serve pays floor(5 x 1.25) = 6")
	check(h.get(p).stats.customersServed == 1, "customersServed counts")
	local econ = h.eventsOf("economy")
	check(
		#econ == 1 and econ[1][1] == "Source" and econ[1][5] == "Gameplay" and econ[1][6] == "Serve",
		"economy event Gameplay:Serve"
	)
	-- Queue cap.
	h.wait(p, 180)
	check(
		Restaurant.waiting(h.get(p).queue) == math.min(QMAX, 36),
		`after 3 minutes away the line holds {math.min(QMAX, 36)} (queue max {QMAX}), the rest walked on by`
	)
	for _ = 1, math.min(QMAX, 36) do
		h.actions:serve(p)
	end
	check(not h.actions:serve(p), `{math.min(QMAX, 36)} serves clear the line`)
	note(
		`the Serve prompt is one press per customer. A player who steps away for {QMAX * 5} s at district 1 (or {QMAX * 2} s with three districts) starts losing customers; nothing on screen says how many walked away`
	)
	-- Spam.
	local before = #h.notices
	for _ = 1, 5 do
		h.actions:serve(p)
	end
	check(
		#h.notices - before == 5,
		"five Serve presses on an empty counter give five notices (the client hides the prompt when nobody waits, so this only matters for a modified client)"
	)
end

-- ---------------------------------------------------------------------------
section("Stations: build, upgrade, move")
do
	local h, p = fresh()
	local ok, err = h.actions:build(p, "LemonadeStand", 2)
	check(ok == true and h.get(p).cash == 20, "Lemonade Stand costs 30 on spot 2")
	check(rates(h, p).meal == 5, "a station under construction adds nothing to the meal")
	h.wait(p, 5)
	check(rates(h, p).meal == 9, "after its 5 s build the Lemonade Stand adds 4 to the meal")
	check(h.get(p).firsts.FirstStationBought ~= nil, "FirstStationBought marked")
	ok, err = h.actions:build(p, "LemonadeStand", 3)
	check(not ok and err == "You already have that station.", "a second copy is refused")
	ok, err = h.actions:build(p, "TacoTruck", 3)
	check(
		not ok and err == "Open Market Row first.",
		"a Market Row station is refused before the district, by display name: " .. tostring(err)
	)
	ok, err = h.actions:build(p, "PretzelOven", 5)
	check(not ok and err == "That spot is not open yet.", "spot 5 is closed with one district")
	ok, err = h.actions:build(p, "PretzelOven", 1)
	check(not ok and err == "That spot is taken.", "spot 1 is taken")
	ok, err = h.actions:build(p, "PretzelOven", 3)
	check(
		not ok and err == "Not enough cash." and lastNotice(h) == "Not enough cash.",
		"200 cash short of a Pretzel Oven is refused with a notice"
	)
	ok, err = h.actions:build(p, "Nothing", 3)
	check(not ok and err == "unknown station", "unknown station refused")
	-- Upgrade keeps the old level while working.
	h.give(p, 100_000)
	ok = h.actions:upgrade(p, 1)
	check(
		ok == true and h.get(p).stations[1].level == 2 and rates(h, p).meal == 9,
		"upgrading the cart keeps it serving at level 1 for 10 s"
	)
	ok, err = h.actions:upgrade(p, 1)
	check(
		not ok and err == "That station is still being upgraded.",
		"a second upgrade during the first is refused: " .. tostring(err)
	)
	h.wait(p, 10)
	check(rates(h, p).meal == 14, "level 2 cart: meal 10 + 4")
	h.actions:upgrade(p, 1)
	h.wait(p, 30)
	ok, err = h.actions:upgrade(p, 1)
	check(not ok and err == "That station is fully upgraded.", "level 3 is the top")
	ok, err = h.actions:upgrade(p, 4)
	check(not ok and err == "There is no station there.", "upgrading an empty spot is refused")
	-- Move swaps, cook follows (by station id).
	assert(h.actions:hireCook(p, "Trainee", 1))
	ok = h.actions:move(p, 1, 2)
	local s1 = Restaurant.stationAt(h.get(p), 1)
	local s2 = Restaurant.stationAt(h.get(p), 2)
	check(
		ok == true and s1 and s1.stationId == "LemonadeStand" and s2 and s2.stationId == "HotDogCart",
		"move swaps the two stations"
	)
	local cook = Restaurant.cookAt(h.get(p), "HotDogCart")
	check(cook ~= nil, "the cook stays with the Hot Dog Cart")
	ok, err = h.actions:move(p, 2, 2)
	check(not ok and err == "It is already there.", "moving onto itself is refused")
	ok, err = h.actions:move(p, 2, 5)
	check(not ok and err == "That spot is not open yet.", "moving to a closed spot is refused")
	ok = h.actions:move(p, 2, 4)
	check(
		ok == true and Restaurant.stationAt(h.get(p), 4) ~= nil and Restaurant.stationAt(h.get(p), 2) == nil,
		"moving to an empty spot leaves the old one empty"
	)
	note(
		"moving is free and purely cosmetic until M4 moods; zones are cosmetic too, so a Taco Truck can sit in Cart Corner once Market Row is open"
	)
	-- Build on a spot of a higher zone with a lower district station.
	h.actions:unlockDistrict(p)
	ok = h.actions:build(p, "PretzelOven", 7)
	check(ok == true, "a Cart Corner station can be built on a Market Row spot (spot 7)")
end

-- ---------------------------------------------------------------------------
section("Cooks and the register")
do
	local h, p = fresh()
	h.give(p, 1000)
	local ok, err = h.actions:hireCook(p, "Trainee", 1)
	check(ok == true and h.get(p).cash == 950, "a Trainee costs 100")
	check(
		math.abs(rates(h, p).registerPerSecond - TR_CART) < 1e-9,
		`a Trainee on the cart earns {TR} x 5 / 60 = {TR_CART} a second into the register`
	)
	h.wait(p, 60)
	check(
		math.abs(h.get(p).pendingCash - TR_CART * 60) < 1e-6,
		`60 s later the register holds {TR_CART * 60}`
	)
	ok = h.actions:collect(p)
	check(
		ok == true and h.get(p).cash == 950 + math.floor(TR_CART * 60) and h.get(p).pendingCash < 1,
		"collect moves whole cash to the wallet"
	)
	local econ = h.eventsOf("economy")
	check(econ[#econ][6] == "Collect", "economy event Gameplay:Collect")
	ok = h.actions:collect(p)
	check(ok == true, "collecting an empty register is a quiet no-op (true, no notice)")
	ok, err = h.actions:hireCook(p, "Trainee", 1)
	check(
		not ok and err == "This station already has a cook that good.",
		"a second Trainee on the same station is refused"
	)
	ok, err = h.actions:hireCook(p, "Trainee", 2)
	check(not ok and err == "Build a station here first.", "hiring on an empty spot is refused")
	assert(h.actions:build(p, "LemonadeStand", 2))
	check(Restaurant.hireCost(h.get(p), config, "Trainee") == 150, "the second Trainee costs 150 (x1.5)")
	ok = h.actions:hireCook(p, "Trainee", 2)
	check(
		ok == true and math.abs(rates(h, p).registerPerSecond - TR_CART) < 1e-9,
		"a cook on a station still being built waits (no extra income yet)"
	)
	h.wait(p, 5)
	check(
		math.abs(rates(h, p).registerPerSecond - (TR_CART + TR_LEMON)) < 1e-9,
		`once built, the Lemonade Trainee adds {TR} x 4 / 60 = {TR_LEMON} a second`
	)
	check(Restaurant.hireCost(h.get(p), config, "Trainee") == 225, "the third Trainee would cost 225")
	-- Replace with a LineCook: the Trainee leaves, no refund, next Trainee cheaper again.
	h.give(p, 10_000)
	local cashBefore = h.get(p).cash
	ok = h.actions:hireCook(p, "LineCook", 1)
	check(
		ok == true and cashBefore - h.get(p).cash == 8000 and #h.get(p).cooks == 2,
		"a Line Cook (8,000) replaces the cart's Trainee"
	)
	check(
		Restaurant.hireCost(h.get(p), config, "Trainee") == 150,
		"with one Trainee left, the next costs 150 again"
	)
	note(
		"replacing a cook refunds nothing and the replaced cook simply vanishes; with Trainee 100 -> Line Cook 8,000 -> Chef 500,000 that is fine, but the hire menu should say 'replaces your Trainee (no refund)'"
	)
	check(
		math.abs(rates(h, p).registerPerSecond - (LC * 5 / 60 + TR_LEMON)) < 1e-9,
		`the Line Cook sells {LC} a minute`
	)
	ok, err = h.actions:hireCook(p, "Trainee", 1)
	check(not ok, "a worse cook cannot replace a better one")
	-- Cook during an upgrade sells at the old price.
	h.actions:upgrade(p, 1)
	check(
		math.abs(rates(h, p).registerPerSecond - (LC * 5 / 60 + TR_LEMON)) < 1e-9,
		"during the cart's upgrade the Line Cook still sells at 5"
	)
	h.wait(p, 10)
	check(
		math.abs(rates(h, p).registerPerSecond - (LC * 10 / 60 + TR_LEMON)) < 1e-9,
		"after the upgrade the Line Cook sells at 10"
	)
	-- Auto-collect perk.
	local h2, p2 = fresh({ perks = { doubleCash = false, autoCollect = true } })
	h2.give(p2, 1000)
	assert(h2.actions:hireCook(p2, "Trainee", 1))
	h2.wait(p2, 29)
	local before = h2.get(p2).cash
	h2.wait(p2, 11)
	check(h2.get(p2).cash > before, "Auto-Collect banks the register within 30-40 s")
	note(
		"Auto-Collect runs on the 10 s tick, so it fires 30-40 s apart; the HUD says 'Auto-collecting' which covers it"
	)
end

-- ---------------------------------------------------------------------------
section("Districts and rebirth")
do
	local h, p = fresh()
	local ok, err = h.actions:unlockDistrict(p)
	check(not ok and err == "Not enough cash.", "Market Row needs 8,000")
	h.give(p, 8000)
	ok = h.actions:unlockDistrict(p)
	check(
		ok == true and h.get(p).districts == 2 and Restaurant.spotCount(2, config) == 8,
		"Market Row opens 4 more spots"
	)
	check(math.abs(rates(h, p).customersPerSecond - 20 / 60) < 1e-9, "foot traffic is now 20 a minute")
	local prog = h.eventsOf("progression")
	check(
		#prog == 1 and prog[1][1] == "District" and prog[1][2] == "Complete" and prog[1][3] == 2,
		"District Complete 2 reported"
	)
	check(h.get(p).firsts.SecondDistrictUnlocked ~= nil, "SecondDistrictUnlocked marked")
	ok, err = h.actions:rebirth(p)
	check(not ok and err == "Open every district before you rebirth.", "rebirth needs every district")
	h.give(p, 500_000)
	assert(h.actions:unlockDistrict(p))
	ok, err = h.actions:unlockDistrict(p)
	check(not ok and err == "Every district is open.", "no fourth district")
	ok, err = h.actions:rebirth(p)
	check(not ok and err == "Not enough cash to rebirth.", "rebirth needs 100M cash")
	-- Build some things, leave cash in the register, then rebirth with extra cash.
	h.give(p, 150_000_000)
	assert(h.actions:build(p, "TacoTruck", 5))
	assert(h.actions:hireCook(p, "Trainee", 1))
	h.wait(p, 120)
	local pending = h.get(p).pendingCash
	local cashBefore = h.get(p).cash
	ok = h.actions:rebirth(p)
	local d = h.get(p)
	check(
		ok == true
			and d.rebirths == 1
			and d.districts == 1
			and #d.stations == 1
			and #d.cooks == 0
			and d.queue == 0,
		"rebirth resets the restaurant"
	)
	check(d.cash == economy.startingCash, "cash after rebirth is the starting 50")
	local lost = cashBefore - economy.rebirth.cost
	if lost > 0 then
		note(
			`rebirth took the whole wallet: {Layout.shortNumber(lost)} above the 100M cost was burned ('Gameplay:RebirthReset'), plus {Layout.shortNumber(
				pending
			)} left in the register. The stand should warn, or keep the surplus (same finding as Hatchery Heist)`
		)
	end
	check(#d.rebirthArchive == 1 and #d.rebirthArchive[1].stations == 2, "the old restaurant is archived")
	check(math.abs(rates(h, p).multiplier - 1.5) < 1e-9, "+50% cash after the rebirth")
	h.wait(p, 5)
	assert(h.actions:serve(p))
	check(
		h.served[#h.served] == math.floor(5 * 1.25 * 1.5),
		"a hand serve after rebirth pays floor(5 x 1.25 x 1.5) = 9"
	)
	h.give(p, 1e9)
	assert(h.actions:unlockDistrict(p))
	assert(h.actions:unlockDistrict(p))
	ok, err = h.actions:rebirth(p)
	check(
		not ok and err == "You have done every rebirth for now. More are coming!",
		"one rebirth at launch, with a message"
	)
	local progs = h.eventsOf("progression")
	check(progs[#progs - 2][1] == "Rebirth" or progs[#progs][1] == "Rebirth" or (function()
		for _, e in progs do
			if e[1] == "Rebirth" then
				return true
			end
		end
		return false
	end)(), "Rebirth progression reported")
	note(
		"after the single rebirth there is no further goal: a +50% restaurant with the same 12 stations. The 6-hour climb to the rebirth is the whole launch content"
	)
end

-- ---------------------------------------------------------------------------
section("Offline, leaving, rejoining")
do
	local store = Fakes.store()
	local h = Harness.new({ store = store })
	local p = Fakes.player(9)
	h.join(p)
	h.give(p, 1000)
	assert(h.actions:hireCook(p, "Trainee", 1))
	assert(h.actions:build(p, "PretzelOven", 2)) -- builds for 15 s: a rate change while away
	assert(h.actions:hireCook(p, "Trainee", 2))
	h.actions:collect(p)
	local leftAt = h.clock.now()
	local snapshot = h.get(p)
	local playBefore = snapshot.stats.playSeconds
	h.leave(p)
	-- Away one hour on another server.
	local h2 = Harness.new({ store = store, start = leftAt + 3600 })
	h2.join(p)
	local d = h2.get(p)
	-- Cart Trainee for 3600 s; Pretzel Trainee (10 a meal) from 15 s on. All at 50%.
	local expected = (TR_CART * 3600 + (TR * 10 / 60) * (3600 - 15)) * 0.5
	check(
		math.abs(d.pendingCash - expected) < 1e-6,
		string.format(
			"an hour away pays the cooks 50%%, with the Pretzel Oven finishing 15 s in (%.1f)",
			expected
		)
	)
	check(
		#h2.welcomes == 1 and h2.welcomes[1].cash == math.floor(expected) and h2.welcomes[1].waiting == QMAX,
		`the welcome-back message says the cash and {QMAX} waiting`
	)
	check(d.stats.playSeconds == playBefore, "offline time does not count as play time")
	check(
		d.cash == snapshot.cash and #d.stations == 2 and #d.cooks == 2,
		"cash, stations and cooks survive the rejoin"
	)
	h2.leave(p)
	-- Away ten hours: capped at 2 h of pay.
	local h3 = Harness.new({ store = store, start = h2.clock.now() + 10 * 3600 })
	h3.join(p)
	local rate = TR_CART + TR * 10 / 60
	check(
		math.abs(h3.get(p).pendingCash - (d.pendingCash + rate * 7200 * 0.5)) < 1e-6,
		"ten hours away pays for two"
	)
	note(
		"offline pay is 50% of the cooks' rate for 2 h. For an attentive player the cooks are about a quarter of income, so a full offline cap is worth roughly 15 minutes of active play; a return hook, but a modest one"
	)
	-- A short hop between servers.
	h3.leave(p)
	local h4 = Harness.new({ store = store, start = h3.clock.now() + 3 })
	h4.join(p)
	check(#h4.welcomes == 1, "a 3-second hop still shows the welcome message (register and 12 waiting)")
	note(
		"every rejoin, even a 3 s server hop, gets 'Welcome back! your cooks earned ... and 12 customers are waiting' when the line was already full; fine, but it will also fire on every rejoin after a crash"
	)
	-- Session lock.
	local other = Harness.new({ store = store })
	local ok = pcall(other.join, p)
	check(not ok, "a second server cannot load a player who is still in the first")
end

-- ---------------------------------------------------------------------------
section("Onboarding and analytics")
do
	-- The intended order.
	local h, p = fresh()
	h.wait(p, 5)
	assert(h.actions:serve(p))
	assert(h.actions:build(p, "LemonadeStand", 2))
	h.give(p, 100_000)
	if table.find(Restaurant.ONBOARDING, "FirstUpgrade") then
		assert(h.actions:upgrade(p, 1))
	end
	assert(h.actions:hireCook(p, "Trainee", 1))
	assert(h.actions:unlockDistrict(p))
	local names = {}
	for _, e in h.eventsOf("onboarding") do
		table.insert(names, e[2])
	end
	check(
		table.concat(names, ",") == table.concat(Restaurant.ONBOARDING, ","),
		"played in the listed order, every step is reported: " .. table.concat(Restaurant.ONBOARDING, ","),
		table.concat(names, ",")
	)
	-- Cook before station: a real option with 100 cash after 9 serves.
	local h2, p2 = fresh()
	h2.give(p2, 100)
	assert(h2.actions:hireCook(p2, "Trainee", 1))
	h2.wait(p2, 5)
	assert(h2.actions:serve(p2))
	h2.give(p2, 100_000)
	assert(h2.actions:build(p2, "LemonadeStand", 2))
	assert(h2.actions:unlockDistrict(p2))
	local names2 = {}
	for _, e in h2.eventsOf("onboarding") do
		table.insert(names2, e[2])
	end
	check(
		table.find(names2, "FirstStationBought") ~= nil and table.find(names2, "FirstCustomerServed") ~= nil,
		"a player who hires a cook first still reports FirstCustomerServed and FirstStationBought",
		"a player who hires a Trainee (step 4) before serving (step 2) or building (step 3) never reports those steps: core Analytics drops any step <= the last one sent and firsts is already marked. Sent: "
			.. table.concat(names2, ",")
			.. ". Hiring first is a real path (100 cash after 9 serves; the cart's Hire prompt is right there). Send steps in a fixed order regardless of play order, or let Analytics accept them out of order"
	)
	local custom: { [string]: number } = {}
	for _, e in h.eventsOf("custom") do
		custom[e[1]] = (custom[e[1]] or 0) + 1
	end
	local list = {}
	for n, c in custom do
		table.insert(list, `{n} x{c}`)
	end
	table.sort(list)
	note("custom events seen: " .. table.concat(list, ", "))
	note(
		"nothing marks the first upgrade, the first full line (12 waiting), District 3 or the first Line Cook; the 10-minute-session gate will want a step near minute 5-10 (first Fry Station, say)"
	)
end

-- ---------------------------------------------------------------------------
section("Passes")
do
	local h, p = fresh({ perks = { doubleCash = true, autoCollect = false } })
	h.wait(p, 5)
	assert(h.actions:serve(p))
	check(h.served[1] == math.floor(5 * 1.25 * 2), "2x Cash doubles a hand serve (12)")
	h.give(p, 1000)
	assert(h.actions:hireCook(p, "Trainee", 1))
	check(math.abs(rates(h, p).registerPerSecond - 2 * TR_CART) < 1e-9, "2x Cash doubles the register")
	note(
		"2x Cash is a straight x2 on everything, including the rebirth climb: it roughly halves the 6 hours. Price it with that in mind at M5"
	)
end

-- ---------------------------------------------------------------------------
section("First-session guide (PR #13)")
do
	-- The guide must never point at something the player cannot do right now,
	-- and its goals must never go backwards, whatever the player's habits.
	-- Each bot style plays 15 minutes; whenever the guide says a goal is
	-- affordable ("... for $N"), the matching action is taken and must succeed.
	local hasGuide, Guide = pcall(require, "../../games/street-food-empire/src/shared/Guide")
	local hasBot, PlayBot = pcall(require, "./bot")
	if not hasGuide then
		note("no Guide module in this build; skipping")
	elseif not hasBot then
		bug(`the playtest bot failed to load: {PlayBot}`)
	else
		local ORDER = { Serve = 1, Build = 2, Upgrade = 3, Hire = 4, Unlock = 5 }
		local function money(n: number): string
			return `${math.floor(n)}`
		end
		local function unspace(text: string): string
			return (string.gsub(text, " ", ""))
		end
		for _, styleName in { "attentive", "batcher", "casual", "idle" } do
			local style = PlayBot.STYLES[styleName]
			local h, p = fresh()
			local b = PlayBot.new(h, p, style)
			local last, backwards, refused, finishedAt = 0, 0, {}, nil
			local seen = {}
			for second = 1, 15 * 60 do
				local d = h.get(p)
				local now = h.clock.now()
				local step = Guide.next(d, config, h.perks, now, false, money)
				if step == nil then
					finishedAt = finishedAt or second
					break
				end
				local rank = ORDER[step.id]
				if rank == nil then
					bug(`{styleName}: unknown guide step id {step.id}`)
				elseif rank < last then
					backwards += 1
				else
					if rank > last then
						table.insert(seen, step.id)
					end
					last = rank
				end
				local target = step.target
				if target == nil then
					bug(`{styleName}: guide step "{step.text}" has no target`)
				elseif target.kind == "Register" then
					local pending = Restaurant.preview(d, config, h.perks, now)
					if pending < 1 then
						table.insert(refused, `collect with an empty register: {step.text}`)
					end
				elseif
					string.find(step.text, " for %$") and (target.kind == "Spot" or target.kind == "Gate")
				then
					local ok, err
					local station = string.match(step.text, "^Build a (.-) for %$")
					local upgrade = string.match(step.text, "^Upgrade your (.-) for %$")
					local tier = string.match(step.text, "^Hire a (.-) for ")
					if station then
						ok, err = h.actions:build(p, unspace(station), target.spot)
					elseif upgrade then
						ok, err = h.actions:upgrade(p, target.spot)
					elseif tier then
						local tierId = if tier == "cook" then config.cooks.tiers[1].id else unspace(tier)
						ok, err = h.actions:hireCook(p, tierId, target.spot)
					elseif target.kind == "Gate" then
						ok, err = h.actions:unlockDistrict(p)
					else
						ok, err = false, "the check does not know this step"
					end
					if not ok then
						table.insert(refused, `{step.id} "{step.text}" -> {err or lastNotice(h)}`)
					end
				end
				PlayBot.play(h, b, 1)
			end
			check(
				backwards == 0,
				`{styleName}: guide goals never go backwards ({table.concat(seen, " > ")})`,
				`{styleName}: the guide went backwards {backwards} times`
			)
			check(
				#refused == 0,
				`{styleName}: every affordable goal the guide pointed at could be done`,
				`{styleName}: {#refused} guided actions refused, first: {refused[1]}`
			)
			if finishedAt then
				note(
					`{styleName}: the guide finished (Market Row open) at {finishedAt // 60}:{string.format(
						"%02d",
						finishedAt % 60
					)}`
				)
			else
				note(`{styleName}: still on "{seen[#seen]}" after 15 minutes`)
			end
		end
	end
end

-- ---------------------------------------------------------------------------
section("Numbers worth a look")
do
	-- Hand income versus register at a few states.
	local function state(label: string, stations: { any }, cooks: { any }, districts: number)
		local h, p = fresh()
		h.give(p, 1e12)
		for _ = 2, districts do
			assert(h.actions:unlockDistrict(p))
		end
		local spot = 1
		for _, s in stations do
			if s[1] ~= "HotDogCart" then
				spot += 1
				assert(h.actions:build(p, s[1], spot))
			end
			local st = Restaurant.stationById(h.get(p), s[1]) :: any
			for _ = 2, s[2] do
				h.wait(p, 2000)
				assert(h.actions:upgrade(p, st.spot))
			end
		end
		h.wait(p, 2000)
		for _, c in cooks do
			local st = Restaurant.stationById(h.get(p), c[2]) :: any
			assert(h.actions:hireCook(p, c[1], st.spot))
		end
		local r = rates(h, p)
		local hand = r.customersPerSecond * 60 * math.floor(r.meal * 1.25)
		note(
			string.format(
				"%s: meal %d, hand %s/min if every customer is served, register %s/min (%.0f%% of the total)",
				label,
				r.meal,
				Layout.shortNumber(hand),
				Layout.shortNumber(r.registerPerSecond * 60),
				100 * r.registerPerSecond * 60 / (hand + r.registerPerSecond * 60)
			)
		)
	end
	state("start", { { "HotDogCart", 1 } }, {}, 1)
	state(
		"minute 15 (4 Cart Corner stations at level 3, 4 Trainees)",
		{ { "HotDogCart", 3 }, { "LemonadeStand", 3 }, { "PretzelOven", 3 }, { "FryStation", 3 } },
		{
			{ "Trainee", "HotDogCart" },
			{ "Trainee", "LemonadeStand" },
			{ "Trainee", "PretzelOven" },
			{ "Trainee", "FryStation" },
		},
		1
	)
	state(
		"all 12 stations at level 3, 12 Line Cooks",
		(function()
			local t = {}
			for _, s in config.stations do
				table.insert(t, { s.id, 3 })
			end
			return t
		end)(),
		(function()
			local t = {}
			for _, s in config.stations do
				table.insert(t, { "LineCook", s.id })
			end
			return t
		end)(),
		3
	)
	note(
		"a player who taps Serve for every customer earns 3-4x what the cooks make at every stage; cooks only matter while the player is away. That is the tycoon shape, but the first minute is 11 taps and 49 s of standing still"
	)
	-- Walk-by losses for a player who serves in bursts.
	for _, districts in { 1, 3 } do
		local traffic = 0
		for i = 1, districts do
			traffic += config.districts[i].customersPerMinute
		end
		for _, gap in { 60, 120, 180 } do
			local arrivals = traffic * gap / 60
			local lost = math.max(0, arrivals - economy.customers.queueMax)
			note(
				string.format(
					"%d district(s), back every %d s: %.0f of %.0f customers walk away (%.0f%%)",
					districts,
					gap,
					lost,
					arrivals,
					100 * lost / arrivals
				)
			)
		end
	end
	-- Build timers by district.
	for _, s in { "FryStation", "SmoothieBar", "DessertCafe" } do
		local c = stationCfg(s)
		note(
			string.format(
				"%s build/upgrade timers: %s / %s / %s",
				Layout.displayName(s),
				Layout.duration(c.levels[1].buildSeconds),
				Layout.duration(c.levels[2].buildSeconds),
				Layout.duration(c.levels[3].buildSeconds)
			)
		)
	end
end

print(string.format("\n%d pass, %d bug, %d notes", counts.pass, counts.bug, counts.note))
if counts.bug > 0 then
	require("@lune/process").exit(1)
end
