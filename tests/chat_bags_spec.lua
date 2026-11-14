-- Link an item from your bags while typing (Chat/BagLinks.lua): the option off leaves the edit box alone; a `[`
-- and one more typed character list matching bag items, sorted by name and capped at eight; Up/Down and Tab
-- move the selection; Enter completes the line in place and the client's own Enter sends it; a click inserts and
-- leaves the box focused for more typing; Escape is left to the client; the index is rebuilt on
-- BAG_UPDATE_DELAYED, never per keystroke; every row's icon goes through ForeverCore.Art.CooldownIcon.
-- luacheck: ignore 212/self (stub methods mirror the frame API)

local features, handlers, settingHandlers = {}, {}, {}
local db = {}
local shift = false
local sent
local icons = {}
local bagReads = 0
local callbacks = {}
local secured = {}

-- The bags: backpack 0, bag 1 and bag 2. Mithril Bar is in two places and must list once.
local ITEMS = {
	{ bag = 0, slot = 1, id = 3860, name = "Mithril Bar", icon = 134000, quality = 1 },
	{ bag = 0, slot = 2, id = 2772, name = "Mithril Ore", icon = 134001, quality = 2 },
	{ bag = 0, slot = 3, id = 3861, name = "Mithril Casing", icon = 134002, quality = 2 },
	{ bag = 0, slot = 4, id = 2592, name = "Wool Cloth", icon = 134003, quality = 1 },
	{ bag = 1, slot = 1, id = 3860, name = "Mithril Bar", icon = 134000, quality = 1 },
	{ bag = 1, slot = 2, id = 7910, name = "Star Ruby", icon = 134004, quality = 3 },
}
local extra = {}
local SLOTS = { [0] = 4, [1] = 2, [2] = 4, [3] = 0, [4] = 0, [5] = 0 }

local function Link(item)
	return ("|cff9d9d9d|Hitem:%d:0:0:0:0:0:0|h[%s]|h|r"):format(item.id, item.name)
end

local function ItemAt(bag, slot)
	for _, item in ipairs(ITEMS) do
		if item.bag == bag and item.slot == slot then
			return item
		end
	end
	for _, item in ipairs(extra) do
		if item.bag == bag and item.slot == slot then
			return item
		end
	end
end

local function Texture(parent)
	local texture = { parent = parent, shown = true }
	function texture:SetAtlas(atlas)
		self.atlas = atlas
	end
	function texture:SetPoint() end
	function texture:SetSize(width, height)
		self.width, self.height = width, height
	end
	function texture:SetAllPoints() end
	function texture:SetBlendMode(mode)
		self.blend = mode
	end
	function texture:SetAlpha(alpha)
		self.alpha = alpha
	end
	function texture:SetShown(shown)
		self.shown = shown
	end
	function texture:Show()
		self.shown = true
	end
	function texture:Hide()
		self.shown = false
	end
	function texture:IsShown()
		return self.shown == true
	end
	function texture:SetTexture(file)
		self.file = file
	end
	function texture:GetParent()
		return self.parent
	end
	return texture
end

local function FontString(parent)
	local text = { parent = parent, text = "" }
	function text:SetText(value)
		self.text = value or ""
	end
	function text:GetText()
		return self.text
	end
	function text:GetStringWidth()
		return #self.text * 6
	end
	function text:SetTextColor(r, g, b)
		self.r, self.g, self.b = r, g, b
	end
	function text:SetPoint() end
	function text:SetJustifyH() end
	return text
end

local function FrameObject(parent)
	local frame = { parent = parent, scripts = {}, hooks = {}, shown = false, level = 0 }
	function frame:CreateTexture()
		local texture = Texture(self)
		self.textures = self.textures or {}
		self.textures[#self.textures + 1] = texture
		return texture
	end
	function frame:CreateFontString()
		local text = FontString(self)
		self.fontstrings = self.fontstrings or {}
		self.fontstrings[#self.fontstrings + 1] = text
		return text
	end
	function frame:SetFrameLevel(level)
		self.level = level
	end
	function frame:GetFrameLevel()
		return self.level
	end
	function frame:SetClampedToScreen() end
	function frame:EnableMouse() end
	function frame:RegisterForClicks() end
	function frame:SetSize(width, height)
		self.width, self.height = width, height
	end
	function frame:SetHeight(height)
		self.height = height
	end
	function frame:SetPoint() end
	function frame:ClearAllPoints() end
	function frame:SetScript(script, fn)
		self.scripts[script] = fn
	end
	function frame:GetScript(script)
		return self.scripts[script]
	end
	function frame:HookScript(script, fn)
		self.hooks[script] = self.hooks[script] or {}
		self.hooks[script][#self.hooks[script] + 1] = fn
	end
	function frame:Fire(script, ...)
		local fn = self.scripts[script]
		if fn then
			fn(self, ...)
		end
		for _, hook in ipairs(self.hooks[script] or {}) do
			hook(self, ...)
		end
	end
	function frame:Show()
		self.shown = true
	end
	function frame:Hide()
		self.shown = false
	end
	function frame:IsShown()
		return self.shown == true
	end
	return frame
end

local function EditBox(parent)
	local edit = FrameObject(parent)
	edit.text, edit.cursor = "", 0
	function edit:GetText()
		return self.text
	end
	function edit:SetText(text)
		self.text = text or ""
		self.cursor = math.min(self.cursor, #self.text)
		self:Fire("OnTextChanged", false)
	end
	function edit:GetCursorPosition()
		return self.cursor
	end
	function edit:SetCursorPosition(position)
		self.cursor = position
	end
	function edit:SetFocus()
		self.focused = true
		self:Show()
	end
	function edit:ClearFocus()
		self.focused = false
	end
	-- What typing does: put the text and cursor in and tell the listeners the player typed.
	function edit:TypeAt(text, cursor)
		self.text = text
		self.cursor = cursor or #text
		self:Fire("OnTextChanged", true)
	end
	function edit:KeyDown(key)
		self:Fire("OnKeyDown", key)
	end
	return edit
end

local chatFrame = FrameObject(nil)
chatFrame.editBox = EditBox(chatFrame)
chatFrame.editBox:SetFrameLevel(10)

local whisperFrame = FrameObject(nil)
whisperFrame.editBox = EditBox(whisperFrame)
whisperFrame.editBox:SetFrameLevel(10)
whisperFrame.isTemporary = true
whisperFrame.chatType = "WHISPER"
whisperFrame.chatTarget = "THRALL"

local env = setmetatable({
	canaccessvalue = function()
		return true
	end,
	Ambiguate = function(name)
		return (name:gsub("%-.*$", ""))
	end,
	UnitName = function()
		return "Bob"
	end,
	CreateFrame = function(_kind, _, parent)
		return FrameObject(parent)
	end,
	IsShiftKeyDown = function()
		return shift
	end,
	BACKPACK_CONTAINER = 0,
	NUM_BAG_SLOTS = 4,
	NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5,
	C_Container = {
		GetContainerNumSlots = function(bag)
			bagReads = bagReads + 1
			return SLOTS[bag] or 0
		end,
		GetContainerItemInfo = function(bag, slot)
			bagReads = bagReads + 1
			local item = ItemAt(bag, slot)
			if item then
				return { itemID = item.id, iconFileID = item.icon, quality = item.quality, hyperlink = Link(item) }
			end
		end,
		GetContainerItemLink = function(bag, slot)
			local item = ItemAt(bag, slot)
			return item and Link(item) or nil
		end,
	},
	C_Item = {
		GetItemNameByID = function(id)
			for _, item in ipairs(ITEMS) do
				if item.id == id then
					return item.name
				end
			end
			for _, item in ipairs(extra) do
				if item.id == id then
					return item.name
				end
			end
		end,
	},
	ITEM_QUALITY_COLORS = {
		[0] = {
			GetRGB = function()
				return 0.62, 0.62, 0.62
			end,
		},
		[1] = {
			GetRGB = function()
				return 1, 1, 1
			end,
		},
		[2] = {
			GetRGB = function()
				return 0.12, 1, 0
			end,
		},
		[3] = {
			GetRGB = function()
				return 0, 0.44, 0.87
			end,
		},
	},
	NORMAL_FONT_COLOR = {
		GetRGB = function()
			return 1, 0.82, 0
		end,
	},
	ForeverCore = {
		Art = {
			CooldownIcon = function(texture, file, size)
				icons[#icons + 1] = { texture = texture, file = file, size = size }
				return Texture(texture:GetParent())
			end,
		},
	},
	EventRegistry = {
		RegisterCallback = function(_, event, fn)
			callbacks[event] = callbacks[event] or {}
			callbacks[event][#callbacks[event] + 1] = fn
		end,
	},
	ChatFrameUtil = {},
	CHAT_FRAMES = { "ChatFrame1" },
	hooksecurefunc = function(name, fn)
		if type(name) == "string" then
			secured[name] = secured[name] or {}
			secured[name][#secured[name] + 1] = fn
		elseif type(name) == "table" and name.SetTemporaryWindowType then
			name.SetTemporaryWindowType = function(...)
				fn(...)
			end
		end
	end,
	FCF_SetTemporaryWindowType = function(frame, chatType, target)
		for _, fn in ipairs(secured.FCF_SetTemporaryWindowType or {}) do
			fn(frame, chatType, target)
		end
	end,
	GRAY_FONT_COLOR = {
		WrapTextInColorCode = function(_, text)
			return text
		end,
	},
}, { __index = _G })
env._G = env
env.ChatFrame1 = chatFrame
env.ChatFrame7 = whisperFrame

local ns = {
	db = db,
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
	Feature = function(feature)
		features[feature.key] = feature
	end,
	On = function(event, fn)
		handlers[event] = handlers[event] or {}
		handlers[event][#handlers[event] + 1] = fn
	end,
	OnSettingChanged = function(key, fn)
		settingHandlers[key] = fn
	end,
	Init = function(fn)
		fn()
	end,
	Active = function(key)
		return db[key] == true
	end,
	core = {
		SafeCall = function(_, fn, ...)
			return pcall(fn, ...)
		end,
	},
}
function ns.Readable(value)
	if not env.canaccessvalue(value) then
		return nil
	end
	return value
end

for _, path in ipairs({ "Chat/Shared.lua", "Chat/BagLinks.lua" }) do
	setfenv(assert(loadfile(path)), env)("TweaksForever", ns)
end

local function Emit(event, ...)
	for _, fn in ipairs(handlers[event] or {}) do
		fn(...)
	end
end

local function State()
	return ns.ChatBagLinks.State(chatFrame.editBox)
end

local function Names()
	local state = State()
	local names = {}
	for index = 1, #state.results do
		names[index] = state.rows[index].text:GetText()
	end
	return names
end

-- The option is its own feature, in the Chat category and off by default.
local feature = features.chatBagLinks
assert(feature, "the option is declared")
assert(feature.category == "Chat", "the option is in the Chat category")
assert(feature.default == false, "the option starts off")
assert(feature.name == "Link items from your bags", "the option is named")

-- Off: typing `[mith` lists nothing and leaves the edit box exactly as it was.
chatFrame.editBox:TypeAt("say [mith", 9)
assert(not (State() and State().frame:IsShown()), "the list is not shown while the option is off")
assert(chatFrame.editBox:GetText() == "say [mith", "the option off does not change the text")

-- On: the matching bag items, sorted by name then item ID, each item ID once.
db.chatBagLinks = true
ns.ChatBagLinks.Rebuild()
icons = {}
chatFrame.editBox:TypeAt("say [mith", 9)
local state = State()
assert(state and state.frame:IsShown(), "typing [ and letters lists the matches")
assert(#state.results == 3, "three distinct bag items match mith")
local names = Names()
assert(names[1] == "Mithril Bar" and names[2] == "Mithril Casing" and names[3] == "Mithril Ore", "sorted by name")
assert(state.rows[1].highlight:IsShown(), "the first row is selected")
assert(state.rows[1].text.r == 1 and state.rows[1].text.g == 1, "the name takes its quality colour")
assert(state.rows[2].text.g == 1 and state.rows[2].text.r ~= 1, "an uncommon item is green")
assert(#icons == 3, "every shown row goes through ForeverCore.Art.CooldownIcon")
assert(icons[1].file == 134000 and icons[1].size == 14, "the row passes the item's icon and size")

-- While the client's own autocomplete has suggestions for the box, it keeps the keys and this list stays closed.
local clientBox = { shown = false }
env.AutoCompleteBox = {
	IsShown = function()
		return clientBox.shown
	end,
	parent = chatFrame.editBox,
}
clientBox.shown = true
chatFrame.editBox:TypeAt("[mith", 5)
assert(not State().frame:IsShown(), "the client's own autocomplete keeps the box while it shows")
clientBox.shown = false
chatFrame.editBox:TypeAt("[mith", 5)
assert(State().frame:IsShown(), "the list returns once the client's own autocomplete closes")

-- Up and Down move the selection and wrap.
chatFrame.editBox:Fire("OnArrowPressed", "DOWN")
assert(state.rows[2].highlight:IsShown() and not state.rows[1].highlight:IsShown(), "Down moves the selection")
chatFrame.editBox:Fire("OnArrowPressed", "UP")
assert(state.rows[1].highlight:IsShown(), "Up moves it back")
chatFrame.editBox:Fire("OnArrowPressed", "UP")
assert(state.rows[3].highlight:IsShown(), "Up wraps to the last row")

-- Tab and Shift-Tab cycle the same selection through the client's own secure tab hook.
assert(env.ChatEdit_CustomTabPressed(chatFrame.editBox) == true, "Tab is consumed while the list is open")
assert(state.rows[1].highlight:IsShown(), "Tab moves forward")
shift = true
assert(env.ChatEdit_CustomTabPressed(chatFrame.editBox) == true, "Shift-Tab is consumed")
assert(state.rows[3].highlight:IsShown(), "Shift-Tab moves back")
shift = false
assert(env.ChatEdit_CustomTabPressed(FrameObject(nil)) == false, "a closed list lets the client's own Tab run")

-- Enter completes the line in place in OnKeyDown, and the client's own OnEnterPressed then sends the completed line
-- through its normal path. Neither of the client's own key handlers is hooked.
assert(not chatFrame.editBox.hooks.OnEnterPressed, "the client's own OnEnterPressed is not hooked")
assert(not chatFrame.editBox.hooks.OnEscapePressed, "the client's own OnEscapePressed is not hooked")
chatFrame.editBox:TypeAt("WTS [mith thanks", 9)
state = State()
local link = Link(ITEMS[1])
sent = nil
function chatFrame.editBox.scripts.OnEnterPressed(self)
	sent = self:GetText()
	self:SetText("")
	self:Hide()
end
chatFrame.editBox:KeyDown("ENTER")
assert(chatFrame.editBox:GetText() == "WTS " .. link .. " thanks", "Enter puts the link in without clearing the line")
assert(chatFrame.editBox:GetCursorPosition() == 4 + #link, "the cursor sits just after the link")
assert(not state.frame:IsShown(), "the list closes on Enter")
chatFrame.editBox:Fire("OnEnterPressed")
assert(sent == "WTS " .. link .. " thanks", "the client's own send sees the completed line")

-- A click on a row inserts the same way and keeps the box for more typing: only the text and cursor change.
chatFrame.editBox:TypeAt("WTS [mith thanks", 9)
state = State()
local casing = Link(ITEMS[3])
state.rows[2].scripts.OnClick(state.rows[2])
assert(chatFrame.editBox:GetText() == "WTS " .. casing .. " thanks", "a click inserts that row's link")
assert(chatFrame.editBox:GetCursorPosition() == 4 + #casing, "a click puts the cursor after the link")
assert(chatFrame.editBox.focused == true, "a click leaves the box focused so typing carries on")
assert(not state.frame:IsShown(), "a click closes the list")

-- Escape is the client's own: the list leaves the key alone, and closes with the box the client clears and hides.
chatFrame.editBox:TypeAt("WTS [mith thanks", 9)
state = State()
local before = chatFrame.editBox:GetText()
local beforeCursor = chatFrame.editBox:GetCursorPosition()
chatFrame.editBox:KeyDown("ESCAPE")
assert(state.frame:IsShown(), "Escape leaves the list to the client")
assert(chatFrame.editBox:GetText() == before, "Escape does not change the text itself")
assert(chatFrame.editBox:GetCursorPosition() == beforeCursor, "Escape does not move the cursor itself")
function chatFrame.editBox.scripts.OnEscapePressed(self)
	self:SetText("")
	self:Hide()
end
chatFrame.editBox:Fire("OnEscapePressed")
chatFrame.editBox:Fire("OnHide")
assert(chatFrame.editBox:GetText() == "", "the client's own Escape clears the box")
assert(not state.frame:IsShown(), "the list closes with the box")

-- No `[`, a closed `]`, or nothing after the bracket shows nothing.
chatFrame.editBox:TypeAt("no bracket here", 15)
assert(not state.frame:IsShown(), "no [ shows no list")
chatFrame.editBox:TypeAt("[mith]", 6)
assert(not state.frame:IsShown(), "a closed ] shows no list")
chatFrame.editBox:TypeAt("say [", 5)
assert(not state.frame:IsShown(), "the bracket alone shows no list")

-- A space or a `]` typed after no match closes the list, and a match with a space in it stays.
chatFrame.editBox:TypeAt("[mithril bar", 12)
assert(state.frame:IsShown(), "a typed space with a match keeps the list")
chatFrame.editBox:TypeAt("[zzz ", 5)
assert(not state.frame:IsShown(), "a typed space with no match closes the list")

-- The index is rebuilt on BAG_UPDATE_DELAYED, never on a keystroke.
bagReads = 0
chatFrame.editBox:TypeAt("[m", 2)
chatFrame.editBox:TypeAt("[mi", 3)
chatFrame.editBox:TypeAt("[mit", 4)
assert(bagReads == 0, "typing never reads the bags")
Emit("BAG_UPDATE_DELAYED")
assert(bagReads > 0, "the index is rebuilt when the bags change")

-- Eight rows at most, still in name order.
for index = 1, 8 do
	extra[index] = {
		bag = 2,
		slot = 5 + index,
		id = 20000 + index,
		name = ("Mithril Widget %02d"):format(index),
		icon = 135000 + index,
		quality = 1,
	}
end
SLOTS[2] = 13
Emit("BAG_UPDATE_DELAYED")
chatFrame.editBox:TypeAt("[mithril widget", 15)
state = State()
assert(#state.results == 8, "the list is capped at eight rows")
local last = state.rows[8].text:GetText()
assert(last == "Mithril Widget 08", "the eighth row is the eighth name in order")

-- Turning the option off hides the list and leaves the edit box alone.
db.chatBagLinks = false
settingHandlers.chatBagLinks()
chatFrame.editBox:TypeAt("[mith", 5)
assert(not state.frame:IsShown(), "the option off closes and keeps the list closed")
assert(chatFrame.editBox:GetText() == "[mith", "the option off leaves the typed text")
db.chatBagLinks = true
settingHandlers.chatBagLinks()

-- A temporary whisper window's own edit box is hooked through the client's temporary window setup.
env.FCF_SetTemporaryWindowType(whisperFrame, "WHISPER", "THRALL")
whisperFrame.editBox:TypeAt("[mith", 5)
local whisperState = ns.ChatBagLinks.State(whisperFrame.editBox)
assert(whisperState and whisperState.frame:IsShown(), "a temporary whisper window gets the list too")
chatFrame.editBox:TypeAt("[mith", 5)
assert(not whisperState.frame:IsShown(), "opening another box's list closes the first")

-- No ForeverCore.Art: an older core leaves the list closed rather than drawing rows without their icon.
local art = env.ForeverCore.Art
env.ForeverCore.Art = nil
chatFrame.editBox:TypeAt("[mith", 5)
assert(not State().frame:IsShown(), "a core without Art.CooldownIcon leaves the list closed")
env.ForeverCore.Art = art
chatFrame.editBox:TypeAt("[mith", 5)
assert(State().frame:IsShown(), "the list comes back with the helper")

print("chat bags: ok")
