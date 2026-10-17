---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "dungeonEntrances",
	category = "Maps",
	name = "Instance entrances",
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
		-- Its "Dungeons, travel and more" icons: every entrance, with its level range.
		{ openmap = "icons" },
	},
})

local TEMPLATE = "TweaksForeverDungeonEntrancePinTemplate"
-- Markers of a place found through the map's pins (a read): Blizzard's flight points, and the pins of Forever addons
-- from before they drew on frames of their own. Those that do list theirs through ForeverMapMarkers
-- (Map/MapCanvas.lua). An entrance either sits on steps aside.
local NATIVE_MARKERS = {
	"FlightPointPinTemplate",
	"LegacyForeverPinTemplate",
	"ShortestPathForeverDockPinTemplate",
	"ShortestPathForeverFlightPinTemplate",
	"ShortestPathForeverPortalPinTemplate",
}
-- Seconds between re-checks of which entrances a marker covers while the map is open.
local SETTLE_INTERVAL = 0.25
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
			names[i] = ns.Art.Markup(atlas, 16) .. " " .. names[i]
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
	local MapCanvas = ns.MapCanvas

	-- Measured at the smallest zoom, where icons crowd most.
	local function HalfExtents()
		local canvas, scale = map:GetCanvas(), map:GetScaleForMinZoom()
		return COVER / (canvas:GetWidth() * scale), COVER / (canvas:GetHeight() * scale)
	end

	-- Where the map's own and the other Forever addons' markers sit now, as map fractions.
	local function Markers()
		local markers = MapCanvas.OtherMarkers(map)
		for _, template in ipairs(NATIVE_MARKERS) do
			for marker in map:EnumeratePinsByTemplate(template) do
				local mx, my = marker:GetPosition()
				if mx and marker:IsShown() then
					markers[#markers + 1] = { x = mx, y = my }
				end
			end
		end
		return markers
	end

	---@param pin TFEntrancePin
	---@param markers {x: number, y: number}[]
	local function Covered(pin, markers, halfX, halfY)
		local x, y = pin:GetPosition()
		for _, marker in ipairs(markers) do
			if Model.Covers(x, y, marker.x, marker.y, halfX, halfY) then
				return true
			end
		end
		return false
	end

	-- Retail's pin, fed from Data/DungeonEntrances.lua: C_EncounterJournal has no entrances without the journal's
	-- tables, which Forever's client lacks, so Blizzard's own provider draws nothing. Drawn on a frame of our own
	-- (Map/MapCanvas.lua) with the retail icon and tooltip; a left click travels there in place of retail's journal,
	-- and a right click goes through to the map to zoom out.
	---@class TFEntrancePin : TFCanvasPin
	---@field Texture Texture
	---@field HighlightTexture Texture
	---@field entry TFEntrance
	---@field name string
	---@field lines string?
	local Pin = CreateFromMixins(MapCanvas.PinMixin)

	function Pin:OnLoad()
		self.takesMouse, self.clicks = true, true
		self:UseFrameLevelType("PIN_FRAME_LEVEL_DUNGEON_ENTRANCE")
		self:SetScalingLimits(1, 1.0, 1.2)
	end

	---@param entry TFEntrance
	function Pin:OnAcquired(entry)
		local atlas = Model.Atlas(entry)
		self.Texture:SetAtlas(atlas, true)
		self.HighlightTexture:SetAtlas(atlas, true)
		self:SetSize(self.Texture:GetSize()) -- multi-value: width and height
		self.entry = entry
		self.name, self.lines = Model.Describe(entry)
		self:SetPosition(entry.x, entry.y)
	end

	-- The game's own POI tooltip, then a grey line about Shortest Path Forever while it is not loaded
	-- (ns.EntranceHint).
	function Pin:OnMouseEnter()
		local tooltip = GetAppropriateTooltip()
		tooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip_SetTitle(tooltip, self.name)
		if self.lines then
			GameTooltip_AddNormalLine(tooltip, self.lines)
		end
		GameTooltip_AddInstructionLine(tooltip, ns.NavigateHint(), false)
		local hint = ns.EntranceHint()
		if hint then
			GameTooltip_AddDisabledLine(tooltip, hint)
		end
		tooltip:Show()
	end

	function Pin:OnMouseLeave()
		local tooltip = GetAppropriateTooltip()
		if tooltip:GetOwner() == self then
			tooltip:Hide()
		end
	end

	---@param button string
	function Pin:OnMouseClickAction(button)
		if button == "LeftButton" then
			Model.Travel(map:GetMapID(), self.entry)
		end
	end

	local pins = MapCanvas.Pool(map, Pin, { template = TEMPLATE, marker = "entrance" })

	local function Settle()
		if InCombatLockdown() then
			return
		end
		local markers, halfX, halfY = Markers(), HalfExtents()
		for _, pin in ipairs(pins:Active()) do
			pin:SetShown(not Covered(pin, markers, halfX, halfY))
		end
	end

	-- Not CVarMapCanvasDataProviderMixin or any data provider: the map's providers and pins are walked by the
	-- gamepad interface's secure code (Map/MapCanvas.lua). A redraw in combat hides the pins and waits for its end.
	local CVAR = "showDungeonEntrancesOnMap"
	local refreshPending = false

	local function Draw()
		if InCombatLockdown() then
			refreshPending = true
			MapCanvas.SetShown(map, false)
			return
		end
		refreshPending = false
		pins:ReleaseAll()
		MapCanvas.SetShown(map, true)
		if not (ns.Active("dungeonEntrances") and GetCVarBool(CVAR)) then
			return
		end
		for _, entry in ipairs(ns.DungeonEntrances[map:GetMapID()] or {}) do
			pins:Acquire(entry)
		end
		Settle()
	end

	MapCanvas.Watch(map, function(_, what)
		if what == "show" or what == "map" then
			Draw()
		end
	end)
	-- The Instance entrances setting redraws an open map at once, as the map's own filter does.
	ns.OnSettingChanged("dungeonEntrances", function()
		if map:IsShown() then
			Draw()
		end
	end)
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:RegisterEvent("CVAR_UPDATE")
	events:SetScript("OnEvent", function(_, event, cvar)
		if map:IsShown() and (event == "CVAR_UPDATE" and cvar == CVAR or refreshPending) then
			Draw()
		end
	end)

	-- Markers come and go with their own addons, before or after ours, so the entrances settle a few times a second
	-- while the map is open, on a frame of our own on the map's canvas.
	local elapsed = 0
	MapCanvas.Watch(map).host:HookScript("OnUpdate", function(_, delta)
		elapsed = elapsed + delta
		if elapsed >= SETTLE_INTERVAL then
			elapsed = 0
			Settle()
		end
	end)
end)
