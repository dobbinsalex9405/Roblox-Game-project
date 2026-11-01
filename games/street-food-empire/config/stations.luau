--!strict
-- The twelve stations, four per district. Each one adds a dish to the menu:
-- counter customers order the whole menu, so their meal is worth the sum of
-- the prices of every finished station; a cook at a station sells that
-- station's dish on its own.
--
-- `levels[1]` is building the station; `levels[2]` and `levels[3]` are its
-- upgrades. `cost` is cash, `buildSeconds` how long the work takes, `price`
-- the cash the dish sells for at that level. A new station serves nothing
-- until it is built; an upgrading one keeps serving at its old level.
-- The starter station is given free (its level 1 cost is never charged).
return {
	-- Cart Corner
	{
		id = "HotDogCart",
		district = 1,
		levels = {
			{ cost = 1, buildSeconds = 0, price = 5 },
			{ cost = 60, buildSeconds = 10, price = 10 },
			{ cost = 300, buildSeconds = 30, price = 20 },
		},
	},
	{
		id = "LemonadeStand",
		district = 1,
		levels = {
			{ cost = 30, buildSeconds = 5, price = 4 },
			{ cost = 150, buildSeconds = 15, price = 8 },
			{ cost = 600, buildSeconds = 30, price = 16 },
		},
	},
	{
		id = "PretzelOven",
		district = 1,
		levels = {
			{ cost = 200, buildSeconds = 15, price = 10 },
			{ cost = 600, buildSeconds = 30, price = 20 },
			{ cost = 2000, buildSeconds = 60, price = 40 },
		},
	},
	{
		id = "FryStation",
		district = 1,
		levels = {
			{ cost = 800, buildSeconds = 30, price = 20 },
			{ cost = 2500, buildSeconds = 60, price = 40 },
			{ cost = 7000, buildSeconds = 120, price = 80 },
		},
	},

	-- Market Row
	{
		id = "TacoTruck",
		district = 2,
		levels = {
			{ cost = 4300, buildSeconds = 60, price = 50 },
			{ cost = 11000, buildSeconds = 120, price = 100 },
			{ cost = 25000, buildSeconds = 240, price = 200 },
		},
	},
	{
		id = "NoodleBar",
		district = 2,
		levels = {
			{ cost = 13000, buildSeconds = 90, price = 100 },
			{ cost = 31000, buildSeconds = 180, price = 200 },
			{ cost = 72000, buildSeconds = 360, price = 400 },
		},
	},
	{
		id = "DumplingSteamer",
		district = 2,
		levels = {
			{ cost = 36000, buildSeconds = 120, price = 200 },
			{ cost = 90000, buildSeconds = 240, price = 400 },
			{ cost = 220000, buildSeconds = 480, price = 800 },
		},
	},
	{
		id = "SmoothieBar",
		district = 2,
		levels = {
			{ cost = 100000, buildSeconds = 180, price = 400 },
			{ cost = 250000, buildSeconds = 300, price = 800 },
			{ cost = 600000, buildSeconds = 600, price = 1600 },
		},
	},

	-- Downtown
	{
		id = "PizzaOven",
		district = 3,
		levels = {
			{ cost = 600000, buildSeconds = 300, price = 1000 },
			{ cost = 1500000, buildSeconds = 600, price = 2000 },
			{ cost = 3600000, buildSeconds = 900, price = 4000 },
		},
	},
	{
		id = "BarbecuePit",
		district = 3,
		levels = {
			{ cost = 1800000, buildSeconds = 420, price = 2000 },
			{ cost = 4400000, buildSeconds = 720, price = 4000 },
			{ cost = 11000000, buildSeconds = 1200, price = 8000 },
		},
	},
	{
		id = "SushiCounter",
		district = 3,
		levels = {
			{ cost = 5600000, buildSeconds = 600, price = 4000 },
			{ cost = 13000000, buildSeconds = 900, price = 8000 },
			{ cost = 32000000, buildSeconds = 1500, price = 16000 },
		},
	},
	{
		id = "DessertCafe",
		district = 3,
		levels = {
			{ cost = 16000000, buildSeconds = 900, price = 8000 },
			{ cost = 40000000, buildSeconds = 1200, price = 16000 },
			{ cost = 100000000, buildSeconds = 1800, price = 32000 },
		},
	},
}
