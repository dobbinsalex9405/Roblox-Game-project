--!strict
-- Every block the mine can contain. `hp` is how much pick power it takes to
-- break; `value` is what one piece sells for at camp (0 = plain rock, which
-- breaks but never goes in the pack). Colors and materials are grey-box
-- placeholders until art comes after the gate.
return {
	-- Layer 1: Clay Shallows
	Clay = { hp = 2, value = 0, color = { 150, 110, 80 }, material = "Slate" },
	Coal = { hp = 3, value = 2, color = { 40, 40, 45 }, material = "Slate" },
	Copper = { hp = 4, value = 5, color = { 200, 120, 70 }, material = "Metal" },
	Quartz = { hp = 6, value = 20, color = { 235, 235, 245 }, material = "Glass" },
	-- Layer 2: Ironroot Caverns
	Slate = { hp = 8, value = 0, color = { 90, 95, 105 }, material = "Slate" },
	Iron = { hp = 9, value = 12, color = { 160, 140, 130 }, material = "Metal" },
	Silver = { hp = 11, value = 25, color = { 200, 205, 215 }, material = "Metal" },
	Jade = { hp = 14, value = 60, color = { 60, 180, 110 }, material = "Glass" },
	-- Layer 3: Ember Deep
	Basalt = { hp = 20, value = 0, color = { 50, 40, 40 }, material = "Basalt" },
	Gold = { hp = 22, value = 45, color = { 240, 200, 60 }, material = "Metal" },
	Cobalt = { hp = 26, value = 80, color = { 60, 90, 220 }, material = "Metal" },
	Sapphire = { hp = 32, value = 200, color = { 40, 60, 200 }, material = "Glass" },
	Emberite = { hp = 40, value = 600, color = { 255, 90, 30 }, material = "Neon" },
}
