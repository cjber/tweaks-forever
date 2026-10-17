-- Maps that fail on any write, and frames enough to draw on them, for the specs that put Tweaks on a map.
-- dofile("tests/strict_map.lua") returns the kit; Kit.NewMap() makes a map and Kit.Install(env) sets the client
-- globals the map files read.
--
-- A map lets through only the reads Map/MapCanvas.lua lists: a field written on it, or any other method (such as
-- AddDataProvider, AcquirePin, AddOverlayFrame, RemoveAllPinsByTemplate or HookScript), raises an error naming it.
-- That is the proof that Forever's gamepad code, walking the map's own tables, never meets a value of ours.
local Kit = {}

-- Every frame made, in order, so a spec can find one by template.
Kit.frames = {}
Kit.events = {}
Kit.combat = false

local Frame = {}
Frame.__index = function(_, key)
	local method = Frame[key]
	if method then
		return method
	end
	-- Engine methods a spec does not look at do nothing.
	if type(key) == "string" and key:match("^%u") then
		return function() end
	end
end

function Frame:SetScript(script, fn)
	self.scripts[script] = fn
end
function Frame:HookScript(script, fn)
	local before = self.scripts[script]
	self.scripts[script] = function(...)
		if before then
			before(...)
		end
		fn(...)
	end
end
function Frame:GetScript(script)
	return self.scripts[script]
end
function Frame:Run(script, ...)
	local fn = self.scripts[script]
	if fn then
		return fn(self, ...)
	end
end
function Frame:SetParent(parent)
	self.parent = parent
end
function Frame:GetParent()
	return self.parent
end
function Frame:Show()
	self.shown = true
end
function Frame:Hide()
	local was = self.shown
	self.shown = false
	if was then
		self:Run("OnHide")
	end
end
function Frame:SetShown(shown)
	if shown then
		self:Show()
	else
		self:Hide()
	end
end
function Frame:IsShown()
	return self.shown
end
-- Shown, with every parent up to the map's canvas shown, and the map visible.
function Frame:IsVisible()
	local frame = self
	while frame do
		for _, state in pairs(Kit.states) do
			if frame == state.canvas then
				return state.visible
			end
		end
		if frame.shown == false then
			return false
		end
		frame = frame.parent
	end
	return true
end
function Frame:SetScale(scale)
	self.scale = scale
end
function Frame:GetScale()
	return self.scale or 1
end
function Frame:GetEffectiveScale()
	return self.scale or 1
end
function Frame:SetSize(width, height)
	self.width, self.height = width, height
end
function Frame:GetSize()
	return self.width or 0, self.height or 0
end
function Frame:GetWidth()
	return self.width or 0
end
function Frame:GetHeight()
	return self.height or 0
end
function Frame:SetPoint(...)
	self.point = { ... }
end
function Frame:ClearAllPoints()
	self.point = nil
end
function Frame:SetFrameLevel(level)
	self.level = level
end
function Frame:GetFrameLevel()
	return self.level or 1
end
function Frame:EnableMouse(enabled)
	self.mouse = enabled
end
function Frame:SetMouseClickEnabled(enabled)
	assert(not Kit.combat, "SetMouseClickEnabled is refused in combat")
	self.mouseClicks = enabled
end
function Frame:SetPassThroughButtons(...)
	assert(not Kit.combat, "SetPassThroughButtons is refused in combat")
	self.passThrough = { ... }
end
function Frame:IsMouseOver()
	return Kit.mouseOver == self
end
function Frame:GetCenter()
	return self.centerX, self.centerY
end
function Frame:RegisterEvent(event)
	self.events[event] = true
end
function Frame:UnregisterEvent(event)
	self.events[event] = nil
end
function Frame.CreateTexture()
	return Kit.Region()
end
function Frame.CreateFontString()
	return Kit.Region()
end
function Frame.GetLeft()
	return 0
end
function Frame.GetTop()
	return 0
end

-- A texture or font string: records what it was set to.
function Kit.Region()
	local region = { shown = true }
	return setmetatable(region, {
		__index = function(_, key)
			if key == "IsShown" then
				return function(self)
					return self.shown
				end
			elseif key == "Show" then
				return function(self)
					self.shown = true
				end
			elseif key == "Hide" then
				return function(self)
					self.shown = false
				end
			elseif key == "SetShown" then
				return function(self, shown)
					self.shown = shown
				end
			elseif key == "SetVertexColor" then
				return function(self, r, g, b, a)
					self.color = { r, g, b, a }
				end
			elseif key == "SetText" then
				return function(self, text)
					self.text = text
				end
			elseif key == "SetAtlas" then
				return function(self, atlas)
					self.atlas = atlas
				end
			elseif key == "GetSize" then
				return function()
					return 32, 32
				end
			elseif key == "GetStringWidth" or key == "GetStringHeight" then
				return function()
					return 10
				end
			end
			return function() end
		end,
	})
end

-- The pieces the addon's XML templates give a frame.
local TEMPLATES = {
	TweaksForeverDungeonEntrancePinTemplate = function(frame)
		frame.Texture, frame.HighlightTexture = Kit.Region(), Kit.Region()
	end,
}

---@return table
function Kit.CreateFrame(frameType, name, parent, template)
	local frame = setmetatable({
		frameType = frameType,
		name = name,
		parent = parent,
		madeUnder = parent,
		template = template,
		scripts = {},
		events = {},
	}, Frame)
	frame.shown = true
	if template then
		assert(TEMPLATES[template], "no stub for template " .. template)(frame)
	end
	Kit.frames[#Kit.frames + 1] = frame
	return frame
end

-- The frames made from `template`, or plain frames (template false) under `parent`.
function Kit.Made(template)
	local made = {}
	for _, frame in ipairs(Kit.frames) do
		if frame.template == template then
			made[#made + 1] = frame
		end
	end
	return made
end

-- Fires an event at every frame registered for it.
function Kit.Fire(event, ...)
	for _, frame in ipairs(Kit.frames) do
		if frame.events[event] then
			frame:Run("OnEvent", event, ...)
		end
	end
end

local levels = setmetatable({
	GetValidFrameLevel = function(_, levelType)
		return ({ PIN_FRAME_LEVEL_DUNGEON_ENTRANCE = 30, PIN_FRAME_LEVEL_MAP_EXPLORATION = 20 })[levelType]
	end,
}, {
	__newindex = function(_, key)
		error("wrote the map's pin frame levels manager: " .. tostring(key), 2)
	end,
})

-- A map frame: `state` holds what it shows (mapID, zoom, scale, pinScale, visible, layer) and `state.pins` the
-- Blizzard pins it holds by template, each { x, y }.
function Kit.NewMap(state)
	state.zoom, state.scale, state.pinScale = state.zoom or 0, state.scale or 1, state.pinScale or 1
	state.visible = state.visible ~= false
	state.pins = state.pins or {}
	state.canvas = Kit.CreateFrame("Frame")
	state.canvas:SetSize(1000, 700)
	state.canvas.level = 10
	state.container = setmetatable({}, {
		__index = function(_, key)
			if key == "GetCurrentLayerIndex" then
				return function()
					return state.layer or 1
				end
			end
			error("called or read the scroll container's " .. tostring(key), 2)
		end,
		__newindex = function(_, key)
			error("wrote the scroll container's " .. tostring(key), 2)
		end,
	})
	state.mask = Kit.Region()
	-- The reads Map/MapCanvas.lua names, and nothing else.
	local reads = {
		GetMapID = function()
			return state.mapID
		end,
		GetCanvas = function()
			return state.canvas
		end,
		GetCanvasScale = function()
			return state.scale
		end,
		GetScaleForMinZoom = function()
			return 0.5
		end,
		GetCanvasZoomPercent = function()
			return state.zoom
		end,
		GetGlobalPinScale = function()
			return state.pinScale
		end,
		IsVisible = function()
			return state.visible
		end,
		IsShown = function()
			return state.visible
		end,
		GetPinFrameLevelsManager = function()
			return levels
		end,
		GetCanvasContainer = function()
			return state.container
		end,
		GetMaskTexture = function()
			return state.mask
		end,
		GetUseMaskTexture = function()
			return true
		end,
		EnumeratePinsByTemplate = function(_, template)
			assert(not template:find("^TweaksForever"), "looked for a pin of ours among the map's")
			local index, list = 0, state.pins[template] or {}
			return function()
				index = index + 1
				local pin = list[index]
				if pin then
					return {
						GetPosition = function()
							return pin.x, pin.y
						end,
						IsShown = function()
							return true
						end,
					}
				end
			end
		end,
	}
	local map = setmetatable({}, {
		__index = function(_, key)
			return reads[key] or error("called or read the map's " .. tostring(key), 2)
		end,
		__newindex = function(_, key)
			error("wrote the map's " .. tostring(key), 2)
		end,
	})
	state.map = map
	Kit.states[map] = state
	return map
end
Kit.states = {}

-- One frame of the map's view: every OnUpdate a shown frame of ours has runs once.
function Kit.Tick()
	for _, frame in ipairs(Kit.frames) do
		if frame.scripts.OnUpdate and frame:IsVisible() then
			frame:Run("OnUpdate", 0.016)
		end
	end
end

-- Closes a map: the view's frame hears its OnHide.
function Kit.Close(map)
	local state = Kit.states[map]
	state.visible = false
	for _, frame in ipairs(Kit.frames) do
		if frame.parent == state.canvas then
			frame:Run("OnHide")
		end
	end
end

function Kit.Install(env)
	env.CreateFrame = Kit.CreateFrame
	env.InCombatLockdown = function()
		return Kit.combat
	end
	env.Saturate = function(value)
		return math.max(0, math.min(1, value))
	end
	env.Lerp = function(a, b, t)
		return a + (b - a) * t
	end
	env.CreateTexturePool = function()
		local pool = { active = {} }
		function pool.Acquire()
			local texture = Kit.Region()
			pool.active[#pool.active + 1] = texture
			return texture
		end
		function pool.ReleaseAll()
			pool.active = {}
		end
		return pool
	end
	env.Mixin = function(object, ...)
		for _, mixin in ipairs({ ... }) do
			for key, value in pairs(mixin) do
				object[key] = value
			end
		end
		return object
	end
	env.CreateFromMixins = function(...)
		return env.Mixin({}, ...)
	end
	env.GetCursorPosition = function()
		return Kit.cursorX or 0, Kit.cursorY or 0
	end
end

return Kit
