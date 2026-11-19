local _, ns = ...

-- The game refuses to load this addon when ForeverCore is absent (## Dependencies), but an older ForeverCore still
-- loads. ForeverCore's interface version stays at 1 while it adds members, so a core is out of date when a member this
-- addon calls is missing, never because of a version comparison. The API kit arrived after API 1 (ForeverCore 1.1.0)
-- and Core/API.lua builds this addon's own API on its Hub and NotReady, so a core without them stops the addon's own
-- files here. Everything else this addon calls (its Register, OpenSettingsPanel and Family) came with API 1, which a
-- core carrying the kit has. The warning itself is Core/ForeverRequire.lua, shared by every Forever addon: one line on
-- screen, never a chat message, naming the addon to update and never ForeverCore.
local ready = ForeverCore ~= nil
	and type(ForeverCore.APIKit) == "table"
	and type(ForeverCore.APIKit.Hub) == "function"
	and type(ForeverCore.APIKit.NotReady) == "function"

-- UI/Settings.lua's slash words; the pin gate (forever_tools.require_slash) keeps the two lists equal. A
-- stopped addon still answers them with the line that names the fix, as its addon compartment entry does.
ns.Slash = { key = "TWEAKSFOREVER", "/tweaks", "/tweaksforever" }

ns.ForeverRequire(ready, ns.Slash)
