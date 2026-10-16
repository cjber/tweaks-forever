---@type string, TFNamespace
local _, ns = ...
local L = ns.L

-- Tweaks' hints for my other Forever addons, behind the shared "Suggest my other Forever addons" setting
-- (db.suggestFamily, on the Forever addons page that UI/ForeverFamily.lua draws).

local SPF = "ShortestPathForever"
-- Family.Hint keys are shared by all five addons, so each starts with this addon's folder.
local ENTRANCE_KEY = "TweaksForever.entrance"

-- The grey line on a dungeon entrance's tooltip. Without Shortest Path Forever installed: what it would add,
-- through Family.Hint (the shared setting on, not dismissed). Installed but switched off: why a click only sets
-- a waypoint. That explains a missing feature rather than suggesting an addon, so the setting ("only for addons
-- you don't have") leaves it alone; it needs the client to say plainly that the addon exists, since the module
-- reads an answer it can't get as "off".
---@return string?
function ns.EntranceHint()
	local Family, db = ns.Family, ns.db
	if not (Family and db) then
		return nil
	end
	if Family.Hint(db, ENTRANCE_KEY, SPF) then
		return L["With Shortest Path Forever, click to plan the way there."]
	end
	if Family.State(SPF) == "off" then
		local ok, exists = pcall(C_AddOns.DoesAddOnExist, SPF)
		if ok and exists == true then
			return L["Enable Shortest Path Forever for walked routes and boat times."]
		end
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
