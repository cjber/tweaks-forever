local _, ns = ...

-- The game refuses to load this addon when ForeverCore is absent (## Dependencies), but an older ForeverCore still
-- loads. ForeverCore's interface version stays at 1 while it adds members, so a core is out of date when a member this
-- addon calls is missing, never because of a version comparison. The API kit arrived after API 1 (ForeverCore 1.1.0)
-- and Core/API.lua builds this addon's own API on its Hub and NotReady, so a core without them stops the addon's own
-- files here. The settings page's headings use SettingsSections (ForeverCore 1.12.0), so a core without it stops
-- the addon too, before UI/Settings.lua fails on the first heading. Everything else this addon calls (its Register
-- and OpenSettingsPanel) came with API 1, which a core carrying the kit has. The warning itself is
-- Core/ForeverRequire.lua, shared by every Forever addon: one line on screen, never a chat message, naming the addon
-- to update and never ForeverCore.
local ready = ForeverCore ~= nil
	and type(ForeverCore.APIKit) == "table"
	and type(ForeverCore.APIKit.Hub) == "function"
	and type(ForeverCore.APIKit.NotReady) == "function"
	and type(ForeverCore.SettingsSections) == "table"
	and type(ForeverCore.SettingsSections.Register) == "function"

ns.ForeverRequire(ready, { key = "TWEAKSFOREVER", "/tweaks", "/tweaksforever" })
