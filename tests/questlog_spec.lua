local init, settings, features = {}, {}, {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		init[#init + 1] = fn
	end,
	OnSettingChanged = function(key, fn)
		settings[key] = fn
	end,
	Active = function(key)
		return features[key].default
	end,
}
local log = {
	{ isHeader = true, questID = 0 },
	{ title = "First", questID = 101 },
	{ title = "Cannot abandon", questID = 102 },
	{ title = "Hidden", questID = 103, isHidden = true },
	{ title = "Last", questID = 104 },
}
local selected, target, combat, cvar = 102, nil, false, false
local abandoned = {}
local function Find(id)
	for index, info in ipairs(log) do
		if info.questID == id then
			return index
		end
	end
end
local env = setmetatable({
	InCombatLockdown = function()
		return combat
	end,
	GetCVarBool = function()
		return cvar
	end,
	SetCVar = function(name, value)
		assert(name == "showQuestLevel")
		cvar = value == "1"
	end,
	C_QuestLog = {
		GetNumQuestLogEntries = function()
			return #log
		end,
		GetInfo = function(index)
			return log[index]
		end,
		GetLogIndexForQuestID = Find,
		IsQuestDisabledForSession = function(id)
			return id == 105
		end,
		CanAbandonQuest = function(id)
			return id ~= 102
		end,
		GetSelectedQuest = function()
			return selected
		end,
		SetSelectedQuest = function(id)
			selected = id
		end,
		SetAbandonQuest = function()
			target = selected
		end,
		AbandonQuest = function()
			abandoned[#abandoned + 1] = target
			table.remove(log, assert(Find(target)))
		end,
		GetQuestDifficultyLevel = function(id)
			return id == 101 and 19 or 0
		end,
	},
}, { __index = _G })
assert(loadfile("Locales/enUS.lua"))("TweaksForever", ns)
setfenv(assert(loadfile("Quests/QuestLevels.lua")), env)("TweaksForever", ns)
setfenv(assert(loadfile("Quests/QuestLog.lua")), env)("TweaksForever", ns)
assert(loadfile("Data/ForeverQuests.lua"))("TweaksForever", ns)
assert(ns.ForeverQuests[92750] and not ns.ForeverQuests[455] and not ns.ForeverQuests[9999999])
assert(ns.QuestTitle(101, "First") == "First")
init[1]()
assert(cvar and ns.QuestTitle(101, "First") == "[19] First")
assert(ns.QuestTitle(101, "[19] First") == "[19] First")
assert(ns.QuestTitle(999, "Unknown") == "Unknown", "never manufacture a level")
features.questLevels.default = false
settings.questLevels()
assert(not cvar)
local model = ns.QuestLog
assert(#model.Entries() == 3, "headers and hidden quests never offered")
local ids = model.Selection({ [101] = true, [102] = true, [103] = true, [104] = true, [999] = true })
assert(table.concat(ids, ",") == "101,104", "only current visible abandonable selections")
combat = true
model.Abandon(ids)
assert(#abandoned == 0, "no changes in combat")
combat = false
model.Abandon(ids)
assert(table.concat(abandoned, ",") == "101,104", "stable IDs survive shrinking log indices")
assert(selected == 102, "previous quest selection restored")
model.Abandon(ids)
assert(#abandoned == 2, "stale confirmed IDs never abandon a different quest")
print("questlog: stable batch selection and native quest levels verified")

local frames = {}
local methods = {}
for _, name in ipairs({
	"SetSize",
	"SetPoint",
	"SetFrameStrata",
	"SetJustifyH",
	"SetWidth",
	"SetHitRectInsets",
	"SetFontString",
	"HookScript",
}) do
	methods[name] = function() end
end
function methods:SetText(value)
	self.text = value
end
function methods:SetScript(event, fn)
	self.scripts[event] = fn
end
function methods:SetShown(shown)
	if self.shown ~= shown then
		self.shown = shown
		local fn = self.scripts[shown and "OnShow" or "OnHide"]
		if fn then
			fn(self)
		end
	end
end
function methods:Hide()
	self:SetShown(false)
end
function methods:IsShown()
	return self.shown
end
function methods:SetEnabled(enabled)
	self.enabled = enabled
end
function methods:SetChecked(checked)
	self.checked = checked
end
function methods:GetChecked()
	return self.checked
end
function methods:SetFrameLevel(level)
	self.level = level
end
function methods:GetFrameLevel()
	return self.level
end
local function Frame(parent)
	local frame = setmetatable(
		{ parent = parent, scripts = {}, shown = true, level = parent and parent.level + 1 or 1 },
		{
			__index = methods,
		}
	)
	frames[#frames + 1] = frame
	return frame
end
function methods:CreateFontString()
	return Frame(self)
end
local quests = Frame()
quests.level = 3
local scroll = Frame(quests)
scroll.level = 5
local function Button(text)
	for _, frame in ipairs(frames) do
		if frame.text == text and frame.scripts.OnClick then
			return frame
		end
	end
	error("Missing button: " .. text)
end
local function Click(button)
	assert(button.enabled ~= false and button.shown, "button must be usable")
	button.scripts.OnClick(button)
end
env.CreateFrame = function(_, _, parent)
	return Frame(parent)
end
env.UIParent = Frame()
env.QuestMapFrame = { QuestsFrame = quests, DetailsFrame = { ScrollFrame = {} } }
env.QuestScrollFrame = scroll
env.QuestLogPopupDetailFrame = Frame()
env.QuestFrameDetailPanel = Frame()
env.QuestFrame = Frame()
env.QuestFrame:Hide()
env.hooksecurefunc = function() end
env.PAGE_NUMBER_WITH_MAX = "%d / %d"
ns.On = function() end
log = { { title = "First", questID = 101 }, { title = "Last", questID = 104 } }
init[2]()
local open = Button("Abandon quests")
-- The native scroll area's background receives clicks across the button's bounds.
local receiver = open.level > scroll.level and open or scroll
assert(receiver.scripts.OnClick, "the native scroll area must not intercept Abandon quests")
Click(receiver)
local selectAll = Button("Select all")
local panel = selectAll.parent
assert(panel.shown, "click opens the checklist")
Click(selectAll)
Click(Button("Abandon selected (2)"))
assert(Button("Confirm abandon (2)") and #abandoned == 2, "first click only requests confirmation")
Click(Button("Cancel"))
assert(not panel.shown and #abandoned == 2, "cancel never abandons quests")
Click(open)
assert(Button("Abandon selected (0)").enabled == false, "reopening clears the selection and pending confirmation")
print("questlog: native scroll overlap and selection/confirmation/cancel verified")
