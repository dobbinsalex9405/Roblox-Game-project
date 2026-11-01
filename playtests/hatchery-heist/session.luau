--!nocheck
-- 15-minute playtest sessions of Hatchery Heist with a bot that plays like a
-- new player: hatch what is ready, collect often, buy the best egg it can,
-- unlock incubators, ride, rebirth when it can. Prints a timeline and metrics.
local Sim = require("./Sim")
local Hatchery = require("../../games/hatchery-heist/src/shared/Hatchery")
local Creatures = require("../../games/hatchery-heist/src/shared/Creatures")

local config = Sim.config
local economy = config.economy
local NO = { doubleCoins = false, extraIncubators = false }

local function fmt(n)
	if math.abs(n) >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif math.abs(n) >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

local function mmss(s)
	return string.format("%d:%02d", s // 60, s % 60)
end

local function bestCreature(d)
	local best = nil
	for _, c in d.creatures do
		if
			c.slot
			and (
				best == nil
				or Hatchery.creatureIncome(c, config.creatures)
					> Hatchery.creatureIncome(best, config.creatures)
			)
		then
			best = c
		end
	end
	return best
end

-- strategy: "greedy" (best affordable egg), "basic" (basic only), "slots" (unlock slots first)
local function play(h, player, seconds, strategy, log)
	local t0 = h.clock.now()
	local milestones = {}
	local timeline = {}
	local idle = 0
	local sinceCollect = 0
	local refusals = 0
	local lastNotices = #h.notices
	local padsFullAt, storageSoldAt, firstRebirthAt = nil, nil, nil
	local rarities = {}
	local function mark(name)
		if milestones[name] == nil then
			milestones[name] = h.clock.now() - t0
		end
	end
	for elapsed = 0, seconds - 1 do
		local d = h.get(player)
		local now = h.clock.now()
		local acted = false
		-- hatch everything ready (a real player walks the row and presses E on each)
		for _, inc in table.clone(d.incubators) do
			if inc.readyAt <= now then
				local ok = h.actions:hatch(player, inc.slot)
				if ok then
					acted = true
					mark("first hatch")
					local sp = config.creatures.species[inc.outcome]
					rarities[sp.rarity] = (rarities[sp.rarity] or 0) + 1
					if sp.rarity == "Rare" then
						mark("first Rare")
					end
					if sp.rarity == "Epic" then
						mark("first Epic")
					end
					if sp.rarity == "Uncommon" then
						mark("first Uncommon")
					end
				end
			end
		end
		d = h.get(player)
		-- ride the best creature
		local best = bestCreature(d)
		if best and d.mountUid ~= best.uid then
			if h.actions:ride(player, best.uid) then
				mark("first ride")
			end
		end
		-- collect every 20s or when the pile is worth it
		local perSecond = Hatchery.incomePerSecond(d, config, NO)
		local pile = Hatchery.pendingAt(d, now, perSecond)
		if sinceCollect >= 20 and pile >= 1 then
			h.actions:collect(player)
			sinceCollect = 0
			acted = true
			mark("first collect")
		end
		d = h.get(player)
		-- rebirth as soon as affordable
		if d.coins >= Creatures.rebirthCost(d.rebirths, economy) then
			if h.actions:rebirth(player) then
				mark("first rebirth")
				firstRebirthAt = firstRebirthAt or (now - t0)
				acted = true
			end
		end
		d = h.get(player)
		-- slots
		local cost = Hatchery.nextSlotCost(d, economy)
		if cost then
			local want = if strategy == "slots" then d.coins >= cost else d.coins >= cost + 2500
			if want and h.actions:buySlot(player) then
				mark("first slot bought")
				acted = true
			end
		end
		d = h.get(player)
		-- eggs
		local bought = 0
		while Hatchery.freeSlot(d, d.slots) and bought < 4 do
			local eggId
			if strategy == "basic" then
				eggId = "BasicEgg"
			else
				eggId = if d.coins >= 2500 then "MeadowEgg" else "BasicEgg"
			end
			local price = Hatchery.eggById(config.eggs, eggId).priceCoins
			if d.coins < price then
				break
			end
			local index = h.findOnBelt(player, eggId)
			if index == nil then
				break -- wait for one to come along
			end
			local ok = h.actions:buyEgg(player, index)
			if ok then
				h.taken[player][index] = true
				bought += 1
				acted = true
				mark("first egg bought")
				if eggId == "MeadowEgg" then
					mark("first Meadow egg")
				end
			else
				break
			end
			d = h.get(player)
		end
		-- idle: nothing to do this second (no coins for an egg while a slot is free, or no slot free and nothing ready)
		local hasFree = Hatchery.freeSlot(d, d.slots) ~= nil
		local anyReady = false
		for _, inc in d.incubators do
			if inc.readyAt <= now + 1 then
				anyReady = true
			end
		end
		if not acted and not anyReady and (not hasFree or d.coins < 50) then
			idle += 1
		end
		-- pads / storage
		local onPads, stored = 0, 0
		for _, c in d.creatures do
			if c.slot then
				onPads += 1
			else
				stored += 1
			end
		end
		if onPads >= economy.creaturePads and padsFullAt == nil then
			padsFullAt = now - t0
			mark("all 20 pads full")
		end
		for i = lastNotices + 1, #h.notices do
			if h.notices[i].player == player then
				refusals += 1
				if string.find(h.notices[i].text, "Storage is full") and storageSoldAt == nil then
					storageSoldAt = now - t0
					mark("first storage auto-sell")
				end
			end
		end
		lastNotices = #h.notices
		if elapsed % 60 == 0 or elapsed == seconds - 1 then
			table.insert(
				timeline,
				string.format(
					"  %5s | coins %8s | +%6s/s | pads %2d | store %2d | slots %2d | busy %2d | rb %d",
					mmss(elapsed),
					fmt(d.coins),
					fmt(perSecond),
					onPads,
					stored,
					d.slots,
					#d.incubators,
					d.rebirths
				)
			)
		end
		h.wait(1)
		sinceCollect += 1
	end
	local d = h.get(player)
	local result = {
		milestones = milestones,
		timeline = timeline,
		idle = idle,
		refusals = refusals,
		rarities = rarities,
		final = d,
		perSecond = Hatchery.incomePerSecond(d, config, NO),
	}
	if log then
		print(table.concat(timeline, "\n"))
		local names = {}
		for name in milestones do
			table.insert(names, name)
		end
		table.sort(names, function(a, b)
			return milestones[a] < milestones[b]
		end)
		for _, name in names do
			print(string.format("  milestone %-24s at %s", name, mmss(milestones[name])))
		end
		local r = {}
		for k, v in rarities do
			table.insert(r, `{k}={v}`)
		end
		table.sort(r)
		print(`  hatched by rarity: {table.concat(r, " ")}`)
		print(
			string.format(
				"  idle seconds (nothing to do): %d of %d (%.0f%%); refusal notices: %d",
				idle,
				seconds,
				idle / seconds * 100,
				refusals
			)
		)
		print(
			string.format(
				"  end: coins %s, income %s/s, creatures %d, slots %d, rebirths %d, eggs bought %s",
				fmt(d.coins),
				fmt(result.perSecond),
				#d.creatures,
				d.slots,
				d.rebirths,
				(function()
					local s = {}
					for k, v in d.eggsBought do
						table.insert(s, `{k}={v}`)
					end
					table.sort(s)
					return table.concat(s, ",")
				end)()
			)
		)
		local rb = Creatures.rebirthCost(d.rebirths, economy)
		if d.rebirths == 0 and result.perSecond > 0 then
			print(
				string.format(
					"  rebirth costs %s; at the final income it is %s away (plus hatching)",
					fmt(rb),
					mmss(math.floor((rb - d.coins) / result.perSecond))
				)
			)
		end
	end
	return result
end

return { play = play, fmt = fmt, mmss = mmss }
