-- Readable chat (Chat/*.lua): every option off leaves chat alone; short channel and fixed headers keep their links
-- without changing the event's arguments; levels come only from the client's own sources, one source per event;
-- class colours use the client's one override CVar and survive a reload; only item links get icons; repeats fold on
-- the client's line ID within two minutes, never on a secret value; mentions match a whole word in plain text and
-- never inside a link; web links become copy links; history saves and replays above its divider.

local now = 1000
local readable = true

local function Pack(...)
	return { n = select("#", ...), ... }
end

local function Unpack(packed)
	return unpack(packed, 1, packed.n)
end

local features, filters, nameFilters, handlers, timers = {}, {}, {}, {}, {}
local madeFrames = {}
local opened
local linkHandlers = {}
local cvars, cvarWrites = { chatClassColorOverride = "1" }, {}

local function Widget(kind, name, parent, template)
	local widget = {
		kind = kind,
		name = name,
		parent = parent,
		template = template,
		shown = false,
		text = nil,
	}
	function widget:GetName()
		return self.name
	end
	function widget.SetSize() end
	function widget.SetFrameStrata() end
	function widget.SetClampedToScreen() end
	function widget.SetPoint() end
	function widget.SetHeight() end
	function widget.SetAutoFocus() end
	function widget:HighlightText()
		self.highlighted = true
	end
	function widget:SetFocus()
		self.focused = true
	end
	function widget:SetText(text)
		self.text = text
	end
	function widget:Show()
		self.shown = true
	end
	function widget:Hide()
		self.shown = false
	end
	madeFrames[#madeFrames + 1] = widget
	return widget
end

local function Frame(name)
	local frame = { name = name, messages = {} }
	function frame:GetName()
		return self.name
	end
	function frame:AddMessage(text, r, g, b, ...)
		local extra = Pack(...)
		self.messages[#self.messages + 1] = { text = text, r = r, g = g, b = b, extra = extra }
	end
	-- A back-filled line goes above the lines the frame already holds, the way ScrollingMessageFrameMixin does it.
	function frame:BackFillMessage(text, r, g, b, ...)
		local extra = Pack(...)
		table.insert(self.messages, 1, { text = text, r = r, g = g, b = b, extra = extra })
	end
	function frame:GetNumMessages()
		return #self.messages
	end
	function frame:GetMessageInfo(index)
		local message = self.messages[index]
		if not message then
			return nil
		end
		return message.text, message.r, message.g, message.b, Unpack(message.extra)
	end
	function frame:RemoveMessagesByPredicate(predicate)
		local kept = {}
		for _, message in ipairs(self.messages) do
			local args = Pack(message.text, message.r, message.g, message.b, Unpack(message.extra))
			if not predicate(Unpack(args)) then
				kept[#kept + 1] = message
			end
		end
		self.messages = kept
	end
	function frame:TransformMessages(predicate, transform)
		for index, message in ipairs(self.messages) do
			local args = Pack(message.text, message.r, message.g, message.b, Unpack(message.extra))
			if predicate(Unpack(args)) then
				local changed = Pack(transform(Unpack(args)))
				message.text, message.r, message.g, message.b = changed[1], changed[2], changed[3], changed[4]
				message.extra = { n = changed.n - 4 }
				for at = 5, changed.n do
					message.extra[at - 4] = changed[at]
				end
			end
			self.messages[index] = message
		end
	end
	function frame.GetID()
		return 1
	end
	return frame
end

local docked = { Frame("ChatFrame1") }
local player = { name = "Bob", level = 60 }
local units = {
	player = player,
	target = { name = "Alice", level = 42 },
}
local guild = { { "Guildie", 30 }, { "Offline", 0 } }
local friends =
	{ { name = "Friend", level = 25, connected = true }, { name = "Offline", level = 70, connected = false } }
local who = { { fullName = "Who", level = 18 } }

local env = setmetatable({
	canaccessvalue = function(value)
		return readable or value ~= "secret"
	end,
	Ambiguate = function(name)
		return (name:gsub("%-.*$", ""))
	end,
	UnitName = function(unit)
		local entry = units[unit]
		return entry and entry.name or nil
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
		return 1
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
		return member and member[1], "Rank", 0, member and member[2]
	end,
	C_FriendList = {
		GetNumFriends = function()
			return #friends
		end,
		GetFriendInfoByIndex = function(index)
			return friends[index]
		end,
		GetNumWhoResults = function()
			return #who
		end,
		GetWhoInfo = function(index)
			return who[index]
		end,
	},
	GetCVar = function(name)
		return cvars[name]
	end,
	SetCVar = function(name, value)
		cvarWrites[#cvarWrites + 1] = { name = name, value = value }
		cvars[name] = value
	end,
	ChatFrameUtil = {
		AddMessageEventFilter = function(event, fn)
			filters[event] = filters[event] or {}
			filters[event][#filters[event] + 1] = fn
		end,
		AddSenderNameFilter = function(fn)
			nameFilters[#nameFilters + 1] = fn
		end,
		-- The client's own display name for a channel: the number prefix and the channel name.
		ResolvePrefixedChannelName = function(name)
			local prefix, channel = tostring(name):match("^(%d+%. )(.*)$")
			return prefix and (prefix .. channel) or tostring(name)
		end,
	},
	FCFDock_GetChatFrames = function()
		return docked
	end,
	GENERAL_CHAT_DOCK = {},
	CHAT_FRAMES = { "ChatFrame1" },
	C_Timer = {
		After = function(_, fn)
			timers[#timers + 1] = fn
		end,
	},
	GetTime = function()
		return now
	end,
	time = function()
		return now
	end,
	C_Item = {
		GetItemIconByID = function(itemID)
			if itemID == 2589 then
				return "Interface\\Icons\\INV_Misc_Cloth_01"
			end
		end,
	},
	LinkUtil = {
		RegisterLinkHandler = function(kind, fn)
			linkHandlers[kind] = fn
		end,
	},
	LinkProcessorResponse = { Handled = 2 },
	CreateAtlasMarkup = function(atlas, width, height)
		return ("|A:%s:%d:%d|a"):format(atlas, width, height)
	end,
	GRAY_FONT_COLOR = {
		WrapTextInColorCode = function(_, text)
			return "|cff808080" .. text .. "|r"
		end,
	},
	NORMAL_FONT_COLOR = {
		WrapTextInColorCode = function(_, text)
			return "|cffffd200" .. text .. "|r"
		end,
	},
	CreateFrame = function(kind, name, parent, template)
		local widget = Widget(kind, name, parent, template)
		widget.TitleText = Widget("FontString", nil, widget, nil)
		widget.CreateFontString = function()
			return Widget("FontString", nil, widget, nil)
		end
		return widget
	end,
	TweaksForeverCharDB = {},
	Settings = { SOCIAL_CATEGORY_ID = 42 },
	ForeverCore = {
		OpenSettingsPanel = function(category, element)
			opened = { category, element }
		end,
	},
	TIMESTAMPS_LABEL = "Chat Timestamps",
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
	OnSettingChanged = function() end,
	Init = function(fn)
		fn()
	end,
	Active = function(key)
		return db[key] == true
	end,
	Art = {
		Markup = function(atlas, height)
			return ("|A:%s:%d:12|a"):format(atlas, height)
		end,
	},
	EscapeCloses = function(frame)
		env.escaped = frame
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

for _, path in ipairs({
	"Chat/Shared.lua",
	"Chat/ShortNames.lua",
	"Chat/ClassLevels.lua",
	"Chat/Timestamps.lua",
	"Chat/FoldRepeats.lua",
	"Chat/ItemIcons.lua",
	"Chat/Mentions.lua",
	"Chat/WebLinks.lua",
	"Chat/History.lua",
}) do
	setfenv(assert(loadfile(path)), env)("TweaksForever", ns)
end

local function RunTimers()
	local due = timers
	timers = {}
	for _, fn in ipairs(due) do
		fn()
	end
end

-- Handlers registered through ns.On take the event's arguments only, never the event name (Core.lua's event frame
-- calls ns.core.SafeCall(event, fn, ...)).
local function Emit(event, ...)
	for _, fn in ipairs(handlers[event] or {}) do
		fn(...)
	end
end

-- Run every message filter for an event in registration order, threading the arguments the way the client does.
local function Fire(event, frame, ...)
	local args = Pack(...)
	for _, callback in ipairs(filters[event] or {}) do
		local out = Pack(callback(frame, event, Unpack(args)))
		if out[1] == false then
			local nextArgs = { n = out.n - 1 }
			for index = 2, out.n do
				nextArgs[index - 1] = out[index]
			end
			args = nextArgs
		end
	end
	return Unpack(args)
end

-- Every option is off to start with. Each filter leaves the line exactly as it was, class colours are not touched,
-- and history saves nothing.
local untouched = "|Hitem:2589|h[Linen Cloth]|h https://example.com 2. Trade - City Bob"
local before = untouched
for _, event in ipairs({ "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_GUILD" }) do
	local text, _, _, channel =
		Fire(event, docked[1], untouched, "Alice", "", "2. Trade - City", "", "", 0, 2, "Trade", 0, 1)
	assert(text == before, event .. ": no option changes the line while all are off")
	assert(channel == "2. Trade - City", event .. ": the channel is untouched while all are off")
end
assert(#cvarWrites == 0, "class colours are not touched while off")
ns.ChatClassLevels.Sync()
assert(#cvarWrites == 0, "syncing while off changes no class colour")
docked[1]:AddMessage("line", 1, 1, 1)
ns.ChatHistory.Save()
assert(next(env.TweaksForeverCharDB) == nil, "history saves nothing while off")

-- Every option is its own feature, all in the Chat category and off by default. Timestamps is a link row.
local expected = {
	chatShortNames = "Short channel names",
	chatClassLevels = "Class colours and levels",
	chatTimestamps = "Chat timestamps",
	chatFoldRepeats = "Fold repeated messages",
	chatItemIcons = "Item icons in chat",
	chatMentions = "Mention marker",
	chatWebLinks = "Clickable web links",
	chatHistory = "Chat history after a reload",
}
for key, name in pairs(expected) do
	assert(features[key], key .. " is declared")
	assert(features[key].category == "Chat", key .. " is in the Chat category")
	assert(features[key].default == false, key .. " starts off")
	assert(features[key].name == name, key .. " is named")
end
assert(features.chatTimestamps.buttonOnly and features.chatTimestamps.buttonText == "Open", "timestamps is a link row")
assert(features.chatShortNames.conflicts[1].addon == "Prat-3.0", "Prat is named for short names")
assert(features.chatHistory.conflicts[2].addon == "Chattynator", "Chattynator is named for history")

-- Channel names: the number and the zone suffix go, LookingForGroup becomes LFG, and the link target stays.
local short = ns.ChatShortNames
assert(short.Channel("2. Trade - City") == "Trade", "a numbered trade channel keeps its base name")
assert(short.Channel("1. General - Elwynn Forest") == "General", "a zone suffix goes")
assert(short.Channel("4. LookingForGroup") == "LFG", "LookingForGroup is LFG")
assert(short.Channel("Trade") == nil, "a name without a number is left alone")
readable = false
assert(short.Channel("secret") == nil, "a name the client keeps secret is left alone")
readable = true

-- A channel line: the client built its link from arg4, and the queued transform replaces only the link's display
-- text on the stored line. The arguments themselves are never changed, because the client reads arg4 again.
db.chatShortNames = true
local channelFrame = Frame("ChatFrameChannel")
local channelLine = 0
local function Channel(name, index, base, lineID)
	channelLine = channelLine + 1
	local link = "|Hchannel:channel:" .. index .. "|h[" .. name .. "]|h"
	channelFrame:AddMessage(link .. " Alice: hi", 1, 1, 1, 5, 6, 7, "CHAT_MSG_CHANNEL", { [11] = lineID })
	local text, author, _, channel =
		Fire("CHAT_MSG_CHANNEL", channelFrame, "hi", "Alice", "", name, "", "", 0, index, base, 0, lineID)
	assert(text == "hi" and author == "Alice", "the channel line's text and sender are unchanged")
	assert(channel == name, "arg4, which the client reads again, is unchanged")
	assert(
		channelFrame.messages[channelLine].text:find(link, 1, true),
		"the stored line is untouched until the queued transform runs"
	)
	RunTimers()
	return channelFrame.messages[channelLine].text
end
local trade = Channel("2. Trade - City", 2, "Trade", 201)
assert(
	trade:find("|Hchannel:channel:2|h[Trade]|h", 1, true),
	"the Trade link keeps its channel target and shows the short name"
)
assert(not trade:find("2. Trade - City", 1, true), "the number and the zone suffix are gone from the display")
local general = Channel("1. General - Elwynn Forest", 1, "General", 202)
assert(general:find("|Hchannel:channel:1|h[General]|h", 1, true), "the General link shows the short name")
local lfg = Channel("4. LookingForGroup", 4, "LookingForGroup", 203)
assert(lfg:find("|Hchannel:channel:4|h[LFG]|h", 1, true), "the LookingForGroup link shows LFG")

-- The fixed headers come from the client's own format globals; the short form keeps the header's channel link.
env.CHAT_GUILD_GET = "|Hchannel:GUILD|h[Guild]|h %s: "
env.CHAT_RAID_WARNING_GET = "[Raid Warning] %s: "
local shown, replacement = short.Header("GUILD")
assert(shown == "|Hchannel:GUILD|h[Guild]|h" and replacement == "|Hchannel:GUILD|h[G]|h", "guild keeps its link")
local warningShown, warningReplacement = short.Header("RAID_WARNING")
assert(warningShown == "[Raid Warning]" and warningReplacement == "[RW]", "raid warning has no link to keep")
assert(short.Header("SAY") == nil, "a format type not in the short list is left alone")
local fixed = {
	{ "GUILD", "GUILD", "G" },
	{ "OFFICER", "OFFICER", "O" },
	{ "PARTY", "PARTY", "P" },
	{ "PARTY_LEADER", "PARTY", "PL" },
	{ "RAID", "RAID", "R" },
	{ "RAID_LEADER", "RAID", "RL" },
	{ "INSTANCE_CHAT", "INSTANCE_CHAT", "I" },
	{ "INSTANCE_CHAT_LEADER", "INSTANCE_CHAT", "IL" },
}
for _, row in ipairs(fixed) do
	local kind, target, form = row[1], row[2], row[3]
	env["CHAT_" .. kind .. "_GET"] = "|Hchannel:" .. target .. "|h[" .. kind .. "]|h %s: "
	local long, brief = short.Header(kind)
	assert(long == "|Hchannel:" .. target .. "|h[" .. kind .. "]|h", kind .. " keeps its link")
	assert(brief == "|Hchannel:" .. target .. "|h[" .. form .. "]|h", kind .. " takes its short form")
end
env.CHAT_GUILD_GET = "|Hchannel:GUILD|h[Guild]|h %s: "

local headerFrame = Frame("ChatFrame2")
headerFrame:AddMessage("|Hchannel:GUILD|h[Guild]|h Bob: hello", 1, 1, 1, 5, 6, 7, "CHAT_MSG_GUILD", { [11] = 77 })
Fire("CHAT_MSG_GUILD", headerFrame, "hello", "Bob", "", "", "", "", 0, 0, "", 0, 77)
RunTimers()
assert(headerFrame.messages[1].text == "|Hchannel:GUILD|h[G]|h Bob: hello", "the guild header is shortened")
headerFrame:AddMessage("|Hchannel:GUILD|h[Guild]|h Bob: other", 1, 1, 1, 5, 6, 7, "CHAT_MSG_GUILD", { [11] = 78 })
Fire("CHAT_MSG_GUILD", headerFrame, "other", "Bob", "", "", "", "", 0, 0, "", 0, 79)
RunTimers()
assert(headerFrame.messages[2].text:find("[Guild]", 1, true), "a line with another line ID is not touched")

-- Levels: only the client's own sources fill the cache, and the name filter adds the level it knows.
local levels = ns.ChatClassLevels
db.chatClassLevels = true
levels.Refresh()
assert(levels.Level("Bob") == 60, "the player's own unit level is known")
assert(levels.Level("Alice") == 42, "the target's unit level is known")
assert(levels.Level("Guildie") == 30, "the guild roster is read")
assert(levels.Level("Offline") == nil, "an offline friend's stale level is not used")
assert(levels.Level("Friend") == 25, "a connected friend's level is read")
assert(levels.Level("Who") == 18, "/who results are read")
assert(levels.Level("Nobody") == nil, "a name the client never gave a level for has none")
assert(levels.Decorate("Bob", 60):find("60", 1, true), "the level follows the name")
local decorated = nameFilters[1]("CHAT_MSG_SAY", "Bob", "hello", "Bob")
assert(type(decorated) == "string" and decorated:find("60", 1, true), "the sender's name gets its level")
assert(nameFilters[1]("CHAT_MSG_SAY", "Nobody", "hello", "Nobody") == nil, "an unknown sender is not guessed")
readable = false
assert(nameFilters[1]("CHAT_MSG_SAY", "secret", "hello", "secret") == nil, "a secret sender is not decorated")
readable = true

-- Each event reads only its own source: a mouseover does not walk the guild roster for its level.
local guildReads = 0
env.GetGuildRosterInfo = function(index)
	guildReads = guildReads + 1
	local member = guild[index]
	return member and member[1], "Rank", 0, member and member[2]
end
units.mouseover = { name = "Hover", level = 12 }
Emit("UPDATE_MOUSEOVER_UNIT", "mouseover")
assert(guildReads == 0, "a mouseover does not read the guild roster")
assert(levels.Level("Hover") == 12, "the mouseover unit's level is read")
units.target = { name = "Alice", level = 43 }
Emit("PLAYER_TARGET_CHANGED")
assert(guildReads == 0, "a target change does not read the guild roster either")
assert(levels.Level("Alice") == 43, "the target's level is read")

-- Class colours: the client's one override CVar, whose old value lives in the account saved variables. A /reload
-- while the option is on must never record this addon's own "0" as the player's choice.
cvars.chatClassColorOverride = "1"
db.chatClassColorSaved = nil
db.chatClassLevels = true
levels.Sync()
assert(cvars.chatClassColorOverride == "0", "class colours are forced on while the option is on")
assert(db.chatClassColorSaved == "1", "the player's own value is kept")

-- A /reload: fresh module state, the same saved variables.
setfenv(assert(loadfile("Chat/ClassLevels.lua")), env)("TweaksForever", ns)
levels = ns.ChatClassLevels
levels.Sync()
assert(cvars.chatClassColorOverride == "0", "a reload keeps class colours on")
assert(db.chatClassColorSaved == "1", "our own 0 never replaces the player's value")

db.chatClassLevels = false
levels.Sync()
assert(cvars.chatClassColorOverride == "1", "the player's own value comes back")
assert(db.chatClassColorSaved == nil, "the saved value is cleared after restoring")

-- An unset CVar is stored and put back exactly as it was.
cvars.chatClassColorOverride = ""
db.chatClassLevels = true
levels.Sync()
assert(db.chatClassColorSaved == "", "an unset CVar is kept as it was")
assert(cvars.chatClassColorOverride == "0", "class colours are forced on from unset too")
db.chatClassLevels = false
levels.Sync()
assert(cvars.chatClassColorOverride == "", "an unset CVar is restored as unset")
assert(db.chatClassColorSaved == nil, "nothing is left saved after restoring")

-- Item icons: only item links, only when the client knows the item.
local icons = ns.ChatItemIcons
db.chatItemIcons = true
local withIcon = icons.Add("|Hitem:2589|h[Linen Cloth]|h")
assert(
	withIcon:find("|TInterface\\Icons\\INV_Misc_Cloth_01:0:0:0:0:64:64:5:59:5:59|t ", 1, true),
	"the item icon is inserted"
)
assert(withIcon:find("|Hitem:2589|h[Linen Cloth]|h", 1, true), "the item link survives")
assert(icons.Add("|Hquest:1|h[A Quest]|h") == "|Hquest:1|h[A Quest]|h", "a quest link is left alone")
assert(icons.Add("|Hspell:133|h[Fireball]|h") == "|Hspell:133|h[Fireball]|h", "a spell link is left alone")
assert(icons.Add("|Hitem:999999|h[Unknown]|h") == "|Hitem:999999|h[Unknown]|h", "an unknown item gets no icon")

-- Folding: same sender and text within two minutes, exact only, by the client's line ID.
local fold = ns.ChatFoldRepeats
assert(fold.Fresh(100, 220), "exactly two minutes is still within the window")
assert(not fold.Fresh(100, 221), "after two minutes is a new message")
db.chatFoldRepeats = true
local foldFrame = Frame("ChatFrame3")
local firstLine = Pack(Fire("CHAT_MSG_SAY", foldFrame, "hello", "Bob", "", "", "", "", 0, 0, "", 0, 1))
assert(firstLine[1] == "hello", "the first line is unchanged")
foldFrame:AddMessage(firstLine[1], 1, 1, 1, 1, 1, 1, "CHAT_MSG_SAY", { [11] = 1 })
local args = Pack(Fire("CHAT_MSG_SAY", foldFrame, "hello", "Bob", "", "", "", "", 0, 0, "", 0, 2))
assert(args[1]:find("x2", 1, true), "the second line carries x2")
foldFrame:AddMessage(args[1], 1, 1, 1, 1, 1, 1, "CHAT_MSG_SAY", { [11] = 2 })
assert(
	#foldFrame.messages == 1 and foldFrame.messages[1].text:find("x2", 1, true),
	"the earlier line was removed by its ID"
)
args = Pack(Fire("CHAT_MSG_SAY", foldFrame, "hello", "Bob", "", "", "", "", 0, 0, "", 0, 3))
assert(args[1]:find("x3", 1, true), "the third line counts x3")
foldFrame:AddMessage(args[1], 1, 1, 1, 1, 1, 1, "CHAT_MSG_SAY", { [11] = 3 })
assert(#foldFrame.messages == 1, "only the newest line of the run remains")

now = now + 121
args = Pack(Fire("CHAT_MSG_SAY", foldFrame, "hello", "Bob", "", "", "", "", 0, 0, "", 0, 4))
assert(args[1] == "hello", "after the window the text is unchanged")
foldFrame:AddMessage(args[1], 1, 1, 1, 1, 1, 1, "CHAT_MSG_SAY", { [11] = 4 })
assert(#foldFrame.messages == 2, "after the window the line is added separately")

args = Pack(Fire("CHAT_MSG_SAY", foldFrame, "different", "Bob", "", "", "", "", 0, 0, "", 0, 5))
assert(args[1] == "different", "different text is not folded")
foldFrame:AddMessage(args[1], 1, 1, 1, 1, 1, 1, "CHAT_MSG_SAY", { [11] = 5 })
assert(#foldFrame.messages == 3, "different text adds a line")

args = Pack(Fire("CHAT_MSG_SAY", foldFrame, "hello", "Alice", "", "", "", "", 0, 0, "", 0, 6))
assert(args[1] == "hello", "a different sender is not folded")

local channelA = Pack(Fire("CHAT_MSG_CHANNEL", foldFrame, "same", "Bob", "", "5. Trade", "", "", 0, 5, "Trade", 0, 7))
foldFrame:AddMessage(channelA[1], 1, 1, 1, 1, 1, 1, "CHAT_MSG_CHANNEL", { [11] = 7 })
local channelB = Pack(Fire("CHAT_MSG_CHANNEL", foldFrame, "same", "Bob", "", "6. Other", "", "", 0, 6, "Other", 0, 8))
assert(channelB[1] == "same", "the same text in another channel is not folded")

readable = false
args = Pack(Fire("CHAT_MSG_SAY", foldFrame, "secret", "Bob", "", "", "", "", 0, 0, "", 0, 9))
assert(args[1] == "secret", "a secret line is never folded")
args = Pack(Fire("CHAT_MSG_SAY", foldFrame, "hello", "secret", "", "", "", "", 0, 0, "", 0, 10))
assert(args[1] == "hello", "a secret sender is never folded")
readable = true

-- The table is pruned once it grows past its limit; the current frame's own table survives that sweep, so the next
-- repeat still counts on it.
local pruneFrame = Frame("ChatFramePrune")
local pruneLine = 1000
local function PruneLine(text)
	pruneLine = pruneLine + 1
	local out = Pack(Fire("CHAT_MSG_SAY", pruneFrame, text, "Carol", "", "", "", "", 0, 0, "", 0, pruneLine))
	pruneFrame:AddMessage(out[1], 1, 1, 1, 1, 1, 1, "CHAT_MSG_SAY", { [11] = pruneLine })
end
for index = 1, 520 do
	PruneLine("filler " .. index)
end
args = Pack(Fire("CHAT_MSG_SAY", pruneFrame, "filler 520", "Carol", "", "", "", "", 0, 0, "", 0, 1600))
assert(args[1]:find("x2", 1, true), "a repeat still folds after the table has been pruned")

-- Mentions: the player's own name as a whole word, from another player, once per word.
local mentions = ns.ChatMentions
local found = mentions.Found("hey Bob, Bobbie and bob", "Bob")
assert(#found == 2, "Bob and bob match, Bobbie does not")
assert(found[1][1] == 5 and found[1][2] == 7, "the first whole word's bytes")
local marked = mentions.Mark("hey Bob", "Bob")
assert(marked:find("communities-icon-chat", 1, true), "the mention marker is at the line start")
assert(marked:find("|cffffd200Bob|r", 1, true), "the name takes NORMAL_FONT_COLOR")
assert(mentions.Mark("hey Bobbie", "Bob") == nil, "a longer word is not a mention")

-- A hyperlink is never touched. Its display text and its payload are both escape sequences; the same name in the
-- plain text beside it is still a mention.
local item = "|Hitem:2589|h[Bob's Linen Cloth]|h"
assert(mentions.Mark(item, "Bob") == nil, "a name in an item link's display text is not marked")
local payload = "|Hitem:999:Bob|h[Plain Linen]|h"
assert(mentions.Mark(payload, "Bob") == nil, "a name in a link's payload is not marked")
local beside = mentions.Mark("Bob " .. payload, "Bob")
assert(beside:find("|cffffd200Bob|r", 1, true), "the same name in plain text beside the link is marked")
assert(beside:find(payload, 1, true), "the link beside it is unchanged")
db.chatMentions = true
args = Pack(Fire("CHAT_MSG_SAY", docked[1], "hey Bob", "Alice", "", "", "", "", 0, 0, "", 11))
assert(args[1]:find("communities-icon-chat", 1, true), "another player's line is marked")
args = Pack(Fire("CHAT_MSG_SAY", docked[1], "hey Bob", "Bob", "", "", "", "", 0, 0, "", 12))
assert(args[1] == "hey Bob", "your own line is not marked")
readable = false
args = Pack(Fire("CHAT_MSG_SAY", docked[1], "secret", "Alice", "", "", "", "", 0, 0, "", 13))
assert(args[1] == "secret", "a secret line is never read for a mention")
readable = true

-- Web links: http and https become a custom link, a click copies the address, and nothing links a plain word.
local links = ns.ChatWebLinks
local urls = links.URLs("see https://example.com. and http://a.b/c now")
assert(#urls == 2 and urls[1][1] == "https://example.com", "the trailing full stop is not part of the address")
local linked = links.Linkify("see https://example.com now")
assert(linked:find("|Htweaksurl:https://example.com|h[https://example.com]|h", 1, true), "the address becomes a link")
assert(links.Linkify("no address here") == "no address here", "plain text is untouched")
db.chatWebLinks = true
args = Pack(Fire("CHAT_MSG_SAY", docked[1], "see https://example.com", "Alice", "", "", "", "", 0, 0, "", 14))
assert(args[1]:find("tweaksurl", 1, true), "the chat filter links the address")
local copied
local originalCopy = links.Copy
links.Copy = function(url)
	copied = url
end
assert(
	linkHandlers.tweaksurl("tweaksurl:https://example.com", "text", { options = "https://example.com" }) == 2,
	"the link is handled"
)
assert(copied == "https://example.com", "the click copies the address")
links.Copy = originalCopy
links.Copy("https://example.com")
local box, editBox
for _, widget in ipairs(madeFrames) do
	if widget.name == "TweaksForeverChatURLCopy" then
		box = widget
	end
	if widget.kind == "EditBox" then
		editBox = widget
	end
end
assert(editBox and editBox.text == "https://example.com", "the copy box shows the address")
assert(editBox.highlighted and editBox.focused, "the address is selected and focused")
assert(box and box.shown and env.escaped == box, "the box is shown and Escape closes it")

-- History: 200 lines kept, saved lines skipped when secret, replayed oldest first above the divider.
local history = ns.ChatHistory
local many = {}
for lineIndex = 1, 250 do
	many[lineIndex] = { text = tostring(lineIndex), r = 1, g = 1, b = 1, time = lineIndex }
end
local kept = history.Keep(many)
assert(#kept == 200 and kept[1].text == "51" and kept[200].text == "250", "the newest 200 lines are kept")
local saveFrame = Frame("ChatFrame4")
saveFrame:AddMessage("first", 0.1, 0.2, 0.3, 1, 2, 3, "CHAT_MSG_SAY", { [1] = "first", [2] = "Alice", [11] = 21 })
saveFrame:AddMessage("second", 0.4, 0.5, 0.6, 1, 2, 3, "CHAT_MSG_SAY", { [1] = "second", [2] = "Alice", [11] = 22 })
saveFrame:AddMessage("secret", 1, 1, 1, 1, 2, 3, "CHAT_MSG_SAY", { [1] = "secret", [2] = "Alice", [11] = 23 })
readable = false
env.canaccessvalue = function(value)
	return value ~= "secret"
end
now = 500
db.chatHistory = true
docked = { saveFrame }
Fire("CHAT_MSG_SAY", saveFrame, "first", "Alice", "", "", "", "", 0, 0, "", 0, 21)
Fire("CHAT_MSG_SAY", saveFrame, "second", "Alice", "", "", "", "", 0, 0, "", 0, 22)
history.Save()
local saved = env.TweaksForeverCharDB.chatHistory.ChatFrame4
assert(#saved == 2, "the secret line is not saved")
assert(saved[1].text == "first" and saved[2].text == "second", "saved lines keep their order")
assert(saved[1].r == 0.1 and saved[1].g == 0.2 and saved[1].b == 0.3, "saved lines keep their colour")
assert(saved[1].time == 500 and saved[2].time == 500, "saved lines keep the time they arrived")
db.chatHistory = false
history.Save()
env.TweaksForeverCharDB.chatHistory = nil

-- Replay once, above everything the client already printed: the oldest saved line at the top, then the newest
-- saved line, then the divider, then the line that arrived during login.
local replayFrame = Frame("ChatFrame4")
replayFrame:AddMessage("login", 0.9, 0.9, 0.9, 5, 6, 7, "CHAT_MSG_SYSTEM", { [11] = 90 })
docked = { replayFrame }
env.TweaksForeverCharDB.chatHistory = {
	ChatFrame4 = {
		{ text = "older", r = 1, g = 0, b = 0, time = 1 },
		{ text = "newer", r = 0, g = 1, b = 0, time = 2 },
	},
}
db.chatHistory = true
Emit("PLAYER_ENTERING_WORLD")
RunTimers()
assert(#replayFrame.messages == 4, "both saved lines, the divider and the login line are there")
assert(
	replayFrame.messages[1].text == "older" and replayFrame.messages[2].text == "newer",
	"saved lines replay above the divider, oldest first"
)
assert(
	replayFrame.messages[3].text:find("communities-chat-date-line", 1, true),
	"the divider uses the client's date line"
)
assert(replayFrame.messages[3].text:find("Before your /reload", 1, true), "the divider says what it is")
assert(replayFrame.messages[4].text == "login", "the line from login stays below the divider")
history.Replay()
assert(#replayFrame.messages == 4, "a second world entry does not replay again")

-- Timestamps: the link row opens the game's own Chat Timestamps setting.
db.chatTimestamps = true
features.chatTimestamps.button()
assert(opened and opened[1] == 42 and opened[2] == "Chat Timestamps", "the row opens the game's own setting")

-- History off: a saved history is cleared and nothing is replayed, even on the first world entry of a fresh load.
db.chatHistory = false
local offFrame = Frame("ChatFrame4")
docked = { offFrame }
env.TweaksForeverCharDB.chatHistory = { ChatFrame4 = { { text = "older", r = 1, g = 0, b = 0, time = 1 } } }
setfenv(assert(loadfile("Chat/History.lua")), env)("TweaksForever", ns)
ns.ChatHistory.Replay()
assert(#offFrame.messages == 0, "history off replays nothing")
assert(env.TweaksForeverCharDB.chatHistory == nil, "history off clears the saved lines")

-- Before PLAYER_LOGIN the client fires ADDON_LOADED for every addon that loads after this one, while ns.db is still
-- nil and ns.Init holds its startup functions (Core/Core.lua). Class colours read no saved setting then; login
-- applies the option, and an addon loading after login syncs it again.
do
	local early, startup, earlyHandlers = {}, {}, {}
	for key, value in pairs(ns) do
		early[key] = value
	end
	early.db = nil
	early.Init = function(fn)
		startup[#startup + 1] = fn
	end
	early.On = function(event, fn)
		earlyHandlers[event] = earlyHandlers[event] or {}
		earlyHandlers[event][#earlyHandlers[event] + 1] = fn
	end
	early.Active = function(key)
		return early.db ~= nil and early.db[key] == true
	end
	local function AddonLoaded(name)
		for _, fn in ipairs(earlyHandlers.ADDON_LOADED or {}) do
			fn(name)
		end
	end
	cvars.chatClassColorOverride = "1"
	cvarWrites = {}
	setfenv(assert(loadfile("Chat/ClassLevels.lua")), env)("TweaksForever", early)
	AddonLoaded("Questie")
	AddonLoaded("WeakAuras")
	assert(#cvarWrites == 0, "an addon loading before login changes no class colour")

	db.chatClassLevels, db.chatClassColorSaved = true, nil
	early.db = db
	for _, fn in ipairs(startup) do
		fn()
	end
	assert(cvars.chatClassColorOverride == "0", "login applies class colours")
	assert(db.chatClassColorSaved == "1", "login keeps the player's own value")
	cvars.chatClassColorOverride = "1"
	AddonLoaded("Blizzard_TrainerUI")
	assert(cvars.chatClassColorOverride == "0", "an addon loading after login syncs class colours again")
end

print("chat: ok")
