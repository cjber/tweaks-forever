---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "dungeonEntrances",
	category = "Maps",
	name = "Dungeon and raid entrances on the world map",
	tooltip = "Mark every dungeon and raid entrance on zone and continent maps with the retail icons; point at "
		.. "one for its name, and click it to travel there. Follows the map's own Show instance entrances filter.",
	default = true,
	conflicts = {
		{
			addon = "Leatrix_Maps",
			title = "Leatrix Maps",
			-- Its points of interest include dungeon entrances and are on by default.
			when = function()
				return not (LeaMapsDB and LeaMapsDB.ShowPointsOfInterest == "Off")
			end,
		},
	},
})

local TEMPLATE = "TweaksForeverDungeonEntrancePinTemplate"
-- Other addons' and Blizzard's markers of a place. An entrance they sit on steps aside for them.
local MARKERS = {
	"FlightPointPinTemplate",
	"LegacyForeverPinTemplate",
	"ShortestPathForeverDockPinTemplate",
	"ShortestPathForeverFlightPinTemplate",
	"ShortestPathForeverPortalPinTemplate",
}
local IS_MARKER = tInvert(MARKERS)
-- Half the solid part of the 32-unit icon, in UI units: a marker nearer than this covers the entrance.
local COVER = 10

---@class TFEntrances
local Model = {}
ns.Entrances = Model

---@param entry TFEntrance
---@return 'Raid'|'Dungeon'
function Model.Atlas(entry)
	for _, instance in ipairs(entry.instances) do
		if not ns.RaidInstances[instance] then
			return "Dungeon"
		end
	end
	return "Raid"
end

-- The tooltip title, and a line per instance under it: a complex takes its area's name, a lone instance its
-- own. Lines carry the dungeon or raid icon where a pin mixes the two.
---@param entry TFEntrance
---@return string title
---@return string? lines
function Model.Describe(entry)
	local names = {}
	for i, instance in ipairs(entry.instances) do
		names[i] = GetRealZoneText(instance)
	end
	local title = entry.area and C_Map.GetAreaInfo(entry.area) or table.remove(names, 1)
	if #names == 0 then
		return title
	end
	if entry.area and Model.Atlas(entry) == "Dungeon" then
		for i, instance in ipairs(entry.instances) do
			local atlas = ns.RaidInstances[instance] and "Raid" or "Dungeon"
			names[i] = CreateAtlasMarkup(atlas, 16, 16) .. " " .. names[i]
		end
	end
	return title, table.concat(names, "\n")
end

-- Travel to the entrance on the map it is drawn on, under the name its tooltip gives it.
---@param uiMapID integer
---@param entry TFEntrance
function Model.Travel(uiMapID, entry)
	ns.Navigate(uiMapID, entry.x, entry.y, (Model.Describe(entry)))
end

-- Whether a marker at (mx, my) sits on (x, y), both normalized, within the given half extents.
---@return boolean
function Model.Covers(x, y, mx, my, halfX, halfY)
	return math.abs(x - mx) < halfX and math.abs(y - my) < halfY
end

ns.Init(function()
	local map = WorldMapFrame

	-- Measured at the smallest zoom, where icons crowd most.
	local function HalfExtents()
		local canvas, scale = map:GetCanvas(), map:GetScaleForMinZoom()
		return COVER / (canvas:GetWidth() * scale), COVER / (canvas:GetHeight() * scale)
	end

	local function Covered(pin, halfX, halfY)
		local x, y = pin:GetPosition()
		for _, template in ipairs(MARKERS) do
			for marker in map:EnumeratePinsByTemplate(template) do
				local mx, my = marker:GetPosition()
				if mx and marker:IsShown() and Model.Covers(x, y, mx, my, halfX, halfY) then
					return true
				end
			end
		end
		return false
	end

	local function Settle()
		local halfX, halfY = HalfExtents()
		for pin in map:EnumeratePinsByTemplate(TEMPLATE) do
			pin:SetShown(not Covered(pin, halfX, halfY))
		end
	end

	-- Retail's pin, fed from Data/DungeonEntrances.lua: C_EncounterJournal has no entrances without the journal's
	-- tables, which Forever's client lacks, so Blizzard's own provider draws nothing. A left click travels there in
	-- place of retail's journal; the canvas still passes right clicks through to zoom out.
	---@class TFEntrancePin : BaseMapPoiPinMixin, Frame
	---@field entry TFEntrance
	---@field lines string?
	---@field OnMouseClickAction fun(self: TFEntrancePin, button: string) the canvas's optional click hook
	TweaksForeverDungeonEntrancePinMixin = BaseMapPoiPinMixin:CreateSubPin("PIN_FRAME_LEVEL_DUNGEON_ENTRANCE")
	local Pin = TweaksForeverDungeonEntrancePinMixin

	---@param entry TFEntrance
	function Pin:OnAcquired(entry)
		local title, lines = Model.Describe(entry)
		BaseMapPoiPinMixin.OnAcquired(self, {
			name = title,
			atlasName = Model.Atlas(entry),
			position = CreateVector2D(entry.x, entry.y),
		})
		self.entry = entry
		self.lines = lines
		self:SetShown(not Covered(self, HalfExtents()))
	end

	function Pin.UseTooltip()
		return true
	end

	function Pin:GetBestNameAndDescription()
		return self.name, self.lines
	end

	function Pin.GetTooltipInstructions()
		return ns.NavigateHint()
	end

	---@param button string
	function Pin:OnMouseClickAction(button)
		if button == "LeftButton" then
			Model.Travel(self:GetMap():GetMapID(), self.entry)
		end
	end

	local Provider = CreateFromMixins(CVarMapCanvasDataProviderMixin)
	Provider:Init("showDungeonEntrancesOnMap")

	function Provider:RemoveAllData()
		self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
	end

	function Provider:RefreshAllData()
		self:RemoveAllData()
		if not (ns.Active("dungeonEntrances") and self:IsCVarSet()) then
			return
		end
		for _, entry in ipairs(ns.DungeonEntrances[self:GetMap():GetMapID()] or {}) do
			self:GetMap():AcquirePin(TEMPLATE, entry)
		end
	end

	map:AddDataProvider(Provider)

	-- Markers come and go with their own providers, before or after ours. Placing one hides what it covers;
	-- removing any settles every entrance again. Both happen only as providers refresh.
	hooksecurefunc(map, "SetPinPosition", function(_, marker, mx, my)
		if IS_MARKER[marker.pinTemplate] then
			local halfX, halfY = HalfExtents()
			for pin in map:EnumeratePinsByTemplate(TEMPLATE) do
				local x, y = pin:GetPosition()
				if Model.Covers(x, y, mx, my, halfX, halfY) then
					pin:Hide()
				end
			end
		end
	end)
	hooksecurefunc(map, "RemoveAllPinsByTemplate", function(_, template)
		if IS_MARKER[template] then
			Settle()
		end
	end)
	hooksecurefunc(map, "RemovePin", function(_, marker)
		if IS_MARKER[marker.pinTemplate] then
			Settle()
		end
	end)
end)
