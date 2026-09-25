# Translations

Every phrase the addon shows is keyed by its English text, so anything not translated shows in English.

To add a language, copy `phrases.txt` to `<locale>.lua` (`deDE.lua`, `frFR.lua`, `zhCN.lua` and so on), set the
locale in its `GetLocale()` line, translate the text on the right of each line and delete the lines you'd rather
leave in English. Then add `Locales\<locale>.lua` to `TweaksForever.toc` straight after `Locales\enUS.lua` and open
a pull request. If that's more than you want to do, paste your translations into an issue and I'll add them.
