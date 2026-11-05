--!strict
-- Rojo project files: properties that `rojo build` silently drops must never
-- be used. A Baseplate placed with `Position` was built centred on Y = 0, its
-- top ten studs above every floor, so three games' maps were buried in the
-- ground on Staging (Nov 4). Place parts with `CFrame` instead.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

-- Not written into a built place file (they are derived from CFrame).
local DROPPED = { Position = true, Orientation = true, Rotation = true }

local function problems(node: { [string]: any }, path: string, out: { string })
	local props = node["$properties"]
	if type(props) == "table" then
		for key in props do
			if DROPPED[key] then
				table.insert(out, `{path}: "{key}" is dropped by rojo build; use "CFrame"`)
			end
		end
	end
	for key, child in node do
		if type(child) == "table" and string.sub(key, 1, 1) ~= "$" then
			problems(child, `{path}.{key}`, out)
		end
	end
end

describe("Rojo project files", function()
	it("place parts with CFrame, never with properties rojo build drops", function()
		local found: { string } = {}
		local checked = 0
		for _, name in fs.readDir("games") do
			local file = `games/{name}/default.project.json`
			if fs.isFile(file) then
				checked += 1
				problems(serde.decode("json", fs.readFile(file)).tree, file, found)
			end
		end
		expect(checked >= 4).toBe(true)
		expect(table.concat(found, "\n")).toBe("")
	end)

	it("flags a Position property", function()
		local found: { string } = {}
		problems(
			{ Workspace = { Baseplate = { ["$properties"] = { Position = { 0, -10, 0 } } } } },
			"x",
			found
		)
		expect(#found).toBe(1)
	end)
end)
