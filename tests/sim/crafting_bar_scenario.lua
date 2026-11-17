-- luacheck: read globals scenario ADDON
-- #617: the option fades the anchor Blizzard's own Professions crafting page parks the player cast bar on, once
-- the window loads on demand. Switching it on and off is covered by tests/craftingbar_spec.lua.
scenario("Hide the crafting bar fades the Professions cast bar anchor", function(sim)
	dofile("tests/sim/forever_core.lua").install(sim)
	sim.world.professions = { { skillLineID = 129, name = "First Aid", skill = 1, max = 75 } }
	sim:login()
	local ns
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == ADDON then
			ns = entry.ns
		end
	end
	assert(ns, "Tweaks loaded")
	ns.db.hideCraftingBar = true
	local host = sim:openProfessions(129)
	local anchor = assert(host.CraftingPage.OverlayCastBarAnchor, "the crafting page has its cast bar anchor")
	assert(anchor:GetAlpha() == 0, "the anchor fades once the window loads")
	sim:expectNoErrors(ADDON)
end)
