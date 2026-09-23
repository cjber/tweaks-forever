---@meta

---@alias TFAnchor [FramePoint, ScriptRegion?, FramePoint, number, number]

---@class TFWindowPreview : Frame
---@field Selection EditModeSystemSelectionTemplate

---@class TFScaleDialog : Frame
---@field Title FontString
---@field Value FontString
---@field Slider MinimalSliderWithSteppersTemplate
---@field initializing boolean

---@class TFTabFrame : Frame
---@field Tabs PanelTabButtonTemplate[]

-- Frame, scale and anchors arrive together in Attach; editor controls arrive in BuildEditor/MakePreview.
---@class TFWindowRecord
---@field name string
---@field label string
---@field addon? string
---@field frame? Frame
---@field scale number
---@field points TFAnchor[]
---@field preview? TFWindowPreview
---@field checkbox? EditModeCheckButtonTemplate
---@field applied? boolean
---@field applying? boolean
---@field dragging? boolean

---@class TFQuestBlock : ObjectiveTrackerBlockTemplate
---@field id integer
---@field rightEdgeOffset? number

---@class TFQuestDecor
---@field label FontString
---@field glow Texture

---@class TFSectionItem
---@field button ContainerFrameItemButtonTemplate
---@field section? string

---@class TFSectionPlace
---@field column integer
---@field y number

---@class TFSectionHeading
---@field section string
---@field y number

---@class TFOverlay
---@field x number
---@field y number
---@field width number
---@field height number
---@field files integer[]
---@field key string

---@class TFOverlayTile
---@field x number
---@field y number
---@field width number
---@field height number
---@field u number
---@field v number

---@class TFClickOverlay : Button
---@field UpdateTooltip fun(overlay: TFClickOverlay)
---@field GetParent fun(self: TFClickOverlay): ContainerFrameItemButtonTemplate
