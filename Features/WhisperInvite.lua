---@type string, TFNamespace
local _, ns = ...

local KEY = "whisperInvite"
local KEYWORD = "whisperInviteKeyword"

ns.Feature({
	key = KEY,
	category = "Automation",
	name = "Invite from whispers",
	tooltip = "A whisper that is exactly the keyword you pick below invites its sender to your group. You must be "
		.. "ungrouped, the group leader or a raid assistant. Nothing is sent until such a whisper arrives.",
	default = false,
	conflicts = {
		{
			addon = "Leatrix_Plus",
			when = function()
				return LeaPlusDB and LeaPlusDB.InviteFromWhisper == "On"
			end,
		},
	},
})

ns.Feature({
	key = KEYWORD,
	category = "Automation",
	name = "Invite keyword",
	tooltip = "The whole whisper that invites its sender: the message must be this word alone.",
	default = "inv",
	options = {
		{ "inv", "inv" },
		{ "invite", "invite" },
		{ "group", "group" },
	},
	parent = KEY,
})

---@class TFWhisperInvite
local Model = {}
ns.WhisperInvite = Model

---@param message string
---@param keyword string
---@return boolean
function Model.Matches(message, keyword)
	return strtrim(message):lower() == keyword
end

-- A group invite can be sent by an ungrouped player, the leader or a raid assistant; anyone else's invite would
-- be refused by the game.
---@return boolean
local function MayInvite()
	if not IsInGroup() then
		return true
	end
	return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

ns.On("CHAT_MSG_WHISPER", function(message, author)
	-- A whispered line can be a secret value, which cannot be read.
	if not (ns.Active(KEY) and author and canaccessvalue(message) and canaccessvalue(author)) then
		return
	end
	if Model.Matches(message, ns.db[KEYWORD]) and MayInvite() then
		C_PartyInfo.InviteUnit(author)
	end
end)
