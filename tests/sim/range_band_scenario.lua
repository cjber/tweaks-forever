-- luacheck: read globals scenario ADDON
-- A hunter's range band beside Blizzard's own target frame, run through the client's own frame API, events and ticker.
-- Our frame is a child of the real TargetFrame, so Edit Mode's position, scale and visibility carry it, and no field
-- of Blizzard's is written.
scenario("the hunter range band follows the target and its own ticker", function(sim)
	dofile("tests/sim/forever_core.lua").install(sim)
	local G = sim.G
	G.UnitClass = function()
		return "Hunter", "HUNTER"
	end
	G.UnitExists = function(unit)
		return unit == "target"
	end
	G.UnitCanAttack = function()
		return true
	end
	G.UnitIsDead = function()
		return false
	end
	G.UnitIsDeadOrGhost = function()
		return false
	end
	-- The stock unit-frame addon is one of the heavy Blizzard addons the sim leaves out as a dependency, so the
	-- scenario loads the target frame's own files and the status-bar template it inherits.
	sim:loadBlizzard("Blizzard_FrameXML/SecureTemplates.xml")
	sim:loadBlizzard("Blizzard_TextStatusBar")
	sim:loadBlizzard("Blizzard_UnitFrame:TargetFrame")

	G.Enum.SpellBookSpellBank = G.Enum.SpellBookSpellBank or { Player = 0 }
	G.C_SpellBook = {
		GetNumSpellBookSkillLines = function()
			return 1
		end,
		GetSpellBookSkillLineInfo = function()
			return { itemIndexOffset = 0, numSpellBookItems = 2 }
		end,
		GetSpellBookItemInfo = function(slot)
			return ({ { actionID = 14260, spellID = 14260 }, { actionID = 75, spellID = 75 } })[slot]
		end,
		FindBaseSpellByID = function(id)
			return ({ [14260] = 2973, [75] = 75 })[id] or id
		end,
		IsSpellKnown = function()
			return false
		end,
	}
	sim.impl["C_Spell.GetSpellTexture"] = function(id)
		return 1000 + id
	end
	local melee = true
	sim.impl["C_Spell.IsSpellInRange"] = function(id)
		return id == 14260 and melee or id == 75 and not melee
	end
	local tickers, newTicker = 0, sim.impl["C_Timer.NewTicker"]
	sim.impl["C_Timer.NewTicker"] = function(period, fn, iterations)
		if period == 0.2 then
			tickers = tickers + 1
		end
		return newTicker(period, fn, iterations)
	end

	sim:login()
	local frame = G.TweaksForeverRangeBand
	assert(frame, "the range band frame is built")
	assert(frame:GetParent() == G.TargetFrame, "it is a child of the target frame")
	assert(frame:GetWidth() == 28 and frame:GetHeight() == 28, "a whole 28 square icon")
	assert(frame:IsShown(), "the client says the melee spell reaches")
	assert(tickers == 1, "one throttled ticker while a target exists")

	-- The same ticker reads the dead zone a moment later, without a second timer.
	melee = false
	sim:tick(0.25)
	assert(frame:IsShown(), "the dead zone still shows the ranged icon")
	assert(tickers == 1, "the ticker is reused")

	-- A target change reacts at once. No target hides the icon and stops the ticker.
	G.UnitExists = function()
		return false
	end
	sim:event("PLAYER_TARGET_CHANGED")
	sim:tick(0.25)
	assert(not frame:IsShown(), "no target, no icon")
	G.UnitExists = function(unit)
		return unit == "target"
	end
	sim:enterCombat()
	sim:event("PLAYER_TARGET_CHANGED")
	sim:tick(0.25)
	assert(frame:IsShown(), "combat does not hide it")
	assert(tickers == 2, "a new target starts one new ticker")
	sim:leaveCombat()
	sim:expectNoErrors(ADDON)
end)
