---@type string, TFNamespace
local _, ns = ...
local L = ns.L

local KEY = "mapCoords"

ns.Feature({
	key = KEY,
	category = "Maps",
	name = "Coordinates on the world map",
	tooltip = "Your position and the cursor's, as map coordinates, along the bottom of the world map.",
	default = true,
	conflicts = {
		{
			addon = "Leatrix_Maps",
			title = "Leatrix Maps",
			-- On by default, so only an explicit "Off" leaves the job to us.
			when = function()
				return not (LeaMapsDB and LeaMapsDB.ShowCoords == "Off")
			end,
		},
		{
			addon = "Mapster",
			when = function()
				local ace = LibStub and LibStub("AceAddon-3.0", true)
				local addon = ace and ace:GetAddon("Mapster", true)
				local coords = addon and addon:GetModule("Coords", true)
				return coords and coords:IsEnabled()
			end,
		},
		{ addon = "Coordinates" },
		{ polestar = "maps.coords" },
		{ openmap = "coords" },
	},
})

-- How often the text follows the player and cursor, in seconds.
local INTERVAL = 0.1

---@class TFCoordinates
local Model = {}
ns.Coordinates = Model

-- A 0-1 map position as the map's own coordinates, "45.2, 60.1"; nil off the map.
---@param x number?
---@param y number?
---@return string?
function Model.Format(x, y)
	if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 or (x == 0 and y == 0) then
		return nil
	end
	return ("%.1f, %.1f"):format(x * 100, y * 100)
end

-- The cursor over `canvas`, the map's scrolling content, as a 0-1 position on it: engine reads only.
---@param canvas Frame
---@return number? x
---@return number? y
function Model.Cursor(canvas)
	local left, top, width, height = canvas:GetLeft(), canvas:GetTop(), canvas:GetWidth(), canvas:GetHeight()
	if not (left and top and width and height) or width <= 0 or height <= 0 then
		return nil
	end
	local x, y = GetCursorPosition()
	local scale = canvas:GetEffectiveScale()
	return (x / scale - left) / width, (top - y / scale) / height
end

-- The bar's text: whichever of the player's and cursor's positions there are.
---@param here string?
---@param there string?
---@return string
function Model.Line(here, there)
	if here and there then
		return L["Player: %s    Cursor: %s"]:format(here, there)
	elseif here then
		return L["Player: %s"]:format(here)
	elseif there then
		return L["Cursor: %s"]:format(there)
	end
	return ""
end

ns.Init(function()
	local container = WorldMapFrame.ScrollContainer
	-- Our own frame, centred along the bottom of the map, clear of the dungeon map's corner button and above the
	-- map's pins; it runs only while the map shows.
	local bar = ns.MapCanvas.FrameUnder("Frame", WorldMapFrame)
	bar:SetPoint("BOTTOM", container, "BOTTOM", 0, 6)
	bar:SetSize(320, 16)
	bar:SetFrameLevel(container:GetFrameLevel() + 500)
	local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("CENTER")

	local elapsed, shown = 0, nil
	local function Update()
		elapsed = 0
		local map = WorldMapFrame:GetMapID()
		local position = map and C_Map.GetPlayerMapPosition(map, "player")
		local here = position and Model.Format(position:GetXY()) -- multi-value: x and y
		local there = container:IsMouseOver() and Model.Format(Model.Cursor(container.Child)) or nil -- multi-value: x and y
		local line = Model.Line(here, there)
		if line ~= shown then
			shown = line
			text:SetText(line)
		end
	end
	bar:SetScript("OnShow", Update)
	bar:SetScript("OnUpdate", function(_, delta)
		elapsed = elapsed + delta
		if elapsed >= INTERVAL then
			Update()
		end
	end)
	local function Apply()
		bar:SetShown(ns.Active(KEY))
	end
	ns.OnSettingChanged(KEY, Apply)
	hooksecurefunc(ns, "RefreshConflicts", Apply)
	Apply()
end)
