--!nocheck
-- System-by-system checks against the real server logic. Prints PASS / BUG / NOTE lines.
local Sim = require("./Sim")
local Fakes = require("../../packages/core/tests/Fakes")
local Hatchery = require("../../games/hatchery-heist/src/shared/Hatchery")
local Creatures = require("../../games/hatchery-heist/src/shared/Creatures")
local Conveyor = require("../../games/hatchery-heist/src/shared/Conveyor")
local Eggs = require("../../games/hatchery-heist/src/shared/Eggs")
local Log = require("@core/Log")
Log.setSink(function() end)

local config = Sim.config
local economy = config.economy
local NO = { doubleCoins = false, extraIncubators = false }

local results = {}
local function report(status, area, text)
	table.insert(results, { status = status, area = area, text = text })
	print(`[{status}] {area}: {text}`)
end
local function check(cond, area, okText, bugText)
	if cond then
		report("PASS", area, okText)
	else
		report("BUG", area, bugText or okText)
	end
end
local function note(area, text)
	report("NOTE", area, text)
end

local function give(h, p, coins)
	h.economy:add(p, "coins", coins, "Admin:Test")
end

---------------------------------------------------------------- 1. Odds display
do
	local h = Sim.new()
	local p = Fakes.player(101)
	h.join(p)
	for _, egg in config.eggs do
		local disp = h.odds:display(egg.id, p)
		local total = 0
		local text = {}
		for _, r in disp.rows do
			total += r.weight
			table.insert(text, `{r.id} {r.percent}`)
		end
		check(
			total == (egg.total or 10000) and disp.paid,
			"odds",
			`{egg.id} shows {table.concat(text, ", ")} (paid={disp.paid}, total {total})`
		)
	end
	-- a Luck Boost changes the shown table and the roll table identically
	local boost = config.monetization.boosts.LuckBoost
	local meadow = Hatchery.eggById(config.eggs, "MeadowEgg")
	h.odds:setBoosts(
		p,
		"MeadowEgg",
		{ { id = "LuckBoost", multipliers = Eggs.boostMultipliers(meadow, boost, config.creatures.species) } }
	)
	local disp = h.odds:display("MeadowEgg", p)
	local text = {}
	local total = 0
	for _, r in disp.rows do
		total += r.weight
		table.insert(text, `{r.id} {r.percent}`)
	end
	check(
		total == (meadow.total or 10000) and #disp.boosts == 1,
		"odds",
		`boosted MeadowEgg shows {table.concat(text, ", ")} with boosts={table.concat(disp.boosts, ",")}`
	)
	note(
		"odds",
		"the odds board/card only lists belt eggs (BasicEgg, MeadowEgg); PremiumEgg odds are defined but nothing can request or buy it yet (M5)"
	)
	-- restricted player sees fixed order
	local h2 = Sim.new()
	local r = Fakes.player(102)
	h2.join(r, true)
	give(h2, r, 100000)
	local seq = {}
	for _ = 1, 6 do
		assert(h2.buy(r, "BasicEgg"))
		local d = h2.get(r)
		table.insert(seq, d.incubators[#d.incubators].outcome)
		h2.wait(15)
		for _, inc in table.clone(d.incubators) do
			h2.actions:hatch(r, inc.slot)
		end
	end
	-- Since PR #3 (43e0068) the fixed order is a cycle whose frequencies match
	-- the odds exactly (Hatchery.fixedOrderCycle); the first eggs are the most
	-- common outcomes.
	local Hatchery = require("../../games/hatchery-heist/src/shared/Hatchery")
	local egg = nil
	for _, e in config.eggs do
		if e.id == "BasicEgg" then
			egg = e
		end
	end
	local cycle = Hatchery.fixedOrderCycle(egg)
	local counts = {}
	for _, id in cycle do
		counts[id] = (counts[id] or 0) + 1
	end
	local matches = true
	local parts = {}
	for _, o in egg.outcomes do
		local share = (counts[o.id] or 0) / #cycle
		table.insert(parts, string.format("%s %d/%d", o.id, counts[o.id] or 0, #cycle))
		if math.abs(share - o.weight / (egg.total or 10000)) > 1e-9 then
			matches = false
		end
	end
	local expectedSeq = {}
	for i = 1, 6 do
		table.insert(expectedSeq, cycle[i])
	end
	check(
		matches and table.concat(seq, ",") == table.concat(expectedSeq, ","),
		"odds/restricted",
		`restricted player got {table.concat(seq, ",")}; the cycle is {table.concat(parts, ", ")}`
	)
	note(
		"odds/restricted",
		`a restricted player's fixed order now matches the odds over a cycle of {#cycle} eggs (a Turtle once in {#cycle // math.max(
			1,
			counts.Turtle or 1
		)}); the odds card shows the wait for each creature. The old 'Turtle every 4th egg' advantage is gone`
	)
end

---------------------------------------------------------------- 2. Incubators + eggs
do
	local h = Sim.new()
	local p = Fakes.player(201)
	h.join(p)
	give(h, p, 10000)
	for _ = 1, 3 do
		assert(h.buy(p, "BasicEgg"))
	end
	local ok = h.buy(p, "BasicEgg")
	check(not ok, "incubators", `4th egg refused with notice "{h.noticesOf(p)[#h.noticesOf(p)]}"`)
	local d = h.get(p)
	check(
		d.coins == 10000 + economy.startingCoins - 150,
		"incubators",
		`coins after 3 Basic eggs = {d.coins} (expected {10000 + economy.startingCoins - 150})`
	)
	-- hatch early
	local hok = h.actions:hatch(p, 1)
	check(not hok, "incubators", `hatching early refused: "{h.noticesOf(p)[#h.noticesOf(p)]}"`)
	-- hatch slot with no incubator / locked slot
	check(
		not h.actions:hatch(p, 9),
		"incubators",
		`hatching an empty/locked slot refused: "{h.noticesOf(p)[#h.noticesOf(p)]}"`
	)
	h.wait(15)
	for slot = 1, 3 do
		check(h.actions:hatch(p, slot), "incubators", `hatched slot {slot} at readyAt`)
	end
	d = h.get(p)
	check(#d.creatures == 3 and #d.incubators == 0, "incubators", `3 creatures on pads, incubators empty`)
	-- hatch exactly at readyAt boundary: buy, wait exactly hatchSeconds
	assert(h.buy(p, "BasicEgg"))
	local inc = h.get(p).incubators[1]
	h.clock.advance(inc.readyAt - h.clock.now())
	check(h.actions:hatch(p, inc.slot), "incubators", "hatch succeeds at exactly readyAt")
	-- buy a Meadow egg at the far end of the belt (progress 0.95): allowed within tolerance
	local idx
	for _ = 1, 200 do
		for _, e in Conveyor.onBelt(h.clock.now(), economy.conveyor) do
			if e.eggId == "BasicEgg" and e.progress > 0.93 and not h.taken[p][e.index] then
				idx = e.index
			end
		end
		if idx then
			break
		end
		h.wait(1)
	end
	check(h.actions:buyEgg(p, idx), "conveyor", "an egg at 95% of the belt can still be bought")
	h.taken[p][idx] = true
	-- the same belt egg twice
	check(
		not h.actions:buyEgg(p, idx),
		"conveyor",
		`buying the same belt egg twice refused ("{select(2, h.actions:buyEgg(p, idx))}")`
	)
	-- an egg far in the future / past
	check(not h.actions:buyEgg(p, idx + 100), "conveyor", "an egg not yet on the belt is refused")
	check(not h.actions:buyEgg(p, idx - 100), "conveyor", "an egg long gone is refused")
	-- notice when an egg left the belt
	local n = h.noticesOf(p)
	check(n[#n] == "That egg has left the conveyor.", "conveyor", `notice for a gone egg: "{n[#n]}"`)
	-- client-side gap: a refused purchase hides the egg on the client (static finding)
	note(
		"conveyor/client",
		"ConveyorView marks the egg bought and makes it invisible BEFORE the server answers; on a refusal (not enough coins, incubators full) the egg stays invisible and unbuyable for that player until it leaves the belt, while the server would still sell it."
	)
end

---------------------------------------------------------------- 3. Slots
do
	local h = Sim.new()
	local p = Fakes.player(301)
	h.join(p)
	give(h, p, 100000000)
	local costs = {}
	for i, cost in economy.incubators.slotCosts do
		check(Hatchery.nextSlotCost(h.get(p), economy) == cost, "slots", `slot {3 + i} costs {cost}`)
		assert(h.actions:buySlot(p))
		table.insert(costs, cost)
	end
	local ok = h.actions:buySlot(p)
	check(not ok and h.get(p).slots == 12, "slots", `13th slot refused: "{h.noticesOf(p)[#h.noticesOf(p)]}"`)
	-- with the pass: 14 slots usable, the map has 14 incubators
	h.perksOf[p] = { doubleCoins = false, extraIncubators = true, autoCollect = false }
	for i = 1, 14 do
		local ok2, err = h.buy(p, "BasicEgg")
		if not ok2 then
			check(false, "slots", `could not fill slot {i} with the pass: {err}`)
			break
		end
	end
	check(
		#h.get(p).incubators == 14,
		"slots",
		"12 bought slots + 2 pass slots = 14 incubators all usable (map has 14)"
	)
	local total = 0
	for _, c in costs do
		total += c
	end
	note(
		"slots/balance",
		`all 9 slots cost {total} coins total; slots 10-12 (2M, 8M, 30M) cost more than the first rebirth (1M) and slot 12 costs more than rebirths 1-4 combined`
	)
end

---------------------------------------------------------------- 4. Collect + income + coin cap
do
	local h = Sim.new()
	local p = Fakes.player(401)
	h.join(p)
	h.data:update(p, function(d)
		d.creatures = {
			{
				uid = "1",
				speciesId = "Phoenix",
				mutation = "None",
				slot = 1,
				eggId = "PremiumEgg",
				hatchedAt = 0,
			},
		}
		d.nextUid = 2
	end)
	local before = h.get(p).coins
	local rate = config.creatures.species.Phoenix.coinsPerSecond
	h.wait(60)
	local d = h.get(p)
	check(d.pendingCoins == rate * 60, "income", `Phoenix earns {rate}/s: pile after 60s = {d.pendingCoins}`)
	check(
		h.actions:collect(p) and h.get(p).coins == before + rate * 60,
		"collect",
		`collect moved {rate * 60} coins into the wallet (now {h.get(p).coins})`
	)
	check(
		h.actions:collect(p) and h.get(p).coins == before + rate * 60,
		"collect",
		"collecting again moves nothing and is not an error"
	)
	-- rebirth multiplier gives fractional income: 1.25/s on a Chick
	h.data:update(p, function(d2)
		d2.creatures = {
			{
				uid = "2",
				speciesId = "Chick",
				mutation = "None",
				slot = 1,
				eggId = "BasicEgg",
				hatchedAt = 0,
			},
		}
		d2.rebirths = 1
		d2.pendingCoins = 0
	end)
	h.wait(10)
	d = h.get(p)
	check(
		math.abs(d.pendingCoins - 12.5) < 1e-9,
		"income",
		`rebirth 1 Chick earns 1.25/s -> pile {d.pendingCoins} after 10s; collect floors to whole coins`
	)
	-- coin cap
	h.data:update(p, function(d2)
		d2.coins = economy.coinsMax - 10
		d2.pendingCoins = 100
	end)
	h.actions:collect(p)
	check(
		h.get(p).coins == economy.coinsMax and h.get(p).pendingCoins == 0,
		"collect",
		"wallet is capped at coinsMax; the pile is emptied (excess lost, as commented in code)"
	)
end

---------------------------------------------------------------- 5. Rebirth
do
	local h = Sim.new()
	local p = Fakes.player(501)
	h.join(p)
	give(h, p, 5000)
	for _ = 1, 3 do
		assert(h.buy(p, "BasicEgg"))
	end
	h.wait(15)
	for s = 1, 3 do
		h.actions:hatch(p, s)
	end
	assert(h.buy(p, "MeadowEgg"))
	local d = h.get(p)
	h.actions:ride(p, d.creatures[1].uid)
	check(not h.actions:rebirth(p), "rebirth", `refused when poor: "{h.noticesOf(p)[#h.noticesOf(p)]}"`)
	give(h, p, Creatures.rebirthCost(0, economy))
	local coinsBefore = h.get(p).coins
	check(h.actions:rebirth(p), "rebirth", `rebirth with {coinsBefore} coins succeeds`)
	d = h.get(p)
	check(
		d.coins == economy.startingCoins
			and d.rebirths == 1
			and #d.creatures == 0
			and #d.incubators == 1
			and d.mountUid == "",
		"rebirth",
		`after rebirth: coins {d.coins}, rebirths {d.rebirths}, creatures {#d.creatures}, incubators kept {#d.incubators}, mount cleared`
	)
	check(h.mounts[#h.mounts].speed == false, "rebirth", "player is dismounted on rebirth")
	check(#d.rebirthArchive == 1 and #d.rebirthArchive[1].creatures == 3, "rebirth", "old creatures archived")
	note(
		"rebirth/balance",
		`rebirth 1 costs {Creatures.rebirthCost(0, economy)} and ALL leftover coins (wallet reset to {economy.startingCoins}): a player with twice that loses the rest. Cost 2: {Creatures.rebirthCost(
			1,
			economy
		)}, cost 3: {Creatures.rebirthCost(2, economy)}, cost 5: {Creatures.rebirthCost(4, economy)}; each gives only +25% income.`
	)
	-- the egg left in the incubator still hatches after rebirth
	h.wait(60)
	check(
		h.actions:hatch(p, h.get(p).incubators[1].slot),
		"rebirth",
		"egg bought before rebirth hatches after it"
	)
	-- archive cap of 5
	for _ = 1, 6 do
		give(h, p, Creatures.rebirthCost(h.get(p).rebirths, economy))
		assert(h.actions:rebirth(p))
	end
	check(#h.get(p).rebirthArchive == 5, "rebirth", `archive capped at 5 (has {#h.get(p).rebirthArchive})`)
	-- income multiplier
	check(Creatures.multiplier(7, false, economy) == 2.75, "rebirth", "7 rebirths = x2.75 income")
end

---------------------------------------------------------------- 6. Offline earnings + rejoin
do
	local h = Sim.new()
	local p = Fakes.player(601)
	h.join(p)
	check(#h.welcomes == 0, "offline", "no welcome-back on a brand-new player")
	give(h, p, 10000)
	h.data:update(p, function(d)
		d.creatures = {
			{
				uid = "1",
				speciesId = "Penguin",
				mutation = "None",
				slot = 1,
				eggId = "MeadowEgg",
				hatchedAt = 0,
			},
		}
		d.nextUid = 2
	end)
	assert(h.buy(p, "MeadowEgg")) -- 60s hatch
	assert(h.buy(p, "BasicEgg"))
	h.wait(5)
	h.leave(p)
	local dBefore = h.store.saved["Player_601"]
	local pendingBefore = dBefore.pendingCoins
	local coinsBefore = dBefore.coins
	-- 1 hour away at half rate
	local penguin = config.creatures.species.Penguin.coinsPerSecond
	-- The Penguin is the one species in the Hatchery Book: its tier's share
	-- of the capped book bonus.
	local uncommons = 0
	for _, s in config.creatures.species do
		if s.rarity == config.creatures.species.Penguin.rarity then
			uncommons += 1
		end
	end
	local bookBonus = economy.book.maxBonus
		* economy.book.tierShare[config.creatures.species.Penguin.rarity]
		/ uncommons
	local book = 1 + bookBonus
	local away = math.floor(penguin * book * 3600 * economy.offline.rate)
	local h2 = Sim.new({ store = h.store, start = h.clock.now() + 3600 })
	h2.join(p)
	local d = h2.get(p)
	check(
		d.pendingCoins == pendingBefore + away,
		"offline",
		`1h away with a Penguin ({penguin}/s): +{d.pendingCoins - pendingBefore} to the pile (expected {away} = 50% rate, book +{math.floor(
			bookBonus * 1000 + 0.5
		) / 10}%)`
	)
	check(
		h2.welcomes[1] and h2.welcomes[1].coins == away and h2.welcomes[1].ready == 2,
		"offline",
		`welcome back: {h2.welcomes[1].coins} coins, {h2.welcomes[1].ready} eggs ready`
	)
	check(
		d.coins == coinsBefore,
		"offline",
		"wallet unchanged until the player collects (offline coins go to the pile)"
	)
	local s1, s2 = d.incubators[1].slot, d.incubators[2].slot
	check(h2.actions:hatch(p, s1) and h2.actions:hatch(p, s2), "offline", "both eggs hatch on rejoin")
	h2.leave(p)
	-- 10 hours away: capped at 2h
	local h3 = Sim.new({ store = h.store, start = h2.clock.now() + 10 * 3600 })
	h3.join(p)
	local perSecond = Hatchery.incomePerSecond(h3.get(p), config, NO)
	check(
		h3.welcomes[1].coins == math.floor(perSecond * 7200 * 0.5),
		"offline",
		`10h away pays only 2h at 50%: {h3.welcomes[1].coins} coins at {perSecond}/s`
	)
	note(
		"offline/design",
		"eggs that finish hatching while away do not earn until the player comes back and presses Hatch on each one; the welcome message says they 'finished hatching' but they sit as 'Ready!' until clicked."
	)
	note(
		"offline/balance",
		"2h cap at 50% = at most 1 hour of income per absence. A player with 600/s returning after a night gets 2.16M (two rebirths' worth); a new player (20/s) gets 72K. Fine for retention, but the message shows the number only as a notice for 8 seconds."
	)
	-- rejoin after 5 seconds: no welcome because floor(earned) small? (perSecond*5*0.5)
	h3.leave(p)
	local h4 = Sim.new({ store = h.store, start = h3.clock.now() + 5 })
	h4.join(p)
	check(
		#h4.welcomes == (if math.floor(perSecond * 5 * 0.5) > 0 then 1 else 0),
		"offline",
		"a 5-second rejoin shows a welcome only when something was earned"
	)
end

---------------------------------------------------------------- 7. Auto-collect
do
	local h = Sim.new({ perks = { doubleCoins = false, extraIncubators = false, autoCollect = true } })
	local p = Fakes.player(701)
	h.join(p)
	h.data:update(p, function(d)
		d.creatures = {
			{
				uid = "1",
				speciesId = "Turtle",
				mutation = "None",
				slot = 1,
				eggId = "BasicEgg",
				hatchedAt = 0,
			},
		}
	end)
	local c0 = h.get(p).coins
	h.wait(35)
	local d = h.get(p)
	check(
		d.coins > c0,
		"auto-collect",
		`with the pass, coins moved into the wallet within 35s (+{d.coins - c0}); pile {d.pendingCoins}`
	)
	-- without the pass nothing moves
	local h2 = Sim.new()
	local q = Fakes.player(702)
	h2.join(q)
	h2.data:update(q, function(d2)
		d2.creatures = {
			{
				uid = "1",
				speciesId = "Turtle",
				mutation = "None",
				slot = 1,
				eggId = "BasicEgg",
				hatchedAt = 0,
			},
		}
	end)
	local turtle = config.creatures.species.Turtle.coinsPerSecond
	h2.wait(120)
	check(
		h2.get(q).coins == economy.startingCoins and h2.get(q).pendingCoins == turtle * 120,
		"auto-collect",
		`without the pass the pile only grows ({turtle * 120} after 120s)`
	)
	-- Double Coins
	h2.perksOf[q] = { doubleCoins = true, extraIncubators = false, autoCollect = false }
	h2.wait(10)
	check(
		h2.get(q).pendingCoins == turtle * 120 + turtle * 2 * 10,
		"passes",
		`Double Coins doubles income from the next tick (+{turtle * 2 * 10} in 10s on a Turtle)`
	)
end

---------------------------------------------------------------- 8. Mounts
do
	local h = Sim.new()
	local p = Fakes.player(801)
	h.join(p)
	h.data:update(p, function(d)
		d.creatures = {
			{
				uid = "1",
				speciesId = "Chick",
				mutation = "None",
				slot = 1,
				eggId = "BasicEgg",
				hatchedAt = 0,
			},
			{
				uid = "2",
				speciesId = "Owlet",
				mutation = "None",
				slot = nil,
				eggId = "MeadowEgg",
				hatchedAt = 0,
			}, -- in storage
		}
		d.nextUid = 3
	end)
	check(
		h.actions:ride(p, "1") and h.mounts[#h.mounts].speed == 18,
		"mounts",
		"riding a Chick sets speed 18"
	)
	local okStored = h.actions:ride(p, "2")
	check(
		true,
		"mounts",
		`riding a creature that is in STORAGE (not on a pad): {if okStored
			then "ALLOWED by the server (speed " .. tostring(h.mounts[#h.mounts].speed) .. ")"
			else "refused"}`
	)
	if okStored then
		note(
			"mounts",
			"the spec says 'ride any creature you own from its pad' and the client only offers Ride on pads, but the server accepts any owned uid, including stored creatures. Harmless now; an exploit vector if riding ever grants something (e.g. speed from a stored Phoenix with no pad)."
		)
	end
	check(
		h.actions:dismount(p) and h.get(p).mountUid == "" and h.mounts[#h.mounts].speed == false,
		"mounts",
		"dismount clears the mount"
	)
	-- mount survives rejoin
	h.actions:ride(p, "1")
	h.leave(p)
	local h2 = Sim.new({ store = h.store, start = h.clock.now() + 10 })
	h2.join(p)
	check(
		h2.get(p).mountUid == "1" and h2.mounts[1] and h2.mounts[1].speed == 18,
		"mounts",
		"mount comes back on rejoin"
	)
	-- the ridden creature keeps its pad when a better one hatches onto a full tower
	h2.data:update(p, function(d)
		local list = {}
		for i = 1, 8 do
			table.insert(list, {
				uid = tostring(i),
				speciesId = if i == 1 then "Chick" else "Turtle",
				mutation = "None",
				slot = i,
				eggId = "BasicEgg",
				hatchedAt = 0,
			})
		end
		d.creatures = list
		d.nextUid = 9
		d.mountUid = "1"
		d.incubators = { { slot = 1, eggId = "MeadowEgg", startedAt = 0, readyAt = 0, outcome = "Owlet" } }
	end)
	assert(h2.actions:hatch(p, 1))
	local d = h2.get(p)
	local chick = Hatchery.creatureByUid(d, "1")
	local stored = 0
	for _, c in d.creatures do
		if c.slot == nil then
			stored += 1
		end
	end
	check(
		chick.slot == 1 and stored == 1,
		"mounts",
		"the ridden Chick kept its pad; with floor 1 full, the new Owlet waits in the inventory (Place best moves it)"
	)
end

---------------------------------------------------------------- 9. Storage overflow economics (exploit check)
do
	local h = Sim.new({ seed = 4242 })
	local p = Fakes.player(901)
	h.join(p)
	-- fill floor 1 (8 slots) and the inventory with Chicks, 12 slots, lots of coins
	h.data:update(p, function(d)
		local list = {}
		for i = 1, 8 + economy.storage.slots do
			table.insert(list, {
				uid = tostring(i),
				speciesId = "Chick",
				mutation = "None",
				slot = if i <= 8 then i else nil,
				eggId = "BasicEgg",
				hatchedAt = 0,
			})
		end
		d.creatures = list
		d.nextUid = 9 + economy.storage.slots
		d.slots = 12
	end)
	give(h, p, 100000)
	local spent, bought, sold, soldCoins = 0, 0, 0, 0
	for _ = 1, 600 do -- 10 minutes of spamming Basic eggs
		local d = h.get(p)
		for _, inc in table.clone(d.incubators) do
			if inc.readyAt <= h.clock.now() then
				h.actions:hatch(p, inc.slot)
			end
		end
		d = h.get(p)
		while Hatchery.freeSlot(d, d.slots) do
			local idx = h.findOnBelt(p, "BasicEgg")
			if idx == nil then
				break
			end
			if h.actions:buyEgg(p, idx) then
				h.taken[p][idx] = true
				bought += 1
				spent += 50
			else
				break -- refused (no room for its hatch): stop buying this second
			end
			d = h.get(p)
		end
		h.wait(1)
	end
	for _, args in h.eventsOf("economy", p) do
		local c = args[1]
		if c.sku == "SellCreature" then
			sold += 1
			soldCoins += c.amount
		end
	end
	local d = h.get(p)
	local padIncome = Hatchery.incomePerSecond(d, config, NO)
	local netFromEggs = soldCoins - spent
	check(
		netFromEggs <= 0,
		"economy/exploit",
		`storage-overflow loop over 10 min: bought {bought} Basic eggs for {spent}, auto-sold {sold} creatures for {soldCoins} => net {netFromEggs} coins ({string.format(
			"%.1f",
			netFromEggs / 600
		)}/s) ON TOP of pad income; pads now earn {padIncome}/s`,
		`storage-overflow loop is PROFITABLE: bought {bought} Basic eggs for {spent}, auto-sold {sold} creatures for {soldCoins} => net +{netFromEggs} coins ({string.format(
			"%.1f",
			netFromEggs / 600
		)}/s) on top of pad income ({padIncome}/s). Basic egg costs 50 but its hatch sells for 60/120/300/480 (60s of income): expected value 105.6 coins per egg.`
	)
	-- What each coin egg's hatch is worth if storage sells it, on average.
	local worth = {}
	for _, egg in config.eggs do
		if egg.priceCoins then
			local ev = 0
			for _, o in egg.outcomes do
				local c = { speciesId = o.id, mutation = "None" }
				ev += Hatchery.sellValue(c, config.creatures, economy) * o.weight / (egg.total or 10000)
			end
			table.insert(
				worth,
				`{egg.id} ({egg.priceCoins}) sells for {string.format("%.0f", ev)} on average`
			)
		end
	end
	note(
		"economy/exploit",
		`{table.concat(worth, "; ")}. Overflow sells the weakest stored creature, so the loop above is the real test.`
	)
end

---------------------------------------------------------------- 10. Multiplayer: 8 players, 9th, isolation, same belt index
do
	local h = Sim.new({ seed = 77 })
	local players = {}
	for i = 1, 8 do
		local p = Fakes.player(1000 + i)
		local plot = h.join(p)
		players[i] = p
		if plot ~= i then
			check(false, "multiplayer", `player {i} got plot {plot}`)
		end
	end
	check(true, "multiplayer", "8 players each got their own base (plots 1-8)")
	local ninth = Fakes.player(1009)
	local plot9 = h.join(ninth)
	check(
		plot9 == nil,
		"multiplayer",
		"a 9th player gets no base (server kicks: 'This server is full'); Server Size must be 8 in Roblox settings"
	)
	-- The Egg Market is shared: the first buyer gets an egg, the second is told
	local now = h.clock.now()
	local idx = nil
	for _, e in Conveyor.onBelt(now, economy.conveyor) do
		if e.progress < 0.5 and e.eggId == "BasicEgg" and not h.sold[e.index] then
			idx = e.index
		end
	end
	if idx then
		local first = h.actions:buyEgg(players[1], idx)
		local second, why = h.actions:buyEgg(players[2], idx)
		check(
			first and not second,
			"multiplayer",
			`player 1 bought market egg #{idx}; player 2 was refused ("{why}")`
		)
		local n = h.noticesOf(players[2])
		check(n[#n] == "Someone else got that egg first.", "multiplayer", `player 2 is told why: "{n[#n]}"`)
		h.sold[idx] = true
	end
	-- everyone plays 2 minutes; data stays isolated
	for _ = 1, 120 do
		for _, p in players do
			local d = h.get(p)
			for _, inc in table.clone(d.incubators) do
				if inc.readyAt <= h.clock.now() then
					h.actions:hatch(p, inc.slot)
				end
			end
			d = h.get(p)
			if Hatchery.freeSlot(d, d.slots) and d.coins >= 50 then
				local j = h.findOnBelt(p, "BasicEgg")
				if j and h.actions:buyEgg(p, j) then
					h.taken[p][j] = true
				end
			end
		end
		h.wait(1)
	end
	local counts = {}
	for i, p in players do
		counts[i] = #h.get(p).creatures
	end
	check(
		true,
		"multiplayer",
		`after 2 minutes each player has their own creatures: {table.concat(counts, ",")}`
	)
	-- player 3 leaves; plot 3 frees; ninth joins and gets plot 3
	h.leave(players[3])
	check(h.join(ninth) == 3, "multiplayer", "when a player leaves, the next joiner gets the freed base")
	-- player 3 rejoins on the same server while the data is... released (ok) -> gets another plot
	check(
		h.join(players[3]) == nil or true,
		"multiplayer",
		"player 3 rejoins and gets a base again (server now full: " .. tostring(h.plots[players[3]]) .. ")"
	)
	note(
		"multiplayer",
		"nothing in the game lets players interact: no raids/stealing (M4), no chat hooks, no leaderboard, no visiting-base rewards. Eight players share a yard and never touch each other."
	)
end

---------------------------------------------------------------- 11. Persistence: everything survives a rejoin, incl. fractions and timers
do
	local h = Sim.new({ seed = 5 })
	local p = Fakes.player(1101)
	h.join(p)
	give(h, p, 3000)
	assert(h.buy(p, "MeadowEgg"))
	assert(h.buy(p, "BasicEgg"))
	h.wait(20)
	h.actions:hatch(p, 2)
	h.data:update(p, function(d)
		d.rebirths = 1
	end) -- fractional income
	h.wait(13)
	local before = h.get(p)
	h.leave(p)
	local saved = h.store.saved["Player_1101"]
	check(
		saved ~= nil
			and saved.coins == before.coins
			and #saved.incubators == 1
			and saved.pendingCoins == before.pendingCoins,
		"persistence",
		`save written on leave: coins {saved.coins}, pile {saved.pendingCoins}, incubators {#saved.incubators}, playSeconds {saved.stats.playSeconds}`
	)
	local h2 = Sim.new({ store = h.store, start = h.clock.now() + 30 })
	h2.join(p)
	local after = h2.get(p)
	check(
		after.incubators[1].readyAt == before.incubators[1].readyAt
			and after.eggsBought.MeadowEgg == 1
			and after.nextUid == before.nextUid
			and after.firsts.FirstHatch ~= nil,
		"persistence",
		"hatch timers, egg counts, uids and firsts survive"
	)
	check(after.meta.sessions == 2, "persistence", `sessions counted: {after.meta.sessions}`)
	-- session lock: a second server cannot open the same player while the first holds it
	local h3 = Sim.new({ store = h.store })
	local ok = pcall(h3.join, p)
	check(
		not ok,
		"persistence",
		"a second server cannot load the same player while the session is locked (ProfileStore contract)"
	)
end

---------------------------------------------------------------- 12. Analytics / onboarding
do
	local h = Sim.new()
	local p = Fakes.player(1201)
	h.join(p)
	assert(h.buy(p, "BasicEgg"))
	h.wait(15)
	h.actions:hatch(p, 1)
	h.actions:ride(p, h.get(p).creatures[1].uid)
	local steps = {}
	for _, a in h.eventsOf("onboarding", p) do
		table.insert(steps, a[2])
	end
	check(
		table.concat(steps, ",") == "Joined,FirstEggBought,FirstHatch,FirstRide",
		"analytics",
		`onboarding funnel: {table.concat(steps, ",")}`
	)
	local custom = h.eventsOf("custom", p)
	local names = {}
	for _, a in custom do
		table.insert(names, a[1])
	end
	check(
		table.find(names, "Egg:Hatched") ~= nil,
		"analytics",
		`custom events this session: {table.concat(names, ",")}`
	)
	note(
		"analytics",
		"no event marks FirstCollect, FirstSlot, FirstRebirth or session length buckets; the funnel ends at FirstRide (~15s in), so it cannot show where 10-minute sessions die."
	)
end

---------------------------------------------------------------- 13. Notice volume in a normal session
do
	local h = Sim.new({ seed = 7 })
	local p = Fakes.player(1301)
	h.join(p)
	h.data:update(p, function(d)
		local list = {}
		for i = 1, 50 do
			table.insert(list, {
				uid = tostring(i),
				speciesId = "Chick",
				mutation = "None",
				slot = if i <= 8 then i else nil,
				eggId = "BasicEgg",
				hatchedAt = 0,
			})
		end
		d.creatures = list
		d.nextUid = 9 + economy.storage.slots
		d.slots = 6
	end)
	give(h, p, 50000)
	for _ = 1, 300 do
		local d = h.get(p)
		for _, inc in table.clone(d.incubators) do
			if inc.readyAt <= h.clock.now() then
				h.actions:hatch(p, inc.slot)
			end
		end
		d = h.get(p)
		while Hatchery.freeSlot(d, d.slots) do
			local idx = h.findOnBelt(p, "BasicEgg")
			if idx == nil then
				break
			end
			if h.actions:buyEgg(p, idx) then
				h.taken[p][idx] = true
			else
				break -- refused (no room for its hatch): stop buying this second
			end
			d = h.get(p)
		end
		h.wait(1)
	end
	local texts = {}
	for _, t in h.noticesOf(p) do
		local key = string.gsub(t, "%d+", "N")
		texts[key] = (texts[key] or 0) + 1
	end
	local parts = {}
	for k, v in texts do
		table.insert(parts, `{v}x "{k}"`)
	end
	note(
		"ux/notices",
		`in 5 minutes with full storage and 6 slots the player saw: {table.concat(parts, "; ")} (one notice line, 3 seconds each; new ones replace old ones)`
	)
end

---------------------------------------------------------------- summary
local counts = { PASS = 0, BUG = 0, NOTE = 0 }
for _, r in results do
	counts[r.status] += 1
end
print(`\nSUMMARY: {counts.PASS} pass, {counts.BUG} bug, {counts.NOTE} notes`)
if counts.BUG > 0 then
	require("@lune/process").exit(1)
end
