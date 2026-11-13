-- Chat login order (#548): ADDON_LOADED fires for every addon before PLAYER_LOGIN has read the saved settings, so
-- the ADDON_LOADED sync in Chat/ClassLevels.lua and Chat/WhisperTabs.lua is registered only from ns.Init. An addon
-- loading before login changes no CVar and raises no error; once the settings are read, an addon loading still
-- forces the client's chat settings back to what the options ask for, and turning them off puts the player's own
-- values back.

local errors, handlers, pending = {}, {}, {}
local cvarWrites = {}
local cvars = { chatClassColorOverride = "1", whisperMode = "inline" }

local env = setmetatable({
	Ambiguate = function(name)
		return (name:gsub("%-.*$", ""))
	end,
	UnitName = function()
		return nil
	end,
	UnitLevel = function()
		return 0
	end,
	UnitExists = function()
		return false
	end,
	UnitIsPlayer = function()
		return false
	end,
	GetNumGroupMembers = function()
		return 0
	end,
	IsInGuild = function()
		return false
	end,
	C_FriendList = {
		GetNumFriends = function()
			return 0
		end,
		GetNumWhoResults = function()
			return 0
		end,
	},
	GetCVar = function(name)
		return cvars[name]
	end,
	SetCVar = function(name, value)
		cvarWrites[#cvarWrites + 1] = { name = name, value = value }
		cvars[name] = value
	end,
	ChatFrameUtil = {
		AddMessageEventFilter = function() end,
		AddSenderNameFilter = function() end,
	},
	GRAY_FONT_COLOR = {
		WrapTextInColorCode = function(_, text)
			return "|cff808080" .. text .. "|r"
		end,
	},
}, { __index = _G })

env._G = env

-- The namespace Core/Core.lua gives these files: ns.db stays nil until PLAYER_LOGIN reads the saved variables, and
-- ns.Init holds its callbacks until then, so the registration order is the one the client sees.
local ns
ns = {
	db = nil,
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
	Feature = function() end,
	On = function(event, fn)
		handlers[event] = handlers[event] or {}
		handlers[event][#handlers[event] + 1] = fn
	end,
	OnSettingChanged = function() end,
	Init = function(fn)
		if ns.db ~= nil then
			fn()
			return
		end
		pending[#pending + 1] = fn
	end,
	Active = function(key)
		return ns.db ~= nil and ns.db[key] == true
	end,
	core = {
		-- Core.lua runs every handler through SafeCall: a handler that fails is recorded, never thrown here, so the
		-- error the live client logged is what this spec asserts against.
		SafeCall = function(_, fn, ...)
			local ok, err = pcall(fn, ...)
			if not ok then
				errors[#errors + 1] = tostring(err)
			end
			return ok
		end,
	},
}
function ns.Readable(value)
	return value
end

for _, path in ipairs({
	"Chat/Shared.lua",
	"Chat/ClassLevels.lua",
	"Chat/WhisperTabs.lua",
}) do
	setfenv(assert(loadfile(path)), env)("TweaksForever", ns)
end

-- Handlers registered through ns.On are called with the event's arguments only, never the event name: Core.lua's
-- event frame does `ns.core.SafeCall(event, fn, ...)`.
local function Emit(event, ...)
	for _, fn in ipairs(handlers[event] or {}) do
		ns.core.SafeCall(event, fn, ...)
	end
end

local function Login(saved)
	ns.db = saved
	local queued = pending
	pending = {}
	for _, fn in ipairs(queued) do
		assert(ns.core.SafeCall("startup", fn), "an initializer runs at login: " .. tostring(errors[#errors]))
	end
end

-- An addon loading before login, the way every addon's own ADDON_LOADED arrives: no saved settings to index, no
-- CVar written, and nothing for the client to report.
cvarWrites = {}
Emit("ADDON_LOADED", "Blizzard_SomeAddon")
assert(#errors == 0, "an addon loading before login raises no error: " .. tostring(errors[1]))
assert(#cvarWrites == 0, "an addon loading before login changes no CVar")
assert(cvars.chatClassColorOverride == "1", "class colours are left as the player set them")
assert(cvars.whisperMode == "inline", "the whisper mode is left as the player set it")

-- Login reads the saved settings and runs the initializers, which register the ADDON_LOADED sync. Both options are
-- on, so both client settings are forced now.
Login({ chatClassLevels = true, chatWhisperTabs = true })
assert(#errors == 0, "login raises no error: " .. tostring(errors[1]))
assert(cvars.chatClassColorOverride == "0", "class colours come on at login")
assert(cvars.whisperMode == "popout", "whisper tabs come on at login")
assert(ns.db.chatClassColorSaved == "1" and ns.db.chatWhisperModeSaved == "inline", "the player's values are kept")

-- An addon loading after login still syncs: a client setting Blizzard put back is forced again.
cvars.chatClassColorOverride = "1"
cvars.whisperMode = "inline"
cvarWrites = {}
Emit("ADDON_LOADED", "Blizzard_SomeAddon")
assert(#errors == 0, "an addon loading after login raises no error: " .. tostring(errors[1]))
assert(cvars.chatClassColorOverride == "0", "an addon loading after login forces class colours on")
assert(cvars.whisperMode == "popout", "an addon loading after login docks whisper tabs")

-- Turning both off puts the player's own values back through the same handler.
ns.db.chatClassLevels = false
ns.db.chatWhisperTabs = false
cvarWrites = {}
Emit("ADDON_LOADED", "Blizzard_SomeAddon")
assert(#errors == 0, "restoring through the handler raises no error: " .. tostring(errors[1]))
assert(cvars.chatClassColorOverride == "1", "the player's class colour value comes back")
assert(cvars.whisperMode == "inline", "the player's whisper mode comes back")
assert(ns.db.chatClassColorSaved == nil and ns.db.chatWhisperModeSaved == nil, "both saved values are cleared")

print("chat login: ok")
