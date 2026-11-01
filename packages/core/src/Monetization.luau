--!strict
-- Game pass and developer product ids for the experience this build runs in.
--
-- Each game's `config/monetization.luau` lists its passes (key -> id) and
-- products (key -> { id = ..., ... }). Those ids are the defaults, used in
-- Studio and dev builds, and stay 0 until the item exists on Roblox. Dev
-- products and passes belong to one experience, so Staging and Production
-- have different ids. They go in an optional `environments` table:
--
--   environments = {
--       staging = { passes = { DoubleCoins = 123 }, products = { CoinPackSmall = 456 } },
--       production = { passes = { ... }, products = { ... } },
--   }
--
-- `resolve` picks the right ids for the build's environment (stamped by
-- tools/build.sh from BUILD_ENVIRONMENT). An id of 0 means "not created on
-- Roblox yet": it is never prompted, never registered by id and never owned.

export type Resolved = {
	environment: string,
	passes: { [string]: number }, -- key -> game pass id (0 = not created)
	products: { [string]: number }, -- key -> developer product id (0 = not created)
}

local ENVIRONMENTS = { dev = true, staging = true, production = true }

local Monetization = {}

local function checkId(id: any, what: string)
	assert(type(id) == "number" and id >= 0 and id // 1 == id, `{what} must be a whole number >= 0`)
end

function Monetization.resolve(monetization: { [string]: any }, environment: string): Resolved
	assert(ENVIRONMENTS[environment], `unknown environment "{tostring(environment)}"`)
	local passes: { [string]: number } = {}
	for key, id in monetization.passes or {} do
		checkId(id, `pass {key}`)
		passes[key] = id
	end
	local products: { [string]: number } = {}
	for key, product in monetization.products or {} do
		assert(type(product) == "table", `product {key} must be a table with an id`)
		checkId(product.id, `product {key} id`)
		products[key] = product.id
	end

	local overrides = monetization.environments and monetization.environments[environment]
	if overrides then
		for key, id in overrides.passes or {} do
			assert(passes[key] ~= nil, `environments.{environment}.passes.{key} is not a pass`)
			checkId(id, `environments.{environment}.passes.{key}`)
			passes[key] = id
		end
		for key, id in overrides.products or {} do
			assert(products[key] ~= nil, `environments.{environment}.products.{key} is not a product`)
			checkId(id, `environments.{environment}.products.{key}`)
			products[key] = id
		end
	end

	-- Roblox ids are unique per kind; the same id twice is a copy-paste slip.
	for _, list in { passes, products } do
		local seen: { [number]: string } = {}
		for key, id in list do
			if id > 0 then
				assert(seen[id] == nil, `id {id} is used by both {seen[id]} and {key} ({environment})`)
				seen[id] = key
			end
		end
	end

	return { environment = environment, passes = passes, products = products }
end

return Monetization
