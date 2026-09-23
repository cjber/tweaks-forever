---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "trainableSpells",
	category = "Interface",
	name = "Show spells left to train",
	tooltip = "The spellbook says how many spells you can learn from your class trainer now and when the next ones "
		.. "come. Hover it for the list. The trainer's list is remembered each time you visit one.",
	default = true,
})

---@class TFTrainable
local Model = {}
ns.Trainable = Model

-- The trainer rows worth keeping: ones you can learn now and ones your level does not allow yet. "used" is learned.
local KEEP = { available = true, unavailable = true }

---@param a TFTrainerSpell
---@param b TFTrainerSpell
local function ByName(a, b)
	if a.name ~= b.name then
		return a.name < b.name
	end
	return (a.rank or "") < (b.rank or "")
end

-- The remembered spells not yet known: those your level allows, and the rest in groups by level, lowest first.
---@param spells table<integer, TFTrainerSpell>
---@param level number
---@param IsKnown fun(id: integer): boolean?
---@return TFTrainerSpell[] ready
---@return TFTrainerGroup[] later
function Model.Plan(spells, level, IsKnown)
	---@type TFTrainerSpell[], TFTrainerGroup[], table<number, TFTrainerGroup>
	local ready, later, byLevel = {}, {}, {}
	for id, spell in pairs(spells) do
		if not IsKnown(id) then
			if spell.level <= level then
				ready[#ready + 1] = spell
			else
				local group = byLevel[spell.level]
				if not group then
					group = { level = spell.level }
					byLevel[spell.level] = group
					later[#later + 1] = group
				end
				group[#group + 1] = spell
			end
		end
	end
	table.sort(ready, ByName)
	table.sort(later, function(a, b)
		return a.level < b.level
	end)
	for _, group in ipairs(later) do
		table.sort(group, ByName)
	end
	return ready, later
end

local function Count(n)
	return n == 1 and "1 spell" or n .. " spells"
end

---@param ready TFTrainerSpell[]
---@param later TFTrainerGroup[]
---@return string
function Model.Summary(ready, later)
	local parts = {}
	if #ready > 0 then
		parts[1] = GREEN_FONT_COLOR:WrapTextInColorCode(Count(#ready)) .. " ready to train"
	end
	if later[1] then
		parts[#parts + 1] = ("Next: level %d (%s)"):format(later[1].level, Count(#later[1]))
	end
	return #parts > 0 and table.concat(parts, "  ·  ") or "Every trainer spell learned"
end

---@param spell TFTrainerSpell
---@return string
function Model.Label(spell)
	return spell.rank and ("%s (%s)"):format(spell.name, spell.rank) or spell.name
end

ns.Init(function()
	TweaksForeverCharDB = TweaksForeverCharDB or {}
	---@type Frame, FontString, TFTrainerSpell[]?, TFTrainerGroup[]?
	local bar, text, ready, later

	local function Known(id)
		return C_SpellBook.IsSpellKnown(id)
	end

	local function ShowTooltip()
		if not ready or not later then
			return
		end
		GameTooltip:SetOwner(bar, "ANCHOR_NONE")
		GameTooltip:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -4)
		GameTooltip_SetTitle(GameTooltip, "Trainer spells")
		if #ready > 0 then
			GameTooltip_AddNormalLine(GameTooltip, "Ready to train")
			for _, spell in ipairs(ready) do
				GameTooltip:AddLine(("|T%s:0|t %s"):format(spell.icon, Model.Label(spell)), GREEN_FONT_COLOR:GetRGB())
			end
		end
		if later[1] then
			GameTooltip_AddBlankLineToTooltip(GameTooltip)
			GameTooltip_AddNormalLine(GameTooltip, "Coming up")
			for _, group in ipairs(later) do
				local names = {}
				for i, spell in ipairs(group) do
					names[i] = Model.Label(spell)
				end
				local level = NORMAL_FONT_COLOR:WrapTextInColorCode(("Level %d:"):format(group.level))
				GameTooltip:AddLine(level .. " " .. table.concat(names, ", "), 0.6, 0.6, 0.6, true)
			end
		end
		GameTooltip:Show()
	end

	-- Level up reports the new level before UnitLevel has it.
	---@param level? number
	local function Refresh(level)
		if not bar or not bar:GetParent():IsVisible() then
			return
		end
		bar:SetShown(ns.Active("trainableSpells"))
		if not bar:IsShown() then
			return
		end
		local spells = TweaksForeverCharDB.trainer
		if spells then
			ready, later = Model.Plan(spells, level or UnitLevel("player"), Known)
			text:SetText(Model.Summary(ready, later))
		else
			ready, later = nil, nil
			text:SetText("Visit your class trainer to see upcoming spells")
		end
		bar:SetWidth(text:GetStringWidth())
		if GameTooltip:GetOwner() == bar then
			ShowTooltip()
		end
	end

	-- Our own frame in the blank strip above the left page, never inside Blizzard's secure spell grid.
	local function Create()
		local book = PlayerSpellsFrame.SpellBookFrame
		bar = CreateFrame("Frame", nil, book)
		bar:SetPoint("TOPLEFT", 85, -72)
		bar:SetHeight(24)
		bar:SetMouseMotionEnabled(true)
		text = bar:CreateFontString(nil, "OVERLAY", "SystemFont_Med3")
		text:SetPoint("LEFT")
		text:SetTextColor(SPELLBOOK_FONT_COLOR:GetRGB())
		bar:SetScript("OnEnter", ShowTooltip)
		bar:SetScript("OnLeave", GameTooltip_Hide)
	end

	-- The server keeps unlearned spells out of the spellbook, so the class trainer's list is the only full one. It
	-- lists only the kinds its filter shows: show both for the scan, then put the filter back as it was. Rows merge
	-- by spell, so another trainer (weapons, riding) adds to the list rather than replacing it.
	ns.On("TRAINER_SHOW", function()
		if not ns.Active("trainableSpells") or IsTradeskillTrainer() then
			return
		end
		if C_Trainer.GetTrainerType() ~= Enum.TrainerType.General then
			return
		end
		local shown = {}
		for kind in pairs(KEEP) do
			if not GetTrainerServiceTypeFilter(kind) then
				shown[#shown + 1] = kind
				SetTrainerServiceTypeFilter(kind, true, false)
			end
		end
		local spells = TweaksForeverCharDB.trainer or {}
		for i = 1, GetNumTrainerServices() do
			local name, kind, icon, level, rank = GetTrainerServiceInfo(i)
			local data = KEEP[kind] and C_TooltipInfo.GetTrainerService(i)
			if data and data.id then
				spells[data.id] = {
					name = name or C_Spell.GetSpellName(data.id),
					rank = rank ~= "" and rank or nil,
					level = level or 1,
					icon = icon,
				}
			end
		end
		for _, kind in ipairs(shown) do
			SetTrainerServiceTypeFilter(kind, false, false)
		end
		if next(spells) then
			TweaksForeverCharDB.trainer = spells
			Refresh()
		end
	end)

	EventRegistry:RegisterCallback("PlayerSpellsFrame.SpellBookFrame.Show", function()
		if not bar then
			Create()
		end
		Refresh()
	end)
	ns.On("SPELLS_CHANGED", Refresh)
	ns.On("PLAYER_LEVEL_UP", Refresh)
	Settings.SetOnValueChangedCallback("TweaksForever_trainableSpells", function()
		Refresh()
	end)
end)
