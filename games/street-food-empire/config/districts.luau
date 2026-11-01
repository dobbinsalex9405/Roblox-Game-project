--!strict
-- The three districts a restaurant grows through, in unlock order. The first
-- is open from the start (cost 0). Each district adds station spots and foot
-- traffic: customers per minute add up across unlocked districts.
return {
	{ id = "CartCorner", cost = 0, spots = 4, customersPerMinute = 12 },
	{ id = "MarketRow", cost = 8000, spots = 4, customersPerMinute = 8 },
	{ id = "Downtown", cost = 500000, spots = 4, customersPerMinute = 10 },
}
