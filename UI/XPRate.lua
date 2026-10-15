---@type string, TFNamespace
local _, ns = ...
local L = ns.L

local KEY = "xpRate"

ns.Feature({
	key = KEY,
	category = "Interface",
	name = "XP per hour on the experience bar",
	tooltip = "Pointing at the experience bar adds your XP per hour over the last 15 minutes, the time to your next "
		.. "level at that pace, and about how many kills or quests that is.",
	default = true,
	conflicts = { { addon = "XToLevel" }, { polestar = "qol.xpTracker" } },
})

-- The window the rate is measured over, in seconds, and how many recent kills and quests the averages use.
local WINDOW, RECENT = 900, 10
-- XP that arrives within this long of combat counts as a kill's; a quest's XP is expected within QUEST_WAIT of its
-- hand-in, either side; no rate shows until FIRST seconds of data.
local AFTER_COMBAT, QUEST_WAIT, FIRST = 3, 2, 300

---@class TFXPRate
local Model = {}
ns.XPRate = Model

---@class TFXPGain
---@field at number
---@field xp number

-- XP gained, over the window; recent kill and quest gains for the averages.
---@type TFXPGain[]
local gains = {}
---@type number[], number[]
local kills, quests = {}, {}
local started, lastXP, lastMax
local questXP, questAt, combatEnded = 0, nil, nil
-- The last gain counted as a kill, in case its quest's hand-in event comes just after it.
---@type TFXPGain?
local lastKill

---@param list number[]
---@param value number
local function Push(list, value)
	list[#list + 1] = value
	if #list > RECENT then
		table.remove(list, 1)
	end
end

-- The middle value, so one odd lump (a discovery mid-fight) doesn't skew it.
---@param list number[]
---@return number?
local function Median(list)
	if #list == 0 then
		return nil
	end
	local sorted = { unpack(list) }
	table.sort(sorted)
	local middle = (#sorted + 1) / 2
	return (sorted[math.floor(middle)] + sorted[math.ceil(middle)]) / 2
end

-- Start counting from now (login, or a reset in tests).
---@param now number
---@param xp number
---@param max number
function Model.Start(now, xp, max)
	gains, kills, quests = {}, {}, {}
	started, lastXP, lastMax, questXP, questAt, combatEnded, lastKill = now, xp, max, 0, nil, nil, nil
end

-- A quest handed in for `xp` at `now`: the next XP update is that quest's, not a kill's. If the XP arrived just
-- before the hand-in event and was taken for a kill, it is moved back.
---@param xp number
---@param now number
function Model.QuestXP(xp, now)
	if not xp or xp <= 0 then
		return
	end
	Push(quests, xp)
	if lastKill and now - lastKill.at <= QUEST_WAIT and lastKill.xp == xp and kills[#kills] == xp then
		kills[#kills], lastKill = nil, nil
		return
	end
	questXP, questAt = questXP + xp, now
end

-- Combat ended at `now`: XP just after it still counts as a kill's.
---@param now number
function Model.CombatEnded(now)
	combatEnded = now
end

-- The XP bar moved to `xp` of `max`, at `now`, in or out of combat. A level up wraps through the old level's top.
---@param now number
---@param xp number
---@param max number
---@param inCombat boolean
function Model.Update(now, xp, max, inCombat)
	if not started then
		Model.Start(now, xp, max)
		return
	end
	local gain = xp - lastXP
	if gain < 0 then
		gain = (lastMax - lastXP) + xp
	end
	-- A max that changes alone (the new level's, before the XP moves) keeps the old top for the wrap.
	if gain <= 0 then
		return
	end
	lastXP, lastMax = xp, max
	gains[#gains + 1] = { at = now, xp = gain }
	while gains[1] and now - gains[1].at > WINDOW do
		table.remove(gains, 1)
	end
	if questAt and now - questAt > QUEST_WAIT then
		questXP, questAt = 0, nil
	end
	local fromQuest = math.min(gain, questXP)
	questXP = questXP - fromQuest
	local rest = gain - fromQuest
	if rest > 0 and (inCombat or (combatEnded and now - combatEnded <= AFTER_COMBAT)) then
		Push(kills, rest)
		lastKill = { at = now, xp = rest }
	end
end

-- XP per hour over the window (or since counting started, when that is shorter); nil for the first five minutes.
---@param now number
---@return number?
function Model.Rate(now)
	if not started or now - started < FIRST then
		return nil
	end
	local sum = 0
	for index = #gains, 1, -1 do
		local gain = gains[index]
		if now - gain.at > WINDOW then
			break
		end
		sum = sum + gain.xp
	end
	return sum / math.min(WINDOW, now - started) * 3600
end

-- The tooltip lines for `xp` of `max` at `now`.
---@param now number
---@param xp number
---@param max number
---@return string[]
function Model.Lines(now, xp, max)
	local lines = {}
	local rate = Model.Rate(now)
	local left = max - xp
	if rate and rate > 0 then
		lines[#lines + 1] = L["XP per hour: %s"]:format(BreakUpLargeNumbers(math.floor(rate + 0.5)))
		lines[#lines + 1] = L["Time to level: %s"]:format(SecondsToTime(math.floor(left / rate * 3600 + 0.5)))
	end
	local kill, quest = Median(kills), Median(quests)
	if kill and kill > 0 then
		lines[#lines + 1] = L["Kills to level: about %d"]:format(math.ceil(left / kill))
	end
	if quest and quest > 0 then
		lines[#lines + 1] = L["Quests to level: about %d"]:format(math.ceil(left / quest))
	end
	return lines
end

ns.Init(function()
	local function Restart()
		Model.Start(GetTime(), UnitXP("player"), UnitXPMax("player"))
	end
	Restart()
	-- Nothing is counted while off or covered by another addon; switching back on starts afresh.
	local active = ns.Active(KEY)
	local function Toggled()
		if ns.Active(KEY) ~= active then
			active = ns.Active(KEY)
			Restart()
		end
	end
	ns.OnSettingChanged(KEY, Toggled)
	hooksecurefunc(ns, "RefreshConflicts", Toggled)
	ns.On("QUEST_TURNED_IN", function(_, xp)
		if active then
			Model.QuestXP(xp, GetTime())
		end
	end)
	ns.On("PLAYER_REGEN_ENABLED", function()
		if active then
			Model.CombatEnded(GetTime())
		end
	end)
	ns.On("PLAYER_XP_UPDATE", function()
		if active then
			Model.Update(GetTime(), UnitXP("player"), UnitXPMax("player"), UnitAffectingCombat("player"))
		end
	end)

	-- After Blizzard's own experience tooltip (anchored to UIParent by GameTooltip_SetDefaultAnchor), on each
	-- container's experience bar, read from its bars and never written.
	local function AddLines()
		if not ns.Usable(GameTooltip) then
			return
		end
		if not ns.Active(KEY) or not GameTooltip:IsShown() or GameTooltip:GetOwner() ~= UIParent then
			return
		end
		local lines = Model.Lines(GetTime(), UnitXP("player"), UnitXPMax("player"))
		for _, line in ipairs(lines) do
			GameTooltip:AddLine(line, 1, 1, 1)
		end
		if #lines > 0 then
			GameTooltip:Show()
		end
	end
	local experience = StatusTrackingBarInfo and StatusTrackingBarInfo.BarsEnum.Experience
	for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
		local bar = experience and container and container.bars and container.bars[experience]
		if bar then
			bar:HookScript("OnEnter", AddLines)
		end
	end
end)
