--!strict
-- A small software canvas for the audit renders: an RGB pixel buffer with a
-- depth buffer, filled triangles with depth testing, blended rectangles and
-- bitmap text. Saved as PNG (Png.luau).

local Font = require("./Font")
local Png = require("./Png")

export type Color = { r: number, g: number, b: number } -- 0..1

export type Canvas = {
	width: number,
	height: number,
	rgb: buffer,
	depth: buffer,
	-- Optional clip rectangle for fillRect and text: x0, y0, x1, y1.
	clip: { number }?,
}

local Canvas = {}

local FAR = -1e30

local function clamp01(v: number): number
	if v < 0 then
		return 0
	elseif v > 1 then
		return 1
	end
	return v
end

function Canvas.new(width: number, height: number, background: Color?): Canvas
	local c: Canvas = {
		width = width,
		height = height,
		rgb = buffer.create(width * height * 3),
		depth = buffer.create(width * height * 4),
		clip = nil,
	}
	Canvas.clearDepth(c)
	local bg = background or { r = 0, g = 0, b = 0 }
	Canvas.fillRect(c, 0, 0, width, height, bg, 1)
	return c
end

function Canvas.clearDepth(c: Canvas)
	for i = 0, c.width * c.height - 1 do
		buffer.writef32(c.depth, i * 4, FAR)
	end
end

local function blendPixel(c: Canvas, i: number, r: number, g: number, b: number, a: number)
	local o = i * 3
	if a >= 1 then
		buffer.writeu8(c.rgb, o, r)
		buffer.writeu8(c.rgb, o + 1, g)
		buffer.writeu8(c.rgb, o + 2, b)
	else
		local ia = 1 - a
		buffer.writeu8(c.rgb, o, math.floor(buffer.readu8(c.rgb, o) * ia + r * a + 0.5))
		buffer.writeu8(c.rgb, o + 1, math.floor(buffer.readu8(c.rgb, o + 1) * ia + g * a + 0.5))
		buffer.writeu8(c.rgb, o + 2, math.floor(buffer.readu8(c.rgb, o + 2) * ia + b * a + 0.5))
	end
end

local function bytes(color: Color): (number, number, number)
	return math.floor(clamp01(color.r) * 255 + 0.5),
		math.floor(clamp01(color.g) * 255 + 0.5),
		math.floor(clamp01(color.b) * 255 + 0.5)
end

-- Fills [x0, x1) x [y0, y1) in pixel coordinates (rounded), blended with alpha.
function Canvas.fillRect(
	c: Canvas,
	x0: number,
	y0: number,
	x1: number,
	y1: number,
	color: Color,
	alpha: number
)
	if alpha <= 0 then
		return
	end
	local clip = c.clip
	if clip then
		x0, y0 = math.max(x0, clip[1]), math.max(y0, clip[2])
		x1, y1 = math.min(x1, clip[3]), math.min(y1, clip[4])
	end
	local ax = math.max(0, math.floor(x0 + 0.5))
	local ay = math.max(0, math.floor(y0 + 0.5))
	local bx = math.min(c.width, math.floor(x1 + 0.5))
	local by = math.min(c.height, math.floor(y1 + 0.5))
	if bx <= ax or by <= ay then
		return
	end
	local r, g, b = bytes(color)
	for y = ay, by - 1 do
		local row = y * c.width
		for x = ax, bx - 1 do
			blendPixel(c, row + x, r, g, b, alpha)
		end
	end
end

-- A rectangle outline `thickness` pixels wide, inside the rectangle.
function Canvas.strokeRect(
	c: Canvas,
	x0: number,
	y0: number,
	x1: number,
	y1: number,
	color: Color,
	alpha: number,
	thickness: number
)
	local t = thickness
	Canvas.fillRect(c, x0, y0, x1, y0 + t, color, alpha)
	Canvas.fillRect(c, x0, y1 - t, x1, y1, color, alpha)
	Canvas.fillRect(c, x0, y0 + t, x0 + t, y1 - t, color, alpha)
	Canvas.fillRect(c, x1 - t, y0 + t, x1, y1 - t, color, alpha)
end

-- A filled triangle in pixel coordinates with a depth value per corner
-- (larger is nearer, interpolated linearly across the screen). Pixels whose
-- depth is not nearer than the buffer are skipped. `writeDepth` false is for
-- see-through surfaces.
function Canvas.triangle(
	c: Canvas,
	x0: number,
	y0: number,
	d0: number,
	x1: number,
	y1: number,
	d1: number,
	x2: number,
	y2: number,
	d2: number,
	color: Color,
	alpha: number,
	writeDepth: boolean
)
	local area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
	if math.abs(area) < 1e-9 then
		return
	end
	local minX = math.max(0, math.floor(math.min(x0, x1, x2)))
	local maxX = math.min(c.width - 1, math.ceil(math.max(x0, x1, x2)))
	local minY = math.max(0, math.floor(math.min(y0, y1, y2)))
	local maxY = math.min(c.height - 1, math.ceil(math.max(y0, y1, y2)))
	if minX > maxX or minY > maxY then
		return
	end
	local r, g, b = bytes(color)
	local inv = 1 / area
	for py = minY, maxY do
		local sy = py + 0.5
		local row = py * c.width
		for px = minX, maxX do
			local sx = px + 0.5
			local w0 = ((x1 - sx) * (y2 - sy) - (x2 - sx) * (y1 - sy)) * inv
			local w1 = ((x2 - sx) * (y0 - sy) - (x0 - sx) * (y2 - sy)) * inv
			local w2 = 1 - w0 - w1
			if w0 >= 0 and w1 >= 0 and w2 >= 0 then
				local d = w0 * d0 + w1 * d1 + w2 * d2
				local i = row + px
				if d > buffer.readf32(c.depth, i * 4) then
					if writeDepth then
						buffer.writef32(c.depth, i * 4, d)
					end
					blendPixel(c, i, r, g, b, alpha)
				end
			end
		end
	end
end

-- Depth stored at a pixel (FAR when nothing was drawn there).
function Canvas.depthAt(c: Canvas, x: number, y: number): number
	local px, py = math.floor(x), math.floor(y)
	if px < 0 or py < 0 or px >= c.width or py >= c.height then
		return FAR
	end
	return buffer.readf32(c.depth, (py * c.width + px) * 4)
end

Canvas.FAR = FAR

-- Text with the bitmap font. `size` is Roblox's TextSize in pixels: capital
-- letters come out about 0.7 of it tall, characters 0.6 of it wide.
function Canvas.text(
	c: Canvas,
	x: number,
	y: number,
	text: string,
	size: number,
	color: Color,
	alpha: number?
)
	local a = alpha or 1
	local s = size / 10
	local cx = x
	local top = y + size * 0.15
	for _, g in Font.layout(text) do
		local gs = if g.small then s * 0.8 else s
		local gy = top + (Font.HEIGHT * s - Font.HEIGHT * gs)
		for row = 1, Font.HEIGHT do
			local bits = g.glyph[row]
			for col = 1, Font.WIDTH do
				if bits[col] then
					local px = cx + (col - 1) * gs
					local py = gy + (row - 1) * gs
					Canvas.fillRect(c, px, py, px + math.max(gs, 1), py + math.max(gs, 1), color, a)
				end
			end
		end
		cx += Font.ADVANCE * s
	end
end

-- Width in pixels of `text` drawn at `size` by Canvas.text.
function Canvas.textWidth(text: string, size: number): number
	return Font.width(text) * size / 10
end

function Canvas.toPng(c: Canvas): string
	return Png.encode(c.width, c.height, c.rgb)
end

-- Draws `src` into `dst` at (x, y), unscaled.
function Canvas.blit(dst: Canvas, src: Canvas, x: number, y: number)
	for sy = 0, src.height - 1 do
		local dy = y + sy
		if dy >= 0 and dy < dst.height then
			for sx = 0, src.width - 1 do
				local dx = x + sx
				if dx >= 0 and dx < dst.width then
					local si = (sy * src.width + sx) * 3
					local di = (dy * dst.width + dx) * 3
					buffer.writeu8(dst.rgb, di, buffer.readu8(src.rgb, si))
					buffer.writeu8(dst.rgb, di + 1, buffer.readu8(src.rgb, si + 1))
					buffer.writeu8(dst.rgb, di + 2, buffer.readu8(src.rgb, si + 2))
				end
			end
		end
	end
end

return Canvas
