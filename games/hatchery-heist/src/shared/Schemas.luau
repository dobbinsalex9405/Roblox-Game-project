--!strict
-- Schemas for every file in config/, plus checks that span files (an egg can
-- only hatch species that exist, a paid egg needs a product, and so on).
--
-- Takes the core Schema module as an argument because this file runs both in
-- Roblox (server start-up) and in Lune (CI tests), which load the core from
-- different places.

export type Section = { schema: (value: any, path: string) -> (boolean, string?), value: any }

return function(Schema: any, Odds: any)
	local Schemas = {}

	local id = Schema.string({ maxLength = 50, pattern = "^%u%w*$" })
	local positive = Schema.number({ min = 0 })
	local count = Schema.integer({ min = 0 })
	local productId = Schema.integer({ min = 0 })

	Schemas.economy = Schema.record({
		startingCoins = count,
		coinsMax = Schema.integer({ min = 1, max = 2 ^ 53 }),
		incubators = Schema.check(
			Schema.record({
				startingSlots = Schema.integer({ min = 1, max = 50 }),
				maxSlots = Schema.integer({ min = 1, max = 50 }),
				slotCosts = Schema.array(Schema.integer({ min = 1 })),
				passBonusSlots = count,
			}),
			function(v: any): (boolean, string?)
				if v.maxSlots < v.startingSlots then
					return false, "maxSlots is below startingSlots"
				end
				if #v.slotCosts ~= v.maxSlots - v.startingSlots then
					return false,
						`slotCosts needs {v.maxSlots - v.startingSlots} entries (one per buyable slot)`
				end
				for i = 2, #v.slotCosts do
					if v.slotCosts[i] < v.slotCosts[i - 1] then
						return false, "slotCosts must not decrease"
					end
				end
				return true, nil
			end
		),
		rebirth = Schema.record({
			baseCost = Schema.integer({ min = 1 }),
			costGrowth = Schema.number({ min = 1 }),
			incomeBonusPerRebirth = positive,
		}),
		conveyor = Schema.record({
			spawnSeconds = Schema.number({ min = 0.25, max = 60 }),
			travelSeconds = Schema.number({ min = 2, max = 120 }),
			lanes = Schema.integer({ min = 1, max = 2 }),
			buyReach = Schema.number({ min = 10, max = 60 }),
			signSeconds = Schema.number({ min = 1, max = 30 }),
			weights = Schema.map(id, Schema.integer({ min = 1 })),
		}),
		tower = Schema.record({
			floorPrices = Schema.array(Schema.integer({ min = 1 }), { minLength = 9, maxLength = 9 }),
			floorBonus = Schema.number({ min = 0, max = 1 }),
			startBonus = Schema.number({ min = 0, max = 1 }),
			upgradeBonus = Schema.number({ min = 0, max = 1 }),
			upgradeShares = Schema.array(
				Schema.number({ min = 0, max = 10 }),
				{ minLength = 4, maxLength = 4 }
			),
			slotsByRarity = Schema.map(
				Schema.string({ maxLength = 20 }),
				Schema.integer({ min = 1, max = 4 })
			),
			themes = Schema.array(Schema.string({ maxLength = 40 }), { minLength = 10, maxLength = 10 }),
		}),
		storage = Schema.record({
			slots = Schema.integer({ min = 0, max = 200 }),
			sellSeconds = Schema.number({ min = 0, max = 3600 }),
		}),
		autoCollectSeconds = Schema.integer({ min = 1, max = 3600 }),
		doubleCoinsMultiplier = Schema.number({ min = 1, max = 10 }),
		daily = Schema.record({
			rewards = Schema.array(
				Schema.record({
					incomeSeconds = Schema.integer({ min = 0, max = 86400 }),
					minCoins = Schema.integer({ min = 1 }),
					maxCoins = Schema.integer({ min = 1 }),
				}),
				{ minLength = 1, maxLength = 14 }
			),
		}),
		book = Schema.record({
			maxBonus = Schema.number({ min = 0, max = 1 }),
			tierShare = Schema.map(Schema.string({ maxLength = 20 }), Schema.number({ min = 0, max = 1 })),
		}),
		offline = Schema.record({
			rate = Schema.number({ min = 0, max = 1 }),
			maxSeconds = Schema.integer({ min = 0, max = 24 * 60 * 60 }),
		}),
	})

	Schemas.creatures = Schema.check(
		Schema.record({
			species = Schema.map(
				id,
				Schema.record({
					rarity = Schema.oneOf({
						"Common",
						"Uncommon",
						"Rare",
						"Ultra Rare",
						"Epic",
						"Legendary",
						"Godly",
					}),
					coinsPerSecond = Schema.number({ min = 0 }),
					mountSpeed = Schema.number({ min = 16, max = 60 }),
					-- The eggs' pools it hatches from, its share inside its
					-- tier (1 when left out), and its element (no effect yet).
					pools = Schema.array(id, { minLength = 1 }),
					weight = Schema.optional(Schema.number({ min = 0.01, max = 100 })),
					element = Schema.optional(
						Schema.oneOf({ "Ember", "Glacial", "Nature", "Storm", "Celestial" })
					),
				}),
				{ maxEntries = 2000 }
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

	Schemas.eggs = Schema.array(
		Schema.record({
			id = id,
			priceCoins = Schema.optional(Schema.integer({ min = 1 })),
			productKey = Schema.optional(id),
			hatchSeconds = Schema.integer({ min = 0, max = 24 * 60 * 60 }),
			-- What the weights add up to (a power of ten; 10,000 when left out).
			total = Schema.optional(Schema.integer({ min = 100, max = 10000000 })),
			-- The pool its creatures come from, and each tier's whole weight.
			pool = id,
			tiers = Schema.map(
				Schema.oneOf({ "Common", "Uncommon", "Rare", "Ultra Rare", "Epic", "Legendary", "Godly" }),
				Schema.integer({ min = 1 })
			),
			-- One weight per creature, made from tiers by Eggs.expand.
			outcomes = Schema.array(
				Schema.record({ id = id, weight = Schema.integer({ min = 1 }) }),
				{ minLength = 1 }
			),
		}),
		{ minLength = 1 }
	)

	local seconds = Schema.number({ min = 0, max = 3600 })
	Schemas.raids = Schema.record({
		newPlayerProtectionSeconds = count,
		perOwnerCooldownSeconds = count,
		pickupReach = Schema.number({ min = 1, max = 50 }),
		carryWalkSpeed = Schema.number({ min = 1, max = 32 }),
		carryMountFactor = Schema.number({ min = 0.1, max = 1 }),
		carrySpeedTolerance = Schema.number({ min = 1, max = 3 }),
		maxCarried = Schema.integer({ min = 1, max = 1 }),
		maxCarrySeconds = Schema.integer({ min = 5, max = 600 }),
		ownerCatchReach = Schema.number({ min = 1, max = 30 }),
		guardCatchReach = Schema.number({ min = 1, max = 30 }),
		guardSightRange = Schema.number({ min = 1, max = 100 }),
		guardSpeedFactor = Schema.number({ min = 0.1, max = 2 }),
		freeShieldSeconds = count,
		shieldCooldownSeconds = count,
		shieldSeconds = count,
		trapPrompt = Schema.record({
			reach = Schema.number({ min = 1, max = 20 }),
			holdSeconds = Schema.number({ min = 0, max = 5 }),
		}),
		traps = Schema.record({
			Snare = Schema.record({
				price = Schema.integer({ min = 1 }),
				stunSeconds = seconds,
				rearmSeconds = seconds,
			}),
			Slime = Schema.record({
				price = Schema.integer({ min = 1 }),
				slowFactor = Schema.number({ min = 0.05, max = 1 }),
				slowSeconds = seconds,
				rearmSeconds = seconds,
			}),
		}),
		decoy = Schema.record({
			price = Schema.integer({ min = 1 }),
			stunSeconds = seconds,
		}),
	})

	local channel = Schema.integer({ min = 0, max = 255 })
	local rgb = Schema.array(channel, { minLength = 3, maxLength = 3 })
	local unit = Schema.number({ min = 0, max = 1 })
	local farmSpot = Schema.record({
		angle = Schema.number({ min = 0, max = 360 }),
		radius = Schema.number({ min = 150, max = 260 }),
	})
	Schemas.atmosphere = Schema.record({
		lighting = Schema.record({
			clockTime = Schema.number({ min = 0, max = 24 }),
			geographicLatitude = Schema.number({ min = -90, max = 90 }),
			brightness = Schema.number({ min = 0, max = 10 }),
			ambient = rgb,
			outdoorAmbient = rgb,
			environmentDiffuseScale = unit,
			environmentSpecularScale = unit,
			exposureCompensation = Schema.number({ min = -3, max = 3 }),
			shadowSoftness = unit,
		}),
		atmosphere = Schema.record({
			density = unit,
			offset = unit,
			color = rgb,
			decay = rgb,
			glare = Schema.number({ min = 0, max = 10 }),
			haze = Schema.number({ min = 0, max = 10 }),
		}),
		sky = Schema.record({
			sunAngularSize = Schema.number({ min = 0, max = 60 }),
			moonAngularSize = Schema.number({ min = 0, max = 60 }),
			starCount = Schema.integer({ min = 0, max = 5000 }),
		}),
		skybox = Schema.record({
			cloudCover = unit,
			atmosphereDensity = unit,
			haze = Schema.number({ min = 0, max = 10 }),
		}),
		ground = Schema.record({
			grassTileStuds = Schema.number({ min = 4, max = 256 }),
		}),
		clouds = Schema.record({
			cover = unit,
			density = unit,
			color = rgb,
		}),
		effects = Schema.record({
			bloomIntensity = unit,
			bloomSize = Schema.number({ min = 0, max = 56 }),
			bloomThreshold = Schema.number({ min = 0, max = 4 }),
			sunRaysIntensity = unit,
			sunRaysSpread = unit,
			saturation = Schema.number({ min = -1, max = 1 }),
			contrast = Schema.number({ min = -1, max = 1 }),
			tint = rgb,
		}),
		wander = Schema.record({
			speed = Schema.number({ min = 0.5, max = 10 }),
			segmentSeconds = Schema.number({ min = 2, max = 60 }),
			turnSeconds = Schema.number({ min = 0.1, max = 3 }),
			faceFrontAfter = Schema.number({ min = 0, max = 30 }),
			margin = Schema.number({ min = 0, max = 4 }),
			cullStuds = Schema.number({ min = 40, max = 1000 }),
			cullOtherStuds = Schema.number({ min = 20, max = 1000 }),
			animateOtherStuds = Schema.number({ min = 10, max = 500 }),
		}),
		creatureLod = Schema.record({
			farStuds = Schema.number({ min = 10, max = 200 }),
		}),
		scenery = Schema.check(
			Schema.record({
				hillRadius = Schema.number({ min = 200, max = 1000 }),
				hillCount = Schema.integer({ min = 0, max = 60 }),
				seed = Schema.integer(),
				nature = Schema.record({
					seed = Schema.integer({ min = 1 }),
					gap = Schema.record({
						trees = Schema.array(Schema.string({ minLength = 1, maxLength = 40 }), {
							minLength = 1,
							maxLength = 8,
						}),
						bushes = Schema.array(Schema.string({ minLength = 1, maxLength = 40 }), {
							maxLength = 8,
						}),
						radius = Schema.number({ min = 146, max = 250 }),
						degrees = Schema.number({ min = 0, max = 22 }),
					}),
					wood = Schema.record({
						count = Schema.integer({ min = 0, max = 150 }),
						radiusMin = Schema.number({ min = 150, max = 300 }),
						radiusMax = Schema.number({ min = 150, max = 300 }),
						scaleMin = Schema.number({ min = 0.5, max = 2 }),
						scaleMax = Schema.number({ min = 0.5, max = 2 }),
						minSpacing = Schema.number({ min = 0, max = 40 }),
						species = Schema.map(Schema.string({ maxLength = 40 }), Schema.number({ min = 0 })),
					}),
					scatter = Schema.record({
						radiusMin = Schema.number({ min = 146, max = 300 }),
						radiusMax = Schema.number({ min = 146, max = 300 }),
						bushes = Schema.integer({ min = 0, max = 200 }),
						rocks = Schema.integer({ min = 0, max = 200 }),
						flowers = Schema.integer({ min = 0, max = 200 }),
						tufts = Schema.integer({ min = 0, max = 400 }),
						mushroomRings = Schema.integer({ min = 0, max = 60 }),
					}),
					hillPines = Schema.integer({ min = 0, max = 60 }),
					hillPine = Schema.string({ minLength = 1, maxLength = 40 }),
				}),
				farm = Schema.record({
					barn = farmSpot,
					windmill = farmSpot,
					pond = farmSpot,
					pen = farmSpot,
					fields = Schema.array(Schema.number({ min = 0, max = 360 }), { maxLength = 8 }),
					fieldRadius = Schema.number({ min = 160, max = 260 }),
					clearRadius = Schema.number({ min = 0, max = 80 }),
					windmillTurnSeconds = Schema.number({ min = 1, max = 120 }),
				}),
				-- The farm hub (tests/HubLayout.spec.luau checks the fit).
				hub = Schema.optional(Schema.record({
					innerRadius = Schema.number({ min = 20, max = 60 }),
					outerRadius = Schema.number({ min = 40, max = 100 }),
					pathWidth = Schema.number({ min = 4, max = 30 }),
					shop = Schema.record({
						angle = Schema.number({ min = 0, max = 360 }),
						radius = Schema.number({ min = 20, max = 100 }),
						width = Schema.number({ min = 1, max = 60 }),
						depth = Schema.number({ min = 1, max = 60 }),
					}),
					arch = Schema.record({
						id = Schema.string({ maxLength = 40 }),
						radius = Schema.number({ min = 20, max = 100 }),
					}),
					lamps = Schema.record({
						id = Schema.string({ maxLength = 40 }),
						radii = Schema.array(Schema.number({ min = 20, max = 100 }), { maxLength = 8 }),
						side = Schema.number({ min = 0, max = 30 }),
					}),
					signposts = Schema.record({
						id = Schema.string({ maxLength = 40 }),
						radius = Schema.number({ min = 20, max = 100 }),
						side = Schema.number({ min = 0, max = 30 }),
					}),
					pieces = Schema.array(
						Schema.record({
							id = Schema.string({ maxLength = 40 }),
							angle = Schema.number({ min = 0, max = 360 }),
							radius = Schema.number({ min = 20, max = 100 }),
							yaw = Schema.optional(Schema.number({ min = -360, max = 360 })),
						}),
						{ maxLength = 80 }
					),
				})),
			}),
			function(v: any): (boolean, string?)
				if v.nature.wood.radiusMax < v.nature.wood.radiusMin then
					return false, "nature.wood.radiusMax must be at least radiusMin"
				end
				if v.nature.wood.scaleMax < v.nature.wood.scaleMin then
					return false, "nature.wood.scaleMax must be at least scaleMin"
				end
				if v.nature.scatter.radiusMax < v.nature.scatter.radiusMin then
					return false, "nature.scatter.radiusMax must be at least radiusMin"
				end
				return true
			end
		),
		-- Menu buttons (client/TowerView): how long a row shows "Built!" or
		-- "Need ... more" in place of its button, and how long it waits for
		-- the server after a tap before showing the button again.
		menus = Schema.record({
			holdSeconds = Schema.number({ min = 0.5, max = 5 }),
			waitSeconds = Schema.number({ min = 1, max = 10 }),
		}),
		-- The guide's arrow and beam (client/GuideView).
		-- The Hatchery Book's drawn-ahead rows (client/BookView).
		book = Schema.record({
			overscanRows = Schema.integer({ min = 1, max = 4 }),
			warmCards = Schema.integer({ min = 24, max = 300 }),
			warmPerFrame = Schema.integer({ min = 1, max = 20 }),
		}),
		guide = Schema.record({
			arrivedStuds = Schema.number({ min = 2, max = 30 }),
			playerList = Schema.boolean(),
		}),
		music = Schema.record({
			tracks = Schema.array(Schema.integer({ min = 1 }), { maxLength = 20 }),
			volume = Schema.number({ min = 0, max = 1 }),
			fadeSeconds = Schema.number({ min = 0, max = 10 }),
			startDelaySeconds = Schema.number({ min = 0, max = 30 }),
			startFadeSeconds = Schema.number({ min = 0.5, max = 15 }),
			crossfadeSeconds = Schema.number({ min = 0.5, max = 10 }),
		}),
		sounds = Schema.map(
			Schema.string({ maxLength = 30 }),
			Schema.record({
				id = Schema.integer({ min = 0 }),
				volume = unit,
			})
		),
		towerShells = Schema.record({
			drawStuds = Schema.number({ min = 20, max = 1000 }),
			towers = Schema.integer({ min = 1, max = 8 }),
			boxesPerFrame = Schema.integer({ min = 50, max = 10000 }),
		}),
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
			DoubleCoins = productId,
			ExtraIncubators = productId,
			AutoCollect = productId,
		}),
		products = Schema.map(
			id,
			Schema.record({
				id = productId,
				coins = Schema.optional(Schema.integer({ min = 1 })),
			})
		),
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
		boosts = Schema.map(
			id,
			Schema.record({
				durationSeconds = Schema.integer({ min = 1 }),
				eggs = Schema.array(id, { minLength = 1 }),
				rarityMultipliers = Schema.map(
					Schema.oneOf({ "Common", "Uncommon", "Rare", "Ultra Rare", "Epic", "Legendary", "Godly" }),
					Schema.number({ min = 0.01, max = 100 })
				),
			})
		),
	})

	-- Rules that need more than one file. Returns a list of problems.
	function Schemas.crossCheck(config: { [string]: any }): { string }
		local problems = {}
		local species = config.creatures.species
		local products = config.monetization.products

		local eggIds: { [string]: boolean } = {}
		for _, egg in config.eggs do
			if eggIds[egg.id] then
				table.insert(problems, `eggs: {egg.id} is listed twice`)
			end
			eggIds[egg.id] = true
			if (egg.priceCoins == nil) == (egg.productKey == nil) then
				table.insert(problems, `eggs.{egg.id}: set exactly one of priceCoins or productKey`)
			end
			if egg.productKey and products[egg.productKey] == nil then
				table.insert(
					problems,
					`eggs.{egg.id}: productKey {egg.productKey} is not in monetization.products`
				)
			end
			local tierSum = 0
			for rarity, weight in egg.tiers do
				tierSum += weight
				local members = 0
				for _, s in species do
					if s.rarity == rarity and table.find(s.pools, egg.pool) then
						members += 1
					end
				end
				if members == 0 then
					table.insert(problems, `eggs.{egg.id}: no {rarity} creature is in pool {egg.pool}`)
				elseif weight < members then
					table.insert(
						problems,
						`eggs.{egg.id}: {rarity} weight {weight} is less than its {members} creatures`
					)
				end
			end
			if tierSum ~= (egg.total or 10000) then
				table.insert(problems, `eggs.{egg.id}: tiers add up to {tierSum}, not {egg.total or 10000}`)
			end
			for _, outcome in egg.outcomes do
				if species[outcome.id] == nil then
					table.insert(problems, `eggs.{egg.id}: hatches unknown species {outcome.id}`)
				end
			end
			local ok, err = pcall(Odds.validate, {
				id = egg.id,
				paid = egg.productKey ~= nil,
				total = egg.total,
				outcomes = egg.outcomes,
			})
			if not ok then
				table.insert(problems, `eggs.{egg.id}: {err}`)
			end
		end

		local onBelt = 0
		for eggId in config.economy.conveyor.weights do
			onBelt += 1
			local egg = nil
			for _, e in config.eggs do
				if e.id == eggId then
					egg = e
				end
			end
			if egg == nil then
				table.insert(problems, `economy.conveyor.weights: unknown egg {eggId}`)
			elseif egg.priceCoins == nil then
				table.insert(problems, `economy.conveyor.weights: {eggId} is not a coin egg`)
			end
		end
		if onBelt == 0 then
			table.insert(problems, "economy.conveyor.weights: at least one egg must ride the belt")
		end

		for boostId, boost in config.monetization.boosts do
			if products[boostId] == nil then
				table.insert(problems, `monetization.boosts.{boostId} has no matching product`)
			end
			for _, eggId in boost.eggs do
				if not eggIds[eggId] then
					table.insert(problems, `monetization.boosts.{boostId}: unknown egg {eggId}`)
				end
			end
		end

		local usedIds: { [number]: string } = {}
		for key, product in products do
			if product.id > 0 then
				if usedIds[product.id] then
					table.insert(
						problems,
						`monetization: product id {product.id} used by {usedIds[product.id]} and {key}`
					)
				end
				usedIds[product.id] = key
			end
			if string.match(key, "^CoinPack") and product.coins == nil then
				table.insert(problems, `monetization.products.{key}: coin packs need coins`)
			end
		end
		return problems
	end

	-- Builds the Config.load input from the raw config modules.
	Schemas.shophouse = Schema.record({
		angle = Schema.number({ min = 0, max = 360 }),
		radius = Schema.number({ min = 34, max = 70 }),
		groundY = Schema.number({ min = -1, max = 2 }),
		promptDistance = Schema.number({ min = 4, max = 14 }),
		title = Schema.string({ maxLength = 30 }),
		coinsHeader = Schema.string({ maxLength = 24 }),
		passesHeader = Schema.string({ maxLength = 24 }),
		lightScale = Schema.number({ min = 0, max = 3 }),
		lightRangeScale = Schema.number({ min = 0.1, max = 2 }),
		lightColor = Schema.array(Schema.number({ min = 0, max = 255 }), { minLength = 3, maxLength = 3 }),
		neon = Schema.boolean(),
		animateRange = Schema.number({ min = 0, max = 400 }),
		indoorZoom = Schema.number({ min = 4, max = 30 }),
	})

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
