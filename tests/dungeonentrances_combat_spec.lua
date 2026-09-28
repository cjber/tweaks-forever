-- Exercise the provider against the protected MapCanvas contract: AcquirePin and
-- RemoveAllPinsByTemplate are forbidden while combat lockdown is active.
local combat, acquired, removed = false, 0, 0
local provider, onEvent
local pins = {}
local map = {
	IsShown = function()
		return true
	end,
	GetMapID = function()
		return 1427
	end,
	GetCanvas = function()
		return {
			GetWidth = function()
				return 1000
			end,
			GetHeight = function()
				return 1000
			end,
		}
	end,
	GetScaleForMinZoom = function()
		return 1
	end,
	EnumeratePinsByTemplate = function(_, template)
		local index = 0
		return function()
			index = index + 1
			local pin = pins[template] and pins[template][index]
			return pin
		end
	end,
	RemoveAllPinsByTemplate = function(_, template)
		assert(not combat, "RemoveAllPinsByTemplate is protected in combat: " .. template)
		removed = removed + 1
	end,
	AcquirePin = function(_, template)
		assert(not combat, "AcquirePin is protected in combat: " .. template)
		acquired = acquired + 1
		return {}
	end,
	AddDataProvider = function(_, value)
		provider = value
		provider.GetMap = function()
			return _G.__dungeonCombatMap
		end
	end,
	HookScript = function() end,
}
_G.__dungeonCombatMap = map
local ns = {
	Feature = function() end,
	Init = function(fn)
		fn()
	end,
	L = {},
	RaidInstances = {},
	DungeonEntrances = { [1427] = {} },
	Active = function()
		return true
	end,
	NavigateHint = function()
		return "hint"
	end,
	Suggestion = function() end,
	Navigate = function() end,
}
local eventFrame = {
	RegisterEvent = function(self)
		self.registered = true
	end,
	UnregisterEvent = function(self)
		self.registered = false
	end,
	SetScript = function(_, _, fn)
		onEvent = fn
	end,
}
local env = setmetatable({
	WorldMapFrame = map,
	InCombatLockdown = function()
		return combat
	end,
	CreateFrame = function()
		return eventFrame
	end,
	CreateFromMixins = function(mixin)
		return setmetatable({}, { __index = mixin })
	end,
	CVarMapCanvasDataProviderMixin = {
		Init = function() end,
		IsCVarSet = function()
			return true
		end,
	},
	BaseMapPoiPinMixin = {
		CreateSubPin = function()
			return {}
		end,
		OnAcquired = function() end,
		OnMouseEnter = function() end,
	},
	CreateVector2D = function(x, y)
		return { x = x, y = y }
	end,
	GetRealZoneText = function(instance)
		return "instance " .. instance
	end,
	C_Map = {
		GetAreaInfo = function(area)
			return "area " .. area
		end,
	},
	CreateAtlasMarkup = function(atlas)
		return atlas
	end,
	GameTooltip_AddDisabledLine = function() end,
	GetAppropriateTooltip = function()
		return {}
	end,
	L = {},
}, { __index = _G })
assert(loadfile("Data/DungeonEntrances.lua"))("TweaksForever", ns)
setfenv(assert(loadfile("DungeonEntrances.lua")), env)("TweaksForever", ns)

-- A refresh in combat neither removes old pins nor acquires fresh ones.
combat = true
provider:RefreshAllData()
assert(removed == 0 and acquired == 0, "combat refresh touched protected pin manager")
assert(eventFrame.registered, "combat refresh did not defer until regen")

-- Repeated refreshes remain deferred, then one regen event rebuilds once.
provider:RefreshAllData()
assert(removed == 0 and acquired == 0, "repeated combat refresh touched pin manager")
combat = false
onEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(removed == 1, "regen did not remove stale pins")
-- A later combat must still receive its regen event.
combat = true
provider:RefreshAllData()
combat = false
if eventFrame.registered then
	onEvent(eventFrame, "PLAYER_REGEN_ENABLED")
end
assert(removed == 2, "second combat never rebuilt deferred pins")
print("dungeonentrances_combat: protected MapCanvas refresh contract passed")
