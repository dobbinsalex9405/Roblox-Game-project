--!strict
-- What an incubator's floating label says. The client writes this label
-- itself every frame; the server's blank text never reaches it again once
-- the client has changed it, so the client must clear it too (a Studio
-- playtest found an emptied incubator still saying "Ready!").
local IncubatorLabel = require("../src/shared/IncubatorLabel")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local function name(id: string): string
	return id
end
local function short(n: number): string
	return tostring(n)
end

describe("Incubator label", function()
	it("counts down, then says Ready!", function()
		local text, ready = IncubatorLabel.text("Busy", "BasicEgg", 130, nil, 100, name, short)
		expect(text).toBe("BasicEgg 0:30")
		expect(ready).toBe(false)
		text, ready = IncubatorLabel.text("Busy", "BasicEgg", 100, nil, 100, name, short)
		expect(text).toBe("Ready!")
		expect(ready).toBe(true)
	end)

	it("is blank once the egg has hatched or the slot is locked", function()
		for _, state in { "Empty", "Locked" } do
			local text, ready = IncubatorLabel.text(state, nil, nil, nil, 100, name, short)
			expect(text).toBe("")
			expect(ready).toBe(false)
		end
	end)

	it("shows the unlock price on the next slot", function()
		local text = IncubatorLabel.text("Buyable", nil, nil, 2500, 100, name, short)
		expect(text).toBe("Unlock: 2500")
	end)
end)
