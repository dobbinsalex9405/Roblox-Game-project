--!strict
-- Eggs roll a tier, then a creature inside that tier (Alex, Nov 5): adding a
-- creature only splits its own tier's share, so the chance of every other
-- tier, and of every creature in it, never moves.
local Eggs = require("../src/shared/Eggs")
local creatures = require("../config/creatures")
local rawEggs = require("../config/eggs")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local function byId(list: { any }): { [string]: any }
	local out = {}
	for _, egg in list do
		local weights = {}
		for _, o in egg.outcomes do
			weights[o.id] = o.weight
		end
		out[egg.id] = weights
	end
	return out
end

describe("Egg tiers", function()
	it("gives each tier exactly its weight, and the tiers exactly the total", function()
		for _, egg in Eggs.expand(rawEggs, creatures.species) do
			local perTier: { [string]: number } = {}
			local sum = 0
			for _, o in egg.outcomes do
				local rarity = creatures.species[o.id].rarity
				perTier[rarity] = (perTier[rarity] or 0) + o.weight
				expect(o.weight).toBeAtLeast(1)
				sum += o.weight
			end
			expect(sum).toBe(egg.total)
			for rarity, weight in egg.tiers do
				expect(perTier[rarity]).toBe(weight)
			end
		end
	end)

	it("splits a tier as evenly as whole numbers allow", function()
		for _, egg in Eggs.expand(rawEggs, creatures.species) do
			local low: { [string]: number } = {}
			local high: { [string]: number } = {}
			for _, o in egg.outcomes do
				local rarity = creatures.species[o.id].rarity
				low[rarity] = math.min(low[rarity] or math.huge, o.weight)
				high[rarity] = math.max(high[rarity] or 0, o.weight)
			end
			for rarity in low do
				expect(high[rarity] - low[rarity]).toBeAtMost(1)
			end
		end
	end)

	it("gives every creature in a tier the same weight (tools/economy/even_eggs.py)", function()
		for _, egg in Eggs.expand(rawEggs, creatures.species) do
			local seen: { [string]: number } = {}
			for _, o in egg.outcomes do
				local rarity = creatures.species[o.id].rarity
				seen[rarity] = seen[rarity] or o.weight
				if o.weight ~= seen[rarity] then
					error(
						`{egg.id}: {o.id} has weight {o.weight}, others in {rarity} {seen[rarity]}; run even_eggs.py`
					)
				end
			end
		end
	end)

	it("never moves another tier's odds when a creature is added", function()
		local before = byId(Eggs.expand(rawEggs, creatures.species))
		local more = table.clone(creatures.species)
		more.TestCommon =
			{ rarity = "Common", coinsPerSecond = 2, mountSpeed = 18, pools = { "Barnyard", "Meadow" } }
		more.TestEpic = { rarity = "Epic", coinsPerSecond = 150, mountSpeed = 28, pools = { "Moonlit" } }
		local after = byId(Eggs.expand(rawEggs, more))
		for eggId, weights in before do
			for id, weight in weights do
				local rarity = creatures.species[id].rarity
				local moved = (rarity == "Common" and (eggId == "BasicEgg" or eggId == "MeadowEgg"))
					or (rarity == "Epic" and eggId == "MoonlitEgg")
				if not moved then
					expect(after[eggId][id]).toBe(weight)
				end
			end
		end
		expect(after.BasicEgg.TestCommon).toBeAtLeast(1)
		expect(after.MoonlitEgg.TestEpic).toBeAtLeast(1)
	end)

	it("lets a creature be rarer inside its tier without moving the tier", function()
		local more = table.clone(creatures.species)
		local raccoon = table.clone(more.Raccoon)
		raccoon.pools = { "Moonlit" }
		raccoon.weight = 0.5
		more.Raccoon = raccoon
		local moonlit = byId(Eggs.expand(rawEggs, more)).MoonlitEgg
		local rare = 0
		for _, egg in rawEggs do
			if egg.id == "MoonlitEgg" then
				rare = egg.tiers.Rare
			end
		end
		-- Every other Moonlit Rare at its own weight (1 unless set), the
		-- Raccoon at 0.5: it gets 0.5 parts of the tier, and the tier's total
		-- stays exactly the same. Counted from the config, so new Rares in the
		-- pool don't break it.
		local parts = 0
		for id, c in more do
			if id ~= "Raccoon" and c.rarity == "Rare" and table.find(c.pools, "Moonlit") then
				parts += (c :: any).weight or 1
			end
		end
		expect(parts).toBeAtLeast(1)
		expect(math.abs(moonlit.Raccoon - rare * 0.5 / (parts + 0.5))).toBeAtMost(1)
		local tier = 0
		for id, w in moonlit do
			if more[id].rarity == "Rare" then
				tier += w
			end
		end
		expect(tier).toBe(rare)
	end)
end)
