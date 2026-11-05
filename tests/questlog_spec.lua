local init, settings, features = {}, {}, {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		init[#init + 1] = fn
	end,
	-- Records the width each button asks for, as Core's FitButton widens it to a longer translated label.
	FitButton = function(button, width)
		button.fitted = width
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
		IsQuestDisabledForSession = function()
			return false
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
env.hooksecurefunc = env.hooksecurefunc or function() end
ns.On = ns.On or function() end
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
	"SetFrameStrata",
	"SetJustifyH",
	"SetWidth",
	"SetHitRectInsets",
	"SetFontString",
	"HookScript",
	"SetChecked",
}) do
	methods[name] = function() end
end
function methods:SetPoint(...)
	self.point = { ... }
end
function methods:ClearAllPoints()
	self.point = nil
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
function methods:IsVisible()
	local frame = self
	while frame do
		if not frame.shown then
			return false
		end
		frame = frame.parent
	end
	return true
end
function methods:SetEnabled(enabled)
	self.enabled = enabled
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
scroll.BorderFrame = Frame(scroll)
scroll.BorderFrame.Shadow = Frame(scroll.BorderFrame)
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
-- The world map hides the quest list and shows one quest's details in its place; the button belongs to the list
-- and must go with it, rather than sitting over the details page.
assert(open.parent == scroll, "the Abandon quests button must be parented to the quest list")
-- The list stops 34 units above the panel's bottom, as the search box's header band does at the top, so the button
-- sits below the last row instead of over its objectives. The button is 4 units above the panel's bottom, leaving
-- 8 units between its top and the list.
assert(scroll.point[1] == "BOTTOMRIGHT" and scroll.point[3] == 34, "the list reserves a footer for the button")
assert(
	open.point[1] == "BOTTOMLEFT" and open.point[2] == scroll and open.point[3] == "BOTTOMLEFT" and open.point[5] == -30,
	"the button sits in the reserved footer"
)
assert(scroll.BorderFrame.point[5] == -40, "the quest log's frame art still reaches the panel's bottom")
assert(scroll.BorderFrame.Shadow.point[5] == 38, "the bottom shadow stays on the list's edge, not the footer")
scroll:SetShown(false)
assert(not open:IsVisible(), "the button hides with the list while a quest's details show")
scroll:SetShown(true)
-- The button sits below the list, clear of the native scroll area, so its own click opens the checklist.
Click(open)
local selectAll = Button("Select all")
-- Each button widens to a longer translated label, and Clear selection stays beside Select all however wide it is.
assert(open.fitted == 140 and selectAll.fitted == 110, "the buttons fit their labels")
local clear = Button("Clear selection")
assert(clear.fitted == 130 and clear.point[2] == selectAll and clear.point[3] == "RIGHT", "anchored to Select all")
local panel = selectAll.parent
assert(panel.shown, "click opens the checklist")
Click(selectAll)
Click(Button("Abandon selected (2)"))
assert(Button("Confirm abandon (2)") and #abandoned == 2, "first click only requests confirmation")
Click(Button("Cancel"))
assert(not panel.shown and #abandoned == 2, "cancel never abandons quests")
Click(open)
assert(
	Button("Abandon selected (0)").enabled == false and Button("Abandon selected (0)").fitted == 210,
	"reopening clears the selection and pending confirmation"
)
-- With the feature off, the list keeps the game's own size and the button leaves with the footer.
features.bulkAbandon.default = false
settings.bulkAbandon()
assert(not open.shown, "the button hides with the feature")
assert(scroll.point[3] == 0 and scroll.BorderFrame.point[5] == -6, "the list takes its native size back")
assert(scroll.BorderFrame.Shadow.point[5] == 4, "the shadow returns to the game's list edge")
print("questlog: footer placement and selection/confirmation/cancel verified")
