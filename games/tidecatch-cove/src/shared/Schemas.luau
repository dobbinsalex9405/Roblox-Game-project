--!strict
-- Schemas for every file in config/, plus checks that span files (a spot can
-- only catch species that exist, every species can be caught somewhere, and
-- so on).
--
-- Takes the core Schema and Odds modules as arguments because this file runs
-- both in Roblox (server start-up) and in Lune (CI tests), which load the core
-- from different places.

export type Section = { schema: (value: any, path: string) -> (boolean, string?), value: any }

local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

return function(Schema: any, Odds: any)
	local Schemas = {}

	local id = Schema.string({ maxLength = 40, pattern = "^%u%w*$" })
	local rarity = Schema.oneOf(RARITIES)
	local count = Schema.integer({ min = 0 })
	local productId = Schema.integer({ min = 0 })
	local multiplier = Schema.number({ min = 0.01, max = 100 })
	local byRarity = Schema.map(rarity, multiplier)

	local function perRarity(item: any)
		local fields = {}
		for _, r in RARITIES do
			fields[r] = item
		end
		return Schema.record(fields)
	end

	Schemas.species = Schema.check(
		Schema.record({
			species = Schema.map(
				id,
				Schema.check(
					Schema.record({
						rarity = rarity,
						value = Schema.integer({ min = 1 }),
						minKg = Schema.number({ min = 0.01 }),
						maxKg = Schema.number({ min = 0.01 }),
					}),
					function(v: any): (boolean, string?)
						if v.maxKg < v.minKg then
							return false, "maxKg is below minKg"
						end
						return true, nil
					end
				),
				{ maxEntries = 500 }
			),
			sizeValue = Schema.check(
				Schema.record({ min = Schema.number({ min = 0.1 }), max = Schema.number({ min = 0.1 }) }),
				function(v: any): (boolean, string?)
					if v.max < v.min then
						return false, "max is below min"
					end
					return true, nil
				end
			),
			mutations = Schema.map(id, Schema.number({ min = 1 })),
		}),
		function(v: any): (boolean, string?)
			if v.mutations.None ~= 1 then
				return false, "mutations.None must exist and equal 1"
			end
			return true, nil
		end
	)

	Schemas.fishing = Schema.record({
		spots = Schema.array(
			Schema.record({
				id = id,
				minRod = Schema.integer({ min = 1, max = 10 }),
				lowTideOnly = Schema.boolean(),
				outcomes = Schema.array(
					Schema.record({ id = id, weight = Schema.integer({ min = 1 }) }),
					{ minLength = 1 }
				),
			}),
			{ minLength = 1, maxLength = 4 } -- the map has 4 docks
		),
		bait = Schema.array(
			Schema.record({
				id = id,
				priceCoins = count, -- 0 for Robux-only bait (crossCheck)
				stock = Schema.integer({ min = 0, max = 50 }),
				robux = Schema.boolean(),
				rarityMultipliers = byRarity,
			}),
			{ maxLength = 8 }
		),
		rods = Schema.array(
			Schema.record({
				id = id,
				priceCoins = count,
				biteTime = Schema.number({ min = 0.1, max = 2 }),
				zone = Schema.number({ min = 0.1, max = 0.8 }),
				luck = byRarity,
			}),
			{ minLength = 1, maxLength = 10 }
		),
		castReach = Schema.number({ min = 4, max = 60 }),
		castCooldownSeconds = Schema.number({ min = 0.5, max = 30 }),
		biteSeconds = Schema.check(
			Schema.record({ min = Schema.number({ min = 0.5 }), max = Schema.number({ min = 0.5, max = 60 }) }),
			function(v: any): (boolean, string?)
				if v.max < v.min then
					return false, "max is below min"
				end
				return true, nil
			end
		),
		reel = Schema.record({
			hookSeconds = Schema.number({ min = 0.5, max = 10 }),
			reactionSeconds = Schema.number({ min = 0, max = 1 }),
			startProgress = Schema.number({ min = 0.05, max = 0.95 }),
			timeoutSeconds = Schema.number({ min = 5, max = 120 }),
			toleranceSeconds = Schema.number({ min = 0, max = 1 }),
			rarity = perRarity(Schema.record({
				fill = Schema.number({ min = 0.01, max = 5 }),
				drain = Schema.number({ min = 0, max = 5 }),
				fishSpeed = Schema.number({ min = 0, max = 5 }),
			})),
			autoSeconds = Schema.number({ min = 0, max = 30 }),
			autoSuccess = perRarity(Schema.number({ min = 0, max = 1 })),
		}),
		bucketSlots = Schema.integer({ min = 1, max = 100 }),
	})

	Schemas.pools = Schema.check(
		Schema.record({
			startingSlots = Schema.integer({ min = 1, max = 20 }),
			maxSlots = Schema.integer({ min = 1, max = 20 }),
			slotCosts = Schema.array(Schema.integer({ min = 1 })),
			passBonusSlots = count,
			stages = Schema.array(
				Schema.record({ name = id, valueMultiplier = Schema.number({ min = 1 }) }),
				{ minLength = 2, maxLength = 10 }
			),
			stageSeconds = perRarity(Schema.integer({ min = 1, max = 24 * 60 * 60 })),
			feed = Schema.record({
				stageFraction = Schema.number({ min = 0, max = 1 }),
				cooldownSeconds = Schema.integer({ min = 1, max = 3600 }),
			}),
			offline = Schema.record({ maxSeconds = Schema.integer({ min = 0, max = 7 * 24 * 60 * 60 }) }),
		}),
		function(v: any): (boolean, string?)
			if v.maxSlots < v.startingSlots then
				return false, "maxSlots is below startingSlots"
			end
			if #v.slotCosts ~= v.maxSlots - v.startingSlots then
				return false, `slotCosts needs {v.maxSlots - v.startingSlots} entries (one per buyable pool)`
			end
			for i = 2, #v.slotCosts do
				if v.slotCosts[i] < v.slotCosts[i - 1] then
					return false, "slotCosts must not decrease"
				end
			end
			for i = 2, #v.stages do
				if v.stages[i].valueMultiplier < v.stages[i - 1].valueMultiplier then
					return false, "a later stage must not be worth less"
				end
			end
			return true, nil
		end
	)

	Schemas.economy = Schema.record({
		startingCoins = count,
		coinsMax = Schema.integer({ min = 1, max = 2 ^ 53 }),
		startingBait = Schema.map(id, Schema.integer({ min = 1, max = 1000 })),
		restockSeconds = Schema.integer({ min = 60, max = 24 * 60 * 60 }),
	})

	-- Name, Robux price and description of each pass and product on Roblox
	-- (Roblox's limits: names 50 characters, descriptions 1,000). Which items
	-- need one, and the price ladder, are checked by tools/tests/Pricing.spec.
	local listing = Schema.record({
		name = Schema.string({ minLength = 1, maxLength = 50 }),
		robux = Schema.integer({ min = 1 }),
		description = Schema.string({ minLength = 1, maxLength = 1000 }),
	})
	local listings = Schema.record({
		passes = Schema.map(id, listing),
		products = Schema.map(id, listing),
	})

	Schemas.monetization = Schema.record({
		listings = listings,
		passes = Schema.record({
			AutoReel = productId,
			ExtraPools = productId,
			SellMultiplier = productId,
		}),
		products = Schema.record({
			GrowthBoost = Schema.record({ id = productId, stages = Schema.integer({ min = 1, max = 4 }) }),
			RestockSkip = Schema.record({ id = productId }),
			BaitPack = Schema.record({
				id = productId,
				bait = id,
				count = Schema.integer({ min = 1, max = 100 }),
			}),
			MysteryBait = Schema.record({ id = productId }),
		}),
		-- Ids per experience (see packages/core/src/Monetization.luau).
		environments = Schema.optional(
			Schema.map(
				Schema.oneOf({ "dev", "staging", "production" }),
				Schema.record({
					passes = Schema.optional(Schema.map(id, productId)),
					products = Schema.optional(Schema.map(id, productId)),
				})
			)
		),
		mysteryBait = Schema.array(
			Schema.record({
				id = id,
				bait = id,
				count = Schema.integer({ min = 1, max = 100 }),
				weight = Schema.integer({ min = 1 }),
			}),
			{ minLength = 1, maxLength = 12 }
		),
		sellMultiplier = Schema.number({ min = 1, max = 10 }),
	})

	-- Rules that need more than one file. Returns a list of problems.
	function Schemas.crossCheck(config: { [string]: any }): { string }
		local problems = {}
		local species = config.species.species
		local fishing = config.fishing

		local catchable: { [string]: boolean } = {}
		local spotIds: { [string]: boolean } = {}
		for _, spot in fishing.spots do
			if spotIds[spot.id] then
				table.insert(problems, `fishing.spots: {spot.id} is listed twice`)
			end
			spotIds[spot.id] = true
			if fishing.rods[spot.minRod] == nil then
				table.insert(problems, `fishing.spots.{spot.id}: minRod {spot.minRod} is not a rod tier`)
			end
			for _, outcome in spot.outcomes do
				if species[outcome.id] == nil then
					table.insert(problems, `fishing.spots.{spot.id}: catches unknown species {outcome.id}`)
				end
				catchable[outcome.id] = true
			end
			local ok, err = pcall(Odds.validate, { id = spot.id, paid = false, outcomes = spot.outcomes })
			if not ok then
				table.insert(problems, `fishing.spots.{spot.id}: {err}`)
			end
		end
		for speciesId in species do
			if not catchable[speciesId] then
				table.insert(problems, `species.{speciesId} cannot be caught at any spot`)
			end
		end

		local baitIds: { [string]: boolean } = { None = true }
		for _, bait in fishing.bait do
			if baitIds[bait.id] then
				table.insert(
					problems,
					`fishing.bait: {bait.id} is listed twice (or uses the reserved id None)`
				)
			end
			baitIds[bait.id] = true
			-- Robux bait is never sold for coins; coin bait always is.
			if bait.robux and (bait.priceCoins ~= 0 or bait.stock ~= 0) then
				table.insert(problems, `fishing.bait.{bait.id}: Robux bait needs priceCoins 0 and stock 0`)
			elseif not bait.robux and (bait.priceCoins < 1 or bait.stock < 1) then
				table.insert(
					problems,
					`fishing.bait.{bait.id}: coin bait needs a price and stock of at least 1`
				)
			end
		end
		for baitId in config.economy.startingBait do
			if not baitIds[baitId] or baitId == "None" then
				table.insert(problems, `economy.startingBait: unknown bait {baitId}`)
			end
		end

		for i, rod in fishing.rods do
			if i == 1 and rod.priceCoins ~= 0 then
				table.insert(
					problems,
					"fishing.rods: the first rod is everyone's starting rod and must be free"
				)
			end
			local previous = fishing.rods[i - 1]
			if previous and rod.priceCoins < previous.priceCoins then
				table.insert(problems, `fishing.rods.{rod.id}: costs less than the rod before it`)
			end
		end

		-- Robux products only ever give Robux-only bait, so a coin-bait cast
		-- is never a paid roll and a Robux-bait cast always is.
		local function robuxBait(baitId: string, where: string)
			for _, bait in fishing.bait do
				if bait.id == baitId then
					if not bait.robux then
						table.insert(
							problems,
							`{where}: {baitId} is coin bait; products give Robux-only bait`
						)
					end
					return
				end
			end
			table.insert(problems, `{where}: unknown bait {baitId}`)
		end
		local monetization = config.monetization
		robuxBait(monetization.products.BaitPack.bait, "monetization.products.BaitPack")
		local mystery = { id = "MysteryBait", paid = true, outcomes = {} }
		for _, outcome in monetization.mysteryBait do
			robuxBait(outcome.bait, `monetization.mysteryBait.{outcome.id}`)
			table.insert(mystery.outcomes, { id = outcome.id, weight = outcome.weight })
		end
		local okMystery, mysteryProblem = pcall(Odds.validate, mystery)
		if not okMystery then
			table.insert(problems, `monetization.mysteryBait: {mysteryProblem}`)
		end

		local usedIds: { [number]: string } = {}
		for key, product in config.monetization.products do
			if product.id > 0 then
				if usedIds[product.id] then
					table.insert(
						problems,
						`monetization: product id {product.id} used by {usedIds[product.id]} and {key}`
					)
				end
				usedIds[product.id] = key
			end
		end
		return problems
	end

	-- Builds the Config.load input from the raw config modules.
	function Schemas.sections(config: { [string]: any }): { [string]: Section }
		local sections = {}
		for name, value in config do
			local schema = Schemas[name]
			assert(type(schema) == "function", `no schema for config/{name}`)
			sections[name] = { schema = schema, value = value }
		end
		return sections
	end

	return Schemas
end
