--!strict
-- Studio-only test panel (the client half is client/TestPanelUi.luau).
--
-- It only starts when RunService:IsStudio() is true on the server, so a live
-- server never listens to it. In Studio each command is also checked against
-- who sent it: Studio's own test players (user ids <= 0), the place's creator,
-- or the owner of the group that owns the place.
--
-- Commands (Test:Command action, key, amount):
--   info                       send the panel what it can do
--   currency  <currency> <n>   add n of a currency (a negative n spends it)
--   pass      <pass>     1|0   own / stop owning a pass for this session
--   product   <product>        buy a product through the real receipt path,
--                              with a new fake purchase id
--   replay    <product>        send the last fake purchase id again: proves a
--                              repeated receipt grants nothing
--   reset                      wipe this player's save back to the template,
--                              then kick so the next join starts fresh

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataService = require(ReplicatedStorage.Core.DataService)
local Economy = require(ReplicatedStorage.Core.Economy)
local Log = require(ReplicatedStorage.Core.Log)
local Passes = require(ReplicatedStorage.Core.Passes)
local Receipts = require(ReplicatedStorage.Core.Receipts)
local ShopRemotes = require(ReplicatedStorage.Core.ShopRemotes)
local Util = require(ReplicatedStorage.Core.Util)

local ServerNet = require(script.Parent.ServerNet)

export type Deps = {
	net: ServerNet.ServerNet,
	data: DataService.DataService,
	economy: Economy.Economy,
	receipts: Receipts.Receipts,
	passes: Passes.Passes,
	passIds: { [string]: number },
	currencies: { [string]: any },
	template: { [string]: any },
	-- Called after a pass changes so clients and the shop see it.
	passesChanged: (player: Player) -> (),
}

local log = Log.new("TestPanel")

local TestPanel = {}

-- Whether this player may use the panel. Only ever asked on a Studio server.
local function authorized(player: Player): boolean
	if player.UserId <= 0 then
		return true -- Studio's local test players (Player1, Player2...)
	end
	if game.CreatorType == Enum.CreatorType.User then
		return game.CreatorId == 0 or player.UserId == game.CreatorId
	end
	local ok, info = pcall(function()
		return GroupService:GetGroupInfoAsync(game.CreatorId)
	end)
	return ok and type(info) == "table" and info.Owner ~= nil and info.Owner.Id == player.UserId
end

function TestPanel.start(deps: Deps): boolean
	if not RunService:IsStudio() then
		return false
	end

	local counter = 0
	local lastPurchase: { [Player]: { [string]: string } } = {}
	local allowed: { [Player]: boolean } = {}

	local function result(player: Player, text: string)
		deps.net:fire(ShopRemotes["Test:Result"], player, text)
	end

	local function sorted(map: { [string]: any }): { string }
		local out = {}
		for key in map do
			table.insert(out, key)
		end
		table.sort(out)
		return out
	end

	local function info(player: Player)
		local passes = {}
		for _, key in sorted(deps.passIds) do
			table.insert(passes, { key = key, owned = deps.passes:owns(player, key) })
		end
		local currencies = {}
		for _, key in sorted(deps.currencies) do
			table.insert(currencies, { key = key, balance = deps.economy:balance(player, key) or 0 })
		end
		deps.net:fire(ShopRemotes["Test:Info"], player, {
			currencies = currencies,
			passes = passes,
			products = deps.receipts:keys(),
		})
	end

	local commands: { [string]: (player: Player, key: string, amount: number) -> string } = {}

	function commands.currency(player: Player, key: string, amount: number): string
		if deps.currencies[key] == nil then
			return `No currency called {key}.`
		end
		amount = math.floor(amount)
		if amount == 0 then
			return "Amount must not be 0."
		end
		local ok, err
		if amount > 0 then
			ok, err = deps.economy:add(player, key, amount, "Admin:StudioTest")
		else
			ok, err = deps.economy:spend(player, key, -amount, "Admin:StudioTest")
		end
		if not ok then
			return `Could not change {key}: {err or "not enough"}.`
		end
		return `{if amount > 0 then "Added" else "Spent"} {math.abs(amount)} {key}. Balance: {deps.economy:balance(
			player,
			key
		) or 0}.`
	end

	function commands.pass(player: Player, key: string, amount: number): string
		if deps.passIds[key] == nil then
			return `No pass called {key}.`
		end
		local own = amount ~= 0
		deps.passes:setSessionOwned(player, key, own)
		deps.passesChanged(player)
		return if own
			then `You own {key} until you leave (not saved; Roblox is asked again next join).`
			else `You no longer own {key} this session.`
	end

	function commands.product(player: Player, key: string): string
		counter += 1
		local purchaseId = `studio-{player.UserId}-{os.time()}-{counter}`
		local decision, fresh = deps.receipts:grant(player, key, purchaseId)
		if decision ~= "PurchaseGranted" then
			return `{key}: not granted ({decision}). Check the output log.`
		end
		local last = lastPurchase[player] or {}
		lastPurchase[player] = last
		last[key] = purchaseId
		return if fresh
			then `{key} granted through the receipt path (purchase {purchaseId}).`
			else `{key}: purchase {purchaseId} was already granted.`
	end

	function commands.replay(player: Player, key: string): string
		local purchaseId = lastPurchase[player] and lastPurchase[player][key]
		if purchaseId == nil then
			return `Buy {key} once first, then replay it.`
		end
		local decision, fresh = deps.receipts:grant(player, key, purchaseId)
		if decision == "PurchaseGranted" and not fresh then
			return `Replayed purchase {purchaseId}: Roblox would be told "granted" and nothing was given twice. Exactly-once works.`
		end
		return `PROBLEM: replaying {purchaseId} gave {decision}, granted again = {tostring(fresh)}.`
	end

	function commands.reset(player: Player): string
		local ok, err = deps.data:update(player, function(d)
			local version = d.version
			for key in table.clone(d) do
				d[key] = nil
			end
			for key, value in Util.deepCopy(deps.template) do
				d[key] = value
			end
			d.version = version
		end)
		if not ok then
			return `Reset failed: {err}.`
		end
		lastPurchase[player] = nil
		task.delay(1, function()
			if player.Parent == Players then
				player:Kick(
					"Save reset from the Studio test panel. Start the test again to play from the beginning."
				)
			end
		end)
		return "Save reset to a brand-new player. Leaving so the game starts fresh..."
	end

	deps.net:on(
		ShopRemotes["Test:Command"],
		function(player: Player, action: string, key: string, amount: number)
			if allowed[player] == nil then
				allowed[player] = authorized(player)
			end
			if not allowed[player] then
				log:warn("test panel used by someone who is not the creator", { userId = player.UserId })
				return
			end
			if not deps.data:isLoaded(player) then
				result(player, "Your data has not loaded yet.")
				return
			end
			if action == "info" then
				info(player)
				return
			end
			local command = commands[action]
			if command == nil then
				return
			end
			local ok, text = Util.try(function()
				local message = command(player, key, amount)
				result(player, message)
			end)
			if not ok then
				result(player, `Command failed: {text}`)
			end
			info(player)
		end
	)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastPurchase[player] = nil
		allowed[player] = nil
	end)

	log:info("Studio test panel is on")
	return true
end

return TestPanel
