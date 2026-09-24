---@meta

-- These integrations belong to other addons, so their tables are absent until those addons load.
---@type table<string, string>?
LeaPlusDB = nil
---@type table<string, string>?
LeaMapsDB = nil
---@type {showAreas: boolean?}?
LegacyForeverDB = nil
---@type {db: {profile: {autoaccept: boolean?, autocomplete: boolean?, trackerEnabled: boolean?}?}?}?
Questie = nil

-- QuestieDB's public API (contract 2), only the parts QuestGivers.lua reads. Entity reads return packed values.
---@class TFQuestieEntity
---@field GetAll fun(id: integer, keys: string[]): table?
---@field IdsByName fun(name: string): integer[]?
---@field BuildNameIndex fun()

---@class TFQuestieDB
---@field RequireContract fun(required: integer): boolean, string?
---@field Npc TFQuestieEntity
---@field Quest TFQuestieEntity
---@field Support {Get: fun(name: string): table?}

---@type TFQuestieDB?
LibQuestieDB = nil

-- Shortest Path Forever's public API, narrowed to what Navigate.lua calls; each member is feature-detected.
---@class TFShortestPathAPI
---@field version? integer
---@field Navigate? fun(owner: string, map: integer, x: number, y: number, title?: string): boolean
---@type {API: TFShortestPathAPI?}?
ShortestPathForever = nil

-- Camelot's character panel dimensions and panel-manager accessor are absent from Retail FrameXML.
---@type number
CHARACTER_FRAME_COLLAPSED_WIDTH = 0
---@type number
CHARACTER_FRAME_WIDTH = 0
---@type number
CHARACTER_FRAME_HEIGHT = 0
---@param attribute 'TOP_OFFSET'|'LEFT_OFFSET'
---@return number
function GetUIPanelLayoutAttribute(attribute) end

-- Localised client strings are not included in Ketho's API annotations.
---@type string
ERR_NOT_IN_COMBAT = ""
---@type string
SELL_ALL_JUNK_ITEMS_POPUP = ""
---@type string
FACTION_ALLIANCE = ""
---@type string
FACTION_HORDE = ""

-- Camelot's pane toggle is a mixin method; Retail's generated CharacterFrame omits it.
---@class CharacterFrame
---@field IsRightPaneCollapsed fun(self: CharacterFrame): boolean

-- PanelTemplates sets this in Lua, which the generated XML-only class does not capture.
---@class MerchantFrame
---@field selectedTab integer

-- A bag's children include both item buttons and ordinary window controls.
---@class TFBagChild : Frame
---@field GetSlotAndBagID? fun(self: TFBagChild): integer, integer

-- Forever's TrainerDocumentation/TrainerConstantsDocumentation; absent from the pinned Retail API.
C_Trainer = {}
---@enum Enum.TrainerType
Enum.TrainerType = { General = 0, TalentsObsolete = 1, Tradeskills = 2, Pet = 3 }
---@return Enum.TrainerType
function C_Trainer.GetTrainerType() end

-- Forever's trainer rows include texture, required level and subtext (rank), as its TrainerUI consumes them.
---@param index integer
---@return string? name
---@return string kind
---@return fileID icon
---@return number? level
---@return string? rank
---@diagnostic disable-next-line: duplicate-set-field -- Replace the pinned legacy four-return signature.
function GetTrainerServiceInfo(index) end

-- Spell and trainer tooltips carry the spell ID; the pinned TooltipData structure omits it.
---@class TooltipData
---@field id? integer

-- Only ShoppingTooltipTemplate supplies this child; ordinary tooltip frames have no comparison header.
---@class GameTooltip
---@field CompareHeader? ShoppingTooltipTemplate_CompareHeader

-- Blizzard_NamePlates' unit frame (BaseNamePlateUnitFrameTemplate) is absent from the generated FrameXML
-- annotations; only the parts Nameplates.lua restyles are declared.
---@class NamePlateHealthBar : StatusBar
---@field barTexture Texture
---@field bgTexture Texture
---@field selectedBorder Texture
---@field deselectedOverlay Texture
---@field Text FontString
---@field LeftText FontString
---@field RightText FontString
---@field IsTarget fun(self: NamePlateHealthBar): boolean?

---@class NamePlateCastBar : StatusBar
---@field Icon Texture
---@field Spark Texture
---@field Text FontString

---@class NamePlateLevelFrame : Frame
---@field playerLevelDiffIcon Texture
---@field selectedBorder Texture?

---@class NamePlateUnitFrame : Button
---@field HealthBarsContainer Frame|{healthBar: NamePlateHealthBar}
---@field CastBarsContainer Frame|{castBar: NamePlateCastBar}
---@field PlayerLevelDiffFrame NamePlateLevelFrame
---@field LevelFrame Frame
---@field name FontString
---@field unit UnitToken?
---@field widgetsOnlyMode boolean?
---@field IsShowOnlyName fun(self: NamePlateUnitFrame): boolean

---@class NamePlateFrame
---@field UnitFrame NamePlateUnitFrame?

-- Our future-spell entries borrow the spellbook item template and keep their own state on it.
---@class SpellBookItemTemplate
---@field entry TFFutureSpell
---@field trainableFXController? {CancelEffect: fun(self)}
---@field ApplyBorderArt fun(self, atlas: string, anchors: AnchorMixin[]) Camelot's; newer than the pinned FrameXML

-- PagedContentFrame's split of its elements into views, set in Lua and read for where the last view ends.
---@class TFPagedElement
---@field gridRow? integer
---@field isHeader? boolean
---@field isSpacer? boolean

---@class SpellBookFrameTemplate_PagedSpellsFrame
---@field viewDataList? TFPagedElement[][]

---@class SpellBookSingleSkillLineCategoryMixin
---@field skillLineIndex? Enum.SpellBookSkillLineIndex

-- Retail spellbook strings, absent from Ketho's annotations.
---@type string
SPELLBOOK_TRAINABLE = ""
---@type string
SPELLBOOK_AVAILABLE_AT = ""
---@type string
GENERAL = ""
---@type string
PAGE_NUMBER_WITH_MAX = ""
---@type string
COSTS_LABEL = ""
