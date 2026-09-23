local _, ns = ...

-- Features, in declaration order, and by key. Each is { key, category, name, tooltip, default, conflicts }, plus
-- `options` ({ { value, label } }) for a choice rather than an on/off switch and `parent` (a key) to indent it
-- under that feature and grey it out while the parent is off.
ns.features = {}
local byKey = {}
-- [key] = title of the addon already doing that feature's job, once addons have loaded.
local conflicted = {}
local pending, ready = {}, false

local function Start(fn)
	xpcall(fn, geterrorhandler())
end

function ns.Print(message)
	print("|cffffd200Tweaks Forever:|r " .. message)
end

-- Every item button in an open bag. A button of a bag frame not in use can still report IsShown with no slot.
function ns.ForEachBagButton(fn)
	for _, container in ContainerFrameUtil_EnumerateContainerFrames() do
		if container:IsShown() then
			for _, button in container:EnumerateValidItems() do
				fn(button)
			end
		end
	end
end

-- Declare a feature. A conflict is { addon = folder name, title = shown name, when = optional check of that
-- addon's own setting }; with no `when`, the addon being loaded is the conflict.
function ns.Feature(feature)
	assert(not byKey[feature.key], "duplicate feature " .. feature.key)
	feature.conflicts = feature.conflicts or {}
	ns.features[#ns.features + 1] = feature
	byKey[feature.key] = feature
end

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
	end
end

function ns.ConflictOf(key)
	return conflicted[key]
end

-- Switched on and not already handled by another addon. Checked when the feature acts, so toggles apply at once.
function ns.Active(key)
	assert(byKey[key], "unknown feature " .. key)
	return ns.db[key] and not conflicted[key]
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

function ns.On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		events:RegisterEvent(event)
	end
	table.insert(handlers[event], fn)
end

-- Hook every bag slot button, including ones made later, recording each in `hooked`. `update` runs whenever the
-- button redraws its junk coin, and again as a bag opens; `click` runs after a modified click.
function ns.HookBagButtons(hooked, update, click)
	-- A bag reports its size before its buttons exist, so a slot can have no button yet.
	local function Hook(button)
		if not button or hooked[button] then
			return
		end
		hooked[button] = true
		hooksecurefunc(button, "UpdateJunkItem", update)
		-- OnModifiedClick avoids ever running after the ordinary use/equip/sell path.
		hooksecurefunc(button, "OnModifiedClick", click)
	end
	hooksecurefunc(ContainerFrameItemButtonMixin, "OnLoad", Hook)
	hooksecurefunc("ContainerFrame_GenerateFrame", function(container)
		for _, button in container:EnumerateValidItems() do
			Hook(button)
			update(button)
		end
	end)
	for _, container in ContainerFrameUtil_EnumerateContainerFrames() do
		for _, button in container:EnumerateValidItems() do
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
	TweaksForeverDB = TweaksForeverDB or {}
	ns.db = TweaksForeverDB
	ns.db.junk = ns.db.junk or {}
	for _, feature in ipairs(ns.features) do
		if ns.db[feature.key] == nil then
			ns.db[feature.key] = feature.default
		end
	end
	ns.RefreshConflicts()
	ready = true
	for _, fn in ipairs(pending) do
		Start(fn)
	end
	pending = nil
end)
