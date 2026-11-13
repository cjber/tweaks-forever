---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L
local KEY = "chatHistory"
local Chat = ns.Chat

ns.Feature({
	key = KEY,
	category = "Chat",
	name = "Chat history after a reload",
	tooltip = "The last 200 lines of each chat window come back after a reload or logging out, above a Before your "
		.. "/reload line. Kept for this character only, and lines the game keeps secret are left out.",
	default = false,
	conflicts = { { addon = "Prat-3.0" }, { addon = "Chattynator" } },
})

---@class TFChatHistory
local Model = {}
ns.ChatHistory = Model

-- Two screens of chat, about what a player reads after a reload. Older lines make the saved variable grow without
-- showing anything a player would scroll back to.
local CAP = 200

-- [line ID] = when the client showed it, for the saved line's time. The client does not expose its own message
-- timestamp through GetMessageInfo.
---@type table<any, number>
local stamps = {}
local stamped = 0

-- The divider the client's own Communities chat uses for a date: a line 165 by 8 with three texels of padding, the
-- shape Blizzard_Communities gives it. Its label follows on the same line.
---@return string
function Model.Divider()
	if CreateAtlasMarkup then -- art-ok: the client's own chat date line uses this atlas at 165 by 8
		return CreateAtlasMarkup("communities-chat-date-line", 165, 8, 0, 3)
	end
	return ""
end

-- The newest `CAP` lines, oldest first.
---@param lines TFChatHistoryLine[]
---@return TFChatHistoryLine[]
function Model.Keep(lines)
	if #lines <= CAP then
		return lines
	end
	local kept = {}
	for index = #lines - CAP + 1, #lines do
		kept[#kept + 1] = lines[index]
	end
	return kept
end

-- The lines a frame holds now, oldest first, skipping a line that is or contains a secret value and keeping its
-- colours and the time it arrived.
---@param frame ScrollingMessageFrame
---@return TFChatHistoryLine[]
function Model.Read(frame)
	local lines = {}
	if not (frame.GetNumMessages and frame.GetMessageInfo) then
		return lines
	end
	local now = time and time() or 0
	for index = 1, frame:GetNumMessages() do
		local text, r, g, b, _, _, _, _, eventArgs = frame:GetMessageInfo(index)
		local body = ns.Readable(text)
		local secret = not body
		if eventArgs then
			if not ns.Readable(eventArgs[1]) then
				secret = true
			elseif eventArgs[2] ~= nil and not ns.Readable(eventArgs[2]) then
				secret = true
			end
		end
		if not secret then
			local lineID = eventArgs and eventArgs[11]
			lines[#lines + 1] = {
				text = body,
				r = r,
				g = g,
				b = b,
				time = lineID and stamps[lineID] or now,
			}
		end
	end
	return Model.Keep(lines)
end

-- Save the docked frames now. PLAYER_LOGOUT is the last point the frames still hold their lines, on /reload as well
-- as on logging out, and saved variables are written after it.
function Model.Save()
	if not ns.Active(KEY) then
		return
	end
	local db = TweaksForeverCharDB
	if type(db) ~= "table" then
		return
	end
	db.chatHistory = db.chatHistory or {}
	for _, frame in ipairs(Chat.Docked()) do
		local name = Chat.Name(frame)
		if name then
			local lines = Model.Read(frame)
			db.chatHistory[name] = #lines > 0 and lines or nil
		end
	end
	stamps, stamped = {}, 0
end

-- Replay the saved lines above what the client already printed. BackFillMessage puts each line above the frame's
-- current lines, so the divider goes in first and the saved lines after it, newest first: the oldest saved line ends
-- up at the top, then the newest saved line, then the divider, then the login and current-session lines below.
---@param frame ScrollingMessageFrame
---@param lines TFChatHistoryLine[]
function Model.Show(frame, lines)
	frame:BackFillMessage(Model.Divider() .. " " .. L["Before your /reload"], 0.5, 0.5, 0.5)
	for index = #lines, 1, -1 do
		local line = lines[index]
		if ns.Readable(line.text) then
			frame:BackFillMessage(line.text, line.r, line.g, line.b)
		end
	end
end

local replayed = false

-- Once per login, after the client has built its chat frames, put each docked frame's saved lines back.
function Model.Replay()
	if replayed then
		return
	end
	replayed = true
	local db = type(TweaksForeverCharDB) == "table" and TweaksForeverCharDB.chatHistory
	if not ns.Active(KEY) then
		if type(TweaksForeverCharDB) == "table" then
			TweaksForeverCharDB.chatHistory = nil
		end
		return
	end
	if type(db) ~= "table" then
		return
	end
	for _, frame in ipairs(Chat.Docked()) do
		local name = Chat.Name(frame)
		local lines = name and db[name]
		if type(lines) == "table" and #lines > 0 then
			ns.core.SafeCall("chat history", Model.Show, frame, lines)
		end
	end
end

-- Note when a line arrived, keyed by the client's line ID. The callback changes nothing.
local function Stamp(_, _, ...)
	if not ns.Active(KEY) then
		return
	end
	local lineID = select(11, ...)
	if lineID and lineID ~= 0 then
		if stamped >= 2000 then
			stamps, stamped = {}, 0
		end
		stamps[lineID] = time and time() or GetTime()
		stamped = stamped + 1
	end
end

ns.On("PLAYER_LOGOUT", Model.Save)
ns.On("PLAYER_ENTERING_WORLD", function()
	if C_Timer and C_Timer.After then
		C_Timer.After(0, Model.Replay)
	else
		Model.Replay()
	end
end)
ns.OnSettingChanged(KEY, function()
	if not ns.Active(KEY) and type(TweaksForeverCharDB) == "table" then
		TweaksForeverCharDB.chatHistory = nil
	end
end)

ns.Init(function()
	Chat.Filter(Chat.TEXT_EVENTS, Stamp)
end)
