---@type string, TFNamespace
local addonName, ns = ...

if ns.broken then
	return
end
local L = ns.L

ns.Feature({
	key = "whatsNew",
	category = "Interface",
	name = "What's new after an update",
	tooltip = "The first time you log in after Tweaks Forever updates, one line in chat says what changed.",
	default = true,
})

-- The newest release in CHANGELOG.md with a bold headline, and that headline, said once in chat after an update. A
-- core sync's maintenance entry has no headline, so these stay on the release before it: an update to a maintenance
-- version says nothing new but still moves the remembered version on. Rewrite both lines for each release that has a
-- headline (whatsnew_spec checks them against CHANGELOG.md).
ns.WHATS_NEW_VERSION = "2.6.7"
ns.WHATS_NEW = L["The players who helped are on the Thanks page."]

-- The packager's placeholder, left as is in a dev checkout.
local UNPACKAGED = "@" .. "project-version@"

---@class TFWhatsNew
local Model = {}
ns.WhatsNew = Model

-- The chat line for coming from `seen` to `version`, if any: none on a first install, the same version, or a
-- maintenance release, whose version has no headline.
---@param seen string?
---@param version string
---@return string?
function Model.Message(seen, version)
	if seen and seen ~= version and version == ns.WHATS_NEW_VERSION then
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
