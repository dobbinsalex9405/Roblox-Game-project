--!strict
-- System-by-system checks of Tidecatch Cove (PR #7) through its own Harness.
-- Prints [PASS] / [BUG] / [NOTE] lines and a summary. A BUG contradicts
-- SPEC.md or common sense; a NOTE is design feedback or a number worth a look.
--   lune run playtests/tidecatch-cove/checks.luau

local Harness = require("../../games/tidecatch-cove/tests/Harness")
local Fakes = require("../../packages/core/tests/Fakes")
local Log = require("../../packages/core/src/Log")
local Util = require("../../packages/core/src/Util")
local Catch = require("../../games/tidecatch-cove/src/shared/Catch")
local Cove = require("../../games/tidecatch-cove/src/shared/Cove")
local Creatures = require("../../games/tidecatch-cove/src/shared/Creatures")
local Reel = require("../../games/tidecatch-cove/src/shared/Reel")
local Bot = require("./bot")

Log.setSink(function() end)

local config = Harness.config
local fishing = config.fishing
local species = config.species.species
local pools = config.pools
local economy = config.economy
local NONE = Catch.NO_BAIT
local NO_PERKS = { autoReel = false, extraPools = false, sellMultiplier = false }
local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

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
local function check(ok: boolean, msg: string, detail: string?)
	if ok then
		pass(msg)
	else
		bug(msg .. (if detail then " -- " .. detail else ""))
	end
end
local function section(name: string)
	print(`\n## {name}`)
end
local function fmt(n: number): string
	if n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n + 0.5))
end
local function clockStr(seconds: number): string
	return Bot.clockStr(seconds)
end

local function fresh(opts: any?): (any, any)
	local h = Harness.new(opts)
	local p = Fakes.player(1)
	h.join(p)
	return h, p
end
local function lastNotice(h: any): string
	return h.notices[#h.notices] or ""
end
local function give(h: any, p: any, coins: number)
	h.economy:add(p, "coins", coins, "Admin:Test")
end
local function avgCreature(id: string): any
	local def = species[id]
	return { uid = "", speciesId = id, kg = (def.minKg + def.maxKg) / 2, mutation = "None" }
end
local function tinyValue(id: string): number
	return Creatures.value(avgCreature(id), 1, config.species, pools)
end
-- Puts a creature straight into the bucket (as if just caught).
local function inject(h: any, p: any, id: string, kg: number?): string
	local uid = ""
	h.data:update(p, function(d: any)
		uid = tostring(d.nextUid)
		d.nextUid += 1
		local def = species[id]
		table.insert(d.bucket, {
			uid = uid,
			speciesId = id,
			kg = kg or (def.minKg + def.maxKg) / 2,
			mutation = "None",
			caughtAt = math.floor(h.time),
			spotId = "Shallows",
		})
	end)
	return uid
end
-- Casts, waits for the bite, reels at a human pace. Returns the caught record or nil.
local function fishOnce(h: any, p: any, spot: string, bait: string): any?
	local bite = h.castAndWait(p, spot, bait)
	if bite == nil then
		return nil
	end
	h.wait(Reel.minSeconds(bite.rarity, fishing) + 1)
	local before = #h.caught
	h.actions:reel(p, bite.id, true)
	if #h.caught > before then
		return h.caught[#h.caught]
	end
	return nil
end

-- ---------------------------------------------------------------------------
section("Config")
do
	local rodTotal, poolTotal = 0, 0
	for _, rod in fishing.rods do
		rodTotal += rod.priceCoins
	end
	for _, c in pools.slotCosts do
		poolTotal += c
	end
	local coinBaits, robuxBaits = 0, 0
	for _, bait in fishing.bait do
		if bait.robux then
			robuxBaits += 1
			check(bait.priceCoins == 0 and bait.stock == 0, `{bait.id} is Robux-only, so coins never buy it`)
		else
			coinBaits += 1
		end
	end
	check(
		#fishing.rods == 3 and coinBaits == 4 and #fishing.spots == 4,
		`3 rods, 4 coin baits (+{robuxBaits} Robux-only), 4 spots`
	)
	local n = 0
	for _ in species do
		n += 1
	end
	check(n == 25, "25 species")
	note(
		`everything to buy: rods {fmt(rodTotal)}, six extra pools {fmt(poolTotal)}; total {fmt(
			rodTotal + poolTotal
		)}`
	)
	for _, spot in fishing.spots do
		local total = 0
		for _, o in spot.outcomes do
			total += o.weight
		end
		check(total == 10000, `{spot.id} weights total 10,000`)
	end
	-- Expected value per cast, Tiny price, average size, starting rod.
	local h, p = fresh()
	local function ev(spot: string, bait: string): number
		return Bot.expectedValue(h, p, spot, bait)
	end
	local rows = {}
	for _, spot in fishing.spots do
		local parts = { `{spot.id}: none {string.format("%.1f", ev(spot.id, NONE))}` }
		for _, bait in fishing.bait do
			local gain = ev(spot.id, bait.id) - ev(spot.id, NONE)
			table.insert(parts, string.format("%s %+.1f (costs %d)", bait.id, gain, bait.priceCoins))
		end
		table.insert(rows, table.concat(parts, ", "))
	end
	note(
		"expected coins per cast at the Tiny sale price, average size, Driftwood Rod; bait shown as the gain over no bait: "
			.. table.concat(rows, " | ")
	)
	local worm = Catch.bait(fishing, "Worm")
	local gainWorm = ev("Shallows", "Worm") - ev("Shallows", NONE)
	if gainWorm < worm.priceCoins then
		note(
			string.format(
				"a Worm (%d coins) raises the Shallows expected value by only %.1f coins when the catch is sold Tiny: bait loses money for a player who sells catches",
				worm.priceCoins,
				gainWorm
			)
		)
	else
		pass(
			string.format(
				"a Worm (%d coins) raises the Shallows expected value by %.1f coins at Tiny prices: it pays for itself",
				worm.priceCoins,
				gainWorm
			)
		)
	end
	-- Pool income per minute per rarity: Giant value over growth time.
	local parts = {}
	for _, r in RARITIES do
		local sample = nil
		for id, def in species do
			if def.rarity == r and (sample == nil or def.value < species[sample].value) then
				sample = id
			end
		end
		local giant = Creatures.value(avgCreature(sample :: string), 5, config.species, pools)
		local tiny = tinyValue(sample :: string)
		local growth = Creatures.growthSeconds(r, pools)
		-- Feeding every 90 s adds stageSeconds/4 each time.
		local fedPerSecond = 1
			+ (pools.stageSeconds[r] * pools.feed.stageFraction) / pools.feed.cooldownSeconds
		table.insert(
			parts,
			string.format(
				"%s (%s): Tiny %d -> Giant %d in %s, %.1f coins/min per pool; fed every 90 s it grows %.2fx faster (Giant in %s)",
				r,
				sample,
				tiny,
				giant,
				clockStr(growth),
				(giant - tiny) / growth * 60,
				fedPerSecond,
				clockStr(growth / fedPerSecond)
			)
		)
	end
	note("cheapest species per rarity in a pool: " .. table.concat(parts, " | "))
	note(
		"feeding adds a quarter stage per 90 s: for a Common (45 s stages) that is 11 s of growth, nothing; for a Legendary (900 s stages) it is 225 s, so feeding makes a Legendary grow 3.5x faster. Feeding is a rare-fish mechanic and the pool card should say so"
	)
end

-- ---------------------------------------------------------------------------
section("New player")
do
	local h, p = fresh()
	local d = h.get(p)
	check(d.coins == 100 and d.rodTier == 1 and d.poolSlots == 2, "100 coins, Driftwood Rod, 2 pools")
	check(d.bait.Worm == 10, "10 Worms on the first join")
	check(#h.welcomes == 0, "no welcome-back message on a first join")
	local steps = h.eventsOf("onboarding")
	check(#steps == 1 and steps[1][2] == "Joined", "Joined reported")
	h.leave(p)
	local h2 = Harness.new({ store = h.store, start = h.time + 5 })
	h2.join(p)
	check(h2.get(p).bait.Worm == 10, "starting bait is not given again on rejoin")
	check(#h2.eventsOf("onboarding") == 0, "Joined is reported once ever")
	check(#h2.welcomes == 0, "a 5-second hop with nothing grown shows no welcome message")
end

-- ---------------------------------------------------------------------------
section("Casting rules")
do
	local h, p = fresh()
	check(not h.actions:cast(p, "Reef", NONE), "Reef needs the Reef Rod")
	check(
		lastNotice(h) == "You need a Reef Rod or better to fish here.",
		"the refusal names the rod by its display name",
		lastNotice(h)
	)
	check(
		not h.actions:cast(p, "TideFlats", NONE) and lastNotice(h) == "This spot opens at low tide.",
		"Tide Flats closed until M4"
	)
	h.reachable = false
	check(
		not h.actions:cast(p, "Shallows", NONE) and lastNotice(h) == "Walk onto the dock to cast here.",
		"must stand on the dock"
	)
	h.reachable = true
	check(not h.actions:cast(p, "Shallows", "GoldenLure"), "cannot cast bait you do not own")
	check(
		string.find(lastNotice(h), "out of Golden Lure") ~= nil,
		"the bait refusal says which bait, by display name",
		lastNotice(h)
	)
	local ok, why = h.actions:cast(p, "Shallows", "Dynamite")
	check(not ok and why == "unknown bait" and #h.notices == 4, "unknown bait is refused quietly")
	check(h.actions:cast(p, "Shallows", "Worm") == true, "a Worm cast is accepted")
	check(h.get(p).bait.Worm == 9, "the Worm is used at the cast")
	ok, why = h.actions:cast(p, "Shallows", "Worm")
	check(not ok and why == "casting too fast", "1 s cast cooldown")
	h.wait(1)
	local worms = h.get(p).bait.Worm
	ok, why = h.actions:cast(p, "Shallows", "Worm")
	check(
		not ok and why == "your line is already out" and h.get(p).bait.Worm == worms,
		"recasting before the bite is refused and keeps the Worm (fixed in bb323f3)"
	)
	h.wait(fishing.biteSeconds.max + 1)
	check(#h.bites == 1 and h.bites[1].id == 1, "the first line bites")
	ok, why = h.actions:cast(p, "Shallows", NONE)
	check(
		not ok and (why == "a fish is on the line" or why == "your line is already out"),
		"no new cast with a fish on",
		why
	)
	-- Bite delay range.
	local h2, p2 = fresh({ seed = 5 })
	local minDelay, maxDelay = math.huge, 0
	for _ = 1, 30 do
		local t = h2.time
		local bite = h2.castAndWait(p2, "Shallows", NONE)
		local delay = (bite :: any).at - t
		minDelay = math.min(minDelay, delay)
		maxDelay = math.max(maxDelay, delay)
		h2.actions:reel(p2, (bite :: any).id, false)
		h2.wait(1)
	end
	check(
		minDelay >= fishing.biteSeconds.min - 0.3 and maxDelay <= fishing.biteSeconds.max + 0.3,
		string.format("bite comes 3-8 s after the cast (saw %.1f-%.1f)", minDelay, maxDelay)
	)
	note(
		string.format(
			"a cast is %.1f s of waiting on average with the Driftwood Rod (x0.8 Reef Rod, x0.65 Storm Rod), then 2.5-4.5 s of reel and the catch card; about 8.5 s per fish, 7 fish a minute",
			(fishing.biteSeconds.min + fishing.biteSeconds.max) / 2
		)
	)
end

-- ---------------------------------------------------------------------------
section("Bite and odds")
do
	local h, p = fresh({ seed = 11 })
	-- Roll many times with no bait and compare rarity frequencies to the table.
	local tally: { [string]: number } = {}
	local rolls = 600
	for _ = 1, rolls do
		local bite = h.castAndWait(p, "Shallows", NONE) :: any
		tally[bite.rarity] = (tally[bite.rarity] or 0) + 1
		h.actions:reel(p, bite.id, false)
		h.wait(1)
	end
	local expected: { [string]: number } = {}
	for _, row in h.odds:display(Catch.tableId("Shallows", NONE), p).rows do
		local r = species[row.id].rarity
		expected[r] = (expected[r] or 0) + row.weight / 10000
	end
	local worst = 0
	local parts = {}
	for _, r in RARITIES do
		local seen = (tally[r] or 0) / rolls
		local want = expected[r] or 0
		worst = math.max(worst, math.abs(seen - want))
		table.insert(parts, string.format("%s %.1f%% (table %.1f%%)", r, seen * 100, want * 100))
	end
	check(
		worst < 0.05,
		"600 Shallows bites match the odds board by rarity within 5 points: " .. table.concat(parts, ", ")
	)
	check(h.get(p).stats.escapes == rolls, "a reel reported as failed counts as an escape")
	check(#h.customEvents("Fish:Escaped") == rolls, "Fish:Escaped logged with spot and rarity")
	-- Bait and rod change the board and the roll together.
	local plain = h.odds:display(Catch.tableId("Shallows", "Worm"), p)
	check(plain.paid == false, "coin bait is not a paid roll")
	local total = 0
	for _, row in plain.rows do
		total += row.weight
	end
	check(total == 10000, "the Worm table still totals 10,000")
	give(h, p, 20000)
	check(h.actions:buyRod(p, 3) == true, "the Storm Rod can be bought straight from the Driftwood Rod")
	local boosted = h.odds:display(Catch.tableId("KelpForest", "GoldenLure"), p)
	check(boosted.boosts[1] == "StormRod", "the rod shows as a boost on every table")
	total = 0
	local legendary = 0
	for _, row in boosted.rows do
		total += row.weight
		if species[row.id].rarity == "Legendary" then
			legendary += row.weight
		end
	end
	check(total == 10000, "Kelp Forest + Golden Lure + Storm Rod totals 10,000")
	note(
		string.format(
			"Kelp Forest with the Storm Rod and a Golden Lure: %.2f%% Legendary per cast (base 2%%). A 1,000-coin lure for a 1-in-%d shot at a 6,000-coin Tide Leviathan (48,000 as a Giant)",
			legendary / 100,
			math.floor(10000 / legendary)
		)
	)
	-- Every species reachable without the Tide Flats?
	local reachable: { [string]: boolean } = {}
	for _, spot in fishing.spots do
		if not spot.lowTideOnly then
			for _, o in spot.outcomes do
				reachable[o.id] = true
			end
		end
	end
	local missing = {}
	for id in species do
		if not reachable[id] then
			table.insert(missing, id)
		end
	end
	check(
		#missing == 0,
		"all 25 species can be caught before the tide cycle (M4)",
		table.concat(missing, ",")
	)
	-- Paid bait and the policy.
	local f = Util.deepCopy(fishing)
	f.bait[1].robux = true
	local hr, pr = fresh({ restricted = true, fishing = f })
	check(
		not hr.actions:cast(pr, "Shallows", "Worm") and hr.get(pr).bait.Worm == 10,
		"a restricted player cannot cast Robux bait and keeps it"
	)
	local hs, ps = fresh({ sellsCurrency = true })
	check(
		hs.odds:display(Catch.tableId("Shallows", "Worm"), ps).paid == true,
		"if coins were ever sold for Robux, coin bait casts become paid rolls"
	)
end

-- ---------------------------------------------------------------------------
section("Reel")
do
	local h, p = fresh({ seed = 3 })
	local bite = h.castAndWait(p, "Shallows", NONE) :: any
	local minS = Reel.minSeconds(bite.rarity, fishing)
	-- castAndWait polls every 0.25 s, so measure from the bite's own time.
	local function sinceBite(seconds: number)
		h.wait(bite.at + seconds - h.time)
	end
	sinceBite(minS - fishing.reel.toleranceSeconds - 0.1)
	check(
		not h.actions:reel(p, bite.id, true),
		string.format("a %s reel %.2f s after the bite is too fast", bite.rarity, minS - 0.35)
	)
	check(
		#h.customEvents("Fish:ReelTooFast") == 1 and h.get(p).stats.escapes == 1,
		"too fast: logged and counted as an escape"
	)
	check(
		h.escaped[#h.escaped] ~= nil and h.escaped[#h.escaped].text == "It got away!",
		"too fast reads like a normal escape to the player"
	)
	h.wait(1)
	bite = h.castAndWait(p, "Shallows", NONE) :: any
	sinceBite(Reel.minSeconds(bite.rarity, fishing) - fishing.reel.toleranceSeconds + 0.01)
	check(
		h.actions:reel(p, bite.id, true) == true,
		"a reel at the fastest human pace (minus tolerance) is accepted"
	)
	h.wait(1)
	bite = h.castAndWait(p, "Shallows", NONE) :: any
	h.wait(Reel.maxSeconds(fishing) + 0.5)
	local ok, why = h.actions:reel(p, bite.id, true)
	check(not ok, "a reel after the timeout is refused", why)
	if why == "no line" then
		note(
			"a reel result arriving after the timeout gets 'no line' and no escape message, because the 10 s tick may already have forgotten the line; the client has its own timer so the player still sees 'got away'. Fine"
		)
	end
	h.wait(1)
	check(h.actions:cast(p, "Shallows", NONE) == true, "cast again after a forgotten line")
	h.wait(0.5)
	local line = h.actions:line(p)
	ok, why = h.actions:reel(p, (line :: any).id, true)
	check(
		not ok and h.escaped[#h.escaped].text == "Too early! Wait for the bite.",
		"reeling before the bite loses the line"
	)
	note(
		"a reel message before the bite (only possible from a modified client, the hook button appears at the bite) throws the line and its bait away. Harmless"
	)
	for _, r in RARITIES do
		local m = Reel.minSeconds(r, fishing)
		if m > 5 then
			note(string.format("%s minimum reel %.2f s", r, m))
		end
	end
	-- Catch rates by rarity and rod for a human-like player (0.2 s lag), and a slow one (0.35 s).
	local function rate(rarity: string, tier: number, lag: number): (number, number)
		local saved = Bot.REACTION
		Bot.REACTION = lag
		local caught, total = 0, 0
		for seed = 1, 200 do
			local state = seed
			local function random(): number
				state = (state * 48271) % 2147483647
				return (state - 1) / 2147483646
			end
			local ok2, seconds = Bot.playReel(rarity, tier, random)
			if ok2 then
				caught += 1
			end
			total += seconds
		end
		Bot.REACTION = saved
		return caught / 200, total / 200
	end
	local parts = {}
	for _, r in RARITIES do
		local r1, s1 = rate(r, 1, 0.2)
		local r3 = rate(r, 3, 0.2)
		local slow = rate(r, 1, 0.35)
		table.insert(
			parts,
			string.format(
				"%s: Driftwood %.0f%% (%.1f s), Storm %.0f%%, slow player %.0f%%",
				r,
				r1 * 100,
				s1,
				r3 * 100,
				slow * 100
			)
		)
	end
	note("reel catch rate over 200 seeds: " .. table.concat(parts, " | "))
	local common = rate("Common", 1, 0.2)
	local legend = rate("Legendary", 1, 0.2)
	if legend < 0.2 then
		note(
			string.format(
				"a player with 0.2 s reactions lands %.0f%% of Legendaries and %.0f%% of Epics on the Driftwood Rod, and 100%% of both with the Storm Rod: the rod is the real gate, which is good design. But a slower player (0.35 s, a phone) loses almost every Epic and Legendary until the Storm Rod, and a new player's 1-in-1,000 Pearl Whale on the Shallows is lost %.0f%% of the time with no way to know why. Say 'too strong for your rod' on the escape card",
				legend * 100,
				rate("Epic", 1, 0.2) * 100,
				(1 - legend) * 100
			)
		)
	end
	check(common >= 0.95, "Commons are caught at least 95% of the time")
end

-- ---------------------------------------------------------------------------
section("Bucket, selling, journal")
do
	local h, p = fresh({ seed = 21 })
	local c = fishOnce(h, p, "Shallows", NONE) :: any
	check(c ~= nil and #h.get(p).bucket == 1 and c.soldFor == 0, "a catch goes into the bucket")
	local def = species[c.speciesId]
	local expectedValue = Creatures.value(
		{ uid = c.uid, speciesId = c.speciesId, kg = c.kg, mutation = "None" },
		1,
		config.species,
		pools
	)
	local coins = h.get(p).coins
	check(
		h.actions:sellCatch(p, c.uid) == true and h.get(p).coins == coins + expectedValue,
		`selling it pays value x size factor ({expectedValue} for a {string.format("%.2f", c.kg)} kg {c.speciesId}, base {def.value})`
	)
	check(#h.customEvents("Onboarding:FirstSale") == 1, "Onboarding:FirstSale once")
	local j = h.get(p).journal[c.speciesId]
	check(j and j.caught == 1 and j.bestKg == c.kg and c.isNew, "journal: count, best size, new flag")
	check(h.get(p).stats.biggestSpecies == c.speciesId, "biggest catch recorded")
	check(
		not h.actions:sellCatch(p, c.uid) and lastNotice(h) == "That creature is not in your bucket.",
		"selling twice is refused"
	)
	check(
		not h.actions:sellBucket(p) and lastNotice(h) == "Your bucket is empty.",
		"selling an empty bucket is refused"
	)
	-- Size factor extremes.
	local small = inject(h, p, "PearlWhale", 400)
	local big = inject(h, p, "PearlWhale", 1500)
	local before = h.get(p).coins
	h.actions:sellCatch(p, small)
	local smallPaid = h.get(p).coins - before
	before = h.get(p).coins
	h.actions:sellCatch(p, big)
	local bigPaid = h.get(p).coins - before
	check(
		smallPaid == math.floor(4500 * 0.8) and bigPaid == math.floor(4500 * 1.25),
		`smallest Pearl Whale {smallPaid}, largest {bigPaid} (x0.8 to x1.25)`
	)
	-- Sell the bucket.
	for _ = 1, 3 do
		inject(h, p, "SandShrimp")
	end
	before = h.get(p).coins
	check(h.actions:sellBucket(p) == true and #h.get(p).bucket == 0, "Sell all empties the bucket")
	check(string.find(lastNotice(h), "Sold 3 for") ~= nil, "Sell all notice", lastNotice(h))
	-- Full bucket: the next catch sells at once.
	for _ = 1, fishing.bucketSlots do
		inject(h, p, "SandShrimp")
	end
	h.data:update(p, function()
		-- Make the next bite a Legendary by stacking the odds: not possible from outside, so test Cove.land directly.
	end)
	local landed = nil
	h.data:update(p, function(d: any)
		local ledger = h.economy:ledger(p, d)
		landed = Cove.land(
			d,
			ledger,
			{ speciesId = "PearlWhale", kg = 950, mutation = "None", spotId = "Shallows" },
			math.floor(h.time),
			config,
			NO_PERKS
		)
		h.economy:commit(ledger)
	end)
	local l = landed :: any
	check(
		l ~= nil and l.soldFor == 0 and l.madeRoom ~= nil and l.madeRoom.speciesId == "SandShrimp",
		"a full bucket sells the cheapest bucket creature to make room for a better catch (fixed in bb323f3)"
	)
	local whaleKept = Cove.bucketIndex(h.get(p), l.uid) ~= nil
	check(
		whaleKept and #h.get(p).bucket == fishing.bucketSlots,
		"the Pearl Whale is in the bucket and the bucket stays at 12"
	)
	-- A worse catch than everything in the bucket still sells at once.
	local landed2 = nil
	h.data:update(p, function(d: any)
		local ledger = h.economy:ledger(p, d)
		landed2 = Cove.land(
			d,
			ledger,
			{ speciesId = "SandShrimp", kg = 0.1, mutation = "None", spotId = "Shallows" },
			math.floor(h.time),
			config,
			NO_PERKS
		)
		h.economy:commit(ledger)
	end)
	check(
		landed2 ~= nil and (landed2 :: any).soldFor > 0 and (landed2 :: any).madeRoom == nil,
		"a catch worth less than everything in the full bucket sells itself"
	)
	local caught, total = Cove.journalCount(h.get(p), config.species)
	check(
		total == 25 and caught == 3,
		"journal count 3 of 25 (the injected creatures skip the journal; the two landed catches are in)"
	)
end

-- ---------------------------------------------------------------------------
section("Pools: place, grow, feed, sell")
do
	local h, p = fresh()
	local a = inject(h, p, "SandShrimp", 0.25)
	local b = inject(h, p, "PearlWhale", 950)
	local c = inject(h, p, "Lionfish", 1.9)
	check(h.actions:place(p, a) == true and h.get(p).pools[1].slot == 1, "first placement takes pool 1")
	check(h.actions:place(p, b) == true and h.get(p).pools[2].slot == 2, "second takes pool 2")
	check(
		not h.actions:place(p, c) and lastNotice(h) == "Every pool is full. Sell a grown creature first.",
		"third is refused: pools full"
	)
	local steps = {}
	for _, e in h.eventsOf("onboarding") do
		table.insert(steps, e[2])
	end
	check(steps[#steps] == "FirstPlaced", "FirstPlaced reported")
	-- Common growth: 45 s a stage.
	local function stageOf(slot: number): number
		local pooled = Cove.poolAt(h.get(p), slot)
		return Creatures.stage(pooled, math.floor(h.time), config.species, pools)
	end
	h.wait(44)
	check(stageOf(1) == 1, "Sand Shrimp still Tiny at 44 s")
	h.wait(1)
	check(stageOf(1) == 2, "Young at 45 s")
	h.wait(10)
	local marked = false
	for _, e in h.eventsOf("onboarding") do
		if e[2] == "FirstGrowth" then
			marked = true
		end
	end
	check(marked, "FirstGrowth reported by the tick within 10 s of the first stage")
	h.wait(135 - 10)
	check(stageOf(1) == 5, "Giant at 180 s")
	-- Feeding.
	check(
		not h.actions:feed(p, 1) and lastNotice(h) == "It is fully grown. Sell it!",
		"a Giant cannot be fed"
	)
	check(h.actions:feed(p, 2) == true, "feeding the Pearl Whale")
	local whale = Cove.poolAt(h.get(p), 2)
	check(whale.fed == 225, "one feed adds a quarter stage (225 s for a Legendary)")
	check(
		not h.actions:feed(p, 2) and string.find(lastNotice(h), "Not hungry yet") ~= nil,
		"feed cooldown 90 s",
		lastNotice(h)
	)
	check(
		not h.actions:feed(p, 3) and lastNotice(h) == "That pool is empty.",
		"feeding an empty pool is refused"
	)
	-- Sell values by stage.
	local shrimp = Cove.poolAt(h.get(p), 1)
	local tiny = Creatures.value(shrimp, 1, config.species, pools)
	local giant = Creatures.value(shrimp, 5, config.species, pools)
	check(
		giant == math.floor(tiny * 8) or giant == math.floor(4 * 8 * (0.8 + 0.45 * 0.5)),
		`Giant sells for 8x Tiny ({tiny} -> {giant})`
	)
	local coins = h.get(p).coins
	check(h.actions:sellPool(p, 1) == true and h.get(p).coins == coins + giant, "sold from the pool at Giant")
	check(
		string.find(lastNotice(h), "Sold your Giant Sand Shrimp for") ~= nil,
		"pool sale notice names the creature",
		lastNotice(h)
	)
	local sold = h.customEvents("Pool:Sold")
	check(
		#sold == 1 and sold[1][3][1] == "SandShrimp" and sold[1][3][2] == "Giant",
		"Pool:Sold event with species and stage"
	)
	check(
		not h.actions:sellPool(p, 1) and lastNotice(h) == "That pool is empty.",
		"selling an empty pool is refused"
	)
	check(h.actions:place(p, c) == true and Cove.poolAt(h.get(p), 1) ~= nil, "the freed pool 1 is reused")
	-- Legendary growth with and without feeding.
	local whaleNext =
		Creatures.nextStageIn(Cove.poolAt(h.get(p), 2), math.floor(h.time), config.species, pools)
	check(whaleNext ~= nil and whaleNext < 900 - 225, "feeding brought the Pearl Whale's next stage closer")
	note(
		"selling a Tiny creature from a pool pays the same as selling it from the bucket, so a pool is never a trap; but the only way to free a pool is to sell, there is no 'move back to bucket' or 'swap'. A player who pooled two Commons then catches a Rare must sell a pool at a loss of growth to make room"
	)
	-- Buying pools.
	local h2, p2 = fresh()
	give(h2, p2, 1e7)
	local costs = {}
	for i = 3, 8 do
		local before = h2.get(p2).coins
		check(h2.actions:buyPool(p2) == true and h2.get(p2).poolSlots == i, `pool {i} bought`)
		table.insert(costs, before - h2.get(p2).coins)
	end
	check(
		table.concat(costs, ",") == "400,1500,5000,15000,50000,150000",
		"pool prices 400 to 150,000",
		table.concat(costs, ",")
	)
	check(not h2.actions:buyPool(p2) and lastNotice(h2) == "Every pool is unlocked.", "no ninth pool")
	local h3, p3 = fresh({ perks = { autoReel = false, extraPools = true, sellMultiplier = false } })
	for _ = 1, 4 do
		inject(h3, p3, "SandShrimp")
	end
	local placed = 0
	for _, cr in table.clone(h3.get(p3).bucket) do
		if h3.actions:place(p3, cr.uid) then
			placed += 1
		end
	end
	check(placed == 4, "the Extra Pools pass adds 2 pools (4 at the start)")
	local h4, p4 = fresh({ perks = { autoReel = false, extraPools = true, sellMultiplier = false } })
	give(h4, p4, 1e7)
	for _ = 3, 8 do
		h4.actions:buyPool(p4)
	end
	check(
		Cove.poolCount(h4.get(p4), pools, h4.perks) == 10,
		"8 bought + 2 pass = 10 pools, which the map has room for"
	)
end

-- ---------------------------------------------------------------------------
section("Offline, leaving, rejoining")
do
	local h, p = fresh()
	local a = inject(h, p, "PearlWhale", 950) -- 900 s a stage
	local b = inject(h, p, "SandShrimp", 0.25) -- 45 s a stage
	h.actions:place(p, a)
	h.actions:place(p, b)
	h.wait(30)
	local playBefore = h.get(p).stats.playSeconds
	h.leave(p)
	-- Away 10 hours: 3 hours count.
	local away = 10 * 3600
	local h2 = Harness.new({ store = h.store, start = h.time + away })
	h2.join(p)
	local d = h2.get(p)
	local whale = Cove.poolAt(d, 1)
	local shrimp = Cove.poolAt(d, 2)
	local now = math.floor(h2.time)
	local credited = now - whale.placedAt
	check(
		credited == 30 + 3 * 3600,
		`Pearl Whale's timer was credited 30 s online + 3 h of a 10 h absence ({credited} s)`
	)
	check(
		Creatures.stage(whale, now, config.species, pools) == 5,
		"which makes it a Giant (3,600 s of growth)"
	)
	check(Creatures.stage(shrimp, now, config.species, pools) == 5, "the Sand Shrimp is a Giant too")
	check(
		#h2.welcomes == 1 and h2.welcomes[1].grew == 2 and h2.welcomes[1].restocked == true,
		"welcome back: 2 grew, shop restocked"
	)
	check(h2.get(p).stats.playSeconds == playBefore, "offline time is not play time")
	note(
		"the offline cap (3 h) is longer than any creature needs (a Legendary is Giant in 1 h unfed), so every return after an hour finds every pool at Giant: a clean 'come back and cash out' hook. The welcome message says how many grew but not what the pools are now worth; add the total"
	)
	h2.wait(10)
	-- A second absence counts again.
	h2.leave(p)
	local h3 = Harness.new({ store = h2.store, start = h2.time + 3600 })
	h3.join(p)
	check(
		#h3.welcomes == 1 and h3.welcomes[1].grew == 0 and h3.welcomes[1].restocked == true,
		"nothing new grew (all Giant), but the shop restocked, so the welcome message still shows"
	)
	note(
		"the welcome-back message fires whenever an absence crosses a 10-minute restock mark, even a 2-minute hop at :09, saying only 'the shop restocked'. Reserve the toast for growth, or add a cheap daily-return reward so it is worth reading"
	)
	-- Session lock.
	local h4 = Harness.new({ store = h3.store, start = h3.time + 1 })
	local okLoad = pcall(function()
		h4.join(p)
	end)
	check(not okLoad, "a second server cannot load a player who is still in the first")
	-- Leaving mid-cast loses the line, not the save.
	local h5, p5 = fresh({ seed = 2 })
	h5.actions:cast(p5, "Shallows", "Worm")
	local worms = h5.get(p5).bait.Worm
	h5.leave(p5)
	local h6 = Harness.new({ store = h5.store, start = h5.time + 20 })
	h6.join(p5)
	check(
		h6.get(p5).bait.Worm == worms and h6.actions:line(p5) == nil,
		"leaving mid-cast: the Worm is gone, the line is gone, the save is fine"
	)
end

-- ---------------------------------------------------------------------------
section("Shop: rods and bait")
do
	local h, p = fresh()
	check(
		not h.actions:buyRod(p, 2) and lastNotice(h) == "Not enough coins.",
		"Reef Rod at 100 coins is refused"
	)
	give(h, p, 1500)
	check(
		h.actions:buyRod(p, 2) == true and h.get(p).coins == 100 and h.get(p).rodTier == 2,
		"Reef Rod costs 1,500"
	)
	check(lastNotice(h) == "You bought the Reef Rod!", "rod notice", lastNotice(h))
	check(
		not h.actions:buyRod(p, 2) and lastNotice(h) == "You already have a rod at least this good.",
		"no second Reef Rod"
	)
	check(not h.actions:buyRod(p, 1), "cannot buy a worse rod")
	local prog = h.eventsOf("progression")
	check(#prog == 1 and prog[1][1] == "Rod" and prog[1][3] == 2, "Rod progression reported")
	check(h.actions:cast(p, "Reef", NONE) == true, "the Reef opens with the Reef Rod")
	-- Bait stock per restock window.
	local h2, p2 = fresh({ start = 1_800_000_000 })
	give(h2, p2, 1e6)
	check(h2.actions:buyBait(p2, "Worm", 40) == true and h2.get(p2).bait.Worm == 50, "40 Worms per restock")
	check(
		not h2.actions:buyBait(p2, "Worm", 1) and lastNotice(h2) == "Sold out until the next restock.",
		"the 41st is sold out"
	)
	check(h2.actions:buyBait(p2, "GoldenLure", 2) == true, "2 Golden Lures per restock")
	check(not h2.actions:buyBait(p2, "GoldenLure", 1), "a third is sold out")
	local ok, why = h2.actions:buyBait(p2, "Worm", 0)
	check(not ok and why == "invalid amount", "count 0 refused")
	ok, why = h2.actions:buyBait(p2, "Worm", 1.5)
	check(not ok and why == "invalid amount", "count 1.5 refused")
	ok, why = h2.actions:buyBait(p2, "Worm", -3)
	check(not ok and why == "invalid amount", "negative count refused")
	local toWindow = economy.restockSeconds - (math.floor(h2.time) % economy.restockSeconds)
	h2.wait(toWindow)
	check(h2.actions:buyBait(p2, "Worm", 40) == true, "stock is back at the next 10-minute mark")
	note(
		"the restock runs on the wall clock (every 10 minutes at :00, :10, :20...), the same in every server, so a player who joins at :09 gets a second batch a minute later. Fine, but the shop should show the countdown"
	)
	local h3, p3 = fresh({ store = Fakes.store(), start = h2.time })
	give(h3, p3, 1000)
	check(h3.actions:buyBait(p3, "Worm", 40) == true, "stock is per player, not per server")
	-- Affordability message.
	local h4, p4 = fresh()
	check(
		not h4.actions:buyBait(p4, "GoldenLure", 1) and lastNotice(h4) == "Not enough coins.",
		"Golden Lure at 100 coins is refused"
	)
	local wormPrice = Catch.bait(fishing, "Worm").priceCoins
	check(
		h4.actions:buyBait(p4, "Worm", 10) == true and h4.get(p4).coins == 100 - 10 * wormPrice,
		`10 Worms cost {10 * wormPrice} of the 100 starting coins`
	)
	local priceList = {}
	for _, bt in fishing.bait do
		table.insert(priceList, `{bt.id} {bt.priceCoins}`)
	end
	note(
		"bait prices: "
			.. table.concat(priceList, ", ")
			.. "; the expected-value table above says whether each pays back at Tiny prices on the spot it suits"
	)
end

-- ---------------------------------------------------------------------------
section("Onboarding and analytics")
do
	local h, p = fresh({ seed = 8 })
	-- Sell first, then place: FirstSale is a custom event, so order cannot drop a step.
	local c = fishOnce(h, p, "Shallows", "Worm") :: any
	h.actions:sellCatch(p, c.uid)
	local c2 = fishOnce(h, p, "Shallows", "Worm") :: any
	h.actions:place(p, c2.uid)
	h.wait(200)
	local steps = {}
	for _, e in h.eventsOf("onboarding") do
		table.insert(steps, e[2])
	end
	check(
		table.concat(steps, ",") == "Joined,FirstCast,FirstCatch,FirstPlaced,FirstGrowth",
		"funnel: Joined, FirstCast, FirstCatch, FirstPlaced, FirstGrowth in order",
		table.concat(steps, ",")
	)
	note(
		"the funnel steps can only happen in this order (a catch needs a cast, a placement needs a catch, growth needs a placement), so the core's increasing-step rule cannot drop one here, unlike SFE and Depthbound. Good design"
	)
	check(#h.customEvents("Onboarding:FirstSale") == 1, "FirstSale as a custom event, once")
	local caught = h.customEvents("Fish:Caught")
	check(#caught == 2 and caught[1][3][1] == "Shallows", "Fish:Caught with spot and species")
	local names = {}
	for _, args in h.eventsOf("custom") do
		names[args[1]] = (names[args[1]] or 0) + 1
	end
	local list = {}
	for n, k in names do
		table.insert(list, `{n} x{k}`)
	end
	table.sort(list)
	note("custom events seen: " .. table.concat(list, ", "))
	note(
		"nothing marks the first rod, the first pool bought, the first Rare, or a journal milestone; the 10-minute gate wants a step near minute 5-10 (Pool 3 at 5-7 min or the first Rare, both in the keeper sessions). The Rod progression event covers the Reef Rod at 10-15 min"
	)
end

-- ---------------------------------------------------------------------------
section("Passes")
do
	local h, p = fresh({ perks = { autoReel = false, extraPools = false, sellMultiplier = true } })
	local a = inject(h, p, "SandShrimp", 0.25)
	local base = Creatures.value(h.get(p).bucket[1], 1, config.species, pools)
	local coins = h.get(p).coins
	h.actions:sellCatch(p, a)
	check(h.get(p).coins - coins == base * 2, "Sell Multiplier doubles a bucket sale")
	local b = inject(h, p, "SandShrimp", 0.25)
	h.actions:place(p, b)
	h.wait(180)
	coins = h.get(p).coins
	h.actions:sellPool(p, 1)
	check(h.get(p).coins - coins == base * 8 * 2, "and a pool sale at Giant (x8 x2)")
	note(
		"Sell Multiplier is a flat x2 on every coin the game pays: with Extra Pools the 15-minute keeper ends with 4,192 coins against 67 (after the same Reef Rod); price it as the big pass. Auto-reel is not wired yet (perk exists, nothing reads it)"
	)
end

-- ---------------------------------------------------------------------------
section("Numbers worth a look")
do
	local h, p = fresh()
	for tier = 1, 3 do
		h.data:update(p, function(d: any)
			d.rodTier = tier
		end)
		h.actions:refreshOdds(p)
		local best = nil
		for _, spot in fishing.spots do
			if not spot.lowTideOnly and tier >= spot.minRod then
				best = spot.id
			end
		end
		local ev = Bot.expectedValue(h, p, best :: string, NONE)
		local wait = (fishing.biteSeconds.min + fishing.biteSeconds.max) / 2 * fishing.rods[tier].biteTime
		local cycle = wait + 3.5 + 1
		note(
			string.format(
				"%s at %s: %.1f coins a cast sold Tiny, %.1f s a cast, %.0f coins a minute selling everything",
				fishing.rods[tier].id,
				best,
				ev,
				cycle,
				ev * 60 / cycle
			)
		)
	end
	note(
		"Reef Rod (1,500) is about 15 minutes of selling everything with the Driftwood Rod; Storm Rod (15,000) about 25 more minutes with the Reef Rod. Pools roughly double income from minute 20 (2-hour keeper: 647K from pools vs 84K from fish)"
	)
	note(
		string.format(
			"walking: dock to cove and back about %d s, dock to shop and back %d s (grey-box Layout: docks at 58 studs, coves at 160, 16 studs/s). The 15-minute keeper spent 237 s walking, a quarter of the session; the seller 0 s. Pools punish exactly the player who uses them; a 'Sell' and 'Feed' button on the HUD pool list (Place already is) would remove most trips",
			Bot.COVE_TRIP,
			Bot.SHOP_TRIP
		)
	)
end

print(`\n{counts.pass} pass, {counts.bug} bug, {counts.note} notes`)
if counts.bug > 0 then
	require("@lune/process").exit(1)
end
