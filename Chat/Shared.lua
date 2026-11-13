---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

-- Shared pieces for the Chat category: the events each option reads, the client's own message-filter seam, and the
-- docked frames it changes. A message event filter sees the client's arguments before the chat frame formats the
-- line, so every option changes the line at the producer, never the rendered text.
--
-- A filter returns nothing to leave the line alone, or false and every argument to replace them. Returning nothing
-- also keeps the client's other filters on the line.

---@class TFChat
---@field TEXT_EVENTS string[] chat events whose text an option may rewrite
---@field FOLD_EVENTS string[] player chat that can repeat
local Chat = {}
ns.Chat = Chat

-- Every event whose first argument is chat text a player wrote or the game showed. Achievements and loot carry a
-- format token, not a sentence, so they are left out.
Chat.TEXT_EVENTS = {
	"CHAT_MSG_SAY",
	"CHAT_MSG_YELL",
	"CHAT_MSG_EMOTE",
	"CHAT_MSG_TEXT_EMOTE",
	"CHAT_MSG_WHISPER",
	"CHAT_MSG_WHISPER_INFORM",
	"CHAT_MSG_BN_WHISPER",
	"CHAT_MSG_BN_WHISPER_INFORM",
	"CHAT_MSG_PARTY",
	"CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID",
	"CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_GUILD",
	"CHAT_MSG_OFFICER",
	"CHAT_MSG_INSTANCE_CHAT",
	"CHAT_MSG_INSTANCE_CHAT_LEADER",
	"CHAT_MSG_CHANNEL",
	"CHAT_MSG_COMMUNITIES_CHANNEL",
	"CHAT_MSG_GUILD_DISCORD",
	"CHAT_MSG_MONSTER_SAY",
	"CHAT_MSG_MONSTER_YELL",
	"CHAT_MSG_MONSTER_WHISPER",
	"CHAT_MSG_MONSTER_EMOTE",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"CHAT_MSG_RAID_BOSS_WHISPER",
}

-- Player chat that can repeat: the same sender, text and event (and channel) within the fold window.
Chat.FOLD_EVENTS = {
	"CHAT_MSG_SAY",
	"CHAT_MSG_YELL",
	"CHAT_MSG_PARTY",
	"CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID",
	"CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_GUILD",
	"CHAT_MSG_OFFICER",
	"CHAT_MSG_INSTANCE_CHAT",
	"CHAT_MSG_INSTANCE_CHAT_LEADER",
	"CHAT_MSG_CHANNEL",
}

-- A name as the client compares it: without its realm, when the client can shorten it.
---@param name any
---@return string?
function Chat.ShortName(name)
	local value = ns.Readable(name)
	if type(value) ~= "string" or value == "" then
		return nil
	end
	if Ambiguate then
		local ok, short = pcall(Ambiguate, value, "short")
		if ok and type(short) == "string" and short ~= "" then
			return short
		end
	end
	return value
end

-- The player's own name, when the client lets this code read it.
---@return string?
function Chat.Player()
	return Chat.ShortName((UnitName("player")))
end

-- The game's docked chat frames, in dock order. A frame that is not in the dock (a popped-out whisper window) is
-- not one this addon keeps history for.
---@return ScrollingMessageFrame[]
function Chat.Docked()
	local frames = {}
	if FCFDock_GetChatFrames and GENERAL_CHAT_DOCK then
		local ok, docked = pcall(FCFDock_GetChatFrames, GENERAL_CHAT_DOCK)
		if ok and type(docked) == "table" then
			for _, frame in ipairs(docked) do
				frames[#frames + 1] = frame
			end
		end
	end
	if #frames == 0 and CHAT_FRAMES then
		for _, name in ipairs(CHAT_FRAMES) do
			if _G[name] then
				frames[#frames + 1] = _G[name]
			end
		end
	end
	return frames
end

---@param frame ScrollingMessageFrame?
---@return string?
function Chat.Name(frame)
	if not (frame and frame.GetName) then
		return nil
	end
	return frame:GetName()
end

-- The two events the client delivers to a whisper window: one partner, one line at a time.
Chat.WHISPER_EVENTS = { "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER" }

-- Every chat frame the client holds now, docked or temporary, from its own list of names.
---@return ScrollingMessageFrame[]
function Chat.Frames()
	local frames = {}
	if CHAT_FRAMES then
		for _, name in ipairs(CHAT_FRAMES) do
			local frame = _G[name]
			if frame then
				frames[#frames + 1] = frame
			end
		end
	end
	return frames
end

-- A chat frame's tab button, the client's own name for it.
---@param frame ScrollingMessageFrame?
---@return Button?
function Chat.Tab(frame)
	local name = Chat.Name(frame)
	return name and _G[name .. "Tab"] or nil
end

-- A temporary frame the client opened for one whisper partner. Its chatType and chatTarget are the client's own
-- fields, set by FCF_SetTemporaryWindowType.
---@param frame ScrollingMessageFrame?
---@return boolean
function Chat.IsWhisperWindow(frame)
	return frame ~= nil
		and frame.isTemporary == true
		and (frame.chatType == "WHISPER" or frame.chatType == "BN_WHISPER")
end

-- The tab the dock shows now. A window that is not this one is unread for the tab counts.
---@return ScrollingMessageFrame?
function Chat.SelectedWindow()
	if not (FCFDock_GetSelectedWindow and GENERAL_CHAT_DOCK) then
		return nil
	end
	local ok, frame = pcall(FCFDock_GetSelectedWindow, GENERAL_CHAT_DOCK)
	if ok and type(frame) == "table" then
		return frame
	end
end

-- Callbacks that decorate a whisper window, run as the client sets one up.
---@type (fun(frame: ScrollingMessageFrame, target: string): any)[]
local windowCallbacks = {}
local windowHooked = false

-- Run `fn(frame, target)` when the client sets up a whisper window, before its first line. FCF_SetTemporaryWindowType
-- is hooked, never replaced, and it is the client's own one call that clears an old window and names the new
-- partner, so the callback runs once per window with an empty frame.
---@param fn fun(frame: ScrollingMessageFrame, target: string)
function Chat.OnWhisperWindow(fn)
	windowCallbacks[#windowCallbacks + 1] = fn
	if windowHooked or type(FCF_SetTemporaryWindowType) ~= "function" then
		return
	end
	windowHooked = true
	hooksecurefunc("FCF_SetTemporaryWindowType", function(frame, chatType, target)
		if chatType ~= "WHISPER" and chatType ~= "BN_WHISPER" then
			return
		end
		for _, callback in ipairs(windowCallbacks) do
			ns.core.SafeCall("whisper window", callback, frame, target)
		end
	end)
end

-- Registrations made before Blizzard's chat code loads, replayed as the world loads.
---@type { events?: string[], fn?: function, name?: function }[]
local waiting = {}

-- Register `fn` for each event through the client's own message event filter registry. The client wraps the
-- callback so a message whose text the client keeps secret never reaches it. If Blizzard's chat code is not loaded
-- yet, the registration waits for the world to load.
---@param events string[]
---@param fn function
function Chat.Filter(events, fn)
	if ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter then
		for _, event in ipairs(events) do
			ChatFrameUtil.AddMessageEventFilter(event, fn)
		end
		return
	end
	waiting[#waiting + 1] = { events = events, fn = fn }
end

-- Register a callback that decorates the sender's name. The client wraps it and skips a secret name.
---@param fn function
function Chat.NameFilter(fn)
	if ChatFrameUtil and ChatFrameUtil.AddSenderNameFilter then
		ChatFrameUtil.AddSenderNameFilter(fn)
		return
	end
	waiting[#waiting + 1] = { name = fn }
end

-- Blizzard's chat code loads with the interface, but a build that loads it on demand reaches login after this
-- addon. Anything queued is registered as the world loads, once.
local function RegisterWaiting()
	if not ChatFrameUtil then
		return
	end
	local queued = waiting
	waiting = {}
	for _, item in ipairs(queued) do
		if item.name and ChatFrameUtil.AddSenderNameFilter then
			ChatFrameUtil.AddSenderNameFilter(item.name)
		elseif item.events and ChatFrameUtil.AddMessageEventFilter then
			for _, event in ipairs(item.events) do
				ChatFrameUtil.AddMessageEventFilter(event, item.fn)
			end
		end
	end
end

ns.On("PLAYER_ENTERING_WORLD", RegisterWaiting)

-- Grey, the client's own colour for a secondary value.
---@param text string
---@return string
function Chat.Grey(text)
	if GRAY_FONT_COLOR then
		return GRAY_FONT_COLOR:WrapTextInColorCode(text)
	end
	return "|cff808080" .. text .. "|r"
end
