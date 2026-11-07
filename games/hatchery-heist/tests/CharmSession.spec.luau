--!strict
-- Charms and the claw machine through the real core services: coins move
-- only through the ledger, refusals change nothing, PolicyService closes
-- the claw (and opens the Charm Counter), the Robux pulls grant exactly
-- once, and the odds a player sees with a Clover are the odds they roll.
local Charms = require("../src/shared/Charms")
local Claw = require("../src/shared/Claw")
local DataTemplate = require("../src/shared/DataTemplate")
local Fakes = require("../../../packages/core/tests/Fakes")
local Harness = require("./Harness")
local Receipts = require("@core/Receipts")
local Util = require("@core/Util")
local t = require("@testlib")
local describe, it, expect = t.describe, t.it, t.expect

local config = Harness.config
local charms = config.charms

local function setup(options: Harness.Options?)
	local h = Harness.new(options)
	local p = Fakes.player(101)
	h.join(p)
	return h, p
end

local function lastEvent(h: any, name: string): { any }?
	local found = nil
	for _, args in h.eventsOf("custom") do
		if args[1] == name then
			found = args
		end
	end
	return found
end

describe("Claw pulls at the machine", function()
	it("a coin pull takes the price through the ledger and drops the charms in the bag", function()
		local h, p = setup()
		local d = h.get(p)
		d.coins = 100000
		local ok, err = h.charms:pull(p, 10)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(d.coins).toBe(100000 - 45000)
		expect(Charms.bagCount(d)).toBe(10)
		expect(d.clawPulls).toBe(10)
		local result = h.clawResults[#h.clawResults]
		expect(#result.ids).toBe(10)
		expect(result.source).toBe("Coins")
		-- The promise held.
		local best = 0
		for _, id in result.ids do
			best = math.max(best, (Charms.def(charms, id) :: Charms.Def).rank)
		end
		expect(best >= 3).toBe(true)
		-- Through the ledger, as a coin sink at the shop.
		local spent = nil
		for _, args in h.eventsOf("economy") do
			if args[1] == "Sink" and args[6] == "ClawPull10" then
				spent = args
			end
		end
		assert(spent, "no ClawPull10 sink")
		expect(spent[3]).toBe(45000)
		expect(lastEvent(h, "Claw:Pull") ~= nil).toBe(true)
	end)

	it("refuses without enough coins, a full bag or away from the machine, changing nothing", function()
		local h, p = setup()
		local d = h.get(p)
		d.coins = 4999
		local ok = h.charms:pull(p, 1)
		expect(ok).toBe(false)
		expect(h.lastNotice(p)).toBe("Not enough coins: 1 pull costs 5000.")
		d.coins = 1e9
		for i = 1, charms.bagSlots - 5 do
			Charms.add(d, "FeedBag", i, "test")
		end
		ok = h.charms:pull(p, 10)
		expect(ok).toBe(false)
		expect(h.lastNotice(p)).toBe("Your charm bag is full (300). Fuse charms to make room.")
		expect(d.coins).toBe(1e9)
		expect(Charms.bagCount(d)).toBe(charms.bagSlots - 5)
		h.atClaw = false
		ok = h.charms:pull(p, 1)
		expect(ok).toBe(false)
		expect(h.lastNotice(p)).toBe("Walk up to the claw machine to pull.")
		expect(#h.clawResults).toBe(0)
	end)

	it("pulls rise with the player's best income", function()
		local h, p = setup()
		local d = h.get(p)
		d.incomePeak = 1000 -- 5 minutes = 300,000
		d.coins = 299999
		expect((h.charms:pull(p, 1))).toBe(false)
		d.coins = 300000
		expect((h.charms:pull(p, 1))).toBe(true)
		expect(d.coins).toBe(0)
	end)
end)

describe("Paid random items policy", function()
	it("closes the claw and opens the Charm Counter for restricted players", function()
		local h, p = setup({ restricted = true })
		local d = h.get(p)
		d.coins = 1e6
		local ok, err = h.charms:pull(p, 1)
		expect(ok).toBe(false)
		expect(err).toBe("restricted")
		expect(Charms.bagCount(d)).toBe(0)
		expect(d.coins).toBe(1e6)
		ok = h.charms:counter(p, "HoneyPot")
		expect(ok).toBe(true)
		expect(d.coins).toBe(1e6 - 50000)
		expect(Charms.counts(d).HoneyPot).toBe(1)
		-- Nothing above Rare at the counter.
		ok = h.charms:counter(p, "EmberStone")
		expect(ok).toBe(false)
	end)

	it("keeps the Charm Counter closed to players who can pull", function()
		local h, p = setup()
		h.get(p).coins = 1e6
		expect((h.charms:counter(p, "HoneyPot"))).toBe(false)
	end)
end)

describe("Robux claw pulls", function()
	local function receiptsFor(h: any, p: any)
		local receipts = Receipts.new({
			data = h.data,
			economy = h.economy,
			findPlayer = function()
				return p
			end,
			persist = function()
				return true
			end,
			onGranted = function() end,
		})
		for _, pull in charms.claw.pulls do
			if pull.product then
				receipts:register(
					pull.product,
					if pull.count == 10 then 9010 else 9100,
					function(player, data)
						h.charms:grantInside(player, data, pull.count)
					end
				)
			end
		end
		return receipts
	end

	it("grants a 100-pull exactly once, with the Epic promise, even into a full bag", function()
		local h, p = setup()
		local d = h.get(p)
		for i = 1, charms.bagSlots do
			Charms.add(d, "FeedBag", i, "test")
		end
		local receipts = receiptsFor(h, p)
		local receipt = { PlayerId = 101, ProductId = 9100, PurchaseId = "R1", CurrencySpent = 700 }
		for _ = 1, 3 do
			expect(receipts:process(receipt)).toBe("PurchaseGranted")
		end
		expect(Charms.bagCount(d)).toBe(charms.bagSlots + 100)
		expect(d.clawPulls).toBe(100)
		local best = 0
		for i = charms.bagSlots + 1, #d.charms do
			best = math.max(best, (Charms.def(charms, d.charms[i].id) :: Charms.Def).rank)
		end
		expect(best >= 5).toBe(true)
		local event = lastEvent(h, "Claw:Pull")
		assert(event, "no Claw:Pull event")
		expect(event[2]).toBe(100)
	end)
end)

describe("Equipped charms in play", function()
	it("the odds shown with a Clover are the odds rolled, and other sources keep theirs", function()
		local h, p = setup()
		local d = h.get(p)
		-- The first egg: Commons and rarer, so the Clover shifts its odds.
		local egg = config.eggs[1]
		local before = h.odds:effective(egg.id, p)
		Charms.add(d, "StarOfFortune", 1, "test")
		expect((h.charms:equip(p, "StarOfFortune"))).toBe(true)
		local boosts = Charms.luckBoosts(d, charms, egg, config.creatures.species)
		h.odds:setSourceBoosts(p, egg.id, "charms", boosts)
		local display = h.odds:display(egg.id, p)
		local effective = h.odds:effective(egg.id, p)
		local changed = false
		for i, row in display.rows do
			expect(row.weight).toBe(effective[i].weight)
			changed = changed or effective[i].weight ~= before[i].weight
		end
		expect(changed).toBe(true)
		expect(display.boosts[#display.boosts]).toBe("Star of Fortune")
		-- Unequipping clears only the charm's boost.
		h.charms:unequip(p, "Clover")
		h.odds:setSourceBoosts(
			p,
			egg.id,
			"charms",
			Charms.luckBoosts(d, charms, egg, config.creatures.species)
		)
		local after = h.odds:effective(egg.id, p)
		for i, o in after do
			expect(o.weight).toBe(before[i].weight)
		end
	end)

	it("a Warmer shortens the hatch of an egg bought after equipping it", function()
		local h, p = setup()
		local d = h.get(p)
		d.coins = 1e9
		local egg = config.eggs[1]
		Charms.add(d, "DragonsHearth", 1, "test")
		expect((h.charms:equip(p, "DragonsHearth"))).toBe(true)
		local ok = h.buy(p, egg.id)
		expect(ok).toBe(true)
		local incubator = d.incubators[#d.incubators]
		local expected = Charms.hatchSeconds(egg.hatchSeconds, d, charms)
		expect(expected < egg.hatchSeconds).toBe(true)
		expect(incubator.readyAt - incubator.startedAt).toBe(expected)
	end)

	it("equip, hide and fuse tell the server's listeners, and fusing charges the fee", function()
		local h, p = setup()
		local d = h.get(p)
		d.coins = 10000
		for i = 1, 5 do
			Charms.add(d, "CloverSprig", i, "test")
		end
		expect((h.charms:equip(p, "CloverSprig"))).toBe(true)
		expect((h.charms:setShown(p, "Clover", false))).toBe(true)
		expect(Charms.wornAttribute(d, charms)).toBe("")
		-- One equipped: only four free, so no fuse.
		expect((h.charms:fuse(p, "CloverSprig", 1))).toBe(false)
		h.charms:unequip(p, "Clover")
		expect((h.charms:fuse(p, "CloverSprig", 1))).toBe(true)
		expect(d.coins).toBe(10000 - Claw.fuseFee(0, charms))
		expect(Charms.counts(d).FourLeafClover).toBe(1)
		expect(h.charmChanges >= 4).toBe(true)
	end)
end)

describe("Charm saves", function()
	it("a save from before charms loads with every charm field filled in", function()
		local old = Util.deepCopy(DataTemplate.template) :: any
		for _, key in
			{
				"charms",
				"charmNextUid",
				"charmEquipped",
				"charmHidden",
				"charmsShown",
				"clawPity",
				"clawPulls",
				"incomePeak",
			}
		do
			old[key] = nil
		end
		local store = Fakes.store({ Player_102 = old })
		local h = Harness.new({ store = store })
		local p = Fakes.player(102)
		h.join(p)
		local d = h.get(p)
		expect(type(d.charms)).toBe("table")
		expect(d.charmNextUid).toBe(1)
		expect(d.charmsShown).toBe(true)
		expect(d.clawPity).toBe(0)
		expect(d.version).toBe(DataTemplate.template.version)
		h.leave(p)
		expect(type(store.saved.Player_102.charms)).toBe("table")
	end)
end)
