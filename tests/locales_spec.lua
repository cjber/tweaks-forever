-- Every translation the TOC loads, loaded the way the client does with GetLocale stubbed: it fills ns.L only for
-- its own locale, keys only phrases.txt's phrases, and every format string formats with sample arguments.

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
local function Load(file, client)
	local ns = {}
	assert(loadfile("Locales/enUS.lua"))("TweaksForever", ns)
	local env = setmetatable({
		GetLocale = function()
			return client
		end,
	}, { __index = _G })
	setfenv(assert(loadfile("Locales/" .. file .. ".lua")), env)("TweaksForever", ns)
	return ns
end

-- The English phrases, read through the template's own lines.
local phrases
do
	local ns = { L = {} }
	local env = setmetatable({
		GetLocale = function()
			return "deDE"
		end,
	}, { __index = _G })
	setfenv(assert(loadfile("Locales/phrases.txt")), env)("TweaksForever", ns)
	phrases = ns.L
end
assert(next(phrases), "phrases.txt holds no phrase")

-- Sample arguments for each placeholder in `text`, or nil when it is not a format string.
local SAMPLES = { d = 3, i = 3, s = "Elwynn Forest", f = 1.5, g = 1.5 }
local function Samples(text)
	local args = {}
	for spec in text:gmatch("%%[-+ #0]*%d*%.?%d*(%a?%%?)") do
		if spec ~= "%" then
			local sample = SAMPLES[spec]
			if sample == nil then
				return nil
			end
			args[#args + 1] = sample
		end
	end
	return #args > 0 and args or nil
end

for _, code in ipairs(files) do
	local ns = Load(code, code)
	local own = rawget(ns, "L")
	local count = 0
	for key, value in pairs(own) do
		count = count + 1
		assert(phrases[key], code .. ": not in phrases.txt: " .. key)
		assert(type(value) == "string" and value ~= "", code .. ": empty line for " .. key)
		local args = Samples(key)
		if args then
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
