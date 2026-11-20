-- Run from the repository root: luajit tests/core_dependency_spec.lua
-- Tweaks Forever requires ForeverCore. Core/Require.lua checks the members this addon calls and hands the answer to
-- Core/ForeverRequire.lua, the shared warning ForeverCore's own tests cover. This spec covers the addon's half: a core
-- missing a member stops the addon's own files with one line in the error frame, and a complete one runs silently.
local function Load(foreverCore, installed, enabled)
	local lines = {}
	local env = {
		ForeverCore = foreverCore,
		UIErrorsFrame = {
			AddMessage = function(_, text, red, green, blue)
				lines[#lines + 1] = { text = text, red = red, green = green, blue = blue }
			end,
		},
		UnitName = function()
			return "Tester"
		end,
		C_AddOns = {
			GetAddOnMetadata = function(addon, field)
				if addon == "TweaksForever" then
					if field == "Title" then
						return "Tweaks Forever"
					end
					if field == "X-Forever-Core" then
						return "v1.5.0"
					end
				elseif addon == 1 or addon == "ForeverCore" then
					if field == "Title" then
						return "ForeverCore"
					end
					if field == "X-Curse-Project-ID" then
						return "1796337"
					end
				end
			end,
			GetNumAddOns = function()
				return installed == false and 0 or 1
			end,
			GetAddOnInfo = function(index)
				if index == 1 and installed ~= false then
					return "ForeverCore"
				end
			end,
			IsAddOnLoaded = function(index)
				return index == 1 and installed ~= false and enabled ~= false
			end,
			GetAddOnEnableState = function(index)
				return index == 1 and installed ~= false and enabled ~= false and 2 or 0
			end,
			-- The client returns a dependency list as varargs, never a table.
			GetAddOnDependencies = function()
				return unpack({})
			end,
		},
	}
	env._G = env
	setmetatable(env, { __index = _G })
	local ns = {
		L = setmetatable({}, {
			__index = function(_, key)
				return key
			end,
		}),
	}
	setfenv(assert(loadfile("Core/ForeverRequire.lua")), env)("TweaksForever", ns)
	setfenv(assert(loadfile("Core/Require.lua")), env)("TweaksForever", ns)
	return ns, lines
end

-- ForeverCore without NotReady, which Core/API.lua calls, stops the addon with one error-frame line and no chat.
local missing, missingLines = Load({ APIKit = { Hub = function() end } })
assert(missing.broken == true, "a ForeverCore missing a member this addon calls stops it")
assert(#missingLines == 1, "and says so in one error line")
assert(
	missingLines[1].text == "Tweaks Forever could not start. Reinstall Tweaks Forever to fix this.",
	missingLines[1].text
)

-- ForeverCore before 1.12.0 has the API kit but no SettingsSections, which the settings page's headings call.
local noSections = Load({ APIKit = { Hub = function() end, NotReady = function() end } })
assert(noSections.broken == true, "a ForeverCore without SettingsSections stops the addon")

local ready, readyLines = Load({
	APIKit = { Hub = function() end, NotReady = function() end },
	SettingsSections = { Register = function() end },
})
assert(ready.broken == nil, "a ForeverCore with every member this addon calls runs it")
assert(#readyLines == 0, "and says nothing")

local absent, absentLines = Load(nil, false)
assert(absent.broken == true, "a missing ForeverCore folder stops the addon")
assert(#absentLines == 1, "a missing ForeverCore folder gives exactly one error line")
assert(
	absentLines[1].text
		== (
			"Tweaks Forever needs ForeverCore. Install it from CurseForge, "
			.. "or choose Reinstall on ForeverCore in the CurseForge app."
		),
	absentLines[1].text
)

local disabled, disabledLines = Load(nil, true, false)
assert(disabled.broken == true, "an installed but disabled ForeverCore stops the addon")
assert(#disabledLines == 1, "a disabled ForeverCore gives exactly one error line")
assert(
	disabledLines[1].text == "Tweaks Forever: ForeverCore is turned off. Enable it in the AddOns list to fix this.",
	disabledLines[1].text
)

print("core_dependency_spec: ok")
