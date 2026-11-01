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
	register: (self: Receipts, productKey: string, productId: number, grant: Grant) -> (),
	process: (self: Receipts, receipt: ReceiptInfo) -> Decision,
	productKey: (self: Receipts, productId: number) -> string?,
}

local log = Log.new("Receipts")

local Receipts = {}

function Receipts.new(options: Options): Receipts
	local field = options.receiptsField or "receipts"
	local maxStored = options.maxStored or 100
	local byId: { [number]: { key: string, grant: Grant } } = {}
	local keys: { [string]: boolean } = {}

	local receipts = {}

	function receipts.register(_self: Receipts, productKey: string, productId: number, grant: Grant)
		assert(type(productId) == "number" and productId > 0, `product {productKey} needs a real product id`)
		assert(byId[productId] == nil, `product id {productId} registered twice`)
		assert(not keys[productKey], `product key {productKey} registered twice`)
		byId[productId] = { key = productKey, grant = grant }
		keys[productKey] = true
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

		local data = options.data:get(player)
		if data == nil then
			return "NotProcessedYet"
		end

		if contains(data[field], receipt.PurchaseId) then
			-- Granted earlier. Only report success once that grant is saved.
			if options.persist(player, receipt.PurchaseId) then
				return "PurchaseGranted"
			end
			return "NotProcessedYet"
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
			return "NotProcessedYet"
		end
		if ledger then
			options.economy:commit(ledger)
		end

		if not options.persist(player, receipt.PurchaseId) then
			log:warn(
				"granted but not yet saved; Roblox will retry",
				{ product = product.key, purchaseId = receipt.PurchaseId }
			)
			return "NotProcessedYet"
		end

		log:info(
			"purchase granted",
			{ product = product.key, purchaseId = receipt.PurchaseId, userId = receipt.PlayerId }
		)
		if options.onGranted then
			local fine, problem = pcall(options.onGranted, player, product.key, receipt.CurrencySpent or 0)
			if not fine then
				log:error("onGranted failed", { err = problem })
			end
		end
		return "PurchaseGranted"
	end

	return (receipts :: any) :: Receipts
end

return Receipts
