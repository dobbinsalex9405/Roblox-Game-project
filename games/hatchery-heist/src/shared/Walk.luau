--!strict
-- How a creature wanders its spot on a tower floor and how its body moves
-- while it walks (Alex, Nov 5: "I want the creatures to actually walk, not
-- just tilt side to side"). Pure maths, shared so it is tested; the client
-- (CreatureView) moves the stand-in and poses the joints from it.
--
-- Where: each creature wanders its own cell, the spots it takes on its floor
-- (10 studs a spot, `Walk.range`), so two creatures never walk into each
-- other and a raider's Steal prompt on the pad stays next to it. The server
-- never moves anything: placement, raids and income ignore the wandering.
--
-- When: a fixed schedule from the creature's uid and the server clock, so
-- every player sees it at the same place. Each `segmentSeconds` it turns
-- toward a new point in its cell, walks there, and stands; after a long
-- stand it turns to face the yard, so players see its face.
--
-- How: one gait per species (CreatureMeshes.gait, set from its legs by the
-- art tools): trot (four legs in diagonal pairs), waddle (two legs and a
-- roll), hop, scuttle (bug legs in two sets of three), slither (a body wave)
-- hover (a lean, faster wing beats and dangling legs) and swim (a tail
-- sweep and paddling fins, for fish). A creature whose parts have no legs
-- (some voxel stand-ins) bounces its body in time with the steps.

local Walk = {}

export type Config = {
	speed: number, -- studs per second while walking
	segmentSeconds: number, -- one turn, walk and stand
	turnSeconds: number, -- turning on the spot before a walk
	faceFrontAfter: number, -- stand this long, then turn to the yard
	margin: number, -- studs kept clear of the cell's edge
	cullStuds: number, -- your own tower's creatures farther than this are not drawn
	cullOtherStuds: number, -- other players' tower creatures farther than this are not drawn
	animateOtherStuds: number, -- other players' tower creatures hold still beyond this
}

export type Gait = "trot" | "waddle" | "hop" | "scuttle" | "slither" | "hover" | "swim"

Walk.GAITS = { "trot", "waddle", "hop", "scuttle", "slither", "hover", "swim" } :: { Gait }

-- Studs moved per full step cycle, as a share of the creature's height.
local STRIDE: { [Gait]: number } = {
	trot = 0.9,
	waddle = 0.5,
	hop = 0.8,
	scuttle = 0.4,
	slither = 1.2,
	hover = 1.0,
	swim = 1.0,
}

-- 32-bit FNV-1a of a string: the creature's own seed.
function Walk.seed(uid: string): number
	local h = 2166136261
	for i = 1, #uid do
		h = bit32.bxor(h, string.byte(uid, i))
		h = (h * 16777619) % 4294967296
	end
	return h
end

-- A repeatable number in [0, 1) for (seed, n).
local function noise(seed: number, n: number): number
	local h = bit32.bxor(seed, (n * 2654435761) % 4294967296)
	h = bit32.bxor(h, bit32.rshift(h, 15))
	h = (h * 2246822519) % 4294967296
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = (h * 3266489917) % 4294967296
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h / 4294967296
end

-- How far from its cell's centre a creature may stand, in studs, along the
-- floor's row (x) and across it (z). `spots`: spots it takes (1 to 3);
-- `along`: its size along the row in studs; `across`: across it (the same
-- as `along` for a creature that turns freely).
function Walk.range(spots: number, along: number, margin: number, across: number?): (number, number)
	local rx = math.max(0, (spots * 10 - along) / 2 - margin)
	local rz = math.max(0, (10 - (across or along)) / 2 - margin)
	return rx, rz
end

-- A creature too long for a spot's 10-stud depth (the Clockwork Leviathan,
-- the Cosmic Whale: Godlies take three spots, 30 studs along the row) lies
-- along its floor's row instead of turning freely (Godly thread, Nov 5).
-- `width` and `depth` are its drawn size across and along its facing (art
-- faces -Z). Returns the yaw it keeps, or nil for a creature that fits any
-- way round:
--   * pi/2: longer nose to tail than the depth allows; it keeps side-on
--     and paces up and down the row, never turning end for end (turning on
--     the spot would sweep its length across the spots in front and behind);
--   * 0: wider than the depth allows; it faces the yard and sidesteps.
function Walk.lie(width: number, depth: number, margin: number): number?
	local room = 10 - 2 * margin
	if depth > room and depth >= width then
		return math.pi / 2
	elseif width > room then
		return 0
	end
	return nil
end

-- The elevator shaft fills each floor's back-left corner (base x -24..-17,
-- z 17..24), 3 studs into the cell of spot 5 (back row, left column). A
-- creature whose cell starts there wanders 3 studs less on that side and
-- that end, so it never walks into the shaft.
local SHAFT_SPOT = 5
local SHAFT_CUT = 3

-- A creature's wander area on its floor: the centre's offset from where it
-- stands (along the row, across it) and the half-ranges, for one starting
-- on pad `pad` (counted across the tower) and taking `spots` spots.
function Walk.cell(
	pad: number,
	spots: number,
	along: number,
	margin: number,
	across: number?
): (number, number, number, number)
	local rx, rz = Walk.range(spots, along, margin, across)
	if (pad - 1) % 8 + 1 ~= SHAFT_SPOT then
		return 0, 0, rx, rz
	end
	local half = SHAFT_CUT / 2
	return half, -half, math.max(0, rx - half), math.max(0, rz - half)
end

-- The yaw (about Y) that faces a creature drawn facing -Z along (dx, dz).
function Walk.yawOf(dx: number, dz: number): number
	return math.atan2(-dx, -dz)
end

local function lerpAngle(a: number, b: number, u: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * u
end

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

type Segment = {
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	startYaw: number,
	walkYaw: number,
	walkSeconds: number,
	restYaw: number,
	faceFront: boolean,
}

local function waypoint(seed: number, k: number, rx: number, rz: number): (number, number)
	return (noise(seed, k * 2) * 2 - 1) * rx, (noise(seed, k * 2 + 1) * 2 - 1) * rz
end

-- Segment k's plan. Each segment's rest yaw is the next one's start, so the
-- creature never snaps round; segment k - 1 is planned without its own
-- start, which only its turn uses.
local function plan(
	seed: number,
	k: number,
	rx: number,
	rz: number,
	cfg: Config,
	startYaw: number?,
	lie: number?
): Segment
	if lie then
		rz = 0 -- it keeps to the row's centreline
	end
	local fx, fz = waypoint(seed, k - 1, rx, rz)
	local tx, tz = waypoint(seed, k, rx, rz)
	local dx, dz = tx - fx, tz - fz
	local distance = math.sqrt(dx * dx + dz * dz)
	-- A creature lying along its row keeps its heading (Walk.lie).
	local walkYaw = if lie then lie elseif distance > 1e-3 then Walk.yawOf(dx, dz) else (startYaw or 0)
	local free = cfg.segmentSeconds - cfg.turnSeconds
	local walkSeconds = math.min(distance / cfg.speed, free * 0.7)
	local stand = free - walkSeconds
	-- A creature lying along its row never turns to face the yard: across
	-- the row it would reach into the spots in front and behind.
	local faceFront = lie == nil and stand >= cfg.faceFrontAfter + cfg.turnSeconds
	return {
		fromX = fx,
		fromZ = fz,
		toX = tx,
		toZ = tz,
		startYaw = startYaw or walkYaw,
		walkYaw = walkYaw,
		walkSeconds = walkSeconds,
		restYaw = if faceFront then 0 else walkYaw,
		faceFront = faceFront,
	}
end

export type State = {
	x: number, -- studs from the cell's centre, along the row
	z: number, -- studs from the cell's centre, across the row
	yaw: number, -- radians; 0 faces the yard
	moving: number, -- 0 standing to 1 walking, eased at both ends
	travelled: number, -- studs walked in this segment, for the step phase
}

-- Where the creature with `seed` is at server time `now`, in a cell of
-- half-size (rx, rz); `lie` from Walk.lie for a creature lying along its row.
function Walk.at(seed: number, rx: number, rz: number, now: number, cfg: Config, lie: number?): State
	local D = cfg.segmentSeconds
	local offset = noise(seed, 999983) * D
	local clock = now + offset
	local k = math.floor(clock / D)
	local u = clock - k * D
	local previous = plan(seed, k - 1, rx, rz, cfg, nil, lie)
	local seg = plan(seed, k, rx, rz, cfg, previous.restYaw, lie)
	local T = cfg.turnSeconds
	if u < T then
		return {
			x = seg.fromX,
			z = seg.fromZ,
			yaw = lerpAngle(seg.startYaw, seg.walkYaw, smooth(u / T)),
			moving = 0,
			travelled = 0,
		}
	end
	local w = u - T
	local dx, dz = seg.toX - seg.fromX, seg.toZ - seg.fromZ
	local distance = math.sqrt(dx * dx + dz * dz)
	if w < seg.walkSeconds then
		local p = smooth(w / seg.walkSeconds)
		-- Ease in and out over a quarter of a second at each end.
		local ramp = math.min(1, w / 0.25, (seg.walkSeconds - w) / 0.25)
		return {
			x = seg.fromX + dx * p,
			z = seg.fromZ + dz * p,
			yaw = seg.walkYaw,
			moving = math.clamp(ramp, 0, 1),
			travelled = distance * p,
		}
	end
	local stood = w - seg.walkSeconds
	local yaw = seg.walkYaw
	if seg.faceFront and stood > cfg.faceFrontAfter then
		yaw = lerpAngle(seg.walkYaw, 0, smooth((stood - cfg.faceFrontAfter) / T))
	end
	return { x = seg.toX, z = seg.toZ, yaw = yaw, moving = 0, travelled = distance }
end

-- The step phase in cycles for `travelled` studs at height `height`.
function Walk.phase(gait: Gait, travelled: number, height: number): number
	return travelled / math.max(0.2, (STRIDE[gait] or 1) * height)
end

-- The gait for a species: CreatureMeshes' when it has one, else from the
-- leg parts it has, else a trot (a body bounce when it has no legs).
function Walk.gaitOf(given: string?, anims: { [string]: boolean }, hovers: boolean): Gait
	if given and STRIDE[given :: Gait] then
		return given :: Gait
	end
	if hovers then
		return "hover"
	end
	if anims.leg1L or anims.leg1R then
		return "scuttle"
	end
	if anims.legL or anims.legR then
		return "waddle"
	end
	return "trot"
end

local LEG_SETS: { [string]: number } = {
	-- +1 swings with the first beat, -1 against it. Bug legs alternate down
	-- each side (left 1, 3, 5 with right 2, 4, 6), so six legs walk as two
	-- tripods and a spider's eight as two sets of four.
	legFL = 1,
	legBR = 1,
	legFR = -1,
	legBL = -1,
	legL = 1,
	legR = -1,
	leg1L = 1,
	leg2R = 1,
	leg3L = 1,
	leg4R = 1,
	leg5L = 1,
	leg6R = 1,
	leg1R = -1,
	leg2L = -1,
	leg3R = -1,
	leg4L = -1,
	leg5R = -1,
	leg6L = -1,
}

-- Gaits whose numbered (sideways) legs swing about Y; hop and hover keep
-- their own leg poses.
local SIDEWAYS_GAITS: { [string]: boolean } = { scuttle = true, trot = true, waddle = true }

-- Bug, crab and spider legs (leg1L..leg6R) stick out sideways, so they swing
-- about the vertical axis; +1 for the right side, -1 for the left, so both
-- reach forward on a positive swing.
local function sideways(anim: string): number?
	if string.match(anim, "^leg%d[LR]$") then
		return if string.sub(anim, -1) == "R" then 1 else -1
	end
	return nil
end

function Walk.isLeg(anim: string): boolean
	return LEG_SETS[anim] ~= nil
end

export type Pose = {
	rx: number, -- radians about X (pitch, legs swing)
	ry: number, -- radians about Y (yaw)
	rz: number, -- radians about Z (roll)
	dx: number, -- studs sideways
	dy: number, -- studs up
}

local STILL: Pose = { rx = 0, ry = 0, rz = 0, dx = 0, dy = 0 }

-- How far a foot rises when its leg swings out by `angle`, for a leg about a
-- third of the creature's height: the body drops this much to stay planted.
local LEG_SHARE = 0.3
local function dip(h: number, angle: number): number
	return h * LEG_SHARE * (1 - math.cos(angle))
end

-- A hop spends this share of its cycle in the air, the rest crouched.
local HOP_AIR = 0.6
local function hopArc(phase: number): number
	local u = phase % 1
	return if u < HOP_AIR then math.sin(u / HOP_AIR * math.pi) else 0
end

-- A joint's walking pose: `phase` in step cycles, `moving` 0 to 1, `h` the
-- creature's height, `legged` whether the creature has leg parts. Wings use
-- `Walk.wingRate` instead. Returns STILL for joints the gait leaves alone.
function Walk.pose(gait: Gait, anim: string, phase: number, moving: number, h: number, legged: boolean): Pose
	if moving <= 0 then
		return STILL
	end
	local a = phase * 2 * math.pi
	local s = math.sin(a)
	local side = LEG_SETS[anim]
	if side then
		local out = sideways(anim)
		if out and SIDEWAYS_GAITS[gait] then
			-- Swing forward and back about the hip, lifting the foot (a roll
			-- that raises the leg's outer end) while it swings forward.
			local lift = math.max(0, side * math.cos(a))
			return {
				rx = 0,
				ry = 0.45 * moving * side * s * out,
				rz = 0.3 * moving * lift * out,
				dx = 0,
				dy = 0,
			}
		end
		if gait == "trot" then
			return { rx = 0.55 * moving * side * s, ry = 0, rz = 0, dx = 0, dy = 0 }
		elseif gait == "waddle" then
			return { rx = 0.6 * moving * side * s, ry = 0, rz = 0, dx = 0, dy = 0 }
		elseif gait == "scuttle" then
			return { rx = 0.4 * moving * side * s, ry = 0, rz = 0, dx = 0, dy = 0 }
		elseif gait == "hop" then
			-- Legs push back on take-off and tuck in the air.
			return { rx = -0.7 * moving * hopArc(phase), ry = 0, rz = 0, dx = 0, dy = 0 }
		elseif gait == "hover" then
			-- Off the ground: legs trail back and paddle a little.
			return { rx = moving * (-0.3 + 0.12 * side * s), ry = 0, rz = 0, dx = 0, dy = 0 }
		end
		return STILL
	end
	-- A mesh with no leg parts (most of today's creature meshes) can't swing
	-- legs, so it walks with its whole body: it rocks from foot to foot,
	-- nods, bounces each step and swings its tail and ears, so it never
	-- reads as gliding (Studio gate, Nov 5).
	local steps = gait == "trot" or gait == "waddle" or gait == "scuttle"
	if not legged and steps then
		local rock = if gait == "waddle" then 0.2 elseif gait == "scuttle" then 0.08 else 0.15
		local rate = if gait == "scuttle" then 2 else 1
		local step = math.sin(a * rate)
		local twice = math.sin(2 * a * rate)
		local bounce = (1 - math.cos(2 * a * rate)) / 2
		if anim == "body" then
			return {
				rx = 0.07 * moving * twice,
				ry = 0.06 * moving * step,
				rz = rock * moving * step,
				dx = 0,
				dy = h * 0.07 * moving * bounce,
			}
		elseif anim == "head" then
			-- Nods with each step and leans against the rock, staying nearly level.
			return { rx = 0.12 * moving * twice, ry = 0, rz = -0.6 * rock * moving * step, dx = 0, dy = 0 }
		elseif anim == "tail" then
			return { rx = 0, ry = 0.45 * moving * math.sin(a * rate - 0.8), rz = 0, dx = 0, dy = 0 }
		elseif anim == "ears" then
			return { rx = 0.18 * moving * math.max(0, twice), ry = 0, rz = 0, dx = 0, dy = 0 }
		end
		return STILL
	end
	if anim == "body" then
		if gait == "trot" then
			-- Legs swung out reach less far down, so the body dips as they
			-- spread and rises as they pass under it, twice a cycle. A
			-- legless stand-in bounces instead, so its steps still read.
			local pitch = 0.04 * moving * math.sin(2 * a)
			if legged then
				return { rx = pitch, ry = 0, rz = 0, dx = 0, dy = -dip(h, 0.55 * moving * s) }
			end
			local bounce = (1 - math.cos(2 * a)) / 2
			return { rx = pitch, ry = 0, rz = 0, dx = 0, dy = h * 0.08 * moving * bounce }
		elseif gait == "waddle" then
			local dy = if legged
				then -dip(h, 0.6 * moving * s)
				else h * 0.04 * moving * (1 - math.cos(2 * a)) / 2
			return { rx = 0, ry = 0.06 * moving * s, rz = 0.14 * moving * s, dx = 0, dy = dy }
		elseif gait == "hop" then
			-- Crouch nose down, spring up nose first, land.
			local u = phase % 1
			-- One smooth pitch through the whole cycle: nose up in the air, back
			-- down through the crouch.
			local pitch = if u < HOP_AIR
				then -0.25 * math.cos(u / HOP_AIR * math.pi)
				else 0.25 * math.cos((u - HOP_AIR) / (1 - HOP_AIR) * math.pi)
			return { rx = pitch * moving, ry = 0, rz = 0, dx = 0, dy = h * 0.35 * moving * hopArc(phase) }
		elseif gait == "scuttle" then
			local jitter = (1 - math.cos(4 * a)) / 2
			return { rx = 0, ry = 0.06 * moving * s, rz = 0, dx = 0, dy = h * 0.015 * moving * jitter }
		elseif gait == "slither" then
			-- Worms, slugs, snails and caterpillars creep: a gentle sway and a
			-- small surge each stride (a bigger swing spins a short body round).
			local surge = (1 - math.cos(2 * a)) / 2
			return {
				rx = 0,
				ry = 0.1 * moving * s,
				rz = 0,
				dx = h * 0.04 * moving * s,
				dy = h * 0.02 * moving * surge,
			}
		elseif gait == "hover" then
			return { rx = -0.14 * moving, ry = 0, rz = 0.05 * moving * s, dx = 0, dy = h * 0.06 * moving }
		elseif gait == "swim" then
			-- The body sways against the tail.
			return { rx = 0, ry = -0.12 * moving * s, rz = 0, dx = h * 0.03 * moving * s, dy = 0 }
		end
	elseif anim == "head" then
		if gait == "waddle" then
			-- A bird's head pecks forward each step.
			return { rx = 0.12 * moving * math.max(0, math.sin(2 * a)), ry = 0, rz = 0, dx = 0, dy = 0 }
		elseif gait == "slither" then
			return { rx = 0, ry = -0.12 * moving * s, rz = 0, dx = 0, dy = 0 }
		end
	elseif anim == "tail" then
		if gait == "slither" then
			return { rx = 0, ry = 0.5 * moving * math.sin(a - 1.2), rz = 0, dx = 0, dy = 0 }
		elseif gait == "swim" then
			return { rx = 0, ry = 0.55 * moving * math.sin(a - 0.8), rz = 0, dx = 0, dy = 0 }
		elseif gait == "hover" then
			-- a flyer's tail streams and sways behind it
			return { rx = 0.1 * moving, ry = 0.25 * moving * math.sin(a - 0.8), rz = 0, dx = 0, dy = 0 }
		end
	elseif anim == "wingL" or anim == "wingR" then
		if gait == "waddle" then
			-- Folded wings flick out a little on every step, for balance.
			local flick = 0.18 * moving * (1 - math.cos(2 * a)) / 2
			return { rx = 0, ry = 0, rz = if anim == "wingL" then flick else -flick, dx = 0, dy = 0 }
		end
	elseif anim == "finL" or anim == "finR" then
		if gait == "swim" then
			-- Fins paddle in turn, out and back.
			local paddle = 0.4 * moving * math.sin(a + (if anim == "finL" then 0 else math.pi))
			return { rx = 0, ry = 0, rz = if anim == "finL" then paddle else -paddle, dx = 0, dy = 0 }
		end
	end
	return STILL
end

-- Wing beats per second times this while moving (hovering flyers work
-- harder to travel).
function Walk.wingRate(gait: Gait, moving: number): number
	return 1 + (if gait == "hover" then 0.8 else 0.3) * moving
end

-- Which floor (1 up) a height in studs above the ground floor's deck is on.
function Walk.floorAt(above: number, floorHeight: number): number
	return math.max(1, math.floor((above + 1) / floorHeight) + 1)
end

-- Whether a tower creature is left undrawn: only by distance, so every
-- floor of a tower near you shows (Studio gate, Nov 5: culling by floor left
-- whole floors looking empty). Other players' towers stop sooner: four full
-- neighbours cost a phone 20 fps.
function Walk.culled(distance: number, own: boolean, config: Config): boolean
	return distance > (if own then config.cullStuds else config.cullOtherStuds)
end

-- The joint a part animates as. Exported meshes tag many heads, tails and
-- ears "static" (they don't move standing still), but they still nod and
-- swing while walking, so a static part named head, tail or ears walks as
-- one (Studio gate, Nov 5: those parts stayed at 0 degrees).
local WALKS_BY_NAME: { [string]: boolean } = { head = true, tail = true, ears = true }
function Walk.role(name: string, anim: string): string
	if name == "body" then
		return "body"
	end
	if anim == "static" and WALKS_BY_NAME[name] then
		return name
	end
	return anim
end

return Walk
