-- luacheck: read globals scenario ADDON
-- A pet trainer beside the class trainer: the stock frame, with the client's own future spells on the pet bank,
-- then combat. The trainer is Blizzard's real one, loaded on demand as the client loads it.
scenario("a pet trainer names what the pet has not learned", function(sim)
	dofile("tests/sim/forever_core.lua").install(sim)
	sim:login()
	local G = sim.G
	local filters = { available = true, unavailable = true, used = false }
	local services = {
		{ id = 2649, kind = "used", name = "Growl" },
		{ id = 1082, kind = "used", name = "Claw" },
	}
	local pet = {
		{ itemType = 2, spellID = 2649, name = "Growl" },
		{ itemType = 2, spellID = 1082, name = "Claw" },
	}
	local names = { [5149] = "Beast Training", [2649] = "Growl", [1082] = "Claw" }
	local function visible()
		local rows = {}
		for _, service in ipairs(services) do
			if filters[service.kind] then
				rows[#rows + 1] = service
			end
		end
		return rows
	end

	G.C_Trainer = {
		GetTrainerType = function()
			return 0
		end,
	}
	G.Enum.TrainerType = { General = 0, Pet = 3 }
	G.Enum.SpellBookSpellBank = G.Enum.SpellBookSpellBank or { Pet = 1 }
	G.Enum.SpellBookItemType = G.Enum.SpellBookItemType or { FutureSpell = 2, PetAction = 3 }
	G.GetNumTrainerServices = function()
		return #visible()
	end
	G.GetTrainerServiceInfo = function(index)
		local row = visible()[index]
		if row then
			return row.name, row.kind, 134400, 1, "", ""
		end
	end
	G.GetTrainerServiceTypeFilter = function(kind)
		return filters[kind]
	end
	G.SetTrainerServiceTypeFilter = function(kind, shown)
		filters[kind] = shown
	end
	G.GetTrainerServiceStepIndex = function()
		return nil
	end
	G.GetTrainerTradeskillRankValues = function()
		return nil
	end
	G.GetTrainerServiceCost = function()
		return 0
	end
	G.GetTrainerServiceSkillReq = function()
		return nil
	end
	G.GetMoney = function()
		return 0
	end
	G.IsTradeskillTrainer = function()
		return false
	end
	G.GetCategorizeTrainerUI = function()
		return nil
	end
	G.C_TooltipInfo = G.C_TooltipInfo or {}
	G.C_TooltipInfo.GetTrainerService = function(index)
		return visible()[index]
	end
	G.C_SpellBook = G.C_SpellBook or {}
	G.C_SpellBook.HasPetSpells = function()
		return #pet
	end
	G.C_SpellBook.GetSpellBookItemInfo = function(slot)
		return pet[slot]
	end
	G.C_Spell = G.C_Spell or {}
	G.C_Spell.GetSpellName = function(id)
		return names[id]
	end
	G.C_Spell.GetSpellInfo = function(id)
		return names[id] and { name = names[id] }
	end
	G.UnitClass = function()
		return "Hunter", "HUNTER"
	end
	G.UnitExists = function(unit)
		return unit == "pet"
	end
	G.UnitName = function(unit)
		return unit == "pet" and "Claws" or "Player"
	end

	sim:loadBlizzard("Blizzard_FrameXML/SecureTemplates.xml")
	sim:loadBlizzard("Blizzard_TrainerUI")
	sim:showPanel(G.ClassTrainerFrame)

	local inset = G.ClassTrainerFrame.bottomInset
	assert(inset:IsShown(), "the note takes the trainer's own bottom inset")
	local text
	for _, region in ipairs({ inset:GetRegions() }) do
		if region:GetObjectType() == "FontString" then
			text = region:GetText()
		end
	end
	assert(text and text:find("Claws hasn't learned Growl, Claw.", 1, true), "note text: " .. tostring(text))
	assert(text:find("hidden by the filter", 1, true), "the filter line: " .. tostring(text))
	local button
	for _, child in ipairs({ inset:GetChildren() }) do
		if child:GetObjectType() == "Button" and child:GetText() == "Teach with Beast Training" then
			button = child
		end
	end
	assert(button, "the Beast Training button is there")
	assert(button:GetAttribute("type") == "spell" and button:GetAttribute("spell") == "Beast Training")

	-- Combat never touches the secure button: the state it would hide waits for the end of combat.
	local before = text
	sim:enterCombat()
	G.UnitExists = function()
		return false
	end
	sim:event("TRAINER_UPDATE")
	sim:tick(0)
	assert(button:IsShown(), "the secure button is untouched in combat")
	assert(text == before, "the note is untouched in combat")
	sim:leaveCombat()
	sim:event("PLAYER_REGEN_ENABLED")
	sim:tick(0)
	assert(not button:IsShown(), "the button hides once combat ends")
	sim:expectNoErrors(ADDON)
end)
