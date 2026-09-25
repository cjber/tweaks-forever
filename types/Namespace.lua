---@meta

---@alias TFMarks table<integer, boolean>
---@alias TFGroups table<string, TFMarks>
---@alias TFColour [number, number, number]
---@alias TFColours table<string, table<string|integer, TFColour>>
---@alias TFCampBenefit [integer, string, string, number?, number[]?]

---@class TFCampRow
---@field benefit TFCampBenefit
---@field left? number
---@field points? number[] the aura's values by effect, while you have it

---@class TFCamp
---@field Listing fun(remaining: fun(aura: integer): number?, number[]?): TFCampRow[]
---@field Toward fun(north: number, west: number, facing: number): string
---@field Effect fun(benefit: TFCampBenefit, points: number[]?): string
---@field Announcement fun(benefit: TFCampBenefit, points: number[]?): string

---@class TFTrainerSpell
---@field name string
---@field rank? string
---@field level number
---@field icon fileID
---@field lineID? integer the skill line the spell belongs to, as a SkillLine ID: a class line is its spellbook tab
---@field general? true its line is not a class line, so it goes on the General tab (Dual Wield, Defense, armour)
---@field line? string a trainer visit's name for that line, in the client's language
---@field cost? number copper

-- A spell a class trainer teaches: { spell, level, fee in copper (nil when unknown), SkillLine ID }. A class line
-- is its spellbook tab; any other puts it on the General tab.
---@class TFClassSpell
---@field [1] integer
---@field [2] integer
---@field [3] integer?
---@field [4] integer
---@field needs? integer[] the rank before it, which no trainer teaches: any of these must be known first
---@field races? integer[] the ChrRaces IDs it is for, when not every race

---@class TFClassSpells
---@field lines integer[] its class skill line IDs (spellbook tabs)
---@field spells TFClassSpell[]

-- What the client knows of a spell, for a trainer row it has never seen.
---@class TFSpellFacts
---@field name string
---@field icon fileID
---@field rank? string

---@class TFFutureSpell
---@field id integer
---@field spell TFTrainerSpell
---@field ready boolean your level allows it: waiting at the trainer

---@class TFGrid
---@field views integer
---@field width number
---@field height number
---@field columns integer
---@field gap number
---@field pad number
---@field spacer number
---@field header number
---@field item number

---@class TFSlot
---@field page integer
---@field view integer
---@field x number
---@field y number

---@class TFEntrance
---@field x number
---@field y number
---@field instances integer[]
---@field area? integer

---@class TFPosition
---@field x number
---@field y number
---@field scale number

---@class TFGiverPoint
---@field continent integer
---@field x number world yards
---@field y number world yards

---@class TFGiverCandidate
---@field id integer
---@field points TFGiverPoint[]
---@field starts integer[] quest IDs
---@field ends integer[] quest IDs

---@class TFGiverQuest
---@field id integer
---@field title string
---@field level integer
---@field min integer the level it opens at
---@field soon? boolean above your level
---@field ready? boolean complete, for a quest in your log

---@class TFQuestGivers
---@field Attach fun(): boolean
---@field Resolve fun(name: string, continent: integer, x: number, y: number): TFGiverCandidate?
---@field Quests fun(npc: TFGiverCandidate): TFGiverQuest[], TFGiverQuest[]
---@field Lines fun(npc: TFGiverCandidate): [string, number, number, number][]
---@field Names fun(data: TooltipData): string[]
---@field TooltipLines fun(names: string[]): [string, number, number, number][]

-- One of a quest's objectives in the log's order: the kind the log gives it and the creatures that count toward it.
---@class TFQuestTarget
---@field kind string
---@field npcs table<integer, true>

-- Which objectives of one quest a creature counts for by QuestieDB's IDs: [position in the log] = the kind there.
---@alias TFQuestLink table<integer, string>

-- A quest in your log, with its objectives as of the log's last change.
---@class TFLogQuest
---@field id integer
---@field title string
---@field complete boolean
---@field objectives QuestObjectiveInfo[]

-- A quest a creature counts for, and the objectives it counts for.
---@class TFQuestMatch
---@field quest TFLogQuest
---@field objectives QuestObjectiveInfo[]

---@class TFQuestProgress
---@field Attach fun(): boolean
---@field NpcId fun(guid: any): integer?
---@field Targets fun(id: integer): TFQuestTarget[]
---@field Rebuild fun()
---@field Matches fun(npc: integer?, name: string?): TFQuestMatch[]
---@field Lines fun(npc: integer?, name: string?): [string, number, number, number][]
---@field Needed fun(npc: integer?, name: string?): boolean
---@field Name fun(name: any): string?
---@field HasQuestLines fun(data: TooltipData): boolean

---@class TFDatabase
---@field junk TFMarks
---@field gearMark? 'strip'|'border'|'dots'|'none'
---@field savedSounds? table<string, string>
---@field windowLayouts? table<string, table<string, TFPosition>>
---@field [string] boolean|string|TFMarks|table<string, string>|table<string, table<string, TFPosition>>

---@class TFCharacterDatabase
---@field groups TFGroups
---@field colours TFColours
---@field beforeFishing? table<integer, integer>
---@field trainer? table<integer, TFTrainerSpell>

---@type TFDatabase
TweaksForeverDB = nil
---@type TFCharacterDatabase
TweaksForeverCharDB = nil

---@class TFConflict
---@field addon string
---@field title? string
---@field when? fun(): boolean?

---@class TFFeature
---@field key string
---@field category string
---@field name string
---@field tooltip? string
---@field default boolean|string
---@field conflicts? TFConflict[]
---@field options? [string, string][]
---@field parent? string

---@class TFClickMode
---@field feature string
---@field label string
---@field tooltip string
---@field cursor string
---@field Apply fun(owner: Button, bag: integer, slot: integer)

---@class TFNamespace
---@field db TFDatabase
---@field features TFFeature[]
---@field Overlays table<integer, string>
---@field Junk TFJunk
---@field Gear TFGear
---@field Fishing TFFishing
---@field Frames TFFrames
---@field Exploration TFExploration
---@field Sections TFSections
---@field Reagents TFReagents
---@field CampBenefits TFCampBenefit[]
---@field Camp TFCamp
---@field FutureSpells TFFutureSpells
---@field ClassSpells table<string, TFClassSpells> by class token
---@field TrainerSpells fun(): table<integer, TFTrainerSpell>
---@field LineName fun(lineID: integer, fallback: string?): string
---@field GeneralName fun(): string
---@field OnGeneral fun(lineID: integer): true?
---@field LineResolver fun(): fun(id: integer, name: string?): integer?
---@field KnownSpell fun(id: integer): boolean
---@field ZoneRanges table<integer, [number, number]>
---@field ZoneLevels TFZoneLevels
---@field DungeonEntrances table<integer, TFEntrance[]>
---@field RaidInstances table<integer, boolean>
---@field Entrances TFEntrances
---@field QuestGivers TFQuestGivers
---@field QuestProgress TFQuestProgress
---@field QuestieDB fun(): TFQuestieDB?
---@field Print fun(message: string)
---@field Navigate fun(uiMapID: integer, x: number, y: number, title: string)
---@field NavigateHint fun(): string
---@field Feature fun(feature: TFFeature)
---@field RefreshConflicts fun()
---@field ConflictOf fun(key: string): string?
---@field Active fun(key: string): boolean
---@field On fun(event: WowEvent, fn: function)
---@field Init fun(fn: fun())
---@field ContainerFrames fun(): (fun(): ContainerFrameTemplate|ContainerFrameCombinedBags?)
---@field ForEachBagButton fun(fn: fun(button: ContainerFrameItemButtonTemplate))
---@field HookBagButtons fun(hooked: table<ContainerFrameItemButtonTemplate, boolean>, update: fun(button: ContainerFrameItemButtonTemplate), click: fun(button: ContainerFrameItemButtonTemplate, mouseButton: string))
---@field IsBagActionClick fun(): boolean
---@field ClickMode fun(mode: TFClickMode)
