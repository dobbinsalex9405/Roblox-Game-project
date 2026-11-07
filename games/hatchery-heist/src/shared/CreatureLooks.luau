--!strict
-- How each rarity tier moves and shines (the voxel style guide). The client's
-- CreatureView reads it; plain data so tests can check every tier has a row
-- and that the look only ever grows with rarity.
--
-- Fields:
--   bob        how far the body bobs, as a share of the creature's height
--   bobSpeed   bobs per second (radians per second / 2pi)
--   hover      lift off the ground, as a share of height (Legendary, Godly)
--   moves      which part animations play: head, ears, tail, wings, blink
--   light      a PointLight in the glow colour: range in studs, 0 = none
--   particles  sparkles per second around it, 0 = none
--   ring       a glowing rarity ring under its feet
--   orbit      glowing cubes circling it, 0 = none
--   pulse      glowing voxels breathe brighter and dimmer
--   shimmer    glowing voxels drift through the rainbow (Godly)
--   neon       how bright glowing voxels are, 1 = their full colour. The big
--              tiers have the most glowing voxels, so each glows less, or a
--              base of them washes out in bloom (Studio playtest, Nov 5)
--
-- The hatch reveal (client HatchReveal) grows with rarity too:
--   wobble     seconds the egg shakes before it cracks
--   rays       light rays turning behind the creature, 0 = none
--   confetti   confetti pieces when it appears, 0 = none
--   shake      how hard the screen shakes as it appears, in pixels
--   hold       seconds the reveal stays up before closing by itself

export type Look = {
	bob: number,
	bobSpeed: number,
	hover: number,
	moves: { head: boolean, ears: boolean, tail: boolean, wings: boolean, blink: boolean },
	light: number,
	particles: number,
	ring: boolean,
	orbit: number,
	pulse: boolean,
	shimmer: boolean,
	neon: number,
	wobble: number,
	rays: number,
	confetti: number,
	shake: number,
	hold: number,
}

local function moves(head: boolean, ears: boolean, tail: boolean, wings: boolean, blink: boolean)
	return { head = head, ears = ears, tail = tail, wings = wings, blink = blink }
end

local CreatureLooks: { [string]: Look } = {
	Common = {
		bob = 0.04,
		bobSpeed = 0.9,
		hover = 0,
		moves = moves(false, false, false, false, true),
		light = 0,
		particles = 0,
		ring = false,
		orbit = 0,
		pulse = false,
		shimmer = false,
		neon = 1,
		wobble = 1.0,
		rays = 0,
		confetti = 0,
		shake = 0,
		hold = 2.2,
	},
	Uncommon = {
		bob = 0.04,
		bobSpeed = 0.9,
		hover = 0,
		moves = moves(true, false, true, false, true),
		light = 0,
		particles = 0,
		ring = false,
		orbit = 0,
		pulse = false,
		shimmer = false,
		neon = 1,
		wobble = 1.2,
		rays = 0,
		confetti = 0,
		shake = 0,
		hold = 2.4,
	},
	Rare = {
		bob = 0.04,
		bobSpeed = 0.8,
		hover = 0,
		moves = moves(true, true, true, true, true),
		light = 0,
		particles = 0,
		ring = false,
		orbit = 0,
		pulse = false,
		shimmer = false,
		neon = 1,
		wobble = 1.5,
		rays = 8,
		confetti = 0,
		shake = 0,
		hold = 2.8,
	},
	["Ultra Rare"] = {
		bob = 0.04,
		bobSpeed = 0.8,
		hover = 0,
		moves = moves(true, true, true, true, true),
		light = 8,
		particles = 3,
		ring = false,
		orbit = 0,
		pulse = true,
		shimmer = false,
		neon = 1,
		wobble = 1.9,
		rays = 10,
		confetti = 0,
		shake = 0,
		hold = 3.2,
	},
	Epic = {
		bob = 0.035,
		bobSpeed = 0.7,
		hover = 0,
		moves = moves(true, true, true, true, true),
		light = 12,
		particles = 6,
		ring = true,
		orbit = 0,
		pulse = true,
		shimmer = false,
		neon = 0.85,
		wobble = 2.4,
		rays = 12,
		confetti = 40,
		shake = 0,
		hold = 3.6,
	},
	Legendary = {
		bob = 0.03,
		bobSpeed = 0.5,
		hover = 0.14,
		moves = moves(true, true, true, true, true),
		light = 14,
		particles = 14,
		ring = true,
		orbit = 0,
		pulse = true,
		shimmer = false,
		neon = 0.65,
		wobble = 3.2,
		rays = 16,
		confetti = 80,
		shake = 10,
		hold = 4.5,
	},
	Godly = {
		bob = 0.03,
		bobSpeed = 0.45,
		hover = 0.14,
		moves = moves(true, true, true, true, true),
		light = 16,
		particles = 22,
		ring = true,
		orbit = 8,
		pulse = true,
		shimmer = true,
		neon = 0.55,
		wobble = 4.0,
		rays = 20,
		confetti = 120,
		shake = 16,
		hold = 5.5,
	},
}

return CreatureLooks
