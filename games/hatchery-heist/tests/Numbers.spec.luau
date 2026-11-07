--!strict
-- Short numbers on labels and buttons (Studio gate, Nov 5: "25.00K coins").
local Numbers = require("../src/shared/Numbers")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("Short numbers", function()
	it("drop trailing zeros", function()
		expect(Numbers.short(25000)).toBe("25K")
		expect(Numbers.short(1500)).toBe("1.5K")
		expect(Numbers.short(165e6)).toBe("165M")
		expect(Numbers.short(10000)).toBe("10K")
	end)

	it("keep up to two decimals and whole small numbers", function()
		expect(Numbers.short(1234567)).toBe("1.23M")
		expect(Numbers.short(999)).toBe("999")
		expect(Numbers.short(12.7)).toBe("12")
		expect(Numbers.short(2.5e12)).toBe("2.5T")
	end)
end)
