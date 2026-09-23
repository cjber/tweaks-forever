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

local function Format(yards)
	if yards < 1000 then
		return ("%d yd"):format(yards)
	end
	return ("%.1fk yd"):format(yards / 1000)
end

ns.Init(function()
	local modules = { QuestObjectiveTracker, CampaignQuestObjectiveTracker }
	-- [block] = { label, glow }; our own regions only, never Blizzard's, so the tracker's secure item buttons stay clean.
	local decor = {}

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
		if not position then
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

	local function Decor(block)
		local d = decor[block]
		if not d then
			local label = block:CreateFontString(nil, "OVERLAY", "ObjectiveTrackerLineFont")
			label:SetJustifyH("RIGHT")
			local glow = block:CreateTexture(nil, "BACKGROUND")
			glow:SetColorTexture(1, 1, 1)
			glow:SetGradient("HORIZONTAL", CreateColor(1, 0.82, 0, 0.22), CreateColor(1, 0.82, 0, 0))
			glow:SetPoint("TOPLEFT", -28, 3)
			glow:SetPoint("BOTTOMRIGHT", 0, -1)
			d = { label = label, glow = glow }
			decor[block] = d
		end
		return d
	end

	local function Hide(block)
		local d = decor[block]
		if d then
			d.label:Hide()
			d.glow:Hide()
		end
	end

	-- A quest with no area on this continent shows nothing. Anchors only move when the tracker lays out again.
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
			d.label:SetPoint("RIGHT", block, "RIGHT", block.rightEdgeOffset or 0, 0)
		end
		d.label:SetText(here and "here" or Format(math.sqrt(distanceSq)))
		if here then
			d.label:SetTextColor(GREEN_FONT_COLOR:GetRGB())
		else
			d.label:SetTextColor(0.6, 0.6, 0.6)
		end
		d.label:Show()
		d.glow:SetShown(here)
	end

	local function Each(fn)
		for _, module in ipairs(modules) do
			module:EnumerateActiveBlocks(fn)
		end
	end

	local function Relayout(block)
		Update(block, true)
	end

	for _, module in ipairs(modules) do
		hooksecurefunc(module, "EndLayout", function()
			if ns.Active("questDistance") then
				CheckAreas()
				Each(Relayout)
			else
				Each(Hide)
			end
		end)
		hooksecurefunc(module, "OnFreeBlock", function(_, block)
			Hide(block)
		end)
	end

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
		Each(Update)
	end)
end)
