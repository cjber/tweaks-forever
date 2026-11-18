local _, ns = ...

-- Waiting for the client's item data. GET_ITEM_INFO_RECEIVED fires for every item any addon asks about, in bursts, so
-- a feature never reacts to the event itself: it names the item it is waiting for, and its callback runs once that
-- item's data arrives, at most once per frame however many of its items land together (#636).

---@type table<integer, table<function, true>>
local awaited = {}
---@type table<function, true>?
local due

local function RunDue()
	local run = due or {}
	due = nil
	for callback in pairs(run) do
		ns.core.SafeCall("item info", callback)
	end
end

-- Run `callback` on the frame after the client's data for `itemID` arrives. Asking again for an item already
-- awaited adds nothing, and an item whose data never arrives costs one table entry.
---@param itemID integer?
---@param callback function
function ns.AwaitItem(itemID, callback)
	if type(itemID) ~= "number" then
		return
	end
	local callbacks = awaited[itemID]
	if not callbacks then
		callbacks = {}
		awaited[itemID] = callbacks
	end
	callbacks[callback] = true
end

ns.Init(function()
	ns.On("GET_ITEM_INFO_RECEIVED", function(itemID)
		local callbacks = awaited[itemID]
		if not callbacks then
			return
		end
		awaited[itemID] = nil
		if not due then
			due = {}
			C_Timer.After(0, RunDue)
		end
		for callback in pairs(callbacks) do
			due[callback] = true
		end
	end)
end)
