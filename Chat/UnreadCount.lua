---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

local L = ns.L
local KEY = "chatWhisperUnread"
local Chat = ns.Chat

ns.Feature({
	key = KEY,
	category = "Chat",
	name = "Unread whispers on tabs",
	tooltip = "A whisper tab you are not reading shows how many whispers have arrived since you last opened it, "
		.. "after the player's name, such as Thrall (3). The game's own glow marks a new whisper as before.",
	default = false,
	conflicts = { { addon = "WIM" }, { addon = "Prat-3.0" } },
})

---@class TFChatWhisperUnread
local Model = {}
ns.ChatWhisperUnread = Model

-- [frame] = whispers received since its tab was last selected. Only a window that is not the dock's selected one
-- keeps a count, so the number is always about something the player has not read yet.
---@type table<ScrollingMessageFrame, integer>
local counts = {}

-- The tab text: the client's own name for the window, then the count. The name is read from the frame each time so
-- a reused window and a renamed partner keep the client's name. The tab keeps the width the client gave it: a
-- whisper tab's name may be a secret value, so FCF_SetWindowName and FCFDock_UpdateTabs size it from a fixed set of
-- widths with FCF_SetTabFixedWidth, never from its text. Measuring the text here to widen the tab would leak the
-- name's width and leave the dock's next tab at its old position.
---@param frame ScrollingMessageFrame
function Model.Render(frame)
	local tab = Chat.Tab(frame)
	local name = ns.Readable(frame.name)
	if not (tab and tab.SetText and type(name) == "string" and name ~= "") then
		return
	end
	local count = counts[frame]
	tab:SetText(count and count > 0 and L["%s (%d)"]:format(name, count) or name)
end

-- The tab is being read: forget its count and put the client's name back.
---@param frame ScrollingMessageFrame
function Model.Clear(frame)
	if counts[frame] == nil then
		return
	end
	counts[frame] = nil
	Model.Render(frame)
end

-- Add one whisper to a window the player is not reading. A whisper in the selected window is already read.
---@param frame ScrollingMessageFrame
function Model.Add(frame)
	if not Chat.IsWhisperWindow(frame) or frame == Chat.SelectedWindow() then
		return
	end
	counts[frame] = (counts[frame] or 0) + 1
	Model.Render(frame)
end

local function Filter(frame)
	if not ns.Active(KEY) then
		return
	end
	Model.Add(frame)
end

-- A window the client has just set up for a new partner starts at zero, and its tab may still carry the previous
-- partner's count from a reused frame, so the client's name goes back on it.
local function Opened(frame)
	if not ns.Active(KEY) then
		return
	end
	counts[frame] = nil
	Model.Render(frame)
end

ns.OnSettingChanged(KEY, function()
	if ns.Active(KEY) then
		return
	end
	for _, frame in ipairs(Chat.Frames()) do
		Model.Clear(frame)
	end
end)

ns.Init(function()
	Chat.Filter(Chat.WHISPER_EVENTS, Filter)
	Chat.OnWhisperWindow(Opened)
	-- FCF_Tab_OnClick is the client's own tab click, after it has selected the window. Hooked, never replaced.
	if type(FCF_Tab_OnClick) == "function" then
		hooksecurefunc("FCF_Tab_OnClick", function(tab)
			if not ns.Active(KEY) then
				return
			end
			local frame = _G["ChatFrame" .. tab:GetID()]
			if frame and Chat.SelectedWindow() == frame then
				Model.Clear(frame)
			end
		end)
	end
end)
