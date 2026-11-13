---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

local KEY = "chatWhisperTabs"

ns.Feature({
	key = KEY,
	category = "Chat",
	name = "Whisper tabs",
	tooltip = "Every person who whispers you gets their own tab in the chat window, using the game's own New Whispers "
		.. "setting. Turning this off puts your previous setting back.",
	default = false,
	conflicts = { { addon = "WIM" }, { addon = "Prat-3.0" } },
})

-- The client's own New Whispers setting (Settings > Social, Blizzard_SettingsDefinitions_Frame/Social.lua):
-- "popout" docks one tab per whisper partner and keeps whispers out of the other tabs, "inline" keeps them in the
-- regular tabs, and "popout_and_inline" does both.
local CVAR = "whisperMode"
local POPOUT = "popout"
-- The two values that already dock a tab for each partner.
local DOCKED = { popout = true, popout_and_inline = true }

---@class TFChatWhisperTabs
local Model = {}
ns.ChatWhisperTabs = Model

-- Set the client's setting to popout unless it already docks whisper tabs. The player's own value is kept in the
-- account saved variables the first time it changes, because the setting is not per character: a /reload or relog
-- while the option is on must never record this addon's own "popout" as their value.
function Model.Apply()
	local current = GetCVar(CVAR)
	if current == nil or DOCKED[current] then
		return
	end
	if ns.db.chatWhisperModeSaved == nil then
		ns.db.chatWhisperModeSaved = current
	end
	SetCVar(CVAR, POPOUT)
end

-- Put the player's own value back, including an unset "", and forget it so the next change records their next
-- choice. With no saved value nothing is touched, so a mode that already docked tabs is left exactly alone.
function Model.Restore()
	local saved = ns.db.chatWhisperModeSaved
	if saved == nil then
		return
	end
	SetCVar(CVAR, saved)
	ns.db.chatWhisperModeSaved = nil
end

-- Turn whisper tabs on while the option is on and not standing down for another addon, and put the player's own
-- setting back otherwise. Called at login, when the setting changes, and as an addon loads.
function Model.Sync()
	if ns.Active(KEY) then
		Model.Apply()
	else
		Model.Restore()
	end
end

ns.On("ADDON_LOADED", Model.Sync)
ns.OnSettingChanged(KEY, Model.Sync)

ns.Init(Model.Sync)
