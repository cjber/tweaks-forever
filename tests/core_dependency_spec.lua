-- Run from the repository root: luajit tests/core_dependency_spec.lua
-- Tweaks Forever requires ForeverCore. Core/Require.lua checks the members this addon calls and hands the answer to
-- Core/ForeverRequire.lua, the shared warning ForeverCore's own tests cover. This spec covers the addon's half: a core
-- missing a member stops the addon's own files with one line in the error frame, and a complete one runs silently.
local function Load(foreverCore)
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
				end
			end,
			GetNumAddOns = function()
				return 0
			end,
			GetAddOnInfo = function() end,
			IsAddOnLoaded = function() end,
			GetAddOnEnableState = function() end,
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

local ready, readyLines = Load({ APIKit = { Hub = function() end, NotReady = function() end } })
assert(ready.broken == nil, "a ForeverCore with every member this addon calls runs it")
assert(#readyLines == 0, "and says nothing")

print("core_dependency_spec: ok")
