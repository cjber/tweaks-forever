-- Run from the repository root: luajit tests/core_dependency_spec.lua
-- Tweaks Forever requires ForeverCore. The game already refuses to load the addon when ForeverCore is absent; this
-- spec covers the one-line stop for a ForeverCore older than API 1 or without the APIKit that arrived in 1.1.0.
local function Require(foreverCore)
	local lines = {}
	local env = {
		UIErrorsFrame = {
			AddMessage = function(_, text, red, green, blue)
				lines[#lines + 1] = { text = text, red = red, green = green, blue = blue }
			end,
		},
		ForeverCore = foreverCore,
	}
	env._G = env
	setmetatable(env, { __index = _G })
	local addon = {
		L = setmetatable({}, {
			__index = function(_, key)
				return key
			end,
		}),
	}
	setfenv(assert(loadfile("Core/Require.lua")), env)("TweaksForever", addon)
	return addon, lines
end

local missing, missingLines = Require(nil)
assert(missing.broken == true, "a missing ForeverCore stops the addon")
assert(#missingLines == 1 and missingLines[1].text:find("ForeverCore", 1, true), "and names it in one error line")

local old, oldLines = Require({ API = 0 })
assert(old.broken == true and #oldLines == 1, "a ForeverCore older than API 1 stops the addon too")

local noKit, noKitLines = Require({ API = 1 })
assert(noKit.broken == true and #noKitLines == 1, "a ForeverCore without APIKit stops the addon too")

local ready, readyLines = Require({ API = 1, APIKit = {} })
assert(ready.broken == nil, "API 1 with APIKit runs the addon")
assert(#readyLines == 0, "and says nothing")

print("core_dependency_spec: ok")
