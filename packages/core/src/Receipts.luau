--!strict
-- Module 5: Receipts.
-- Handles developer product purchases (MarketplaceService.ProcessReceipt).
-- The purchase id is written into the player's saved data in the same update
-- that grants the item, and Roblox is told "granted" only after that data has
-- been saved. So:
--
--  * a repeat receipt for the same purchase grants nothing a second time;
--  * if the save fails or the player leaves first, Roblox is told "not
--    processed yet" and retries later, and the retry sees the saved id (if the
--    save landed) or grants afresh (if it did not). A purchase is never lost
--    and never doubled.

local DataService = require("./DataService")
local Economy = require("./Economy")
local Log = require("./Log")
local Util = require("./Util")

export type Decision = "PurchaseGranted" | "NotProcessedYet"

export type ReceiptInfo = {
	PlayerId: number,
	ProductId: number,
	PurchaseId: string,
	CurrencySpent: number?,
}

-- Grants run inside a data update: change `data` or use `ledger`, never yield.
export type Grant = (player: any, data: { [string]: any }, ledger: Economy.Ledger) -> ()

export type Options = {
	data: DataService.DataService,
	economy: Economy.Economy,
	findPlayer: (userId: number) -> any?,
	-- Saves the player's data now and returns true once a save that includes
	-- `purchaseId` has landed. May yield. Returns false on failure or timeout.
	persist: (player: any, purchaseId: string) -> boolean,
	onGranted: ((player: any, productKey: string, robux: number) -> ())?,
	receiptsField: string?, -- defaults to "receipts"
	maxStored: number?, -- recent purchase ids kept per player, defaults to 100
}

export type Receipts = {
	-- `productId` may be 0 while the product does not exist on Roblox yet:
	-- it is then known by key only (Studio test grants), never by a receipt.
	register: (self: Receipts, productKey: string, productId: number, grant: Grant) -> (),
	process: (self: Receipts, receipt: ReceiptInfo) -> Decision,
	-- Runs a purchase of `productKey` through exactly the same path as a real
	-- receipt (same exactly-once bookkeeping). Used by the Studio test panel.
	-- Also returns whether this call granted anything (false for a repeat).
	grant: (
		self: Receipts,
		player: any,
		productKey: string,
		purchaseId: string,
		robux: number?
	) -> (Decision, boolean),
	productKey: (self: Receipts, productId: number) -> string?,
	productId: (self: Receipts, productKey: string) -> number?,
	keys: (self: Receipts) -> { string },
}

local log = Log.new("Receipts")

local Receipts = {}

function Receipts.new(options: Options): Receipts
	local field = options.receiptsField or "receipts"
	local maxStored = options.maxStored or 100
	type Product = { key: string, id: number, grant: Grant }
	local byId: { [number]: Product } = {}
	local byKey: { [string]: Product } = {}

	local receipts = {}

	function receipts.register(_self: Receipts, productKey: string, productId: number, grant: Grant)
		assert(
			type(productId) == "number" and productId >= 0 and productId // 1 == productId,
			`product {productKey} needs a whole-number id (0 = not created yet)`
		)
		assert(productId == 0 or byId[productId] == nil, `product id {productId} registered twice`)
		assert(byKey[productKey] == nil, `product key {productKey} registered twice`)
		local product = { key = productKey, id = productId, grant = grant }
		byKey[productKey] = product
		if productId > 0 then
			byId[productId] = product
		end
	end

	function receipts.productId(_self: Receipts, productKey: string): number?
		local product = byKey[productKey]
		return product and product.id
	end

	function receipts.keys(_self: Receipts): { string }
		local out = {}
		for key in byKey do
			table.insert(out, key)
		end
		table.sort(out)
		return out
	end

	function receipts.productKey(_self: Receipts, productId: number): string?
		local product = byId[productId]
		return product and product.key
	end

	local function contains(list: { string }?, id: string): boolean
		if list == nil then
			return false
		end
		return table.find(list, id) ~= nil
	end

	-- Returns the decision and whether this call granted the product.
	local function run(
		product: Product,
		player: any,
		purchaseId: string,
		robux: number,
		userId: number
	): (Decision, boolean)
		local receipt = { PurchaseId = purchaseId, PlayerId = userId }
		local data = options.data:get(player)
		if data == nil then
			return "NotProcessedYet", false
		end

		if contains(data[field], receipt.PurchaseId) then
			-- Granted earlier. Only report success once that grant is saved.
			if options.persist(player, receipt.PurchaseId) then
				return "PurchaseGranted", false
			end
			return "NotProcessedYet", false
		end

		local ledger: Economy.Ledger? = nil
		local ok, err = options.data:update(player, function(d)
			local l = options.economy:ledger(player, d)
			product.grant(player, d, l)
			local list = d[field]
			if list == nil then
				list = {}
				d[field] = list
			end
			table.insert(list, receipt.PurchaseId)
			while #list > maxStored do
				table.remove(list, 1)
			end
			ledger = l
		end)
		if not ok then
			log:error("grant failed", { product = product.key, purchaseId = receipt.PurchaseId, err = err })
			return "NotProcessedYet", false
		end
		if ledger then
			options.economy:commit(ledger)
		end

		if not options.persist(player, receipt.PurchaseId) then
			log:warn(
				"granted but not yet saved; Roblox will retry",
				{ product = product.key, purchaseId = receipt.PurchaseId }
			)
			-- Granted in memory; the retry will find the id and not grant again.
			return "NotProcessedYet", true
		end

		log:info(
			"purchase granted",
			{ product = product.key, purchaseId = receipt.PurchaseId, userId = receipt.PlayerId }
		)
		if options.onGranted then
			local fine, problem = Util.try(options.onGranted, player, product.key, robux)
			if not fine then
				log:error("onGranted failed", { err = problem })
			end
		end
		return "PurchaseGranted", true
	end

	function receipts.process(_self: Receipts, receipt: ReceiptInfo): Decision
		local product = byId[receipt.ProductId]
		if product == nil then
			log:error(
				"receipt for an unknown product",
				{ productId = receipt.ProductId, purchaseId = receipt.PurchaseId }
			)
			return "NotProcessedYet"
		end
		local player = options.findPlayer(receipt.PlayerId)
		if player == nil then
			return "NotProcessedYet" -- Roblox retries when the player is next in a server.
		end
		return (run(product, player, receipt.PurchaseId, receipt.CurrencySpent or 0, receipt.PlayerId))
	end

	function receipts.grant(
		_self: Receipts,
		player: any,
		productKey: string,
		purchaseId: string,
		robux: number?
	): (Decision, boolean)
		local product = byKey[productKey]
		if product == nil then
			log:error("test grant for an unknown product", { product = productKey })
			return "NotProcessedYet", false
		end
		return run(product, player, purchaseId, robux or 0, (player :: any).UserId or 0)
	end

	return (receipts :: any) :: Receipts
end

return Receipts
