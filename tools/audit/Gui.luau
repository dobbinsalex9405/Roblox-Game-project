--!nocheck
-- The HUD as a player sees it: lays out the player's ScreenGuis at phone,
-- tablet and desktop sizes the way Roblox does (UDim2, anchor points, list
-- and grid layouts, padding, size and aspect constraints, automatic size,
-- scrolling frames, the top-bar inset), checks what a player would hit and
-- draws it over the spawn view. Then clicks every button on the first
-- screen, one at a time from a fresh boot, and looks again.
--
-- Text sizes and widths are estimates (0.6 of the text size per character):
-- good enough to catch text that is far too small or far too long. The real
-- font metrics come from the cloud engine check (tools/cloud).

local roblox = require("@lune/roblox")
local Canvas = require("./Canvas")

local Gui = {}

export type Screen = { name: string, width: number, height: number, inset: number, render: number }

-- Sizes in Roblox's units (points on a phone). The top bar is 58 tall.
Gui.SCREENS = {
	{ name = "phone", width = 844, height = 390, inset = 58, render = 2 },
	{ name = "small-phone", width = 667, height = 375, inset = 58, render = 0 },
	{ name = "tablet", width = 1180, height = 820, inset = 58, render = 1 },
	{ name = "desktop", width = 1920, height = 1080, inset = 58, render = 1 },
} :: { Screen }

Gui.MIN_TEXT_FAIL = 9 -- px on a phone: unreadable
Gui.MIN_TEXT_WARN = 12
Gui.MIN_TAP = 28
Gui.CHAR_WIDTH = 0.6
Gui.MAX_CLICKS = 14
-- Buttons clicked inside each panel a first-screen button opens.
Gui.MAX_INNER_CLICKS = 12
-- Roblox's own buttons in the top bar (menu, chat) on the left.
Gui.TOPBAR_LEFT = 104 -- GuiService.TopbarInset.Min.X: free top-bar space starts here

local GUI_OBJECTS = {
	Frame = true,
	TextLabel = true,
	TextButton = true,
	TextBox = true,
	ImageLabel = true,
	ImageButton = true,
	ScrollingFrame = true,
	ViewportFrame = true,
	CanvasGroup = true,
	VideoFrame = true,
}
local INTERACTIVE = { TextButton = true, ImageButton = true, TextBox = true }
local TEXT = { TextLabel = true, TextButton = true, TextBox = true }

local function prop(inst: any, name: string, default: any): any
	local ok, value = pcall(function()
		return inst[name]
	end)
	if ok and value ~= nil then
		return value
	end
	return default
end

local function enumName(v: any, default: string): string
	if v == nil then
		return default
	end
	local ok, name = pcall(function()
		return v.Name
	end)
	return if ok and name then name else default
end

local function udim2(v: any): { number }
	if v == nil then
		return { 0, 0, 0, 0 }
	end
	return { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset }
end

local function udim(v: any): { number }
	if v == nil then
		return { 0, 0 }
	end
	return { v.Scale, v.Offset }
end

local function stripRich(text: string): string
	return (string.gsub(text, "<[^>]*>", ""))
end

local function utf8len(text: string): number
	local ok, n = pcall(utf8.len, text)
	return if ok and n then n else #text
end

-- Plain snapshot of a GuiObject subtree --------------------------------------

local function snapshotNode(inst: any, guiName: string): any
	local class = inst.ClassName
	local node = {
		inst = inst,
		class = class,
		name = inst.Name,
		path = inst:GetFullName(),
		gui = guiName,
		visible = prop(inst, "Visible", true),
		position = udim2(prop(inst, "Position", nil)),
		size = udim2(prop(inst, "Size", nil)),
		anchor = {
			prop(inst, "AnchorPoint", nil) and inst.AnchorPoint.X or 0,
			prop(inst, "AnchorPoint", nil) and inst.AnchorPoint.Y or 0,
		},
		bg = prop(inst, "BackgroundColor3", nil),
		bgT = prop(inst, "BackgroundTransparency", 0),
		z = prop(inst, "ZIndex", 1),
		order = prop(inst, "LayoutOrder", 0),
		clips = prop(inst, "ClipsDescendants", false) or class == "ScrollingFrame",
		auto = enumName(prop(inst, "AutomaticSize", nil), "None"),
		rotation = prop(inst, "Rotation", 0),
		interactive = INTERACTIVE[class] == true,
		children = {},
	}
	if TEXT[class] then
		node.text = stripRich(prop(inst, "Text", ""))
		node.textSize = prop(inst, "TextSize", 14)
		node.scaled = prop(inst, "TextScaled", false)
		node.wrapped = prop(inst, "TextWrapped", false)
		node.textColor = prop(inst, "TextColor3", nil)
		node.textT = prop(inst, "TextTransparency", 0)
		node.xAlign = enumName(prop(inst, "TextXAlignment", nil), "Center")
		node.yAlign = enumName(prop(inst, "TextYAlignment", nil), "Center")
		node.font = enumName(prop(inst, "Font", nil), "Legacy")
	end
	if class == "ImageLabel" or class == "ImageButton" then
		node.image = prop(inst, "Image", "")
		node.imageT = prop(inst, "ImageTransparency", 0)
	end
	if class == "ScrollingFrame" then
		node.canvas = udim2(prop(inst, "CanvasSize", nil))
		local cp = prop(inst, "CanvasPosition", nil)
		node.scroll = if cp then { cp.X, cp.Y } else { 0, 0 }
		node.autoCanvas = enumName(prop(inst, "AutomaticCanvasSize", nil), "None")
	end
	for _, child in inst:GetChildren() do
		local cc = child.ClassName
		if GUI_OBJECTS[cc] then
			table.insert(node.children, snapshotNode(child, guiName))
		elseif cc == "UIListLayout" then
			node.layout = {
				inst = child,
				kind = "list",
				fill = enumName(prop(child, "FillDirection", nil), "Vertical"),
				padding = udim(prop(child, "Padding", nil)),
				h = enumName(prop(child, "HorizontalAlignment", nil), "Left"),
				v = enumName(prop(child, "VerticalAlignment", nil), "Top"),
				sort = enumName(prop(child, "SortOrder", nil), "LayoutOrder"),
			}
		elseif cc == "UIGridLayout" then
			node.layout = {
				inst = child,
				kind = "grid",
				fill = enumName(prop(child, "FillDirection", nil), "Horizontal"),
				cell = udim2(prop(child, "CellSize", nil)),
				cellPadding = udim2(prop(child, "CellPadding", nil)),
				h = enumName(prop(child, "HorizontalAlignment", nil), "Left"),
				v = enumName(prop(child, "VerticalAlignment", nil), "Top"),
				sort = enumName(prop(child, "SortOrder", nil), "LayoutOrder"),
				maxCells = prop(child, "FillDirectionMaxCells", 0),
			}
		elseif cc == "UIPageLayout" then
			node.layout = { kind = "page" }
		elseif cc == "UIPadding" then
			node.padding = {
				udim(prop(child, "PaddingLeft", nil)),
				udim(prop(child, "PaddingRight", nil)),
				udim(prop(child, "PaddingTop", nil)),
				udim(prop(child, "PaddingBottom", nil)),
			}
		elseif cc == "UISizeConstraint" then
			local mn, mx = prop(child, "MinSize", nil), prop(child, "MaxSize", nil)
			node.sizeConstraint = {
				minX = mn and mn.X or 0,
				minY = mn and mn.Y or 0,
				maxX = mx and mx.X or math.huge,
				maxY = mx and mx.Y or math.huge,
			}
		elseif cc == "UIAspectRatioConstraint" then
			node.aspect = prop(child, "AspectRatio", 1)
		elseif cc == "UIScale" then
			node.uiScale = prop(child, "Scale", 1)
		elseif cc == "UITextSizeConstraint" then
			node.textMin = prop(child, "MinTextSize", 1)
			node.textMax = prop(child, "MaxTextSize", 100)
		end
	end
	return node
end

-- The player's ScreenGuis, in draw order.
function Gui.snapshot(player: any): { any }
	local pg = player:FindFirstChild("PlayerGui")
	local guis = {}
	if pg == nil then
		return guis
	end
	for _, g in pg:GetChildren() do
		if g.ClassName == "ScreenGui" then
			local insets = enumName(prop(g, "ScreenInsets", nil), "CoreUISafeInsets")
			local ignore = prop(g, "IgnoreGuiInset", false)
				or insets == "None"
				or insets == "DeviceSafeInsets"
			local root = {
				inst = g,
				class = "ScreenGui",
				name = g.Name,
				path = g:GetFullName(),
				gui = g.Name,
				enabled = prop(g, "Enabled", true),
				displayOrder = prop(g, "DisplayOrder", 0),
				ignoreInset = ignore,
				children = {},
			}
			for _, child in g:GetChildren() do
				if GUI_OBJECTS[child.ClassName] then
					table.insert(root.children, snapshotNode(child, g.Name))
				end
			end
			table.insert(guis, root)
		end
	end
	table.sort(guis, function(a, b)
		if a.displayOrder ~= b.displayOrder then
			return a.displayOrder < b.displayOrder
		end
		return a.name < b.name
	end)
	return guis
end

-- Layout -----------------------------------------------------------------------

local function estimateTextSize(node: any, w: number, h: number): number
	local text = node.text or ""
	local n = math.max(1, utf8len(text))
	if not node.scaled then
		return node.textSize
	end
	local maxSize = math.min(100, node.textMax or 100)
	local s
	if node.wrapped then
		s = 1
		for size = math.floor(math.min(maxSize, h)), 1, -1 do
			local perLine = math.max(1, math.floor(w / (Gui.CHAR_WIDTH * size)))
			local lines = math.ceil(n / perLine)
			if lines * size * 1.15 <= h then
				s = size
				break
			end
		end
	else
		s = math.min(maxSize, h, w / (n * Gui.CHAR_WIDTH))
	end
	if node.textMin then
		s = math.max(s, node.textMin)
	end
	return math.max(0, s)
end

local function textBounds(node: any, size: number, boxW: number): (number, number, number)
	local text = node.text or ""
	local n = utf8len(text)
	local width = n * Gui.CHAR_WIDTH * size
	local lines = 1
	if node.wrapped and boxW > 0 and width > boxW then
		lines = math.ceil(width / boxW)
		width = boxW
	end
	return width, lines * size * 1.15, lines
end

local place

-- Size of a node inside a parent content box of pw x ph, with constraints
-- and automatic size; `scale` is the product of UIScales above it.
local function measure(node: any, pw: number, ph: number, scale: number): (number, number)
	local w = node.size[1] * pw + node.size[2] * scale
	local h = node.size[3] * ph + node.size[4] * scale
	if node.uiScale then
		w *= node.uiScale
		h *= node.uiScale
	end
	if node.auto ~= "None" then
		-- Grow to fit the children (and the text).
		local probe = { x = 0, y = 0, w = w, h = h }
		local maxX, maxY = 0, 0
		local childScale = scale * (node.uiScale or 1)
		local content = place.content(node, probe, childScale)
		place.children(node, content, nil, childScale, true)
		for _, c in node.children do
			if c.visible and c.rect then
				maxX = math.max(maxX, c.rect.x + c.rect.w - probe.x)
				maxY = math.max(maxY, c.rect.y + c.rect.h - probe.y)
			end
		end
		if node.text and node.text ~= "" and not node.scaled then
			local tw, th = textBounds(node, node.textSize, if node.auto == "Y" then w else 0)
			maxX = math.max(maxX, tw + 4)
			maxY = math.max(maxY, th + 2)
		end
		if node.padding then
			maxX += node.padding[2][1] * w + node.padding[2][2]
			maxY += node.padding[4][1] * h + node.padding[4][2]
		end
		if node.auto == "X" or node.auto == "XY" then
			w = math.max(w, maxX)
		end
		if node.auto == "Y" or node.auto == "XY" then
			h = math.max(h, maxY)
		end
	end
	if node.aspect and node.aspect > 0 then
		if w / math.max(h, 1e-6) > node.aspect then
			w = h * node.aspect
		else
			h = w / node.aspect
		end
	end
	local sc = node.sizeConstraint
	if sc then
		w = math.clamp(w, sc.minX, math.max(sc.minX, sc.maxX))
		h = math.clamp(h, sc.minY, math.max(sc.minY, sc.maxY))
	end
	return math.max(0, w), math.max(0, h)
end

place = {}

-- A node's content box: its rect minus padding.
function place.content(node: any, rect: any, _scale: number): any
	local p = node.padding
	if p == nil then
		return { x = rect.x, y = rect.y, w = rect.w, h = rect.h }
	end
	local l = p[1][1] * rect.w + p[1][2]
	local r = p[2][1] * rect.w + p[2][2]
	local t = p[3][1] * rect.h + p[3][2]
	local b = p[4][1] * rect.h + p[4][2]
	return { x = rect.x + l, y = rect.y + t, w = math.max(0, rect.w - l - r), h = math.max(0, rect.h - t - b) }
end

local function sortedForLayout(node: any): { any }
	-- Roblox: "If two children share the same LayoutOrder, whichever was
	-- added sooner to the parent object takes precedence." GetChildren keeps
	-- that order, so ties keep their child index. SortOrder Name sorts by name.
	local list = {}
	for i, c in node.children do
		if c.visible then
			table.insert(list, { c = c, i = i })
		end
	end
	local byOrder = node.layout == nil or node.layout.sort ~= "Name"
	table.sort(list, function(a, b)
		if byOrder then
			if a.c.order ~= b.c.order then
				return a.c.order < b.c.order
			end
		elseif a.c.name ~= b.c.name then
			return a.c.name < b.c.name
		end
		return a.i < b.i
	end)
	for i, e in list do
		list[i] = e.c
	end
	return list
end

-- Places a node at rect and lays out its children.
function place.node(node: any, rect: any, clip: any, scale: number, probing: boolean)
	node.rect = rect
	if not probing then
		node.clip = clip
	end
	local childScale = scale * (node.uiScale or 1)
	local content = place.content(node, rect, childScale)
	local childClip = clip
	if node.clips then
		childClip = {
			x0 = math.max(clip.x0, rect.x),
			y0 = math.max(clip.y0, rect.y),
			x1 = math.min(clip.x1, rect.x + rect.w),
			y1 = math.min(clip.y1, rect.y + rect.h),
			scrolling = clip.scrolling or node.class == "ScrollingFrame",
		}
	end
	if node.class == "ScrollingFrame" then
		local cv = node.canvas
		content = {
			x = content.x,
			y = content.y,
			w = math.max(content.w, cv[1] * rect.w + cv[2]),
			h = math.max(content.h, cv[3] * rect.h + cv[4]),
		}
		-- CanvasPosition scrolls the content up and left.
		local sc = node.scroll or { 0, 0 }
		content.x -= sc[1]
		content.y -= sc[2]
	end
	place.children(node, content, childClip, childScale, probing)
end

function place.children(node: any, content: any, clip: any, scale: number, probing: boolean)
	local layout = node.layout
	clip = clip or { x0 = -math.huge, y0 = -math.huge, x1 = math.huge, y1 = math.huge }
	if layout == nil then
		for _, c in node.children do
			local w, h = measure(c, content.w, content.h, scale)
			local x = content.x + c.position[1] * content.w + c.position[2] * scale - c.anchor[1] * w
			local y = content.y + c.position[3] * content.h + c.position[4] * scale - c.anchor[2] * h
			place.node(c, { x = x, y = y, w = w, h = h }, clip, scale, probing)
		end
		return
	end
	local items = sortedForLayout(node)
	for _, c in node.children do
		if not c.visible then
			place.node(c, { x = content.x, y = content.y, w = 0, h = 0 }, clip, scale, probing)
		end
	end
	if layout.kind == "page" then
		for i, c in items do
			local w, h = measure(c, content.w, content.h, scale)
			place.node(
				c,
				{ x = content.x, y = content.y, w = if i == 1 then w else 0, h = if i == 1 then h else 0 },
				clip,
				scale,
				probing
			)
		end
		return
	end
	if layout.kind == "list" then
		local vertical = layout.fill == "Vertical"
		local pad = if vertical
			then layout.padding[1] * content.h + layout.padding[2] * scale
			else layout.padding[1] * content.w + layout.padding[2] * scale
		local sizes = {}
		local total = 0
		for i, c in items do
			local w, h = measure(c, content.w, content.h, scale)
			sizes[i] = { w, h }
			total += (if vertical then h else w) + (if i > 1 then pad else 0)
		end
		local cursor
		if vertical then
			cursor = content.y
			if layout.v == "Center" then
				cursor += (content.h - total) / 2
			elseif layout.v == "Bottom" then
				cursor += content.h - total
			end
		else
			cursor = content.x
			if layout.h == "Center" then
				cursor += (content.w - total) / 2
			elseif layout.h == "Right" then
				cursor += content.w - total
			end
		end
		local cross = 0
		for _, size in sizes do
			cross = math.max(cross, if vertical then size[1] else size[2])
		end
		if not probing then
			node.contentSize = if vertical then { cross, total } else { total, cross }
		end
		for i, c in items do
			local w, h = sizes[i][1], sizes[i][2]
			local x, y
			if vertical then
				y = cursor
				x = content.x
				if layout.h == "Center" then
					x += (content.w - w) / 2
				elseif layout.h == "Right" then
					x += content.w - w
				end
				cursor += h + pad
			else
				x = cursor
				y = content.y
				if layout.v == "Center" then
					y += (content.h - h) / 2
				elseif layout.v == "Bottom" then
					y += content.h - h
				end
				cursor += w + pad
			end
			place.node(c, { x = x, y = y, w = w, h = h }, clip, scale, probing)
		end
		return
	end
	-- Grid: fixed cells, filled row by row (or column by column).
	local cw = layout.cell[1] * content.w + layout.cell[2] * scale
	local ch = layout.cell[3] * content.h + layout.cell[4] * scale
	local px = layout.cellPadding[1] * content.w + layout.cellPadding[2] * scale
	local py = layout.cellPadding[3] * content.h + layout.cellPadding[4] * scale
	local horizontal = layout.fill == "Horizontal"
	local perLine
	if horizontal then
		perLine = math.max(1, math.floor((content.w + px) / math.max(1, cw + px)))
	else
		perLine = math.max(1, math.floor((content.h + py) / math.max(1, ch + py)))
	end
	if layout.maxCells and layout.maxCells > 0 then
		perLine = math.min(perLine, layout.maxCells)
	end
	local lineCount = math.min(perLine, #items)
	local lineLength = lineCount * cw + math.max(0, lineCount - 1) * px
	local startX = content.x
	if horizontal and layout.h == "Center" then
		startX += (content.w - lineLength) / 2
	elseif horizontal and layout.h == "Right" then
		startX += content.w - lineLength
	end
	if not probing then
		local lines = math.ceil(#items / perLine)
		local across = lineCount * cw + math.max(0, lineCount - 1) * px
		local down = lines * ch + math.max(0, lines - 1) * py
		node.contentSize = if horizontal then { across, down } else { down, across }
	end
	for i, c in items do
		local k = i - 1
		local col, row
		if horizontal then
			col, row = k % perLine, k // perLine
		else
			row, col = k % perLine, k // perLine
		end
		local w, h = cw, ch
		if c.aspect and c.aspect > 0 then
			if w / math.max(h, 1e-6) > c.aspect then
				w = h * c.aspect
			else
				h = w / c.aspect
			end
		end
		place.node(
			c,
			{ x = startX + col * (cw + px), y = content.y + row * (ch + py), w = w, h = h },
			clip,
			scale,
			probing
		)
	end
end

export type Item = {
	node: any,
	gui: any,
	rect: any,
	clip: any,
	rank: number,
	textSize: number?,
	textRect: any?,
}

-- Lays out every gui for one screen; returns visible items in draw order.
function Gui.layout(guis: { any }, screen: Screen): { Item }
	local items: { Item } = {}
	local rank = 0
	for _, g in guis do
		if g.enabled then
			local top = if g.ignoreInset then 0 else screen.inset
			local rect = { x = 0, y = top, w = screen.width, h = screen.height - top }
			local clip = { x0 = -math.huge, y0 = -math.huge, x1 = math.huge, y1 = math.huge }
			place.children(g, rect, clip, 1, false)
			-- Draw order: tree order, siblings by ZIndex (ZIndexBehavior Sibling).
			local function walk(node: any)
				-- Equal ZIndex: the later child draws on top, as in Roblox.
				local kids = {}
				for i, c in node.children do
					kids[i] = { c = c, i = i }
				end
				table.sort(kids, function(a, b)
					if (a.c.z or 1) ~= (b.c.z or 1) then
						return (a.c.z or 1) < (b.c.z or 1)
					end
					return a.i < b.i
				end)
				for i, k in kids do
					kids[i] = k.c
				end
				for _, c in kids do
					if c.visible and c.rect and c.rect.w > 0.5 and c.rect.h > 0.5 then
						rank += 1
						local item: Item = { node = c, gui = g, rect = c.rect, clip = c.clip, rank = rank }
						if c.text ~= nil then
							local size = estimateTextSize(c, c.rect.w, c.rect.h)
							item.textSize = size
							local tw, th = textBounds(c, size, c.rect.w)
							tw = math.min(tw, c.rect.w)
							th = math.min(th, c.rect.h)
							local tx = c.rect.x + (c.rect.w - tw) / 2
							if c.xAlign == "Left" then
								tx = c.rect.x
							elseif c.xAlign == "Right" then
								tx = c.rect.x + c.rect.w - tw
							end
							local ty = c.rect.y + (c.rect.h - th) / 2
							if c.yAlign == "Top" then
								ty = c.rect.y
							elseif c.yAlign == "Bottom" then
								ty = c.rect.y + c.rect.h - th
							end
							item.textRect = { x = tx, y = ty, w = tw, h = th }
						end
						table.insert(items, item)
						walk(c)
					end
				end
			end
			walk(g)
		end
	end
	return items
end

-- Tells the game what Roblox would: every element's AbsoluteSize and
-- AbsolutePosition, each layout's AbsoluteContentSize, and fires the change
-- signals, so code that sizes itself from those (fit a card to the screen,
-- grow a list) runs as it would on that screen. Returns whether anything
-- changed (the game may then move things again).
function Gui.publish(guis: { any }, screen: Screen, shim: any): boolean
	local changed = false
	local function set(inst: any, name: string, value: any)
		local ok, current = pcall(function()
			return inst[name]
		end)
		if ok and current == value then
			return
		end
		local wrote = pcall(function()
			inst[name] = value
		end)
		if wrote then
			changed = true
			shim.signalOf(inst, `Changed:{name}`):Fire()
		end
	end
	local function v2(x: number, y: number): any
		return roblox.Vector2.new(math.floor(x + 0.5), math.floor(y + 0.5))
	end
	local function walk(node: any)
		for _, c in node.children do
			if c.rect then
				set(c.inst, "AbsoluteSize", v2(c.rect.w, c.rect.h))
				set(c.inst, "AbsolutePosition", v2(c.rect.x, c.rect.y))
				if c.class == "ScrollingFrame" then
					set(c.inst, "AbsoluteWindowSize", v2(c.rect.w, c.rect.h))
				end
			end
			if c.layout and c.layout.inst and c.contentSize then
				set(c.layout.inst, "AbsoluteContentSize", v2(c.contentSize[1], c.contentSize[2]))
			end
			walk(c)
		end
	end
	for _, g in guis do
		local top = if g.ignoreInset then 0 else screen.inset
		set(g.inst, "AbsoluteSize", v2(screen.width, screen.height - top))
		set(g.inst, "AbsolutePosition", v2(0, top))
		walk(g)
	end
	return changed
end

-- Checks ---------------------------------------------------------------------

local function area(r: any): number
	return math.max(0, r.w) * math.max(0, r.h)
end

local function intersection(a: any, b: any): number
	local x0, y0 = math.max(a.x, b.x), math.max(a.y, b.y)
	local x1, y1 = math.min(a.x + a.w, b.x + b.w), math.min(a.y + a.h, b.y + b.h)
	if x1 <= x0 or y1 <= y0 then
		return 0
	end
	return (x1 - x0) * (y1 - y0)
end

local function contains(outer: any, inner: any): boolean
	return inner.x >= outer.x - 0.5
		and inner.y >= outer.y - 0.5
		and inner.x + inner.w <= outer.x + outer.w + 0.5
		and inner.y + inner.h <= outer.y + outer.h + 0.5
end

local function isAncestor(a: any, b: any): boolean
	return b.inst:IsDescendantOf(a.inst)
end

-- The part of a rect inside its clip (what can actually be seen).
local function clipped(r: any, clip: any): any
	if clip == nil then
		return r
	end
	local x0, y0 = math.max(r.x, clip.x0), math.max(r.y, clip.y0)
	local x1, y1 = math.min(r.x + r.w, clip.x1), math.min(r.y + r.h, clip.y1)
	return { x = x0, y = y0, w = math.max(0, x1 - x0), h = math.max(0, y1 - y0) }
end

-- Is the item hidden under a later, solid panel (an open pop-up)?
local function covered(items: { Item }, item: Item, r: any): boolean
	for _, other in items do
		if
			other.rank > item.rank
			and not isAncestor(other.node, item.node)
			and not isAncestor(item.node, other.node)
		then
			if (other.node.bgT or 1) < 0.3 and contains(clipped(other.rect, other.clip), r) then
				return true
			end
		end
	end
	return false
end

local function label(item: Item): string
	local node = item.node
	local t = node.text
	if t and t ~= "" then
		t = string.gsub(t, "\n", " ")
		if #t > 40 then
			t = string.sub(t, 1, 37) .. "..."
		end
		return `{node.path} ("{t}")`
	end
	return node.path
end

-- Findings for one screen. `kind` is the screen name; `phoneLike` turns on
-- the text-size and tap-size rules.
function Gui.check(items: { Item }, screen: Screen, phoneLike: boolean): { any }
	local out = {}
	local function add(severity: string, rule: string, key: string, message: string, item: Item?)
		table.insert(out, { severity = severity, rule = rule, key = key, message = message, item = item })
	end
	local visibleItems = {}
	for _, item in items do
		local vis = clipped(item.rect, item.clip)
		if area(vis) > 1 then
			item.visibleRect = vis
			if not covered(items, item, vis) then
				table.insert(visibleItems, item)
			end
		end
	end

	-- A full-screen button behind a pop-up (tap outside to close) is a
	-- backdrop, not a button a player aims for.
	local screenArea = screen.width * screen.height
	for _, item in visibleItems do
		item.backdrop = item.node.interactive and area(item.visibleRect) >= 0.7 * screenArea
	end

	for _, item in visibleItems do
		local node = item.node
		local r = item.rect
		local vis = item.visibleRect
		if node.interactive and not item.backdrop then
			local inScroll = item.clip and item.clip.scrolling
			local over = math.max(0, -r.x, -r.y, r.x + r.w - screen.width, r.y + r.h - screen.height)
			-- A sliver off the edge is untidy; a real chunk is a button players
			-- can't see or reach.
			local hidden = 1
				- area(clipped(r, { x0 = 0, y0 = 0, x1 = screen.width, y1 = screen.height }))
					/ math.max(area(r), 1)
			if over > 2 and not inScroll then
				add(
					if over > 12 or hidden > 0.25 then "FAIL" else "WARN",
					"hud.offscreen",
					node.path,
					`{label(item)} sticks {math.floor(over)} px off the screen`,
					item
				)
			end
			if vis.y < screen.inset and vis.x < Gui.TOPBAR_LEFT and item.gui.ignoreInset then
				add(
					"FAIL",
					"hud.topbar",
					node.path,
					`{label(item)} is under Roblox's top-bar buttons (top-left {Gui.TOPBAR_LEFT}x{screen.inset})`,
					item
				)
			end
			-- The button's own size: one half scrolled out of a list is still
			-- big enough once the player scrolls to it.
			local r = item.rect
			if phoneLike and (r.w < Gui.MIN_TAP or r.h < Gui.MIN_TAP) then
				add(
					"WARN",
					"hud.tap-size",
					node.path,
					`{label(item)} is {math.floor(r.w)}x{math.floor(r.h)}: hard to tap (aim for {Gui.MIN_TAP}+)`,
					item
				)
			end
			if node.class == "TextButton" and (node.text or "") == "" then
				local hasLabel = false
				for _, c in node.children do
					if (c.text and c.text ~= "") or (c.image and c.image ~= "") then
						hasLabel = true
					end
				end
				if not hasLabel then
					add(
						"WARN",
						"hud.unlabelled",
						node.path,
						`{label(item)} is a button with no text or icon`,
						item
					)
				end
			end
		end
		if node.text and node.text ~= "" and (node.textT or 0) < 0.9 and item.textSize then
			local size = item.textSize
			if phoneLike and size < Gui.MIN_TEXT_FAIL then
				add(
					"FAIL",
					"hud.text-tiny",
					node.path,
					`{label(item)} draws at about {string.format("%.0f", size)} px: unreadable (minimum {Gui.MIN_TEXT_FAIL})`,
					item
				)
			elseif phoneLike and size < Gui.MIN_TEXT_WARN then
				add(
					"WARN",
					"hud.text-small",
					node.path,
					`{label(item)} draws at about {string.format("%.0f", size)} px: small on a phone`,
					item
				)
			end
			if not node.scaled then
				local tw, th = textBounds(node, size, r.w)
				if not node.wrapped and tw > r.w * 1.15 + 4 then
					add(
						"WARN",
						"hud.text-long",
						node.path,
						`{label(item)} is about {math.floor(tw)} px of text in a {math.floor(r.w)} px box`,
						item
					)
				elseif node.wrapped and th > r.h * 1.15 + 4 then
					add(
						"WARN",
						"hud.text-long",
						node.path,
						`{label(item)} needs about {math.floor(th)} px of height in a {math.floor(r.h)} px box`,
						item
					)
				end
			end
		end
	end

	-- Is `top` drawn on a solid panel that lies over `under`? Then `under`
	-- is behind that panel (an open window over the HUD), not overlapping.
	local byInst = {}
	for _, item in items do
		byInst[item.node.inst] = item
	end
	local function onPanelOver(top: Item, under: Item, r: any): boolean
		local inst = top.node.inst.Parent
		while inst do
			local panel = byInst[inst]
			if panel and panel.rank > under.rank and (panel.node.bgT or 1) < 0.3 then
				if intersection(clipped(panel.rect, panel.clip), r) > 0 then
					return true
				end
			end
			inst = inst.Parent
		end
		return false
	end

	-- Overlaps between things a player reads or taps.
	for i = 1, #visibleItems do
		local a = visibleItems[i]
		for j = i + 1, #visibleItems do
			local b = visibleItems[j]
			local first, second = a, b
			if b.rank < a.rank then
				first, second = b, a
			end
			local behind = onPanelOver(second, first, first.textRect or first.visibleRect)
			if not behind and not isAncestor(a.node, b.node) and not isAncestor(b.node, a.node) then
				local sameGui = a.gui == b.gui
				if a.node.interactive and b.node.interactive and not a.backdrop and not b.backdrop then
					local o = intersection(a.visibleRect, b.visibleRect)
					local small = math.min(area(a.visibleRect), area(b.visibleRect))
					if small > 0 and o / small > 0.2 then
						add(
							if sameGui then "FAIL" else "WARN",
							"hud.buttons-overlap",
							`{a.node.path}|{b.node.path}`,
							`{label(a)} and {label(b)} overlap ({math.floor(o / small * 100)}% of the smaller)`,
							b
						)
					end
				end
				if a.textRect and b.textRect and (a.node.text or "") ~= "" and (b.node.text or "") ~= "" then
					local ta, tb = clipped(a.textRect, a.clip), clipped(b.textRect, b.clip)
					local o = intersection(ta, tb)
					local small = math.min(area(ta), area(tb))
					if small > 0 and o / small > 0.3 then
						add(
							if sameGui then "FAIL" else "WARN",
							"hud.text-overlap",
							`{a.node.path}|{b.node.path}`,
							`{label(a)} and {label(b)} are drawn over each other ({math.floor(o / small * 100)}% of the smaller)`,
							b
						)
					end
				end
			end
		end
	end
	return out
end

-- How much of the screen solid panels cover, 0..1 (sampled every 8 px).
function Gui.coverage(items: { Item }, screen: Screen): number
	local hit, total = 0, 0
	for y = screen.inset, screen.height - 1, 8 do
		for x = 0, screen.width - 1, 8 do
			total += 1
			for _, item in items do
				local r = item.visibleRect or clipped(item.rect, item.clip)
				local solid = (item.node.bgT or 1) < 0.3
					or (item.node.image and item.node.image ~= "" and (item.node.imageT or 0) < 0.5)
				if solid and x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h then
					hit += 1
					break
				end
			end
		end
	end
	return if total > 0 then hit / total else 0
end

-- Drawing ----------------------------------------------------------------------

local RED = { r = 1, g = 0.1, b = 0.1 }
local BAR = { r = 0.1, g = 0.1, b = 0.12 }
local ICON = { r = 0.85, g = 0.85, b = 0.85 }

local function color(c: any, default: Canvas.Color): Canvas.Color
	if c == nil then
		return default
	end
	return { r = c.R, g = c.G, b = c.B }
end

local function wrapLines(text: string, size: number, width: number, wrapped: boolean): { string }
	local lines = {}
	for _, para in string.split(text, "\n") do
		if not wrapped then
			table.insert(lines, para)
		else
			local line = ""
			for _, word in string.split(para, " ") do
				local candidate = if line == "" then word else line .. " " .. word
				if line ~= "" and Canvas.textWidth(candidate, size) > width then
					table.insert(lines, line)
					line = word
				else
					line = candidate
				end
			end
			table.insert(lines, line)
		end
	end
	return lines
end

-- Draws the HUD items over `c` at `k` canvas pixels per screen unit; items
-- with a failing finding get a red outline.
function Gui.draw(c: Canvas.Canvas, items: { Item }, screen: Screen, k: number, failing: { [any]: boolean })
	-- Roblox's top bar: two round buttons on the left, as a reminder of the space it takes.
	for i = 0, 1 do
		local x = (12 + i * 52) * k
		Canvas.fillRect(c, x, 8 * k, x + 44 * k, 52 * k, BAR, 0.55)
		Canvas.fillRect(c, x + 14 * k, 26 * k, x + 30 * k, 29 * k, ICON, 0.9)
	end
	for _, item in items do
		local node = item.node
		local r = item.rect
		local clip = item.clip
		if clip and clip.x0 ~= -math.huge then
			c.clip = { clip.x0 * k, clip.y0 * k, clip.x1 * k, clip.y1 * k }
		else
			c.clip = nil
		end
		local alpha = 1 - (node.bgT or 1)
		if alpha > 0.01 then
			Canvas.fillRect(
				c,
				r.x * k,
				r.y * k,
				(r.x + r.w) * k,
				(r.y + r.h) * k,
				color(node.bg, ICON),
				alpha
			)
		end
		if node.image and node.image ~= "" and (node.imageT or 0) < 0.95 then
			-- Images are not loaded: a grey stand-in with a cross.
			Canvas.fillRect(
				c,
				r.x * k,
				r.y * k,
				(r.x + r.w) * k,
				(r.y + r.h) * k,
				ICON,
				0.35 * (1 - (node.imageT or 0))
			)
			Canvas.strokeRect(c, r.x * k, r.y * k, (r.x + r.w) * k, (r.y + r.h) * k, ICON, 0.6, 1)
		end
		if node.text and node.text ~= "" and item.textSize and item.textRect then
			local size = item.textSize * k
			local lines = wrapLines(node.text, size, r.w * k, node.wrapped or node.scaled)
			local lineH = size * 1.15
			local blockH = #lines * lineH
			local y = r.y * k + (r.h * k - blockH) / 2
			if node.yAlign == "Top" then
				y = r.y * k
			elseif node.yAlign == "Bottom" then
				y = (r.y + r.h) * k - blockH
			end
			local tc = color(node.textColor, { r = 0, g = 0, b = 0 })
			for _, line in lines do
				local w = Canvas.textWidth(line, size)
				local x = r.x * k + (r.w * k - w) / 2
				if node.xAlign == "Left" then
					x = r.x * k
				elseif node.xAlign == "Right" then
					x = (r.x + r.w) * k - w
				end
				Canvas.text(c, x, y, line, size, tc, 1 - (node.textT or 0))
				y += lineH
			end
		end
	end
	c.clip = nil
	for _, item in items do
		if failing[item] then
			local r = item.rect
			Canvas.strokeRect(
				c,
				r.x * k - 2,
				r.y * k - 2,
				(r.x + r.w) * k + 2,
				(r.y + r.h) * k + 2,
				RED,
				1,
				2
			)
		end
	end
	local _ = screen
end

-- Clicking ---------------------------------------------------------------------

local CLOSE_WORDS =
	{ "x", "close", "back", "done", "ok", "okay", "got it", "continue", "cancel", "no thanks", "later" }

local function isCloseButton(node: any): boolean
	local t = string.lower(string.gsub(node.text or "", "^%s*(.-)%s*$", "%1"))
	t = string.gsub(t, utf8.char(0x2715), "x")
	t = string.gsub(t, utf8.char(0x00D7), "x")
	for _, w in CLOSE_WORDS do
		if t == w then
			return true
		end
	end
	return string.find(string.lower(node.name), "close", 1, true) ~= nil
end

-- Fires the click a player's tap would: Activated if the game listens to it,
-- else MouseButton1Click, else the press and release.
function Gui.click(Shim: any, inst: any): boolean
	local function listening(name: string): boolean
		local s = Shim.signalOf(inst, name)
		for _, h in s.handlers do
			if h.Connected then
				return true
			end
		end
		return false
	end
	for _, name in { "Activated", "MouseButton1Click", "MouseButton1Up", "MouseButton1Down", "TouchTap" } do
		if listening(name) then
			if name == "TouchTap" then
				Shim.signalOf(inst, name):Fire({}, nil)
			elseif name == "Activated" then
				Shim.signalOf(inst, name):Fire(nil, 1)
			else
				Shim.signalOf(inst, name):Fire(0, 0)
			end
			return true
		end
	end
	return false
end

-- Several elements can share a path (list rows made by one function), so
-- each is told apart by how many came before it with the same path.
local function keyed(items: { Item }): { [Item]: string }
	local count: { [string]: number } = {}
	local keys = {}
	for _, item in items do
		local path = item.node.path
		count[path] = (count[path] or 0) + 1
		keys[item] = `{path}#{count[path]}`
	end
	return keys
end

local function visibleSet(items: { Item }): { [string]: string }
	local set = {}
	local keys = keyed(items)
	for _, item in items do
		if item.visibleRect == nil or area(item.visibleRect) > 1 then
			set[keys[item]] = item.node.text or ""
		end
	end
	return set
end

-- Scrolls the ScrollingFrame around `item` so all of it shows, as a player
-- would swipe to it. Returns false when it is not in a scrolling frame.
local function scrollIntoView(items: { Item }, item: Item): boolean
	local inst = item.node.inst
	local scroller = inst and inst:FindFirstAncestorWhichIsA("ScrollingFrame")
	if scroller == nil then
		return false
	end
	local frame = nil
	for _, other in items do
		if other.node.inst == scroller then
			frame = other
			break
		end
	end
	if frame == nil then
		return false
	end
	local cp = scroller.CanvasPosition
	local top = item.rect.y - frame.rect.y + cp.Y
	local y = cp.Y
	if top < cp.Y then
		y = top - 8
	elseif top + item.rect.h > cp.Y + frame.rect.h then
		y = top + item.rect.h + 8 - frame.rect.h
	end
	y = math.max(0, y)
	if y == cp.Y then
		return false
	end
	scroller.CanvasPosition = roblox.Vector2.new(cp.X, y)
	return true
end

-- Audit ------------------------------------------------------------------------

-- Lune refuses to read any property of a destroyed instance; Roblox allows
-- it. Such an error is the harness, not the game: shown as a note.
function Gui.severityOfError(message: string): (string, string?)
	if string.find(message, "Instance has been destroyed", 1, true) then
		return "NOTE",
			"the game read a property of a destroyed instance, which Roblox allows but Lune refuses; what happened after it was not seen"
	end
	return "FAIL", nil
end

local function errorFinding(rule: string, prefix: string, e: any, where: string): any
	local severity, why = Gui.severityOfError(e.message)
	local first = string.split(e.message, "\n")[1]
	return {
		severity = severity,
		rule = if why then "harness.destroyed" else rule,
		message = if why then `{prefix}: {why} ({e.where}: {first})` else `{prefix}: {e.where}: {e.message}`,
		screens = { where },
	}
end

export type Options = {
	images: boolean,
	background: (number, number) -> Canvas.Canvas,
	save: (string, string, Canvas.Canvas) -> (),
	takeErrors: () -> { any },
	settle: number,
	reboot: (() -> (any, any))?,
	shim: any,
	wait: (number) -> (),
	setScreen: (any, number, number, number) -> (),
}

local function slug(text: string): string
	local s = string.lower(string.gsub(text, "[^%w]+", "-"))
	s = string.gsub(s, "^-+", "")
	s = string.gsub(s, "-+$", "")
	if s == "" then
		s = "button"
	end
	return string.sub(s, 1, 24)
end

function Gui.audit(
	_game: any,
	player: any,
	opts: Options
): { findings: { any }, notes: { string }, texts: { any } }
	local findings = {}
	local notes = {}
	local seen: { [string]: any } = {}

	local function record(list: { any }, where: string)
		for _, f in list do
			local key = `{f.rule}|{f.key}`
			local existing = seen[key]
			if existing then
				if not table.find(existing.screens, where) then
					table.insert(existing.screens, where)
				end
			else
				local entry =
					{ severity = f.severity, rule = f.rule, message = f.message, screens = { where } }
				seen[key] = entry
				table.insert(findings, entry)
			end
		end
	end

	local phone = Gui.SCREENS[1]
	local function snapshotScreen(p: any, screen: Screen): ({ Item }, { any })
		opts.setScreen(p, screen.width, screen.height, screen.inset)
		opts.wait(0.05)
		local items
		-- Lay out, tell the game the sizes, and again until nothing moves.
		for _ = 1, 4 do
			local guis = Gui.snapshot(p)
			items = Gui.layout(guis, screen)
			if not Gui.publish(guis, screen, opts.shim) then
				break
			end
			opts.wait(0.05)
		end
		local phoneLike = screen.width <= 900
		return items, Gui.check(items, screen, phoneLike)
	end

	local function render(items: { Item }, list: { any }, screen: Screen, file: string, title: string)
		if not opts.images or screen.render == 0 then
			return
		end
		local k = screen.render
		local c = opts.background(screen.width * k, screen.height * k)
		local failing = {}
		for _, f in list do
			if f.severity == "FAIL" and f.item then
				failing[f.item] = true
			end
		end
		Gui.draw(c, items, screen, k, failing)
		opts.save(file, title, c)
	end

	-- 1. The first screen at every size.
	local idleItems
	local texts = {}
	for _, screen in Gui.SCREENS do
		local items, list = snapshotScreen(player, screen)
		record(list, screen.name)
		render(
			items,
			list,
			screen,
			`{screen.name}.png`,
			`first screen, {screen.name} {screen.width}x{screen.height}`
		)
		if screen == phone then
			idleItems = items
			for _, item in items do
				local node = item.node
				if node.text and node.text ~= "" then
					table.insert(texts, {
						path = node.path,
						text = node.text,
						font = node.font,
						size = item.textSize,
						scaled = node.scaled,
						wrapped = node.wrapped,
						width = item.rect.w,
						height = item.rect.h,
					})
				end
			end
			local cover = Gui.coverage(items, screen)
			table.insert(
				notes,
				`On a phone, solid panels cover {math.floor(cover * 100)}% of the first screen.`
			)
			if cover > 0.4 then
				table.insert(findings, {
					severity = "WARN",
					rule = "hud.covers-world",
					message = `On a phone the first screen's panels cover {math.floor(cover * 100)}% of the view; players need to see the world.`,
					screens = { "phone" },
				})
			end
		end
	end
	local errors = opts.takeErrors()
	for _, e in errors do
		table.insert(findings, errorFinding("hud.error", "While showing the first screen", e, "phone"))
	end

	-- 2. Every button on the first phone screen, one at a time.
	local targets = {}
	for _, item in idleItems or {} do
		if
			item.node.interactive
			and item.node.class ~= "TextBox"
			and item.visibleRect
			and area(item.visibleRect) > 1
		then
			if not covered(idleItems, item, item.visibleRect) then
				table.insert(targets, item)
			end
		end
	end
	table.sort(targets, function(a, b)
		if math.abs(a.rect.y - b.rect.y) > 4 then
			return a.rect.y < b.rect.y
		end
		return a.rect.x < b.rect.x
	end)
	if #targets > Gui.MAX_CLICKS then
		table.insert(notes, `Clicked the first {Gui.MAX_CLICKS} of {#targets} buttons.`)
		targets = table.move(targets, 1, Gui.MAX_CLICKS, 1, {})
	end
	local before = visibleSet(idleItems or {})
	local beforePaths: { [string]: boolean } = {}
	for _, item in idleItems or {} do
		beforePaths[item.node.path] = true
	end
	for n, target in targets do
		local path = target.node.path
		local name = if (target.node.text or "") ~= "" then target.node.text else target.node.name
		local p = player
		if opts.reboot and n > 1 then
			local _, fresh = opts.reboot()
			p = fresh
		end
		-- Find the same button in this boot.
		local inst = nil
		local pg = p:FindFirstChild("PlayerGui")
		for _, d in pg:GetDescendants() do
			if d:GetFullName() == path and INTERACTIVE[d.ClassName] then
				inst = d
				break
			end
		end
		if inst == nil then
			table.insert(notes, `Could not find {path} again after a fresh boot; skipped.`)
			continue
		end
		opts.shim.output = {}
		local handled = Gui.click(opts.shim, inst)
		opts.wait(opts.settle)
		local where = `after clicking "{name}"`
		if not handled then
			table.insert(findings, {
				severity = "WARN",
				rule = "click.nothing",
				message = `{path} ("{name}") has no click handler: tapping it does nothing.`,
				screens = { "phone" },
			})
			continue
		end
		for _, e in opts.takeErrors() do
			table.insert(
				findings,
				errorFinding("click.error", `Clicking "{name}" raised an error`, e, "phone")
			)
		end
		local prompts = {}
		for _, line in opts.shim.output do
			if string.sub(line, 1, 8) == "[prompt]" then
				table.insert(prompts, line)
			end
		end
		local items, list = snapshotScreen(p, phone)
		record(list, where)
		local after = visibleSet(items)
		local opened, changed = 0, 0
		for key, text in after do
			if before[key] == nil then
				opened += 1
			elseif before[key] ~= text then
				changed += 1
			end
		end
		local closedCount = 0
		for key in before do
			if after[key] == nil then
				closedCount += 1
			end
		end
		local what = `opened {opened} element(s), changed {changed} text(s), hid {closedCount}`
		if #prompts > 0 then
			what ..= `, purchase prompt: {string.sub(prompts[1], 10)}`
		end
		table.insert(notes, `Clicked "{name}" ({path}): {what}.`)
		if opened == 0 and changed == 0 and closedCount == 0 and #prompts == 0 then
			table.insert(findings, {
				severity = "WARN",
				rule = "click.no-feedback",
				message = `Clicking "{name}" changed nothing on the screen (the server may answer later, but the player sees no response).`,
				screens = { "phone" },
			})
		end
		render(items, list, phone, string.format("click-%02d-%s.png", n, slug(name)), where)

		-- Close it again, as a player would.
		local reopen = false
		if opened > 0 then
			local closer = nil
			for _, item in items do
				if
					item.node.interactive
					and beforePaths[item.node.path] == nil
					and isCloseButton(item.node)
				then
					closer = item
					break
				end
			end
			if closer then
				Gui.click(opts.shim, closer.node.inst)
				opts.wait(opts.settle)
			else
				-- Many menus toggle with the same button.
				Gui.click(opts.shim, inst)
				opts.wait(opts.settle)
			end
			for _, e in opts.takeErrors() do
				table.insert(
					findings,
					errorFinding("click.error", `Closing "{name}" raised an error`, e, "phone")
				)
			end
			local back = visibleSet((snapshotScreen(p, phone)))
			local stillOpen = 0
			for key in back do
				if before[key] == nil then
					stillOpen += 1
				end
			end
			reopen = stillOpen == 0
			if stillOpen > 0 then
				table.insert(findings, {
					severity = "WARN",
					rule = "click.no-close",
					message = `After opening "{name}", no close button (X, Close, Back, Done, OK) or second tap closed it; {stillOpen} element(s) stayed open.`,
					screens = { "phone" },
				})
			end
		end
		-- Inside what opened: tabs, odds, buy buttons, one after another as a
		-- player would (same session), so a shop's second tab and its odds
		-- screen are seen too. Close buttons are left for the step below.
		if opened > 0 then
			-- Open it again if the close step closed it.
			if reopen then
				Gui.click(opts.shim, inst)
				opts.wait(opts.settle)
				opts.takeErrors()
				items, list = snapshotScreen(p, phone)
			end
			local tried: { [string]: boolean } = {}
			-- The next button to try, in reading order; one scrolled out of
			-- view in a list is swiped to first.
			local function nextTarget(): Item?
				local keys = keyed(items)
				local order = table.clone(items)
				table.sort(order, function(a, b)
					if math.abs(a.rect.y - b.rect.y) > 4 then
						return a.rect.y < b.rect.y
					end
					return a.rect.x < b.rect.x
				end)
				for _, item in order do
					local node = item.node
					local key = `{keys[item]}|{node.text or ""}`
					local shows = item.visibleRect ~= nil and area(item.visibleRect) > 1
					if
						node.interactive
						and node.class ~= "TextBox"
						and beforePaths[node.path] == nil
						and not tried[key]
						and not isCloseButton(node)
						and not item.backdrop
						and (shows or (item.clip and item.clip.scrolling))
					then
						tried[key] = true
						local whole = shows and area(item.visibleRect) >= 0.9 * area(item.rect)
						if not whole and scrollIntoView(items, item) then
							opts.wait(0.05)
							items, list = snapshotScreen(p, phone)
							local again = keyed(items)
							local found = nil
							for _, other in items do
								if
									again[other] == keys[item]
									and (other.node.text or "") == (node.text or "")
								then
									found = other
									break
								end
							end
							if found == nil or found.visibleRect == nil or area(found.visibleRect) <= 1 then
								continue
							end
							item = found
						elseif not shows then
							continue
						end
						if not covered(items, item, item.visibleRect) then
							return item
						end
					end
				end
				return nil
			end
			for m = 1, Gui.MAX_INNER_CLICKS do
				local inner = nextTarget()
				if inner == nil then
					break
				end
				local innerName = if (inner.node.text or "") ~= "" then inner.node.text else inner.node.name
				local innerWhere = `after clicking "{name}" then "{innerName}"`
				local shown = visibleSet(items)
				opts.shim.output = {}
				local innerHandled = Gui.click(opts.shim, inner.node.inst)
				opts.wait(opts.settle)
				local lost = false
				for _, e in opts.takeErrors() do
					if Gui.severityOfError(e.message) == "NOTE" then
						lost = true
					end
					table.insert(
						findings,
						errorFinding(
							"click.error",
							`Clicking "{innerName}" in "{name}" raised an error`,
							e,
							"phone"
						)
					)
				end
				local innerPrompt = nil
				for _, line in opts.shim.output do
					if string.sub(line, 1, 8) == "[prompt]" then
						innerPrompt = string.sub(line, 10)
						break
					end
				end
				items, list = snapshotScreen(p, phone)
				record(list, innerWhere)
				local now = visibleSet(items)
				local diff = 0
				for k, text in now do
					if shown[k] ~= text then
						diff += 1
					end
				end
				for k in shown do
					if now[k] == nil then
						diff += 1
					end
				end
				local result = if not innerHandled
					then "no click handler"
					elseif lost then "the harness lost track (see harness.destroyed); check it in Studio"
					elseif innerPrompt then `purchase prompt: {innerPrompt}`
					elseif diff == 0 then "nothing changed on the screen"
					else `{diff} element(s) changed`
				table.insert(notes, `In "{name}", clicked "{innerName}": {result}.`)
				render(
					items,
					list,
					phone,
					string.format("click-%02d-%02d-%s.png", n, m, slug(innerName)),
					innerWhere
				)
			end
		end
	end

	-- Fold the screens each finding showed up on into its message.
	local out = {}
	for _, f in findings do
		local where = table.concat(f.screens or {}, ", ")
		table.insert(out, {
			severity = f.severity,
			rule = f.rule,
			message = if where ~= "" then `{f.message} [{where}]` else f.message,
		})
	end
	return { findings = out, notes = notes, texts = texts }
end

return Gui
