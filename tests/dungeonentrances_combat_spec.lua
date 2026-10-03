-- Exercise the provider against the protected MapCanvas contract: AcquirePin and
-- RemoveAllPinsByTemplate are forbidden while combat lockdown is active.
local combat, acquired, removed = false, 0, 0
local provider, onEvent
local mapEvents = 0
local map = {
	IsShown = function()
		return true
	end,
	GetMapID = function()
		return 1427
	end,
	EnumeratePinsByTemplate = function()
		return function() end
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
	AddDataProvider = function(self, value)
		provider = value
		provider.GetMap = function()
			return self
		end
	end,
	HookScript = function() end,
}
local ns = {
	Feature = function() end,
	Init = function(fn)
		fn()
	end,
	Active = function()
		return true
	end,
}
local eventFrame = {
	RegisterEvent = function(self)
		self.registered = true
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
	MapCanvasDataProviderMixin = {
		RegisterEvent = function()
			mapEvents = mapEvents + 1
		end,
		OnShow = function() end,
	},
	GetCVarBool = function()
		return true
	end,
	BaseMapPoiPinMixin = {
		CreateSubPin = function()
			return {}
		end,
	},
}, { __index = _G })
assert(loadfile("Data/DungeonEntrances.lua"))("TweaksForever", ns)
setfenv(assert(loadfile("Map/DungeonEntrances.lua")), env)("TweaksForever", ns)

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
-- The map's own toggle redraws through our frame, never through the map's shared event counts.
onEvent(eventFrame, "CVAR_UPDATE", "questPOI")
assert(removed == 2, "another cvar redrew the entrances")
onEvent(eventFrame, "CVAR_UPDATE", "showDungeonEntrancesOnMap")
assert(removed == 3, "the entrance toggle did not redraw")
provider:OnShow()
assert(mapEvents == 0, "showing the map registered an event through the map")
print("dungeonentrances_combat: protected MapCanvas refresh contract passed")
