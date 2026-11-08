--!strict
-- A ScreenGui, SurfaceGui or BillboardGui in PlayerGui is destroyed on every
-- respawn unless ResetOnSpawn is false. The client builds its GUIs once and
-- keeps references to them, so a reset GUI leaves those references pointing at
-- destroyed instances: after a death the Egg Market odds signs went blank and
-- OddsView.renderSign errored on a nil Holder (Staging, Nov 8). Every GUI the
-- client creates therefore sets ResetOnSpawn = false (it does nothing on a GUI
-- parented into the world, so the rule holds for those too).
local fs = require("@lune/fs")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local CLIENT = "games/hatchery-heist/src/client"

-- Each `local <var> = Instance.new("<LayerCollector>")` in a file, with
-- whether the same file sets `<var>.ResetOnSpawn = false`.
local function layerCollectors(source: string): { { var: string, class: string, reset: boolean } }
	local found = {}
	local pattern = 'local%s+([%w_]+)%s*=%s*Instance%.new%("(%a+)"%)'
	local at = 1
	while true do
		local first, last, var, class = string.find(source, pattern, at)
		if first == nil then
			break
		end
		at = (last :: number) + 1
		if class == "ScreenGui" or class == "SurfaceGui" or class == "BillboardGui" then
			-- Only this declaration's scope: up to the next `local <var> =`.
			local nextDecl = string.find(source, `local%s+{var}%s*=`, at)
			local scope = string.sub(source, at, if nextDecl then nextDecl - 1 else #source)
			local reset = string.find(scope, `[^%w_]{var}%.ResetOnSpawn%s*=%s*false`) ~= nil
			table.insert(found, { var = var :: string, class = class :: string, reset = reset })
		end
	end
	return found
end

describe("Client GUIs survive a respawn", function()
	it("finds GUIs with or without the setting", function()
		local src = 'local g = Instance.new("SurfaceGui")\ng.ResetOnSpawn = false\n'
			.. 'local h = Instance.new("ScreenGui")\nlocal p = Instance.new("Part")\n'
			.. 'local g = Instance.new("BillboardGui")\n'
		local found = layerCollectors(src)
		expect(#found).toBe(3)
		expect(found[1].reset).toBe(true)
		expect(found[2].reset).toBe(false)
		-- A later GUI reusing the name does not borrow the earlier setting.
		expect(found[3].reset).toBe(false)
	end)

	it("sets ResetOnSpawn = false on every ScreenGui, SurfaceGui and BillboardGui", function()
		local missing = {}
		local total = 0
		local files = fs.readDir(CLIENT)
		table.sort(files)
		for _, name in files do
			if string.match(name, "%.luau$") then
				for _, gui in layerCollectors(fs.readFile(`{CLIENT}/{name}`)) do
					total += 1
					if not gui.reset then
						table.insert(missing, `{name}: {gui.var} ({gui.class})`)
					end
				end
			end
		end
		expect(total > 0).toBe(true)
		expect(table.concat(missing, ", ")).toBe("")
	end)
end)
