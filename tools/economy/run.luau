--!strict
-- Prints Hatchery Heist's progression tables from tools/economy/sim.luau.
--
--   lune run tools/economy/run                        every profile, 14 days, 60 runs each
--   lune run tools/economy/run --runs 200 --days 7
--   lune run tools/economy/run --profile grinder
--   lune run tools/economy/run --patch tools/economy/proposals/nov7   try a config change first
--   lune run tools/economy/run --json out.json         also write every number as JSON
--   lune run tools/economy/run --shop                  eggs from an always-stocked shop, not only the belt
--   lune run tools/economy/run --values                only the price-per-rarity table
--
-- A patch is a module returning function(config) that changes the raw config
-- tables ({ economy, creatures, eggs }) before eggs are expanded, so a change
-- can be tried here before it is written into config/.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Sim = require("./sim")

local args = process.args
local opts: { [string]: string } = {}
local i = 1
while i <= #args do
	local key = string.match(args[i], "^%-%-(.+)$")
	if key then
		local value = args[i + 1]
		if value == nil or string.sub(value, 1, 2) == "--" then
			opts[key] = "true" -- a flag
			i += 1
		else
			opts[key] = value
			i += 2
		end
	else
		i += 1
	end
end

local runs = tonumber(opts.runs) or 60
local days = tonumber(opts.days) or 14
local patch = nil
if opts.patch then
	local path = opts.patch
	if string.sub(path, 1, 1) ~= "." and string.sub(path, 1, 1) ~= "/" then
		path = "../../" .. path
	end
	patch = (require :: any)(path)
end
local config = Sim.loadConfig(patch)
if opts.shop then
	Sim.MARKET.shop = true
end

-- What each rarity costs from each egg: the coins spent on average for one
-- creature of that tier, its income, and how long it takes to pay that back
-- on floor 1 and on a fully upgraded floor 10.
local function valuesTable(): ({ string }, { any })
	local rows, data = {}, {}
	local top = 1 + config.economy.tower.floorBonus * 9
	table.insert(
		rows,
		"| Egg | Price | Tier | Chance | 1 in | Coins per creature | Income/s (avg) | Per spot | Pays back on floor 1 | on floor 10 |"
	)
	table.insert(rows, "| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
	for _, egg in config.expanded do
		local total = 0
		for _, o in egg.outcomes do
			total += o.weight
		end
		for _, rarity in Sim.RARITIES do
			local w, incomeSum = 0, 0
			for _, o in egg.outcomes do
				local sp = config.creatures.species[o.id]
				if sp.rarity == rarity then
					w += o.weight
					incomeSum += o.weight * sp.coinsPerSecond
				end
			end
			if w > 0 then
				local chance = w / total
				local avg = incomeSum / w
				local size = config.economy.tower.slotsByRarity[rarity] or 1
				local price = egg.priceCoins
				local per = if price then price / chance else nil
				table.insert(data, {
					egg = egg.id,
					price = price,
					robuxProduct = egg.productKey,
					tier = rarity,
					chance = chance,
					oneIn = 1 / chance,
					coinsPer = per,
					income = avg,
					perSpot = avg / size,
					payback1 = if per then per / avg else nil,
					payback10 = if per then per / (avg * top) else nil,
				})
				local function dur(sec: number?): string
					if sec == nil then
						return "Robux"
					end
					if sec < 3600 then
						return string.format("%d min", math.floor(sec / 60 + 0.5))
					end
					return string.format("%.1f h", sec / 3600)
				end
				table.insert(
					rows,
					`| {egg.id} | {if price then tostring(price) else "Robux"} | {rarity} | {string.format(
						"%.4g%%",
						chance * 100
					)} | {string.format("%.0f", 1 / chance)} | {if per
						then string.format("%.0f", per)
						else "-"} | {string.format("%.0f", avg)} | {string.format("%.0f", avg / size)} | {dur(
						if per then per / avg else nil
					)} | {dur(if per then per / (avg * top) else nil)} |`
				)
			end
		end
	end
	return rows, data
end

if opts.values then
	print(table.concat((valuesTable()), "\n"))
	process.exit(0)
end

local MILESTONES = {}
for _, r in Sim.RARITIES do
	table.insert(MILESTONES, "first " .. r)
end
for n = 4, 14 do
	table.insert(MILESTONES, `incubator {n}`)
end
for f = 2, 10 do
	table.insert(MILESTONES, `floor {f}`)
end
for r = 1, 3 do
	table.insert(MILESTONES, `rebirth {r}`)
end

local function fmtMinutes(m: number): string
	if m == math.huge then
		return "not reached"
	end
	if m < 90 then
		return string.format("%d min", math.floor(m + 0.5))
	end
	return string.format("%.1f h", m / 60)
end

local function short(n: number): string
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.0fK", n / 1e3)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return string.format("%.0f", n)
end

local _valueRows, valueData = valuesTable()
local report = {
	runs = runs,
	days = days,
	patch = opts.patch,
	shop = opts.shop ~= nil,
	profiles = {},
	values = valueData,
}
local lines = {}
local function out(s: string)
	table.insert(lines, s)
end

local wanted = opts.profile
for _, profile in Sim.PROFILES do
	if wanted and wanted ~= profile.name then
		continue
	end
	local results = Sim.batch(config, profile, days, runs)
	local entry = { name = profile.name, label = profile.label, milestones = {}, days = {} }
	out(`## {profile.label}`)
	out("")
	out(`{runs} runs, {days} days.`)
	out("")
	out("| Milestone | Reached by | Median play time | Median day | Fast 10% | Slow 10% |")
	out("| --- | ---: | ---: | ---: | ---: | ---: |")
	for _, name in MILESTONES do
		local minutes, dayList, reached = {}, {}, 0
		for _, r in results do
			local m = r.milestones[name]
			if m then
				reached += 1
				table.insert(minutes, m.minutes)
				table.insert(dayList, m.day)
			else
				table.insert(minutes, math.huge)
				table.insert(dayList, math.huge)
			end
		end
		if reached == 0 then
			continue
		end
		local med, p10, p90 =
			Sim.quantile(minutes, 0.5), Sim.quantile(minutes, 0.1), Sim.quantile(minutes, 0.9)
		local medDay = Sim.quantile(dayList, 0.5)
		table.insert(entry.milestones, {
			name = name,
			reached = reached / runs,
			median = if med == math.huge then nil else med,
			p10 = if p10 == math.huge then nil else p10,
			p90 = if p90 == math.huge then nil else p90,
			day = if medDay == math.huge then nil else medDay,
		})
		out(
			`| {name} | {math.floor(reached / runs * 100 + 0.5)}% | {fmtMinutes(med)} | {if medDay
					== math.huge
				then "-"
				else tostring(medDay)} | {fmtMinutes(p10)} | {fmtMinutes(p90)} |`
		)
	end
	out("")
	out(
		"| End of day | Play time | Income/s | Coins/min | Floors | Upgrades | Incubators | Rebirths | Best tier (most runs) | Book |"
	)
	out("| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |")
	for dayIndex = 1, days do
		local incomes, floors, ups, incs, rebs, found = {}, {}, {}, {}, {}, {}
		local tiers: { [string]: number } = {}
		local eggs: { [string]: { number } } = {}
		local minutes = 0
		local total = 0
		for _, r in results do
			local s = r.days[dayIndex]
			table.insert(incomes, s.income)
			table.insert(floors, s.floors)
			table.insert(ups, s.upgrades)
			table.insert(incs, s.incubators)
			table.insert(rebs, s.rebirths)
			table.insert(found, s.bookFound)
			tiers[s.bestTier] = (tiers[s.bestTier] or 0) + 1
			for id, n in s.eggs do
				eggs[id] = eggs[id] or {}
				table.insert(eggs[id], n)
			end
			minutes = s.minutes
			total = s.bookTotal
		end
		local topTier, topCount = "-", 0
		for t, n in tiers do
			if n > topCount then
				topTier, topCount = t, n
			end
		end
		local eggMedians = {}
		for id, list in eggs do
			eggMedians[id] = Sim.quantile(list, 0.5)
		end
		local row = {
			day = dayIndex,
			minutes = minutes,
			income = Sim.quantile(incomes, 0.5),
			incomeP10 = Sim.quantile(incomes, 0.1),
			incomeP90 = Sim.quantile(incomes, 0.9),
			floors = Sim.quantile(floors, 0.5),
			upgrades = Sim.quantile(ups, 0.5),
			incubators = Sim.quantile(incs, 0.5),
			rebirths = Sim.quantile(rebs, 0.5),
			bestTier = topTier,
			bestTierShare = topCount / runs,
			bookFound = Sim.quantile(found, 0.5),
			bookTotal = total,
			eggs = eggMedians,
		}
		table.insert(entry.days, row)
		if dayIndex == 1 or dayIndex == 2 or dayIndex == 3 or dayIndex == 7 or dayIndex == days then
			out(
				`| {dayIndex} | {fmtMinutes(minutes)} | {short(row.income)} | {short(row.income * 60)} | {row.floors} | {row.upgrades} | {row.incubators} | {row.rebirths} | {topTier} ({math.floor(
					topCount / runs * 100 + 0.5
				)}%) | {row.bookFound}/{total} |`
			)
		end
	end
	out("")
	table.insert(report.profiles, entry)
end

print(table.concat(lines, "\n"))
if opts.json then
	fs.writeFile(opts.json, serde.encode("json", report, true))
end
