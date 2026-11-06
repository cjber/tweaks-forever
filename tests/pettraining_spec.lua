-- Drives UI/PetTrainer.lua against a stub client: a pet trainer, Beast Training, the trainer filter and combat.
local function Load(options)
	local features, inits, handlers = {}, {}, {}
	local hooks = {}
	local combat = options.combat or false
	local mutations = {}
	local made = { buttons = {}, fonts = {} }
	local db = { petTrainerHint = options.enabled ~= false }
	local ns = {
		Feature = function(feature)
			features[feature.key] = feature
		end,
		Init = function(fn)
			inits[#inits + 1] = fn
		end,
		On = function(event, fn)
			handlers[event] = handlers[event] or {}
			handlers[event][#handlers[event] + 1] = fn
		end,
		OnSettingChanged = function(key)
			assert(key == "petTrainerHint")
		end,
		Active = function(key)
			return db[key]
		end,
		Readable = function(value)
			return value
		end,
		FitButton = function(button, width)
			button.fitted = width
		end,
		L = setmetatable({}, {
			__index = function(_, key)
				return key
			end,
		}),
		db = db,
	}

	local function mutated(name)
		if combat then
			mutations[#mutations + 1] = name
		end
	end

	local function Frame(parent, template)
		local frame = {
			parent = parent,
			template = template,
			shown = true,
			points = {},
			attributes = {},
			scripts = {},
		}
		function frame:CreateFontString()
			local text = Frame(self, "FontString")
			text.isFont = true
			made.fonts[#made.fonts + 1] = text
			return text
		end
		function frame:SetPoint(point, relative, relativePoint, x, y)
			mutated("SetPoint")
			self.points[point] = { relative = relative, relativePoint = relativePoint, x = x, y = y }
		end
		function frame:SetHeight(height)
			mutated("SetHeight")
			self.height = height
		end
		function frame:SetText(text)
			mutated("SetText")
			self.text = text
		end
		function frame.GetTextWidth()
			return 120
		end
		function frame.SetJustifyH()
			mutated("SetJustifyH")
		end
		function frame.SetWordWrap()
			mutated("SetWordWrap")
		end
		function frame:SetMaxLines(lines)
			mutated("SetMaxLines")
			self.maxLines = lines
		end
		function frame:Show()
			mutated("Show")
			self.shown = true
		end
		function frame:Hide()
			mutated("Hide")
			self.shown = false
		end
		function frame:SetShown(shown)
			mutated("SetShown")
			self.shown = shown
		end
		function frame:IsShown()
			return self.shown
		end
		function frame.RegisterForClicks()
			mutated("RegisterForClicks")
		end
		function frame:SetAttribute(key, value)
			mutated("SetAttribute")
			self.attributes[key] = value
		end
		function frame:GetAttribute(key)
			return self.attributes[key]
		end
		function frame:SetScript(name, fn)
			self.scripts[name] = fn
		end
		function frame:HookScript(name, fn)
			self.scripts[name] = fn
		end
		if template and template:find("SecureActionButtonTemplate", 1, true) then
			frame.secure = true
			made.buttons[#made.buttons + 1] = frame
		end
		return frame
	end

	local trainer = Frame(UIParent, "ClassTrainerFrame")
	trainer:Show()
	trainer.Inset = Frame(trainer, "Inset")
	trainer.ScrollBox = Frame(trainer, "ScrollBox")
	trainer.bottomInset = Frame(trainer, "Inset")
	trainer.bottomInset:Hide()

	local filters = { available = true, unavailable = true, used = false }
	local services = options.services or {
		{ id = 2649, kind = "used" },
		{ id = 1082, kind = "used" },
	}
	local pet = options.pet
		or {
			{ itemType = 2, spellID = 2649, name = "Growl" },
			{ itemType = 2, spellID = 1082, name = "Claw" },
			{ itemType = 2, spellID = 2649, name = "Growl" },
			{ itemType = 3, spellID = 17253, name = "Bite" },
		}
	local function visible()
		local rows = {}
		for _, service in ipairs(services) do
			if filters[service.kind] then
				rows[#rows + 1] = service
			end
		end
		return rows
	end

	local names = { [5149] = "Beast Training", [2649] = "Growl", [1082] = "Claw" }
	local env = setmetatable({
		UIParent = {},
		ClassTrainerFrame = trainer,
		CreateFrame = function(_, _, parent, template)
			return Frame(parent, template)
		end,
		hooksecurefunc = function(global, fn)
			assert(global == "ClassTrainerFrame_Update")
			hooks[#hooks + 1] = fn
		end,
		InCombatLockdown = function()
			return combat
		end,
		UnitClass = function()
			return options.class or "Hunter", options.classToken or "HUNTER"
		end,
		UnitExists = function(unit)
			assert(unit == "pet")
			return options.petExists ~= false
		end,
		UnitName = function(unit)
			assert(unit == "pet")
			return options.petName or "Claws"
		end,
		C_Trainer = {
			GetTrainerType = function()
				return options.trainerType or 0
			end,
		},
		IsTradeskillTrainer = function()
			return options.tradeskill == true
		end,
		GetNumTrainerServices = function()
			return #visible()
		end,
		GetTrainerServiceTypeFilter = function(kind)
			return filters[kind]
		end,
		SetTrainerServiceTypeFilter = function(kind, shown)
			filters[kind] = shown
		end,
		GetTrainerServiceStepIndex = function()
			return nil
		end,
		C_TooltipInfo = {
			GetTrainerService = function(index)
				return visible()[index]
			end,
		},
		C_SpellBook = {
			HasPetSpells = function()
				return #pet
			end,
			GetSpellBookItemInfo = function(slot)
				return pet[slot]
			end,
		},
		C_Spell = {
			GetSpellName = function(id)
				return names[id]
			end,
			GetSpellInfo = function(id)
				return names[id] and { name = names[id] }
			end,
		},
		C_AddOns = {
			IsAddOnLoaded = function()
				return false
			end,
		},
		Enum = {
			TrainerType = { General = 0, Pet = 3 },
			SpellBookSpellBank = { Pet = 1 },
			SpellBookItemType = { FutureSpell = 2, PetAction = 3 },
		},
	}, { __index = _G })

	setfenv(assert(loadfile("UI/PetTrainer.lua")), env)("TweaksForever", ns)

	local function Fire(event, ...)
		for _, fn in ipairs(handlers[event] or {}) do
			fn(...)
		end
	end

	local function Update()
		for _, fn in ipairs(hooks) do
			fn()
		end
	end

	return {
		features = features,
		inits = inits,
		db = db,
		env = env,
		trainer = trainer,
		buttons = made.buttons,
		fonts = made.fonts,
		filters = filters,
		services = services,
		pet = pet,
		mutations = mutations,
		Fire = Fire,
		Update = Update,
		Start = function()
			for _, fn in ipairs(inits) do
				fn()
			end
			Fire("ADDON_LOADED", "Blizzard_TrainerUI")
		end,
		note = function()
			return made.fonts[1]
		end,
		teach = function()
			return made.buttons[1]
		end,
		setCombat = function(value)
			combat = value
		end,
		setPet = function(value)
			pet = value
		end,
		setServices = function(value)
			services = value
		end,
		clearMutations = function()
			for index = #mutations, 1, -1 do
				mutations[index] = nil
			end
		end,
	}
end

-- A pet trainer with the stock "Used" filter hidden: the list is empty, but the pet's own future spells name what
-- it still has to learn, once each, and the note explains why the trainer's list looks empty.
local run = Load({})
assert(run.features.petTrainerHint.default == true and run.features.petTrainerHint.category == "Interface")
run.Start()
assert(run.note() and run.note().shown, "the note appears on a pet trainer")
assert(
	run.note().text == "Claws hasn't learned Growl, Claw.\nThe ranks you already know are hidden by the filter.",
	"the note names each unlearned ability once and says the filter hides the known ranks: "
		.. tostring(run.note().text)
)
assert(run.teach() and run.teach().shown, "the Beast Training button appears with the note")
assert(run.teach().secure, "the button is a secure action button")
assert(
	run.teach().attributes.type == "spell" and run.teach().attributes.spell == "Beast Training",
	"it casts Beast Training"
)
assert(run.teach().text == "Teach with Beast Training" and run.teach().fitted == 160, "its stock label fits")
assert(run.trainer.bottomInset.shown, "the note takes the trainer's own bottom inset")
assert(run.trainer.ScrollBox.height == 330 - 72, "the list makes room for it")
assert(run.trainer.Inset.points.BOTTOMRIGHT.y == 26 + 72, "the inset ends above the note")

-- The list is not empty once the player shows the known ranks, so the filter line goes.
run.filters.used = true
run.Update()
assert(
	run.note().text == "Claws hasn't learned Growl, Claw.",
	"the filter line only shows while the used ranks are hidden and the list is empty"
)

-- A class trainer's services are not on the pet's spellbook, even though the hunter has a pet with future spells.
run.setServices({ { id = 133, kind = "used" } })
run.Fire("TRAINER_SHOW")
run.Update()
assert(not run.note().shown and not run.teach().shown, "nothing shows on a class trainer")
run.setServices({
	{ id = 2649, kind = "used" },
	{ id = 1082, kind = "used" },
})
run.Fire("TRAINER_SHOW")
run.Update()
assert(run.note().shown, "the pet trainer is recognised again")

-- Beast Training itself is the pet's list, not an NPC trainer: no note.
run.env.C_Trainer.GetTrainerType = function()
	return 3
end
run.Update()
assert(not run.note().shown and not run.teach().shown, "nothing shows in Beast Training")
assert(not run.trainer.bottomInset.shown and run.trainer.ScrollBox.height == 330, "the stock list gets its room back")

-- No pet, no note.
run.env.C_Trainer.GetTrainerType = function()
	return 0
end
run.env.UnitExists = function()
	return false
end
run.Update()
assert(not run.note().shown and not run.teach().shown, "nothing shows without a pet out")

-- A pet that already knows every future ability leaves nothing to say.
run.env.UnitExists = function()
	return true
end
run.setPet({ { itemType = 3, spellID = 2649, name = "Growl" } })
run.Update()
assert(not run.note().shown and not run.teach().shown, "nothing shows when the pet knows everything")

-- The option turns it off.
run.setPet({ { itemType = 2, spellID = 2649, name = "Growl" } })
run.db.petTrainerHint = false
run.Update()
assert(not run.note().shown and not run.teach().shown, "the setting turns the note off")
run.db.petTrainerHint = true
run.Update()
assert(run.note().shown, "and back on")
assert(run.note().text == "Claws hasn't learned Growl.", "the note follows the abilities still missing")

-- Non-hunters are left alone even with a pet.
run.env.UnitClass = function()
	return "Mage", "MAGE"
end
run.Update()
assert(not run.note().shown and not run.teach().shown, "nothing shows for another class")

-- Combat: the secure button and its frame are never created, shown, hidden, moved or changed. A change waits for
-- the end of combat, then lands.
run.env.UnitClass = function()
	return "Hunter", "HUNTER"
end
run.Update()
assert(run.note().shown)
local text = run.note().text
run.clearMutations()
run.setCombat(true)
run.env.UnitExists = function()
	return false
end
run.Update()
assert(#run.mutations == 0, "combat changes nothing: " .. table.concat(run.mutations, ", "))
assert(run.note().shown and run.teach().shown and run.note().text == text, "the note waits in combat")
run.setCombat(false)
run.Fire("PLAYER_REGEN_ENABLED")
assert(not run.note().shown and not run.teach().shown, "it updates when combat ends")

-- A trainer opened in combat makes no secure frame at all until combat ends.
local late = Load({ combat = true })
late.env.UnitExists = function()
	return true
end
late.clearMutations()
late.Start()
assert(late.note() == nil and late.teach() == nil, "no secure frame is made in combat")
assert(#late.mutations == 0, "and nothing is shown or moved")
late.setCombat(false)
late.Fire("PLAYER_REGEN_ENABLED")
assert(late.note() and late.note().shown and late.teach() and late.teach().shown, "the note arrives after combat")

print("pettraining: ok")
