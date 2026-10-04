local features, handlers, db = {}, {}, {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	On = function(event, fn)
		handlers[event] = fn
	end,
	Active = function(key)
		return db[key]
	end,
	db = db,
}
local invited, grouped, leader, assistant = nil, false, false, false
local readable = true
local env = setmetatable({
	C_PartyInfo = {
		InviteUnit = function(name)
			invited = name
		end,
	},
	IsInGroup = function()
		return grouped
	end,
	UnitIsGroupLeader = function()
		return leader
	end,
	UnitIsGroupAssistant = function()
		return assistant
	end,
	canaccessvalue = function()
		return readable
	end,
	strtrim = function(text)
		return (text:gsub("^%s*(.-)%s*$", "%1"))
	end,
}, { __index = _G })
setfenv(assert(loadfile("Features/WhisperInvite.lua")), env)("TweaksForever", ns)
assert(features.whisperInvite.default == false and features.whisperInvite.category == "Automation")
assert(features.whisperInviteKeyword.default == "inv" and features.whisperInviteKeyword.parent == "whisperInvite")

local Matches = ns.WhisperInvite.Matches
assert(Matches("  INV ", "inv"), "the whole message, trimmed and case-insensitive")
assert(Matches("invite", "invite"))
assert(not Matches("invite", "inv"), "a longer word is not the keyword")
assert(not Matches("inv please", "inv"), "extra words are not the keyword")

db.whisperInviteKeyword = "inv"
handlers.CHAT_MSG_WHISPER("inv", "Bob")
assert(invited == nil, "the setting is off by default")

db.whisperInvite = true
handlers.CHAT_MSG_WHISPER("inv", "Bob")
assert(invited == "Bob", "the keyword whisper invites its sender")

invited = nil
handlers.CHAT_MSG_WHISPER("invite", "Bob")
assert(invited == nil)

invited = nil
handlers.CHAT_MSG_WHISPER("inv")
assert(invited == nil, "a whisper with no sender sends nothing")

grouped = true
handlers.CHAT_MSG_WHISPER("inv", "Bob")
assert(invited == nil, "a plain group member cannot invite")
leader = true
handlers.CHAT_MSG_WHISPER("inv", "Bob")
assert(invited == "Bob", "the group leader invites")
leader = false
assistant = true
handlers.CHAT_MSG_WHISPER("inv", "Bob")
assert(invited == "Bob", "a raid assistant invites")

readable = false
invited = nil
handlers.CHAT_MSG_WHISPER("inv", "Bob")
assert(invited == nil, "a whisper the client hides is left alone")
readable = true

local leatrix = features.whisperInvite.conflicts[1].when
assert(not leatrix())
env.LeaPlusDB = { InviteFromWhisper = "On" }
assert(leatrix())
print("whisperinvite: ok")
