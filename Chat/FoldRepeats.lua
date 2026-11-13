---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

local KEY = "chatFoldRepeats"
local Chat = ns.Chat

ns.Feature({
	key = KEY,
	category = "Chat",
	name = "Fold repeated messages",
	tooltip = "When the same player posts the same text in the same chat within two minutes, the earlier line is "
		.. "removed and the new line ends with a grey count, such as x3. Only an exact match on the sender and the "
		.. "whole text, never a fuzzy guess.",
	default = false,
	conflicts = { { addon = "Prat-3.0" } },
})

---@class TFChatFoldRepeats
local Model = {}
ns.ChatFoldRepeats = Model

-- Two minutes is long enough for a repeated raid warning or trade advertisement and short enough that a later
-- repeat reads as a new message. The client's own five-minute chat history keeps the lines this compares.
local WINDOW = 120
-- At most this many live keys are kept. An entry past the window is dropped as the next messages arrive, so the
-- table stays about the size of a busy screen rather than the whole session.
local KEEP = 500

---@class TFChatFoldEntry
---@field at number
---@field lineID any
---@field count integer

-- [frame] = { [key] = entry }. Two chat windows each show and fold their own copy of a line.
---@type table<ScrollingMessageFrame, table<string, TFChatFoldEntry>>
local recent = {}
local keys = 0

-- A line's identity: the sender, the exact text, the event, and for a numbered channel the channel itself. A
-- secret sender or text answers nil, so that line is never folded.
---@param event string
---@param text any
---@param sender any
---@param channelID any
---@param channelName any
---@return string?
function Model.Key(event, text, sender, channelID, channelName)
	local body = ns.Readable(text)
	local author = Chat.ShortName(sender)
	if not body or not author then
		return nil
	end
	local channel = event
	if event == "CHAT_MSG_CHANNEL" then
		local id = ns.Readable(channelID) or ns.Readable(channelName)
		if not id then
			return nil
		end
		channel = "CHANNEL:" .. tostring(id)
	end
	return channel .. "\0" .. author .. "\0" .. body
end

-- Whether an earlier line at `at` still folds into `now`. Exactly two minutes is still within the window.
---@param at number
---@param now number
---@return boolean
function Model.Fresh(at, now)
	return now - at <= WINDOW
end

-- Drop entries older than the window once the table is full, so a long session does not grow it without end.
---@param now number
local function Prune(now)
	if keys <= KEEP then
		return
	end
	for other, entries in pairs(recent) do
		for key, entry in pairs(entries) do
			if now - entry.at > WINDOW then
				entries[key] = nil
				keys = keys - 1
			end
		end
		if next(entries) == nil then
			recent[other] = nil
		end
	end
end

-- Remove the earlier line by the line ID the client put in its extra data, never by the text it renders. The ID is
-- the ninth predicate argument, the event's own arguments in the message's extra data.
---@param frame ScrollingMessageFrame
---@param lineID any
local function Remove(frame, lineID)
	if not (lineID and lineID ~= 0 and frame.RemoveMessagesByPredicate) then
		return
	end
	pcall(frame.RemoveMessagesByPredicate, frame, function(_, _, _, _, _, _, _, _, eventArgs)
		return type(eventArgs) == "table" and eventArgs[11] == lineID
	end)
end

-- The message filter: count a repeated line, remove the one it replaces, and put the count on the new line. It runs
-- before the other text filters, so the key is the player's own text and not our icon or link markup.
---@param frame ScrollingMessageFrame
---@param event string
---@param arg1 any
---@param arg2 any
---@param arg3 any
---@param arg4 any
---@param arg5 any
---@param arg6 any
---@param arg7 any
---@param arg8 any
---@param arg9 any
---@param arg10 any
---@param arg11 any
local function FoldFilter(frame, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, ...)
	if not ns.Active(KEY) then
		return
	end
	local key = Model.Key(event, arg1, arg2, arg8, arg4)
	local lineID = ns.Readable(arg11)
	if not key or type(lineID) ~= "number" or lineID == 0 then
		return
	end
	local now = GetTime()
	-- Prune before this frame's table is looked up, so a prune can never take the table out from under the line it
	-- is recording.
	Prune(now)
	local entries = recent[frame]
	if not entries then
		entries = {}
		recent[frame] = entries
	end

	local previous = entries[key]
	local count = 1
	if previous and Model.Fresh(previous.at, now) then
		count = previous.count + 1
		Remove(frame, previous.lineID)
	else
		if not previous then
			keys = keys + 1
		end
	end
	entries[key] = { at = now, lineID = lineID, count = count }
	if count == 1 then
		return
	end
	return false,
		tostring(ns.Readable(arg1)) .. " " .. Chat.Grey("x" .. count),
		arg2,
		arg3,
		arg4,
		arg5,
		arg6,
		arg7,
		arg8,
		arg9,
		arg10,
		arg11,
		...
end

ns.Init(function()
	Chat.Filter(Chat.FOLD_EVENTS, FoldFilter)
end)
