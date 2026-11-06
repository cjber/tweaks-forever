---@type string, TFNamespace
local _, ns = ...

local KEY = "talentReminder"
-- A soft gold glow around the talents micro button while points wait to be spent.
local GLOW_ATLAS = "collections-newglow"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Unspent talent reminder",
	tooltip = "A soft glow over the talents button while you have unspent talent points, or your pet has unspent "
		.. "training points, until they are spent. Nothing in combat.",
	default = true,
})

---@class TFTalentReminder
local Model = {}
ns.TalentReminder = Model

-- The client's own count of unspent class and spec talent points, with the classic count as a fallback for a tree
-- the newer API does not report (Forever has one talent currency).
---@return integer
local function TalentPoints()
	local points = 0
	if C_ClassTalents and C_ClassTalents.HasUnspentTalentPoints then
		local has, classPoints, specPoints = C_ClassTalents.HasUnspentTalentPoints()
		if has then
			points = (classPoints or 0) + (specPoints or 0)
		end
	end
	if points == 0 and GetNumUnspentTalents then
		points = GetNumUnspentTalents() or 0
	end
	return points
end

-- A pet's training points: the total it has earned less the ones already spent.
---@return integer
local function PetPoints()
	local total, used = C_PetInfo.GetPetTrainingPoints()
	return math.max((total or 0) - (used or 0), 0)
end

-- Both counts, for the reminder and its glow.
---@return integer talent
---@return integer pet
function Model.Unspent()
	return TalentPoints(), PetPoints()
end

---@type Frame?
local glow

-- Our own frame and texture over the talents button: the button itself is never written to, only anchored to.
---@return Frame?
local function Glow()
	if glow then
		return glow
	end
	if not TalentMicroButton then
		return nil
	end
	glow = CreateFrame("Frame", nil, UIParent)
	glow:SetFrameStrata("MEDIUM")
	glow:SetFrameLevel(TalentMicroButton:GetFrameLevel() + 5)
	glow:SetPoint("CENTER", TalentMicroButton, "CENTER")
	local texture = glow:CreateTexture(nil, "OVERLAY")
	ns.Art.Fit(texture, GLOW_ATLAS, 46, 46)
	texture:SetPoint("CENTER")
	texture:SetBlendMode("ADD")
	texture:SetVertexColor(1, 0.82, 0)
	glow:Hide()
	return glow
end

-- The glow follows the points, and waits out combat: nothing of ours is drawn there.
local function Refresh()
	local frame = Glow()
	if not frame then
		return
	end
	if not ns.Active(KEY) or InCombatLockdown() then
		frame:Hide()
		return
	end
	local talent, pet = Model.Unspent()
	frame:SetShown(talent > 0 or pet > 0)
end

ns.Init(function()
	Refresh()
	ns.On("PLAYER_LEVEL_UP", Refresh)
	-- Spending a point clears the glow at once, whichever window is open.
	for _, event in ipairs({
		"CHARACTER_POINTS_CHANGED",
		"TRAIT_CONFIG_UPDATED",
		"TRAIT_NODE_CHANGED",
		"TRAIT_TREE_CURRENCY_INFO_UPDATED",
		"PLAYER_TALENT_UPDATE",
		"UNIT_PET",
		"UNIT_PET_TRAINING_POINTS",
	}) do
		ns.On(event, Refresh)
	end
	ns.On("PLAYER_ENTERING_WORLD", Refresh)
	ns.On("PLAYER_REGEN_DISABLED", Refresh)
	ns.On("PLAYER_REGEN_ENABLED", Refresh)
	ns.OnSettingChanged(KEY, Refresh)
end)
