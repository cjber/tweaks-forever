---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "exploration",
	category = "Maps",
	name = "Reveal unexplored areas",
	tooltip = "Show unexplored zone terrain with a dim blue tint. Explored areas keep their normal appearance.",
	default = false,
	conflicts = {
		{
			addon = "LegacyForever",
			title = "Legacy Forever",
			when = function()
				return not (LegacyForeverDB and LegacyForeverDB.showAreas == false)
			end,
		},
		{
			addon = "Leatrix_Maps",
			title = "Leatrix Maps",
			when = function()
				return LeaMapsDB and LeaMapsDB.RevealMap == "On"
			end,
		},
		{
			addon = "Mapster",
			when = function()
				local ace = LibStub and LibStub("AceAddon-3.0", true)
				local addon = ace and ace:GetAddon("Mapster", true)
				local fog = addon and addon:GetModule("FogClear", true)
				return fog and fog:IsEnabled()
			end,
		},
	},
})

---@class TFExploration
local Model = {}
ns.Exploration = Model

---@param x number
---@param y number
---@param width number
---@param height number
---@return string
function Model.OverlayKey(x, y, width, height)
	return ("%d:%d:%d:%d"):format(x, y, width, height)
end

---@param encoded string
---@return table<integer, TFOverlay[]>
function Model.Decode(encoded)
	local layers = {}
	for record in encoded:gmatch("([^;]+);") do
		local values = {}
		for value in record:gmatch("%d+") do
			values[#values + 1] = tonumber(value)
		end
		local index = values[1]
		local area = {
			x = values[2],
			y = values[3],
			width = values[4],
			height = values[5],
			files = {},
		}
		area.key = Model.OverlayKey(area.x, area.y, area.width, area.height)
		for i = 6, #values do
			area.files[#area.files + 1] = values[i]
		end
		layers[index] = layers[index] or {}
		layers[index][#layers[index] + 1] = area
	end
	return layers
end

---@param total number
---@param size number
---@param index integer
---@param count integer
---@return number, number
local function TileSpan(total, size, index, count)
	if index < count then
		return size, 1
	end
	local pixels = total % size
	if pixels == 0 then
		pixels = size
	end
	local file = 16
	while file < pixels do
		file = file * 2
	end
	return pixels, pixels / file
end

-- Partial edge tiles occupy power-of-two files, as in MapExplorationPinMixin.
---@param width number
---@param height number
---@param tileWidth number
---@param tileHeight number
---@return TFOverlayTile[]
function Model.OverlayTiles(width, height, tileWidth, tileHeight)
	local wide, tall = math.ceil(width / tileWidth), math.ceil(height / tileHeight)
	local tiles = {}
	for row = 1, tall do
		local h, v = TileSpan(height, tileHeight, row, tall)
		for column = 1, wide do
			local w, u = TileSpan(width, tileWidth, column, wide)
			tiles[#tiles + 1] = {
				x = tileWidth * (column - 1),
				y = tileHeight * (row - 1),
				width = w,
				height = h,
				u = u,
				v = v,
			}
		end
	end
	return tiles
end

---@param areas TFOverlay[]
---@param explored UiMapExplorationInfo[]?
---@return TFOverlay[]
function Model.Unexplored(areas, explored)
	local known, result = {}, {}
	for _, area in ipairs(explored or {}) do
		known[Model.OverlayKey(area.offsetX, area.offsetY, area.textureWidth, area.textureHeight)] = true
	end
	for _, area in ipairs(areas) do
		if not known[area.key] then
			result[#result + 1] = area
		end
	end
	return result
end

-- Keep only the viewed art decoded; the source strings stay compact at login.
local cachedArt, cachedLayers
---@param art integer
---@param layer integer
---@return TFOverlay[]
local function Areas(art, layer)
	if cachedArt ~= art then
		cachedArt = art
		cachedLayers = ns.Overlays[art] and Model.Decode(ns.Overlays[art]) or {}
	end
	return cachedLayers[layer] or {}
end

ns.Init(function()
	local map = WorldMapFrame
	-- Drawn on Blizzard's exploration pin, below its explored textures, so overlapping edges retain Blizzard's
	-- normal artwork. Everything else is ours: a data provider of our own redraws them, and the map's mask is
	-- applied here. Hooking the pin's methods or listing textures in the map's tables made Blizzard's own map code
	-- fail with "attempt to call a nil value".
	local pool, poolPin
	-- [texture] = whether it carries the map's mask.
	local masked = {}

	---@return Frame?
	local function ExplorationPin()
		for pin in map:EnumeratePinsByTemplate("MapExplorationPinTemplate") do -- luacheck: ignore 512 (first only)
			return pin
		end
	end

	local function Draw()
		if pool then
			pool:ReleaseAll()
		end
		if not ns.Active("exploration") then
			return
		end
		local pin = ExplorationPin()
		local mapID = map:GetMapID()
		local info = mapID and C_Map.GetMapInfo(mapID)
		if not pin or not info or info.mapType ~= Enum.UIMapType.Zone then
			return
		end
		if poolPin ~= pin then
			pool, poolPin = CreateTexturePool(pin, "ARTWORK", -1), pin
		end
		local art = C_Map.GetMapArtID(mapID)
		local index = map:GetCanvasContainer():GetCurrentLayerIndex()
		local layers = C_Map.GetMapArtLayers(mapID)
		local layer = layers and layers[index]
		if not art or not layer then
			return
		end
		local mask = map:GetMaskTexture()
		local useMask = mask and map:GetUseMaskTexture() or false
		local explored = C_MapExplorationInfo.GetExploredMapTextures(mapID)
		for _, area in ipairs(Model.Unexplored(Areas(art, index), explored)) do
			for i, tile in ipairs(Model.OverlayTiles(area.width, area.height, layer.tileWidth, layer.tileHeight)) do
				local texture = pool:Acquire()
				if mask and masked[texture] ~= useMask then
					if useMask then
						texture:AddMaskTexture(mask)
					else
						texture:RemoveMaskTexture(mask)
					end
					masked[texture] = useMask
				end
				texture:SetTexture(area.files[i], nil, nil, "TRILINEAR")
				texture:SetSize(tile.width, tile.height)
				texture:SetTexCoord(0, tile.u, 0, tile.v)
				texture:ClearAllPoints()
				texture:SetPoint("TOPLEFT", area.x + tile.x, -(area.y + tile.y))
				texture:SetVertexColor(0.55, 0.65, 0.85, 0.8)
				texture:Show()
			end
		end
	end

	-- The base provider redraws on every map change as well; a zoom can change the art layer.
	local Provider = CreateFromMixins(MapCanvasDataProviderMixin)
	function Provider.RemoveAllData()
		if pool then
			pool:ReleaseAll()
		end
	end
	Provider.RefreshAllData = Draw
	Provider.OnCanvasScaleChanged = Draw
	map:AddDataProvider(Provider)
end)
