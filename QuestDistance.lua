---@type string, TFNamespace
local _, ns = ...

ns.Feature({
	key = "questDistance",
	category = "Interface",
	name = "Nearest quests first",
	tooltip = "Sorts the quest tracker nearest first and shows how far away each quest is. The quest whose "
		.. "area you're standing in is marked 'here' with a soft highlight.",
	default = true,
	conflicts = {
		{
			addon = "Questie",
			when = function()
				local profile = Questie and Questie.db and Questie.db.profile
				return profile and profile.trackerEnabled
			end,
		},
	},
})

-- Yards you move before your position is checked against quest areas again, and before the list is re-sorted.
local RECHECK, RESORT = 5, 25
-- Space between the distance column and the item buttons.
local GAP = 4

---@param yards number
---@return string
local function Format(yards)
	if yards < 1000 then
		return ("%d yd"):format(yards)
	end
	return ("%.1fk yd"):format(yards / 1000)
end

local function CreateAreaProbe()
	-- The distance API measures to a quest's map marker, not its area, so "here" asks an invisible quest-area frame
	-- which area is under your map position, the same test the world map uses for its area tooltips.
	local probe = CreateFrame("QuestPOIFrame", nil, UIParent)
	probe:SetAllPoints()
	probe:SetFillAlpha(0)
	probe:SetBorderAlpha(0)
	local inside, probeMap = {}, nil

	local function CheckAreas()
		wipe(inside)
		local mapID = C_Map.GetBestMapForUnit("player")
		local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
		if not mapID or not position then
			return
		end
		if mapID ~= probeMap then
			probe:SetMapID(mapID)
			probeMap = mapID
		end
		local x, y = position:GetXY()
		for i = 1, C_QuestLog.GetNumQuestWatches() do
			local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
			if questID then
				probe:DrawNone()
				probe:DrawBlob(questID, true)
				inside[questID] = probe:UpdateMouseOverTooltip(x, y) == questID or nil
			end
		end
		probe:DrawNone()
	end

	return CheckAreas, inside
end

---@param inside TFMarks
---@param Each fun(fn: fun(block: TFQuestBlock))
local function CreateDecorations(inside, Each)
	-- Our own regions only, so the tracker's secure item buttons stay clean.
	local decor = {}

	---@param block TFQuestBlock
	---@return TFQuestDecor
	local function Decor(block)
		local d = decor[block]
		if not d then
			local label = block:CreateFontString(nil, "OVERLAY", "ObjectiveTrackerLineFont")
			label:SetJustifyH("RIGHT")
			local glow = block:CreateTexture(nil, "BACKGROUND")
			glow:SetColorTexture(1, 1, 1)
			local start = CreateColor(1, 0.82, 0, 0.22) --[[@as colorRGBA]]
			local finish = CreateColor(1, 0.82, 0, 0) --[[@as colorRGBA]]
			glow:SetGradient("HORIZONTAL", start, finish)
			glow:SetPoint("TOPLEFT", -28, 3)
			glow:SetPoint("BOTTOMRIGHT", 0, -1)
			d = { label = label, glow = glow }
			decor[block] = d
		end
		return d
	end

	---@param block TFQuestBlock
	local function Hide(block)
		local d = decor[block]
		if d then
			d.label:Hide()
			d.glow:Hide()
		end
	end

	-- The right edge every distance lines up on: left of the item buttons whenever any tracked quest shows one, so
	-- the column stays straight instead of stepping in beside each button.
	local column = 0

	-- A quest with no area on this continent shows nothing. Anchors only move when the tracker lays out again.
	---@param block TFQuestBlock
	---@param relayout? boolean
	local function Update(block, relayout)
		local distanceSq, onContinent = C_QuestLog.GetDistanceSqToQuest(block.id)
		if not distanceSq or not onContinent then
			return Hide(block)
		end
		local d = Decor(block)
		local here = inside[block.id]
		if relayout then
			d.label:ClearAllPoints()
			d.label:SetPoint("TOP", block.HeaderText, "TOP")
			d.label:SetPoint("RIGHT", block, "RIGHT", column, 0)
		end
		d.label:SetText(here and "here" or Format(math.sqrt(distanceSq)))
		if here then
			d.label:SetTextColor(GREEN_FONT_COLOR:GetRGB()) -- multi-value: r, g, b
		else
			d.label:SetTextColor(0.6, 0.6, 0.6)
		end
		d.label:Show()
		d.glow:SetShown(here)
	end

	---@param block TFQuestBlock
	local function Relayout(block)
		Update(block, true)
	end

	---@param block TFQuestBlock
	local function Widen(block)
		column = math.min(column, block.rightEdgeOffset or 0)
	end

	local function Layout()
		column = 0
		Each(Widen)
		if column < 0 then
			column = column - GAP
		end
		Each(Relayout)
	end

	return Hide, Layout
end

ns.Init(function()
	local modules = { QuestObjectiveTracker, CampaignQuestObjectiveTracker }
	---@param fn fun(block: TFQuestBlock)
	local function Each(fn)
		for _, module in ipairs(modules) do
			module:EnumerateActiveBlocks(fn)
		end
	end

	local CheckAreas, inside = CreateAreaProbe()
	local Hide, Layout = CreateDecorations(inside, Each)

	local function Refresh()
		if ns.Active("questDistance") then
			CheckAreas()
			Layout()
		else
			Each(Hide)
		end
	end
	-- The tracker lays its blocks out on the frame after it is marked dirty (DirtiableMixin, from RunNextFrame), so
	-- the labels follow once its dirty flag clears. Watched from a frame of our own: hooksecurefunc on the modules'
	-- EndLayout or OnFreeBlock writes into Blizzard's tracker and taints its layout. A freed block hides its labels
	-- with it, as they are its children.
	local pending = false
	CreateFrame("Frame"):SetScript("OnUpdate", function()
		local container = QuestObjectiveTracker.parentContainer
		if container and container.dirty then
			pending = true
		elseif pending then
			pending = false
			Refresh()
		end
	end)

	---@param last {x: number?, y: number?}
	---@param x number
	---@param y number
	---@param yards number
	---@return boolean
	local function Moved(last, x, y, yards)
		return not last.x or (x - last.x) ^ 2 + (y - last.y) ^ 2 > yards * yards
	end

	-- Re-sort only after real movement and never in combat, when the tracker's item buttons can't be moved.
	local sorted, checked = {}, {}
	C_Timer.NewTicker(1, function()
		if not ns.Active("questDistance") then
			if checked.x then
				sorted.x, checked.x = nil, nil
				Each(Hide)
			end
			return
		end
		local y, x = UnitPosition("player")
		if x and Moved(checked, x, y, RECHECK) then
			checked.x, checked.y = x, y
			CheckAreas()
		end
		if x and not InCombatLockdown() and Moved(sorted, x, y, RESORT) then
			sorted.x, sorted.y = x, y
			C_QuestLog.SortQuestWatches()
		end
		-- Also catches a tracker update that ran without marking it dirty (collapsing it, say).
		Layout()
	end)
end)
