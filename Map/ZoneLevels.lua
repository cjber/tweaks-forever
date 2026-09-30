---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "zoneLevels",
	category = "Maps",
	name = "Zone level ranges on the world map",
	tooltip = "Pointing at a zone on the world map adds its level range after the name. Coloured like quest "
		.. "levels: red and orange are above you, yellow is your level, green and grey are below.",
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

---@class TFZoneLevels
local Model = {}
ns.ZoneLevels = Model

-- The client's own range where it has one, else Data/ZoneLevels.lua's.
---@param mapID integer
---@return number? low
---@return number? high
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

---@param low number
---@param high number
---@return string
function Model.Text(low, high)
	return low == high and tostring(low) or low .. "-" .. high
end

-- The level a zone is coloured as, by the rule of Blizzard's own hover label: the bottom of a zone above you,
-- your own level inside one, and two under the top of a zone below you so it stops being yellow at its top.
---@param level number
---@param low number
---@param high number
---@return number
function Model.ChallengeLevel(level, low, high)
	if level < low then
		return low
	elseif level > high then
		return high - 2
	end
	return level
end

ns.Init(function()
	-- Blizzard's hover label carries only the zone's name, so look it up among the shown map's zones.
	local byName, namedMap = {}, nil
	local function Zone(name)
		local mapID = WorldMapFrame:GetMapID()
		if mapID ~= namedMap then
			namedMap = mapID
			wipe(byName)
			for _, child in ipairs(C_Map.GetMapChildrenInfo(mapID, Enum.UIMapType.Zone) or {}) do
				local low, high = Model.Range(child.mapID)
				if low then
					byName[child.name] = { low = low, high = high }
				end
			end
		end
		return byName[name]
	end

	-- Blizzard's hover label names the zone under the cursor and adds the client's range, which Forever lacks;
	-- add ours to the name it drew. Reading the text each frame is cheap and catches every redraw. Its OnUpdate
	-- ends by drawing the label; hooking EvaluateLabels on the frame instead wrote a field onto it, and the map's
	-- data providers then failed with "attempt to call a nil value".
	for other in pairs(WorldMapFrame.dataProviders) do
		if other.OnSetAreaLabel == AreaLabelDataProviderMixin.OnSetAreaLabel then
			local shown
			other.Label:HookScript("OnUpdate", function(label)
				local text = label.Name:GetText()
				if text == shown then
					return
				end
				shown = nil
				local zone = text and ns.Active("zoneLevels") and Zone(text)
				if zone then
					local level = UnitEffectiveLevel("player")
					local color = GetRelativeDifficultyColor(level, Model.ChallengeLevel(level, zone.low, zone.high))
					shown = text
						.. RGBTableToColorCode(color)
						.. " ("
						.. Model.Text(zone.low, zone.high)
						.. ")"
						.. FONT_COLOR_CODE_CLOSE
					label.Name:SetText(shown)
				end
			end)
		end
	end
end)
