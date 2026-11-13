-- Whisper tabs and a player card (Chat/WhisperTabs.lua, Chat/UnreadCount.lua, Chat/LastGrouped.lua,
-- Chat/PlayerCard.lua, Chat/PlayerRecord.lua): every option off leaves chat alone; the whisper mode CVar is set and
-- restored across a fresh module load while an existing popout mode is never touched; an unselected whisper tab
-- counts its whispers and clears on selection; the group record is written on GROUP_ROSTER_UPDATE, capped, and read
-- back as the grey line only when it exists; the card shows only fields the client or the record states, and only
-- for player: links.

local now = 1000
local groupSize, guildName, inInstance, instanceName, zone = 0, "Silver Hand", true, "Deadmines", "Elwynn Forest"
local selected
local cvarWrites = {}
local cvars = { whisperMode = "inline" }
local features, filters, handlers, settingHandlers = {}, {}, {}, {}
local secured = {}

local units = {
	player = { name = "Bob", level = 60 },
	party1 = { name = "Thrall", level = 39 },
	party2 = { name = "Jaina", level = 30 },
}

local guild = {
	{ name = "Thrall", level = 39, zone = "Stranglethorn Vale", online = true },
}

local people = {
	["Player-1"] = { "Mage", "MAGE", "Gnome", "Gnome", 2, "Thrall", "Realm" },
}

local function Frame(frameName, fields)
	-- GetName is the client's frame name (ChatFrame5); `name` is the window's display name, which the client also
	-- sets from the whisper partner, exactly as FCF_SetWindowName does.
	local frame = { id = tonumber(frameName:match("(%d+)$")), messages = {} }
	for key, value in pairs(fields or {}) do
		frame[key] = value
	end
	function frame.GetName()
		return frameName
	end
	function frame:GetID()
		return self.id
	end
	function frame:AddMessage(text, r, g, b)
		self.messages[#self.messages + 1] = { text = text, r = r, g = g, b = b }
	end
	function frame:GetNumMessages()
		return #self.messages
	end
	function frame:GetMessageInfo(index)
		local message = self.messages[index]
		if not message then
			return nil
		end
		return message.text, message.r, message.g, message.b, 0, 0, message.lineID, message.event, message.eventArgs
	end
	function frame:HookScript(script, fn)
		self.hooks = self.hooks or {}
		self.hooks[script] = self.hooks[script] or {}
		self.hooks[script][#self.hooks[script] + 1] = fn
	end
	function frame:Fire(script, ...)
		for _, fn in ipairs((self.hooks and self.hooks[script]) or {}) do
			fn(self, ...)
		end
	end
	return frame
end

local function Tab(id)
	local tab = { id = id, text = "", sizePadding = 0, Text = {} }
	function tab:GetID()
		return self.id
	end
	function tab:GetText()
		return self.text
	end
	function tab:SetText(text)
		self.text = text
	end
	return tab
end

local env = setmetatable({
	canaccessvalue = function(value)
		return value ~= "secret"
	end,
	Ambiguate = function(name)
		return (name:gsub("%-.*$", ""))
	end,
	UnitName = function(unit)
		local entry = units[unit]
		return entry and entry.name
	end,
	UnitLevel = function(unit)
		local entry = units[unit]
		return entry and entry.level or 0
	end,
	UnitExists = function(unit)
		return units[unit] ~= nil
	end,
	UnitIsPlayer = function(unit)
		return units[unit] ~= nil
	end,
	GetNumGroupMembers = function()
		return groupSize
	end,
	IsInRaid = function()
		return false
	end,
	IsInGuild = function()
		return true
	end,
	GetNumGuildMembers = function()
		return #guild
	end,
	GetGuildRosterInfo = function(index)
		local member = guild[index]
		if not member then
			return nil
		end
		return member.name, "Rank", 0, member.level, "Mage", member.zone, "", "", member.online
	end,
	GetGuildInfo = function(unit)
		if unit == "player" then
			return guildName
		end
	end,
	C_FriendList = {
		GetFriendInfo = function()
			return nil
		end,
		GetNumFriends = function()
			return 0
		end,
		GetFriendInfoByIndex = function()
			return nil
		end,
		GetNumWhoResults = function()
			return 0
		end,
		GetWhoInfo = function()
			return nil
		end,
	},
	GetCVar = function(name)
		return cvars[name]
	end,
	SetCVar = function(name, value)
		cvarWrites[#cvarWrites + 1] = { name = name, value = value }
		cvars[name] = value
	end,
	GetPlayerInfoByGUID = function(guid)
		local info = people[guid]
		if info then
			return unpack(info)
		end
	end,
	RAID_CLASS_COLORS = {
		MAGE = {
			GetRGB = function()
				return 0.25, 0.78, 0.92
			end,
		},
	},
	ChatFrameUtil = {
		AddMessageEventFilter = function(event, fn)
			filters[event] = filters[event] or {}
			filters[event][#filters[event] + 1] = fn
		end,
		AddSenderNameFilter = function() end,
	},
	FCFDock_GetSelectedWindow = function()
		return selected
	end,
	FCF_SetTemporaryWindowType = function(frame, chatType, target)
		for _, fn in ipairs(secured.FCF_SetTemporaryWindowType or {}) do
			fn(frame, chatType, target)
		end
	end,
	FCF_Tab_OnClick = function() end,
	GENERAL_CHAT_DOCK = {},
	CHAT_FRAMES = { "ChatFrame1", "ChatFrame5" },
	GetTime = function()
		return now
	end,
	time = function()
		return now
	end,
	GetRealZoneText = function()
		return zone
	end,
	GetInstanceInfo = function()
		return instanceName, "party", 1
	end,
	IsInInstance = function()
		return inInstance
	end,
	hooksecurefunc = function(name, fn)
		if type(name) == "string" then
			secured[name] = secured[name] or {}
			secured[name][#secured[name] + 1] = fn
		end
	end,
	LASTONLINE_SECS = "< a minute",
	LASTONLINE_MINUTES = "%d minutes",
	LASTONLINE_HOURS = "%d hours",
	LASTONLINE_DAYS = "%d days",
	TweaksForeverCharDB = {},
	GRAY_FONT_COLOR = {
		WrapTextInColorCode = function(_, text)
			return "|cff808080" .. text .. "|r"
		end,
	},
}, { __index = _G })

env._G = env

local db = {}
local ns = {
	db = db,
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
	Feature = function(feature)
		features[feature.key] = feature
	end,
	On = function(event, fn)
		handlers[event] = handlers[event] or {}
		handlers[event][#handlers[event] + 1] = fn
	end,
	OnSettingChanged = function(key, fn)
		settingHandlers[key] = fn
	end,
	Init = function(fn)
		fn()
	end,
	Active = function(key)
		return db[key] == true
	end,
	core = {
		SafeCall = function(_, fn, ...)
			return pcall(fn, ...)
		end,
	},
}
function ns.Readable(value)
	if not env.canaccessvalue(value) then
		return nil
	end
	return value
end
function ns.Usable(frame)
	return frame ~= nil
end

-- The card's tooltip: the real GameTooltip's methods the option uses.
local tooltip = { lines = {} }
function tooltip:SetOwner(owner, anchor)
	self.owner, self.anchor = owner, anchor
end
function tooltip:SetText(text, r, g, b)
	self.title, self.r, self.g, self.b = text, r, g, b
end
function tooltip:AddLine(text)
	self.lines[#self.lines + 1] = text
end
function tooltip:Show()
	self.shown = true
end
function tooltip:Hide()
	self.shown = false
end
function tooltip:Reset()
	self.lines, self.title, self.shown = {}, nil, false
end
env.GameTooltip = tooltip

local general = Frame("ChatFrame1", { id = 1 })
local whisper = Frame("ChatFrame5", {
	id = 5,
	isTemporary = true,
	chatType = "WHISPER",
	chatTarget = "THRALL",
	name = "Thrall",
})
env.ChatFrame1, env.ChatFrame5 = general, whisper
local whisperTab = Tab(5)
whisperTab.text = "Thrall"
env.ChatFrame5Tab = whisperTab

for _, path in ipairs({
	"Chat/Shared.lua",
	"Chat/ClassLevels.lua",
	"Chat/PlayerRecord.lua",
	"Chat/WhisperTabs.lua",
	"Chat/UnreadCount.lua",
	"Chat/LastGrouped.lua",
	"Chat/PlayerCard.lua",
}) do
	setfenv(assert(loadfile(path)), env)("TweaksForever", ns)
end

local function Fire(event, ...)
	for _, fn in ipairs(filters[event] or {}) do
		fn(...)
	end
end

-- Handlers registered through ns.On are called with the event's arguments only, never the event name: Core.lua's
-- event frame does `ns.core.SafeCall(event, fn, ...)`. Dispatch must do the same or a handler reading the wrong
-- argument still passes here.
local function Emit(event, ...)
	for _, fn in ipairs(handlers[event] or {}) do
		fn(...)
	end
end

-- Every option is off to start with. No whisper mode is written, no whisper tab changes, no line is added, no
-- group is recorded, and no card is shown.
local untouchedTab = whisperTab.text
ns.ChatWhisperTabs.Sync()
assert(#cvarWrites == 0, "whisper mode is not touched while every option is off")
ns.ChatLastGrouped.Attach(whisper, "THRALL")
assert(#whisper.messages == 0, "no grouped line is added while the option is off")
Fire("CHAT_MSG_WHISPER", whisper, "hi", "Thrall", "", "", "", "", 0, 0, "", 0, 1)
assert(whisperTab.text == untouchedTab, "a whisper tab is not labelled while the option is off")
groupSize = 3
Emit("GROUP_ROSTER_UPDATE")
assert(env.TweaksForeverCharDB.chatPlayers == nil, "no group is recorded while the option is off")
groupSize = 0
tooltip:Reset()
whisper:Fire("OnHyperlinkEnter", "player:Thrall:1:WHISPER:THRALL", "[Thrall]")
assert(not tooltip.shown, "no card is shown while the option is off")

-- Each is its own feature, in the Chat category and off by default. The whisper options name WIM and Prat.
local expected = {
	chatWhisperTabs = "Whisper tabs",
	chatWhisperUnread = "Unread whispers on tabs",
	chatLastGrouped = "Last grouped with",
	chatPlayerCard = "Player card on hover",
}
for key, name in pairs(expected) do
	assert(features[key], key .. " is declared")
	assert(features[key].category == "Chat", key .. " is in the Chat category")
	assert(features[key].default == false, key .. " starts off")
	assert(features[key].name == name, key .. " is named")
end
for _, key in ipairs({ "chatWhisperTabs", "chatWhisperUnread", "chatLastGrouped" }) do
	local conflicts = {}
	for _, conflict in ipairs(features[key].conflicts or {}) do
		conflicts[conflict.addon] = true
	end
	assert(conflicts.WIM, key .. " names WIM")
	assert(conflicts["Prat-3.0"], key .. " names Prat")
end

-- Whisper tabs: the client's own New Whispers setting is forced to popout, the player's value is kept across a
-- fresh module load, and turning the option off puts that value back and clears it.
cvars.whisperMode = "inline"
db.chatWhisperModeSaved = nil
db.chatWhisperTabs = true
cvarWrites = {}
ns.ChatWhisperTabs.Sync()
assert(cvars.whisperMode == "popout", "whisper tabs are on")
assert(db.chatWhisperModeSaved == "inline", "the player's own mode is kept")

setfenv(assert(loadfile("Chat/WhisperTabs.lua")), env)("TweaksForever", ns)
ns.ChatWhisperTabs.Sync()
assert(cvars.whisperMode == "popout", "a reload keeps whisper tabs on")
assert(db.chatWhisperModeSaved == "inline", "our own popout never replaces the player's mode")

db.chatWhisperTabs = false
ns.ChatWhisperTabs.Sync()
assert(cvars.whisperMode == "inline", "the player's own mode comes back")
assert(db.chatWhisperModeSaved == nil, "the saved mode is cleared after restoring")

-- A mode that already docks whisper tabs is left exactly alone, and nothing of ours is saved.
for _, mode in ipairs({ "popout", "popout_and_inline" }) do
	cvars.whisperMode = mode
	db.chatWhisperModeSaved = nil
	db.chatWhisperTabs = true
	cvarWrites = {}
	ns.ChatWhisperTabs.Sync()
	assert(#cvarWrites == 0, mode .. " is not rewritten")
	assert(db.chatWhisperModeSaved == nil, mode .. " saves nothing")
	db.chatWhisperTabs = false
	ns.ChatWhisperTabs.Sync()
	assert(#cvarWrites == 0, mode .. " is not changed when the option goes off")
	assert(cvars.whisperMode == mode, mode .. " stays as the player had it")
end

-- Unread counts: a whisper to an unselected whisper tab counts, a whisper to the selected tab does not, and
-- selecting the tab clears the count and puts the client's name back.
db.chatWhisperUnread = true
whisper.name = "Thrall"
whisperTab.text = "Thrall"
env.FCF_SetTemporaryWindowType(whisper, "WHISPER", "THRALL")
selected = general
Fire("CHAT_MSG_WHISPER", whisper, "one", "Thrall", "", "", "", "", 0, 0, "", 0, 2)
assert(whisperTab.text == "Thrall (1)", "an unselected whisper tab counts its first whisper")
Fire("CHAT_MSG_WHISPER", whisper, "two", "Thrall", "", "", "", "", 0, 0, "", 0, 3)
assert(whisperTab.text == "Thrall (2)", "the count goes up")
Fire("CHAT_MSG_WHISPER", general, "three", "Thrall", "", "", "", "", 0, 0, "", 0, 4)
assert(whisperTab.text == "Thrall (2)", "a whisper to another frame does not count")
selected = whisper
Fire("CHAT_MSG_WHISPER", whisper, "four", "Thrall", "", "", "", "", 0, 0, "", 0, 5)
assert(whisperTab.text == "Thrall (2)", "a whisper in the selected tab does not count")
assert(#(secured.FCF_Tab_OnClick or {}) == 1, "the client's tab click is hooked")
secured.FCF_Tab_OnClick[1](whisperTab, "LeftButton")
assert(whisperTab.text == "Thrall", "selecting the tab clears the count and keeps the client's name")
selected = general
Fire("CHAT_MSG_WHISPER", whisper, "five", "Thrall", "", "", "", "", 0, 0, "", 0, 6)
assert(whisperTab.text == "Thrall (1)", "the count starts again after the tab was read")
db.chatWhisperUnread = false
settingHandlers.chatWhisperUnread()
assert(whisperTab.text == "Thrall", "turning the option off puts the client's name back")

-- The group record: every other player in the group, with the moment and the instance's name, never the player.
db.chatLastGrouped = true
env.TweaksForeverCharDB.chatPlayers = nil
groupSize = 3
now = 1000
Emit("GROUP_ROSTER_UPDATE")
local record = ns.ChatPlayerRecord.Get("Thrall")
assert(record and record.time == 1000, "the group time is recorded")
assert(record.zone == "Deadmines", "the instance's own name is the place")
assert(ns.ChatPlayerRecord.Get("Jaina"), "every other group member is recorded")
assert(ns.ChatPlayerRecord.Get("Bob") == nil, "the player is not in their own record")
assert(ns.ChatPlayerRecord.Get("thrall") == record, "names are matched without case, as a whisper target is uppercased")

-- A group update writes every member and then checks the cap once, not once per member: GROUP_ROSTER_UPDATE fires
-- often in a raid, and a scan of the whole table per member is 40 scans for a full raid.
local trims = 0
local realTrim = ns.ChatPlayerRecord.Trim
ns.ChatPlayerRecord.Trim = function(...)
	trims = trims + 1
	return realTrim(...)
end
groupSize = 3
Emit("GROUP_ROSTER_UPDATE")
ns.ChatPlayerRecord.Trim = realTrim
assert(trims == 1, "a group update trims the record once")
assert(ns.ChatPlayerRecord.Get("Thrall") and ns.ChatPlayerRecord.Get("Jaina"), "every member is written")

-- The line reads back only when a group time exists, in the client's own relative wording, and only once.
now = 1000 + 3 * 24 * 60 * 60
assert(ns.ChatLastGrouped.Summary(record) == "Grouped with you 3 days ago in Deadmines", "the grouped line")
local lineFrame = Frame("ChatFrame6", {
	id = 6,
	isTemporary = true,
	chatType = "WHISPER",
	chatTarget = "THRALL",
})
ns.ChatLastGrouped.Attach(lineFrame, "THRALL")
assert(#lineFrame.messages == 1, "the line is added once")
assert(lineFrame.messages[1].text == "Grouped with you 3 days ago in Deadmines", "the window's first line")
assert(lineFrame.messages[1].r == 0.5 and lineFrame.messages[1].g == 0.5, "the line is grey")
lineFrame:AddMessage("hi", 1, 1, 1)
ns.ChatLastGrouped.Attach(lineFrame, "THRALL")
assert(#lineFrame.messages == 2, "a window that already holds lines gets no second line")
assert(lineFrame.messages[1].text:find("Grouped with you", 1, true), "the line stays first")
local nobody = Frame("ChatFrame7", { id = 7, isTemporary = true, chatType = "WHISPER", chatTarget = "NOBODY" })
ns.ChatLastGrouped.Attach(nobody, "NOBODY")
assert(#nobody.messages == 0, "no record, no line")
local chatty = Frame("ChatFrame8", { id = 8, isTemporary = true, chatType = "WHISPER", chatTarget = "CHATTY" })
ns.ChatPlayerRecord.Whispered("Chatty")
ns.ChatLastGrouped.Attach(chatty, "CHATTY")
assert(#chatty.messages == 0, "a whisper count without a group time adds no line")
local unplaced = Frame("ChatFrame9", { id = 9, isTemporary = true, chatType = "WHISPER", chatTarget = "UNPLACED" })
ns.ChatPlayerRecord.Grouped("Unplaced", nil, now)
ns.ChatLastGrouped.Attach(unplaced, "UNPLACED")
assert(
	unplaced.messages[1] and unplaced.messages[1].text == "Grouped with you < a minute ago",
	"a group with no place keeps the time and leaves the place out"
)
db.chatLastGrouped = false
local offFrame = Frame("ChatFrame10", { id = 10, isTemporary = true, chatType = "WHISPER", chatTarget = "THRALL" })
ns.ChatLastGrouped.Attach(offFrame, "THRALL")
assert(#offFrame.messages == 0, "the option off adds no line")

-- The cap: 500 names, the oldest record dropped. A group update writes one record per member, so 501 events with
-- one changing member leave the last 500.
db.chatLastGrouped = true
env.TweaksForeverCharDB.chatPlayers = nil
groupSize = 2
for index = 1, 501 do
	units.party1 = { name = "P" .. index, level = 1 }
	now = 2000 + index
	Emit("GROUP_ROSTER_UPDATE")
end
local kept = 0
for _ in pairs(env.TweaksForeverCharDB.chatPlayers) do
	kept = kept + 1
end
assert(kept == 500, "the record is capped at 500 names")
assert(ns.ChatPlayerRecord.Get("P1") == nil, "the oldest record is dropped")
assert(ns.ChatPlayerRecord.Get("P501"), "the newest record is kept")

-- A whole group written in the same second still keeps the record that triggered the sweep.
env.TweaksForeverCharDB.chatPlayers = nil
now = 3000
for index = 1, 501 do
	ns.ChatPlayerRecord.Grouped("T" .. index, nil, now)
end
assert(ns.ChatPlayerRecord.Get("T501"), "the record being written survives a tie")

-- The player card: only fields the client or the record states, and only for a player: link.
db.chatPlayerCard = true
db.chatLastGrouped = true
env.TweaksForeverCharDB.chatPlayers = nil
now = 1000 + 3 * 24 * 60 * 60
ns.ChatPlayerRecord.Grouped("Thrall", "Deadmines", 1000)
for _ = 1, 14 do
	ns.ChatPlayerRecord.Whispered("Thrall")
end
ns.ChatClassLevels.Remember("Thrall", 39)
units.party1 = { name = "Thrall", level = 39 }
guild = { { name = "Thrall", level = 39, zone = "Stranglethorn Vale", online = true } }

local cardFrame = Frame("ChatFrame11", { id = 11 })
cardFrame:AddMessage("|Hplayer:Thrall:55|h[Thrall]|h hello", 1, 1, 1)
cardFrame.messages[1].lineID = 55
cardFrame.messages[1].eventArgs = { [2] = "Thrall", [11] = 55, [12] = "Player-1" }
ns.ChatPlayerCard.Hook(cardFrame)

-- The client's relative formatter wins while the friends list is loaded; without it the client's own strings do.
env.FriendsListUtil = {
	GetRelativeTimeText = function()
		return "3 days"
	end,
}
assert(ns.ChatPlayerRecord.Ago(1000, now) == "3 days", "the friends list's own relative time is used")
env.FriendsListUtil = nil
assert(ns.ChatPlayerRecord.Ago(1000, now) == "3 days", "the fallback uses the client's own day string")

tooltip:Reset()
cardFrame:Fire("OnHyperlinkEnter", "player:Thrall:55:WHISPER:THRALL", "[Thrall]")
assert(tooltip.shown, "a player: link shows the card")
assert(tooltip.title == "Thrall", "the card is titled with the name")
assert(tooltip.r == 0.25 and tooltip.g == 0.78 and tooltip.b == 0.92, "the title takes the class colour")
local lines = table.concat(tooltip.lines, "\n")
assert(lines:find("Level 39 Gnome Mage", 1, true), "level, race and class from the line's GUID and the level cache")
assert(lines:find("Guild: Silver Hand", 1, true), "the guild roster's guild")
assert(lines:find("Zone: Stranglethorn Vale", 1, true), "the guild roster's zone")
assert(lines:find("Last grouped 3 days ago in Deadmines", 1, true), "the record's last group")
assert(lines:find("Whispers: 14", 1, true), "the record's whisper count")
assert(not lines:find("nil", 1, true), "no placeholder is shown")

-- No GUID and no record: only the name, and never a made-up level, place, group or count.
local bare = Frame("ChatFrame12", { id = 12 })
bare:AddMessage("|Hplayer:Nobody:77|h[Nobody]|h hi", 1, 1, 1)
bare.messages[1].lineID = 77
bare.messages[1].eventArgs = { [2] = "Bobby", [11] = 77, [12] = "Player-9" }
ns.ChatPlayerCard.Hook(bare)
tooltip:Reset()
bare:Fire("OnHyperlinkEnter", "player:Nobody:77:SAY:Bobby", "[Nobody]")
assert(tooltip.shown and tooltip.title == "Nobody", "the name alone is still a card")
assert(#tooltip.lines == 0, "an unknown player gets no level, place, group or whisper lines")

-- A secret GUID is never read: the identity fields are left out rather than guessed.
local hidden = Frame("ChatFrame13", { id = 13 })
hidden:AddMessage("|Hplayer:Thrall:88|h[Thrall]|h hi", 1, 1, 1)
hidden.messages[1].lineID = 88
hidden.messages[1].eventArgs = { [2] = "Thrall", [11] = 88, [12] = "secret" }
ns.ChatPlayerCard.Hook(hidden)
tooltip:Reset()
hidden:Fire("OnHyperlinkEnter", "player:Thrall:88:SAY:THRALL", "[Thrall]")
local hiddenLines = table.concat(tooltip.lines, "\n")
assert(not hiddenLines:find("Level", 1, true), "a secret GUID gives no level")
assert(not hiddenLines:find("Gnome", 1, true), "a secret GUID gives no race")
assert(hiddenLines:find("Whispers: 14", 1, true), "the record's own fields still show")

-- Only player: links: an item link and a Battle.net link leave the tooltip alone.
cardFrame:Fire("OnHyperlinkLeave")
tooltip:Reset()
cardFrame:Fire("OnHyperlinkEnter", "item:2589:0:0:0:0:0:0", "[Linen Cloth]")
assert(not tooltip.shown, "an item link shows no card")
cardFrame:Fire("OnHyperlinkEnter", "BNplayer:Someone:1:WHISPER:0", "[Someone]")
assert(not tooltip.shown, "a Battle.net link shows no card")

-- Whispers are counted both ways round, each event once, and only while the card is on.
local before = ns.ChatPlayerRecord.Get("Thrall").whispers
Emit("CHAT_MSG_WHISPER", "hello", "Thrall")
Emit("CHAT_MSG_WHISPER_INFORM", "hello back", "Thrall")
assert(ns.ChatPlayerRecord.Get("Thrall").whispers == before + 2, "both sides of a whisper are counted")
db.chatPlayerCard = false
Emit("CHAT_MSG_WHISPER", "hello", "Thrall")
assert(ns.ChatPlayerRecord.Get("Thrall").whispers == before + 2, "the card off stops counting")

print("chat whispers: ok")
