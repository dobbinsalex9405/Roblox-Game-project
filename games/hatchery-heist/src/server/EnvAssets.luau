--!strict
-- Loads the outdoor nature meshes (shared/EnvArt: `assetId`) and the
-- skybox and grass images. Each model's MeshParts become a template in
-- ServerStorage; Scenery asks for a template with `when` and places copies
-- with `place`. A model that is not uploaded (id 0) or fails to load never
-- arrives, and Scenery keeps its box tree there (small props are simply
-- left out). Loads run in the background, so start-up never waits on them.
--
-- InsertService only loads assets owned by the experience's owner, so the
-- uploads are made by the group that owns the place (ops/ASSETS.md).

local InsertService = game:GetService("InsertService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Log = require(ReplicatedStorage.Core.Log)
local EnvArt = require(ReplicatedStorage.Shared.EnvArt)

local EnvAssets = {}

EnvAssets.FOLDER = "EnvMeshes"

local templates: { [string]: Model } = {}
local waiting: { [string]: { (Model) -> () } } = {}
local folder: Folder? = nil

local function vec(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

-- Calls `fn(template)` once the model's meshes have loaded (at once if they
-- already have). Never called for a model that does not load.
function EnvAssets.when(modelId: string, fn: (Model) -> ())
	local template = templates[modelId]
	if template then
		fn(template)
		return
	end
	local list = waiting[modelId] or {}
	waiting[modelId] = list
	table.insert(list, fn)
end

-- A copy of a template at `cframe` (the model's base centre), `scale` times
-- its modelled size.
function EnvAssets.place(template: Model, cframe: CFrame, scale: number, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = template.Name
	for _, source in template:GetChildren() do
		if source:IsA("MeshPart") then
			local copy = source:Clone()
			local center = source:GetAttribute("Center") :: Vector3
			copy.Size = source.Size * scale
			copy.CFrame = cframe * CFrame.new(center * scale)
			copy.Parent = model
		end
	end
	model.Parent = parent
	return model
end

-- Every MeshPart the model needs, found by name in what loaded, coloured
-- and sized from EnvArt. nil when one is missing, so a half-imported asset
-- never draws half a tree.
local function collect(loaded: Instance, modelId: string): Model?
	local entry = EnvArt.models[modelId]
	local found: { [string]: MeshPart } = {}
	for _, d in loaded:GetDescendants() do
		if d:IsA("MeshPart") then
			found[d.Name] = d
		end
	end
	local model = Instance.new("Model")
	model.Name = modelId
	local small = entry.kind ~= "tree" and entry.kind ~= "rock"
	for _, mesh in entry.meshes do
		local mp: MeshPart? = found[mesh.name]
		if mp == nil then
			model:Destroy()
			return nil
		end
		for _, child in mp:GetChildren() do
			child:Destroy() -- no SurfaceAppearance or textures: the colour is the Color
		end
		mp.TextureID = ""
		mp.Anchored = true
		mp.CanCollide = false
		mp.CanTouch = false
		mp.CanQuery = false
		mp.CastShadow = not small
		mp.Color = Color3.fromHex(mesh.color)
		mp.Material = if mesh.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		mp.Size = vec(mesh.size)
		mp:SetAttribute("Center", vec(mesh.center))
		mp.CFrame = CFrame.new(vec(mesh.center))
		mp.Parent = model
	end
	return model
end

-- An uploaded Image asset as a content id. The images are Image assets
-- (tools/art/env/upload.py): a Decal id on a Sky face or Texture draws
-- nothing, so EnvArt leaves anything else at 0.
function EnvAssets.image(id: number): string
	return `rbxassetid://{id}`
end

local SKY_FACES = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }

-- The uploaded skybox, once all six faces are known; then `onSky` runs
-- (Scenery thins the clouds and haze to suit it).
local function loadSky(log: Log.Logger, onSky: (() -> ())?)
	local images = EnvArt.images :: any
	for _, face in SKY_FACES do
		if images[face] <= 0 then
			return
		end
	end
	task.spawn(function()
		local urls = {}
		for _, face in SKY_FACES do
			urls[face] = EnvAssets.image(images[face])
		end
		local sky = Lighting:FindFirstChildOfClass("Sky")
		if not sky then
			log:warn("no Sky to put the uploaded skybox on")
			return
		end
		for _, face in SKY_FACES do
			(sky :: any)[face] = urls[face]
		end
		if onSky then
			onSky()
		end
	end)
end

-- Starts every load. `onGrass(url)` gets the grass tile once it is known;
-- `onSky()` runs once the skybox is on.
function EnvAssets.start(log: Log.Logger, onGrass: ((string) -> ())?, onSky: (() -> ())?): Folder
	local f = Instance.new("Folder")
	f.Name = EnvAssets.FOLDER
	f.Parent = ServerStorage
	folder = f
	for modelId, entry in EnvArt.models do
		if entry.assetId <= 0 then
			continue
		end
		task.spawn(function()
			local ok, loaded = pcall(function()
				return InsertService:LoadAsset(entry.assetId)
			end)
			local model = if ok and typeof(loaded) == "Instance" then collect(loaded, modelId) else nil
			if ok and typeof(loaded) == "Instance" then
				loaded:Destroy()
			end
			if not model then
				log:warn("nature meshes did not load", { model = modelId })
				return
			end
			model.Parent = f
			templates[modelId] = model
			local list = waiting[modelId]
			waiting[modelId] = nil
			if list then
				for _, fn in list do
					task.spawn(fn, model)
				end
			end
		end)
	end
	loadSky(log, onSky)
	if onGrass and EnvArt.images.Grass > 0 then
		task.spawn(function()
			onGrass(EnvAssets.image(EnvArt.images.Grass))
		end)
	end
	return f
end

-- For tests and tools: the folder holding the loaded templates.
function EnvAssets.folder(): Folder?
	return folder
end

return EnvAssets
