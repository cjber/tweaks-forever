-- UI/RangeBand.lua reads the hunter's melee and ranged reach from the client's own spell checks, picks the rank the
-- spellbook holds and draws one icon beside the target frame: melee, ranged, or Auto Shot greyed and red in the dead
-- zone. The ticker exists only while a target does.

local function Texture()
	local texture = {}
	function texture.SetPoint() end
	function texture.SetSize(_, width, height)
		texture.width, texture.height = width, height
	end
	function texture.SetTexCoord() end
	function texture.SetTexture(_, file)
		texture.texture = file
	end
	function texture.SetDesaturated(_, value)
		texture.desaturated = value
	end
	function texture.SetVertexColor(_, red, green, blue)
		texture.red, texture.green, texture.blue = red, green, blue
	end
	return texture
end

local function Frame()
	local frame = { shown = false }
	function frame.SetFrameLevel(_, level)
		frame.level = level
	end
	function frame.SetSize() end
	function frame.SetPoint() end
	function frame.Show()
		frame.shown = true
	end
	function frame.Hide()
		frame.shown = false
	end
	function frame.CreateTexture()
		frame.texture = Texture()
		return frame.texture
	end
	return frame
end

-- A target frame with the one child the range icon anchors to.
local function Target()
	return {
		level = 10,
		GetFrameLevel = function()
			return 10
		end,
		TargetFrameContainer = { Portrait = {} },
	}
end

-- Loads UI/RangeBand.lua against a client whose target, spellbook and range answers the spec sets. `opts`:
-- class, targetExists, targetHostile, playerDead, targetDead, readable, range, book, baseOf, known.
local function Boot(opts)
	opts = opts or {}
	local state = {
		handlers = {},
		tickers = {},
		db = { rangeBand = true },
		class = opts.class or "HUNTER",
		targetExists = opts.targetExists ~= false,
		targetHostile = opts.targetHostile ~= false,
		playerDead = opts.playerDead == true,
		targetDead = opts.targetDead == true,
		readable = opts.readable ~= false,
		range = opts.range or { [14260] = true, [75] = false },
		book = opts.book or {
			{ actionID = 14260, spellID = 14260 },
			{ actionID = 75, spellID = 75 },
		},
		baseOf = opts.baseOf or { [14260] = 2973, [75] = 75 },
		known = opts.known or {},
	}
	local ns = {
		L = setmetatable({}, {
			__index = function(_, key)
				return key
			end,
		}),
		Feature = function(feature)
			state.feature = feature
		end,
		Init = function(initializer)
			state.init = initializer
		end,
		On = function(event, handler)
			state.handlers[event] = state.handlers[event] or {}
			table.insert(state.handlers[event], handler)
		end,
		Active = function(key)
			return state.db[key] ~= false
		end,
		OnSettingChanged = function(_, handler)
			state.settingChanged = handler
		end,
		Readable = function(value)
			if not state.readable then
				return nil
			end
			return value
		end,
		Art = {
			Icon = function(texture, file, size)
				texture:SetTexCoord(0, 1, 0, 1)
				texture:SetTexture(file)
				texture:SetSize(size, size)
			end,
		},
		db = state.db,
	}
	state.ns = ns
	local target = Target()
	state.target = target
	local env = setmetatable({
		Enum = { SpellBookSpellBank = { Player = 0 } },
		C_Spell = {
			IsSpellInRange = function(id)
				return state.range[id]
			end,
			GetSpellTexture = function(id)
				return 1000 + id
			end,
		},
		C_SpellBook = {
			GetNumSpellBookSkillLines = function()
				return #state.book > 0 and 1 or 0
			end,
			GetSpellBookSkillLineInfo = function()
				return { itemIndexOffset = 0, numSpellBookItems = #state.book }
			end,
			GetSpellBookItemInfo = function(slot)
				return state.book[slot]
			end,
			FindBaseSpellByID = function(id)
				return state.baseOf[id] or id
			end,
			IsSpellKnown = function(id)
				return state.known[id] == true
			end,
		},
		C_Timer = {
			NewTicker = function(period, fn)
				local ticker = { period = period, fn = fn }
				function ticker:Cancel()
					self.cancelled = true
				end
				state.tickers[#state.tickers + 1] = ticker
				return ticker
			end,
		},
		CreateFrame = function(_, _, parent)
			state.frame = Frame()
			state.frame.parent = parent
			return state.frame
		end,
		TargetFrame = target,
		UnitClass = function()
			return "Hunter", state.class
		end,
		UnitExists = function(unit)
			return unit == "target" and state.targetExists
		end,
		UnitCanAttack = function()
			return state.targetHostile
		end,
		UnitIsDeadOrGhost = function(unit)
			return (unit == "player" and state.playerDead) or (unit == "target" and state.targetDead)
		end,
		wipe = function(table)
			for key in pairs(table) do
				table[key] = nil
			end
		end,
	}, { __index = _G })
	setfenv(assert(loadfile("UI/RangeBand.lua")), env)("TweaksForever", ns)
	state.init()

	---@param event string
	function state.Fire(event)
		for _, handler in ipairs(state.handlers[event] or {}) do
			handler()
		end
	end

	function state.Tick()
		for index = #state.tickers, 1, -1 do
			local ticker = state.tickers[index]
			if not ticker.cancelled then
				ticker.fn()
				return
			end
		end
	end

	---@return table?
	function state.Live()
		for _, ticker in ipairs(state.tickers) do
			if not ticker.cancelled then
				return ticker
			end
		end
	end

	return state
end

-- The declaration claims only hunters' own dead zone and names the range addons it steps aside for.
local declared = Boot()
assert(declared.feature.default == true, "a reading of the target, not an automation")
assert(declared.feature.category == "Interface")
assert(declared.feature.tooltip:find("dead zone", 1, true))
local conflicts = {}
for _, conflict in ipairs(declared.feature.conflicts) do
	conflicts[conflict.addon] = true
end
assert(conflicts.RangeLens and conflicts.RangeDisplay)

-- The band is melee, then ranged, then the dead zone only when both answers are a plain no. A missing answer hides.
local Model = declared.ns.RangeBand
assert(Model.Band(true, false) == "melee")
assert(Model.Band(true, true) == "melee", "melee reach wins when both answer")
assert(Model.Band(false, true) == "ranged")
assert(Model.Band(false, false) == "dead")
assert(Model.Band(nil, true) == "ranged")
assert(Model.Band(nil, nil) == nil)
assert(Model.Band(nil, false) == nil)
assert(Model.Band(false, nil) == nil)

-- The spellbook's rank wins over the base ID, and a base the client knows but the book does not list still answers.
assert(Model.Rank(2973, { [2973] = 14260 }, function()
	return false
end) == 14260)
assert(Model.Rank(75, {}, function(id)
	return id == 75
end) == 75)
assert(Model.Rank(75, {}, function()
	return false
end) == nil)
assert(Model.First({ 2973, 2974 }, { [2974] = 14261 }, function(id)
	return id == 2974
end) == 14261)

-- One ticker, and the icon follows the client's answers. Melee shows the rank the spellbook holds.
local harness = Boot()
assert(harness.frame.parent == harness.target, "the icon is a child of the target frame, so Edit Mode carries it")
assert(harness.frame.level == 15, "the icon sits above the target frame's own art")
assert(#harness.tickers == 1 and harness.Live(), "one ticker while a target exists")
assert(harness.tickers[1].period == 0.2)
assert(harness.frame.shown)
assert(harness.frame.texture.texture == 1000 + 14260, "Raptor Strike's known rank")
assert(harness.frame.texture.desaturated == false)
assert(harness.frame.texture.red == 1 and harness.frame.texture.green == 1 and harness.frame.texture.blue == 1)

-- Neither reaches: Auto Shot's icon, desaturated and red.
harness.range[14260], harness.range[75] = false, false
harness.Tick()
assert(harness.frame.shown)
assert(harness.frame.texture.texture == 1000 + 75, "the ranged spell marks the dead zone")
assert(harness.frame.texture.desaturated == true)
assert(harness.frame.texture.red == 1 and harness.frame.texture.green == 0.08 and harness.frame.texture.blue == 0.08)

-- Ranged: the same icon in its own colours.
harness.range[14260], harness.range[75] = false, true
harness.Tick()
assert(harness.frame.shown)
assert(harness.frame.texture.texture == 1000 + 75)
assert(harness.frame.texture.desaturated == false)
assert(harness.frame.texture.red == 1 and harness.frame.texture.green == 1 and harness.frame.texture.blue == 1)

-- A missing answer is not a band: the icon stays off.
harness.range[14260], harness.range[75] = nil, false
harness.Tick()
assert(not harness.frame.shown)

-- No target: the icon and its ticker go, and a fresh target starts one ticker again.
harness.targetExists = false
harness.Fire("PLAYER_TARGET_CHANGED")
assert(not harness.frame.shown)
assert(harness.tickers[1].cancelled and harness.Live() == nil)
harness.targetExists = true
harness.range[14260], harness.range[75] = true, false
harness.Fire("PLAYER_TARGET_CHANGED")
assert(#harness.tickers == 2 and harness.Live() == harness.tickers[2])
assert(harness.frame.shown)

-- A friendly target, a dead player and a dead target all hide it.
harness.targetHostile = false
harness.Fire("PLAYER_TARGET_CHANGED")
assert(not harness.frame.shown)
harness.targetHostile = true
harness.playerDead = true
harness.Tick()
assert(not harness.frame.shown)
harness.playerDead = false
harness.targetDead = true
harness.Tick()
assert(not harness.frame.shown)
harness.targetDead = false
harness.Tick()
assert(harness.frame.shown)

-- The setting stops the ticker at once, and switching it back on redraws without waiting for the next tick.
harness.db.rangeBand = false
harness.settingChanged()
assert(not harness.frame.shown and harness.Live() == nil)
harness.db.rangeBand = true
harness.settingChanged()
assert(harness.frame.shown and harness.Live())
assert(harness.Live().period == 0.2)

-- A secret range answer cannot be read, so the icon waits rather than guesses.
local secret = Boot({ readable = false })
assert(not secret.frame.shown)
assert(secret.Live(), "the target still exists, so the ticker still watches it for a readable answer")

-- Classes without a dead zone never build a ticker or show anything.
local mage = Boot({ class = "MAGE" })
assert(not mage.frame.shown and mage.Live() == nil)

-- Both spells must be known. Raptor Strike alone is not a band.
local partial = Boot({
	book = { { actionID = 14260, spellID = 14260 } },
	known = {},
})
assert(partial.frame.texture.texture == nil and not partial.frame.shown, "no ranged spell, no band")

-- A base the client knows but the spellbook does not list is asked as that base ID.
local base = Boot({
	book = {},
	known = { [2973] = true, [75] = true },
	range = { [2973] = false, [75] = true },
})
assert(base.frame.shown)
assert(base.frame.texture.texture == 1000 + 75)

print("rangeband_spec: ok")
