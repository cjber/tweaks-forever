local _, ns = ...

ns.Feature({
	key = "zoneLevels",
	category = "Maps",
	name = "Zone level ranges on the world map",
	tooltip = "Shows each zone's level range on the continent maps, and after the zone's name when you point "
		.. "at it. Coloured like quest levels: red and orange are above you, yellow is your level, "
		.. "green and grey are below.",
	default = true,
	conflicts = {
		{
			addon = "Leatrix_Maps",
			title = "Leatrix Maps",
			-- On by default, so only an explicit "Off" leaves the job to us.
			when = function()
				return not (LeaMapsDB and LeaMapsDB.ShowZoneLevels == "Off")
			end,
		},
	},
})

local Model = {}
ns.ZoneLevels = Model

-- The client's own range where it has one, else the published range.
function Model.Range(mapID)
	local low, high = C_Map.GetMapLevels(mapID)
	if low and high and low > 0 and high > 0 then
		return low, high
	end
	local range = ns.ZoneRanges[mapID]
	if range then
		return range[1], range[2]
	end
end

function Model.Text(low, high)
	return low == high and tostring(low) or low .. "-" .. high
end

-- The level a zone is coloured as, by the rule of Blizzard's own hover label: the bottom of a zone above you,
-- your own level inside one, and two under the top of a zone below you so it stops being yellow at its top.
function Model.ChallengeLevel(level, low, high)
	if level < low then
		return low
	elseif level > high then
		return high - 2
	end
	return level
end

-- Labels draw just above the hovered zone's glow and under every icon on the map.
local function FrameLevel(map)
	local levels = map:GetPinFrameLevelsManager()
	local highlight = "PIN_FRAME_LEVEL_MAP_HIGHLIGHT"
	return levels:GetFrameLevelStart(highlight) + levels:GetFrameLevelRange(highlight)
end

ns.Init(function()
	local zones = {} -- { mapID, name, low, high, x, y } for each labelled zone on the shown map
	local byName = {}
	local labels = {}
	local level = UnitEffectiveLevel("player")

	local function Color(zone)
		return GetRelativeDifficultyColor(level, Model.ChallengeLevel(level, zone.low, zone.high))
	end

	local function Label(i, map)
		local label = labels[i]
		if not label then
			label = CreateFrame("Frame", nil, map:GetCanvas())
			label:SetSize(1, 1)
			label:EnableMouse(false)
			label.text = label:CreateFontString(nil, "OVERLAY", "GameFontNormalSmallOutline")
			label.text:SetPoint("CENTER")
			labels[i] = label
		end
		label:SetFrameLevel(FrameLevel(map))
		return label
	end

	-- Readable at any zoom, growing a little when zoomed in, as Blizzard scales its own map icons.
	local function Place(map)
		local canvas = map:GetCanvas()
		local width, height = canvas:GetSize()
		local scale = Lerp(1, 1.2, Saturate(map:GetCanvasZoomPercent())) / map:GetCanvasScale()
		for i, zone in ipairs(zones) do
			local label = labels[i]
			label:SetScale(scale)
			label:ClearAllPoints()
			label:SetPoint("CENTER", canvas, "TOPLEFT", width * zone.x / scale, -height * zone.y / scale)
		end
	end

	local function Recolor()
		for i, zone in ipairs(zones) do
			local color = Color(zone)
			labels[i].text:SetTextColor(color.r, color.g, color.b)
		end
	end

	local function Clear()
		wipe(zones)
		wipe(byName)
		for _, label in ipairs(labels) do
			label:Hide()
		end
	end

	-- Continents only: on the world map both continents' zones shrink until their labels overlap.
	local function Collect(mapID)
		local info = C_Map.GetMapInfo(mapID)
		if not info or info.mapType ~= Enum.UIMapType.Continent then
			return
		end
		for _, child in ipairs(C_Map.GetMapChildrenInfo(mapID, Enum.UIMapType.Zone) or {}) do
			local low, high = Model.Range(child.mapID)
			local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(child.mapID, mapID)
			if low and minX then
				local zone = {
					mapID = child.mapID,
					name = child.name,
					low = low,
					high = high,
					x = (minX + maxX) / 2,
					y = (minY + maxY) / 2,
				}
				zones[#zones + 1] = zone
				byName[child.name] = zone
			end
		end
	end

	local provider = CreateFromMixins(MapCanvasDataProviderMixin)

	provider.RemoveAllData = Clear

	function provider:RefreshAllData()
		Clear()
		if not ns.Active("zoneLevels") then
			return
		end
		local map = self:GetMap()
		level = UnitEffectiveLevel("player")
		Collect(map:GetMapID())
		for i, zone in ipairs(zones) do
			local label = Label(i, map)
			label.text:SetText(Model.Text(zone.low, zone.high))
			label:Show()
		end
		Place(map)
		Recolor()
	end

	function provider:OnCanvasScaleChanged()
		Place(self:GetMap())
	end

	function provider:OnCanvasSizeChanged()
		Place(self:GetMap())
	end

	WorldMapFrame:AddDataProvider(provider)

	-- Blizzard's hover label names the zone under the cursor and adds the client's range, which Forever lacks;
	-- add ours to the name it drew. Reading the text each frame is cheap and catches every redraw.
	for other in pairs(WorldMapFrame.dataProviders) do
		if other.OnSetAreaLabel == AreaLabelDataProviderMixin.OnSetAreaLabel then
			local shown
			hooksecurefunc(other.Label, "EvaluateLabels", function(label)
				local text = label.Name:GetText()
				if text == shown then
					return
				end
				shown = nil
				local zone = byName[text]
				if zone then
					shown = text
						.. RGBTableToColorCode(Color(zone))
						.. " ("
						.. Model.Text(zone.low, zone.high)
						.. ")"
						.. FONT_COLOR_CODE_CLOSE
					label.Name:SetText(shown)
				end
			end)
		end
	end

	ns.On("PLAYER_LEVEL_UP", function(newLevel)
		level = newLevel
		Recolor()
	end)

	-- The settings toggle applies at once on an open map.
	Settings.SetOnValueChangedCallback("TweaksForever_zoneLevels", function()
		if WorldMapFrame:IsShown() then
			provider:RefreshAllData()
		end
	end)
end)
