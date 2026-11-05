--!strict
-- Short numbers for labels and buttons: 1234567 -> "1.23M", 25000 -> "25K",
-- 1500 -> "1.5K", 999 -> "999". At most two decimals and no trailing zeros
-- (the Studio gate, Nov 5: "25.00K coins" should read "25K coins").

local Numbers = {}

local UNITS: { { size: number, suffix: string } } = {
	{ size = 1e12, suffix = "T" },
	{ size = 1e9, suffix = "B" },
	{ size = 1e6, suffix = "M" },
	{ size = 1e3, suffix = "K" },
}

function Numbers.short(n: number): string
	for _, unit in UNITS do
		if math.abs(n) >= unit.size then
			local text = string.format("%.2f", n / unit.size)
			text = string.gsub(text, "%.?0+$", "")
			return text .. unit.suffix
		end
	end
	return tostring(math.floor(n))
end

return Numbers
