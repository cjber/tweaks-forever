### Fixed

- **Quest giver and trainer lookups take less work as more NPCs are queued.** Reading NPC places from QuestieDB no longer shifts the whole queue for every NPC it takes. The range strip reads its spells and weapon icon when they change (spells, talents, level, equipment or entering the world) instead of five times a second, and reads a spell again until the client has loaded its name.
