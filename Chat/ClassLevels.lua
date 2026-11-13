---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

local KEY = "chatClassLevels"
local Chat = ns.Chat

ns.Feature({
	key = KEY,
	category = "Chat",
	name = "Class colours and levels",
	tooltip = "Player names in chat take their class colour, and the level follows the name in grey when the game "
		.. "knows it exactly: your group, guild, friends, /who, your target or the player under your mouse. Turning "
		.. "this off puts your previous class colour choices back.",
	default = false,
	conflicts = { { addon = "Prat-3.0" } },
})

-- The client's one switch for class-coloured names, read by ChatFrameUtil.ShouldColorChatByClass: "0" forces them on
-- for every chat type, "1" forces them off, and any other value follows each type's own setting. The per-type setting
-- ChatConfigFrame.lua writes is CHANNEL1..CHANNELn for numbered channels, so this switch is the only one that covers
-- channels too.
local CVAR = "chatClassColorOverride"
local FORCE = "0"

---@class TFChatClassLevels
local Model = {}
ns.ChatClassLevels = Model

-- [name] = level from a source the client stated exactly: a unit, the guild roster, the friends list, /who or a
-- target. Nothing guesses: a level the client does not give is left out of the cache.
---@type table<string, integer>
local levels = {}

---@param name any
---@param level any
function Model.Remember(name, level)
	local key = Chat.ShortName(name)
	local value = ns.Readable(level)
	if not key or type(value) ~= "number" or value < 1 then
		return
	end
	levels[key] = value
end

---@param name any
---@return integer?
function Model.Level(name)
	local key = Chat.ShortName(name)
	return key and levels[key] or nil
end

-- The sender's name with the level after it, in the client's grey.
---@param name string
---@param level integer
---@return string
function Model.Decorate(name, level)
	return name .. " " .. Chat.Grey(tostring(level))
end

-- Force class colours for every chat type through the client's own override, channels included. The value the player
-- had before is kept in the account saved variables, because the CVar is not per character: a /reload or relog while
-- the option is on must never record this addon's own "0" as their value.
function Model.Apply()
	local current = GetCVar(CVAR)
	if current == nil then
		return
	end
	if ns.db.chatClassColorSaved == nil then
		ns.db.chatClassColorSaved = current
	end
	if current ~= FORCE then
		SetCVar(CVAR, FORCE)
	end
end

-- Put the player's own value back, including an unset "", and forget it so the next change records their next choice.
function Model.Restore()
	local saved = ns.db.chatClassColorSaved
	if saved == nil then
		return
	end
	SetCVar(CVAR, saved)
	ns.db.chatClassColorSaved = nil
end

-- Turn class colours on while the option is on and not standing down for another addon, and put the player's own
-- choice back otherwise. Called at login, when the setting changes, and when an addon loads or the world changes.
function Model.Sync()
	if ns.Active(KEY) then
		Model.Apply()
	else
		Model.Restore()
	end
end

---@param unit string
local function RememberUnit(unit)
	if not (UnitExists(unit) and UnitIsPlayer(unit)) then
		return
	end
	Model.Remember(ns.Readable(UnitName(unit)), ns.Readable((UnitLevel(unit)))) -- multi-value: Readable keeps the name
end

---@param name any
---@param level any
---@param online any
local function RememberCharacter(name, level, online)
	if online then
		Model.Remember(name, level)
	end
end

-- The group's units, including the player. Read on its own so a group change never walks the other lists.
function Model.RefreshGroup()
	RememberUnit("player")
	local members = GetNumGroupMembers and GetNumGroupMembers() or 0
	if members > 0 then
		local raid = IsInRaid and IsInRaid()
		for index = 1, members do
			RememberUnit((raid and "raid" or "party") .. index)
		end
	end
end

-- The guild roster, read only when there is a guild and the client answers with a roster.
function Model.RefreshGuild()
	if not (IsInGuild and IsInGuild()) then
		return
	end
	for index = 1, GetNumGuildMembers and GetNumGuildMembers() or 0 do
		local name, _, _, level = GetGuildRosterInfo(index)
		Model.Remember(name, level)
	end
end

-- The friends list, only the friends who are connected: an offline friend's level is stale.
function Model.RefreshFriends()
	if not (C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex) then
		return
	end
	for index = 1, C_FriendList.GetNumFriends() do
		local info = C_FriendList.GetFriendInfoByIndex(index)
		if info then
			RememberCharacter(info.name, info.level, info.connected)
		end
	end
end

-- The last /who results the client holds.
function Model.RefreshWho()
	local who = C_FriendList and C_FriendList.GetNumWhoResults and C_FriendList.GetNumWhoResults() or 0
	for index = 1, who do
		local info = C_FriendList.GetWhoInfo and C_FriendList.GetWhoInfo(index)
		if info then
			Model.Remember(info.fullName, info.level)
		end
	end
end

-- Every source the client states a level for, for the one moment that wants all of them: the world loads. Each
-- source is read only when it is available, so a client without /who results or the friends list has fewer names.
function Model.Refresh()
	RememberUnit("target")
	RememberUnit("mouseover")
	Model.RefreshGroup()
	Model.RefreshGuild()
	Model.RefreshFriends()
	Model.RefreshWho()
end

-- The sender's level is added to the name the client already decorated, so the class colour, link and the client's
-- own formatting all keep working. A secret sender never reaches this callback (ChatFrameFilters.lua guards it),
-- and is checked again here.
local function NameFilter(_, decoratedName, ...)
	if not ns.Active(KEY) or type(decoratedName) ~= "string" then
		return
	end
	local sender = select(2, ...)
	local level = Model.Level(sender)
	if level then
		return Model.Decorate(decoratedName, level)
	end
end

-- Each event reads only the source it is about. A mouseover fires constantly, so it reads that unit and nothing
-- else; a full guild roster read belongs to GUILD_ROSTER_UPDATE alone.
---@type table<string, function>
local EVENTS = {
	PLAYER_TARGET_CHANGED = function()
		RememberUnit("target")
	end,
	UPDATE_MOUSEOVER_UNIT = function()
		RememberUnit("mouseover")
	end,
	GROUP_ROSTER_UPDATE = Model.RefreshGroup,
	UNIT_LEVEL = RememberUnit,
	GUILD_ROSTER_UPDATE = Model.RefreshGuild,
	FRIENDLIST_UPDATE = Model.RefreshFriends,
	WHO_LIST_UPDATE = Model.RefreshWho,
	PLAYER_ENTERING_WORLD = Model.Refresh,
}

for event, handler in pairs(EVENTS) do
	ns.On(event, handler)
end

-- An addon that loads after login can become a conflict, and Blizzard can reset its chat settings on a world change.
ns.On("ADDON_LOADED", Model.Sync)
ns.OnSettingChanged(KEY, Model.Sync)

ns.Init(function()
	Chat.NameFilter(NameFilter)
	Model.Refresh()
	Model.Sync()
end)
