---@type string, TFNamespace
local _, ns = ...
local L, locale = {}, GetLocale()

-- The packager replaces each comment below with that language's L["English"] = "translation" lines from the
-- CurseForge project's Localization page. Unpackaged, they stay comments and every phrase shows in English.
if locale == "deDE" then
	--@localization(locale="deDE", format="lua_additive_table", handle-unlocalized="ignore")@
elseif locale == "esES" then
	--@localization(locale="esES", format="lua_additive_table", handle-unlocalized="ignore")@
elseif locale == "esMX" then
	--@localization(locale="esMX", format="lua_additive_table", handle-unlocalized="ignore")@
elseif locale == "frFR" then
	--@localization(locale="frFR", format="lua_additive_table", handle-unlocalized="ignore")@
elseif locale == "itIT" then
	--@localization(locale="itIT", format="lua_additive_table", handle-unlocalized="ignore")@
elseif locale == "koKR" then
	--@localization(locale="koKR", format="lua_additive_table", handle-unlocalized="ignore")@
elseif locale == "ptBR" then
	--@localization(locale="ptBR", format="lua_additive_table", handle-unlocalized="ignore")@
elseif locale == "ruRU" then
	--@localization(locale="ruRU", format="lua_additive_table", handle-unlocalized="ignore")@
elseif locale == "zhCN" then
	--@localization(locale="zhCN", format="lua_additive_table", handle-unlocalized="ignore")@
elseif locale == "zhTW" then
	--@localization(locale="zhTW", format="lua_additive_table", handle-unlocalized="ignore")@
end
for english, text in pairs(L) do
	ns.L[english] = text
end
