--!strict
-- Renders World boxes and labels into a Canvas: the view a player gets
-- from the spawn (perspective, Roblox's default camera), a top-down map and
-- a side cut through the spawn (orthographic). Flat-shaded boxes with a
-- depth buffer: no meshes, textures, terrain or lighting effects, but every
-- part where Roblox puts it, which is what the floor bug needed.

local Canvas = require("./Canvas")
local World = require("./World")

type Box = World.Box
type Label = World.Label
type Color = Canvas.Color

local Scene = {}

export type Camera = {
	kind: string, -- "perspective" or "ortho"
	-- Position (perspective eye, or ortho centre) and orthonormal basis.
	ex: number,
	ey: number,
	ez: number,
	rx: number,
	ry: number,
	rz: number,
	ux: number,
	uy: number,
	uz: number,
	fx: number,
	fy: number,
	fz: number,
	-- Perspective: vertical field of view in degrees. Ortho: pixels per stud.
	fov: number,
	scale: number,
	-- Ortho only: drop everything in front of the camera's plane (a cut).
	cut: boolean,
}

local SUN = { x = 0.35, y = 0.85, z = 0.4 }
do
	local l = math.sqrt(SUN.x ^ 2 + SUN.y ^ 2 + SUN.z ^ 2)
	SUN.x, SUN.y, SUN.z = SUN.x / l, SUN.y / l, SUN.z / l
end

local NEAR = 0.1

local function normalize(x: number, y: number, z: number): (number, number, number)
	local l = math.sqrt(x * x + y * y + z * z)
	if l < 1e-9 then
		return 0, 0, 0
	end
	return x / l, y / l, z / l
end

local function cross(
	ax: number,
	ay: number,
	az: number,
	bx: number,
	by: number,
	bz: number
): (number, number, number)
	return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
end

-- A perspective camera at (ex, ey, ez) looking at (tx, ty, tz).
function Scene.lookAt(
	ex: number,
	ey: number,
	ez: number,
	tx: number,
	ty: number,
	tz: number,
	fov: number
): Camera
	local fx, fy, fz = normalize(tx - ex, ty - ey, tz - ez)
	local rx, ry, rz = normalize(cross(fx, fy, fz, 0, 1, 0))
	if rx == 0 and ry == 0 and rz == 0 then
		rx, ry, rz = 1, 0, 0
	end
	local ux, uy, uz = cross(rx, ry, rz, fx, fy, fz)
	return {
		kind = "perspective",
		ex = ex,
		ey = ey,
		ez = ez,
		rx = rx,
		ry = ry,
		rz = rz,
		ux = ux,
		uy = uy,
		uz = uz,
		fx = fx,
		fy = fy,
		fz = fz,
		fov = fov,
		scale = 0,
		cut = false,
	}
end

-- An orthographic camera centred on (cx, cy, cz) looking along forward,
-- with `up` on screen, at `scale` pixels per stud.
function Scene.ortho(
	cx: number,
	cy: number,
	cz: number,
	forward: { number },
	up: { number },
	scale: number,
	cut: boolean
): Camera
	local fx, fy, fz = normalize(forward[1], forward[2], forward[3])
	local ux, uy, uz = normalize(up[1], up[2], up[3])
	local rx, ry, rz = cross(fx, fy, fz, ux, uy, uz)
	return {
		kind = "ortho",
		ex = cx,
		ey = cy,
		ez = cz,
		rx = rx,
		ry = ry,
		rz = rz,
		ux = ux,
		uy = uy,
		uz = uz,
		fx = fx,
		fy = fy,
		fz = fz,
		fov = 0,
		scale = scale,
		cut = cut,
	}
end

-- Camera-space coordinates of a world point: right, up, depth.
local function toView(cam: Camera, x: number, y: number, z: number): (number, number, number)
	local dx, dy, dz = x - cam.ex, y - cam.ey, z - cam.ez
	return dx * cam.rx + dy * cam.ry + dz * cam.rz,
		dx * cam.ux + dy * cam.uy + dz * cam.uz,
		dx * cam.fx + dy * cam.fy + dz * cam.fz
end

-- Screen position and depth value (larger is nearer) of a view-space point.
local function project(
	cam: Camera,
	c: Canvas.Canvas,
	vx: number,
	vy: number,
	vz: number
): (number, number, number)
	if cam.kind == "perspective" then
		local f = (c.height / 2) / math.tan(math.rad(cam.fov) / 2)
		return c.width / 2 + vx / vz * f, c.height / 2 - vy / vz * f, 1 / vz
	end
	return c.width / 2 + vx * cam.scale, c.height / 2 - vy * cam.scale, -vz
end

-- Screen position of a world point, or nil when it is behind the camera.
function Scene.toScreen(
	cam: Camera,
	c: Canvas.Canvas,
	x: number,
	y: number,
	z: number
): (number?, number?, number?)
	local vx, vy, vz = toView(cam, x, y, z)
	if (cam.kind == "perspective" or cam.cut) and vz <= NEAR then
		return nil, nil, nil
	end
	local sx, sy, d = project(cam, c, vx, vy, vz)
	return sx, sy, d
end

-- Clips a polygon (view space) to depth > NEAR.
local function clipNear(poly: { { number } }): { { number } }
	local out = {}
	local n = #poly
	for i = 1, n do
		local a = poly[i]
		local b = poly[i % n + 1]
		local aIn, bIn = a[3] > NEAR, b[3] > NEAR
		if aIn then
			table.insert(out, a)
		end
		if aIn ~= bIn then
			local t = (NEAR - a[3]) / (b[3] - a[3])
			table.insert(out, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, NEAR })
		end
	end
	return out
end

local FACES = {
	-- Corner sign triples per face (x, y, z), and the face's normal axis.
	{ corners = { { 1, -1, -1 }, { 1, 1, -1 }, { 1, 1, 1 }, { 1, -1, 1 } }, axis = "r", sign = 1 },
	{ corners = { { -1, -1, 1 }, { -1, 1, 1 }, { -1, 1, -1 }, { -1, -1, -1 } }, axis = "r", sign = -1 },
	{ corners = { { -1, 1, -1 }, { -1, 1, 1 }, { 1, 1, 1 }, { 1, 1, -1 } }, axis = "u", sign = 1 },
	{ corners = { { -1, -1, 1 }, { -1, -1, -1 }, { 1, -1, -1 }, { 1, -1, 1 } }, axis = "u", sign = -1 },
	{ corners = { { -1, -1, 1 }, { 1, -1, 1 }, { 1, 1, 1 }, { -1, 1, 1 } }, axis = "b", sign = 1 },
	{ corners = { { 1, -1, -1 }, { -1, -1, -1 }, { -1, 1, -1 }, { 1, 1, -1 } }, axis = "b", sign = -1 },
}

local function drawBox(
	c: Canvas.Canvas,
	cam: Camera,
	b: Box,
	alpha: number,
	writeDepth: boolean,
	cullBack: boolean
)
	for _, face in FACES do
		local nx, ny, nz
		if face.axis == "r" then
			nx, ny, nz = b.rx * face.sign, b.ry * face.sign, b.rz * face.sign
		elseif face.axis == "u" then
			nx, ny, nz = b.ux * face.sign, b.uy * face.sign, b.uz * face.sign
		else
			nx, ny, nz = b.bx * face.sign, b.by * face.sign, b.bz * face.sign
		end
		-- Face centre, to decide whether it faces the camera.
		local fcx = b.cx + nx * (if face.axis == "r" then b.hx elseif face.axis == "u" then b.hy else b.hz)
		local fcy = b.cy + ny * (if face.axis == "r" then b.hx elseif face.axis == "u" then b.hy else b.hz)
		local fcz = b.cz + nz * (if face.axis == "r" then b.hx elseif face.axis == "u" then b.hy else b.hz)
		local facing
		if cam.kind == "perspective" then
			facing = (cam.ex - fcx) * nx + (cam.ey - fcy) * ny + (cam.ez - fcz) * nz > 0
		else
			facing = -(cam.fx * nx + cam.fy * ny + cam.fz * nz) > 0
		end
		if facing or not cullBack then
			local light = 0.55 + 0.45 * math.max(0, nx * SUN.x + ny * SUN.y + nz * SUN.z)
			if not facing then
				light *= 0.6 -- inside of a cut part
			end
			local color = { r = b.color.r * light, g = b.color.g * light, b = b.color.b * light }
			local poly = {}
			for k = 1, 4 do
				local s = face.corners[k]
				local x = b.cx + b.rx * s[1] * b.hx + b.ux * s[2] * b.hy + b.bx * s[3] * b.hz
				local y = b.cy + b.ry * s[1] * b.hx + b.uy * s[2] * b.hy + b.by * s[3] * b.hz
				local z = b.cz + b.rz * s[1] * b.hx + b.uz * s[2] * b.hy + b.bz * s[3] * b.hz
				local vx, vy, vz = toView(cam, x, y, z)
				poly[k] = { vx, vy, vz }
			end
			if cam.kind == "perspective" or cam.cut then
				poly = clipNear(poly)
			end
			if #poly >= 3 then
				local pts = {}
				for k, p in poly do
					local sx, sy, d = project(cam, c, p[1], p[2], p[3])
					pts[k] = { sx, sy, d }
				end
				for k = 2, #pts - 1 do
					local p0, p1, p2 = pts[1], pts[k], pts[k + 1]
					Canvas.triangle(
						c,
						p0[1],
						p0[2],
						p0[3],
						p1[1],
						p1[2],
						p1[3],
						p2[1],
						p2[2],
						p2[3],
						color,
						alpha,
						writeDepth
					)
				end
			end
		end
	end
end

-- Draws boxes: solid ones first, then see-through ones far to near.
function Scene.drawBoxes(c: Canvas.Canvas, cam: Camera, boxes: { Box })
	local glass = {}
	for _, b in boxes do
		if b.transparency <= 0.02 then
			-- Only the top-down map culls back faces: a camera inside a part (a
			-- spawn buried in the ground) must see the part's inside.
			drawBox(c, cam, b, 1, true, cam.kind == "ortho" and not cam.cut)
		elseif b.transparency < 0.98 then
			table.insert(glass, b)
		end
	end
	table.sort(glass, function(a, b)
		local _, _, da = toView(cam, a.cx, a.cy, a.cz)
		local _, _, db = toView(cam, b.cx, b.cy, b.cz)
		return da > db
	end)
	for _, b in glass do
		drawBox(c, cam, b, 1 - b.transparency, false, true)
	end
end

local LABEL_BG = { r = 0.05, g = 0.05, b = 0.08 }
local WHITE = { r = 1, g = 1, b = 1 }
local PROMPT = { r = 1, g = 0.85, b = 0.2 }

-- Draws labels where a player would see them: hidden behind walls or the
-- ground unless the label is AlwaysOnTop, as in Roblox.
function Scene.drawLabels(c: Canvas.Canvas, cam: Camera, labels: { Label }, size: number)
	for _, l in labels do
		local sx, sy, d = Scene.toScreen(cam, c, l.x, l.y, l.z)
		if sx and sy and d and sx >= 0 and sy >= 0 and sx < c.width and sy < c.height then
			local visible = l.alwaysOnTop or Canvas.depthAt(c, sx, sy) <= d + math.abs(d) * 0.02
			if visible then
				local text = if l.kind == "Prompt" then `[E] {l.text}` else l.text
				if text ~= "" then
					-- A sign with several text lines: the first few, stacked.
					local lines = string.split(text, "\n")
					if #lines > 4 then
						lines = { lines[1], lines[2], lines[3], `(+{#lines - 3} more lines)` }
					end
					local w = 0
					for _, line in lines do
						w = math.max(w, Canvas.textWidth(line, size))
					end
					local lineH = size * 1.2
					local x0, y0 = sx - w / 2 - 3, sy - #lines * lineH / 2 - 2
					Canvas.fillRect(c, x0, y0, x0 + w + 6, y0 + #lines * lineH + 4, LABEL_BG, 0.55)
					for i, line in lines do
						Canvas.text(
							c,
							sx - Canvas.textWidth(line, size) / 2,
							y0 + 2 + (i - 1) * lineH,
							line,
							size,
							if l.kind == "Prompt" then PROMPT else WHITE
						)
					end
				end
			end
		end
	end
end

-- Roblox-style sky behind a perspective view.
function Scene.sky(c: Canvas.Canvas)
	for y = 0, c.height - 1 do
		local t = y / c.height
		Canvas.fillRect(c, 0, y, c.width, y + 1, { r = 0.45 + 0.3 * t, g = 0.65 + 0.2 * t, b = 0.95 }, 1)
	end
end

-- A blocky R15-sized stand-in for the player's character, feet at `feet`,
-- facing along (lx, lz).
function Scene.character(x: number, feet: number, z: number, lx: number, lz: number): { Box }
	local lxn, _, lzn = normalize(lx, 0, lz)
	-- Back axis is the opposite of where the character looks.
	local bx, bz = -lxn, -lzn
	local rx, rz = -bz, bx
	local function part(
		name: string,
		ox: number,
		oy: number,
		sx: number,
		sy: number,
		sz: number,
		color: Color
	): Box
		return {
			name = name,
			path = `Character.{name}`,
			className = "Part",
			cx = x + rx * ox,
			cy = feet + oy,
			cz = z + rz * ox,
			rx = rx,
			ry = 0,
			rz = rz,
			ux = 0,
			uy = 1,
			uz = 0,
			bx = bx,
			by = 0,
			bz = bz,
			hx = sx / 2,
			hy = sy / 2,
			hz = sz / 2,
			color = color,
			transparency = 0,
			canCollide = false,
			isGround = false,
			isSpawn = false,
			enabled = true,
		}
	end
	local skin = { r = 0.96, g = 0.8, b = 0.6 }
	local shirt = { r = 0.2, g = 0.45, b = 0.85 }
	local pants = { r = 0.2, g = 0.2, b = 0.3 }
	return {
		part("LeftLeg", -0.5, 1, 1, 2, 1, pants),
		part("RightLeg", 0.5, 1, 1, 2, 1, pants),
		part("Torso", 0, 3, 2, 2, 1, shirt),
		part("LeftArm", -1.5, 3, 1, 2, 1, shirt),
		part("RightArm", 1.5, 3, 1, 2, 1, shirt),
		part("Head", 0, 4.6, 1.2, 1.2, 1.2, skin),
	}
end

return Scene
