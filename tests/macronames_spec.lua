local features, initializers, events = {}, {}, {}
local db = {}
local ns = {
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
	Active = function(key)
		return db[key]
	end,
	On = function(event, fn)
		events[event] = fn
	end,
}

local function Button(named)
	local name = named and {
		alpha = 1,
		SetAlpha = function(self, alpha)
			self.alpha = alpha
		end,
	}
	return { Name = name }
end

local registry = { frames = { Button(true), Button(true), Button(false) } }
function registry:RegisterFrame(frame)
	table.insert(self.frames, frame)
end
function registry:ForEachFrame(fn)
	for _, frame in ipairs(self.frames) do
		fn(frame)
	end
end

local changed
local env = setmetatable({
	ActionBarButtonEventsFrame = registry,
	hooksecurefunc = function()
		error("the action bars' events frame is never hooked")
	end,
	Settings = {
		SetOnValueChangedCallback = function(variable, fn)
			assert(variable == "TweaksForever_hideMacroNames")
			changed = fn
		end,
	},
}, { __index = _G })
env._G = env
setfenv(assert(loadfile("MacroNames.lua")), env)("TweaksForever", ns)
local feature = features.hideMacroNames
assert(feature.default == false and feature.category == "Interface" and #initializers == 1)

local first, second = registry.frames[1], registry.frames[2]
initializers[1]()
assert(first.Name.alpha == 1 and second.Name.alpha == 1, "off by default leaves names alone")

db.hideMacroNames = true
changed()
assert(first.Name.alpha == 0 and second.Name.alpha == 0, "switching on hides names at once")

-- A load-on-demand bar registers its buttons as it loads.
local late = Button(true)
registry:RegisterFrame(late)
events.ADDON_LOADED("Blizzard_GamepadActionBars")
assert(late.Name.alpha == 0, "a button made later is hidden once its addon loads")

-- Somebody else's alpha on a button this never faded is left as it was.
local other = Button(true)
other.Name.alpha = 0.5
table.insert(registry.frames, other)
db.hideMacroNames = false
changed()
assert(first.Name.alpha == 1 and second.Name.alpha == 1 and late.Name.alpha == 1, "switching off restores")
assert(other.Name.alpha == 0.5)
print("macronames: ok")
