# About the app

Tweaks Forever is a World of Warcraft: Forever addon written in Lua 5.1, with Python tooling for its
checks. The game cannot run here. What verifies a refactor is the repo's own gate: `stylua --check .`,
`luacheck .`, `tools/typecheck.sh` against the pinned client annotations, and every `tests/*_spec.lua`
under LuaJIT, where the specs stub the client API and load the addon files the TOC lists in order.

Sloppatrol does not read Lua yet, so its census and survey see nothing to propose. That is expected;
the checks here are what make a proposed change verifiable anyway, and they are the same commands the
repo runs before a pull request.

## Useful refactors in this tree

- A feature file that repeats a frame, tooltip or settings-page pattern another feature already has in
  `UI/`.
- A branch that duplicates a condition already computed a few lines up.
- A table that is built at load time but only read inside one function.

## Never

- Never draw on a map outside `Map/MapCanvas.lua`, hook a Blizzard object method, or write a field on a
  Blizzard table: the gate's taint lint refuses it, and so does the game.
- Never edit `Data/` (generated), `Locales/` (translations), `types/` (pinned contracts) or
  `tools/forever_tools/` (vendored byte for byte from forever-core).
- Never launch the game, Battle.net, Lutris or Wine.
- Never leave the working tree with two changes at once: one refactor, one commit.
