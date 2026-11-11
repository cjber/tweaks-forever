-- Run from the repository root: luajit tests/error_journal_spec.lua
-- ForeverCore's shared error journal and debug log live in TweaksForeverDB, attached at PLAYER_LOGIN once the saved
-- variables and their defaults are in, so the report lists earlier sessions' errors and the lines that led to them
-- after a /reload.
-- Each login runs ForeverCore and then the addon in its own environment, as the client loads a required dependency
-- first. The chunk is parsed once: executing it again still builds every local and table fresh.
local chunks = {}
local function Chunk(path)
	local chunk = chunks[path]
	if not chunk then
		chunk = assert(loadfile(path))
		chunks[path] = chunk
	end
	return chunk
end

local function Login(saved)
	local frames = {}
	local env = setmetatable({
		TweaksForeverDB = saved,
		C_AddOns = {
			IsAddOnLoaded = function()
				return false
			end,
		},
		CreateFrame = function()
			local frame = { RegisterEvent = function() end }
			function frame:SetScript(_, fn)
				self.callback = fn
			end
			frames[#frames + 1] = frame
			return frame
		end,
		geterrorhandler = function()
			return function() end
		end,
		seterrorhandler = function() end,
		strtrim = function(text)
			return (text:gsub("^%s+", ""):gsub("%s+$", ""))
		end,
		-- The client's clock for the shared log's lines (Core/Log.lua), fixed so the spec is deterministic.
		GetTime = function()
			return 1.5
		end,
		date = function()
			return "2026-11-08 12:00:00"
		end,
	}, { __index = _G })
	local core = dofile("tests/forever_core.lua")
	core.install(env, {
		"Core/SafeCall.lua",
		"Core/Log.lua",
		"UI/Report.lua",
		"UI/Credits.lua",
		"UI/MapCanvas.lua",
		"Data/Credits.lua",
		"UI/Credits.lua",
		"Expose.lua",
	})
	local ns = {}
	Chunk("Locales/enUS.lua")("TweaksForever", ns)
	setfenv(Chunk("Core/Core.lua"), env)("TweaksForever", ns)
	-- The last frame Core.lua makes is its PLAYER_LOGIN one.
	frames[#frames].callback()
	return ns, env
end

-- A first install, with no saved table at all: login makes the journal and the log in TweaksForeverDB and attaches
-- them.
local ns, env = Login(nil)
local db = assert(env.TweaksForeverDB, "the saved table was not made")
assert(type(db.errors) == "table", "the saved table has no error journal")
assert(type(db.log) == "table", "the saved table has no debug log")

-- An error caught by ns.core.SafeCall is recorded in the saved journal, which is where the next session reads it.
local ok = ns.core.SafeCall("error journal spec", function()
	error("error journal spec failure")
end)
assert(ok == false, "the failure was not caught")
local entry
for _, candidate in ipairs(db.errors) do
	if candidate.message:find("error journal spec failure", 1, true) then
		entry = candidate
	end
end
assert(entry, "the caught error did not reach the saved journal")
assert(entry.kind == "error" and entry.count == 1, "the journal entry is not one error")
assert(type(entry.firstSeen) == "number" and type(entry.lastSeen) == "number", "the journal entry has no times")

-- The log rides in the same saved table, so the lines that led to a bug survive a /reload too.
ns.core.Log("info", "error journal spec", "a line before the reload")
local logged
for _, line in ipairs(db.log.lines or {}) do
	if line:find("a line before the reload", 1, true) then
		logged = line
	end
end
assert(logged, "the log line did not reach the saved ring")
assert(logged:find("info error journal spec:", 1, true), "the saved line has no level and topic")

-- A table a previous session saved is the journal and the log this one keeps, and its entries reach the report as
-- earlier sessions' errors.
local saved = {
	errors = {
		{
			signature = "earlier\n",
			kind = "error",
			message = "error from an earlier session",
			stack = "",
			count = 2,
			firstSeen = 1,
			lastSeen = 2,
		},
	},
	log = {
		lines = { "2026-11-07 09:00:00 +12.0s info earlier: line from an earlier session" },
		pinned = false,
	},
}
local reloaded, reloadedEnv = Login(saved)
assert(reloadedEnv.TweaksForeverDB == saved, "the saved table was replaced")
assert(reloadedEnv.TweaksForeverDB.errors == saved.errors, "the journal is not the saved errors table")
assert(reloadedEnv.TweaksForeverDB.log == saved.log, "the log is not the saved log table")
local earlier
for _, candidate in ipairs(reloaded.core.CaughtErrors()) do
	if candidate.message == "error from an earlier session" then
		earlier = candidate
	end
end
assert(earlier and earlier.fromSession == false, "an earlier session's error is missing from the report")
assert(earlier.count == 2, "the earlier session's count was lost")
local kept
for _, line in ipairs(reloaded.core.LogLines(10)) do
	if line:find("line from an earlier session", 1, true) then
		kept = line
	end
end
assert(kept, "an earlier session's log line is missing after the reload")

-- A saved value a hand edit left unreadable is replaced at login, not kept: keeping it would leave the journal and
-- the log in memory, and the next reload would drop them.
local corrupt, corruptEnv = Login({ errors = "junk", log = 5 })
local repairedDB = assert(corruptEnv.TweaksForeverDB)
assert(type(repairedDB.errors) == "table", "a corrupt journal was kept instead of replaced")
assert(type(repairedDB.log) == "table", "a corrupt log was kept instead of replaced")
assert(type(repairedDB.log.lines) == "table", "a replaced log has no ring")
assert(corrupt.core.SafeCall("corrupt journal", function()
	error("corrupt journal failure")
end) == false, "the failure was not caught")
local repaired
for _, candidate in ipairs(repairedDB.errors) do
	if candidate.message:find("corrupt journal failure", 1, true) then
		repaired = candidate
	end
end
assert(repaired, "the replaced journal is not the one this session records into")

print("error_journal_spec: ok")
