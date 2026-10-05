-- The sale run, driven the way the game drives it: the merchant opening and closing, item info arriving, the Sell
-- All Junk confirmation and time passing, against a stub of the bags, the merchant and the timer. Every scenario
-- loads the file afresh and asserts on the slots that were used and the total that was printed.
local SELL_ALL = "Sell all junk items?"

local function stack(quality, id, count)
	return { itemID = id, quality = quality, stackCount = count or 2, hyperlink = "item:" .. id }
end
local function grey(id, count)
	return stack(0, id, count)
end
local function green(id, count)
	return stack(2, id, count)
end
-- Slots 1..count of the backpack, one stack each.
local function fill(count, make)
	local slots = {}
	for slot = 1, count do
		slots[slot] = make(slot)
	end
	return slots
end

-- Every stack is worth 7 a piece unless `price` says otherwise; `unpriced` links are not in the item cache yet.
local function Client(slots, db)
	local c = {
		slots = slots,
		db = db or {},
		used = {},
		printed = {},
		price = {},
		unpriced = {},
		refundable = {},
		requested = {},
		lag = 1,
		button = {},
	}
	c.db.junk = c.db.junk or {}
	if c.db.sellJunk == nil then
		c.db.sellJunk = true
	end
	local handlers, timers, leaving, scripts, accept = {}, {}, {}, {}, {}
	local features, initializers = {}, {}
	c.features = features

	local ns = {
		db = c.db,
		Feature = function(feature)
			features[feature.key] = feature
		end,
		Init = function(fn)
			initializers[#initializers + 1] = fn
		end,
		On = function(event, fn)
			assert(not handlers[event], event .. " is handled once")
			handlers[event] = fn
		end,
		Active = function(key)
			assert(features[key], "unknown feature " .. key)
			return not not c.db[key]
		end,
		ConflictOf = function() end,
		Print = function(message)
			c.printed[#c.printed + 1] = message
		end,
		ClickMode = function(mode)
			c.mode = mode
		end,
		HookBagButtons = function(update, click)
			c.update, c.click = update, click
		end,
		OnTooltip = function() end,
		ForEachBagButton = function() end,
		IsBagActionClick = function()
			return false
		end,
	}
	local function No()
		return false
	end
	local env = setmetatable({
		NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5,
		SELL_ALL_JUNK_ITEMS_POPUP = SELL_ALL,
		Enum = { TooltipDataType = { Item = 0 } },
		hooksecurefunc = function() end,
		IsControlKeyDown = No,
		IsShiftKeyDown = No,
		IsAltKeyDown = function()
			return c.alt
		end,
		InCombatLockdown = function()
			return c.combat
		end,
		CursorHasItem = function()
			return c.cursor
		end,
		InRepairMode = function()
			return c.repairing
		end,
		GameTooltip = { GetOwner = function() end },
		C_Container = {
			GetContainerNumSlots = function(bag)
				return bag == 0 and 20 or 0
			end,
			GetContainerItemInfo = function(bag, slot)
				assert(bag == 0)
				return c.slots[slot]
			end,
			GetContainerItemPurchaseInfo = function(_, slot)
				return c.refundable[slot] and { refundSeconds = 60 }
			end,
			UseContainerItem = function(bag, slot)
				assert(bag == 0 and c.slots[slot], "only a held stack is used")
				c.used[#c.used + 1] = slot
				if not c.rejects then
					leaving[#leaving + 1] = { slot = slot, ticks = c.lag }
				end
			end,
		},
		C_Item = {
			GetItemInfo = function(link)
				c.requested[link] = true
				if not c.unpriced[link] then
					return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, c.price[link] or 7
				end
			end,
		},
		C_Timer = {
			After = function(delay, fn)
				assert(delay == 0.2)
				timers[#timers + 1] = fn
			end,
		},
		C_AddOns = {
			IsAddOnLoaded = function(addon)
				return addon == "Leatrix_Plus" and c.leatrix ~= nil
			end,
		},
		C_MerchantFrame = {
			GetNumJunkItems = function()
				local count = 0
				for _, item in pairs(c.slots) do
					if item.quality == 0 then
						count = count + 1
					end
				end
				return count
			end,
			IsSellAllJunkEnabled = function()
				return not c.nativeDisabled
			end,
			SellAllJunkItems = function()
				c.nativeCalls = (c.nativeCalls or 0) + 1
				for slot, item in pairs(c.slots) do
					if item.quality == 0 and not item.isLocked and not item.hasNoValue and not c.refundable[slot] then
						if c.nativeLag then
							leaving[#leaving + 1] = { slot = slot, ticks = c.nativeLag }
						else
							c.slots[slot] = nil
						end
					end
				end
			end,
		},
		C_CurrencyInfo = {
			GetCoinTextureString = function(money)
				return money .. "c"
			end,
		},
		MerchantFrame = {
			selectedTab = 1,
			IsShown = function()
				return c.open
			end,
		},
		MerchantSellAllJunkButton = {
			HookScript = function(_, script, fn)
				scripts[script] = fn
			end,
			SetEnabled = function(_, enabled)
				c.button.enabled = enabled
			end,
			Icon = { SetDesaturated = function() end },
		},
		StaticPopup1 = {
			GetButton1 = function()
				return {
					HookScript = function(_, _, fn)
						accept[#accept + 1] = fn
					end,
				}
			end,
		},
	}, { __index = _G })
	env._G = env
	c.env = env
	assert(loadfile("Locales/enUS.lua"))("TweaksForever", ns)
	setfenv(assert(loadfile("Bags/Junk.lua")), env)("TweaksForever", ns)
	for _, init in ipairs(initializers) do
		init()
	end

	function c.fire(event)
		handlers[event]()
	end
	function c.show()
		c.open = true
		c.fire("MERCHANT_SHOW")
	end
	function c.close()
		c.open = false
		c.fire("MERCHANT_CLOSED")
	end
	-- The server takes the stacks it was sent, `lag` ticks after each was used.
	function c.land(all)
		local still = {}
		for _, sale in ipairs(leaving) do
			sale.ticks = sale.ticks - 1
			if all or sale.ticks <= 0 then
				c.slots[sale.slot] = nil
			else
				still[#still + 1] = sale
			end
		end
		leaving = still
	end
	-- 0.2 seconds pass.
	function c.tick()
		local due = timers
		timers = {}
		c.land()
		for _, fn in ipairs(due) do
			fn()
		end
	end
	-- Time passes until nothing is scheduled; returns how many ticks that took.
	function c.settle()
		local ticks = 0
		while #timers > 0 do
			ticks = ticks + 1
			assert(ticks <= 200, "the run never ends")
			c.tick()
		end
		return ticks
	end
	function c.clickSellAll()
		scripts.OnClick()
	end
	function c.confirm(text)
		if (not text or text == SELL_ALL) and c.open then
			env.C_MerchantFrame.SellAllJunkItems()
		end
		env.StaticPopup1.which, env.StaticPopup1.data = "GENERIC_CONFIRMATION", { text = text or SELL_ALL }
		for _, fn in ipairs(accept) do
			fn()
		end
	end
	function c.visit()
		c.show()
		return c.settle()
	end
	function c.sold()
		return table.concat(c.used, ",")
	end
	return c
end

local function MarkedClient(slots, db)
	db = db or {}
	db.markJunk, db.junk = true, db.junk or {}
	for _, item in pairs(slots) do
		if item.quality == 0 then
			item.quality = 2
			db.junk[item.itemID] = true
		end
	end
	return Client(slots, db)
end

local function same(actual, expected, why)
	assert(actual == expected, ("%s: expected %q, got %q"):format(why, tostring(expected), tostring(actual)))
end

do -- Native bulk selling includes the final grey and does not use bag-slot queues.
	local c = Client(fill(13, grey))
	local calls = 0
	c.env.C_MerchantFrame.IsSellAllJunkEnabled = function()
		return true
	end
	c.env.C_MerchantFrame.SellAllJunkItems = function()
		calls = calls + 1
		for slot = 1, 20 do
			local item = c.slots[slot]
			if item and item.quality == 0 then
				c.slots[slot] = nil
			end
		end
	end
	c.visit()
	assert(not c.slots[13], "the last grey is sold too")
	same(calls, 1, "the native sale runs once per visit")
	same(#c.used, 0, "grey items never use the custom per-slot seller")
end

do -- Marked items wait for an asynchronous native sale, which is submitted only once.
	local c = Client({ grey(1), grey(2), green(3) }, { markJunk = true, junk = { [3] = true } })
	c.nativeLag = 3
	c.show()
	c.tick()
	same(c.nativeCalls, 1, "one bulk sale")
	same(c.sold(), "", "marks wait while greys are in flight")
	c.fire("GET_ITEM_INFO_RECEIVED")
	c.tick()
	c.tick()
	same(c.sold(), "", "marks still wait before the native acknowledgement")
	c.settle()
	same(c.sold(), "3", "the marked item follows the native acknowledgement")
	same(c.nativeCalls, 1, "no duplicate native call")
end

do -- A native sale that makes no progress does not leave an endless timer.
	local c = Client({ grey(1), green(2) }, { markJunk = true, junk = { [2] = true } })
	local calls = 0
	c.env.C_MerchantFrame.SellAllJunkItems = function()
		calls = calls + 1
	end
	c.visit()
	same(calls, 1, "a stalled bulk sale is not resubmitted")
	same(c.sold(), "2", "marks remain usable after the bounded native wait")
	assert(c.slots[1], "the native failure is left for the game's merchant button")
end

do -- Merchant, feature and client guards prevent the native call.
	local blocks = {
		function(c)
			c.combat = true
		end,
		function(c)
			c.cursor = true
		end,
		function(c)
			c.repairing = true
		end,
		function(c)
			c.env.MerchantFrame.selectedTab = 2
		end,
		function(c)
			c.db.sellJunk = false
		end,
		function(c)
			c.open = false
		end,
		function(c)
			c.nativeDisabled = true
		end,
	}
	for _, block in ipairs(blocks) do
		local c = Client({ grey(1) })
		c.show()
		block(c)
		c.settle()
		same(c.nativeCalls, nil, "a blocked native sale is never submitted")
		assert(c.slots[1])
	end
end

do -- Native selling leaves marked non-grey items to the custom seller.
	local c = Client({ grey(1), green(2), green(3, 1) }, { markJunk = true, junk = { [3] = true } })
	c.price["item:3"] = 100
	c.visit()
	same(c.nativeCalls, 1, "grey junk is handled by the game")
	same(c.sold(), "3", "only the marked non-grey uses the custom seller")
	same(c.printed[1], "Sold 1 junk stacks for 100c.", "only acknowledged custom sales are reported")
	assert(c.slots[2], "unmarked items stay")
end

do -- A stack that changed between the scan and its turn is never sold.
	local c = MarkedClient(
		fill(10, function(slot)
			return slot == 7 and green(7) or grey(slot)
		end),
		{ markJunk = true, junk = { [7] = true } }
	)
	c.show()
	c.tick()
	same(c.sold(), "1", "the first stack goes; the rest wait their turn")
	c.slots[2] = grey(2, 3) -- a different count
	c.slots[3] = grey(3)
	c.slots[3].hyperlink = "item:3:different-enchant" -- the same item ID is not the same item variant
	c.slots[4] = grey(44)
	c.slots[4].hyperlink = "item:4" -- another item
	c.slots[5] = grey(5)
	c.slots[5].isLocked = true -- picked up
	c.slots[6] = nil -- moved away
	c.db.junk[7] = nil -- unmarked
	c.refundable[8] = true
	c.slots[9] = grey(9)
	c.slots[9].hasNoValue = true
	c.settle()
	same(c.sold(), "1,10", "only the untouched stack follows")
	same(c.printed[1], "Sold 2 junk stacks for 28c.", "the total")
end

do -- Closing the merchant stops the run, and a new visit starts its own.
	local c = MarkedClient(fill(4, grey))
	c.show()
	c.tick()
	c.tick()
	same(c.sold(), "1,2", "two stacks in")
	c.land(true)
	c.close()
	same(c.printed[1], "Sold 2 junk stacks for 28c.", "what was sold before the close is reported")
	c.settle()
	same(c.sold(), "1,2", "nothing is used once the merchant has closed")
	c.show()
	c.close()
	c.open = true -- another window reports shown while the old visit's timer is still due
	c.settle()
	same(c.sold(), "1,2", "a closed visit's start timer sells nothing")
	c.open = false
	c.show()
	c.tick()
	c.close()
	c.show()
	c.settle()
	same(c.sold(), "1,2,3,4", "the next visit sells the rest, once each")
end

do -- A sale the server never acknowledges ends the run after ten polls: no endless retry, nothing more sold.
	local c = MarkedClient(fill(3, grey))
	c.rejects = true
	same(c.visit(), 12, "the opening delay, the sale and ten polls")
	same(c.sold(), "1", "the rejected stack is tried once and nothing follows it")
	same(#c.printed, 0, "nothing sold, nothing printed")
	c.fire("GET_ITEM_INFO_RECEIVED")
	c.fire("BAG_UPDATE_DELAYED")
	same(c.settle(), 0, "and nothing restarts it")
	same(c.sold(), "1", "still once")
end

do -- A slow sale inside the cap is waited for and counted.
	local c = MarkedClient(fill(2, grey))
	c.lag = 10
	c.visit()
	same(c.sold(), "1,2", "both sell")
	same(c.printed[1], "Sold 2 junk stacks for 28c.", "the total")
end

do -- One visit sells twelve stacks, so all of them fit the buyback tab.
	local c = MarkedClient(fill(14, grey))
	c.unpriced["item:1"] = true
	c.visit()
	same(c.sold(), "2,3,4,5,6,7,8,9,10,11,12,13", "a batch")
	same(c.printed[1], "Sold 12 junk stacks for 168c.", "the total")
	c.unpriced["item:1"] = nil
	c.fire("GET_ITEM_INFO_RECEIVED")
	c.settle()
	same(#c.used, 12, "awaited item info arriving does not start a second batch")
	c.close()
	c.visit()
	same(c.sold(), "2,3,4,5,6,7,8,9,10,11,12,13,1,14", "the next visit sells the rest")
end

do -- Each condition that blocks selling blocks it at the start and stops a run under way.
	local blocks = {
		function(c)
			c.combat = true
		end,
		function(c)
			c.cursor = true
		end,
		function(c)
			c.repairing = true
		end,
		function(c)
			c.env.MerchantFrame.selectedTab = 2
		end,
		function(c)
			c.db.sellJunk = false
		end,
		function(c)
			c.open = false
		end,
	}
	for index, block in ipairs(blocks) do
		local c = MarkedClient(fill(3, grey))
		c.show()
		block(c)
		c.settle()
		same(c.sold(), "", "block " .. index .. " at the start")

		c = MarkedClient(fill(3, grey))
		c.show()
		c.tick()
		block(c)
		c.settle()
		same(c.sold(), "1", "block " .. index .. " under way")
		same(c.printed[1], "Sold 1 junk stacks for 14c.", "block " .. index .. " still reports the stack that went")
	end
end

do -- An item whose price or quality is not cached yet is left, then sold when its info arrives.
	local c = MarkedClient({ grey(1), grey(2), stack(nil, 3) })
	c.unpriced["item:1"] = true
	c.visit()
	same(c.sold(), "2", "unknown price and unknown quality are not sold")
	assert(c.requested["item:3"], "the unknown item is requested")
	c.unpriced["item:1"], c.slots[3].quality = nil, 2
	c.db.junk[3] = true
	c.fire("GET_ITEM_INFO_RECEIVED")
	c.settle()
	same(c.sold(), "2,1,3", "they sell once known")
	c.slots[4] = grey(4)
	c.fire("GET_ITEM_INFO_RECEIVED")
	c.settle()
	same(c.sold(), "2,1,3", "with nothing left pending, later item info sells nothing")
end

do -- Item info arriving during a run retries after it, within the same visit's batch.
	local c = MarkedClient(fill(12, grey))
	c.unpriced["item:1"] = true
	c.show()
	c.tick()
	same(c.sold(), "2", "the run is under way")
	c.unpriced["item:1"] = nil
	c.fire("GET_ITEM_INFO_RECEIVED")
	c.settle()
	same(c.sold(), "2,3,4,5,6,7,8,9,10,11,12,1", "the retry sells the late item")
	same(c.printed[1], "Sold 11 junk stacks for 154c.", "the first run's total")
	same(c.printed[2], "Sold 1 junk stacks for 14c.", "the retry's total")
end

do -- Leatrix owns greys only when its auto-sell is on.
	local c = Client({ grey(1), green(2) }, { markJunk = true, junk = { [2] = true } })
	c.leatrix, c.env.LeaPlusDB = "On", { AutoSellJunk = "On" }
	c.visit()
	same(c.nativeCalls, nil, "Leatrix sells the greys")
	same(c.sold(), "2", "marked non-grey items still sell")
	assert(c.slots[1])

	c = Client({ grey(1) })
	c.leatrix, c.env.LeaPlusDB = "Off", { AutoSellJunk = "Off" }
	c.visit()
	same(c.nativeCalls, 1, "Leatrix with auto-sell off leaves native selling here")
end

do -- Sell All Junk, once confirmed, also sells the marked non-grey stacks; Blizzard sells the greys.
	local c = Client({ grey(1), green(2, 1), green(3) }, { markJunk = true, sellJunk = false, junk = { [2] = true } })
	c.price["item:2"] = 100
	c.visit()
	same(c.sold(), "", "automatic selling is off")
	same(c.button.enabled, true, "a marked stack enables Sell All Junk")
	c.confirm()
	c.settle()
	same(c.sold(), "", "a confirmation that did not come from the button sells nothing")
	c.clickSellAll()
	c.confirm("Delete this item?")
	c.settle()
	same(c.sold(), "", "another confirmation sells nothing")
	c.confirm()
	same(c.sold(), "2", "the confirmed click sells the mark at once, and leaves the grey to Blizzard")
	c.settle()
	same(c.printed[1], "Sold 1 junk stacks for 100c.", "the total")
	c.slots[4], c.db.junk[4] = green(4), true
	c.confirm()
	c.settle()
	same(c.sold(), "2", "one click is one confirmation")
	c.clickSellAll()
	c.close()
	c.show()
	c.confirm()
	c.settle()
	same(c.sold(), "2", "a click does not carry over to the next merchant")
	c.clickSellAll()
	c.db.markJunk = false
	c.confirm()
	c.settle()
	same(c.sold(), "2", "nor does it sell with marking switched off")
end

do -- A confirmed Sell All Junk sells its own twelve, whatever the automatic batch has left.
	local c = MarkedClient(fill(2, grey), { markJunk = true })
	c.visit()
	same(c.sold(), "1,2", "the automatic run")
	for slot = 3, 15 do
		c.slots[slot], c.db.junk[slot] = green(slot), true
	end
	c.clickSellAll()
	c.confirm()
	c.settle()
	same(c.sold(), "1,2,3,4,5,6,7,8,9,10,11,12,13,14", "twelve marked stacks")
end

do -- A confirmation during an automatic run is honoured after it, beyond the automatic batch.
	local c = Client(fill(14, green), { markJunk = true, junk = {} })
	for id = 1, 14 do
		c.db.junk[id] = true
	end
	c.show()
	c.tick()
	c.clickSellAll()
	c.confirm()
	c.settle()
	same(c.sold(), "1,2,3,4,5,6,7,8,9,10,11,12,13,14", "the manual run follows the automatic one")
	same(c.printed[1], "Sold 12 junk stacks for 168c.", "the automatic total")
	same(c.printed[2], "Sold 2 junk stacks for 28c.", "the manual total")
end

do -- Marking: the click mode and Alt+Right-click toggle the saved, account-wide mark.
	local held = green(5)
	local c = Client({ held, green(6) }, { markJunk = true })
	c.mode.Apply(nil, 0, 1)
	same(c.db.junk[5], true, "marked")
	c.mode.Apply(nil, 0, 1)
	same(c.db.junk[5], nil, "unmarked, leaving no false behind")
	held.isLocked = true
	c.mode.Apply(nil, 0, 1)
	same(c.db.junk[5], nil, "a locked item is left alone")

	local bagButton = {
		GetBagID = function()
			return 0
		end,
		GetID = function()
			return 2
		end,
	}
	c.click(bagButton, "RightButton")
	same(c.db.junk[6], nil, "a right-click without Alt marks nothing")
	c.alt = true
	c.click(bagButton, "LeftButton")
	same(c.db.junk[6], nil, "nor does Alt+Left-click")
	c.click(bagButton, "RightButton")
	same(c.db.junk[6], true, "Alt+Right-click marks")
	c.db.markJunk = false
	c.click(bagButton, "RightButton")
	same(c.db.junk[6], true, "and does nothing with marking switched off")
end

do -- The coin drawn over a bag button takes the game's junk coin's layer and sublevel, each in its own slot.
	local c = Client({ green(100) }, { markJunk = true, junk = { [100] = true } })
	local drawn
	local button = {
		JunkIcon = {
			GetDrawLayer = function()
				return "OVERLAY", 5
			end,
			GetAtlas = function()
				return "bags-junkcoin"
			end,
		},
		GetBagID = function()
			return 0
		end,
		GetID = function()
			return 1
		end,
		CreateTexture = function(_, name, layer, inherits, sublevel)
			assert(
				inherits == nil or type(inherits) == "string",
				('Couldn\'t find inherited node "%s"'):format(tostring(inherits))
			)
			assert(name == nil and layer == "OVERLAY" and sublevel == 5, "the coin keeps the junk coin's draw layer")
			drawn = {
				SetAtlas = function() end,
				SetAllPoints = function() end,
				SetShown = function(_, shown)
					drawn.shown = shown
				end,
			}
			return drawn
		end,
	}
	c.update(button)
	assert(drawn and drawn.shown, "a marked item shows the coin")
end
print("junk_spec: ok")
