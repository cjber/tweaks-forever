-- Logs in with Core and WhatsNew loaded, the saved table and the addon's version given, and returns what went to
-- chat and the saved table after.
-- ForeverCore provides the per-addon services Core/Core.lua registers and calls; this stand-in records what it is
-- handed and makes no frame of its own, so the addon's own frames keep their order.
-- Each login runs the shared files in its own environment. The chunk is parsed once: executing it again still builds
-- every local and table fresh, and parsing the same file seven times only measured the parser.
local chunks = {}
local function Chunk(path)
	local chunk = chunks[path]
	if not chunk then
		chunk = assert(loadfile(path))
		chunks[path] = chunk
	end
	return chunk
end

-- UI/WhatsNew.lua is read and parsed once per form: the packager's keyword is substituted in the packaged copy only.
local sources = {}
local function Source(packaged, version)
	local key = packaged and "packaged" or "source"
	local chunk = sources[key]
	if not chunk then
		local source = assert(io.open("UI/WhatsNew.lua")):read("*a")
		if packaged then
			source = source:gsub("@project%-version@", version)
		end
		chunk = assert(loadstring(source))
		sources[key] = chunk
	end
	return chunk
end

local function Login(saved, version, on, packaged, headlineVersion)
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
	Chunk("Locales/enUS.lua")("TweaksForever", ns)
	env.ForeverCore = {
		Register = function()
			return {
				SafeCall = function(_, fn, ...)
					return pcall(fn, ...)
				end,
				Attach = function() end,
				Report = {
					Command = function()
						return false
					end,
				},
			}
		end,
	}
	setfenv(Chunk("Core/Core.lua"), env)("TweaksForever", ns)
	setfenv(Source(packaged, version), env)("TweaksForever", ns)
	-- A test version is one the addon does not ship, so name the release whose headline it carries for this login.
	local shippedVersion = ns.WHATS_NEW_VERSION
	if headlineVersion then
		ns.WHATS_NEW_VERSION = headlineVersion
	end
	if on == false then
		env.TweaksForeverDB = env.TweaksForeverDB or {}
		env.TweaksForeverDB.whatsNew = false
	end
	frames[2].callback()
	ns.WHATS_NEW_VERSION = shippedVersion
	return printed, env.TweaksForeverDB, ns
end

-- A first install, with no saved table at all (Forever may not load it): silent, and the version is kept.
local printed, db = Login(nil, "0.6.0")
assert(#printed == 0 and db.lastVersion == "0.6.0")

-- The same version again: silent.
printed, db = Login({ lastVersion = "0.6.0" }, "0.6.0")
assert(#printed == 0 and db.lastVersion == "0.6.0")

-- A new version with a headline: one line, once.
local ns
printed, db, ns = Login({ lastVersion = "0.5.0" }, "0.6.0", nil, nil, "0.6.0")
assert(#printed == 1 and db.lastVersion == "0.6.0")
assert(printed[1] == "|cffffd200Tweaks Forever:|r updated to 0.6.0. " .. ns.WHATS_NEW, printed[1])
local shippedVersion, shippedHeadline = ns.WHATS_NEW_VERSION, ns.WHATS_NEW
printed = Login(db, "0.6.0")
assert(#printed == 0)

-- A maintenance release (a core sync's entry above a normal one) has no headline: silent, but remembered.
printed, db = Login({ lastVersion = "0.6.0" }, "0.6.1", nil, nil, "0.6.0")
assert(#printed == 0, "a maintenance release says nothing new")
assert(db.lastVersion == "0.6.1", "a maintenance release is still remembered")

-- The setting off: silent, and the version still moves on so turning it back on says nothing stale.
printed, db = Login({ lastVersion = "0.5.0" }, "0.6.0", false)
assert(#printed == 0 and db.lastVersion == "0.6.0")

-- A dev checkout's unsubstituted version: silent and not saved.
printed, db = Login({ lastVersion = "0.5.0" }, "@project-version@")
assert(#printed == 0 and db.lastVersion == "0.5.0")

-- The packager replaces its keywords in Lua too; a release must still announce and save its version.
printed, db = Login({ lastVersion = "v0.7.3" }, "v0.7.4", true, true, "v0.7.4")
assert(#printed == 1 and db.lastVersion == "v0.7.4", "packaged release still announces its update")

-- The newest release with a bold lead, skipping the maintenance entries a core sync adds above it. Each entry is its
-- heading and the text up to the next versioned heading.
local function Releases(text)
	local found = {}
	local nextSearch = 1
	while true do
		local start, finish, release = text:find("\n## %[(%d+%.%d+%.%d+)%] %- %d%d%d%d%-%d%d%-%d%d\n", nextSearch)
		if not start then
			return found
		end
		local following = text:find("\n## %[", finish + 1)
		found[#found + 1] = { version = release, body = text:sub(finish + 1, (following or #text + 1) - 1) }
		nextSearch = finish + 1
	end
end

-- The packager ships text files with CRLF line endings, so the packaged CHANGELOG.md is read the same way.
local function Headline(text)
	for _, release in ipairs(Releases("\n" .. (text:gsub("\r\n", "\n")))) do
		local headline = release.body:match("%- %*%*(.-)%*%*")
		if headline then
			return release.version, headline
		end
	end
end

-- The shipped headline and version are the newest release's with a bold lead, so a release that forgets to rewrite
-- them fails here instead of announcing the release before it. This is also where the packager's version check lives.
local changelog = assert(io.open("CHANGELOG.md")):read("*a")
local newestVersion, newestHeadline = Headline(changelog)
assert(
	newestVersion == shippedVersion,
	("UI/WhatsNew.lua is release %s, CHANGELOG.md's newest headline release is %s"):format(
		tostring(shippedVersion),
		tostring(newestVersion)
	)
)
assert(newestHeadline == shippedHeadline, "UI/WhatsNew.lua carries that release's headline")

-- A core sync's maintenance entry has no bold lead, so the headline above it is the one a player still sees.
local maintenance = table.concat({
	"## [9.9.9] - 2026-11-12",
	"",
	"<!-- forever-core-sync -->",
	"",
	"- Ships with the same shared code as your other Forever addons, so they keep working together.",
	"",
	"## [9.9.8] - 2026-11-11",
	"",
	"- **A real headline.** What it says.",
}, "\n")
local maintenanceVersion, maintenanceHeadline = Headline(maintenance)
assert(maintenanceVersion == "9.9.8", "a maintenance entry on top is skipped for the newest version")
assert(maintenanceHeadline == "A real headline.", "and for its headline")

print("whatsnew: ok")
