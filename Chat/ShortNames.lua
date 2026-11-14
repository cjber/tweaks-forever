---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

local KEY = "chatShortNames"
local Chat = ns.Chat

ns.Feature({
	key = KEY,
	category = "Chat",
	name = "Short channel names",
	tooltip = "Numbered channels show just their name: [2. Trade - City] reads [Trade], [1. General - Elwynn Forest] "
		.. "reads [General] and [4. LookingForGroup] reads [LFG]. Guild, officer, party, raid, instance and raid "
		.. "warning lines read [G], [O], [P], [PL], [R], [RL], [RW], [I] and [IL]. Clicking a channel name still works.",
	default = false,
	conflicts = { { addon = "Prat-3.0" }, { addon = "Chattynator" } },
})

---@class TFChatShortNames
local Model = {}
ns.ChatShortNames = Model

-- The fixed chat types and the short form each header shows. These are the client's own format globals
-- (CHAT_GUILD_GET and the rest), read at the moment the line is added, so a translated header keeps its link.
local SHORT = {
	GUILD = "G",
	OFFICER = "O",
	PARTY = "P",
	PARTY_LEADER = "PL",
	RAID = "R",
	RAID_LEADER = "RL",
	RAID_WARNING = "RW",
	INSTANCE_CHAT = "I",
	INSTANCE_CHAT_LEADER = "IL",
}

-- The displayed name of a numbered channel: the part before " - ", which is the zone suffix. LookingForGroup is
-- the one channel whose name the game abbreviates. A name without a number, or a name the client keeps secret, is
-- left alone and answers nil.
---@param name any
---@return string?
function Model.Channel(name)
	local value = ns.Readable(name)
	if type(value) ~= "string" then
		return nil
	end
	local rest = value:match("^%d+%.%s*(.+)$")
	if not rest then
		return nil
	end
	local base = rest:match("^(.-)%s+%-%s+") or rest
	if base == "LookingForGroup" then
		return "LFG"
	end
	return base
end

-- The header the client will show for `kind`, and the short header that replaces it: both include the channel link
-- so a click still runs the game's own channel action. A header with no link (raid warning) has no link to keep.
---@param kind string
---@return string? shown
---@return string? short
function Model.Header(kind)
	local form = SHORT[kind]
	local format = form and _G["CHAT_" .. kind .. "_GET"]
	if type(format) ~= "string" then
		return nil
	end
	local link, text = format:match("^(|H[^|]+|h)(%b[])|h")
	if link then
		return link .. text .. "|h", link .. "[" .. form .. "]|h"
	end
	local plain = format:match("^(%b[])%s*%%s")
	if plain then
		return plain, "[" .. form .. "]"
	end
end

-- A header, or a channel's link, is added after the filters return, so the shortened text replaces it on the frame's
-- next frame. Chat frames do not draw their new line until then, so the long form is never visible.
---@class TFChatHeaderJob
---@field frame ScrollingMessageFrame
---@field lineID any
---@field shown string
---@field short string

---@type TFChatHeaderJob[]
local pending = {}
local scheduled = false

---@param frame ScrollingMessageFrame
---@param lineID any
---@param shown string
---@param short string
function Model.Queue(frame, lineID, shown, short)
	pending[#pending + 1] = { frame = frame, lineID = lineID, shown = shown, short = short }
	if not scheduled then
		scheduled = true
		if C_Timer and C_Timer.After then
			C_Timer.After(0, Model.Flush)
		end
	end
end

-- Replace the header on the line whose extra data carries `lineID`, not on any line that happens to read the same.
function Model.Flush()
	scheduled = false
	local jobs = pending
	pending = {}
	for _, job in ipairs(jobs) do
		local frame = job.frame
		if frame and frame.TransformMessages then
			ns.core.SafeCall("chat header", function()
				frame:TransformMessages(function(_, _, _, _, _, _, _, _, eventArgs)
					return type(eventArgs) == "table" and eventArgs[11] == job.lineID
				end, function(text, r, g, b, ...)
					if type(text) == "string" then
						local at = text:find(job.shown, 1, true)
						if at then
							text = text:sub(1, at - 1) .. job.short .. text:sub(at + #job.shown)
						end
					end
					return text, r, g, b, ...
				end)
			end)
		end
	end
end

-- The channel name as the client itself shows it inside the link: the number prefix and the channel name, with a
-- Communities channel resolved to the stream's name (`ChatFrameUtil.ResolvePrefixedChannelName`).
---@param arg4 string
---@return string
local function Shown(arg4)
	if ChatFrameUtil and ChatFrameUtil.ResolvePrefixedChannelName then
		local ok, shown = pcall(ChatFrameUtil.ResolvePrefixedChannelName, arg4)
		if ok and type(shown) == "string" and shown ~= "" then
			return shown
		end
	end
	return arg4
end

-- A numbered channel's line is built from the fourth event argument, but the client reads that argument again after
-- the filters: it compares its length with each of the frame's channels, and it builds the channel link from it. So
-- the event's arguments are never changed. Instead the display text inside the link on the stored line is replaced,
-- keyed by the client's line ID, and the clickable channel index is kept exactly as the client built it.
---@param frame ScrollingMessageFrame
---@param _ string
---@param ... any
local function ChannelFilter(frame, _, ...)
	if not ns.Active(KEY) then
		return
	end
	local arg4 = ns.Readable((select(4, ...)))
	local index = ns.Readable((select(8, ...)))
	local lineID = ns.Readable((select(11, ...)))
	if type(arg4) ~= "string" or not index or not lineID or lineID == 0 then
		return
	end
	local short = Model.Channel(arg4)
	if not short then
		return
	end
	local link = "|Hchannel:channel:" .. tostring(index) .. "|h["
	Model.Queue(frame, lineID, link .. Shown(arg4) .. "]|h", link .. short .. "]|h")
end

---@param frame ScrollingMessageFrame
---@param event string
local function HeaderFilter(frame, event, ...)
	if not ns.Active(KEY) then
		return
	end
	local shown, short = Model.Header(event:sub(10))
	local lineID = select(11, ...)
	if shown and short and lineID and lineID ~= 0 then
		Model.Queue(frame, lineID, shown, short)
	end
end

ns.Init(function()
	Chat.Filter({ "CHAT_MSG_CHANNEL" }, ChannelFilter)
	Chat.Filter({
		"CHAT_MSG_GUILD",
		"CHAT_MSG_OFFICER",
		"CHAT_MSG_PARTY",
		"CHAT_MSG_PARTY_LEADER",
		"CHAT_MSG_RAID",
		"CHAT_MSG_RAID_LEADER",
		"CHAT_MSG_RAID_WARNING",
		"CHAT_MSG_INSTANCE_CHAT",
		"CHAT_MSG_INSTANCE_CHAT_LEADER",
	}, HeaderFilter)
end)
