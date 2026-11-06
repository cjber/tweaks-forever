---@type string, TFNamespace
local _, ns = ...
local L = ns.L

local KEY = "petTrainerHint"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Pet trainer hint",
	tooltip = "At a pet trainer, names the abilities you know that your pet has not learned, and adds a button "
		.. "that opens Beast Training. Nothing shows in Beast Training itself, and the button waits until combat "
		.. "ends.",
	default = true,
})

-- Beast Training opens the pet training list; its name is the client's own, in every language.
local BEAST_TRAINING = 5149
-- The stock trainer inset ends above the button bar. A note fills a strip of its own above that bar, built from
-- the trainer's own bottom inset so no new art is drawn.
local FOOTER = 26
local SCROLL_HEIGHT = 330
-- Three lines of small text, then the button at the foot of the strip.
local NOTE_HEIGHT = 72

local KINDS = { "available", "unavailable", "used" }

---@class TFPetTrainerHint
local Model = {}
ns.PetTrainerHint = Model

-- The abilities the current pet's spellbook marks as future spells: the ones the hunter has unlocked but the pet
-- has not learned. They are the Pet tab's own "See your trainer" entries, named once each in spellbook order.
---@param Count fun(): number?
---@param Info fun(slot: integer): SpellBookItemInfo?
---@return string[]
function Model.Names(Count, Info)
	local total = Count()
	if not total then
		return {}
	end
	local names, seen = {}, {}
	for slot = 1, total do
		local info = Info(slot)
		if info and info.itemType == Enum.SpellBookItemType.FutureSpell and info.spellID then
			local name = info.name or C_Spell.GetSpellName(info.spellID)
			if name and not seen[name] then
				seen[name] = true
				names[#names + 1] = name
			end
		end
	end
	return names
end

-- The note itself: what the pet lacks, then, when the trainer's own filter hides the ranks the hunter knows and
-- leaves the list empty, why the list looks empty.
---@param petName string
---@param names string[]
---@param hidden boolean
---@return string
function Model.Note(petName, names, hidden)
	local text = L["%s hasn't learned %s."]:format(petName, table.concat(names, ", "))
	if hidden then
		text = text .. "\n" .. L["The ranks you already know are hidden by the filter."]
	end
	return text
end

---@type FontString?
local note
---@type Button?
local teach
-- Whether our strip is currently taken out of the trainer's list, so closing the note puts the stock layout back.
local reserved = false
-- A trainer looked at before its rows and the pet's spellbook could answer; refreshed after combat or login.
local petTrainer
local detecting = false

---@return boolean
local function IsHunter()
	local _, class = UnitClass("player")
	return class == "HUNTER"
end

-- Every spell in the current pet's spellbook, known and future, by ID. A trainer service on the pet's bank marks
-- the NPC as a pet trainer, even when the player's filter hides every row.
---@return table<integer, true>
local function PetSpellIDs()
	local ids = {}
	local total = C_SpellBook.HasPetSpells()
	for slot = 1, total or 0 do
		local info = C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Pet)
		if info and info.spellID then
			ids[info.spellID] = true
		end
	end
	return ids
end

---@param ids table<integer, true>
---@return boolean
local function HasPetService(ids)
	for index = 1, GetNumTrainerServices() do
		local data = C_TooltipInfo.GetTrainerService(index)
		if data and data.id and ids[data.id] then
			return true
		end
	end
	return false
end

-- Looks behind the trainer's filter without changing it: every kind is shown for the look, then the player's own
-- choices are put back exactly.
---@param ids table<integer, true>
---@return boolean
local function LookBehindFilter(ids)
	local shown = {}
	for _, kind in ipairs(KINDS) do
		shown[kind] = GetTrainerServiceTypeFilter(kind)
		if not shown[kind] then
			SetTrainerServiceTypeFilter(kind, true, false)
		end
	end
	local found = HasPetService(ids)
	for _, kind in ipairs(KINDS) do
		if not shown[kind] then
			SetTrainerServiceTypeFilter(kind, false, false)
		end
	end
	return found
end

---@return boolean
local function IsPetTrainer()
	if petTrainer ~= nil then
		return petTrainer
	end
	if detecting then
		return false
	end
	local ids = PetSpellIDs()
	if next(ids) == nil then
		petTrainer = false
		return false
	end
	detecting = true
	petTrainer = HasPetService(ids) or LookBehindFilter(ids)
	detecting = false
	return petTrainer
end

---@return boolean
local function ListHidden()
	return not GetTrainerServiceTypeFilter("used") and GetNumTrainerServices() == 0
end

---@return string?
local function BeastTrainingName()
	local name = C_Spell.GetSpellName(BEAST_TRAINING)
	if name then
		return name
	end
	local info = C_Spell.GetSpellInfo(BEAST_TRAINING)
	return info and info.name
end

-- The note is made out of combat only: its button is a secure spell button, so no part of it may be created,
-- shown, hidden, moved or given an attribute in combat.
local function Make()
	if note or not ClassTrainerFrame then
		return
	end
	local inset = ClassTrainerFrame.bottomInset
	note = inset:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	note:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -8)
	note:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -10, -8)
	note:SetJustifyH("LEFT")
	note:SetWordWrap(true)
	note:SetMaxLines(3)
	note:Hide()
	teach = CreateFrame("Button", nil, inset, "SharedButtonSmallTemplate,SecureActionButtonTemplate") --[[@as Button]]
	teach:SetHeight(22)
	teach:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -10, 8)
	teach:SetText(L["Teach with Beast Training"])
	ns.FitButton(teach, 160)
	teach:RegisterForClicks("AnyUp")
	teach:SetAttribute("type", "spell")
	teach:Hide()
end

-- Gives the note a strip of the trainer's own bottom inset, leaving the stock list and button bar where they were
-- when it goes. Blizzard anchors both again on each update, so this runs after its own update.
---@param shown boolean
local function Layout(shown)
	if not ClassTrainerFrame then
		reserved = false
		return
	end
	if not reserved and not shown then
		return
	end
	if shown then
		ClassTrainerFrame.Inset:SetPoint("BOTTOMRIGHT", ClassTrainerFrame, "BOTTOMRIGHT", -6, FOOTER + NOTE_HEIGHT)
		ClassTrainerFrame.ScrollBox:SetHeight(SCROLL_HEIGHT - NOTE_HEIGHT)
		ClassTrainerFrame.bottomInset:Show()
		reserved = true
	else
		-- A profession trainer uses the same inset for its own step, so leave its layout to Blizzard.
		if not IsTradeskillTrainer() then
			ClassTrainerFrame.Inset:SetPoint("BOTTOMRIGHT", ClassTrainerFrame, "BOTTOMRIGHT", -6, FOOTER)
			ClassTrainerFrame.ScrollBox:SetHeight(SCROLL_HEIGHT)
			ClassTrainerFrame.bottomInset:Hide()
		end
		reserved = false
	end
end

local function Hide()
	if note then
		note:Hide()
	end
	if teach then
		teach:Hide()
	end
	Layout(false)
end

---@param names string[]
local function Show(names)
	local petName = ns.Readable(UnitName("pet")) -- multi-value: Readable keeps the name
	if not petName then
		Hide()
		return
	end
	Make()
	if not note then
		return
	end
	note:SetText(Model.Note(petName, names, ListHidden()))
	note:Show()
	Layout(true)
	local spell = BeastTrainingName()
	if teach and spell then
		teach:SetAttribute("spell", spell)
		teach:Show()
	elseif teach then
		teach:Hide()
	end
end

local function Refresh()
	if InCombatLockdown() then
		return
	end
	if
		not (ns.Active(KEY) and ClassTrainerFrame and ClassTrainerFrame:IsShown())
		or not IsHunter()
		or not UnitExists("pet")
		or C_Trainer.GetTrainerType() == Enum.TrainerType.Pet
		or IsTradeskillTrainer()
	then
		Hide()
		return
	end
	if not IsPetTrainer() then
		Hide()
		return
	end
	local names = Model.Names(C_SpellBook.HasPetSpells, function(slot)
		return C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Pet)
	end)
	if #names == 0 then
		Hide()
		return
	end
	Show(names)
end

-- Installed once the trainer frame exists. The update is Blizzard's own global, so this runs after its list and
-- inset have been laid out again.
local hooked = false
local function Install()
	if hooked or not ClassTrainerFrame then
		return
	end
	hooked = true
	hooksecurefunc("ClassTrainerFrame_Update", Refresh)
	Refresh()
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
	ns.On("TRAINER_SHOW", function()
		petTrainer = nil
	end)
	ns.On("TRAINER_CLOSED", function()
		petTrainer = nil
		Refresh()
	end)
	ns.On("PLAYER_REGEN_ENABLED", Refresh)
	ns.On("SPELLS_CHANGED", Refresh)
	ns.On("UNIT_PET", function(unit)
		if unit == "player" then
			Refresh()
		end
	end)
	ns.OnSettingChanged(KEY, Refresh)
end)
