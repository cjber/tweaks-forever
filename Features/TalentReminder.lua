---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

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

-- The player's unspent talent points, read the way Forever's own talent frame reads them: a class talent tree is a
-- trait tree, and the quantity left of its first tree currency is what the frame's UNSPENT_POINTS display shows
-- (Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua, RefreshClassCurrencyDisplay). The
-- class and spec counts (C_ClassTalents.HasUnspentTalentPoints) cover mainline's separate class and spec trees, and
-- the classic count (GetNumUnspentTalents) the talent system Forever replaced; neither is what this frame reads.
---@return integer
local function TalentPoints()
	local configID = C_ClassTalents.GetActiveConfigID()
	if not configID then
		return 0
	end
	local config = C_Traits.GetConfigInfo(configID)
	local treeID = config and config.treeIDs[1]
	if not treeID then
		return 0
	end
	-- Staged spends count as spent, as they do in the frame: its `excludeStagedChangesForCurrencies` is false.
	local currencies = C_Traits.GetTreeCurrencyInfo(configID, treeID, false)
	local currency = currencies and currencies[1]
	return currency and currency.quantity or 0
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
	-- The micro menu's own strata, and a level above the menu itself (frameLevel 51 in Camelot's
	-- Blizzard_MicroMenu/Camelot/MainMenuBarMicroMenu.xml): our frame is no child of it, so nothing else lifts it.
	glow:SetFrameStrata(TalentMicroButton:GetFrameStrata())
	local level = TalentMicroButton:GetFrameLevel()
	if MicroMenu then
		level = math.max(level, MicroMenu:GetFrameLevel())
	end
	glow:SetFrameLevel(level + 5)
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
	-- A point earned or spent arrives as a tree currency update; the level-up is the earliest hint of one.
	ns.On("TRAIT_TREE_CURRENCY_INFO_UPDATED", Refresh)
	ns.On("PLAYER_LEVEL_UP", Refresh)
	-- Spending a point clears the glow at once, whichever window is open.
	for _, event in ipairs({
		"CHARACTER_POINTS_CHANGED",
		"TRAIT_CONFIG_UPDATED",
		"TRAIT_NODE_CHANGED",
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
