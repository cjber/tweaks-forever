---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L
local KEY = "chatWebLinks"
local Chat = ns.Chat

ns.Feature({
	key = KEY,
	category = "Chat",
	name = "Clickable web links",
	tooltip = "A web address in chat shows as a light blue link. Clicking it opens a small box with the address "
		.. "selected, ready to copy, because the game cannot open a browser itself.",
	default = false,
	conflicts = { { addon = "Prat-3.0" } },
})

---@class TFChatWebLinks
local Model = {}
ns.ChatWebLinks = Model

-- Sentence punctuation that follows a web address in ordinary writing. It is left out of the link, so
-- "see https://example.com." copies the address without the full stop.
local TRAILING = {
	[","] = true,
	["."] = true,
	[";"] = true,
	[":"] = true,
	["!"] = true,
	["?"] = true,
	[")"] = true,
	["]"] = true,
	["}"] = true,
}

-- The link colour: a light blue, so it stands apart from the item links' quality colour and the chat text.
local COLOR = "|cff66bbff"

-- A web address, from http:// or https:// to the next whitespace. Trailing sentence punctuation is not part of it.
---@param text string
---@return { [1]: string, [2]: integer, [3]: integer }[]
function Model.URLs(text)
	local found = {}
	local at = 1
	while true do
		local start, finish = text:find("https?://[^%s|]+", at)
		if not start then
			break
		end
		local url = text:sub(start, finish)
		while #url > 8 and TRAILING[url:sub(-1)] do
			url = url:sub(1, -2)
			finish = finish - 1
		end
		if #url > 7 then
			found[#found + 1] = { url, start, finish }
		end
		at = finish + 1
	end
	return found
end

-- Replace each web address with a link the client's SetItemRef path can hand back to us. The displayed text is the
-- address itself, in the link colour.
---@param text string
---@return string
function Model.Linkify(text)
	local found = Model.URLs(text)
	if #found == 0 then
		return text
	end
	local out, at = {}, 1
	for _, span in ipairs(found) do
		local url = span[1]
		out[#out + 1] = text:sub(at, span[2] - 1)
		out[#out + 1] = ("%s|Htweaksurl:%s|h[%s]|h|r"):format(COLOR, url, url)
		at = span[3] + 1
	end
	out[#out + 1] = text:sub(at)
	return table.concat(out)
end

---@type Frame?
local box
---@type EditBox?
local edit

-- A small copy box: the address is shown selected, and Escape closes it. There is no browser to open from the
-- game, so selecting the text is the whole action.
---@return Frame
local function Box()
	if box then
		return box
	end
	box = CreateFrame("Frame", "TweaksForeverChatURLCopy", UIParent, "BasicFrameTemplateWithInset")
	box:SetSize(440, 116)
	box:SetFrameStrata("DIALOG")
	box:SetClampedToScreen(true)
	if box.TitleText then
		box.TitleText:SetText(L["Copy link"])
	else
		local title = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		title:SetPoint("TOP", 0, -8)
		title:SetText(L["Copy link"])
	end
	edit = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
	edit:SetPoint("TOPLEFT", 20, -38)
	edit:SetPoint("TOPRIGHT", -20, -38)
	edit:SetHeight(28)
	edit:SetAutoFocus(false)
	local hint = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("BOTTOMLEFT", 20, 16)
	hint:SetText(L["Press Escape to close."])
	ns.EscapeCloses(box)
	return box
end

-- Open the copy box on `url`, with the text selected so Ctrl+C copies it.
---@param url string
function Model.Copy(url)
	if type(url) ~= "string" or url == "" then
		return
	end
	local frame = Box()
	if edit then
		edit:SetText(url)
		edit:HighlightText()
	end
	frame:Show()
	if edit then
		edit:SetFocus()
	end
end

-- The client's own custom link path: SetItemRef asks LinkUtil, and a registered type is handled before the item
-- tooltip. Nothing of Blizzard's is replaced.
---@param linkData table
---@return integer?
local function Click(_, _, linkData)
	local url = linkData and linkData.options
	if type(url) == "string" and url ~= "" then
		Model.Copy(url)
	end
	return LinkProcessorResponse and LinkProcessorResponse.Handled or nil
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
	local linked = Model.Linkify(body)
	if linked ~= body then
		return false, linked, ...
	end
end

ns.Init(function()
	if LinkUtil and LinkUtil.RegisterLinkHandler then
		pcall(LinkUtil.RegisterLinkHandler, "tweaksurl", Click)
	end
	Chat.Filter(Chat.TEXT_EVENTS, Filter)
end)
