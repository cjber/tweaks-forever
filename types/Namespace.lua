---@meta

---@alias TFMarks table<integer, boolean>
---@alias TFGroups table<string, TFMarks>
---@alias TFColour [number, number, number]
---@alias TFColours table<string, table<string|integer, TFColour>>
---@alias TFCampBenefit [integer, string, string, number?]

---@class TFCampRow
---@field benefit TFCampBenefit
---@field left? number

---@class TFCamp
---@field Listing fun(remaining: fun(aura: integer): number?): TFCampRow[]
---@field Touches fun(info: UnitAuraUpdateInfo, instances: TFMarks): boolean

---@class TFTrainerSpell
---@field name string
---@field rank? string
---@field level number
---@field icon fileID

---@class TFTrainerGroup
---@field level number
---@field [integer] TFTrainerSpell

---@class TFPosition
---@field x number
---@field y number
---@field scale number

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
---@field Trainable TFTrainable
---@field ZoneRanges table<integer, [number, number]>
---@field ZoneLevels TFZoneLevels
---@field Print fun(message: string)
---@field Feature fun(feature: TFFeature)
---@field RefreshConflicts fun()
---@field ConflictOf fun(key: string): string?
---@field Active fun(key: string): boolean
---@field On fun(event: WowEvent, fn: function)
---@field Init fun(fn: fun())
---@field ForEachBagButton fun(fn: fun(button: ContainerFrameItemButtonTemplate))
---@field HookBagButtons fun(hooked: table<ContainerFrameItemButtonTemplate, boolean>, update: fun(button: ContainerFrameItemButtonTemplate), click: fun(button: ContainerFrameItemButtonTemplate, mouseButton: string))
---@field IsBagActionClick fun(): boolean
---@field ClickMode fun(mode: TFClickMode)
