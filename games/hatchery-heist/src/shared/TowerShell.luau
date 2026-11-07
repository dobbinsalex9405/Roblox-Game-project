--!strict
-- Which apartment-shell pieces a tower draws (client/TowerShellView), as a
-- pure function so the tests check it: for each built storey its floor,
-- back, left, right and front (WorldArt TowerFloor n ... TowerFront n), and
-- the roof one storey above the top. Every piece shares one anchor: the
-- base's centre at its storey's walking height (tools/art/world/tower.py).

local TowerShell = {}

export type Piece = {
	prop: string, -- the WorldArt prop
	storey: number, -- placed at this storey's walking height (Layout.floorTop)
	lift: number, -- studs above it
}

local SIDES = { "Floor", "Back", "Left", "Right", "Front" }

-- The ground storey's floor art sits this far above the base's own floor
-- part, whose top is at the same height, so the two never flicker.
TowerShell.GROUND_LIFT = 0.04

-- Storeys to draw for a plot's TowerFloors attribute: the floors built, and
-- one for a base nobody owns (0 or no attribute), so every lot shows a
-- ground-floor apartment.
function TowerShell.storeys(attribute: any, maxFloors: number): number
	local n = if type(attribute) == "number" then math.floor(attribute) else 0
	return math.clamp(n, 1, maxFloors)
end

-- Whether to draw a box whose top is `top` studs above its storey's walking
-- height. On the ground storey a box wholly below the walking height would
-- sit inside the base's own floor part, or under the ground, so it is left out.
function TowerShell.drawn(storey: number, top: number): boolean
	return storey > 1 or top > 0
end

function TowerShell.pieces(storeys: number): { Piece }
	local out: { Piece } = {}
	for storey = 1, storeys do
		for _, side in SIDES do
			table.insert(out, {
				prop = `Tower{side}{storey}`,
				storey = storey,
				lift = if storey == 1 and side == "Floor" then TowerShell.GROUND_LIFT else 0,
			})
		end
	end
	table.insert(out, { prop = "TowerRoof", storey = storeys + 1, lift = 0 })
	return out
end

return TowerShell
