---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

local L = ns.L
local KEY = "chatBagLinks"
local Chat = ns.Chat

ns.Feature({
	key = KEY,
	category = "Chat",
	name = "Link items from your bags",
	tooltip = "Typing [ and part of an item's name in a chat box lists the items in your bags whose name contains "
		.. "what you typed. Up and Down or Tab and Shift-Tab move the selection, Enter puts the item's link in and "
		.. "sends the line, and a click puts it in so you can keep typing. Escape closes the list.",
	default = false,
})

-- No conflict: Prat 3.9.115's modules complete player names and /commands but not bag items, so this runs beside it.

---@class TFChatBagLinks
local Model = {}
ns.ChatBagLinks = Model

-- Eight rows is this option's fixed cap: a short list with no scroll bar, so it stays a glance above the box where
-- the player is typing instead of growing over the conversation as they type more letters.
local MAX_ROWS = 8
local ROW_HEIGHT = 18
local ICON_SIZE = 14
-- The client's dropdown list background keeps its own width padding; the rows start inside it.
local PAD = 6

-- The bags' contents, one row per distinct item ID, rebuilt when the bags change. Never rebuilt on a keystroke:
-- every keypress only scans this list for the typed text.
---@type TFChatBagItem[]
local index = {}

-- A bag's item name, from the client's item table or else from the link's own display text.
---@param id integer
---@param link string
---@return string?
local function Name(id, link)
	local name = ns.Readable(C_Item.GetItemNameByID(id))
	if type(name) == "string" and name ~= "" then
		return name
	end
	name = link:match("%[(.-)%]")
	return type(name) == "string" and name ~= "" and name or nil
end

-- Read every bag the client has equipped, backpack through the reagent bag when the build has one, and keep the
-- first stack of each item ID. Nothing is guessed: an item whose link or name the client cannot state is left out.
function Model.Rebuild()
	local rows, seen = {}, {}
	local first = BACKPACK_CONTAINER or 0
	local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or first
	for bag = first, last do
		local slots = C_Container.GetContainerNumSlots(bag) or 0
		for slot = 1, slots do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local id = info and ns.Readable(info.itemID)
			local link = info and ns.Readable(C_Container.GetContainerItemLink(bag, slot))
			if type(id) == "number" and not seen[id] and type(link) == "string" then
				local name = Name(id, link)
				if name then
					seen[id] = true
					rows[#rows + 1] = {
						id = id,
						name = name,
						lower = name:lower(),
						link = link,
						icon = ns.Readable(info.iconFileID),
						quality = ns.Readable(info.quality),
					}
				end
			end
		end
	end
	-- By name, then by item ID so two items with the same name always list in the same order.
	table.sort(rows, function(a, b)
		if a.lower ~= b.lower then
			return a.lower < b.lower
		end
		return a.id < b.id
	end)
	index = rows
end

-- The items whose name contains `typed`, case-insensitively and as a plain substring, in index order. No scoring:
-- the player typed letters that are in the name or they did not.
---@param typed string
---@return TFChatBagItem[]
function Model.Matches(typed)
	local needle = typed:lower()
	local rows = {}
	for _, item in ipairs(index) do
		if string.find(item.lower, needle, 1, true) then
			rows[#rows + 1] = item
			if #rows == MAX_ROWS then
				break
			end
		end
	end
	return rows
end

-- The last `[` before the cursor and the text after it, when that bracket is still open. A `]` anywhere after it
-- closes it, so the list never reappears inside an item link the player is editing.
---@param editBox EditBox
---@return integer? open
---@return string? typed
local function Context(editBox)
	local text = editBox:GetText()
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local cursor = editBox:GetCursorPosition()
	if type(cursor) ~= "number" or cursor < 1 then
		return nil
	end
	cursor = math.min(cursor, #text)
	local open = text:sub(1, cursor):match(".*()%[")
	if not open or text:find("]", open + 1, true) then
		return nil
	end
	local typed = text:sub(open + 1, cursor)
	if typed == "" then
		return nil
	end
	return open, typed
end

-- The edit box's text with the open bracket and what was typed replaced by the item's real link, and the cursor
-- just after the link. Everything before the bracket and after the cursor stays exactly as it was.
---@param editBox EditBox
---@param open integer
---@param item TFChatBagItem
---@return string text
---@return integer cursor
local function Completed(editBox, open, item)
	local text = editBox:GetText()
	local cursor = math.min(editBox:GetCursorPosition(), #text)
	return text:sub(1, open - 1) .. item.link .. text:sub(cursor + 1), open - 1 + #item.link
end

-- One list frame per chat edit box, made the first time that box needs it and dropped with the box.
---@class TFChatBagList
---@field frame Frame
---@field title FontString
---@field rows TFChatBagRow[]
---@field results TFChatBagItem[]
---@field selected integer

---@type table<EditBox, TFChatBagList>
local lists = setmetatable({}, { __mode = "k" })
-- The box whose list is on screen now, so opening another one closes it.
---@type EditBox?
local showing

---@param quality integer?
---@return number r
---@return number g
---@return number b
local function Quality(quality)
	local colour = ITEM_QUALITY_COLORS[quality or 1]
	if colour and colour.GetRGB then
		local r, g, b = colour:GetRGB()
		return r, g, b
	end
	return 1, 1, 1
end

-- The selected row's highlight, the client's own bag list highlight, and the text in its quality colour.
---@param state TFChatBagList
---@param selected integer
local function Select(state, selected)
	local count = #state.results
	if count == 0 then
		return
	end
	state.selected = ((selected - 1) % count) + 1
	for position, row in ipairs(state.rows) do
		row.highlight:SetShown(position <= count and position == state.selected)
	end
end

---@param state TFChatBagList
---@param delta integer
local function Move(state, delta)
	Select(state, state.selected + delta)
end

---@param editBox EditBox
local function Hide(editBox)
	local state = lists[editBox]
	if not state then
		return
	end
	state.frame:Hide()
	state.results = {}
	if showing == editBox then
		showing = nil
	end
end

---@param editBox EditBox
---@return TFChatBagList
local function List(editBox)
	local state = lists[editBox]
	if state then
		return state
	end
	local frame = CreateFrame("Frame", nil, editBox)
	frame:SetFrameLevel(editBox:GetFrameLevel() + 5)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:Hide()

	-- The client's own dropdown list background, drawn whole its menu draws it (Blizzard_Menu/MenuTemplates.lua).
	local background = frame:CreateTexture(nil, "BACKGROUND")
	-- art-ok: the client's menu list background, drawn whole at a menu's own offsets
	background:SetAtlas("common-dropdown-bg")
	background:SetPoint("TOPLEFT", -10, 3)
	background:SetPoint("BOTTOMRIGHT", 10, -3)
	background:SetAlpha(0.925)

	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	title:SetText(L["In your bags"])
	local r, g, b = NORMAL_FONT_COLOR:GetRGB()
	title:SetTextColor(r, g, b)
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -8)

	local rows = {}
	for position = 1, MAX_ROWS do
		local row = CreateFrame("Button", nil, frame)
		row:SetHeight(ROW_HEIGHT)
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -24 - (position - 1) * ROW_HEIGHT)
		row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -24 - (position - 1) * ROW_HEIGHT)
		row:RegisterForClicks("LeftButtonUp")
		row:Hide()

		row.highlight = row:CreateTexture(nil, "BACKGROUND")
		-- art-ok: the client's own bag list selection highlight over a list row
		row.highlight:SetAtlas("bags-roundhighlight")
		row.highlight:SetBlendMode("ADD")
		row.highlight:SetAllPoints()
		row.highlight:Hide()

		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(ICON_SIZE, ICON_SIZE)
		row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)

		row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		row.text:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
		row.text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
		row.text:SetJustifyH("LEFT")

		row:SetScript("OnClick", function()
			local clickState = lists[editBox]
			local item = clickState and clickState.results[position]
			if item then
				Model.Complete(editBox, item)
			end
		end)
		rows[position] = row
	end

	state = { frame = frame, title = title, rows = rows, results = {}, selected = 1 }
	lists[editBox] = state
	return state
end

-- Draw the list of matches above the edit box. The icon frame is ForeverCore's, which arrived in core 1.9.0: on an
-- older core the list stays closed rather than showing rows without the icon this option promises.
---@param editBox EditBox
---@param results TFChatBagItem[]
local function Draw(editBox, results)
	local art = ForeverCore and ForeverCore.Art
	if not (type(art) == "table" and type(art.CooldownIcon) == "function") then
		Hide(editBox)
		return
	end
	local state = List(editBox)
	if showing and showing ~= editBox then
		Hide(showing)
	end
	state.results = results
	showing = editBox

	local width = state.title:GetStringWidth() + PAD * 2
	for position, item in ipairs(results) do
		local row = state.rows[position]
		row.item = item
		row.text:SetText(item.name)
		local r, g, b = Quality(item.quality)
		row.text:SetTextColor(r, g, b)
		if item.icon then
			art.CooldownIcon(row.icon, item.icon, ICON_SIZE)
		else
			row.icon:SetTexture(nil) -- art-ok: clearing the icon when the item has none
		end
		width = math.max(width, ICON_SIZE + 5 + row.text:GetStringWidth() + PAD * 2)
		row:Show()
	end
	for position = #results + 1, MAX_ROWS do
		state.rows[position]:Hide()
		state.rows[position].highlight:Hide()
	end

	state.frame:ClearAllPoints()
	state.frame:SetFrameLevel(editBox:GetFrameLevel() + 5)
	state.frame:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 0, 3)
	state.frame:SetSize(math.max(160, width), 24 + #results * ROW_HEIGHT + 6)
	Select(state, 1)
	state.frame:Show()
end

-- Replace the open bracket and what was typed with the item's link, leaving the rest of the line as it was. A click
-- and Enter both come through here; the click leaves the box focused so the player can keep typing.
---@param editBox EditBox
---@param item TFChatBagItem
function Model.Complete(editBox, item)
	local open = Context(editBox)
	if not open then
		Hide(editBox)
		return
	end
	local text, cursor = Completed(editBox, open, item)
	Hide(editBox)
	editBox:SetText(text)
	editBox:SetCursorPosition(cursor)
	editBox:SetFocus()
end

-- The list as it shows for a box, for the spec and for the setting switch.
---@param editBox EditBox
---@return TFChatBagList?
function Model.State(editBox)
	return lists[editBox]
end

-- A keystroke or a programmatic text change. Only what the player typed opens a list; text set by this addon or by
-- the client is read for closing, never for showing. While the client's own autocomplete has suggestions for the
-- same box (a /command target), it keeps the box: two lists over one edit box would fight for the same keys.
---@param editBox EditBox
---@param userInput boolean?
local function Changed(editBox, userInput)
	if not ns.Active(KEY) then
		Hide(editBox)
		return
	end
	if not userInput then
		return
	end
	if AutoCompleteBox and AutoCompleteBox:IsShown() and AutoCompleteBox.parent == editBox then
		Hide(editBox)
		return
	end
	local _, typed = Context(editBox)
	local results = typed and Model.Matches(typed) or {}
	if #results == 0 then
		Hide(editBox)
		return
	end
	Draw(editBox, results)
end

-- Enter with the list open puts the selected item's link in and leaves the line in the box. OnKeyDown runs before the
-- client's own OnEnterPressed, which then sends the completed line through its normal path: the client still owns the
-- send, the chat type and the box's deactivation, and this addon never replaces or hooks that handler.
---@param editBox EditBox
local function Enter(editBox)
	local state = lists[editBox]
	local item = state and state.results[state.selected]
	if item then
		Model.Complete(editBox, item)
	else
		Hide(editBox)
	end
end

-- Chat edit boxes, including the client's temporary whisper windows, are all made from ChatFrameEditBoxTemplate
-- with ChatFrameEditBoxMixin. Rather than guess their names, react to the client's own edit box events: the mixin
-- fires ChatFrame.OnEditBoxShow as one opens, and FCF_SetTemporaryWindowType as a whisper window is set up.
-- [editBox] = true once its scripts are hooked.
---@type table<EditBox, boolean>
local hooked = setmetatable({}, { __mode = "k" })

---@param editBox EditBox?
local function Hook(editBox)
	if not (editBox and editBox.HookScript and not hooked[editBox]) then
		return
	end
	hooked[editBox] = true
	editBox:HookScript("OnTextChanged", function(self, userInput)
		ns.core.SafeCall("bag links", Changed, self, userInput)
	end)
	-- OnArrowPressed is the script the client's own AutoComplete template uses for Up and Down, so it is the
	-- client's own key route and no script of its is replaced. Its handler does nothing while its box is closed.
	editBox:HookScript("OnArrowPressed", function(self, key)
		local state = lists[self]
		if not (state and state.frame:IsShown()) then
			return
		end
		ns.core.SafeCall("bag links", function()
			if key == "UP" then
				Move(state, -1)
			elseif key == "DOWN" then
				Move(state, 1)
			end
		end)
	end)
	-- OnKeyDown runs before OnEnterPressed (Blizzard_AutoComplete and the client's edit box mixin), which is the
	-- only place an addon can put the completed line in before the client's own handler sends it. Escape is left
	-- entirely to the client, and the list closes with the box through OnHide.
	editBox:HookScript("OnKeyDown", function(self, key)
		local state = lists[self]
		if not (state and state.frame:IsShown()) then
			return
		end
		if key == "ENTER" or key == "NUMPADENTER" then
			ns.core.SafeCall("bag links", Enter, self)
		end
	end)
	editBox:HookScript("OnHide", function(self)
		Hide(self)
	end)
end

-- Tab and Shift-Tab cycle the list. ChatFrameEditBoxMixin:OnTabPressed calls ChatEdit_CustomTabPressed through
-- securecall after its own AutoComplete, and the client leaves that global as the hook point for addons. It is
-- chained, never dropped, so the previous handler still runs whenever this list is closed.
local previousTab = ChatEdit_CustomTabPressed
function ChatEdit_CustomTabPressed(editBox)
	local state = lists[editBox]
	if state and state.frame:IsShown() then
		Move(state, IsShiftKeyDown() and -1 or 1)
		return true
	end
	if previousTab then
		return previousTab(editBox)
	end
	return false
end

ns.On("BAG_UPDATE_DELAYED", function()
	if ns.Active(KEY) then
		Model.Rebuild()
	end
end)

ns.OnSettingChanged(KEY, function()
	if ns.Active(KEY) then
		Model.Rebuild()
	elseif showing then
		Hide(showing)
	end
end)

ns.Init(function()
	Model.Rebuild()
	for _, frame in ipairs(Chat.Frames()) do
		Hook(frame.editBox)
	end
	Chat.OnWhisperWindow(function(frame)
		Hook(frame.editBox)
	end)
	if EventRegistry and EventRegistry.RegisterCallback then
		local watcher = CreateFrame("Frame")
		EventRegistry:RegisterCallback("ChatFrame.OnEditBoxShow", function(_, editBox)
			Hook(editBox)
		end, watcher)
	end
end)
