--!nocheck
-- Turns a booted place (Lune's Roblox instances) into the plain data the
-- audit checks and renders: World boxes and labels, Gui nodes.

local roblox = require("@lune/roblox")
local World = require("./World")

local Collect = {}

local function color3(c: any): World.Color
	if c == nil then
		return { r = 0.6, g = 0.6, b = 0.6 }
	end
	return { r = c.R, g = c.G, b = c.B }
end

local function prop(inst: any, name: string, default: any): any
	local ok, value = pcall(function()
		return inst[name]
	end)
	if ok and value ~= nil then
		return value
	end
	return default
end

local function axes(cf: any): (any, any, any)
	return cf.XVector, cf.YVector, cf.ZVector
end

local function isUnder(inst: any, ancestors: { any }): boolean
	for _, a in ancestors do
		if a ~= nil and inst:IsDescendantOf(a) then
			return true
		end
	end
	return false
end

-- Where Roblox would have the part. Lune keeps a part's Position apart from
-- its CFrame (setting one does not move the other), so game code that places
-- parts with `part.Position = ...` leaves CFrame at the origin. In Roblox both
-- are one value. A Position that was set while the CFrame stayed at the
-- origin wins; otherwise the CFrame does.
function Collect.cframe(part: any): any
	local cf = part.CFrame
	local okPos, pos = pcall(function()
		return part.Position
	end)
	local okOri, ori = pcall(function()
		return part.Orientation
	end)
	local atOrigin = cf.Position.Magnitude < 1e-6
	local unrotated = cf.XVector.X > 0.999999 and cf.YVector.Y > 0.999999
	if okOri and ori and ori.Magnitude > 1e-6 and unrotated then
		local okBuild, rotated = pcall(function()
			return roblox.CFrame.fromOrientation(math.rad(ori.X), math.rad(ori.Y), math.rad(ori.Z))
		end)
		if okBuild then
			cf = roblox.CFrame.new(cf.Position) * rotated
		end
	end
	if okPos and pos and atOrigin and pos.Magnitude > 1e-6 then
		cf = cf - cf.Position + pos
	end
	return cf
end

function Collect.box(part: any, workspace: any): World.Box
	local cf = Collect.cframe(part)
	local x, y, z = axes(cf)
	local size = part.Size
	local isSpawn = part.ClassName == "SpawnLocation"
	return {
		name = part.Name,
		path = part:GetFullName(),
		className = part.ClassName,
		cx = cf.Position.X,
		cy = cf.Position.Y,
		cz = cf.Position.Z,
		rx = x.X,
		ry = x.Y,
		rz = x.Z,
		ux = y.X,
		uy = y.Y,
		uz = y.Z,
		bx = z.X,
		by = z.Y,
		bz = z.Z,
		hx = size.X / 2,
		hy = size.Y / 2,
		hz = size.Z / 2,
		color = color3(prop(part, "Color", nil)),
		transparency = prop(part, "Transparency", 0),
		canCollide = prop(part, "CanCollide", true),
		isGround = part.Name == "Baseplate" and part.Parent == workspace,
		isSpawn = isSpawn,
		enabled = if isSpawn then prop(part, "Enabled", true) ~= false else true,
	}
end

-- World position of a part or attachment.
local function anchorPosition(inst: any): any
	if inst == nil then
		return nil
	end
	if inst:IsA("BasePart") then
		return Collect.cframe(inst).Position
	end
	if inst:IsA("Attachment") then
		local parent = inst.Parent
		if parent and parent:IsA("BasePart") then
			return (Collect.cframe(parent) * inst.CFrame).Position
		end
	end
	if inst:IsA("Model") then
		local primary = prop(inst, "PrimaryPart", nil)
		if primary then
			return Collect.cframe(primary).Position
		end
	end
	return nil
end

local function textOf(gui: any): string
	local parts = {}
	for _, d in gui:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local t = prop(d, "Text", "")
			if t ~= "" and prop(d, "Visible", true) then
				table.insert(parts, t)
			end
		end
	end
	return table.concat(parts, "\n")
end

local FACE_AXIS = {
	Right = { 1, 0, 0 },
	Left = { -1, 0, 0 },
	Top = { 0, 1, 0 },
	Bottom = { 0, -1, 0 },
	Back = { 0, 0, 1 },
	Front = { 0, 0, -1 },
}

-- Boxes and labels in the world, leaving out the characters (the player
-- model the boot shim makes is not part of the game's world).
function Collect.world(game: any, characters: { any }): ({ World.Box }, { World.Label })
	local workspace = game:GetService("Workspace")
	local boxes: { World.Box } = {}
	local labels: { World.Label } = {}
	for _, d in workspace:GetDescendants() do
		if not isUnder(d, characters) then
			if d:IsA("BasePart") and d.ClassName ~= "Terrain" then
				table.insert(boxes, Collect.box(d, workspace))
			end
		end
	end

	local roots = { workspace }
	for _, p in game:GetService("Players"):GetChildren() do
		local pg = p:FindFirstChild("PlayerGui")
		if pg then
			table.insert(roots, pg)
		end
	end
	for _, root in roots do
		for _, d in root:GetDescendants() do
			if not isUnder(d, characters) then
				if d:IsA("BillboardGui") and prop(d, "Enabled", true) then
					local pos = anchorPosition(prop(d, "Adornee", nil) or d.Parent)
					if pos then
						local offset = prop(d, "StudsOffsetWorldSpace", nil)
						local local_ = prop(d, "StudsOffset", nil)
						local x, y, z = pos.X, pos.Y, pos.Z
						if offset then
							x, y, z = x + offset.X, y + offset.Y, z + offset.Z
						end
						if local_ then
							y += local_.Y
						end
						table.insert(labels, {
							path = d:GetFullName(),
							kind = "Billboard",
							text = textOf(d),
							x = x,
							y = y,
							z = z,
							alwaysOnTop = prop(d, "AlwaysOnTop", false),
							reach = 0,
						})
					end
				elseif d:IsA("SurfaceGui") and prop(d, "Enabled", true) then
					local part = prop(d, "Adornee", nil) or d.Parent
					if part and part:IsA("BasePart") then
						local face = prop(d, "Face", nil)
						local axis = FACE_AXIS[if face then face.Name else "Front"] or FACE_AXIS.Front
						local half = part.Size / 2
						local cf = Collect.cframe(part)
						local p = (cf * roblox.CFrame.new(
							axis[1] * half.X,
							axis[2] * half.Y,
							axis[3] * half.Z
						)).Position
						table.insert(labels, {
							path = d:GetFullName(),
							kind = "Surface",
							text = textOf(d),
							x = p.X,
							y = p.Y,
							z = p.Z,
							alwaysOnTop = false,
							reach = 0,
						})
					end
				elseif d:IsA("ProximityPrompt") and prop(d, "Enabled", true) then
					local pos = anchorPosition(d.Parent)
					if pos then
						local action = prop(d, "ActionText", "")
						local object = prop(d, "ObjectText", "")
						table.insert(labels, {
							path = d:GetFullName(),
							kind = "Prompt",
							text = if object ~= "" then `{action} {object}` else action,
							x = pos.X,
							y = pos.Y,
							z = pos.Z,
							alwaysOnTop = true,
							reach = prop(d, "MaxActivationDistance", 10),
						})
					end
				end
			end
		end
	end
	return boxes, labels
end

return Collect
