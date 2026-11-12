--!strict
-- Keyboard and gamepad keys of the base's prompts that stand close together.
-- A trap spot is a few studs from the front incubators, and with every
-- prompt on E, pressing E at a ready egg could set a 5,000-coin snare
-- instead of hatching (Studio gate, Nov 5). Buying a trap has its own keys.
-- Names are Enum.KeyCode names (client/BaseView turns them into keys).

export type Keys = { keyboard: string, gamepad: string }

local PromptKeys: { [string]: Keys } = {
	Hatch = { keyboard = "E", gamepad = "ButtonX" },
	Snare = { keyboard = "F", gamepad = "DPadLeft" },
	Slime = { keyboard = "R", gamepad = "ButtonY" },
	-- On a placed creature: Ride is E, Make guard is R; Stash (pick it up
	-- into the inventory, Alex Nov 12) gets its own key.
	Ride = { keyboard = "E", gamepad = "ButtonX" },
	Guard = { keyboard = "R", gamepad = "ButtonY" },
	Stash = { keyboard = "Q", gamepad = "DPadRight" },
}

return PromptKeys
