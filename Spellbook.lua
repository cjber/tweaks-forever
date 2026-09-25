---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "trainableSpells",
	category = "Interface",
	name = "Show future spells in the spellbook",
	tooltip = "Spells you have not learned yet appear greyed out after the ones you know, as the Retail spellbook "
		.. "shows them: what your trainer can teach you now, and each spell's next rank with the level it comes at. "
		.. "Visiting your trainer brings the list and its prices up to date.",
	default = true,
})

---@class TFFutureSpells
local Model = {}
ns.FutureSpells = Model

-- The trainer rows worth keeping: ones you can learn now and ones your level does not allow yet. "used" is learned.
local KEEP = { available = true, unavailable = true }
-- Retail's glow on a spellbook entry waiting at the trainer (TRAINABLE_FX_ID in Blizzard_SpellBookItem.lua).
local TRAINABLE_FX = 176
-- The General tab has no skill line of its own: a spell on a line that isn't a class line (Dual Wield, Defense,
-- armour, Lockpicking) is listed there. SkillLine IDs start at 1, so this stands for it among them.
Model.GENERAL = 0

---@param a TFFutureSpell
---@param b TFFutureSpell
local function InOrder(a, b)
	if a.ready ~= b.ready then
		return a.ready
	end
	if a.spell.level ~= b.spell.level then
		return a.spell.level < b.spell.level
	end
	return a.spell.name < b.spell.name
end

-- A tab's unlearned spells, or every tab's with no line: the lowest unlearned rank of each, those your trainer
-- teaches now first, then by level. A row on no skill line of the class (weapons, riding) is never listed.
---@param spells table<integer, TFTrainerSpell>
---@param lineID integer? the tab's SkillLine ID, or GENERAL
---@param level number
---@param Skip fun(id: integer): boolean? known, or hidden by the spellbook's filter
---@return TFFutureSpell[]
function Model.Choose(spells, lineID, level, Skip)
	---@type table<string, TFFutureSpell>
	local byName = {}
	for id, spell in pairs(spells) do
		local held = byName[spell.name]
		if
			spell.lineID
			and (not lineID or (spell.general and Model.GENERAL or spell.lineID) == lineID)
			and not Skip(id)
			and (not held or spell.level < held.spell.level)
		then
			byName[spell.name] = { id = id, spell = spell, ready = spell.level <= level }
		end
	end
	local chosen = {}
	for _, entry in pairs(byName) do
		chosen[#chosen + 1] = entry
	end
	table.sort(chosen, InOrder)
	return chosen
end

---@param ids integer[]?
---@param Known fun(id: integer): boolean
local function AnyKnown(ids, Known)
	if not ids then
		return true
	end
	for _, id in ipairs(ids) do
		if Known(id) then
			return true
		end
	end
	return false
end

-- What your class trainer teaches: your class's baked list, less other races' spells and ranks whose untrained
-- earlier rank you lack, with the rows a trainer visit recorded laid over it, as the server has the last word on
-- level and fee. A baked spell the client can't describe is left out, never guessed at; one on a line that is not
-- a class line goes on the General tab.
---@param baked TFClassSpells?
---@param live table<integer, TFTrainerSpell>?
---@param race integer
---@param Describe fun(id: integer): TFSpellFacts?
---@param Known fun(id: integer): boolean
---@return table<integer, TFTrainerSpell>
function Model.Spells(baked, live, race, Describe, Known)
	---@type table<integer, TFTrainerSpell>
	local spells = {}
	local lines = baked and baked.lines or {}
	for _, row in ipairs(baked and baked.spells or {}) do
		local facts = (not row.races or tContains(row.races, race)) and AnyKnown(row.needs, Known) and Describe(row[1])
		if facts then
			spells[row[1]] = {
				name = facts.name,
				rank = facts.rank,
				icon = facts.icon,
				level = row[2],
				cost = row[3],
				lineID = row[4],
				general = not tContains(lines, row[4]) or nil,
			}
		end
	end
	for id, spell in pairs(live or {}) do
		spells[id] = spell
	end
	return spells
end

-- The class skill line on each spellbook tab, by tab index. A tab tells only its name, in the client's language,
-- so each baked line's ID is asked for its tab instead of names being compared: the same answer in every locale.
---@param lineIDs integer[]
---@param IndexOf fun(lineID: integer): integer?
---@return table<integer, integer> tab index -> SkillLine ID
function Model.Tabs(lineIDs, IndexOf)
	local tabs = {}
	for _, lineID in ipairs(lineIDs) do
		local index = IndexOf(lineID)
		if index then
			tabs[index] = lineID
		end
	end
	return tabs
end

-- Saves from before lines were kept by ID hold only the trainer's name for one: give each row its ID, and drop the
-- rows that have none (weapon and riding rows, which no class tab shows; a spell the next visit records again).
---@param saved table<integer, TFTrainerSpell>
---@param Resolve fun(id: integer, name: string?): integer?
function Model.Migrate(saved, Resolve)
	for id, spell in pairs(saved) do
		if type(spell) ~= "table" then
			saved[id] = nil
		elseif spell.lineID == nil then
			spell.lineID = Resolve(id, spell.line)
			if not spell.lineID then
				saved[id] = nil
			end
		end
	end
end

-- How far down a view our entries may reach: its foot, or the top of the pager where the pager covers it (the stock
-- pager sits over the foot of the last view). Tops are screen offsets, as GetTop gives them; nil before layout.
---@param height number the view's height
---@param top number? the view's top
---@param pagerTop number? the pager's top
---@return number
function Model.Room(height, top, pagerTop)
	if top and pagerTop then
		return math.min(height, top - pagerTop)
	end
	return height
end

-- Places a header and count entries after the spellbook's own, with its column-first grid rules: a spacer before a
-- group on a view already holding one, a header only with room for a row under it, and each view's rows balanced
-- over the columns. Page 0 is the spellbook's last page; views past it are ours.
---@param count integer
---@param view integer where the spellbook's content ends
---@param used number height the spellbook fills on that view
---@param grid TFGrid
---@return TFSlot header
---@return TFSlot[] slots
function Model.Layout(count, view, used, grid)
	local page, y = 0, used
	local row = grid.item + grid.pad
	local function NextView()
		view, y = view + 1, 0
		if view > grid.views then
			page, view = page + 1, 1
		end
	end
	if y > 0 then
		y = y + grid.spacer + grid.pad
	end
	if y + grid.header + grid.pad + row > grid.height then
		NextView()
	end
	local header = { page = page, view = view, x = 0, y = y }
	y = y + grid.header + grid.pad
	local width = (grid.width - grid.gap * (grid.columns - 1)) / grid.columns
	local slots = {}
	while #slots < count do
		local rows = math.floor((grid.height - y) / row)
		if rows < 1 then
			NextView()
			rows = math.floor(grid.height / row)
		end
		rows = math.min(rows, math.ceil((count - #slots) / grid.columns))
		for i = 0, math.min(count - #slots, rows * grid.columns) - 1 do
			local column = math.floor(i / rows)
			slots[#slots + 1] = {
				page = page,
				view = view,
				x = column * (width + grid.gap),
				y = y + (i % rows) * row,
			}
		end
		if #slots < count then
			NextView()
		end
	end
	return header, slots
end

-- Our own frames beside Blizzard's paged grid: its data provider and pager are never written to, so the
-- spellbook's own entries stay untainted for casting and dragging.
---@type Frame, Frame, SpellBookHeaderTemplate, FontString, Button, Button
local layer, blocker, header, pageText, prev, nextPage
---@type SpellBookItemTemplate[]
local items = {}
local extra, extraPages, lastDisplay = 0, 0, 0

---@param id integer
---@return TFSpellFacts?
local function Describe(id)
	local info = C_Spell.GetSpellInfo(id)
	if info then
		local rank = C_Spell.GetSpellSubtext(id)
		return { name = info.name, icon = info.iconID, rank = rank ~= "" and rank or nil }
	end
end

---@param id integer
---@return boolean
function ns.KnownSpell(id)
	return C_SpellBook.IsSpellKnown(id)
end

---@return TFClassSpells?
local function ClassData()
	local _, class = UnitClass("player")
	return ns.ClassSpells[class]
end

-- Everything your class trainer teaches, as far as the baked list and your trainer visits know.
---@return table<integer, TFTrainerSpell>
function ns.TrainerSpells()
	local live = TweaksForeverCharDB and TweaksForeverCharDB.trainer
	return Model.Spells(ClassData(), live, (select(3, UnitRace("player"))), Describe, ns.KnownSpell)
end

---@return table<integer, integer> tab index -> SkillLine ID
local function Tabs()
	local data = ClassData()
	return Model.Tabs(data and data.lines or {}, C_SpellBook.GetSkillLineIndexByID)
end

-- A class skill line's name in the client's language: its spellbook tab's, else the trainer's, else the client's.
---@param lineID integer
---@param fallback string? the name a trainer gave it
---@return string
function ns.LineName(lineID, fallback)
	local index = C_SpellBook.GetSkillLineIndexByID(lineID)
	local info = index and C_SpellBook.GetSpellBookSkillLineInfo(index)
	return info and info.name or fallback or C_TradeSkillUI.GetTradeSkillDisplayName(lineID)
end

-- The General tab's name in the client's language.
---@return string
function ns.GeneralName()
	local info = C_SpellBook.GetSpellBookSkillLineInfo(Enum.SpellBookSkillLineIndex.General)
	return info and info.name or GENERAL
end

-- Whether a trainer row's line puts it on the General tab: it is none of the class's lines.
---@param lineID integer
---@return true?
function ns.OnGeneral(lineID)
	local data = ClassData()
	return not (data and tContains(data.lines, lineID)) or nil
end

-- Finds a spell's skill line ID: the baked row's (a General tab row's own line), else the class tab the trainer
-- names. The trainer names it in the client's language, as the tab does, so the two match in every locale; weapon
-- and riding lines don't.
---@return fun(id: integer, name: string?): integer?
function ns.LineResolver()
	local data = ClassData()
	local byID, byName = {}, {}
	for _, row in ipairs(data and data.spells or {}) do
		byID[row[1]] = row[4]
	end
	for index, lineID in pairs(Tabs()) do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(index)
		if info then
			byName[info.name] = lineID
		end
	end
	return function(id, name)
		return byID[id] or name and byName[name]
	end
end

local function Book()
	return PlayerSpellsFrame.SpellBookFrame
end

-- The class skill line ID on show, GENERAL on the General tab, or nil on the pet and outfit tabs and in search
-- results.
---@return integer?
local function ActiveLine()
	local book = Book()
	if book:IsInSearchResultsMode() then
		return nil
	end
	local category = book:GetActiveCategoryMixin()
	local index = category and category.skillLineIndex
	if index == Enum.SpellBookSkillLineIndex.General then
		return Model.GENERAL
	end
	return index and Tabs()[index]
end

-- Where the spellbook's last view ends, read from its split data so it holds on any page.
---@return integer view, number used, integer pages
local function BlizzardEnd(paged, item, heading)
	local views = paged.viewDataList or {}
	local last = views[#views] or {}
	local heights = {}
	for _, element in ipairs(last) do
		local height = element.isSpacer and paged.spacerSize or element.isHeader and heading or item
		heights[element.gridRow or 1] = height + paged.yPadding
	end
	local used = 0
	for _, height in pairs(heights) do
		used = used + height
	end
	local view = (math.max(#views, 1) - 1) % paged.viewsPerPage + 1
	return view, used, paged.PagingControls:GetMaxPages()
end

local function Uncover(paged)
	for _, view in ipairs(paged.ViewFrames) do
		view:SetAlpha(1)
	end
	paged.PagingControls.PageText:SetAlpha(1)
	blocker:Hide()
end

---@param item SpellBookItemTemplate
local function Release(item)
	if item.trainableFXController then
		item.trainableFXController:CancelEffect()
		item.trainableFXController = nil
	end
end

---@param item SpellBookItemTemplate
---@param entry TFFutureSpell
local function Paint(item, entry)
	local spell, button, text = entry.spell, item.Button, item.TextContainer
	local art = C_Spell.IsSpellPassive(entry.id) and SpellBookItemMixin.ArtSet.Circle
		or SpellBookItemMixin.ArtSet.Square
	item.entry = entry
	text.Name:SetText(spell.name)
	text.SubName:SetText(spell.rank or "")
	text.RequiredLevel:SetText(entry.ready and SPELLBOOK_TRAINABLE or SPELLBOOK_AVAILABLE_AT:format(spell.level))
	text.RequiredLevel:Show()
	for _, label in ipairs({ text.Name, text.SubName, text.RequiredLevel }) do
		label:SetAlpha(item.unlearnedTextAlpha)
	end
	button.Icon:SetTexture(spell.icon)
	button.Icon:SetDesaturated(true)
	button.Icon:SetVertexColor(SPELLBOOK_UNLEARNED_TINT_COLOR:GetRGB())
	button.Icon:SetAlpha(item.unlearnedIconAlpha)
	button.IconMask:SetAtlas(art.iconMask, TextureKitConstants.IgnoreAtlasSize)
	button.IconMask:Show()
	button.TrainableBackplate:SetAtlas(art.trainableBackplate, TextureKitConstants.IgnoreAtlasSize)
	button.TrainableBackplate:SetShown(entry.ready)
	button.TrainableShadow:SetShown(entry.ready)
	item:ApplyBorderArt(art.inactiveBorder, art.inactiveBorderAnchors)
	item:UpdateTextContainer()
	if entry.ready then
		item.trainableFXController = button.FxModelScene:AddEffect(TRAINABLE_FX, button, button)
	end
end

local function ShowTooltip(button)
	local entry = button:GetParent().entry
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:SetSpellByID(entry.id)
	if entry.ready then
		GameTooltip_AddColoredLine(GameTooltip, SPELLBOOK_TRAINABLE, GREEN_FONT_COLOR)
	else
		GameTooltip_AddErrorLine(GameTooltip, SPELLBOOK_AVAILABLE_AT:format(entry.spell.level))
	end
	if entry.spell.cost and entry.spell.cost > 0 then
		SetTooltipMoney(GameTooltip, entry.spell.cost, nil, COSTS_LABEL)
	end
	GameTooltip:Show()
end

local function LinkInChat(button)
	if IsModifiedClick("CHATLINK") then
		ChatFrameUtil.InsertLink(C_Spell.GetSpellLink(button:GetParent().entry.id))
	end
end

---@param i integer
---@return SpellBookItemTemplate
local function Item(i)
	local item = items[i]
	if not item then
		item = CreateFrame("Frame", nil, layer, "SpellBookItemTemplate") --[[@as SpellBookItemTemplate]]
		item:SetFrameLevel(layer:GetFrameLevel() + 2)
		item.Button:HookScript("OnEnter", ShowTooltip)
		item.Button:HookScript("OnLeave", GameTooltip_Hide)
		item.Button:HookScript("OnClick", LinkInChat)
		items[i] = item
	end
	return item
end

local function Render()
	local book = Book()
	local paged = book.PagedSpellsFrame
	for _, item in ipairs(items) do
		Release(item)
		item:Hide()
	end
	header:Hide()
	local line = ns.Active("trainableSpells") and ActiveLine()
	local chosen = line
			and Model.Choose(ns.TrainerSpells(), line, UnitLevel("player"), function(id)
				return ns.KnownSpell(id) or (GetCVarBool("spellBookHidePassives") and C_Spell.IsSpellPassive(id))
			end)
		or {}
	if #chosen == 0 then
		extra, extraPages = 0, 0
		Uncover(paged)
		pageText:Hide()
		prev:Hide()
		nextPage:Hide()
		return
	end

	local itemHeight = C_XMLUtil.GetTemplateInfo("SpellBookItemTemplate").height
	local view, used, pages = BlizzardEnd(paged, itemHeight, header:GetHeight())
	local grid = {
		views = paged.viewsPerPage,
		width = paged.ViewFrames[1]:GetWidth(),
		height = Model.Room(
			paged.ViewFrames[1]:GetHeight(),
			paged.ViewFrames[1]:GetTop(),
			paged.PagingControls:GetTop()
		),
		columns = paged.columnsPerRow,
		gap = paged.xPadding,
		pad = paged.yPadding,
		spacer = paged.spacerSize,
		header = header:GetHeight(),
		item = itemHeight,
	}
	local top, slots = Model.Layout(#chosen, view, used, grid)
	extraPages = slots[#slots].page
	extra = math.min(extra, extraPages)
	local current = paged.PagingControls:GetCurrentPage()
	local onLast = current == pages
	if not onLast then
		extra = 0
	end

	local width = (grid.width - grid.gap * (grid.columns - 1)) / grid.columns
	if onLast and top.page == extra then
		header.Text:SetText("Future Spells")
		header:ClearAllPoints()
		header:SetPoint("TOPLEFT", paged.ViewFrames[top.view], "TOPLEFT", top.x, -top.y)
		header:SetWidth(grid.width)
		header:Show()
	end
	local shown = 0
	for i, slot in ipairs(slots) do
		if onLast and slot.page == extra then
			shown = shown + 1
			local item = Item(shown)
			item:ClearAllPoints()
			item:SetPoint("TOPLEFT", paged.ViewFrames[slot.view], "TOPLEFT", slot.x, -slot.y)
			item:SetWidth(width)
			item:Show()
			Paint(item, chosen[i])
		end
	end

	for _, frame in ipairs(paged.ViewFrames) do
		frame:SetAlpha(extra > 0 and 0 or 1)
	end
	blocker:SetShown(extra > 0)
	paged.PagingControls.PageText:SetAlpha(extraPages > 0 and 0 or 1)
	pageText:SetShown(extraPages > 0)
	pageText:SetFormattedText(PAGE_NUMBER_WITH_MAX, current + extra, pages + extraPages)
	prev:SetShown(extra > 0)
	nextPage:SetShown(onLast and extra < extraPages)
end

---@param step integer
local function Turn(step)
	local to = extra + step
	if to < 0 or to > extraPages then
		return
	end
	extra = to
	PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
	Render()
end

---@param controls Button
---@param template string
---@param step integer
local function Arrow(controls, template, step)
	local arrow = CreateFrame("Button", nil, layer, template)
	arrow:SetAllPoints(controls)
	-- Above our entries and the blocker, which cover the stock pager's own buttons.
	arrow:SetFrameLevel(layer:GetFrameLevel() + 10)
	arrow:SetScript("OnClick", function()
		Turn(step)
	end)
	return arrow
end

local function Create()
	local book = Book()
	local paged = book.PagedSpellsFrame
	local controls = paged.PagingControls
	layer = CreateFrame("Frame", nil, book)
	layer:SetAllPoints(paged)
	layer:SetFrameLevel(paged:GetFrameLevel() + 20)
	layer:SetScript("OnHide", function()
		extra = 0
		Uncover(paged)
	end)
	-- Hides the spellbook's own entries from the mouse while one of our pages covers them.
	blocker = CreateFrame("Frame", nil, layer)
	blocker:SetAllPoints()
	blocker:EnableMouse(true)
	blocker:EnableMouseWheel(true)
	blocker:SetScript("OnMouseWheel", function(_, delta)
		Turn(delta > 0 and -1 or 1)
	end)
	blocker:Hide()
	header = CreateFrame("Frame", nil, layer, "SpellBookHeaderTemplate") --[[@as SpellBookHeaderTemplate]]
	pageText = layer:CreateFontString(nil, "OVERLAY", controls.fontName)
	pageText:SetTextColor(SPELLBOOK_FONT_COLOR:GetRGB())
	-- The stock label is only as wide as its own text, so ours keeps just its right edge and its line.
	pageText:SetPoint("RIGHT", controls.PageText)
	pageText:SetWordWrap(false)
	prev = Arrow(controls.PrevPageButton, "PagingControlsPrevPageButtonTemplate", -1)
	nextPage = Arrow(controls.NextPageButton, "PagingControlsNextPageButtonTemplate", 1)

	-- Every page, tab or filter change redraws Blizzard's views; ours follow, starting again on its page.
	hooksecurefunc(paged, "DisplayViewsForCurrentPage", function()
		extra, lastDisplay = 0, GetTime()
		Render()
	end)
	-- Scrolling on past the spellbook's last page carries on into ours.
	paged:HookScript("OnMouseWheel", function(_, delta)
		if delta < 0 and lastDisplay ~= GetTime() and controls:GetCurrentPage() == controls:GetMaxPages() then
			Turn(1)
		end
	end)
end

local function RenderIfShown()
	if layer and layer:IsVisible() then
		Render()
	end
end

-- The server, not the baked list, has the last word on what the class trainer teaches and for how much. The trainer
-- lists only the kinds its filter shows: show both for the scan, then put the filter back as it was. Rows merge by
-- spell and keep only lines the spellbook shows (class tabs, and the General tab's baked rows), so another trainer
-- (weapons, riding) neither replaces nor adds to them.
local function ScanTrainer()
	if not ns.Active("trainableSpells") or IsTradeskillTrainer() then
		return
	end
	if C_Trainer.GetTrainerType() ~= Enum.TrainerType.General then
		return
	end
	local shown = {}
	for kind in pairs(KEEP) do
		if not GetTrainerServiceTypeFilter(kind) then
			shown[#shown + 1] = kind
			SetTrainerServiceTypeFilter(kind, true, false)
		end
	end
	local spells = TweaksForeverCharDB.trainer or {}
	local Resolve = ns.LineResolver()
	for i = 1, GetNumTrainerServices() do
		local name, kind, icon, level, rank = GetTrainerServiceInfo(i)
		local data = KEEP[kind] and C_TooltipInfo.GetTrainerService(i)
		local line = GetTrainerServiceSkillLine(i)
		local lineID = data and data.id and Resolve(data.id, line)
		if lineID then
			spells[data.id] = {
				name = name or C_Spell.GetSpellName(data.id),
				rank = rank ~= "" and rank or nil,
				level = level or 1,
				icon = icon,
				lineID = lineID,
				general = ns.OnGeneral(lineID),
				line = line,
				cost = GetTrainerServiceCost(i),
			}
		end
	end
	for _, kind in ipairs(shown) do
		SetTrainerServiceTypeFilter(kind, false, false)
	end
	if next(spells) then
		TweaksForeverCharDB.trainer = spells
		RenderIfShown()
	end
end

ns.Init(function()
	if type(TweaksForeverCharDB.trainer) == "table" then
		Model.Migrate(TweaksForeverCharDB.trainer, ns.LineResolver())
	end
	ns.On("TRAINER_SHOW", ScanTrainer)
	EventRegistry:RegisterCallback("PlayerSpellsFrame.SpellBookFrame.Show", function()
		if not layer then
			Create()
		end
		Render()
	end)
	-- Blizzard redraws its entries in place when a spell is learned, without a new page display.
	ns.On("SPELLS_CHANGED", function()
		C_Timer.After(0, RenderIfShown)
	end)
	ns.On("PLAYER_LEVEL_UP", function()
		C_Timer.After(0, RenderIfShown)
	end)
	Settings.SetOnValueChangedCallback("TweaksForever_trainableSpells", RenderIfShown)
end)
