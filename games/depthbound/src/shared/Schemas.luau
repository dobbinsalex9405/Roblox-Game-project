--!strict
-- Schemas for every file in config/, plus checks that span files (a layer can
-- only contain blocks that exist, each layer's weights total exactly 10,000,
-- and so on).
--
-- Takes the core Schema and Odds modules as arguments because this file runs
-- both in Roblox (server start-up) and in Lune (CI tests), which load the core
-- from different places.

export type Section = { schema: (value: any, path: string) -> (boolean, string?), value: any }

local MATERIALS = { "Slate", "Metal", "Glass", "Basalt", "Neon", "Rock", "Granite", "Marble", "Ground" }

return function(Schema: any, Odds: any)
	local Schemas = {}

	local id = Schema.string({ maxLength = 50, pattern = "^%u%w*$" })
	local name = Schema.string({ minLength = 1, maxLength = 40 })
	local positive = Schema.number({ min = 0 })
	local productId = Schema.integer({ min = 0 })
	local channel = Schema.integer({ min = 0, max = 255 })

	-- Tiers: a non-empty list whose first tier is free and whose costs never drop.
	local function tiers(fields: { [string]: any }): any
		fields.name = name
		fields.cost = Schema.integer({ min = 0 })
		return Schema.check(
			Schema.array(Schema.record(fields), { minLength = 1, maxLength = 20 }),
			function(v: any): (boolean, string?)
				if v[1].cost ~= 0 then
					return false, "tier 1 is the starting gear and must cost 0"
				end
				for i = 2, #v do
					if v[i].cost < v[i - 1].cost then
						return false, "costs must not decrease"
					end
				end
				return true, nil
			end
		)
	end

	Schemas.economy = Schema.record({
		startingCoins = Schema.integer({ min = 0 }),
		coinsMax = Schema.integer({ min = 1, max = 2 ^ 53 }),
	})

	Schemas.blocks = Schema.map(
		id,
		Schema.record({
			hp = Schema.number({ min = 0.1, max = 1e6 }),
			value = Schema.integer({ min = 0 }),
			color = Schema.array(channel, { minLength = 3, maxLength = 3 }),
			material = Schema.oneOf(MATERIALS),
		}),
		{ maxEntries = 200 }
	)

	Schemas.mine = Schema.record({
		width = Schema.integer({ min = 2, max = 64 }),
		length = Schema.integer({ min = 2, max = 64 }),
		blockSize = Schema.number({ min = 4, max = 16 }),
		layers = Schema.array(
			Schema.record({
				id = id,
				name = name,
				rows = Schema.integer({ min = 1, max = 100 }),
				minPickTier = Schema.integer({ min = 1, max = 20 }),
				oilPerSecond = Schema.number({ min = 0.1, max = 20 }),
				blocks = Schema.array(
					Schema.record({ id = id, weight = Schema.integer({ min = 1 }) }),
					{ minLength = 1 }
				),
			}),
			{ minLength = 1, maxLength = 20 }
		),
		regrowSeconds = Schema.integer({ min = 10, max = 24 * 60 * 60 }),
		regrowClearance = Schema.number({ min = 0, max = 200 }),
	})

	Schemas.gear = Schema.record({
		pick = tiers({ power = Schema.number({ min = 0.1, max = 1e6 }) }),
		pack = tiers({ capacity = Schema.integer({ min = 1, max = 10000 }) }),
		lamp = tiers({ oilSeconds = Schema.number({ min = 5, max = 3600 }) }),
		passes = Schema.record({
			biggerPackSlots = Schema.integer({ min = 0, max = 10000 }),
			betterLampMultiplier = Schema.number({ min = 1, max = 10 }),
		}),
	})

	Schemas.dive = Schema.record({
		reach = Schema.number({ min = 4, max = 40 }),
		swingSeconds = Schema.number({ min = 0.05, max = 5 }),
		swingTolerance = Schema.number({ min = 0.1, max = 1 }),
		climb = Schema.record({
			baseSeconds = positive,
			secondsPerRow = positive,
			oilPerSecond = Schema.number({ min = 0, max = 20 }),
		}),
		lampOut = Schema.record({
			keepFraction = Schema.number({ min = 0, max = 1 }),
		}),
	})

	Schemas.monetization = Schema.record({
		passes = Schema.record({
			BiggerPack = productId,
			BetterLamp = productId,
			AutoSell = productId,
		}),
		products = Schema.map(id, Schema.record({ id = productId })),
	})

	-- The odds tables the mine rolls from: one per layer, free (finding ore costs nothing).
	function Schemas.oddsTables(mine: any): { any }
		local out = {}
		for _, layer in mine.layers do
			local outcomes = {}
			for _, entry in layer.blocks do
				table.insert(outcomes, { id = entry.id, weight = entry.weight })
			end
			table.insert(out, { id = layer.id, paid = false, outcomes = outcomes })
		end
		return out
	end

	-- Rules that need more than one file. Returns a list of problems.
	function Schemas.crossCheck(config: { [string]: any }): { string }
		local problems = {}
		local blocks = config.blocks
		local mine = config.mine
		local pickTiers = #config.gear.pick

		local layerIds: { [string]: boolean } = {}
		for index, layer in mine.layers do
			if layerIds[layer.id] then
				table.insert(problems, `mine.layers: {layer.id} is listed twice`)
			end
			layerIds[layer.id] = true
			local hasRock = false
			for _, entry in layer.blocks do
				local block = blocks[entry.id]
				if block == nil then
					table.insert(problems, `mine.layers.{layer.id}: unknown block {entry.id}`)
				elseif block.value == 0 then
					hasRock = true
				end
			end
			if not hasRock then
				table.insert(problems, `mine.layers.{layer.id}: needs a plain rock (value 0) to dig through`)
			end
			if layer.minPickTier > pickTiers then
				table.insert(
					problems,
					`mine.layers.{layer.id}: no pick tier reaches minPickTier {layer.minPickTier}`
				)
			end
			if index > 1 and layer.minPickTier < mine.layers[index - 1].minPickTier then
				table.insert(problems, `mine.layers.{layer.id}: minPickTier is below the layer above`)
			end
		end
		for _, def in Schemas.oddsTables(mine) do
			local ok, err = pcall(Odds.validate, def)
			if not ok then
				table.insert(problems, `mine.layers.{def.id}: {err}`)
			end
		end

		-- A full candle lamp must at least get a new player to the bottom of
		-- layer 1 and back, or the first dive cannot succeed.
		local layer1Bottom = mine.layers[1].rows
		local candle = config.gear.lamp[1].oilSeconds
		local climb = config.dive.climb
		local climbOil = (climb.baseSeconds + climb.secondsPerRow * layer1Bottom) * climb.oilPerSecond
		if climbOil >= candle then
			table.insert(
				problems,
				"gear.lamp[1]: the starting lamp cannot climb out from the bottom of layer 1"
			)
		end

		-- The reach must cover the block next to the player, or nobody can mine.
		if config.dive.reach < mine.blockSize * 1.5 then
			table.insert(problems, "dive.reach: must be at least 1.5 blocks so the next block is in reach")
		end

		local usedIds: { [number]: string } = {}
		local function claim(key: string, value: number)
			if value > 0 then
				if usedIds[value] then
					table.insert(problems, `monetization: id {value} used by {usedIds[value]} and {key}`)
				end
				usedIds[value] = key
			end
		end
		for key, value in config.monetization.passes do
			claim(`passes.{key}`, value)
		end
		for key, product in config.monetization.products do
			claim(`products.{key}`, product.id)
			if string.match(key, "^CoinPack") then
				table.insert(problems, `monetization.products.{key}: Depthbound sells no coin packs`)
			end
		end
		return problems
	end

	-- Builds the Config.load input from the raw config modules.
	function Schemas.sections(config: { [string]: any }): { [string]: Section }
		local sections = {}
		for sectionName, value in config do
			local schema = Schemas[sectionName]
			assert(type(schema) == "function", `no schema for config/{sectionName}`)
			sections[sectionName] = { schema = schema, value = value }
		end
		return sections
	end

	return Schemas
end
