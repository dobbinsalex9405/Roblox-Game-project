--!strict
-- Loads each creature's uploaded Blender meshes (shared/CreatureMeshes:
-- `assetId`) into ReplicatedStorage.CreatureMeshes, one Model per species
-- named after it, for the client's CreatureView to copy. A creature whose
-- asset is not uploaded (id 0), or fails to load (a Studio place that is not
-- published, an outage), is simply missing there, and the client draws its
-- VoxelArt boxes as before. Loads run in the background, so start-up never
-- waits on them; the client swaps a creature to its meshes when they land.
--
-- InsertService only loads assets owned by the experience's owner, so the
-- uploads must be made by the group that owns the place (ops/ASSETS.md).

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Core.Log)
local CreatureMeshes = require(ReplicatedStorage.Shared.CreatureMeshes)

local CreatureAssets = {}

CreatureAssets.FOLDER = "CreatureMeshes"

-- Every MeshPart the creature needs, found by name anywhere in what loaded
-- (the importer may nest them under the file's joints). Returns nil when
-- one is missing, so a half-imported asset never draws a half creature.
local function collect(loaded: Instance, speciesId: string): Model?
	local entry = CreatureMeshes[speciesId]
	local found: { [string]: MeshPart } = {}
	for _, d in loaded:GetDescendants() do
		if d:IsA("MeshPart") then
			found[d.Name] = d
		end
	end
	if entry.textureId <= 0 then
		return nil -- no colours uploaded: grey meshes would be worse than boxes
	end
	local model = Instance.new("Model")
	model.Name = speciesId
	for _, part in entry.parts do
		for _, mesh in part.meshes do
			local mp: MeshPart? = found[mesh.name]
			if mp == nil then
				model:Destroy()
				return nil
			end
			-- The colours are the uploaded palette image, never the importer's
			-- own PBR textures (their TexturePacks fail to build).
			for _, child in mp:GetChildren() do
				if child:IsA("SurfaceAppearance") then
					child:Destroy()
				end
			end
			mp.TextureID = `rbxassetid://{entry.textureId}`
			mp.Anchored = true
			mp.Parent = model
		end
	end
	return model
end

function CreatureAssets.start(log: Log.Logger)
	local folder = Instance.new("Folder")
	folder.Name = CreatureAssets.FOLDER
	folder.Parent = ReplicatedStorage
	for speciesId, entry in CreatureMeshes do
		if entry.assetId <= 0 then
			continue
		end
		task.spawn(function()
			local ok, loaded = pcall(function()
				return InsertService:LoadAsset(entry.assetId)
			end)
			local model = if ok and typeof(loaded) == "Instance" then collect(loaded, speciesId) else nil
			if ok and typeof(loaded) == "Instance" then
				loaded:Destroy()
			end
			if model then
				model.Parent = folder
			else
				log:warn("creature meshes did not load; drawing voxel boxes", { species = speciesId })
			end
		end)
	end
	return folder
end

return CreatureAssets
