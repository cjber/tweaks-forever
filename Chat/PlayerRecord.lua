---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

local Chat = ns.Chat

-- The addon's own record of the players this character has grouped or whispered with. The whisper window's
-- "Grouped with you" line and the player card read it; a group change and a whisper write it. It lives in
-- TweaksForeverCharDB because a group or a whisper belongs to the character who met the player.
--
-- Nothing here is sent anywhere and nothing is inferred: a player with no record has no line and no card field.
-- The name is the key, case-folded, because the client upper-cases a whisper window's target
-- (FCFManager_GetChatTarget) while a chat line keeps the name's own case.

-- 500 names covers years of pick-up groups for one character and stays a small saved variable: a record is a time,
-- a zone, a whisper count and one more time, so the whole table is a few tens of kilobytes. A larger cap would keep
-- growing the file for cards nobody will ever hover over.
local CAP = 500

---@class TFChatPlayerRecord
local Record = {}
ns.ChatPlayerRecord = Record

-- Wall-clock seconds, so a group time still means something after a reload or a logout. GetTime only exists as a
-- fallback for a client without time().
---@return number
local function Now()
	return time and time() or GetTime()
end

---@param name any
---@return string?
local function Key(name)
	local short = Chat.ShortName(name)
	if not short then
		return nil
	end
	return short:lower()
end

-- This character's records, created on the first write.
---@return table<string, TFChatPlayer>?
local function Store()
	local db = TweaksForeverCharDB
	if type(db) ~= "table" then
		return nil
	end
	if type(db.chatPlayers) ~= "table" then
		db.chatPlayers = {}
	end
	return db.chatPlayers
end

-- Drop the oldest records until the table fits CAP. "Oldest" is the last time the record was written, so a player
-- whispered with yesterday survives a group met this morning. Ties go by name so the same record always goes, and
-- `keep` (the record or records being written now) is never dropped: a whole raid recorded in one second would
-- otherwise be able to evict a member whose write triggered the sweep.
---@param players table<string, TFChatPlayer>
---@param keep? string|table<string, boolean>
function Record.Trim(players, keep)
	local count = 0
	for _ in pairs(players) do
		count = count + 1
	end
	while count > CAP do
		local oldestKey, oldestSeen
		for key, record in pairs(players) do
			if not (type(keep) == "table" and keep[key] or key == keep) then
				local seen = type(record) == "table" and record.seen or 0
				if not oldestSeen or seen < oldestSeen or (seen == oldestSeen and key < oldestKey) then
					oldestKey, oldestSeen = key, seen
				end
			end
		end
		if not oldestKey then
			break
		end
		players[oldestKey] = nil
		count = count - 1
	end
end

-- The record for `name`, or nil when this character has never grouped or whispered with them.
---@param name any
---@return TFChatPlayer?
function Record.Get(name)
	local key = Key(name)
	local players = type(TweaksForeverCharDB) == "table" and TweaksForeverCharDB.chatPlayers
	if not (key and type(players) == "table") then
		return nil
	end
	local record = players[key]
	return type(record) == "table" and record or nil
end

-- The record `name` writes to, creating it and marking it as just seen, without checking the cap. Every write goes
-- through here so a pass that writes many records (a group) can trim once at the end.
---@param name any
---@return TFChatPlayer?
---@return string?
---@return table<string, TFChatPlayer>?
local function Write(name)
	local key = Key(name)
	local players = Store()
	if not (key and players) then
		return nil
	end
	local record = players[key]
	if type(record) ~= "table" then
		record = {}
		players[key] = record
	end
	record.seen = Now()
	return record, key, players
end

-- The record `name` writes to, with the cap checked after the write.
---@param name any
---@return TFChatPlayer?
local function Entry(name)
	local record, key, players = Write(name)
	if record and key and players then
		Record.Trim(players, key)
	end
	return record
end

-- The player was in the group just now: remember when and where. A nil zone clears an older zone, because the
-- last group is this group, and claiming the old place would be wrong.
---@param name any
---@param zone string?
---@param at number?
---@return TFChatPlayer?
function Record.Grouped(name, zone, at)
	local record = Entry(name)
	if not record then
		return nil
	end
	record.time = at or Now()
	record.zone = zone
	return record
end

-- One whisper between this character and `name`, received or sent.
---@param name any
---@return TFChatPlayer?
function Record.Whispered(name)
	local record = Entry(name)
	if not record then
		return nil
	end
	record.whispers = (record.whispers or 0) + 1
	return record
end

-- The place this character is in: the instance's own name inside one, the zone outside.
---@return string?
function Record.Zone()
	if IsInInstance and IsInInstance() then
		local name = GetInstanceInfo and (GetInstanceInfo())
		name = ns.Readable(name)
		if type(name) == "string" and name ~= "" then
			return name
		end
	end
	local zone = GetRealZoneText and GetRealZoneText()
	zone = ns.Readable(zone)
	if type(zone) == "string" and zone ~= "" then
		return zone
	end
end

-- Store every other player in the group with this moment and this place. Called on GROUP_ROSTER_UPDATE: each
-- change records the whole group again, which is what "last grouped" means. A raid writes up to 40 records, so the
-- cap is checked once after them all rather than scanning the table once per member.
function Record.Group()
	local me = Chat.Player()
	if not me then
		return
	end
	local members = GetNumGroupMembers and GetNumGroupMembers() or 0
	if members == 0 then
		return
	end
	local raid = IsInRaid and IsInRaid()
	local zone = Record.Zone()
	local at = Now()
	local written, players
	for index = 1, members do
		local unit = (raid and "raid" or "party") .. index
		if UnitExists(unit) and UnitIsPlayer(unit) then
			local name = Chat.ShortName(ns.Readable(UnitName(unit))) -- multi-value: Readable keeps the name
			if name and name:lower() ~= me:lower() then
				local record, key, store = Write(name)
				if record and key and store then
					record.time = at
					record.zone = zone
					written, players = written or {}, store
					written[key] = true
				end
			end
		end
	end
	if written and players then
		Record.Trim(players, written)
	end
end

-- The client's own relative time for a stamp: the friends list's formatter while that frame is loaded, otherwise
-- the same client strings it builds on (LASTONLINE_SECS, LASTONLINE_MINUTES, LASTONLINE_HOURS, LASTONLINE_DAYS).
-- The fallback uses the friends list's own cutoffs (a minute, an hour, a day) so the words match the game's.
---@param at number?
---@param now number?
---@return string?
function Record.Ago(at, now)
	if type(at) ~= "number" then
		return nil
	end
	local friends = FriendsListUtil
	if type(friends) == "table" and friends.GetRelativeTimeText then
		local ok, text = pcall(friends.GetRelativeTimeText, at)
		if ok and type(text) == "string" and text ~= "" then
			return text
		end
	end
	local seconds = math.max(0, (now or Now()) - at)
	if seconds < 60 then
		return LASTONLINE_SECS or "< a minute"
	elseif seconds < 60 * 60 then
		return (LASTONLINE_MINUTES or "%d minutes"):format(math.floor(seconds / 60))
	elseif seconds < 24 * 60 * 60 then
		return (LASTONLINE_HOURS or "%d hours"):format(math.floor(seconds / 3600))
	end
	return (LASTONLINE_DAYS or "%d days"):format(math.floor(seconds / 86400))
end
