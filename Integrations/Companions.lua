---@type string, TFNamespace
local _, ns = ...
local L = ns.L

-- Tweaks' hints for my other Forever addons, behind the shared "Suggest my other Forever addons" setting
-- (db.suggestFamily, on the Forever addons page that UI/ForeverFamily.lua draws).

local SPF = "ShortestPathForever"
-- Family.Hint keys are shared by all five addons, so each starts with this addon's folder.
local ENTRANCE_KEY = "TweaksForever.entrance"

-- The grey line on a dungeon entrance's tooltip. Without Shortest Path Forever installed: what it would add,
-- through Family.Hint (on, not dismissed). Installed but switched off: why clicking only sets a waypoint, which
-- explains a missing feature rather than suggesting an addon, so only the setting turns it off.
---@return string?
function ns.EntranceHint()
	local Family, db = ns.Family, ns.db
	if not (Family and db) then
		return nil
	end
	local state = Family.State(SPF)
	if state == "missing" then
		return Family.Hint(db, ENTRANCE_KEY, SPF) and L["With Shortest Path Forever, click to plan the way there."]
			or nil
	elseif state == "off" and db.suggestFamily ~= false then
		return L["Enable Shortest Path Forever for walked routes and boat times."]
	end
end

-- The old "Suggest companion addons" setting becomes the shared one: turned off, it turns suggestFamily off once.
ns.Init(function()
	local db = ns.db
	if db.companionHints == false and db.suggestFamily == nil then
		db.suggestFamily = false
	end
	db.companionHints = nil
end)
