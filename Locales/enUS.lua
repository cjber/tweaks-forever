---@type string, TFNamespace
local _, ns = ...

-- English phrases are the keys, so a phrase with no translation shows in English. Locales/Translations.lua fills
-- the other languages from the CurseForge project's Localization page when the addon is packaged.
ns.L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
