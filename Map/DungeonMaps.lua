---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "dungeonMaps",
	category = "Maps",
	name = "Dungeon interior maps",
	tooltip = "Inside a dungeon, the world map opens on its floor map, with a floor picker and a Back to map button.",
	default = true,
})

local PAD, HEADER, COLUMNS, ROWS = 12, 46, 4, 3
local PICKER_WIDTH = 200

---@class TFDungeonMaps
local Model = {}
ns.DungeonMaps = Model

---@param art table?
---@param instance integer
---@return TFInteriorMap[]
function Model.Floors(art, instance)
	local source = type(art) == "table" and art[instance]
	local floors = {}
	if type(source) ~= "table" then
		return floors
	end
	for _, floor in ipairs(source) do
		if type(floor) == "table" and type(floor.title) == "string" and type(floor.pattern) == "string" then
			floors[#floors + 1] = { title = floor.title, pattern = floor.pattern, separator = floor.separator or "_" }
		end
	end
	return floors
end

---@param instanceType string
---@param instance integer?
---@param playerMap integer?
---@param shownMap integer?
---@return integer?
function Model.Inside(instanceType, instance, playerMap, shownMap)
	if instanceType == "party" and playerMap and playerMap == shownMap then
		return instance
	end
end

---@param count integer
---@param chosen integer?
---@return integer
function Model.Floor(count, chosen)
	return math.max(1, math.min(chosen or 1, count))
end

ns.Init(function()
	local map = WorldMapFrame
	local host, heading, picker, popup, back, reopen
	local tiles = {}
	local choices, floors, selected, shown = {}, {}, 1, nil
	---@type table<integer, integer>
	local chosen = {}
	local pending = false

	local function Hide()
		if host then
			popup:Hide()
			host:Hide()
			reopen:Hide()
		end
		shown = nil
	end

	local function Layout()
		local width, height = host:GetWidth(), host:GetHeight()
		local sheetWidth = math.max(1, math.min(width - PAD * 2, (height - HEADER - PAD) * COLUMNS / ROWS))
		local sheetHeight = sheetWidth * ROWS / COLUMNS
		for index, tile in ipairs(tiles) do
			local column, row = (index - 1) % COLUMNS, math.floor((index - 1) / COLUMNS)
			tile:SetSize(sheetWidth / COLUMNS, sheetHeight / ROWS)
			tile:ClearAllPoints()
			tile:SetPoint(
				"TOPLEFT",
				host,
				"TOPLEFT",
				PAD + column * sheetWidth / COLUMNS,
				-HEADER - row * sheetHeight / ROWS
			)
		end
	end

	local Select
	local function Choices()
		for index, floor in ipairs(floors) do
			local choice = choices[index]
			if not choice then
				choice = ns.MapCanvas.FrameUnder("Button", popup, "UIPanelButtonTemplate")
				choice:SetSize(PICKER_WIDTH - 12, 24)
				choice:SetPoint("TOPLEFT", 6, -6 - (index - 1) * 26)
				choice:SetScript("OnClick", function()
					Select(index)
				end)
				choices[index] = choice
			end
			choice:SetText(floor.title)
			choice:SetEnabled(index ~= selected)
			choice:Show()
		end
		for index = #floors + 1, #choices do
			choices[index]:Hide()
		end
		popup:SetSize(PICKER_WIDTH, #floors * 26 + 12)
	end

	local function Draw()
		local floor = floors[selected]
		heading:SetText(floor.title)
		for index, tile in ipairs(tiles) do
			tile:SetTexture(floor.pattern .. floor.separator .. index) -- art-ok: native 256px square tile in a square cell
		end
		picker:SetShown(#floors > 1)
		picker:SetText(floor.title)
		popup:Hide()
		Choices()
	end

	---@param index integer
	function Select(index)
		selected = Model.Floor(#floors, index)
		popup:Hide()
		if shown then
			chosen[shown] = selected
		end
		Draw()
	end

	local function Build()
		local canvas = map.ScrollContainer
		host = ns.MapCanvas.FrameUnder("Frame", canvas)
		host:SetAllPoints(canvas)
		host:SetFrameLevel(canvas:GetFrameLevel() + 100)
		host:EnableMouse(true)
		local background = host:CreateTexture(nil, "BACKGROUND")
		background:SetAllPoints()
		background:SetColorTexture(0, 0, 0, 1)
		heading = host:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		heading:SetPoint("TOPLEFT", PAD, -PAD)
		heading:SetJustifyH("LEFT")
		for index = 1, COLUMNS * ROWS do
			tiles[index] = host:CreateTexture(nil, "ARTWORK")
			tiles[index]:SetTexCoord(0, 1, 0, 1)
		end
		back = ns.MapCanvas.FrameUnder("Button", host, "UIPanelButtonTemplate") --[[@as Button]]
		back:SetSize(112, 22)
		back:SetPoint("TOPRIGHT", -PAD, -PAD)
		back:SetText(ns.L["Back to map"])
		ns.FitButton(back, 112)
		reopen = ns.MapCanvas.FrameUnder("Button", canvas, "UIPanelButtonTemplate") --[[@as Button]]
		reopen:SetSize(112, 22)
		reopen:SetPoint("BOTTOMLEFT", PAD, PAD)
		reopen:SetFrameLevel(host:GetFrameLevel() + 1)
		reopen:SetText(ns.L["Dungeon map"])
		ns.FitButton(reopen, 112)
		reopen:Hide()
		back:SetScript("OnClick", function()
			host:Hide()
			reopen:Show()
		end)
		reopen:SetScript("OnClick", function()
			reopen:Hide()
			host:Show()
		end)
		picker = ns.MapCanvas.FrameUnder("Button", host, "UIPanelButtonTemplate") --[[@as Button]]
		picker:SetSize(PICKER_WIDTH, 24)
		picker:SetPoint("TOPRIGHT", back, "TOPLEFT", -8, 0)
		popup = ns.MapCanvas.FrameUnder("Frame", picker)
		popup:SetFrameStrata("DIALOG")
		popup:SetPoint("TOPRIGHT", picker, "BOTTOMRIGHT", 0, -2)
		popup:EnableMouse(true)
		local popupBackground = popup:CreateTexture(nil, "BACKGROUND")
		popupBackground:SetAllPoints()
		popupBackground:SetColorTexture(0.04, 0.03, 0.02, 1)
		popup:SetScript("OnShow", function(self)
			self:RegisterEvent("GLOBAL_MOUSE_DOWN")
		end)
		popup:SetScript("OnHide", function(self)
			self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
		end)
		popup:SetScript("OnEvent", function(self)
			if not (self:IsMouseOver() or picker:IsMouseOver()) then
				self:Hide()
			end
		end)
		ns.EscapeCloses(popup)
		popup:Hide()
		picker:SetScript("OnClick", function()
			popup:SetShown(not popup:IsShown())
		end)
		host:SetScript("OnSizeChanged", Layout)
	end

	local function Refresh()
		if not map:IsShown() then
			return
		end
		local _, instanceType, _, _, _, _, _, instance = GetInstanceInfo()
		local inside = Model.Inside(instanceType, instance, C_Map.GetBestMapForUnit("player"), map:GetMapID())
		if not (inside and ns.Active("dungeonMaps")) then
			Hide()
			return
		end
		if shown == inside then
			pending = false
			return
		end
		if InCombatLockdown() then
			Hide()
			pending = true
			return
		end
		pending = false
		local found = Model.Floors(ns.DungeonMapArt, inside)
		if #found == 0 then
			Hide()
			return
		end
		if not host then
			Build()
		end
		floors, shown = found, inside
		selected = Model.Floor(#floors, chosen[inside])
		reopen:Hide()
		host:Show()
		Layout()
		Draw()
	end

	ns.MapCanvas.Watch(map, function(_, what)
		if what == "map" then
			Refresh()
		end
	end)
	map:HookScript("OnShow", Refresh)
	map:HookScript("OnHide", function()
		if host then
			popup:Hide()
		end
		shown = nil
	end)
	ns.On("PLAYER_ENTERING_WORLD", Refresh)
	ns.On("ZONE_CHANGED_NEW_AREA", Refresh)
	ns.On("PLAYER_REGEN_ENABLED", function()
		if pending then
			Refresh()
		end
	end)
	ns.OnSettingChanged("dungeonMaps", Refresh)
end)
