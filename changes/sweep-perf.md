### Fixed

- **Quest giver and trainer lookups no longer slow down as more NPCs are queued.** Reading NPC places from QuestieDB now takes each queued NPC in constant time instead of shifting the whole queue for every one, and the range strip rebuilds its segments only when your spells or weapon change instead of five times a second.
