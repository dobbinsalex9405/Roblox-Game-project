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
		-- Fennec, Owlet and Panda Cub at 1, the Raccoon at 0.5: 1 part in 7
		-- of the Moonlit Egg's 30,000 Rare weight.
		expect(moonlit.Raccoon).toBe(4286)
		expect(moonlit.Fennec + moonlit.Owlet + moonlit.PandaCub + moonlit.Raccoon).toBe(30000)
	end)
end)
