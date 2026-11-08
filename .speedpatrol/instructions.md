# About the app

Tweaks Forever is a World of Warcraft: Forever addon in Lua 5.1. The game cannot run here. The
benchmarks run the headless harness the specs use, which stubs the client API and loads the files
`TweaksForever.toc` lists in order.

- Keep a change only when it speeds up a file the TOC loads or the gate itself. A change to a spec, a
  bench or other measuring code is not a speed-up.
- Every change must pass the full gate in `AGENTS.md` under "Commands", with lua-language-server
  3.19.1 and stylua 2.5.2 first on `PATH`, the versions CI uses.
- Generated data (`Data/`), translations (`Locales/`), pinned contracts (`types/`) and the vendored
  `tools/forever_tools/` are never edited by hand.
- Commit only the files the change needs: no profiler output or scratch files.
- Never use the network, and never start the game, Battle.net, Lutris or Wine. The headless client (forever-core's `wow-forever-addon/in-game.md`) tests the build linked into the game, not this checkout, so in-game checks belong to the agent that ships a change.

## On pull requests

`.github/workflows/speedpatrol.yml` runs `speedpatrol compare` on every pull request: three A/B rounds
against the base branch, over `gate.specs` only, failing the job on a regression. Tweaks has no
bench script; `gate.typecheck` is for the local patrol.
