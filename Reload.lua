---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "reloadCommand",
	category = "Interface",
	name = "Type /rl to reload the interface",
	tooltip = "A shorter /reload. Switching this on or off takes effect after the next reload.",
	default = true,
	conflicts = { { addon = "Leatrix_Plus" } },
})

-- Slash commands cannot be unregistered, so the setting is read once.
ns.Init(function()
	if ns.Active("reloadCommand") then
		SLASH_TWEAKSFOREVER_RELOAD1 = "/rl"
		SlashCmdList.TWEAKSFOREVER_RELOAD = function()
			C_UI.Reload()
		end
	end
end)
