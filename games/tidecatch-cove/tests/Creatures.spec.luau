--!strict
local Creatures = require("../src/shared/Creatures")
local pools = require("../config/pools")
local species = require("../config/species")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local function pooled(speciesId: string, kg: number, placedAt: number, fed: number?): Creatures.Pooled
	return {
		uid = "1",
		speciesId = speciesId,
		kg = kg,
		mutation = "None",
		slot = 1,
		placedAt = placedAt,
		fed = fed or 0,
		lastFedAt = 0,
	}
end

describe("Creatures", function()
	local shrimp = species.species.SandShrimp

	it("values size from the smallest to the largest catch", function()
		expect(Creatures.sizeFactor(shrimp.minKg, shrimp, species.sizeValue)).toBe(species.sizeValue.min)
		expect(Creatures.sizeFactor(shrimp.maxKg, shrimp, species.sizeValue)).toBe(species.sizeValue.max)
		local mid = (shrimp.minKg + shrimp.maxKg) / 2
		expect(Creatures.sizeFactor(mid, shrimp, species.sizeValue)).toBeCloseTo(
			(species.sizeValue.min + species.sizeValue.max) / 2,
			1e-9
		)
	end)

	it("sells for more at every growth stage, and never for 0", function()
		local c = pooled("SandShrimp", shrimp.minKg, 0)
		local last = 0
		for stage = 1, #pools.stages do
			local value = Creatures.value(c, stage, species, pools)
			expect(value > last).toBe(true)
			last = value
		end
		expect(Creatures.value(c, 1, species, pools)).toBeAtLeast(1)
		local glowing = table.clone(c)
		glowing.mutation = "Glowing"
		expect(Creatures.value(glowing, 5, species, pools)).toBe(
			math.floor(
				shrimp.value
					* pools.stages[5].valueMultiplier
					* species.sizeValue.min
					* species.mutations.Glowing
			)
		)
	end)

	it("grows one stage per stageSeconds, plus feeding, up to the last stage", function()
		local per = pools.stageSeconds.Common
		local c = pooled("SandShrimp", 0.2, 1000)
		expect(Creatures.stage(c, 1000, species, pools)).toBe(1)
		expect(Creatures.stage(c, 1000 + per - 1, species, pools)).toBe(1)
		expect(Creatures.stage(c, 1000 + per, species, pools)).toBe(2)
		expect(Creatures.nextStageIn(c, 1000 + per, species, pools)).toBe(per)
		c.fed = per
		expect(Creatures.stage(c, 1000 + per, species, pools)).toBe(3)
		expect(Creatures.stage(c, 1000 + 100 * per, species, pools)).toBe(#pools.stages)
		expect(Creatures.nextStageIn(c, 1000 + 100 * per, species, pools)).toBeNil()
		expect(Creatures.grown(c, 1000 + 100 * per, "Common", pools)).toBe(
			Creatures.growthSeconds("Common", pools)
		)
	end)

	it("formats sizes for people", function()
		expect(Creatures.formatKg(0.35)).toBe("0.35 kg")
		expect(Creatures.formatKg(12.44)).toBe("12.4 kg")
		expect(Creatures.formatKg(1250)).toBe("1,250 kg")
		expect(Creatures.formatKg(999999)).toBe("999,999 kg")
	end)
end)
