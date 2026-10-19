---@type string, TFNamespace
local _, ns = ...

local KEY = "nativeQuestiePins"
ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Native quest map icons",
	tooltip = "Uses the game's quest symbols at a readable size for Questie's map and minimap markers. "
		.. "Keeps Questie's locations and tooltips. Turn off to restore Questie's appearance.",
	default = true,
	needs = {
		title = "Questie",
		check = function()
			return QuestieLoader ~= nil
		end,
	},
})

-- Questie's pin types, not its saved profile: replacing the art leaves every location and objective intact.
local ATLASES = {
	[1] = "questobjective",
	[2] = "questobjective",
	[3] = "questobjective",
	[4] = "questobjective",
	[5] = "questobjective",
	[6] = "questnormal",
	[7] = "questnormal",
	[8] = "questturnin",
	[10] = "questdaily",
	[11] = "questrepeatableturnin",
	[12] = "SideInProgressquesticon",
	[13] = "questdaily",
	[14] = "questrepeatableturnin",
	[15] = "questnormal",
	[16] = "questturnin",
	[17] = "questobjective",
}

-- The setting each kind of pin takes its size from in Questie's options (Questie.ICON_TYPE_*): objectives by what they
-- ask, and quests to pick up or hand in by one. A kind not listed follows the map or minimap slider alone.
local KIND_SCALES = {
	[1] = "monsterScale",
	[2] = "lootScale",
	[3] = "eventScale",
	[4] = "objectScale",
	[6] = "availableScale",
	[7] = "availableScale",
	[8] = "availableScale",
	[10] = "availableScale",
	[11] = "availableScale",
	[12] = "availableScale",
	[13] = "availableScale",
	[14] = "availableScale",
	[15] = "availableScale",
	[16] = "availableScale",
}

-- How far the player has moved Questie's own sliders from their defaults: Map Icons or Minimap Icons, and the one
-- for the pin's kind. The symbols keep their readable size at Questie's defaults and follow the sliders from there;
-- the map's zoom stays out, so zooming out never shrinks them. A setting it cannot read counts as unmoved.
---@param frame TFQuestiePin
---@return number
local function QuestieSliders(frame)
	local db = Questie and Questie.db
	local profile, defaults = db and db.profile, db and db.defaults and db.defaults.profile
	if type(profile) ~= "table" or type(defaults) ~= "table" then
		return 1
	end
	---@param key string?
	local function Ratio(key)
		local value, default = key and tonumber(profile[key]), key and tonumber(defaults[key])
		return value and default and default > 0 and value / default or 1
	end
	local kind = frame.data and KIND_SCALES[frame.data.Icon]
	return Ratio(frame.miniMapIcon and "globalMiniMapScale" or "globalScale") * Ratio(kind)
end

ns.Init(function()
	if not QuestieLoader then
		return
	end
	local map = QuestieLoader:ImportModule("QuestieMap")
	if not (map.utils and map.utils.SetDrawOrder and map.utils.RescaleIcon and map.questIdFrames) then
		return
	end
	---@type table<TFQuestiePin, boolean>
	local watched = setmetatable({}, { __mode = "k" })
	-- Pins whose texture last drew an atlas of ours: it keeps that atlas's place on its sheet as its coordinates,
	-- so a file Questie sets over it would show only that corner of the file until they are reset.
	---@type table<TFQuestiePin, boolean>
	local cropped = setmetatable({}, { __mode = "k" })
	---@param frame TFQuestiePin
	local function Style(frame)
		local kind = frame.data and frame.data.Icon
		local atlas = ns.Active(KEY) and not frame.isManualIcon and kind and ATLASES[kind]
		local info = atlas and C_Texture.GetAtlasInfo(atlas)
		if not atlas or not info then
			if cropped[frame] then
				cropped[frame] = nil
				frame.texture:SetTexCoord(0, 1, 0, 1)
			end
			return
		end
		local span = (frame.miniMapIcon and 20 or 24) * QuestieSliders(frame)
		local scale = span / math.max(info.width, info.height)
		frame:SetSize(info.width * scale, info.height * scale)
		frame.texture:SetAtlas(atlas) -- art-ok: the pin, which the texture fills, takes the atlas's aspect above
		cropped[frame] = true
		local _, _, _, alpha = frame.texture:GetVertexColor()
		local shade = kind == 7 and 0.55 or 1
		frame.texture:SetVertexColor(shade, shade, shade, alpha)
	end
	---@param frame TFQuestiePin
	local function Watch(frame)
		if not watched[frame] and frame.UpdateTexture then
			watched[frame] = true
			hooksecurefunc(frame, "UpdateTexture", Style) -- taint-ok: Questie-owned addon method, never a Blizzard frame method.
		end
		Style(frame)
	end
	hooksecurefunc(map.utils, "SetDrawOrder", Watch) -- taint-ok: Questie module, observes drawn pins.
	hooksecurefunc(map.utils, "RescaleIcon", function(ref) -- taint-ok: Questie module, observes zoom resizing.
		local frame = type(ref) == "string" and _G[ref] or ref
		if frame then
			Watch(frame)
		end
	end)
	local function Refresh()
		for _, names in pairs(map.questIdFrames) do
			for _, name in pairs(names) do
				local frame = _G[name] --[[@as TFQuestiePin?]]
				if frame and frame.data and not frame.isManualIcon then
					if ns.Active(KEY) then
						Watch(frame)
					elseif watched[frame] and Questie and Questie.usedIcons then
						frame:UpdateTexture(Questie.usedIcons[frame.data.Icon])
						map.utils.RescaleIcon(frame, map.GetScaleValue())
					end
				end
			end
		end
	end
	ns.OnSettingChanged(KEY, Refresh)
	Refresh()
end)
