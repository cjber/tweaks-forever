# Translations

Every phrase the addon shows is keyed by its English text, so anything not translated shows in English.

German, Spanish (esES and esMX), French, Korean, Brazilian Portuguese, Russian and Chinese (zhCN and zhTW) are
machine translated, using the game's own words where it has them: each such file starts with a
`-- Machine translated` comment. A human correction replaces the machine line; in a file that then mixes the two,
each remaining machine line ends `-- mt`. There is no Italian file, because the WoW: Forever client has no Italian.
`python3 tools/check_locales.py` checks every file and prints its coverage.

To correct a line, edit `Locales/<locale>.lua` and open a pull request, or paste the corrected lines into a
[translation issue](https://github.com/cjber/tweaks-forever/issues/new?template=translation.yml) and I'll add them.

To add a language the client offers, copy `phrases.txt` to `<locale>.lua`, set the locale in its `GetLocale()` line,
translate the text on the right of each line and delete the lines you'd rather leave in English. Then add
`Locales\<locale>.lua` to `TweaksForever.toc` straight after `Locales\enUS.lua` and open a pull request.
