---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

local KEY = "beastTrainingKnown"
-- How far a known row fades, matching the way the client dims something already learned.
local KNOWN_ALPHA = 0.5

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Known ranks in Beast Training",
	tooltip = "In Beast Training, marks the ranks your pet already knows, or has replaced with a higher rank, as known, "
		.. "so they no longer look like ranks still to learn.",
	default = true,
})

---@class TFBeastTraining
local Model = {}
ns.BeastTraining = Model

-- The rank number in a "Rank 3" subtext, in any client language's wording; nil for a row with no rank.
---@param subtext string?
---@return integer?
local function RankOf(subtext)
	local rank = subtext and subtext:match("%d+")
	return rank and tonumber(rank)
end

-- The rows whose spell the pet already knows, or whose rank is below one it knows: a higher rank replaces the
-- lower one even when the client still offers it.
---@param services TFBeastTrainingService[]
---@param Known fun(id: integer): boolean
---@return table<integer, true>
function Model.KnownIndices(services, Known)
	local knownRank = {}
	for _, service in ipairs(services) do
		if service.name and service.rank and Known(service.id) then
			if not knownRank[service.name] or service.rank > knownRank[service.name] then
				knownRank[service.name] = service.rank
			end
		end
	end
	local known = {}
	for _, service in ipairs(services) do
		if
			Known(service.id)
			or (service.name and service.rank and knownRank[service.name] and service.rank < knownRank[service.name])
		then
			known[service.index] = true
		end
	end
	return known
end

-- Our label on each row button, keyed weakly by the button: Blizzard's own regions are only ever given an alpha,
-- never written to or shown and hidden.
---@type table<ClassTrainerSkillButtonTemplate, FontString>
local labels = setmetatable({}, { __mode = "k" })
-- The element data each tracked button was last drawn for, so the rows can be repainted when the known set changes.
---@type table<ClassTrainerSkillButtonTemplate, TFClassTrainerElement>
local rows = setmetatable({}, { __mode = "k" })
-- The rows the current list counts as known, filled once per ClassTrainerFrame_Update.
---@type table<integer, true>
local known = {}

---@param button ClassTrainerSkillButtonTemplate
---@return FontString
local function Label(button)
	local label = labels[button]
	if not label then
		label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("LEFT", button.subText, "LEFT")
		label:SetTextColor(GRAY_FONT_COLOR:GetRGB()) -- multi-value: r, g, b
		label:SetText(ITEM_SPELL_KNOWN)
		label:Hide()
		labels[button] = label
	end
	return label
end

-- Puts a row back the way Blizzard drew it, for a recycled button, another trainer's row or the option off.
---@param button ClassTrainerSkillButtonTemplate
local function Restore(button)
	local label = labels[button]
	if not label then
		return
	end
	button.icon:SetAlpha(1)
	button.name:SetAlpha(1)
	button.subText:SetAlpha(1)
	button.alternateCost:SetAlpha(1)
	label:Hide()
end

-- Dims a known row's icon and name, hides its requirement line and training point cost, and shows our own
-- "Already known" where the requirement line sits.
---@param button ClassTrainerSkillButtonTemplate
local function MarkKnown(button)
	local label = Label(button)
	button.icon:SetAlpha(KNOWN_ALPHA)
	button.name:SetAlpha(KNOWN_ALPHA)
	button.subText:SetAlpha(0)
	button.alternateCost:SetAlpha(0)
	label:Show()
end

---@param button ClassTrainerSkillButtonTemplate
---@param data TFClassTrainerElement
local function Paint(button, data)
	rows[button] = data
	if ns.Active(KEY) and data.trainerType == Enum.TrainerType.Pet and known[data.skillIndex] then
		MarkKnown(button)
	else
		Restore(button)
	end
end

---@param skillButton ClassTrainerSkillButtonTemplate
---@param elementData TFClassTrainerElement?
local function InitServiceButton(skillButton, elementData)
	local data = elementData and (elementData.data or elementData)
	if not data then
		Restore(skillButton)
		return
	end
	Paint(skillButton, data)
end

-- Every service the pet trainer lists, with the number in its rank subtext. The spell ID comes from the tooltip
-- data, as it does in UI/PetTrainer.lua.
---@return TFBeastTrainingService[]
local function Services()
	local services = {}
	for index = 1, GetNumTrainerServices() do
		local name, _, _, _, rank = GetTrainerServiceInfo(index)
		local data = C_TooltipInfo.GetTrainerService(index)
		if data and data.id then
			services[#services + 1] = {
				index = index,
				id = data.id,
				name = name or C_Spell.GetSpellName(data.id),
				rank = RankOf(rank),
			}
		end
	end
	return services
end

-- The known set is built once for the list Blizzard has just filled. Blizzard initializes its rows during its own
-- update, so every row already drawn is repainted from its own element data once the set is current.
local function Update()
	known = {}
	if ns.Active(KEY) and C_Trainer.GetTrainerType() == Enum.TrainerType.Pet then
		local Known = function(id)
			return ns.KnownSpell(id, true)
		end
		known = Model.KnownIndices(Services(), Known)
	end
	for button, data in pairs(rows) do
		Paint(button, data)
	end
end

local hooked = false
local function Install()
	if hooked or not ClassTrainerFrame then
		return
	end
	hooked = true
	hooksecurefunc("ClassTrainerFrame_Update", Update)
	hooksecurefunc("ClassTrainerFrame_InitServiceButton", InitServiceButton)
end

ns.Init(function()
	ns.On("ADDON_LOADED", function(addon)
		if addon == "Blizzard_TrainerUI" then
			Install()
		end
	end)
	if C_AddOns.IsAddOnLoaded("Blizzard_TrainerUI") then
		Install()
	end
	ns.OnSettingChanged(KEY, function()
		if not ns.Active(KEY) then
			known = {}
			for button in pairs(labels) do
				Restore(button)
			end
		end
	end)
end)
