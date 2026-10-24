---@type string, TFNamespace
local _, ns = ...
if ns.L then
	ns.ReportTitle = ns.L["Tweaks Forever report"]
end

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

---@param message string
function ns.Print(message)
	print("|cffffd200Tweaks Forever:|r " .. message)
end

-- Widens a button to its label, never below `width`: a translated label can run past the width chosen for the
-- English, and UIPanelButtonTemplate neither shrinks nor wraps its text. Call it after each SetText.
---@param button Button
---@param width number
function ns.FitButton(button, width)
	button:SetWidth(math.max(width, math.ceil(button:GetTextWidth()) + 24))
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
		if tooltip ~= GameTooltip or not ns.Usable(tooltip) then
			return
		end
		local info = tooltip:GetProcessingTooltipInfo()
		local args = info and info.getterArgs
		if info and getters[info.getterName] then
			ns.SafeCall(
				"tooltip",
				fn,
				GameTooltip,
				info.getterName,
				unpack(args or {}, 1, args and args.n or 0) -- multi-value: the getter's arguments
			)
		end
	end)
end

-- Declare a feature. A conflict is { addon = folder name, title = shown name, when = optional check of that
-- addon's own setting }; with no `when`, the addon being loaded is the conflict. { polestar = setting path } is
-- Polestar's own setting, on (ns.PolestarOn) while Polestar is loaded; `addon` can name another of its addons that
-- must be loaded too. { openmap = option } is one of OpenMap's world map options, on (ns.OpenMapOn) while OpenMap
-- is loaded.
---@param feature TFFeature
function ns.Feature(feature)
	assert(not byKey[feature.key], "duplicate feature " .. feature.key)
	feature.conflicts = feature.conflicts or {}
	for _, conflict in ipairs(feature.conflicts) do
		if conflict.polestar then
			conflict.addon, conflict.title = conflict.addon or "Polestar", "Polestar"
		elseif conflict.openmap then
			-- Its TOC title is colour-coded, so name it plainly.
			conflict.addon, conflict.title = conflict.addon or "OpenMap", "OpenMap"
		end
	end
	ns.features[#ns.features + 1] = feature
	byKey[feature.key] = feature
end

-- Whether Polestar is loaded with one of its settings on, read through its own Polestar.Get. Its settings are
-- true/false, or a choice where "off" is off. Anything unreadable counts as off.
---@param path string
---@return boolean
function ns.PolestarOn(path)
	if not (C_AddOns.IsAddOnLoaded("Polestar") and Polestar and Polestar.Get) then
		return false
	end
	local ok, value = pcall(Polestar.Get, path)
	return ok and value ~= nil and value ~= false and value ~= "off"
end

-- Whether OpenMap is loaded and its world map runs with one of its options on. It keeps them in
-- OpenMapDB.worldmap, filled from its defaults as it loads: a missing table or option is its default, and every
-- option it shares with a feature here starts on. Its options are true/false, or a choice where "hide" is off
-- (unexplored areas hidden, as the game's own map does). Whether the world map runs is its module's own flag once
-- it has started (false when it failed to start; switching it in OpenMap's options takes a reload there too), and
-- its saved setting before then.
---@param option string
---@return boolean
function ns.OpenMapOn(option)
	if not C_AddOns.IsAddOnLoaded("OpenMap") then
		return false
	end
	local db = type(OpenMapDB) == "table" and OpenMapDB.worldmap
	db = type(db) == "table" and db or {}
	local modules = type(OpenMap) == "table" and OpenMap.modules
	local worldmap = type(modules) == "table" and modules.worldmap
	local running = db.enabled ~= false
	if type(worldmap) == "table" and type(worldmap.enabled) == "boolean" then
		running = worldmap.enabled
	end
	local value = db[option]
	return running == true and value ~= false and value ~= "hide"
end

---@param conflict TFConflict
---@return boolean?
local function Applies(conflict)
	if conflict.polestar then
		return ns.PolestarOn(conflict.polestar)
	elseif conflict.openmap then
		return ns.OpenMapOn(conflict.openmap)
	end
	return not conflict.when or conflict.when()
end

---@param feature TFFeature
---@return string?
local function FindConflict(feature)
	for _, conflict in ipairs(feature.conflicts) do
		local addon = conflict.addon --[[@as string]]
		if C_AddOns.IsAddOnLoaded(addon) and Applies(conflict) then
			return conflict.title or C_AddOns.GetAddOnMetadata(addon, "Title") or addon
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
-- so toggles apply at once. Off until PLAYER_LOGIN has read the saved settings: some events (map markers,
-- nameplates) reach a feature while the world loads, before then (#202).
---@param key string
---@return boolean
function ns.Active(key)
	assert(byKey[key], "unknown feature " .. key)
	return ns.db ~= nil and not not ns.db[key] and not conflicted[key] and not missing[key]
end

-- The Settings variable a feature's setting is registered under.
---@param key string
---@return string
function ns.SettingVariable(key)
	assert(byKey[key], "unknown feature " .. key)
	return "TweaksForever_" .. key
end

-- Run fn whenever the player changes a feature's setting.
---@param key string
---@param fn function
function ns.OnSettingChanged(key, fn)
	Settings.SetOnValueChangedCallback(ns.SettingVariable(key), function(...)
		ns.SafeCall("setting " .. key, fn, ...)
	end)
end

local handlers = {}
local events = CreateFrame("Frame")
-- Each handler runs through ns.SafeCall: one that fails is kept for /tweaks report, reaches the game's error
-- handler, and doesn't stop the rest.
events:SetScript("OnEvent", function(_, event, ...)
	for _, fn in ipairs(handlers[event]) do
		ns.SafeCall(event, fn, ...)
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

-- Hook every bag slot button once, as its bag opens. `update` runs as a bag opens (callers
-- also refresh on BAG_UPDATE_DELAYED); `click` runs after a modified click. Script hooks only: hooksecurefunc on a
-- button's methods, or on ContainerFrameItemButtonMixin, writes into Blizzard's tables and taints its bag code.
---@param update fun(button: ContainerFrameItemButtonTemplate)
---@param click fun(button: ContainerFrameItemButtonTemplate, mouseButton: string)
function ns.HookBagButtons(update, click)
	local hooked = {}
	-- A bag reports its size before its buttons exist, so a slot can have no button yet.
	local function Hook(button)
		if not button or hooked[button] then
			return
		end
		hooked[button] = true
		button:HookScript("OnClick", function(self, mouseButton)
			if IsModifiedBagClick(self, mouseButton) then
				ns.SafeCall("bag click", click, self, mouseButton)
			end
		end)
	end
	hooksecurefunc("ContainerFrame_GenerateFrame", function(container)
		for _, button in ns.BagItems(container) do
			Hook(button)
			ns.SafeCall("bag update", update, button)
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
		ns.SafeCall("startup", fn)
	else
		pending[#pending + 1] = fn
	end
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
-- A load-on-demand addon (Polestar's quest database) can become a conflict after login.
ns.On("ADDON_LOADED", function()
	if ready then
		ns.RefreshConflicts()
	end
end)
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
	-- Polestar applies its settings at once, so its matching features here follow them at once too.
	if Polestar and type(Polestar.On) == "function" and C_AddOns.IsAddOnLoaded("Polestar") then
		pcall(Polestar.On, "SETTING_CHANGED", function()
			ns.RefreshConflicts()
		end)
	end
	ready = true
	for _, fn in ipairs(pending) do
		ns.SafeCall("startup", fn)
	end
	pending = nil
end)
