# About the app

Tweaks Forever is a World of Warcraft: Forever addon written in Lua 5.1. It cannot run outside the
game client, and you must never start the game. What runs here is its headless test harness:
each `tests/<name>_spec.lua` stubs the client API, loads the addon files the TOC lists, and checks
one feature. Run a spec with `luajit tests/<name>_spec.lua`; a failing spec exits non-zero and prints
the failed assertion. `luacheck <file>` lints a file.

Use the specs and `luajit -e` one-liners that load the harness to check what a change claims.
Report a spec that fails, an error that a spec prints, or a behaviour a spec shows that the
change does not intend.

## Sign in

No sign-in.

## Important flows

- The specs for the files a change touches, for example `tests/dungeonmaps_spec.lua` and
  `tests/dungeonentrances_spec.lua` for the dungeon maps.

## Never do these things

- Never launch the game, Battle.net, Lutris or Wine.
- Never edit, move or delete files.
- Never use the network.
