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
			return {
				width = atlas == "SideInProgressquesticon" and 16 or 32,
				height = atlas == "SideInProgressquesticon" and 18 or 32,
			}
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
	function pin.texture:SetAtlas(atlas)
		self.atlas = atlas
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
local manual = Pin(6, false)
manual.isManualIcon = true
manual.width = 8
map.utils.SetDrawOrder(manual)
assert(manual.width == 8 and not manual.texture.atlas, "townsfolk unchanged")
enabled = false
refresh()
assert(frames.a.texture.original == "original-pickup" and frames.a.width == 8, "toggle restores originals")
enabled = true
refresh()
assert(frames.a.texture.atlas == "questnormal" and frames.a.width == 24)
print("questiepins: native art, aspect, zoom, reuse and restoration verified")
