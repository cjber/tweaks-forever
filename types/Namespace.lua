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
---@field Name fun(benefit: TFCampBenefit): string
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
---@field cost? number copper, or pet training points with `points`
---@field points? true its cost is pet training points, not copper

-- A row a pet trainer offers, as a visit reads it, before it is stored on the Pet tab.
---@class TFPetTrainerService
---@field id integer the spell ID
---@field name string
---@field kind string available, unavailable or used
---@field icon fileID
---@field level? number
---@field rank? string
---@field cost? number training points

-- A Beast Training row as the known-rank check reads it: its position in the trainer's list, its spell ID, its
-- name and the number in its rank subtext.
---@class TFBeastTrainingService
---@field index integer
---@field id integer
---@field name? string
---@field rank? integer

---@class TFBeastTraining
---@field KnownIndices fun(services: TFBeastTrainingService[], Known: fun(id: integer): boolean): table<integer, true>

-- The element data Blizzard's trainer list passes to each row's initializer.
---@class TFClassTrainerElement
---@field skillIndex? integer
---@field trainerType? Enum.TrainerType
---@field data? TFClassTrainerElement

-- A spell a class trainer teaches: { spell, level, fee in copper (nil when unknown), SkillLine ID }. A class line
-- is its spellbook tab; any other puts it on the General tab.
---@class TFClassSpell
---@field [1] integer
---@field [2] integer
---@field [3] integer?
---@field [4] integer
---@field needs? integer[] the rank before it, which no trainer teaches: any of these must be known first
---@field races? integer[] the ChrRaces IDs it is for, when not every race

-- What QuestieDB tells of an NPC: its name in the client's language and one of its spawns.
---@class TFNpcPlace
---@field name string
---@field map? integer UiMapID
---@field x? number fraction across the map, 0-1
---@field y? number fraction down the map, 0-1

---@class TFQuestieSource
---@field Zones fun(): TFQuestieDB?, (fun(area: integer): integer?)?
---@field Places fun(npcs: integer[]): table<integer, TFNpcPlace>, "absent"|"pending"|"ready"

---@class TFClassSpells
---@field lines integer[] its class skill line IDs (spellbook tabs)
---@field spells TFClassSpell[]
---@field trainers integer[] the NPC IDs of the class trainers to visit

-- A spell a hunter pet family can learn: { spell, pet level, training points }. A nil cost is one the client does
-- not carry, and its tooltip omits it.
---@class TFPetFamilySpell
---@field [1] integer
---@field [2] integer
---@field [3] integer?

-- What a hunter pet family can learn, keyed by the client's CreatureFamily ID.
---@class TFPetFamily
---@field lines integer[] its pet SkillLine IDs: the family's own line and the generic pet line
---@field spells TFPetFamilySpell[]

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

-- One floor in the client's own dungeon map art.
---@class TFInteriorMap
---@field wing? string localized through the floor picker
---@field level? integer numbered floor when no wing is named
---@field title string
---@field pattern string texture path before tile number
---@field separator string tile path separator

---@class TFDungeonMaps
---@field Floors fun(art: table?, instance: integer): TFInteriorMap[]
---@field Inside fun(instanceType: string, instance: integer?, playerMap: integer?, shownMap: integer?): integer?
---@field FloorsOf fun(art: table?, instances: integer[]): TFInteriorMap[]
---@field Open fun(uiMapID: integer, instances: integer[]): boolean
---@field Floor fun(count: integer, chosen: integer?): integer

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
---@field items table<integer, true> quest items it asks you to collect
---@field objects table<integer, true> objects it asks you to use

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
---@field Matches fun(id: integer?, kind?: "npc"|"item"|"object"): TFQuestMatch[]
---@field Lines fun(id: integer?, kind?: "npc"|"item"|"object"): [string, number, number, number][]
---@field Starts fun(item: integer?): string?
---@field ObjectId fun(guid: any): integer?
---@field Needed fun(npc: integer?): boolean
---@field HasQuestLines fun(data: TooltipData): boolean

---@class TFDatabase : ForeverFamilyDB
---@field companionHints? boolean the old hint setting, read once to carry a player's "off" over to suggestFamily
---@field junk TFMarks
---@field errors ForeverCaughtError[] the shared error journal (Core/SafeCall.lua): earlier sessions' errors, for the report
---@field log ForeverDebugLogStore the shared log ring (Core/Log.lua): recent lines, for the report
---@field gearMark? 'strip'|'border'|'dots'|'none'
---@field savedSounds? table<string, string>
---@field cameraZoomSaved? string
---@field screenGlowSaved? string
---@field lootSparklesSaved? table<string, string>
---@field lastVersion? string the addon version last logged in with
---@field windowLayouts? table<string, table<string, TFPosition>>
---@field [string] boolean|number|string|TFMarks|table<string, string>|table<string, table<string, TFPosition>>|ForeverCaughtError[]|ForeverDebugLogStore

---@class TFCharacterDatabase
---@field groups TFGroups
---@field colours TFColours
---@field beforeFishing? table<integer, integer>
---@field trainer? table<integer, TFTrainerSpell>
---@field petTrainer? table<integer, TFTrainerSpell>

---@type TFDatabase
TweaksForeverDB = nil
---@type TFCharacterDatabase
TweaksForeverCharDB = nil

-- `addon` may be left out of a `polestar` conflict: ns.Feature fills in "Polestar". An `openmap` conflict is
-- one of OpenMap's world map options and a `naowh` conflict one of Naowh Forever's QoL switches; ns.Feature fills
-- in their addon and title. A `cvar` conflict is one of the game's own settings, a conflict while any CVar in its
-- list is on; its `title` names it to the player and is an L[...] phrase.
---@class TFConflict
---@field addon? string
---@field title? string
---@field when? fun(): boolean?
---@field polestar? string
---@field openmap? string
---@field naowh? string
---@field cvar? string[]

---@class TFFeature
---@field key string
---@field category string
---@field name string
---@field tooltip? string
---@field default boolean|string|number
---@field conflicts? TFConflict[]
---@field options? [string, string][]
---@field slider? { min: number, max: number, step?: number }
---@field parent? string
---@field button? fun()
---@field needs? TFNeed

-- Another addon a feature can't work without: `check` finds it, and `title` names it while it's missing.
---@class TFNeed
---@field title string
---@field check fun(): any

---@class TFClickMode
---@field feature string
---@field label string
---@field tooltip string
---@field cursor string
---@field Apply fun(owner: Button, bag: integer, slot: integer)

---@class TFNamespace
---@field ReportTitle string the localized title shown by the shared report window
---@field ForeverQuests table<integer, true>
---@field QuestLog TFQuestLog
---@field QuestTitle fun(id: integer, title: string): string
---@field L table<string, string> English phrase to this locale's text; a missing one is the phrase itself
---@field db TFDatabase
---@field features TFFeature[]
---@field Overlays table<integer, string>
---@field Gear TFGear
---@field Fishing TFFishing
---@field Frames TFFrames
---@field Tooltips TFTooltips
---@field WhisperInvite TFWhisperInvite
---@field Exploration TFExploration
---@field CombinedBag TFCombinedBag
---@field Sections TFSections
---@field Reagents TFReagents
---@field CampBenefits TFCampBenefit[]
---@field CampBenefitEffects table<string, table<integer, string>>
---@field Camp TFCamp
---@field FutureSpells TFFutureSpells
---@field PetTrainerHint TFPetTrainerHint
---@field BeastTraining TFBeastTraining
---@field TalentReminder TFTalentReminder
---@field ClassSpells table<string, TFClassSpells> by class token
---@field PetFamilies table<integer, TFPetFamily> by CreatureFamily ID
---@field PetFamily fun(): TFPetFamily?
---@field TrainerSpells fun(): table<integer, TFTrainerSpell>
---@field LineName fun(lineID: integer, fallback: string?): string
---@field GeneralName fun(): string
---@field LineResolver fun(): fun(id: integer, name: string?): integer?
---@field KnownSpell fun(id: integer, pet: boolean?): boolean
---@field ZoneRanges table<integer, [number, number]>
---@field ZoneLevels TFZoneLevels
---@field DungeonEntrances table<integer, TFEntrance[]>
---@field InstanceEntrances table<integer, TFDungeonEntrance> by instance Map.ID, before pin clustering
---@field RaidInstances table<integer, boolean>
---@field Entrances TFEntrances
---@field MapCanvas TFMapCanvasModule the views of our own on the maps (Map/MapCanvas.lua)
---@field DungeonMaps TFDungeonMaps
---@field DungeonMapArt table<integer, TFInteriorMap[]>
---@field Art TFArt
---@field QuestGivers TFQuestGivers
---@field QuestProgress TFQuestProgress
---@field QuestieDB fun(): TFQuestieDB?
---@field QuestieSource TFQuestieSource
---@field Print fun(message: string)
---@field FitButton fun(button: Button, width: number)
---@field EscapeCloses fun(frame: Frame)
---@field Navigate fun(uiMapID: integer, x: number, y: number, title: string)
---@field NavigateHint fun(shift: boolean?): string
---@field EntranceHint fun(shift: boolean?): string? the grey line about Shortest Path Forever on a dungeon entrance (Integrations/Companions.lua)
---@field Family ForeverFamilyAPI the shared Forever addons module (UI/ForeverFamily.lua)
---@field WHATS_NEW string
---@field WHATS_NEW_VERSION string
---@field WhatsNew TFWhatsNew
---@field Feature fun(feature: TFFeature)
---@field RefreshConflicts fun()
---@field XPRate TFXPRate
---@field QuestXPBar TFQuestXPBar
---@field QuestButtons TFQuestButtons
---@field Coordinates TFCoordinates
---@field BestReward TFBestReward
---@field SafeCall fun(label: string, fn: function, ...: any): boolean, ... run fn as pcall does, keeping a failure for the report and passing it to the error handler (Core/SafeCall.lua)
---@field RecordError fun(label: string, message: any, stack?: string) keep an error caught some other way for the report
---@field CaughtErrors fun(): ForeverCaughtError[] this session's caught errors, oldest first, as copies
---@field AttachErrorJournal fun(store: table) keep the journal in the saved table, so a /reload keeps it
---@field Log fun(level: string, topic: string, message: any, ...: any) one line in the shared ring (Core/Log.lua)
---@field LogLines fun(count?: integer): string[] the newest log lines, oldest first, as copies (Core/Log.lua)
---@field AttachLog fun(store: table) keep the log ring in the saved table, so a /reload keeps it
---@field DebugCommand fun(argument?: string): boolean `/forever debug`: toggle, pin, off or show (Core/Log.lua)
---@field CutText fun(text: string, limit: integer): string `text` cut to `limit` bytes on a character boundary, ending "..."
---@field Report ForeverReportModule the report window (UI/Report.lua)
---@field ReportLines fun(): string[] Tweaks Forever's own lines in the report (Core/Report.lua)
---@field PolestarOn fun(path: string): boolean
---@field OpenMapOn fun(option: string): boolean
---@field NaowhOn fun(switch: string): boolean
---@field ConflictOf fun(key: string): string?
---@field MissingOf fun(key: string): string?
---@field Active fun(key: string): boolean
---@field SettingVariable fun(key: string): string
---@field OnSettingChanged fun(key: string, fn: function)
---@field On fun(event: WowEvent, fn: function)
---@field Init fun(fn: fun())
---@field BagSize fun(container: ContainerFrameTemplate|ContainerFrameCombinedBags): integer
---@field BagItems fun(container: ContainerFrameTemplate|ContainerFrameCombinedBags): (fun(): integer?, ContainerFrameItemButtonTemplate?)
---@field Readable fun(value: any): any
---@field Usable fun(frame?: Frame): boolean
---@field OnTooltip fun(dataType: Enum.TooltipDataType, getters: table<string, true>, fn: fun(tooltip: GameTooltip, getter: string, ...: any))
---@field ContainerFrames fun(): (fun(): ContainerFrameTemplate|ContainerFrameCombinedBags?)
---@field ForEachBagButton fun(fn: fun(button: ContainerFrameItemButtonTemplate))
---@field HookBagButtons fun(update: fun(button: ContainerFrameItemButtonTemplate), click: fun(button: ContainerFrameItemButtonTemplate, mouseButton: string))
---@field IsBagActionClick fun(): boolean
---@field ClickMode fun(mode: TFClickMode)
