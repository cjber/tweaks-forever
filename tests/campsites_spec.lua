local initializers, active = {}, { campAlerts = true }
local ns = {
	Feature = function() end,
	Init = function(fn)
		initializers[#initializers + 1] = fn
	end,
	Active = function(key)
		return active[key]
	end,
}
local auras, messages, onAura, secret = {}, {}, nil, false
local env = setmetatable({
	C_UnitAuras = {
		GetPlayerAuraBySpellID = function(spell)
			return auras[spell]
		end,
	},
	C_Spell = { GetSpellName = function() end },
	C_Secrets = {
		ShouldAurasBeSecret = function()
			return false
		end,
	},
	InCombatLockdown = function()
		return secret
	end,
	Enum = { TooltipDataType = {} },
	TooltipDataProcessor = { AddTooltipPostCall = function() end },
	-- The camp benefit announcer's frame is the last one made.
	CreateFrame = function()
		local frame = { RegisterUnitEvent = function() end }
		function frame.SetScript(_, _, fn)
			onAura = fn
		end
		return frame
	end,
	UIErrorsFrame = {
		AddMessage = function(_, text)
			messages[#messages + 1] = text
		end,
	},
	YELLOW_FONT_COLOR = {
		GetRGB = function()
			return 1, 1, 0
		end,
	},
}, { __index = _G })
setfenv(assert(loadfile("Data/CampBenefits.lua")), env)("TweaksForever", ns)
setfenv(assert(loadfile("Campsites.lua")), env)("TweaksForever", ns)
local Camp = ns.Camp

-- The list: benefits you have first, then the rest, each in the game's order.
local TENT, MANA_WELL, FIRST_AID, BANNER = 1229451, 1230587, 1230124, 1229718
local FISH_BOWL, LUTE, CHAIR = 1230098, 1230653, 1229519
local have = { [FIRST_AID] = 1200, [TENT] = 0 }
local rows = Camp.Listing(function(aura)
	return have[aura]
end)
assert(#rows == #ns.CampBenefits)
assert(rows[1].benefit[1] == TENT and rows[1].left == 0, "the tent comes first in the game's order")
assert(rows[2].benefit[1] == FIRST_AID and rows[2].left == 1200)
assert(rows[3].benefit[1] == MANA_WELL and rows[3].left == nil, "then what you don't have")
assert(rows[#rows].benefit[1] == BANNER)

-- Directions: bearings run counter-clockwise from north, as the player's facing does.
local pi = math.pi
assert(Camp.Toward(40, 0, 0) == "Campfire: about 40 yd ahead")
assert(Camp.Toward(0, 30, 0) == "Campfire: about 30 yd to your left", "west is left facing north")
assert(Camp.Toward(0, 30, pi / 2) == "Campfire: about 30 yd ahead", "facing west")
assert(Camp.Toward(-20, -20, 0) == "Campfire: about 30 yd behind you to the right")
assert(Camp.Toward(3, 3, 1) == "Campfire: right here")

-- Effects carry the aura's own values, which can differ from the spell's base ones.
local byAura = {}
for _, benefit in ipairs(ns.CampBenefits) do
	byAura[benefit[1]] = benefit
end
assert(Camp.Effect(byAura[FIRST_AID], { 8 }) == "Stamina increased by 8")
assert(Camp.Effect(byAura[MANA_WELL], { 12 }) == "Restores 12 Mana every 5 seconds", "the period stays")
assert(
	Camp.Effect(byAura[LUTE], { 44, 2, 3, 3, 3, 3, 3, 3 })
		== "Armor increased by 44, all attributes increased by 2, and all resistances increased by 3"
)
assert(Camp.Effect(byAura[CHAIR], { 1.5 }) == "Critical strike chance with all spells and attacks increased by 1.5%")
-- Without the aura's values the amount is unknown: the base one would contradict the buff, so none shows.
assert(Camp.Effect(byAura[FIRST_AID], nil) == "Stamina increased", "no values: no amount")
assert(Camp.Effect(byAura[FIRST_AID], {}) == "Stamina increased")
assert(Camp.Effect(byAura[LUTE], { 44 }) == "Armor increased, all attributes increased, and all resistances increased")
assert(Camp.Effect(byAura[MANA_WELL], nil) == "Restores Mana every 5 seconds")
assert(Camp.Effect(byAura[FISH_BOWL], nil) == "All stats increased")
assert(Camp.Effect(byAura[CHAIR], nil) == "Critical strike chance with all spells and attacks increased")
assert(Camp.Effect(byAura[TENT], nil) == byAura[TENT][3], "the tent's timings are not amounts")
for _, benefit in ipairs(ns.CampBenefits) do
	assert(not Camp.Effect(benefit, nil):find("%d%%?$"), benefit[2] .. ": no amount left over")
end

-- The rows carry the values of the auras you have, and only those.
rows = Camp.Listing(function(aura)
	if aura == FIRST_AID then
		return 1200, { 8 }
	end
end)
assert(rows[1].benefit[1] == FIRST_AID and Camp.Effect(rows[1].benefit, rows[1].points) == "Stamina increased by 8")
assert(rows[2].points == nil)
assert(Camp.Announcement(byAura[FISH_BOWL], { 8 }) == "Camp benefit gained: Fish Bowl (all stats increased by 8%)")
assert(Camp.Announcement(byAura[TENT], {}) == "Camp benefit gained: Tent (rested experience)")

-- Announcements: only benefits gained since the last look, never the ones you logged in with.
auras[FIRST_AID] = { points = { 8 } }
for _, fn in ipairs(initializers) do
	fn()
end
onAura(nil, "UNIT_AURA", "player", {})
assert(#messages == 0, "a benefit you had at login is not news")
auras[FISH_BOWL] = { points = { 8 } }
onAura(nil, "UNIT_AURA", "player", {})
assert(#messages == 1 and messages[1] == "Camp benefit gained: Fish Bowl (all stats increased by 8%)")
onAura(nil, "UNIT_AURA", "player", {})
assert(#messages == 1, "a refresh is not a new benefit")
auras[MANA_WELL] = { points = { 29 } }
onAura(nil, "UNIT_AURA", "player", { isFullUpdate = true })
assert(#messages == 1, "a full update only takes stock")
secret, auras[BANNER] = true, { points = { 32 } }
onAura(nil, "UNIT_AURA", "player", {})
assert(#messages == 1, "nothing is read in combat")
secret = false
onAura(nil, "UNIT_AURA", "player", {})
assert(messages[2] == "Camp benefit gained: Faction Banner (spirit increased by 32)", "announced once combat ends")
auras[FISH_BOWL] = nil
onAura(nil, "UNIT_AURA", "player", {})
auras[FISH_BOWL], active.campAlerts = { points = { 8 } }, false
onAura(nil, "UNIT_AURA", "player", {})
assert(#messages == 2, "switched off")
active.campAlerts = true
auras[FISH_BOWL] = nil
onAura(nil, "UNIT_AURA", "player", {})
auras[FISH_BOWL] = { points = { 8 } }
onAura(nil, "UNIT_AURA", "player", {})
assert(#messages == 3, "gained again after it ran out")
print("campsites: ok")
