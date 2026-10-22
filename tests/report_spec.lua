-- The report window and caught errors (UI/Report.lua, Core/Report.lua, Core/SafeCall.lua): /tweaks report shows
-- one selected block of text with the versions, character, place, what the player changed and what stands down,
-- the caught errors and the other addons, never longer than one message; ns.SafeCall keeps errors and still
-- reports them.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)), 2)
	end
end
local function has(text, part, label)
	checks = checks + 1
	if not text:find(part, 1, true) then
		error(("%s: %q not in\n%s"):format(label, part, text), 2)
	end
end
local function lacks(text, part, label)
	checks = checks + 1
	if text:find(part, 1, true) then
		error(("%s: %q in\n%s"):format(label, part, text), 2)
	end
end

-- Frames that remember what the report window does with them; any other method is a no-op.
local made, focus = 0, nil
local function Widget(kind, template, parent)
	local widget =
		{ kind = kind, template = template, parentFrame = parent or false, scripts = {}, shown = true, text = "" }
	return setmetatable(widget, {
		__index = function(_, name)
			local methods = {
				SetScript = function(self, script, fn)
					self.scripts[script] = fn
				end,
				SetText = function(self, text)
					self.text, self.highlighted = text, nil
				end,
				GetText = function(self)
					return self.text
				end,
				SetTitle = function(self, text)
					self.title = text
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
				SetFocus = function(self)
					focus = self
				end,
				HighlightText = function(self)
					self.highlighted = self.text
				end,
				GetPortrait = function(self)
					rawset(self, "portrait", rawget(self, "portrait") or Widget("Texture"))
					return rawget(self, "portrait")
				end,
				CreateFontString = function()
					return Widget("FontString")
				end,
				SetScrollChild = function(self, child)
					self.child = child
				end,
			}
			return methods[name] or function() end
		end,
	})
end

local errors, addons, globals = {}, {}, {}
local env = setmetatable({
	UISpecialFrames = {},
	CreateFrame = function(kind, name, parent, template)
		made = made + 1
		local widget = Widget(kind, template, parent)
		if name then
			globals[name] = widget
		end
		return widget
	end,
	geterrorhandler = function()
		return function(message)
			errors[#errors + 1] = message
		end
	end,
	strtrim = function(text)
		return (text:gsub("^%s+", ""):gsub("%s+$", ""))
	end,
	GetTime = function()
		return 100
	end,
	GetBuildInfo = function()
		return "1.60.1", "70374", "Oct 1 2026", 16001
	end,
	GetLocale = function()
		return "enUS"
	end,
	UnitClass = function()
		return "Shaman", "SHAMAN"
	end,
	UnitRace = function()
		return "Orc", "Orc"
	end,
	UnitLevel = function()
		return 18
	end,
	UnitFactionGroup = function()
		return "Horde"
	end,
	C_Map = {
		GetBestMapForUnit = function()
			return 1413
		end,
		GetPlayerMapPosition = function()
			return {
				GetXY = function()
					return 0.52, 0.3
				end,
			}
		end,
		GetMapInfo = function()
			return { name = "The Barrens" }
		end,
	},
	C_AddOns = {
		GetAddOnMetadata = function(addon, field)
			assert(field == "Version")
			return addon == "TweaksForever" and "1.2.3" or addons[addon]
		end,
		GetNumAddOns = function()
			local count = 1
			for _ in pairs(addons) do
				count = count + 1
			end
			return count
		end,
		GetAddOnInfo = function(index)
			local names = {}
			for name in pairs(addons) do
				names[#names + 1] = name
			end
			table.sort(names)
			table.insert(names, 1, "TweaksForever")
			return names[index]
		end,
		IsAddOnLoaded = function()
			return true
		end,
	},
}, { __index = _G })

local ns = { L = {} }
setmetatable(ns.L, {
	__index = function(_, key)
		return key
	end,
})
ns.Art = {
	Icon = function(texture, file, size)
		texture.file, texture.size = file, size
	end,
}
local db, conflicts, missing = {}, {}, {}
ns.db = db
ns.features = {
	{ key = "repair", default = true },
	{ key = "quests", default = false },
	{ key = "gearMark", default = "strip" },
	{ key = "fastLoot", default = true },
	{ key = "questTooltips", default = true },
}
ns.ConflictOf = function(key)
	return conflicts[key]
end
ns.MissingOf = function(key)
	return missing[key]
end
for _, file in ipairs({ "Core/SafeCall.lua", "UI/Report.lua", "Core/Report.lua" }) do
	setfenv(assert(loadfile(file)), env)("TweaksForever", ns)
end

local function Report()
	ns.Report.Show(ns.Report.Text(ns.ReportLines()))
	return focus, focus and focus.text
end

do
	db.repair, db.quests, db.gearMark, db.fastLoot, db.questTooltips = true, true, "dots", true, true
	conflicts.fastLoot, missing.questTooltips = "Polestar", "QuestieDB"
	addons.Questie, addons.Polestar = "9.1.0", "0.4.0"
	local before = made
	local edit, text = Report()
	equal(edit and edit.kind, "EditBox", "the report's edit box has the focus")
	equal(edit.highlighted, text, "the whole report is selected")
	has(text, "TweaksForever 1.2.3 | WoW 1.60.1 (70374) 16001 | enUS", "versions, build and locale")
	has(text, "Character: level 18 Orc SHAMAN, Horde", "character, no name")
	has(text, "Place: map 1413 (The Barrens) 52.0, 30.0", "place")
	has(text, "Differs from default: quests=on, gearMark=dots", "what the player changed, by key")
	lacks(text, "repair=", "a default left alone is not listed")
	has(text, "Standing down for: fastLoot (Polestar)", "conflicts")
	has(text, "Missing an addon: questTooltips (QuestieDB)", "missing addons")
	has(text, "Errors: none caught", "no errors yet")
	has(text, "Other addons (2): Polestar 0.4.0, Questie 9.1.0", "the other addons with versions")
	equal(#text <= 2000, true, "one message")

	-- The window: a stock portrait frame with the addon's icon, titled through L.
	local window = edit
	while window.template ~= "PortraitFrameTemplate" do
		window = assert(rawget(window, "parentFrame") or nil, "the portrait frame")
	end
	equal(rawget(window, "title"), "Tweaks Forever report", "its title")
	equal(rawget(window, "portrait").file, "Interface\\AddOns\\TweaksForever\\media\\Icon", "its icon")

	-- Read-only: a key typed in the box puts the report back, selected.
	edit.text, edit.highlighted = "x", nil
	edit.scripts.OnTextChanged(edit, true)
	equal(edit.text, text, "typing restores the report")
	equal(edit.highlighted, text, "and selects it again")
	edit.scripts.OnEscapePressed(edit)
	equal(window.shown, false, "Escape hides it")
	equal(env.UISpecialFrames[1], "TweaksForeverReport", "Escape without focus: a special frame")
	equal(globals.TweaksForeverReport, window, "named for it")
	local count = made - before
	Report()
	equal(window.shown, true, "shown again")
	equal(made - before, count, "the window is made once")
	equal(#errors, 0, "no errors")
end

do
	for key in pairs(db) do
		db[key] = nil
	end
	conflicts.fastLoot, missing.questTooltips = "Polestar", "QuestieDB"
	db.fastLoot, db.questTooltips = false, false
	local _, text = Report()
	has(text, "Differs from default: fastLoot=off, questTooltips=off", "switched off")
	has(text, "Standing down for: none", "a switched-off feature isn't standing down")
	has(text, "Missing an addon: none", "nor missing anything")
	conflicts.fastLoot, missing.questTooltips = nil, nil
	db.fastLoot, db.questTooltips = nil, nil
	_, text = Report()
	has(text, "Differs from default: none", "nothing changed")
	-- The Forever addons setting and dismissed hints live outside ns.features but still show.
	db.suggestFamily, db.familyDismissed = false, { ["TweaksForever.entrance"] = true, ["Other.key"] = false }
	_, text = Report()
	has(text, "Differs from default: suggestFamily=off, familyDismissed=TweaksForever.entrance", "family settings")
	db.suggestFamily, db.familyDismissed = nil, nil
end

-- ns.SafeCall: pcall's answers, and each failure kept (label, count, short stack) and passed to the error handler.
do
	local ok, a, b, c = ns.SafeCall("test", function(x)
		return x, nil, 3
	end, 1)
	equal(ok, true, "SafeCall: ok")
	equal(a, 1, "SafeCall: first result")
	equal(b, nil, "SafeCall: a nil result kept in place")
	equal(c, 3, "SafeCall: last result")
	equal(#ns.CaughtErrors(), 0, "SafeCall: nothing caught")
	local failed, message = ns.SafeCall("test", error, "boom", 0)
	equal(failed, false, "SafeCall: failure")
	equal(message, "boom", "SafeCall: the error")
	equal(#errors, 1, "SafeCall: passed to the error handler")
	ns.SafeCall("test", error, "boom", 0)
	local caught = ns.CaughtErrors()
	equal(#caught, 1, "SafeCall: a repeat is one entry")
	equal(caught[1].count, 2, "SafeCall: counted")
	ns.SafeCall("deep", function()
		local t = nil
		return t.field
	end)
	caught = ns.CaughtErrors()
	equal(caught[2].label, "deep", "SafeCall: newest last")
	has(caught[2].stack, "report_spec.lua:", "SafeCall: the stack names the file")
	for index = 1, 6 do
		ns.SafeCall("many", error, "error " .. index, 0)
	end
	caught = ns.CaughtErrors()
	equal(#caught, 5, "SafeCall: the last five kept")
	equal(caught[5].message, "error 6", "SafeCall: newest kept")
	equal(caught[1].message, "error 2", "SafeCall: oldest dropped")
	caught[1].message = "changed"
	equal(ns.CaughtErrors()[1].message, "error 2", "SafeCall: copies")
	ns.SafeCall("long", error, ("x"):rep(400), 0)
	equal(#ns.CaughtErrors()[5].message, 300, "SafeCall: a long message is cut")
	local _, text = Report()
	has(text, "Errors (5):", "report: the caught errors")
	has(text, "- [long] x1 xxx", "report: newest first")
	equal(#text <= 2000, true, "report: still one message")
end

-- Client-format stack lines are kept; a long message is cut on a character boundary; nested calls name their own
-- label; long addon lines leave room for the errors and the addon list.
do
	ns.RecordError(
		"client",
		"boom",
		table.concat({
			'[string "@Interface/AddOns/TweaksForever/Bags/Junk.lua"]:612: in function <...>',
			"[C]: in function 'xpcall'",
		}, "\n")
	)
	local caught = ns.CaughtErrors()
	has(caught[#caught].stack, 'Junk.lua"]:612', "client stack: a string chunk line")
	lacks(caught[#caught].stack, "[C]", "client stack: C frames left out")
	ns.RecordError("utf8", ("é"):rep(200))
	local message = ns.CaughtErrors()[5].message
	equal(message:sub(-3), "...", "utf8: cut")
	equal(select(2, message:sub(1, -4):gsub("é", "")) * 2, #message - 3, "utf8: whole characters only")
	ns.SafeCall("outer", function()
		ns.SafeCall("inner", error, "inner failed", 0)
	end)
	caught = ns.CaughtErrors()
	equal(caught[#caught].label, "inner", "nested: the inner label")
	local ReportLines = ns.ReportLines
	ns.ReportLines = function()
		local long = {}
		for index = 1, 100 do
			long[index] = ("line %03d "):format(index) .. ("x"):rep(60)
		end
		return long
	end
	local _, text = Report()
	ns.ReportLines = ReportLines
	equal(#text <= 2000, true, "long lines: one message")
	lacks(text, "line 100 ", "long lines: the last cut")
	has(text, "- [inner] x1 inner failed", "long lines: the errors still shown")
	has(text, "Other addons (", "long lines: the addon list still shown")
end

-- Many other addons: the list says how many more, and the report stays one message.
do
	for index = 1, 300 do
		addons[("SomeAddon%03d"):format(index)] = "1.0." .. index
	end
	local _, text = Report()
	equal(#text <= 2000, true, "many addons: one message")
	has(text, " more", "many addons: the rest counted")
	lacks(text, "SomeAddon300", "many addons: the last left out")
end

-- Core runs every event handler through SafeCall: a failing one is kept for the report, and the next still runs.
do
	local frames = {}
	local coreEnv = setmetatable({
		CreateFrame = function()
			local frame = { RegisterEvent = function() end }
			function frame:SetScript(_, fn)
				self.callback = fn
			end
			frames[#frames + 1] = frame
			return frame
		end,
	}, { __index = env })
	local core = {}
	for _, file in ipairs({ "Core/SafeCall.lua", "Core/Core.lua" }) do
		setfenv(assert(loadfile(file)), coreEnv)("TweaksForever", core)
	end
	local ran = false
	core.On("BAG_UPDATE", function()
		error("handler failed", 0)
	end)
	core.On("BAG_UPDATE", function()
		ran = true
	end)
	local before = #errors
	frames[1].callback(frames[1], "BAG_UPDATE")
	equal(ran, true, "event: the next handler still runs")
	local caught = core.CaughtErrors()
	equal(caught[1].label, "BAG_UPDATE", "event: kept under its event")
	equal(caught[1].message, "handler failed", "event: its error")
	equal(#errors, before + 1, "event: still passed to the error handler")
end

print(("report_spec: %d checks passed"):format(checks))
