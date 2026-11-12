---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

local KEY = "rangeBand"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "Range band beside the target",
	tooltip = "A small spell icon beside the target frame shows how your target sits in your range: Raptor Strike "
		.. "when it is within melee reach, Auto Shot when it is in shooting range, and Auto Shot greyed and red in "
		.. "the dead zone between. Nothing shows without a hostile target, while you are dead, or for a class with "
		.. "no dead zone.",
	default = true,
	conflicts = {
		{ addon = "RangeLens" },
		{ addon = "RangeDisplay" },
	},
})

-- The class abilities whose reach marks the band, by base spell ID rather than a rank: the spellbook names the rank
-- the character knows and the client's own check answers for it. Raptor Strike, Wing Clip and Mongoose Bite are
-- Combat Range 0-5, and Auto Shot is Hunter Range 8-35 at every rank. IDs and ranges verified against the pinned
-- Forever client 1.60.1.70888 on wago.tools (SpellName, SpellMisc.RangeIndex, SpellRange).
local BANDS = {
	HUNTER = {
		melee = { 2973, 2974, 1495 }, -- Raptor Strike, Wing Clip, Mongoose Bite
		ranged = { 75 }, -- Auto Shot
	},
}

-- Range raises no event, so the target is asked five times a second while one exists. With no target there is no
-- ticker and no work at all.
local PERIOD = 0.2
-- The icon is a whole square leg of its own next to the portrait, not part of the frame's health bar.
local SIZE, GAP = 28, 6
-- Desaturated first, so the red reads as red rather than the icon's colours pushed towards red.
local RED = { 1, 0.08, 0.08 }

---@class TFRangeBand
local Model = {}
ns.RangeBand = Model

-- The band the two answers name: melee first, then ranged, and the dead zone only when both say the target is out
-- of reach. A nil answer is no answer, so the icon stays off rather than guessing.
---@param melee boolean?
---@param ranged boolean?
---@return "melee"|"ranged"|"dead"|nil
function Model.Band(melee, ranged)
	if melee == true then
		return "melee"
	elseif ranged == true then
		return "ranged"
	elseif melee == false and ranged == false then
		return "dead"
	end
end

-- The rank the character knows of a base spell: the spellbook's own entry for it, or the base ID when the client
-- says it is known. nil when it is not known.
---@param base integer
---@param ranks table<integer, integer>
---@param known fun(id: integer): boolean
---@return integer?
function Model.Rank(base, ranks, known)
	return ranks[base] or (known(base) and base or nil)
end

-- The first of the class's base spells the character knows.
---@param bases integer[]
---@param ranks table<integer, integer>
---@param known fun(id: integer): boolean
---@return integer?
function Model.First(bases, ranks, known)
	for _, base in ipairs(bases) do
		local id = Model.Rank(base, ranks, known)
		if id then
			return id
		end
	end
end

-- [base spell ID] = the rank's spell ID in the spellbook.
---@type table<integer, integer>
local ranks = {}
---@type string?
local class
---@type Frame?
local frame
---@type Texture?
local icon
---@type FunctionContainer?
local ticker

-- The spellbook's own ranks, so a level 60 hunter uses the Raptor Strike they know rather than rank 1. A base ID the
-- client says is known but the book does not list is answered with the base ID itself.
local function ScanSpells()
	wipe(ranks)
	for index = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local line = C_SpellBook.GetSpellBookSkillLineInfo(index)
		for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
			local item = C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
			if item then
				for _, id in ipairs({ item.actionID, item.spellID }) do
					if id then
						local base = C_SpellBook.FindBaseSpellByID(id) or id
						ranks[base] = ranks[base] or id
					end
				end
			end
		end
	end
end

---@param id integer
---@return boolean
local function Known(id)
	return C_SpellBook.IsSpellKnown(id)
end

-- Our own frame, a child of the target frame so Edit Mode's position, scale and visibility come with it. It is only
-- ever read from Blizzard's frame, never written to it.
local function Build()
	if frame or not TargetFrame then
		return
	end
	frame = CreateFrame("Frame", "TweaksForeverRangeBand", TargetFrame)
	frame:SetFrameLevel(TargetFrame:GetFrameLevel() + 5)
	frame:SetSize(SIZE, SIZE)
	local portrait = TargetFrame.TargetFrameContainer and TargetFrame.TargetFrameContainer.Portrait
	frame:SetPoint("LEFT", portrait or TargetFrame, "RIGHT", GAP, 0)
	icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("CENTER")
	frame:Hide()
end

-- The client's own answer for one spell, or nil when the client keeps it secret and this code cannot read it.
---@param id integer
---@return boolean?
local function InRange(id)
	return ns.Readable(C_Spell.IsSpellInRange(id, "target"))
end

---@param id integer
---@param band "melee"|"ranged"|"dead"
local function Draw(id, band)
	local texture = C_Spell.GetSpellTexture(id)
	if not (frame and icon and texture) then
		if frame then
			frame:Hide()
		end
		return
	end
	ns.Art.Icon(icon, texture, SIZE)
	icon:SetDesaturated(band == "dead")
	if band == "dead" then
		icon:SetVertexColor(RED[1], RED[2], RED[3])
	else
		icon:SetVertexColor(1, 1, 1)
	end
	frame:Show()
end

local function Stop()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
	if frame then
		frame:Hide()
	end
end

local function Update()
	if not frame then
		return
	end
	local bands = class and BANDS[class]
	if not (ns.Active(KEY) and bands) then
		Stop()
		return
	end
	if
		not UnitExists("target")
		or not UnitCanAttack("player", "target")
		or UnitIsDeadOrGhost("player")
		or UnitIsDeadOrGhost("target")
	then
		frame:Hide()
		return
	end
	local melee = Model.First(bands.melee, ranks, Known)
	local ranged = Model.First(bands.ranged, ranks, Known)
	if not (melee and ranged) then
		frame:Hide()
		return
	end
	local band = Model.Band(InRange(melee), InRange(ranged))
	if not band then
		frame:Hide()
		return
	end
	Draw(band == "melee" and melee or ranged, band)
end

local function Sync()
	Build()
	if not frame then
		return
	end
	local bands = class and BANDS[class]
	if not (ns.Active(KEY) and bands) then
		Stop()
		return
	end
	if UnitExists("target") then
		if not ticker then
			ticker = C_Timer.NewTicker(PERIOD, Update)
		end
		Update()
	else
		Stop()
	end
end

ns.Init(function()
	local _, playerClass = UnitClass("player")
	class = playerClass
	ScanSpells()
	Sync()
end)

ns.On("PLAYER_TARGET_CHANGED", Sync)
ns.On("PLAYER_ENTERING_WORLD", function()
	ScanSpells()
	Sync()
end)
ns.On("SPELLS_CHANGED", function()
	ScanSpells()
	Sync()
end)
ns.OnSettingChanged(KEY, Sync)
