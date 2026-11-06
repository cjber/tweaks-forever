-- Unspent talent reminder (Features/TalentReminder.lua): a glow of our own over the talents button while talent or
-- pet training points are unspent, cleared as they are spent and never drawn in combat. The talent count is the one
-- Forever's own talent frame shows: the first tree currency of the active class talent config.
local features, handlers, db, printed, initializers, frames = {}, {}, {}, {}, {}, {}
local ns = {
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
	Feature = function(feature)
		features[feature.key] = feature
	end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
	On = function(event, fn)
		handlers[event] = handlers[event] or {}
		table.insert(handlers[event], fn)
	end,
	Active = function(key)
		return db[key]
	end,
	Print = function(message)
		printed[#printed + 1] = message
	end,
	OnSettingChanged = function(_, fn)
		handlers.setting = { fn }
	end,
	Art = {
		Fit = function(texture, atlas, width, height)
			texture.atlas, texture.width, texture.height = atlas, width, height
			return width, height
		end,
	},
}
-- Forever's class talent trees are trait trees with one talent currency (3820, 51 sourced points). The mainline class
-- and spec counts and the classic count are not what the talent frame reads, so they answer other numbers here: only
-- the tree currency may decide.
local combat, activeConfigID, treeID, quantity = false, 41, 12, 0
local classPoints, specPoints, classicPoints = 3, 1, 7
local petTotal, petUsed = 0, 0
local reads = {}
local env = setmetatable({
	InCombatLockdown = function()
		return combat
	end,
	C_ClassTalents = {
		GetActiveConfigID = function()
			return activeConfigID
		end,
		HasUnspentTalentPoints = function()
			return true, classPoints, specPoints
		end,
	},
	C_Traits = {
		GetConfigInfo = function(configID)
			if configID ~= activeConfigID then
				return nil
			end
			return {
				ID = configID,
				type = 1,
				name = "",
				treeIDs = treeID and { treeID } or {},
				usesSharedActionBars = false,
			}
		end,
		GetTreeCurrencyInfo = function(configID, readTreeID, excludeStagedChanges)
			reads[#reads + 1] = { configID = configID, treeID = readTreeID, exclude = excludeStagedChanges }
			if configID ~= activeConfigID or readTreeID ~= 12 then
				return {}
			end
			return {
				{
					traitCurrencyID = 3820,
					quantity = quantity,
					maxQuantity = 51,
					spent = 51 - quantity,
					spentInTree = 0,
				},
			}
		end,
	},
	GetNumUnspentTalents = function()
		return classicPoints
	end,
	C_PetInfo = {
		GetPetTrainingPoints = function()
			return petTotal, petUsed
		end,
	},
	MicroMenu = {
		GetFrameLevel = function()
			return 51
		end,
	},
	TalentMicroButton = {
		-- A button can report a level below its parent's: the menu's level is the floor.
		GetFrameLevel = function()
			return 1
		end,
		GetFrameStrata = function()
			return "MEDIUM"
		end,
	},
	CreateFrame = function()
		local frame = {}
		frame.SetFrameStrata = function(self, strata)
			self.strata = strata
		end
		frame.SetFrameLevel = function(self, level)
			self.level = level
		end
		frame.SetPoint = function(self, ...)
			self.point = { ... }
		end
		frame.CreateTexture = function(parent)
			local texture = {}
			texture.SetPoint = function() end
			texture.SetBlendMode = function(self, mode)
				self.blend = mode
			end
			texture.SetVertexColor = function(self, r, g, b)
				self.colour = { r, g, b }
			end
			parent.texture = texture
			return texture
		end
		frame.Show = function(self)
			self.shown = true
		end
		frame.Hide = function(self)
			self.shown = false
		end
		frame.SetShown = function(self, shown)
			self.shown = not not shown
		end
		frames[#frames + 1] = frame
		return frame
	end,
}, { __index = _G })
setfenv(assert(loadfile("Features/TalentReminder.lua")), env)("TweaksForever", ns)

local function Fire(event, ...)
	for _, fn in ipairs(handlers[event] or {}) do
		fn(...)
	end
end

local feature = features.talentReminder
assert(feature and feature.default == true and feature.category == "Interface", "on by default under Interface")
assert(feature.name == "Unspent talent reminder")

db.talentReminder = true
quantity = 2
initializers[1]()
local glow = frames[1]
assert(#printed == 0, "no chat line at login")
assert(glow and glow.shown, "our glow over the talents button")
assert(glow.strata == "MEDIUM", "in the micro menu's strata")
assert(glow.level == 56, "above the micro menu at 51")
assert(glow.texture.atlas == "collections-newglow" and glow.texture.width == 46, "drawn whole through Art")

-- The count is read the way the talent frame reads its UNSPENT_POINTS display: the active config's first tree, with
-- staged spends counted, never the class/spec or classic counts.
local read = reads[#reads]
assert(read and read.configID == 41 and read.treeID == 12, "the active class talent config and its first tree")
assert(read.exclude == false, "staged spends count, as in the talent frame")
local talent, pet = ns.TalentReminder.Unspent()
assert(talent == 2 and pet == 0, "two points and no pet points")

-- Spending them all clears the glow at once, on the currency event.
quantity = 0
Fire("TRAIT_TREE_CURRENCY_INFO_UPDATED", treeID)
assert(not glow.shown, "the glow clears when the points are spent")

-- The new point of a level-up brings it back.
quantity = 1
Fire("PLAYER_LEVEL_UP", 11)
assert(glow.shown, "the glow follows a level-up's point")

-- Only the pet waits now: the glow stays until its last point is spent, with no chat.
quantity = 0
petTotal, petUsed = 3, 1
Fire("UNIT_PET")
assert(glow.shown, "the glow follows pet points")
petUsed = 3
Fire("UNIT_PET_TRAINING_POINTS")
assert(not glow.shown, "the glow clears when the pet points are spent")

-- Both kinds waiting, then combat: no glow.
quantity = 1
petTotal, petUsed = 2, 0
Fire("TRAIT_NODE_CHANGED")
assert(glow.shown)
combat = true
Fire("PLAYER_REGEN_DISABLED")
assert(not glow.shown, "nothing drawn in combat")
combat = false
Fire("PLAYER_REGEN_ENABLED")
assert(glow.shown, "the glow returns once the fight is over")

-- A character with no active talent config has no points to count, and neither does a tree with no currency.
activeConfigID = nil
talent = select(1, ns.TalentReminder.Unspent())
assert(talent == 0, "no active config, no points")
activeConfigID, treeID = 41, 99
talent = select(1, ns.TalentReminder.Unspent())
assert(talent == 0, "no currency for that tree, no points")
treeID = 12

-- Switching it off clears the glow and silences the reminder.
db.talentReminder = false
Fire("setting")
Fire("PLAYER_LEVEL_UP")
assert(not glow.shown, "off means no glow")
print("talentreminder_spec: ok")
