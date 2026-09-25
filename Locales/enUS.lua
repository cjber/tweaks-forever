---@type string, TFNamespace
local _, ns = ...

-- English phrases are the keys, so a phrase with no translation shows in English. A translation is a
-- Locales/<locale>.lua listed in the TOC after this file; Locales/README.md says how to add one.
ns.L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
