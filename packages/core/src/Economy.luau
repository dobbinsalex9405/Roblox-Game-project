--!strict
-- Module 4: Economy.
-- Currencies live only in server-owned player data. Every change goes through a
-- ledger that checks the amount, refuses to go below zero or above the cap,
-- writes one log line and emits one analytics event.
--
-- Reasons are "<TransactionType>:<sku>", for example "IAP:CoinPackSmall" or
-- "Gameplay:Hatch". The type matches Roblox's AnalyticsEconomyTransactionType
-- names where one fits, so dashboards group them correctly.
--
-- Do not call Economy every second for passive income: batch it (collect
-- button, or one grant per minute), because each change is one analytics event.

local DataService = require("./DataService")
local Log = require("./Log")
local Util = require("./Util")

export type Currency = {
	field: string, -- key in player data that holds the balance
	max: number,
}

export type Flow = "Source" | "Sink"

export type Change = {
	player: any,
	currency: string,
	flow: Flow,
	amount: number,
	balance: number,
	transactionType: string,
	sku: string,
}

export type Ledger = {
	add: (self: Ledger, currency: string, amount: number, reason: string) -> number,
	spend: (self: Ledger, currency: string, amount: number, reason: string) -> boolean,
	balance: (self: Ledger, currency: string) -> number,
	changes: { Change },
}

export type Options = {
	data: DataService.DataService,
	currencies: { [string]: Currency },
	onChange: ((change: Change) -> ())?, -- usually Analytics:economy
}

export type Economy = {
	add: (self: Economy, player: any, currency: string, amount: number, reason: string) -> (boolean, string?),
	spend: (
		self: Economy,
		player: any,
		currency: string,
		amount: number,
		reason: string
	) -> (boolean, string?),
	balance: (self: Economy, player: any, currency: string) -> number?,
	ledger: (self: Economy, player: any, data: { [string]: any }) -> Ledger,
	commit: (self: Economy, ledger: Ledger) -> (),
}

local REASON_PATTERN = "^(%u%a+):([%w_%-]+)$"
local MAX_SAFE = 2 ^ 53

local log = Log.new("Economy")

local Economy = {}

function Economy.parseReason(reason: string): (string, string)
	local transactionType, sku = string.match(reason, REASON_PATTERN)
	if transactionType == nil or sku == nil then
		error(`reason "{reason}" must look like "Type:sku", for example "Gameplay:Hatch"`, 3)
	end
	return transactionType, sku
end

local function checkAmount(amount: number)
	if
		type(amount) ~= "number"
		or amount ~= amount
		or amount // 1 ~= amount
		or amount <= 0
		or amount > MAX_SAFE
	then
		error(`amount must be a positive whole number, got {tostring(amount)}`, 3)
	end
end

function Economy.new(options: Options): Economy
	for name, currency in options.currencies do
		assert(type(currency.field) == "string", `currency {name} needs a data field`)
		assert(currency.max > 0 and currency.max <= MAX_SAFE, `currency {name} has an invalid max`)
	end

	local economy = {}

	local function currencyOf(name: string): Currency
		local currency = options.currencies[name]
		if currency == nil then
			error(`unknown currency "{tostring(name)}"`, 3)
		end
		return currency
	end

	-- A ledger applies changes to a data table (inside DataService:update) and
	-- remembers them so `commit` can log them after the update succeeds.
	function economy.ledger(_self: Economy, player: any, data: { [string]: any }): Ledger
		local ledger = { changes = {} :: { Change } }

		function ledger.balance(_l: Ledger, currencyName: string): number
			local currency = currencyOf(currencyName)
			return data[currency.field] or 0
		end

		function ledger.add(l: Ledger, currencyName: string, amount: number, reason: string): number
			local currency = currencyOf(currencyName)
			checkAmount(amount)
			local transactionType, sku = Economy.parseReason(reason)
			local before = l:balance(currencyName)
			local after = math.min(currency.max, before + amount)
			local applied = after - before
			data[currency.field] = after
			if applied > 0 then
				table.insert(l.changes, {
					player = player,
					currency = currencyName,
					flow = "Source",
					amount = applied,
					balance = after,
					transactionType = transactionType,
					sku = sku,
				})
			end
			return applied
		end

		function ledger.spend(l: Ledger, currencyName: string, amount: number, reason: string): boolean
			local currency = currencyOf(currencyName)
			checkAmount(amount)
			local transactionType, sku = Economy.parseReason(reason)
			local before = l:balance(currencyName)
			if before < amount then
				return false
			end
			data[currency.field] = before - amount
			table.insert(l.changes, {
				player = player,
				currency = currencyName,
				flow = "Sink",
				amount = amount,
				balance = before - amount,
				transactionType = transactionType,
				sku = sku,
			})
			return true
		end

		return (ledger :: any) :: Ledger
	end

	-- Logs and reports every change in a ledger. Call only after the data update succeeded.
	function economy.commit(_self: Economy, ledger: Ledger)
		for _, change in ledger.changes do
			log:info("currency changed", {
				currency = change.currency,
				flow = change.flow,
				amount = change.amount,
				balance = change.balance,
				reason = `{change.transactionType}:{change.sku}`,
				player = change.player,
			})
			if options.onChange then
				local ok, err = Util.try(options.onChange, change)
				if not ok then
					log:error("onChange failed", { err = err })
				end
			end
		end
		table.clear(ledger.changes)
	end

	function economy.add(
		self: Economy,
		player: any,
		currency: string,
		amount: number,
		reason: string
	): (boolean, string?)
		local ledger: Ledger? = nil
		local ok, err = options.data:update(player, function(data)
			local l = self:ledger(player, data)
			l:add(currency, amount, reason)
			ledger = l
		end)
		if ok and ledger then
			self:commit(ledger)
		end
		return ok, err
	end

	function economy.spend(
		self: Economy,
		player: any,
		currency: string,
		amount: number,
		reason: string
	): (boolean, string?)
		local ledger: Ledger? = nil
		local ok, err = options.data:update(player, function(data)
			local l = self:ledger(player, data)
			if not l:spend(currency, amount, reason) then
				error("insufficient funds", 0)
			end
			ledger = l
		end)
		if not ok then
			return false, err
		end
		if ledger then
			self:commit(ledger)
		end
		return true, nil
	end

	function economy.balance(_self: Economy, player: any, currencyName: string): number?
		local data = options.data:get(player)
		if data == nil then
			return nil
		end
		return data[currencyOf(currencyName).field] or 0
	end

	return (economy :: any) :: Economy
end

return Economy
