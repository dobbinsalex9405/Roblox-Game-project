--!strict
-- How the hatch reveal (client/HatchReveal) answers the player, from any
-- device: a tap or click, a gamepad's B button ("back"), or the Roblox menu
-- opening ("menu": Escape, or Back on Android). Like every other window
-- (CoreClient/Modal), the reveal can always be left without a pointer
-- (Studio gate on #175).
--
-- A tap or B cracks a wobbling egg at once, and closes the reveal once the
-- creature has shown for `grace` seconds; the menu skips the whole reveal,
-- hatches still queued included, so the menu is never left under it.
-- Pure, for the Lune tests.

local RevealInput = {}

export type Source = "tap" | "back" | "menu"
export type Action = "crack" | "close" | "skipAll"

local CRACK_AFTER = 0.15 -- seconds after the egg appears before a tap cracks it

function RevealInput.action(
	source: Source,
	phase: string,
	now: number,
	startedAt: number,
	shownAt: number,
	grace: number
): Action?
	if phase ~= "wobble" and phase ~= "shown" then
		return nil
	end
	if source == "menu" then
		return "skipAll"
	end
	if phase == "wobble" then
		return if now - startedAt > CRACK_AFTER then "crack" else nil
	end
	return if now - shownAt > grace then "close" else nil
end

return RevealInput
