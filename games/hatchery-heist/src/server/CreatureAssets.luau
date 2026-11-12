--!strict
-- Loads each creature's uploaded Blender meshes (shared/CreatureMeshes:
-- `assetId`) into ReplicatedStorage.CreatureMeshes, one Model per species
-- named after it, for the client's CreatureView to copy. A creature whose
-- asset is not uploaded (id 0), or fails to load (a Studio place that is not
-- published, an outage), is simply missing there, and the client draws its
-- VoxelArt boxes as before. Loads run in the background, so start-up never
-- waits on them; the client swaps a creature to its meshes when they land.
-- A few loads at a time, each retried with a pause: InsertService turns
-- away bursts now and then, which once left one species on its boxes for
-- the whole server. The warning names why a species stayed on boxes.
--
-- InsertService only loads assets owned by the experience's owner, so the
-- uploads must be made by the group that owns the place (ops/ASSETS.md).

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Core.Log)
local Util = require(ReplicatedStorage.Core.Util)
local CreatureMeshes = require(ReplicatedStorage.Shared.CreatureMeshes)

local CreatureAssets = {}

CreatureAssets.FOLDER = "CreatureMeshes"
CreatureAssets.WORKERS = 4 -- loads in flight at once
CreatureAssets.RETRY_SECONDS = { 2, 5, 10 } -- pauses between tries of one load
CreatureAssets.COUNT_ATTRIBUTE = "MeshCount" -- on each species model: its MeshParts

-- Every MeshPart the creature needs, found by name anywhere in what loaded
-- (the importer may nest them under the file's joints). Returns nil when
-- a solid mesh is missing, so a half-imported asset never draws a half
-- creature; the second value then says why. A missing glow mesh (a thin
-- accent: glowing paws, a belly stripe) only loses that accent. The four
-- species that kept falling back to boxes (EmberFox, FrostWolf, CrystalStag,
-- MoonUnicorn) are exactly the ones with a ground-level paw-glow mesh, so a
-- dropped glow mesh is the likely cause; the third value names what was
-- left out, and the log line says it.
local function collect(loaded: Instance, speciesId: string): (Model?, string?, string?)
	local entry = CreatureMeshes[speciesId]
	local found: { [string]: MeshPart } = {}
	for _, d in loaded:GetDescendants() do
		if d:IsA("MeshPart") then
			found[d.Name] = d
		end
	end
	if entry.textureId <= 0 then
		return nil, "no colour image uploaded" -- grey meshes would be worse than boxes
	end
	local model = Instance.new("Model")
	model.Name = speciesId
	local skipped: { string } = {}
	for _, part in entry.parts do
		for _, mesh in part.meshes do
			local mp: MeshPart? = found[mesh.name]
			if mp == nil and mesh.glow ~= nil then
				table.insert(skipped, mesh.name)
				continue
			elseif mp == nil then
				model:Destroy()
				return nil, `mesh {mesh.name} missing from asset {entry.assetId}`, nil
			end
			assert(mp, "mesh part checked above")
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
	-- How many meshes the client must see before it loads them: the model
	-- reaches the client before all of its MeshParts do (shared/MeshArrival).
	model:SetAttribute(CreatureAssets.COUNT_ATTRIBUTE, #model:GetChildren())
	return model, nil, if #skipped > 0 then table.concat(skipped, ", ") else nil
end

function CreatureAssets.start(log: Log.Logger)
	local folder = Instance.new("Folder")
	folder.Name = CreatureAssets.FOLDER
	folder.Parent = ReplicatedStorage
	local queue: { string } = {}
	for speciesId, entry in CreatureMeshes do
		if entry.assetId > 0 then
			table.insert(queue, speciesId)
		end
	end
	table.sort(queue)
	local function loadOne(speciesId: string)
		local entry = CreatureMeshes[speciesId]
		local loaded, err = Util.retry(
			function(): Instance
				return InsertService:LoadAsset(entry.assetId)
			end,
			CreatureAssets.RETRY_SECONDS,
			function(seconds)
				task.wait(seconds)
			end
		)
		local model, why, skipped = nil, err, nil
		if loaded then
			model, why, skipped = collect(loaded, speciesId)
			loaded:Destroy()
		end
		if model then
			if skipped then
				log:warn("creature glow meshes missing; drawing the creature without them", {
					species = speciesId,
					meshes = skipped,
				})
			end
			model.Parent = folder
		else
			log:warn("creature meshes did not load; drawing voxel boxes", {
				species = speciesId,
				reason = if why then string.sub(why, 1, 200) else "unknown",
			})
		end
	end
	for _ = 1, CreatureAssets.WORKERS do
		task.spawn(function()
			while #queue > 0 do
				loadOne(table.remove(queue, 1) :: string)
			end
		end)
	end
	return folder
end

return CreatureAssets
