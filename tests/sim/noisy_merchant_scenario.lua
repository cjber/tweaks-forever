-- luacheck: read globals scenario ADDON
-- #639: a live client raises item, bag and merchant traffic that no addon asked for. Tweaks waits for item data
-- through one listener (Core/ItemInfo.lua, #636), so its work per noisy event stays the same with the merchant open
-- or closed and as the noise runs on: the same handlers, no client API calls from addon code on item data it was not
-- waiting for, and a bag update that costs no more over time. The sim counts every frame's handlers, Blizzard's
-- included, so Tweaks' own are read from ns.On's table. The quest reward choice half waits on the sim's quest reward
-- panel (cjber/forever-core#927).
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

scenario("Tweaks' work per noisy item event stays flat at a merchant", function(sim)
	dofile("tests/sim/forever_core.lua").install(sim)
	sim.world.items[2589] = { name = "Linen Cloth" }
	sim.world.items[2592] = { name = "Wool Cloth" }
	sim:login()
	local ns
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == ADDON then
			ns = entry.ns
		end
	end
	assert(ns, "Tweaks loaded")

	sim:noisy({ seed = 11 })
	local closed = Window(sim, ns, 2)
	assert(closed.GET_ITEM_INFO_RECEIVED.runs > 0, "the noise raises item info")
	assert(closed.GET_ITEM_INFO_RECEIVED.ours == 1, "one item info listener (#636)")

	sim:openMerchant()
	local open = Window(sim, ns, 2)
	local later = Window(sim, ns, 2)
	assert(open.MERCHANT_UPDATE.runs > 0, "the merchant churns while open")
	for _, event in ipairs(NOISE) do
		local a, b, c = closed[event], open[event], later[event]
		assert(b.ours == a.ours and c.ours == a.ours, event .. ": the same handlers, merchant open or closed")
		if event ~= "MERCHANT_UPDATE" then
			assert(a.runs > 0 and b.runs > 0 and c.runs > 0, event .. ": the noise raises it in every window")
		end
		assert(c.maxApiCalls <= b.maxApiCalls, event .. ": an event costs no more as the noise runs on")
	end
	for _, event in ipairs({ "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT" }) do
		for name, window in pairs({ closed = closed[event], open = open[event], later = later[event] }) do
			assert(window.apiCalls == 0, ("%s: no client calls from addon code, merchant %s"):format(event, name))
		end
	end
	sim:closeMerchant()
	sim:noisy(false)
	sim:expectNoErrors(ADDON)
end)
