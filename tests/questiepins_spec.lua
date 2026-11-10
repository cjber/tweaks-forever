local init, refresh, enabled = nil, nil, true
local ns = {
	Feature = function(f)
		assert(f.default)
	end,
	Init = function(fn)
		init = fn
	end,
	OnSettingChanged = function(_, fn)
		refresh = fn
	end,
	Active = function()
		return enabled
	end,
}
local frames = {}
local map = {
	questIdFrames = { [1] = { a = "a", b = "b" } },
	GetScaleValue = function()
		return 0.7
	end,
	utils = {},
}
function map.utils.SetDrawOrder() end
function map.utils.RescaleIcon(ref)
	local frame = type(ref) == "string" and frames[ref] or ref
	frame:SetSize(8, 8)
end
local hooks = 0
local ATLAS_SIZE = {
	SideInProgressquesticon = { 16, 18 },
}
local env = setmetatable({
	_G = frames,
	Questie = { usedIcons = { [6] = "original-pickup", [8] = "original-turnin" } },
	QuestieLoader = {
		ImportModule = function()
			return map
		end,
	},
	C_Texture = {
		GetAtlasInfo = function(atlas)
			local size = ATLAS_SIZE[atlas] or { 32, 32 }
			return { width = size[1], height = size[2] }
		end,
	},
	hooksecurefunc = function(object, key, fn)
		local original = object[key]
		object[key] = function(...)
			original(...)
			fn(...)
		end
		hooks = hooks + 1
	end,
}, { __index = _G })
local function Pin(kind, mini)
	local pin = { data = { Icon = kind }, miniMapIcon = mini, texture = { alpha = 0.4 }, tooltip = "kept" }
	function pin:SetSize(w, h)
		self.width, self.height = w, h
	end
	-- As the client does: an atlas leaves its place on the sheet as the coordinates until they are set again.
	function pin.texture:SetAtlas(atlas)
		self.atlas, self.crop = atlas, atlas
	end
	function pin.texture:SetTexCoord()
		self.crop = nil
	end
	function pin.texture:GetVertexColor()
		return 1, 1, 1, self.alpha
	end
	function pin.texture:SetVertexColor(r, _, _, a)
		self.red, self.alpha = r, a
	end
	function pin:UpdateTexture(texture)
		self.texture.atlas = nil
		self.texture.original = texture
		self:SetSize(8, 8)
	end
	return pin
end
frames.a, frames.b = Pin(6, false), Pin(8, true)
-- Questie's pin module can be absent, or not shaped as this replaces it: nothing is hooked, and loading never errors.
local function Probe(module)
	local before = hooks
	env.QuestieLoader = {
		ImportModule = function()
			return module
		end,
	}
	setfenv(assert(loadfile("Quests/QuestiePins.lua")), env)("TweaksForever", ns)
	init()
	assert(hooks == before, "nothing is hooked without Questie's pin module")
end
Probe(nil)
Probe(false)
Probe({})
Probe({ utils = 1 })
Probe({ utils = {} })
env.QuestieLoader = {
	ImportModule = function()
		return map
	end,
}
setfenv(assert(loadfile("Quests/QuestiePins.lua")), env)("TweaksForever", ns)
init()
assert(frames.a.texture.atlas == "questnormal" and frames.a.width == 24)
assert(frames.b.texture.atlas == "questturnin" and frames.b.width == 20)
assert(frames.b.texture.alpha == 0.4 and frames.a.tooltip == "kept", "fade and tooltip retained")
local count = hooks
refresh()
refresh()
assert(hooks == count, "pooled pins hooked only once")
frames.a.data.Icon = 12
frames.a:UpdateTexture("progress")
assert(frames.a.texture.atlas == "SideInProgressquesticon")
assert(frames.a.width / frames.a.height == 16 / 18, "non-square art preserves aspect")
frames.a.data.Icon = 6
map.utils.RescaleIcon("a", 0.1)
assert(frames.a.width == 24, "zoom cannot shrink native marker to unreadable size")
local new = Pin(2, false)
map.utils.SetDrawOrder(new)
assert(new.texture.atlas == "questobjective", "new objective pins retain their locations")

-- Daily and repeatable quests take the game's own recurring quest symbols, the client's 32x32 map art.
local daily, repeatable = Pin(10, false), Pin(11, true)
map.utils.SetDrawOrder(daily)
map.utils.SetDrawOrder(repeatable)
assert(daily.texture.atlas == "UI-QuestPoiRecurring-QuestBang", "a daily quest takes the game's recurring symbol")
assert(repeatable.texture.atlas == "UI-QuestPoiRecurring-QuestBangTurnIn", "a repeatable hand-in takes its turn-in")
assert(daily.width == 24 and daily.height == 24, "the recurring symbol keeps its square shape on the map")
assert(repeatable.width == 20 and repeatable.height == 20, "and on the minimap")
for kind, atlas in pairs({
	[13] = "UI-QuestPoiRecurring-QuestBang",
	[14] = "UI-QuestPoiRecurring-QuestBangTurnIn",
}) do
	local pin = Pin(kind, false)
	map.utils.SetDrawOrder(pin)
	assert(pin.texture.atlas == atlas, "every recurring quest kind takes the game's symbol")
end

local manual = Pin(6, false)
manual.isManualIcon = true
manual.width = 8
map.utils.SetDrawOrder(manual)
assert(manual.width == 8 and not manual.texture.atlas, "townsfolk unchanged")
new.isManualIcon = true
new:UpdateTexture("townsfolk")
map.utils.SetDrawOrder(new)
assert(not new.texture.crop, "a pin reused for a townsfolk icon draws it whole")
enabled = false
refresh()
assert(frames.a.texture.original == "original-pickup" and frames.a.width == 8, "toggle restores originals")
assert(
	not frames.a.texture.crop and not frames.b.texture.crop,
	"Questie's file is drawn whole, not at the atlas's crop"
)
enabled = true
refresh()
assert(frames.a.texture.atlas == "questnormal" and frames.a.width == 24)

-- Questie's own sliders, against their defaults: Minimap Icons at half halves the minimap symbol, a kind's slider
-- scales that kind, and the map's zoom still cannot shrink it.
local defaults = { globalScale = 0.6, globalMiniMapScale = 0.7, availableScale = 1.2 }
env.Questie.db = {
	profile = { globalScale = 0.6, globalMiniMapScale = 0.35, availableScale = 1.2 },
	defaults = { profile = defaults },
}
frames.b:UpdateTexture("original-turnin")
assert(frames.b.width == 10, "Minimap Icons at half halves the minimap symbol")
env.Questie.db.profile.availableScale = 2.4
frames.a:UpdateTexture("original-pickup")
assert(frames.a.width == 48, "a kind's own slider scales that kind")
map.utils.RescaleIcon("a", 0.1)
assert(frames.a.width == 48, "and the map's zoom still cannot shrink it")
env.Questie.db.profile.globalScale = nil
frames.a:UpdateTexture("original-pickup")
assert(frames.a.width == 48, "a setting Questie cannot read leaves the size as it was set")
print("questiepins: native art, aspect, zoom, reuse and restoration verified")
