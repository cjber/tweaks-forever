---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

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

-- Stop waiting with `callback` for every item: the wait it was for is over (a merchant visit ended).
---@param callback function
function ns.ForgetItems(callback)
	for itemID, callbacks in pairs(awaited) do
		callbacks[callback] = nil
		if next(callbacks) == nil then
			awaited[itemID] = nil
		end
	end
	if due then
		due[callback] = nil
	end
end

ns.Init(function()
	ns.On("GET_ITEM_INFO_RECEIVED", function(itemID, success)
		local callbacks = awaited[itemID]
		-- A failed load caches nothing: the wait stays for the arrival that does.
		if not callbacks or success == false then
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
