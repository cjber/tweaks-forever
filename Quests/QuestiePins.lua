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
		local span = frame.miniMapIcon and 20 or 24
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
