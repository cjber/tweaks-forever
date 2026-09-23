local _, ns = ...

ns.Feature({
	key = "questDistance",
	category = "Interface",
	name = "Nearest quests first",
	tooltip = "Sorts the quest tracker nearest first and shows how far away each quest's area is. The quest whose "
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

-- Yards within which you count as inside a quest's area, and how far you move before the list is re-sorted.
local HERE, RESORT = 10, 25

local function Format(yards)
	if yards <= HERE then
		return "here"
	elseif yards < 1000 then
		return ("%d yd"):format(yards)
	end
	return ("%.1fk yd"):format(yards / 1000)
end

ns.Init(function()
	local modules = { QuestObjectiveTracker, CampaignQuestObjectiveTracker }
	-- [block] = { label, glow }; our own regions only, never Blizzard's, so the tracker's secure item buttons stay clean.
	local decor = {}

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
		local yards = math.sqrt(distanceSq)
		local here = yards <= HERE
		if relayout then
			d.label:ClearAllPoints()
			d.label:SetPoint("TOP", block.HeaderText, "TOP")
			d.label:SetPoint("RIGHT", block, "RIGHT", block.rightEdgeOffset or 0, 0)
		end
		d.label:SetText(Format(yards))
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
			Each(ns.Active("questDistance") and Relayout or Hide)
		end)
		hooksecurefunc(module, "OnFreeBlock", function(_, block)
			Hide(block)
		end)
	end

	-- Re-sort only after real movement and never in combat, when the tracker's item buttons can't be moved.
	local lastX, lastY
	C_Timer.NewTicker(1, function()
		if not ns.Active("questDistance") then
			if lastX then
				lastX, lastY = nil, nil
				Each(Hide)
			end
			return
		end
		local y, x = UnitPosition("player")
		if x and not InCombatLockdown() and (not lastX or (x - lastX) ^ 2 + (y - lastY) ^ 2 > RESORT * RESORT) then
			lastX, lastY = x, y
			C_QuestLog.SortQuestWatches()
		end
		Each(Update)
	end)
end)
