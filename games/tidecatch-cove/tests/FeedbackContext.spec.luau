--!strict
local DataTemplate = require("../src/shared/DataTemplate")
local Feedback = require("@core/Feedback")
local FeedbackContext = require("../src/shared/FeedbackContext")
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

describe("FeedbackContext", function()
	it("describes a new player in at most 12 simple values the core keeps unchanged", function()
		local context = FeedbackContext.from(Util.deepCopy(DataTemplate.template), 1793520000)
		local count = 0
		for _, value in context do
			count += 1
			expect(type(value) == "number" or type(value) == "boolean").toBe(true)
		end
		expect(count >= 6).toBe(true)
		expect(count <= 12).toBe(true)
		expect(Feedback.sanitizeContext(context)).toEqual(context)
	end)

	it("never fails on missing or partial data", function()
		local context = FeedbackContext.from({}, 0)
		expect(Feedback.sanitizeContext(context)).toEqual(context)
	end)
end)
