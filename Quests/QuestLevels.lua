---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "questLevels",
	category = "Interface",
	name = "Show quest levels",
	tooltip = "Shows quest levels in the tracker, on map quest tooltips, and beside quest names added by Tweaks Forever.",
	default = true,
})

-- The client already uses this CVar for its tracker and map pins. Let its own callbacks redraw them.
ns.Init(function()
	local function Apply()
		SetCVar("showQuestLevel", ns.Active("questLevels") and "1" or "0")
	end
	ns.OnSettingChanged("questLevels", Apply)
	Apply()
end)

---@param id integer
---@param title string
---@return string
function ns.QuestTitle(id, title)
	if not GetCVarBool("showQuestLevel") or title:match("^%[%d+%+?%]") then
		return title
	end
	local level = C_QuestLog.GetQuestDifficultyLevel(id)
	return level and level > 0 and ("[%d] %s"):format(level, title) or title
end
