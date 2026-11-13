---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

local L = ns.L
local KEY = "chatPlayerCard"
local Chat = ns.Chat
local Record = ns.ChatPlayerRecord

ns.Feature({
	key = KEY,
	category = "Chat",
	name = "Player card on hover",
	tooltip = "Hovering a player's name in chat shows their level, race and class when the game knows them, their "
		.. "guild and zone when your guild roster, friends list or last /who gives them, when you last grouped with "
		.. "them, and how many whispers you have exchanged. Nothing is sent to anyone.",
	default = false,
})

---@class TFChatPlayerCard
local Model = {}
ns.ChatPlayerCard = Model

-- The card the mouse is over, so leaving a link hides only a card this addon showed.
local showing = false

-- The client's own chat link for a player: player:Name:lineID:chatType:chatTarget
-- (Blizzard_SharedXML/LinkUtil.lua, GetPlayerLink). Other link types, Battle.net names included, are not this card.
---@param link any
---@return string? name
---@return integer lineID
local function Link(link)
	local text = ns.Readable(link)
	if type(text) ~= "string" then
		return nil, 0
	end
	local name, lineID = text:match("^player:([^:]+):(%d+)")
	if not name then
		name = text:match("^player:([^:]+)$")
		lineID = "0"
	end
	return Chat.ShortName(name), tonumber(lineID) or 0
end

-- The event arguments the client stored with the line that carries a link, keyed by the line's own ID. The client
-- packs them at AddMessage's ninth argument (ChatFrameOverrides.lua, the message event handler).
---@param frame ScrollingMessageFrame
---@param lineID integer
---@return table?
local function Line(frame, lineID)
	if lineID <= 0 or not (frame.GetNumMessages and frame.GetMessageInfo) then
		return nil
	end
	for index = frame:GetNumMessages(), 1, -1 do
		local _, _, _, _, _, _, _, _, eventArgs = frame:GetMessageInfo(index)
		if type(eventArgs) == "table" and eventArgs[11] == lineID then
			return eventArgs
		end
	end
end

-- Level, race and class. The GUID comes from the line's sender, so it is used only when the link names that same
-- sender; a link to someone else on the line gets no identity rather than the sender's. The level comes from the
-- addon's cache of levels the client stated exactly (Chat/ClassLevels.lua), never from a guess.
---@param name string
---@param eventArgs table?
---@return integer? level
---@return string? race
---@return string? class
---@return string? classFile
local function Identity(name, eventArgs)
	local guid = type(eventArgs) == "table" and ns.Readable(eventArgs[12]) or nil
	local sender = type(eventArgs) == "table" and Chat.ShortName(ns.Readable(eventArgs[2])) or nil
	if type(guid) ~= "string" or guid == "" or sender ~= name then
		return nil
	end
	local localizedClass, englishClass, localizedRace = GetPlayerInfoByGUID(guid)
	localizedClass = ns.Readable(localizedClass)
	englishClass = ns.Readable(englishClass)
	localizedRace = ns.Readable(localizedRace)
	if type(localizedClass) ~= "string" or localizedClass == "" then
		return nil
	end
	local level = ns.ChatClassLevels and ns.ChatClassLevels.Level(name)
	return level, localizedRace, localizedClass, englishClass
end

-- An empty place from one of the client's lists means the client does not know it, so it is left out.
---@param value any
---@return string?
local function Stated(value)
	local text = ns.Readable(value)
	if type(text) ~= "string" or text == "" or text == "nil" or text == "0" then
		return nil
	end
	return text
end

-- Guild and zone from the three lists that state them: your guild roster, the friends list, the last /who.
---@param name string
---@return string? guild
---@return string? zone
local function Place(name)
	local guild, zone
	if IsInGuild and IsInGuild() then
		local guildName = GetGuildInfo and GetGuildInfo("player")
		for index = 1, GetNumGuildMembers and GetNumGuildMembers() or 0 do
			local member, _, _, _, _, memberZone, _, _, online = GetGuildRosterInfo(index)
			if Chat.ShortName(member) == name then
				guild = Stated(guildName)
				-- A roster entry keeps the zone it was last in, which is stale for someone offline.
				if online then
					zone = Stated(memberZone)
				end
				break
			end
		end
	end
	if not zone and C_FriendList and C_FriendList.GetFriendInfo then
		local info = C_FriendList.GetFriendInfo(name)
		if info and info.connected then
			zone = Stated(info.area)
		end
	end
	if (not guild or not zone) and C_FriendList and C_FriendList.GetNumWhoResults and C_FriendList.GetWhoInfo then
		for index = 1, C_FriendList.GetNumWhoResults() do
			local info = C_FriendList.GetWhoInfo(index)
			if info and Chat.ShortName(info.fullName) == name then
				guild = guild or Stated(info.fullGuildName)
				zone = zone or Stated(info.area)
				break
			end
		end
	end
	return guild, zone
end

-- Every line of the card, in reading order, built only from values the client or this addon's record states.
-- Answers the lines and the English class the title is coloured by.
---@param name string
---@param eventArgs table?
---@return string[] lines
---@return string? classFile
function Model.Lines(name, eventArgs)
	local lines = {}
	local level, race, class, classFile = Identity(name, eventArgs)
	if level and race and class then
		lines[#lines + 1] = L["Level %d %s %s"]:format(level, race, class)
	elseif race and class then
		lines[#lines + 1] = L["%s %s"]:format(race, class)
	elseif level and class then
		lines[#lines + 1] = L["Level %d %s"]:format(level, class)
	elseif level then
		lines[#lines + 1] = L["Level %d"]:format(level)
	elseif race then
		lines[#lines + 1] = race
	elseif class then
		lines[#lines + 1] = class
	end
	local guild, zone = Place(name)
	if guild then
		lines[#lines + 1] = L["Guild: %s"]:format(guild)
	end
	if zone then
		lines[#lines + 1] = L["Zone: %s"]:format(zone)
	end
	local record = Record.Get(name)
	if record and record.time then
		local ago = Record.Ago(record.time)
		if ago then
			if record.zone then
				lines[#lines + 1] = L["Last grouped %s ago in %s"]:format(ago, record.zone)
			else
				lines[#lines + 1] = L["Last grouped %s ago"]:format(ago)
			end
		end
	end
	-- A count of zero says nothing, so it is left out rather than claiming a number for a player never whispered.
	if record and (record.whispers or 0) > 0 then
		lines[#lines + 1] = L["Whispers: %d"]:format(record.whispers)
	end
	return lines, classFile
end

-- Show the card over the chat frame, with the name as its title in the class colour when the client gave the class.
---@param frame ScrollingMessageFrame
---@param name string
---@param eventArgs table?
function Model.Show(frame, name, eventArgs)
	if not ns.Usable(GameTooltip) then
		return
	end
	local lines, classFile = Model.Lines(name, eventArgs)
	local colour = classFile and RAID_CLASS_COLORS[classFile]
	GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
	if colour then
		local r, g, b = colour:GetRGB()
		GameTooltip:SetText(name, r, g, b)
	else
		GameTooltip:SetText(name)
	end
	for _, line in ipairs(lines) do
		GameTooltip:AddLine(line, 1, 1, 1, true)
	end
	GameTooltip:Show()
	showing = true
end

-- Hide only a card this addon showed, so another addon's tooltip is left alone.
function Model.Hide()
	if showing and ns.Usable(GameTooltip) then
		GameTooltip:Hide()
	end
	showing = false
end

---@param frame ScrollingMessageFrame
---@param link any
function Model.Enter(frame, link)
	if not ns.Active(KEY) then
		return
	end
	local name, lineID = Link(link)
	if not name then
		return
	end
	ns.core.SafeCall("player card", Model.Show, frame, name, Line(frame, lineID))
end

-- [frame] = true once its hyperlink scripts are hooked.
---@type table<ScrollingMessageFrame, boolean>
local hooked = setmetatable({}, { __mode = "k" })

-- Hook a chat frame's own hyperlink scripts once. The client's ChatFrameMixin:OnHyperlinkEnter sets the frame's
-- script, so the hook runs after it and never replaces it. Frames the client creates later are hooked as it sets a
-- whisper window up.
---@param frame ScrollingMessageFrame
function Model.Hook(frame)
	if not (frame and frame.HookScript and not hooked[frame]) then
		return
	end
	hooked[frame] = true
	frame:HookScript("OnHyperlinkEnter", function(self, link)
		Model.Enter(self, link)
	end)
	frame:HookScript("OnHyperlinkLeave", function()
		Model.Hide()
	end)
end

-- One whisper, received or sent, is one whisper between this character and the other character. The event's first
-- argument is the sender on a received whisper and the recipient on a sent one (Core.lua calls a handler with the
-- event's arguments only, not the event name). Battle.net whispers are keyed by a Battle.net name, which no player:
-- link names, so they are not counted here.
local function Whisper(_, name)
	if not ns.Active(KEY) then
		return
	end
	ns.core.SafeCall("whisper count", Record.Whispered, name)
end

ns.On("CHAT_MSG_WHISPER", Whisper)
ns.On("CHAT_MSG_WHISPER_INFORM", Whisper)

ns.OnSettingChanged(KEY, function()
	if not ns.Active(KEY) then
		Model.Hide()
	end
end)

ns.Init(function()
	for _, frame in ipairs(Chat.Frames()) do
		Model.Hook(frame)
	end
	Chat.OnWhisperWindow(function(frame)
		Model.Hook(frame)
	end)
end)
