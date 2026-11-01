--!strict
-- Schemas for every file in config/, plus checks that span files (a station
-- must belong to a district, the starter station must exist, every station
-- must fit on a spot, and so on).
--
-- Takes the core Schema module as an argument because this file runs both in
-- Roblox (server start-up) and in Lune (CI tests), which load the core from
-- different places.

export type Section = { schema: (value: any, path: string) -> (boolean, string?), value: any }

return function(Schema: any)
	local Schemas = {}

	local id = Schema.string({ maxLength = 50, pattern = "^%u%w*$" })
	local positive = Schema.number({ min = 0 })
	local count = Schema.integer({ min = 0 })
	local productId = Schema.integer({ min = 0 })

	Schemas.economy = Schema.record({
		startingCash = count,
		cashMax = Schema.integer({ min = 1, max = 2 ^ 53 }),
		starterStation = id,
		customers = Schema.record({
			queueMax = Schema.integer({ min = 1, max = 50 }),
			handServeBonus = Schema.number({ min = 0, max = 5 }),
		}),
		rebirth = Schema.record({
			cost = Schema.integer({ min = 1 }),
			maxRebirths = Schema.integer({ min = 0, max = 100 }),
			incomeBonusPerRebirth = positive,
		}),
		autoCollectSeconds = Schema.integer({ min = 1, max = 3600 }),
		doubleCashMultiplier = Schema.number({ min = 1, max = 10 }),
		offline = Schema.record({
			rate = Schema.number({ min = 0, max = 1 }),
			maxSeconds = Schema.integer({ min = 0, max = 24 * 60 * 60 }),
		}),
	})

	Schemas.districts = Schema.check(
		Schema.array(
			Schema.record({
				id = id,
				cost = count,
				spots = Schema.integer({ min = 1, max = 8 }),
				customersPerMinute = Schema.number({ min = 0.1, max = 600 }),
			}),
			{ minLength = 1, maxLength = 6 }
		),
		function(v: any): (boolean, string?)
			if v[1].cost ~= 0 then
				return false, "the first district is open from the start: its cost must be 0"
			end
			for i = 2, #v do
				if v[i].cost <= v[i - 1].cost then
					return false, "each district must cost more than the one before"
				end
			end
			return true, nil
		end
	)

	local level = Schema.record({
		cost = Schema.integer({ min = 1 }),
		buildSeconds = Schema.integer({ min = 0, max = 24 * 60 * 60 }),
		price = Schema.integer({ min = 1 }),
	})

	Schemas.stations = Schema.array(
		Schema.check(
			Schema.record({
				id = id,
				district = Schema.integer({ min = 1, max = 6 }),
				levels = Schema.array(level, { minLength = 1, maxLength = 10 }),
			}),
			function(v: any): (boolean, string?)
				for i = 2, #v.levels do
					if v.levels[i].price <= v.levels[i - 1].price then
						return false, "each level's price must be higher than the one before"
					end
				end
				return true, nil
			end
		),
		{ minLength = 1, maxLength = 48 }
	)

	Schemas.cooks = Schema.record({
		tiers = Schema.check(
			Schema.array(
				Schema.record({
					id = id,
					cost = Schema.integer({ min = 1 }),
					costGrowth = Schema.number({ min = 1, max = 10 }),
					servesPerMinute = Schema.number({ min = 0.1, max = 600 }),
				}),
				{ minLength = 1, maxLength = 10 }
			),
			function(v: any): (boolean, string?)
				for i = 2, #v do
					if v[i].servesPerMinute <= v[i - 1].servesPerMinute then
						return false, "each tier must serve more customers than the one before"
					end
				end
				return true, nil
			end
		),
	})

	Schemas.monetization = Schema.record({
		passes = Schema.record({
			DoubleCash = productId,
			AutoCollect = productId,
			FestivalBundle = productId,
		}),
		products = Schema.map(
			id,
			Schema.record({
				id = productId,
				cash = Schema.optional(Schema.integer({ min = 1 })),
			})
		),
		boosts = Schema.record({
			SpeedBoost = Schema.record({
				durationSeconds = Schema.integer({ min = 1, max = 24 * 60 * 60 }),
				customerMultiplier = Schema.number({ min = 1, max = 10 }),
			}),
		}),
	})

	-- Rules that need more than one file. Returns a list of problems.
	function Schemas.crossCheck(config: { [string]: any }): { string }
		local problems = {}
		local districts = config.districts
		local products = config.monetization.products

		local stationIds: { [string]: any } = {}
		local perDistrict: { [number]: number } = {}
		for _, station in config.stations do
			if stationIds[station.id] then
				table.insert(problems, `stations: {station.id} is listed twice`)
			end
			stationIds[station.id] = station
			if districts[station.district] == nil then
				table.insert(problems, `stations.{station.id}: unknown district {station.district}`)
			else
				perDistrict[station.district] = (perDistrict[station.district] or 0) + 1
			end
		end

		-- With the first k districts open, every station they allow must fit.
		local stations, spots = 0, 0
		for index, district in districts do
			stations += perDistrict[index] or 0
			spots += district.spots
			if stations > spots then
				table.insert(
					problems,
					`districts: {stations} stations need a spot by {district.id}, but there are {spots}`
				)
			end
		end

		local starter = stationIds[config.economy.starterStation]
		if starter == nil then
			table.insert(problems, `economy.starterStation: unknown station {config.economy.starterStation}`)
		elseif starter.district ~= 1 then
			table.insert(problems, "economy.starterStation must be a first-district station")
		end

		local tierIds: { [string]: boolean } = {}
		for _, tier in config.cooks.tiers do
			if tierIds[tier.id] then
				table.insert(problems, `cooks: {tier.id} is listed twice`)
			end
			tierIds[tier.id] = true
		end

		for boostId in config.monetization.boosts do
			if products[boostId] == nil then
				table.insert(problems, `monetization.boosts.{boostId} has no matching product`)
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
			if string.match(key, "^CashPack") and product.cash == nil then
				table.insert(problems, `monetization.products.{key}: cash packs need cash`)
			end
		end
		local passIds: { [number]: string } = {}
		for key, passId in config.monetization.passes do
			if passId > 0 then
				if passIds[passId] then
					table.insert(
						problems,
						`monetization: pass id {passId} used by {passIds[passId]} and {key}`
					)
				end
				passIds[passId] = key
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
