---@type string, TFNamespace
local _, ns = ...

-- Tweaks Forever's own lines in /tweaks report: settings that differ from today's defaults (a saved value from
-- before a default changed counts too), and which switched-on features are standing down for another addon or
-- missing one they need. Feature keys rather than their names, so the report
-- reads the same in every locale.

---@param value any
---@return string
local function Show(value)
	if value == true then
		return "on"
	elseif value == false then
		return "off"
	end
	return tostring(value)
end

-- The report's Tweaks Forever lines.
---@return string[]
function ns.ReportLines()
	local changed, conflicts, missing = {}, {}, {}
	for _, feature in ipairs(ns.features) do
		local key = feature.key
		local value = ns.db and ns.db[key]
		if value ~= nil and value ~= feature.default then
			changed[#changed + 1] = ("%s=%s"):format(key, Show(value))
		end
		local on = value ~= nil and value ~= false
		local conflict, needs = on and ns.ConflictOf(key), on and ns.MissingOf(key)
		if conflict then
			conflicts[#conflicts + 1] = ("%s (%s)"):format(key, conflict)
		end
		if needs then
			missing[#missing + 1] = ("%s (%s)"):format(key, needs)
		end
	end
	local function Line(label, list)
		return ("%s: %s"):format(label, list[1] and table.concat(list, ", ") or "none")
	end
	return {
		Line("Differs from default", changed),
		Line("Standing down for", conflicts),
		Line("Missing an addon", missing),
	}
end
