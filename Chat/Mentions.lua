---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

local KEY = "chatMentions"
local Chat = ns.Chat

ns.Feature({
	key = KEY,
	category = "Chat",
	name = "Mention marker",
	tooltip = "A chat line from another player that names your character as a whole word gets a small chat icon at "
		.. "its start and your name in the game's normal colour. No sound plays and no line is added.",
	default = false,
	conflicts = { { addon = "Prat-3.0" } },
})

---@class TFChatMentions
local Model = {}
ns.ChatMentions = Model

-- The client's own Communities chat bubble, at the height of a chat line. The atlas is square, so Art.Markup keeps
-- its shape.
local MARKER = "communities-icon-chat"

-- A byte that continues a word: an ASCII letter or digit, or any byte of a multi-byte character. A name is matched
-- only when the bytes on both sides are outside that set.
---@param byte string
---@return boolean
local function WordByte(byte)
	if byte == "" then
		return false
	end
	local value = byte:byte()
	return (value >= 48 and value <= 57)
		or (value >= 65 and value <= 90)
		or (value >= 97 and value <= 122)
		or value >= 128
end

-- The escape sequences and link spans in `text`, as start and end byte positions: a link's payload and its display
-- text, a colour code or its `|r`, and a texture or atlas markup. A name inside one of these is not plain text:
-- wrapping it would corrupt a link's payload or cut a link's own colour off with `|r`.
---@param text string
---@return { [1]: integer, [2]: integer }[]
function Model.Escapes(text)
	local spans = {}
	local at = 1
	while true do
		local start = text:find("|", at, true)
		if not start then
			break
		end
		local kind = text:sub(start + 1, start + 1)
		local finish
		if kind == "H" then
			local _, first = text:find("|h", start + 2, true)
			if first then
				local _, second = text:find("|h", first + 1, true)
				finish = second or first
			end
		elseif kind == "c" then
			finish = start + 9
		elseif kind == "r" then
			finish = start + 1
		elseif kind == "T" then
			local _, close = text:find("|t", start + 2, true)
			finish = close
		elseif kind == "A" then
			local _, close = text:find("|a", start + 2, true)
			finish = close
		end
		if finish and finish <= #text then
			spans[#spans + 1] = { start, finish }
			at = finish + 1
		else
			at = start + 1
		end
	end
	return spans
end

-- Every whole-word occurrence of `name` in the plain text, as start and end byte positions. A match that touches an
-- escape sequence or a link, in its payload or its display text, is left out. Case is ignored, as players type a
-- name in any case; the original text keeps its own casing and the replacement wraps exactly the bytes found.
---@param text string
---@param name string
---@return { [1]: integer, [2]: integer }[]
function Model.Found(text, name)
	local found = {}
	if name == "" then
		return found
	end
	local escapes = Model.Escapes(text)
	local haystack, needle = text:lower(), name:lower()
	local at = 1
	while true do
		local start, finish = haystack:find(needle, at, true)
		if not start then
			break
		end
		local escaped = false
		for _, span in ipairs(escapes) do
			if start <= span[2] and finish >= span[1] then
				escaped = true
				break
			end
		end
		if escaped then
			at = finish + 1
		else
			local before = start > 1 and text:sub(start - 1, start - 1) or ""
			local after = finish < #text and text:sub(finish + 1, finish + 1) or ""
			if not WordByte(before) and not WordByte(after) then
				found[#found + 1] = { start, finish }
			end
			at = finish + 1
		end
	end
	return found
end

-- Mark the line when it names the player as a whole word: the name takes NORMAL_FONT_COLOR and the line begins with
-- the chat icon. The marker is inline text, because a ScrollingMessageFrame has no supported per-line background
-- region. Answers nil when nothing matches.
---@param text string
---@param name string
---@return string?
function Model.Mark(text, name)
	local found = Model.Found(text, name)
	if #found == 0 then
		return nil
	end
	local color = NORMAL_FONT_COLOR
	local out, at = {}, 1
	for _, span in ipairs(found) do
		out[#out + 1] = text:sub(at, span[1] - 1)
		local word = text:sub(span[1], span[2])
		out[#out + 1] = color and color:WrapTextInColorCode(word) or word
		at = span[2] + 1
	end
	out[#out + 1] = text:sub(at)
	local marker = ns.Art and ns.Art.Markup(MARKER, 12) or ""
	return marker .. " " .. table.concat(out)
end

---@param text any
---@param sender any
local function Filter(_, _, text, sender, ...)
	if not ns.Active(KEY) then
		return
	end
	local body = ns.Readable(text)
	local me = Chat.Player()
	if type(body) ~= "string" or not me then
		return
	end
	local author = Chat.ShortName(sender)
	if not author or author == me then
		return
	end
	local marked = Model.Mark(body, me)
	if marked then
		return false, marked, sender, ...
	end
end

ns.Init(function()
	Chat.Filter(Chat.TEXT_EVENTS, Filter)
end)
