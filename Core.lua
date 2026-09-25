---@type string, TFNamespace
local _, ns = ...

-- Features, in declaration order, and by key. Each is { key, category, name, tooltip, default, conflicts }, plus
-- `options` ({ { value, label } }) for a choice rather than an on/off switch, `parent` (a key) to indent it
-- under that feature and grey it out while the parent is off, and `needs` ({ title, check }) for another addon it
-- can't work without: off and greyed out while `check` finds it missing.
ns.features = {}
---@type table<string, TFFeature>
local byKey = {}
-- [key] = title of the addon already doing that feature's job, once addons have loaded.
---@type table<string, string>
local conflicted = {}
-- [key] = title of the addon a feature needs and can't find, once addons have loaded.
---@type table<string, string>
local missing = {}
local pending, ready = {}, false

---@param fn fun()
local function Start(fn)
	xpcall(fn, geterrorhandler())
end

---@param message string
function ns.Print(message)
	print("|cffffd200Tweaks Forever:|r " .. message)
end

-- The bag frames, read straight from the container. ContainerFrameUtil_EnumerateContainerFrames builds Blizzard's
-- cached list on its first call, so calling it first from here left that list tainted and the bank blocked.
---@return fun(): ContainerFrameTemplate|ContainerFrameCombinedBags?
function ns.ContainerFrames()
	local frames, index = ContainerFrameContainer.ContainerFrames, -1
	return function()
		index = index + 1
		if index == 0 then
			return ContainerFrameCombinedBags
		end
		return frames[index]
	end
end

-- A bag frame's slot count, never through GetBagSize: that caches self.size on first call, and caching it from
-- here would leave Blizzard's bag code reading a value this addon wrote.
---@param container ContainerFrameTemplate|ContainerFrameCombinedBags
---@return integer
function ns.BagSize(container)
	return container.size or C_Container.GetContainerNumSlots(container:GetID())
end

-- A bag frame's item buttons that hold a slot, as EnumerateValidItems but read-only.
---@param container ContainerFrameTemplate|ContainerFrameCombinedBags
---@return fun(): integer?, ContainerFrameItemButtonTemplate?
function ns.BagItems(container)
	local size, index = container.size or 0, 0
	return function()
		index = index + 1
		if index <= size then
			return index, container.Items[index]
		end
	end
end

-- Every item button in an open bag. A button of a bag frame not in use can still report IsShown with no slot.
---@param fn fun(button: ContainerFrameItemButtonTemplate)
function ns.ForEachBagButton(fn)
	for container in ns.ContainerFrames() do
		if container:IsShown() then
			for _, button in ns.BagItems(container) do
				fn(button)
			end
		end
	end
end

-- Run fn(tooltip, ...) as GameTooltip fills from a C_TooltipInfo getter (GetBagItem for SetBagItem, and so on),
-- with the arguments it was called with. Never hooksecurefunc(GameTooltip, "SetBagItem"): Blizzard's own calls
-- to a tooltip method an addon has hooked then fail with "attempt to call a nil value".
---@param dataType Enum.TooltipDataType
---@param getters table<string, true>
---@param fn fun(tooltip: GameTooltip, getter: string, ...: any)
function ns.OnTooltip(dataType, getters, fn)
	TooltipDataProcessor.AddTooltipPostCall(dataType, function(tooltip)
		if tooltip ~= GameTooltip then
			return
		end
		local info = tooltip:GetProcessingTooltipInfo()
		local args = info and info.getterArgs
		if info and getters[info.getterName] then
			fn(GameTooltip, info.getterName, unpack(args or {}, 1, args and args.n or 0))
		end
	end)
end

-- Declare a feature. A conflict is { addon = folder name, title = shown name, when = optional check of that
-- addon's own setting }; with no `when`, the addon being loaded is the conflict.
---@param feature TFFeature
function ns.Feature(feature)
	assert(not byKey[feature.key], "duplicate feature " .. feature.key)
	feature.conflicts = feature.conflicts or {}
	ns.features[#ns.features + 1] = feature
	byKey[feature.key] = feature
end

---@param feature TFFeature
---@return string?
local function FindConflict(feature)
	for _, conflict in ipairs(feature.conflicts) do
		if C_AddOns.IsAddOnLoaded(conflict.addon) and (not conflict.when or conflict.when()) then
			return conflict.title or C_AddOns.GetAddOnMetadata(conflict.addon, "Title") or conflict.addon
		end
	end
end

-- Re-read other addons' settings; they may have changed theirs since login.
function ns.RefreshConflicts()
	for _, feature in ipairs(ns.features) do
		local ok, title = pcall(FindConflict, feature)
		conflicted[feature.key] = ok and title or nil
		local needs = feature.needs
		local found, present = true, true
		if needs then
			found, present = pcall(needs.check)
		end
		missing[feature.key] = not (found and present) and needs and needs.title or nil
	end
end

-- The addon a feature needs and can't find, if any.
---@param key string
---@return string?
function ns.MissingOf(key)
	return missing[key]
end

---@param key string
---@return string?
function ns.ConflictOf(key)
	return conflicted[key]
end

-- Switched on, not already handled by another addon and not missing one it needs. Checked when the feature acts,
-- so toggles apply at once.
---@param key string
---@return boolean
function ns.Active(key)
	assert(byKey[key], "unknown feature " .. key)
	return not not ns.db[key] and not conflicted[key] and not missing[key]
end

local handlers = {}
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
	local args, count = { ... }, select("#", ...)
	for _, fn in ipairs(handlers[event]) do
		Start(function()
			fn(unpack(args, 1, count))
		end)
	end
end)

---@param event WowEvent
---@param fn function
function ns.On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		events:RegisterEvent(event)
	end
	table.insert(handlers[event], fn)
end

-- Blizzard's rule for a modified click (ContainerFrameItemButtonMixin:OnClick): with the auto-loot toggle held, a
-- button other than the left one on a lootable item is an ordinary click.
---@param button ContainerFrameItemButtonTemplate
---@param mouseButton string
---@return boolean
local function IsModifiedBagClick(button, mouseButton)
	if not IsModifiedClick() then
		return false
	end
	if mouseButton ~= "LeftButton" and IsModifiedClick("AUTOLOOTTOGGLE") then
		local info = C_Container.GetContainerItemInfo(button:GetBagID(), button:GetID())
		return not (info and info.hasLoot)
	end
	return true
end

-- Hook every bag slot button as its bag opens, recording each in `hooked`. `update` runs as a bag opens (callers
-- also refresh on BAG_UPDATE_DELAYED); `click` runs after a modified click. Script hooks only: hooksecurefunc on a
-- button's methods, or on ContainerFrameItemButtonMixin, writes into Blizzard's tables and taints its bag code.
---@param hooked table<ContainerFrameItemButtonTemplate, boolean>
---@param update fun(button: ContainerFrameItemButtonTemplate)
---@param click fun(button: ContainerFrameItemButtonTemplate, mouseButton: string)
function ns.HookBagButtons(hooked, update, click)
	-- A bag reports its size before its buttons exist, so a slot can have no button yet.
	local function Hook(button)
		if not button or hooked[button] then
			return
		end
		hooked[button] = true
		button:HookScript("OnClick", function(self, mouseButton)
			if IsModifiedBagClick(self, mouseButton) then
				click(self, mouseButton)
			end
		end)
	end
	hooksecurefunc("ContainerFrame_GenerateFrame", function(container)
		for _, button in ns.BagItems(container) do
			Hook(button)
			update(button)
		end
	end)
	for container in ns.ContainerFrames() do
		for _, button in ns.BagItems(container) do
			Hook(button)
		end
	end
end

-- Whether the modified click held now is bound to one of the game's bag actions, which may have been remapped.
function ns.IsBagActionClick()
	for _, action in ipairs({ "EXPANDITEM", "CHATLINK", "DRESSUP", "SPLITSTACK", "AUTOLOOTTOGGLE" }) do
		if IsModifiedClick(action) then
			return true
		end
	end
	return false
end

-- Run once every addon has loaded (their saved variables are readable, so conflicts are known).
---@param fn fun()
function ns.Init(fn)
	if ready then
		Start(fn)
	else
		pending[#pending + 1] = fn
	end
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function()
	local db = TweaksForeverDB or {}
	db.junk = db.junk or {}
	for _, feature in ipairs(ns.features) do
		if db[feature.key] == nil then
			db[feature.key] = feature.default
		end
	end
	TweaksForeverDB, ns.db = db, db
	TweaksForeverCharDB = TweaksForeverCharDB or {}
	ns.RefreshConflicts()
	ready = true
	for _, fn in ipairs(pending) do
		Start(fn)
	end
	pending = nil
end)
