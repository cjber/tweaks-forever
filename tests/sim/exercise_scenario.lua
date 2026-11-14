-- luacheck: read globals scenario ADDON
-- The runner's own exercise with ForeverCore loaded, so the addon's UI builds: the TOC depends on it, and without
-- the checkout every file stops at its dependency guard. Declaring the scenario replaces the runner's automatic one,
-- so it passes the same addon list to walk only this addon's widgets.
local core = os.getenv("FOREVER_CORE") or "../forever-core"
scenario(
	"every surface, in and out of combat and across a reload",
	{ addons = { { core, "ForeverCore" } } },
	function(sim)
		sim:exercise({ addons = { ADDON } })
	end
)
