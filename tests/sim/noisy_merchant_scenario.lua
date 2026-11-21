-- luacheck: read globals scenario ADDON
-- #639: Tweaks waits for item data through one listener (Core/ItemInfo.lua, #636). Unrequested item data
-- should cost no addon API calls, and noisy event paths should stay flat with a merchant or quest reward panel open.
-- The sim counts Blizzard's handlers too, so read Tweaks' own registrations from ns.On's table.
local NOISE =
	{ "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT", "BAG_UPDATE", "BAG_UPDATE_DELAYED", "MERCHANT_UPDATE" }

local function Handlers(ns)
	for i = 1, math.huge do
		local name, value = debug.getupvalue(ns.On, i)
		if not name then
			return {}
		elseif name == "handlers" then
			return value
		end
	end
end

local function Window(sim, ns, seconds)
	sim.work.reset()
	sim:advance(seconds)
	local out, handlers = {}, Handlers(ns)
	for _, event in ipairs(NOISE) do
		local stat = sim.work.paths[event]
		out[event] = {
			runs = stat and stat.runs or 0,
			apiCalls = stat and stat.apiCalls or 0,
			maxApiCalls = stat and stat.maxApiCalls or 0,
			ours = #(handlers[event] or {}),
		}
	end
	return out
end

local function Namespace(sim)
	local ns
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == ADDON then
			ns = entry.ns
		end
	end
	return assert(ns, "Tweaks loaded")
end

local function AssertFlat(closed, open, later)
	assert(closed.GET_ITEM_INFO_RECEIVED.ours == 1, "one item info listener (#636)")
	for _, event in ipairs(NOISE) do
		local a, b, c = closed[event], open[event], later[event]
		assert(b.ours == a.ours and c.ours == a.ours, event .. ": the same handlers, panel open or closed")
		if event ~= "MERCHANT_UPDATE" then
			assert(a.runs > 0 and b.runs > 0 and c.runs > 0, event .. ": the noise raises it in every window")
		end
		assert(c.maxApiCalls <= b.maxApiCalls, event .. ": an event costs no more as the noise runs on")
	end
	for _, event in ipairs({ "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT" }) do
		for name, window in pairs({ closed = closed[event], open = open[event], later = later[event] }) do
			assert(window.apiCalls == 0, ("%s: no client calls from addon code, panel %s"):format(event, name))
		end
	end
end

scenario("Tweaks' work per noisy item event stays flat at a merchant", function(sim)
	dofile("tests/sim/forever_core.lua").install(sim)
	sim.world.items[2589] = { name = "Linen Cloth" }
	sim.world.items[2592] = { name = "Wool Cloth" }
	sim:login()
	local ns = Namespace(sim)

	sim:noisy({ seed = 11 })
	local closed = Window(sim, ns, 2)

	sim:openMerchant()
	local open = Window(sim, ns, 2)
	local later = Window(sim, ns, 2)
	assert(open.MERCHANT_UPDATE.runs > 0, "the merchant churns while open")
	AssertFlat(closed, open, later)
	sim:closeMerchant()
	sim:noisy(false)
	sim:expectNoErrors(ADDON)
end)

scenario("Tweaks' work per noisy item event stays flat on a quest reward choice", function(sim)
	dofile("tests/sim/forever_core.lua").install(sim)
	sim.world.items[2589] = { name = "Linen Cloth", sell = 13 }
	sim.world.items[2592] = { name = "Wool Cloth", sell = 33 }
	sim:login()
	local ns = Namespace(sim)

	sim:noisy({ seed = 17 })
	local closed = Window(sim, ns, 2)

	sim:openQuestReward(1, { choices = { 2589, 2592 } })
	local open = Window(sim, ns, 2)
	local later = Window(sim, ns, 2)
	AssertFlat(closed, open, later)

	local rewards = sim.G.QuestInfoRewardsFrame
	assert(sim.G.QuestFrameRewardPanel:IsVisible(), "the quest reward panel is visible")
	local choices = {}
	for _, button in ipairs(rewards.RewardButtons) do
		if button:IsVisible() and button.type == "choice" then
			choices[#choices + 1] = button
		end
	end
	assert(#choices == 2, "both quest choices are visible")

	local marked = {}
	for _, child in ipairs({ rewards:GetChildren() }) do
		if child:IsVisible() then
			for _, region in ipairs({ child:GetRegions() }) do
				if
					region:GetObjectType() == "Texture"
					and region:IsVisible()
					and region:GetTexture() == "Interface\\MoneyFrame\\UI-GoldIcon"
				then
					local _, anchor = child:GetPoint()
					marked[#marked + 1] = anchor
				end
			end
		end
	end
	assert(#marked == 1 and marked[1] == choices[2].Icon, "only the higher-value reward has a visible gold coin")

	sim:closeQuestReward()
	sim:noisy(false)
	sim:expectNoErrors(ADDON)
end)
