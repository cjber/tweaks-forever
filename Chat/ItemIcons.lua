---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

local KEY = "chatItemIcons"
local Chat = ns.Chat

ns.Feature({
	key = KEY,
	category = "Chat",
	name = "Item icons in chat",
	tooltip = "A small picture of the item appears before each item link in chat, so a trade or a loot link is "
		.. "recognised at a glance. Quest, spell and other links are left alone.",
	default = false,
	conflicts = { { addon = "Prat-3.0" } },
})

---@class TFChatItemIcons
local Model = {}
ns.ChatItemIcons = Model

-- The client's own square icon crop: 64 by 64 texels, with the 5 to 59 crop taking off the baked bevel. A height
-- of 0 lets the chat line's font height choose the icon's size.
local ICON = "|T%s:0:0:0:0:64:64:5:59:5:59|t " -- art-ok: the registry's square icon crop, at the line's own height

-- The icon the client gives an item, or nil when it does not know the item.
---@param itemID number
---@return string|integer?
local function Icon(itemID)
	return C_Item.GetItemIconByID(itemID)
end

-- Put the icon before every item hyperlink's target. Only `|Hitem:` is matched: a spell, quest, achievement or
-- player link keeps its own appearance.
---@param text string
---@return string
function Model.Add(text)
	return (
		text:gsub("|Hitem:(%d+)", function(id)
			local itemID = tonumber(id)
			local texture = itemID and Icon(itemID)
			if not texture then
				return nil
			end
			return ICON:format(tostring(texture)) .. "|Hitem:" .. id
		end)
	)
end

---@param text any
local function Filter(_, _, text, ...)
	if not ns.Active(KEY) then
		return
	end
	local body = ns.Readable(text)
	if type(body) ~= "string" then
		return
	end
	local added = Model.Add(body)
	if added ~= body then
		return false, added, ...
	end
end

ns.Init(function()
	Chat.Filter(Chat.TEXT_EVENTS, Filter)
end)
