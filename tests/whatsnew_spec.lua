-- Logs in with Core and WhatsNew loaded, the saved table and the addon's version given, and returns what went to
-- chat and the saved table after.
local function Login(saved, version, on, packaged)
	local printed, frames = {}, {}
	local env = setmetatable({
		TweaksForeverDB = saved,
		C_AddOns = {
			GetAddOnMetadata = function(addon, field)
				assert(addon == "TweaksForever" and field == "Version")
				return version
			end,
		},
		CreateFrame = function()
			local frame = { RegisterEvent = function() end }
			function frame:SetScript(_, fn)
				self.callback = fn
			end
			frames[#frames + 1] = frame
			return frame
		end,
		geterrorhandler = function()
			return error
		end,
		print = function(message)
			printed[#printed + 1] = message
		end,
	}, { __index = _G })
	local ns = {}
	assert(loadfile("Locales/enUS.lua"))("TweaksForever", ns)
	setfenv(assert(loadfile("Core/Core.lua")), env)("TweaksForever", ns)
	local source = assert(io.open("UI/WhatsNew.lua")):read("*a")
	if packaged then
		source = source:gsub("@project%-version@", version)
	end
	setfenv(assert(loadstring(source)), env)("TweaksForever", ns)
	if on == false then
		env.TweaksForeverDB = env.TweaksForeverDB or {}
		env.TweaksForeverDB.whatsNew = false
	end
	frames[2].callback()
	return printed, env.TweaksForeverDB, ns
end

-- A first install, with no saved table at all (Forever may not load it): silent, and the version is kept.
local printed, db = Login(nil, "0.6.0")
assert(#printed == 0 and db.lastVersion == "0.6.0")

-- The same version again: silent.
printed, db = Login({ lastVersion = "0.6.0" }, "0.6.0")
assert(#printed == 0 and db.lastVersion == "0.6.0")

-- A new version: one line with the headline, once.
local ns
printed, db, ns = Login({ lastVersion = "0.5.0" }, "0.6.0")
assert(#printed == 1 and db.lastVersion == "0.6.0")
assert(printed[1] == "|cffffd200Tweaks Forever:|r updated to 0.6.0. " .. ns.WHATS_NEW, printed[1])
printed = Login(db, "0.6.0")
assert(#printed == 0)

-- The setting off: silent, and the version still moves on so turning it back on says nothing stale.
printed, db = Login({ lastVersion = "0.5.0" }, "0.6.0", false)
assert(#printed == 0 and db.lastVersion == "0.6.0")

-- A dev checkout's unsubstituted version: silent and not saved.
printed, db = Login({ lastVersion = "0.5.0" }, "@project-version@")
assert(#printed == 0 and db.lastVersion == "0.5.0")

-- The packager replaces its keywords in Lua too; a release must still announce and save its version.
printed, db = Login({ lastVersion = "v0.7.3" }, "v0.7.4", true, true)
assert(#printed == 1 and db.lastVersion == "v0.7.4", "packaged release still announces its update")

-- The headline is the newest release's: a release that adds a CHANGELOG entry without rewriting it fails here.
local changelog = assert(io.open("CHANGELOG.md")):read("*a")
local newest = changelog:match("\n## %[(%d+%.%d+%.%d+)%]")
assert(
	newest and ns.WHATS_NEW_VERSION == newest,
	("UI/WhatsNew.lua is %s's headline, CHANGELOG.md's newest release is %s"):format(
		tostring(ns.WHATS_NEW_VERSION),
		tostring(newest)
	)
)

print("whatsnew: ok")
