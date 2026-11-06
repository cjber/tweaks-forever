-- Unspent talent reminder (Features/TalentReminder.lua): a glow of our own over the talents button while talent or
-- pet training points are unspent, cleared as they are spent and never drawn in combat.
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
local combat, hasTalent, classPoints, specPoints, fallback = false, false, 0, 0, 0
local petTotal, petUsed = 0, 0
local env = setmetatable({
	InCombatLockdown = function()
		return combat
	end,
	C_ClassTalents = {
		HasUnspentTalentPoints = function()
			return hasTalent, classPoints, specPoints
		end,
	},
	GetNumUnspentTalents = function()
		return fallback
	end,
	C_PetInfo = {
		GetPetTrainingPoints = function()
			return petTotal, petUsed
		end,
	},
	TalentMicroButton = {
		GetFrameLevel = function()
			return 50
		end,
	},
	CreateFrame = function()
		local frame = {}
		frame.SetFrameStrata = function() end
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
hasTalent, classPoints, specPoints = true, 2, 0
initializers[1]()
local glow = frames[1]
assert(#printed == 0, "no chat line at login")
assert(glow and glow.shown and glow.level == 55, "our glow over the talents button")
assert(glow.texture.atlas == "collections-newglow" and glow.texture.width == 46, "drawn whole through Art")

-- Only the pet waits now: the glow stays and a level-up says so.
hasTalent = false
petTotal, petUsed = 3, 1
Fire("PLAYER_LEVEL_UP")
assert(glow.shown, "the glow follows pet points at a level-up")
assert(#printed == 0, "no chat line at a level-up")

-- Spending every pet point clears the glow at once, with no more chat.
petUsed = 3
Fire("UNIT_PET_TRAINING_POINTS")
assert(not glow.shown, "the glow clears when the points are spent")

-- Both kinds waiting, then combat: no line, no glow.
hasTalent, classPoints = true, 1
petTotal, petUsed = 2, 0
Fire("TRAIT_NODE_CHANGED")
assert(glow.shown)
combat = true
Fire("PLAYER_REGEN_DISABLED")
assert(not glow.shown, "nothing drawn in combat")
combat = false
Fire("PLAYER_REGEN_ENABLED")
assert(glow.shown, "the glow returns once the fight is over")

-- The classic count covers a tree the newer API does not report.
env.C_ClassTalents = nil
fallback = 4
local talent, pet = ns.TalentReminder.Unspent()
assert(talent == 4 and pet == 2, "the fallback count")
env.C_ClassTalents = {
	HasUnspentTalentPoints = function()
		return hasTalent, classPoints, specPoints
	end,
}

-- Switching it off clears the glow and silences the reminder.
db.talentReminder = false
Fire("setting")
Fire("PLAYER_LEVEL_UP")
assert(not glow.shown, "off means no glow")
print("talentreminder_spec: ok")
