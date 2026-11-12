--!strict
-- The name players see for an id: CamelCase words spaced out
-- ("BasicEgg" -> "Basic Egg"). An id whose words do not split cleanly on
-- capitals carries an explicit name here.

local NAMES: { [string]: string } = {
	WillOWisp = "Will-o'-Wisp",
}

local function displayName(id: string): string
	return NAMES[id] or (string.gsub(id, "(%l)(%u)", "%1 %2"))
end

return displayName
