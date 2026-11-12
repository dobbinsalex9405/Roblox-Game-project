--!strict
-- Which egg the odds card beside the Buy prompt is about, as belt eggs ride
-- past (client/ConveyorView, client/Hud).
--
-- Every egg on the belt has its own Buy prompt, so standing at a stop the
-- prompts of passing eggs show and hide about twice a second, often a new
-- one showing before the old one hides. The card was rebuilt each time a
-- prompt showed, so a tap on its "See every creature" button could land on
-- a button just replaced and do nothing (issue #188: 2 to 4 tries in the
-- Studio gate). Now the card follows the most recently shown egg prompt
-- still up, hides only when none is, and is rebuilt only when the egg it is
-- about changes.

local PromptFocus = {}
PromptFocus.__index = PromptFocus

export type Action = { kind: "show", eggId: string } | { kind: "hide" }

export type Focus = typeof(setmetatable(
	{} :: {
		up: { { key: any, eggId: string } }, -- prompts up, oldest first
		current: string?,
	},
	PromptFocus
))

function PromptFocus.new(): Focus
	return setmetatable({ up = {}, current = nil }, PromptFocus)
end

-- What the card should do now, or nil to leave it as it is.
local function settle(self: Focus): Action?
	local top = self.up[#self.up]
	local want = if top then top.eggId else nil
	if want == self.current then
		return nil
	end
	self.current = want
	if want == nil then
		return { kind = "hide" }
	end
	return { kind = "show", eggId = want }
end

local function remove(self: Focus, key: any)
	for i = #self.up, 1, -1 do
		if self.up[i].key == key then
			table.remove(self.up, i)
		end
	end
end

-- A prompt (`key`, any value) for egg `eggId` showed.
function PromptFocus.shown(self: Focus, key: any, eggId: string): Action?
	remove(self, key)
	table.insert(self.up, { key = key, eggId = eggId })
	return settle(self)
end

-- A prompt hid.
function PromptFocus.hidden(self: Focus, key: any): Action?
	remove(self, key)
	return settle(self)
end

-- The egg the card is about, or nil while it is hidden.
function PromptFocus.egg(self: Focus): string?
	return self.current
end

return PromptFocus
