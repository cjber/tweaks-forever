---@type string, TFNamespace
local _, ns = ...

local KEY = "lootSparkles"
-- ForeverLootSparkles uses these same client settings for the native quest object effect.
local WANTED = {
	{ "outlineModeShowLootEffectWhenDisabled", "1" },
	{ "graphicsOutlineMode", "0" },
	{ "raidGraphicsOutlineMode", "0" },
	{ "OutlineEngineMode", "0" },
	{ "RAIDOutlineEngineMode", "0" },
}
local watched = { graphicsquality = true, raidgraphicsquality = true }
for _, setting in ipairs(WANTED) do
	watched[setting[1]:lower()] = true
end

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Show quest item sparkles",
	tooltip = "Shows the game's sparkles on lootable quest objects by turning outline mode off, including in raids. "
		.. "Your previous graphics settings return when you switch this off. "
		.. "Restart the game to remove sparkles; /reload is not enough.",
	default = false,
	conflicts = { { addon = "ForeverLootSparkles", title = "Forever Loot Sparkles" } },
})

local applying = false
local pending = false
---@type FunctionContainer?
local timer

local function Apply()
	if ns.ConflictOf(KEY) then
		return
	end
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = false
	local active = ns.Active(KEY)
	local saved = ns.db.lootSparklesSaved
	if active then
		saved = saved or {}
		ns.db.lootSparklesSaved = saved
		for _, setting in ipairs(WANTED) do
			local cvar = setting[1]
			if saved[cvar] == nil then
				saved[cvar] = GetCVar(cvar)
			end
		end
	end
	applying = true
	-- Graphics settings can update their engine setting too, so restore the engine values last.
	for _, setting in ipairs(WANTED) do
		local cvar, wanted = setting[1], setting[2]
		local current = GetCVar(cvar)
		if current then
			local value = active and wanted or saved and saved[cvar]
			if value and value ~= current then
				SetCVar(cvar, value)
			end
		end
	end
	applying = false
	if not active then
		ns.db.lootSparklesSaved = nil
	end
end

local function Schedule(delay)
	if timer then
		timer:Cancel()
		timer = nil
	end
	if ns.Active(KEY) then
		timer = C_Timer.NewTimer(delay, function()
			timer = nil
			Apply()
		end)
	end
end

ns.Init(function()
	ns.OnSettingChanged(KEY, function()
		Schedule(1)
		Apply()
	end)
	ns.On("CVAR_UPDATE", function(cvar)
		if not applying and watched[cvar:lower()] then
			Schedule(1)
		end
	end)
	ns.On("PLAYER_REGEN_ENABLED", function()
		if pending then
			Apply()
		end
	end)
	Apply()
	Schedule(5)
end)
