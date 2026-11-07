-- Drives UI/BeastTraining.lua against a stub client: Beast Training rows, the pet's spellbook and the setting.
local function Load(options)
	local features, inits, handlers = {}, {}, {}
	local hooks = { update = {}, init = {} }
	local changed = {}
	local known = options.known or {}
	local db = { beastTrainingKnown = options.enabled ~= false }
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
		Active = function(key)
			return db[key]
		end,
		KnownSpell = function(id, pet)
			assert(pet == true)
			return known[id] == true
		end,
		OnSettingChanged = function(key, fn)
			assert(key == "beastTrainingKnown")
			changed[#changed + 1] = fn
		end,
	}

	local function Region(parent, kind)
		return {
			parent = parent,
			kind = kind,
			alpha = 1,
			alphaCalls = 0,
			shown = true,
			points = {},
			SetAlpha = function(self, alpha)
				self.alpha = alpha
				self.alphaCalls = self.alphaCalls + 1
			end,
			SetPoint = function(self, ...)
				self.points[#self.points + 1] = { ... }
			end,
			SetText = function(self, text)
				self.text = text
			end,
			SetTextColor = function(self, r, g, b)
				self.colour = { r, g, b }
			end,
			Show = function(self)
				self.shown = true
			end,
			Hide = function(self)
				self.shown = false
			end,
			IsShown = function(self)
				return self.shown
			end,
		}
	end

	local function Row()
		local row = { fonts = {} }
		row.icon = Region(row, "icon")
		row.name = Region(row, "name")
		row.subText = Region(row, "subText")
		row.alternateCost = Region(row, "alternateCost")
		function row:CreateFontString()
			local font = Region(self, "FontString")
			self.fonts[#self.fonts + 1] = font
			return font
		end
		return row
	end

	local services = options.services or {}
	local trainerType = options.trainerType or 3
	local env = setmetatable({
		ClassTrainerFrame = {},
		ITEM_SPELL_KNOWN = "Already known",
		GRAY_FONT_COLOR = {
			GetRGB = function()
				return 0.5, 0.5, 0.5
			end,
		},
		Enum = { TrainerType = { General = 0, Pet = 3 } },
		hooksecurefunc = function(global, fn)
			if global == "ClassTrainerFrame_Update" then
				hooks.update[#hooks.update + 1] = fn
			elseif global == "ClassTrainerFrame_InitServiceButton" then
				hooks.init[#hooks.init + 1] = fn
			else
				error("unexpected hook: " .. global)
			end
		end,
		C_Trainer = {
			GetTrainerType = function()
				return trainerType
			end,
		},
		GetNumTrainerServices = function()
			return #services
		end,
		GetTrainerServiceInfo = function(index)
			local service = services[index]
			return service.name, "available", nil, nil, service.subtext
		end,
		C_TooltipInfo = {
			GetTrainerService = function(index)
				return { id = services[index].id }
			end,
		},
		C_Spell = {
			GetSpellName = function()
				return nil
			end,
		},
		C_AddOns = {
			IsAddOnLoaded = function()
				return false
			end,
		},
	}, { __index = _G })

	setfenv(assert(loadfile("UI/BeastTraining.lua")), env)("TweaksForever", ns)

	return {
		features = features,
		inits = inits,
		db = db,
		ns = ns,
		hooks = hooks,
		services = services,
		Row = Row,
		Start = function()
			for _, fn in ipairs(inits) do
				fn()
			end
			for _, fn in ipairs(handlers.ADDON_LOADED or {}) do
				fn("Blizzard_TrainerUI")
			end
		end,
		Update = function()
			for _, fn in ipairs(hooks.update) do
				fn()
			end
		end,
		Paint = function(button, elementData)
			for _, fn in ipairs(hooks.init) do
				fn(button, elementData)
			end
		end,
		SetSetting = function(value)
			db.beastTrainingKnown = value
			for _, fn in ipairs(changed) do
				fn()
			end
		end,
		SetTrainerType = function(value)
			trainerType = value
		end,
		SetKnown = function(value)
			known = value
		end,
	}
end

local function Service(index, id, name, rank)
	return {
		index = index,
		id = id,
		name = name,
		rank = rank,
		subtext = rank and ("Rank " .. rank) or nil,
	}
end

local run = Load({})
assert(run.features.beastTrainingKnown.default == true, "the feature is on by default")
assert(run.features.beastTrainingKnown.category == "Interface", "it sits under Interface")
assert(run.features.beastTrainingKnown.name == "Known ranks in Beast Training", "its name says what it does")
local Model = run.ns.BeastTraining

-- The model: an exact known spell, the lower rank of a known higher rank, an unknown higher rank, and rows with no
-- rank at all.
local modelled = Model.KnownIndices({
	{ index = 1, id = 1, name = "Growl", rank = 1 },
	{ index = 2, id = 2, name = "Growl", rank = 2 },
	{ index = 3, id = 3, name = "Growl", rank = 3 },
	{ index = 4, id = 4, name = "Natural Armor" },
	{ index = 5, id = 5, name = "Bite" },
}, function(id)
	return id == 2 or id == 5
end)
assert(modelled[1], "a rank below a known higher rank counts as known")
assert(modelled[2], "the exact known spell counts as known")
assert(not modelled[3], "a higher unknown rank stays to learn")
assert(not modelled[4], "a row with no rank is not guessed known")
assert(modelled[5], "a row with no rank is known from its exact spell")

-- Beast Training with the reported rows: Great Stamina Rank 1 above the known Rank 2, and the pet's own Growl.
run = Load({
	services = {
		Service(1, 4187, "Great Stamina", 1),
		Service(2, 4188, "Great Stamina", 2),
		Service(3, 2649, "Growl", 1),
		Service(4, 24545, "Natural Armor", 1),
		Service(5, 14916, "Growl", 2),
	},
	known = { [4188] = true, [2649] = true },
})
run.Start()
assert(#run.hooks.update == 1 and #run.hooks.init == 1, "both of Blizzard's trainer globals are hooked once it loads")
run.Update()

local pet = { trainerType = 3 }
local lower = run.Row()
run.Paint(lower, { skillIndex = 1, trainerType = pet.trainerType })
assert(lower.icon.alpha == 0.5 and lower.name.alpha == 0.5, "a known row dims the icon and name")
assert(lower.subText.alpha == 0 and lower.alternateCost.alpha == 0, "its requirement and cost lines go")
assert(#lower.fonts == 1 and lower.fonts[1].shown, "our own label appears")
assert(lower.fonts[1].text == "Already known", "it uses the game's own known text")
assert(lower.fonts[1].parent == lower and lower.fonts[1].kind == "FontString", "the label is the button's own")
assert(lower.fonts[1].colour[1] == 0.5 and lower.fonts[1].colour[3] == 0.5, "and it is grey")

run.Paint(lower, { skillIndex = 1, trainerType = pet.trainerType })
assert(#lower.fonts == 1, "the label is made once per row button")

local exact = run.Row()
run.Paint(exact, { skillIndex = 3, trainerType = pet.trainerType })
assert(exact.icon.alpha == 0.5 and exact.fonts[1] and exact.fonts[1].shown, "a known exact spell is marked too")

local unknown = run.Row()
run.Paint(unknown, { skillIndex = 4, trainerType = pet.trainerType })
assert(unknown.icon.alpha == 1 and unknown.name.alpha == 1, "an unknown row keeps its stock look")
assert(unknown.subText.alpha == 1 and unknown.alternateCost.alpha == 1, "and its requirement line")
assert(#unknown.fonts == 0, "no label is made for it")

local higher = run.Row()
run.Paint(higher, { skillIndex = 5, trainerType = pet.trainerType })
assert(higher.icon.alpha == 1 and #higher.fonts == 0, "a higher unknown rank is not marked by a lower known one")

-- Recycled rows, as the scroll box reuses its buttons: the stock look comes back and our label goes.
run.Paint(lower, { skillIndex = 4, trainerType = pet.trainerType })
assert(lower.icon.alpha == 1 and lower.name.alpha == 1, "a recycled row gets its icon and name back")
assert(lower.subText.alpha == 1 and lower.alternateCost.alpha == 1, "and its requirement and cost lines")
assert(#lower.fonts == 1 and not lower.fonts[1].shown, "the label is hidden, not thrown away")
run.Paint(lower, { skillIndex = 1, trainerType = pet.trainerType })
assert(lower.icon.alpha == 0.5 and lower.fonts[1].shown, "the same row can be marked again")

-- An update repaints the rows already drawn when what the pet knows changes.
run.SetKnown({})
run.Update()
assert(lower.icon.alpha == 1 and not lower.fonts[1].shown, "an update repaints a row that is no longer known")
run.SetKnown({ [4188] = true, [2649] = true })
run.Update()
assert(lower.icon.alpha == 0.5 and lower.fonts[1].shown, "and paints it again once it is known")

-- The same buttons serve the class and profession trainers.
run.SetTrainerType(0)
run.Update()
assert(lower.icon.alpha == 1 and not lower.fonts[1].shown, "a class trainer's list restores the pet rows it reuses")
local class = run.Row()
run.Paint(class, { skillIndex = 2, trainerType = 0 })
assert(class.icon.alpha == 1 and class.name.alpha == 1 and class.subText.alpha == 1, "a class trainer row is untouched")
assert(class.icon.alphaCalls == 0 and class.subText.alphaCalls == 0, "and not even its alphas are written")
assert(#class.fonts == 0, "and gets no label")
local recycled = run.Row()
run.SetTrainerType(3)
run.Update()
run.Paint(recycled, { skillIndex = 2, trainerType = pet.trainerType })
assert(recycled.fonts[1].shown, "a pet row on the same kind of button is marked")
run.Paint(recycled, { skillIndex = 2, trainerType = 0 })
assert(recycled.icon.alpha == 1 and not recycled.fonts[1].shown, "and restored for a class trainer")

-- The option turns it off.
run.Paint(lower, { skillIndex = 1, trainerType = pet.trainerType })
assert(lower.fonts[1].shown, "the row is marked before the setting changes")
run.SetSetting(false)
assert(lower.icon.alpha == 1 and not lower.fonts[1].shown, "turning it off restores the rows already drawn")
local off = run.Row()
run.Update()
run.Paint(off, { skillIndex = 1, trainerType = pet.trainerType })
assert(off.icon.alpha == 1 and off.subText.alpha == 1 and #off.fonts == 0, "the setting leaves the rows alone")
run.SetSetting(true)
run.Update()
run.Paint(off, { skillIndex = 1, trainerType = pet.trainerType })
assert(off.icon.alpha == 0.5 and off.fonts[1] and off.fonts[1].shown, "and back on")

print("beasttraining: ok")
