--!strict
-- Starts every core service on the server and runs the player lifecycle:
--
-- It also runs the Feedback button's server side: every game gets it.
--
--   join:  load data (kick with a clear message if it cannot load) -> record
--          join times -> read policy -> check passes -> start analytics session
--          -> send the client its data and passes -> run the game's onPlayerReady
--   leave: end analytics session -> forget per-player state -> save and
--          release data
--
-- A game calls CoreServer.start once from its server script, then registers its
-- products, pass hooks and remote handlers on the returned services.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")

local Core = ReplicatedStorage.Core
local Analytics = require(Core.Analytics)
local CoreRemotes = require(Core.CoreRemotes)
local DataService = require(Core.DataService)
local Economy = require(Core.Economy)
local ErrorReporter = require(Core.ErrorReporter)
local Feedback = require(Core.Feedback)
local Log = require(Core.Log)
local Net = require(Core.Net)
local Odds = require(Core.Odds)
local Passes = require(Core.Passes)
local Policy = require(Core.Policy)
local Receipts = require(Core.Receipts)
local ShopRemotes = require(Core.ShopRemotes)
local Util = require(Core.Util)

local ProfileStoreAdapter = require(script.Parent.ProfileStoreAdapter)
local Purchases = require(script.Parent.Purchases)
local RobloxSinks = require(script.Parent.RobloxSinks)
local ServerNet = require(script.Parent.ServerNet)
local TestPanel = require(script.Parent.TestPanel)

local RECEIPTS_FIELD = "receipts"
local FLUSH_EVERY = 5 -- seconds between ErrorReporter/Feedback flush checks (each writes at most once a minute)

export type Options = {
	game: string, -- folder name, e.g. "hatchery-heist"
	build: string, -- git commit the place was built from
	dataStoreName: string,
	template: { [string]: any },
	migrations: { DataService.Migration },
	currencies: { [string]: Economy.Currency },
	passes: { [string]: number },
	oddsTables: { Odds.TableDef },
	remotes: { [string]: Net.Remote },
	onPlayerReady: ((player: Player) -> ())?,
	onPlayerLeaving: ((player: Player) -> ())?,
	-- A few values that help reproduce a bug report (area, level, what the
	-- player is holding). Called when the player sends feedback; at most 12
	-- keys of numbers, booleans or short strings are kept.
	feedbackContext: ((player: Player) -> { [string]: any })?,
}

export type Services = {
	data: DataService.DataService,
	economy: Economy.Economy,
	receipts: Receipts.Receipts,
	passes: Passes.Passes,
	odds: Odds.Odds,
	policy: Policy.Policy,
	analytics: Analytics.Analytics,
	errors: ErrorReporter.Reporter,
	feedback: Feedback.Feedback,
	net: ServerNet.ServerNet,
	-- The shared shop: call shop:setCatalog after registering products.
	shop: Purchases.Shop,
}

local log = Log.new("CoreServer")

local CoreServer = {}

local started = false

local function snapshot(data: { [string]: any }): { [string]: any }
	local out = table.clone(data)
	out[RECEIPTS_FIELD] = nil
	out._retired = nil
	return out
end

function CoreServer.start(options: Options): Services
	assert(not started, "CoreServer.start called twice")
	started = true

	local net = ServerNet.start({ CoreRemotes, ShopRemotes, options.remotes })

	local errors = ErrorReporter.new({
		game = options.game,
		build = options.build,
		write = RobloxSinks.errorQueue(),
	})
	ScriptContext.Error:Connect(function(message: string, trace: string)
		errors:record("server", message, trace, os.time())
	end)

	local feedback = Feedback.new({
		game = options.game,
		build = options.build,
		placeVersion = game.PlaceVersion,
		server = game.JobId,
		write = RobloxSinks.feedbackStore(),
		filter = RobloxSinks.textFilter(),
	})

	task.spawn(function()
		while true do
			task.wait(FLUSH_EVERY)
			errors:flush(os.time())
			feedback:flush(os.time())
		end
	end)
	game:BindToClose(function()
		errors:flush(os.time(), true)
		feedback:flush(os.time(), true)
	end)

	local analytics = Analytics.new(RobloxSinks.analytics())

	local data: DataService.DataService
	local store = ProfileStoreAdapter.store(options.dataStoreName, function(player: Player)
		-- Another server took this player's session: stop using stale data. Sessions
		-- this server ends itself (leaving, or a refused load) are not registered
		-- with DataService at that moment, so they do not kick.
		if player.Parent == Players and data:profile(player) ~= nil then
			player:Kick("Your data was opened in another server. Please rejoin.")
		end
	end)
	data = DataService.new({
		store = store,
		template = options.template,
		migrations = options.migrations,
	})

	local economy = Economy.new({
		data = data,
		currencies = options.currencies,
		onChange = function(change)
			analytics:economy(change)
		end,
	})

	local receipts = Receipts.new({
		data = data,
		economy = economy,
		receiptsField = RECEIPTS_FIELD,
		findPlayer = function(userId: number)
			return Players:GetPlayerByUserId(userId)
		end,
		persist = function(player: Player, purchaseId: string)
			return ProfileStoreAdapter.persist(data, player, purchaseId, RECEIPTS_FIELD)
		end,
		onGranted = function(player: Player, productKey: string, robux: number)
			analytics:purchase(player, productKey, robux)
		end,
	})
	MarketplaceService.ProcessReceipt = function(info)
		local decision = receipts:process(info)
		return if decision == "PurchaseGranted"
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local passes: Passes.Passes
	local shop: Purchases.Shop? = nil
	local function sendPasses(player: Player)
		local owned = {}
		for key in options.passes do
			if passes:owns(player, key) then
				table.insert(owned, key)
			end
		end
		table.sort(owned)
		net:fire(CoreRemotes["Core:Passes"], player, owned)
		if shop then
			shop:refresh(player)
		end
	end
	passes = Passes.new({
		passes = options.passes,
		ownsAsync = function(player: Player, passId: number)
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end,
		onOwned = function(player: Player, _key: string)
			if player.Parent == Players then
				sendPasses(player)
			end
		end,
	})
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			passes:onPurchaseFinished(player, passId, purchased)
		end
	)

	local policy = Policy.new({
		fetch = function(player: Player)
			return PolicyService:GetPolicyInfoForPlayerAsync(player) :: any
		end,
	})

	local rng = Random.new()
	local odds = Odds.new({
		randomInteger = function(min: number, max: number)
			return rng:NextInteger(min, max)
		end,
	})
	for _, def in options.oddsTables do
		odds:define(def)
	end
	local function sendOdds(player: Player, tableId: string)
		net:fire(CoreRemotes["Core:Odds"], player, odds:display(tableId, player))
		if shop then
			shop:oddsShown(player, tableId)
		end
	end
	odds:onChanged(function(player: Player, tableId: string)
		if player.Parent == Players then
			sendOdds(player, tableId)
		end
	end)

	-- The shared shop, and the test panel (it only starts on a Studio server).
	local theShop = Purchases.start({
		net = net,
		receipts = receipts,
		passes = passes,
		passIds = options.passes,
		policy = policy,
		studio = RunService:IsStudio(),
	})
	shop = theShop
	TestPanel.start({
		net = net,
		data = data,
		economy = economy,
		receipts = receipts,
		passes = passes,
		passIds = options.passes,
		currencies = options.currencies,
		template = options.template,
		passesChanged = sendPasses,
	})

	-- Core remotes.
	net:on(CoreRemotes["Core:ClientError"], function(player: Player, message: string, trace: string)
		local now = os.time()
		local signature = errors:record("client", message, trace, now)
		feedback:noteError(player.UserId, signature, message, now)
		log:info("client error", { userId = player.UserId })
	end)

	local joinedAt: { [Player]: number } = {}
	local function feedbackInfo(player: Player, now: number): Feedback.PlayerInfo
		local position = ""
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local p = root.Position
			position = `{math.round(p.X)},{math.round(p.Y)},{math.round(p.Z)}`
		end
		local pingOk, ping = pcall(function(): number
			return player:GetNetworkPing()
		end)
		local context: { [string]: any }? = nil
		if options.feedbackContext then
			local ok, result = pcall(options.feedbackContext, player)
			if ok then
				context = result
			else
				log:warn("feedbackContext failed", { userId = player.UserId, err = tostring(result) })
			end
		end
		return {
			userId = player.UserId,
			accountAgeDays = player.AccountAge,
			locale = player.LocaleId,
			sessionSeconds = now - (joinedAt[player] or now),
			pingMs = if pingOk then ping * 1000 else 0,
			position = position,
			context = context,
		}
	end
	net:on(
		CoreRemotes["Core:Feedback"],
		function(
			player: Player,
			category: Feedback.Category,
			text: string,
			rating: number,
			client: Feedback.ClientInfo
		)
			local now = os.time()
			local sent, message = feedback:submit(feedbackInfo(player, now), {
				category = category,
				text = text,
				rating = rating,
				client = client,
			}, now)
			if player.Parent == Players then
				net:fire(CoreRemotes["Core:FeedbackResult"], player, sent, message)
			end
			if sent then
				analytics:custom(player, "Feedback:Sent", 1, { category :: string })
				if rating > 0 then
					analytics:custom(player, "Feedback:Rating", rating)
				end
			end
		end
	)
	net:on(CoreRemotes["Core:RequestOdds"], function(player: Player, tableId: string)
		if odds:has(tableId) then
			sendOdds(player, tableId)
		end
	end)

	-- Send each player a snapshot of their data after changes, at most once per frame.
	local pendingSnapshot: { [Player]: boolean } = {}
	data:onChanged(function(player: Player)
		if pendingSnapshot[player] then
			return
		end
		pendingSnapshot[player] = true
		task.defer(function()
			pendingSnapshot[player] = nil
			local current = data:get(player)
			if current and player.Parent == Players then
				net:fire(CoreRemotes["Core:Data"], player, snapshot(current))
			end
		end)
	end)

	local function onPlayerAdded(player: Player)
		joinedAt[player] = os.time()
		local result, reason = data:load(player, player.UserId)
		if player.Parent ~= Players then
			data:release(player)
			return
		end
		if result ~= "loaded" then
			log:warn("data did not load", { userId = player.UserId, result = result, reason = reason })
			if result == "too-new" then
				player:Kick("This server is running an older version of the game. Please rejoin.")
			else
				player:Kick("Your data could not be loaded, so nothing was changed. Please rejoin.")
			end
			return
		end

		local now = os.time()
		local before = data:get(player) :: { [string]: any }
		local meta: { [string]: any } = before.meta or {}
		local info: Analytics.SessionInfo = {
			firstJoinAt = meta.firstJoinAt or 0,
			lastJoinAt = meta.lastJoinAt or 0,
		}
		data:update(player, function(d)
			d.meta = d.meta or {}
			if (d.meta.firstJoinAt or 0) <= 0 then
				d.meta.firstJoinAt = now
			end
			d.meta.lastJoinAt = now
			d.meta.sessions = (d.meta.sessions or 0) + 1
		end)

		policy:load(player)
		passes:load(player)
		if player.Parent ~= Players then
			return
		end
		analytics:sessionStart(player, info, now)
		sendPasses(player)
		net:fire(CoreRemotes["Core:Data"], player, snapshot(data:get(player) :: any))

		if options.onPlayerReady then
			local ok, err = Util.try(options.onPlayerReady, player)
			if not ok then
				log:error("onPlayerReady failed", { userId = player.UserId, err = err })
			end
		end
	end

	local function onPlayerRemoving(player: Player)
		if options.onPlayerLeaving and data:isLoaded(player) then
			local ok, err = Util.try(options.onPlayerLeaving, player)
			if not ok then
				log:error("onPlayerLeaving failed", { userId = player.UserId, err = err })
			end
		end
		analytics:sessionEnd(player, os.time())
		odds:forget(player)
		theShop:forget(player)
		passes:release(player)
		policy:release(player)
		pendingSnapshot[player] = nil
		feedback:forget(player.UserId)
		joinedAt[player] = nil
		data:release(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	log:info("core started", { game = options.game, build = options.build, studio = RunService:IsStudio() })

	return {
		data = data,
		economy = economy,
		receipts = receipts,
		passes = passes,
		odds = odds,
		policy = policy,
		analytics = analytics,
		errors = errors,
		feedback = feedback,
		net = net,
		shop = theShop,
	}
end

return CoreServer
