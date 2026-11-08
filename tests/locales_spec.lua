-- Every translation the TOC loads, loaded the way the client does with GetLocale stubbed: it fills ns.L only for
-- its own locale, keys only phrases.txt's phrases, and every format string keeps English's placeholders in order and
-- formats with sample arguments.

-- The translations, in TOC order after the English file.
local files = {}
for line in io.lines("TweaksForever.toc") do
	local code = line:match("^Locales\\(%a%a%u%u)%.lua%s*$")
	if code and code ~= "enUS" then
		files[#files + 1] = code
	end
end
assert(#files > 0, "the TOC loads no translation")

-- Loads Locales/<file>.lua into a fresh ns (English first) with the client reporting `client`, and returns ns.
-- Each chunk is parsed once: executing it again still fills a fresh ns, and the same 43 KB translation parsed three
-- times only measured the parser.
local chunks = {}
local function Chunk(file)
	local chunk = chunks[file]
	if not chunk then
		chunk = assert(loadfile("Locales/" .. file .. ".lua"))
		chunks[file] = chunk
	end
	return chunk
end

local function Load(file, client)
	local ns = {}
	Chunk("enUS")("TweaksForever", ns)
	local env = setmetatable({
		GetLocale = function()
			return client
		end,
	}, { __index = _G })
	setfenv(Chunk(file), env)("TweaksForever", ns)
	return ns
end

-- The English phrases, read through the template's own lines. The release zip leaves the template out, so on the
-- packaged files only the translations themselves are checked (each key is its English text).
local phrases
local template = loadfile("Locales/phrases.txt")
if template then
	local ns = { L = {} }
	local env = setmetatable({
		GetLocale = function()
			return "deDE"
		end,
	}, { __index = _G })
	setfenv(template, env)("TweaksForever", ns)
	phrases = ns.L
	assert(next(phrases), "phrases.txt holds no phrase")
end

-- Each placeholder's conversion in `text`, in order, or nil when it is not a format string (a literal "100% "
-- has none).
local SAMPLES = { d = 3, i = 3, s = "Elwynn Forest", f = 1.5, g = 1.5 }
local function Conversions(text)
	local found = {}
	for spec in text:gmatch("%%[-+ #0]*%d*%.?%d*(%a?%%?)") do
		if spec ~= "%" then
			if SAMPLES[spec] == nil then
				return nil
			end
			found[#found + 1] = spec
		end
	end
	return #found > 0 and found or nil
end

for _, code in ipairs(files) do
	local ns = Load(code, code)
	local own = rawget(ns, "L")
	local count = 0
	for key, value in pairs(own) do
		count = count + 1
		assert(not phrases or phrases[key], code .. ": not in phrases.txt: " .. key)
		assert(type(value) == "string" and value ~= "", code .. ": empty line for " .. key)
		local want = Conversions(key)
		if want then
			-- The same placeholders as English, in the same order, so the code's arguments land where they belong.
			local have = Conversions(value) or {}
			assert(table.concat(have, " ") == table.concat(want, " "), code .. ": placeholders differ in " .. value)
			local args = {}
			for index, conversion in ipairs(want) do
				args[index] = SAMPLES[conversion]
			end
			local ok, result = pcall(string.format, value, unpack(args))
			assert(ok, code .. ": " .. key .. " -> " .. value .. ": " .. tostring(result))
			assert(not result:find("%%[%a]"), code .. ": left a placeholder in " .. result)
		end
	end
	assert(count > 0, code .. " translated nothing")
	-- A phrase the file leaves out still reads as English.
	assert(ns.L["a phrase nobody translated"] == "a phrase nobody translated")

	-- Another client language leaves English untouched.
	local other = Load(code, code == "deDE" and "frFR" or "deDE")
	assert(next(rawget(other, "L")) == nil, code .. " wrote lines for another locale")
end

-- These values are formatted directly from the client's yard counts, without metric conversion.
local yardWords =
	{ deDE = "yd", esES = "yardas", esMX = "yardas", frFR = "yd", ptBR = "jardas", koKR = "야드", ruRU = "ярд." }
for code, unit in pairs(yardWords) do
	local translated = Load(code, code).L
	assert(translated["%d yd"]:format(100):find(unit, 1, true), code .. ": 100 yards must retain its yard unit")
	assert(
		translated["%.1fk yd"]:format(1.5):find(unit, 1, true),
		code .. ": 1500 yards must not be labelled kilometres"
	)
	for key, value in pairs(translated) do
		if key:find("Campfire:", 1, true) and key:find("%d yd", 1, true) then
			assert(value:format(100):find(unit, 1, true), code .. ": campfire yards must use the same unit")
		end
	end
end
