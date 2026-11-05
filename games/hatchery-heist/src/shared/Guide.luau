--!strict
-- The first-session guide: one goal at a time, from the first egg to the
-- fourth incubator, with the place to go. The client shows it as a line
-- under the coin bar and a beam to the target, so a new player always knows
-- what to do next. It follows the onboarding moments (Hatchery.ONBOARDING).
--
-- Pure: reads data, changes nothing. The client calls it a few times a
-- second.

local Hatchery = require("./Hatchery")

export type Target = {
	kind: "Belt" | "Incubator" | "CollectPad",
	slot: number?, -- for "Incubator"
}

export type Step = {
	id: string, -- stable name, for tests
	text: string,
	target: Target?,
}

local Guide = {}

-- `money` formats coins for display (Layout.shortNumber on the client).
function Guide.next(d: Hatchery.Data, economy: any, now: number, money: (number) -> string): Step?
	local firsts = d.firsts or {}
	if firsts.FirstSlot ~= nil then
		return nil
	end

	-- An egg in an incubator: hatch it when ready, otherwise wait.
	local ready: any = nil
	local soonest: any = nil
	for _, incubator in d.incubators do
		if incubator.readyAt <= now then
			if ready == nil or incubator.slot < ready.slot then
				ready = incubator
			end
		elseif soonest == nil or incubator.readyAt < soonest.readyAt then
			soonest = incubator
		end
	end

	if firsts.FirstEggBought == nil and #d.incubators == 0 then
		return {
			id = "BuyEgg",
			text = "Walk to the Egg Market in the middle and buy an egg",
			target = { kind = "Belt" },
		}
	end
	if ready then
		return {
			id = "Hatch",
			text = "Your egg is ready! Hatch it",
			target = { kind = "Incubator", slot = ready.slot },
		}
	end
	if firsts.FirstHatch == nil and soonest then
		local seconds = math.max(1, math.ceil(soonest.readyAt - now))
		return {
			id = "WaitHatch",
			text = `Your egg hatches in {seconds}s. Buy another while you wait!`,
			target = { kind = "Incubator", slot = soonest.slot },
		}
	end
	if firsts.FirstCollect == nil then
		return {
			id = "Collect",
			text = "Your creature is earning coins. Collect them at the green pad",
			target = { kind = "CollectPad" },
		}
	end
	local cost = Hatchery.nextSlotCost(d, economy)
	if cost == nil then
		return nil
	end
	if d.coins >= cost then
		return {
			id = "BuySlot",
			text = `Unlock another incubator for {money(cost)} coins`,
			target = { kind = "Incubator", slot = d.slots + 1 },
		}
	end
	return {
		id = "EarnForSlot",
		text = `Hatch more eggs and collect: {money(d.coins)} / {money(cost)} coins for a new incubator`,
		target = { kind = "Belt" },
	}
end

-- Whether to open the welcome screen on join: a brand-new save that has
-- never bought an egg.
function Guide.isNewPlayer(d: Hatchery.Data): boolean
	local firsts = d.firsts or {}
	local sessions = if type(d.meta) == "table" then d.meta.sessions or 0 else 0
	return firsts.FirstEggBought == nil and #d.incubators == 0 and #d.creatures == 0 and sessions <= 1
end

-- A ScreenGui as the side menu sees it: `windowVisible` is whether its own
-- window frame ("Window", or the feedback "Form") is showing, nil when it
-- has none (a top-bar button, the HUD).
export type Screen = { name: string, enabled: boolean, displayOrder: number, windowVisible: boolean? }

-- Whether a window (DisplayOrder 20 to 49) is open, so the side menu steps
-- aside (Studio gate, Nov 5). Only a window that is actually showing counts:
-- the Core Feedback and Shop buttons are always-enabled ScreenGuis in that
-- range, and counting them hid the menu for good (#112 gate).
function Guide.windowOpen(screens: { Screen }): boolean
	for _, s in screens do
		if s.enabled and s.windowVisible == true and s.displayOrder >= 20 and s.displayOrder < 50 then
			return true
		end
	end
	return false
end

return Guide
