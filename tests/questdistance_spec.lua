-- Nearest quests first: the client's SortQuestWatches leaves manual watches alone, so the order is worked out here.
local ns = {
	Feature = function() end,
	Init = function() end,
	L = setmetatable({}, {
		__index = function(_, k)
			return k
		end,
	}),
}
setfenv(assert(loadfile("QuestDistance.lua")), setmetatable({}, { __index = _G }))("TweaksForever", ns)
local Nearest = ns.QuestDistance.Nearest

local function same(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

-- Watched in the order the screenshot showed: 531, 276, 28, 573 yards.
local order = Nearest({ 1, 2, 3, 4 }, { [1] = 531 ^ 2, [2] = 276 ^ 2, [3] = 28 ^ 2, [4] = 573 ^ 2 })
assert(order and same(order, { 3, 2, 1, 4 }), "nearest first")
-- Already in order: nothing to move.
assert(Nearest({ 3, 2, 1 }, { [1] = 9, [2] = 4, [3] = 1 }) == nil, "no change when sorted")
-- Quests on another continent go after, in the order they had; ties keep theirs.
order = Nearest({ 5, 1, 6, 2, 7 }, { [1] = 4, [2] = 4, [7] = 1 })
assert(order and same(order, { 7, 1, 2, 5, 6 }), "no distance after, ties stable: " .. table.concat(order or {}, ","))
assert(Nearest({}, {}) == nil)
print("questdistance: ok")
