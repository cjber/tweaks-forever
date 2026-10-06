---@type string, TFNamespace
local _, ns = ...
local L = ns.L

local MODULE = "Atlas_ClassicWoW"

ns.Feature({
	key = "dungeonMaps",
	category = "Maps",
	name = "Dungeon interior maps",
	tooltip = "Inside a dungeon, the world map opens on the dungeon's own floor map and what is where, with a button "
		.. "for the floor and a Back to map button. Needs Atlas and its Classic WoW maps.",
	default = true,
	needs = {
		title = "Atlas [Classic WoW]",
		check = function()
			return (C_AddOns.IsAddOnLoaded(MODULE))
		end,
	},
})

-- The Atlas records of each five-player dungeon, by the instance ID GetInstanceInfo gives: every floor and wing
-- is a record whose key starts "CL_" and one of these. A key ending "Ent" is the outdoor sheet of the way in.
local GROUPS = {
	[33] = { "ShadowfangKeep" },
	[34] = { "TheStockade" },
	[36] = { "TheDeadmines" },
	[43] = { "WailingCaverns" },
	[47] = { "RazorfenKraul" },
	[48] = { "BlackfathomDeeps" },
	[70] = { "Uldaman" },
	[90] = { "Gnomeregan" },
	[109] = { "TheSunkenTemple" },
	[129] = { "RazorfenDowns" },
	[189] = { "ScarletMonastery", "SM" },
	[209] = { "ZulFarrak" },
	[229] = { "BlackrockSpire" },
	[230] = { "BlackrockDepths" },
	[289] = { "Scholomance" },
	[329] = { "Stratholme" },
	[349] = { "Maraudon" },
	[389] = { "RagefireChasm" },
	[429] = { "DireMaul" },
}
local PAD = 12
local PICKER_WIDTH = 200
-- Room above the map sheet for the heading, the floor menu and Back to map.
local HEADER = 46

---@class TFDungeonMaps
local Model = {}
ns.DungeonMaps = Model

---@param key string
---@param prefixes string[]
---@return boolean
local function IsFloorOf(key, prefixes)
	if key:sub(-3) == "Ent" then
		return false
	end
	for _, prefix in ipairs(prefixes) do
		if key:sub(1, #prefix + 3) == "CL_" .. prefix then
			return true
		end
	end
	return false
end

-- The floors Atlas draws for a dungeon, in key order, each with its title and legend lines. `atlas` is Atlas's
-- AtlasMaps table, absent until the addon has loaded and read here without trusting its shape.
---@param atlas table?
---@param instance integer
---@return TFInteriorMap[]
function Model.Floors(atlas, instance)
	local prefixes, floors = GROUPS[instance], {}
	if not (prefixes and type(atlas) == "table") then
		return floors
	end
	for key, record in pairs(atlas) do
		local names = type(record) == "table" and record.ZoneName
		if
			type(key) == "string"
			and key:match("^CL_[%w_]+$")
			and IsFloorOf(key, prefixes)
			and record.Module == MODULE
			and type(names) == "table"
			and type(names[1]) == "string"
		then
			local legend = {}
			for _, line in ipairs(record) do
				if type(line) == "table" and type(line[1]) == "string" then
					legend[#legend + 1] = line[1]
				end
			end
			floors[#floors + 1] = {
				key = key,
				title = names[1],
				texture = "Interface\\AddOns\\" .. MODULE .. "\\Images\\" .. key,
				legend = table.concat(legend, "\n"),
			}
		end
	end
	table.sort(floors, function(a, b)
		return a.key < b.key
	end)
	return floors
end

-- The dungeon the player stands in while the map shows the zone they are in, which is when its interior opens.
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

-- The floor to show: the one chosen last time, kept for the session, else the first.
---@param count integer
---@param chosen integer?
---@return integer
function Model.Floor(count, chosen)
	return math.max(1, math.min(chosen or 1, count))
end

ns.Init(function()
	local map = WorldMapFrame
	local host, art, heading, legend, legendBody, scroll, picker, popup, back, reopen
	local choices = {}
	local floors, selected, shown = {}, 1, nil
	-- The floor chosen for each dungeon this session.
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

	-- The legend text wraps to the scroll frame and the scroll child grows to the text.
	local function FitLegend()
		local width = math.max(1, scroll:GetWidth())
		legend:SetWidth(width)
		legendBody:SetSize(width, math.max(scroll:GetHeight(), legend:GetStringHeight() + PAD))
	end

	local function Layout()
		local width, height = host:GetWidth(), host:GetHeight()
		-- The sheets are square: the largest square that leaves the legend a column beside it.
		local side = math.max(1, math.min(width * 0.58, height - HEADER - PAD))
		art:SetSize(side, side)
		FitLegend()
	end

	local Select

	-- One choice per floor, the current one greyed; the popup is as tall as its choices.
	local function Choices()
		for index, floor in ipairs(floors) do
			local choice = choices[index]
			if not choice then
				choice = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
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
		art:SetTexture(floor.texture) -- art-ok: Atlas's map sheet, a 512 by 512 square drawn in a square
		art:SetTexCoord(0, 1, 0, 1)
		legend:SetText(floor.legend)
		-- One floor needs no menu.
		picker:SetShown(#floors > 1)
		picker:SetText(floor.title)
		popup:Hide()
		Choices()
		FitLegend()
		scroll:SetVerticalScroll(0)
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

	-- Our own frames over the map's canvas, so the map's own frames and Lua state are left alone.
	local function Build()
		local canvas = map.ScrollContainer
		host = CreateFrame("Frame", nil, canvas)
		host:SetAllPoints(canvas)
		host:SetFrameLevel(canvas:GetFrameLevel() + 100)
		host:EnableMouse(true)
		local background = host:CreateTexture(nil, "BACKGROUND")
		background:SetAllPoints()
		background:SetColorTexture(0, 0, 0, 1)

		heading = host:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		heading:SetPoint("TOPLEFT", PAD, -PAD)
		heading:SetJustifyH("LEFT")
		art = host:CreateTexture(nil, "ARTWORK")
		art:SetPoint("TOPLEFT", PAD, -HEADER)

		scroll = CreateFrame("ScrollFrame", nil, host, "ScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", art, "TOPRIGHT", PAD, 0)
		scroll:SetPoint("BOTTOMRIGHT", -PAD * 2, PAD)
		legendBody = CreateFrame("Frame", nil, scroll)
		scroll:SetScrollChild(legendBody)
		legend = legendBody:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		legend:SetPoint("TOPLEFT")
		legend:SetJustifyH("LEFT")
		legend:SetWordWrap(true)
		scroll:SetScript("OnSizeChanged", FitLegend)

		back = CreateFrame("Button", nil, host, "UIPanelButtonTemplate")
		back:SetSize(112, 22)
		back:SetPoint("TOPRIGHT", -PAD, -PAD)
		back:SetText(L["Back to map"])
		-- The map's own frames are untouched: the interior steps aside and a button on the canvas brings it back.
		reopen = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
		reopen:SetSize(112, 22)
		reopen:SetPoint("BOTTOMLEFT", PAD, PAD)
		reopen:SetFrameLevel(host:GetFrameLevel() + 1)
		reopen:SetText(L["Dungeon map"])
		reopen:Hide()
		back:SetScript("OnClick", function()
			host:Hide()
			reopen:Show()
		end)
		reopen:SetScript("OnClick", function()
			reopen:Hide()
			host:Show()
		end)

		-- The floor picker is a button over a popup of choices, all our own frames: the game's menu pool
		-- (GenerateMenu) asserts in Forever build 70009 when it opens.
		picker = CreateFrame("Button", nil, host, "UIPanelButtonTemplate")
		picker:SetSize(PICKER_WIDTH, 24)
		picker:SetPoint("TOPRIGHT", back, "TOPLEFT", -8, 0)
		popup = CreateFrame("Frame", nil, picker)
		popup:SetFrameStrata("DIALOG")
		popup:SetPoint("TOPRIGHT", picker, "BOTTOMRIGHT", 0, -2)
		popup:EnableMouse(true)
		popup:EnableKeyboard(true)
		local popupBackground = popup:CreateTexture(nil, "BACKGROUND")
		popupBackground:SetAllPoints()
		popupBackground:SetColorTexture(0.04, 0.03, 0.02, 1)
		popup:SetScript("OnKeyDown", function(self, key)
			self:SetPropagateKeyboardInput(key ~= "ESCAPE")
			if key == "ESCAPE" then
				self:Hide()
			end
		end)
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
		popup:Hide()
		picker:SetScript("OnClick", function()
			popup:SetShown(not popup:IsShown())
		end)
		heading:SetPoint("RIGHT", picker, "LEFT", -8, 0)
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
		-- Building and retargeting wait for the end of combat; leaving the interior never does. What the host
		-- still holds is another dungeon's, or one the map has since closed on, so it steps aside until then.
		if InCombatLockdown() then
			Hide()
			pending = true
			return
		end
		pending = false
		local found = Model.Floors(AtlasMaps, inside)
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

	local Provider = CreateFromMixins(MapCanvasDataProviderMixin)
	Provider.RefreshAllData = Refresh
	map:AddDataProvider(Provider)
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
