---@type string, TFNamespace
local _, ns = ...

-- Fishing addons that already cast on a double-click and manage lures and sound.
local FISHING_ADDONS = { { addon = "FishingBuddy" }, { addon = "FishingAce" } }

ns.Feature({
	key = "easyCast",
	category = "Fishing",
	name = "Double right-click to fish",
	tooltip = "With a fishing pole equipped, double right-click anywhere in the world to cast Fishing. "
		.. "Does nothing in combat or while mounted.",
	default = true,
	conflicts = FISHING_ADDONS,
})

ns.Feature({
	key = "applyLure",
	category = "Fishing",
	name = "Put on a lure first",
	tooltip = "When your pole has no lure, the double-click puts on the best lure in your bags that your "
		.. "fishing skill allows. Double right-click again to cast.",
	default = true,
	parent = "easyCast",
	conflicts = FISHING_ADDONS,
})

ns.Feature({
	key = "lureWarning",
	category = "Fishing",
	name = "Warn when your pole has no lure",
	tooltip = "A message when you log in or equip a fishing pole without a lure, and each time you cast without one.",
	default = true,
	conflicts = FISHING_ADDONS,
})

ns.Feature({
	key = "fishingSounds",
	category = "Fishing",
	name = "Louder splashes while fishing",
	tooltip = "While a fishing pole is equipped, sound effects play at full volume and music and ambience "
		.. "are silenced, so the bobber's splash is easy to hear. Your volumes come back when you unequip it.",
	default = false,
	conflicts = FISHING_ADDONS,
})

local FISHING_SPELL = 7620
local DOUBLE_CLICK = 0.4
local MIN_DOUBLE_CLICK = 0.05

-- Classic lures, best first, with the fishing skill each needs (ItemSparse RequiredSkillRank).
local LURES = {
	{ item = 6533, skill = 100 }, -- Aquadynamic Fish Attractor, +100
	{ item = 6532, skill = 100 }, -- Bright Baubles, +75
	{ item = 7307, skill = 100 }, -- Flesh Eating Worm, +75
	{ item = 6530, skill = 50 }, -- Nightcrawlers, +50
	{ item = 6811, skill = 50 }, -- Aquadynamic Fish Lens, +50
	{ item = 6529, skill = 0 }, -- Shiny Bauble, +25
}

local SOUNDS = { Sound_SFXVolume = "1", Sound_MusicVolume = "0", Sound_AmbienceVolume = "0" }

---@class TFFishing
local Model = {}
ns.Fishing = Model

---@param last number?
---@param now number
---@return boolean
function Model.IsDoubleClick(last, now)
	return last ~= nil and now - last < DOUBLE_CLICK and now - last > MIN_DOUBLE_CLICK
end

-- The best lure carried that this fishing skill can use, or nil. count(item) is how many are in the bags.
---@param count fun(item: integer): number
---@param skill number
---@return integer?
function Model.BestLure(count, skill)
	for _, lure in ipairs(LURES) do
		if skill >= lure.skill and count(lure.item) > 0 then
			return lure.item
		end
	end
end

---@param item integer
---@return boolean
function Model.IsPole(item)
	local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(item)
	return classID == Enum.ItemClass.Weapon and subclassID == Enum.ItemWeaponSubclass.Fishingpole
end

local function HasPole()
	local item = GetInventoryItemID("player", INVSLOT_MAINHAND)
	return item ~= nil and Model.IsPole(item)
end

local function HasLure()
	return C_PaperDollInfo.GetTemporaryEnchantmentInfo(INVSLOT_MAINHAND) ~= nil
end

local function FishingSkill()
	-- Camelot's order: two primary professions, first aid, fishing, cooking.
	local fishing = select(4, GetProfessions())
	return fishing and select(3, GetProfessionInfo(fishing)) or 0
end

local function WarnNoLure()
	if ns.Active("lureWarning") and HasPole() and not HasLure() then
		UIErrorsFrame:AddMessage("Your fishing pole has no lure.", YELLOW_FONT_COLOR:GetRGB())
	end
end

local function RestoreSounds()
	if ns.db.savedSounds then
		for cvar, value in pairs(ns.db.savedSounds) do
			SetCVar(cvar, value)
		end
		ns.db.savedSounds = nil
	end
end

-- Save the player's volumes once, then hold the fishing ones while a pole is equipped. The saved copy lives in
-- SavedVariables, so volumes left raised by a crash come back at the next login without a pole.
local function UpdateSounds()
	if not (ns.Active("fishingSounds") and HasPole()) then
		RestoreSounds()
	elseif not ns.db.savedSounds then
		ns.db.savedSounds = {}
		for cvar, value in pairs(SOUNDS) do
			ns.db.savedSounds[cvar] = GetCVar(cvar)
			SetCVar(cvar, value)
		end
	end
end

ns.Init(function()
	local fishing = C_Spell.GetSpellName(FISHING_SPELL)

	-- A right-click on the world normally turns the camera, so for one press BUTTON2 is bound to this button.
	-- Forever has no secure snippets (loadstring_untainted is nil), so PostClick clears the binding instead.
	-- It acts on release: the press already belongs to the binding, and the release is when the click lands.
	local button = CreateFrame("Button", "TweaksForeverFishingButton", UIParent, "SecureActionButtonTemplate")
	button:RegisterForClicks("AnyDown", "AnyUp")
	button:SetAttribute("useOnKeyDown", false)
	button:SetScript("PostClick", function(self, _, down)
		if not down and not InCombatLockdown() then
			ClearOverrideBindings(self)
		end
	end)

	local lastClick
	ns.On("GLOBAL_MOUSE_DOWN", function(mouseButton)
		if mouseButton ~= "RightButton" then
			return
		end
		local now = GetTime()
		local double = Model.IsDoubleClick(lastClick, now)
		lastClick = not double and now or nil
		if
			not double
			or not ns.Active("easyCast")
			or InCombatLockdown()
			or IsMounted()
			-- Over open world the list may be empty rather than WorldFrame; a UI frame keeps its own click.
			or (GetMouseFoci()[1] or WorldFrame) ~= WorldFrame
			or not HasPole()
		then
			return
		end
		local lure = ns.Active("applyLure") and not HasLure() and Model.BestLure(C_Item.GetItemCount, FishingSkill())
		-- An item that targets an item (a lure) goes on target-slot once used.
		button:SetAttribute("type", lure and "item" or "spell")
		button:SetAttribute("item", lure and "item:" .. lure)
		button:SetAttribute("target-slot", lure and INVSLOT_MAINHAND)
		button:SetAttribute("spell", fishing)
		-- The press started camera turning; without the release it would never stop.
		if IsMouselooking() then
			MouselookStop()
		end
		SetOverrideBindingClick(button, true, "BUTTON2", button:GetName())
	end)

	-- Only your own casts: another unit's may carry secret arguments.
	local channels = CreateFrame("Frame")
	channels:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
	channels:SetScript("OnEvent", function(_, _, _, _, spellID)
		if canaccessvalue(spellID) and C_Spell.GetSpellName(spellID) == fishing then
			WarnNoLure()
		end
	end)
	-- A pole already in hand at login or after a reload never fires PLAYER_EQUIPMENT_CHANGED.
	ns.On("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
		if isLogin or isReload then
			WarnNoLure()
		end
	end)
	ns.On("PLAYER_EQUIPMENT_CHANGED", function(slot)
		if slot == INVSLOT_MAINHAND then
			WarnNoLure()
			UpdateSounds()
		end
	end)
	-- Combat started between the press and the release, so PostClick could not clear the binding.
	ns.On("PLAYER_REGEN_ENABLED", function()
		ClearOverrideBindings(button)
	end)
	-- SavedVariables are written after this, so the restored volumes stay restored if the game closes.
	ns.On("PLAYER_LOGOUT", RestoreSounds)
	Settings.SetOnValueChangedCallback("TweaksForever_fishingSounds", UpdateSounds)
	UpdateSounds()
end)
