---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

local L = ns.L
local KEY = "chatLastGrouped"
local Chat = ns.Chat
local Record = ns.ChatPlayerRecord

ns.Feature({
	key = KEY,
	category = "Chat",
	name = "Last grouped with",
	tooltip = "A whisper window starts with a grey line saying when you last grouped with that player and where, "
		.. "from what this character has seen. Nothing is added when you have never grouped with them.",
	default = false,
	conflicts = { { addon = "WIM" }, { addon = "Prat-3.0" } },
})

---@class TFChatLastGrouped
local Model = {}
ns.ChatLastGrouped = Model

-- The client's own grey for a secondary chat line, the colour of its timestamp and date divider.
local GREY = 0.5

-- "Grouped with you 3 days ago in Deadmines", from the addon's own record. A place the client never gave that
-- session is left out rather than guessed.
---@param record TFChatPlayer
---@param now number?
---@return string?
function Model.Summary(record, now)
	local ago = Record.Ago(record.time, now)
	if not ago then
		return nil
	end
	if record.zone then
		return L["Grouped with you %s ago in %s"]:format(ago, record.zone)
	end
	return L["Grouped with you %s ago"]:format(ago)
end

-- Add the line once, before the window's first whisper. A frame that already holds lines (a window the client
-- reused with copied messages) does not get one, so the line is always the window's first.
---@param frame ScrollingMessageFrame
---@param target string?
function Model.Attach(frame, target)
	if not ns.Active(KEY) or not Chat.IsWhisperWindow(frame) then
		return
	end
	local record = Record.Get(target)
	if not (record and record.time) then
		return
	end
	if frame.GetNumMessages and frame:GetNumMessages() > 0 then
		return
	end
	local summary = Model.Summary(record)
	if summary then
		frame:AddMessage(summary, GREY, GREY, GREY)
	end
end

-- Every other player in the group is remembered with now and this place, which is what the line reads back.
ns.On("GROUP_ROSTER_UPDATE", function()
	if ns.Active(KEY) then
		Record.Group()
	end
end)

ns.Init(function()
	Chat.OnWhisperWindow(Model.Attach)
end)
