--!strict
-- What an incubator's floating label says, for every state. The client
-- writes the label every frame; it must also clear it, because once the
-- client has changed the text the server's blank never reaches it again.
--
-- Pure: names and numbers are formatted by the functions passed in.

local IncubatorLabel = {}

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Returns the label and whether the egg is ready to hatch.
function IncubatorLabel.text(
	state: string,
	eggId: string?,
	readyAt: number?,
	cost: number?,
	now: number,
	displayName: (string) -> string,
	shortNumber: (number) -> string
): (string, boolean)
	if state == "Busy" and eggId and readyAt then
		if readyAt <= now then
			return "Ready!", true
		end
		return `{displayName(eggId)} {clock(readyAt - now)}`, false
	elseif state == "Buyable" and cost then
		return `Unlock: {shortNumber(cost)}`, false
	end
	return "", false
end

return IncubatorLabel
