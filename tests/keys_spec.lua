-- Escape closes our panels and every other key reaches the game, in and out of combat. SetPropagateKeyboardInput
-- is blocked for addon code in combat, so the stub raises if it is called then.
local combat = false
local timers = {}
local ns = {}
local env = setmetatable({
	InCombatLockdown = function()
		return combat
	end,
	C_Timer = {
		After = function(_, fn)
			timers[#timers + 1] = fn
		end,
	},
}, { __index = _G })
setfenv(assert(loadfile("UI/Keys.lua")), env)("TweaksForever", ns)

local function Panel()
	local panel = { scripts = {}, hooks = {}, shown = false, propagate = false, keyboard = false }
	function panel:SetScript(event, fn)
		self.scripts[event] = fn
	end
	function panel:HookScript(event, fn)
		self.hooks[event] = fn
	end
	function panel:SetPropagateKeyboardInput(value)
		assert(not combat, "SetPropagateKeyboardInput is blocked in combat")
		self.propagate = value
	end
	function panel:GetPropagateKeyboardInput()
		return self.propagate
	end
	function panel:EnableKeyboard(value)
		self.keyboard = value
	end
	function panel:Show()
		self.shown = true
		if self.hooks.OnShow then
			self.hooks.OnShow(self)
		end
	end
	function panel:Hide()
		self.shown = false
	end
	return panel
end

local function RunTimers()
	local due = timers
	timers = {}
	for _, fn in ipairs(due) do
		fn()
	end
end

local panel = Panel()
ns.EscapeCloses(panel)
assert(panel.keyboard and panel.propagate, "a new panel passes keys on from the start")
panel:Show()
panel.scripts.OnKeyDown(panel, "W")
assert(panel.shown and panel.propagate, "a movement key reaches the game")
panel.scripts.OnKeyDown(panel, "ESCAPE")
assert(not panel.shown and not panel.propagate, "Escape closes only the panel, not the game menu as well")
RunTimers()
assert(panel.propagate, "propagation comes back on the next frame")

-- In combat nothing is set, keys still reach the game, and Escape still closes the panel.
panel:Show()
combat = true
panel.scripts.OnKeyDown(panel, "W")
assert(panel.shown and panel.propagate, "a key in combat reaches the game")
panel.scripts.OnKeyDown(panel, "ESCAPE")
assert(not panel.shown, "Escape in combat closes the panel")

-- Escape just before a pull: propagation could not come back, so the panel reopened in combat closes on its first
-- key rather than holding the keyboard.
combat = false
panel:Show()
panel.scripts.OnKeyDown(panel, "ESCAPE")
combat = true
RunTimers()
assert(not panel.propagate)
panel:Show()
panel.scripts.OnKeyDown(panel, "W")
assert(not panel.shown, "a panel that would swallow keys in combat steps aside")
combat = false
panel:Show()
assert(panel.propagate, "showing it out of combat passes keys on again")

-- A panel built in combat cannot set propagation, so it starts closed to keys and steps aside on the first one.
local late = Panel()
combat = true
ns.EscapeCloses(late)
late:Show()
late.scripts.OnKeyDown(late, "W")
assert(not late.shown and late.keyboard)
combat = false
print("keys: Escape closes panels and every other key reaches the game, in and out of combat: ok")
