---@type string, TFNamespace
local addonName, ns = ...
local L = ns.L

ns.Feature({
	key = "whatsNew",
	category = "Interface",
	name = "Tell me what's new after an update",
	tooltip = "The first time you log in after Tweaks Forever updates, one line in chat says what changed.",
	default = true,
})

-- The headline of this version's changes in CHANGELOG.md, said once in chat after an update. The version is the
-- TOC's, filled in by the packager; rewrite this line with each release's entry.
ns.WHATS_NEW = L["Ready for translation, and dungeon entrances suggest Shortest Path Forever for the walk."]

-- The packager's placeholder, left as is in a dev checkout.
local UNPACKAGED = "@project-version@"

---@class TFWhatsNew
local Model = {}
ns.WhatsNew = Model

-- The chat line for coming from `seen` to `version`, if any: none on a first install or the same version.
---@param seen string?
---@param version string
---@return string?
function Model.Message(seen, version)
	if seen and seen ~= version then
		return L["updated to %s. %s"]:format(version, ns.WHATS_NEW)
	end
end

-- Saved variables may not load on this client, so the saved table can be a fresh one every login.
ns.Init(function()
	local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
	if not version or version == UNPACKAGED then
		return
	end
	local message = Model.Message(ns.db.lastVersion, version)
	if message and ns.Active("whatsNew") then
		ns.Print(message)
	end
	ns.db.lastVersion = version
end)
